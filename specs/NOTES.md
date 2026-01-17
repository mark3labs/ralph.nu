# Ralph.nu Implementation Notes

## URGENT!!!
- Move all tests to tests/
- Makre sure all tests have meaningful names

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

- Task 5: Implement iteration logging (all subtasks)
  - Created `log-iteration-start` function that logs to ralph.{name}.iteration topic
  - Created `log-iteration-complete` function that logs to ralph.{name}.iteration topic
  - Both functions include iteration number and timestamp in metadata
  - log-iteration-complete also includes status ("success" or "failure")
  - Created test-ralph-logging.nu to verify functionality
  - Tested successfully: events are logged correctly with proper metadata structure
  - Fixed spec file: updated all `from json -l` to `from json --objects` (correct Nushell flag)

- Task 4: Implement cleanup handler (all subtasks)
  - Cleanup function already existed from previous work
  - Wired cleanup into main function with try/catch for interrupt/error handling
  - Implemented cleanup-all helper that gets current job list for cleanup
  - Cleanup is called on both normal completion and error paths
  - Created test-ralph-cleanup.nu to verify cleanup functionality
  - Tested successfully: cleanup kills all spawned jobs (xs store + opencode web)
  - Tested error path: cleanup properly handles errors during startup (invalid port)
  - All existing tests still pass (test-ralph-web.nu, test-ralph-logging.nu)

- Task 6: Build prompt template (all subtasks)
  - Created `build-prompt` function that generates complete prompt with placeholders
  - Function accepts: spec_content, store_path, name, pid, iteration parameters
  - Template includes Context section with spec, store path, and topic prefix
  - Template includes State Commands section with xs CLI examples for:
    - Reading all notes (xs cat + from json --objects + xs cas)
    - Adding completed notes with iteration number
    - Adding in_progress notes with iteration number
    - Adding blocked notes with iteration number
    - Adding remaining notes (no iteration number)
  - Template includes Instructions section (7 steps from STUDY to pkill)
  - Template includes Rules section (ONE task, run tests, document blockers)
  - Created test-ralph-prompt.nu to verify functionality
  - Tested successfully: all 12 verification checks passed (spec content, store path, session name, pid, iteration, xs commands, note types, termination instruction)
  - Function properly substitutes all placeholders with provided values

- Task 7: Implement main iteration loop (all subtasks)
  - Implemented iteration loop with counter starting at 1
  - Loop reads spec file and builds prompt using build-prompt function
  - Supports custom --prompt override or uses built template
  - Logs iteration start before running opencode
  - Runs opencode with --attach to web server and --title "Session - Iteration #N"
  - Captures opencode exit code and logs iteration complete with success/failure status
  - Handles --iterations limit: 0 = infinite loop, N > 0 stops after N iterations
  - Created comprehensive test (test-task7.nu) that verifies:
    - Both iterations execute
    - Loop stops after specified iteration count
    - Store directory is created
    - Both servers (xs store and opencode web) start successfully
    - Web UI URL is displayed
    - All 4 iteration events are logged correctly (2 starts + 2 completes)
  - All tests pass

- Task 8: Wire everything together (all subtasks)
  - Main function orchestrates: init -> loop -> cleanup ✓ (already done in Task 7)
  - Substitute placeholders in prompt template ✓ (already done in Tasks 6-7)
  - Handle piped input vs --prompt flag vs default ✓
  - Updated main signature to accept optional input parameter: `input?: string`
  - Implemented priority logic: --prompt flag > piped input > default template
  - Created test-task8.nu to verify:
    - Signature accepts optional input parameter
    - Prompt priority logic exists and is correct
  - All existing tests still pass (web, logging, cleanup, prompt, task7)
  - Main function now properly handles all three input methods

## In Progress
(none)

## Blocked
(none)

## Remaining
- Task 9: Add status display helpers
  - Create `show-notes` function: aggregate ralph.note by type
  - Create `show-iterations` function: list ralph.iteration events
  - Optional: call on startup to show current state
- Task 10: Testing and polish
  - Test with simple spec file
  - Verify web UI shows titled sessions
  - Verify notes persist across runs
  - Verify cleanup on Ctrl+C
