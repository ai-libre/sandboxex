defmodule SandboxRuntime.Platform.NetworkBridge do
  @moduledoc """
  Creates network bridges for Linux sandboxing using socat.

  Bridges Unix domain sockets into network namespaces for
  proxy communication.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    config = SandboxRuntime.ConfigServer.get_network_config()
    http_port = Map.get(config, :http_proxy_port, 8888)
    socks_port = Map.get(config, :socks_proxy_port, 1080)

    state = %{
      http_bridge: nil,
      socks_bridge: nil,
      http_socket: nil,
      socks_socket: nil
    }

    {:ok, state, {:continue, {:start_bridges, http_port, socks_port}}}
  end

  @impl true
  def handle_continue({:start_bridges, http_port, socks_port}, state) do
    # Create Unix socket paths
    temp_dir = Path.join(System.tmp_dir!(), "sandbox_runtime")
    File.mkdir_p!(temp_dir)

    http_socket = Path.join(temp_dir, "http-#{http_port}.sock")
    socks_socket = Path.join(temp_dir, "socks-#{socks_port}.sock")

    # Clean up old sockets
    File.rm(http_socket)
    File.rm(socks_socket)

    # Start socat bridges
    http_bridge = start_socat_bridge(http_socket, "localhost:#{http_port}")
    socks_bridge = start_socat_bridge(socks_socket, "localhost:#{socks_port}")

    new_state = %{
      state
      | http_bridge: http_bridge,
        socks_bridge: socks_bridge,
        http_socket: http_socket,
        socks_socket: socks_socket
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, state) do
    Logger.warning("Socat bridge exited with status #{status}")

    # Determine which bridge died and restart it
    new_state =
      cond do
        port == state.http_bridge ->
          new_bridge = restart_bridge(:http, state)
          %{state | http_bridge: new_bridge}

        port == state.socks_bridge ->
          new_bridge = restart_bridge(:socks, state)
          %{state | socks_bridge: new_bridge}

        true ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up
    if state.http_bridge, do: Port.close(state.http_bridge)
    if state.socks_bridge, do: Port.close(state.socks_bridge)
    if state.http_socket, do: File.rm(state.http_socket)
    if state.socks_socket, do: File.rm(state.socks_socket)

    :ok
  end

  # Private Helpers

  defp start_socat_bridge(socket_path, target) do
    case System.find_executable("socat") do
      nil ->
        Logger.error("socat not found, network bridging will not work")
        nil

      socat_path ->
        Port.open({:spawn_executable, socat_path}, [
          :binary,
          :exit_status,
          args: [
            "UNIX-LISTEN:#{socket_path},fork",
            "TCP:#{target}"
          ]
        ])
    end
  end

  defp restart_bridge(:http, state) do
    config = SandboxRuntime.ConfigServer.get_network_config()
    http_port = Map.get(config, :http_proxy_port, 8888)
    start_socat_bridge(state.http_socket, "localhost:#{http_port}")
  end

  defp restart_bridge(:socks, state) do
    config = SandboxRuntime.ConfigServer.get_network_config()
    socks_port = Map.get(config, :socks_proxy_port, 1080)
    start_socat_bridge(state.socks_socket, "localhost:#{socks_port}")
  end
end
