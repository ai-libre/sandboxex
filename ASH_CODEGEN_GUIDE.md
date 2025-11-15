# Guía de Generación de Código con Ash (`mix ash.codegen`)

**Referencias:** Ash Framework 3.0 Hexdocs + Pensamiento José Valim/Zach Daniel

---

## 📚 Referencias Fundamentales (Hexdocs)

### Core Ash Documentation

1. **Ash.Resource** - https://hexdocs.pm/ash/Ash.Resource.html
   - Declaración de resources (attributes, relationships, actions)
   - DSL completo documentado
   - Ejemplos de policies, calculations, aggregates

2. **AshPostgres.DataLayer** - https://hexdocs.pm/ash_postgres/AshPostgres.DataLayer.html
   - PostgreSQL data layer
   - Migraciones automáticas
   - Custom indexes, references, constraints

3. **Ash.Policy.Authorizer** - https://hexdocs.pm/ash/Ash.Policy.Authorizer.html
   - Authorization policies
   - Checks reutilizables
   - Field-level access control

4. **Reactor** - https://hexdocs.pm/reactor/Reactor.html
   - Workflow orchestration
   - Steps, compensations, async execution
   - DAG (Directed Acyclic Graph) patterns

5. **AshPhoenix** - https://hexdocs.pm/ash_phoenix/AshPhoenix.html
   - Phoenix integration
   - LiveView forms (`AshPhoenix.Form`)
   - Subscriptions para real-time

6. **AshAuthentication** - https://hexdocs.pm/ash_authentication/AshAuthentication.html
   - Estrategias de auth (password, OAuth, tokens)
   - User impersonation
   - Confirmations, password reset

---

## 🛠️ `mix ash.codegen` - Generación Automática

### ¿Qué es `ash.codegen`?

Ash incluye tasks de Mix para **generar código automáticamente** desde resources:
- Migraciones de DB
- GraphQL schemas
- JSON:API endpoints
- LiveView forms

**Filosofía (Zach Daniel):**
> "Define tu resource una vez, genera todo lo demás automáticamente."

---

## 📋 Setup Inicial del Proyecto KAIROS

### 1. Crear nuevo proyecto Phoenix con Ash

```bash
# Crear proyecto Phoenix
mix phx.new kairos --database postgres --live

cd kairos

# Agregar Ash dependencies
```

**mix.exs:**

```elixir
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

      # Ash Framework
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
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:floki, ">= 0.36.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind kairos", "esbuild kairos"],
      "assets.deploy": [
        "tailwind kairos --minify",
        "esbuild kairos --minify",
        "phx.digest"
      ],

      # Ash aliases
      "ash.setup": ["ash.codegen --name initial"],
      "ash.migrate": ["ash_postgres.generate_migrations", "ash_postgres.migrate"],
      "ash.reset": ["ash_postgres.drop", "ash.migrate"]
    ]
  end
end
```

### 2. Configurar Ash Domains

**lib/kairos/accounts.ex** (Domain):

```elixir
defmodule Kairos.Accounts do
  use Ash.Domain

  resources do
    resource Kairos.Accounts.User do
      # Define actions disponibles via domain
      define :create_user, action: :register
      define :verify_user, action: :verify_behavior
      define :get_user_by_id, action: :read, get_by: [:id]
      define :get_user_by_email, action: :read, get_by: [:email]
    end

    resource Kairos.Accounts.Token
  end
end
```

**lib/kairos/merits.ex**:

```elixir
defmodule Kairos.Merits do
  use Ash.Domain

  resources do
    resource Kairos.Merits.Profile do
      define :create_profile, action: :create
      define :update_scores, action: :recalculate_scores
      define :award_badge, action: :award_badge
    end
  end
end
```

**lib/kairos/interactions.ex**:

```elixir
defmodule Kairos.Interactions do
  use Ash.Domain

  resources do
    resource Kairos.Interactions.Post do
      define :create_post, action: :create
      define :high_quality_feed, action: :high_quality_feed
      define :user_posts, action: :for_user
    end

    resource Kairos.Interactions.Conversation do
      define :start_conversation, action: :start
      define :get_conversation, action: :read, get_by: [:id]
    end

    resource Kairos.Interactions.Message
  end
end
```

