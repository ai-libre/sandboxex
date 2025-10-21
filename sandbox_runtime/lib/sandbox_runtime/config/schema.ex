defmodule SandboxRuntime.Config.Schema do
  @moduledoc """
  Configuration schema validation using NimbleOptions.
  """

  @config_schema [
    sandbox: [
      type: :map,
      keys: [
        enabled: [type: :boolean, default: true],
        network: [
          type: :map,
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
      type: :map,
      keys: [
        allow: [type: {:list, :string}, default: []],
        deny: [type: {:list, :string}, default: []]
      ]
    ],
    fs_read: [
      type: :map,
      keys: [
        deny_only: [type: {:list, :string}, default: []]
      ],
      default: %{deny_only: []}
    ],
    fs_write: [
      type: :map,
      keys: [
        allow_only: [type: {:list, :string}, default: []],
        deny_within_allow: [type: {:list, :string}, default: []]
      ],
      default: %{allow_only: [], deny_within_allow: []}
    ]
  ]

  @doc """
  Validates configuration against the schema.
  """
  @spec validate!(map()) :: map()
  def validate!(config) when is_map(config) do
    # Convert string keys to atoms for validation
    config =
      config
      |> atomize_keys()

    # Validate with NimbleOptions
    case NimbleOptions.validate(config, @config_schema) do
      {:ok, validated} ->
        validated

      {:error, %NimbleOptions.ValidationError{} = error} ->
        raise ArgumentError, "Invalid configuration: #{Exception.message(error)}"
    end
  end

  @doc """
  Returns the schema definition.
  """
  def schema, do: @config_schema

  # Private Helpers

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value
end
