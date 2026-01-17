#!/usr/bin/env nu

# Test iteration notes functionality

use std/assert
use mod.nu [run-tests, setup-test-store, teardown-test-store]

source ../ralph.nu

def "test notes persist across iterations" [] {
  let test_store = (setup-test-store)
  
  print "\nTesting note persistence across iterations..."
  
  # Add notes in iteration 1
  print "1. Adding notes in iteration 1..."
  echo "API rate limit is 100/min" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"stuck","iteration":1}'
  echo "Tests require --no-cache flag" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"learning","iteration":1}'
  
  # Get notes state
  let notes = (get-note-state $test_store "test-notes")
  print $"   Found ($notes | length) notes"
  assert equal ($notes | length) 2
  
  # Add notes in iteration 2
  print "2. Adding notes in iteration 2..."
  echo "Using SQLite over Postgres" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"decision","iteration":2}'
  
  # Get notes state again
  let notes2 = (get-note-state $test_store "test-notes")
  print $"   Found ($notes2 | length) notes total"
  assert equal ($notes2 | length) 3
  
  # Verify notes have correct iterations
  let iter1_notes = ($notes2 | where iteration == 1)
  let iter2_notes = ($notes2 | where iteration == 2)
  assert equal ($iter1_notes | length) 2
  assert equal ($iter2_notes | length) 1
  
  print "✓ Notes persist across iterations"
  
  teardown-test-store $test_store
}

def "test format-notes-for-prompt filters current iteration" [] {
  let test_store = (setup-test-store)
  
  print "\nTesting note filtering for current iteration..."
  
  # Add notes from iterations 1, 2, 3
  echo "Iter 1 note" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"learning","iteration":1}'
  echo "Iter 2 note" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"stuck","iteration":2}'
  echo "Iter 3 note" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"tip","iteration":3}'
  
  let notes = (get-note-state $test_store "test-notes")
  
  # Format for iteration 3 (should only show notes from 1 and 2)
  let formatted = (format-notes-for-prompt $notes 3)
  
  print "   Formatted prompt section:"
  print $formatted
  
  assert str contains $formatted "Iter 1 note"
  assert str contains $formatted "Iter 2 note"
  assert not ($formatted | str contains "Iter 3 note")
  
  print "✓ Current iteration notes filtered correctly"
  
  teardown-test-store $test_store
}

def "test show-session-notes displays grouped by type" [] {
  let test_store = (setup-test-store)
  
  print "\nTesting show-session-notes display..."
  
  # Add notes of different types
  echo "Hit API limit" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"stuck","iteration":1}'
  echo "Use exponential backoff" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"learning","iteration":1}'
  echo "Always check rate limit headers" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"tip","iteration":2}'
  echo "Chose REST over GraphQL" | xs append $test_store ralph.test-notes.note --meta '{"action":"add","type":"decision","iteration":2}'
  
  print "   Display output:"
  show-session-notes $test_store "test-notes"
  
  print "\n✓ Notes display grouped by type (visual verification above)"
  
  teardown-test-store $test_store
}

run-tests
