#!/usr/bin/env nu

# Tests for single task addition
# Covers tasks:
# - Test adding task with default status (remaining)
# - Test adding task with explicit "remaining" status
# - Test adding task with "blocked" status
# - Verify task appears in correct status category
# - Verify task content preserved correctly
# - Verify task ID generated and accessible

# Source helper functions
source helpers.nu

# Source ralph.nu to get access to the functions
source ../../ralph.nu

# Helper to add a task to the test store
def add-test-task [
  store: string
  topic: string
  content: string
  status: string = "remaining"
] {
  let meta = ({action: "add", status: $status} | to json -r)
  echo $content | xs append $store $topic --meta $meta
}

def run-tests [] {
  print "=== Running: single-task-add.nu ==="
  
  # Setup test environment
  let ctx = (setup-test-store)
  
  try {
    # Test 1: Adding task with default status (remaining)
    print "\n--- Test 1: Add task with default status ---"
    let task_content = "Test task with default status"
    add-test-task $ctx.store $ctx.topic $task_content
    sleep 50ms
    
    let state1 = (get-task-state $ctx.store "test")
    assert-eq ($state1.remaining | length) 1 "task added to remaining by default"
    let task1 = ($state1.remaining | first)
    assert-eq $task1.content $task_content "task content preserved with default status"
    assert-true (($task1.id | str length) > 20) "task ID generated with default status"
    
    # Test 2: Adding task with explicit "remaining" status
    print "\n--- Test 2: Add task with explicit remaining status ---"
    let task_content2 = "Test task with explicit remaining"
    add-test-task $ctx.store $ctx.topic $task_content2 "remaining"
    sleep 50ms
    
    let state2 = (get-task-state $ctx.store "test")
    assert-eq ($state2.remaining | length) 2 "task added with explicit remaining status"
    let task2 = ($state2.remaining | where content == $task_content2 | first)
    assert-eq $task2.content $task_content2 "task content preserved with explicit remaining"
    assert-eq $task2.status "remaining" "task has remaining status"
    
    # Test 3: Adding task with "blocked" status
    print "\n--- Test 3: Add task with blocked status ---"
    let task_content3 = "Test task with blocked status"
    add-test-task $ctx.store $ctx.topic $task_content3 "blocked"
    sleep 50ms
    
    let state3 = (get-task-state $ctx.store "test")
    assert-eq ($state3.blocked | length) 1 "task added to blocked category"
    let task3 = ($state3.blocked | first)
    assert-eq $task3.content $task_content3 "task content preserved with blocked status"
    assert-eq $task3.status "blocked" "task has blocked status"
    
    # Test 4: Verify task appears in correct status category
    print "\n--- Test 4: Verify task categorization ---"
    assert-eq ($state3.remaining | length) 2 "remaining tasks still in remaining"
    assert-eq ($state3.blocked | length) 1 "blocked task in blocked"
    assert-eq ($state3.in_progress | length) 0 "no in_progress tasks"
    assert-eq ($state3.completed | length) 0 "no completed tasks"
    
    # Test 5: Verify task content preserved correctly
    print "\n--- Test 5: Verify content preservation ---"
    let all_contents = [$task_content, $task_content2, $task_content3]
    let remaining_contents = ($state3.remaining | get content)
    let blocked_contents = ($state3.blocked | get content)
    let state_contents = ($remaining_contents | append $blocked_contents)
    assert-eq ($state_contents | length) 3 "all task contents accessible"
    for content in $all_contents {
      assert-true ($content in $state_contents) $"content '($content)' preserved"
    }
    
    # Test 6: Verify task ID generated and accessible
    print "\n--- Test 6: Verify ID generation ---"
    let remaining_ids = ($state3.remaining | get id)
    let blocked_ids = ($state3.blocked | get id)
    let all_ids = ($remaining_ids | append $blocked_ids)
    assert-eq ($all_ids | length) 3 "all task IDs present"
    for id in $all_ids {
      assert-true (($id | str length) > 20) $"ID ($id | str substring 0..8) is valid length"
      assert-true ($id =~ "^[a-z0-9]+$") $"ID ($id | str substring 0..8) contains valid characters"
    }
    
    # Verify all IDs are unique
    let unique_ids = ($all_ids | uniq)
    assert-eq ($unique_ids | length) 3 "all task IDs are unique"
    
    print "\nAll single task add tests passed!"
    
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
