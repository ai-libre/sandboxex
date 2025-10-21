defmodule SandboxRuntimeTest do
  use ExUnit.Case
  doctest SandboxRuntime

  setup do
    # Clear violations before each test
    SandboxRuntime.clear_violations()
    :ok
  end

  describe "platform detection" do
    test "detects current platform" do
      assert SandboxRuntime.platform_info().platform in [:macos, :linux, :windows, :unknown]
    end

    test "returns platform information" do
      info = SandboxRuntime.platform_info()
      assert is_map(info)
      assert Map.has_key?(info, :platform)
      assert Map.has_key?(info, :supported)
      assert Map.has_key?(info, :dependencies)
    end
  end

  describe "configuration" do
    test "gets current configuration" do
      config = SandboxRuntime.get_config()
      assert is_map(config)
    end

    test "reloads configuration" do
      assert :ok == SandboxRuntime.reload_config() or
               match?({:error, _}, SandboxRuntime.reload_config())
    end
  end

  describe "violations" do
    test "starts with no violations" do
      assert SandboxRuntime.violation_count() == 0
      assert SandboxRuntime.get_violations() == []
    end

    test "can add and retrieve violations" do
      SandboxRuntime.ViolationStore.add_violation(%{
        type: :network,
        operation: "test",
        target: "example.com",
        process: "test",
        metadata: %{}
      })

      assert SandboxRuntime.violation_count() == 1
      violations = SandboxRuntime.get_violations()
      assert length(violations) == 1
      assert hd(violations).type == :network
    end

    test "can filter violations by type" do
      SandboxRuntime.ViolationStore.add_violation(%{
        type: :network,
        operation: "test",
        target: "example.com",
        process: "test",
        metadata: %{}
      })

      SandboxRuntime.ViolationStore.add_violation(%{
        type: :filesystem,
        operation: "test",
        target: "/path",
        process: "test",
        metadata: %{}
      })

      network_violations = SandboxRuntime.get_violations_by_type(:network)
      assert length(network_violations) == 1
      assert hd(network_violations).type == :network

      fs_violations = SandboxRuntime.get_violations_by_type(:filesystem)
      assert length(fs_violations) == 1
      assert hd(fs_violations).type == :filesystem
    end

    test "can clear violations" do
      SandboxRuntime.ViolationStore.add_violation(%{
        type: :network,
        operation: "test",
        target: "example.com",
        process: "test",
        metadata: %{}
      })

      assert SandboxRuntime.violation_count() > 0
      SandboxRuntime.clear_violations()
      assert SandboxRuntime.violation_count() == 0
    end
  end
end
