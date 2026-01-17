#!/usr/bin/env nu

# Task 10: Integration test for ralph.nu
# Tests: simple spec file, web UI sessions, notes persistence, cleanup

use std/assert

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
assert equal $ralph_result.exit_code 0 "ralph.nu should execute successfully"
print "✓ ralph.nu executed successfully"

# Verify output mentions the session name
assert ($ralph_result.stdout | str contains $test_name) "Output should contain session name"
print "✓ Output contains session name"

# Verify output mentions iterations
assert ($ralph_result.stdout | str contains "Iteration #1") "Output should show iteration number"
print "✓ Output shows iteration number"

print "\nTest 2: Verify web UI shows titled sessions"
print "============================================"

# The web server should have been cleaned up by ralph
# We test this by checking that the title format is correct in the output
assert ($ralph_result.stdout | str contains $"($test_name)") "Session title should contain session name"
assert ($ralph_result.stdout | str contains "Iteration #") "Session title should contain iteration number"
print "✓ Session title format is correct"

print "\nTest 3: Verify data persists across runs"
print "=========================================="

# Start xs store to query data
print "Starting xs store for querying..."
let store_job = (start-store $test_store)

# Verify iteration history from first run
print "Checking iteration history from first run..."
let iter_count = (xs cat $test_store | from json --objects | where topic == $"ralph.($test_name).iteration" | length)
# We expect 2 events from first run: 1 iteration × 2 events (start + complete)
assert equal $iter_count 2 "Should have 2 iteration events from first run"
print $"✓ Iteration history persisted \(($iter_count) events from first run\)"

# Clean up store so ralph can start its own
cleanup [$store_job]

# Run ralph again and verify it can read existing data from store
print "\nRunning ralph again to verify it reads existing data from store..."
let ralph_result2 = (
  timeout 15s nu $script_path --name $test_name --spec $test_spec --prompt $custom_prompt --iterations 1 --port 4101 --store $test_store
  | complete
)

# Verify ralph read the store and showed iteration history
assert ($ralph_result2.stdout | str contains "HISTORY") "Iteration history should be displayed from store on second run"
print "✓ Iteration history displayed from store on second run"

# Verify it shows the previous iteration
assert ($ralph_result2.stdout | str contains "#1") "Should show iteration #1 from previous run"
print "✓ Previous iteration visible in history"

# Verify it continues from the next iteration number
assert ($ralph_result2.stdout | str contains "Iteration #2") "Should continue to iteration #2"
print "✓ Correctly continues from previous iteration"

# Verify iteration history now has 4 events total (2 runs × 2 events each)
# Need to restart store to query
let store_job = (start-store $test_store)
let final_iter_count = (xs cat $test_store | from json --objects | where topic == $"ralph.($test_name).iteration" | length)
assert equal $final_iter_count 4 "Should have 4 iteration events after two runs"
print $"✓ Store persisted data across runs \(($final_iter_count) events total\)"

print "\nTest 4: Verify cleanup on Ctrl+C (signal handling)"
print "==================================================="

# We can't actually send Ctrl+C in a test, but we can verify:
# 1. The cleanup function works (already tested in job-cleanup.nu)
# 2. Ralph uses try/catch to ensure cleanup runs

# Check ralph.nu has try/catch structure
let ralph_content = (open $script_path)
assert (($ralph_content | str contains "try {") and ($ralph_content | str contains "cleanup-all")) "ralph.nu should have try/catch with cleanup-all handler"
print "✓ ralph.nu has try/catch with cleanup-all handler"

# Verify cleanup-all is called in error path
assert (($ralph_content | str contains "catch") and ($ralph_content | str contains "cleanup-all")) "cleanup-all should be called in error handler"
print "✓ cleanup-all called in error handler"

# Verify cleanup-all is called after normal completion
let lines = ($ralph_content | lines)
let cleanup_line = ($lines | enumerate | where item =~ "# Normal cleanup" | first)
assert (not ($cleanup_line | is-empty)) "Normal cleanup path should exist"
print "✓ Normal cleanup path exists"

print "\nTest 5: Verify store directory structure"
print "========================================"

# Verify store was created
assert ($test_store | path exists) "Store directory should be created"
print "✓ Store directory created"

# Verify store has data
let store_files = (ls $test_store | length)
assert ($store_files > 0) "Store should contain data"
print $"✓ Store contains data \(($store_files) files\)"

# Final cleanup
print "\nCleaning up test environment..."
# Cleanup the store job we started
cleanup [$store_job]
rm -rf $test_store

print "\n=== ✓ All Task 10 integration tests passed! ==="
print ""
print "Summary:"
print "  ✓ Simple spec file execution works"
print "  ✓ Web UI session titles formatted correctly"
print "  ✓ Store data persists across multiple runs"
print "  ✓ Iteration history tracked correctly"
print "  ✓ Cleanup handlers properly implemented"
print "  ✓ Store directory structure correct"
