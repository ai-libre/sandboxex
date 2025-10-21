# SandboxRuntime

**OS-level sandboxing for Elixir applications** using native OS primitives (macOS Seatbelt, Linux bubblewrap).

Port of [@anthropic-ai/sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) to Elixir, providing process isolation for safer AI agent execution and untrusted code sandboxing.

## Features

- **Filesystem Isolation**: Read/write restrictions with glob pattern support
- **Network Filtering**: Domain-based allowlists/denylists via HTTP/SOCKS5 proxies
- **Process Isolation**: Native OS sandboxing (no containers needed)
- **Violation Monitoring**: Real-time tracking of sandbox violations
- **Platform Support**: macOS (Seatbelt) and Linux (bubblewrap)
- **OTP Architecture**: Fault-tolerant supervision trees
- **Telemetry Integration**: Built-in observability

## Installation

Add `sandbox_runtime` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sandbox_runtime, "~> 0.1.0"}
  ]
end
```

### System Dependencies

**macOS:**
```bash
brew install ripgrep
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install bubblewrap socat ripgrep
```

**Linux (Fedora):**
```bash
sudo dnf install bubblewrap socat ripgrep
```

## Quick Start

```elixir
# Wrap a command with sandboxing
{:ok, sandboxed_cmd} = SandboxRuntime.wrap_with_sandbox("curl anthropic.com")

# Execute directly
{:ok, output} = SandboxRuntime.execute_sandboxed("cat README.md")

# Check violations
violations = SandboxRuntime.get_violations()

# Get platform info
SandboxRuntime.platform_info()
# => %{platform: :macos, supported: true, dependencies: %{...}}
```

## Configuration

Configure in `config/config.exs`:

```elixir
config :sandbox_runtime,
  sandbox: %{
    enabled: true,
    network: %{
      http_proxy_port: 8888,
      socks_proxy_port: 1080,
      allow_unix_sockets: [],
      allow_local_binding: false
    }
  },
  permissions: %{
    allow: [
      "WebFetch(domain:github.com)",
      "WebFetch(domain:hex.pm)",
      "Read(.)",
      "Edit(./src)",
      "Edit(./test)"
    ],
    deny: [
      "Read(~/.ssh)",
      "Read(~/.aws)",
      "Edit(.env)",
      "WebFetch(domain:malicious.com)"
    ]
  }
```

### JSON Configuration Files

Create `.sandbox/settings.json`:

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "httpProxyPort": 8888,
      "socksProxyPort": 1080
    }
  },
  "permissions": {
    "allow": [
      "WebFetch(domain:github.com)",
      "Read(.)",
      "Edit(./src)"
    ],
    "deny": [
      "Read(~/.ssh)",
      "Edit(.env)"
    ]
  }
}
```

## Permission String Format

### Network Permissions

```elixir
"WebFetch(domain:github.com)"        # Allow github.com and subdomains
"WebFetch(domain:*.example.com)"     # Allow subdomains only
"WebFetch(tcp:localhost:5432)"       # Allow TCP connection
```

### Filesystem Permissions

```elixir
"Read(/path/to/dir)"                 # Deny read access (deny-only model)
"Edit(/path/to/file)"                # Allow write access (allow-only model)
"Edit(./src/**/*.ex)"                # Glob patterns (macOS only)
```

### Unix Sockets

```elixir
"UnixSocket(/var/run/docker.sock)"   # Allow Unix socket access
```

## Mix Task

Execute commands directly via Mix:

```bash
# Basic usage
mix sandbox "curl anthropic.com"

# With debug logging
mix sandbox --debug "npm install"

# Complex commands
mix sandbox "git clone https://github.com/user/repo.git && cd repo && mix test"
```

## Architecture

Built on modern Elixir/OTP patterns:

- **GenServer** with `handle_continue/2` for async initialization
- **Supervision trees** for fault tolerance
- **Port communication** for external process management
- **ETS** for fast concurrent violation tracking
- **Telemetry** for observability
- **DynamicSupervisor** for proxy lifecycle management

### Supervision Tree

```
SandboxRuntime.Application
└── SandboxRuntime.Supervisor
    ├── SandboxRuntime.ConfigServer
    ├── SandboxRuntime.ViolationStore
    ├── SandboxRuntime.ProxySupervisor (DynamicSupervisor)
    │   ├── SandboxRuntime.Proxy.HttpProxy
    │   └── SandboxRuntime.Proxy.SocksProxy
    └── Platform-specific (macOS: ViolationMonitor, Linux: NetworkBridge)
```

## Platform-Specific Details

### macOS (Seatbelt)

Uses `sandbox-exec` with dynamically generated Seatbelt profiles:

```scheme
(version 1)
(allow default)
(deny file-write*)
(allow file-write* (subpath "/allowed/path"))
(deny file-read* (subpath "~/.ssh"))
```

