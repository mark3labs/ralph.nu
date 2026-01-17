#!/usr/bin/env nu

# Test the build-prompt function

source ralph.nu

print "Testing build-prompt function..."

let spec_content = "# Test Spec\n\nThis is a test spec file."
let store_path = "./.ralph/test-store"
let name = "test-session"
let pid = 12345
let iteration = 3

print "\nBuilding prompt with:"
print $"  spec: ($spec_content | str replace '\n' ' ')"
print $"  store: ($store_path)"
print $"  name: ($name)"
print $"  pid: ($pid)"
print $"  iteration: ($iteration)"

let prompt = (build-prompt $spec_content $store_path $name $pid $iteration)

print "\n=== Generated Prompt ==="
print $prompt
print "=== End Prompt ==="

# Verify key elements are present
let checks = [
  {name: "spec content", pattern: "# Test Spec"},
  {name: "store path", pattern: $store_path},
  {name: "session name", pattern: $name},
  {name: "pid", pattern: ($pid | into string)},
  {name: "iteration", pattern: ($iteration | into string)},
  {name: "xs cat command", pattern: "xs cat"},
  {name: "xs append command", pattern: "xs append"},
  {name: "completed note type", pattern: "completed"},
  {name: "in_progress note type", pattern: "in_progress"},
  {name: "blocked note type", pattern: "blocked"},
  {name: "remaining note type", pattern: "remaining"},
  {name: "pkill termination", pattern: "pkill -P"},
]

print "\n=== Verification Checks ==="
for check in $checks {
  let found = ($prompt | str contains $check.pattern)
  if $found {
    print $"✓ ($check.name): found"
  } else {
    print $"✗ ($check.name): NOT FOUND"
  }
}

print "\nTest complete!"
