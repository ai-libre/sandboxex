defmodule Kairos.Moderation do
  @moduledoc """
  Domain para moderación asistida por IA.

  NO es censura - es protección y calidad. Filtra:
  - Bots
  - Grooming
  - Violencia
  - Manipulación psicológica
  - Spam
  """

  use Ash.Domain

  resources do
    resource Kairos.Moderation.Violation do
      define :create_violation, action: :create
      define :escalate_violation, action: :escalate_to_human
      define :get_user_violations, action: :for_user
    end
  end
end
