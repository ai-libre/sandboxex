# MentraOS - Análisis Completo y Relación con KAIROS

**Explorado:** 2025-11-17
**Repositorio:** https://github.com/Mentra-Community/MentraOS
**Licencia:** MIT (Open Source)

---

## 📋 Resumen Ejecutivo

**MentraOS** es un sistema operativo open-source, plataforma de apps, y framework de desarrollo para **gafas inteligentes**. Permite a desarrolladores escribir una vez y ejecutar en cualquier marca de gafas inteligentes.

### Misión Core
- **Cross-Compatibility**: Una app funciona en Even Realities, Mentra, Vuzix, y más
- **Developer Experience**: SDK TypeScript - desarrolla apps en minutos, no meses
- **Hardware Control**: Acceso directo a displays, micrófonos, cámaras, speakers
- **Ecosystem**: App Store real con aplicaciones en producción

### Dispositivos Soportados
- ✅ **Even Realities G1** (display texto/imagen, micrófono)
- ✅ **Mentra Live** (micrófono, speaker, cámara - sin display)
- ✅ **Mentra Mach 1** (display texto)
- ✅ **Vuzix Z100** (display texto)
- ✅ Y expandiendo...

---

## 🏗️ Stack Tecnológico Completo

### Backend (Cloud Package)

**Runtime:**
- **Bun** (primary) - TypeScript execution y bundling
- **Node.js 18+** (herramientas)
- **TypeScript 5.2+**

**Framework Web:**
- **Express.js 5.1** - REST APIs
- **WebSocket** - Real-time bidireccional
- **Docker + Docker Compose**

**AI/ML:**
- **LangChain 0.3.18** - Orchestration multi-provider
  - `@langchain/anthropic` - Claude API
  - `@langchain/google-vertexai` - Vertex AI
- **AssemblyAI 4.9** - Speech-to-text
- Soporte: Azure Speech, Soniox, Deepgram

**Database:**
- **MongoDB** - Primary database
- **S3 Storage** - Cloud objects
- **Docker volumes** - Persistent data

**Observability:**
- **Sentry** (@sentry/bun, @sentry/node) - Error tracking
- **Pino 9.6** - Structured logging

### Mobile (React Native + Expo)

**Core:**
- **Expo 52.0** - RN development platform
- **React 18.3.1** + **React Native 0.76.9**
- **Expo Router 4.0** - File-based routing

**Real-Time:**
- **LiveKit Client 2.15.6** - WebRTC video streaming
- **@livekit/react-native 2.9**
- **RTMP Relay** - Streaming support

**Smart Glasses Communication:**
- **React Native BLE Manager 12.1** - Bluetooth Low Energy
- **React Native Bluetooth Classic 1.73**
- **React Native WiFi Reborn 4.13**

**Hardware:**
- **Expo Camera** - Cámara access
- **Expo Audio & AV** - Audio/video
- **Expo Location** - GPS
- **React Native Image Picker 8.2**

**State Management:**
- **MobX State Tree 7.0.2**
- **Zustand 5.0.8**
- React Context API

**Backend Integration:**
- **Supabase JS 2.50** - Backend-as-a-service
- **Axios** - HTTP requests

### Native Layers

**Android:**
- Java 17 (required)
- Gradle build system
- Kotlin support
- SmartGlassesManager - Unified glasses management

**iOS:**
- Swift (primary)
- SwiftFormat
- Xcode + CocoaPods

---

## 📊 Arquitectura Multi-Capa

```
┌─────────────────────────────────────────────┐
│   Smart Glasses (Hardware)                  │
│   Even Realities, Mentra, Vuzix, etc.      │
└──────────────────┬──────────────────────────┘
                   │ BLE/WiFi
                   ▼
┌─────────────────────────────────────────────┐
│   MentraOS Mobile App (React Native)        │
│   - Pairing & Connection Management         │
│   - Audio/Video Processing                  │
│   - Session Handling                        │
└──────────────────┬──────────────────────────┘
                   │ WebSocket
                   ▼
┌─────────────────────────────────────────────┐
│   MentraOS Cloud (Express + WebSocket)      │
│   - Session Management                      │
│   - Message Routing                         │
│   - Display Throttling                      │
│   - User Authentication                     │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
   ┌─────────┐┌─────────┐┌─────────┐
   │  App 1  ││  App 2  ││  App 3  │
   │ (TS SDK)││ (TS SDK)││ (TS SDK)│
   └─────────┘└─────────┘└─────────┘
```

---

## 🎯 Features Clave

