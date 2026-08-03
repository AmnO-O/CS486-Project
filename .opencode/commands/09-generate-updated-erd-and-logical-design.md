---
description: Run Task 09 — Phase 2 updated ERD and logical schema design for the Campus Space Management System.
---

Command: generate-updated-erd-and-logical-design

Description:
Run the `db-design-pipeline:09-updated-erd-and-logical-design` skill to produce
`outputs/09-updated-erd-and-logical-design-G05.md` — the updated ERD and logical
schema for the Phase 2 extension, plus the 3NF re-check.

Task 09 concerns ONLY the ERD and the logical schema. It designs the Phase 2
schema changes (entities, relationships, attributes, PK/FK, constraints, defaults,
indexes) on top of the Phase 1 baseline. It does NOT design the migration (Task
10), concurrency controls/mechanisms (Tasks 11–13), index tuning (Task 15), or the
analytical query implementations (Task 16).

If a Phase 2 requirement results in no ERD / logical-schema change, do not invent
one — leave that section with an explicit statement that no change is needed.

Usage:
```
generate-updated-erd-and-logical-design
generate-updated-erd-and-logical-design --req all
generate-updated-erd-and-logical-design --req 1
generate-updated-erd-and-logical-design --req 2
generate-updated-erd-and-logical-design --req 3
```

Scope (`--req`):
- No `--req`, or `--req all` → regenerate the whole file (all three areas) — create-or-overwrite.
- `--req 1` → maintenance impact levels + advisory acknowledgement + current_status.
- `--req 2` → concurrent/instant booking and approval (booking origin/pathway).
- `--req 3` → analytical reporting needs.
- Scoped run: overwrite that area's section in place if it exists; otherwise insert it
  so sections stay ascending 1, 2, 3 (above higher-numbered sections). Never duplicate.
- If a scoped requirement needs no ERD/logical change, write the no-schema-change
  statement in that section.

Prompt:
  Produce the updated ERD and logical schema design for the Phase 2 extension of the
  Campus Space Management System, group {{group}}, scope [all / 1 / 2 / 3].

  Input sources:
  - `docs/project_phase2_description.md` (authoritative Phase 2 source)
  - `outputs/08-requirement-change-analysis-G{{group}}.md` (Task 08 analysis)
  - `docs/entity-registry.md`, `docs/schema-registry.md` (Phase 1 baseline)
  - `docs/design-decisions.md` (do not contradict)
  - `outputs/02-erd-design-G{{group}}.md`, `outputs/03-logical-design-G{{group}}.md` (Phase 1 reference)

  Output:
  - Update `outputs/09-updated-erd-and-logical-design-G{{group}}.md` with the updated
    ERD excerpts and logical tables for the Phase 2 changes, plus a 3NF re-check.
    Only design ERD + logical schema. If a requirement causes no schema change, state
    that explicitly instead of fabricating a design.

  Include these sections per the skill (scope-adjusted):
  1. Overview (scope, what extends Phase 1)
  2. Section A — Area 1: Maintenance impact levels (impact_level, impact history,
     advisory acknowledgment, current_status handling)
  3. Section B — Area 2: Concurrent/instant booking and approval
  4. Section C — Area 3: Analytical reporting needs
  5. 3NF re-check
  6. Deviations from Phase 1 — business rules & related elements changed under the
     Phase 2 requirements (e.g., BR2/BR4/BR19), with their ERD/logical impact
  7. Resolved ambiguities (report each open question this task resolved — question →
     decision → where designed; carry forward the rest)
  8. Assumptions / unresolved ambiguities
  9. Revision log

  Do not:
  - design or implement concurrency controls/mechanisms (Tasks 11–13), migration
    scripts (Task 10), index tuning (Task 15), or analytical queries (Task 16)
  - invent schema objects for a requirement that needs no ERD/logical change
  - generate shell commands or wrapper scripts
  - invent unsupported requirements
  - edit `outputs/` files other than the Task 09 output

Notes:
  - Default `--group G05`.
  - Default scope is all three areas when `--req` is omitted.
  - This command file defines the invocation interface only; the skill contains the
    behavior. Read the skill at
    `.opencode/skills/db-design-pipeline/09-updated-erd-and-logical-design/SKILL.md`.
  - Update `docs/entity-registry.md` and `docs/schema-registry.md` for affected
    entities (Maintenance, Bookings) per the registry protocol.
