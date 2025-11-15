# KAIROS - Consensos Técnicos y Decisiones de Arquitectura

**Estilo:** José Valim (Elixir/OTP) + Zach Daniel (Ash Framework)
**Principio:** Decisiones fundamentadas, trade-offs explícitos, pragmatismo sobre dogmatismo

---

## 📐 ADR (Architecture Decision Records)

### ADR-001: Ash 3.0 como framework core (no Ecto contexts tradicionales)

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15
**Decisores:** Equipo técnico KAIROS

#### Contexto

KAIROS requiere:
1. **Authorization compleja** basada en méritos y comportamiento
2. **Workflows de AI** con múltiples steps y compensations
3. **Real-time updates** para feeds, conversaciones, merit changes
4. **Field-level privacy** (ethical_profile parcialmente oculto)
5. **Calculations dinámicos** (merit_level, trust_level, quality_level)

**Opciones consideradas:**

**Opción A: Ecto + Phoenix Contexts (tradicional)**
```elixir
# Pros:
- Familiar para equipo Phoenix
- Documentación abundante
- Control total sobre SQL

# Contras:
- Authorization manual (repetitivo)
- Changesets manuales para cada action
- Policies dispersas en múltiples módulos
- Workflows complejos requieren sagas manuales
- Field-level access control custom
```

**Opción B: Ash 3.0**
```elixir
# Pros:
- Policies declarativas (field-level nativo)
- Actions con validations/changes integradas
- Reactor para workflows complejos (compensations automáticas)
- Calculations y aggregates optimizados
- Pub/Sub integrado
- Migraciones auto-generadas desde resources

# Contras:
- Curva de aprendizaje (paradigma declarativo)
- Menos familiar para equipo tradicional Phoenix
- Debugging más abstracto
- Menor control directo sobre SQL
```

#### Decisión

**Elegimos Ash 3.0** porque:

1. **Authorization es crítica para KAIROS**
   - Merit-based gates (`authorize_if UserIsVerified`)
   - Field-level privacy (`forbid_if accessing_field(:ethical_profile)`)
   - Relationship-based (`relates_to_actor_via(:user)`)
   - **En Ecto:** Requeriría Bodyguard + custom field filters en cada query

2. **Workflows de AI necesitan compensations**
   - Reactor maneja rollbacks automáticos
   - Steps async paralelos (toxicity + depth + coherence)
   - **En Ecto:** Sagas manuales con Ecto.Multi (más código, más bugs)

3. **Calculations dinámicos son core**
   - `merit_level`, `trust_level`, `quality_level`
   - Ash calcula on-the-fly con SQL optimizado
   - **En Ecto:** Virtual fields o preloads custom

4. **Reducción de boilerplate**
   ```elixir
   # Ash: 1 resource = schema + changesets + actions + policies
   # Ecto: N archivos (schema, context, changesets, policies custom)

   # KAIROS tiene 8+ resources → Ash ahorra ~2000 líneas de boilerplate
   ```

#### Consecuencias

**Positivas:**
- Código más declarativo y conciso
- Authorization centralizada en resources
- Workflows robustos con compensations
- Field-level privacy nativa

**Negativas:**
- Equipo debe aprender paradigma Ash
- Debugging requiere entender Ash internals
- Migraciones menos control directo

**Mitigación:**
- Training en Ash 3.0 para equipo
- Usar `Ash.Query.to_sql/1` para debug
- Migraciones custom cuando necesario con `migration_ignore/1`

---

### ADR-002: Reactor para workflows de AI (no Oban jobs simples)

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15

#### Contexto

Análisis de posts requiere:
1. Toxicity detection (Nx/Bumblebee)
2. Depth analysis (embedding similarity)
3. Coherence check (vs baseline del usuario)
4. Update post scores
5. Update user merit profile
6. Check badge eligibility

**Si falla step 3** → rollback steps 1-2 ✓
**Si falla step 5** → rollback steps 1-4 ✓

**Opciones consideradas:**

**Opción A: Oban jobs simples**
```elixir
defmodule AnalyzePostWorker do
  use Oban.Worker

  def perform(%{args: %{"post_id" => post_id}}) do
    # 1. Toxicity
    toxicity = AI.ToxicityDetector.analyze(post.content)

    # 2. Depth
    depth = AI.DepthAnalyzer.analyze(post.content)

    # 3. Coherence - ¿QUÉ PASA SI ESTO FALLA?
    coherence = AI.CoherenceAnalyzer.analyze(...)

    # Ya tenemos toxicity y depth en DB...
    # ¿Cómo rollback? ❌
  end
end
```

