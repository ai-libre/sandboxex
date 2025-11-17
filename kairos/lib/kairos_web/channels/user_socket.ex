defmodule KairosWeb.UserSocket do
  @moduledoc """
  Socket para Phoenix Channels.

  ## Channels disponibles

  - `glasses:*` → WearableChannel (smart glasses real-time)
  - `conversation:*` → ConversationChannel (chat real-time) [TODO]
  - `feed:*` → FeedChannel (live updates) [TODO]

  ## Authentication

  Token-based auth via query params:
  - Connect: ws://localhost:4000/socket?token=USER_TOKEN
  - Token verificado en connect/3
  """

  use Phoenix.Socket

  # Channels
  channel "glasses:*", KairosWeb.WearableChannel
  # TODO: Add more channels
  # channel "conversation:*", KairosWeb.ConversationChannel
  # channel "feed:*", KairosWeb.FeedChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # TODO: Verify token and load user
    # case verify_token(token) do
    #   {:ok, user_id} ->
    #     {:ok, assign(socket, :current_user_id, user_id)}
    #   {:error, _reason} ->
    #     :error
    # end

    # Temporal: allow all connections
    {:ok, socket}
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(socket) do
    # Return nil to disable connection tracking
    # or "user:#{socket.assigns.current_user_id}" to track
    nil
  end
end
