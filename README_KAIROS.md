# KAIROS - Documentación Técnica Completa

**Red Social Pro-Humana Asistida por IA**

> Autenticidad sobre curaduría. Coherencia emocional sobre métricas vanidosas. Calidad humana sobre engagement artificial.

---

## 📚 Índice de Documentación

Este repositorio contiene la **arquitectura técnica completa** de KAIROS, diseñada con **Ash Framework 3.0**, **Phoenix 1.8.1** y **LiveView 1.1**.

### Documentos Principales

| Documento | Propósito | Audiencia | Líneas |
|-----------|-----------|-----------|--------|
| **[KAIROS_ARCHITECTURE.md](./KAIROS_ARCHITECTURE.md)** | Arquitectura completa con Ash 3.0 | Desarrolladores técnicos | ~1,200 |
| **[KAIROS_CONSENSOS.md](./KAIROS_CONSENSOS.md)** | Architecture Decision Records (ADRs) | Tech leads, arquitectos | ~1,100 |
| **[ASH_CODEGEN_GUIDE.md](./ASH_CODEGEN_GUIDE.md)** | Guía práctica de implementación | Desarrolladores Elixir/Ash | ~900 |

**Total:** ~3,200 líneas de documentación técnica profesional

---

## 🚀 Inicio Rápido

### Para Entender el Proyecto

```bash
# 1. Lee la visión y arquitectura general
cat KAIROS_ARCHITECTURE.md | head -n 300

# 2. Entiende las decisiones técnicas clave
cat KAIROS_CONSENSOS.md | grep "ADR-"

# 3. Ve cómo implementar
cat ASH_CODEGEN_GUIDE.md | grep "## Setup"
```

### Para Implementar el Proyecto

```bash
# 1. Crear proyecto Phoenix
mix phx.new kairos --database postgres --live
cd kairos

# 2. Seguir ASH_CODEGEN_GUIDE.md paso a paso
# Ver sección "Setup Inicial del Proyecto KAIROS"

# 3. Crear resources según KAIROS_ARCHITECTURE.md
# Ver sección "Ash Resources - Arquitectura Declarativa"

# 4. Generar migraciones
mix ash_postgres.generate_migrations --name initial_schema

# 5. Ejecutar migraciones
mix ash_postgres.migrate
```

---

## 📋 KAIROS_ARCHITECTURE.md

**Arquitectura Técnica Completa con Ash 3.0**

### Contenido

#### 1. Especificaciones Técnicas

**Resumen Ejecutivo:**
- Stack: Elixir 1.16+, Phoenix 1.8.1, LiveView 1.1, **Ash 3.0**, PostgreSQL 16
- Target MVP: 6 meses, 10k usuarios activos
- Equipo: 2-3 devs Elixir + 1 ML engineer

**Especificaciones de Sistema:**
```yaml
Performance:
  - max_concurrent_connections: 100,000
  - websocket_latency_p95: < 50ms
  - database_query_p99: < 100ms
  - ai_inference_latency: < 200ms

Escalado:
  - users_per_node: 50,000
  - messages_per_second: 10,000
  - posts_analyzed_per_second: 100
```

**Especificaciones de Seguridad:**
- Bcrypt (cost: 12)
- Ash Policies (field-level access control)
- AI on-premise (Nx/Bumblebee)
- GDPR compliant

**Especificaciones de IA:**
- Toxicity detection: unitary/toxic-bert
- Coherence analysis: Sentence embeddings
- Behavioral pattern detection: Custom LSTM
- Latencia target: < 200ms

#### 2. Ash Resources Completos

**User Resource** (`Kairos.Accounts.User`)
- Attributes: username, email, behavioral_hash, verification_score
- Calculations: is_verified, trust_level
- Actions: register, verify_behavior, flag_for_review
- Policies: Field-level privacy (email, behavioral_hash ocultos)
- AshAuthentication integrado

**MeritProfile Resource** (`Kairos.Merits.Profile`)
- 4 core scores: coherence, non_violence, depth, contribution
- Calculation: merit_level (exemplary, strong, developing, emerging)
- Actions: create, recalculate_scores, award_badge
- Policies: Ethical profile parcialmente oculto
- Pub/Sub para updates en tiempo real