Real-time violation monitoring via `log stream`.

### Linux (bubblewrap)

Creates isolated namespaces with bind mounts:

```bash
bwrap \
  --unshare-all \
  --ro-bind / / \
  --bind /allowed/path /allowed/path \
  --tmpfs ~/.ssh \
  --setenv HTTP_PROXY http://localhost:8888 \
  -- sh -c "command"
```

Network bridges via `socat` for proxy communication.

## API Reference

### Core Functions

```elixir
# Wrap command
SandboxRuntime.wrap_with_sandbox(command, opts \\ [])

# Execute sandboxed
SandboxRuntime.execute_sandboxed(command, opts \\ [])

# Violations
SandboxRuntime.get_violations()
SandboxRuntime.get_violations_by_type(:network)
SandboxRuntime.clear_violations()
SandboxRuntime.violation_count()

# Configuration
SandboxRuntime.get_config()
SandboxRuntime.reload_config()

# Platform
SandboxRuntime.platform_info()
SandboxRuntime.sandboxing_enabled?()

# Lifecycle
SandboxRuntime.initialize()
SandboxRuntime.reset()
```

## Examples

### Sandboxing MCP Servers

```elixir
# In your MCP server launcher
defmodule MyApp.MCPLauncher do
  def launch_server(server_cmd) do
    {:ok, sandboxed} = SandboxRuntime.wrap_with_sandbox(
      server_cmd,
      config: %{
        permissions: %{
          allow: ["WebFetch(domain:api.example.com)", "Read(.)"],
          deny: ["Edit(.env)", "Read(~/.ssh)"]
        }
      }
    )

    Port.open({:spawn, sandboxed}, [:binary])
  end
end
```

### Monitoring Violations

```elixir
# Attach custom telemetry handler
:telemetry.attach(
  "my-violation-handler",
  [:sandbox_runtime, :violation, :added],
  fn _event, measurements, metadata, _config ->
    IO.puts("Violation detected: #{metadata.operation} on #{metadata.target}")
    # Send alert, log to external system, etc.
  end,
  nil
)
```

### Testing with Sandbox

```elixir
defmodule MyApp.SandboxTest do
  use ExUnit.Case

  test "blocks unauthorized file access" do
    SandboxRuntime.clear_violations()

    {:error, {:exit_code, _, _}} =
      SandboxRuntime.execute_sandboxed("cat ~/.ssh/id_rsa")

    violations = SandboxRuntime.get_violations()
    assert length(violations) > 0
  end
end
```

## Security Considerations

⚠️ **This sandbox is defense-in-depth, not a security boundary.**

**Provides:**
- Filesystem access restrictions
- Network domain filtering
- Process isolation

**Does NOT provide:**
- Memory isolation
- CPU/resource limits
- Protection against kernel exploits
- Protection against domain fronting
- Deep packet inspection

**Risks:**
- Unix socket access (e.g., Docker socket) can grant full host control
- Overly broad write permissions can enable privilege escalation
- Network filtering is domain-based, not content-based
- macOS Seatbelt may be deprecated in future OS versions

## Development

```bash
# Get dependencies
cd sandbox_runtime && mix deps.get

# Run tests
mix test

# Run tests with coverage
mix coveralls

# Format code
mix format

# Run static analysis
mix credo --strict

# Generate docs
mix docs

# Type checking
mix dialyzer
```

## Comparison: TypeScript vs Elixir

| Feature | TypeScript | Elixir |
|---------|-----------|---------|
| **Concurrency** | Single-threaded | Multi-process (BEAM) |
| **Fault Tolerance** | Process crashes | Supervision trees |
| **State Management** | In-memory objects | GenServer + ETS |
| **Observability** | Custom logging | Telemetry |
| **Hot Code Reload** | No | Yes |
| **Type Safety** | TypeScript | Dialyzer |

## Roadmap

- [ ] Support for custom proxy servers (mitmproxy, etc.)
- [ ] WSL2 support for Windows
- [ ] Resource limits (CPU, memory)
- [ ] Distributed mode (sandbox on remote nodes)
- [ ] Phoenix LiveView dashboard for monitoring
- [ ] Integration with Livebook

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure `mix test` passes
5. Run `mix format` and `mix credo`
6. Submit a pull request

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## Credits

Inspired by [@anthropic-ai/sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) (TypeScript).

Built with modern Elixir patterns based on:
- [Elixir Hexdocs](https://hexdocs.pm/elixir/)
- [OTP Design Principles](https://www.erlang.org/doc/design_principles/users_guide.html)
- [Phoenix Framework patterns](https://www.phoenixframework.org/)

## Support

- **Documentation**: [hexdocs.pm/sandbox_runtime](https://hexdocs.pm/sandbox_runtime)
- **Issues**: [GitHub Issues](https://github.com/ai-libre/sandbox_runtime/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ai-libre/sandbox_runtime/discussions)
