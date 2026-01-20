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

# Kill processes matching a pattern (helper to reduce duplication)
def kill-matching [
  pattern: string     # Pattern to match with pgrep/pkill -f
  description: string # Human-readable description for status message
] {
  let result = (pgrep -f $pattern | complete)
  if $result.exit_code == 0 and ($result.stdout | str trim | is-not-empty) {
    print-status $"Killing existing ($description)..."
    pkill -f $pattern
    sleep 100ms
  }
}

# Poll until condition is met or timeout (generic retry helper)
# Returns: result from check_fn on success, or null on timeout
def poll-until [
  check_fn: closure   # Closure that returns {ok: bool, value: any}
  --attempts: int = 30
  --delay: duration = 100ms
  --error-msg: string = "Operation timed out"
] {
  for attempt in 0..($attempts) {
    let result = (do $check_fn)
    if $result.ok { return $result.value }
    sleep $delay
  }
  error make {msg: $error_msg}
}

# Kill any existing processes for this session
def kill-existing [
  store_path: string  # Path to the store directory
  port: int           # Web server port
] {
  kill-matching $"xs serve ($store_path)" $"xs serve for (style value)($store_path)(style reset)"
  kill-matching $"opencode serve --port ($port)" $"opencode serve on port (style value)($port)(style reset)"
  kill-matching $"ngrok http ($port)" $"ngrok on port (style value)($port)(style reset)"
}

# Start xs store server as background job
def start-store [
  store_path: string  # Path to the store directory
] {
  mkdir $store_path
  print-status $"Starting xs store at (style value)($store_path)(style reset)..."
  
  let job_id = (job spawn { xs serve $store_path })
  
  poll-until {|| 
    let r = (xs version $store_path | complete)
    {ok: ($r.exit_code == 0), value: $job_id}
  } --error-msg "xs store failed to start after 3 seconds"
  
  print-ok "xs store is ready"
  $job_id
}

# Start opencode serve server as background job
def start-web [
  port: int  # Port for the web server
] {
  print-status $"Starting opencode serve on port (style value)($port)(style reset)..."
  
  let job_id = (job spawn { opencode serve --port $port })
  let url = $"http://localhost:($port)"
  
  poll-until {||
    let r = (curl -s -o /dev/null -w "%{http_code}" $url | complete)
    {ok: ($r.exit_code == 0 and ($r.stdout | into int) < 500), value: {job_id: $job_id, url: $url}}
  } --error-msg "opencode serve failed to start after 3 seconds"
  
  print-ok $"opencode serve ready at (style url)($url)(style reset)"
  {job_id: $job_id, url: $url}
}

