defmodule SandboxRuntime.Platform.Detector do
  @moduledoc """
  Detects the current platform and checks for sandboxing support.
  """

  @doc """
  Detects the current operating system platform.

  Returns:
  - `:macos` for macOS
  - `:linux` for Linux
  - `:windows` for Windows
  - `:unknown` for unknown platforms
  """
  @spec detect() :: :macos | :linux | :windows | :unknown
  def detect do
    case :os.type() do
      {:unix, :darwin} -> :macos
      {:unix, :linux} -> :linux
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  @doc """
  Checks if the current platform supports sandboxing.
  """
  @spec supported?() :: boolean()
  def supported? do
    detect() in [:macos, :linux]
  end

  @doc """
  Returns platform-specific information.
  """
  @spec platform_info() :: map()
  def platform_info do
    platform = detect()

    %{
      platform: platform,
      supported: supported?(),
      os_type: :os.type(),
      dependencies: check_dependencies(platform)
    }
  end

  # Private Helpers

  defp check_dependencies(:macos) do
    %{
      sandbox_exec: executable_exists?("sandbox-exec"),
      ripgrep: executable_exists?("rg")
    }
  end

  defp check_dependencies(:linux) do
    %{
      bubblewrap: executable_exists?("bwrap"),
      socat: executable_exists?("socat"),
      ripgrep: executable_exists?("rg")
    }
  end

  defp check_dependencies(_), do: %{}

  defp executable_exists?(name) do
    case System.find_executable(name) do
      nil -> false
      _ -> true
    end
  end
end