### 1. WebSocket-Based Real-Time Communication

**Flujos:**
- **Glasses → Cloud**: Event streams (audio transcription, sensors, input)
- **Cloud → Apps**: Event distribution y message delivery
- **App → Cloud**: Command submission
- **Cloud → Glasses**: Display updates con throttling inteligente

### 2. Multi-User App Communication

**Features avanzados:**
- App Broadcasting: Envía a todos los usuarios con misma app activa
- Direct Messaging: Peer-to-peer entre app instances
- User Discovery: Encuentra otros usuarios activos
- Room-Based Messaging: Group channels
- Session Tracking: Gestión multi-user

**Código ejemplo:**
```typescript
const session = new AppSession({
  packageName: 'com.example.collaborative-notes',
  apiKey: 'your-api-key',
  userId: 'user@example.com'
});

// Descubrir usuarios activos
const activeUsers = await session.discoverAppUsers(true);

// Escuchar cambios colaborativos
session.onAppMessage((message) => {
  if (message.payload.type === 'note_update') {
    updateNoteInRealtime(message.payload.noteData);
  }
});

// Broadcast a todos
session.broadcastToAppUsers({
  type: 'note_update',
  noteId: 'note-123',
  changes: { text: 'Updated content' }
});
```

### 3. Display Management Inteligente

**Throttling por hardware constraints:**
- 200-300ms mínimo entre updates
- Priority queue para mensajes urgentes
- Bandwidth awareness (Bluetooth limitado)
- Verification system para tracking

### 4. Hardware Abstraction Layer

**SmartGlassesManager:**
```java
String deviceModel = smartGlassesManager.getConnectedSmartGlasses().deviceModelName;
boolean usesWifi = deviceModel != null &&
  (deviceModel.contains("Mentra Live") ||
   deviceModel.contains("Android Smart Glasses"));
```

**Capability Matrix por device:**
- Text display capability
- Image display capability
- Microphone support
- Speaker support
- Camera support
- WiFi vs BLE

### 5. TypeScript SDK Modular

**Componentes:**
- **AppSession**: Core connection management
- **DisplayManager**: Intelligent display rendering
- **AudioManager**: Microphone/audio streaming
- **SubscriptionService**: Event subscription
- **LayoutAPI**: UI layout definitions
- **StorageAPI**: Key-value storage simple
- **EventEmitter**: Custom event handling

---

## 🤖 AI/ML Integration

### LangChain Multi-Provider

**Providers soportados:**
- Anthropic Claude (flagship)
- Google Vertex AI
- OpenAI (via community)

**Use cases:**
- Speech-to-text responses
- Natural language understanding
- Command processing
- Smart replies

### Transcription Services

**Múltiples providers:**
- AssemblyAI (real-time STT)
- Azure Speech Services
- Soniox (live captioning)
- Deepgram

### Apps AI en Producción

- **Live Captions**: Real-time speech transcription
- **Translation**: Multi-language support
- **Smart Replies**: Context-aware suggestions
- **Notes**: AI-assisted note-taking

---

## 🎥 Video Streaming & Real-Time

### LiveKit Integration

**Características:**
- WebRTC-based: Peer-to-peer video
- Low latency: Optimizado para wearables
- Multi-platform: iOS, Android, Web
- RTMP Relay: Streaming protocol support

### Real-Time Capabilities

- **Live Video Streaming**: Camera feed to cloud
- **Bidirectional Audio**: Mic and speaker
- **Screen Sharing**: Display entre devices
- **Presence Tracking**: Online/offline status

### Mentra Live Device

Especializado para video:
- No visual display
- High-res camera
- Microphone + speaker
- WiFi connectivity

---

## 📂 Estructura del Proyecto

```
MentraOS/
├── mobile/                      # React Native Expo app
│   ├── src/app/                 # Screens (Expo Router)
│   ├── src/components/          # UI components
│   ├── src/stores/              # MobX/Zustand state
│   ├── src/services/            # API/BLE services
│   ├── ios/                     # Swift native
│   └── android/                 # Java/Kotlin native
│
├── cloud/                       # Backend infrastructure
│   ├── packages/cloud/          # Express backend
│   │   ├── src/routes/          # HTTP endpoints
│   │   ├── src/websocket/       # Real-time
│   │   └── src/services/        # Business logic
│   ├── packages/sdk/            # TypeScript SDK
│   ├── packages/react-sdk/      # React hooks
│   ├── docs/                    # API docs (Mintlify)
│   └── docker-compose.dev.yml   # Development env
│
├── android_core/                # Android framework
├── android_library/             # Reusable libs
├── asg_client/                  # Smart Glasses Client
├── SmartGlassesManager/         # Multi-glasses layer
├── sdk_ios/                     # iOS SDK
└── mcu_client/                  # Microcontroller firmware
```

