# KAIROS - Implementación con Ash Framework 3.0

Red Social Pro-Humana Asistida por IA

**Status:** ✅ Estructura base implementada - Ready para `mix deps.get`

---

## 📋 Resumen

Este directorio contiene la **implementación inicial** de KAIROS usando:
- Phoenix 1.8.1
- LiveView 1.1
- Ash Framework 3.0
- PostgreSQL 16

**Documentación completa:** Ver archivos en directorio padre (`../`)
- `../KAIROS_ARCHITECTURE.md` - Arquitectura técnica completa
- `../KAIROS_CONSENSOS.md` - ADRs y decisiones técnicas
- `../ASH_CODEGEN_GUIDE.md` - Guía de desarrollo
- `../README_KAIROS.md` - Índice funcional

---

## 🚀 Setup Inicial

### Requisitos

```bash
# Versiones requeridas
elixir >= 1.16.0
erlang >= 26.0
postgresql >= 16.0
```

### Instalación

```bash
# 1. Instalar dependencias
cd kairos/
mix deps.get

# 2. Crear base de datos
mix ash_postgres.create

# 3. Generar migraciones desde resources
mix ash_postgres.generate_migrations --name initial_schema

# 4. Ejecutar migraciones
mix ash_postgres.migrate

# 5. (Opcional) Seeds
mix run priv/repo/seeds.exs

# 6. Iniciar servidor
mix phx.server
```

**Aplicación corriendo en:** http://localhost:4000

---

## 📂 Estructura Implementada

```
kairos/
├── config/
│   ├── config.exs           ✅ Ash domains, ecto repos
│   ├── dev.exs              ✅ Development config
│   ├── test.exs             ✅ Test config
│   └── runtime.exs          ✅ Production config
├── lib/
│   ├── kairos/
│   │   ├── application.ex   ✅ OTP application
│   │   ├── repo.ex          ✅ AshPostgres repo
│   │   ├── accounts.ex      ✅ Accounts domain
│   │   ├── accounts/
│   │   │   └── user.ex      ✅ User resource
│   │   ├── merits.ex        ✅ Merits domain
│   │   ├── merits/
│   │   │   └── profile.ex   ✅ MeritProfile resource
│   │   ├── interactions.ex  ✅ Interactions domain
│   │   ├── interactions/
│   │   │   ├── post.ex      ✅ Post resource
│   │   │   └── conversation.ex  ✅ Conversation resource
│   │   ├── moderation.ex    ✅ Moderation domain
│   │   └── moderation/
│   │       └── violation.ex ✅ Violation resource
│   └── kairos_web/          ⏳ TODO: Phoenix web layer
├── priv/
│   └── repo/
│       └── migrations/      📝 Auto-generadas con mix ash_postgres.generate_migrations
├── test/                    ⏳ TODO: Tests
├── mix.exs                  ✅ Dependencies y aliases
└── README.md                ✅ Este archivo
```

---

## 📦 Resources Implementados

### 1. User Resource (`Kairos.Accounts.User`)

**Features:**
- ✅ UUID primary key
- ✅ Username, email (case-insensitive)
- ✅ Behavioral hash (no DNI)
- ✅ Verification score (0.0 - 1.0)
- ✅ AshAuthentication integrado
- ✅ Calculations: `is_verified`, `trust_level`
- ✅ Policies: Field-level privacy

**Actions:**
- `:register` - Crear usuario con behavioral hash
- `:verify_behavior` - Actualizar verification score
- `:flag_for_review` - Marcar para revisión

**Identities:**
- `unique_username`
- `unique_email`

### 2. MeritProfile Resource (`Kairos.Merits.Profile`)

**Features:**
- ✅ 4 core scores (coherence, non_violence, depth, contribution)
- ✅ Ethical profile (parcialmente oculto)
- ✅ Badges array
- ✅ Calculation: `merit_level` (exemplary, strong, developing, emerging)
- ✅ Pub/Sub notifications

**Actions:**
- `:create` - Crear perfil (auto al registrar usuario)
- `:recalculate_scores` - Actualizar scores con AI
- `:award_badge` - Otorgar badge

**Policies:**
- Usuario ve perfil completo
- Otros ven perfil parcial (sin ethical_profile)

### 3. Post Resource (`Kairos.Interactions.Post`)

