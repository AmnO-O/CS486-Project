---
name: 06-sample-data
description: Generate Task 06 SQL Server sample data with valid seeds, expected-error proofs, execution evidence, and trajectory.
---

# Task 06 - Sample Data

## Goal

Create `outputs/06-sample-data-G05.sql`: a reviewer-ready T-SQL script that runs after `outputs/05-db-definition-G05.sql` and proves the schema supports normal workflows plus required exceptional cases. Do not change schema to make data fit.

## Source Of Truth

Resolve conflicts in this order:

1. `outputs/05-db-definition-G05.sql`
2. `docs/schema-registry.md`
3. `docs/entity-registry.md`
4. `outputs/01-business-req-analysis-G05.md`
5. `req/business-requirement.md`
6. `docs/project-overview.md`

Do not change the schema. If valid sample data cannot be produced without changing a table, column, constraint, trigger, or enum, stop and report the conflict.

## Required Reading

Read these project inputs before generating SQL:

- `req/business-requirement.md`
- `outputs/01-business-req-analysis-G05.md`
- `outputs/05-db-definition-G05.sql`
- `docs/entity-registry.md` as read-only
- `docs/schema-registry.md` as read-only

Then read these Task 06 references, in order:

1. `references/data-requirements.md`
2. `references/script-rules.md`
3. `references/validation-and-completion.md`

Do not silently skip a referenced file. If any required file is missing, stop and report the gap.

## Allowed Writes

- `outputs/06-sample-data-G05.sql`
- `logs/execution/task06/temp-execution-output.txt` during the current validation run
- `logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt`
- `logs/trajectory/task06/<YYYY-MM-DD-HHMM>-trajectory.md`
- `memory/Progress.md` and `memory/ActiveContext.md` only after user approval under the AGENTS post-task handshake

## Hard Boundaries

- Do not edit `docs/entity-registry.md`.
- Do not edit `docs/schema-registry.md`.
- Do not edit prior output artifacts.
- Do not invent tables, columns, enum values, triggers, or constraints absent from Task 05 DDL.
- Keep the final SQL file as SQL only. Use SQL comments, not Markdown prose.
- Do not mark Task 06 complete with uncovered coverage items or missing execution evidence unless execution is blocked and documented.

## Reference Responsibility Map

Avoid copying the same checklist across files. Use the references this way:

- `data-requirements.md` defines **what must be proved** from the business requirements and from the Task 05 DDL.
- `script-rules.md` defines **how to write SQL proof cases** safely and repeatably.
- `validation-and-completion.md` defines **how to reject incomplete proof** before and after execution.

Some overlap is intentional only at handoff points: the proof matrix named in
`data-requirements.md` must be audited by `validation-and-completion.md`, and
expected-error SQL mechanics from `script-rules.md` must appear in the execution
log checks. Do not add BR-specific fixes to this file when a generic DDL-derived
rule belongs in a reference file.

## Workflow

1. Read the required inputs and identify all locked table names, columns, constraints, triggers, enum values, identities, and FK dependencies from Task 05 DDL.
2. Build a DDL-derived coverage inventory from this `SKILL.md` and all Task 06 references. Every mandatory item needs a planned proof owner before SQL generation. The inventory must include each table, FK, CHECK, UNIQUE, filtered index, trigger branch, trigger side effect, enum/status value, and lifecycle transition discovered in Task 05 DDL; do not rely only on BR numbers.
3. Plan valid seed rows and expected-error cases from `references/data-requirements.md`.
4. Choose and document an idempotence strategy before writing inserts, cleanup, lookup capture, temp fixtures, or expected-error cases.
5. Write the SQL using `references/script-rules.md` for style, FK order, trigger-aware lifecycle steps, and isolation.
6. Save `outputs/06-sample-data-G05.sql`.
7. Run the static coverage audit from `references/validation-and-completion.md`; revise before execution if anything is uncovered.
8. Run `sqlcmd` after Task 05 DDL creates the database, using a temporary log first and then a final timestamped log.
9. Rerun after any fix affecting cleanup, idempotence, lookup capture, FK order, expected-error setup, or coverage evidence.
10. Write the trajectory after final SQL/log review, following `.opencode/skills/evaluations/trajectory-recording.md`, and record reruns, fixes, coverage counts, and blockers.

## Completion Gate

Task 06 is complete only when the SQL exists, the coverage inventory has `0` uncovered items, and final execution evidence is recorded. If SQL Server or `sqlcmd` is unavailable, record the blocker in trajectory and ask the user before updating memory.