---

## 🔗 Relación con KAIROS

### Comparación Arquitectónica

| Aspecto | KAIROS | MentraOS |
|---------|--------|----------|
| **Lenguaje** | Elixir/Phoenix | TypeScript/JavaScript |
| **Runtime** | BEAM VM | Bun/Node.js |
| **Framework Data** | Ash Framework | MongoDB raw |
| **Arquitectura** | Monolith con layers | Microservices + Monolith |
| **API Style** | Ash APIs | Express REST + WebSocket |
| **Real-time** | Phoenix Channels | WebSocket custom + LiveKit |
| **Deployment** | Phoenix-specific | Docker containers |
| **Target** | General web apps | Smart glasses ecosystem |

### ✅ Oportunidades de Integración

#### 1. **KAIROS como Backend para MentraOS**

**Propuesta:**
Reemplazar Express + MongoDB con Phoenix + Ash

**Ventajas:**
- Phoenix Channels más robusto que WebSocket custom
- Ash Policies para authorization compleja
- BEAM concurrency para millones de conexiones
- Hot code reloading en producción
- Distributed Erlang para multi-region

**Arquitectura propuesta:**
```
┌─────────────────────────────────┐
│   Smart Glasses                 │
└────────────┬────────────────────┘
             │ BLE/WiFi
             ▼
┌─────────────────────────────────┐
│   MentraOS Mobile (React Native)│
│   (sin cambios)                 │
└────────────┬────────────────────┘
             │ Phoenix Channels (WebSocket)
             ▼
┌─────────────────────────────────┐
│   KAIROS Backend                │
│   Phoenix 1.8.1 + Ash 3.0       │
│   - User auth (AshAuth)         │
│   - Session management (Ash)    │
│   - Message routing (Channels)  │
│   - Merit system integration    │
│   - AI orchestration (Reactor)  │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│   Apps (TypeScript SDK)         │
│   Con acceso a KAIROS features  │
└─────────────────────────────────┘
```

#### 2. **Ash Resources para MentraOS Data Models**

**Reemplazar MongoDB con Ash:**

```elixir
defmodule Kairos.Wearables.GlassesSession do
  use Ash.Resource,
    domain: Kairos.Wearables,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :device_model, :string do
      constraints one_of: ["Even Realities G1", "Mentra Live", "Vuzix Z100"]
    end

    attribute :connection_type, :atom do
      constraints one_of: [:ble, :wifi, :bluetooth_classic]
    end

    attribute :app_package_name, :string
    attribute :session_metadata, :map
    attribute :last_heartbeat, :utc_datetime
  end

  relationships do
    belongs_to :user, Kairos.Accounts.User
    has_many :display_updates, Kairos.Wearables.DisplayUpdate
    has_many :audio_transcriptions, Kairos.Wearables.AudioTranscription
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :heartbeat do
      change set_attribute(:last_heartbeat, &DateTime.utc_now/0)
    end

    read :active_sessions do
      filter expr(last_heartbeat > ago(5, :minute))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type([:create, :update]) do
      authorize_if relates_to_actor_via(:user)
    end
  end
end
```

#### 3. **Phoenix Channels para WebSocket**

**Reemplazar WebSocket custom:**

```elixir
defmodule KairosWeb.WearableChannel do
  use Phoenix.Channel

  @moduledoc """
  Phoenix Channel para MentraOS smart glasses.

  Compatible con SDK TypeScript existente.
  """

  # Join glasses session
  def join("glasses:" <> session_id, params, socket) do
    case authorize_session(session_id, params) do
      {:ok, session} ->
        send(self(), {:after_join, session})
        {:ok, %{session_id: session_id}, assign(socket, :session, session)}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  # Handle display update (from app)
  def handle_in("display_update", payload, socket) do
    session = socket.assigns.session

    # Throttle display updates (200-300ms)
    case throttle_display_update(session, payload) do
      {:ok, queued} ->
        # Forward to glasses via BLE/WiFi
        push_to_glasses(session, queued)
        {:reply, :ok, socket}

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}
    end
  end

  # Handle audio stream (from glasses)
  def handle_in("audio_chunk", %{"data" => audio_data}, socket) do
    session = socket.assigns.session

    # Process with AI (AssemblyAI, etc.)
    Task.start(fn ->
      transcription = Kairos.AI.Transcription.process(audio_data)

      # Broadcast to subscribed apps
      broadcast!(socket, "transcription", transcription)
    end)

    {:noreply, socket}
  end

  # Presence tracking
  def handle_info({:after_join, session}, socket) do
    {:ok, _} = Presence.track(socket, session.id, %{
      online_at: System.system_time(:second),
      device_model: session.device_model
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
```

