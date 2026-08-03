---
description: Run Task 08 — Phase 2 requirement-change analysis for the Campus Space Management System.
---

Command: generate-requirement-change

Description:
Run the `db-design-pipeline:08-requirement-change-analysis` skill to generate `outputs/08-requirement-change-analysis-G05.md` from the Phase 2 source and Phase 1 baseline.

Usage:
```
generate-requirement-change --group G05
```

Prompt:
  Generate a requirement-change analysis for the Phase 2 extension of the Campus
  Space Management System, group G05.

  Input sources:
  - `docs/project_phase2_description.md` (authoritative Phase 2 source)
  - `docs/project-overview.md` (Phase 2 scope summary)
  - `docs/entity-registry.md`, `docs/schema-registry.md` (Phase 1 baseline, read-only)
  - `outputs/01-business-req-analysis-G05.md` (Phase 1 baseline)

  Output:
  - A single markdown document suitable for `outputs/08-requirement-change-analysis-G05.md`

  Include these sections:
  1. Phase 2 change summary (maintenance impact levels, concurrent/instant booking
     & approval, new reporting needs)
  2. Affected entities
  3. Affected relationships
  4. Affected business rules and new-rule interactions
  5. Possible concurrency conflicts from simultaneous booking and approval
  6. Assumptions / unresolved ambiguities

  Do not:
  - generate shell commands or wrapper scripts
  - design or finalize the Phase 2 schema, migration, or concurrency solution
  - invent unsupported requirements
  - edit the registries or any Phase 1 output

Notes:
  - Use `--group G05` as the default group.
  - This command file defines the invocation interface only; the skill contains the task behavior.
  - Overwrite `outputs/08-requirement-change-analysis-G05.md` if it already exists.