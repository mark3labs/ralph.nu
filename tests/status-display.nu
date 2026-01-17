#!/usr/bin/env nu

# Test Task 9: Status display helpers (show-tasks and show-iterations)

use std/assert
source ../ralph.nu

def "test show-tasks empty store" [store: string] {
  print "\n2. Testing show-tasks with empty store..."
  show-tasks $store "test-session"
  print "✓ show-tasks handles empty store correctly"
}

def "test show-iterations empty store" [store: string] {
  print "\n3. Testing show-iterations with empty store..."
  show-iterations $store "test-session"
  print "✓ show-iterations handles empty store correctly"
}

def "test show-tasks with data" [store: string] {
  print "\n4. Adding test tasks to store..."
  echo "Completed task 1" | xs append $store ralph.test-session.task --meta '{"action":"add","status":"completed","iteration":1}'
  echo "Completed task 2" | xs append $store ralph.test-session.task --meta '{"action":"add","status":"completed","iteration":2}'
  echo "Working on task 3" | xs append $store ralph.test-session.task --meta '{"action":"add","status":"in_progress","iteration":3}'
  echo "Blocked by dependency" | xs append $store ralph.test-session.task --meta '{"action":"add","status":"blocked","iteration":3}'
  echo "Task 4 pending" | xs append $store ralph.test-session.task --meta '{"action":"add","status":"remaining"}'
  echo "Task 5 pending" | xs append $store ralph.test-session.task --meta '{"action":"add","status":"remaining"}'
  
  print "✓ Added 6 test tasks"
  
  print "\n5. Testing show-tasks with populated store..."
  show-tasks $store "test-session"
  print "✓ show-tasks displays tasks (visual verification above)"
}

def "test show-iterations with data" [store: string] {
  print "\n6. Adding test iteration events..."
  log-iteration-start $store "test-session" 1
  sleep 100ms
  log-iteration-complete $store "test-session" 1 "success"
  sleep 100ms
  log-iteration-start $store "test-session" 2
  sleep 100ms
  log-iteration-complete $store "test-session" 2 "failure"
  
  print "✓ Added 4 iteration events"
  
  print "\n7. Testing show-iterations with populated store..."
  show-iterations $store "test-session"
  print "✓ show-iterations displays iteration history (visual verification above)"
}

def "test store data verification" [store: string] {
  print "\n8. Verifying data in store..."
  let task_count = (xs cat $store | from json --objects | where topic == "ralph.test-session.task" | length)
  assert equal $task_count 6 "Expected 6 tasks in store"
  print $"✓ Correct number of tasks in store: ($task_count)"
  
  let iter_count = (xs cat $store | from json --objects | where topic == "ralph.test-session.iteration" | length)
  assert equal $iter_count 4 "Expected 4 iteration events in store"
  print $"✓ Correct number of iteration events in store: ($iter_count)"
}

print "Testing Task 9: Status display helpers..."

# Setup: Create a temporary store
let test_store = $"/tmp/ralph-test-status-(random chars -l 8)"
mkdir $test_store

try {
  # Start xs store for testing
  print "\n1. Starting xs store..."
  let store_job_id = (start-store $test_store)
  
  print "✓ Store started"
  
  # Run tests in sequence
  do { test show-tasks empty store $test_store }
  do { test show-iterations empty store $test_store }
  do { test show-tasks with data $test_store }
  do { test show-iterations with data $test_store }
  do { test store data verification $test_store }
  
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
