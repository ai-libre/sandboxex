# KAIROS - Red Social Pro-Humana con IA
## Arquitectura Técnica - Phoenix 1.8.1 + LiveView 1.1

**Diseñado con principios de José Valim: concurrencia, fault-tolerance, elegancia**

**Documentación completa en español**

---

## 📋 Especificaciones Técnicas

### Resumen Ejecutivo

**Proyecto:** KAIROS - Red Social Pro-Humana Asistida por IA
**Stack Principal:** Elixir 1.16+, Phoenix 1.8.1, LiveView 1.1, **Ash 3.0**, PostgreSQL 16
**Paradigma:** Autenticidad conductual, méritos intangibles, moderación IA no invasiva
**Target MVP:** 6 meses, 10k usuarios activos
**Equipo Estimado:** 2-3 desarrolladores Elixir (con experiencia Ash), 1 ML engineer

**Framework Core: Ash 3.0**
- Declarative resources en lugar de Ecto schemas manuales
- Policies para authorization basada en méritos
- Reactors para workflows complejos de AI
- Pub/Sub integrado para real-time
- Automatic changesets y validations

### Especificaciones de Sistema

```yaml
# Requisitos de Runtime
elixir: ">= 1.16.0"
erlang_otp: ">= 26.0"
postgresql: ">= 16.0"
redis: ">= 7.0"  # Opcional - para PubSub distribuido

# Límites de Performance
max_concurrent_connections: 100_000  # Phoenix/Cowboy
websocket_latency_p95: "< 50ms"
database_query_p99: "< 100ms"
ai_inference_latency: "< 200ms"

# Capacidad de Escalado
users_per_node: 50_000
messages_per_second: 10_000
posts_analyzed_per_second: 100

# Recursos por Nodo
cpu_cores: 4
ram_gb: 8
storage_gb: 100  # Base + logs

# Alta Disponibilidad
min_nodes: 2
target_uptime: "99.9%"
backup_frequency: "hourly"
disaster_recovery_rto: "< 4h"
```

### Especificaciones de Arquitectura

**Capas del Sistema:**

1. **Capa de Presentación** (LiveView)
   - Rendering server-side con LiveView 1.1
   - WebSocket bidireccional para updates en tiempo real
   - Componentes reutilizables (function components)
   - Streams para listas eficientes

2. **Capa de Lógica de Negocio** (Ash Domains + Resources)
   - `Kairos.Accounts` Domain
     - `User` Resource - Usuarios con verificación conductual
     - `Session` Resource - Autenticación
   - `Kairos.Merits` Domain
     - `Profile` Resource - Sistema de intangibles
     - `Badge` Resource - Reconocimientos
   - `Kairos.Interactions` Domain
     - `Post` Resource - Publicaciones
     - `Conversation` Resource - Conversaciones
     - `Message` Resource - Mensajes
   - `Kairos.Moderation` Domain
     - `Violation` Resource - Infracciones detectadas
     - `Analysis` Resource - Análisis de IA

3. **Capa OTP** (Runtime)
   - GenServers para state management
   - Supervisors para fault tolerance
   - DynamicSupervisors para procesos bajo demanda
   - ETS para cache de alta concurrencia
   - Pooling para recursos costosos (AI models)

4. **Capa de Datos** (AshPostgres + PostgreSQL)
   - Resources con attributes declarativos
   - Migraciones auto-generadas desde resources
   - Índices definidos en resources
   - Calculations y aggregates nativos
   - JSONB para behavioral patterns (maps en Ash)

**Flujo de Datos (Ash-based):**

```
User Browser (LiveView)
       ↕ WebSocket
Phoenix Endpoint
       ↕
LiveView Process (AshPhoenix.Form)
       ↕
Ash Action (create, update, read, destroy)
       ↕
Ash Policy (authorization)
       ↕
Ash Change/Preparation (business logic)
       ↕ Ash.Notifier (PubSub)
AshPostgres DataLayer
       ↕
PostgreSQL

Parallel flow para AI:
Ash Change → Reactor → AI Analysis → Update Resource
```

### Especificaciones de Seguridad

**Autenticación:**
- Bcrypt para password hashing (cost: 12)
- Phoenix.Token para sesiones (max age: 24h)
- Guardian JWT para API (si se necesita)
- Multi-factor authentication (futuro)

**Autorización:**
- Policy-based authorization (similar a Pundit)
- LiveView socket authentication
- CSRF protection habilitado
- Content Security Policy headers

**Privacidad:**
- AI inference on-premise (sin datos a terceros)
- GDPR compliance: derecho al olvido, portabilidad
- Encriptación en tránsito (TLS 1.3)
- Encriptación en reposo (PostgreSQL AES-256)
- Anonimización de datos para análisis

**Rate Limiting:**
- Por IP: 100 req/min
- Por usuario autenticado: 1000 req/min
- Por acción específica: configurable
- DDoS protection con Cloudflare o similar

### Especificaciones de IA/ML

**Modelos Utilizados:**

1. **Toxicity Detection**
   - Modelo: `unitary/toxic-bert` o similar
   - Framework: Nx + Bumblebee
   - Latencia: < 100ms
   - Precisión target: > 90%

2. **Coherence Analysis**
   - Modelo: Sentence embeddings (all-MiniLM-L6-v2)
   - Framework: Nx + Bumblebee
   - Métrica: Cosine similarity entre mensajes
   - Umbral de coherencia: configurable

3. **Behavioral Pattern Detection**
   - Modelo: Custom LSTM o Transformer
   - Entrenamiento: Transfer learning + fine-tuning
   - Features: timing, vocabulary, emotional tone
   - Output: Behavioral hash único

**Pipeline de AI:**

