defmodule SandboxRuntime.Proxy.HttpProxy do
  @moduledoc """
  HTTP/HTTPS proxy server using Plug and Bandit.

  Filters requests based on domain allowlists/denylists.
  """

  use GenServer
  require Logger

  alias SandboxRuntime.Proxy.DomainFilter

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, 8888)

    state = %{
      port: port,
      server_pid: nil
    }

    {:ok, state, {:continue, :start_server}}
  end

  @impl true
  def handle_continue(:start_server, state) do
    # Start Bandit server
    {:ok, server_pid} =
      Bandit.start_link(
        plug: {__MODULE__.Router, []},
        port: state.port,
        thousand_island_options: [num_acceptors: 10]
      )

    :telemetry.execute(
      [:sandbox_runtime, :proxy, :started],
      %{},
      %{type: :http, port: state.port}
    )

    Logger.info("HTTP Proxy started on port #{state.port}")

    {:noreply, %{state | server_pid: server_pid}}
  end

  @impl true
  def terminate(_reason, state) do
    if state.server_pid do
      GenServer.stop(state.server_pid)
    end

    :telemetry.execute(
      [:sandbox_runtime, :proxy, :stopped],
      %{},
      %{type: :http, port: state.port}
    )

    :ok
  end

  # Plug Router

  defmodule Router do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    # Handle CONNECT for HTTPS tunneling
    match "/", via: :connect do
      handle_connect(conn)
    end

    # Handle regular HTTP requests
    match _ do
      handle_request(conn)
    end

    defp handle_connect(conn) do
      # Extract host from CONNECT request
      [host | _] = String.split(conn.request_path, ":")

      config = SandboxRuntime.ConfigServer.get_config()

      case DomainFilter.check(host, config) do
        :allow ->
          # Allow CONNECT
          send_resp(conn, 200, "Connection established")

        :deny ->
          record_violation(:network, "CONNECT", host)
          send_resp(conn, 403, "Domain not allowed: #{host}")
      end
    end

    defp handle_request(conn) do
      host = get_host(conn)

      config = SandboxRuntime.ConfigServer.get_config()

      case DomainFilter.check(host, config) do
        :allow ->
          proxy_request(conn, host)

        :deny ->
          record_violation(:network, conn.method, host)
          send_resp(conn, 403, "Domain not allowed: #{host}")
      end
    end

    defp get_host(conn) do
      case Plug.Conn.get_req_header(conn, "host") do
        [host | _] -> DomainFilter.normalize_domain(host)
        [] -> ""
      end
    end

    defp proxy_request(conn, host) do
      # Build target URL
      scheme = if conn.port == 443, do: "https", else: "http"
      url = "#{scheme}://#{host}#{conn.request_path}"

      # Add query string if present
      url = if conn.query_string && conn.query_string != "", do: "#{url}?#{conn.query_string}", else: url

      # Get request body
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      # Forward request using Req
      case forward_http_request(conn.method, url, conn.req_headers, body) do
        {:ok, status, headers, resp_body} ->
          conn
          |> put_resp_headers(headers)
          |> send_resp(status, resp_body)

        {:error, _reason} ->
          send_resp(conn, 502, "Proxy error")
      end
    end

    defp forward_http_request(method, url, headers, body) do
      method_atom = String.downcase(method) |> String.to_atom()

      # Make request using Req
      case Req.request(
        method: method_atom,
        url: url,
        headers: headers,
        body: body
      ) do
        {:ok, %Req.Response{status: status, headers: resp_headers, body: resp_body}} ->
          # Convert headers map to list of tuples
          headers_list = Map.to_list(resp_headers)
          {:ok, status, headers_list, resp_body}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp put_resp_headers(conn, headers) do
      Enum.reduce(headers, conn, fn {key, value}, acc ->
        # Handle both string and list values
        value_str = if is_list(value), do: Enum.join(value, ", "), else: to_string(value)
        Plug.Conn.put_resp_header(acc, to_string(key), value_str)
      end)
    end

    defp record_violation(type, operation, target) do
      SandboxRuntime.ViolationStore.add_violation(%{
        type: type,
        operation: operation,
        target: target,
        process: "http_proxy",
        metadata: %{proxy: :http}
      })
    end
  end
end