**Features:**
- ✅ Content (10-5000 chars)
- ✅ AI scores (depth, coherence, toxicity) - read-only
- ✅ Calculations: `is_high_quality`, `quality_level`
- ✅ Custom indexes para performance
- ✅ Pub/Sub notifications

**Actions:**
- `:create` - Crear post (con AI analysis hook)
- `:update` - Actualizar post
- `:high_quality_feed` - Feed filtrado (depth >= 0.7)
- `:for_user` - Posts de usuario específico

**Policies:**
- Todos leen posts públicos
- Solo verified users crean
- Solo autor edita/borra

### 4. Conversation Resource (`Kairos.Interactions.Conversation`)

**Features:**
- ✅ Title, conversation_type
- ✅ Moderation status (active, monitored, flagged)
- ✅ Quality score
- ✅ Calculation: `is_high_quality`
- ✅ Pub/Sub notifications

**Actions:**
- `:start` - Iniciar conversación
- `:update_quality_score` - Actualizar calidad
- `:flag` - Marcar para revisión

**Pending:**
- Many-to-many participants (requires join table)
- Messages relationship
- Aggregates (message_count, avg_quality)

### 5. Violation Resource (`Kairos.Moderation.Violation`)

**Features:**
- ✅ Polymorphic content reference
- ✅ Violation types (bot, grooming, violence, manipulation, spam)
- ✅ Severity levels (low, medium, high, critical)
- ✅ AI confidence score
- ✅ Evidence JSONB

**Actions:**
- `:create` - Crear violación (sistema only)
- `:escalate_to_human` - Escalar a moderador
- `:for_user` - Violaciones de usuario
- `:pending_review` - Pending revisión

---

## 🎯 Próximos Pasos

### Fase 1: Completar Resources Base

- [ ] Message resource (para conversations)
- [ ] ConversationParticipant join table
- [ ] Aggregates en Conversation (message_count, etc.)
- [ ] Reply resource (para posts)

### Fase 2: Ash Changes & Validations

- [ ] `Kairos.Accounts.Changes.UpdateBehavioralProfile`
- [ ] `Kairos.Accounts.Changes.NotifyModerators`
- [ ] `Kairos.Interactions.Changes.AnalyzePostQuality`
- [ ] `Kairos.Interactions.Validations.ToxicityThreshold`
- [ ] `Kairos.Merits.Changes.RecalculateAllScores`
- [ ] `Kairos.Moderation.Changes.CreateViolation`

### Fase 3: Ash Checks (Policies)

- [ ] `Kairos.Accounts.Checks.IsModerator`
- [ ] `Kairos.Interactions.Checks.UserIsVerified`
- [ ] `Kairos.Interactions.Checks.IsParticipant`
- [ ] `Kairos.Merits.Checks.IsSystemProcess`
- [ ] `Kairos.Moderation.Checks.IsModerator`

### Fase 4: AI Layer (Nx/Bumblebee)

- [ ] `Kairos.AI.ToxicityDetector`
- [ ] `Kairos.AI.DepthAnalyzer`
- [ ] `Kairos.AI.CoherenceAnalyzer`
- [ ] `Kairos.AI.BehaviorAnalyzer`
- [ ] Model serving con Nx.Serving (pooling)

### Fase 5: Reactor Workflows

- [ ] `Kairos.Reactors.PostAnalysisReactor`
- [ ] Integration con Ash Changes
- [ ] Compensations setup

### Fase 6: Phoenix Web Layer

- [ ] LiveView layouts
- [ ] `KairosWeb.FeedLive`
- [ ] `KairosWeb.ProfileLive`
- [ ] `KairosWeb.ConversationLive`
- [ ] AshPhoenix.Form integration
- [ ] Real-time PubSub subscriptions

### Fase 7: Tests

- [ ] Resource unit tests
- [ ] Policy tests
- [ ] Integration tests
- [ ] AI model tests

---

## 🛠️ Comandos Útiles

### Development

```bash
# Generar nueva migración después de cambiar resources
mix ash_postgres.generate_migrations --name nombre_descriptivo

# Ver migración sin crearla (dry-run)
mix ash_postgres.generate_migrations --name test --dry-run

# Ejecutar migraciones
mix ash_postgres.migrate

# Rollback última migración
mix ash_postgres.rollback

# Rollback N migraciones
mix ash_postgres.rollback --step N

# Reset completo (drop + migrate)
mix ash.reset
```

