---
description: Run Task 12 - Phase 2 concurrency implementation for the Campus Space Management System.
---

Command: generate-concurrency-implementation

Description:
Run the `db-design-pipeline:12-concurrency-implementation` skill to generate a SQL Server implementation of the
approved Task 11 concurrency design.

Task 12 is an implementation task. It translates the current approved concurrency
design into executable T-SQL entry points, normally stored procedures, while preserving
the Task 10 migrated schema and existing triggers. It must not redesign the
concurrency strategy, create Task 13 concurrent test scripts, build Task 14 data
generation, tune Task 15 indexes, or write Task 16 analytical queries.

Usage:
```bash
generate-concurrency-implementation
generate-concurrency-implementation --group G05
generate-concurrency-implementation --group G05 --mode overwrite
generate-concurrency-implementation --group G05 --mode revise
```

Arguments:
  --group G05       Group identifier. Default: G05.
  --mode <mode>     Write mode for `outputs/12-concurrency-implementation-G{{group}}.sql`.
                    - overwrite: replace the whole Task 12 output
                    - revise: re-read all current sources, compare with the
                      existing Task 12 output, then rewrite it coherently
                    Default: overwrite.

Prompt:
  Generate the Task 12 concurrency implementation for the Phase 2 extension of
  the Campus Space Management System, group {{group}}.

  Required reading:
  - Follow `AGENTS.md`, `docs/README.md`, and the main `db-design-pipeline`
    skill reading order first.
  - Read the Task 12 skill at
    `.opencode/skills/db-design-pipeline/12-concurrency-implementation/SKILL.md`.
  - Read current project state from memory, registries, Phase 2 requirements,
    approved upstream outputs, and the current Task 11 implementation handoff.
    Do not rely on stale hardcoded assumptions when a file has changed.

  Main input sources:
  - `memory/Progress.md` and `memory/ActiveContext.md` for task gates and handoff
  - `docs/design-decisions.md` (do not contradict)
  - `docs/tech-stack.md` (SQL Server and naming conventions)
  - `docs/entity-registry.md` and `docs/schema-registry.md` (current source of truth)
  - `outputs/10-schema-migration-G{{group}}.sql` and rollback (implemented Phase 2 schema)
  - `outputs/11-concurrency-design-G{{group}}.md` (approved Task 11 design and
    implementation handoff)

  Output:
  - Write `outputs/12-concurrency-implementation-G{{group}}.sql`.
  - Write a static or compile verification log under `logs/eval/task12/`.
  - Write a trajectory file under `logs/trajectory/task12/` before reporting completion.
  - Append to `docs/design-decisions.md` only if Task 12 discovers a key
    implementation decision not already recorded; otherwise leave it unchanged.

  Include:
  1. SQL settings and header naming the upstream files and no-schema-change promise.
  2. Preflight checks for the migrated schema, required triggers/indexes, system rows,
     and Task 11 dependencies.
  3. Idempotent `CREATE OR ALTER` implementation of every Task 11 entry point.
  4. Transaction-owned `sys.sp_getapplock` handling, if still selected by Task 11,
     with all return codes mapped exactly as Task 11 defines.
  5. Post-lock authoritative re-checks before every write.
  6. Deterministic result-code and message outputs.
  7. Non-concurrent smoke checks that prove procedures exist and basic success/error
     paths work without persisting test data.
  8. Verification instructions or actual `sqlcmd` compile results in `logs/eval/task12/`.

  Do not:
  - generate Task 13 two-session concurrency scripts
  - change tables, columns, keys, indexes, or triggers unless the approved Task 11
    design explicitly requires it
  - add an `approval_source` or stored origin column
  - tune performance indexes or record execution-plan timings
  - write Task 16 analytical queries
  - edit Task 08/09/10/11 outputs or registries to make the implementation easier
  - update `memory/Progress.md` or `memory/ActiveContext.md` without user approval

Notes:
  - Stop before writing SQL if Task 11 is not approved in `memory/Progress.md`, even
    if `outputs/11-concurrency-design-G{{group}}.md` exists.
  - The skill must adapt to current files: procedure names, result codes, selected
    lock mechanism, and handoff requirements come from the latest approved Task 11
    design, not from this command file.
