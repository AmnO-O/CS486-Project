---
description: Run Task 10 - Phase 2 schema migration for the Campus Space Management System.
---

Command: generate-schema-migration

Description:
Run the `db-design-pipeline:10-schema-migration` skill to generate
`outputs/10-schema-migration-G05.sql`, a SQL Server migration delta that upgrades
the approved Phase 1 baseline (`outputs/05-db-definition-G05.sql`) to the current
approved Phase 2 schema described by Task 09 and the registries.

Task 10 is an implementation task for schema migration only. It translates the
approved Task 09 design into T-SQL DDL, data-preserving migration steps, seed rows,
trigger replacements, indexes, and validation queries. It must not redesign the
schema, resolve Task 11 concurrency decisions, implement Task 12 procedures, build
Task 14 data generation, tune Task 15 indexes, or write Task 16 analytical queries.

Usage:
```bash
generate-schema-migration
generate-schema-migration --group G05
generate-schema-migration --group G05 --mode overwrite
generate-schema-migration --group G05 --mode revise
```

Arguments:
  --group G05       Group identifier. Default: G05.
  --mode <mode>     Write mode for `outputs/10-schema-migration-G{{group}}.sql`.
                    - overwrite: replace the whole Task 10 output
                    - revise: update the existing Task 10 output after re-reading
                      all current sources and explaining what changed
                    Default: overwrite.

Prompt:
  Generate the Task 10 schema migration for the Phase 2 extension of the Campus
  Space Management System, group {{group}}.

  Input sources:
  - `docs/README.md` and `memory/MEMORY.md` for required reading order
  - `memory/Progress.md` and `memory/ActiveContext.md` for task status and open
    question gates
  - `docs/project_phase2_description.md` (authoritative Phase 2 source)
  - `docs/templates/README.md` for routing
  - `docs/design-decisions.md` (do not contradict)
  - `docs/tech-stack.md` for SQL Server and naming conventions
  - `outputs/05-db-definition-G{{group}}.sql` (Phase 1 baseline implementation)
  - `outputs/06-sample-data-G{{group}}.sql` (existing-data and validation context)
  - `outputs/08-requirement-change-analysis-G{{group}}.md` (Phase 2 analysis)
  - `outputs/09-updated-erd-and-logical-design-G{{group}}.md` (approved target design)
  - `docs/entity-registry.md` and `docs/schema-registry.md` (current source of truth)

  Output:
  - Write `outputs/10-schema-migration-G{{group}}.sql`.
  - Write the companion rollback script
    `outputs/10-schema-migration-G{{group}}-rollback.sql` that reverses every
    additive change (new columns, tables, constraints, triggers, seed rows), so a
    bad migration can be undone during testing.
  - The migration must be a data-preserving T-SQL delta from Task 05 to the current
    Task 09/registry target, not a full database rebuild.
  - Include verification SELECTs at the end so the migrated schema can be checked
    without relying on hardcoded sample row counts.

  Required content:
  0. Pre-migration audit: diff `outputs/05-db-definition-G{{group}}.sql` against
     `docs/schema-registry.md` table-by-table and column-by-column for every Phase 1
     object that the Task 09 target touches (tables, columns, nullability,
     PK/FK/UNIQUE/CHECK/DEFAULT, indexes, triggers). On any mismatch, STOP and
     report before generating migration SQL.
  1. Header and preflight comments naming baseline, target, and assumptions.
  2. Transactional migration body with `XACT_ABORT ON`.
  3. Idempotent guards for objects that may already exist.
  4. Data-preserving changes for every registry delta from Phase 1 to Phase 2.
  5. Seed/migration data required by the approved design, including guarded seed
     rows such as the reserved system approver if still present in the registries.
  6. Updated or new constraints, indexes, and triggers required by the current
     schema registry and Task 09 design.
  7. Validation queries for columns, tables, constraints, indexes, triggers, and
     Phase 2 business-rule smoke checks.
  8. A trajectory file under `logs/trajectory/task10/` before reporting completion.

  Do not:
  - hardcode a static migration list without first diffing the current baseline DDL
    against the current Task 09/registry target
  - proceed if `docs/design-decisions.md` lacks resolved answers for the three
    migration-critical decision points: the advisory-acknowledgement uniqueness
    shape, the instant-approval approver-identity design, and whether
    `spaces.current_status` stays trigger-maintained. Stop and report the exact gap.
  - add an `approval_source`/origin column to `booking_approvals` (rejected by
    Task 09 for 3NF) unless the current registries record a different decision
  - drop and recreate populated tables when `ALTER` or `CREATE` can preserve data
  - update `memory/Progress.md` or `memory/ActiveContext.md` without user approval
  - edit Task 08/09 outputs or the registries to make the migration easier
  - implement Task 11 concurrency design or later Phase 2 deliverables

Notes:
  - This command file defines the invocation interface only; the skill contains the
    behavior. Read the skill at
    `.opencode/skills/db-design-pipeline/10-schema-migration/SKILL.md`.
  - If Task 09 is not approved or directly relevant open questions for Task 10 are
    pending, stop before writing SQL and report the gate.