```
Input (texto/comportamiento)
       ↓
Preprocessing (tokenización, normalización)
       ↓
Model Pool (Nx.Serving with pool_size: 4)
       ↓
Inference (EXLA-compiled para velocidad)
       ↓
Post-processing (thresholds, scoring)
       ↓
Storage (scores en DB) + Events (PubSub)
```

### Especificaciones de Base de Datos

**Schema Principal:**

```sql
-- Tablas core
users (id, username, email, behavioral_hash, verification_score, ...)
merit_profiles (id, user_id, coherence_score, non_violence_score, ...)
posts (id, user_id, content, depth_score, toxicity_score, ...)
conversations (id, title, quality_score, moderation_status, ...)
messages (id, conversation_id, user_id, content, ai_flags, ...)
violations (id, user_id, violation_type, severity, evidence, ...)

-- Índices principales
CREATE INDEX idx_posts_quality ON posts (depth_score DESC, inserted_at DESC);
CREATE INDEX idx_users_verification ON users (verification_status, verification_score);
CREATE INDEX idx_violations_severity ON violations (severity, human_reviewed);
CREATE INDEX idx_messages_conversation ON messages (conversation_id, inserted_at);

-- Particionamiento (futuro, para escala)
-- Particionar posts y messages por fecha (mensual)
```

**Estimaciones de Volumen:**

```
10k usuarios activos:
  - Users: 10,000 rows
  - Merit profiles: 10,000 rows
  - Posts: ~100k/mes → 1.2M/año
  - Messages: ~1M/mes → 12M/año
  - Violations: ~10k/mes → 120k/año

Storage estimado (año 1): ~50GB
Query performance target: p99 < 100ms
```

### Especificaciones de Deployment

**Entorno de Producción:**

```yaml
provider: Fly.io / Render / Railway
regions:
  - primary: us-east
  - replica: eu-west
auto_scaling:
  min_machines: 2
  max_machines: 10
  scale_metric: cpu_usage > 70%
health_checks:
  path: /health
  interval: 10s
  timeout: 5s
```

**CI/CD Pipeline:**

```yaml
# .github/workflows/deploy.yml
on: [push to main]
steps:
  1. Run tests (mix test)
  2. Check formatting (mix format --check-formatted)
  3. Static analysis (mix credo --strict)
  4. Type checking (mix dialyzer)
  5. Security audit (mix deps.audit)
  6. Build release
  7. Deploy to staging
  8. Run smoke tests
  9. Deploy to production (if all pass)
```

**Monitoring:**

```yaml
metrics:
  - Phoenix telemetry (requests, latency, errors)
  - Ecto telemetry (queries, connection pool)
  - Custom business metrics (merit calculations, violations)
  - System metrics (CPU, RAM, disk)

logging:
  level: info
  format: json
  destinations:
    - stdout (para fly.io logs)
    - external: Papertrail / Logflare

alerting:
  - Error rate > 1%
  - p95 latency > 500ms
  - Database connection pool exhausted
  - AI model inference timeout
  - High violation rate spike
```

---

## 🎯 Visión Técnica

KAIROS es una red social que prioriza:
- **Autenticidad** sobre curaduría
- **Coherencia emocional** sobre métricas vanidosas
- **Calidad humana** sobre engagement artificial
- **IA como asistente** no como invasor

**Stack Core:**
- **Phoenix 1.8.1** - Framework web
- **LiveView 1.1** - Real-time interactions sin JS complejo
- **Ash 3.0** - Declarative resource framework
- **AshPostgres 2.0** - PostgreSQL data layer para Ash
- **AshPhoenix 2.0** - Phoenix integration
- **AshAuthentication 4.0** - Auth con behavioral verification
- **Oban 2.17** - Background jobs
- **Nx + Bumblebee** - ML on-device (Elixir-native)
- **Reactor** - Complex workflows (viene con Ash)
- **Phoenix.Presence** - User presence tracking

---

## 🏗️ Arquitectura General

