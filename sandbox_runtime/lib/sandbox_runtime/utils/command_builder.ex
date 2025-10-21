defmodule SandboxRuntime.Utils.CommandBuilder do
  @moduledoc """
  Utilities for building shell commands safely.
  """

  @doc """
  Escapes a shell argument for safe execution.

  ## Examples

      iex> escape("hello world")
      "'hello world'"

      iex> escape("hello'world")
      "'hello'\\\\''world'"
  """
  @spec escape(String.t()) :: String.t()
  def escape(arg) when is_binary(arg) do
    # Use single quotes and escape any single quotes in the string
    "'" <> String.replace(arg, "'", "'\\''") <> "'"
  end

  @doc """
  Builds a command from a program and arguments.
  """
  @spec build(String.t(), [String.t()]) :: String.t()
  def build(program, args) when is_binary(program) and is_list(args) do
    escaped_args = Enum.map(args, &escape/1)
    Enum.join([program | escaped_args], " ")
  end

  @doc """
  Joins multiple commands with && operator.
  """
  @spec join_commands([String.t()]) :: String.t()
  def join_commands(commands) when is_list(commands) do
    Enum.join(commands, " && ")
  end

  @doc """
  Sets environment variables for a command.
  """
  @spec with_env(String.t(), map()) :: String.t()
  def with_env(command, env) when is_binary(command) and is_map(env) do
    env_string =
      env
      |> Enum.map(fn {key, value} -> "#{key}=#{escape(to_string(value))}" end)
      |> Enum.join(" ")

    if env_string == "" do
      command
    else
      "#{env_string} #{command}"
    end
  end
end
