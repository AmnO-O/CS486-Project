---
description: Run Task 04 — validate logical schema against ERD and business requirements
---

Execute Task 04 — Design Validation following the process and criteria defined in the `04-design-validation` skill.

Group: ${1:-G05}

Required inputs:
- outputs/01-business-req-analysis-${1:-G05}.md
- outputs/02-erd-design-${1:-G05}.md
- outputs/03-logical-design-${1:-G05}.md
- docs/entity-registry.md
- docs/schema-registry.md

Requirement: complete all 5 evaluation criteria and all 11 steps defined in the skill, and output the report to `outputs/04-design-validation-${1:-G05}.md`.

If any of the inputs above is missing, stop and report exactly which file was not found — do not guess or fabricate replacement content.
Notes:
  - Use `--group G05` as the default group.
  - This command file defines the invocation interface only; the skill contains the task behavior.
  - If the file already exists, enhance the existing report with new insights or validations based on the current ERD and schema registry. If no new insights are available, append a note about the last validation date and any minor updates made.