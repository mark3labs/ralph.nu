#!/usr/bin/env nu

# ralph.nu - Iterative AI coding assistant with xs event store and opencode web UI

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
