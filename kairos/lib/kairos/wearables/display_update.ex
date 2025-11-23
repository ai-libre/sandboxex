defmodule Kairos.Wearables.DisplayUpdate do
  @moduledoc """
  Actualizaciones de display para smart glasses.

  Compatible con MentraOS display protocol y Even G1 UI updates.

  ## Throttling

  CRÍTICO: Bluetooth Low Energy tiene bandwidth limitado.
  - Minimum interval: 200-300ms entre updates
  - Queue updates cuando rate limit excedido
  - Auto-debounce: merge updates consecutivos del mismo tipo

  ## Update Types

  - :notification → Notificación temporal
  - :persistent → UI persistente (status bar, etc.)
  - :overlay → Overlay sobre contenido existente
  - :full_screen → Full takeover
  - :kairos_feed → Feed de KAIROS posts

  ## Priority Levels

  - :critical → Bypass throttle (alertas de seguridad)
  - :high → Queue front (mensajes importantes)
  - :normal → Queue normal (default)
  - :low → Queue back, puede ser descartado

  ## Rendering

  Payload es JSON flexible:
  - MentraOS format: {type, content, metadata}
  - Custom KAIROS format: {post_id, merit_level, quality_score}
  """

  use Ash.Resource,
    domain: Kairos.Wearables,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "display_updates"
    repo Kairos.Repo

    custom_indexes do
      # Query por session y status
      index [:glasses_session_id, :delivered_at]
      index [:glasses_session_id, :update_type]
      index [:priority, :inserted_at], where: "delivered_at IS NULL"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :update_type, :atom do
      constraints one_of: [:notification, :persistent, :overlay, :full_screen, :kairos_feed]
      default :notification
      public? true
    end

    attribute :priority, :atom do
      constraints one_of: [:critical, :high, :normal, :low]
      default :normal
      public? true
    end

    attribute :payload, :map do
      description "Contenido del update (JSON flexible)"
      allow_nil? false
      public? true
    end

    attribute :display_duration_ms, :integer do
      description "Duración del display en ms (null = persistente)"
      constraints min: 100, max: 60_000
      public? true
    end

    attribute :ttl_seconds, :integer do
      description "Time to live - descartar si no entregado en N segundos"
      default 300  # 5 minutos
      public? true
    end

    # Delivery tracking
    attribute :queued_at, :utc_datetime do
      description "Cuando se encoló para envío"
      public? true
    end

    attribute :delivered_at, :utc_datetime do
      description "Cuando se entregó al dispositivo"
      public? true
    end

    attribute :displayed_at, :utc_datetime do
      description "Cuando el dispositivo confirmó display"
      public? true
    end

    attribute :dismissed_at, :utc_datetime do
      description "Cuando el usuario dismisseó (opcional)"
      public? true
    end

    # Metadata
    attribute :source_type, :string do
      description "Tipo de fuente (Post, Conversation, System, etc.)"
      public? true
    end

    attribute :source_id, :uuid do
      description "ID de la fuente"
      public? true
    end

    attribute :metadata, :map do
      description "Metadata adicional (analytics, A/B tests, etc.)"
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :glasses_session, Kairos.Wearables.GlassesSession do
      allow_nil? false
    end

    # Polymorphic source - puede ser Post, Conversation, etc.
    # belongs_to :source, :any (no soportado directamente en Ash)
  end

  calculations do
    calculate :is_pending, :boolean do
      description "Update pendiente de entrega"
      calculation expr(is_nil(delivered_at))
    end

    calculate :is_delivered, :boolean do
      description "Update entregado pero no necesariamente mostrado"
      calculation expr(not is_nil(delivered_at) and is_nil(displayed_at))
    end

    calculate :is_active, :boolean do
      description "Update actualmente mostrado"
      calculation expr(
        not is_nil(displayed_at) and is_nil(dismissed_at)
      )
    end

    calculate :delivery_latency_ms, :integer do
      description "Latencia de entrega en ms"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          if record.delivered_at && record.inserted_at do
            DateTime.diff(record.delivered_at, record.inserted_at, :millisecond)
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
      description "Crear update y encolar para envío"

      accept [
        :glasses_session_id,
        :update_type,
        :priority,
        :payload,
        :display_duration_ms,
        :ttl_seconds,
        :source_type,
        :source_id,
        :metadata
      ]

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :queued_at, DateTime.utc_now())
      end

      # TODO: Auto-enqueue para envío
      # change Kairos.Wearables.Changes.EnqueueDisplayUpdate

      # TODO: Validar payload según update_type
      # validate Kairos.Wearables.Validations.ValidatePayloadFormat
    end

    update :mark_delivered do
      description "Marcar como entregado al dispositivo"

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :delivered_at, DateTime.utc_now())
      end
    end

    update :mark_displayed do
      description "Dispositivo confirmó display"

      change fn changeset, _context ->
        changeset =
          if Ash.Changeset.get_attribute(changeset, :delivered_at) == nil do
            Ash.Changeset.force_change_attribute(changeset, :delivered_at, DateTime.utc_now())
          else
            changeset
          end

        Ash.Changeset.force_change_attribute(changeset, :displayed_at, DateTime.utc_now())
      end
    end

    update :dismiss do
      description "Usuario dismisseó el update"

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :dismissed_at, DateTime.utc_now())
      end
    end

    read :pending_for_session do
      description "Updates pendientes para una sesión específica"
      argument :session_id, :uuid, allow_nil?: false

      filter expr(
        glasses_session_id == ^arg(:session_id) and
        is_nil(delivered_at)
      )

      prepare build(sort: [priority: :desc, inserted_at: :asc])
    end

    read :active_for_session do
      description "Updates activamente mostrados en una sesión"
      argument :session_id, :uuid, allow_nil?: false

      filter expr(
        glasses_session_id == ^arg(:session_id) and
        not is_nil(displayed_at) and
        is_nil(dismissed_at)
      )
    end

    read :expired do
      description "Updates que excedieron TTL sin ser entregados"

      filter expr(
        is_nil(delivered_at) and
        inserted_at < ago(^ref(:ttl_seconds), :second)
      )
    end

    destroy :cleanup_expired do
      description "Eliminar updates expirados"

      # Solo permite borrar expirados
      require_atomic? false

      change fn changeset, _context ->
        record = changeset.data

        if record.delivered_at == nil do
          ttl = record.ttl_seconds || 300
          expired_at = DateTime.add(record.inserted_at, ttl, :second)

          if DateTime.compare(DateTime.utc_now(), expired_at) == :gt do
            changeset
          else
            Ash.Changeset.add_error(changeset, "Update not expired yet")
          end
        else
          Ash.Changeset.add_error(changeset, "Cannot cleanup delivered updates")
        end
      end
    end
  end

  policies do
    # El owner de la session puede leer updates
    policy action_type(:read) do
      # TODO: Authorize via session ownership
      # authorize_if relates_to_actor_via([:glasses_session, :user])
      authorize_if always()  # Temporal
    end

    # Sistema puede crear updates
    policy action_type(:create) do
      # TODO: Implement IsSystemProcess check
      # authorize_if Kairos.Wearables.Checks.IsSystemProcess
      authorize_if always()  # Temporal
    end

    # Sistema y owner pueden actualizar
    policy action_type([:update, :destroy]) do
      # TODO: Authorize via session ownership
      # authorize_if relates_to_actor_via([:glasses_session, :user])
      authorize_if always()  # Temporal
    end
  end

  pub_sub do
    module KairosWeb.Endpoint
    prefix "display_update"

    publish :create, ["queued", :glasses_session_id]
    publish :mark_delivered, ["delivered", :id]
    publish :mark_displayed, ["displayed", :id]
    publish :dismiss, ["dismissed", :id]
  end
end
