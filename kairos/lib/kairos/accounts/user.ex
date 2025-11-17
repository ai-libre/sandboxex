defmodule Kairos.Accounts.User do
  @moduledoc """
  User resource con verificación conductual (no legal).

  KAIROS NO verifica DNI - verificamos CONSISTENCIA DE COMPORTAMIENTO.

  Características:
  - Behavioral hash único (timing, vocabulary, emotional tone)
  - Verification score (0.0 - 1.0)
  - AI-assisted profile
  - AshAuthentication integrado
  """

  use Ash.Resource,
    domain: Kairos.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

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
      public? true
    end

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string, sensitive?: true, private?: true

    # Behavioral Identity (not legal identity)
    attribute :behavioral_hash, :string do
      description "Hash único de patrones de comportamiento del usuario"
      private? true  # Solo visible para el usuario y moderadores
    end

    attribute :verification_status, :atom do
      constraints one_of: [:pending, :verified, :flagged]
      default :pending
      public? true
    end

    attribute :verification_score, :float do
      constraints min: 0.0, max: 1.0
      default 0.0
      public? true
    end

    # AI-assisted profile
    attribute :ai_profile_summary, :string do
      public? true
    end

    attribute :coherence_baseline, :map do
      description "Patrones de coherencia - JSONB"
      private? true  # Solo para análisis interno
    end

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
      description "Register new user"
      accept [:username, :email]

      argument :password, :string, allow_nil?: false, sensitive?: true

      change fn changeset, _context ->
        password = Ash.Changeset.get_argument(changeset, :password)
        hashed = Bcrypt.hash_pwd_salt(password)

        changeset
        |> Ash.Changeset.change_attribute(:hashed_password, hashed)
        |> Ash.Changeset.force_change_attribute(
          :behavioral_hash,
          # TODO: Implement behavioral analyzer
          "initial_hash_#{:crypto.strong_rand_bytes(16) |> Base.encode16()}"
        )
        |> Ash.Changeset.force_change_attribute(:coherence_baseline, %{})
      end
    end

    update :verify_behavior do
      description "Update behavioral verification scores"
      accept [:verification_score, :verification_status, :behavioral_hash]

      argument :analysis_data, :map, allow_nil?: false

      # TODO: Implement UpdateBehavioralProfile change
      # change Kairos.Accounts.Changes.UpdateBehavioralProfile
    end

    update :flag_for_review do
      description "Flag user for moderator review"
      accept [:verification_status]
      argument :reason, :string, allow_nil?: false

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :verification_status, :flagged)
      end

      # TODO: Implement NotifyModerators change
      # change Kairos.Accounts.Changes.NotifyModerators
    end
  end

  policies do
    # Solo el usuario puede ver su propio perfil completo
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:id, expr(id))
      # TODO: Implement IsModerator check
      # authorize_if Kairos.Accounts.Checks.IsModerator
    end

    # Otros pueden ver datos públicos
    policy action_type(:read) do
      authorize_if always()

      # Pero ocultamos campos sensibles
      forbid_if accessing_field(:email)
      forbid_if accessing_field(:behavioral_hash)
      forbid_if accessing_field(:coherence_baseline)
      forbid_if accessing_field(:hashed_password)
    end

    policy action_type(:create) do
      authorize_if always()  # Cualquiera puede registrarse
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:id, expr(id))
      # authorize_if Kairos.Accounts.Checks.IsModerator
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:id, expr(id))
    end
  end

  identities do
    identity :unique_username, [:username]
    identity :unique_email, [:email]
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end
    end
  end
end
