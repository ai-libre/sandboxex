defmodule SandboxRuntime.Platform.MacOS do
  @moduledoc """
  macOS-specific sandboxing using Seatbelt (sandbox-exec).

  Generates Seatbelt sandbox profiles and wraps commands.
  """

  require Logger

  alias SandboxRuntime.Utils.{Path, Glob, DangerousFiles, CommandBuilder}

  @doc """
  Generates a Seatbelt sandbox profile from configuration.

  Returns {:ok, profile_content} or {:error, reason}.
  """
  @spec generate_profile(map()) :: {:ok, String.t()} | {:error, term()}
  def generate_profile(config) do
    fs_read = Map.get(config, :fs_read, %{deny_only: []})
    fs_write = Map.get(config, :fs_write, %{allow_only: [], deny_within_allow: []})
    network = get_in(config, [:sandbox, :network]) || %{}

    # Scan for dangerous files
    {:ok, dangerous_files} = DangerousFiles.scan()

    profile = """
    (version 1)
    (debug deny)
    (allow default)

    ;;; Filesystem Write Restrictions
    ;; Deny all writes by default
    (deny file-write*)

    ;; Allow writing to temp directories
    (allow file-write* (subpath "/tmp"))
    (allow file-write* (subpath "/var/tmp"))
    (allow file-write* (regex #"^/private/var/folders/[^/]+/[^/]+/[TC]/"))

    #{generate_write_allows(fs_write)}
    #{generate_write_denials(fs_write, dangerous_files)}

    ;;; Filesystem Read Restrictions
    #{generate_read_denials(fs_read)}

    ;;; Network Restrictions
    #{generate_network_rules(network)}

    ;;; Process Restrictions
    (allow process-exec*)
    (allow process-fork)

    ;;; IPC and System
    (allow ipc-posix-shm*)
    (allow sysctl-read)
    (allow mach-lookup)
    """

    {:ok, profile}
  end

  @doc """
  Wraps a command with sandbox-exec using the given profile.
  """
  @spec wrap_command(String.t(), String.t()) :: String.t()
  def wrap_command(command, profile) do
    # Write profile to temporary file
    profile_path = write_temp_profile(profile)

    # Build sandbox-exec command
    "sandbox-exec -f #{CommandBuilder.escape(profile_path)} sh -c #{CommandBuilder.escape(command)}"
  end

  # Private Helpers

  defp generate_write_allows(fs_write) do
    allow_only = Map.get(fs_write, :allow_only, [])

    if Enum.empty?(allow_only) do
      ""
    else
      allows =
        allow_only
        |> Enum.map(&Path.normalize/1)
        |> Enum.map(&generate_write_allow_rule/1)
        |> Enum.join("\n")

      ";; Allowed write paths\n" <> allows
    end
  end

  defp generate_write_allow_rule(path) do
    if Glob.has_wildcards?(path) do
      # Convert glob to regex
      regex = Glob.to_regex(path)
      regex_str = Regex.source(regex)
      "(allow file-write* (regex #\"#{escape_regex(regex_str)}\"))"
    else
      # Use subpath for literal paths
      "(allow file-write* (subpath \"#{escape_path(path)}\"))"
    end
  end

  defp generate_write_denials(fs_write, dangerous_files) do
    deny_within_allow = Map.get(fs_write, :deny_within_allow, [])
    all_denials = (deny_within_allow ++ dangerous_files) |> Enum.uniq()

    if Enum.empty?(all_denials) do
      ""
    else
      denials =
        all_denials
        |> Enum.map(&Path.normalize/1)
        |> Enum.map(fn path ->
          "(deny file-write* (subpath \"#{escape_path(path)}\"))"
        end)
        |> Enum.join("\n")

      ";; Denied write paths (dangerous files)\n" <> denials
    end
  end

  defp generate_read_denials(fs_read) do
    deny_only = Map.get(fs_read, :deny_only, [])

    if Enum.empty?(deny_only) do
      ""
    else
      denials =
        deny_only
        |> Enum.map(&Path.normalize/1)
        |> Enum.map(&generate_read_deny_rule/1)
        |> Enum.join("\n")

      ";; Denied read paths\n" <> denials
    end
  end

  defp generate_read_deny_rule(path) do
    if Glob.has_wildcards?(path) do
      regex = Glob.to_regex(path)
      regex_str = Regex.source(regex)
      "(deny file-read* (regex #\"#{escape_regex(regex_str)}\"))"
    else
      "(deny file-read* (subpath \"#{escape_path(path)}\"))"
    end
  end

  defp generate_network_rules(network) do
    http_port = Map.get(network, :http_proxy_port, 8888)
    socks_port = Map.get(network, :socks_proxy_port, 1080)

    """
    ;; Network: Allow only proxy connections
    (deny network*)
    (allow network* (remote ip "localhost:#{http_port}"))
    (allow network* (remote ip "127.0.0.1:#{http_port}"))
    (allow network* (remote ip "localhost:#{socks_port}"))
    (allow network* (remote ip "127.0.0.1:#{socks_port}"))
    (allow network-inbound (local ip "localhost:*"))
    """
  end

  defp write_temp_profile(profile) do
    # Create temp directory if it doesn't exist
    temp_dir = Path.join(System.tmp_dir!(), "sandbox_runtime")
    File.mkdir_p!(temp_dir)

    # Generate unique filename
    timestamp = System.system_time(:millisecond)
    filename = "profile_#{timestamp}.sb"
    path = Path.join(temp_dir, filename)

    # Write profile
    File.write!(path, profile)

    path
  end

  defp escape_path(path) do
    String.replace(path, "\"", "\\\"")
  end

  defp escape_regex(regex) do
    String.replace(regex, "\"", "\\\"")
  end
end