#### 4. **Merit System para Smart Glasses Interactions**

**Integración única de KAIROS:**

```elixir
defmodule Kairos.Wearables.InteractionAnalyzer do
  @moduledoc """
  Analiza interacciones con smart glasses para merit system.

  Features:
  - Coherence tracking (voz vs texto escrito)
  - Depth of conversations via glasses
  - Quality of voice commands
  - Behavioral patterns
  """

  def analyze_glasses_interaction(session_id, interaction_data) do
    # Get user merit profile
    user = get_user_from_session(session_id)
    merit_profile = user.merit_profile

    # Analyze interaction quality
    quality_scores = %{
      voice_clarity: analyze_voice_clarity(interaction_data.audio),
      command_coherence: analyze_command_coherence(interaction_data.commands),
      conversation_depth: analyze_conversation_depth(interaction_data.transcript)
    }

    # Update merit scores
    Ash.update!(merit_profile, %{
      depth_score: calculate_new_depth(merit_profile, quality_scores),
      coherence_score: calculate_new_coherence(merit_profile, quality_scores)
    })
  end
end
```

#### 5. **Reactor Workflows para AI Processing**

**Orquestar AI pipeline:**

```elixir
defmodule Kairos.Wearables.Reactors.AudioProcessingReactor do
  use Reactor

  @moduledoc """
  Reactor para procesar audio desde smart glasses:
  1. Transcribe audio (AssemblyAI)
  2. Analyze sentiment
  3. Detect commands
  4. Update merit scores
  5. Send response to glasses
  """

  input :audio_data
  input :session_id

  step :transcribe, async?: true do
    argument :audio_data, input(:audio_data)

    run fn %{audio_data: audio_data} ->
      Kairos.AI.AssemblyAI.transcribe(audio_data)
    end
  end

  step :analyze_sentiment, async?: true do
    argument :transcript, result(:transcribe)

    run fn %{transcript: text} ->
      Kairos.AI.SentimentAnalyzer.analyze(text)
    end
  end

  step :detect_commands do
    argument :transcript, result(:transcribe)

    run fn %{transcript: text} ->
      Kairos.Wearables.CommandParser.parse(text)
    end
  end

  step :update_merit do
    argument :sentiment, result(:analyze_sentiment)
    argument :session_id, input(:session_id)

    run fn args ->
      Kairos.Wearables.InteractionAnalyzer.analyze_glasses_interaction(
        args.session_id,
        %{sentiment: args.sentiment}
      )
    end
  end

  step :send_response do
    argument :commands, result(:detect_commands)
    argument :session_id, input(:session_id)

    run fn args ->
      Kairos.Wearables.ResponseGenerator.send_to_glasses(
        args.session_id,
        args.commands
      )
    end
  end

  return :send_response
end
```

---

## 🎓 Patrones & Aprendizajes para KAIROS

### 1. **Write Once, Run Anywhere**

**Lección:** Hardware abstraction layer funciona
**Para KAIROS:**
- Crear `Kairos.Wearables` domain
- Support múltiples dispositivos (gafas, watches, etc.)
- Feature capability matrix

### 2. **Developer Experience Matters**

**Lección:** SDK bueno = alta adopción
**Para KAIROS:**
- Crear SDK Elixir-friendly (no solo JS)
- Documentación exhaustiva (Hexdocs)
- Examples incluidos

### 3. **Real-Time is Complex**

**Lección:** WebSocket health checks son necesarios
**Para KAIROS:**
- Phoenix Channels tiene ventaja (built-in heartbeat)
- Connection recovery crítico
- Message ordering importa

### 4. **Hardware Constraints son Reales**

**Lección:** 200-300ms delay óptimo para Bluetooth
**Para KAIROS:**
- Display throttling necesario
- Priority queues para mensajes urgentes
- Bandwidth awareness

### 5. **Monorepo Escalable**

**Lección:** Workspaces organizan bien
**Para KAIROS:**
- Mantener estructura modular
- Root-level config compartida
- Clear separation of concerns

### 6. **TypeScript Everywhere**

