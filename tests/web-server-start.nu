#!/usr/bin/env nu

# Test suite for start-web function
# Verifies that start-web can start opencode serve and poll it successfully

use std/assert
use mod.nu [run-tests]

# Source ralph.nu to get the actual start-web function
source ../ralph.nu

def "test start-web starts server and returns url" [] {
  let port = 4097
  let result = (start-web $port)
  
  # Verify result has expected fields
  assert ("url" in $result)
  assert ("job_id" in $result)
  
  # Verify URL contains the port
  assert str contains $result.url $"($port)"
  
  # Cleanup
  try {
    job kill $result.job_id
  } catch {
    # Job may have already exited
  }
}

def "test start-web server responds to http requests" [] {
  let port = 4098
  let result = (start-web $port)
  
  # Verify we can access it
  let response = (curl -s -o /dev/null -w "%{http_code}" $result.url | complete)
  assert equal $response.exit_code 0 "curl should succeed"
  
  # Cleanup
  try {
    job kill $result.job_id
  } catch {
    # Job may have already exited
  }
}

run-tests
