defmodule Kairos.Merits.Profile do
  @moduledoc """
  Sistema de méritos basado en valores humanos reales.

  NO es gamificación - es reconocimiento de calidad humana.

  Core Intangibles:
  - coherence_score: Capacidad de sostener contradicciones
  - non_violence_score: Cero violencia verbal
  - depth_score: Profundidad de conversaciones
  - contribution_score: Aportes significativos

  El perfil ético es parcialmente oculto (no revelamos el algoritmo completo).
  """

  use Ash.Resource,
    domain: Kairos.Merits,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

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
      public? true
    end

    attribute :non_violence_score, :float do
      description "Cero violencia verbal"
      constraints min: 0.0, max: 1.0
      default 0.5
      public? true
    end

    attribute :depth_score, :float do
      description "Profundidad de conversaciones"
      constraints min: 0.0, max: 1.0
      default 0.5
      public? true
    end

    attribute :contribution_score, :float do
      description "Aportes significativos"
      constraints min: 0.0, max: 1.0
      default 0.5
      public? true
    end

    # Dynamic Reputation (parcialmente oculto)
    attribute :ethical_profile, :map do
      description "Perfil ético dinámico - NO revelado completamente"
      private? true  # Solo visible para el usuario
    end

    attribute :interaction_quality, :map do
      description "Métricas de calidad de interacciones"
      default %{}
      public? true
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

    # TODO: Implement aggregate calculation
    # calculate :high_quality_post_count, :integer,
    #   Kairos.Merits.Calculations.CountHighQualityPosts
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

      # TODO: Usa Reactor para análisis complejo
      # change Kairos.Merits.Changes.RecalculateAllScores
    end

    update :award_badge do
      argument :badge_type, :string, allow_nil?: false

      # TODO: Implement BadgeEligibility validation
      # validate Kairos.Merits.Validations.BadgeEligibility

      change fn changeset, _context ->
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

      # TODO: Implement NotifyUserBadgeAwarded change
      # change Kairos.Merits.Changes.NotifyUserBadgeAwarded
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
      # TODO: Implement IsSystemProcess check
      # authorize_if Kairos.Merits.Checks.IsSystemProcess
      authorize_if always()  # Temporal - cambiar a system check
    end

    policy action_type(:create) do
      authorize_if always()  # Creado automáticamente al registrar usuario
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