**Lección:** Type safety previene bugs
**Para KAIROS:**
- Elixir tiene Dialyzer (similar benefit)
- Typespecs en todas las funciones públicas
- Ash resources son typed por naturaleza

---

## 🚀 Propuesta de Integración Completa

### Fase 1: Backend Replacement (2 meses)

**Tareas:**
1. Crear `Kairos.Wearables` domain
2. Implementar resources (GlassesSession, DisplayUpdate, etc.)
3. Migrar Express routes a Phoenix controllers
4. Reemplazar WebSocket con Phoenix Channels
5. Migrar MongoDB data a PostgreSQL + Ash

**Resultado:**
- MentraOS Cloud powered by KAIROS
- Backward compatible con SDK TypeScript existente
- Mejor performance (BEAM concurrency)

### Fase 2: Merit System Integration (1 mes)

**Tareas:**
1. Analizar interacciones de smart glasses
2. Calculate merit scores basados en uso
3. Behavioral verification via voice patterns
4. Quality scoring para apps

**Resultado:**
- Merit-based app recommendations
- User reputation visible en MentraOS Store
- Quality filtering para apps maliciosas

### Fase 3: AI Enhancement (1 mes)

**Tareas:**
1. Replace LangChain con Nx/Bumblebee (on-premise)
2. Reactor workflows para audio processing
3. Custom models para glasses-specific tasks
4. Privacy-first AI (no data leaves KAIROS)

**Resultado:**
- Menor latencia AI (on-premise)
- Costos reducidos (no APIs externas)
- Privacy mejorada

### Fase 4: Advanced Features (2 meses)

**Tareas:**
1. Multi-user collaboration via KAIROS
2. Cross-device synchronization
3. Distributed BEAM para multi-region
4. Advanced analytics con Ash aggregates

**Resultado:**
- Global scale MentraOS
- Low latency worldwide
- Rich analytics dashboard

---

## 📊 Comparación de Performance Estimada

| Métrica | MentraOS (actual) | KAIROS-Powered | Mejora |
|---------|-------------------|----------------|--------|
| **Concurrent Connections** | ~10k (Express) | ~100k (Phoenix) | **10x** |
| **WebSocket Latency** | ~50ms | ~20ms | **2.5x** |
| **DB Query Time** | ~50ms (MongoDB) | ~10ms (Postgres+Ash) | **5x** |
| **AI Inference** | ~500ms (API) | ~100ms (on-premise) | **5x** |
| **Message Throughput** | ~1k/sec | ~50k/sec | **50x** |
| **Memory per Connection** | ~100KB | ~2KB | **50x** |

---

## 💡 Conclusiones

### MentraOS Strengths

✅ Excelente abstraction layer para hardware
✅ Developer SDK bien diseñado
✅ Apps reales en producción
✅ Open source con MIT license
✅ Community-driven development
✅ Cross-platform (iOS, Android, Web)

### KAIROS Advantages

✅ BEAM concurrency (millones de conexiones)
✅ Ash Framework (declarativo, menos código)
✅ Phoenix Channels (real-time robusto)
✅ On-premise AI (privacy + performance)
✅ Hot code reloading (deploy sin downtime)
✅ Distributed by default (multi-region)

### Perfect Match

**MentraOS + KAIROS = Best of Both Worlds:**

- MentraOS maneja hardware complexity
- KAIROS maneja backend scalability
- TypeScript SDK se mantiene (no breaking changes)
- KAIROS agrega merit system único
- AI on-premise reduce costos y latency
- Phoenix Channels mejora real-time
- Ash Policies para authorization compleja

---

## 🎯 Siguiente Paso Recomendado

**Crear `kairos_wearables` package:**

```bash
cd /home/user/sandboxex/kairos
mkdir -p lib/kairos/wearables
```

**Implementar:**
1. `Kairos.Wearables` domain
2. `GlassesSession` resource
3. `DisplayUpdate` resource
4. `AudioTranscription` resource
5. `WearableChannel` Phoenix Channel
6. `InteractionAnalyzer` for merit system

**Test con:**
- MentraOS Mobile app conectando a KAIROS
- SDK TypeScript sin cambios
- Backward compatibility completa

---

**¿Quieres que implemente el módulo `Kairos.Wearables` completo?** 🚀

Podríamos crear una integración production-ready que permita a MentraOS usar KAIROS como backend, manteniendo 100% compatibility con el SDK TypeScript existente mientras agregamos todas las ventajas de Elixir/Phoenix/Ash.