### 3. Configurar AshPostgres Repo

**lib/kairos/repo.ex**:

```elixir
defmodule Kairos.Repo do
  use AshPostgres.Repo, otp_app: :kairos

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext"]
  end
end
```

**config/config.exs**:

```elixir
import Config

config :kairos,
  ash_domains: [
    Kairos.Accounts,
    Kairos.Merits,
    Kairos.Interactions,
    Kairos.Moderation
  ]

config :kairos, Kairos.Repo,
  database: "kairos_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :kairos,
  ecto_repos: [Kairos.Repo]

# Ash PostgreSQL
config :ash, :use_all_identities_in_upserts?, false

import_config "#{config_env()}.exs"
```

---

## 🚀 Generación de Código con `mix ash.codegen`

### Workflow de Desarrollo

#### 1. Crear Resource

**lib/kairos/accounts/user.ex**:

```elixir
defmodule Kairos.Accounts.User do
  use Ash.Resource,
    domain: Kairos.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  @moduledoc """
  User resource con verificación conductual.
  """

  postgres do
    table "users"
    repo Kairos.Repo

    references do
      reference :merit_profile, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :username, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :email, :ci_string do
      allow_nil? false
      public? true  # Visible en read sin auth
    end

    attribute :hashed_password, :string, sensitive?: true

    # Behavioral verification
    attribute :behavioral_hash, :string
    attribute :verification_status, :atom, default: :pending
    attribute :verification_score, :float, default: 0.0

    timestamps()
  end

  relationships do
    has_one :merit_profile, Kairos.Merits.Profile do
      destination_attribute :user_id
    end

    has_many :posts, Kairos.Interactions.Post
  end

  calculations do
    calculate :is_verified, :boolean, expr(verification_status == :verified)
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:username, :email, :hashed_password]
    end

    update :verify_behavior do
      accept [:verification_score, :verification_status, :behavioral_hash]
      argument :analysis_data, :map, allow_nil?: false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end
  end

  identities do
    identity :unique_username, [:username]
    identity :unique_email, [:email]
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end
    end
  end
end
```

#### 2. Generar Migración Inicial

```bash
# Genera migración desde resource definitions
mix ash_postgres.generate_migrations --name create_users

# Output:
# * creating priv/repo/migrations/20251115120000_create_users.exs
```

**Resultado (priv/repo/migrations/xxx_create_users.exs)**:

```elixir
defmodule Kairos.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def up do
    create table(:users, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :username, :text, null: false
      add :email, :citext, null: false
      add :hashed_password, :text, null: false
      add :behavioral_hash, :text
      add :verification_status, :text, default: "pending"
      add :verification_score, :float, default: 0.0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
    create index(:users, [:verification_status])
  end

  def down do
    drop table(:users)
  end
end
```

#### 3. Ejecutar Migración

```bash
# Run pending migrations
mix ash_postgres.migrate

# Output:
# Compiling 1 file (.ex)
# Generated kairos app
#
# 12:00:00.000 [info] == Running 20251115120000 Kairos.Repo.Migrations.CreateUsers.up/0 forward
# 12:00:00.001 [info] create table users
# 12:00:00.050 [info] create index users_username_index
# 12:00:00.051 [info] create index users_email_index
# 12:00:00.052 [info] == Migrated 20251115120000 in 0.0s
```

#### 4. Agregar Campos Nuevos

**Modificar resource:**

```elixir
defmodule Kairos.Accounts.User do
  # ... (resto igual)

  attributes do
    # ... (atributos existentes)

    # NUEVO campo
    attribute :ai_profile_summary, :string do
      allow_nil? true
    end
  end
end
```

**Generar migración incremental:**

```bash
mix ash_postgres.generate_migrations --name add_ai_profile_summary

# Output:
# * creating priv/repo/migrations/20251115120100_add_ai_profile_summary.exs
```

**Resultado:**

```elixir
defmodule Kairos.Repo.Migrations.AddAiProfileSummary do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :ai_profile_summary, :text
    end
  end

  def down do
    alter table(:users) do
      remove :ai_profile_summary
    end
  end
end
```

---

## 🧪 Desarrollo con Resources

### Workflow Completo

