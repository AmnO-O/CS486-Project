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

Produce a reviewer-ready, executable SQL Server script implementing the approved
Task 11 concurrency design: database entry points that make booking confirmation and
maintenance impact-level changes concurrency-safe. Precise enough for Task 13 to run
concurrent-session tests, but it must not create those tests.

## Adaptive Source Rule

Re-read the current repo every run. Do not hardcode procedure names, result codes,
lock resources, trigger names, or the selected strategy unless the current approved
sources still define them.

Read, in order: `memory/Progress.md` (gates), `memory/ActiveContext.md` (handoff),
`outputs/11-concurrency-design-G{{group}}.md` (selected strategy, entry points,
result codes, workflow steps — the implementation contract), registries + Task 10
migration (tables/columns/indexes/triggers). If sources contradict each other, stop
and report the exact conflict.

Priority on conflict: `docs/design-decisions.md` > memory > Task 11 output > Task 10
migration > registries > Task 09 > Task 08 > phase-2 description > `docs/tech-stack.md`.

## Parameters

- `{{group}}` — group id; default `G05`.
- Entry-point count is NOT a Task 12 parameter — it comes from the Task 11 handoff
  (Task 11's `--max_concurrency`). Implement exactly the listed entry points: every
  one, none extra. If the handoff entry-point list is missing or ambiguous, stop and
  report the gap.

## Task Gates (before writing SQL)

- Tasks 08–11 approved in `memory/Progress.md`; Task 12 is next (unless explicit
  revise). **If the Task 11 output exists but memory still marks Task 11
  unapproved, stop and report the gate — never implement from an unapproved design.**
- No open question assigned to Task 12 is pending.
- `outputs/11-concurrency-design-G{{group}}.md` exists and contains a Task 12
  implementation handoff; `docs/design-decisions.md` does not contradict it.
- Do NOT update memory files (user approves first) and do NOT modify registries or
  prior task outputs.

## Outputs

- `outputs/12-concurrency-implementation-G{{group}}.sql` — SQL only; SQL comments for
  short explanations, no Markdown prose inside.
- `docs/design-decisions.md` — append ONLY when Task 12 introduces a key
  implementation decision not already recorded.
- `logs/eval/task12/YYYY-MM-DD-HHmm-12-concurrency-compile.log`
- `logs/trajectory/task12/YYYY-MM-DD-HHmm-trajectory.md`

## Implementation Scope

Implement:

- every database entry point named by the Task 11 handoff;
- the Task 11 concurrency mechanism, transaction boundary, lock acquisition order,
  isolation choice, timeout/deadlock handling, retry-facing codes, error contract;
- authoritative post-lock re-checks before every write;
- basic non-concurrent smoke checks proving compile + expected success/error behavior.

Do NOT implement: Task 13 two-session test scripts; Task 14 generator; Task 15 index
tuning or plan timings; Task 16 analytical queries; any schema redesign (new
tables/columns, stored origin column, version columns, performance indexes) unless
the Task 11 handoff explicitly says Task 12 must add them.

## Required Extraction (run-time inventory)

From current sources: entry-point names/parameters/result codes/workflow steps
(Task 11); confirmed booking status set (BR1/NR6); booking/approval/maintenance/
ack/impact-history table+column names; instant-origin model + system approver;
manual-closure and maintenance-blocking rules; ack-completeness rule; which triggers
are defense-in-depth only; indexes/constraints the procedures rely on;
session-context audit key. If a required item is absent from approved sources, stop
and report the gap.

## SQL Script Requirements

### Header, settings, preflight

Start each batch with `SET QUOTED_IDENTIFIER ON`/`SET ANSI_NULLS ON` + `GO`. Add a
comment header naming Task 12 + group, upstream Task 10/11 files, the selected
strategy, and the no-schema-change promise (unless Task 11 requires otherwise).

Before creating procedures, run reviewer-runnable preflight checks (THROW with
deterministic numbers ≥ 50000; do not reuse business result codes): required migrated
tables/columns exist; triggers/indexes used as defense-in-depth exist; reserved system
rows (e.g. approver `-1`) exist; Task 11 assumptions visible in the schema.

### Idempotency

Prefer `CREATE OR ALTER PROCEDURE dbo.<name>`; one procedure per `GO` batch; never
drop tables/triggers/indexes/data. Re-running must refresh bodies without duplicating
objects or changing data.

### Procedure shape (per entry point, unless sources require otherwise)

1. Validate lock-free inputs → 2. TRY/CATCH + explicit transaction → 3. acquire the
selected lock inside the transaction → 4. map lock timeout/cancel/deadlock returns
exactly per Task 11 → 5. re-read authoritative rows post-lock → 6. re-run all
invariant checks before DML → 7. DML → 8. COMMIT, return success code → 9.
deterministic business rejection: rollback + matching code → 10. unexpected error:
rollback + rethrow or Task 11's unexpected-error code.

If Task 11 selected `sp_getapplock`: `@LockOwner = 'Transaction'`, acquire after
`BEGIN TRANSACTION`, never release manually before COMMIT/ROLLBACK.

### Procedure-level checks

Generate from the Task 11 workflow (project shape usually includes: confirmed
booking overlap; active out-of-service maintenance overlap; ack completeness;
capacity; manual closed/retired space; instant eligibility; already-decided booking;
maintenance no-op/active-status). Triggers stay defense-in-depth only — procedures
must return deterministic codes before intentionally attempting DML that is known to
fail.

### Result-code contract

Extract codes from Task 11 and implement exactly: one code per rejection cause; do
not collapse timeout/cancellation/deadlock if Task 11 distinguishes them; return code
+ message through Task 11's parameter shape. Task 13 asserts on codes, not text.

### Session context

If Task 10/11 uses `SESSION_CONTEXT(N'current_user_id')`: set it at unit-of-work
start when an acting-user parameter exists, clear before returning, via TRY/CATCH so
cleanup runs on success and failure. If the design says it is solely an application
responsibility, preserve that and document in comments.

### Smoke checks (end of script, scratch-DB-safe, non-concurrent)

Verify procedures exist (+ metadata/parameter counts if feasible); exercise one
simple success path and one deterministic rejection path. **Do NOT wrap entry-point
calls in an outer transaction** — entry points own their transactions and ROLLBACK on
failure paths; a nested rollback rolls back the caller (N3). Call entry points
standalone, then explicitly delete created rows so nothing persists; verify no
confirmed booking overlaps remain. No Task 13 two-session scripts here.

## SQL Server Engineering Notes (proven during execution)

These stay valid regardless of which tables/columns/procedures/lock resources the
current sources define.

- **N1 — `EXEC @rc = <proc> <arg>` cannot take expressions as arguments.** Passing a
  computed argument inline (e.g. `N'prefix:' + CONVERT(NVARCHAR(16), @id)`) to
  `sys.sp_getapplock` through the `EXEC @return_var = proc` form fails to compile.
  Build the argument into a local variable first, then pass the variable.
- **N2 — Bare `THROW;` directly after a compound `BEGIN ... END` statement in a CATCH
  block is a parse error** (Msg 102), while the same pattern after a simple statement
  compiles. Fix: wrap the rethrow (e.g. `ELSE BEGIN THROW; END`). To pin such errors,
  compile minimal repro procedures on a scratch DB and rule out file encoding with an
  ASCII-stripped copy before blaming the parser.
- **N3 — A procedure that `ROLLBACK`s on failure rolls back the caller's outer
  transaction too (SQL 266 trap).** Nested rollback decrements the transaction count
  to zero → `Msg 266` on return. Options: (a) call entry points standalone and clean
  up rows explicitly — the project pattern; (b) `SAVE TRANSACTION` — but rolling back
  to a savepoint does NOT release a `@LockOwner = 'Transaction'` applock, so (b) must
  not be used on failure paths that rely on the applock.
- **N4 — Parser error line numbers are relative to the batch start, not the file.**
  To get clean numbers, extract the failing batch (plus the settings preamble) into a
  standalone `.sql` file and compile it alone.
- **N5 — Signature checks must count OUTPUT parameters too.** `sys.parameters`
  counts every parameter; verify the arithmetic before hardcoding a count into a
  smoke check — an off-by-one fails at runtime, not compile time.
- **N6 — Never rely on a column DEFAULT for business-meaningful values.** A raw
  INSERT omitting the column silently picks the default. Entry points controlling
  such a value must pass it explicitly in the INSERT column list and default the
  parameter to the safe value.
- **N7 — Audit/history triggers may be AFTER UPDATE only.** An AFTER-UPDATE history
  trigger produces no row on INSERT through a new entry point; if creation must be
  audited, do it explicitly in the procedure or negotiate a trigger change upstream
  (do not silently create triggers).
- **N8 — Idempotency re-run is the proof of `CREATE OR ALTER`.** Re-run the full
  script: procedures must refresh, smoke checks pass again, no duplicate objects.
  Do not judge success from truncated `sqlcmd` output (piping through truncating
  commands can close the stdout pipe early and mislead the exit code).

## Compile and Verify

When local SQL Server + `sqlcmd` are available, verify on a scratch database only
(never on a live/named baseline). Flow: create scratch DB → run
`outputs/05-db-definition-G{{group}}.sql` → `outputs/06-sample-data-G{{group}}.sql`
→ `outputs/10-schema-migration-G{{group}}.sql` → Task 12 script → re-run Task 12 for
idempotency → review smoke-check output.

If SQL Server is unavailable, static checks: file exists/non-empty; settings header
present; every Task 11 entry-point name appears; each procedure has explicit
transaction handling; the selected lock mechanism appears where required; Task 11
result codes appear unmerged; no `CREATE/ALTER TABLE`, `DROP`, `CREATE INDEX`, or
trigger recreation unless Task 11 required it; no Task 13 scripts. Record notes in
`logs/eval/task12/YYYY-MM-DD-HHmm-12-concurrency-compile.log`.

## Validation Checklist

- Task 11 approval gate passed; entry-point count matches the Task 11 handoff exactly.
- Every write workflow has a post-lock authoritative re-check.
- Procedures return the exact Task 11 codes; lock timeout/cancel/deadlock mapped per
  Task 11.
- No schema drift; Task 10 triggers untouched unless Task 11 required a change.
- Smoke checks safe: standalone calls (N3), created rows removed, nothing persists.
- Compile/static-verification log and trajectory file exist before any completion
  summary.

## Trajectory and Completion

Write `logs/trajectory/task12/YYYY-MM-DD-HHmm-trajectory.md` (evaluation template,
task number 12) BEFORE any user-facing summary. Then report: what was completed;
assumptions; verification performed or why not; end with the AGENTS.md prompt:

> _"Ready to mark Task X as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

with `X` = `12`.

## Idempotency

- Overwrite (default): re-read sources, replace the whole Task 12 output.
- Revise: re-read sources, compare against the current Task 11 contract, overwrite
  coherently.
- Never patch isolated SQL fragments while leaving stale procedure bodies elsewhere.