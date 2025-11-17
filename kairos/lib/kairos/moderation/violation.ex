defmodule Kairos.Moderation.Violation do
  @moduledoc """
  Violaciones detectadas por el sistema de moderación asistido por IA.

  NO es censura - es protección y calidad.

  Tipos de violaciones:
  - bot_behavior: Patrones de bot detectados
  - grooming: Intento de manipulación
  - violence: Violencia verbal
  - manipulation: Manipulación psicológica
  - spam: Contenido spam
  """

  use Ash.Resource,
    domain: Kairos.Moderation,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "violations"
    repo Kairos.Repo

    custom_indexes do
      # Índices para queries comunes
      index [:user_id]
      index [:violation_type]
      index [:severity]
      index [:human_reviewed]
    end
  end

  attributes do
    uuid_primary_key :id

    # Polymorphic content reference
    attribute :content_type, :string do
      description "Tipo de contenido (Post, Message, etc.)"
      public? true
    end

    attribute :content_id, :uuid do
      description "ID del contenido violador"
      public? true
    end

    attribute :violation_type, :atom do
      constraints one_of: [:bot_behavior, :grooming, :violence, :manipulation, :spam]
      allow_nil? false
      public? true
    end

    attribute :severity, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :low
      public? true
    end

    attribute :ai_confidence, :float do
      description "Confianza del modelo de IA (0.0 - 1.0)"
      constraints min: 0.0, max: 1.0
      public? true
    end

    attribute :human_reviewed, :boolean do
      default false
      public? true
    end

    # Evidence - JSONB con patrones detectados
    attribute :evidence, :map do
      description "Evidencia detectada (patrones, scores, etc.)"
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Kairos.Accounts.User do
      allow_nil? false
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:user_id, :content_type, :content_id, :violation_type, :severity, :ai_confidence, :evidence]
    end

    update :escalate_to_human do
      description "Escalar violación para revisión humana"

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :human_reviewed, true)
      end

      # TODO: Notify moderators
      # change Kairos.Moderation.Changes.NotifyModerators
    end

    read :for_user do
      description "Violaciones de un usuario específico"
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :pending_review do
      description "Violaciones pendientes de revisión humana"
      filter expr(human_reviewed == false and severity in [:high, :critical])
    end
  end

  policies do
    # Solo moderadores pueden leer violaciones
    policy action_type(:read) do
      # TODO: Implement IsModerator check
      # authorize_if Kairos.Moderation.Checks.IsModerator

      # Temporal: el usuario puede ver sus propias violaciones
      authorize_if relates_to_actor_via(:user)
    end

    # Solo el sistema puede crear violaciones
    policy action_type(:create) do
      # TODO: Implement IsSystemProcess check
      # authorize_if Kairos.Moderation.Checks.IsSystemProcess
      authorize_if always()  # Temporal
    end

    # Solo moderadores pueden actualizar
    policy action_type(:update) do
      # TODO: Implement IsModerator check
      # authorize_if Kairos.Moderation.Checks.IsModerator
      authorize_if always()  # Temporal
    end
  end
end