**Post Resource** (`Kairos.Interactions.Post`)
- AI scores: depth_score, coherence_score, toxicity_score (read-only)
- Actions: create (con AI analysis), high_quality_feed
- Policies: Solo verified users pueden crear
- Custom indexes para performance

**Conversation Resource** (`Kairos.Interactions.Conversation`)
- Many-to-many participants
- Aggregates: message_count, avg_message_quality, active_participants
- Actions: start, update_quality_score, flag
- Policies: Solo participants pueden leer

#### 3. Reactor Workflow

**PostAnalysisReactor** - 5 steps:
1. Load post + user data
2. **AI Analysis en paralelo:**
   - Toxicity detection (async)
   - Depth analysis (async)
   - Coherence check (async)
3. Update post scores
4. Update user merit profile
5. Check badge eligibility

**Compensations automáticas** si falla cualquier step.

#### 4. Stack Completo

```elixir
# Core
{:phoenix, "~> 1.8.1"}
{:phoenix_live_view, "~> 1.1.0"}

# Ash Framework
{:ash, "~> 3.0"}
{:ash_postgres, "~> 2.0"}
{:ash_phoenix, "~> 2.0"}
{:ash_authentication, "~> 4.0"}

# AI/ML
{:nx, "~> 0.7"}
{:bumblebee, "~> 0.5"}
{:exla, "~> 0.7"}

# Background
{:oban, "~> 2.17"}
{:reactor, "~> 0.9"}
```

### Cómo Usar Este Documento

**Para arquitectos:**
- Leer secciones de especificaciones (sistema, seguridad, IA, deployment)
- Revisar flujo de datos Ash-based
- Entender decisions de escalabilidad

**Para desarrolladores:**
- Copiar resources completos (User, Post, etc.)
- Seguir patterns de Policies y Calculations
- Implementar Reactor workflows

**Para ML engineers:**
- Ver especificaciones de IA/ML
- Entender pipeline de AI (Nx/Bumblebee)
- Implementar modelos on-premise

---

## 🎯 KAIROS_CONSENSOS.md

**Architecture Decision Records + Filosofía Técnica**

### Contenido

#### ADRs (Architecture Decision Records)

**ADR-001: Ash 3.0 vs Ecto Contexts**
- **Decisión:** Ash 3.0
- **Rationale:** Authorization compleja (field-level, merit-based), workflows con compensations
- **Trade-off:** Learning curve vs 50% menos boilerplate
- **Métricas:** -40% LOC, -30% complexity, -50% bugs esperados

**ADR-002: Reactor vs Oban Simple**
- **Decisión:** Reactor para AI workflows
- **Rationale:** Compensations automáticas, paralelismo (toxicity + depth + coherence)
- **Trade-off:** Complejidad inicial vs robustez
- **Resultado:** Latencia 300ms → 100ms (async steps)

**ADR-003: Float Scores vs Atoms**
- **Decisión:** Floats (0.0-1.0)
- **Rationale:** ML compatibility, matemáticas naturales, thresholds configurables
- **Trade-off:** Menos legible en DB vs precisión
- **Solución:** Calculations para atoms en UI

**ADR-004: Behavioral Hash vs DNI**
- **Decisión:** Behavioral hash
- **Rationale:** Privacy-first, bot detection, multi-accounting detection
- **Trade-off:** 100% accuracy vs privacy total
- **Implementación:** Timing, vocabulary, emotional tone fingerprinting

**ADR-005: Nx/Bumblebee vs OpenAI API**
- **Decisión:** On-premise AI (Nx + Bumblebee)
- **Rationale:** Privacy, costos ($200→$50/mes), latencia (500ms→100ms)
- **Trade-off:** 95% accuracy → 92% (suficiente para KAIROS)
- **Ventaja:** Data never leaves server

**ADR-006: Ash Policies vs Bodyguard**
- **Decisión:** Ash Policies
- **Rationale:** Co-located authorization, field-level nativo, works everywhere
- **Trade-off:** Debugging abstracto vs composabilidad
- **Solución:** `Ash.Policy.Info.describe_resource/1` para debug

