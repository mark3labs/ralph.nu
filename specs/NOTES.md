# Ralph.nu Implementation Notes

## Completed
- Task 1: Create basic script skeleton (all subtasks)
  - Created ralph.nu with shebang and main function signature
  - Added all CLI flags: --name (required), --prompt, --spec, --model, --iterations, --port, --store
  - Added default values matching spec
  - Validated --name is required with proper error handling
  - Tested basic invocation

## In Progress
(none)

## Blocked
(none)

## Remaining
- Task 2: Implement xs store management
  - Create `start-store` function: mkdir -p, job spawn xs serve
  - Return store path for $env.XS_ADDR
  - Add wait/poll loop until store responds (xs version)
- Task 3: Implement opencode web management
  - Create `start-web` function: job spawn opencode web --port
  - Add wait/poll loop until web responds (curl localhost:port)
  - Return server URL for --attach
- Task 4: Implement cleanup handler
  - Create `cleanup` function to kill all spawned jobs
  - Track job IDs from spawn calls
  - Wire into try/catch for interrupt handling
- Task 5: Implement iteration logging
  - Create `log-iteration-start` function: xs append ralph.iteration
  - Create `log-iteration-complete` function: xs append ralph.iteration
  - Include iteration number and timestamp in meta
- Task 6: Build prompt template
  - Create prompt string with {spec}, {store}, {pid} placeholders
  - Include xs CLI examples for note CRUD
  - Include note type categories (completed, in_progress, blocked, remaining)
  - Include termination instruction (pkill -P {pid})
- Task 7: Implement main iteration loop
  - Initialize servers (store, web)
  - Loop with iteration counter
  - Call opencode run --attach --title "Iteration #N"
  - Log iteration start/complete
  - Handle --iterations limit (0 = infinite)
- Task 8: Wire everything together
  - Main function orchestrates: init -> loop -> cleanup
  - Substitute placeholders in prompt template
  - Handle piped input vs --prompt flag vs default
- Task 9: Add status display helpers
  - Create `show-notes` function: aggregate ralph.note by type
  - Create `show-iterations` function: list ralph.iteration events
  - Optional: call on startup to show current state
- Task 10: Testing and polish
  - Test with simple spec file
  - Verify web UI shows titled sessions
  - Verify notes persist across runs
  - Verify cleanup on Ctrl+C
