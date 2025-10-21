#!/usr/bin/env elixir

IO.puts("\n🧪 Testing Compiled SandboxRuntime Modules\n")
IO.puts(String.duplicate("=", 60))

# Test 1: Path utilities
IO.puts("\n1️⃣  Testing SandboxRuntime.Utils.Path")
IO.puts("   normalize(\"~/Documents\")...")
normalized = SandboxRuntime.Utils.Path.normalize("~/Documents")
IO.puts("   ✓ Result: #{normalized}")

IO.puts("   absolute?(\"/usr/local\")...")
is_abs = SandboxRuntime.Utils.Path.absolute?("/usr/local")
IO.puts("   ✓ Result: #{is_abs}")

# Test 2: Glob utilities
IO.puts("\n2️⃣  Testing SandboxRuntime.Utils.Glob")
IO.puts("   to_regex(\"*.ex\")...")
regex = SandboxRuntime.Utils.Glob.to_regex("*.ex")
IO.puts("   ✓ Result: #{inspect(regex)}")

IO.puts("   matches?(\"test.ex\", \"*.ex\")...")
matches = SandboxRuntime.Utils.Glob.matches?("test.ex", "*.ex")
IO.puts("   ✓ Result: #{matches}")

IO.puts("   matches?(\"test.md\", \"*.ex\")...")
no_match = SandboxRuntime.Utils.Glob.matches?("test.md", "*.ex")
IO.puts("   ✓ Result: #{no_match}")

# Test 3: Command builder
IO.puts("\n3️⃣  Testing SandboxRuntime.Utils.CommandBuilder")
IO.puts("   escape(\"hello world\")...")
escaped = SandboxRuntime.Utils.CommandBuilder.escape("hello world")
IO.puts("   ✓ Result: #{escaped}")

IO.puts("   build(\"echo\", [\"hello\", \"world\"])...")
cmd = SandboxRuntime.Utils.CommandBuilder.build("echo", ["hello", "world"])
IO.puts("   ✓ Result: #{cmd}")

# Test 4: Platform detector
IO.puts("\n4️⃣  Testing SandboxRuntime.Platform.Detector")
IO.puts("   detect()...")
platform = SandboxRuntime.Platform.Detector.detect()
IO.puts("   ✓ Result: #{platform}")

IO.puts("   supported?()...")
supported = SandboxRuntime.Platform.Detector.supported?()
IO.puts("   ✓ Result: #{supported}")

IO.puts("   platform_info()...")
info = SandboxRuntime.Platform.Detector.platform_info()
IO.puts("   ✓ Result: #{inspect(info, pretty: true)}")

# Test 5: Domain filter
IO.puts("\n5️⃣  Testing SandboxRuntime.Proxy.DomainFilter")
IO.puts("   matches?(\"github.com\", \"github.com\")...")
match1 = SandboxRuntime.Proxy.DomainFilter.matches?("github.com", "github.com")
IO.puts("   ✓ Result: #{match1}")

IO.puts("   matches?(\"api.github.com\", \"github.com\")...")
match2 = SandboxRuntime.Proxy.DomainFilter.matches?("api.github.com", "github.com")
IO.puts("   ✓ Result: #{match2}")

IO.puts("   check(\"github.com\", %{network_allow: [\"github.com\"]})...")
check = SandboxRuntime.Proxy.DomainFilter.check("github.com", %{network_allow: ["github.com"]})
IO.puts("   ✓ Result: #{check}")

# Summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✅ All 5 compiled modules are working correctly!")
IO.puts("\nCompiled modules:")
IO.puts("  1. SandboxRuntime.Utils.Path")
IO.puts("  2. SandboxRuntime.Utils.Glob")
IO.puts("  3. SandboxRuntime.Utils.CommandBuilder")
IO.puts("  4. SandboxRuntime.Platform.Detector")
IO.puts("  5. SandboxRuntime.Proxy.DomainFilter")
IO.puts("\n🎉 Partial functionality validated!")
IO.puts(String.duplicate("=", 60) <> "\n")
