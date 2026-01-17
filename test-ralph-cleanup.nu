#!/usr/bin/env nu

# Test script for ralph.nu cleanup handler
# This test verifies that cleanup properly kills all spawned jobs

source ralph.nu

print "Testing cleanup handler..."

# Setup test store
let test_store = "./test-cleanup-store"
rm -rf $test_store

print "\n1. Testing cleanup with multiple jobs..."

# Start some jobs
print "Starting xs store..."
let store_job = (start-store $test_store)
print $"✓ Started store job: ($store_job)"

print "Starting opencode web..."
let web_result = (start-web 4098)
print $"✓ Started web job: ($web_result.job_id)"

# Verify jobs are running
let jobs_before = (job list)
print $"\nJobs running before cleanup: ($jobs_before | length)"
for j in $jobs_before {
  print $"  Job ID: ($j.id)"
}

# Call cleanup
print "\nCalling cleanup..."
cleanup [$store_job, $web_result.job_id]

# Wait a moment for jobs to terminate
sleep 500ms

# Verify jobs are gone
let jobs_after = (job list)
print $"\nJobs running after cleanup: ($jobs_after | length)"

if ($jobs_after | length) == 0 {
  print "✓ All jobs successfully killed"
} else {
  print "✗ Some jobs still running:"
  for j in $jobs_after {
    print $"  Job ID: ($j.id)"
  }
  exit 1
}

# Cleanup test directory
print "\n2. Cleaning up test directory..."
rm -rf $test_store
print "✓ Test directory removed"

print "\n✓ All cleanup tests passed!"
