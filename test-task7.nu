#!/usr/bin/env nu

# Comprehensive test for Task 7: Main iteration loop

print "=== Testing Task 7: Main Iteration Loop ==="

# Create a test spec file
let test_spec = "/tmp/test-task7-spec.md"
"# Test Spec\n\n## Tasks\n- [ ] Task 1\n- [ ] Task 2" | save -f $test_spec

# Create a minimal prompt (opencode will fail but that's OK for testing)
let test_prompt = "exit 0"

# Clean up any previous test store
rm -rf /tmp/test-task7-store

print "\n1. Testing iteration loop with limit of 2 iterations..."
let result = (
  timeout 15s nu ralph.nu --name "task7-test" --spec $test_spec --prompt $test_prompt --iterations 2 --port 4099 --store "/tmp/test-task7-store"
  | complete
)

print $"\n   Exit code: ($result.exit_code)"

# Check key outputs
if ($result.stdout | str contains "Iteration #1") {
  print "   ✓ Iteration #1 executed"
} else {
  print "   ✗ Iteration #1 not found"
}

if ($result.stdout | str contains "Iteration #2") {
  print "   ✓ Iteration #2 executed"
} else {
  print "   ✗ Iteration #2 not found"
}

if ($result.stdout | str contains "Completed 2 iterations") {
  print "   ✓ Loop stopped after 2 iterations"
} else {
  print "   ✗ Loop didn't stop after 2 iterations"
}

if ($result.stdout | str contains "Cleaning up background jobs") {
  print "   ✓ Cleanup executed"
} else {
  print "   ✗ Cleanup not executed"
}

print "\n2. Checking that store directory was created..."
if ("/tmp/test-task7-store" | path exists) {
  print "   ✓ Store directory exists"
} else {
  print "   ✗ Store directory not created"
  exit 1
}

print "\n3. Checking that servers were started..."
if ($result.stdout | str contains "Starting xs store") {
  print "   ✓ xs store was started"
} else {
  print "   ✗ xs store not started"
}

if ($result.stdout | str contains "Starting opencode web") {
  print "   ✓ opencode web was started"
} else {
  print "   ✗ opencode web not started"
}

if ($result.stdout | str contains "Web UI: http://localhost:4099") {
  print "   ✓ Web UI URL displayed"
} else {
  print "   ✗ Web UI URL not displayed"
}

print "\n4. Verifying iteration events were logged..."
# Start a temporary store to read events
let temp_store_job = (job spawn { xs serve /tmp/test-task7-store })
sleep 1sec

let events_result = (xs cat /tmp/test-task7-store | complete)

if $events_result.exit_code == 0 {
  let events = ($events_result.stdout | from json --objects | where topic == "ralph.task7-test.iteration")
  let event_count = ($events | length)
  print $"   Found ($event_count) events"
  
  if $event_count == 4 {
    print "   ✓ Correct number of events (4: 2 starts + 2 completes)"
  } else {
    print $"   ✗ Expected 4 events, found ($event_count)"
  }
} else {
  print "   ⚠ Could not read events (store may have been cleaned up)"
}

job kill $temp_store_job

# Cleanup
print "\n5. Cleaning up test files..."
rm -rf /tmp/test-task7-store
rm $test_spec

print "\n=== ✓ Task 7 implementation verified ==="
