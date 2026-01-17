#!/usr/bin/env nu

# Test Task 9: Status display helpers (show-notes and show-iterations)

source ../ralph.nu

print "Testing Task 9: Status display helpers..."

# Setup: Create a temporary store
let test_store = $"/tmp/ralph-test-status-(random chars -l 8)"
mkdir $test_store

try {
  # Start xs store for testing
  print "\n1. Starting xs store..."
  let store_job_id = (start-store $test_store)
  
  print "✓ Store started"
  
  # Test 1: show-notes with empty store
  print "\n2. Testing show-notes with empty store..."
  # Just call the function - it will print output directly
  show-notes $test_store "test-session"
  print "✓ show-notes handles empty store correctly"
  
  # Test 2: show-iterations with empty store
  print "\n3. Testing show-iterations with empty store..."
  # Just call the function - it will print output directly
  show-iterations $test_store "test-session"
  print "✓ show-iterations handles empty store correctly"
  
  # Test 3: Add various note types and verify show-notes displays them
  print "\n4. Adding test notes to store..."
  echo "Completed task 1" | xs append $test_store ralph.test-session.note --meta '{"type":"completed","iteration":1}'
  echo "Completed task 2" | xs append $test_store ralph.test-session.note --meta '{"type":"completed","iteration":2}'
  echo "Working on task 3" | xs append $test_store ralph.test-session.note --meta '{"type":"in_progress","iteration":3}'
  echo "Blocked by dependency" | xs append $test_store ralph.test-session.note --meta '{"type":"blocked","iteration":3}'
  echo "Task 4 pending" | xs append $test_store ralph.test-session.note --meta '{"type":"remaining"}'
  echo "Task 5 pending" | xs append $test_store ralph.test-session.note --meta '{"type":"remaining"}'
  
  print "✓ Added 6 test notes"
  
  print "\n5. Testing show-notes with populated store..."
  show-notes $test_store "test-session"
  print "✓ show-notes displays notes (visual verification above)"
  
  # Test 4: Add iteration events and verify show-iterations displays them
  print "\n6. Adding test iteration events..."
  log-iteration-start $test_store "test-session" 1
  sleep 100ms
  log-iteration-complete $test_store "test-session" 1 "success"
  sleep 100ms
  log-iteration-start $test_store "test-session" 2
  sleep 100ms
  log-iteration-complete $test_store "test-session" 2 "failure"
  
  print "✓ Added 4 iteration events"
  
  print "\n7. Testing show-iterations with populated store..."
  show-iterations $test_store "test-session"
  print "✓ show-iterations displays iteration history (visual verification above)"
  
  print "\n8. Verifying data in store..."
  # Verify we can query the store directly to confirm data was stored
  let note_count = (xs cat $test_store | from json --objects | where topic == "ralph.test-session.note" | length)
  if $note_count == 6 {
    print $"✓ Correct number of notes in store: ($note_count)"
  } else {
    print $"✗ Expected 6 notes, found ($note_count)"
    exit 1
  }
  
  let iter_count = (xs cat $test_store | from json --objects | where topic == "ralph.test-session.iteration" | length)
  if $iter_count == 4 {
    print $"✓ Correct number of iteration events in store: ($iter_count)"
  } else {
    print $"✗ Expected 4 iteration events, found ($iter_count)"
    exit 1
  }
  
  # Cleanup
  print "\n9. Cleaning up..."
  let jobs = (job list | get id)
  cleanup $jobs
  rm -rf $test_store
  
  print "\n✓ All Task 9 tests passed!"
  
} catch { |err|
  print $"\n✗ Test failed: ($err.msg)"
  
  # Cleanup on error
  try {
    let jobs = (job list | get id)
    cleanup $jobs
  }
  try {
    rm -rf $test_store
  }
  
  exit 1
}
