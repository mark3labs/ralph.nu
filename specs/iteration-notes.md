# Iteration Notes for ralph.nu

## Overview

Persistent cross-iteration memory system. Agent writes notes (learnings, tips, blockers, decisions) that persist across iterations and sessions. Notes auto-injected into prompt so agent learns from previous attempts.

## User Story

Agent gets stuck on same issue repeatedly. With notes:
- Iteration 3: hits rate limit, writes `note_add("API rate limit is 100/min, need exponential backoff", "stuck")`
- Iteration 4: sees note in prompt, implements backoff correctly first try

## Requirements

### New Topic
`ralph.{name}.note` - append-only note log

Event schema:
```
action: "add"
type: "learning" | "stuck" | "tip" | "decision"  
iteration: number
content: <stored in CAS>
```

### Note Types
- **learning** - what worked, insights gained
- **stuck** - where blocked, what didn't work, dead ends
- **tip** - recommendations for future iterations
- **decision** - key choices made and rationale

### New Tools

**note_add** - Add note for future iterations
- Args: `content` (string), `type` (enum)
- Returns: confirmation with truncated preview

**note_list** - List all notes from session
- Args: `type?` (optional filter)
- Returns: notes grouped by type with iteration numbers

### Prompt Injection
Notes section added to prompt template between Context and Task State:
```
## Notes from Previous Iterations
STUCK:
  - [#3] API rate limit is 100/min - need exponential backoff
LEARNING:
  - [#2] Test suite requires --no-cache flag
DECISION:
  - [#1] Using SQLite over Postgres for simplicity
```

Only show notes from iterations < current (agent shouldn't see own notes mid-iteration).

### CLI Display
On startup, `show-session-notes` displays existing notes alongside iteration history.

## Technical Implementation

### State Function
```nushell
def get-note-state [store_path: string, name: string] {
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
```

### Format Function
```nushell
def format-notes-for-prompt [notes: list, current_iteration: int] {
  # Filter to notes from previous iterations only
  let prev_notes = ($notes | where {|n| 
    $n.iteration != null and $n.iteration < $current_iteration
  })
  
  if ($prev_notes | is-empty) { return "" }
  
  let grouped = ($prev_notes | group-by type)
  mut lines = ["## Notes from Previous Iterations"]
  
  for type in ["stuck", "learning", "tip", "decision"] {
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
```

### Tool Additions to generate-tools
```typescript
export const note_add = tool({
  description: "Add a note for future iterations (learnings, tips, blockers, decisions)",
  args: {
    content: tool.schema.string().describe("Note content - be specific and actionable"),
    type: tool.schema.enum(["learning", "stuck", "tip", "decision"]).describe("Note category"),
  },
  async execute(args) {
    const meta = JSON.stringify({ action: "add", type: args.type, iteration: ITERATION })
    await Bun.$`echo ${args.content} | xs append ${STORE_PATH} ralph.${SESSION_NAME}.note --meta ${meta}`
    const preview = args.content.length > 50 ? args.content.slice(0, 50) + "..." : args.content
    return `Note added: [${args.type}] ${preview}`
  },
})

export const note_list = tool({
  description: "List notes from this session",
  args: {
    type: tool.schema.enum(["learning", "stuck", "tip", "decision"]).optional().describe("Filter by type"),
  },
  async execute(args) {
    const typeFilter = args.type ? `| where {|n| $n.type == "${args.type}"}` : ""
    const cmd = `
      let topic = "ralph.${SESSION_NAME}.note"
      xs cat ${STORE_PATH} | from json --objects | where topic == $topic | each {|f|
        {
          id: $f.id
          type: ($f.meta.type? | default "note")
          iteration: ($f.meta.iteration? | default null)
          content: (xs cas ${STORE_PATH} $f.hash)
        }
      } ${typeFilter} | to json
    `
    const result = await Bun.$`nu -c ${cmd}`.text()
    return result.trim() || "No notes yet"
  },
})
```

### Updated Prompt Template
```nushell
def build-prompt [...] {
  let notes = (get-note-state $store_path $name)
  let notes_section = (format-notes-for-prompt $notes $iteration)
  
  $"## Context
- Spec: ($spec_content)
- Iteration: #($iteration)

($notes_section)

## Current Task State
($state_text)

## Available Tools
...
- note_add\(content, type\) - Record learning/tip/blocker/decision for future iterations
- note_list\(type?\) - View session notes

## Instructions
...
7. If stuck or learned something important: call note_add\(\)
...
"
}
```

### Display Helper
```nushell
def show-session-notes [store_path: string, name: string] {
  let notes = (get-note-state $store_path $name)
  if ($notes | is-empty) { return }
  
  let grouped = ($notes | group-by type)
  print $"\n(style section)SESSION NOTES(style reset)"
  
  for type in ["stuck", "learning", "tip", "decision"] {
    let type_notes = ($grouped | get -o $type | default [])
    if ($type_notes | length) > 0 {
      let color = match $type {
        "stuck" => "red"
        "learning" => "green"  
        "tip" => "cyan"
        "decision" => "yellow"
        _ => "white"
      }
      print $"\n(ansi $color)($type | str upcase)(ansi reset)"
      for note in $type_notes {
        let iter = if ($note.iteration != null) { $"[#($note.iteration)]" } else { "" }
        print $"  ($iter) ($note.content)"
      }
    }
  }
}
```

## Tasks

### 1. Add note state functions
- [ ] Add `get-note-state` function to ralph.nu
- [ ] Add `format-notes-for-prompt` function

### 2. Add display helper
- [ ] Add `show-session-notes` function
- [ ] Call from startup sequence after `show-iterations`

### 3. Add note tools to generate-tools
- [ ] Add `note_add` tool definition
- [ ] Add `note_list` tool definition

### 4. Update prompt template
- [ ] Inject notes section in `build-prompt`
- [ ] Add note tools to Available Tools section
- [ ] Add instruction for when to use notes

### 5. Test note persistence
- [ ] Verify notes persist across iterations
- [ ] Verify notes persist across ralph.nu restarts
- [ ] Verify notes appear in prompt for subsequent iterations

## Out of Scope (v1)
- Note editing/deletion (append-only)
- Note search/filtering beyond type
- Cross-session note sharing
- Note expiration/cleanup
- Structured note fields (just free-form content)

## Open Questions
- Max notes to show in prompt? (prevent context bloat with long-running sessions)
- Include note IDs in display? (not needed since no update/delete)
