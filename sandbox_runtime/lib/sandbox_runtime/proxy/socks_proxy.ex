defmodule SandboxRuntime.Proxy.SocksProxy do
  @moduledoc """
  SOCKS5 proxy server for TCP traffic filtering.

  Uses ThousandIsland for TCP server implementation.
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
    port = Keyword.get(opts, :port, 1080)

    state = %{
      port: port,
      server_pid: nil
    }

    {:ok, state, {:continue, :start_server}}
  end

  @impl true
  def handle_continue(:start_server, state) do
    # Start ThousandIsland SOCKS5 server
    {:ok, server_pid} =
      ThousandIsland.start_link(
        port: state.port,
        handler_module: __MODULE__.Handler,
        handler_options: []
      )

    :telemetry.execute(
      [:sandbox_runtime, :proxy, :started],
      %{},
      %{type: :socks, port: state.port}
    )

    Logger.info("SOCKS5 Proxy started on port #{state.port}")

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
      %{type: :socks, port: state.port}
    )

    :ok
  end

  # SOCKS5 Handler

  defmodule Handler do
    @moduledoc false
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      # SOCKS5 handshake
      case handle_socks5_handshake(socket) do
        :ok ->
          handle_socks5_request(socket)

        :error ->
          :ok
      end

      {:close, state}
    end

    defp handle_socks5_handshake(socket) do
      # Read greeting: [version, nmethods, methods...]
      case ThousandIsland.Socket.recv(socket, 2, 5000) do
        {:ok, <<5, nmethods>>} ->
          # Read methods
          case ThousandIsland.Socket.recv(socket, nmethods, 5000) do
            {:ok, _methods} ->
              # Send no authentication required
              ThousandIsland.Socket.send(socket, <<5, 0>>)
              :ok

            {:error, _} ->
              :error
          end

        _ ->
          :error
      end
    end

    defp handle_socks5_request(socket) do
      # Read request: [version, cmd, reserved, atyp, dst.addr, dst.port]
      case ThousandIsland.Socket.recv(socket, 4, 5000) do
        {:ok, <<5, cmd, 0, atyp>>} ->
          # Parse destination
          case parse_destination(socket, atyp) do
            {:ok, domain, port} ->
              if check_allowed(domain) do
                # Send success response
                ThousandIsland.Socket.send(socket, <<5, 0, 0, 1, 0, 0, 0, 0, 0, 0>>)

                if cmd == 1 do
                  # CONNECT command
                  forward_connection(socket, domain, port)
                end
              else
                # Send connection refused
                ThousandIsland.Socket.send(socket, <<5, 5, 0, 1, 0, 0, 0, 0, 0, 0>>)
                record_violation(domain, port)
              end

            :error ->
              :error
          end

        _ ->
          :error
      end
    end

    defp parse_destination(socket, atyp) do
      case atyp do
        # IPv4
        1 ->
          with {:ok, <<a, b, c, d>>} <- ThousandIsland.Socket.recv(socket, 4, 5000),
               {:ok, <<port::16>>} <- ThousandIsland.Socket.recv(socket, 2, 5000) do
            {:ok, "#{a}.#{b}.#{c}.#{d}", port}
          end

        # Domain name
        3 ->
          with {:ok, <<len>>} <- ThousandIsland.Socket.recv(socket, 1, 5000),
               {:ok, domain} <- ThousandIsland.Socket.recv(socket, len, 5000),
               {:ok, <<port::16>>} <- ThousandIsland.Socket.recv(socket, 2, 5000) do
            {:ok, to_string(domain), port}
          end

        # IPv6
        4 ->
          with {:ok, _addr} <- ThousandIsland.Socket.recv(socket, 16, 5000),
               {:ok, <<port::16>>} <- ThousandIsland.Socket.recv(socket, 2, 5000) do
            {:ok, "ipv6", port}
          end

        _ ->
          :error
      end
    end

    defp check_allowed(domain) do
      config = SandboxRuntime.ConfigServer.get_config()
      DomainFilter.check(domain, config) == :allow
    end

    defp forward_connection(socket, domain, port) do
      # Simple forwarding (for demonstration)
      # In production, use proper connection pooling
      case :gen_tcp.connect(String.to_charlist(domain), port, [:binary, active: false]) do
        {:ok, target_socket} ->
          # Bidirectional forwarding
          spawn(fn -> forward_loop(socket, target_socket) end)
          forward_loop(target_socket, socket)
          :gen_tcp.close(target_socket)

        {:error, _reason} ->
          :error
      end
    end

    defp forward_loop(from, to) do
      case ThousandIsland.Socket.recv(from, 0, 30000) do
        {:ok, data} ->
          case :gen_tcp.send(to, data) do
            :ok -> forward_loop(from, to)
            {:error, _} -> :ok
          end

        {:error, _} ->
          :ok
      end
    end

    defp record_violation(domain, port) do
      SandboxRuntime.ViolationStore.add_violation(%{
        type: :network,
        operation: "SOCKS5",
        target: "#{domain}:#{port}",
        process: "socks_proxy",
        metadata: %{proxy: :socks}
      })
    end
  end
end
