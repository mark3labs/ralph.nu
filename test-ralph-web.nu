#!/usr/bin/env nu

# Simple test for start-web function
# This test verifies that start-web can start opencode web and poll it successfully

# Inline copy of start-web for testing
def start-web [
  port: int  # Port for the web server
] {
  print $"Starting opencode web on port ($port)..."
  
  # Start opencode web as background job
  job spawn { opencode web --port $port }
  
  # Wait for web server to be ready (poll with curl)
  for attempt in 0..30 {
    let result = (curl -s -o /dev/null -w "%{http_code}" $"http://localhost:($port)" | complete)
    if $result.exit_code == 0 and ($result.stdout | into int) < 500 {
      print $"opencode web is ready at http://localhost:($port)"
      return $"http://localhost:($port)"
    }
    sleep 100ms
  }
  
  # If we get here, web server didn't start
  error make {msg: "opencode web failed to start after 3 seconds"}
}

print "Testing start-web function..."

try {
  # Start the web server
  let url = (start-web 4097)
  print $"✓ Web server started successfully: ($url)"
  
  # Verify we can access it
  let response = (curl -s -o /dev/null -w "%{http_code}" $url | complete)
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
