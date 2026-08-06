---
description: Run Task 11 - Phase 2 concurrency design for the Campus Space Management System.
---

Command: generate-concurrency-design

Description:
Run the `db-design-pipeline:11-concurrency-design` skill to generate
`outputs/11-concurrency-design-G05.md`, a reviewer-ready design document for
preventing conflicting approved bookings under concurrent instant booking and
staff approval.

Task 11 is a design task. It resolves Task 11's relevant open questions, maps the
current Phase 2 schema and migration contract, evaluates SQL Server concurrency
control strategies, and selects the design that Task 12 will implement and Task 13
will test.


Usage:
```bash
generate-concurrency-design
generate-concurrency-design --group G05
generate-concurrency-design --group G05 --mode overwrite
generate-concurrency-design --group G05 --mode revise
generate-concurrency-design --group G05 --max_concurrency 4
```

Arguments:
  --group G05       Group identifier. Default: G05.
  --mode <mode>     Write mode for `outputs/11-concurrency-design-G{{group}}.md`.
                    - overwrite: replace the whole Task 11 output
                    - revise: re-read all current sources, compare with the
                      existing Task 11 output, then rewrite it coherently
                    Default: overwrite.
  --max_concurrency <n>
                    Maximum number of critical-section entry points the Task 11
                    design covers (2|3|4). Passed to the skill as
                    `--max_concurrency {{max_concurrency}}`.
                    - 4: all entry points — instant booking submit, staff approval,
                      maintenance escalation/downgrade, maintenance ticket creation.
                    - 3 (default): instant booking submit, staff approval,
                      maintenance escalation/downgrade. Maintenance ticket creation
                      is documented as out-of-scope residual risk.
                    - 2: instant booking submit and staff approval only. Maintenance
                      escalation/downgrade is also out-of-scope.
                    Default: 3.

Prompt:
  Generate the Task 11 concurrency design for the Phase 2 extension of the Campus
  Space Management System, group {{group}}, covering at most
  {{max_concurrency}} critical-section entry points.

  Required reading:
  - Follow `AGENTS.md`, `docs/README.md`, and the main
    `db-design-pipeline` skill reading order first.
  - Read the Task 11 skill at
    `.opencode/skills/db-design-pipeline/11-concurrency-design/SKILL.md`.
  - Read current project state from memory, registries, Phase 2 requirements, and
    approved upstream outputs. Do not rely on stale hardcoded assumptions when a
    file has changed.

  Main input sources:
  - `docs/project_phase2_description.md` (authoritative Phase 2 source)
  - `memory/Progress.md` and `memory/ActiveContext.md` (task gates and open questions)
  - `docs/design-decisions.md` (do not contradict)
  - `docs/tech-stack.md` (SQL Server and naming conventions)
  - `docs/entity-registry.md` and `docs/schema-registry.md` (current source of truth)
  - `outputs/08-requirement-change-analysis-G{{group}}.md` (conflict inventory)
  - `outputs/09-updated-erd-and-logical-design-G{{group}}.md` (approved Phase 2 design)
  - `outputs/10-schema-migration-G{{group}}.sql` and rollback, if Task 10 is
    approved or present (implemented contract and handoff notes)

  Output:
  - Write `outputs/11-concurrency-design-G{{group}}.md`.
  - Append Task 11 KEY design decisions to `docs/design-decisions.md` ONLY when a
    decision is actually made (resolved Task 11 open questions, selected concurrency
    strategy). Do NOT append revision-log, audit, or bookkeeping rows for
    regeneration, revision, or formatting runs — those are not decisions.
  - Write a static verification log under `logs/eval/task11/`.
  - Write a trajectory file under `logs/trajectory/task11/` before reporting completion.

  Do not:
  - implement Task 12 SQL procedures, triggers, migrations, or runnable scripts
  - create Task 13 two-session test files
  - tune indexes or record execution-plan timings
  - write Task 16 analytical queries
  - edit Task 08/09/10 outputs or registries to make the design easier
  - update `memory/Progress.md` or `memory/ActiveContext.md` without user approval

Notes:
  - Stop before writing the Task 11 output if a directly relevant Task 11 open
    question is still pending and no final decision was provided in the current turn.
  - The skill must adapt to current files: examples in the skill are guidance, not a
    substitute for re-reading the repository state.
