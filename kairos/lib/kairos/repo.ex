defmodule Kairos.Repo do
  use AshPostgres.Repo, otp_app: :kairos

  @doc """
  Lista de extensiones de PostgreSQL requeridas.
  """
  def installed_extensions do
    [
      # Ash framework functions
      "ash-functions",
      # UUID generation
      "uuid-ossp",
      # Case-insensitive text (para emails)
      "citext",
      # Trigram similarity (para búsqueda full-text)
      "pg_trgm"
    ]
  end
end