**ADR-007: UUIDs v7 vs Integers**
- **Decisión:** UUIDs v7
- **Rationale:** Security (no enumeration), distributed-friendly, time-ordered
- **Trade-off:** 16 bytes vs 4-8 bytes (aceptable)
- **Performance:** UUID v7 performance ≈ integers

#### Filosofía de Diseño

**José Valim:**
- Pragmatismo > Dogmatismo
- "If it makes you 10x productive at 5% performance cost, take it"
- Let it crash (con Reactor compensations)
- Data structures > algorithms

**Zach Daniel:**
- Declarativo > Imperativo
- "Tell Ash what, not how"
- Resources como single source of truth
- Composability + reusability

#### Trade-offs Explícitos

| Aspecto | Ecto | Ash | KAIROS Choice |
|---------|------|-----|---------------|
| Learning Curve | Bajo | Alto | Ash (vale la pena) |
| Boilerplate | Alto | Bajo | Ash (50% menos) |
| Authorization | Manual | Declarativo | Ash (field-level) |
| Workflows | Manual | Reactor | Ash (compensations) |
| SQL Control | Total | Alto | Ash (suficiente) |

### Cómo Usar Este Documento

**Para tech leads:**
- Leer ADRs para entender decisiones fundamentadas
- Revisar trade-offs explícitos
- Validar con métricas propuestas

**Para arquitectos:**
- Estudiar filosofía de diseño
- Comparar opciones (Ash vs Ecto, Cloud vs On-premise)
- Adaptar patterns a otros proyectos

**Para stakeholders:**
- Entender por qué Ash 3.0 (no es "hype")
- Ver estimaciones de costos ($200→$50/mes)
- Validar decisiones de privacy/security

---

## 🛠️ ASH_CODEGEN_GUIDE.md

**Guía Práctica de Implementación con Ash**

### Contenido

#### Referencias Hexdocs

**Links directos:**
- Ash.Resource: https://hexdocs.pm/ash/Ash.Resource.html
- AshPostgres: https://hexdocs.pm/ash_postgres/
- Reactor: https://hexdocs.pm/reactor/
- AshPhoenix: https://hexdocs.pm/ash_phoenix/
- AshAuthentication: https://hexdocs.pm/ash_authentication/

#### Setup Completo Proyecto

**mix.exs completo:**
```elixir
defp deps do
  [
    # Phoenix
    {:phoenix, "~> 1.8.1"},
    {:phoenix_live_view, "~> 1.1.0"},

    # Ash
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},
    {:ash_phoenix, "~> 2.0"},
    {:ash_authentication, "~> 4.0"},

    # AI/ML
    {:nx, "~> 0.7"},
    {:bumblebee, "~> 0.5"},
    {:exla, "~> 0.7"},

    # Background
    {:oban, "~> 2.17"},
    {:reactor, "~> 0.9"}
  ]
end
```

**config/config.exs:**
```elixir
config :kairos,
  ash_domains: [
    Kairos.Accounts,
    Kairos.Merits,
    Kairos.Interactions,
    Kairos.Moderation
  ]
```

**lib/kairos/repo.ex:**
```elixir
defmodule Kairos.Repo do
  use AshPostgres.Repo, otp_app: :kairos

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext"]
  end
end
```

#### Workflow de Desarrollo

**Paso 1: Crear Resource**
```bash
touch lib/kairos/accounts/user.ex
# Definir resource (ver KAIROS_ARCHITECTURE.md)
```

**Paso 2: Agregar al Domain**
```elixir
# lib/kairos/accounts.ex
defmodule Kairos.Accounts do
  use Ash.Domain

  resources do
    resource Kairos.Accounts.User
  end
end
```

**Paso 3: Generar Migración**
```bash
mix ash_postgres.generate_migrations --name create_users
```

**Paso 4: Revisar Migración Generada**
```bash
cat priv/repo/migrations/*_create_users.exs
```

**Paso 5: Ejecutar Migración**
```bash
mix ash_postgres.migrate
```

**Paso 6: Test en IEx**
```elixir
iex -S mix

# Crear usuario
Ash.create!(Kairos.Accounts.User, %{
  username: "jose_valim",
  email: "jose@example.com",
  hashed_password: "..."
})
```

#### Mix Tasks Reference

