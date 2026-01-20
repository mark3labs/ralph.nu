# Message Subcommand for ralph.nu

## Overview

Add `ralph.nu message` subcommand to send messages to a running ralph session's inbox. Agent checks inbox at loop start, processes messages, marks as read.

Also restructure CLI: `main` shows usage only (no side effects), `main build` runs the agent loop.

## User Story

User wants to communicate with running agent mid-session. Send guidance, corrections, or new info without restarting. Agent sees messages immediately at next iteration start.

## Requirements

### CLI Structure Change
- `./ralph.nu` (bare) - Shows usage/help only. No cleanup_all, no kill servers, no side effects.
- `./ralph.nu build [flags]` - Runs agent loop (current `main` behavior: cleanup, start servers, iterate)
- All existing flags (`--name`, `--spec`, `--model`, etc.) move to `main build`

### CLI Interface
- `ralph.nu message --name <session> <message>`
- `--name` flag required, identifies target session
- Message string required, appended to `.inbox` topic
- No message length limit
- Only validates store is running (allows messages for future sessions)
- No sender tracking (assume human operator)

### Inbox Topic Structure
- Topic: `ralph.<name>.inbox`
- Content: message text
- Meta: `{status: "unread", timestamp: <iso8601>}`

### Agent Behavior
- ALWAYS check inbox at iteration start (before task work)
- Unread messages auto-injected into prompt (not agent-initiated)
- All unread messages shown at once (batched)
- Process message content (may influence task selection)
- Mark messages as read after processing
- Messages persist across session restarts (stored in xs)

### Message Read Workflow
- Agent calls `inbox_mark_read(id)` tool after processing
- Status change: append frame with `{action: "mark_read", id: <id>}`
- Reduce pattern same as tasks: compute current state from log

### New Tools for Agent
- `inbox_list(session_name)` - Get unread inbox messages
- `inbox_mark_read(session_name, id)` - Mark message as read

## Technical Implementation

### CLI Subcommand
```nushell
def "main message" [
  message: string           # Message to send
  --name (-n): string       # Session name (required)
] {
  if ($name | is-empty) {
    error make {msg: "--name flag required"}
  }
  
  let store = ".ralph/store"
  # Verify store is running
  let check = (xs version $store | complete)
  if $check.exit_code != 0 {
    error make {msg: "Store not running. Is session active?"}
  }
  
  let topic = $"ralph.($name).inbox"
  let meta = {status: "unread", timestamp: (date now | format date "%Y-%m-%dT%H:%M:%S%z")} | to json -r
  
  let result = (echo $message | xs append $store $topic --meta $meta)
  print $"Message sent: ($result)"
}
```

### Inbox State Functions
```nushell
# Get inbox state (unread messages)
def get-inbox-state [store_path: string, name: string] {
  let topic = $"ralph.($name).inbox"
  let frames = (xs cat $store_path | from json --objects | where topic == $topic)
  
  if ($frames | is-empty) { return [] }
  
  # Reduce to compute read status
  let messages = ($frames | reduce -f {} {|frame, state|
    let action = ($frame.meta.action? | default "add")
    
    match $action {
      "add" | _ if ($frame.meta.status? == "unread") => {
        let content = (xs cas $store_path $frame.hash)
        $state | upsert $frame.id {
          id: $frame.id
          content: $content
          status: "unread"
          timestamp: ($frame.meta.timestamp? | default "")
        }
      }
      "mark_read" => {
        let target = $frame.meta.id
        let matching = ($state | columns | where {|id| $id == $target or ($id | str starts-with $target)} | first | default null)
        if ($matching | is-not-empty) {
          $state | upsert $matching {|m| $m | get $matching | upsert status "read"}
        } else { $state }
      }
      _ => $state
    }
  })
  
  # Return only unread
  $messages | values | where status == "unread"
}

# Format inbox for prompt
def format-inbox-for-prompt [messages: list] {
  if ($messages | is-empty) { return "" }
  
  mut lines = ["## INBOX (Unread Messages - Process these first!)"]
  for msg in $messages {
    $lines = ($lines | append $"- [($msg.id | str substring 0..8)] ($msg.timestamp): ($msg.content)")
  }
  $lines = ($lines | append "")
  $lines = ($lines | append "After reading, call inbox_mark_read(session_name, id) for each message.")
  $lines | str join "\n"
}
```

