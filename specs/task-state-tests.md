# Task State Management Test Suite

## Overview

Comprehensive test coverage for ralph.nu's task state management system. Validates the event-sourcing pattern used by `get-task-state`, output formatting by `format-task-state`, and integration with xs store.

## User Story

Developers need confidence that task state management handles edge cases correctly. Tests prevent regressions when refactoring the event-reduce pattern.

## Requirements

### Unit Test Coverage
- `get-task-state` function - event reduction logic
- `format-task-state` function - output formatting
- `show-notes` function - display formatting
- ID prefix matching - partial ID lookups

### Edge Case Coverage
- Empty store (no events)
- Single task lifecycle
- Multiple tasks with interleaved operations
- Invalid operations (bad IDs, invalid transitions)
- Duplicate task additions
- Status transition validation

### Integration Coverage
- Round-trip with actual xs store
- Custom tool integration (if implemented)
- Concurrent operation handling

## Technical Implementation

### Test File Structure
```
tests/
├── task-state/
│   ├── get-task-state.nu      # Unit tests for state reduction
│   ├── format-task-state.nu   # Unit tests for formatting
│   ├── show-notes.nu          # Unit tests for display
│   ├── id-matching.nu         # Partial ID prefix tests
│   ├── edge-cases.nu          # Invalid inputs, boundaries
│   ├── transitions.nu         # Status transition validation
│   └── integration.nu         # Full round-trip tests
```

### Test Helper Pattern
```nushell
# Each test file sources ralph.nu and uses temp stores
def setup-test-store [] {
  let store = $"/tmp/ralph-test-($random uuid | str substring 0..8)"
  xs serve $store --gc 1000000000 &
  sleep 100ms
  { store: $store, topic: "ralph.test.task" }
}

def teardown-test-store [ctx: record] {
  xs .stop $ctx.store
  rm -rf $ctx.store
}
```

### Assertions Pattern
```nushell
def assert-eq [actual: any, expected: any, msg: string] {
  if $actual != $expected {
    print $"✗ ($msg): expected ($expected), got ($actual)"
    exit 1
  }
  print $"✓ ($msg)"
}

def assert-contains [haystack: string, needle: string, msg: string] {
  if not ($haystack | str contains $needle) {
    print $"✗ ($msg): '($needle)' not in '($haystack)'"
    exit 1
  }
  print $"✓ ($msg)"
}
```

## Tasks

### 1. Create test infrastructure
- [ ] Create `tests/task-state/` directory
- [ ] Create `tests/task-state/helpers.nu` with setup/teardown functions
- [ ] Add `assert-eq` helper for equality checks
- [ ] Add `assert-contains` helper for string checks
- [ ] Add `assert-true` / `assert-false` helpers
- [ ] Add `assert-error` helper for expected failures
- [ ] Create test runner script `tests/task-state/run-all.nu`

### 2. Unit tests: empty store handling
- [ ] Test `get-task-state` returns empty record for new store
- [ ] Test `get-task-state` returns empty lists for each status category
- [ ] Test `format-task-state` with empty state produces "No tasks"
- [ ] Test `show-notes` with empty store produces expected output

### 3. Unit tests: single task add
- [ ] Test adding task with default status (remaining)
- [ ] Test adding task with explicit "remaining" status
- [ ] Test adding task with "blocked" status
- [ ] Verify task appears in correct status category
- [ ] Verify task content preserved correctly
- [ ] Verify task ID generated and accessible

### 4. Unit tests: task status transitions
- [ ] Test remaining -> in_progress transition
- [ ] Test in_progress -> completed transition
- [ ] Test remaining -> blocked transition
- [ ] Test blocked -> remaining transition (unblock)
- [ ] Test blocked -> in_progress transition
- [ ] Verify previous status cleared after transition
- [ ] Test multiple transitions on same task

### 5. Unit tests: multiple tasks
- [ ] Test adding 3 tasks, all start as remaining
- [ ] Test mixed statuses (1 remaining, 1 in_progress, 1 completed)
- [ ] Test all tasks completed scenario
- [ ] Test interleaved add/status operations
- [ ] Verify task ordering within categories
- [ ] Verify total task count accuracy

