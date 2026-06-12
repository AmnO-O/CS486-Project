> ⚠️ This is a CS486 academic project. Do NOT rely on general SQL training knowledge
> for project conventions — follow `docs/` strictly.

## Project context
- **Course**: CS486 – Introduction to Database System
- **Group**: G05 | **Domain**: Campus Space Management System
- **Pipeline**: 7-task DB design (business req → ERD → logical → validation → DDL → data → queries)

## Always read at session start
1. `docs/README.md` → required reading order for current task
2. `memory/MEMORY.md` → scan, open only entries relevant to current task

## Hard rules (never violate)
- **NO skipping tasks** — pipeline runs 01 → 07 in strict order
- **NO generating output** without reading the relevant skill + template first
- **NO contradicting** any entry in `docs/design-decisions.md` — raise conflicts, do not silently override
- **NO editing** `outputs/` files directly — only via generate commands
- **NO finalizing** a task without running the evaluation command after

## Operation rules
- After each task: update `memory/Progress.md` and `memory/ActiveContext.md`
- After a key design decision: append to `docs/design-decisions.md` immediately
- If a business rule is ambiguous: refer to `req/business-requirement.md`, do not assume

## Quick reference
| Need | File |
|---|---|
| Workflow & checklist per task | `docs/db-design-pipeline.md` |
| Entities & attributes | `docs/entity-registry.md` |
| Relational schema | `docs/schema-registry.md` |
| Past design decisions | `docs/design-decisions.md` |
| Current task state | `memory/ActiveContext.md` |
| Task progress | `memory/Progress.md` |
| Skill + templates | `.opencode/skills/db-design-pipeline/SKILL.md` |