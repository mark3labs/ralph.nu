# Custom Prompt Template

## Overview

Allow users to provide a custom prompt template instead of the hardcoded one in `build-prompt`. Default location: `.ralph.template` in project root. New `gen-template` subcommand outputs the default template. Optional `--template` flag on `build` specifies alternate template file.

## User Story

User wants to customize agent behavior, tone, or workflow without modifying ralph.nu source. Export default template as starting point, tweak to their needs, commit to repo.

## Requirements

### Template Location Discovery (priority order)
1. `--template <path>` flag on `main build` - explicit path
2. `.ralph.template` in project root - default custom location
3. Hardcoded template in `build-prompt` - fallback (current behavior)

### Template Variables
Template uses Nushell string interpolation placeholders:
- `{{session}}` - Session name
- `{{iteration}}` - Current iteration number
- `{{spec}}` - Full spec file content
- `{{inbox}}` - Formatted inbox section (empty string if none)
- `{{notes}}` - Formatted notes section (empty string if none)  
- `{{tasks}}` - Formatted task state
- `{{extra}}` - Extra instructions from `--extra-instructions` flag

### gen-template Subcommand
- `./ralph.nu gen-template` - Writes default template to `.ralph.template`
- `./ralph.nu gen-template --output <path>` - Writes to specified path
- Overwrites existing file without prompting
- Prints confirmation with output path

### build --template Flag
- `./ralph.nu build --template <path> --spec ./specs/foo.md`
- Template file must exist (error if not found)
- Takes precedence over `.ralph.template`

### Template Processing
- Read template file content
- Replace `{{variable}}` placeholders with computed values
- Preserve literal `{{` by escaping as `\{\{` in template (optional v1)

## Technical Implementation

### Default Template (extract from build-prompt)
```
## Context
Session: {{session}} | Iteration: #{{iteration}}
Spec: {{spec}}
{{inbox}}{{notes}}
## Task State
{{tasks}}

## Tools - all require session_name="{{session}}"
- inbox_list / inbox_mark_read(id) - check/ack messages
- task_add(content, status?) / task_status(id, status) / task_list - manage tasks
- note_add(content, type) / note_list(type?) - record learnings/tips/blockers/decisions
- session_complete - call when ALL tasks done

## Workflow
1. Check inbox, mark read after processing
2. Ensure all spec tasks exist in task list
3. Pick ONE task, mark in_progress, do work, mark completed
4. Run tests, commit with clear message
5. If stuck/learned something: note_add
6. When ALL done: session_complete("{{session}}")

Rules: ONE task/iteration. Test before commit. Call session_complete to end - do NOT just print a message.
{{extra}}
```

### New Constants
```nushell
const DEFAULT_TEMPLATE_PATH = ".ralph.template"

const DEFAULT_TEMPLATE = '## Context
Session: {{session}} | Iteration: #{{iteration}}
Spec: {{spec}}
{{inbox}}{{notes}}
## Task State
{{tasks}}

## Tools - all require session_name="{{session}}"
- inbox_list / inbox_mark_read(id) - check/ack messages
- task_add(content, status?) / task_status(id, status) / task_list - manage tasks
- note_add(content, type) / note_list(type?) - record learnings/tips/blockers/decisions
- session_complete - call when ALL tasks done

## Workflow
1. Check inbox, mark read after processing
2. Ensure all spec tasks exist in task list
3. Pick ONE task, mark in_progress, do work, mark completed
4. Run tests, commit with clear message
5. If stuck/learned something: note_add
6. When ALL done: session_complete("{{session}}")

Rules: ONE task/iteration. Test before commit. Call session_complete to end - do NOT just print a message.
{{extra}}'
```

### gen-template Subcommand
```nushell
def "main gen-template" [
  --output (-o): string = ".ralph.template"  # Output file path
] {
  $DEFAULT_TEMPLATE | save -f $output
  print-ok $"Template written to ($output)"
}
```

### Template Resolution Function
```nushell
# Resolve template: --template flag > .ralph.template > hardcoded default
def resolve-template [
  template_flag?: string  # Explicit --template path
] {
  if ($template_flag | is-not-empty) {
    if not ($template_flag | path exists) {
      error make {msg: $"Template file not found: ($template_flag)"}
    }
    return (open $template_flag)
  }
  
  if (DEFAULT_TEMPLATE_PATH | path exists) {
    return (open DEFAULT_TEMPLATE_PATH)
  }
  
  $DEFAULT_TEMPLATE
}
```

### Template Variable Substitution
```nushell
# Substitute {{variable}} placeholders in template
def apply-template [
  template: string
  vars: record  # {session, iteration, spec, inbox, notes, tasks, extra}
] {
  $template
    | str replace --all "{{session}}" $vars.session
    | str replace --all "{{iteration}}" ($vars.iteration | into string)
    | str replace --all "{{spec}}" $vars.spec
    | str replace --all "{{inbox}}" $vars.inbox
    | str replace --all "{{notes}}" $vars.notes
    | str replace --all "{{tasks}}" $vars.tasks
    | str replace --all "{{extra}}" $vars.extra
}
```