**Problemas:**
- No hay compensations automáticas
- Rollback manual (propenso a errores)
- No hay paralelismo nativo (toxicity + depth podrían correr en paralelo)
- Estado disperso (¿dónde guardamos resultados parciales?)

**Opción B: Reactor**
```elixir
defmodule PostAnalysisReactor do
  use Reactor

  # Steps con async: true corren en paralelo
  step :analyze_toxicity, async?: true
  step :analyze_depth, async?: true
  step :analyze_coherence, async?: true

  # Compensations automáticas
  step :update_post_scores do
    run fn args, _context ->
      # ...
    end

    compensate fn args, _context ->
      # Rollback automático si falla step posterior
      Ash.update(args.post, %{toxicity_score: nil, ...})
    end
  end
end
```

**Ventajas:**
- Compensations declarativas
- Paralelismo con `async?: true`
- DAG (Directed Acyclic Graph) clear
- Retry logic por step
- Telemetry integrado

#### Decisión

**Elegimos Reactor** porque:

1. **Compensations son críticas**
   - Si falla badge check, debemos revertir merit updates
   - Reactor maneja el rollback automático

2. **Paralelismo reduce latencia**
   ```elixir
   # Sin paralelismo: 300ms (100ms + 100ms + 100ms)
   # Con async?: 100ms (paralelo)
   ```

3. **DAG clear = mantenibilidad**
   - Visualización clara de dependencias
   - Fácil agregar/remover steps

4. **Integración perfecta con Ash**
   - Reactor viene con Ash 3.0
   - `Ash.update` en steps

#### Consecuencias

**Positivas:**
- Workflows robustos
- Latencia reducida (async steps)
- Rollbacks automáticos

**Negativas:**
- Complejidad inicial (DAG thinking)
- Overhead mínimo vs Oban simple

**Mitigación:**
- Documentar cada Reactor con diagrama
- Tests unitarios por step
- Usar Oban para jobs sin compensations (ej: email notifications)

---

### ADR-003: Merit scores como floats (no integers o atoms)

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15

#### Contexto

Merit scores necesitan:
- **Precisión:** Distinguir 0.75 vs 0.76
- **Matemáticas:** Promedios, weighted sums
- **Comparaciones:** `> 0.7` para gates

**Opciones consideradas:**

**Opción A: Atoms (`:low`, `:medium`, `:high`)**
```elixir
# Pros:
- Legibles
- Pattern matching

# Contras:
- No hay matemáticas (¿cómo promediar :low + :high?)
- Pérdida de granularidad
- Cambiar thresholds requiere migración
```

**Opción B: Integers (0-100)**
```elixir
# Pros:
- Matemáticas posibles
- Familiar (porcentajes)

# Contras:
- Menos precisión que floats
- No hay standard (¿0-100? ¿0-1000?)
```

**Opción C: Floats (0.0 - 1.0)**
```elixir
# Pros:
- Precisión máxima
- Standard ML (todos los modelos retornan 0.0-1.0)
- Matemáticas naturales
- Thresholds configurables sin migración

# Contras:
- Menos legible que atoms
```

#### Decisión

**Elegimos floats (0.0 - 1.0)** porque:

1. **ML models retornan floats**
   ```elixir
   Bumblebee toxicity model → %{score: 0.847}
   # No conversion needed ✓
   ```

2. **Matemáticas naturales**
   ```elixir
   # Weighted average
   new_score = current_score * 0.9 + new_value * 0.1

   # Threshold gates
   depth_score >= 0.7  # Claro y preciso
   ```

3. **Thresholds configurables**
   ```elixir
   # Cambiar threshold NO requiere migración
   config :kairos, high_quality_threshold: 0.75  # Antes: 0.70
   ```

4. **Mostramos atoms al usuario**
   ```elixir
   # DB: float (precisión)
   coherence_score: 0.847

   # UI: atom (legibilidad)
   calculate :merit_level, :atom do
     calculation fn records ->
       Enum.map(records, fn r ->
         avg = (r.coherence + r.depth + ...) / 4
         cond do
           avg >= 0.8 -> :exemplary
           avg >= 0.6 -> :strong
           avg >= 0.4 -> :developing
           true -> :emerging
         end
       end)
     end
   end
   ```

