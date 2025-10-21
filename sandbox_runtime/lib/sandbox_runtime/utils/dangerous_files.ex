defmodule SandboxRuntime.Utils.DangerousFiles do
  @moduledoc """
  Detection of dangerous files and directories that should be
  automatically denied in sandbox write access.

  Uses ripgrep to scan for dangerous patterns.
  """

  require Logger

  @dangerous_files [
    ".gitconfig",
    ".bashrc",
    ".zshrc",
    ".bash_profile",
    ".zsh_profile",
    ".profile",
    ".ripgreprc",
    ".mcp.json"
  ]

  @dangerous_dirs [
    ".git",
    ".ssh",
    ".aws",
    ".gnupg",
    ".vscode",
    ".idea",
    ".claude/commands",
    ".claude/agents"
  ]

  @dangerous_git_paths [
    ".git/hooks",
    ".git/config"
  ]

  @doc """
  Returns a list of dangerous file patterns.
  """
  @spec dangerous_files() :: [String.t()]
  def dangerous_files, do: @dangerous_files

  @doc """
  Returns a list of dangerous directory patterns.
  """
  @spec dangerous_dirs() :: [String.t()]
  def dangerous_dirs, do: @dangerous_dirs

  @doc """
  Scans a directory for dangerous files using ripgrep.

  Returns a list of absolute paths to dangerous files found.
  """
  @spec scan(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def scan(base_path \\ ".") do
    case System.find_executable("rg") do
      nil ->
        Logger.warning("ripgrep (rg) not found, skipping dangerous file detection")
        {:ok, []}

      _rg_path ->
        perform_scan(base_path)
    end
  end

  # Private Helpers

  defp perform_scan(base_path) do
    # Build ripgrep pattern for dangerous files
    file_pattern = Enum.join(@dangerous_files, "|")

    # Use ripgrep to find files
    case System.cmd("rg", [
      "--files",
      "--glob",
      "{#{file_pattern}}",
      "--ignore-case",
      base_path
    ], stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&Path.absname/1)

        {:ok, files}

      {_output, _code} ->
        # ripgrep returns non-zero if no matches found
        {:ok, []}
    end
  rescue
    e ->
      Logger.warning("Failed to scan for dangerous files: #{inspect(e)}")
      {:ok, []}
  end

  @doc """
  Checks if a path matches any dangerous pattern.
  """
  @spec dangerous?(String.t()) :: boolean()
  def dangerous?(path) do
    basename = Path.basename(path)

    Enum.member?(@dangerous_files, basename) or
      Enum.any?(@dangerous_dirs, fn dir ->
        String.contains?(path, "/#{dir}/") or String.ends_with?(path, "/#{dir}")
      end) or
      Enum.any?(@dangerous_git_paths, fn git_path ->
        String.ends_with?(path, git_path)
      end)
  end
end