### 6. Unit tests: ID prefix matching
- [ ] Test full ID lookup succeeds
- [ ] Test 8-char prefix lookup succeeds
- [ ] Test 12-char prefix lookup succeeds
- [ ] Test ambiguous prefix (matches multiple) handling
- [ ] Test non-existent ID returns error/null
- [ ] Test empty ID string handling
- [ ] Test case sensitivity of ID matching

### 7. Unit tests: format-task-state output
- [ ] Test "IN PROGRESS" section header formatting
- [ ] Test "REMAINING" section header formatting
- [ ] Test "COMPLETED" section header formatting
- [ ] Test "BLOCKED" section header formatting
- [ ] Test task line format: "- [id] content"
- [ ] Test ID truncation (8 chars displayed)
- [ ] Test multi-line task content handling
- [ ] Test section ordering (in_progress first)
- [ ] Test empty section omission

### 8. Unit tests: show-notes display
- [ ] Test output matches format-task-state
- [ ] Test with piped vs interactive mode
- [ ] Test color codes present/absent based on terminal

### 9. Edge case tests: invalid inputs
- [ ] Test status update with non-existent ID
- [ ] Test adding task with empty content
- [ ] Test adding task with very long content (1000+ chars)
- [ ] Test status update with invalid status string
- [ ] Test adding task with special chars in content
- [ ] Test adding task with newlines in content
- [ ] Test adding task with unicode/emoji content

### 10. Edge case tests: state boundaries
- [ ] Test 100 tasks performance
- [ ] Test 1000 events on single task
- [ ] Test task with all status transitions in sequence
- [ ] Test rapid sequential status updates
- [ ] Test concurrent add operations (race condition)

### 11. Edge case tests: data integrity
- [ ] Test store corruption recovery (if applicable)
- [ ] Test partial event replay
- [ ] Test duplicate event handling
- [ ] Verify idempotency of state reduction

### 12. Integration tests: full lifecycle
- [ ] Test complete task lifecycle: add -> in_progress -> completed
- [ ] Test session with multiple tasks completing sequentially
- [ ] Test session resumption (state reload from store)
- [ ] Test iteration boundary crossing

### 13. Integration tests: xs store interaction
- [ ] Test xs append creates correct frame
- [ ] Test xs cat returns expected event format
- [ ] Test topic filtering works correctly
- [ ] Test meta field encoding/decoding
- [ ] Test hash/content retrieval via xs cas

### 14. Regression tests: known issues
- [ ] Add test for any bug fixes (document issue)
- [ ] Test that fixes remain effective
- [ ] Create regression test template

### 15. Documentation and cleanup
- [ ] Add README.md to tests/task-state/ explaining structure
- [ ] Document how to run individual test files
- [ ] Document how to run full suite
- [ ] Add test coverage summary comments
- [ ] Ensure all temp stores cleaned up on failure

### 16. CI integration prep
- [ ] Create single entry point script
- [ ] Add exit codes for pass/fail
- [ ] Add summary output at end
- [ ] Document CI integration steps

## UI Mockup

Test output format:
```
=== Running: get-task-state.nu ===
✓ empty store returns empty record
✓ empty store has empty remaining list
✓ empty store has empty completed list
✗ empty store has empty blocked list: expected [], got null
  
=== Running: format-task-state.nu ===
✓ formats in_progress section
✓ formats remaining section
...

=== Summary ===
Passed: 45/47
Failed: 2
  - get-task-state.nu:4 - empty store blocked list
  - edge-cases.nu:12 - unicode content
```

## Out of Scope (v1)
- Property-based/fuzz testing
- Performance benchmarks with timing
- Mocking xs store (use real temp stores)
- Coverage tooling integration
- Parallel test execution
- Watch mode for TDD

## Open Questions
- Should failed tests continue or halt early?
- Include snapshot testing for format output?
- Test against multiple Nushell versions?
