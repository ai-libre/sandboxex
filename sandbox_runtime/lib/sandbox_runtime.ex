defmodule SandboxRuntime do
  @moduledoc """
  OS-level sandboxing for Elixir applications.

  Provides process isolation using native OS primitives:
  - macOS: Seatbelt (sandbox-exec)
  - Linux: bubblewrap

  ## Quick Start

      # Wrap a command with sandboxing
      {:ok, sandboxed_cmd} = SandboxRuntime.wrap_with_sandbox("curl anthropic.com")

      # Execute directly
      {:ok, output} = SandboxRuntime.execute_sandboxed("cat README.md")

      # Check violations
      violations = SandboxRuntime.get_violations()

  ## Configuration

  Configuration can be provided via:
  - Application config (`config/*.exs`)
  - JSON settings files (`.sandbox/settings.json`)
  - Inline options

  Example configuration:

      config :sandbox_runtime,
        sandbox: %{
          enabled: true,
          network: %{
            http_proxy_port: 8888,
            socks_proxy_port: 1080
          }
        },
        permissions: %{
          allow: [
            "WebFetch(domain:github.com)",
            "Read(.)",
            "Edit(./src)"
          ],
          deny: [
            "Read(~/.ssh)",
            "Edit(.env)"
          ]
        }

  ## Permission Strings

  - `WebFetch(domain:example.com)` - Allow network access to domain
  - `Read(path)` - Deny read access to path
  - `Edit(path)` - Allow write access to path
  - `UnixSocket(path)` - Allow Unix socket access

  ## Platform Support

  - **macOS**: Uses Seatbelt (sandbox-exec)
    - Requires: `sandbox-exec`, `ripgrep`
  - **Linux**: Uses bubblewrap
    - Requires: `bwrap`, `socat`, `ripgrep`
  - **Windows**: Not supported

  ## Security Considerations

  This sandbox is defense-in-depth, not a security boundary. It provides:
  - Filesystem isolation (read/write restrictions)
  - Network filtering (domain-based)
  - Process isolation

  It does NOT provide:
  - Memory isolation
  - CPU/resource limits
  - Protection against kernel exploits
  """

  alias SandboxRuntime.Manager

  @type violation :: %{
          timestamp: integer(),
          type: atom(),
          operation: String.t(),
          target: String.t(),
          process: String.t() | nil,
          metadata: map()
        }

  @doc """
  Wraps a command with sandboxing.

  Returns the sandboxed command string that can be executed via
  System.cmd/3 or Port.open/2.

  ## Options

  - `:config` - Inline configuration map to merge with loaded config
  - `:allow` - List of additional allow permissions
  - `:deny` - List of additional deny permissions

  ## Examples

      iex> SandboxRuntime.wrap_with_sandbox("curl anthropic.com")
      {:ok, "sandbox-exec -f /tmp/profile_123.sb sh -c 'curl anthropic.com'"}

      iex> SandboxRuntime.wrap_with_sandbox("cat ~/.ssh/id_rsa")
      {:ok, "sandbox-exec -f /tmp/profile_456.sb sh -c 'cat ~/.ssh/id_rsa'"}
  """
  @spec wrap_with_sandbox(command :: String.t(), opts :: keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def wrap_with_sandbox(command, opts \\ []) do
    Manager.wrap_with_sandbox(command, opts)
  end

  @doc """
  Executes a sandboxed command and returns output.

  Convenience wrapper around wrap_with_sandbox/2 + System.cmd/3.

  ## Examples

      iex> SandboxRuntime.execute_sandboxed("echo hello")
      {:ok, "hello\\n"}

      iex> SandboxRuntime.execute_sandboxed("cat /etc/shadow")
      {:error, :permission_denied}
  """
  @spec execute_sandboxed(command :: String.t(), opts :: keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def execute_sandboxed(command, opts \\ []) do
    with {:ok, sandboxed_cmd} <- wrap_with_sandbox(command, opts) do
      case System.cmd("sh", ["-c", sandboxed_cmd], stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, output}

        {output, exit_code} ->
          {:error, {:exit_code, exit_code, output}}
      end
    end
  end

  @doc """
  Returns all recorded sandbox violations.

  ## Examples

      iex> SandboxRuntime.get_violations()
      [
        %{
          timestamp: 1234567890,
          type: :network,
          operation: "WebFetch",
          target: "blocked.com",
          process: "http_proxy",
          metadata: %{}
        }
      ]
  """
  @spec get_violations() :: [violation()]
  def get_violations do
    SandboxRuntime.ViolationStore.get_violations()
  end

  @doc """
  Returns violations filtered by type.

  ## Examples

      iex> SandboxRuntime.get_violations_by_type(:network)
      [%{type: :network, ...}]
  """
  @spec get_violations_by_type(atom()) :: [violation()]
  def get_violations_by_type(type) do
    SandboxRuntime.ViolationStore.get_violations_by_type(type)
  end

  @doc """
  Clears all recorded violations.
  """
  @spec clear_violations() :: :ok
  def clear_violations do
    SandboxRuntime.ViolationStore.clear()
  end

  @doc """
  Returns the count of violations.
  """
  @spec violation_count() :: non_neg_integer()
  def violation_count do
    SandboxRuntime.ViolationStore.count()
  end

  @doc """
  Checks if sandboxing is enabled and available on this platform.

  ## Examples

      iex> SandboxRuntime.sandboxing_enabled?()
      true
  """
  @spec sandboxing_enabled?() :: boolean()
  def sandboxing_enabled? do
    Manager.sandboxing_enabled?()
  end

  @doc """
  Returns platform information.

  ## Examples

      iex> SandboxRuntime.platform_info()
      %{
        platform: :macos,
        supported: true,
        dependencies: %{sandbox_exec: true, ripgrep: true}
      }
  """
  @spec platform_info() :: map()
  def platform_info do
    SandboxRuntime.Platform.Detector.platform_info()
  end

  @doc """
  Initializes sandbox infrastructure (starts proxies).

  This is called automatically by the Application, but can be
  called manually if needed.

  ## Examples

      iex> SandboxRuntime.initialize()
      :ok
  """
  @spec initialize(keyword()) :: :ok | {:error, term()}
  def initialize(opts \\ []) do
    Manager.initialize(opts)
  end

  @doc """
  Resets sandbox state (stops proxies, clears violations).

  ## Examples

      iex> SandboxRuntime.reset()
      :ok
  """
  @spec reset() :: :ok
  def reset do
    Manager.reset()
  end

  @doc """
  Reloads configuration from files.

  ## Examples

      iex> SandboxRuntime.reload_config()
      :ok
  """
  @spec reload_config() :: :ok | {:error, term()}
  def reload_config do
    SandboxRuntime.ConfigServer.reload()
  end

  @doc """
  Gets the current configuration.

  ## Examples

      iex> SandboxRuntime.get_config()
      %{sandbox: %{enabled: true, ...}, ...}
  """
  @spec get_config() :: map()
  def get_config do
    SandboxRuntime.ConfigServer.get_config()
  end
end
