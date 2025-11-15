import Config

# Configure Ash Domains
config :kairos,
  ash_domains: [
    Kairos.Accounts,
    Kairos.Merits,
    Kairos.Interactions,
    Kairos.Moderation
  ]

# Configure Ecto Repo
config :kairos,
  ecto_repos: [Kairos.Repo]

# Configures the endpoint
config :kairos, KairosWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KairosWeb.ErrorHTML, json: KairosWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kairos.PubSub,
  live_view: [signing_salt: "kairos_secret"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  kairos: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  kairos: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash configuration
config :ash, :use_all_identities_in_upserts?, false
config :ash, :utc_datetime_type, :datetime

# Import environment specific config
import_config "#{config_env()}.exs"
