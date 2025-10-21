defmodule SandboxRuntime.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Attach telemetry handlers if enabled
    if Application.get_env(:sandbox_runtime, :enable_telemetry, true) do
      attach_telemetry_handlers()
    end

    children = base_children() ++ platform_children()

    opts = [strategy: :one_for_one, name: SandboxRuntime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp base_children do
    [
      SandboxRuntime.ConfigServer,
      SandboxRuntime.ViolationStore,
      {DynamicSupervisor, name: SandboxRuntime.ProxySupervisor, strategy: :one_for_one}
    ]
  end

  defp platform_children do
    case SandboxRuntime.Platform.Detector.detect() do
      :macos ->
        if Application.get_env(:sandbox_runtime, :enable_violation_monitor, true) do
          [SandboxRuntime.Platform.ViolationMonitor]
        else
          []
        end

      :linux ->
        []

      _ ->
        Logger.warning("Unsupported platform for sandboxing")
        []
    end
  end

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "sandbox-runtime-telemetry",
      [
        [:sandbox_runtime, :config, :loaded],
        [:sandbox_runtime, :proxy, :started],
        [:sandbox_runtime, :proxy, :stopped],
        [:sandbox_runtime, :violation, :added],
        [:sandbox_runtime, :command, :wrapped]
      ],
      &SandboxRuntime.Telemetry.handle_event/4,
      nil
    )
  end
end
