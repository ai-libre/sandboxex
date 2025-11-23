defmodule Kairos.Merits do
  @moduledoc """
  Domain para sistema de méritos basado en intangibles humanos.

  NO es gamificación - es reconocimiento de calidad humana:
  - Coherencia (capacidad de sostener contradicciones)
  - No violencia (cero violencia verbal)
  - Profundidad (conversaciones significativas)
  - Contribución (aportes valiosos)
  """

  use Ash.Domain

  resources do
    resource Kairos.Merits.Profile do
      define :create_profile, action: :create
      define :update_scores, action: :recalculate_scores
      define :award_badge, action: :award_badge
      define :get_profile_by_user, action: :read, get_by: [:user_id]
    end
  end
end
