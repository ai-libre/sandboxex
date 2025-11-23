defmodule Kairos.Wearables.GlassesSession do
  @moduledoc """
  Sesión activa de smart glasses conectados.

  Compatible con MentraOS, EvenApp, y otros wearables.

  ## Lifecycle

  1. Device connects → create session
  2. Heartbeat cada 30s → update last_heartbeat
  3. Timeout (2min) → mark as disconnected
  4. Explicit disconnect → destroy session

  ## Connection Types

  - :ble → Bluetooth Low Energy (Even G1)
  - :wifi → Direct WiFi (MentraOS)
  - :bluetooth_classic → Classic Bluetooth

  ## Telemetry

  Emite eventos para monitoreo:
  - [:kairos, :wearables, :session, :connected]
  - [:kairos, :wearables, :session, :heartbeat]
  - [:kairos, :wearables, :session, :timeout]
  """

  use Ash.Resource,
    domain: Kairos.Wearables,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "glasses_sessions"
    repo Kairos.Repo

    custom_indexes do
      # Query activas frecuentemente
      index [:user_id], where: "disconnected_at IS NULL"
      index [:last_heartbeat], where: "disconnected_at IS NULL"
      index [:device_model]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :device_model, :string do
      description "Modelo del dispositivo (Even G1, MentraOS, etc.)"
      constraints max_length: 100
      public? true
    end

    attribute :device_serial, :string do
      description "Serial único del hardware"
      constraints max_length: 100
      public? true
    end

    attribute :connection_type, :atom do
      constraints one_of: [:ble, :wifi, :bluetooth_classic]
      default :wifi
      public? true
    end

    attribute :app_package_name, :string do
      description "Package del app cliente (com.even.app, com.mentra.os)"
      constraints max_length: 200
      public? true
    end

    attribute :app_version, :string do
      description "Versión del cliente"
      constraints max_length: 50
      public? true
    end

    attribute :firmware_version, :string do
      description "Versión del firmware de hardware"
      public? true
    end

    attribute :last_heartbeat, :utc_datetime do
      description "Último heartbeat recibido"
      public? true
    end

    attribute :connected_at, :utc_datetime do
      description "Timestamp de conexión"
      default &DateTime.utc_now/0
      public? true
    end

    attribute :disconnected_at, :utc_datetime do
      description "Timestamp de desconexión (null si activo)"
      public? true
    end

    # Metadata del dispositivo (batería, sensores, capabilities)
    attribute :device_metadata, :map do
      description "Metadata adicional (batería, sensores disponibles, etc.)"
      default %{}
      public? true
    end

    # Settings específicos del dispositivo
    attribute :settings, :map do
      description "Configuración (brightness, notifications, etc.)"
      default %{
        "display_brightness" => 0.7,
        "notifications_enabled" => true,
        "audio_enabled" => true,
        "display_throttle_ms" => 250
      }
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Kairos.Accounts.User do
      allow_nil? false
    end

    has_many :display_updates, Kairos.Wearables.DisplayUpdate
    has_many :audio_transcriptions, Kairos.Wearables.AudioTranscription
  end

  calculations do
    calculate :is_active, :boolean do
      description "Session activa (heartbeat en últimos 2 minutos)"
      calculation expr(
        is_nil(disconnected_at) and
        last_heartbeat > ago(2, :minute)
      )
    end

    calculate :connection_duration, :integer do
      description "Duración de conexión en segundos"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          end_time = record.disconnected_at || DateTime.utc_now()
          DateTime.diff(end_time, record.connected_at, :second)
        end)
      end
    end

    calculate :session_status, :atom do
      description "Estado de la sesión: :active, :idle, :disconnected"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          cond do
            record.disconnected_at != nil ->
              :disconnected

            DateTime.diff(DateTime.utc_now(), record.last_heartbeat, :second) < 120 ->
              :active

            true ->
              :idle
          end
        end)
      end
    end
  end

  aggregates do
    count :display_update_count, :display_updates
    count :audio_transcription_count, :audio_transcriptions

    # Actualizaciones en última hora
    count :recent_updates, :display_updates do
      filter expr(inserted_at > ago(1, :hour))
    end
  end

  actions do
    defaults [:read, :destroy]

    create :connect do
      description "Crear nueva sesión de dispositivo"

      accept [
        :user_id,
        :device_model,
        :device_serial,
        :connection_type,
        :app_package_name,
        :app_version,
        :firmware_version,
        :device_metadata,
        :settings
      ]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:connected_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:last_heartbeat, DateTime.utc_now())
      end

      # TODO: Emit telemetry
      # change Kairos.Wearables.Changes.EmitSessionConnected
    end

    update :heartbeat do
      description "Actualizar heartbeat (cada 30s)"

      accept [:device_metadata]

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :last_heartbeat, DateTime.utc_now())
      end

      # TODO: Emit telemetry
      # change Kairos.Wearables.Changes.EmitHeartbeat
    end

    update :disconnect do
      description "Marcar sesión como desconectada"

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :disconnected_at, DateTime.utc_now())
      end

      # TODO: Cleanup and telemetry
      # change Kairos.Wearables.Changes.CleanupSession
    end

    update :update_settings do
      description "Actualizar settings del dispositivo"
      accept [:settings]

      # TODO: Validate settings schema
      # validate Kairos.Wearables.Validations.ValidateSettings
    end

    read :active_sessions do
      description "Sesiones activas (heartbeat reciente)"
      filter expr(is_nil(disconnected_at) and last_heartbeat > ago(2, :minute))
    end

    read :for_user do
      description "Sesiones de un usuario específico"
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :idle_sessions do
      description "Sesiones idle (sin heartbeat por >2min pero no desconectadas)"
      filter expr(
        is_nil(disconnected_at) and
        last_heartbeat <= ago(2, :minute)
      )
    end
  end

  policies do
    # El usuario puede leer sus propias sesiones
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    # El usuario puede crear sus propias sesiones
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:id, arg(:user_id))
    end

    # El usuario puede actualizar sus propias sesiones
    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end

    # Moderadores pueden ver todas las sesiones
    policy action_type(:read) do
      # TODO: Implement IsModerator check
      # authorize_if Kairos.Moderation.Checks.IsModerator
      forbid_if always()  # Temporal
    end
  end

  pub_sub do
    module KairosWeb.Endpoint
    prefix "glasses_session"

    publish :connect, ["connected", :user_id]
    publish :heartbeat, ["heartbeat", :id]
    publish :disconnect, ["disconnected", :id]
    publish :update_settings, ["settings_updated", :id]
  end
end
