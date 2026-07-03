---
description: Generate the logical schema design from the ERD and entity registry.
---

Command: generate-logical-design

Description:
Run the `db-design-pipeline:03-logical-design` skill to produce the logical
schema design from the entity registry, ERD, and business requirements.

Usage:
```
generate-logical-design --group G05
# or
generate-logical-design --group G05 --input-entity docs/entity-registry.md --output outputs/03-logical-design-G05.md
```

Read in this order before generating:
- `docs/entity-registry.md` — Entity Registry (required)
- `outputs/02-erd-design-G{{group}}.md` — ERD for reference (required)
- `outputs/01-business-req-analysis-G{{group}}.md` — Business rules (required)

Output: `outputs/03-logical-design-G{{group}}.md`

Also update:
- `docs/schema-registry.md` — add table definitions, FK wiring, indexes, 3NF proof
- `docs/entity-registry.md` — lock finalized names/types/constraints

Prompt:
  Generate the logical database design for the Campus Space Management
  System, group {{group}}. Follow the design rules in the skill at
  `.opencode/skills/db-design-pipeline/03-logical-design/SKILL.md`.

  Input sources:
  - `docs/entity-registry.md` — entity definitions, attributes, relationships
  - `outputs/02-erd-design-G{{group}}.md` — ERD for reference
  - `outputs/01-business-req-analysis-G{{group}}.md` — business rules

  Output:
  - A single markdown document written to `outputs/03-logical-design-G{{group}}.md`

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
  - This command file defines the invocation interface only; the skill
    contains the task behavior.
  - Read the skill definition in `.opencode/skills/db-design-pipeline/03-logical-design/SKILL.md`
    for the logical design rules.
  - Overwrite `outputs/03-logical-design-G05.md` if it already exists.
