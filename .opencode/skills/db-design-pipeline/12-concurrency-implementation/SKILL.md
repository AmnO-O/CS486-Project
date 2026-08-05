---
name: 12-concurrency-implementation
description: >
  Generate the Task 12 Phase 2 concurrency implementation SQL for the Campus Space
  Management System. The skill creates outputs/12-concurrency-implementation-G05.sql
  by reading the current approved Task 11 concurrency design and implementing its
  database entry points in SQL Server T-SQL. Use when the user runs
  /generate-concurrency-implementation or asks to implement the Phase 2 concurrency
  solution.
---

# Task 12 - Concurrency Implementation (Phase 2)

## Goal

Produce a reviewer-ready, executable SQL Server script that implements the current
approved Task 11 concurrency design.

Task 12 translates design into T-SQL. It must produce database entry points that
make booking confirmation and maintenance impact-level changes concurrency-safe. It
must be precise enough for Task 13 to run concurrent-session tests, but it must not
create those tests.

## Adaptive Source Rule

This skill must stay useful when project files change. Do not hardcode procedure
names, result codes, lock resources, trigger names, or selected strategy unless the
current approved sources still define them.

When generating the output:

- Extract task status and gates from `memory/Progress.md`.
- Extract active handoff notes from `memory/ActiveContext.md`.
- Extract the selected strategy, entry points, result codes, workflow steps, and
  non-negotiables from the current approved Task 11 output.
- Extract current tables, columns, indexes, triggers, and business-rule coverage
  from the registries and Task 10 migration.
- Treat examples in this skill as implementation patterns, not as replacement source
  material.

If the current files contradict one another, stop and report the exact conflict.

## Inputs and Source Priority

Follow the global reading order in `.opencode/skills/db-design-pipeline/SKILL.md` and
`docs/README.md`, then read the task-specific sources below.

1. `docs/project_phase2_description.md` - authoritative Phase 2 requirement source.
2. `outputs/10-schema-migration-G{{group}}.sql` and
   `outputs/10-schema-migration-G{{group}}-rollback.sql` - migrated schema and
   trigger contract.
3. `outputs/11-concurrency-design-G{{group}}.md` - approved Task 11 design, entry
   point list, workflow steps, result codes, and Task 13 handoff.
4. Existing `outputs/12-concurrency-implementation-G{{group}}.sql` only in
   `--mode revise`.

Use `--group` if supplied; default to `G05`.

When sources conflict, use this priority:

