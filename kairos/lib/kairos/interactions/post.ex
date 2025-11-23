defmodule Kairos.Interactions.Post do
  @moduledoc """
  Posts de alta calidad - contenido profundo, creativo, significativo.

  AI analysis automático en cada create/update:
  - Toxicity detection
  - Depth analysis
  - Coherence check

  Los scores de IA son read-only (solo el sistema puede escribirlos).
  """

  use Ash.Resource,
    domain: Kairos.Interactions,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "posts"
    repo Kairos.Repo

    custom_indexes do
      # Índice para feed de alta calidad
      index ["depth_score DESC", "inserted_at DESC"]
      index ["toxicity_score"], where: "toxicity_score > 0.5"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints min_length: 10, max_length: 5000
      public? true
    end

    attribute :content_type, :atom do
      constraints one_of: [:text, :creative, :question, :insight]
      default :text
      public? true
    end

    # AI Analysis scores (auto-calculated, read-only)
    attribute :depth_score, :float do
      description "Profundidad del contenido (calculado por IA)"
      constraints min: 0.0, max: 1.0
      writable? false  # Solo AI puede escribir
      public? true
    end

    attribute :coherence_score, :float do
      description "Coherencia con perfil del usuario"
      constraints min: 0.0, max: 1.0
      writable? false
      public? true
    end

    attribute :toxicity_score, :float do
      description "Nivel de toxicidad (0.0 = no tóxico)"
      constraints min: 0.0, max: 1.0
      writable? false
      public? true
    end

    attribute :ai_summary, :string do
      description "Resumen generado por IA"
      writable? false
      public? true
    end

    # Internal metrics (no público)
    attribute :interaction_quality, :map do
      default %{}
      private? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Kairos.Accounts.User do
      allow_nil? false
    end

    # TODO: Implement Reply resource
    # has_many :replies, Kairos.Interactions.Reply
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

      # User desde argument
      change set_attribute(:user_id, arg(:user_id))

      # TODO: AI analysis automático ANTES de guardar
      # change Kairos.Interactions.Changes.AnalyzePostQuality

      # TODO: Si toxicity muy alta, bloquear
      # validate Kairos.Interactions.Validations.ToxicityThreshold
    end

    update :update do
      accept [:content, :content_type]

      # TODO: Re-analizar al actualizar
      # change Kairos.Interactions.Changes.AnalyzePostQuality
      # validate Kairos.Interactions.Validations.ToxicityThreshold
    end

    read :high_quality_feed do
      description "Feed de posts con depth_score > 0.7"

      # Solo posts con depth_score > 0.7
      filter expr(depth_score >= 0.7 and toxicity_score < 0.3)

      # Ordenar por calidad + recencia
      prepare build(sort: [depth_score: :desc, inserted_at: :desc])
    end

    read :for_user do
      description "Posts de un usuario específico"
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
      # TODO: Implement UserIsVerified check
      # authorize_if Kairos.Interactions.Checks.UserIsVerified
      authorize_if always()  # Temporal - cambiar a verified check
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
end