#### Consecuencias

**Positivas:**
- Compatibilidad directa con ML
- Flexibilidad en thresholds
- Matemáticas precisas

**Negativas:**
- Menos legible en DB raw (0.75 vs `:high`)

**Mitigación:**
- Calculations para atoms en UI
- Constraints en attributes: `min: 0.0, max: 1.0`

---

### ADR-004: Behavioral hash (no identity legal)

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15

#### Contexto

KAIROS verifica **consistencia de comportamiento**, NO identidad legal.

**Problema:** Bots, trolls, cuentas múltiples.

**Opciones consideradas:**

**Opción A: Verificación por documento (DNI, pasaporte)**
```elixir
# Pros:
- Identidad real comprobable
- Standard en redes sociales

# Contras:
- Privacy concerns (GDPR)
- Burocracia
- Discrimina usuarios sin documentos
- NO previene trolls (misma persona, múltiples documentos)
```

**Opción B: Email/Phone verification**
```elixir
# Pros:
- Fácil implementar
- Standard

# Contras:
- Emails/phones desechables
- NO previene bots sofisticados
```

**Opción C: Behavioral hash**
```elixir
# Hash basado en:
# - Timing patterns (velocidad de escritura)
# - Vocabulary fingerprint (palabras únicas)
# - Emotional tone consistency
# - Interaction patterns

behavioral_hash = :crypto.hash(:sha256, serialized_patterns)
```

**Pros:**
- Privacy-preserving (no PII)
- Detecta bots (patrones no-humanos)
- Detecta cuentas múltiples (mismo behavioral hash)
- Dinámico (evoluciona con el usuario)

**Contras:**
- No es 100% preciso
- Requiere AI analysis

#### Decisión

**Elegimos behavioral hash** porque:

1. **Alineado con valores KAIROS**
   - Privacidad sobre burocracia
   - Autenticidad sobre identidad legal

2. **Más efectivo contra bots**
   ```elixir
   # Bot patterns:
   # - Timing demasiado regular (50ms entre chars)
   # - Vocabulary limitado (100 palabras únicas)
   # - Zero emotional variance

   # Humano:
   # - Timing variable (50-200ms)
   # - Vocabulary rico (1000+ palabras)
   # - Emotional range alto
   ```

3. **GDPR compliant**
   - No almacenamos PII
   - Hash es one-way
   - Derecho al olvido fácil (delete user → delete hash)

4. **Detecta multi-accounting**
   ```elixir
   # Dos usuarios con mismo behavioral_hash (>95% similarity)
   # → Flagged para review
   ```

#### Implementación

```elixir
defmodule Kairos.Accounts.BehavioralAnalyzer do
  def generate_hash(user_id) do
    patterns = %{
      typing_speed: analyze_typing_speed(user_id),
      vocabulary: analyze_vocabulary(user_id),
      emotional_tone: analyze_emotional_consistency(user_id),
      interaction_timing: analyze_interaction_patterns(user_id)
    }

    serialized = Jason.encode!(patterns, sort_keys: true)
    :crypto.hash(:sha256, serialized) |> Base.encode16()
  end

  def similarity(hash1, hash2) do
    # Hamming distance para detectar cuentas similares
    # Returns 0.0 - 1.0
  end
end
```

#### Consecuencias

**Positivas:**
- Privacy-first verification
- Efectivo contra bots
- Multi-accounting detection

**Negativas:**
- False positives posibles (usuarios muy similares)
- Requiere análisis continuo

**Mitigación:**
- Human review para flags
- Threshold alto para auto-ban (>0.98 similarity)
- Re-analysis periódico (behavioral drift)

---

### ADR-005: On-premise AI (Nx/Bumblebee) vs Cloud APIs

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15

#### Contexto

AI analysis necesita:
1. Toxicity detection
2. Depth/coherence analysis
3. Behavioral pattern analysis

**Opciones consideradas:**

**Opción A: Cloud APIs (OpenAI, Anthropic, Cohere)**
```elixir
# Pros:
- State-of-the-art models
- No infra management
- Fácil setup

# Contras:
- Costos variables ($$$)
- Data privacy (contenido sale del servidor)
- Latencia network (200-500ms)
- Vendor lock-in
- Rate limits externos
```