```bash
# 1. Crear resource file
touch lib/kairos/interactions/post.ex

# 2. Definir resource (ver KAIROS_ARCHITECTURE.md)

# 3. Agregar al domain
# Editar lib/kairos/interactions.ex

# 4. Generar migración
mix ash_postgres.generate_migrations --name create_posts

# 5. Revisar migración generada
cat priv/repo/migrations/*_create_posts.exs

# 6. Ejecutar migración
mix ash_postgres.migrate

# 7. Test en IEx
iex -S mix

# Crear post
Ash.create!(Kairos.Interactions.Post, %{
  content: "Mi primer post en KAIROS",
  content_type: :text
}, actor: user)

# Read high quality feed
Ash.read!(Kairos.Interactions.Post, action: :high_quality_feed)
```

---

## 📖 Referencia: Mix Tasks de Ash

### ash_postgres.generate_migrations

```bash
# Generar migración desde resources
mix ash_postgres.generate_migrations [options]

# Options:
#   --name NAME              # Nombre de la migración (required)
#   --dry-run                # Preview sin crear archivo
#   --check                  # Verifica si hay migraciones pendientes (CI)
#   --drop-columns           # Permite drop de columnas (default: false)

# Ejemplos:
mix ash_postgres.generate_migrations --name create_users
mix ash_postgres.generate_migrations --name add_merit_scores --dry-run
mix ash_postgres.generate_migrations --check  # En CI pipeline
```

### ash_postgres.migrate

```bash
# Ejecutar migraciones pendientes
mix ash_postgres.migrate [options]

# Options:
#   --step N                # Ejecutar N migraciones
#   --to VERSION           # Migrar hasta VERSION específica
#   --all                  # Migrar todo (default)

# Ejemplos:
mix ash_postgres.migrate
mix ash_postgres.migrate --step 1
mix ash_postgres.migrate --to 20251115120000
```

### ash_postgres.rollback

```bash
# Revertir migraciones
mix ash_postgres.rollback [options]

# Options:
#   --step N               # Revertir N migraciones (default: 1)
#   --to VERSION          # Revertir hasta VERSION
#   --all                 # Revertir todo

# Ejemplos:
mix ash_postgres.rollback             # Revert last migration
mix ash_postgres.rollback --step 2    # Revert last 2
mix ash_postgres.rollback --all       # Drop everything (peligroso!)
```

### ash.codegen (general)

```bash
# Generar múltiples artifacts desde resources
mix ash.codegen [options]

# Genera:
# - Migraciones de DB
# - GraphQL schemas (si ash_graphql configurado)
# - JSON:API endpoints (si ash_json_api configurado)

# Options:
#   --name NAME           # Nombre para batch generation
#   --apis DOMAINS        # Especificar domains (default: all)

# Ejemplo:
mix ash.codegen --name initial_setup
```

---

## 🎨 Patrones Avanzados

### Pattern 1: Migrations con Custom SQL

```elixir
defmodule Kairos.Accounts.User do
  postgres do
    table "users"
    repo Kairos.Repo

    custom_indexes do
      # GIN index para búsqueda full-text
      index ["username gin_trgm_ops"], using: "GIN"

      # Partial index para usuarios verificados
      index [:verification_status],
        where: "verification_status = 'verified'"

      # Composite index
      index [:inserted_at, :verification_score]
    end

    custom_statements do
      # Custom SQL al crear tabla
      up "CREATE EXTENSION IF NOT EXISTS pg_trgm"

      # Custom SQL al drop tabla
      down "DROP EXTENSION IF EXISTS pg_trgm"
    end
  end
end
```

### Pattern 2: Polymorphic Relationships

```elixir
defmodule Kairos.Moderation.Violation do
  attributes do
    # Polymorphic: puede referirse a Post, Message, etc
    attribute :content_type, :string
    attribute :content_id, :uuid
  end

  postgres do
    table "violations"

    # No foreign key constraint (polymorphic)
    custom_indexes do
      index [:content_type, :content_id]
    end
  end

  calculations do
    # Load content dinámicamente
    calculate :content, :any, Kairos.Moderation.Calculations.LoadPolymorphicContent
  end
end
```

### Pattern 3: Tenant-specific Migrations

