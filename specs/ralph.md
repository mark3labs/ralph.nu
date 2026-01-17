# ralph.nu - Iterative AI Coding Assistant

## Overview

Enhanced iterative AI coding assistant that:
- Runs opencode web as background job
- Attaches opencode instances to running server per iteration
- Persists notes/state via xs event stream instead of markdown file
- Provides real-time visibility into iteration progress

## User Story

Developer wants autonomous AI coding iterations with:
- Web UI for monitoring all sessions
- Persistent, queryable state (not flat files)
- Session continuity across iterations
- Clean process management

## Requirements

### Background Web Server
- Start `opencode web --port <port>` as nushell background job via `job spawn`
- Capture assigned port (use fixed port like 4096 for simplicity)
- Server persists across all iterations
- Cleanup on script exit via `job kill`

### Iteration Loop with Attach
- Each iteration runs: `opencode run --attach http://localhost:<port> --title "Iteration #N" <prompt>`
- Titles allow identifying iterations in web UI
- Server handles session management; client just attaches

### xs Event Store for State
- Store location: `<cwd>/.ralph/store`
- Start `xs serve <store-path>` as background job if not running
- Use full `xs` CLI commands (not xs.nu helpers)

### Event Topics

Topics are namespaced by session name: `ralph.<name>.<type>`

**ralph.\<name\>.iteration** - iteration lifecycle events
```
# start (where name = "auth-feature")
echo "" | xs append ./.ralph/store ralph.auth-feature.iteration --meta '{"action":"start","n":1}'

# complete  
echo "" | xs append ./.ralph/store ralph.auth-feature.iteration --meta '{"action":"complete","n":1,"status":"success"}'
```

**ralph.\<name\>.note** - persistent notes (replaces NOTES.md)
```
# add note
echo "Completed auth module" | xs append ./.ralph/store ralph.auth-feature.note --meta '{"type":"completed","iteration":1}'

# read current notes
xs cat ./.ralph/store | from json --objects | where topic == "ralph.auth-feature.note"
```



### Prompt Template Updates
- Remove references to notes markdown file
- Instruct AI to use xs commands for reading/writing state
- Provide xs command examples in prompt

### CLI Interface
```
ralph.nu [options]
  --name (-n): string       # REQUIRED - name for this ralph session
  --prompt (-p): string     # custom prompt
  --spec (-s): string       # spec file path (default: ./specs/SPEC.md)
  --model (-m): string      # model (default: anthropic/claude-sonnet-4-5)
  --iterations (-i): int    # iterations (0 = infinite)
  --port: int               # opencode web port (default: 4096)
  --store: string           # xs store path (default: ./.ralph/store)
```

## Technical Implementation

### Initialization Sequence
1. Create store dir: `mkdir -p ./.ralph/store`
2. Start xs serve: `job spawn { xs serve ./.ralph/store }`
3. Start opencode web: `job spawn { opencode web --port 4096 }`
4. Wait for servers: poll until responsive (xs version, curl)

### Iteration Loop
```nushell
mut n = 1
let topic_prefix = $"ralph.($name)"
loop {
  # log iteration start
  let meta = {action: "start", n: $n} | to json -r
  echo "" | xs append $store $"($topic_prefix).iteration" --meta $meta
  
  # run opencode attached to server
  opencode run --attach $"http://localhost:($port)" --title $"($name) - Iteration #($n)" $prompt
  
  # log iteration complete
  let meta = {action: "complete", n: $n} | to json -r
  echo "" | xs append $store $"($topic_prefix).iteration" --meta $meta
  
  $n += 1
  if $iterations > 0 and $n > $iterations { break }
}
```

### Cleanup Handler
```nushell
def cleanup [] {
  job list | each { job kill $in.id }
}
```