**Opción B: Nx + Bumblebee (on-premise)**
```elixir
# Pros:
- Privacy total (data never leaves)
- Costos predecibles (compute only)
- Baja latencia (50-100ms local)
- No rate limits
- BEAM-native (concurrency gratis)

# Contras:
- Modelos más pequeños (vs GPT-4)
- Infra management (GPU opcional)
- Menor precisión en algunos casos
```

#### Decisión

**Elegimos Nx + Bumblebee** porque:

1. **Privacy es core value de KAIROS**
   ```elixir
   # Usuario escribe post → Análisis local → Scores guardados
   # NUNCA sale a API externa ✓
   ```

2. **Costos predecibles**
   ```elixir
   # Cloud API: $0.002 por análisis × 100k posts/mes = $200/mes
   # + scaling costs

   # Nx: CPU/GPU compute (fijo) ~$50/mes
   # Escala horizontalmente (más nodos BEAM)
   ```

3. **Latencia baja**
   ```elixir
   # OpenAI API: 200-500ms (network + queue)
   # Nx local: 50-100ms (inference only)

   # Para real-time moderation, latencia crítica
   ```

4. **BEAM concurrency**
   ```elixir
   # Nx.Serving con pool
   {:ok, serving} = Nx.Serving.start_link(
     serving: toxicity_serving,
     name: ToxicityServing,
     batch_size: 32,  # Batch automático
     batch_timeout: 100
   )

   # 1000 requests simultáneos → batching automático
   # BEAM scheduler maneja backpressure
   ```

5. **Precisión suficiente**
   ```elixir
   # Toxicity detection:
   # - OpenAI GPT-4: 95% accuracy
   # - Bumblebee (BERT): 92% accuracy

   # Para KAIROS: 92% es suficiente (human review para edge cases)
   ```

#### Implementación

```elixir
defmodule Kairos.AI.ModelPool do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Load models on startup
    {:ok, toxicity_model} = Bumblebee.load_model({:hf, "unitary/toxic-bert"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "unitary/toxic-bert"})

    toxicity_serving = Bumblebee.Text.text_classification(
      toxicity_model,
      tokenizer,
      compile: [batch_size: 32, sequence_length: 512],
      defn_options: [compiler: EXLA]  # GPU acceleration
    )

    {:ok, _pid} = Nx.Serving.start_link(
      serving: toxicity_serving,
      name: ToxicityServing,
      batch_size: 32
    )

    # Similar para depth, coherence...

    {:ok, %{models_loaded: true}}
  end
end

# Usage
Nx.Serving.batched_run(ToxicityServing, post.content)
# → %{predictions: [%{label: "toxic", score: 0.05}]}
```

#### Consecuencias

**Positivas:**
- Privacy total
- Costos predecibles y bajos
- Latencia < 100ms
- Escalabilidad BEAM nativa

**Negativas:**
- Modelos menos potentes que GPT-4
- Requiere manage de modelos
- GPU opcional para velocidad

**Mitigación:**
- Human-in-the-loop para casos complejos
- Fine-tuning de modelos para dominio KAIROS
- EXLA para CPU optimization (si no GPU)
- Monitores para model drift

---

### ADR-006: Policies en Resources (no middleware custom)

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15

#### Contexto

Authorization en KAIROS es compleja:
- Field-level (ethical_profile oculto)
- Merit-based (solo verified users can post)
- Relationship-based (solo participants leen conversación)

**Opciones consideradas:**

**Opción A: Phoenix Plugs + Bodyguard**
```elixir
defmodule KairosWeb.PostController do
  plug :authorize_post when action in [:update, :delete]

  defp authorize_post(conn, _opts) do
    post = conn.assigns.post
    user = conn.assigns.current_user

    if Bodyguard.permit?(Posts, :update, user, post) do
      conn
    else
      conn |> put_status(403) |> halt()
    end
  end
end

# Policies en módulos separados
defimpl Bodyguard.Policy, for: Posts do
  def authorize(:update, %User{id: user_id}, %Post{user_id: post_user_id}) do
    user_id == post_user_id
  end
end
```

**Problemas:**
- Policies dispersas (plugs, policies, guards)
- Field-level access manual
- No reutilizable fuera de controller
- Testing requiere múltiples setups

