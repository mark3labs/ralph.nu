# ralph.nu

AI coding agent in a while loop. Named after Ralph Wiggum from The Simpsons.

```
while :; do cat PROMPT.md | claude-code ; done
```

This is a Nushell implementation with task tracking, iteration history, and a web UI.

## How it works

1. Reads a spec file describing what to build
2. Spawns an AI agent (via opencode) to work on ONE task per iteration
3. Tracks tasks and iterations in an append-only event store (xs)
4. Loops until all tasks are complete or iteration limit reached
5. Agent calls `session_complete()` when done

The agent has tools to manage tasks: `task_add`, `task_status`, `task_list`, `session_complete`.

## Requirements

- [nushell](https://www.nushell.sh/) - Shell
- [xs](https://github.com/cablehead/xs) - Event store
- [opencode](https://opencode.ai/) - AI coding agent

Optional:
- [ngrok](https://ngrok.com/) - Remote access tunnel

## Setup

Copy `ralph.nu` into your repo:

```bash
curl -o ralph.nu https://raw.githubusercontent.com/anthropics/ralph.nu/main/ralph.nu
chmod +x ralph.nu
```

Create a spec file at `specs/SPEC.md` describing your feature with tasks.

## Usage

```bash
# Basic usage
./ralph.nu --name my-feature

# With custom spec file
./ralph.nu --name my-feature --spec ./specs/auth-system.md

# Limit iterations
./ralph.nu --name my-feature --iterations 5

# Different model
./ralph.nu --name my-feature --model anthropic/claude-sonnet-4-5

# Enable remote access via ngrok
./ralph.nu --name my-feature --ngrok "your-password-here"
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--name`, `-n` | (required) | Session name |
| `--spec`, `-s` | `./specs/SPEC.md` | Path to spec file |
| `--model`, `-m` | `anthropic/claude-sonnet-4-5` | Model to use |
| `--iterations`, `-i` | `0` (infinite) | Max iterations |
| `--port` | `4096` | Web UI port |
| `--store` | `./.ralph/store` | Event store path |
| `--ngrok` | (disabled) | ngrok password (8-128 chars) |
| `--ngrok-domain` | (none) | Custom ngrok domain |

## Spec file format

```markdown
## Overview
What the feature does.

## Tasks
- [ ] Create database schema
- [ ] Add API endpoints
- [ ] Write tests
```

## Testing

Run the test suite:

```bash
# Run all tests
nu tests/run-all.nu

# Run individual test file
nu tests/prompt-template.nu
```

The test suite uses Nushell's `std/assert` module and includes:
- Unit tests for core functions (prompt building, input handling, status display, etc.)
- Integration tests for full workflow scenarios

Test files follow the `def "test ..."` naming convention. See `tests/mod.nu` for test framework utilities.

## Web UI

Access the opencode serve UI at `http://localhost:4096` (or your ngrok URL).

## Data

Session data stored in `.ralph/store/`:
- Task state (add/status events)
- Iteration history (start/complete events)

Sessions can be resumed - ralph continues from the last iteration.