### Updated build-prompt Function
```nushell
def build-prompt [
  spec_content: string
  store_path: string
  name: string
  iteration: int
  task_state: record
  extra_instructions?: string
  template?: string  # New: template content (already resolved)
] {
  let state_text = (format-task-state $task_state)
  let inbox_messages = (get-inbox-state $store_path $name)
  let inbox_section = (format-inbox-for-prompt $inbox_messages)
  let notes = (get-note-state $store_path $name)
  let notes_section = (format-notes-for-prompt $notes $iteration)
  
  let inbox_block = if ($inbox_section | is-empty) { "" } else { $"\n($inbox_section)\n" }
  let notes_block = if ($notes_section | is-empty) { "" } else { $"\n($notes_section)\n" }
  let extra_block = if ($extra_instructions | default "" | is-not-empty) {
    $"\n\n## Additional Instructions\n($extra_instructions)"
  } else { "" }
  
  let template_content = $template | default $DEFAULT_TEMPLATE
  
  apply-template $template_content {
    session: $name
    iteration: $iteration
    spec: $spec_content
    inbox: $inbox_block
    notes: $notes_block
    tasks: $state_text
    extra: $extra_block
  }
}
```

### main build Updates
```nushell
def "main build" [
  # ... existing args ...
  --template (-t): string = ""  # Custom template file path
] {
  # ... existing setup ...
  
  # Resolve template once at start
  let template_content = (resolve-template (if ($template | is-empty) { null } else { $template }))
  
  # In iteration loop, pass template to build-prompt
  let iteration_prompt = (build-prompt $spec_content $store $name $n $task_state $extra $template_content)
  # ...
}
```

### Update main Usage
Add to usage output:
```
  ./ralph.nu gen-template [--output <path>]

SUBCOMMANDS
  gen-template  Write default prompt template to file

BUILD OPTIONS
  --template, -t          Custom template file (default: .ralph.template if exists)
```

## Tasks

### 1. Extract hardcoded template to constant
- [ ] Create `DEFAULT_TEMPLATE` constant with current template string
- [ ] Create `DEFAULT_TEMPLATE_PATH` constant (`.ralph.template`)
- [ ] Ensure template uses `{{variable}}` syntax instead of Nushell interpolation

### 2. Implement template variable substitution
- [ ] Add `apply-template` function with str replace for each variable
- [ ] Handle all variables: session, iteration, spec, inbox, notes, tasks, extra

### 3. Implement template resolution
- [ ] Add `resolve-template` function
- [ ] Check --template flag first (error if specified but not found)
- [ ] Check .ralph.template exists second
- [ ] Fall back to DEFAULT_TEMPLATE

### 4. Add gen-template subcommand
- [ ] Add `def "main gen-template"` function
- [ ] Add `--output` flag with default `.ralph.template`
- [ ] Write DEFAULT_TEMPLATE to file
- [ ] Print confirmation message

### 5. Update build-prompt to use templates
- [ ] Add optional `template` parameter
- [ ] Replace hardcoded string with apply-template call
- [ ] Ensure backward compatibility (null template uses default)

### 6. Add --template flag to main build
- [ ] Add `--template (-t): string = ""` parameter
- [ ] Call resolve-template at session start
- [ ] Pass resolved template to build-prompt in loop

### 7. Update usage/help text
- [ ] Add gen-template to subcommands list
- [ ] Add --template to build options
- [ ] Add example for gen-template

### 8. Add tests for template functionality
- [ ] Test apply-template substitutes all variables
- [ ] Test resolve-template priority order
- [ ] Test gen-template creates file
- [ ] Test build with custom template

### 9. Update README documentation
- [ ] Add gen-template subcommand to usage section
- [ ] Add --template flag to build options
- [ ] Document .ralph.template file and template variables
- [ ] Add example of customizing prompt template

## UI Mockup

```
$ ./ralph.nu gen-template
  ✓ Template written to .ralph.template

$ ./ralph.nu gen-template --output ./my-templates/custom.template
  ✓ Template written to ./my-templates/custom.template

$ ./ralph.nu build --spec ./specs/foo.md
# Uses .ralph.template if exists, else hardcoded default

$ ./ralph.nu build --spec ./specs/foo.md --template ./my-template.txt
# Uses specified template file

$ ./ralph.nu build --spec ./specs/foo.md --template ./missing.txt
Error: Template file not found: ./missing.txt
```

## Out of Scope (v1)

- Template validation / linting
- Escape sequences for literal `{{`
- Template inheritance / includes
- Per-spec templates
- Template caching
- Interactive template editing

## Open Questions

None - requirements clarified.
