---
description: >
  Generate meaningful SQL queries for Task 07 Query Design.
  Each query answers a real business question derived from the Campus Space
  Management System requirements.
---

Command: generate-query-design

Description:
Run the `db-design-pipeline:07-generate-query-design` skill to generate
`outputs/07-query-design-G05.sql` from the approved schema and sample data.

Usage:
```bash
generate-query-design --group G05
```

Input sources:
Check the SKILL.md (`db-design-pipeline:07-generate-query`) for required inputs.

Output: `outputs/07-query-design-G05.sql`

Requirements:
- Each query must answer a meaningful business question.
- Each query must follow the 4-field template (see skill).
- All queries must be valid T-SQL and executable against `CS486_G05`.
- Use parameterized DECLARE blocks — no hardcoded literals in logic.
- Do not modify prior artifacts.

Notes:
- Use `--group G05` as default.
- Task behavior is defined in the skill.
- Overwrite the output file if it already exists.