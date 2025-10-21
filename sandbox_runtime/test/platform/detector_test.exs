defmodule SandboxRuntime.Platform.DetectorTest do
  use ExUnit.Case

  alias SandboxRuntime.Platform.Detector

  describe "detect/0" do
    test "detects a valid platform" do
      platform = Detector.detect()
      assert platform in [:macos, :linux, :windows, :unknown]
    end

    test "is consistent" do
      platform1 = Detector.detect()
      platform2 = Detector.detect()
      assert platform1 == platform2
    end
  end

  describe "supported?/0" do
    test "returns boolean" do
      assert is_boolean(Detector.supported?())
    end

    test "supported platforms are macOS or Linux" do
      if Detector.supported?() do
        assert Detector.detect() in [:macos, :linux]
      end
    end
  end

  describe "platform_info/0" do
    test "returns map with required keys" do
      info = Detector.platform_info()

      assert is_map(info)
      assert Map.has_key?(info, :platform)
      assert Map.has_key?(info, :supported)
      assert Map.has_key?(info, :os_type)
      assert Map.has_key?(info, :dependencies)
    end

    test "dependencies is a map" do
      info = Detector.platform_info()
      assert is_map(info.dependencies)
    end
  end
end
