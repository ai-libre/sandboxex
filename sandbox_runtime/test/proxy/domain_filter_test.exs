defmodule SandboxRuntime.Proxy.DomainFilterTest do
  use ExUnit.Case

  alias SandboxRuntime.Proxy.DomainFilter

  describe "matches?/2" do
    test "exact domain match" do
      assert DomainFilter.matches?("github.com", "github.com")
      refute DomainFilter.matches?("github.com", "gitlab.com")
    end

    test "subdomain matching" do
      assert DomainFilter.matches?("api.github.com", "github.com")
      assert DomainFilter.matches?("www.api.github.com", "github.com")
    end

    test "wildcard subdomain pattern" do
      assert DomainFilter.matches?("api.example.com", "*.example.com")
      refute DomainFilter.matches?("example.com", "*.example.com")
    end

    test "does not match unrelated domains" do
      refute DomainFilter.matches?("github.com", "example.com")
      refute DomainFilter.matches?("notgithub.com", "github.com")
    end
  end

  describe "matches_any?/2" do
    test "matches when domain is in list" do
      patterns = ["github.com", "gitlab.com"]
      assert DomainFilter.matches_any?("github.com", patterns)
      assert DomainFilter.matches_any?("api.github.com", patterns)
    end

    test "does not match when domain is not in list" do
      patterns = ["github.com", "gitlab.com"]
      refute DomainFilter.matches_any?("example.com", patterns)
    end

    test "handles empty pattern list" do
      refute DomainFilter.matches_any?("github.com", [])
    end
  end

  describe "check/2" do
    test "allows domain when in allow list" do
      config = %{network_allow: ["github.com"]}
      assert DomainFilter.check("github.com", config) == :allow
      assert DomainFilter.check("api.github.com", config) == :allow
    end

    test "denies domain when in deny list" do
      config = %{network_deny: ["blocked.com"]}
      assert DomainFilter.check("blocked.com", config) == :deny
    end

    test "denies domain not in allow list when allowlist mode" do
      config = %{network_allow: ["github.com"]}
      assert DomainFilter.check("example.com", config) == :deny
    end

    test "allows all when allow list is empty" do
      config = %{network_allow: []}
      assert DomainFilter.check("anything.com", config) == :allow
    end

    test "deny list takes precedence" do
      config = %{
        network_allow: ["github.com"],
        network_deny: ["github.com"]
      }

      assert DomainFilter.check("github.com", config) == :deny
    end
  end

  describe "normalize_domain/1" do
    test "removes port" do
      assert DomainFilter.normalize_domain("example.com:8080") == "example.com"
    end

    test "converts to lowercase" do
      assert DomainFilter.normalize_domain("Example.COM") == "example.com"
    end

    test "handles domain without port" do
      assert DomainFilter.normalize_domain("example.com") == "example.com"
    end
  end
end
