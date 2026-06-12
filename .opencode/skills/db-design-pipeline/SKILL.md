---
name: db-design-pipeline
description: >
  MANDATORY — load this skill before executing any of the 7 CS486 deliverables.
  Triggers when user runs /generate-* or /evaluate commands, or asks to generate
  business requirement analysis, ERD, logical design, design validation, DDL,
  sample data, or SQL queries for the Campus Space Management System.
---

# DB Design Pipeline Skill

## Before ANY task — required reading sequence
1. `docs/README.md` → determine which files to read for this task
2. `memory/MEMORY.md` → scan, open relevant memory files
3. `docs/design-decisions.md` → never contradict past decisions
4. Task-specific template in `templates/<task-number>-<task-name>/`

## Quality standards
- Entities and attributes → must match `docs/entity-registry.md` exactly
- Table names and columns → must match `docs/schema-registry.md` (task 03+)
- Naming → follow `docs/tech-stack.md` conventions
- Ambiguity → refer to `req/business-requirement.md`, never assume

## After ANY task — required actions
1. Save output to `outputs/<task>-G05.<ext>`
2. Run `file-evaluation.md` on the output
3. Update `memory/Progress.md`
4. Update `memory/ActiveContext.md`
5. If a key design decision was made → append to `docs/design-decisions.md`