```
┌─────────────────────────────────────────────────────────────────┐
│                      KAIROS Application                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              LiveView Layer (Presentation)                │  │
│  │  - ProfileLive, FeedLive, ConversationLive               │  │
│  │  - Components: MeritBadge, CoherenceScore, AIModStatus   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↕                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Context Layer (Business Logic)               │  │
│  │  - Accounts, Interactions, Merits, Moderation            │  │
│  │  - Behavioral verification, AI analysis                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↕                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   OTP Layer (Runtime)                     │  │
│  │  - MeritServer, BehaviorAnalyzer, ModerationEngine       │  │
│  │  - ConversationSupervisor, AIModelPool                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           ↕                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Data Layer (Ecto)                        │  │
│  │  - Users, Posts, Interactions, Merits, Violations        │  │
│  │  - PostgreSQL with jsonb for behavioral patterns          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Ash Resources - Arquitectura Declarativa

### 1. Accounts Domain - User Resource

```elixir
defmodule Kairos.Accounts.User do
  use Ash.Resource,
    domain: Kairos.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  @moduledoc """
  User resource con verificación conductual (no legal).
  No pedimos DNI - verificamos CONSISTENCIA DE COMPORTAMIENTO.
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
    end

    attribute :hashed_password, :string, sensitive?: true

    # Behavioral Identity (not legal identity)
    attribute :behavioral_hash, :string do
      description "Hash único de patrones de comportamiento del usuario"
    end

    attribute :verification_status, :atom do
      constraints one_of: [:pending, :verified, :flagged]
      default :pending
    end

    attribute :verification_score, :float do
      constraints min: 0.0, max: 1.0
      default 0.0
    end

    # AI-assisted profile
    attribute :ai_profile_summary, :string
    attribute :coherence_baseline, :map  # JSONB - patrones de coherencia

    timestamps()
  end

  relationships do
    has_one :merit_profile, Kairos.Merits.Profile do
      destination_attribute :user_id
    end

    has_many :posts, Kairos.Interactions.Post
    has_many :violations, Kairos.Moderation.Violation
  end

  calculations do
    calculate :is_verified, :boolean, expr(verification_status == :verified)

    calculate :trust_level, :atom do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          cond do
            record.verification_score >= 0.8 -> :high
            record.verification_score >= 0.5 -> :medium
            true -> :low
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:username, :email, :hashed_password]

      change fn changeset, _context ->
        # Generate initial behavioral hash
        Ash.Changeset.force_change_attribute(
          changeset,
          :behavioral_hash,
          Kairos.Accounts.BehavioralAnalyzer.generate_initial_hash()
        )
      end

      change Kairos.Accounts.Changes.SendWelcomeEmail
    end

    update :verify_behavior do
      accept [:verification_score, :verification_status, :behavioral_hash]

      argument :analysis_data, :map, allow_nil?: false

      change Kairos.Accounts.Changes.UpdateBehavioralProfile
    end

    update :flag_for_review do
      accept [:verification_status]
      argument :reason, :string, allow_nil?: false

      change fn changeset, context ->
        Ash.Changeset.force_change_attribute(changeset, :verification_status, :flagged)
      end

      change Kairos.Accounts.Changes.NotifyModerators
    end
  end

  policies do
    # Solo el usuario puede ver su propio perfil completo
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:id, expr(id))
      authorize_if Kairos.Accounts.Checks.IsModerator
    end

    # Otros pueden ver datos públicos
    policy action_type(:read) do
      authorize_if always()

      # Pero ocultamos campos sensibles
      forbid_if accessing_field(:email)
      forbid_if accessing_field(:behavioral_hash)
      forbid_if accessing_field(:coherence_baseline)
    end

    policy action_type(:create) do
      authorize_if always()  # Cualquiera puede registrarse
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:id, expr(id))
      authorize_if Kairos.Accounts.Checks.IsModerator
    end
  end

  identities do
    identity :unique_username, [:username]
    identity :unique_email, [:email]
  end
end
```

**AshAuthentication Setup:**

```elixir
defmodule Kairos.Accounts.User do
  # ... (arriba)

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password

        # Extensión: verificar que el usuario está verificado
        sign_in_action_name :sign_in_verified
      end
    end
  end
end
```

---

### 2. Merits Domain - Profile Resource

```elixir
defmodule Kairos.Merits.Profile do
  use Ash.Resource,
    domain: Kairos.Merits,
    data_layer: AshPostgres.DataLayer

  @moduledoc """
  Sistema de méritos basado en valores humanos reales.
  NO es gamificación - es reconocimiento de calidad humana.
  """

  postgres do
    table "merit_profiles"
    repo Kairos.Repo
  end

  attributes do
    uuid_primary_key :id

    # Core Intangibles - actualizados por AI analysis
    attribute :coherence_score, :float do
      description "Capacidad de sostener contradicciones"
      constraints min: 0.0, max: 1.0
      default 0.5
    end

    attribute :non_violence_score, :float do
      description "Cero violencia verbal"
      constraints min: 0.0, max: 1.0
      default 0.5
    end

    attribute :depth_score, :float do
      description "Profundidad de conversaciones"
      constraints min: 0.0, max: 1.0
      default 0.5
    end

    attribute :contribution_score, :float do
      description "Aportes significativos"
      constraints min: 0.0, max: 1.0
      default 0.5
    end

    # Dynamic Reputation (parcialmente oculto)
    attribute :ethical_profile, :map do
      description "Perfil ético dinámico - NO revelado completamente"
    end

    attribute :interaction_quality, :map do
      description "Métricas de calidad de interacciones"
    end

    attribute :badges, {:array, :string}, default: []

    timestamps()
  end

  relationships do
    belongs_to :user, Kairos.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  calculations do
    # Overall merit level (cualitativo)
    calculate :merit_level, :atom do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          avg_score =
            (record.coherence_score + record.non_violence_score +
               record.depth_score + record.contribution_score) / 4

          cond do
            avg_score >= 0.8 -> :exemplary
            avg_score >= 0.6 -> :strong
            avg_score >= 0.4 -> :developing
            true -> :emerging
          end
        end)
      end
    end

    # Aggregate de posts de alta calidad
    calculate :high_quality_post_count, :integer,
      Kairos.Merits.Calculations.CountHighQualityPosts
  end

  actions do
    defaults [:read]

    create :create do
      accept [:user_id]

      # Inicializar con valores default
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:ethical_profile, %{})
        |> Ash.Changeset.force_change_attribute(:interaction_quality, %{})
      end
    end

    update :recalculate_scores do
      argument :interaction_history, {:array, :map}, allow_nil?: false

      # Usa Reactor para análisis complejo
      change Kairos.Merits.Changes.RecalculateAllScores
    end

    update :award_badge do
      argument :badge_type, :string, allow_nil?: false

      validate Kairos.Merits.Validations.BadgeEligibility

      change fn changeset, context ->
        badge_type = Ash.Changeset.get_argument(changeset, :badge_type)
        current_badges = Ash.Changeset.get_attribute(changeset, :badges) || []

        unless badge_type in current_badges do
          Ash.Changeset.force_change_attribute(
            changeset,
            :badges,
            [badge_type | current_badges]
          )
        else
          changeset
        end
      end

      change Kairos.Merits.Changes.NotifyUserBadgeAwarded
    end
  end

  policies do
    # El usuario puede ver su propio perfil COMPLETO
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    # Otros pueden ver perfil PARCIAL (sin ethical_profile completo)
    policy action_type(:read) do
      authorize_if always()

      # Ocultamos el perfil ético completo
      forbid_if accessing_field(:ethical_profile)
    end

    # Solo el sistema puede actualizar scores
    policy action_type(:update) do
      authorize_if Kairos.Merits.Checks.IsSystemProcess
    end
  end

  pub_sub do
    module KairosWeb.Endpoint
    prefix "merit_profile"

    # Notificar cuando cambia el merit level
    publish :recalculate_scores, ["updated", :id]
    publish :award_badge, ["badge_awarded", :id]
  end
end
```

**Cálculo de Méritos:**
- **MeritServer GenServer** - Cálculo en tiempo real
- **AI analysis** - Patrones de largo plazo
- **Telemetry events** - Métricas para ajuste

---

### 3. Interactions Domain - Post Resource

```elixir
defmodule Kairos.Interactions.Post do
  use Ash.Resource,
    domain: Kairos.Interactions,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  @moduledoc """
  Posts de alta calidad - contenido profundo, creativo, significativo.
  AI analysis automático en cada create/update.
  """

  postgres do
    table "posts"
    repo Kairos.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints min_length: 10, max_length: 5000
    end

    attribute :content_type, :atom do
      constraints one_of: [:text, :creative, :question, :insight]
      default :text
    end

    # AI Analysis scores (auto-calculated)
    attribute :depth_score, :float do
      constraints min: 0.0, max: 1.0
      writable? false  # Solo AI puede escribir
    end

    attribute :coherence_score, :float do
      constraints min: 0.0, max: 1.0
      writable? false
    end

    attribute :toxicity_score, :float do
      constraints min: 0.0, max: 1.0
      writable? false
    end

    attribute :ai_summary, :string, writable?: false

    # Internal metrics (no público)
    attribute :interaction_quality, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :user, Kairos.Accounts.User do
      allow_nil? false
    end

    has_many :replies, Kairos.Interactions.Reply
  end

  calculations do
    calculate :is_high_quality, :boolean do
      calculation expr(depth_score >= 0.7 and toxicity_score < 0.3)
    end

    calculate :quality_level, :atom do
      calculation fn records, _context ->
        Enum.map(records, fn post ->
          cond do
            post.depth_score >= 0.8 && post.toxicity_score < 0.2 -> :exceptional
            post.depth_score >= 0.6 && post.toxicity_score < 0.3 -> :high
            post.depth_score >= 0.4 && post.toxicity_score < 0.5 -> :medium
            true -> :low
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:content, :content_type]

      argument :user_id, :uuid, allow_nil?: false

      # User desde actor
      change set_attribute(:user_id, arg(:user_id))

      # AI analysis automático ANTES de guardar
      change Kairos.Interactions.Changes.AnalyzePostQuality

      # Si toxicity muy alta, bloquear
      validate Kairos.Interactions.Validations.ToxicityThreshold
    end

    update :update do
      accept [:content, :content_type]

      # Re-analizar al actualizar
      change Kairos.Interactions.Changes.AnalyzePostQuality
      validate Kairos.Interactions.Validations.ToxicityThreshold
    end

    read :high_quality_feed do
      # Solo posts con depth_score > 0.7
      filter expr(depth_score >= 0.7 and toxicity_score < 0.3)

      # Ordenar por calidad + recencia
      prepare build(sort: [depth_score: :desc, inserted_at: :desc])
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    # Cualquiera puede leer posts públicos
    policy action_type(:read) do
      authorize_if always()
    end

    # Solo usuarios verificados pueden crear
    policy action_type(:create) do
      authorize_if Kairos.Interactions.Checks.UserIsVerified
    end

    # Solo el autor puede editar/borrar
    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module KairosWeb.Endpoint
    prefix "post"

    publish :create, ["created"]
    publish :update, ["updated", :id]
  end

  postgres do
    table "posts"
    repo Kairos.Repo

    custom_indexes do
      # Índice para feed de alta calidad
      index ["depth_score DESC", "inserted_at DESC"]
      index ["toxicity_score"] where: "toxicity_score > 0.5"
    end
  end
end
```

### 4. Interactions Domain - Conversation Resource

```elixir
defmodule Kairos.Interactions.Conversation do
  use Ash.Resource,
    domain: Kairos.Interactions,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  @moduledoc """
  Conversaciones de alto valor: 1-on-1, grupos, colaboraciones.
  Moderación AI en tiempo real.
  """

  postgres do
    table "conversations"
    repo Kairos.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      constraints min_length: 3, max_length: 200
    end

    attribute :conversation_type, :atom do
      constraints one_of: [:one_on_one, :group, :collaboration]
      default :one_on_one
    end

    # AI moderation
    attribute :moderation_status, :atom do
      constraints one_of: [:active, :monitored, :flagged]
      default :active
    end

    attribute :quality_score, :float do
      constraints min: 0.0, max: 1.0
      default 0.5
    end

    timestamps()
  end

  relationships do
    has_many :messages, Kairos.Interactions.Message

    many_to_many :participants, Kairos.Accounts.User do
      through Kairos.Interactions.ConversationParticipant
      source_attribute_on_join_resource :conversation_id
      destination_attribute_on_join_resource :user_id
    end
  end

  aggregates do
    count :message_count, :messages
    avg :avg_message_quality, :messages, :depth_score

    # Participantes activos en última hora
    count :active_participants, :messages do
      filter expr(inserted_at > ago(1, :hour))
    end
  end

  calculations do
    calculate :is_high_quality, :boolean do
      calculation expr(quality_score >= 0.7 and moderation_status == :active)
    end
  end

  actions do
    defaults [:read, :destroy]

    create :start do
      accept [:title, :conversation_type]
      argument :participant_ids, {:array, :uuid}, allow_nil?: false

      # Agregar participants después de crear
      change Kairos.Interactions.Changes.AddParticipants
    end

    update :update_quality_score do
      accept [:quality_score]
      argument :analysis_result, :map, allow_nil?: false

      change Kairos.Interactions.Changes.RecalculateConversationQuality
    end

    update :flag do
      accept [:moderation_status]
      argument :reason, :string, allow_nil?: false

      change set_attribute(:moderation_status, :flagged)
      change Kairos.Moderation.Changes.CreateViolation
    end
  end

  policies do
    # Solo participants pueden leer
    policy action_type(:read) do
      authorize_if Kairos.Interactions.Checks.IsParticipant
    end

    # Usuarios verificados pueden crear
    policy action_type(:create) do
      authorize_if Kairos.Interactions.Checks.UserIsVerified
    end

    # Solo participants pueden actualizar
    policy action_type(:update) do
      authorize_if Kairos.Interactions.Checks.IsParticipant
    end
  end

  pub_sub do
    module KairosWeb.Endpoint
    prefix "conversation"

    publish :start, ["created"]
    publish :update_quality_score, ["quality_updated", :id]
    publish :flag, ["flagged", :id]
  end
end
```

**LiveView Real-time:**
- **FeedLive** - Stream de posts con calidad alta
- **ConversationLive** - Conversaciones en tiempo real
- **PubSub subscriptions** - Updates instantáneos

---

### 5. Reactor - Workflows Complejos de AI

**Reactor** (integrado en Ash 3.0) permite orquestar workflows complejos con steps, compensations y paralelismo.

**Ejemplo: Análisis Completo de Post**

```elixir
defmodule Kairos.Reactors.PostAnalysisReactor do
  use Reactor

  @moduledoc """
  Reactor para análisis completo de un post:
  1. Toxicity detection
  2. Depth analysis
  3. Coherence check
  4. Update post scores
  5. Update user merit profile

  Si algún step falla, rollback automático.
  """

  input :post_id
  input :user_id

  # Step 1: Load post and user data
  step :load_post do
    argument :post_id, input(:post_id)

    run fn %{post_id: post_id}, _context ->
      case Ash.get(Kairos.Interactions.Post, post_id) do
        {:ok, post} -> {:ok, post}
        {:error, error} -> {:error, error}
      end
    end
  end

  step :load_user do
    argument :user_id, input(:user_id)

    run fn %{user_id: user_id}, _context ->
      Ash.get(Kairos.Accounts.User, user_id, load: [:merit_profile])
    end
  end

  # Step 2: AI Analysis en paralelo
  step :analyze_toxicity, async?: true do
    argument :post, result(:load_post)

    run fn %{post: post}, _context ->
      toxicity_score = Kairos.AI.ToxicityDetector.analyze(post.content)
      {:ok, toxicity_score}
    end

    # Si toxicity muy alta, abortar workflow
    compensate fn %{toxicity_score: score}, _context ->
      if score > 0.8 do
        {:error, :toxic_content}
      else
        :ok
      end
    end
  end

  step :analyze_depth, async?: true do
    argument :post, result(:load_post)

    run fn %{post: post}, _context ->
      depth_score = Kairos.AI.DepthAnalyzer.analyze(post.content)
      {:ok, depth_score}
    end
  end

  step :analyze_coherence, async?: true do
    argument :post, result(:load_post)
    argument :user, result(:load_user)

    run fn %{post: post, user: user}, _context ->
      # Comparar con baseline del usuario
      coherence_score =
        Kairos.AI.CoherenceAnalyzer.analyze(
          post.content,
          user.coherence_baseline
        )

      {:ok, coherence_score}
    end
  end

  # Step 3: Update post con scores
  step :update_post_scores do
    argument :post, result(:load_post)
    argument :toxicity, result(:analyze_toxicity)
    argument :depth, result(:analyze_depth)
    argument :coherence, result(:analyze_coherence)

    run fn args, _context ->
      Ash.update(args.post, %{
        toxicity_score: args.toxicity,
        depth_score: args.depth,
        coherence_score: args.coherence
      })
    end

    # Rollback si falla
    compensate fn args, _context ->
      Ash.update(args.post, %{
        toxicity_score: nil,
        depth_score: nil,
        coherence_score: nil
      })
    end
  end

  # Step 4: Update user merit profile
  step :update_user_merits do
    argument :user, result(:load_user)
    argument :depth, result(:analyze_depth)
    argument :toxicity, result(:analyze_toxicity)
    argument :coherence, result(:analyze_coherence)

    run fn args, _context ->
      # Recalcular scores del usuario basado en nuevo post
      new_depth_score =
        (args.user.merit_profile.depth_score * 0.9 + args.depth * 0.1)

      new_violence_score =
        (args.user.merit_profile.non_violence_score * 0.9 +
           (1.0 - args.toxicity) * 0.1)

      new_coherence_score =
        (args.user.merit_profile.coherence_score * 0.9 + args.coherence * 0.1)

      Ash.update(args.user.merit_profile, %{
        depth_score: new_depth_score,
        non_violence_score: new_violence_score,
        coherence_score: new_coherence_score
      })
    end
  end

  # Step 5: Check for badge eligibility
  step :check_badge_eligibility do
    argument :user, result(:load_user)
    argument :updated_merits, result(:update_user_merits)

    run fn args, _context ->
      Kairos.Merits.BadgeChecker.check_and_award(args.updated_merits)
      {:ok, :badge_check_complete}
    end
  end

  # Return final results
  return :update_post_scores
end
```

**Uso del Reactor:**

```elixir
# En Ash Change module
defmodule Kairos.Interactions.Changes.AnalyzePostQuality do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    post_id = Ash.Changeset.get_attribute(changeset, :id)
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)

    # Run reactor async (no bloquea el create)
    Task.start(fn ->
      case Reactor.run(Kairos.Reactors.PostAnalysisReactor,
             %{post_id: post_id, user_id: user_id},
             context
           ) do
        {:ok, _result} ->
          Logger.info("Post analysis completed for #{post_id}")

        {:error, reason} ->
          Logger.error("Post analysis failed: #{inspect(reason)}")
      end
    end)

    changeset
  end
end
```

**Ventajas de Reactor:**
- **Compensations automáticas** - Rollback si algo falla
- **Paralelismo** - Steps async para velocidad
- **Retries configurables** - Resilencia ante fallos transitorios
- **Observabilidad** - Telemetry en cada step

---

### 6. Moderation Domain - Violation Resource

```elixir
defmodule Kairos.Moderation do
  @moduledoc """
  AI-assisted moderation: filters bots, grooming, violence, manipulation.

  NO es censura. Es protección y calidad.
  """

  defmodule Violation do
    use Ecto.Schema

    schema "violations" do
      belongs_to :user, Kairos.Accounts.User
      belongs_to :content, :posts  # Polymorphic

      field :violation_type, Ecto.Enum,
        values: [:bot_behavior, :grooming, :violence, :manipulation, :spam]
      field :severity, Ecto.Enum, values: [:low, :medium, :high, :critical]
      field :ai_confidence, :float
      field :human_reviewed, :boolean, default: false

      # Evidence
      field :evidence, :map  # jsonb - patrones detectados

      timestamps()
    end
  end

  # Public API
  def analyze_content(content, user_id)
  def detect_bot_behavior(user_id)
  def flag_grooming_attempt(conversation_id)
  def escalate_to_human(violation_id)
end
```

**Motor de Moderación:**
- **ModerationEngine GenServer** - Análisis continuo
- **AI Model Pool** - Modelos Nx/Bumblebee en paralelo
- **Human-in-the-loop** - Escalación automática

---

## 🧠 Sistema de IA - Nx + Bumblebee (Elixir-Native)

```elixir
defmodule Kairos.AI do
  @moduledoc """
  AI analysis using Nx and Bumblebee (Elixir-native ML).

  No external APIs - todo on-premise para privacidad.
  """

  defmodule BehaviorAnalyzer do
    use GenServer

    @doc """
    Analiza patrones de comportamiento en tiempo real.
    """
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def analyze_user_behavior(user_id, recent_actions) do
      GenServer.call(__MODULE__, {:analyze, user_id, recent_actions})
    end

    # Uses Bumblebee for NLP
    def init(_opts) do
      {:ok, model} = Bumblebee.load_model({:hf, "microsoft/deberta-v3-base"})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "microsoft/deberta-v3-base"})

      state = %{
        model: model,
        tokenizer: tokenizer,
        serving: Nx.Serving.new(...)
      }

      {:ok, state}
    end
  end

  defmodule ToxicityDetector do
    @doc """
    Detecta violencia, grooming, manipulación.
    """
    def analyze(text) do
      # Nx-based model inference
      # Returns: %{toxicity: 0.05, violence: 0.01, manipulation: 0.03}
    end
  end

  defmodule CoherenceAnalyzer do
    @doc """
    Mide coherencia emocional y capacidad de sostener contradicciones.
    """
    def analyze_conversation_thread(messages) do
      # Embedding-based similarity + pattern detection
    end
  end
end
```

**Ventajas de Nx/Bumblebee:**
- **Privacidad total** - No datos salen del servidor
- **Baja latencia** - Inferencia local
- **Escalabilidad** - BEAM concurrency
- **Costo bajo** - No APIs externas

---

## 🔴 LiveView Components - Real-time UX

### FeedLive - Stream de Contenido de Calidad

```elixir
defmodule KairosWeb.FeedLive do
  use KairosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kairos.PubSub, "feed:high_quality")
      Phoenix.PubSub.subscribe(Kairos.PubSub, "user:#{socket.assigns.current_user.id}")
    end

    {:ok,
     socket
     |> assign(:posts, load_high_quality_posts())
     |> stream(:posts, [])}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    # Only show if quality score > threshold
    if post.depth_score > 0.7 do
      {:noreply, stream_insert(socket, :posts, post, at: 0)}
    else
      {:noreply, socket}
    end
  end

  defp load_high_quality_posts do
    Interactions.list_posts(
      filters: [min_depth: 0.7, min_coherence: 0.6],
      preload: [:user, merit_profile: :user]
    )
  end
end
```

### ConversationLive - Conversaciones Profundas

```elixir
defmodule KairosWeb.ConversationLive do
  use KairosWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    conversation = Interactions.get_conversation!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kairos.PubSub, "conversation:#{id}")
      Kairos.Presence.track(self(), "conversation:#{id}", socket.assigns.current_user.id, %{})
    end

    {:ok,
     socket
     |> assign(:conversation, conversation)
     |> assign(:quality_indicator, calculate_quality(conversation))
     |> stream(:messages, conversation.messages)}
  end

  @impl true
  def handle_event("send_message", %{"message" => text}, socket) do
    # AI analysis BEFORE sending
    case Moderation.analyze_content(text, socket.assigns.current_user.id) do
      {:ok, :safe} ->
        {:ok, message} = Interactions.create_message(...)
        broadcast_message(message)
        {:noreply, stream_insert(socket, :messages, message)}

      {:warning, reason} ->
        {:noreply, put_flash(socket, :warning, "Mensaje podría violar normas: #{reason}")}

      {:blocked, reason} ->
        {:noreply, put_flash(socket, :error, "Mensaje bloqueado: #{reason}")}
    end
  end
end
```

### ProfileLive - Perfil con Méritos

```elixir
defmodule KairosWeb.ProfileLive do
  use KairosWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="profile-container">
      <div class="user-header">
        <h1><%= @user.username %></h1>
        <.verification_badge status={@user.verification_status} score={@user.verification_score} />
      </div>

      <div class="merit-section">
        <h2>Perfil de Valores</h2>

        <!-- NO mostramos scores exactos - mostramos cualitativo -->
        <.merit_indicator
          label="Coherencia"
          level={merit_level(@merit_profile.coherence_score)}
        />
        <.merit_indicator
          label="No Violencia"
          level={merit_level(@merit_profile.non_violence_score)}
        />
        <.merit_indicator
          label="Profundidad"
          level={merit_level(@merit_profile.depth_score)}
        />

        <!-- Badges earned -->
        <div class="badges">
          <%= for badge <- @merit_profile.badges do %>
            <.badge_component type={badge} />
          <% end %>
        </div>
      </div>

      <!-- Recent contributions (filtered by quality) -->
      <div class="contributions">
        <.live_component
          module={ContributionsComponent}
          id="contributions"
          user_id={@user.id}
        />
      </div>
    </div>
    """
  end

  # NO revelamos el algoritmo completo
  defp merit_level(score) when score > 0.8, do: :exemplary
  defp merit_level(score) when score > 0.6, do: :strong
  defp merit_level(score) when score > 0.4, do: :developing
  defp merit_level(_), do: :emerging
