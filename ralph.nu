#!/usr/bin/env nu

# ralph.nu - AI coding agent in a while loop. Named after Ralph Wiggum from The Simpsons.

# ─────────────────────────────────────────────────────────────────────────────
# Styling helpers - consistent colored output throughout the script
# ─────────────────────────────────────────────────────────────────────────────

# Style definitions using ansi codes
def "style reset" [] { ansi reset }
def "style bold" [] { ansi attr_bold }
def "style dim" [] { ansi grey }
def "style header" [] { ansi cyan_bold }
def "style success" [] { ansi green_bold }
def "style error" [] { ansi red_bold }
def "style warn" [] { ansi yellow }
def "style info" [] { ansi blue }
def "style url" [] { ansi cyan_underline }
def "style label" [] { ansi white_dimmed }
def "style value" [] { ansi white_bold }
def "style section" [] { ansi magenta_bold }

# Print a styled header banner
def print-banner [] {
  print $"(style header)╭─────────────────────────────────────╮(style reset)"
  print $"(style header)│(style reset)              (style bold)ralph.nu(style reset)               (style header)│(style reset)"
  print $"(style header)│(style reset)      (style dim)AI agent in a while loop(style reset)       (style header)│(style reset)"
  print $"(style header)╰─────────────────────────────────────╯(style reset)"
}

# Print key-value info line
def print-kv [key: string, value: string] {
  print $"  (style label)($key):(style reset) (style value)($value)(style reset)"
}

# Print success message
def print-ok [msg: string] {
  print $"  (style success)✓(style reset) ($msg)"
}

# Print error message  
def print-err [msg: string] {
  print $"  (style error)✗(style reset) ($msg)"
}

# Print info/status message
def print-status [msg: string] {
  print $"  (style info)→(style reset) ($msg)"
}

# Print section header
def print-section [title: string] {
  print $"\n(style section)── ($title) ──(style reset)"
}

# ─────────────────────────────────────────────────────────────────────────────

# Kill any existing processes for this session
def kill-existing [
  store_path: string  # Path to the store directory
  port: int           # Web server port
] {
  # Kill any existing xs serve for this store
  let xs_pids = (pgrep -f $"xs serve ($store_path)" | complete)
  if $xs_pids.exit_code == 0 {
    let pids = ($xs_pids.stdout | str trim)
    if ($pids | is-not-empty) {
      print-status $"Killing existing xs serve for (style value)($store_path)(style reset)..."
      pkill -f $"xs serve ($store_path)"
      sleep 100ms
    }
  }
  
  # Kill any existing opencode serve on this port
  let web_pids = (pgrep -f $"opencode serve --port ($port)" | complete)
  if $web_pids.exit_code == 0 {
    let pids = ($web_pids.stdout | str trim)
    if ($pids | is-not-empty) {
      print-status $"Killing existing opencode serve on port (style value)($port)(style reset)..."
      pkill -f $"opencode serve --port ($port)"
      sleep 100ms
    }
  }
  
  # Kill any existing ngrok http on this port
  let ngrok_pids = (pgrep -f $"ngrok http ($port)" | complete)
  if $ngrok_pids.exit_code == 0 {
    let pids = ($ngrok_pids.stdout | str trim)
    if ($pids | is-not-empty) {
      print-status $"Killing existing ngrok on port (style value)($port)(style reset)..."
      pkill -f $"ngrok http ($port)"
      sleep 100ms
    }
  }
}

# Start xs store server as background job
def start-store [
  store_path: string  # Path to the store directory
] {
  # Create store directory if it doesn't exist
  mkdir $store_path
  
  print-status $"Starting xs store at (style value)($store_path)(style reset)..."
  
  # Start xs serve as background job and capture job ID
  let job_id = (job spawn { xs serve $store_path })
  
  # Wait for store to be ready (poll xs version)
  for attempt in 0..30 {
    let result = (xs version $store_path | complete)
    if $result.exit_code == 0 {
      print-ok "xs store is ready"
      return $job_id
    }
    sleep 100ms
  }
  
  # If we get here, store didn't start
  error make {msg: "xs store failed to start after 3 seconds"}
}

