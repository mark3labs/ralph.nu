#!/usr/bin/env nu

# Test the build-prompt function

source ../ralph.nu

print "Testing build-prompt function..."

let spec_content = "# Test Spec\n\nThis is a test spec file."
let store_path = "./.ralph/test-store"
let name = "test-session"
let iteration = 3
let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}

print "\nBuilding prompt with:"
print $"  spec: ($spec_content | str replace '\n' ' ')"
print $"  store: ($store_path)"
print $"  name: ($name)"
print $"  iteration: ($iteration)"

let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)

print "\n=== Generated Prompt ==="
print $prompt
print "=== End Prompt ==="

# Verify key elements are present
let checks = [
  {name: "spec content", pattern: "# Test Spec"},
  {name: "session name", pattern: $name},
  {name: "iteration", pattern: ($iteration | into string)},
  {name: "task_add tool", pattern: "task_add"},
  {name: "task_status tool", pattern: "task_status"},
  {name: "task_list tool", pattern: "task_list"},
  {name: "session_complete tool", pattern: "session_complete"},
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