**Opción B: Ash Policies**
```elixir
defmodule Kairos.Interactions.Post do
  use Ash.Resource

  policies do
    # Centralized, declarative

    policy action_type(:update) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:read) do
      forbid_if accessing_field(:interaction_quality)
    end
  end
end
```

**Ventajas:**
- Policies en resource (co-located)
- Field-level nativo
- Funciona en GraphQL, JSON:API, LiveView
- Testing integrado

#### Decisión

**Elegimos Ash Policies** porque:

1. **Co-location**
   ```elixir
   # Todo en 1 resource:
   # - Attributes
   # - Relationships
   # - Actions
   # - Policies ✓

   # Cambias attribute → ves policies afectadas inmediatamente
   ```

2. **Field-level access**
   ```elixir
   # En Bodyguard: Manual filter en cada query
   # En Ash:
   forbid_if accessing_field(:ethical_profile)
   # Ash filtra automáticamente el campo
   ```

3. **Composabilidad**
   ```elixir
   # Checks reutilizables
   defmodule Kairos.Checks.IsVerified do
     use Ash.Policy.SimpleCheck

     def match?(_actor, _opts, _context), do: true

     def check(actor, _opts, _context) do
       actor.verification_status == :verified
     end
   end

   # Usar en múltiples resources
   authorize_if Kairos.Checks.IsVerified
   ```

4. **Works everywhere**
   ```elixir
   # LiveView
   Ash.read(Post, actor: current_user)

   # GraphQL
   Absinthe.run(query, schema, context: %{actor: current_user})

   # JSON:API
   AshJsonApi.read(Post, actor: current_user)

   # Policies apply everywhere ✓
   ```

#### Implementación

```elixir
defmodule Kairos.Interactions.Post do
  policies do
    # Bypass policies for system processes
    bypass always() do
      authorize_if Kairos.Checks.IsSystemProcess
    end

    # Public read (pero con field restrictions)
    policy action_type(:read) do
      authorize_if always()

      # Hide internal metrics
      forbid_if accessing_field(:interaction_quality)
    end

    # Create requires verification
    policy action_type(:create) do
      authorize_if Kairos.Checks.IsVerified
      authorize_if Kairos.Checks.MeritAboveThreshold, threshold: 0.4
    end

    # Update/delete only by author
    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via(:user)
      authorize_if Kairos.Checks.IsModerator
    end
  end
end
```

#### Consecuencias

**Positivas:**
- Authorization centralizada
- Field-level nativo
- Reutilizable cross-interface

**Negativas:**
- Debugging más abstracto

**Mitigación:**
- `Ash.Policy.Info.describe_resource(Post)` para debug
- Tests de policies explícitos
- Logs de authorization failures

---

### ADR-007: UUIDs como primary keys (no integers)

**Status:** ✅ Aceptado
**Fecha:** 2025-11-15

#### Contexto

Primary keys para users, posts, conversations...

**Opciones consideradas:**

**Opción A: Integers auto-increment**
```elixir
# Pros:
- Familiar
- Menor storage (4-8 bytes)
- Sequential = mejor performance en algunos índices

# Contras:
- Enumeration attack (user/1, user/2, ...)
- Sharding difícil (collisions)
- Merge de DBs complicado
```

**Opción B: UUIDs (v7 preferido)**
```elixir
# Pros:
- Globally unique (sin coordinación)
- No enumeration attack
- Merge de DBs trivial
- Sharding-friendly
- UUID v7 = time-ordered (index performance)

# Contras:
- Mayor storage (16 bytes)
- Menos legible en logs
```

#### Decisión

**Elegimos UUIDs (v7)** porque:

1. **Security**
   ```elixir
   # Integer: user/1, user/2, user/3
   # → Attacker enumera todos los usuarios

   # UUID: user/018c5e4e-9a7c-7a3e-8e4f-1a2b3c4d5e6f
   # → No enumerable ✓
   ```

2. **Distributed-friendly**
   ```elixir
   # Multi-node setup:
   # - Integer: Coordinación required
   # - UUID: Generate localmente, sin conflictos ✓
   ```

3. **UUID v7 performance**
   ```elixir
   # UUID v4: Random → index fragmentation
   # UUID v7: Time-ordered → sequential writes ✓

   # PostgreSQL UUID v7 performance ~ integer auto-increment
   ```