# Start opencode serve server as background job
def start-web [
  port: int  # Port for the web server
] {
  print-status $"Starting opencode serve on port (style value)($port)(style reset)..."
  
  # Start opencode serve as background job and capture job ID
  let job_id = (job spawn { opencode serve --port $port })
  
  # Wait for web server to be ready (poll with curl)
  for attempt in 0..30 {
    let result = (curl -s -o /dev/null -w "%{http_code}" $"http://localhost:($port)" | complete)
    if $result.exit_code == 0 and ($result.stdout | into int) < 500 {
      print-ok $"opencode serve ready at (style url)http://localhost:($port)(style reset)"
      return {job_id: $job_id, url: $"http://localhost:($port)"}
    }
    sleep 100ms
  }
  
  # If we get here, web server didn't start
  error make {msg: "opencode serve failed to start after 3 seconds"}
}

# Start ngrok tunnel as background job
def start-ngrok [
  port: int           # Local port to forward
  password: string    # Basic auth password
  domain?: string     # Optional custom domain
] {
  # Validate password length (ngrok requires 8-128 characters)
  let pw_len = ($password | str length)
  if $pw_len < 8 or $pw_len > 128 {
    error make {msg: $"ngrok password must be 8-128 characters, got ($pw_len)"}
  }
  
  print-status "Starting ngrok tunnel..."
  
  let auth = $"ralph:($password)"
  
  # Start ngrok as background job
  let port_str = ($port | into string)
  let job_id = if ($domain | is-not-empty) {
    job spawn { ngrok http $port_str --basic-auth $auth --domain $domain }
  } else {
    job spawn { ngrok http $port_str --basic-auth $auth }
  }
  
  # Poll ngrok API for public URL
  for attempt in 0..30 {
    try {
      let response = (http get http://localhost:4040/api/tunnels)
      if ($response.tunnels? | default [] | is-not-empty) {
        let url = $response.tunnels.0.public_url
        print-ok $"ngrok tunnel ready"
        print $"     (style url)($url)(style reset)"
        print $"     (style dim)auth: (style warn)ralph:($password)(style reset)"
        return {job_id: $job_id, url: $url}
      }
    } catch {
      # Request may fail if ngrok not ready yet
    }
    sleep 500ms
  }
  
  # If we get here, ngrok didn't start
  error make {msg: "ngrok failed to start after 15 seconds"}
}

# Cleanup function to kill all spawned jobs
def cleanup [
  job_ids: list<int>  # List of job IDs to kill
] {
  print $"\n(style dim)Cleaning up background jobs...(style reset)"
  
  for job_id in $job_ids {
    try {
      job kill $job_id
      print $"  (style dim)killed job ($job_id)(style reset)"
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
  
  echo "" | xs append $store_path $topic --meta $meta | ignore
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
  
  echo "" | xs append $store_path $topic --meta $meta | ignore
}

# Compute current task state from append-only log using reduce pattern
# Events: add (creates task), status (changes task status by ID)
# Returns record with tasks grouped by status
def get-task-state [
  store_path: string  # Path to the store directory
  name: string        # Session name
] {
  let topic = $"ralph.($name).task"
  
  # Get all frames from the topic
  let frames = (xs cat $store_path | from json --objects | where topic == $topic)
  
  if ($frames | is-empty) {
    return {completed: [], in_progress: [], blocked: [], remaining: []}
  }
  
  # Use reduce to build state machine - tasks keyed by ID
  let tasks = ($frames | reduce -f {} {|frame, state|
    let action = ($frame.meta.action? | default "add")
    
    match $action {
      "add" => {
        # New task: store content and initial status
        let content = (xs cas $store_path $frame.hash)
        let status = ($frame.meta.status? | default "remaining")
        let iteration = ($frame.meta.iteration? | default null)
        $state | upsert $frame.id {
          id: $frame.id
          content: $content
          status: $status
          iteration: $iteration
        }
      }
      "status" => {
        # Status change: update existing task by ID
        let target_id = $frame.meta.id
        let new_status = $frame.meta.status
        let iteration = ($frame.meta.iteration? | default null)
        if ($target_id in $state) {
          $state | upsert $target_id {|task|
            $task | get $target_id | upsert status $new_status | upsert iteration $iteration
          }
        } else {
          $state
        }
      }
      _ => $state
    }
  })
  
  # Convert from {id: task} record to grouped lists by status
  let task_list = ($tasks | values)
  let grouped = if ($task_list | is-empty) { {} } else { $task_list | group-by status }
  
  # Return with all categories (empty lists for missing)
  {
    completed: ($grouped | get -o completed | default [])
    in_progress: ($grouped | get -o in_progress | default [])
    blocked: ($grouped | get -o blocked | default [])
    remaining: ($grouped | get -o remaining | default [])
  }
}

# Get note state from append-only log
# Notes track learnings, tips, blockers, and decisions across iterations
def get-note-state [
  store_path: string  # Path to the store directory
  name: string        # Session name
] {
  let topic = $"ralph.($name).note"
  let frames = (xs cat $store_path | from json --objects | where topic == $topic)
  
  if ($frames | is-empty) { return [] }
  
  $frames | each {|frame|
    let content = (xs cas $store_path $frame.hash)
    {
      id: $frame.id
      type: ($frame.meta.type? | default "note")
      iteration: ($frame.meta.iteration? | default null)
      content: $content
    }
  }
}

# Show tasks using computed task state (ID-based, reduce pattern)
def show-notes [
  store_path: string  # Path to the store directory
  name: string        # Session name
] {
  let state = (get-task-state $store_path $name)
  
  # Check if any tasks exist
  let has_tasks = (
    ($state.completed | length) > 0 or
    ($state.in_progress | length) > 0 or
    ($state.blocked | length) > 0 or
    ($state.remaining | length) > 0
  )
  
  if not $has_tasks {
    return
  }
  
  # Category display config: [header_color, item_symbol, item_color]
  let category_styles = {
    completed: ["green_bold", "✓", "green"]
    in_progress: ["yellow_bold", "●", "yellow"]
    blocked: ["red_bold", "✗", "red"]
    remaining: ["white_dimmed", "○", "white_dimmed"]
  }
  
  # Display tasks by category
  for category in ["in_progress", "blocked", "remaining", "completed"] {
    let tasks = ($state | get $category)
    if ($tasks | length) > 0 {
      let style_info = ($category_styles | get $category)
      let header_style = ($style_info | get 0)
      let symbol = ($style_info | get 1)
      let item_style = ($style_info | get 2)
      
      print $"\n(ansi $header_style)($category | str upcase | str replace '_' ' ')(ansi reset)"
      $tasks | each {|task|
        let iter_label = if ($task.iteration != null) {
          $"(style dim)[#($task.iteration)](style reset) "
        } else {
          ""
        }
        let id_short = ($task.id | str substring 0..8)
        print $"  (ansi $item_style)($symbol)(ansi reset) (style dim)[($id_short)](style reset) ($iter_label)($task.content)"
      }
    }
  }
}

# Show iteration history from xs store
def show-iterations [
  store_path: string  # Path to the store directory
  name: string        # Session name
] {
  let topic = $"ralph.($name).iteration"
  
  # Get all iteration events
  let frames = (xs cat $store_path | from json --objects | where topic == $topic)
  
  if ($frames | is-empty) {
    return
  }
  
  # Extract and display iteration events
  let events = ($frames | each {|frame|
    {
      action: $frame.meta.action
      iteration: $frame.meta.n
      status: ($frame.meta.status? | default "")
      timestamp: $frame.meta.timestamp
    }
  })
  
  print $"\n(style section)HISTORY(style reset)"
  $events | each {|event|
    if $event.action == "start" {
      print $"  (style info)▶(style reset) (style dim)#($event.iteration)(style reset) started (style dim)($event.timestamp)(style reset)"
    } else if $event.action == "complete" {
      let status_style = if $event.status == "success" { style success } else { style error }
      let status_symbol = if $event.status == "success" { "✓" } else { "✗" }
      print $"  ($status_style)($status_symbol)(style reset) (style dim)#($event.iteration)(style reset) ($event.status) (style dim)($event.timestamp)(style reset)"
    }
  }
}

# Format task state as text for prompt injection (includes IDs for reference)
def format-task-state [state: record] {
  mut lines = []
  
  if ($state.in_progress | length) > 0 {
    $lines = ($lines | append "IN PROGRESS:")
    for task in $state.in_progress {
      $lines = ($lines | append $"  - [($task.id)] ($task.content)")
    }
  }
  
  if ($state.blocked | length) > 0 {
    $lines = ($lines | append "BLOCKED:")
    for task in $state.blocked {
      $lines = ($lines | append $"  - [($task.id)] ($task.content)")
    }
  }
  
  if ($state.remaining | length) > 0 {
    $lines = ($lines | append "REMAINING:")
    for task in $state.remaining {
      $lines = ($lines | append $"  - [($task.id)] ($task.content)")
    }
  }
  
  if ($state.completed | length) > 0 {
    $lines = ($lines | append $"COMPLETED: ($state.completed | length) tasks")
  }
  
  if ($lines | is-empty) {
    "No tasks yet - check spec for initial tasks"
  } else {
    $lines | str join "\n"
  }
}

# Generate custom tool definitions for opencode
def generate-tools [
  store_path: string  # Path to the store directory
  name: string        # Session name
  iteration: int      # Current iteration number
] {
  let abs_store = ($store_path | path expand)
  
  # Create tool directory
  mkdir .opencode/tool
  
  # Build TypeScript content using single quotes (no interpolation) + string concatenation
  let content = (
    'import { tool } from "@opencode-ai/plugin"

const STORE_PATH = "' + $abs_store + '"
const SESSION_NAME = "' + $name + '"
const ITERATION = ' + ($iteration | into string) + '
const TOPIC = `ralph.${SESSION_NAME}.task`

export const task_add = tool({
  description: "Add a new task to the ralph session task list",
  args: {
    content: tool.schema.string().describe("Task description"),
    status: tool.schema.enum(["remaining", "blocked"]).default("remaining").describe("Initial status"),
  },
  async execute(args) {
    const meta = JSON.stringify({ action: "add", status: args.status })
    const result = await Bun.$`echo ${args.content} | xs append ${STORE_PATH} ${TOPIC} --meta ${meta}`.text()
    return result.trim()
  },
})

export const task_status = tool({
  description: "Update a task status by ID. Use IDs from task_list output.",
  args: {
    id: tool.schema.string().describe("Task ID (full or 8+ char prefix)"),
    status: tool.schema.enum(["in_progress", "completed", "blocked"]).describe("New status"),
  },
  async execute(args) {
    const meta = JSON.stringify({ action: "status", id: args.id, status: args.status, iteration: ITERATION })
    const result = await Bun.$`xs append ${STORE_PATH} ${TOPIC} --meta ${meta}`.text()
    return `Task ${args.id} marked as ${args.status}`
  },
})

export const task_list = tool({
  description: "Get current task list grouped by status. Shows task IDs needed for task_status.",
  args: {},
  async execute() {
    // Use the same reduce-based state machine as get-task-state in ralph.nu
    const cmd = `
      let topic = "${TOPIC}"
      let frames = (xs cat ${STORE_PATH} | from json --objects | where topic == $topic)
      
      if ($frames | is-empty) {
        echo "No tasks yet"
        exit 0
      }
      
      # Build state machine using reduce
      let tasks = ($frames | reduce -f {} {|frame, state|
        let action = ($frame.meta.action? | default "add")
        
        if $action == "add" {
          let content = (xs cas ${STORE_PATH} $frame.hash)
          let status = ($frame.meta.status? | default "remaining")
          let iteration = ($frame.meta.iteration? | default null)
          $state | upsert $frame.id {
            id: $frame.id
            content: $content
            status: $status
            iteration: $iteration
          }
        } else if $action == "status" {
          let target_id = $frame.meta.id
          let new_status = $frame.meta.status
          let iteration = ($frame.meta.iteration? | default null)
          if ($target_id in $state) {
            $state | upsert $target_id {|task|
              $task | get $target_id | upsert status $new_status | upsert iteration $iteration
            }
          } else {
            $state
          }
        } else {
          $state
        }
      })
      
      # Convert to grouped lists
      let task_list = ($tasks | values)
      let grouped = if ($task_list | is-empty) { {} } else { $task_list | group-by status }
      
      # Return formatted output matching show-notes display
      let result = {
        completed: ($grouped | get -o completed | default [])
        in_progress: ($grouped | get -o in_progress | default [])
        blocked: ($grouped | get -o blocked | default [])
        remaining: ($grouped | get -o remaining | default [])
      }
      
      $result | to json
    `
    const result = await Bun.$`nu -c ${cmd}`.text()
    return result.trim() || "No tasks yet"
  },
})

export const session_complete = tool({
  description: "Signal that ALL tasks are complete and terminate the ralph session. Only call when every task is done.",
  args: {},
  async execute() {
    const meta = JSON.stringify({ action: "session_complete", iteration: ITERATION })
    await Bun.$`xs append ${STORE_PATH} ralph.${SESSION_NAME}.control --meta ${meta}`
    return "Session marked complete - will exit after this iteration"
  },
})
'
  )
  
  $content | save -f .opencode/tool/ralph.ts
}

# Build prompt template with task state injected
def build-prompt [
  spec_content: string  # Content of the spec file
  store_path: string    # Path to the store directory
  name: string          # Session name
  iteration: int        # Current iteration number
  task_state: record    # Current task state from get-task-state
] {
  let state_text = (format-task-state $task_state)
  
  let template = $"## Context
- Spec: ($spec_content)
- Iteration: #($iteration)

## Current Task State
($state_text)

## Available Tools
- task_add\(content, status?\) - Add new task
- task_status\(id, status\) - Update task \(use IDs from list above\)
- task_list\(\) - Refresh task list
- session_complete\(\) - Call when ALL tasks done

## Instructions
1. Make sure ALL tasks from the spec appear in the task list. If some are missing add them.
2. Pick ONE task from REMAINING or IN PROGRESS
3. Call task_status\(id, \"in_progress\"\)
4. Complete the work
5. Call task_status\(id, \"completed\"\)
6. Git commit with clear message
7. If ALL tasks in the spec are done: call session_complete\(\)

## Rules
- ONE task per iteration
- Run tests before commit
"
  
  return $template
}

# Main entry point
def main [
  input?: string                                            # Optional piped input for prompt
  --name (-n): string = ""                                  # REQUIRED - name for this ralph session
  --prompt (-p): string                                     # Custom prompt
  --spec (-s): string = "./specs/SPEC.md"                   # Spec file path
  --model (-m): string = "anthropic/claude-sonnet-4-5"      # Model to use
  --iterations (-i): int = 0                                # Number of iterations (0 = infinite)
  --port: int = 4096                                        # opencode serve port
  --store: string = "./.ralph/store"                        # xs store path
  --ngrok: string = ""                                      # Enable ngrok tunnel with this password
  --ngrok-domain: string = ""                               # Custom ngrok domain (optional)
] {
  # Validate required parameter
  if ($name | is-empty) {
    print-err "Missing required parameter: --name (-n)"
    print $"  (style dim)Usage: ralph.nu --name <session-name> [--spec <path>] [--iterations <n>](style reset)"
    exit 1
  }

  print-banner
  print ""
  print-kv "Session" $name
  print-kv "Store" $store
  print-kv "Port" ($port | into string)
  print ""
  
  # Helper to cleanup all jobs
  def cleanup-all [] {
    let jobs = (job list | get id)
    if ($jobs | is-not-empty) {
      cleanup $jobs
    }
  }
  
  # Run main logic with cleanup handling
  try {
    # Kill any existing processes from previous runs
    kill-existing $store $port
    
    # Start xs store
    let store_job_id = (start-store $store)
    
    # Start opencode serve
    let web_result = (start-web $port)
    
    # Start ngrok tunnel if requested
    mut ngrok_job_id = null
    if ($ngrok | is-not-empty) {
      let ngrok_result = (start-ngrok $port $ngrok $ngrok_domain)
      $ngrok_job_id = $ngrok_result.job_id
    }
    
    # Display current state (if any previous sessions exist)
    try {
      show-iterations $store $name
      show-notes $store $name
    } catch {
      # Store may not have any data yet - this is fine for first run
    }
    
    # Read spec file
    print-kv "Spec" $spec
    let spec_content = (open $spec)
    
    # Determine base prompt (priority: --prompt > piped input > default template)
    let base_prompt = if ($prompt | is-not-empty) {
      $prompt
    } else if ($input | is-not-empty) {
      $input
    } else {
      null
    }
    
    # Get last iteration from store to enable continuation
    let last_iter = try {
      let frames = (xs cat $store | from json --objects 
        | where topic == $"ralph.($name).iteration")
      if ($frames | is-empty) { 0 } else { $frames | get meta.n | math max }
    } catch { 0 }
    
    if $last_iter > 0 {
      print-status $"Continuing from iteration #($last_iter)"
    }
    
    # Capture session start ID for shutdown signal filtering
    let session_start_id = try {
      xs cat $store | from json --objects | last | get id
    } catch { "0" }
    
    # Main iteration loop
    mut n = $last_iter + 1
    loop {
      print $"\n(style header)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(style reset)"
      print $"(style header)  ($name)(style reset) (style dim)·(style reset) (style value)Iteration #($n)(style reset)"
      print $"(style header)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━(style reset)\n"
      
      # Generate custom tools for this iteration
      generate-tools $store $name $n
      
      # Get current task state for this iteration
      let task_state = (get-task-state $store $name)
      
      # Build prompt for this iteration
      let iteration_prompt = (build-prompt $spec_content $store $name $n $task_state)
      
      # Use base_prompt if set, otherwise use built template
      let final_prompt = if ($base_prompt | is-not-empty) { $base_prompt } else { $iteration_prompt }
      
      # Log iteration start
      log-iteration-start $store $name $n
      
      # Run opencode attached to web server (output streams to terminal)
      opencode run --attach $web_result.url --title $"($name) - Iteration #($n)" -m $model $final_prompt
      
      # Determine status based on exit code
      let status = if $env.LAST_EXIT_CODE == 0 { "success" } else { "failure" }
      
      # Log iteration complete
      log-iteration-complete $store $name $n $status
      
      if $status == "success" {
        print-ok $"Iteration #($n) complete"
      } else {
        print-err $"Iteration #($n) failed"
      }
      
      # Check for graceful shutdown signal (session_complete called by agent)
      let shutdown = (xs cat $store 
        | from json --objects 
        | where topic == $"ralph.($name).control"
        | where {|f| $f.meta.action? == "session_complete" }
        | where {|f| $f.id > $session_start_id }
        | is-not-empty)
      if $shutdown {
        print-ok "Session complete - all tasks done"
        break
      }
      
      # Increment counter
      $n += 1
      
      # Check iteration limit (0 = infinite)
      if $iterations > 0 and $n > $iterations {
        print $"\n(style dim)Completed ($iterations) iterations. Exiting.(style reset)"
        break
      }
    }
    
  } catch { |err|
    print-err $"($err.msg)"
    cleanup-all
    error make {msg: $err.msg}
  }
  
  # Normal cleanup on success or Ctrl+C
  cleanup-all
}
