#!/usr/bin/env nu

use std/assert
use mod.nu [run-tests, setup-test-store, teardown-test-store]

# Source ralph.nu to get access to functions
source ../ralph.nu

def "test apply-template substitutes all variables" [] {
  let template = '## Context
Session: {{session}} | Iteration: #{{iteration}}
Spec: {{spec}}
{{inbox}}{{notes}}
## Task State
{{tasks}}
{{extra}}'
  
  let vars = {
    session: "test-session"
    iteration: 42
    spec: "test spec content"
    inbox: "inbox content"
    notes: "notes content"
    tasks: "task list"
    extra: "extra instructions"
  }
  
  let result = (apply-template $template $vars)
  
  assert ($result | str contains "Session: test-session")
  assert ($result | str contains "Iteration: #42")
  assert ($result | str contains "Spec: test spec content")
  assert ($result | str contains "inbox content")
  assert ($result | str contains "notes content")
  assert ($result | str contains "task list")
  assert ($result | str contains "extra instructions")
}

def "test resolve-template returns default when no files exist" [] {
  # Make sure no .ralph.template exists
  rm -f .ralph.template
  
  let result = (resolve-template)
  
  # Should return the DEFAULT_TEMPLATE constant
  assert ($result | str contains "## Context")
  assert ($result | str contains "{{session}}")
  assert ($result | str contains "{{iteration}}")
}

def "test resolve-template uses .ralph.template if exists" [] {
  # Create a test template file
  "TEST TEMPLATE {{session}}" | save -f .ralph.template
  
  let result = (resolve-template)
  
  assert equal $result "TEST TEMPLATE {{session}}"
  
  # Cleanup
  rm .ralph.template
}

def "test resolve-template prefers explicit flag over .ralph.template" [] {
  # Create both files
  "DEFAULT FILE" | save -f .ralph.template
  "EXPLICIT FILE {{session}}" | save -f /tmp/test-template.txt
  
  let result = (resolve-template "/tmp/test-template.txt")
  
  assert equal $result "EXPLICIT FILE {{session}}"
  
  # Cleanup
  rm .ralph.template
  rm /tmp/test-template.txt
}

def "test resolve-template errors on missing explicit file" [] {
  let result = (try {
    resolve-template "/nonexistent/file.txt"
    "no error"
  } catch { |e|
    $e.msg
  })
  
  assert ($result | str contains "not found")
}

def "test gen-template creates default file" [] {
  # Cleanup any existing file
  rm -f .ralph.template
  
  # Run gen-template subcommand
  main gen-template
  
  # Check file exists and has content
  assert (.ralph.template | path exists)
  let content = (open .ralph.template)
  assert ($content | str contains "## Context")
  assert ($content | str contains "{{session}}")
  
  # Cleanup
  rm .ralph.template
}

def "test gen-template custom output path" [] {
  # Cleanup
  rm -f /tmp/custom-template.txt
  
  # Run gen-template with custom output
  main gen-template --output /tmp/custom-template.txt
  
  # Check file exists
  assert (/tmp/custom-template.txt | path exists)
  let content = (open /tmp/custom-template.txt)
  assert ($content | str contains "## Context")
  
  # Cleanup
  rm /tmp/custom-template.txt
}

run-tests