4. **Merge scenarios**
   ```elixir
   # Dev DB + Staging DB → Production
   # Integer: Collisions ❌
   # UUID: No collisions ✓
   ```

#### Implementación

```elixir
# Ash resource
defmodule Kairos.Accounts.User do
  use Ash.Resource

  attributes do
    uuid_primary_key :id  # UUID v7 by default en Ash 3.0
  end
end

# PostgreSQL
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Ash genera UUID v7 en application layer
  ...
);
```

#### Consecuencias

**Positivas:**
- Security (no enumeration)
- Distributed-friendly
- Merge-friendly

**Negativas:**
- Storage overhead (~12 bytes extra per row)
- URLs más largas

**Mitigación:**
- UUID v7 para performance
- Slugs para URLs user-facing (`/u/jose-valim` en vez de `/u/018c5e...`)

---

## 🧠 Filosofía de Diseño

### Pragmatismo sobre Dogmatismo

**José Valim:**
> "Elixir is about being productive. If a feature makes you 10x more productive at the cost of 5% performance, take it."

**Aplicado a KAIROS:**

```elixir
# Dogma: "Nunca uses macros"
# Pragmatismo: Ash usa macros para DSL declarativo
# → Resultado: Código 50% más conciso

defmodule User do
  use Ash.Resource  # Macro que genera código

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string  # Case-insensitive
  end
end

# Equivalente sin macros: ~200 líneas de boilerplate
```

### Declarativo > Imperativo (cuando aplica)

**Zach Daniel:**
> "Tell Ash what you want, not how to do it."

**Aplicado a KAIROS:**

```elixir
# Imperativo (Ecto)
def high_quality_posts do
  from p in Post,
    where: p.depth_score >= 0.7,
    where: p.toxicity_score < 0.3,
    order_by: [desc: p.depth_score, desc: p.inserted_at],
    preload: [:user, :merit_profile]
end

# Declarativo (Ash)
read :high_quality_feed do
  filter expr(depth_score >= 0.7 and toxicity_score < 0.3)
  prepare build(sort: [depth_score: :desc, inserted_at: :desc])
end

# Ash optimiza la query automáticamente
# + agrega field-level filtering
# + aplica policies
```

### Let It Crash (pero con compensations)

**José Valim (OTP):**
> "Let it crash. Supervisors will restart it."

**Aplicado a KAIROS + Reactor:**

```elixir
# Si toxicity analysis crashea:
# - Supervisor restarta el process ✓
# - Reactor compensa (rollback post scores) ✓
# - User recibe error claro ✓

defmodule PostAnalysisReactor do
  step :analyze_toxicity do
    run fn args ->
      # Si crashea → supervisor maneja
      Kairos.AI.ToxicityDetector.analyze(args.post.content)
    end

    # Si análisis posterior falla → compensa
    compensate fn args ->
      # Rollback toxicity score
      Ash.update(args.post, %{toxicity_score: nil})
    end
  end
end
```

### Data Structures > Algorithms

**José Valim:**
> "Choose the right data structure and the algorithms become trivial."

**Aplicado a KAIROS:**

```elixir
# Merit calculation: ¿Map o struct?

# Opción A: Map anidado (flexible pero error-prone)
merit_data = %{
  scores: %{
    coherence: 0.8,
    depth: 0.7
  }
}
# Acceso: merit_data[:scores][:coherence]  # Puede ser nil ❌

# Opción B: Struct (typed, compiler-checked)
defmodule MeritProfile do
  use Ash.Resource

  attributes do
    attribute :coherence_score, :float, constraints: [min: 0.0, max: 1.0]
    attribute :depth_score, :float, constraints: [min: 0.0, max: 1.0]
  end
end

# Acceso: profile.coherence_score  # Type-safe ✓
# Ash valida constraints al escribir ✓
```

---

## 🔍 Trade-offs Explícitos

### Ash vs Ecto

| Aspecto | Ecto | Ash | KAIROS Choice |
|---------|------|-----|---------------|
| **Learning Curve** | Bajo | Alto | Ash (vale la pena) |
| **Boilerplate** | Alto | Bajo | Ash (50% menos código) |
| **Authorization** | Manual | Declarativo | Ash (field-level nativo) |
| **Workflows** | Manual | Reactor | Ash (compensations) |
| **SQL Control** | Total | Alto | Ash (suficiente) |
| **Debugging** | Directo | Abstracto | Ash (logs mejoran) |

