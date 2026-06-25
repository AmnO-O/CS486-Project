---
description: Generate SQL Server DDL from the approved logical schema.
---

Command: generate-ddl

Description:
Run the `db-design-pipeline:05-generate-ddl` skill to generate
`outputs/05-db-definition-G05.sql` from the approved schema artifacts.

Usage:

```bash
generate-ddl --group G05
```

Input sources:  
check the SKILL.md (`db-design-pipeline:05-generate-ddl`) for required inputs

Output: `outputs/05-db-definition-G{{group}}.md`

Requirements:

* Generate valid SQL Server DDL.
* Implement all approved tables, constraints, indexes, and triggers.
* Follow the locked schema registry.
* Preserve historical data requirements.
* Do not modify prior artifacts.

Notes:

* Use `--group G05` as default.
* Task behavior is defined in the skill.
* Overwrite the output file if it already exists.
