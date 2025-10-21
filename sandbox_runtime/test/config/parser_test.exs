defmodule SandboxRuntime.Config.ParserTest do
  use ExUnit.Case

  alias SandboxRuntime.Config.Parser

  describe "parse_permission/2" do
    test "parses WebFetch domain permission" do
      result = Parser.parse_permission("WebFetch(domain:github.com)")

      assert result.network_allow == ["github.com"]
    end

    test "parses Read permission" do
      result = Parser.parse_permission("Read(~/.ssh)")

      assert result.fs_read.deny_only == ["~/.ssh"]
    end

    test "parses Edit permission" do
      result = Parser.parse_permission("Edit(./src)")

      assert result.fs_write.allow_only == ["./src"]
    end

    test "parses UnixSocket permission" do
      result = Parser.parse_permission("UnixSocket(path:/var/run/docker.sock)")

      assert result.unix_sockets == ["/var/run/docker.sock"]
    end

    test "handles invalid permission strings" do
      result = Parser.parse_permission("InvalidFormat")

      assert result == %{}
    end
  end

  describe "parse_permissions/1" do
    test "parses multiple permissions" do
      permissions = [
        "WebFetch(domain:github.com)",
        "Read(~/.ssh)",
        "Edit(./src)"
      ]

      result = Parser.parse_permissions(permissions)

      assert result.network_allow == ["github.com"]
      assert result.fs_read.deny_only == ["~/.ssh"]
      assert result.fs_write.allow_only == ["./src"]
    end

    test "handles empty list" do
      result = Parser.parse_permissions([])

      assert result == %{}
    end
  end

  describe "to_permission_strings/1" do
    test "converts config back to permission strings" do
      config = %{
        network_allow: ["github.com"],
        fs_read: %{deny_only: ["~/.ssh"]},
        fs_write: %{allow_only: ["./src"]}
      }

      strings = Parser.to_permission_strings(config)

      assert "WebFetch(domain:github.com)" in strings
      assert "Read(~/.ssh)" in strings
      assert "Edit(./src)" in strings
    end
  end
end
