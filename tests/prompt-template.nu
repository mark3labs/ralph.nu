#!/usr/bin/env nu

# Test the build-prompt function

use std/assert
use mod.nu [run-tests]
source ../ralph.nu

def "test prompt contains spec content" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt "# Test Spec"
}

def "test prompt contains session name" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt $name
}

def "test prompt contains iteration" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt ($iteration | into string)
}

def "test prompt contains task_add tool" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt "task_add"
}

def "test prompt contains task_status tool" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt "task_status"
}

def "test prompt contains task_list tool" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt "task_list"
}

def "test prompt contains session_complete tool" [] {
  let spec_content = "# Test Spec\n\nThis is a test spec file."
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 3
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  assert str contains $prompt "session_complete"
}

run-tests
