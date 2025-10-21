defmodule Mix.Tasks.Sandbox do
  @moduledoc """
  Executes a command in a sandbox.

  ## Usage

      mix sandbox <command>
      mix sandbox --debug <command>

  ## Examples

      mix sandbox "curl anthropic.com"
      mix sandbox "npm install"
      mix sandbox --debug "cat ~/.ssh/id_rsa"

  ## Options

    * `--debug` - Enable debug logging
  """

  use Mix.Task

  @shortdoc "Execute a command in a sandbox"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Application.ensure_all_started(:sandbox_runtime)

    {opts, command_parts, _} =
      OptionParser.parse(args,
        strict: [debug: :boolean],
        aliases: [d: :debug]
      )

    if Enum.empty?(command_parts) do
      Mix.shell().error("Usage: mix sandbox [--debug] <command>")
      exit({:shutdown, 1})
    end

    command = Enum.join(command_parts, " ")

    if opts[:debug] do
      Logger.configure(level: :debug)
      Mix.shell().info("Debug mode enabled")
    end

    # Initialize sandbox
    case SandboxRuntime.initialize() do
      :ok ->
        Mix.shell().info("Sandbox initialized")

      {:error, reason} ->
        Mix.shell().error("Failed to initialize sandbox: #{inspect(reason)}")
        exit({:shutdown, 1})
    end

    # Execute command
    Mix.shell().info("Executing: #{command}")

    case SandboxRuntime.execute_sandboxed(command) do
      {:ok, output} ->
        Mix.shell().info(output)
        check_violations()
        :ok

      {:error, {:exit_code, code, output}} ->
        Mix.shell().error("Command failed with exit code #{code}")
        Mix.shell().error(output)
        check_violations()
        exit({:shutdown, code})

      {:error, reason} ->
        Mix.shell().error("Sandbox error: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp check_violations do
    violations = SandboxRuntime.get_violations()

    unless Enum.empty?(violations) do
      Mix.shell().info("\n=== Sandbox Violations (#{length(violations)}) ===")

      Enum.each(violations, fn v ->
        Mix.shell().error("""
        [#{v.type}] #{v.operation} - #{v.target}
          Process: #{v.process}
          Time: #{format_timestamp(v.timestamp)}
        """)
      end)
    end
  end

  defp format_timestamp(ts) do
    DateTime.from_unix!(ts, :millisecond)
    |> DateTime.to_string()
  end
end
