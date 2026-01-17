## Feature Specifications

Feature specs are stored in the `specs/` directory. See `specs/README.md` for the index.

### When to Create a Spec

- New features that require design decisions
- Features with multiple components or integration points
- Work that benefits from upfront planning before implementation

### Spec Format

Each spec should include:
- **Overview** - What the feature does
- **User Story** - Who benefits and why
- **Requirements** - Detailed requirements gathered from stakeholders
- **Technical Implementation** - Routes, components, data flow
- **Tasks** - Byte-sized implementation tasks (see below)
- **UI Mockup** - ASCII or description of the interface
- **Out of Scope** - What's explicitly not included in v1
- **Open Questions** - Unresolved decisions for future discussion

### Tasks Section

Break implementation into small, sequential tasks an AI agent can complete one per iteration:
- Each task should be completable in a single focused session
- Tasks should be ordered by dependency (earlier tasks unblock later ones)
- Use checkbox format: `- [ ] Task description`
- Group related subtasks under numbered headings
- Each task should have clear success criteria implicit in description
- Aim for 5-15 tasks depending on feature complexity

Example:
```markdown
## Tasks

### 1. Create basic skeleton
- [ ] Create file with main function signature
- [ ] Add CLI argument parsing

### 2. Implement core feature
- [ ] Add helper function X
- [ ] Add helper function Y
- [ ] Wire helpers into main
```

### Spec Guidelines
- Make specs extremely concise. Sacrifice grammar for the sake of concision.

### Workflow

1. Create spec via interview process (gather requirements interactively)
2. Save to `specs/<feature-name>.md`
3. Update `specs/README.md` index table

## Testing

Test suite uses Nushell's `std/assert` module and a custom test framework in `tests/mod.nu`.

### Running Tests

Run all tests:
```bash
nu tests/run-all.nu
```

Run individual test file:
```bash
nu tests/prompt-template.nu
```

### Test Structure

Unit tests use `def "test ..."` naming pattern:
```nu
use std/assert
use mod.nu [run-tests]

def "test feature works" [] {
  let result = (my-function "input")
  assert equal $result "expected"
}

run-tests
```

Integration tests keep standalone structure with explicit setup/cleanup blocks.

### Test Helpers

`tests/mod.nu` provides:
- `run-tests` - Discovers and executes all `def "test ..."` functions
- `setup-test-store` - Creates temporary xs store for testing
- `teardown-test-store` - Cleans up test store and background jobs

## btca

When you need up-to-date information about technologies used in this project, use btca to query source repositories directly.

**Available resources**: nushell, xs, httpNu

### Usage

```bash
btca ask -r <resource> -q "<question>"
```

Use multiple `-r` flags to query multiple resources at once:

```bash
btca ask -r nushell -r xs -q "How do I integrate xs with Nushell?"
```
