# ralph.nu

AI coding agent in a while loop. Named after Ralph Wiggum from The Simpsons.

```
while :; do cat PROMPT.md | opencode ; done
```

Nushell implementation with task tracking, iteration history, notes, inbox messaging, and a web UI.

**This is a highly opinionated script. There are no plans to support other tools or features beyond what's already implemented.**

## How it works

1. Reads a spec file describing what to build
2. Spawns an AI agent (via opencode) to work on ONE task per iteration
3. Tracks tasks, notes, and iterations in an append-only event store (xs)
4. Loops until all tasks are complete or iteration limit reached
5. Agent calls `session_complete()` when done

Agent tools (auto-generated in `.opencode/tool/ralph.ts`):
- `task_add`, `task_status`, `task_list` - task management
- `note_add`, `note_list` - persist learnings/tips/blockers across iterations
- `inbox_list`, `inbox_mark_read` - receive messages from external senders
- `session_complete` - signal all tasks done

## Requirements

- [nushell](https://www.nushell.sh/) - Shell
- [xs](https://github.com/cablehead/xs) - Event store
- [opencode](https://opencode.ai/) - AI coding agent
- [bun](https://bun.sh/) - JavaScript runtime (for tool execution)

Optional:
- [ngrok](https://ngrok.com/) - Remote access tunnel

## Setup

Copy `ralph.nu` into your repo:

```bash
curl -o ralph.nu https://raw.githubusercontent.com/mark3labs/ralph.nu/main/ralph.nu
chmod +x ralph.nu
```

Verify dependencies are installed:

```bash
./ralph.nu doctor
```

Create a spec file at `specs/SPEC.md` describing your feature with tasks.

To update to the latest version:

```bash
./ralph.nu update
```

## Usage

```bash
# Basic usage (session name derived from spec filename)
./ralph.nu build --spec ./specs/my-feature.md

# Explicit session name
./ralph.nu build --name my-feature --spec ./specs/auth-system.md

# Add extra instructions to guide the agent
./ralph.nu build --spec ./specs/my-feature.md -e "Focus on error handling first"

# Limit iterations
./ralph.nu build --spec ./specs/my-feature.md --iterations 5

# Different model
./ralph.nu build --spec ./specs/my-feature.md --model anthropic/claude-sonnet-4-5

# Enable remote access via ngrok
./ralph.nu build --spec ./specs/my-feature.md --ngrok "your-password-here"

# Send message to running session
./ralph.nu message --name my-feature "Please prioritize the login feature"
```

## Subcommands

### `build`

Run the AI agent loop.

| Flag | Default | Description |
|------|---------|-------------|
| `--name`, `-n` | spec filename | Session name |
| `--spec`, `-s` | `./specs/SPEC.md` | Path to spec file |
| `--template`, `-t` | `.ralph.template` if exists | Custom template file |
| `--extra-instructions`, `-e` | (none) | Extra instructions appended to prompt |
| `--model`, `-m` | `anthropic/claude-sonnet-4-5` | Model to use |
| `--iterations`, `-i` | `0` (infinite) | Max iterations |
| `--port` | `4096` | Web UI port |
| `--ngrok` | (disabled) | ngrok password (8-128 chars) |
| `--ngrok-domain` | (none) | Custom ngrok domain |
| `--regen-tools` | false | Regenerate tool definitions |

### `message`

Send a message to a running session's inbox.

| Flag | Default | Description |
|------|---------|-------------|
| `--name`, `-n` | (required) | Session name |

### `doctor`

Check that required dependencies are installed.

```bash
./ralph.nu doctor          # Check required tools (xs, opencode, bun)
./ralph.nu doctor --ngrok  # Also check for ngrok
```

### `update`

Update `ralph.nu` to the latest version from GitHub.

```bash
./ralph.nu update
```

### `gen-template`

Export the default prompt template for customization.

```bash
./ralph.nu gen-template                    # Writes to .ralph.template
./ralph.nu gen-template --output my.template  # Custom output path
```

## Spec file format

```markdown
## Overview
What the feature does.

## Tasks
- [ ] Create database schema
- [ ] Add API endpoints
- [ ] Write tests
```

## Customizing agent behavior

Use `--extra-instructions` to add guidance without replacing the built-in prompt template:

```bash
# Prioritize certain work
./ralph.nu build --spec ./specs/api.md -e "Focus on authentication endpoints first"

# Add constraints
./ralph.nu build --spec ./specs/refactor.md -e "Do not modify any public API signatures"

# Specify coding style
./ralph.nu build --spec ./specs/feature.md -e "Use functional style, avoid classes"
```

The extra instructions are appended under an "Additional Instructions" section, preserving all context (session info, task state, inbox, notes, tools, workflow).

## Custom prompt templates

For deeper customization, you can create a custom prompt template:

```bash
# Export default template
./ralph.nu gen-template

# Edit .ralph.template with your changes
# Template uses {{variable}} placeholders

# ralph automatically uses .ralph.template if it exists
./ralph.nu build --spec ./specs/my-feature.md

# Or specify explicit template path
./ralph.nu build --spec ./specs/my-feature.md --template ./my-custom.template
```

### Template variables

Templates use `{{variable}}` syntax:

| Variable | Description |
|----------|-------------|
| `{{session}}` | Session name |
| `{{iteration}}` | Current iteration number |
| `{{spec}}` | Full spec file content |
| `{{inbox}}` | Formatted inbox section (empty if none) |
| `{{notes}}` | Formatted notes section (empty if none) |
| `{{tasks}}` | Formatted task state |
| `{{extra}}` | Extra instructions from `--extra-instructions` flag |

### Template resolution priority

1. `--template <path>` flag (explicit path)
2. `.ralph.template` in project root (default custom location)
3. Hardcoded template in `ralph.nu` (fallback)

Example custom template:

```
# Agent Instructions

Session: {{session}} (Iteration {{iteration}})

## Task
{{spec}}

## Current State
{{tasks}}

{{inbox}}{{notes}}

Focus on one task at a time. Test before committing.
{{extra}}
```

## Testing

```bash
nu tests/run-all.nu        # Run all tests
nu tests/prompt-template.nu # Run individual test file
```

Test files use `def "test ..."` naming convention. See `tests/mod.nu` for framework utilities.

## Web UI

Access the opencode serve UI at `http://localhost:4096` (or your ngrok URL).

## Data

Session data stored in `.ralph/store/`:
- Task state (add/status events)
- Iteration history (start/complete events)
- Notes (learnings, tips, blockers, decisions)
- Inbox messages

Sessions can be resumed - ralph continues from the last iteration.
