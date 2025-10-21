defmodule SandboxRuntime.Config do
  @moduledoc """
  Configuration module for SandboxRuntime.

  Provides access to configuration schemas, loaders, and parsers.
  """

  defdelegate validate!(config), to: SandboxRuntime.Config.Schema
  defdelegate schema(), to: SandboxRuntime.Config.Schema
  defdelegate load_hierarchical(), to: SandboxRuntime.Config.Loader
  defdelegate default_config(), to: SandboxRuntime.Config.Loader
  defdelegate parse_permissions(permissions), to: SandboxRuntime.Config.Parser
end
