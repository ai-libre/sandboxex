import Config

if config_env() == :prod do
  config :sandbox_runtime,
    settings_path: System.get_env("SANDBOX_SETTINGS_PATH"),
    enable_telemetry: true
end
