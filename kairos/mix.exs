defmodule Kairos.MixProject do
  use Mix.Project

  def project do
    [
      app: :kairos,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Kairos.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:finch, "~> 0.18"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.24"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # Ash Framework 3.0
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},

      # Reactor (workflow orchestration)
      {:reactor, "~> 0.9"},

      # AI/ML
      {:nx, "~> 0.7"},
      {:exla, "~> 0.7"},
      {:bumblebee, "~> 0.5"},

      # Background jobs
      {:oban, "~> 2.17"},

      # Dev/Test
      {:floki, ">= 0.36.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ash_postgres.create", "ash_postgres.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ash_postgres.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind kairos", "esbuild kairos"],
      "assets.deploy": [
        "tailwind kairos --minify",
        "esbuild kairos --minify",
        "phx.digest"
      ],

      # Ash aliases
      "ash.setup": ["ash_postgres.create", "ash_postgres.migrate"],
      "ash.migrate": ["ash_postgres.generate_migrations", "ash_postgres.migrate"],
      "ash.reset": ["ash_postgres.drop", "ash.migrate"]
    ]
  end
end
