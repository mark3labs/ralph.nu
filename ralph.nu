#!/usr/bin/env nu

# ralph.nu - Iterative AI coding assistant with xs event store and opencode web UI

# Start xs store server as background job
def start-store [
  store_path: string  # Path to the store directory
] {
  # Create store directory if it doesn't exist
  mkdir $store_path
  
  print $"Starting xs store at ($store_path)..."
  
  # Start xs serve as background job and capture job ID
  let job_id = (job spawn { xs serve $store_path })
  
  # Wait for store to be ready (poll xs version)
  for attempt in 0..30 {
    let result = (xs version $store_path | complete)
    if $result.exit_code == 0 {
      print "xs store is ready!"
      return $job_id
    }
    sleep 100ms
  }
  
  # If we get here, store didn't start
  error make {msg: "xs store failed to start after 3 seconds"}
}

# Start opencode web server as background job
def start-web [
  port: int  # Port for the web server
] {
  print $"Starting opencode web on port ($port)..."
  
  # Start opencode web as background job and capture job ID
  let job_id = (job spawn { opencode web --port $port })
  
  # Wait for web server to be ready (poll with curl)
  for attempt in 0..30 {
    let result = (curl -s -o /dev/null -w "%{http_code}" $"http://localhost:($port)" | complete)
    if $result.exit_code == 0 and ($result.stdout | into int) < 500 {
      print $"opencode web is ready at http://localhost:($port)"
      return {job_id: $job_id, url: $"http://localhost:($port)"}
    }
    sleep 100ms
  }
  
  # If we get here, web server didn't start
  error make {msg: "opencode web failed to start after 3 seconds"}
}

# Cleanup function to kill all spawned jobs
def cleanup [
  job_ids: list<int>  # List of job IDs to kill
] {
  print "Cleaning up background jobs..."
  
  for job_id in $job_ids {
    try {
      job kill $job_id
      print $"Killed job ($job_id)"
    } catch {
      # Job may have already exited - ignore errors
    }
  }
}

# Main entry point
def main [
  --name (-n): string                                       # REQUIRED - name for this ralph session
  --prompt (-p): string                                     # Custom prompt
  --spec (-s): string = "./specs/SPEC.md"                   # Spec file path
  --model (-m): string = "anthropic/claude-sonnet-4-5"      # Model to use
  --iterations (-i): int = 0                                # Number of iterations (0 = infinite)
  --port: int = 4096                                        # opencode web port
  --store: string = "./.ralph/store"                        # xs store path
]: [string -> nothing, nothing -> nothing] {
  # Validate required parameter
  if ($name | is-empty) {
    error make {msg: "--name (-n) is required"}
  }

  print "ralph.nu starting..."
  print $"Session: ($name)"
  print $"Store: ($store)"
  print $"Port: ($port)"
}
