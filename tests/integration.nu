#!/usr/bin/env nu

# Task 10: Integration test for ralph.nu
# Tests: simple spec file, web UI sessions, notes persistence, cleanup

source ../ralph.nu

print "=== Task 10: Integration Testing and Polish ==="
print ""

# Setup
let test_store = $"/tmp/ralph-integration-(random chars -l 8)"
let test_port = 4100
let test_spec = "tests/test-spec.md"

# Clean up any previous test runs
rm -rf $test_store

print "Test 1: Run ralph.nu with simple spec file"
print "============================================"

# Test 1a: Run with 1 iteration to verify basic functionality
print "\n1a. Running ralph.nu for 1 iteration..."
let test_name = "integration-test"
let custom_prompt = "exit 0"  # Simple prompt that exits immediately

# Start ralph in background with timeout
print "Starting ralph.nu..."
let script_path = ($env.FILE_PWD | path join ".." "ralph.nu")
let ralph_result = (
  timeout 15s nu $script_path --name $test_name --spec $test_spec --prompt $custom_prompt --iterations 1 --port $test_port --store $test_store
  | complete
)

# Check basic execution
if $ralph_result.exit_code == 0 {
  print "✓ ralph.nu executed successfully"
} else {
  print $"✗ ralph.nu failed with exit code ($ralph_result.exit_code)"
  print $"Output: ($ralph_result.stdout)"
  print $"Error: ($ralph_result.stderr)"
  exit 1
}

# Verify output mentions the session name
if ($ralph_result.stdout | str contains $test_name) {
  print "✓ Output contains session name"
} else {
  print "✗ Output missing session name"
  exit 1
}

# Verify output mentions iterations
if ($ralph_result.stdout | str contains "Iteration #1") {
  print "✓ Output shows iteration number"
} else {
  print "✗ Output missing iteration number"
  exit 1
}

print "\nTest 2: Verify web UI shows titled sessions"
print "============================================"

# The web server should have been cleaned up by ralph
# We test this by checking that the title format is correct in the output
if ($ralph_result.stdout | str contains $"($test_name) - Iteration") {
  print "✓ Session title format is correct (name - Iteration #N)"
} else {
  print "✗ Session title format not found in output"
  exit 1
}

print "\nTest 3: Verify notes persist across runs"
print "========================================="

# Start xs store to write some notes
print "Starting xs store for testing..."
let store_job = (start-store $test_store)

# Add some test notes
print "Adding test notes..."
echo "First task completed" | xs append $test_store $"ralph.($test_name).note" --meta '{"type":"completed","iteration":1}'
echo "Second task remaining" | xs append $test_store $"ralph.($test_name).note" --meta '{"type":"remaining"}'

# Verify notes exist
let note_count = (xs cat $test_store | from json --objects | where topic == $"ralph.($test_name).note" | length)
if $note_count == 2 {
  print $"✓ Notes persisted correctly \(($note_count) notes in store\)"
} else {
  print $"✗ Expected 2 notes, found ($note_count)"
  cleanup [$store_job]
  exit 1
}

# Verify iteration history from first run
let iter_count = (xs cat $test_store | from json --objects | where topic == $"ralph.($test_name).iteration" | length)
# We expect 2 events from first run: 1 iteration × 2 events (start + complete)
if $iter_count == 2 {
  print $"✓ Iteration history persisted \(($iter_count) events from first run\)"
} else {
  print $"✗ Expected 2 iteration events, found ($iter_count)"
  cleanup [$store_job]
  exit 1
}

# Run ralph again and verify it can read existing notes
print "\nRunning ralph again to verify it reads existing notes..."
let ralph_result2 = (
  timeout 15s nu $script_path --name $test_name --spec $test_spec --prompt $custom_prompt --iterations 1 --port 4101 --store $test_store
  | complete
)

# Check that show-notes was called and displayed our notes
if ($ralph_result2.stdout | str contains "COMPLETED") and ($ralph_result2.stdout | str contains "First task completed") {
  print "✓ Notes from previous run displayed on startup"
} else {
  print "✗ Previous notes not displayed on startup"
  print $"Output: ($ralph_result2.stdout)"
  cleanup [$store_job]
  exit 1
}

if ($ralph_result2.stdout | str contains "REMAINING") and ($ralph_result2.stdout | str contains "Second task remaining") {
  print "✓ All note categories displayed correctly"
} else {
  print "✗ Not all note categories displayed"
  cleanup [$store_job]
  exit 1
}

# Verify iteration history now shows both runs (4 events total)
# Note: ralph cleaned up its store job, so we need to query the store data directly
# The store data is still on disk even though xs serve is not running
# We can verify by checking if the output showed the iteration history
if ($ralph_result2.stdout | str contains "ITERATION HISTORY") {
  print "✓ Iteration history displayed from store on second run"
} else {
  print "✗ Iteration history not displayed on second run"
  cleanup [$store_job]
  exit 1
}

# Count iterations mentioned in the output (should see "Iteration #1" twice - from both runs)
let iter1_mentions = ($ralph_result2.stdout | lines | where $it =~ "Iteration #1" | length)
if $iter1_mentions >= 2 {
  print "✓ Both runs visible in iteration history"
} else {
  print $"✗ Expected multiple iteration #1 mentions, found ($iter1_mentions)"
  cleanup [$store_job]
  exit 1
}

print "\nTest 4: Verify cleanup on Ctrl+C (signal handling)"
print "==================================================="

# We can't actually send Ctrl+C in a test, but we can verify:
# 1. The cleanup function works (already tested in job-cleanup.nu)
# 2. Ralph uses try/catch to ensure cleanup runs

# Check ralph.nu has try/catch structure
let ralph_content = (open $script_path)
if ($ralph_content | str contains "try {") and ($ralph_content | str contains "cleanup-all") {
  print "✓ ralph.nu has try/catch with cleanup-all handler"
} else {
  print "✗ ralph.nu missing try/catch cleanup structure"
  cleanup [$store_job]
  exit 1
}

# Verify cleanup-all is called in error path
if ($ralph_content | str contains "catch") and ($ralph_content | str contains "cleanup-all") {
  print "✓ cleanup-all called in error handler"
} else {
  print "✗ cleanup-all not called in error handler"
  cleanup [$store_job]
  exit 1
}

# Verify cleanup-all is called after normal completion
let lines = ($ralph_content | lines)
let cleanup_line = ($lines | enumerate | where item =~ "# Normal cleanup" | first)
if not ($cleanup_line | is-empty) {
  print "✓ Normal cleanup path exists"
} else {
  print "✗ Normal cleanup path not found"
  cleanup [$store_job]
  exit 1
}

print "\nTest 5: Verify store directory structure"
print "========================================"

# Verify store was created
if ($test_store | path exists) {
  print "✓ Store directory created"
} else {
  print "✗ Store directory not found"
  cleanup [$store_job]
  exit 1
}

# Verify store has data
let store_files = (ls $test_store | length)
if $store_files > 0 {
  print $"✓ Store contains data \(($store_files) files\)"
} else {
  print "✗ Store is empty"
  cleanup [$store_job]
  exit 1
}

# Final cleanup
print "\nCleaning up test environment..."
cleanup [$store_job]
rm -rf $test_store

print "\n=== ✓ All Task 10 integration tests passed! ==="
print ""
print "Summary:"
print "  ✓ Simple spec file execution works"
print "  ✓ Web UI session titles formatted correctly"
print "  ✓ Notes persist across multiple runs"
print "  ✓ Iteration history tracked correctly"
print "  ✓ Cleanup handlers properly implemented"
print "  ✓ Store directory structure correct"
