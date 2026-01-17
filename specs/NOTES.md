# Ralph.nu Implementation Notes

## Completed
- Task 1: Create basic script skeleton (all subtasks)
  - Created ralph.nu with shebang and main function signature
  - Added all CLI flags: --name (required), --prompt, --spec, --model, --iterations, --port, --store
  - Added default values matching spec
  - Validated --name is required with proper error handling
  - Tested basic invocation

- Task 2: Implement xs store management (all subtasks)
  - Created `start-store` function with mkdir -p and job spawn xs serve
  - Implemented wait/poll loop using xs version to verify store is ready (30 attempts @ 100ms)
  - Function accepts store_path parameter and creates/starts store
  - Tested successfully: store starts, accepts appends, and can be queried
  - Note: Function doesn't need to return store path (it's passed in as parameter)

- Task 3: Implement opencode web management (all subtasks)
  - Created `start-web` function with job spawn opencode web --port
  - Implemented wait/poll loop using curl to verify web server responds (30 attempts @ 100ms)
  - Returns server URL (http://localhost:{port}) for --attach usage
  - Created test-ralph-web.nu to validate functionality
  - Tested successfully: web server starts on port 4097, responds with HTTP 200, and cleans up properly
  - Updated to return both job_id and url as a record for tracking

- Task 4: Implement cleanup handler (all subtasks)
  - Created `cleanup` function that accepts list of job IDs
  - Function iterates through job IDs and kills each with job kill
  - Uses try/catch to ignore errors for jobs that may have already exited
  - Updated start-store to return job_id for tracking
  - Updated start-web to return {job_id, url} record for tracking
  - Created and ran test-ralph-cleanup.nu to verify functionality
  - Tested successfully: both store and web jobs are killed cleanly

## In Progress
(none)

## Blocked
(none)

## Remaining
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
