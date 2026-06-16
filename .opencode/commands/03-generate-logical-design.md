---
description: Generate the logical schema design from the ERD and entity registry
---

Command: generate-logical-design

Description:
Run the `db-design-pipeline:03-logical-design` skill to generate `outputs/03-logical-design-G05.md` from `outputs/02-erd-design-G05.md` and `docs/entity-registry.md`.

Usage:
```
generate-logical-design --group G05
# or
generate-logical-design docs/entity-registry.md --group G05
```

Prompt:
  Generate the logical database design for the Campus Space Management System, group G05.

  Input sources:
  - `docs/entity-registry.md` (entity definitions, attributes, relationships)
  - `outputs/02-erd-design-G05.md` (ERD for reference)
  - `outputs/01-business-req-analysis-G05.md` (business rules and constraints)

  Output:
  - A single markdown document suitable for `outputs/03-logical-design-G05.md`

  Include these sections:
  1. Logical design overview
  2. Table definitions (one per entity)
     - Column definitions (name, data type, constraints, nullable)
     - Primary keys
     - Foreign keys
     - Unique and Check constraints
     - Default values
  3. Relationship mapping (ERD → logical tables)
  4. Index strategy
  5. Normalization proof (at least 3NF)
  6. Naming conventions applied
  7. Constraint implementation for business rules
  8. Deviations from ERD (if any) with justification

  Do not:
  - generate shell commands or wrapper scripts
  - modify prior artifacts (outputs/01 or 02)
  - invent constraints not justified by business rules
  - assume specific SQL Server features without compatibility notes

Notes:
  - Use `--group G05` as the default group.
  - This command file defines the invocation interface only; the skill contains the task behavior.
  - Overwrite output file if it already exists.
