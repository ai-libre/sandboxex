defmodule SandboxRuntime.Manager do
  @moduledoc """
  Main manager for sandbox operations.

  Orchestrates sandbox command generation, proxy lifecycle,
  and platform-specific implementations.
  """

  use GenServer
  require Logger

  alias SandboxRuntime.Platform.Detector
  alias SandboxRuntime.ConfigServer

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Wraps a command with sandboxing based on platform.

  Returns a command string that can be executed.
  """
  @spec wrap_with_sandbox(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def wrap_with_sandbox(command, opts \\ []) do
    GenServer.call(__MODULE__, {:wrap_with_sandbox, command, opts}, 30_000)
  end

  @doc """
  Checks if sandboxing is enabled and supported on this platform.
  """
  @spec sandboxing_enabled?() :: boolean()
  def sandboxing_enabled? do
    GenServer.call(__MODULE__, :sandboxing_enabled?)
  end

  @doc """
  Initializes sandbox infrastructure (starts proxies).
  """
  @spec initialize(keyword()) :: :ok | {:error, term()}
  def initialize(opts \\ []) do
    GenServer.call(__MODULE__, {:initialize, opts}, 30_000)
  end

  @doc """
  Resets sandbox state (stops proxies, clears violations).
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      platform: Detector.detect(),
      initialized: false,
      proxies_started: false,
      opts: opts
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:wrap_with_sandbox, command, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result =
      case state.platform do
        :macos ->
          wrap_macos(command, opts, state)

        :linux ->
          wrap_linux(command, opts, state)

        platform ->
          {:error, {:unsupported_platform, platform}}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, wrapped_cmd} ->
        :telemetry.execute(
          [:sandbox_runtime, :command, :wrapped],
          %{duration: duration},
          %{platform: state.platform, command: command}
        )

        {:reply, {:ok, wrapped_cmd}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:sandboxing_enabled?, _from, state) do
    enabled =
      case state.platform do
        platform when platform in [:macos, :linux] ->
          check_platform_dependencies(platform)

        _ ->
          false
      end

    {:reply, enabled, state}
  end

  @impl true
  def handle_call({:initialize, _opts}, _from, state) do
    case start_proxies(state) do
      {:ok, new_state} ->
        {:reply, :ok, %{new_state | initialized: true}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:reset, _from, state) do
    stop_proxies()
    SandboxRuntime.ViolationStore.clear()
    {:reply, :ok, %{state | proxies_started: false}}
  end

  # Private Helpers

  defp wrap_macos(command, opts, _state) do
    config = get_effective_config(opts)

    case SandboxRuntime.Platform.MacOS.generate_profile(config) do
      {:ok, profile} ->
        wrapped = SandboxRuntime.Platform.MacOS.wrap_command(command, profile)
        {:ok, wrapped}

      error ->
        error
    end
  end

  defp wrap_linux(command, opts, _state) do
    config = get_effective_config(opts)
    wrapped = SandboxRuntime.Platform.Linux.generate_command(command, config)
    {:ok, wrapped}
  end

  defp get_effective_config(opts) do
    base_config = ConfigServer.get_config()

    # Merge with inline options if provided
    case Keyword.get(opts, :config) do
      nil -> base_config
      inline_config -> deep_merge(base_config, inline_config)
    end
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      deep_merge(left_val, right_val)
    end)
  end

  defp deep_merge(_left, right), do: right

  defp start_proxies(state) do
    if state.proxies_started do
      {:ok, state}
    else
      network_config = ConfigServer.get_network_config()
      http_port = Map.get(network_config, :http_proxy_port, 8888)
      socks_port = Map.get(network_config, :socks_proxy_port, 1080)

      with {:ok, _http_pid} <-
             DynamicSupervisor.start_child(
               SandboxRuntime.ProxySupervisor,
               {SandboxRuntime.Proxy.HttpProxy, port: http_port}
             ),
           {:ok, _socks_pid} <-
             DynamicSupervisor.start_child(
               SandboxRuntime.ProxySupervisor,
               {SandboxRuntime.Proxy.SocksProxy, port: socks_port}
             ) do
        {:ok, %{state | proxies_started: true}}
      else
        {:error, reason} ->
          Logger.error("Failed to start proxies: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp stop_proxies do
    SandboxRuntime.ProxySupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(SandboxRuntime.ProxySupervisor, pid)
    end)
  end

  defp check_platform_dependencies(:macos) do
    case System.find_executable("sandbox-exec") do
      nil -> false
      _ -> true
    end
  end

  defp check_platform_dependencies(:linux) do
    case System.find_executable("bwrap") do
      nil -> false
      _ -> true
    end
  end
end
