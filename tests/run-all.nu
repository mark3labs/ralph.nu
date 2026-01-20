#!/usr/bin/env nu

# Run all test files in the tests directory
# This script discovers and executes all test files

use std/assert

def main [] {
  let test_files = [
    "prompt-template.nu"
    "input-handling.nu"
    "status-display.nu"
    "job-cleanup.nu"
    "web-server-start.nu"
    "iteration-logging.nu"
    "notes.nu"
    "message-flow.nu"
  ]
  
  print $"(ansi blue)Running all tests...(ansi reset)"
  print ""
  
  let results = ($test_files | each {|file|
    let file_path = ($env.FILE_PWD | path join $file)
    print $"(ansi cyan)Running tests in ($file)...(ansi reset)"
    
    try {
      nu $file_path
      print $"(ansi green)✓(ansi reset) ($file) passed"
      print ""
      {file: $file, status: "passed"}
    } catch {|e|
      print $"(ansi red)✗(ansi reset) ($file) failed: ($e.msg)"
      print ""
      {file: $file, status: "failed", error: $e.msg}
    }
  })
  
  print ""
  print $"(ansi blue)═══════════════════════════════════════════(ansi reset)"
  
  let passed = ($results | where status == "passed" | length)
  let failed = ($results | where status == "failed" | length)
  let total = ($results | length)
  
  if $failed > 0 {
    print $"(ansi red)FAILED:(ansi reset) ($failed)/($total) test files failed"
    let failed_files = ($results | where status == "failed" | get file)
    print $"Failed files: ($failed_files | str join ', ')"
    exit 1
  } else {
    print $"(ansi green)SUCCESS:(ansi reset) All ($passed) test files passed"
  }
}
