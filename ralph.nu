#!/usr/bin/env nu

# ralph.nu - Iterative AI coding assistant with xs event store and opencode web UI

# Start xs store server as background job
def start-store [
  store_path: string  # Path to the store directory
] {
  # Create store directory if it doesn't exist
  mkdir $store_path
  
  print $"Starting xs store at ($store_path)..."
  
  # Start xs serve as background job
  job spawn { xs serve $store_path }
  
  # Wait for store to be ready (poll xs version)
  for attempt in 0..30 {
    let result = (xs version $store_path | complete)
    if $result.exit_code == 0 {
      print "xs store is ready!"
      return
    }
    sleep 100ms
  }
  
  # If we get here, store didn't start
  error make {msg: "xs store failed to start after 3 seconds"}
}

# Main entry point
def main [
  --name (-n): string                                       # REQUIRED - name for this ralph session
  --prompt (-p): string                                     # Custom prompt
  --spec (-s): string = "./specs/SPEC.md"                   # Spec file path
  --model (-m): string = "anthropic/claude-sonnet-4-5"      # Model to use
  --iterations (-i): int = 0                                # Number of iterations (0 = infinite)
  --port: int = 4096                                        # opencode web port
  --store: string = "./.ralph/store"                        # xs store path
]: [string -> nothing, nothing -> nothing] {
  # Validate required parameter
  if ($name | is-empty) {
    error make {msg: "--name (-n) is required"}
  }

  print "ralph.nu starting..."
  print $"Session: ($name)"
  print $"Store: ($store)"
  print $"Port: ($port)"
}
