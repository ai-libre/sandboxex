defmodule SandboxRuntime.Utils.PathTest do
  use ExUnit.Case

  alias SandboxRuntime.Utils.Path, as: PathUtils

  describe "expand_home/1" do
    test "expands tilde to home directory" do
      expanded = PathUtils.expand_home("~/Documents")
      assert String.starts_with?(expanded, System.user_home())
      assert String.ends_with?(expanded, "/Documents")
    end

    test "does not modify paths without tilde" do
      assert PathUtils.expand_home("/usr/local") == "/usr/local"
      assert PathUtils.expand_home("./relative") == "./relative"
    end
  end

  describe "normalize/1" do
    test "expands home directory and makes absolute" do
      normalized = PathUtils.normalize("~/test")
      assert String.starts_with?(normalized, "/")
      assert String.contains?(normalized, System.user_home())
    end

    test "makes relative paths absolute" do
      normalized = PathUtils.normalize("./test")
      assert String.starts_with?(normalized, "/")
    end

    test "keeps absolute paths unchanged (except normalization)" do
      normalized = PathUtils.normalize("/usr/local")
      assert normalized == "/usr/local"
    end
  end

  describe "absolute?/1" do
    test "returns true for absolute paths" do
      assert PathUtils.absolute?("/usr/local")
      assert PathUtils.absolute?("/home/user")
    end

    test "returns false for relative paths" do
      refute PathUtils.absolute?("./relative")
      refute PathUtils.absolute?("relative")
      refute PathUtils.absolute?("~/home")
    end
  end

  describe "normalize_list/1" do
    test "normalizes all paths in list" do
      paths = ["~/test", "./relative", "/absolute"]
      normalized = PathUtils.normalize_list(paths)

      assert length(normalized) == 3
      assert Enum.all?(normalized, &String.starts_with?(&1, "/"))
    end

    test "handles empty list" do
      assert PathUtils.normalize_list([]) == []
    end
  end

  describe "subpath_of?/2" do
    test "returns true when path is subpath of parent" do
      assert PathUtils.subpath_of?("/home/user/docs", "/home/user")
      assert PathUtils.subpath_of?("/home/user/docs/file.txt", "/home/user")
    end

    test "returns false when path is not subpath of parent" do
      refute PathUtils.subpath_of?("/home/other", "/home/user")
      refute PathUtils.subpath_of?("/usr/local", "/home/user")
    end

    test "returns true when paths are the same" do
      assert PathUtils.subpath_of?("/home/user", "/home/user")
    end
  end
end
