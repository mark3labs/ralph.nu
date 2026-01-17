#!/usr/bin/env nu

# Test runner for task state management tests
# Runs all test files in the task-state directory and reports results

def main [] {
  print $"(ansi cyan_bold)═══ Running Task State Tests ═══(ansi reset)\n"
  
  # Track test results
  mut passed = 0
  mut failed = 0
  mut failed_tests = []
  
  # Get all test files (excluding helpers.nu and run-all.nu)
  let test_files = (ls *.nu 
    | where name !~ "helpers.nu" 
    | where name !~ "run-all.nu"
    | get name
    | sort)
  
  if ($test_files | is-empty) {
    print $"(ansi yellow)⚠ No test files found(ansi reset)"
    exit 0
  }
  
  # Run each test file
  for test_file in $test_files {
    let test_name = ($test_file | path basename)
    print $"(ansi blue)═══ Running: ($test_name) ═══(ansi reset)"
    
    let result = (nu $test_file | complete)
    
    if $result.exit_code == 0 {
      print $result.stdout
      $passed += 1
    } else {
      print $result.stdout
      print $result.stderr
      $failed += 1
      $failed_tests = ($failed_tests | append $"  - ($test_name)")
    }
    
    print ""
  }
  
  # Print summary
  print $"(ansi cyan_bold)═══ Summary ═══(ansi reset)"
  print $"Total: ($passed + $failed) tests"
  print $"(ansi green)Passed: ($passed)(ansi reset)"
  
  if $failed > 0 {
    print $"(ansi red)Failed: ($failed)(ansi reset)"
    print "\nFailed tests:"
    for test in $failed_tests {
      print $test
    }
    exit 1
  } else {
    print $"(ansi green_bold)✓ All tests passed!(ansi reset)"
    exit 0
  }
}
