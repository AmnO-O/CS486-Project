---
name: 10-schema-migration
description: >
  Generate the Task 10 Phase 2 schema migration script for the Campus Space
  Management System. The skill creates outputs/10-schema-migration-G05.sql as a
  data-preserving SQL Server delta from the Phase 1 Task 05 DDL baseline to the
  current approved Task 09 schema and registries. Triggers when the user runs
  /generate-schema-migration or asks to write the Phase 2 schema migration.
---

# Task 10 - Schema Migration (Phase 2)

## Goal

Produce a reviewer-ready, executable SQL Server migration script that upgrades an
existing Phase 1 database to the current approved Phase 2 schema without rebuilding
the database or losing historical data.

---

## Inputs

The global reading order lives in `db-design-pipeline/SKILL.md` (`Before ANY task —
required reading sequence`) and `docs/README.md`; follow it, then read the sources
this task's output depends on:

1. **Baseline — what is being changed:** `outputs/05-db-definition-G{{group}}.sql`
   (Phase 1 physical schema) and `outputs/06-sample-data-G{{group}}.sql` (data
   context and validation scaffold).
2. **Target — what it must become:** `outputs/09-updated-erd-and-logical-design-G{{group}}.md`
   (approved design) and `docs/schema-registry.md` (target relational objects).
3. **Binding — what constrains the output:** `docs/design-decisions.md` (locked
   decisions) and `memory/Progress.md` (Task 09 approval, task gates, open
   questions). Also read `outputs/08-requirement-change-analysis-G{{group}}.md` for
   the Phase 2 rationale.

Use `--group` if supplied; default to `G05`.

If a required file is missing (or a Task Gate below fails), stop and report the
exact gap. Never generate migration SQL from memory or guesses.

---

## Output

- `outputs/10-schema-migration-G{{group}}.sql`
- `outputs/10-schema-migration-G{{group}}-rollback.sql` — companion rollback script
  that reverses every additive change (new columns, tables, constraints, triggers,
  seed rows) so a bad migration can be undone during testing. Same style and
  idempotency guards as the migration itself.
- A trajectory file:
  `logs/trajectory/task10/YYYY-MM-DD-HHmm-trajectory.md`

The output is SQL only. Put explanations in SQL comments where useful, not in
Markdown prose outside comments.

---

## Task Gates

Before writing SQL, verify:

- Task 08 and Task 09 are approved in `memory/Progress.md`.
- Task 10 is the next unstarted Phase 2 task.
- No open question assigned to Task 10 is still pending in the "Known open questions
  (Phase 2)" table.
- `docs/design-decisions.md` does not conflict with the target registry.
- `docs/design-decisions.md` records resolved answers for the three
  migration-critical decision points:
  1. the advisory-acknowledgement uniqueness shape (composite vs single-column
     UNIQUE on `booking_advisory_acknowledgement`),
  2. the instant-approval approver-identity design (reserved system user vs
     nullable `approver_id` / stored origin column),
  3. whether `spaces.current_status` stays trigger-maintained or becomes a view.
  If any of these lacks a recorded answer, stop and report the exact gap — do not
  generate migration SQL on an undecided point.
- `docs/schema-registry.md` contains the Phase 2 target objects for Task 10.

If a gate fails, stop and report the exact blocking file and item.

Do not update `memory/Progress.md` or `memory/ActiveContext.md` after generation.
The user must approve first, per `AGENTS.md`.

---

## Source-of-Truth Priority

When sources conflict, use this priority:

