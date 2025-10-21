defmodule SandboxRuntime.ViolationStore do
  @moduledoc """
  In-memory storage for sandbox violations using ETS.

  Provides fast concurrent access to violation records for debugging
  and monitoring purposes.
  """

  use GenServer
  require Logger

  @type violation :: %{
          timestamp: integer(),
          type: atom(),
          operation: String.t(),
          target: String.t(),
          process: String.t() | nil,
          metadata: map()
        }

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Adds a violation to the store.
  """
  @spec add_violation(violation()) :: :ok
  def add_violation(violation) do
    timestamp = System.monotonic_time(:millisecond)
    full_violation = Map.put(violation, :timestamp, timestamp)

    :ets.insert(:sandbox_violations, {timestamp, full_violation})

    :telemetry.execute(
      [:sandbox_runtime, :violation, :added],
      %{count: 1},
      full_violation
    )

    :ok
  end

  @doc """
  Returns all violations.
  """
  @spec get_violations() :: [violation()]
  def get_violations do
    :ets.tab2list(:sandbox_violations)
    |> Enum.map(fn {_ts, violation} -> violation end)
    |> Enum.sort_by(& &1.timestamp, :desc)
  end

  @doc """
  Returns violations filtered by type.
  """
  @spec get_violations_by_type(atom()) :: [violation()]
  def get_violations_by_type(type) do
    get_violations()
    |> Enum.filter(&(&1.type == type))
  end

  @doc """
  Clears all violations.
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Returns the count of violations.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(:sandbox_violations, :size)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table =
      :ets.new(:sandbox_violations, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(:sandbox_violations)
    {:reply, :ok, state}
  end
end
