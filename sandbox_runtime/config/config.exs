import Config

# Configure SandboxRuntime defaults
config :sandbox_runtime,
  sandbox: %{
    enabled: true,
    network: %{
      allow_unix_sockets: [],
      allow_local_binding: false,
      http_proxy_port: 8888,
      socks_proxy_port: 1080
    }
  },
  permissions: %{
    allow: [],
    deny: []
  },
  settings_path: nil,
  enable_telemetry: true,
  enable_violation_monitor: true

# Import environment specific config
import_config "#{config_env()}.exs"
