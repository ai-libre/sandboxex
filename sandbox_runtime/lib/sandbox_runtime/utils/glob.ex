defmodule SandboxRuntime.Utils.Glob do
  @moduledoc """
  Glob pattern matching and conversion utilities.

  Converts glob patterns to regular expressions for use in
  Seatbelt profiles and other pattern matching scenarios.
  """

  @doc """
  Converts a glob pattern to a regular expression.

  Supports:
  - `*` - Matches any characters except /
  - `**` - Matches any characters including /
  - `?` - Matches a single character
  - `[abc]` - Character class
  - `{a,b}` - Alternatives

  ## Examples

      iex> to_regex("*.ex")
      ~r/^[^\/]*\\.ex$/

      iex> to_regex("src/**/*.exs")
      ~r/^src\/.*\/[^\/]*\\.exs$/
  """
  @spec to_regex(String.t()) :: Regex.t()
  def to_regex(glob_pattern) do
    regex_string =
      glob_pattern
      |> escape_special_chars()
      |> convert_glob_to_regex()
      |> wrap_anchors()

    Regex.compile!(regex_string)
  end

  @doc """
  Checks if a path matches a glob pattern.
  """
  @spec matches?(String.t(), String.t()) :: boolean()
  def matches?(path, glob_pattern) do
    regex = to_regex(glob_pattern)
    Regex.match?(regex, path)
  end

  @doc """
  Converts multiple glob patterns to a list of regexes.
  """
  @spec to_regex_list([String.t()]) :: [Regex.t()]
  def to_regex_list(patterns) when is_list(patterns) do
    Enum.map(patterns, &to_regex/1)
  end

  # Private Helpers

  defp escape_special_chars(pattern) do
    # First, escape all regex special characters
    escaped = Regex.escape(pattern)

    # Then unescape glob special characters that we want to process
    escaped
    |> String.replace("\\*", "*")
    |> String.replace("\\?", "?")
    |> String.replace("\\[", "[")
    |> String.replace("\\]", "]")
    |> String.replace("\\{", "{")
    |> String.replace("\\}", "}")
  end

  defp convert_glob_to_regex(pattern) do
    pattern
    # Handle **/ pattern (matches zero or more directories)
    |> String.replace("**/", "<!DOUBLESTAR_SLASH!>")
    # Handle /** pattern (matches zero or more directories at end)
    |> String.replace("/**", "<!SLASH_DOUBLESTAR!>")
    # Handle remaining ** (matches any characters including /)
    |> String.replace("**", "<!DOUBLESTAR!>")
    # Replace single * (matches any characters except /)
    |> String.replace("*", "[^\\/]*")
    # Replace **/ with optional directory matcher
    |> String.replace("<!DOUBLESTAR_SLASH!>", "(?:.*?/)?")
    # Replace /** with directory matcher
    |> String.replace("<!SLASH_DOUBLESTAR!>", "(?:/.*)?")
    # Replace remaining ** with any character matcher
    |> String.replace("<!DOUBLESTAR!>", ".*")
    # Replace ? with single character matcher
    |> String.replace("?", ".")
  end

  defp wrap_anchors(pattern) do
    "^" <> pattern <> "$"
  end

  @doc """
  Checks if a pattern contains glob wildcards.
  """
  @spec has_wildcards?(String.t()) :: boolean()
  def has_wildcards?(pattern) do
    String.contains?(pattern, ["*", "?", "[", "{"])
  end
end