### Tool Additions (ralph.ts)
```typescript
export const inbox_list = tool({
  description: "Get unread inbox messages. Check this at start of each iteration.",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    const topic = `ralph.${session}.inbox`
    const cmd = `...` // reduce logic for inbox state
    const result = await Bun.$`nu -c ${cmd}`.text()
    return result.trim() || "No unread messages"
  },
})

export const inbox_mark_read = tool({
  description: "Mark an inbox message as read after processing",
  args: {
    session_name: tool.schema.string().describe("Session name from Context section"),
    id: tool.schema.string().describe("Message ID from inbox_list"),
  },
  async execute(args) {
    const session = args.session_name
    if (!session?.trim()) return "ERROR: session_name required"
    const topic = `ralph.${session}.inbox`
    const meta = JSON.stringify({ action: "mark_read", id: args.id })
    await Bun.$`xs append ${STORE} ${topic} --meta ${meta}`.text()
    return `Message ${args.id} marked as read`
  },
})
```

### Prompt Template Updates
Add inbox section BEFORE task state:
```
## INBOX
{inbox_messages}

## Context
...
```

Update instructions:
```
## Instructions
1. Check inbox for messages - process any unread messages first
2. Mark processed messages as read with inbox_mark_read()
3. Pick ONE task from REMAINING or IN PROGRESS
...
```

## Tasks

### 1. Restructure CLI commands
- [ ] Rename `def main` to `def "main build"` (keeps all existing flags/logic)
- [ ] Create new `def main` that only shows usage (print-banner + help text, no side effects)
- [ ] Verify `./ralph.nu` shows help without triggering cleanup_all or kill-existing
- [ ] Verify `./ralph.nu build --spec ./specs/foo.md` runs agent loop as before

### 2. Add message subcommand
- [ ] Add `def "main message"` function
- [ ] Validate --name flag required
- [ ] Check store is running
- [ ] Append message to .inbox topic with unread status

### 3. Implement inbox state functions
- [ ] Add `get-inbox-state` function (reduce pattern)
- [ ] Add `format-inbox-for-prompt` function
- [ ] Filter to only return unread messages

### 4. Add inbox_list tool
- [ ] Args: session_name
- [ ] Return unread messages with IDs
- [ ] Use reduce pattern for state computation

### 5. Add inbox_mark_read tool
- [ ] Args: session_name, id
- [ ] Append mark_read action frame
- [ ] Return confirmation

### 6. Update build-prompt function
- [ ] Get inbox state at iteration start
- [ ] Inject inbox section before task state
- [ ] Only show unread messages

### 7. Update prompt template instructions
- [ ] Add "check inbox first" instruction
- [ ] Document inbox_list and inbox_mark_read tools
- [ ] Emphasize processing messages before tasks

### 8. Test message flow
- [ ] Send message to running session
- [ ] Verify message appears in agent prompt
- [ ] Verify mark_read removes from unread list

## UI Mockup

CLI usage:
```
$ ./ralph.nu
# Shows usage/help only, no side effects

$ ./ralph.nu build --spec ./specs/my-feature.md
# Starts agent loop (current behavior)

$ ralph.nu message --name my-session "Please prioritize the login feature"
Message sent: 01jf...

# Agent sees in prompt:
## INBOX (Unread Messages - Process these first!)
- [01jf1234] 2025-01-20T10:30:00-0800: Please prioritize the login feature

After reading, call inbox_mark_read(session_name, id) for each message.
```

## Out of Scope (v1)
- Message history / read messages retrieval
- Message priority levels
- Attachments / file references
- Message acknowledgment confirmation to sender
- Real-time notification (only checked at iteration start)

## Open Questions
None - all clarified.
