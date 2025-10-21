defmodule SandboxRuntime.Platform.ViolationMonitor do
  @moduledoc """
  Monitors sandbox violations on macOS using log stream.

  Listens to macOS system logs for sandbox-exec violations
  and records them in the ViolationStore.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Start log stream monitoring as a Port
    port = start_log_stream()

    {:ok, %{port: port, buffer: ""}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Parse log output for violations
    new_buffer = state.buffer <> data

    {violations, remaining_buffer} = parse_log_data(new_buffer)

    # Record violations
    Enum.each(violations, &SandboxRuntime.ViolationStore.add_violation/1)

    {:noreply, %{state | buffer: remaining_buffer}}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.warning("Log stream exited with status #{status}, restarting...")
    new_port = start_log_stream()
    {:noreply, %{state | port: new_port, buffer: ""}}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port do
      Port.close(state.port)
    end

    :ok
  end

  # Private Helpers

  defp start_log_stream do
    Port.open({:spawn_executable, "/usr/bin/log"}, [
      :binary,
      :exit_status,
      args: [
        "stream",
        "--predicate",
        "process == 'sandbox-exec' OR processImagePath CONTAINS 'sandbox-exec'",
        "--style",
        "syslog"
      ]
    ])
  end

  defp parse_log_data(data) do
    lines = String.split(data, "\n")

    # Keep last incomplete line in buffer
    {complete_lines, [incomplete]} =
      if String.ends_with?(data, "\n") do
        {lines, [""]}
      else
        Enum.split(lines, -1)
      end

    violations =
      complete_lines
      |> Enum.filter(&violation_line?/1)
      |> Enum.map(&parse_violation/1)
      |> Enum.reject(&is_nil/1)

    {violations, incomplete}
  end

  defp violation_line?(line) do
    String.contains?(line, "deny") or
      String.contains?(line, "Deny")
  end

  defp parse_violation(line) do
    # Parse violation from log line
    # Example: "deny file-read* /Users/me/.ssh/id_rsa"
    case Regex.run(~r/deny\s+([\w-]+)\*?\s+(.+)/, line, capture: :all_but_first) do
      [operation, target] ->
        %{
          type: :filesystem,
          operation: operation,
          target: String.trim(target),
          process: "sandbox-exec",
          metadata: %{
            raw_log: line,
            platform: :macos
          }
        }

      nil ->
        # Try network pattern
        case Regex.run(~r/deny\s+network\*?\s+(.+)/, line, capture: :all_but_first) do
          [target] ->
            %{
              type: :network,
              operation: "network",
              target: String.trim(target),
              process: "sandbox-exec",
              metadata: %{
                raw_log: line,
                platform: :macos
              }
            }

          nil ->
            nil
        end
    end
  end
end
