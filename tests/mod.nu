# Test framework utilities for ralph.nu test suite
# Provides test runner, test discovery, and helper functions

use std/assert

# Run all test functions in the current scope
export def run-tests [] {
  let tests = (scope commands | where name =~ "^test " | get name)
  
  if ($tests | is-empty) {
    print "No tests found"
    return
  }
  
  print $"Running ($tests | length) tests..."
  print ""
  
  let results = ($tests | each {|test_name|
    print $"(ansi yellow)▸(ansi reset) ($test_name)"
    
    try {
      do { $test_name }
      print $"(ansi green)✓(ansi reset) ($test_name)"
      {test: $test_name, status: "passed"}
    } catch {|e|
      print $"(ansi red)✗(ansi reset) ($test_name): ($e.msg)"
      {test: $test_name, status: "failed", error: $e.msg}
    }
  })
  
  print ""
  let passed = ($results | where status == "passed" | length)
  let failed = ($results | where status == "failed" | length)
  
  if $failed > 0 {
    print $"(ansi red)($failed) test(s) failed(ansi reset), ($passed) passed"
    exit 1
  } else {
    print $"(ansi green)All ($passed) tests passed(ansi reset)"
  }
}

# Setup a temporary test store
# Returns a record with store_path and job_id
export def setup-test-store [] {
  let store_path = $"/tmp/ralph-test-(random chars -l 8)"
  
  # Clean up if already exists
  rm -rf $store_path
  
  # Create store directory
  mkdir $store_path
  
  # Start xs serve as background job
  let job_id = (job spawn { xs serve $store_path })
  
  # Wait for store to be ready
  for attempt in 0..30 {
    let result = (xs version $store_path | complete)
    if $result.exit_code == 0 {
      return {store_path: $store_path, job_id: $job_id}
    }
    sleep 100ms
  }
  
  # Failed to start
  error make {msg: "Test store failed to start"}
}

# Teardown test store
export def teardown-test-store [
  store_info: record  # Record with store_path and job_id from setup-test-store
] {
  # Kill the xs serve job
  try {
    job kill $store_info.job_id
  } catch {
    # Job may have already exited - ignore
  }
  
  # Remove the store directory
  try {
    rm -rf $store_info.store_path
  } catch {
    # Directory may not exist - ignore
  }
}
