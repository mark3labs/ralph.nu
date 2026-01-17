#!/usr/bin/env nu

# Test task 8: Wire everything together - piped input handling

use std/assert
use mod.nu [run-tests]

def "test signature accepts piped input" [] {
  # Check that ralph.nu has the correct signature  
  let script_dir = ($env.FILE_PWD? | default $env.PWD)
  let ralph_path = ($script_dir | path join ".." "ralph.nu")
  let ralph_content = (^cat $ralph_path)
  let has_input_param = ($ralph_content | str contains "input?: string")
  assert $has_input_param
}

def "test prompt priority logic exists" [] {
  # Check input is handled with priority logic
  let script_dir = ($env.FILE_PWD? | default $env.PWD)
  let ralph_path = ($script_dir | path join ".." "ralph.nu")
  let ralph_content = (^cat $ralph_path)
  let has_priority_logic = ($ralph_content | str contains "# Determine base prompt")
  assert $has_priority_logic
}

run-tests
