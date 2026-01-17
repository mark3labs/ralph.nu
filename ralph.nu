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

# Log iteration start event to xs store
def log-iteration-start [
  store_path: string  # Path to the store directory
  name: string        # Session name
  iteration: int      # Iteration number
] {
  let topic = $"ralph.($name).iteration"
  let timestamp = (date now | format date "%Y-%m-%dT%H:%M:%S%z")
  let meta = {action: "start", n: $iteration, timestamp: $timestamp} | to json -r
  
  echo "" | xs append $store_path $topic --meta $meta
}

# Log iteration complete event to xs store
def log-iteration-complete [
  store_path: string  # Path to the store directory
  name: string        # Session name
  iteration: int      # Iteration number
  status: string      # Status: "success" or "failure"
] {
  let topic = $"ralph.($name).iteration"
  let timestamp = (date now | format date "%Y-%m-%dT%H:%M:%S%z")
  let meta = {action: "complete", n: $iteration, status: $status, timestamp: $timestamp} | to json -r
  
  echo "" | xs append $store_path $topic --meta $meta
}

# Build prompt template with placeholders and xs CLI examples
def build-prompt [
  spec_content: string  # Content of the spec file
  store_path: string    # Path to the store directory
  name: string          # Session name
  pid: int              # Parent process ID for termination
  iteration: int        # Current iteration number
] {
  let template = $"## Context
- Spec: ($spec_content)
- Store: ($store_path) \(use xs CLI for state\)
- Topic prefix: ralph.($name)

## State Commands \(xs CLI\)
# Read all notes with content
xs cat ($store_path) | from json --objects | where topic == \"ralph.($name).note\" | each { |frame| 
  {type: $frame.meta.type, content: \(xs cas ($store_path) $frame.hash\)} 
}

# Add completed note  
echo \"Task description\" | xs append ($store_path) ralph.($name).note --meta '{\"type\":\"completed\",\"iteration\":($iteration)}'

# Add in_progress note
echo \"Current task\" | xs append ($store_path) ralph.($name).note --meta '{\"type\":\"in_progress\",\"iteration\":($iteration)}'

# Add blocked note
echo \"Blocker description\" | xs append ($store_path) ralph.($name).note --meta '{\"type\":\"blocked\",\"iteration\":($iteration)}'

# Add remaining note
echo \"Task description\" | xs append ($store_path) ralph.($name).note --meta '{\"type\":\"remaining\"}'

# Clear in_progress \(mark complete or move to blocked before commit\)

## Instructions
1. STUDY the spec file
2. Query ralph.($name).note topic for current state
3. Pick ONE pending task, complete it
4. Append notes for your changes \(completed, blocked, remaining\)
5. Ensure no in_progress notes remain before commit
6. Git commit with clear message
7. If ALL tasks done: pkill -P ($pid)

## Rules
- ONE task per iteration
- Run tests before commit
- Document blockers in ralph.($name).note with type \"blocked\"
- Keep remaining tasks updated with type \"remaining\"
"
  
  return $template
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
  
  # Helper to cleanup all jobs
  def cleanup-all [] {
    let jobs = (job list | get id)
    if ($jobs | is-not-empty) {
      cleanup $jobs
    }
  }
  
  # Run main logic with cleanup handling
  try {
    # Start xs store
    let store_job_id = (start-store $store)
    
    # Start opencode web
    let web_result = (start-web $port)
    print $"Web UI: ($web_result.url)"
    
    # Read spec file
    let spec_content = (open $spec)
    
    # Get parent PID for termination instruction
    let parent_pid = $nu.pid
    
    # Main iteration loop
    mut n = 1
    loop {
      print $"\n($name) - Iteration #($n)..."
      
      # Build prompt for this iteration
      let iteration_prompt = (build-prompt $spec_content $store $name $parent_pid $n)
      
      # Use custom prompt if provided, otherwise use built template
      let final_prompt = if ($prompt | is-not-empty) { $prompt } else { $iteration_prompt }
      
      # Log iteration start
      log-iteration-start $store $name $n
      
      # Run opencode attached to web server
      let opencode_result = (
        opencode run --attach $web_result.url --title $"($name) - Iteration #($n)" $final_prompt
        | complete
      )
      
      # Determine status based on exit code
      let status = if $opencode_result.exit_code == 0 { "success" } else { "failure" }
      
      # Log iteration complete
      log-iteration-complete $store $name $n $status
      
      print "Done!"
      
      # Increment counter
      $n += 1
      
      # Check iteration limit (0 = infinite)
      if $iterations > 0 and $n > $iterations {
        print $"\nCompleted ($iterations) iterations. Exiting."
        break
      }
    }
    
  } catch { |err|
    print $"\nError occurred: ($err.msg)"
    cleanup-all
    error make {msg: $err.msg}
  }
  
  # Normal cleanup on success or Ctrl+C
  cleanup-all
}
