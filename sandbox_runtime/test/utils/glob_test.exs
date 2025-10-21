defmodule SandboxRuntime.Utils.GlobTest do
  use ExUnit.Case

  alias SandboxRuntime.Utils.Glob

  describe "to_regex/1" do
    test "converts simple wildcard" do
      regex = Glob.to_regex("*.txt")
      assert Regex.match?(regex, "file.txt")
      assert Regex.match?(regex, "readme.txt")
      refute Regex.match?(regex, "dir/file.txt")
    end

    test "converts double asterisk" do
      regex = Glob.to_regex("**/*.txt")
      assert Regex.match?(regex, "dir/file.txt")
      assert Regex.match?(regex, "a/b/c/file.txt")
      refute Regex.match?(regex, "file.md")
    end

    test "converts question mark" do
      regex = Glob.to_regex("file?.txt")
      assert Regex.match?(regex, "file1.txt")
      assert Regex.match?(regex, "fileA.txt")
      refute Regex.match?(regex, "file12.txt")
    end

    test "escapes special regex characters" do
      regex = Glob.to_regex("file.txt")
      assert Regex.match?(regex, "file.txt")
      refute Regex.match?(regex, "filetxt")
    end
  end

  describe "matches?/2" do
    test "matches exact pattern" do
      assert Glob.matches?("file.txt", "file.txt")
      refute Glob.matches?("file.md", "file.txt")
    end

    test "matches wildcard pattern" do
      assert Glob.matches?("readme.md", "*.md")
      assert Glob.matches?("test.md", "*.md")
      refute Glob.matches?("readme.txt", "*.md")
    end

    test "matches nested wildcard" do
      assert Glob.matches?("src/app/file.ex", "src/**/*.ex")
      assert Glob.matches?("src/file.ex", "src/**/*.ex")
      refute Glob.matches?("test/file.ex", "src/**/*.ex")
    end
  end

  describe "has_wildcards?/1" do
    test "detects wildcards" do
      assert Glob.has_wildcards?("*.txt")
      assert Glob.has_wildcards?("file?.txt")
      assert Glob.has_wildcards?("**/*.ex")
    end

    test "returns false for literal paths" do
      refute Glob.has_wildcards?("file.txt")
      refute Glob.has_wildcards?("/path/to/file")
    end
  end

  describe "to_regex_list/1" do
    test "converts multiple patterns" do
      patterns = ["*.ex", "*.exs", "*.md"]
      regexes = Glob.to_regex_list(patterns)

      assert length(regexes) == 3
      assert Enum.all?(regexes, &is_struct(&1, Regex))
    end

    test "handles empty list" do
      assert Glob.to_regex_list([]) == []
    end
  end
end