**Conclusión:** Ash para KAIROS porque authorization y workflows son críticos.

### On-premise AI vs Cloud

| Aspecto | Cloud APIs | Nx/Bumblebee | KAIROS Choice |
|---------|-----------|--------------|---------------|
| **Privacy** | Baja | Alta | Nx (core value) |
| **Costs** | Variable | Fijo | Nx ($200 → $50/mes) |
| **Latency** | 200-500ms | 50-100ms | Nx (real-time) |
| **Accuracy** | 95% | 92% | Nx (suficiente) |
| **Maintenance** | Ninguna | Media | Nx (manageable) |

**Conclusión:** Nx para KAIROS porque privacy y costos son críticos.

### UUIDs vs Integers

| Aspecto | Integers | UUIDs | KAIROS Choice |
|---------|----------|-------|---------------|
| **Storage** | 4-8 bytes | 16 bytes | UUIDs (acceptable) |
| **Security** | Baja | Alta | UUIDs (no enum) |
| **Performance** | Alta | Alta (v7) | UUIDs (v7 time-ordered) |
| **Distributed** | Complejo | Trivial | UUIDs (multi-node) |

**Conclusión:** UUIDs para KAIROS porque security y distributed-friendliness.

---

## 📊 Métricas de Decisiones

### ¿Cómo medimos si las decisiones fueron correctas?

**1. Code Metrics**
```elixir
# Target (vs Ecto baseline):
- Lines of code: -40%
- Cyclomatic complexity: -30%
- Test coverage: +10%
- Bug rate: -50%
```

**2. Performance Metrics**
```elixir
# Target:
- p95 latency: < 100ms (AI analysis)
- p99 DB query: < 50ms (Ash optimizations)
- Throughput: 10k posts/sec analyzed
```

**3. Developer Metrics**
```elixir
# Target:
- New feature time: -30% (Ash boilerplate reduction)
- Bug fix time: -20% (declarative clearer)
- Onboarding time: +50% (Ash learning curve)
```

**4. Business Metrics**
```elixir
# Target:
- Infrastructure costs: -60% (on-premise AI)
- Violation detection: 90%+ accuracy
- User trust: 80%+ users verified
```

---

## 🎯 Próximas Decisiones Pendientes

### PDR-001: GraphQL vs JSON:API vs Phoenix Controller REST

**Status:** 🤔 En discusión

**Contexto:**
- Ash soporta ambos out-of-the-box
- Frontend podría ser LiveView (no necesita API) o SPA (necesita API)

**Opciones:**
- **LiveView-first**: No API, todo server-rendered
- **GraphQL**: Ash + Absinthe
- **JSON:API**: AshJsonApi

**Decisión:** Pendiente frontend choice

---

### PDR-002: Multi-tenancy (necesario?)

**Status:** 🤔 En discusión

**Contexto:**
- ¿KAIROS tendrá múltiples "redes" independientes?
- ¿O una sola red global?

**Si multi-tenancy:**
```elixir
defmodule Kairos.Accounts.User do
  use Ash.Resource

  multitenancy do
    strategy :attribute
    attribute :network_id
  end
end
```

**Decisión:** Pendiente business model

---

## ✅ Resumen de Consensos

| # | Decisión | Rationale | Trade-off Aceptado |
|---|----------|-----------|-------------------|
| **ADR-001** | Ash 3.0 | Authorization + Workflows | Learning curve |
| **ADR-002** | Reactor | Compensations + Paralelismo | Complejidad inicial |
| **ADR-003** | Float scores | ML compatibility | Menos legible |
| **ADR-004** | Behavioral hash | Privacy + Anti-bot | False positives |
| **ADR-005** | Nx/Bumblebee | Privacy + Costos | Menor accuracy |
| **ADR-006** | Ash Policies | Field-level + Composable | Debug abstracto |
| **ADR-007** | UUIDs v7 | Security + Distributed | Storage overhead |

---

**Última actualización:** 2025-11-15
**Próxima revisión:** Post-MVP (evaluar decisiones con data real)

**Mantener pragmatismo:**
> "Estas decisiones son válidas HOY con la información que tenemos.
> Si aprendemos algo nuevo, revisamos sin dogma." — Filosofía KAIROS
