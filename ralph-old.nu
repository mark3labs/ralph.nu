#!/usr/bin/env nu

# Trap handler to kill all child processes on exit
def cleanup [] {
  # Kill all processes in our process group
  ^kill -- $"-($nu.pid)" err>| ignore
}

# Main entry point - a generic iterative AI coding assistant runner
def main [
  --prompt (-p): string                    # Custom prompt (overrides piped input and default)
  --spec (-s): string = "./specs/SPEC.md"        # Spec file to study
  --notes (-n): string = "./specs/NOTES.md"      # Notes file for reading/writing progress
  --model (-m): string = "anthropic/claude-sonnet-4-5"  # Model to use
  --iterations (-i): int = 0              # Number of iterations to run
]: [string -> nothing, nothing -> nothing] {
  # Default prompt template
  let default_prompt = $"
## Context
- Spec file: ($spec)
- Notes file: ($notes)

## Instructions
1. STUDY the spec file to understand the full scope of work
2. STUDY the notes file to see what has been completed and what remains
3. Pick the single most important pending task and complete it
4. Add any tests you feel are needed
5. Update the notes file to reflect your progress

## Rules
- Only work on ONE task per iteration - do not attempt multiple tasks
- Always run tests before committing: ensure all tests pass
- Write clean, well-documented code following existing project conventions
- If you encounter a blocker, document it in the notes file and move on
- Do not refactor unrelated code - stay focused on the current task

## Spec Modifications
You MAY update the spec file when:
- A task needs to be broken into smaller subtasks
- You discover a missing task required for the spec to be complete
- A task is technically infeasible and needs to be revised
- You find an error or ambiguity that needs clarification

You must NOT:
- Remove tasks without justification
- Significantly expand scope beyond the original intent
- Change the overall goals of the spec

Document any spec changes in the notes file with your reasoning.

## Completion
- Git commit your changes with a clear, descriptive message
- If ALL tasks in the spec are complete, terminate by running: pkill -P ($nu.pid)

## Notes File Format
Keep the notes file organized with these sections:
- Completed: tasks that are done
- In Progress: current task [should be empty when you commit]
- Blocked: tasks that cannot be completed and why
- Remaining: tasks yet to be started
"

  # Determine which prompt to use: --prompt flag > piped input > default
  let final_prompt = if ($prompt | is-not-empty) {
    $prompt
  } else if ($in | is-not-empty) {
    $in
  } else {
    $default_prompt
  }

  # Run in a new process group so we can kill all children together
  # Use 'try' to catch interrupts and clean up
  try {
    mut j = 1
    if $iterations == 0 {
      loop {
        print $"Iteration #($j)..."
        opencode run $final_prompt -m $model
        print "Done!"      
        $j += 1
      }
    } else {
      for i in 1..($iterations) {
        print $"Iteration #($i)..."
        opencode run $final_prompt -m $model
        print "Done!"
      }
    }
  } catch {
    print "Caught interrupt, cleaning up..."
    cleanup
  }

  # Final cleanup on normal exit
  cleanup
}
