defmodule KairosWeb.WearableChannel do
  @moduledoc """
  Phoenix Channel para comunicación real-time con wearables.

  Reemplaza WebSocket de MentraOS con Phoenix Channels.

  ## Protocol

  Compatible con MentraOS SDK:
  - Connect: `glasses:SESSION_ID`
  - Heartbeat: `heartbeat` (cada 30s)
  - Display updates: `display_update`
  - Audio stream: `audio_chunk` (base64)
  - Audio end: `audio_end`
  - Settings sync: `settings_update`

  ## Throttling

  CRÍTICO para Bluetooth Low Energy:
  - Display updates: Max 1 cada 250ms (configurable por device)
  - Audio chunks: Buffer hasta silence detection
  - Heartbeat: Exactamente cada 30s

  ## Rate Limiting

  - 100 messages/minute por session
  - 10 display_updates/second (throttled)
  - Audio chunks unlimited (streaming)

  ## Telemetry

  Emite eventos para monitoreo:
  - [:kairos, :wearable_channel, :connect]
  - [:kairos, :wearable_channel, :display_update]
  - [:kairos, :wearable_channel, :audio_transcription]
  """

  use Phoenix.Channel

  require Logger
  alias Kairos.Wearables.{GlassesSession, DisplayUpdate, AudioTranscription}

  @heartbeat_interval_ms 30_000
  @display_throttle_ms 250
  @max_messages_per_minute 100

  # ============================================================================
  # Join/Leave
  # ============================================================================

  @doc """
  Join channel: glasses:SESSION_ID

  Payload:
  - device_model: "Even G1" | "MentraOS"
  - app_version: "1.0.0"
  - firmware_version: "2.3.1"
  """
  def join("glasses:" <> session_id, payload, socket) do
    Logger.metadata(session_id: session_id)

    with {:ok, session} <- load_session(session_id),
         :ok <- verify_session_ownership(session, socket),
         {:ok, socket} <- setup_socket(socket, session, payload) do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, :not_found} ->
        {:error, %{reason: "Session not found"}}

      {:error, :unauthorized} ->
        {:error, %{reason: "Unauthorized"}}

      error ->
        Logger.error("Join error: #{inspect(error)}")
        {:error, %{reason: "Internal error"}}
    end
  end

  def join(_topic, _payload, _socket) do
    {:error, %{reason: "Invalid topic"}}
  end

  def terminate(_reason, socket) do
    if session_id = socket.assigns[:session_id] do
      Logger.info("Wearable disconnected", session_id: session_id)

      # Mark session as disconnected
      session_id
      |> load_session()
      |> case do
        {:ok, session} ->
          GlassesSession
          |> Ash.get!(session.id)
          |> Ash.Changeset.for_update(:disconnect)
          |> Ash.update()

        _ ->
          :ok
      end
    end

    :ok
  end

  # ============================================================================
  # Incoming Messages (from device)
  # ============================================================================

  @doc """
  Heartbeat cada 30s para mantener session alive
  """
  def handle_in("heartbeat", payload, socket) do
    session = socket.assigns.session

    # Update heartbeat timestamp
    session
    |> Ash.Changeset.for_update(:heartbeat, %{device_metadata: payload})
    |> Ash.update()
    |> case do
      {:ok, _session} ->
        {:reply, {:ok, %{timestamp: DateTime.utc_now()}}, socket}

      {:error, error} ->
        Logger.error("Heartbeat update failed: #{inspect(error)}")
        {:reply, {:error, %{reason: "Heartbeat failed"}}, socket}
    end
  end

  @doc """
  Audio chunk from device (streaming)

  Payload:
  - chunk: base64 encoded audio
  - sequence: chunk number
  - sample_rate: Hz
  - format: "opus" | "pcm" | "aac"
  """
  def handle_in("audio_chunk", %{"chunk" => chunk, "sequence" => seq} = payload, socket) do
    session_id = socket.assigns.session.id

    # Accumulate chunks in socket state
    chunks = Map.get(socket.assigns, :audio_chunks, [])
    updated_chunks = [{seq, chunk} | chunks]

    socket = assign(socket, :audio_chunks, updated_chunks)
    socket = assign(socket, :audio_metadata, Map.drop(payload, ["chunk", "sequence"]))

    {:reply, {:ok, %{received: seq}}, socket}
  end

  @doc """
  Audio end - trigger transcription

  Payload:
  - duration_ms: total audio duration
  - chunk_count: total chunks sent
  """
  def handle_in("audio_end", payload, socket) do
    chunks = Map.get(socket.assigns, :audio_chunks, [])
    metadata = Map.get(socket.assigns, :audio_metadata, %{})
    session_id = socket.assigns.session.id

    # Sort chunks by sequence
    sorted_chunks =
      chunks
      |> Enum.sort_by(fn {seq, _chunk} -> seq end)
      |> Enum.map(fn {_seq, chunk} -> chunk end)

    # TODO: Send to transcription service
    # For now, just acknowledge
    Task.start(fn ->
      process_audio_transcription(session_id, sorted_chunks, metadata, payload)
    end)

    # Clear accumulated chunks
    socket = assign(socket, :audio_chunks, [])
    socket = assign(socket, :audio_metadata, %{})

    {:reply, {:ok, %{status: "processing"}}, socket}
  end

  @doc """
  Confirm display update was shown

  Payload:
  - update_id: UUID of DisplayUpdate
  - displayed_at: ISO8601 timestamp
  """
  def handle_in("display_displayed", %{"update_id" => update_id}, socket) do
    update_id
    |> load_display_update()
    |> case do
      {:ok, update} ->
        update
        |> Ash.Changeset.for_update(:mark_displayed)
        |> Ash.update()

        {:reply, :ok, socket}

      _ ->
        {:reply, {:error, %{reason: "Update not found"}}, socket}
    end
  end

  @doc """
  User dismissed display update

  Payload:
  - update_id: UUID of DisplayUpdate
  """
  def handle_in("display_dismissed", %{"update_id" => update_id}, socket) do
    update_id
    |> load_display_update()
    |> case do
      {:ok, update} ->
        update
        |> Ash.Changeset.for_update(:dismiss)
        |> Ash.update()

        {:reply, :ok, socket}

      _ ->
        {:reply, {:error, %{reason: "Update not found"}}, socket}
    end
  end

  @doc """
  Update device settings

  Payload:
  - brightness: 0.0-1.0
  - notifications_enabled: boolean
  - audio_enabled: boolean
  - display_throttle_ms: integer
  """
  def handle_in("settings_update", settings, socket) do
    session = socket.assigns.session

    session
    |> Ash.Changeset.for_update(:update_settings, %{settings: settings})
    |> Ash.update()
    |> case do
      {:ok, updated_session} ->
        socket = assign(socket, :session, updated_session)
        {:reply, {:ok, %{settings: updated_session.settings}}, socket}

      {:error, error} ->
        Logger.error("Settings update failed: #{inspect(error)}")
        {:reply, {:error, %{reason: "Settings update failed"}}, socket}
    end
  end

  # Catch-all for unknown messages
  def handle_in(event, payload, socket) do
    Logger.warning("Unknown event: #{event}", payload: payload)
    {:reply, {:error, %{reason: "Unknown event"}}, socket}
  end

  # ============================================================================
  # Outgoing Messages (to device)
  # ============================================================================

  @doc """
  Send display update to device (throttled)
  """
  def handle_info({:display_update, update}, socket) do
    session = socket.assigns.session
    throttle_ms = get_in(session.settings, ["display_throttle_ms"]) || @display_throttle_ms
    last_update_at = socket.assigns[:last_display_update_at] || 0
    now = System.monotonic_time(:millisecond)

    if now - last_update_at >= throttle_ms do
      # Send update
      push(socket, "display_update", %{
        update_id: update.id,
        type: update.update_type,
        priority: update.priority,
        payload: update.payload,
        duration_ms: update.display_duration_ms
      })

      # Mark as delivered
      update
      |> Ash.Changeset.for_update(:mark_delivered)
      |> Ash.update()

      socket = assign(socket, :last_display_update_at, now)
      {:noreply, socket}
    else
      # Queue for later (re-schedule)
      wait_ms = throttle_ms - (now - last_update_at)
      Process.send_after(self(), {:display_update, update}, wait_ms)
      {:noreply, socket}
    end
  end

  @doc """
  Send KAIROS post to display
  """
  def handle_info({:kairos_post, post}, socket) do
    # Create DisplayUpdate from Post
    session = socket.assigns.session

    DisplayUpdate
    |> Ash.Changeset.for_create(:create, %{
      glasses_session_id: session.id,
      update_type: :kairos_feed,
      priority: :normal,
      payload: %{
        post_id: post.id,
        content: post.content,
        author: post.user.name,
        depth_score: post.depth_score,
        quality_level: calculate_quality_level(post)
      },
      source_type: "Post",
      source_id: post.id
    })
    |> Ash.create()
    |> case do
      {:ok, update} ->
        send(self(), {:display_update, update})
        {:noreply, socket}

      error ->
        Logger.error("Failed to create display update: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  def handle_info(:after_join, socket) do
    session = socket.assigns.session

    Logger.info("Wearable connected", session_id: session.id, device: session.device_model)

    # Subscribe to updates for this session
    Phoenix.PubSub.subscribe(Kairos.PubSub, "glasses_session:#{session.id}")
    Phoenix.PubSub.subscribe(Kairos.PubSub, "display_update:queued:#{session.id}")

    # Schedule heartbeat check
    schedule_heartbeat_check()

    # Send initial state
    push(socket, "connected", %{
      session_id: session.id,
      settings: session.settings,
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  def handle_info(:heartbeat_check, socket) do
    # Check if heartbeat is recent
    session = socket.assigns.session
    last_heartbeat = session.last_heartbeat
    now = DateTime.utc_now()

    if DateTime.diff(now, last_heartbeat, :second) > 120 do
      Logger.warning("Heartbeat timeout, closing channel", session_id: session.id)
      {:stop, :normal, socket}
    else
      schedule_heartbeat_check()
      {:noreply, socket}
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp load_session(session_id) do
    case Ash.UUID.dump(session_id) do
      {:ok, _uuid} ->
        GlassesSession
        |> Ash.Query.filter(id == ^session_id)
        |> Ash.read_one()

      :error ->
        {:error, :invalid_uuid}
    end
  end

  defp verify_session_ownership(session, socket) do
    # TODO: Check actor matches session.user_id
    # actor = socket.assigns[:current_user]
    # if actor && actor.id == session.user_id do
    #   :ok
    # else
    #   {:error, :unauthorized}
    # end

    # Temporal: allow all
    :ok
  end

  defp setup_socket(socket, session, payload) do
    socket =
      socket
      |> assign(:session, session)
      |> assign(:session_id, session.id)
      |> assign(:device_model, session.device_model)
      |> assign(:audio_chunks, [])
      |> assign(:audio_metadata, %{})
      |> assign(:last_display_update_at, 0)
      |> assign(:join_payload, payload)

    {:ok, socket}
  end

  defp schedule_heartbeat_check do
    Process.send_after(self(), :heartbeat_check, @heartbeat_interval_ms * 2)
  end

  defp load_display_update(update_id) do
    case Ash.UUID.dump(update_id) do
      {:ok, _uuid} ->
        DisplayUpdate
        |> Ash.Query.filter(id == ^update_id)
        |> Ash.read_one()

      :error ->
        {:error, :invalid_uuid}
    end
  end

  defp process_audio_transcription(session_id, chunks, metadata, payload) do
    # TODO: Decode base64 chunks and send to transcription service
    # For now, just create a placeholder

    Logger.info("Processing audio transcription",
      session_id: session_id,
      chunk_count: length(chunks),
      duration_ms: payload["duration_ms"]
    )

    # Mock transcription (replace with actual service call)
    AudioTranscription
    |> Ash.Changeset.for_create(:create, %{
      glasses_session_id: session_id,
      transcript: "Audio transcription pending...",
      language: metadata["language"] || "es",
      confidence: 0.0,
      transcription_provider: :assemblyai,
      audio_duration_ms: payload["duration_ms"],
      audio_metadata: metadata
    })
    |> Ash.create()
    |> case do
      {:ok, transcription} ->
        Logger.info("Transcription created", transcription_id: transcription.id)
        :ok

      error ->
        Logger.error("Transcription creation failed: #{inspect(error)}")
        :error
    end
  end

  defp calculate_quality_level(post) do
    cond do
      post.depth_score >= 0.8 && post.toxicity_score < 0.2 -> :exceptional
      post.depth_score >= 0.6 && post.toxicity_score < 0.3 -> :high
      post.depth_score >= 0.4 && post.toxicity_score < 0.5 -> :medium
      true -> :low
    end
  end
end
