#!/usr/bin/env nu

# Test helpers for task state management tests

# Setup a temporary xs store for testing
# Returns a record with store path, topic, and job ID
def "setup-test-store" [] {
  let store = $"/tmp/ralph-test-(random uuid | str substring 0..8)"
  let job_id = (job spawn { xs serve $store })
  sleep 100ms
  { store: $store, topic: "ralph.test.task", job_id: $job_id }
}

# Teardown test store and cleanup
def "teardown-test-store" [ctx: record] {
  try { job kill $ctx.job_id } catch { }
  sleep 50ms
  rm -rf $ctx.store
}

# Assert equality between actual and expected values
def "assert-eq" [actual: any, expected: any, msg: string] {
  if $actual != $expected {
    print $"✗ ($msg): expected ($expected), got ($actual)"
    exit 1
  }
  print $"✓ ($msg)"
}

# Assert that haystack contains needle
def "assert-contains" [haystack: string, needle: string, msg: string] {
  if not ($haystack | str contains $needle) {
    print $"✗ ($msg): '($needle)' not in '($haystack)'"
    exit 1
  }
  print $"✓ ($msg)"
}

# Assert boolean is true
def "assert-true" [value: bool, msg: string] {
  if not $value {
    print $"✗ ($msg): expected true, got false"
    exit 1
  }
  print $"✓ ($msg)"
}

# Assert boolean is false
def "assert-false" [value: bool, msg: string] {
  if $value {
    print $"✗ ($msg): expected false, got true"
    exit 1
  }
  print $"✓ ($msg)"
}

# Assert that code block produces an error
def "assert-error" [code: closure, msg: string] {
  let result = (try { do $code; false } catch { true })
  if not $result {
    print $"✗ ($msg): expected error but code succeeded"
    exit 1
  }
  print $"✓ ($msg)"
}
