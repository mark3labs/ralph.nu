#!/usr/bin/env nu

# Simple test for start-web function
# This test verifies that start-web can start opencode web and poll it successfully

# Source ralph.nu to get the actual start-web function
source ralph.nu

print "Testing start-web function..."

try {
  # Start the web server
  let result = (start-web 4097)
  print $"✓ Web server started successfully: ($result.url)"
  print $"✓ Job ID: ($result.job_id)"
  
  # Verify we can access it
  let response = (curl -s -o /dev/null -w "%{http_code}" $result.url | complete)
  if $response.exit_code == 0 {
    print $"✓ Web server responds with HTTP ($response.stdout)"
  } else {
    print "✗ Failed to get response from web server"
    exit 1
  }
  
  # Kill the job
  let jobs = (job list)
  for j in $jobs {
    job kill $j.id
    print $"✓ Killed job ($j.id)"
  }
  
  print "\n✓ All tests passed!"
} catch { |err|
  print $"✗ Test failed: ($err.msg)"
  
  # Cleanup jobs on failure
  let jobs = (job list)
  for j in $jobs {
    job kill $j.id
  }
  
  exit 1
}
