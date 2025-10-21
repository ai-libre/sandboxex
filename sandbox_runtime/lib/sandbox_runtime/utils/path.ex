defmodule SandboxRuntime.Utils.Path do
  @moduledoc """
  Path normalization and manipulation utilities.
  """

  @doc """
  Normalizes a path by expanding home directory and resolving relative paths.

  ## Examples

      iex> normalize("~/Documents")
      "/Users/username/Documents"

      iex> normalize("./src")
      "/current/working/dir/src"
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(path) when is_binary(path) do
    path
    |> expand_home()
    |> Path.expand()
  end

  @doc """
  Expands ~ to the user's home directory.
  """
  @spec expand_home(String.t()) :: String.t()
  def expand_home("~" <> rest) do
    System.user_home() <> rest
  end

  def expand_home(path), do: path

  @doc """
  Checks if a path is absolute.
  """
  @spec absolute?(String.t()) :: boolean()
  def absolute?(path) do
    Path.type(path) == :absolute
  end

  @doc """
  Converts a list of paths to normalized absolute paths.
  """
  @spec normalize_list([String.t()]) :: [String.t()]
  def normalize_list(paths) when is_list(paths) do
    Enum.map(paths, &normalize/1)
  end

  @doc """
  Checks if path1 is a subpath of path2.
  """
  @spec subpath_of?(String.t(), String.t()) :: boolean()
  def subpath_of?(path, parent) do
    normalized_path = normalize(path)
    normalized_parent = normalize(parent)

    String.starts_with?(normalized_path, normalized_parent)
  end
end