### Testing

```bash
# Correr todos los tests
mix test

# Test específico
mix test test/kairos/accounts/user_test.exs

# Con coverage
mix coveralls
```

### Code Quality

```bash
# Format code
mix format

# Static analysis
mix credo --strict

# Type checking (cuando agregues typespecs)
mix dialyzer
```

### IEx Console

```bash
# Iniciar con app cargada
iex -S mix

# Ejemplo: Crear usuario
iex> Ash.create!(Kairos.Accounts.User, %{
...>   username: "jose_valim",
...>   email: "jose@example.com",
...>   password: "securepassword123"
...> })

# Ejemplo: Leer usuarios
iex> Ash.read!(Kairos.Accounts.User)

# Ejemplo: High quality feed
iex> Ash.read!(Kairos.Interactions.Post, action: :high_quality_feed)
```

---

## 📖 Documentación

### Ash Framework

- **Official:** https://ash-hq.org/
- **Hexdocs:** https://hexdocs.pm/ash/
- **Guides:** https://hexdocs.pm/ash/get-started.html

### Recursos KAIROS

- `../KAIROS_ARCHITECTURE.md` - Arquitectura completa
- `../KAIROS_CONSENSOS.md` - ADRs y decisiones
- `../ASH_CODEGEN_GUIDE.md` - Workflow de desarrollo

---

## ⚠️ TODOs Importantes

### Implementar en Orden de Prioridad

1. **Phoenix Web Layer** - Sin esto no hay UI
2. **Ash Changes** - Para AI analysis automático
3. **Ash Checks** - Para policies funcionales
4. **AI Layer (Nx)** - Para scores reales
5. **Reactor Workflows** - Para workflows complejos
6. **Tests** - Para confidence en producción

### Notas de Implementación

**User Resource:**
- Behavioral hash actualmente genera random string
- Necesita implementar `Kairos.Accounts.BehavioralAnalyzer.generate_initial_hash/0`

**Post Resource:**
- AI scores están como `writable?: false`
- Necesita change para actualizar scores después de crear

**Conversation Resource:**
- Many-to-many participants pending
- Necesita crear join table migration

**Policies:**
- Varios checks están commented (IsModerator, UserIsVerified, etc.)
- Usar `authorize_if always()` temporal hasta implementar checks

---

## 🎯 Estado Actual

### ✅ Completado

- [x] Proyecto Phoenix 1.8.1 structure
- [x] Ash 3.0 configuration
- [x] 4 Ash Domains
- [x] 5 Ash Resources (User, MeritProfile, Post, Conversation, Violation)
- [x] mix.exs con todas las deps
- [x] config/ completo (dev, test, runtime)
- [x] Repo con extensions
- [x] README con setup instructions

### ⏳ Pendiente

- [ ] Phoenix web layer (controllers, LiveViews)
- [ ] Ash Changes & Validations
- [ ] Ash Checks (policies)
- [ ] AI layer (Nx/Bumblebee)
- [ ] Reactor workflows
- [ ] Tests
- [ ] Seeds
- [ ] CI/CD setup

### 📊 Métricas

```
Files creados:   ~20
Líneas de código: ~1,500
Resources:       5 (User, MeritProfile, Post, Conversation, Violation)
Domains:         4 (Accounts, Merits, Interactions, Moderation)
```

---

## 🚀 Deploy

**Cuando esté listo para producción:**

Ver `../README_KAIROS.md` sección "Roadmap de Implementación"

**Providers recomendados:**
- Fly.io (Elixir-friendly)
- Render
- Railway

**Requisitos producción:**
- DATABASE_URL env var
- SECRET_KEY_BASE env var
- Mix release build

---

## 📝 Licencia

Apache 2.0 - Ver LICENSE en directorio padre

---

## 🙏 Créditos

**Arquitectura diseñada con principios de:**
- José Valim (Elixir/Phoenix)
- Zach Daniel (Ash Framework)

**Frameworks:**
- Ash Framework 3.0
- Phoenix 1.8.1
- LiveView 1.1

---

**¿Listo para continuar?**

```bash
cd kairos/
mix deps.get
mix ash_postgres.create
mix ash_postgres.generate_migrations --name initial_schema
mix ash_postgres.migrate
mix phx.server
```

🚀 **Let's build KAIROS!**
