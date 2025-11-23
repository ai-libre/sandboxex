defmodule Kairos.Accounts do
  @moduledoc """
  Domain para gestión de usuarios y autenticación.

  Incluye verificación conductual (behavioral verification) en lugar de
  verificación de identidad legal.
  """

  use Ash.Domain

  resources do
    resource Kairos.Accounts.User do
      # Define actions disponibles via domain
      define :create_user, action: :register
      define :verify_user, action: :verify_behavior
      define :flag_user, action: :flag_for_review
      define :get_user_by_id, action: :read, get_by: [:id]
      define :get_user_by_email, action: :read, get_by: [:email]
      define :get_user_by_username, action: :read, get_by: [:username]
    end
  end
end
