--- 
description: "Generate design validation report for the current ERD and schema registry."
---

Command: generate-design-validation

Description:
Run the `db-design-pipeline:04-design-validation` skill to produce a design validation report for the current ERD and schema registry, outputting `outputs/04-design-validation-G05.md`.

Usage:
```
generate-design-validation --group G05
```

Prompt:
  Validate the ERD and logical design for the Campus Space Management System, group G05.

  Input sources: check the SKILL.md (`db-design-pipeline:04-design-validation`) for required inputs.

  Output:
  - A markdown report suitable for `outputs/04-design-validation-G05.md`

If the file already exists, don't overwrite it. Instead, try to enhance the existing report with new insights or validations based on the current ERD and schema registry. If no new insights are available, you can append a note about the last validation date and any minor updates made.