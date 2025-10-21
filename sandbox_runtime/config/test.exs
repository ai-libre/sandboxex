import Config

config :sandbox_runtime,
  sandbox: %{
    enabled: true,
    network: %{
      allow_unix_sockets: [],
      allow_local_binding: false,
      http_proxy_port: 18888,
      socks_proxy_port: 11080
    }
  },
  enable_telemetry: false,
  enable_violation_monitor: false

config :logger, level: :warning
