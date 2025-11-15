defmodule Kairos.Interactions do
  @moduledoc """
  Domain para interacciones de alto valor.

  Incluye posts, conversaciones y mensajes con análisis de calidad
  automático por IA.
  """

  use Ash.Domain

  resources do
    resource Kairos.Interactions.Post do
      define :create_post, action: :create
      define :update_post, action: :update
      define :high_quality_feed, action: :high_quality_feed
      define :user_posts, action: :for_user
      define :get_post, action: :read, get_by: [:id]
    end

    resource Kairos.Interactions.Conversation do
      define :start_conversation, action: :start
      define :update_quality, action: :update_quality_score
      define :flag_conversation, action: :flag
      define :get_conversation, action: :read, get_by: [:id]
    end
  end
end
