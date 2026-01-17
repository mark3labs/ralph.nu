# Custom Tools for ralph.nu

## Overview

Replace raw xs CLI commands in prompts with typed opencode custom tools. Ralph.nu generates tool definitions at startup, agent calls tools directly.

## User Story

Agent gets clean tool interface instead of constructing xs commands. Better DX, fewer errors, cleaner prompts.

## Requirements

### Tool Generation
- Ralph.nu writes `.opencode/tool/ralph.ts` on startup
- Tools generated with current session context baked in
- Regenerate each run (context may change)

### Tools to Create

**task_add** - Add new task
- Args: `content` (string), `status` (enum: remaining|blocked, default: remaining)
- Returns: frame ID

**task_status** - Update task status  
- Args: `id` (string - task ID or prefix), `status` (enum: in_progress|completed|blocked)
- Returns: confirmation

**task_list** - Get current task state
- Args: none
- Returns: formatted task list grouped by status

**session_complete** - Signal all tasks done
- Args: none  
- Effect: terminates ralph.nu parent process

### Context Injection
Tool file includes hardcoded values from ralph.nu startup:
- `STORE_PATH` - absolute path to xs store
- `SESSION_NAME` - ralph session name
- `ITERATION` - current iteration number
- `PARENT_PID` - for session_complete

### Prompt Updates
- Remove xs CLI examples from prompt
- Reference tools by name instead
- Keep task state display (agent needs to see IDs)

## Technical Implementation

### Tool File Generation (Nushell)
```nushell
def generate-tools [
  store_path: string
  name: string
  iteration: int
  pid: int
] {
  let abs_store = ($store_path | path expand)
  
  let content = $'import { tool } from "@opencode-ai/plugin"

const STORE_PATH = "($abs_store)"
const SESSION_NAME = "($name)"
const ITERATION = ($iteration)
const PARENT_PID = ($pid)
const TOPIC = `ralph.${SESSION_NAME}.task`

export const task_add = tool({
  description: "Add a new task to the ralph session task list",
  args: {
    content: tool.schema.string\(\).describe\("Task description"\),
    status: tool.schema.enum\(["remaining", "blocked"]\).default\("remaining"\).describe\("Initial status"\),
  },
  async execute\(args\) {
    const meta = JSON.stringify\({ action: "add", status: args.status }\)
    const result = await Bun.$`echo ${args.content} | xs append ${STORE_PATH} ${TOPIC} --meta ${meta}`.text\(\)
    return result.trim\(\)
  },
}\)

export const task_status = tool({
  description: "Update a task status by ID. Use IDs from task_list output.",
  args: {
    id: tool.schema.string\(\).describe\("Task ID \(full or 8+ char prefix\)"\),
    status: tool.schema.enum\(["in_progress", "completed", "blocked"]\).describe\("New status"\),
  },
  async execute\(args\) {
    const meta = JSON.stringify\({ action: "status", id: args.id, status: args.status, iteration: ITERATION }\)
    const result = await Bun.$`xs append ${STORE_PATH} ${TOPIC} --meta ${meta}`.text\(\)
    return `Task ${args.id} marked as ${args.status}`
  },
}\)

export const task_list = tool({
  description: "Get current task list grouped by status. Shows task IDs needed for task_status.",
  args: {},
  async execute\(\) {
    const cmd = `xs cat ${STORE_PATH} | from json --objects | where topic == "${TOPIC}" | each {|f| {id: $f.id, status: $f.meta.status, content: \(xs cas ${STORE_PATH} $f.hash\)}} | group-by status | to json`
    const result = await Bun.$`nu -c ${cmd}`.text\(\)
    return result.trim\(\) || "No tasks yet"
  },
}\)

export const session_complete = tool({
  description: "Signal that ALL tasks are complete and terminate the ralph session. Only call when every task is done.",
  args: {},
  async execute\(\) {
    await Bun.$`kill -TERM ${PARENT_PID}`
    return "Session terminated"
  },
}\)
'
  
  mkdir .opencode/tool
  $content | save -f .opencode/tool/ralph.ts
}
```

### Integration Point
Call `generate-tools` in main before iteration loop:
```nushell
# After servers ready, before loop
generate-tools $store $name 1 $parent_pid
```

Regenerate at each iteration start (iteration number changes):
```nushell
loop {
  generate-tools $store $name $n $parent_pid
  # ... rest of iteration
}
```

### Updated Prompt Template
```
## Context
- Spec: {spec}
- Iteration: #{iteration}

## Current Task State
{task_state}

## Available Tools
- task_add(content, status?) - Add new task
- task_status(id, status) - Update task (use IDs from list above)
- task_list() - Refresh task list
- session_complete() - Call when ALL tasks done

## Instructions
1. Pick ONE task from REMAINING or IN PROGRESS
2. Call task_status(id, "in_progress")
3. Complete the work
4. Call task_status(id, "completed")
5. Git commit with clear message
6. If ALL tasks done: call session_complete()

## Rules
- ONE task per iteration
- Run tests before commit
```

## Tasks

### 1. Create tool generation function
- [ ] Add `generate-tools` function to ralph.nu
- [ ] Generate TypeScript with baked-in context values
- [ ] Write to `.opencode/tool/ralph.ts`

### 2. Implement task_add tool
- [ ] Args: content (string), status (enum)
- [ ] Exec: pipe content to xs append with meta
- [ ] Return: frame output (contains ID)

### 3. Implement task_status tool
- [ ] Args: id (string), status (enum)
- [ ] Exec: xs append with status action meta
- [ ] Return: confirmation message

### 4. Implement task_list tool
- [ ] Args: none
- [ ] Exec: xs cat + nushell filter/format
- [ ] Return: formatted task state (match current show-notes output)

### 5. Implement session_complete tool
- [ ] Args: none
- [ ] Exec: kill parent PID
- [ ] Return: confirmation (may not reach caller)

### 6. Integrate into ralph.nu startup
- [ ] Call generate-tools before first iteration
- [ ] Ensure .opencode/tool dir exists

### 7. Regenerate tools each iteration
- [ ] Update ITERATION constant each loop
- [ ] Regenerate file at iteration start

### 8. Update prompt template
- [ ] Remove xs CLI examples
- [ ] Add tool reference section
- [ ] Keep task state display

### 9. Test tool invocation
- [ ] Verify opencode loads tools from .opencode/tool/
- [ ] Test each tool manually
- [ ] Run full iteration with tools

## Out of Scope (v1)
- Tool for reading xs store history
- Tool for adding arbitrary notes
- Caching/diffing tool file (always regenerate)
- TypeScript compilation (opencode handles via Bun)

## Open Questions
- Add .opencode/tool to .gitignore? Generated files usually ignored.
