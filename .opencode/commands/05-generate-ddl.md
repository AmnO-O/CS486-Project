---
description: Implement the database using SQL DDL with tables, keys, constraints, checks, and default values where appropriate.
---

Use skill in:

- `.opencode/skills/db-design-pipeline/SKILL.md`
- `.opencode/skills/db-design-pipeline/05-generate-ddl/SKILL.md`

Required inputs:

- `outputs/01-business-req-analysis-G05.md`
- `outputs/02-erd-design-G05.md`
- `outputs/03-logical-design-G05.md`
- `outputs/04-design-validation-G05.md`
- `docs/schema-registry.md`

Business requirements may be consulted for clarification only:
* `req/business-requirement.md`
* `docs/project-overview.md`


Before generating SQL:
1. Read memory files in order:
   - `memory/Progress.md` → verify Task 04 status
   - `memory/ActiveContext.md` → check for blockers



2. Verify schema is locked:
   - Read `docs/schema-registry.md` — confirm all 7 tables.
   - Confirm all columns, PKs, FKs, and CHECK constraints are specified
  

4. If any dependency is missing, stop and report it.

Usage:
```
generate-ddl --group G05
```

- Use `--group G05` as the default group.

Generate:

* `outputs/05-db-definition-G05.sql`

After generation:

1. Validate output:
   - Check syntax: DDL must be valid T-SQL (SQL Server 2019+)
   - Verify naming convention matches `docs/tech-stack.md`
   - Verify all PK, FK, CHECK, UNIQUE constraints match schema-registry.md

2. Run evaluation (if available):
   - If `.opencode/evaluations/templates/05-ddl-eval.md` exists, use it
   - Or manually verify against rubric in `.opencode/evaluations/`