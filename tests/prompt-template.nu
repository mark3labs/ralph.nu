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

# ─────────────────────────────────────────────────────────────────────────────
# apply-template tests
# ─────────────────────────────────────────────────────────────────────────────

def "test apply-template substitutes session variable" [] {
  let template = "Session: {{session}}"
  let result = (apply-template $template {
    session: "my-session"
    iteration: 1
    spec: ""
    inbox: ""
    notes: ""
    tasks: ""
    extra: ""
  })
  assert equal $result "Session: my-session"
}

def "test apply-template substitutes iteration variable" [] {
  let template = "Iteration: {{iteration}}"
  let result = (apply-template $template {
    session: ""
    iteration: 42
    spec: ""
    inbox: ""
    notes: ""
    tasks: ""
    extra: ""
  })
  assert equal $result "Iteration: 42"
}

def "test apply-template substitutes all variables" [] {
  let template = "S:{{session}} I:{{iteration}} Spec:{{spec}} In:{{inbox}} N:{{notes}} T:{{tasks}} E:{{extra}}"
  let result = (apply-template $template {
    session: "sess"
    iteration: 5
    spec: "SPEC"
    inbox: "INBOX"
    notes: "NOTES"
    tasks: "TASKS"
    extra: "EXTRA"
  })
  assert equal $result "S:sess I:5 Spec:SPEC In:INBOX N:NOTES T:TASKS E:EXTRA"
}

def "test apply-template handles multiple occurrences of same variable" [] {
  let template = "{{session}} - {{session}} - {{session}}"
  let result = (apply-template $template {
    session: "test"
    iteration: 1
    spec: ""
    inbox: ""
    notes: ""
    tasks: ""
    extra: ""
  })
  assert equal $result "test - test - test"
}

# ─────────────────────────────────────────────────────────────────────────────
# resolve-template tests
# ─────────────────────────────────────────────────────────────────────────────

def "test resolve-template returns default when no flag and no file" [] {
  # Ensure .ralph.template doesn't exist in test context
  let test_dir = $"/tmp/ralph-template-test-(random chars -l 8)"
  mkdir $test_dir
  cd $test_dir
  
  let result = (resolve-template)
  
  # Should return DEFAULT_TEMPLATE (check for known content)
  assert str contains $result "## Context"
  assert str contains $result "{{session}}"
  
  # Cleanup
  cd -
  rm -rf $test_dir
}

def "test resolve-template uses template flag when provided" [] {
  let test_dir = $"/tmp/ralph-template-test-(random chars -l 8)"
  mkdir $test_dir
  
  # Create a custom template file
  let template_path = $"($test_dir)/custom.template"
  "CUSTOM TEMPLATE CONTENT" | save $template_path
  
  let result = (resolve-template $template_path)
  assert equal $result "CUSTOM TEMPLATE CONTENT"
  
  # Cleanup
  rm -rf $test_dir
}

def "test resolve-template errors when flag template not found" [] {
  let caught_error = try {
    resolve-template "/nonexistent/path/template.txt"
    false
  } catch {
    true
  }
  assert equal $caught_error true
}

def "test resolve-template uses ralph.template when it exists" [] {
  let test_dir = $"/tmp/ralph-template-test-(random chars -l 8)"
  mkdir $test_dir
  cd $test_dir
  
  # Create .ralph.template in current directory
  "PROJECT TEMPLATE" | save ".ralph.template"
  
  let result = (resolve-template)
  assert equal $result "PROJECT TEMPLATE"
  
  # Cleanup
  cd -
  rm -rf $test_dir
}

def "test resolve-template flag takes priority over ralph.template" [] {
  let test_dir = $"/tmp/ralph-template-test-(random chars -l 8)"
  mkdir $test_dir
  cd $test_dir
  
  # Create both .ralph.template and explicit template
  "PROJECT TEMPLATE" | save ".ralph.template"
  "EXPLICIT TEMPLATE" | save "explicit.template"
  
  let result = (resolve-template "explicit.template")
  assert equal $result "EXPLICIT TEMPLATE"
  
  # Cleanup
  cd -
  rm -rf $test_dir
}

# ─────────────────────────────────────────────────────────────────────────────
# gen-template tests (via main gen-template)
# ─────────────────────────────────────────────────────────────────────────────

def "test gen-template creates default file" [] {
  let test_dir = $"/tmp/ralph-template-test-(random chars -l 8)"
  mkdir $test_dir
  cd $test_dir
  
  # Run gen-template (writes to .ralph.template by default)
  main gen-template
  
  # Verify file exists and has expected content
  assert (".ralph.template" | path exists)
  let content = (open ".ralph.template")
  assert str contains $content "## Context"
  assert str contains $content "{{session}}"
  
  # Cleanup
  cd -
  rm -rf $test_dir
}

def "test gen-template creates file at custom path" [] {
  let test_dir = $"/tmp/ralph-template-test-(random chars -l 8)"
  mkdir $test_dir
  cd $test_dir
  
  # Run gen-template with custom output path
  main gen-template --output "custom-output.template"
  
  # Verify file exists at custom path
  assert ("custom-output.template" | path exists)
  let content = (open "custom-output.template")
  assert str contains $content "## Context"
  
  # Cleanup
  cd -
  rm -rf $test_dir
}

# ─────────────────────────────────────────────────────────────────────────────
# build-prompt with custom template tests
# ─────────────────────────────────────────────────────────────────────────────

def "test build-prompt uses custom template when provided" [] {
  let custom_template = "Custom: {{session}} #{{iteration}} - {{spec}}"
  let spec_content = "My Spec Content"
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 7
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  # Pass empty string for extra_instructions, custom template for template
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state "" $custom_template)
  
  assert str contains $prompt "Custom: test-session #7 - My Spec Content"
}

def "test build-prompt uses default template when template not provided" [] {
  let spec_content = "# Test Spec"
  let store_path = "./.ralph/test-store"
  let name = "test-session"
  let iteration = 1
  let task_state = {completed: [], in_progress: [], blocked: [], remaining: []}
  
  # Omit optional parameters to use defaults
  let prompt = (build-prompt $spec_content $store_path $name $iteration $task_state)
  
  # Should contain default template markers
  assert str contains $prompt "## Context"
  assert str contains $prompt "## Tools"
  assert str contains $prompt "## Workflow"
}

run-tests
