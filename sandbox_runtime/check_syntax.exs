#!/usr/bin/env elixir

# Simple syntax checker for our Elixir files
# Compiles each file and reports any syntax errors

files = Path.wildcard("lib/**/*.ex")

IO.puts("🔍 Checking syntax for #{length(files)} Elixir files...\n")

results = Enum.map(files, fn file ->
  IO.write("  #{file} ... ")

  try do
    Code.compile_file(file)
    IO.puts("✓")
    {:ok, file}
  rescue
    e in SyntaxError ->
      IO.puts("✗ SYNTAX ERROR")
      IO.puts("    #{Exception.message(e)}")
      {:error, file, e}
    e in CompileError ->
      # Expected - modules reference each other
      IO.puts("○ (compile warnings - expected)")
      {:warning, file}
    e ->
      IO.puts("✗ ERROR")
      IO.puts("    #{inspect(e)}")
      {:error, file, e}
  end
end)

# Summary
errors = Enum.filter(results, fn {status, _} -> status == :error end)
warnings = Enum.filter(results, fn
  {:warning, _} -> true
  _ -> false
end)
ok = Enum.filter(results, fn {status, _} -> status == :ok end)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("📊 Summary:")
IO.puts("  ✓ Clean: #{length(ok)} files")
IO.puts("  ○ Warnings (expected): #{length(warnings)} files")
IO.puts("  ✗ Errors: #{length(errors)} files")

if length(errors) == 0 do
  IO.puts("\n✅ All files have valid Elixir syntax!")
  System.halt(0)
else
  IO.puts("\n❌ Found syntax errors in #{length(errors)} file(s)")
  System.halt(1)
end
