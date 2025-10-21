defmodule SandboxRuntime.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ai-libre/sandbox_runtime"

  def project do
    [
      app: :sandbox_runtime,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl],
      mod: {SandboxRuntime.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.3"},
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.6"},
      {:thousand_island, "~> 1.3"},
      {:req, "~> 0.5"},

      # Development & Testing
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end

  defp description do
    "OS-level sandboxing for Elixir applications using native OS primitives (macOS Seatbelt, Linux bubblewrap)"
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "SandboxRuntime",
      source_url: @source_url,
      extras: ["README.md"],
      groups_for_modules: [
        "Core": [
          SandboxRuntime,
          SandboxRuntime.Manager,
          SandboxRuntime.Application
        ],
        "Configuration": [
          SandboxRuntime.Config,
          SandboxRuntime.Config.Loader,
          SandboxRuntime.Config.Schema,
          SandboxRuntime.Config.Parser,
          SandboxRuntime.ConfigServer
        ],
        "Proxies": [
          SandboxRuntime.Proxy.HttpProxy,
          SandboxRuntime.Proxy.SocksProxy,
          SandboxRuntime.Proxy.DomainFilter
        ],
        "Platform Support": [
          SandboxRuntime.Platform.Detector,
          SandboxRuntime.Platform.MacOS,
          SandboxRuntime.Platform.Linux,
          SandboxRuntime.Platform.ViolationMonitor,
          SandboxRuntime.Platform.NetworkBridge
        ],
        "Utilities": [
          SandboxRuntime.Utils.Path,
          SandboxRuntime.Utils.Glob,
          SandboxRuntime.Utils.DangerousFiles,
          SandboxRuntime.Utils.CommandBuilder
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end
end
