defmodule SandboxRuntime.Config.Parser do
  @moduledoc """
  Parses permission strings and converts them to internal format.
  """

  @doc """
  Parses permission strings into structured configuration.

  ## Examples

      iex> parse_permissions(["WebFetch(domain:github.com)"])
      %{network_allow: ["github.com"]}

      iex> parse_permissions(["Read(~/.ssh)", "Edit(./src)"])
      %{fs_read: %{deny_only: ["~/.ssh"]}, fs_write: %{allow_only: ["./src"]}}
  """
  @spec parse_permissions([String.t()]) :: map()
  def parse_permissions(permission_strings) when is_list(permission_strings) do
    Enum.reduce(permission_strings, %{}, fn perm, acc ->
      parse_permission(perm, acc)
    end)
  end

  @doc """
  Parses a single permission string.
  """
  @spec parse_permission(String.t(), map()) :: map()
  def parse_permission(perm_string, acc \\ %{}) do
    case Regex.run(~r/^(\w+)\(([^:]+):(.+)\)$/, perm_string) do
      [_, type, key, value] ->
        apply_permission(type, key, value, acc)

      nil ->
        # Try simpler format: Read(path) or Edit(path)
        case Regex.run(~r/^(Read|Edit|Execute)\((.+)\)$/, perm_string) do
          [_, type, path] ->
            apply_fs_permission(type, path, acc)

          nil ->
            acc
        end
    end
  end

  # Private Helpers

  defp apply_permission("WebFetch", "domain", domain, acc) do
    Map.update(acc, :network_allow, [domain], &(&1 ++ [domain]))
  end

  defp apply_permission("WebFetch", "tcp", tcp_spec, acc) do
    Map.update(acc, :tcp_allow, [tcp_spec], &(&1 ++ [tcp_spec]))
  end

  defp apply_permission("UnixSocket", "path", socket_path, acc) do
    Map.update(acc, :unix_sockets, [socket_path], &(&1 ++ [socket_path]))
  end

  defp apply_permission(_type, _key, _value, acc), do: acc

  defp apply_fs_permission("Read", path, acc) do
    # Read denies (deny-only model)
    fs_read = Map.get(acc, :fs_read, %{deny_only: []})
    deny_list = Map.get(fs_read, :deny_only, [])
    updated_fs_read = Map.put(fs_read, :deny_only, deny_list ++ [path])
    Map.put(acc, :fs_read, updated_fs_read)
  end

  defp apply_fs_permission("Edit", path, acc) do
    # Write allows (allow-only model)
    fs_write = Map.get(acc, :fs_write, %{allow_only: [], deny_within_allow: []})
    allow_list = Map.get(fs_write, :allow_only, [])
    updated_fs_write = Map.put(fs_write, :allow_only, allow_list ++ [path])
    Map.put(acc, :fs_write, updated_fs_write)
  end

  defp apply_fs_permission(_type, _path, acc), do: acc

  @doc """
  Converts structured config back to permission strings.
  """
  @spec to_permission_strings(map()) :: [String.t()]
  def to_permission_strings(config) when is_map(config) do
    []
    |> add_network_permissions(config)
    |> add_fs_permissions(config)
  end

  defp add_network_permissions(acc, config) do
    network_allow = Map.get(config, :network_allow, [])

    Enum.reduce(network_allow, acc, fn domain, acc ->
      ["WebFetch(domain:#{domain})" | acc]
    end)
  end

  defp add_fs_permissions(acc, config) do
    acc
    |> add_fs_read_permissions(config)
    |> add_fs_write_permissions(config)
  end

  defp add_fs_read_permissions(acc, config) do
    fs_read = Map.get(config, :fs_read, %{})
    deny_only = Map.get(fs_read, :deny_only, [])

    Enum.reduce(deny_only, acc, fn path, acc ->
      ["Read(#{path})" | acc]
    end)
  end

  defp add_fs_write_permissions(acc, config) do
    fs_write = Map.get(config, :fs_write, %{})
    allow_only = Map.get(fs_write, :allow_only, [])

    Enum.reduce(allow_only, acc, fn path, acc ->
      ["Edit(#{path})" | acc]
    end)
  end
end
