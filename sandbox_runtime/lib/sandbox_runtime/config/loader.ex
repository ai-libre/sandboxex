defmodule SandboxRuntime.Config.Loader do
  @moduledoc """
  Loads configuration from multiple hierarchical sources.

  Configuration is loaded in the following order (later overrides earlier):
  1. Application config (config/*.exs)
  2. User settings (~/.sandbox/settings.json)
  3. Project settings (./.sandbox/settings.json)
  4. Local settings (./.sandbox/settings.local.json)
  5. Environment variables
  """

  require Logger

  @doc """
  Loads configuration from all sources hierarchically.
  """
  @spec load_hierarchical() :: {:ok, map()} | {:error, term()}
  def load_hierarchical do
    configs = [
      load_application_config(),
      load_user_config(),
      load_project_config(),
      load_local_config(),
      load_env_config()
    ]

    merged =
      configs
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(%{}, &deep_merge/2)

    parsed_config = parse_permissions_in_config(merged)

    {:ok, parsed_config}
  rescue
    e ->
      {:error, e}
  end

  @doc """
  Returns the default configuration.
  """
  @spec default_config() :: map()
  def default_config do
    %{
      sandbox: %{
        enabled: true,
        network: %{
          allow_unix_sockets: [],
          allow_local_binding: false,
          http_proxy_port: 8888,
          socks_proxy_port: 1080
        }
      },
      permissions: %{
        allow: [],
        deny: []
      },
      fs_read: %{
        deny_only: []
      },
      fs_write: %{
        allow_only: [],
        deny_within_allow: []
      }
    }
  end

  # Private Functions

  defp load_application_config do
    Application.get_all_env(:sandbox_runtime)
    |> Enum.into(%{})
  end

  defp load_user_config do
    home = System.user_home()
    path = Path.join([home, ".sandbox", "settings.json"])
    load_json_config(path)
  end

  defp load_project_config do
    path = Path.join([File.cwd!(), ".sandbox", "settings.json"])
    load_json_config(path)
  end

  defp load_local_config do
    path = Path.join([File.cwd!(), ".sandbox", "settings.local.json"])
    load_json_config(path)
  end

  defp load_env_config do
    case System.get_env("SANDBOX_SETTINGS_PATH") do
      nil -> nil
      path -> load_json_config(path)
    end
  end

  defp load_json_config(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, config} ->
              atomize_keys(config)

            {:error, reason} ->
              Logger.warning("Failed to parse JSON config at #{path}: #{inspect(reason)}")
              nil
          end

        {:error, reason} ->
          Logger.warning("Failed to read config at #{path}: #{inspect(reason)}")
          nil
      end
    else
      nil
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        {String.to_atom(k), atomize_keys(v)}

      {k, v} ->
        {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      deep_merge(left_val, right_val)
    end)
  end

  defp deep_merge(_left, right), do: right

  defp parse_permissions_in_config(config) do
    permissions = get_in(config, [:permissions]) || %{}
    allow = Map.get(permissions, :allow, [])
    deny = Map.get(permissions, :deny, [])

    # Parse allow permissions
    allow_parsed = SandboxRuntime.Config.Parser.parse_permissions(allow)

    # Parse deny permissions (for network)
    deny_parsed = parse_deny_permissions(deny)

    # Merge parsed permissions into config
    config
    |> deep_merge(allow_parsed)
    |> deep_merge(deny_parsed)
  end

  defp parse_deny_permissions(deny_list) do
    Enum.reduce(deny_list, %{}, fn perm, acc ->
      case Regex.run(~r/^WebFetch\(domain:(.+)\)$/, perm) do
        [_, domain] ->
          Map.update(acc, :network_deny, [domain], &(&1 ++ [domain]))

        nil ->
          # Handle filesystem denies
          case Regex.run(~r/^(Read|Edit)\((.+)\)$/, perm) do
            [_, "Read", path] ->
              fs_read = Map.get(acc, :fs_read, %{deny_only: []})
              deny_list = Map.get(fs_read, :deny_only, [])
              updated = Map.put(fs_read, :deny_only, deny_list ++ [path])
              Map.put(acc, :fs_read, updated)

            [_, "Edit", path] ->
              fs_write = Map.get(acc, :fs_write, %{allow_only: [], deny_within_allow: []})
              deny_list = Map.get(fs_write, :deny_within_allow, [])
              updated = Map.put(fs_write, :deny_within_allow, deny_list ++ [path])
              Map.put(acc, :fs_write, updated)

            _ ->
              acc
          end
      end
    end)
  end
end