```bash
# Generar migraciones
mix ash_postgres.generate_migrations --name NAME
mix ash_postgres.generate_migrations --dry-run  # Preview
mix ash_postgres.generate_migrations --check    # CI validation

# Ejecutar migraciones
mix ash_postgres.migrate
mix ash_postgres.migrate --step 1
mix ash_postgres.migrate --to VERSION

# Rollback
mix ash_postgres.rollback
mix ash_postgres.rollback --step 2

# Codegen general
mix ash.codegen --name NAME
```

#### Patrones Avanzados

**Custom SQL:**
```elixir
postgres do
  custom_indexes do
    index ["username gin_trgm_ops"], using: "GIN"
    index [:verification_status], where: "verification_status = 'verified'"
  end

  custom_statements do
    up "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    down "DROP EXTENSION IF EXISTS pg_trgm"
  end
end
```

**Polymorphic Relationships:**
```elixir
attributes do
  attribute :content_type, :string
  attribute :content_id, :uuid
end

calculations do
  calculate :content, :any, LoadPolymorphicContent
end
```

**Multitenancy:**
```elixir
multitenancy do
  strategy :attribute
  attribute :network_id
  global? false
end
```

#### Debugging

**Ver SQL generado:**
```elixir
Ash.Query.to_sql(query)
```

**Dry-run migraciones:**
```bash
mix ash_postgres.generate_migrations --name test --dry-run
```

**Check pending migrations (CI):**
```bash
mix ash_postgres.generate_migrations --check
# Exit 0 = no pending, Exit 1 = pending
```

#### Checklist Setup Completo

```bash
# 1. Crear proyecto
mix phx.new kairos --database postgres --live

# 2. Agregar deps (ver mix.exs arriba)
mix deps.get

# 3. Configurar Ash (config/config.exs)

# 4. Crear Repo (lib/kairos/repo.ex)

# 5. Crear Domains
touch lib/kairos/{accounts,merits,interactions,moderation}.ex

# 6. Crear Resources
touch lib/kairos/accounts/user.ex
# ... (ver KAIROS_ARCHITECTURE.md)

# 7. Generar migraciones
mix ash_postgres.generate_migrations --name initial_schema

# 8. Revisar migraciones
cat priv/repo/migrations/*

# 9. Ejecutar
mix ash_postgres.migrate

# 10. Test
iex -S mix
```

### Cómo Usar Este Documento

**Para desarrolladores nuevos en Ash:**
- Seguir Setup Completo paso a paso
- Leer Referencias Hexdocs
- Practicar con Workflow de Desarrollo

**Para desarrolladores Elixir experimentados:**
- Ver Patrones Avanzados directamente
- Usar Mix Tasks Reference como cheatsheet
- Copiar examples de Custom SQL

**Para CI/CD:**
- Usar `--check` en pipeline
- Setup scripts con Checklist
- Debugging con `--dry-run`

---

## 🎨 Stack Tecnológico

### Frontend

**Phoenix LiveView 1.1**
- Server-rendered real-time
- WebSocket bidireccional
- Function components
- Streams para listas eficientes

**Tailwind CSS + Heroicons**
- Utility-first styling
- Responsive design
- Dark mode support

### Backend

**Elixir 1.16+ / OTP 26+**
- Concurrency (millions of processes)
- Fault tolerance (supervisors)
- Hot code reloading

**Phoenix 1.8.1**
- Web framework
- PubSub para real-time
- Telemetry para monitoring

**Ash 3.0**
- Declarative resources
- Policies (authorization)
- Reactor (workflows)
- Auto-migrations

### Database

**PostgreSQL 16**
- JSONB para behavioral patterns
- GIN indexes para full-text
- Partitioning para escala
- Extensions: uuid-ossp, citext, pg_trgm

### AI/ML

**Nx + Bumblebee**
- On-premise inference
- EXLA compilation (GPU/CPU)
- Model serving con pooling
- Latencia < 100ms

**Modelos:**
- Toxicity: unitary/toxic-bert
- Embeddings: all-MiniLM-L6-v2
- Behavioral: Custom LSTM

### Background

**Oban 2.17**
- Reliable job processing
- Scheduled jobs
- Priority queues

**Reactor**
- Workflow orchestration
- Compensations
- Async steps

