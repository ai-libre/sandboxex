defmodule SandboxRuntime.Platform.Linux do
  @moduledoc """
  Linux-specific sandboxing using bubblewrap.

  Generates bubblewrap commands with namespace isolation.
  """

  require Logger

  alias SandboxRuntime.Utils.{Path, CommandBuilder}

  @doc """
  Generates a bubblewrap command for sandboxing.

  Returns a complete command string ready to execute.
  """
  @spec generate_command(String.t(), map()) :: String.t()
  def generate_command(command, config) do
    fs_read = Map.get(config, :fs_read, %{deny_only: []})
    fs_write = Map.get(config, :fs_write, %{allow_only: [], deny_within_allow: []})
    network = get_in(config, [:sandbox, :network]) || %{}

    base_args = [
      "bwrap",
      # Namespace isolation
      "--unshare-all",
      "--die-with-parent",
      # Basic filesystem
      "--ro-bind", "/", "/",
      "--dev", "/dev",
      "--proc", "/proc",
      "--tmpfs", "/tmp",
      "--tmpfs", "/var/tmp"
    ]

    write_binds = generate_write_binds(fs_write)
    read_overlays = generate_read_overlays(fs_read)
    network_setup = generate_network_setup(network)
    env_vars = generate_env_vars(network)

    all_args =
      base_args ++
        write_binds ++
        read_overlays ++
        network_setup ++
        env_vars ++
        ["--", "sh", "-c", command]

    Enum.join(all_args, " ")
  end

  # Private Helpers

  defp generate_write_binds(fs_write) do
    allow_only = Map.get(fs_write, :allow_only, [])

    Enum.flat_map(allow_only, fn path ->
      normalized = Path.normalize(path)

      if File.exists?(normalized) do
        ["--bind", normalized, normalized]
      else
        Logger.warning("Write path does not exist: #{normalized}")
        []
      end
    end)
  end

  defp generate_read_overlays(fs_read) do
    deny_only = Map.get(fs_read, :deny_only, [])

    Enum.flat_map(deny_only, fn path ->
      normalized = Path.normalize(path)
      # Overlay with tmpfs to make it inaccessible
      ["--tmpfs", normalized]
    end)
  end

  defp generate_network_setup(network) do
    http_port = Map.get(network, :http_proxy_port, 8888)
    socks_port = Map.get(network, :socks_proxy_port, 1080)

    # Create socket paths for bridges
    http_socket = create_bridge_socket("http", http_port)
    socks_socket = create_bridge_socket("socks", socks_port)

    if http_socket && socks_socket do
      [
        # Share network namespace for proxy access
        "--share-net",
        # Bind mount Unix sockets
        "--ro-bind", http_socket, "/tmp/http-proxy.sock",
        "--ro-bind", socks_socket, "/tmp/socks-proxy.sock"
      ]
    else
      # Fallback: full network access
      ["--share-net"]
    end
  end

  defp generate_env_vars(network) do
    http_port = Map.get(network, :http_proxy_port, 8888)
    socks_port = Map.get(network, :socks_proxy_port, 1080)

    [
      "--setenv", "HTTP_PROXY", "http://localhost:#{http_port}",
      "--setenv", "HTTPS_PROXY", "http://localhost:#{http_port}",
      "--setenv", "ALL_PROXY", "socks5://localhost:#{socks_port}"
    ]
  end

  defp create_bridge_socket(type, port) do
    # This would be created by NetworkBridge process
    temp_dir = Path.join(System.tmp_dir!(), "sandbox_runtime")
    File.mkdir_p!(temp_dir)

    socket_path = Path.join(temp_dir, "#{type}-#{port}.sock")

    # For now, just return the path
    # The NetworkBridge GenServer will create the actual socket
    socket_path
  end
end
