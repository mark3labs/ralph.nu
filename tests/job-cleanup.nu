#!/usr/bin/env nu

# Test script for ralph.nu cleanup handler
# This test verifies that cleanup properly kills all spawned jobs

use std/assert

source ../ralph.nu

def "test cleanup kills all spawned jobs" [] {
  # Setup test store
  let test_store = "./test-cleanup-store"
  rm -rf $test_store
  
  # Start some jobs
  let store_job = (start-store $test_store)
  let web_result = (start-web 4098)
  
  # Verify jobs are running
  let jobs_before = (job list)
  assert greater ($jobs_before | length) 0 "Expected jobs to be running before cleanup"
  
  # Call cleanup
  cleanup [$store_job, $web_result.job_id]
  
  # Wait a moment for jobs to terminate
  sleep 500ms
  
  # Verify jobs are gone
  let jobs_after = (job list)
  assert equal ($jobs_after | length) 0 "Expected all jobs to be killed after cleanup"
  
  # Cleanup test directory
  rm -rf $test_store
}

# Run tests
print "Running test cleanup kills all spawned jobs..."
test cleanup kills all spawned jobs
print "✓ test cleanup kills all spawned jobs passed"
print "\n✓ All cleanup tests passed!"