# Start ngrok tunnel as background job
def start-ngrok [
  port: int           # Local port to forward
  password: string    # Basic auth password
  domain?: string     # Optional custom domain
] {
  let pw_len = ($password | str length)
  if $pw_len < 8 or $pw_len > 128 {
    error make {msg: $"ngrok password must be 8-128 characters, got ($pw_len)"}
  }
  
  print-status "Starting ngrok tunnel..."
  
  let auth = $"ralph:($password)"
  let port_str = ($port | into string)
  let job_id = if ($domain | is-not-empty) {
    job spawn { ngrok http $port_str --basic-auth $auth --domain $domain }
  } else {
    job spawn { ngrok http $port_str --basic-auth $auth }
  }
  
  let result = (poll-until {||
    try {
      let response = (http get http://localhost:4040/api/tunnels)
      let tunnels = ($response.tunnels? | default [])
      if ($tunnels | is-not-empty) {
        {ok: true, value: {job_id: $job_id, url: $tunnels.0.public_url}}
      } else {
        {ok: false, value: null}
      }
    } catch {
      {ok: false, value: null}
    }
  } --delay 500ms --error-msg "ngrok failed to start after 15 seconds")
  
  print-ok "ngrok tunnel ready"
  print $"     (style url)($result.url)(style reset)"
  print $"     (style dim)auth: (style warn)ralph:($password)(style reset)"
  $result
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

# Cleanup all currently running jobs
def cleanup-all [] {
  let jobs = (job list | get id)
  if ($jobs | is-not-empty) {
    cleanup $jobs
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
        # Status change: update existing task by ID (supports prefix matching)
        let target_id = $frame.meta.id
        let new_status = $frame.meta.status
        let iteration = ($frame.meta.iteration? | default null)
        # Find task by exact match or prefix (8+ chars)
        let matching_id = ($state | columns | where {|id| $id == $target_id or ($id | str starts-with $target_id)} | first | default null)
        if ($matching_id | is-not-empty) {
          $state | upsert $matching_id {|task|
            $task | get $matching_id | upsert status $new_status | upsert iteration $iteration
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

# Note type ordering and colors
const NOTE_TYPES = ["stuck", "learning", "tip", "decision"]
const NOTE_COLORS = {stuck: "red", learning: "green", tip: "cyan", decision: "yellow"}

# Format notes for prompt injection
# Only shows notes from previous iterations (not current)
def format-notes-for-prompt [notes: list, current_iteration: int] {
  let prev_notes = ($notes | where {|n| 
    $n.iteration != null and $n.iteration < $current_iteration
  })
  if ($prev_notes | is-empty) { return "" }
  
  let grouped = ($prev_notes | group-by type)
  mut lines = ["## Notes from Previous Iterations"]
  
  for type in $NOTE_TYPES {
    let type_notes = ($grouped | get -o $type | default [])
    if ($type_notes | length) > 0 {
      $lines = ($lines | append $"($type | str upcase):")
      for note in $type_notes {
        $lines = ($lines | append $"  - [#($note.iteration)] ($note.content)")
      }
    }
  }
  $lines | str join "\n"
}

# Show session notes grouped by type
def show-session-notes [
  store_path: string  # Path to the store directory
  name: string        # Session name
] {
  let notes = (get-note-state $store_path $name)
  if ($notes | is-empty) { return }
  
  let grouped = ($notes | group-by type)
  print $"\n(style section)SESSION NOTES(style reset)"
  
  for type in $NOTE_TYPES {
    let type_notes = ($grouped | get -o $type | default [])
    if ($type_notes | length) > 0 {
      let color = ($NOTE_COLORS | get $type)
      print $"\n(ansi $color)($type | str upcase)(ansi reset)"
      for note in $type_notes {
        let iter = if ($note.iteration != null) { $"[#($note.iteration)]" } else { "" }
        print $"  ($iter) ($note.content)"
      }
    }
  }
}

# Show tasks using computed task state (ID-based, reduce pattern)
def show-tasks [
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
  
  for category in ["in_progress", "blocked", "remaining"] {
    let tasks = ($state | get $category)
    if ($tasks | length) > 0 {
      $lines = ($lines | append $"($category | str upcase | str replace '_' ' '):")
      for task in $tasks {
        $lines = ($lines | append $"  - [($task.id)] ($task.content)")
      }
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
  --force             # Overwrite existing tools
] {
  let tool_path = ".opencode/tool/ralph.ts"
  
  # Skip if tools exist and not forcing regeneration
  if (not $force) and ($tool_path | path exists) {
    return
  }
  
  # Create tool directory
  mkdir .opencode/tool
  
  # Build TypeScript content
  # STORE uses absolute path resolved at tool load time
  # All tools take session_name as argument - agent gets it from prompt context
  let content = '
import { tool } from "@opencode-ai/plugin"
import { resolve, dirname } from "path"

// Resolve absolute path to store - tools run from .opencode/tool/ so we go up 2 levels
const STORE = resolve(dirname(import.meta.path), "../../.ralph/store")

// Retry helper with exponential backoff
async function withRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  let lastError: Error | null = null
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn()
    } catch (e) {
      lastError = e as Error
      if (i < maxRetries - 1) {
        await new Promise(r => setTimeout(r, 100 * Math.pow(2, i)))
      }
    }
  }
  throw lastError
}

// Get current iteration from store
async function getCurrentIteration(session: string): Promise<number> {
  const cmd = `xs cat ${STORE} | from json --objects | where topic == "ralph.${session}.iteration" | where {|f| $f.meta.action? == "start"} | last | get meta.n`
  try {
    const result = await Bun.$`nu -c ${cmd}`.text()
    return parseInt(result.trim()) || 1
  } catch {
    return 1
  }
}

export const task_add = tool({
  description: "Add a new task to the ralph session task list",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
    content: tool.schema.string().describe("Task description"),
    status: tool.schema.enum(["remaining", "blocked"]).default("remaining").describe("Initial status"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    const topic = `ralph.${session}.task`
    try {
      const meta = JSON.stringify({ action: "add", status: args.status })
      const result = await withRetry(async () => {
        return await Bun.$`echo ${args.content} | xs append ${STORE} ${topic} --meta ${meta}`.text()
      })
      return result.trim()
    } catch (e) {
      return `ERROR: ${(e as Error).message}`
    }
  },
})

export const task_status = tool({
  description: "Update a task status by ID. Use IDs from task_list output.",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
    id: tool.schema.string().describe("Task ID (full or 8+ char prefix)"),
    status: tool.schema.enum(["in_progress", "completed", "blocked"]).describe("New status"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    const topic = `ralph.${session}.task`
    try {
      const iteration = await getCurrentIteration(session)
      const meta = JSON.stringify({ action: "status", id: args.id, status: args.status, iteration })
      await withRetry(async () => {
        await Bun.$`xs append ${STORE} ${topic} --meta ${meta}`.text()
      })
      return `Task ${args.id} marked as ${args.status}`
    } catch (e) {
      return `ERROR: ${(e as Error).message}`
    }
  },
})

export const task_list = tool({
  description: "Get current task list grouped by status. Shows task IDs needed for task_status.",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    const topic = `ralph.${session}.task`
    const cmd = `
      let topic = "${topic}"
      let frames = (xs cat ${STORE} | from json --objects | where topic == $topic)
      
      if ($frames | is-empty) {
        "No tasks yet"
      } else {
        let tasks = ($frames | reduce -f {} {|frame, state|
          let action = ($frame.meta.action? | default "add")
          
          if $action == "add" {
            let content = (xs cas ${STORE} $frame.hash)
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
            # Find task by exact match or prefix (8+ chars)
            let matching_id = ($state | columns | where {|id| $id == $target_id or ($id | str starts-with $target_id)} | first | default null)
            if ($matching_id | is-not-empty) {
              $state | upsert $matching_id {|task|
                $task | get $matching_id | upsert status $new_status | upsert iteration $iteration
              }
            } else {
              $state
            }
          } else {
            $state
          }
        })
        
        let task_list = ($tasks | values)
        let grouped = if ($task_list | is-empty) { {} } else { $task_list | group-by status }
        
        {
          completed: ($grouped | get -o completed | default [])
          in_progress: ($grouped | get -o in_progress | default [])
          blocked: ($grouped | get -o blocked | default [])
          remaining: ($grouped | get -o remaining | default [])
        } | to json
      }
    `
    const result = await Bun.$`nu -c ${cmd}`.text()
    return result.trim() || "No tasks yet"
  },
})

export const session_complete = tool({
  description: "Signal that ALL tasks are complete and terminate the ralph session. Only call when every task is done.",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    
    try {
      // Write timestamp-based marker - ralph.nu will check for any session_complete frame
      const ts = Date.now()
      const meta = JSON.stringify({ action: "session_complete", ts })
      const topic = `ralph.${session}.control`
      const result = await withRetry(async () => {
        return await Bun.$`echo "complete" | xs append ${STORE} ${topic} --meta ${meta}`.text()
      })
      return `Session "${session}" marked complete (ts=${ts}, store=${STORE}, result=${result.slice(0,50)}...)`
    } catch (e) {
      return `ERROR: ${(e as Error).message} (store=${STORE})`
    }
  },
})

export const note_add = tool({
  description: "Add a note for future iterations (learnings, tips, blockers, decisions)",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
    content: tool.schema.string().describe("Note content"),
    type: tool.schema.enum(["learning", "stuck", "tip", "decision"]).describe("Note category"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    try {
      const iteration = await getCurrentIteration(session)
      const meta = JSON.stringify({ action: "add", type: args.type, iteration })
      const topic = `ralph.${session}.note`
      await withRetry(async () => {
        await Bun.$`echo ${args.content} | xs append ${STORE} ${topic} --meta ${meta}`.text()
      })
      const preview = args.content.length > 50 ? args.content.slice(0, 50) + "..." : args.content
      return `Note added: [${args.type}] ${preview}`
    } catch (e) {
      return `ERROR: ${(e as Error).message}`
    }
  },
})

export const note_list = tool({
  description: "List notes from this session",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
    type: tool.schema.enum(["learning", "stuck", "tip", "decision"]).optional().describe("Filter by type"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    const typeFilter = args.type ? `| where {|n| $n.type == "${args.type}"}` : ""
    const topic = `ralph.${session}.note`
    const cmd = `
      xs cat ${STORE} | from json --objects | where topic == "${topic}" | each {|f|
        {
          id: $f.id
          type: ($f.meta.type? | default "note")
          iteration: ($f.meta.iteration? | default null)
          content: (xs cas ${STORE} $f.hash)
        }
      } ${typeFilter} | to json
    `
    const result = await Bun.$`nu -c ${cmd}`.text()
    return result.trim() || "No notes yet"
  },
})
'
  
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
  
  # Get notes and format for prompt
  let notes = (get-note-state $store_path $name)
  let notes_section = (format-notes-for-prompt $notes $iteration)
  
  let template = $"## Context
- Session: ($name)
- Spec: ($spec_content)
- Iteration: #($iteration)

($notes_section)

## Current Task State
($state_text)

## Available Tools
ALL tools require session_name=\"($name)\" as the first argument.
- task_add\(session_name, content, status?\) - Add new task
- task_status\(session_name, id, status\) - Update task \(use IDs from list above\)
- task_list\(session_name\) - Refresh task list
- session_complete\(session_name\) - Call when ALL tasks done
- note_add\(session_name, content, type\) - Record learning/tip/blocker/decision for future iterations
- note_list\(session_name, type?\) - View session notes

## Instructions
1. Make sure ALL tasks from the spec appear in the task list. If some are missing add them.
2. Pick ONE task from REMAINING or IN PROGRESS
3. Call task_status\(\"($name)\", id, \"in_progress\"\)
4. Complete the work
5. Call task_status\(\"($name)\", id, \"completed\"\)
6. Git commit with clear message
7. If stuck or learned something important: call note_add\(\)
8. If ALL tasks in the spec are done: call session_complete\(\"($name)\"\)

## Rules
- ONE task per iteration
- Run tests before commit
- To end the session, call session_complete\(\"($name)\"\). Do NOT just print a message.
"
  
  return $template
}

# Main entry point - build subcommand runs the agent loop
def "main build" [
  input?: string                                            # Optional piped input for prompt
  --name (-n): string = ""                                  # Session name (defaults to spec filename without extension)
  --prompt (-p): string                                     # Custom prompt
  --spec (-s): string = "./specs/SPEC.md"                   # Spec file path
  --model (-m): string = "anthropic/claude-sonnet-4-5"      # Model to use
  --iterations (-i): int = 0                                # Number of iterations (0 = infinite)
  --port: int = 4096                                        # opencode serve port
  --ngrok: string = ""                                      # Enable ngrok tunnel with this password
  --ngrok-domain: string = ""                               # Custom ngrok domain (optional)
  --regen-tools                                             # Regenerate tool definitions (overwrites existing)
] {
  # Store path is always relative to project root
  let store = ".ralph/store"
  # Exit early if being sourced (not executed directly)
  # When sourced from tests, $env.CURRENT_FILE will be the test file, not ralph.nu
  let current_file = ($env.CURRENT_FILE? | default "")
  if ($current_file | str contains "tests/") {
    return
  }
  
  # Derive name from spec filename if not provided
  let name = if ($name | is-empty) {
    $spec | path basename | path parse | get stem
  } else {
    $name
  }

  print-banner
  print ""
  print-kv "Session" $name
  print-kv "Store" $store
  print-kv "Port" ($port | into string)
  print ""
  
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
      show-session-notes $store $name
      show-tasks $store $name
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
      
      # Generate custom tools (skip if already exist, unless --regen-tools on first iteration)
      generate-tools --force=($regen_tools and $n == ($last_iter + 1))
      
      # Get current task state for this iteration
      let task_state = (get-task-state $store $name)
      
      # Build prompt for this iteration
      let iteration_prompt = (build-prompt $spec_content $store $name $n $task_state)
      
      # Use base_prompt if set, otherwise use built template
      let final_prompt = if ($base_prompt | is-not-empty) { $base_prompt } else { $iteration_prompt }
      
      # Log iteration start
      log-iteration-start $store $name $n
      
      # Run opencode attached to web server
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
      # Check for any session_complete frame created during this iteration (within last 5 minutes)
      let cutoff = ((date now) - 5min | format date "%s" | into int) * 1000
      let shutdown = (xs cat $store 
        | from json --objects 
        | where topic == $"ralph.($name).control"
        | where {|f| $f.meta.action? == "session_complete" }
        | where {|f| ($f.meta.ts? | default 0) > $cutoff }
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
