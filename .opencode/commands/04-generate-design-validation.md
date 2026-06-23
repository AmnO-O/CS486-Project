---
description: Generate design validation report for the current ERD and schema registry.
---

Command: generate-design-validation

Description:
Run the `db-design-pipeline:04-design-validation` skill to produce a design validation report for the current ERD and schema registry, outputting `outputs/04-design-validation-G{{group}}.md`.

Usage:
```
generate-design-validation --group G05
```

Prompt:
  Validate the ERD and logical design for the Campus Space Management System, group G05.

  Input sources:  check the SKILL.md (`db-design-pipeline:04-design-validation`) for required inputs
  Output: `outputs/04-design-validation-G{{group}}.md`

Notes:
  - Use `--group G05` as the default group.
  - This command file defines the invocation interface only; the skill contains the task behavior.
  - If the file already exists, enhance the existing report with new insights or validations based on the current ERD and schema registry. If no new insights are available, append a note about the last validation date and any minor updates made.