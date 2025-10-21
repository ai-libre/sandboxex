defmodule SandboxRuntime.Config.LoaderTest do
  use ExUnit.Case

  alias SandboxRuntime.Config.Loader

  describe "default_config/0" do
    test "returns valid default configuration" do
      config = Loader.default_config()

      assert is_map(config)
      assert config.sandbox.enabled == true
      assert is_map(config.sandbox.network)
      assert is_list(config.permissions.allow)
      assert is_list(config.permissions.deny)
    end
  end

  describe "load_hierarchical/0" do
    test "loads configuration without errors" do
      assert {:ok, config} = Loader.load_hierarchical()
      assert is_map(config)
    end

    test "configuration includes required keys" do
      {:ok, config} = Loader.load_hierarchical()

      assert Map.has_key?(config, :sandbox)
      assert Map.has_key?(config, :permissions)
    end
  end
end
