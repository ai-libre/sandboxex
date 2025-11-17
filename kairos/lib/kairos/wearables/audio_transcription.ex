defmodule Kairos.Wearables.AudioTranscription do
  @moduledoc """
  Transcripciones de audio desde smart glasses.

  Compatible con múltiples providers (igual que MentraOS):
  - AssemblyAI (default)
  - Deepgram
  - OpenAI Whisper (local con Nx/Bumblebee)
  - Google Speech-to-Text

  ## Workflow

  1. Glasses graba audio → envía chunks via WebSocket
  2. Buffer acumula chunks hasta silence detection
  3. Envia a transcription provider
  4. Resultado guardado + merit analysis
  5. Pub/Sub notifica resultado

  ## Merit Integration

  Las transcripciones alimentan el sistema de méritos:
  - Análisis de coherence (contradicciones vs contexto)
  - Análisis de non-violence (tono, vocabulario)
  - Depth scoring (profundidad de conversación)

  ## Privacy

  - Audio NUNCA se guarda (solo transcripción)
  - Usuario puede opt-out de analysis
  - Transcripciones encriptadas at-rest
  """

  use Ash.Resource,
    domain: Kairos.Wearables,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "audio_transcriptions"
    repo Kairos.Repo

    custom_indexes do
      # Query por session y timestamp
      index [:glasses_session_id, :inserted_at]
      index [:transcription_provider]
      index [:language]

      # Full-text search en transcripción
      index ["to_tsvector('spanish', transcript)"],
        using: :gin,
        name: "audio_transcriptions_transcript_search"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :transcript, :string do
      description "Texto transcrito"
      allow_nil? false
      public? true
    end

    attribute :language, :string do
      description "Idioma detectado (ISO 639-1: es, en, etc.)"
      constraints max_length: 10
      default "es"
      public? true
    end

    attribute :confidence, :float do
      description "Confianza del transcriber (0.0-1.0)"
      constraints min: 0.0, max: 1.0
      public? true
    end

    attribute :transcription_provider, :atom do
      constraints one_of: [:assemblyai, :deepgram, :whisper_local, :google_speech]
      default :assemblyai
      public? true
    end

    attribute :audio_duration_ms, :integer do
      description "Duración del audio original en ms"
      constraints min: 0
      public? true
    end

    attribute :processing_time_ms, :integer do
      description "Tiempo de procesamiento del transcriber"
      public? true
    end

    # Metadata del audio
    attribute :audio_metadata, :map do
      description "Metadata del audio (sample rate, format, etc.)"
      default %{}
      public? true
    end

    # AI Analysis results (integración con merit system)
    attribute :sentiment, :atom do
      description "Sentiment analysis: :positive, :neutral, :negative"
      constraints one_of: [:positive, :neutral, :negative]
      public? true
    end

    attribute :toxicity_score, :float do
      description "Score de toxicidad (0.0-1.0)"
      constraints min: 0.0, max: 1.0
      public? true
    end

    attribute :depth_score, :float do
      description "Profundidad conversacional (0.0-1.0)"
      constraints min: 0.0, max: 1.0
      public? true
    end

    # Privacy controls
    attribute :merit_analysis_enabled, :boolean do
      description "Usuario permitió análisis de mérito"
      default true
      public? true
    end

    # Context
    attribute :conversation_context, :map do
      description "Contexto de conversación (participantes, tema, etc.)"
      default %{}
      public? true
    end

    attribute :interaction_type, :atom do
      description "Tipo de interacción: :voice_command, :conversation, :note"
      constraints one_of: [:voice_command, :conversation, :note, :question]
      default :conversation
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :glasses_session, Kairos.Wearables.GlassesSession do
      allow_nil? false
    end

    # TODO: Link to Conversation if part of one
    # belongs_to :conversation, Kairos.Interactions.Conversation
  end

  calculations do
    calculate :is_high_quality, :boolean do
      description "Transcripción de alta calidad (confidence > 0.85)"
      calculation expr(confidence >= 0.85)
    end

    calculate :is_toxic, :boolean do
      description "Contenido tóxico detectado"
      calculation expr(toxicity_score > 0.5)
    end

    calculate :word_count, :integer do
      description "Cantidad de palabras en transcript"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          record.transcript
          |> String.split(~r/\s+/)
          |> length()
        end)
      end
    end

    calculate :speaking_rate_wpm, :float do
      description "Palabras por minuto"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          if record.audio_duration_ms && record.audio_duration_ms > 0 do
            word_count =
              record.transcript
              |> String.split(~r/\s+/)
              |> length()

            duration_minutes = record.audio_duration_ms / 60_000.0
            word_count / duration_minutes
          else
            nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Crear transcripción desde audio"

      accept [
        :glasses_session_id,
        :transcript,
        :language,
        :confidence,
        :transcription_provider,
        :audio_duration_ms,
        :processing_time_ms,
        :audio_metadata,
        :merit_analysis_enabled,
        :conversation_context,
        :interaction_type
      ]

      # TODO: AI analysis automático si enabled
      # change Kairos.Wearables.Changes.AnalyzeTranscription

      # TODO: Update merit profile si enabled
      # change Kairos.Wearables.Changes.UpdateMeritFromTranscription
    end

    update :analyze do
      description "Analizar transcripción (sentiment, toxicity, depth)"

      argument :force_reanalysis, :boolean, default: false

      # TODO: Run AI analysis
      # change Kairos.Wearables.Changes.AnalyzeTranscription
    end

    read :for_session do
      description "Transcripciones de una sesión específica"
      argument :session_id, :uuid, allow_nil?: false

      filter expr(glasses_session_id == ^arg(:session_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :high_quality do
      description "Transcripciones de alta calidad"
      filter expr(confidence >= 0.85)
    end

    read :recent do
      description "Transcripciones recientes (última hora)"
      filter expr(inserted_at > ago(1, :hour))
      prepare build(sort: [inserted_at: :desc])
    end

    read :toxic_content do
      description "Contenido tóxico detectado"
      filter expr(toxicity_score > 0.5)
      prepare build(sort: [toxicity_score: :desc])
    end

    read :search do
      description "Búsqueda full-text en transcripciones"
      argument :query, :string, allow_nil?: false

      # TODO: Implement full-text search with tsvector
      # filter expr(fragment("to_tsvector('spanish', transcript) @@ plainto_tsquery('spanish', ?)", ^arg(:query)))
    end
  end

  policies do
    # El owner de la session puede leer sus transcripciones
    policy action_type(:read) do
      # TODO: Authorize via session ownership
      # authorize_if relates_to_actor_via([:glasses_session, :user])
      authorize_if always()  # Temporal
    end

    # Sistema puede crear transcripciones
    policy action_type(:create) do
      # TODO: Implement IsSystemProcess check
      # authorize_if Kairos.Wearables.Checks.IsSystemProcess
      authorize_if always()  # Temporal
    end

    # Owner y sistema pueden actualizar/borrar
    policy action_type([:update, :destroy]) do
      # TODO: Authorize via session ownership
      # authorize_if relates_to_actor_via([:glasses_session, :user])
      authorize_if always()  # Temporal
    end

    # Moderadores pueden ver contenido tóxico
    policy action(:toxic_content) do
      # TODO: Implement IsModerator check
      # authorize_if Kairos.Moderation.Checks.IsModerator
      forbid_if always()  # Temporal
    end
  end

  pub_sub do
    module KairosWeb.Endpoint
    prefix "audio_transcription"

    publish :create, ["transcribed", :glasses_session_id]
    publish :analyze, ["analyzed", :id]
  end
end
