# Test Refactor Spec

## Overview
Refactor test suite to use Nushell's `std/assert` module consistently and adopt the basic test framework pattern for better organization and error messages.

## User Story
As a developer, I want consistent, well-organized tests with clear error messages so failures are easy to diagnose.

## Requirements
- Use `std/assert` commands instead of manual if/else + print + exit patterns
- Adopt `def "test ..."` naming convention for unit tests
- Keep integration tests as standalone scripts (complex setup/teardown)
- Maintain existing test coverage

## Technical Implementation

### Pattern: Unit Tests
```nu
use std/assert

def "test notes display empty" [] {
  # setup
  let store = setup-test-store
  # test
  let result = (show-notes $store "test")
  assert equal $result.count 0
  # teardown handled by test runner
}

def main [] {
  let tests = (scope commands | where name =~ "^test " | get name)
  for t in $tests { do { $t } }
}
```

### Pattern: Integration Tests
Keep as standalone scripts with explicit setup/cleanup blocks. Replace manual checks with asserts where practical.

### Files to Refactor

| File | Type | Changes |
|------|------|---------|
| `prompt-template.nu` | unit | Convert to `def "test ..."` pattern |
| `input-handling.nu` | unit | Already uses assert, add test function wrapper |
| `status-display.nu` | unit | Convert manual checks to asserts |
| `job-cleanup.nu` | unit | Convert manual checks to asserts |
| `iteration-loop.nu` | unit | Convert to test function pattern |
| `integration.nu` | integration | Keep structure, replace manual checks with asserts |
| `web-server-start.nu` | unit | Convert to test function pattern |

## Tasks

### 1. Create test runner utility
- [ ] Create `tests/mod.nu` with test discovery and runner logic
- [ ] Add helper functions: `setup-test-store`, `teardown-test-store`

### 2. Refactor prompt-template.nu
- [ ] Add `use std/assert`
- [ ] Wrap checks in `def "test prompt contains spec"` etc
- [ ] Replace print-based checks with `assert str contains`

### 3. Refactor input-handling.nu
- [ ] Wrap existing asserts in `def "test ..."` functions
- [ ] Remove redundant print statements

### 4. Refactor status-display.nu
- [ ] Replace manual if/else/exit with `assert equal`
- [ ] Wrap in `def "test ..."` functions
- [ ] Keep setup/teardown in main or use shared helpers

### 5. Refactor job-cleanup.nu
- [ ] Replace manual checks with `assert equal`
- [ ] Wrap in test functions

### 6. Refactor iteration-loop.nu
- [ ] Review and convert to test function pattern

### 7. Refactor web-server-start.nu
- [ ] Review and convert to test function pattern

### 8. Refactor integration.nu
- [ ] Keep overall structure (complex setup/teardown)
- [ ] Replace manual if/else checks with `assert` calls
- [ ] Improve error messages using assert's built-in formatting

### 9. Update test runner
- [ ] Create `tests/run-all.nu` script to run all test files
- [ ] Document test running in README or AGENTS.md

## Out of Scope
- Nupm package conversion
- Code coverage tooling
- CI/CD integration (separate effort)

## Open Questions
- Should we add a `--verbose` flag to test runner for debugging?