---

## 📊 Métricas del Proyecto

### Documentación

```
KAIROS_ARCHITECTURE.md:  ~1,200 líneas
KAIROS_CONSENSOS.md:     ~1,100 líneas
ASH_CODEGEN_GUIDE.md:    ~900 líneas
README_KAIROS.md:        Este documento
─────────────────────────────────────
Total:                   ~3,200+ líneas
```

### Código Esperado (cuando implementado)

```
Resources:               ~2,500 líneas (8 resources × ~300 líneas)
Domains:                 ~200 líneas (4 domains)
Reactors:                ~400 líneas (2-3 workflows)
LiveViews:               ~800 líneas (4 LiveViews principales)
AI modules:              ~600 líneas (Nx/Bumblebee integration)
Tests:                   ~1,500 líneas (coverage > 80%)
Migraciones:             Auto-generadas desde resources
─────────────────────────────────────
Total estimado:          ~6,000 líneas

Comparado con Ecto:      ~10,000 líneas (-40% código)
```

### Performance Targets

```yaml
Latencia:
  - WebSocket p95: < 50ms
  - DB query p99: < 100ms
  - AI inference: < 200ms
  - Page load: < 500ms

Throughput:
  - Concurrent users: 50,000/node
  - Posts/second: 100 (con AI)
  - Messages/second: 10,000

Costos:
  - Infra (2 nodes): $100/mes
  - AI compute: $50/mes
  - Database: $50/mes
  - Total: ~$200/mes (10k usuarios)
```

---

## 🚦 Roadmap de Implementación

### Fase 1: Fundaciones (Semanas 1-4)

**Semana 1-2: Setup**
- [x] Documentación técnica completa
- [ ] Crear proyecto Phoenix
- [ ] Configurar Ash + AshPostgres
- [ ] Setup CI/CD pipeline

**Semana 3-4: Core Resources**
- [ ] Implementar User resource
- [ ] Implementar MeritProfile resource
- [ ] Generar y ejecutar migraciones
- [ ] Tests unitarios básicos

### Fase 2: AI Layer (Semanas 5-8)

**Semana 5-6: Nx/Bumblebee Setup**
- [ ] Integrar Nx + Bumblebee
- [ ] Load modelos (toxicity, embeddings)
- [ ] Setup model serving con pooling
- [ ] Benchmarks de latencia

**Semana 7-8: Reactor Workflows**
- [ ] Implementar PostAnalysisReactor
- [ ] Compensations y retries
- [ ] Integration con Ash Changes
- [ ] Tests de workflows

### Fase 3: LiveView UI (Semanas 9-12)

**Semana 9-10: Core LiveViews**
- [ ] FeedLive (high quality posts)
- [ ] ProfileLive (merit display)
- [ ] AshPhoenix.Form integration
- [ ] Real-time PubSub subscriptions

**Semana 11-12: Conversations**
- [ ] ConversationLive
- [ ] Message streaming
- [ ] Presence tracking
- [ ] Quality indicators real-time

### Fase 4: Production (Semanas 13-16)

**Semana 13-14: Polish**
- [ ] Behavioral verification flow
- [ ] Badge system
- [ ] Email notifications
- [ ] Admin panel

**Semana 15-16: Deploy**
- [ ] Deploy a Fly.io/Render
- [ ] Setup monitoring (telemetry)
- [ ] Load testing
- [ ] Security audit

---

## 🎓 Recursos de Aprendizaje

### Ash Framework

**Official Docs:**
- Ash Framework: https://ash-hq.org/
- Hexdocs: https://hexdocs.pm/ash/
- GitHub: https://github.com/ash-project/ash

**Ejemplos:**
- AshHQ source: https://github.com/ash-project/ash_hq
- Authentication demo: https://github.com/team-alembic/ash_authentication_phoenix_example

**Videos:**
- Zach Daniel talks: https://www.youtube.com/results?search_query=zach+daniel+ash
- ElixirConf presentations

### Phoenix LiveView

**Official:**
- Phoenix LiveView docs: https://hexdocs.pm/phoenix_live_view/
- Pragmatic Studio course: https://pragmaticstudio.com/phoenix-liveview

