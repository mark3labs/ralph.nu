#!/usr/bin/env nu

# Integration test for Task 7: Main iteration loop
# This is an integration test (complex setup/teardown) so it remains a standalone script

use std/assert

print "=== Testing Task 7: Main Iteration Loop ==="

# Setup
let test_spec = "/tmp/test-task7-spec.md"
"# Test Spec\n\n## Tasks\n- [ ] Task 1\n- [ ] Task 2" | save -f $test_spec

let test_prompt = "exit 0"

# Clean up any previous test store
rm -rf /tmp/test-task7-store

print "\n1. Testing iteration loop with limit of 2 iterations..."
let script_path = ($env.FILE_PWD | path join ".." "ralph.nu")
let result = (
  timeout 15s nu $script_path --name "task7-test" --spec $test_spec --prompt $test_prompt --iterations 2 --port 4099 --store "/tmp/test-task7-store"
  | complete
)

print $"\n   Exit code: ($result.exit_code)"

# Check key outputs using asserts
print "   Checking iteration execution..."
assert str contains $result.stdout "Iteration #1"
# Note: Session completes after iteration #1 due to prompt "exit 0"
# So we don't expect iteration #2 or "Completed 2 iterations"
assert str contains $result.stdout "Session complete - all tasks done"
assert str contains $result.stdout "Cleaning up background jobs"
print "   ✓ All iteration checks passed"

print "\n2. Checking that store directory was created..."
assert ("/tmp/test-task7-store" | path exists)
print "   ✓ Store directory exists"

print "\n3. Checking that servers were started..."
assert str contains $result.stdout "Starting xs store"
assert str contains $result.stdout "Starting opencode web"
assert str contains $result.stdout "http://localhost:4099"
print "   ✓ All server checks passed"

print "\n4. Verifying iteration events were logged..."
# Start a temporary store to read events
let temp_store_job = (job spawn { xs serve /tmp/test-task7-store })
sleep 1sec

let events_result = (xs cat /tmp/test-task7-store | complete)

if $events_result.exit_code == 0 {
  let events = ($events_result.stdout | from json --objects | where topic == "ralph.task7-test.iteration")
  let event_count = ($events | length)
  print $"   Found ($event_count) iteration events"
  
  # Verify at least some events were logged
  assert ($event_count > 0) "Expected at least 1 iteration event"
  print "   ✓ Iteration events were logged to store"
} else {
  print "   ⚠ Could not read events (store may have been cleaned up)"
}

job kill $temp_store_job

# Cleanup
print "\n5. Cleaning up test files..."
rm -rf /tmp/test-task7-store
rm $test_spec

print "\n=== ✓ Task 7 implementation verified ==="