1. `docs/design-decisions.md` for recorded decisions and tradeoffs.
2. `docs/schema-registry.md` for target relational objects.
3. `docs/entity-registry.md` for conceptual relationships and attributes.
4. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` for approved Task 09
   rationale and 3NF evidence.
5. `outputs/08-requirement-change-analysis-G{{group}}.md` for impact analysis.
6. `outputs/05-db-definition-G{{group}}.sql` for implemented Phase 1 baseline.
7. `req/business-requirement.md` and `docs/project_phase2_description.md` for
   resolving requirement wording only.

Do not edit a higher-priority source to fit the migration. If the migration exposes
a target-source mismatch, stop and report it.

---

## Delta Discovery Procedure

Before writing SQL, perform a schema-delta audit:

1. Parse or inspect the Phase 1 baseline DDL:
   - tables
   - columns and nullability
   - PK, FK, UNIQUE, CHECK, DEFAULT constraints
   - indexes
   - triggers
2. Extract the target schema from `docs/schema-registry.md` and Task 09:
   - all tables marked Phase 2 new or changed
   - changed columns on existing tables
   - changed business-rule enforcement objects
   - required seed rows or data migrations
3. Produce the internal delta list:
   - `ADD COLUMN`
   - `CREATE TABLE`
   - `ALTER/DROP/CREATE CONSTRAINT`
   - `CREATE/DROP INDEX`
   - `DROP/CREATE OR ALTER TRIGGER`
   - guarded seed rows
   - legacy-row backfill
4. Confirm each delta is justified by Task 09, the registry, or a design decision.
5. Exclude tasks that belong later:
   - Task 11: concurrency design choices and isolation strategy
   - Task 12: concurrency procedures/scripts beyond migration triggers
   - Task 14: bulk data generator
   - Task 15: performance-tuned indexes not already part of the target registry
   - Task 16: final analytical report queries

### Pre-migration audit — hard stop

Diff `outputs/05-db-definition-G{{group}}.sql` against `docs/schema-registry.md`
table-by-table and column-by-column for every Phase 1 object the delta touches
(tables, columns, nullability, PK/FK/UNIQUE/CHECK/DEFAULT, indexes, triggers). If
any object the migration depends on is missing, renamed, or typed differently in
the baseline than the registry documents it, **stop and report the mismatch before
writing any migration SQL**. Never generate a migration on an unverified baseline —
a wrong assumption about the baseline propagates into every delta statement.

The current approved target is expected to include, if still present in the files:

- `maintenance.impact_level` with default `'out-of-service'` and a CHECK over
  `'advisory'`, `'out-of-service'`.
- `maintenance_impact_history`.
- `booking_advisory_acknowledgement`.
- Guarded seed row for the reserved system approver (`user_id = -1`) if the registry
  still documents derived instant approvals through that row.
- Replacement of Phase 1 maintenance-blocking/status triggers so `out-of-service`
  blocks and `advisory` allows booking only when acknowledgements are present.

Treat this list as a checkpoint, not a substitute for reading the current files.

---

## Migration SQL Requirements

### Script header

The first SQL block must include:

```sql
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON;
GO
```

Then add a concise comment header naming:

- Task 10
- group
- baseline file
- target files
- data-preservation promise

### Idempotency

Use SQL Server catalog guards so the migration is safe to re-run during review:

- `IF COL_LENGTH('dbo.<table>', '<column>') IS NULL` before `ALTER TABLE ADD`.
- `IF OBJECT_ID('dbo.<table>', 'U') IS NULL` before `CREATE TABLE`.
- `IF OBJECT_ID('dbo.<trigger>', 'TR') IS NOT NULL DROP TRIGGER ...` before
  replacing triggers.
- `IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = ... AND object_id = ...)`
  before `CREATE INDEX`.
- Guard seed rows with stable natural keys or explicit IDs.

Idempotency must not hide drift. If an existing object has the same name but a
different definition, add a validation query/comment that surfaces the mismatch.

### Transaction strategy

Wrap the migration body in one explicit transaction where SQL Server allows it:

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    -- migration steps
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
```

Use separate `GO` batches where SQL Server requires them, especially around trigger
creation. Preserve transaction safety as much as SQL Server batching allows.

### Data preservation

- Never drop populated Phase 1 tables to implement a change.
- Do not delete existing bookings or maintenance rows.
- For new NOT NULL columns on existing populated tables, add a default or backfill
  in a way that preserves legacy semantics.
- Legacy active maintenance must retain Phase 1 blocking behavior unless Task 09 says
  otherwise. For the current design this means defaulting/backfilling to
  `'out-of-service'`.
- Seed rows must be guarded and must not disturb existing identity values after use.

### Constraint and object naming

Follow `docs/tech-stack.md`:

| Object | Pattern |
|---|---|
| Primary key | `PK_<table>` |
| Foreign key | `FK_<child>_<col>` |
| Unique | `UQ_<table>_<col>` or a readable composite name |
| Check | `CK_<table>_<rule>` |
| Default | `DF_<table>_<column>` |
| Index | `idx_<table>_<column>` |
| Trigger | `trg_<table>_<action>` |

Prefer deterministic names even when the Phase 1 DDL used inline unnamed defaults.

### Trigger rules

Only create or replace triggers required by the current registry or Task 09 design.

When replacing Phase 1 triggers:

- Drop the old trigger by name first.
- Create the replacement in its own batch.
- Keep `SET NOCOUNT ON;`.
- Preserve existing responsibilities unless Task 09 explicitly changes them.
- Do not implement Task 11 concurrency mechanisms here. The no-overlap invariant can
  keep existing baseline enforcement unless the registry states a Task 10 change.

Current Task 09 trigger behavior to derive from files, if still applicable:

- `trg_bookings_check_maintenance`: block overlapping active maintenance only when
  `impact_level = 'out-of-service'`; do not block `advisory`.
