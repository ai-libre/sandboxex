# Elixir Sandbox Runtime - Comprehensive Implementation Plan

**Date:** 2025-10-21
**Project:** Port of @anthropic-ai/sandbox-runtime to Elixir
**Purpose:** Enable Elixir applications to sandbox themselves using OS-level primitives

---

## Executive Summary

This document outlines the comprehensive plan to create an Elixir version of Anthropic's sandbox-runtime, leveraging modern Elixir/OTP patterns and practices. The implementation will provide process-level sandboxing for Elixir applications without requiring containers, using native OS primitives (macOS Seatbelt and Linux bubblewrap).

---

## Table of Contents

1. [Ultra-Thinking Analysis](#ultra-thinking-analysis)
2. [Architecture Overview](#architecture-overview)
3. [Elixir Patterns & Concepts](#elixir-patterns--concepts)
4. [Project Structure](#project-structure)
5. [Implementation Phases](#implementation-phases)
6. [Technical Specifications](#technical-specifications)
7. [Testing Strategy](#testing-strategy)
8. [Risk Assessment](#risk-assessment)

---

## Ultra-Thinking Analysis

### Core Problem

**Challenge:** Elixir applications running AI agents, external MCP servers, or untrusted code need OS-level sandboxing to restrict:
- Filesystem access (read/write restrictions)
- Network access (domain-based filtering)
- Unix socket access (IPC control)
- Process isolation

**Current State:** The TypeScript implementation uses:
- Node.js child_process spawning
- HTTP/SOCKS5 proxy servers for network filtering
- Platform-specific sandboxing (macOS: sandbox-exec, Linux: bubblewrap)
- Configuration via JSON settings files

### Why Elixir is Well-Suited

1. **Supervision Trees**: Natural fit for managing proxy servers, violation monitors, and sandbox processes
2. **Port Communication**: Built-in primitives for external process management (sandbox-exec, bwrap)
3. **GenServer State**: Perfect for managing sandbox configuration, violation stores, proxy state
4. **OTP Application**: Clean lifecycle management (start proxies, cleanup on shutdown)
5. **Pattern Matching**: Elegant handling of Seatbelt/bubblewrap command generation
6. **Immutability**: Safe concurrent access to sandbox configurations
7. **Telemetry**: Built-in observability for violation monitoring and performance tracking

### Key Design Decisions

#### 1. **Use Ports, Not NIFs**
- **Rationale**: Sandboxing external processes (sandbox-exec, bwrap) requires OS process isolation
- **Pattern**: Port-based communication ensures fault tolerance (external process crash won't kill BEAM)
- **Trade-off**: Slight latency vs. safety (acceptable for sandbox operations)

#### 2. **Supervision Tree Architecture**
```
SandboxRuntime.Application (Application)
└── SandboxRuntime.Supervisor (Supervisor, one_for_one)
    ├── SandboxRuntime.ConfigServer (GenServer) - Configuration management
    ├── SandboxRuntime.ViolationStore (GenServer) - Violation tracking
    ├── SandboxRuntime.ProxySupervisor (DynamicSupervisor)
    │   ├── SandboxRuntime.HttpProxy (GenServer) - HTTP/HTTPS proxy
    │   └── SandboxRuntime.SocksProxy (GenServer) - SOCKS5 proxy
    └── SandboxRuntime.PlatformSupervisor (Supervisor, rest_for_one)
        ├── SandboxRuntime.ViolationMonitor (GenServer) - macOS log monitoring
        └── SandboxRuntime.NetworkBridge (GenServer) - Linux socat bridges
```

**Rationale:**
- `one_for_one`: Config/ViolationStore failures don't affect proxies
- `DynamicSupervisor`: Proxies can be started/stopped independently
- `rest_for_one`: ViolationMonitor depends on config being loaded first

#### 3. **Configuration via Elixir Config System**
- Use `config/config.exs` for compile-time defaults
- Use `config/runtime.exs` for environment-specific settings
- Support external JSON settings for compatibility (parsed at runtime)
- Hierarchical loading: Project > User > Policy > Environment

#### 4. **Modern Elixir Patterns**
- `child_spec/1` for custom supervision
- `handle_continue/2` for async initialization (loading configs, starting proxies)
- `Telemetry` events for observability
- `NimbleOptions` for schema validation (instead of Zod)
- `Jason` for JSON parsing
- `Plug` for HTTP proxy server

---

## Architecture Overview

### Component Mapping: TypeScript → Elixir

| TypeScript Module | Elixir Module | Behavior | Purpose |
|------------------|---------------|----------|---------|
| `sandbox-manager.ts` | `SandboxRuntime.Manager` | GenServer | Main orchestration, API entry point |
| `http-proxy.ts` | `SandboxRuntime.HttpProxy` | GenServer + Plug | HTTP/HTTPS proxy server |
| `socks-proxy.ts` | `SandboxRuntime.SocksProxy` | GenServer | SOCKS5 proxy implementation |
| `macos-sandbox-utils.ts` | `SandboxRuntime.Platform.MacOS` | Module | Seatbelt profile generation |
| `linux-sandbox-utils.ts` | `SandboxRuntime.Platform.Linux` | Module | Bubblewrap command generation |
| `sandbox-violation-store.ts` | `SandboxRuntime.ViolationStore` | GenServer + ETS | In-memory violation tracking |
| `settings.ts` | `SandboxRuntime.Config` | Module | Configuration loading/parsing |
| `sandbox-utils.ts` | `SandboxRuntime.Utils` | Module | Path normalization, glob handling |
| N/A (new) | `SandboxRuntime.ViolationMonitor` | GenServer + Port | macOS log stream monitoring |
| N/A (new) | `SandboxRuntime.NetworkBridge` | GenServer + Port | Linux socat bridge management |

### Data Flow

```
User Application
    ↓
SandboxRuntime.Manager.wrap_with_sandbox("npm install")
    ↓
ConfigServer: Load sandbox settings
    ↓
Platform detection (macOS/Linux)
    ↓
┌─────────────────────────────────┐
│ macOS Path                      │ Linux Path
│ ↓                               │ ↓
│ Generate Seatbelt profile       │ Generate bwrap command
│ ↓                               │ ↓
│ Start ViolationMonitor (Port)   │ Start NetworkBridge (socat Ports)
│ ↓                               │ ↓
│ Return: sandbox-exec -p ...     │ Return: bwrap --unshare-net ...
└─────────────────────────────────┘
    ↓
User executes via System.cmd/3 or Port
    ↓
Violations logged to ViolationStore (ETS)
    ↓
Telemetry events emitted
```

---

## Elixir Patterns & Concepts

### 1. GenServer with handle_continue/2

**Pattern**: Initialize expensive operations asynchronously

```elixir
defmodule SandboxRuntime.Manager do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Fast init, return immediately
    {:ok, %{initialized: false, opts: opts}, {:continue, :load_config}}
  end

  @impl true
  def handle_continue(:load_config, state) do
    # Slow operations: load config files, start proxies
    config = SandboxRuntime.Config.load_hierarchical()

    # Emit telemetry
    :telemetry.execute([:sandbox_runtime, :config, :loaded], %{}, config)

    {:noreply, %{state | config: config, initialized: true}}
  end
end
```

**Rationale**: Prevents blocking supervision tree startup; proxies start in background

### 2. Child Specifications

**Pattern**: Custom child specs for flexible supervision

```elixir
defmodule SandboxRuntime.HttpProxy do
  use GenServer

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
end
```

### 3. Port-Based External Process Management

**Pattern**: Manage sandbox-exec/bwrap via Ports with proper error handling

```elixir
defmodule SandboxRuntime.Platform.MacOS do
  def execute_sandboxed(command, profile) do
    port = Port.open({:spawn_executable, "/usr/bin/sandbox-exec"}, [
      :binary,
      :exit_status,
      args: ["-p", profile, "sh", "-c", command],
      env: [{'PATH', System.get_env("PATH")}]
    ])

    receive_port_data(port, "")
  end

  defp receive_port_data(port, acc) do
    receive do
      {^port, {:data, data}} ->
        receive_port_data(port, acc <> data)

      {^port, {:exit_status, status}} ->
        {:ok, acc, status}
    after
      30_000 -> {:error, :timeout}
    end
  end
end
```

**Key Features**:
- `:binary` mode for efficient data transfer
- `:exit_status` for process completion detection
- Timeout protection
- Accumulator pattern for streaming output

### 4. ETS for Violation Storage

**Pattern**: Fast concurrent reads/writes for violation tracking

```elixir
defmodule SandboxRuntime.ViolationStore do
  use GenServer

  def init(_opts) do
    table = :ets.new(:sandbox_violations, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{table: table}}
  end

  def add_violation(violation) do
    :ets.insert(:sandbox_violations, {System.monotonic_time(), violation})
    :telemetry.execute([:sandbox_runtime, :violation, :added], %{count: 1}, violation)
  end

  def get_violations do
    :ets.tab2list(:sandbox_violations)
    |> Enum.map(fn {_ts, v} -> v end)
  end
end
```

**Rationale**:
- `:public` table allows direct reads (fast path)
- GenServer still owns lifecycle (cleanup on crash)
- `read_concurrency: true` for high-traffic scenarios
- Telemetry integration for observability

### 5. Telemetry Integration

**Pattern**: Emit events at key lifecycle points

```elixir
# In application.ex
def start(_type, _args) do
  # Attach telemetry handlers
  :telemetry.attach_many(
    "sandbox-runtime-telemetry",
    [
      [:sandbox_runtime, :config, :loaded],
      [:sandbox_runtime, :proxy, :started],
      [:sandbox_runtime, :violation, :added],
      [:sandbox_runtime, :command, :wrapped]
    ],
    &SandboxRuntime.Telemetry.handle_event/4,
    nil
  )

  # ...
end

# In telemetry.ex
def handle_event([:sandbox_runtime, :violation, :added], measurements, metadata, _config) do
  Logger.warning("Sandbox violation: #{inspect(metadata)}")
end
```

### 6. DynamicSupervisor for Proxy Management

**Pattern**: Start/stop proxies on demand

```elixir
defmodule SandboxRuntime.ProxySupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_http_proxy(port) do
    spec = {SandboxRuntime.HttpProxy, port: port}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_http_proxy do
    # Find and terminate child
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.find(fn {_, pid, _, [mod]} -> mod == SandboxRuntime.HttpProxy end)
    |> case do
      {_, pid, _, _} -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      nil -> :ok
    end
  end
end
```

### 7. NimbleOptions for Schema Validation

**Pattern**: Validate configuration schemas (replaces TypeScript Zod)

```elixir
defmodule SandboxRuntime.Config do
  @config_schema NimbleOptions.new!(
    sandbox: [
      type: :keyword_list,
      keys: [
        enabled: [type: :boolean, default: true],
        network: [
          type: :keyword_list,
          keys: [
            allow_unix_sockets: [type: {:list, :string}, default: []],
            allow_local_binding: [type: :boolean, default: false],
            http_proxy_port: [type: :integer, default: 8888],
            socks_proxy_port: [type: :integer, default: 1080]
          ]
        ]
      ]
    ],
    permissions: [
      type: :keyword_list,
      keys: [
        allow: [type: {:list, :string}, default: []],
        deny: [type: {:list, :string}, default: []]
      ]
    ]
  )

  def validate!(config) do
    NimbleOptions.validate!(config, @config_schema)
  end
end
```

### 8. Application Behavior with Runtime Configuration

**Pattern**: Use config/runtime.exs for dynamic configuration

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :sandbox_runtime,
    settings_path: System.get_env("SANDBOX_SETTINGS_PATH"),
    enable_telemetry: true
end

# lib/sandbox_runtime/application.ex
defmodule SandboxRuntime.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SandboxRuntime.ConfigServer,
      SandboxRuntime.ViolationStore,
      {DynamicSupervisor, name: SandboxRuntime.ProxySupervisor, strategy: :one_for_one},
      platform_children()
    ]

    opts = [strategy: :one_for_one, name: SandboxRuntime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp platform_children do
    case :os.type() do
      {:unix, :darwin} -> [SandboxRuntime.ViolationMonitor]
      {:unix, :linux} -> [SandboxRuntime.NetworkBridge]
      _ -> []
    end
  end
end
```

---

## Project Structure

### Mix Project Layout

```
sandbox_runtime/                      # Root project
├── mix.exs                          # Project definition
├── README.md                        # Documentation
├── LICENSE                          # Apache 2.0
├── .formatter.exs                   # Code formatting rules
├── .credo.exs                       # Static analysis config
│
├── config/
│   ├── config.exs                   # Compile-time config
│   ├── dev.exs                      # Development overrides
│   ├── test.exs                     # Test environment
│   └── runtime.exs                  # Runtime configuration
│
├── lib/
│   ├── sandbox_runtime.ex           # Public API module
│   ├── sandbox_runtime/
│   │   ├── application.ex           # OTP Application
│   │   ├── manager.ex               # Main GenServer (API entry)
│   │   ├── config_server.ex         # Configuration GenServer
│   │   ├── violation_store.ex       # ETS-backed violation tracking
│   │   ├── telemetry.ex             # Telemetry event handlers
│   │   │
│   │   ├── config/
│   │   │   ├── loader.ex            # Hierarchical config loading
│   │   │   ├── schema.ex            # NimbleOptions schemas
│   │   │   └── parser.ex            # JSON settings parsing
│   │   │
│   │   ├── proxy/
│   │   │   ├── http_proxy.ex        # HTTP/HTTPS proxy GenServer
│   │   │   ├── socks_proxy.ex       # SOCKS5 proxy GenServer
│   │   │   └── domain_filter.ex     # Domain allowlist/denylist
│   │   │
│   │   ├── platform/
│   │   │   ├── detector.ex          # Platform detection
│   │   │   ├── macos.ex             # Seatbelt profile generation
│   │   │   ├── linux.ex             # Bubblewrap command generation
│   │   │   ├── violation_monitor.ex # macOS log stream (Port)
│   │   │   └── network_bridge.ex    # Linux socat bridges (Port)
│   │   │
│   │   └── utils/
│   │       ├── path.ex              # Path normalization
│   │       ├── glob.ex              # Glob pattern matching
│   │       ├── dangerous_files.ex   # Dangerous file detection (rg)
│   │       └── command_builder.ex   # Shell command construction
│   │
│   └── mix/
│       └── tasks/
│           └── sandbox.ex           # Mix task: mix sandbox <cmd>
│
├── test/
│   ├── test_helper.exs              # Test setup
│   ├── sandbox_runtime_test.exs     # Integration tests
│   ├── config/
│   │   └── loader_test.exs
│   ├── proxy/
│   │   ├── http_proxy_test.exs
│   │   └── socks_proxy_test.exs
│   ├── platform/
│   │   ├── macos_test.exs
│   │   └── linux_test.exs
│   └── support/
│       ├── fixtures/                # Test config files
│       └── test_helpers.ex
│
└── priv/
    ├── templates/
    │   ├── seatbelt.profile.eex     # macOS profile template
    │   └── bwrap.sh.eex             # Linux bwrap script template
    └── dangerous_files.txt           # List of dangerous file patterns
```

### mix.exs Configuration

```elixir
defmodule SandboxRuntime.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/your-org/sandbox_runtime"

  def project do
    [
      app: :sandbox_runtime,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex package
      package: package(),
      description: "OS-level sandboxing for Elixir applications",

      # Documentation
      docs: docs(),

      # Code quality
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl],
      mod: {SandboxRuntime.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:jason, "~> 1.4"},              # JSON parsing
      {:nimble_options, "~> 1.1"},     # Schema validation
      {:telemetry, "~> 1.3"},          # Observability
      {:plug, "~> 1.16"},              # HTTP proxy server
      {:bandit, "~> 1.6"},             # HTTP server adapter

      # Development & Testing
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.2", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "SandboxRuntime",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core": [
          SandboxRuntime,
          SandboxRuntime.Manager,
          SandboxRuntime.Application
        ],
        "Configuration": [
          SandboxRuntime.Config,
          SandboxRuntime.ConfigServer
        ],
        "Proxies": [
          SandboxRuntime.HttpProxy,
          SandboxRuntime.SocksProxy
        ],
        "Platform Support": [
          SandboxRuntime.Platform.MacOS,
          SandboxRuntime.Platform.Linux
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix]
    ]
  end
end
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal**: Core OTP structure and configuration system

**Tasks**:
1. Create Mix project: `mix new sandbox_runtime --sup`
2. Implement `SandboxRuntime.Application` supervision tree
3. Build configuration system:
   - `Config.Loader` - hierarchical loading
   - `Config.Schema` - NimbleOptions schemas
   - `ConfigServer` - GenServer state management
4. Implement `ViolationStore` with ETS
5. Add Telemetry infrastructure
6. Write unit tests for config loading

**Deliverable**: `mix test` passes; config can be loaded from files

---

### Phase 2: macOS Platform Support (Week 3-4)

**Goal**: Seatbelt profile generation and sandbox-exec integration

**Tasks**:
1. Implement `Platform.Detector` - OS detection
2. Build `Platform.MacOS`:
   - Seatbelt profile generation from config
   - Glob-to-regex conversion
   - Path normalization
3. Implement `Utils.DangerousFiles` - ripgrep integration
4. Create `ViolationMonitor` GenServer with Port for `log stream`
5. Implement `Manager.wrap_with_sandbox/1` for macOS
6. Add EEx template for Seatbelt profiles
7. Integration tests with actual sandbox-exec

**Deliverable**: Can sandbox simple commands on macOS (e.g., `curl`, `cat`)

---

### Phase 3: HTTP/SOCKS Proxy System (Week 5-6)

**Goal**: Network filtering via proxy servers

**Tasks**:
1. Implement `HttpProxy` GenServer using Plug:
   - Request interception
   - Domain allowlist/denylist filtering
   - CONNECT tunnel handling for HTTPS
2. Implement `SocksProxy` GenServer:
   - SOCKS5 protocol handling
   - TCP connection filtering
3. Create `Proxy.DomainFilter` module:
   - Wildcard pattern matching
   - Subdomain handling
4. Integrate proxies into supervision tree via `DynamicSupervisor`
5. Add environment variable injection (HTTP_PROXY, HTTPS_PROXY, ALL_PROXY)
6. Write proxy tests with mock HTTP/TCP servers

**Deliverable**: Network requests filtered through proxies

---

### Phase 4: Linux Platform Support (Week 7-8)

**Goal**: Bubblewrap integration and network namespace bridging

**Tasks**:
1. Implement `Platform.Linux`:
   - Bubblewrap command generation
   - Bind mount path construction
   - Network namespace setup
2. Implement `NetworkBridge` GenServer:
   - Manage socat bridge processes (Ports)
   - Unix socket lifecycle
   - Error recovery
3. Handle weaker nested sandbox mode
4. Linux-specific integration tests

**Deliverable**: Can sandbox commands on Linux with network isolation

---

### Phase 5: Public API & Mix Tasks (Week 9)

**Goal**: Developer-friendly interface

**Tasks**:
1. Finalize `SandboxRuntime` public API:
   ```elixir
   # Library usage
   SandboxRuntime.start_link()
   SandboxRuntime.wrap_with_sandbox("npm install")
   SandboxRuntime.get_violations()

   # With options
   SandboxRuntime.wrap_with_sandbox(
     "curl example.com",
     allow: ["WebFetch(domain:example.com)"]
   )
   ```

2. Create Mix task:
   ```bash
   mix sandbox "curl anthropic.com"
   mix sandbox --debug "npm install"
   ```

3. Add `use SandboxRuntime` macro for easy integration:
   ```elixir
   defmodule MyApp.SandboxedTask do
     use SandboxRuntime

     def run do
       execute_sandboxed("external-script.sh")
     end
   end
   ```

4. Write comprehensive documentation (ExDoc)
5. Create example projects

**Deliverable**: Published to Hex.pm (beta)

---

### Phase 6: Advanced Features (Week 10-11)

**Goal**: Feature parity with TypeScript version

**Tasks**:
1. Implement command-specific violation ignoring
2. Add Unix socket filtering
3. Support custom proxy configurations
4. Add violation callback mechanism:
   ```elixir
   SandboxRuntime.start_link(
     on_violation: fn violation ->
       Logger.error("Sandbox violation: #{inspect(violation)}")
       # Optionally deny/allow
       :deny
     end
   )
   ```
5. Implement settings file watching (hot reload)
6. Add performance optimizations (profile generation caching)

**Deliverable**: Full feature parity + Elixir-specific enhancements

---

### Phase 7: Testing & Documentation (Week 12)

**Goal**: Production readiness

**Tasks**:
1. Achieve >90% test coverage
2. Add property-based tests (StreamData):
   - Config parsing edge cases
   - Glob pattern matching
   - Path normalization
3. Write comprehensive guides:
   - Getting Started
   - Configuration Reference
   - Platform-Specific Notes
   - Security Considerations
4. Create comparison table vs. TypeScript version
5. Add troubleshooting guide
6. Record demo videos

**Deliverable**: 1.0.0 release candidate

---

## Technical Specifications

### Core APIs

#### Main Module: `SandboxRuntime`

```elixir
defmodule SandboxRuntime do
  @moduledoc """
  OS-level sandboxing for Elixir applications.

  Provides process isolation using native OS primitives:
  - macOS: Seatbelt (sandbox-exec)
  - Linux: bubblewrap

  ## Examples

      iex> SandboxRuntime.wrap_with_sandbox("curl anthropic.com")
      {:ok, "sandbox-exec -p '(version 1)...' curl anthropic.com"}

      iex> SandboxRuntime.execute_sandboxed("cat ~/.ssh/id_rsa")
      {:error, :permission_denied}
  """

  @doc """
  Wraps a command with sandboxing.

  Returns the sandboxed command string that can be executed via
  System.cmd/3 or Port.open/2.

  ## Options

  - `:allow` - List of permission strings (e.g., ["WebFetch(domain:github.com)"])
  - `:deny` - List of denial strings
  - `:debug` - Enable debug logging
  """
  @spec wrap_with_sandbox(command :: String.t(), opts :: keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def wrap_with_sandbox(command, opts \\ [])

  @doc """
  Executes a sandboxed command and returns output.

  Convenience wrapper around wrap_with_sandbox/2 + System.cmd/3.
  """
  @spec execute_sandboxed(command :: String.t(), opts :: keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def execute_sandboxed(command, opts \\ [])

  @doc """
  Returns all recorded sandbox violations.
  """
  @spec get_violations() :: [violation()]
  def get_violations()

  @doc """
  Checks if sandboxing is enabled and available on this platform.
  """
  @spec sandboxing_enabled?() :: boolean()
  def sandboxing_enabled?()

  @doc """
  Resets sandbox state (stops proxies, clears violations).
  """
  @spec reset() :: :ok
  def reset()
end
```

#### Configuration Schema

```elixir
defmodule SandboxRuntime.Config do
  @type t :: %{
    sandbox: %{
      enabled: boolean(),
      network: %{
        allow_unix_sockets: [String.t()],
        allow_local_binding: boolean(),
        http_proxy_port: integer(),
        socks_proxy_port: integer()
      }
    },
    permissions: %{
      allow: [String.t()],
      deny: [String.t()]
    }
  }
end
```

#### Permission String Format

```elixir
# Network permissions
"WebFetch(domain:github.com)"        # Allow github.com and subdomains
"WebFetch(domain:*.example.com)"     # Allow subdomains only
"WebFetch(tcp:localhost:5432)"       # Allow TCP to localhost:5432

# Filesystem permissions
"Read(/path/to/dir)"                 # Allow read access
"Edit(/path/to/file)"                # Allow write access
"Edit(./src/**/*.ex)"                # Glob pattern (macOS only)

# Unix sockets
"UnixSocket(/var/run/docker.sock)"   # Allow Unix socket access
```

---

### Platform-Specific Implementation Details

#### macOS: Seatbelt Profile Generation

```elixir
defmodule SandboxRuntime.Platform.MacOS do
  @moduledoc """
  Generates Seatbelt sandbox profiles for macOS.

  Uses sandbox-exec with custom profiles written in TinyScheme
  (Lisp-like syntax).
  """

  @doc """
  Generates a Seatbelt profile from configuration.
  """
  @spec generate_profile(config :: Config.t()) :: String.t()
  def generate_profile(config) do
    """
    (version 1)
    (debug deny)
    (allow default)

    ;; Deny filesystem writes by default
    (deny file-write*)

    ;; Allow specific paths
    #{generate_write_rules(config.fs_write)}

    ;; Deny specific reads
    #{generate_read_denials(config.fs_read)}

    ;; Network restrictions
    #{generate_network_rules(config.network)}
    """
  end

  @doc """
  Wraps command with sandbox-exec.
  """
  @spec wrap_command(command :: String.t(), profile :: String.t()) :: String.t()
  def wrap_command(command, profile) do
    # Write profile to temp file
    profile_path = write_temp_profile(profile)

    "sandbox-exec -f #{profile_path} sh -c #{Shellwords.escape(command)}"
  end
end
```

**Example Generated Profile**:
```scheme
(version 1)
(debug deny)
(allow default)

;; Deny all writes
(deny file-write*)

;; Allow writing to specific paths
(allow file-write* (subpath "/Users/me/project/src"))
(allow file-write* (regex #"^/Users/me/project/test/.*\\.exs$"))

;; Deny reading sensitive files
(deny file-read* (subpath "/Users/me/.ssh"))
(deny file-read* (literal "/Users/me/.env"))

;; Network: allow only proxy ports
(deny network*)
(allow network* (remote ip "localhost:8888"))
(allow network* (remote ip "localhost:1080"))
```

#### Linux: Bubblewrap Command Generation

```elixir
defmodule SandboxRuntime.Platform.Linux do
  @moduledoc """
  Generates bubblewrap commands for Linux sandboxing.

  Creates isolated namespaces for network, PID, and filesystem.
  """

  @doc """
  Generates a bwrap command from configuration.
  """
  @spec generate_command(command :: String.t(), config :: Config.t()) :: String.t()
  def generate_command(command, config) do
    base_args = [
      "bwrap",
      "--unshare-all",              # Unshare all namespaces
      "--share-net",                # Re-share network for proxy access
      "--die-with-parent",          # Terminate if parent dies
      "--ro-bind", "/", "/",        # Read-only root
      "--dev", "/dev",              # Device access
      "--proc", "/proc",            # Process info
      "--tmpfs", "/tmp"             # Writable temp
    ]

    write_binds = generate_write_binds(config.fs_write)
    read_denials = generate_read_denials(config.fs_read)
    network_setup = generate_network_setup(config.network)

    (base_args ++ write_binds ++ read_denials ++ network_setup ++ ["--", "sh", "-c", command])
    |> Enum.join(" ")
  end

  defp generate_write_binds(fs_write_config) do
    fs_write_config.allow_only
    |> Enum.flat_map(fn path ->
      ["--bind", path, path]
    end)
  end
end
```

**Example Generated Command**:
```bash
bwrap \
  --unshare-all \
  --share-net \
  --die-with-parent \
  --ro-bind / / \
  --dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --bind /home/user/project/src /home/user/project/src \
  --bind /home/user/project/test /home/user/project/test \
  --tmpfs /home/user/.ssh \
  --setenv HTTP_PROXY http://localhost:3128 \
  --setenv HTTPS_PROXY http://localhost:3128 \
  -- sh -c "npm install"
```

---

### HTTP Proxy Implementation

```elixir
defmodule SandboxRuntime.HttpProxy do
  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  # Regular HTTP requests
  match _ do
    case check_domain_allowed(conn.host) do
      :allow -> proxy_request(conn)
      :deny ->
        :telemetry.execute([:sandbox_runtime, :violation, :http], %{}, %{
          domain: conn.host,
          method: conn.method
        })
        send_resp(conn, 403, "Domain not allowed: #{conn.host}")
    end
  end

  defp proxy_request(conn) do
    # Forward to actual destination
    target_url = "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}"

    case HTTPoison.request(conn.method, target_url, conn.body_params, conn.req_headers) do
      {:ok, response} ->
        conn
        |> put_resp_headers(response.headers)
        |> send_resp(response.status_code, response.body)

      {:error, reason} ->
        send_resp(conn, 502, "Proxy error: #{inspect(reason)}")
    end
  end

  defp check_domain_allowed(domain) do
    config = SandboxRuntime.ConfigServer.get_network_config()
    SandboxRuntime.Proxy.DomainFilter.check(domain, config)
  end
end
```

---

### Telemetry Events

```elixir
# Config loaded
:telemetry.execute(
  [:sandbox_runtime, :config, :loaded],
  %{duration: 123},
  %{source: :file, path: "/path/to/settings.json"}
)

# Proxy started
:telemetry.execute(
  [:sandbox_runtime, :proxy, :started],
  %{},
  %{type: :http, port: 8888}
)

# Violation detected
:telemetry.execute(
  [:sandbox_runtime, :violation, :added],
  %{count: 1},
  %{type: :network, domain: "blocked.com", operation: "WebFetch"}
)

# Command wrapped
:telemetry.execute(
  [:sandbox_runtime, :command, :wrapped],
  %{duration: 45},
  %{platform: :macos, command: "npm install"}
)
```

---

## Testing Strategy

### Test Pyramid

```
             /\
            /  \  E2E Tests (10%)
           /____\
          /      \  Integration Tests (30%)
         /________\
        /          \
       /____________\ Unit Tests (60%)
```

### Unit Tests

**Focus**: Individual modules in isolation

```elixir
defmodule SandboxRuntime.Config.LoaderTest do
  use ExUnit.Case

  describe "load_hierarchical/1" do
    test "merges user and project settings correctly" do
      # Setup fixtures
      user_config = %{sandbox: %{enabled: true}}
      project_config = %{permissions: %{allow: ["Read(.)"]}}

      result = Loader.merge_configs([user_config, project_config])

      assert result.sandbox.enabled == true
      assert result.permissions.allow == ["Read(.)"]
    end

    test "project settings override user settings" do
      # ...
    end
  end
end
```

### Integration Tests

**Focus**: Component interactions (GenServers, Ports, Proxies)

```elixir
defmodule SandboxRuntime.ProxyIntegrationTest do
  use ExUnit.Case

  setup do
    # Start supervision tree
    start_supervised!(SandboxRuntime.Application)
    :ok
  end

  test "HTTP proxy filters blocked domains" do
    # Start proxy
    {:ok, _pid} = SandboxRuntime.ProxySupervisor.start_http_proxy(8888)

    # Configure to deny example.com
    SandboxRuntime.ConfigServer.update_config(%{
      permissions: %{deny: ["WebFetch(domain:example.com)"]}
    })

    # Make request through proxy
    result = HTTPoison.get("http://example.com", [], proxy: "http://localhost:8888")

    assert {:error, _} = result
    assert [violation | _] = SandboxRuntime.get_violations()
    assert violation.domain == "example.com"
  end
end
```

### End-to-End Tests

**Focus**: Real sandboxed command execution

```elixir
defmodule SandboxRuntime.E2ETest do
  use ExUnit.Case

  @moduletag :e2e

  setup do
    start_supervised!(SandboxRuntime.Application)
    :ok
  end

  test "blocks reading sensitive files on macOS", %{platform: :macos} do
    # Create test file
    ssh_dir = Path.expand("~/.ssh")
    File.mkdir_p!(ssh_dir)
    test_key = Path.join(ssh_dir, "test_key")
    File.write!(test_key, "SECRET")

    # Configure to deny SSH access
    config = %{permissions: %{deny: ["Read(~/.ssh)"]}}

    # Try to read file
    {:ok, sandboxed_cmd} = SandboxRuntime.wrap_with_sandbox(
      "cat #{test_key}",
      config: config
    )

    {output, exit_code} = System.cmd("sh", ["-c", sandboxed_cmd])

    # Should fail
    assert exit_code != 0
    assert output =~ "Operation not permitted"

    # Cleanup
    File.rm!(test_key)
  end

  test "allows network requests to allowed domains" do
    config = %{permissions: %{allow: ["WebFetch(domain:httpbin.org)"]}}

    {:ok, output} = SandboxRuntime.execute_sandboxed(
      "curl -s http://httpbin.org/get",
      config: config
    )

    assert output =~ "httpbin.org"
  end
end
```

### Property-Based Tests

**Focus**: Edge cases and invariants

```elixir
defmodule SandboxRuntime.GlobTest do
  use ExUnit.Case
  use ExUnitProperties

  property "glob patterns correctly match file paths" do
    check all pattern <- glob_pattern_generator(),
              path <- file_path_generator() do

      # Convert glob to regex
      regex = SandboxRuntime.Utils.Glob.to_regex(pattern)

      # Should match consistently
      manual_match = glob_matches?(pattern, path)
      regex_match = Regex.match?(regex, path)

      assert manual_match == regex_match
    end
  end

  defp glob_pattern_generator do
    one_of([
      constant("*.ex"),
      constant("src/**/*.exs"),
      constant("test/[abc]_test.exs")
    ])
  end
end
```

### Test Coverage Goals

- **Unit tests**: >95% coverage
- **Integration tests**: All major workflows (proxy, platform, config)
- **E2E tests**: Platform-specific (macOS/Linux CI runners)
- **Property tests**: Glob, path normalization, config merging

### CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test_macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18'
          otp-version: '27'
      - run: brew install ripgrep
      - run: mix deps.get
      - run: mix test
      - run: mix coveralls.github

  test_linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
      - run: sudo apt-get update && sudo apt-get install -y bubblewrap socat ripgrep
      - run: mix deps.get
      - run: mix test

  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: erlef/setup-beam@v1
      - run: mix format --check-formatted
      - run: mix credo --strict
      - run: mix dialyzer
```

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Port communication overhead** | Medium | Low | Benchmark against TypeScript; optimize with binary protocols |
| **macOS log stream parsing brittleness** | High | Medium | Implement robust regex parsing; test across macOS versions |
| **Bubblewrap compatibility issues** | High | Medium | Test on multiple Linux distros; provide weaker nested mode |
| **Proxy server performance** | Medium | Medium | Use Bandit (fast HTTP/2); benchmark with wrk/ab |
| **Glob-to-regex conversion bugs** | High | Medium | Extensive property-based tests; compare with gitignore |

### Platform Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **macOS Seatbelt deprecation** | High | Low | Monitor Apple docs; prepare fallback (App Sandbox?) |
| **Bubblewrap not installed** | Medium | High | Clear error messages; auto-install script for dev |
| **Windows unsupported** | Low | N/A | Document limitation; potential WSL2 support later |

### Operational Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Sandbox escape vulnerabilities** | Critical | Low | Security audit; bug bounty program; clear docs on limitations |
| **Performance regression vs. TypeScript** | Medium | Medium | Continuous benchmarking; profile with fprof |
| **Breaking API changes** | Medium | Low | Semantic versioning; deprecation warnings |

### Security Considerations

1. **Not a security boundary**: Document that sandbox is defense-in-depth, not isolation
2. **Dangerous file detection**: Keep `priv/dangerous_files.txt` updated
3. **Proxy bypass**: Warn about domain fronting, localhost binding risks
4. **Unix socket risks**: Highlight Docker socket implications
5. **Code review**: All platform-specific code should be reviewed for injection vulnerabilities

---

## Success Metrics

### Functional Goals

- [ ] Can sandbox commands on macOS (Seatbelt)
- [ ] Can sandbox commands on Linux (bubblewrap)
- [ ] HTTP/HTTPS requests filtered via proxy
- [ ] SOCKS5 proxy for TCP traffic
- [ ] Filesystem read/write restrictions enforced
- [ ] Violations detected and logged
- [ ] Configuration loads from multiple sources
- [ ] Telemetry events emitted

### Quality Goals

- [ ] >90% test coverage
- [ ] All Dialyzer warnings resolved
- [ ] Credo score: A+
- [ ] Documentation completeness: 100% @doc coverage
- [ ] Performance: <50ms overhead for command wrapping
- [ ] CI passing on macOS + Linux

### Adoption Goals

- [ ] Published to Hex.pm
- [ ] ExDoc documentation live
- [ ] README with quick start guide
- [ ] 3+ example projects
- [ ] Blog post announcement
- [ ] Elixir Forum discussion thread

---

## Next Steps

1. **Review this plan** with stakeholders
2. **Set up project**: `mix new sandbox_runtime --sup`
3. **Create GitHub repo**: anthropic-experimental/sandbox-runtime-ex
4. **Start Phase 1**: Configuration system implementation
5. **Weekly progress reviews**: Document learnings and blockers

---

## Appendices

### A. Permission String Grammar

```ebnf
permission     = permission_type "(" parameter ")"
permission_type = "WebFetch" | "Read" | "Edit" | "UnixSocket" | "TCP"
parameter      = key ":" value
key            = "domain" | "path" | "tcp"
value          = string | glob_pattern | wildcard

glob_pattern   = string containing "*", "**", "[abc]", "?"
wildcard       = "*.example.com" | "example.*"
```

### B. Configuration File Example

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "allowUnixSockets": ["/var/run/docker.sock"],
      "allowLocalBinding": false,
      "httpProxyPort": 8888,
      "socksProxyPort": 1080
    }
  },
  "permissions": {
    "allow": [
      "WebFetch(domain:github.com)",
      "WebFetch(domain:npmjs.org)",
      "WebFetch(domain:hex.pm)",
      "Read(.)",
      "Edit(./src)",
      "Edit(./test)"
    ],
    "deny": [
      "Read(~/.ssh)",
      "Read(~/.aws)",
      "Edit(.env)",
      "Edit(.env.production)",
      "WebFetch(domain:malicious.com)"
    ]
  }
}
```

### C. Comparison: TypeScript vs Elixir

| Aspect | TypeScript Version | Elixir Version |
|--------|-------------------|----------------|
| **Lines of Code** | ~3,560 lines | Est. ~2,500 lines |
| **Concurrency** | Single-threaded (Node.js) | Multi-process (BEAM) |
| **Proxy Implementation** | Custom HTTP server | Plug + Bandit |
| **State Management** | In-memory objects | GenServer + ETS |
| **Process Management** | child_process.spawn | Port + supervision trees |
| **Configuration** | JSON + Zod | Elixir Config + NimbleOptions |
| **Observability** | Custom logging | Telemetry |
| **Testing** | No formal tests | ExUnit + property tests |
| **Package Manager** | npm | Hex |
| **Type Safety** | TypeScript | Dialyzer |

**Advantages of Elixir Version**:
- Superior fault tolerance (supervision trees)
- Better concurrency (BEAM scheduler)
- Built-in hot code reloading
- Robust Port communication
- Telemetry ecosystem
- Better observability

**Challenges**:
- Smaller ecosystem for HTTP proxies
- Port overhead vs. direct bindings
- Learning curve for Elixir developers

---

## Conclusion

This plan provides a comprehensive roadmap for implementing a production-grade Elixir sandbox runtime. By leveraging modern OTP patterns (GenServer, supervision trees, Ports, Telemetry), we can create a more robust and maintainable solution than the TypeScript version while maintaining feature parity.

The phased approach ensures incremental delivery, with macOS support first (simpler) followed by Linux (more complex). The testing strategy guarantees reliability, and the use of Elixir's strengths (concurrency, fault tolerance, observability) positions this library as a foundational tool for safe AI agent execution in the Elixir ecosystem.

**Estimated Timeline**: 12 weeks to 1.0.0 release
**Team Size**: 1-2 Elixir developers
**Risk Level**: Medium (mitigated by thorough testing and phased rollout)

---

**Document Version**: 1.0
**Last Updated**: 2025-10-21
**Author**: Claude (Anthropic)
**Status**: Ready for Implementation