**Ejemplos:**
- Phoenix LiveView examples: https://github.com/chrismccord/phoenix_live_view_example

### Nx/Bumblebee

**Official:**
- Nx: https://hexdocs.pm/nx/
- Bumblebee: https://hexdocs.pm/bumblebee/
- EXLA: https://hexdocs.pm/exla/

**Resources:**
- José Valim ML livestreams
- Hugging Face models: https://huggingface.co/models

---

## 🤝 Contribuir

### Setup Development

```bash
# Clone repo
git clone https://github.com/ai-libre/sandboxex
cd sandboxex

# Leer documentación
cat README_KAIROS.md
cat KAIROS_ARCHITECTURE.md

# Crear branch
git checkout -b feature/nombre-feature

# Implementar feature siguiendo arquitectura

# Tests
mix test

# Format & Credo
mix format
mix credo --strict

# Commit
git add .
git commit -m "Add feature X"

# Push
git push origin feature/nombre-feature
```

### Estándares de Código

**Elixir:**
- Seguir Elixir style guide
- `mix format` antes de commit
- Credo strict mode pass
- Dialyzer types cuando aplicable

**Ash Resources:**
- DSL declarativo (no código imperativo)
- Policies explícitas
- Calculations documentadas
- Tests de policies

**Commits:**
- Conventional commits
- Mensajes descriptivos
- Referencias a ADRs cuando aplicable

---

## 📞 Contacto y Soporte

### Documentación

**Principal:**
- KAIROS_ARCHITECTURE.md - Arquitectura técnica
- KAIROS_CONSENSOS.md - Decisiones y filosofía
- ASH_CODEGEN_GUIDE.md - Guía de implementación

**Community:**
- Ash Forum: https://elixirforum.com/c/ash-framework/123
- Elixir Forum: https://elixirforum.com/
- Discord: Elixir Lang Discord

### Issues y Preguntas

**GitHub Issues:**
- Bugs: Usar template de bug report
- Features: Usar template de feature request
- Preguntas: Preferir Discussions

**Antes de abrir issue:**
1. Leer documentación relevante
2. Buscar en issues existentes
3. Revisar ADRs para decisiones técnicas

---

## 📝 Licencia

Apache 2.0 - Ver LICENSE para detalles

---

## 🌟 Reconocimientos

**Inspiración Técnica:**
- José Valim (Elixir/Phoenix)
- Zach Daniel (Ash Framework)
- Chris McCord (Phoenix LiveView)

**Frameworks:**
- Ash Framework 3.0
- Phoenix Framework 1.8
- Elixir/OTP

**Comunidad:**
- Elixir community
- Ash Framework community
- Phoenix community

---

## 🎯 Resumen Ejecutivo

### ¿Qué es KAIROS?

Red social pro-humana que prioriza:
- **Autenticidad** (behavioral verification, no DNI)
- **Calidad** (merit-based, no likes)
- **Privacidad** (on-premise AI, no tracking)

### ¿Por qué Ash 3.0?

- 50% menos boilerplate que Ecto
- Authorization declarativa (field-level)
- Workflows con compensations (Reactor)
- Auto-migrations desde resources

### ¿Cuándo estará listo?

**MVP:** 6 meses
- Fase 1: Fundaciones (1 mes)
- Fase 2: AI Layer (1 mes)
- Fase 3: LiveView UI (1 mes)
- Fase 4: Production (1 mes)
- Buffer: 2 meses

### ¿Cuánto cuesta?

**Desarrollo:** 2-3 devs × 6 meses
**Infraestructura:** ~$200/mes (10k usuarios)
**Escalado:** Horizontal (agregar nodos)

---

**Última actualización:** 2025-11-15
**Versión:** 1.0.0
**Status:** ✅ Documentación completa - Ready para implementación

---

**📚 Comienza aquí:**

1. Lee [KAIROS_ARCHITECTURE.md](./KAIROS_ARCHITECTURE.md) para entender la arquitectura
2. Lee [KAIROS_CONSENSOS.md](./KAIROS_CONSENSOS.md) para entender las decisiones
3. Sigue [ASH_CODEGEN_GUIDE.md](./ASH_CODEGEN_GUIDE.md) para implementar

**🚀 Let's build KAIROS!**
