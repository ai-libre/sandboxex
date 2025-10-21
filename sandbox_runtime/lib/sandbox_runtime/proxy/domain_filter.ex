defmodule SandboxRuntime.Proxy.DomainFilter do
  @moduledoc """
  Domain filtering for network proxy requests.

  Implements allowlist/denylist filtering with wildcard support.
  """

  @doc """
  Checks if a domain is allowed based on configuration.

  Returns :allow or :deny.
  """
  @spec check(String.t(), map()) :: :allow | :deny
  def check(domain, config) do
    network_allow = Map.get(config, :network_allow, [])
    network_deny = Map.get(config, :network_deny, [])

    cond do
      # If in deny list, deny
      matches_any?(domain, network_deny) ->
        :deny

      # If allow list is empty, allow all
      Enum.empty?(network_allow) ->
        :allow

      # If in allow list, allow
      matches_any?(domain, network_allow) ->
        :allow

      # Otherwise deny (allowlist mode)
      true ->
        :deny
    end
  end

  @doc """
  Checks if a domain matches any pattern in a list.

  Supports wildcards:
  - `*.example.com` - matches subdomains only
  - `example.com` - matches domain and all subdomains
  """
  @spec matches_any?(String.t(), [String.t()]) :: boolean()
  def matches_any?(domain, patterns) do
    Enum.any?(patterns, &matches?(domain, &1))
  end

  @doc """
  Checks if a domain matches a pattern.
  """
  @spec matches?(String.t(), String.t()) :: boolean()
  def matches?(domain, pattern) do
    cond do
      # Exact match
      domain == pattern ->
        true

      # Wildcard subdomain pattern: *.example.com
      String.starts_with?(pattern, "*.") ->
        suffix = String.slice(pattern, 2..-1//1)
        # Match subdomains only, not the domain itself
        String.ends_with?(domain, "." <> suffix)

      # Domain pattern: example.com matches itself and subdomains
      true ->
        domain == pattern or String.ends_with?(domain, "." <> pattern)
    end
  end

  @doc """
  Normalizes a domain by removing port and converting to lowercase.
  """
  @spec normalize_domain(String.t()) :: String.t()
  def normalize_domain(domain) do
    domain
    |> String.split(":")
    |> List.first()
    |> String.downcase()
  end
end