1. `docs/design-decisions.md` for recorded decisions.
2. `memory/Progress.md` for approval gates.
3. `memory/ActiveContext.md` for current handoff details.
4. `outputs/11-concurrency-design-G{{group}}.md` for Task 12 implementation contract.
5. `outputs/10-schema-migration-G{{group}}.sql` for implemented database objects.
6. `docs/schema-registry.md` for relational objects and business-rule coverage.
7. `docs/entity-registry.md` for conceptual relationships and attributes.
8. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` for schema rationale.
9. `outputs/08-requirement-change-analysis-G{{group}}.md` for conflict context.
10. `docs/project_phase2_description.md` and `req/business-requirement.md` for
    requirement wording.
11. `docs/tech-stack.md` for SQL Server syntax and naming.

Do not edit higher-priority sources to fit the implementation. If a mismatch blocks
generation, stop and report it.

## Output

- `outputs/12-concurrency-implementation-G{{group}}.sql`
- `logs/eval/task12/YYYY-MM-DD-HHmm-12-concurrency-compile.log`
- `logs/trajectory/task12/YYYY-MM-DD-HHmm-trajectory.md`
- `docs/design-decisions.md` only when Task 12 introduces a key implementation
  decision not already recorded.

The output is SQL only. Use SQL comments for short explanations. Do not include
Markdown prose inside the SQL file.

## Task Gates

Before writing SQL, verify:

- Tasks 08, 09, 10, and 11 are approved in `memory/Progress.md`.
- Task 12 is the next unstarted Phase 2 task, unless this is explicit `--mode revise`.
- No open question assigned to Task 12 is pending in the "Known open questions
  (Phase 2)" table.
- `outputs/11-concurrency-design-G{{group}}.md` exists and contains a Task 12
  implementation handoff.
- `docs/design-decisions.md` does not conflict with the Task 11 handoff.

Important: if Task 11 output exists but memory still marks Task 11 as not approved,
stop before writing SQL and report the gate. Do not implement from an unapproved
design.

Do not update `memory/Progress.md` or `memory/ActiveContext.md` after generation.
The user must approve first, per `AGENTS.md`.

## Implementation Scope

Task 12 must implement:

- Every database entry point named by the current approved Task 11 handoff.
- The selected SQL Server concurrency mechanism from Task 11.
- The Task 11 transaction boundary, lock acquisition order, isolation choice,
  timeout/deadlock handling, retry-facing result codes, and error contract.
- Authoritative post-lock re-checks before every write.
- Basic non-concurrent smoke checks proving the script compiles and the procedures
  expose expected success/error behavior.

Task 12 must not implement:

- Task 13 concurrent-session test scripts or folders.
- Task 14 data generator.
- Task 15 index tuning or execution-plan measurements.
- Task 16 analytical queries.
- Schema redesign, new tables, new columns, stored origin columns, version columns,
  or performance indexes unless the current approved Task 11 design explicitly says
  Task 12 must add them.

## Required Extraction

Before writing SQL, build an internal inventory from current files:

- Procedure or entry-point names, parameters, result-code outputs, and workflow steps
  from Task 11.
- Confirmed booking status set for BR1/NR6.
- Current booking, approval, maintenance, advisory acknowledgement, and impact-history
  table/column names.
- Current instant-origin model and system approver identity.
- Current manual-closure and maintenance-blocking rules.
- Current advisory acknowledgement completeness rule.
- Current trigger names and which ones are defense-in-depth only.
- Current required indexes and constraints the procedures rely on.
- Current session-context audit key, if any.

Write the SQL from this inventory. If a required item is absent from the approved
sources, stop and report the gap.

## SQL Script Requirements

### Header and settings

Start with SQL Server settings compatible with stored procedure creation:

```sql
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
```

Add a concise SQL comment header naming:

- Task 12 and group.
- Upstream Task 10 migration and Task 11 design files.
- The selected concurrency strategy discovered from Task 11.
- A no-schema-change promise, unless Task 11 explicitly requires otherwise.

### Preflight checks

Include reviewer-runnable preflight checks before procedure creation:

- Required migrated tables exist.
- Required columns exist.
- Required triggers/indexes used as defense-in-depth exist.
- Required system rows, such as a reserved system approver, exist when the approved
  design depends on them.
- Required Task 11 assumptions are visible in the schema.

Use `THROW` with deterministic numbers only for preflight failures. Avoid reusing
business result codes for script preflight unless Task 11 explicitly assigns them.

### Idempotency

Use idempotent creation:

- Prefer `CREATE OR ALTER PROCEDURE dbo.<procedure_name>` for procedures.
- Keep each procedure in its own `GO` batch.
- Do not drop tables, triggers, indexes, or existing data.
- Re-running Task 12 must refresh procedure bodies without duplicating objects or
  changing data.

### Stored procedure structure

For each Task 11 entry point, implement this shape unless current sources require a
different one:

1. Validate inputs that do not require locks.
2. Start a TRY/CATCH block and explicit transaction.
3. Acquire the selected lock inside the transaction.
4. Map lock timeout/cancel/deadlock return values exactly as Task 11 defines.
5. Re-read authoritative rows after the lock is acquired.
6. Re-run all workflow-specific invariant checks after the lock and before DML.
7. Perform DML.
8. Commit and return `0` or the current success code.
9. On deterministic business rejection, roll back and return the matching result code.
10. On unexpected error, roll back and rethrow or return the Task 11 unexpected-error
    code if one exists.

If Task 11 selected `sys.sp_getapplock`, use `@LockOwner = 'Transaction'`, acquire it
after `BEGIN TRANSACTION`, and do not release it manually before COMMIT/ROLLBACK.

### Procedure-level checks

Generate checks from the current Task 11 workflow. For the current project shape, this
usually includes:

- confirmed booking overlap check;
- active out-of-service maintenance overlap check;
- advisory acknowledgement completeness check;
- capacity check;
- manual closed/retired space check;
- instant eligibility check;
- already-decided booking check;
- maintenance no-op and active-status checks for impact-level changes.

Do not rely on triggers as the primary app-facing contract. Triggers remain
defense-in-depth; procedures must return deterministic codes before intentionally
attempting DML that is known to fail.

### Result-code contract

Extract result codes from Task 11 and implement them exactly:

- Each distinct rejection cause must have its own code.
- Do not collapse lock timeout, cancellation, and deadlock if Task 11 distinguishes
  them.
- Output result code and message through the parameter shape Task 11 defines.
- Task 13 will assert on codes, not free-text messages.

### Session context

If Task 10/11 uses `SESSION_CONTEXT(N'current_user_id')`, procedures should set it at
the start of the unit of work when an acting user parameter exists, and clear it before
returning. Use a TRY/CATCH pattern so cleanup happens on both success and failure.

If the current design says session context is solely an application responsibility,
preserve that contract and document it in comments instead of changing behavior.

### Smoke checks

End the SQL file with non-concurrent smoke checks that are safe to run on a scratch
database:

- Verify required procedures exist.
- Verify procedure metadata or parameters if feasible.
- Exercise at least one simple success path and one deterministic rejection path in
  transactions that roll back.
- Verify no confirmed booking overlaps exist after smoke checks.

Do not create Task 13 two-session scripts here. Do not leave smoke-test rows persisted.

## SQL Server Design Notes

- `CREATE OR ALTER PROCEDURE` must be the first statement in its batch after settings.
- `THROW` numbers must be 50000 or greater.
- `XACT_ABORT ON` helps roll back on runtime errors, but expected business rejections
  should still explicitly roll back and return deterministic output values.
- A trigger that raises an error may abort the transaction before procedure output
  parameters are set. Prefer procedure-level checks before DML so application-facing
  result codes are stable.
- `sys.sp_getapplock` returns non-negative values for success and negative values for
  failure. Map values according to the current Task 11 contract.
- If using `SESSION_CONTEXT`, remember it is session-scoped. Clear it on every exit
  path unless Task 11 explicitly assigns that responsibility to the caller.

## Compile and Verify

After writing SQL, attempt verification on a scratch database when local SQL Server
and `sqlcmd` are available. Never run Task 12 directly on a live or named baseline
database.

Typical scratch flow:

1. Create or recreate a scratch database.
2. Run `outputs/05-db-definition-G{{group}}.sql`.
3. Run `outputs/06-sample-data-G{{group}}.sql`.
4. Run `outputs/10-schema-migration-G{{group}}.sql`.
5. Run `outputs/12-concurrency-implementation-G{{group}}.sql`.
6. Re-run Task 12 SQL to prove idempotency.
7. Review smoke-check output.

If SQL Server is unavailable, perform static checks:

- Output file exists and is non-empty.
- Header settings are present.
- Required procedure names from Task 11 appear.
- Each procedure uses explicit transaction handling.
- Selected lock mechanism from Task 11 appears where required.
- Result codes from Task 11 appear and are not merged incorrectly.
- No `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE`, `CREATE INDEX`, or trigger recreation
  appears unless Task 11 explicitly required it.
- No Task 13 concurrent-session scripts are generated.

Record execution or static-check notes in:

`logs/eval/task12/YYYY-MM-DD-HHmm-12-concurrency-compile.log`

## Validation Checklist

Before finalizing, verify:

- Task 11 approval gate passed.
- Every Task 11 entry point is implemented once.
- Every write workflow has post-lock authoritative re-checks.
- Procedures return the exact Task 11 result codes.
- Lock handling maps timeout/cancel/deadlock exactly as Task 11 defines.
- No schema drift was introduced.
- Existing Task 10 triggers remain untouched unless Task 11 explicitly required a
  trigger change.
- Smoke checks are safe and rollback test rows.
- Compile/static verification log exists.
- Trajectory file exists before any completion summary.

## Trajectory and Completion

After writing or revising `outputs/12-concurrency-implementation-G{{group}}.sql`,
write the trajectory file before any user-facing task-complete summary:

`logs/trajectory/task12/YYYY-MM-DD-HHmm-trajectory.md`

Use the evaluation trajectory template, adapting the task number to `12`.

Then summarize:

1. What was completed.
2. Assumptions made.
3. Verification performed or why verification could not run.
4. The exact prompt from `AGENTS.md`:

> _"Ready to mark Task X as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

Replace `X` with `12`.

## Idempotency

- Default mode: overwrite the full Task 12 output after re-reading current sources.
- Revise mode: re-read all current sources, compare the existing Task 12 output
  against the current Task 11 contract, then overwrite with a coherent revised script.
- Never patch isolated SQL fragments while leaving stale procedure bodies elsewhere.
