defmodule SandboxRuntime.ConfigServer do
  @moduledoc """
  GenServer that manages sandbox configuration state.

  Loads configuration from multiple sources and provides
  fast access to config values.
  """

  use GenServer
  require Logger

  @type config :: map()

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets the current configuration.
  """
  @spec get_config() :: config()
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Gets the network configuration.
  """
  @spec get_network_config() :: map()
  def get_network_config do
    GenServer.call(__MODULE__, :get_network_config)
  end

  @doc """
  Gets filesystem read restrictions.
  """
  @spec get_fs_read_config() :: map()
  def get_fs_read_config do
    GenServer.call(__MODULE__, :get_fs_read_config)
  end

  @doc """
  Gets filesystem write restrictions.
  """
  @spec get_fs_write_config() :: map()
  def get_fs_write_config do
    GenServer.call(__MODULE__, :get_fs_write_config)
  end

  @doc """
  Updates the configuration.
  """
  @spec update_config(map()) :: :ok
  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end

  @doc """
  Reloads configuration from files.
  """
  @spec reload() :: :ok | {:error, term()}
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{config: nil}, {:continue, :load_config}}
  end

  @impl true
  def handle_continue(:load_config, state) do
    start_time = System.monotonic_time(:millisecond)

    config =
      case SandboxRuntime.Config.Loader.load_hierarchical() do
        {:ok, loaded_config} ->
          loaded_config

        {:error, reason} ->
          Logger.warning("Failed to load config: #{inspect(reason)}, using defaults")
          SandboxRuntime.Config.Loader.default_config()
      end

    duration = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute(
      [:sandbox_runtime, :config, :loaded],
      %{duration: duration},
      %{source: :hierarchical}
    )

    {:noreply, %{state | config: config}}
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_call(:get_network_config, _from, state) do
    network_config = get_in(state.config, [:sandbox, :network]) || %{}
    {:reply, network_config, state}
  end

  @impl true
  def handle_call(:get_fs_read_config, _from, state) do
    fs_read = get_in(state.config, [:fs_read]) || %{deny_only: []}
    {:reply, fs_read, state}
  end

  @impl true
  def handle_call(:get_fs_write_config, _from, state) do
    fs_write = get_in(state.config, [:fs_write]) || %{allow_only: [], deny_within_allow: []}
    {:reply, fs_write, state}
  end

  @impl true
  def handle_call({:update_config, new_config}, _from, state) do
    merged_config = deep_merge(state.config, new_config)
    {:reply, :ok, %{state | config: merged_config}}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    case SandboxRuntime.Config.Loader.load_hierarchical() do
      {:ok, config} ->
        {:reply, :ok, %{state | config: config}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Helpers

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      deep_merge(left_val, right_val)
    end)
  end

  defp deep_merge(_left, right), do: right
end
