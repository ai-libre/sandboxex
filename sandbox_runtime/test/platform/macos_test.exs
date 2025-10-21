defmodule SandboxRuntime.Platform.MacOSTest do
  use ExUnit.Case

  alias SandboxRuntime.Platform.MacOS

  @moduletag :macos

  describe "generate_profile/1" do
    test "generates a valid Seatbelt profile" do
      config = %{
        fs_read: %{deny_only: []},
        fs_write: %{allow_only: [], deny_within_allow: []},
        sandbox: %{network: %{http_proxy_port: 8888, socks_proxy_port: 1080}}
      }

      {:ok, profile} = MacOS.generate_profile(config)

      assert is_binary(profile)
      assert String.contains?(profile, "(version 1)")
      assert String.contains?(profile, "(allow default)")
    end

    test "includes write restrictions" do
      config = %{
        fs_read: %{deny_only: []},
        fs_write: %{allow_only: ["/tmp/allowed"], deny_within_allow: []},
        sandbox: %{network: %{http_proxy_port: 8888, socks_proxy_port: 1080}}
      }

      {:ok, profile} = MacOS.generate_profile(config)

      assert String.contains?(profile, "file-write")
      assert String.contains?(profile, "/tmp/allowed")
    end

    test "includes read restrictions" do
      config = %{
        fs_read: %{deny_only: ["~/.ssh"]},
        fs_write: %{allow_only: [], deny_within_allow: []},
        sandbox: %{network: %{http_proxy_port: 8888, socks_proxy_port: 1080}}
      }

      {:ok, profile} = MacOS.generate_profile(config)

      assert String.contains?(profile, "file-read")
    end

    test "includes network restrictions" do
      config = %{
        fs_read: %{deny_only: []},
        fs_write: %{allow_only: [], deny_within_allow: []},
        sandbox: %{network: %{http_proxy_port: 8888, socks_proxy_port: 1080}}
      }

      {:ok, profile} = MacOS.generate_profile(config)

      assert String.contains?(profile, "network")
      assert String.contains?(profile, "8888")
      assert String.contains?(profile, "1080")
    end
  end

  describe "wrap_command/2" do
    test "wraps command with sandbox-exec" do
      profile = "(version 1)\n(allow default)"
      command = "echo hello"

      wrapped = MacOS.wrap_command(command, profile)

      assert String.contains?(wrapped, "sandbox-exec")
      assert String.contains?(wrapped, "-f")
      assert String.contains?(wrapped, "echo hello")
    end

    test "escapes command properly" do
      profile = "(version 1)\n(allow default)"
      command = "echo 'hello world'"

      wrapped = MacOS.wrap_command(command, profile)

      assert String.contains?(wrapped, "sandbox-exec")
    end
  end
end