```elixir
defmodule Kairos.Accounts.User do
  multitenancy do
    strategy :attribute
    attribute :network_id
    global? false  # Cada tenant tiene sus propios users
  end

  postgres do
    table "users"

    # Index por tenant
    custom_indexes do
      index [:network_id, :username], unique: true
    end
  end
end

# Migración incluye tenant column automáticamente
```

---

## 🔍 Debugging Migraciones

### Ver SQL Generado

```elixir
# En IEx
iex> Ash.Query.to_sql(query)

# Para un resource específico
iex> Kairos.Accounts.User
...> |> Ash.Query.new()
...> |> Ash.Query.filter(verification_status == :verified)
...> |> Ash.Query.to_sql()

# Output:
"""
SELECT u0."id", u0."username", u0."email", ...
FROM "users" AS u0
WHERE (u0."verification_status" = 'verified')
"""
```

### Dry-run de Migraciones

```bash
# Preview migración sin crear archivo
mix ash_postgres.generate_migrations --name test --dry-run

# Output:
# Would create migration:
#
# defmodule Kairos.Repo.Migrations.Test do
#   def up do
#     alter table(:users) do
#       add :new_field, :text
#     end
#   end
# end
```

### Check Pending Migrations

```bash
# En CI pipeline
mix ash_postgres.generate_migrations --check

# Exit code:
# 0 = no pending migrations
# 1 = migrations pending (fail CI)
```

---

## 📚 Recursos Adicionales

### Hexdocs Esenciales

1. **Ash.Resource.Dsl** - https://hexdocs.pm/ash/dsl-ash-resource.html
   - DSL completo documentado
   - Todos los options explicados

2. **AshPostgres.DataLayer.Info** - https://hexdocs.pm/ash_postgres/AshPostgres.DataLayer.Info.html
   - Helpers para introspección
   - Custom SQL examples

3. **Ash.Changeset** - https://hexdocs.pm/ash/Ash.Changeset.html
   - Changesets en profundidad
   - Validations, changes, before/after actions

4. **Ecto.Migration** - https://hexdocs.pm/ecto_sql/Ecto.Migration.html
   - Underlying migration system
   - Custom SQL, constraints

### Ejemplos en GitHub

- **Ash Framework Examples** - https://github.com/ash-project/ash/tree/main/documentation/tutorials
- **AshHQ Source** - https://github.com/ash-project/ash_hq (Real production app)
- **Ash Authentication Demo** - https://github.com/team-alembic/ash_authentication_phoenix_example

---

## ✅ Checklist: Setup Completo KAIROS

```bash
# 1. Crear proyecto
mix phx.new kairos --database postgres --live
cd kairos

# 2. Agregar deps (ver mix.exs arriba)
mix deps.get

# 3. Configurar Ash (ver config/config.exs)

# 4. Crear Repo (lib/kairos/repo.ex)

# 5. Crear Domains
touch lib/kairos/accounts.ex
touch lib/kairos/merits.ex
touch lib/kairos/interactions.ex
touch lib/kairos/moderation.ex

# 6. Crear Resources (ver KAIROS_ARCHITECTURE.md)
touch lib/kairos/accounts/user.ex
touch lib/kairos/merits/profile.ex
touch lib/kairos/interactions/post.ex
# ... etc

# 7. Generar migraciones
mix ash_postgres.generate_migrations --name initial_schema

# 8. Revisar migraciones
cat priv/repo/migrations/*_initial_schema.exs

# 9. Ejecutar migraciones
mix ash_postgres.migrate

# 10. Test en IEx
iex -S mix
```

---

## 🎯 Próximos Pasos

1. **Implementar todos los resources** (ver KAIROS_ARCHITECTURE.md)
2. **Generar migraciones completas**
3. **Configurar seeds** (datos de desarrollo)
4. **Configurar LiveView** con AshPhoenix.Form
5. **Setup CI/CD** con migration checks

---

**Referencias Críticas:**

- Ash Docs: https://hexdocs.pm/ash/
- Ash Postgres: https://hexdocs.pm/ash_postgres/
- Ash Phoenix: https://hexdocs.pm/ash_phoenix/
- Reactor: https://hexdocs.pm/reactor/

**Mantener:**
> "Resources are the source of truth.
> Everything else generates from them." — Zach Daniel