end
```

---

## 🏛️ OTP Supervision Tree

```elixir
defmodule Kairos.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Core Infrastructure
      {Phoenix.PubSub, name: Kairos.PubSub},
      Kairos.Repo,
      {Ecto.Migrator, repos: [Kairos.Repo], skip: skip_migrations?()},

      # Web Endpoint
      KairosWeb.Endpoint,

      # Presence
      KairosWeb.Presence,

      # AI Engine Pool
      {Kairos.AI.ModelPool, pool_size: 4},

      # Business Logic Servers
      {Kairos.Merits.MeritServer, []},
      {Kairos.Moderation.ModerationEngine, []},
      {Kairos.Accounts.VerificationServer, []},

      # Background Jobs
      {Oban, oban_config()},

      # Dynamic Supervisors
      {DynamicSupervisor, name: Kairos.ConversationSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Kairos.BehaviorAnalyzerSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Kairos.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Fault Tolerance:**
- **One process crash** no afecta el sistema completo
- **DynamicSupervisor** para conversaciones activas
- **Pooling** para AI models (evita bottlenecks)

---

## 💾 Database Schema (PostgreSQL + Ecto)

```elixir
# priv/repo/migrations/xxx_create_core_schema.exs

defmodule Kairos.Repo.Migrations.CreateCoreSchema do
  use Ecto.Migration

  def change do
    # Users
    create table(:users) do
      add :username, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false

      # Behavioral verification
      add :behavioral_hash, :string
      add :verification_status, :string, default: "pending"
      add :verification_score, :float, default: 0.0

      # AI profile
      add :ai_profile_summary, :text
      add :coherence_baseline, :map  # jsonb

      timestamps()
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
    create index(:users, [:verification_status])

    # Merit Profiles
    create table(:merit_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :coherence_score, :float, default: 0.5
      add :non_violence_score, :float, default: 0.5
      add :depth_score, :float, default: 0.5
      add :contribution_score, :float, default: 0.5

      add :ethical_profile, :map  # jsonb
      add :interaction_quality, :map  # jsonb
      add :badges, {:array, :string}, default: []

      timestamps()
    end

    create unique_index(:merit_profiles, [:user_id])

    # Posts
    create table(:posts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :content_type, :string, default: "text"

      # AI scores
      add :depth_score, :float
      add :coherence_score, :float
      add :toxicity_score, :float
      add :ai_summary, :text
      add :interaction_quality, :map

      timestamps()
    end

    create index(:posts, [:user_id])
    create index(:posts, [:depth_score])
    create index(:posts, [:inserted_at])

    # Conversations
    create table(:conversations) do
      add :title, :string
      add :conversation_type, :string, default: "one_on_one"
      add :moderation_status, :string, default: "active"
      add :quality_score, :float, default: 0.5

      timestamps()
    end

    # Messages
    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :ai_flags, :map  # jsonb - toxicity, etc

      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:user_id])

    # Violations
    create table(:violations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content_id, :integer
      add :content_type, :string  # "Post", "Message", etc

      add :violation_type, :string, null: false
      add :severity, :string, default: "low"
      add :ai_confidence, :float
      add :human_reviewed, :boolean, default: false
      add :evidence, :map  # jsonb

      timestamps()
    end

    create index(:violations, [:user_id])
    create index(:violations, [:violation_type])
    create index(:violations, [:severity])
  end
end
```

---

## 🔒 Seguridad y Privacidad

### 1. Autenticación - Phoenix.Token + LiveView

```elixir
defmodule KairosWeb.UserAuth do
  use KairosWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  # LiveView auth
  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Debes iniciar sesión")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end
end
```

### 2. Rate Limiting - GenServer-based

```elixir
defmodule Kairos.RateLimiter do
  use GenServer

  # ETS-based rate limiting
  def check_rate_limit(user_id, action) do
    GenServer.call(__MODULE__, {:check, user_id, action})
  end

  # Different limits per action
  defp limits do
    %{
      post_creation: {10, :per_hour},
      message_send: {100, :per_hour},
      profile_view: {1000, :per_hour}
    }
  end
end
```

### 3. Privacidad de Datos

**Principios:**
- **No vendemos datos** - nunca
- **AI on-premise** - Nx/Bumblebee local
- **Perfil ético parcialmente oculto** - no revelamos el algoritmo completo
- **GDPR compliance** - derecho al olvido, exportación de datos

---

## 📊 Background Jobs (Oban)

```elixir
defmodule Kairos.Workers do
  # Análisis profundo de comportamiento (CPU intensive)
  defmodule BehaviorAnalysisWorker do
    use Oban.Worker, queue: :analysis, max_attempts: 3

    def perform(%{args: %{"user_id" => user_id}}) do
      Kairos.AI.BehaviorAnalyzer.deep_analysis(user_id)
      :ok
    end
  end

  # Actualización de merit scores
  defmodule MeritUpdateWorker do
    use Oban.Worker, queue: :merits, max_attempts: 3

    def perform(%{args: %{"user_id" => user_id}}) do
      Kairos.Merits.recalculate_all_scores(user_id)
      :ok
    end
  end

  # Limpieza de violaciones antiguas
  defmodule ViolationCleanupWorker do
    use Oban.Worker, queue: :cleanup, max_attempts: 1

    def perform(_args) do
      Kairos.Moderation.archive_old_violations()
      :ok
    end
  end
end
```

---

## 🚀 MVP - Funcionalidades Mínimas

### Fase 1 (2 meses)
- ✅ Registro y autenticación
- ✅ Perfil básico con verificación conductual
- ✅ Posts con análisis de calidad
- ✅ Feed filtrado por calidad
- ✅ Sistema de méritos básico

### Fase 2 (2 meses)
- ✅ Conversaciones 1-on-1 con LiveView
- ✅ Moderación AI básica (toxicity detection)
- ✅ Badges iniciales
- ✅ Presence tracking

### Fase 3 (2 meses)
- ✅ Grupos y colaboraciones
- ✅ AI analysis avanzado (coherencia, profundidad)
- ✅ Sistema de reputación dinámico
- ✅ Dashboard de métricas

---

## 🎨 Tech Stack Completo

```elixir
# mix.exs
def deps do
  [
    # Core
    {:phoenix, "~> 1.8.1"},
    {:phoenix_live_view, "~> 1.1.0"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_dashboard, "~> 0.8"},
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},

    # AI/ML
    {:nx, "~> 0.7"},
    {:bumblebee, "~> 0.5"},
    {:exla, "~> 0.7"},  # XLA compiler for Nx

    # Background Jobs
    {:oban, "~> 2.17"},

    # Real-time
    {:phoenix_pubsub, "~> 2.1"},
    {:presence, "~> 0.1"},

    # HTTP/WebSocket
    {:plug_cowboy, "~> 2.7"},
    {:bandit, "~> 1.5"},

    # Auth
    {:bcrypt_elixir, "~> 3.0"},
    {:guardian, "~> 2.3"},

    # Utilities
    {:jason, "~> 1.4"},
    {:gettext, "~> 0.24"},
    {:swoosh, "~> 1.16"},  # Email
    {:finch, "~> 0.18"},

    # Dev/Test
    {:phoenix_live_reload, "~> 1.5", only: :dev},
    {:floki, ">= 0.36.0", only: :test},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
  ]
end
```

---

## 🎯 Métricas de Éxito (No públicas)

**Internamente medimos:**
- % de conversaciones con depth_score > 0.7
- % de usuarios con verificación > 0.8
- Tasa de violaciones detectadas vs falsos positivos
- Tiempo promedio de conversaciones (+ es mejor)
- Ratio de contribuciones significativas

**NO medimos:**
- Likes, shares, follower counts
- Engagement time (diseñado para NO ser adictivo)
- Viralidad

---

## 🌟 Diferenciadores Técnicos

**Ventaja #1: Elixir/BEAM**
- Concurrencia masiva (millones de procesos)
- Fault tolerance nativa
- Hot code reloading en producción

**Ventaja #2: LiveView**
- Real-time sin complejidad de SPA
- UX fluido con menos código
- SEO-friendly

**Ventaja #3: AI on-premise (Nx)**
- Privacidad total
- Baja latencia
- Costos predecibles

**Ventaja #4: OTP patterns**
- GenServers para lógica de negocio
- Supervisors para fault tolerance
- PubSub para real-time events

---

## 📈 Escalabilidad

**Horizontal scaling:**
- Phoenix nodes con libcluster
- PostgreSQL replicas
- Redis para PubSub distribuido

**Vertical optimization:**
- ETS para cache caliente
- Pooling de AI models
- Optimización de queries con Ecto

**Costos estimados (10k usuarios activos):**
- Servers: $200/mes (2x 4GB RAM)
- Database: $50/mes
- Storage: $20/mes
- **Total: ~$270/mes**

---

## 🎓 Filosofía de Diseño (José Valim Style)

1. **Let it crash** - Supervisors manejan fallas
2. **Immutability** - Sin state compartido
3. **Message passing** - Comunicación entre procesos
4. **Pattern matching** - Código expresivo
5. **Separation of concerns** - Contexts bien definidos
6. **Simplicity over cleverness** - Código legible

---

## 📝 Próximos Pasos

1. **Inicializar proyecto Phoenix 1.8.1**
2. **Setup base de datos y schemas**
3. **Implementar autenticación básica**
4. **Crear LiveViews core (Feed, Profile, Conversation)**
5. **Integrar Nx/Bumblebee para AI**
6. **Implementar sistema de méritos**
7. **Deploy en producción (Fly.io o similar)**

---

**¿Listo para construir KAIROS con Elixir/Phoenix?**

Este diseño aprovecha lo mejor de BEAM: concurrencia, fault tolerance, y real-time capabilities.

**¿Comenzamos con la implementación?**
