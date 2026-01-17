#!/usr/bin/env nu

# Test script for ralph.nu iteration logging functions

source ../ralph.nu

print "Testing iteration logging functions..."

# Setup test store
let test_store = "./test-logging-store"
rm -rf $test_store
mkdir $test_store

# Start xs store
print "\n1. Starting xs store..."
let store_job = (start-store $test_store)
print $"Store job ID: ($store_job)"

# Test log-iteration-start
print "\n2. Testing log-iteration-start..."
log-iteration-start $test_store "test-session" 1
log-iteration-start $test_store "test-session" 2

# Test log-iteration-complete
print "\n3. Testing log-iteration-complete..."
log-iteration-complete $test_store "test-session" 1 "success"
log-iteration-complete $test_store "test-session" 2 "success"

# Read back the logged events
print "\n4. Reading iteration events..."
let events = (xs cat $test_store | from json --objects | where topic == "ralph.test-session.iteration")
print $events

# Verify we have 4 events (2 start, 2 complete)
let event_count = ($events | length)
print $"\nTotal events: ($event_count)"

if $event_count == 4 {
  print "✓ Correct number of events logged"
} else {
  print $"✗ Expected 4 events, got ($event_count)"
}

# Check event structure
print "\n5. Checking event metadata..."
for event in $events {
  print $"Topic: ($event.topic)"
  print $"  Action: ($event.meta.action)"
  print $"  Iteration: ($event.meta.n)"
  print $"  Timestamp: ($event.meta.timestamp)"
  if $event.meta.action == "complete" {
    print $"  Status: ($event.meta.status)"
  }
}

# Cleanup
print "\n6. Cleaning up..."
cleanup [$store_job]
sleep 500ms
rm -rf $test_store

print "\n✓ Test complete!"
