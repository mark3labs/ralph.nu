#!/usr/bin/env nu

# Tests for empty store handling
# Covers tasks:
# - Test get-task-state returns empty record for new store
# - Test get-task-state returns empty lists for each status category
# - Test format-task-state with empty state produces "No tasks"
# - Test show-notes with empty store produces expected output

# Source helper functions
source helpers.nu

# Source ralph.nu to get access to the functions
source ../../ralph.nu

def run-tests [] {
  print "=== Running: empty-store.nu ==="
  
  # Setup test environment
  let ctx = (setup-test-store)
  
  try {
    # Test 1: get-task-state returns a record structure
    let state = (get-task-state $ctx.store "test")
    assert-true (($state | describe) =~ "record") "get-task-state returns a record"
    
    # Test 2: get-task-state returns empty lists for each status category
    assert-eq ($state.completed | length) 0 "completed list is empty"
    assert-eq ($state.in_progress | length) 0 "in_progress list is empty"
    assert-eq ($state.blocked | length) 0 "blocked list is empty"
    assert-eq ($state.remaining | length) 0 "remaining list is empty"
    
    # Test 3: format-task-state with empty state produces "No tasks" message
    let formatted = (format-task-state $state)
    assert-eq $formatted "No tasks yet - check spec for initial tasks" "empty state formats correctly"
    
    # Test 4: show-notes with empty store produces no output (returns early)
    # This is hard to test since show-notes returns nothing, but we can verify it doesn't error
    show-notes $ctx.store "test"
    print "✓ show-notes handles empty store without error"
    
    print "\nAll empty store tests passed!"
    
  } catch { |err|
    print $"✗ Test failed: ($err.msg)"
    teardown-test-store $ctx
    exit 1
  }
  
  # Cleanup
  teardown-test-store $ctx
  
  # Exit cleanly to avoid ralph.nu main error
  exit 0
}

# Run tests when script is executed directly
run-tests