- Advisory acknowledgement enforcement: require rows in
  `booking_advisory_acknowledgement` for overlapping active advisory maintenance and
  validate each acknowledgement points to an advisory that overlaps the booking.
- `trg_maintenance_impact_history`: record active maintenance impact-level changes.
- `trg_maintenance_recompute_space_status` or equivalent: recompute
  `spaces.current_status` from active out-of-service maintenance, live sessions, and
  manual `retired` / `temporarily_closed` overrides, if the current registry calls
  for it.

If the target files do not name an exact trigger, choose a name that follows the
project convention and document the mapping in a SQL comment.

---

## Implementation Notes (verified during scratch-DB compile)

Validated patterns and T-SQL facts learned from compiling this task. Where a
choice exists, both options are listed with when-to-use guidance — prefer the
recommended option unless the target files justify the alternative.

### Audit-context mechanism for `changed_by` (e.g. `trg_maintenance_impact_history`)

| Option | When to use |
|---|---|
| `SESSION_CONTEXT(N'current_user_id')`, set via `EXEC sys.sp_set_session_context` (recommended) | SQL Server 2016+ (this project targets 2019+). Named key, no byte packing; `TRY_CAST(... AS INT)` returns NULL when unset/invalid → clean fallback to the reserved user `-1`. |
| `CONTEXT_INFO()` binary (pack/unpack `CONVERT(INT, SUBSTRING(@ctx,1,4))`) | Only if a consumer already depends on it or SESSION_CONTEXT is unavailable. Manual byte packing and big-endian assumptions are error-prone. |

Caveat for **both**: the mechanism is session-scoped, not transaction-scoped.
With connection pooling a reused connection may carry a stale context into
another user's work. Add a handoff note in the SQL header: the application
layer must set the key before each unit of work and clear it (set NULL)
afterwards; the trigger must still degrade safely (fallback row) when no
context is set.

### Recompute-trigger guard (e.g. `trg_maintenance_recompute_space_status`)

An `AFTER INSERT, UPDATE` recompute trigger may skip work when only irrelevant
columns changed:

- Guard on every column the trigger body reads. For the current registry that
  is `IF UPDATE(status) OR UPDATE(impact_level) OR UPDATE(start_time) OR UPDATE(completion_time) OR UPDATE(is_deleted)`.
- `is_deleted` is easy to forget but required — soft-deleting a ticket must
  still recompute.
- `UPDATE()` returns TRUE on INSERT (every column counts as updated), so the
  guard never suppresses the INSERT path.
- If the trigger recomputes from **other** tables (e.g. live sessions), a
  column guard is not sufficient — keep the guard only when the trigger reads
  the table's own columns.

### SQL Server batch-compile gotcha

`ALTER TABLE ... ADD <column>` followed by `ADD CONSTRAINT CHECK` in the same
batch fails to compile (`Msg 207 Invalid column name`). Write the constraints
inline in the single ADD statement:

```sql
ALTER TABLE dbo.<table> ADD <column> <type> NOT NULL
    CONSTRAINT DF_<table>_<column> DEFAULT (...)
    CONSTRAINT CK_<table>_<rule> CHECK (...);
```

### Smoke-test isolation under XACT_ABORT

Phase 1-style triggers abort the whole transaction with `ROLLBACK TRANSACTION`.
Under `SET XACT_ABORT ON` an expected-error sub-test inside a shared smoke
transaction also kills the happy-path checks. Run each expected-error sub-test
in its own `BEGIN TRANSACTION`/`ROLLBACK` pair with TRY/CATCH, and keep the
happy-path checks in one rolled-back transaction of their own.

### Idempotency re-run behavior

A preflight that hard-stops (`THROW`) when Phase 2 objects already exist makes
the mandated re-run (compile step e) fail by design. Instead:

- Preflight prints a WARNING and enters "re-run mode": additive steps guarded
  and skipped, triggers dropped + recreated.
- Every new/replaced trigger still needs a guarded `DROP` in the drop section
  (`IF OBJECT_ID(N'dbo.<trigger>', N'TR') IS NOT NULL DROP TRIGGER ...`),
  otherwise the re-run dies on `Msg 2714` (object already exists).

---

## Output Structure

Generate the SQL in this order:

1. Session settings and header.
2. Preflight checks:
   - required Phase 1 tables exist
   - Task 10 is not being run on an empty/non-baseline database
   - any required department/system-row dependency is satisfiable
3. Existing-trigger drops needed before changing dependent behavior.
4. Existing-table alterations.
5. New tables.
6. New or changed indexes.
7. Guarded seed rows and backfills.
8. Trigger creations/replacements.
9. Post-migration validation queries.
10. Final success print.

---

## Validation Queries

End the script with verification SELECTs that reviewers can run after migration:

