defmodule Kairos.Interactions.Conversation do
  @moduledoc """
  Conversaciones de alto valor: 1-on-1, grupos, colaboraciones.

  Moderación AI en tiempo real.

  Features:
  - Many-to-many participants
  - Quality score tracking
  - Real-time moderation status
  - Aggregates (message count, avg quality, active participants)
  """

  use Ash.Resource,
    domain: Kairos.Interactions,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "conversations"
    repo Kairos.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      constraints min_length: 3, max_length: 200
      public? true
    end

    attribute :conversation_type, :atom do
      constraints one_of: [:one_on_one, :group, :collaboration]
      default :one_on_one
      public? true
    end

    # AI moderation
    attribute :moderation_status, :atom do
      constraints one_of: [:active, :monitored, :flagged]
      default :active
      public? true
    end

    attribute :quality_score, :float do
      constraints min: 0.0, max: 1.0
      default 0.5
      public? true
    end

    timestamps()
  end

  relationships do
    # TODO: Implement Message resource
    # has_many :messages, Kairos.Interactions.Message

    # TODO: Implement many-to-many with join table
    # many_to_many :participants, Kairos.Accounts.User do
    #   through Kairos.Interactions.ConversationParticipant
    #   source_attribute_on_join_resource :conversation_id
    #   destination_attribute_on_join_resource :user_id
    # end
  end

  # TODO: Implement aggregates when Message resource exists
  # aggregates do
  #   count :message_count, :messages
  #   avg :avg_message_quality, :messages, :depth_score
  #
  #   # Participantes activos en última hora
  #   count :active_participants, :messages do
  #     filter expr(inserted_at > ago(1, :hour))
  #   end
  # end

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

      # TODO: Agregar participants después de crear
      # change Kairos.Interactions.Changes.AddParticipants
    end

    update :update_quality_score do
      accept [:quality_score]
      argument :analysis_result, :map, allow_nil?: false

      # TODO: Implement RecalculateConversationQuality change
      # change Kairos.Interactions.Changes.RecalculateConversationQuality
    end

    update :flag do
      accept [:moderation_status]
      argument :reason, :string, allow_nil?: false

      change set_attribute(:moderation_status, :flagged)

      # TODO: Implement CreateViolation change
      # change Kairos.Moderation.Changes.CreateViolation
    end
  end

  policies do
    # TODO: Solo participants pueden leer
    # policy action_type(:read) do
    #   authorize_if Kairos.Interactions.Checks.IsParticipant
    # end

    # Temporal: todos pueden leer (cambiar con IsParticipant)
    policy action_type(:read) do
      authorize_if always()
    end

    # Usuarios verificados pueden crear
    policy action_type(:create) do
      # TODO: Implement UserIsVerified check
      # authorize_if Kairos.Interactions.Checks.UserIsVerified
      authorize_if always()  # Temporal
    end

    # Solo participants pueden actualizar
    policy action_type(:update) do
      # TODO: Implement IsParticipant check
      # authorize_if Kairos.Interactions.Checks.IsParticipant
      authorize_if always()  # Temporal
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