### Updated Prompt Template
```
## Context
- Spec: {spec}
- Store: {store} (use xs CLI for state)
- Topic prefix: ralph.{name}

## State Commands (xs CLI)
# Read all notes with content
xs cat {store} | from json --objects | where topic == "ralph.{name}.note" | each { |frame| 
  {type: $frame.meta.type, content: (xs cas {store} $frame.hash)} 
}

# Add completed note  
echo "Task description" | xs append {store} ralph.{name}.note --meta '{"type":"completed","iteration":N}'

# Add in_progress note
echo "Current task" | xs append {store} ralph.{name}.note --meta '{"type":"in_progress","iteration":N}'

# Add blocked note
echo "Blocker description" | xs append {store} ralph.{name}.note --meta '{"type":"blocked","iteration":N}'

# Add remaining note
echo "Task description" | xs append {store} ralph.{name}.note --meta '{"type":"remaining"}'

# Clear in_progress (mark complete or move to blocked before commit)

## Instructions
1. STUDY the spec file
2. Query ralph.{name}.note topic for current state
3. Pick ONE pending task, complete it
4. Append notes for your changes (completed, blocked, remaining)
5. Ensure no in_progress notes remain before commit
6. Git commit with clear message
7. If ALL tasks done: pkill -P {pid}

## Rules
- ONE task per iteration
- Run tests before commit
- Document blockers in ralph.{name}.note with type "blocked"
- Keep remaining tasks updated with type "remaining"
```

### Aggregating Notes for Display (internal use)
```nushell
# get current note state using xs CLI (where name = "auth-feature")
xs cat ./.ralph/store | from json --objects | where topic == "ralph.auth-feature.note" | each {|frame|
  let content = (xs cas ./.ralph/store $frame.hash)
  {
    type: $frame.meta.type
    iteration: ($frame.meta.iteration? | default "")
    content: $content
  }
} | group-by type
```

## UI Mockup

```
$ ralph.nu -n "auth-feature" -s ./specs/feature.md -i 5

Starting xs store at ./.ralph/store...
Starting opencode web on port 4096...
Web UI: http://localhost:4096

auth-feature - Iteration #1...
  [opencode output]
Done!

auth-feature - Iteration #2...
  [opencode output]
Done!

^C
Cleaning up background jobs...
```

## Out of Scope (v1)
- Web dashboard for ralph-specific state (use opencode web UI)
- Resume from specific iteration
- Parallel iterations
- Remote xs stores
- Custom event handlers/generators

## Tasks

### 1. Create basic script skeleton
- [ ] Create `ralph.nu` with shebang and main function signature
- [ ] Add CLI flags: --name (required), --prompt, --spec, --model, --iterations, --port, --store
- [ ] Add default values matching spec

### 2. Implement xs store management
- [ ] Create `start-store` function: mkdir -p, job spawn xs serve
- [ ] Return store path for $env.XS_ADDR
- [ ] Add wait/poll loop until store responds (xs version)

### 3. Implement opencode web management  
- [ ] Create `start-web` function: job spawn opencode web --port
- [ ] Add wait/poll loop until web responds (curl localhost:port)
- [ ] Return server URL for --attach

### 4. Implement cleanup handler
- [ ] Create `cleanup` function to kill all spawned jobs
- [ ] Track job IDs from spawn calls
- [ ] Wire into try/catch for interrupt handling

### 5. Implement iteration logging
- [ ] Create `log-iteration-start` function: xs append ralph.iteration
- [ ] Create `log-iteration-complete` function: xs append ralph.iteration  
- [ ] Include iteration number and timestamp in meta

### 6. Build prompt template
- [ ] Create prompt string with {spec}, {store}, {pid} placeholders
- [ ] Include xs CLI examples for note CRUD
- [ ] Include note type categories (completed, in_progress, blocked, remaining)
- [ ] Include termination instruction (pkill -P {pid})

### 7. Implement main iteration loop
- [ ] Initialize servers (store, web)
- [ ] Loop with iteration counter
- [ ] Call opencode run --attach --title "Iteration #N"
- [ ] Log iteration start/complete
- [ ] Handle --iterations limit (0 = infinite)

### 8. Wire everything together
- [ ] Main function orchestrates: init -> loop -> cleanup
- [ ] Substitute placeholders in prompt template
- [ ] Handle piped input vs --prompt flag vs default

### 9. Add status display helpers
- [ ] Create `show-notes` function: aggregate ralph.note by type
- [ ] Create `show-iterations` function: list ralph.iteration events
- [ ] Optional: call on startup to show current state

### 10. Testing and polish
- [ ] Test with simple spec file
- [ ] Verify web UI shows titled sessions
- [ ] Verify notes persist across runs
- [ ] Verify cleanup on Ctrl+C

## Design Decisions
- **xs serve**: Ralph always starts its own xs serve for isolation
- **AI state access**: AI uses xs CLI directly (not xs.nu module) for portability
- **Note categories**: completed, in_progress, blocked, remaining (same as original)
- **Sessions**: Fresh opencode session each iteration (new title, no --continue)
- **Startup sync**: Simple sleep or poll until servers respond

## Open Questions
- None currently