- Confirm required Phase 2 tables exist.
- Confirm required Phase 2 columns exist with expected nullability/defaults.
- Confirm PK/FK/CHECK/UNIQUE constraints exist.
- Confirm required indexes exist.
- Confirm required triggers exist.
- Confirm legacy maintenance rows have non-null `impact_level`.
- Confirm the reserved system user exists if the current target still requires it.
- Include small smoke checks for advisory/out-of-service semantics where possible
  without depending on specific Task 06 row counts.

Do not include destructive cleanup in validation.

---

## Formatting Requirements

- T-SQL only.
- Use `[dbo].` prefixes in executable SQL for clarity.
- Separate batches with `GO`.
- Avoid bracketed identifiers unless helpful for consistency with existing scripts.
- Keep comments short and purposeful.
- Do not paste Markdown tables into SQL comments.
- Do not include shell commands inside the SQL output.

---

## Guardrails and Prohibitions

- Do not generate a full replacement DDL script. Task 10 is a migration delta.
- Do not skip reading the Task 10 skill, main pipeline skill, or required source
  files.
- Do not invent schema objects that are not supported by the registries, Task 09, or
  design decisions.
- Do not solve the pending Task 11 question U3 unless `memory/Progress.md` has moved
  it to Task 10 and records a final decision.
- Do not add performance indexes just because they seem useful. Save tuning for
  Task 15 unless the index is already in the target registry.
- Do not edit `outputs/05`, `outputs/08`, `outputs/09`, or registries during Task 10.
- Do not update progress memory without user approval.

---

## Compile and Verify (compile log)

After generating the SQL, attempt verification on a **scratch database** when a local
SQL Server is available. Never run the migration directly on a live or named baseline
database — build a throwaway copy:

| Mode | When | Syntax |
|------|------|--------|
| Windows Auth | Local/solo | `-E` |
| SQL Auth | Team server | `-U sa -P "$SA_PASSWORD"` |

Replace `<AUTH>` with either option below.

**a. Create a scratch database:**
```bash
sqlcmd -S localhost -C <AUTH> -Q "DROP DATABASE IF EXISTS CS486_G05_MIGTEST; CREATE DATABASE CS486_G05_MIGTEST;"
```

**b. Rebuild the Phase 1 baseline into the scratch DB (DDL + sample data):**
```bash
sqlcmd -S localhost -C <AUTH> -d CS486_G05_MIGTEST -i outputs/05-db-definition-G05.sql
sqlcmd -S localhost -C <AUTH> -d CS486_G05_MIGTEST -i outputs/06-sample-data-G05.sql
```

**c. Run the migration script:**
```bash
sqlcmd -S localhost -C <AUTH> -d CS486_G05_MIGTEST -i outputs/10-schema-migration-G05.sql
```

**d. Verify the migrated objects** — the script's validation SELECTs must return the
expected results, plus composite-UQ smoke checks:
- insert two acknowledgement rows for the same (booking, maintenance_id) → the second
  must be rejected by the composite UNIQUE;
- insert acknowledgements for the same booking against **different** maintenance
  IDs → both must succeed.

**e. Re-run the migration a second time** — must complete without error and without
duplicate objects (idempotency check).

**f. Run the rollback script** — must complete without error (the scratch DB may end
in a partially-reverted state; success = no error). If a step fails, fix the SQL,
drop the scratch DB, and retry from step (a).

If SQL Server is not available, still perform static checks:

- output file exists and is non-empty; rollback file exists and is non-empty
- first block contains the required settings (`SET QUOTED_IDENTIFIER`,
  `SET XACT_ABORT`)
- no Markdown prose outside SQL comments
- every `CREATE TRIGGER` is batch-separated with `GO`
- every new table/column from the target delta appears
- no `DROP TABLE` against Phase 1 tables
- no statements outside the confirmed delta list

Append execution or static-check notes to:

`logs/eval/task10/YYYY-MM-DD-HHmm-10-schema-compile.log`

---

## Trajectory and Completion

After writing or revising `outputs/10-schema-migration-G{{group}}.sql`, write the
trajectory file before any user-facing task-complete summary:

`logs/trajectory/task10/YYYY-MM-DD-HHmm-trajectory.md`

Use the evaluation trajectory template, adapting the task number to `10`.

Then summarize:

1. What was completed.
2. Assumptions made.
3. Verification performed or why verification could not run.
4. The exact prompt from `AGENTS.md`:

> _"Ready to mark Task X as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

Replace `X` with `10`.

---

## Idempotency

- Default mode: overwrite the full Task 10 output after re-reading current sources.
- Revise mode: re-read all current sources, compare the existing Task 10 output
  against the current target delta, then overwrite with a coherent revised script.
- Never patch isolated SQL fragments while leaving stale sections in place.
