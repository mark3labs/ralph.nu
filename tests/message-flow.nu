#!/usr/bin/env nu

# Test the message flow: send message, verify in prompt, mark as read
# This test covers tasks 20-22 from the spec

use std/assert
use mod.nu [setup-test-store, teardown-test-store]

# Source ralph.nu to get access to its functions
source ../ralph.nu

def "test message flow" [] {
  print $"(ansi cyan_bold)Testing message flow...(ansi reset)\n"
  
  # Setup
  print "1. Setting up test store..."
  let store_data = (setup-test-store)
  let store = $store_data.store_path
  print $"(ansi green)✓(ansi reset) Store ready at ($store)\n"
  
  # Task 20: Send message to running session
  print "2. Testing message sending..."
  let session = "test-session"
  let message = "Please prioritize the login feature"
  
  # Send message using the main message command
  let result = (do { 
    ^nu ../ralph.nu message --name $session $message 
  } | complete)
  
  if $result.exit_code != 0 {
    error make {msg: $"Failed to send message: ($result.stderr)"}
  }
  
  print $"(ansi green)✓(ansi reset) Message sent successfully"
  print $"   ($result.stdout | str trim)\n"
    
    # Task 21: Verify message appears in agent prompt
    print "3. Verifying message appears in inbox state..."
    let inbox_messages = (get-inbox-state $store $session)
    
    assert equal ($inbox_messages | length) 1
    assert equal $inbox_messages.0.content $message
    assert equal $inbox_messages.0.status "unread"
    print $"(ansi green)✓(ansi reset) Message appears in inbox state\n"
    
    # Verify message formatting for prompt
    print "4. Verifying message formatting for prompt..."
    let formatted = (format-inbox-for-prompt $inbox_messages)
    
    assert ($formatted | str contains "INBOX")
    assert ($formatted | str contains $message)
    assert ($formatted | str contains "inbox_mark_read")
    print $"(ansi green)✓(ansi reset) Message formatted correctly for prompt\n"
    
    # Verify build-prompt includes inbox
    print "5. Verifying inbox injection in build-prompt..."
    let spec_content = "# Test Spec\nTest task"
    let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
    let prompt = (build-prompt $spec_content $store $session 1 $task_state)
    
    assert ($prompt | str contains "INBOX")
    assert ($prompt | str contains $message)
    print $"(ansi green)✓(ansi reset) Inbox section injected in prompt\n"
    
    # Task 22: Verify mark_read removes from unread list
    print "6. Testing mark_read functionality..."
    let msg_id = $inbox_messages.0.id
    
    # Mark message as read by appending mark_read action
    let topic = $"ralph.($session).inbox"
    let meta = {action: "mark_read", id: $msg_id} | to json -r
    xs append $store $topic --meta $meta | ignore
    
    # Get inbox state again
    let inbox_after = (get-inbox-state $store $session)
    
    assert equal ($inbox_after | length) 0
    print $"(ansi green)✓(ansi reset) Message removed from unread list after mark_read\n"
    
    # Verify prompt no longer shows inbox when empty
    print "7. Verifying prompt without unread messages..."
    let prompt_after = (build-prompt $spec_content $store $session 2 $task_state)
    
    assert (not ($prompt_after | str contains "INBOX"))
    print $"(ansi green)✓(ansi reset) Inbox section not shown when no unread messages\n"
    
    # Test multiple messages
    print "8. Testing multiple messages..."
    ^nu ../ralph.nu message --name $session "First message" | ignore
    ^nu ../ralph.nu message --name $session "Second message" | ignore
    
    let multi_inbox = (get-inbox-state $store $session)
    assert equal ($multi_inbox | length) 2
    print $"(ansi green)✓(ansi reset) Multiple messages handled correctly\n"
    
    # Mark first message as read
    let first_id = $multi_inbox.0.id
    let meta2 = {action: "mark_read", id: $first_id} | to json -r
    xs append $store $topic --meta $meta2 | ignore
    
    let inbox_partial = (get-inbox-state $store $session)
    assert equal ($inbox_partial | length) 1
    print $"(ansi green)✓(ansi reset) Partial read marking works correctly\n"
    
    print $"\n(ansi green_bold)✓ All message flow tests passed!(ansi reset)"
  
  # Cleanup
  teardown-test-store $store_data
}

# Run the test
use mod.nu [run-tests]
run-tests
