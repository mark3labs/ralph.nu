#!/usr/bin/env nu

# Test the --extra-instructions functionality

use std/assert
use mod.nu [run-tests]
source ../ralph.nu

def "test prompt without extra instructions has no Additional Instructions section" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert not ($prompt | str contains "## Additional Instructions")
}

def "test prompt with extra instructions contains Additional Instructions section" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  let extra = "Focus on error handling first"
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state $extra)
  assert str contains $prompt "## Additional Instructions"
}

def "test extra instructions content appears in prompt" [] {
  let spec_content = "# Test Spec"
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  let extra = "Do not modify public APIs"
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state $extra)
  assert str contains $prompt "Do not modify public APIs"
}

def "test extra instructions preserves core prompt sections" [] {
  let spec_content = "# Test Spec\n\nBuild something cool."
  let store_path = "./.ralph/test-store"
  let name = "my-feature"
  let iteration = 5
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  let extra = "Use functional programming style"
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state $extra)
  
  # Verify all core sections are present
  assert str contains $prompt "## Context"
  assert str contains $prompt "## Task State"
  assert str contains $prompt "## Tools"
  assert str contains $prompt "## Workflow"
  assert str contains $prompt "## Additional Instructions"
  
  # Verify context info is preserved
  assert str contains $prompt "my-feature"
  assert str contains $prompt "Iteration: #5"
  assert str contains $prompt "# Test Spec"
}

def "test extra instructions appears at end of prompt" [] {
  let spec_content = "# Test Spec"
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  let extra = "UNIQUE_MARKER_12345"
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state $extra)
  
  # The extra instructions should be at the very end
  let last_section_pos = ($prompt | str index-of "## Additional Instructions")
  let context_pos = ($prompt | str index-of "## Context")
  let tools_pos = ($prompt | str index-of "## Tools")
  let workflow_pos = ($prompt | str index-of "## Workflow")
  
  # Additional Instructions should come after all other sections
  assert ($last_section_pos > $context_pos)
  assert ($last_section_pos > $tools_pos)
  assert ($last_section_pos > $workflow_pos)
}

def "test empty string extra instructions has no Additional Instructions section" [] {
  let spec_content = "# Test Spec"
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  let empty_str = ""
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state $empty_str)
  
  # Empty extra instructions should not add the section
  assert not ($prompt | str contains "## Additional Instructions")
}

def "test multiline extra instructions work" [] {
  let spec_content = "# Test Spec"
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  let extra = "Line one
Line two
Line three"
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state $extra)
  
  assert str contains $prompt "Line one"
  assert str contains $prompt "Line two"
  assert str contains $prompt "Line three"
}

run-tests
