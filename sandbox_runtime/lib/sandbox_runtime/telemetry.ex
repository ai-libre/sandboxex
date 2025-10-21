defmodule SandboxRuntime.Telemetry do
  @moduledoc """
  Telemetry event handlers for SandboxRuntime.

  Emits events at key lifecycle points for observability.
  """

  require Logger

  @doc """
  Handles telemetry events.

  ## Events

  - `[:sandbox_runtime, :config, :loaded]` - Configuration loaded
  - `[:sandbox_runtime, :proxy, :started]` - Proxy server started
  - `[:sandbox_runtime, :proxy, :stopped]` - Proxy server stopped
  - `[:sandbox_runtime, :violation, :added]` - Sandbox violation detected
  - `[:sandbox_runtime, :command, :wrapped]` - Command wrapped with sandbox
  """
  def handle_event([:sandbox_runtime, :config, :loaded], measurements, metadata, _config) do
    Logger.info("Config loaded in #{measurements[:duration]}ms",
      source: metadata[:source],
      path: metadata[:path]
    )
  end

  def handle_event([:sandbox_runtime, :proxy, :started], _measurements, metadata, _config) do
    Logger.info("Proxy started",
      type: metadata[:type],
      port: metadata[:port]
    )
  end

  def handle_event([:sandbox_runtime, :proxy, :stopped], _measurements, metadata, _config) do
    Logger.info("Proxy stopped",
      type: metadata[:type],
      port: metadata[:port]
    )
  end

  def handle_event([:sandbox_runtime, :violation, :added], measurements, metadata, _config) do
    Logger.warning("Sandbox violation detected",
      count: measurements[:count],
      type: metadata[:type],
      operation: metadata[:operation],
      target: metadata[:target]
    )
  end

  def handle_event([:sandbox_runtime, :command, :wrapped], measurements, metadata, _config) do
    Logger.debug("Command wrapped with sandbox in #{measurements[:duration]}ms",
      platform: metadata[:platform],
      command: String.slice(metadata[:command] || "", 0..100)
    )
  end
end
