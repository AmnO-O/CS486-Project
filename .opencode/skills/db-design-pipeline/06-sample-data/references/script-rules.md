# Script Rules

## SQL Style

- Use SQL Server 2019+ T-SQL with bracketed identifiers matching Task 05 DDL, for example `[dbo].[bookings]`.
- Start with a header naming project, group, task, and dependency on Task 05 DDL.
- Put `SET QUOTED_IDENTIFIER ON;` and `SET NOCOUNT ON;` near the top. `QUOTED_IDENTIFIER` is required for tables with filtered indexes.
- Use `GO` between major sections when useful.
- Keep values deterministic and reviewable; do not hardcode identity values.
- Use stable `PRINT` markers for seed sections, expected-error cases, and verification queries.
- Use short coverage IDs in comments near the seed, expected-error, or verification evidence.
- Add an SQL comment block after the header explaining sample-data-level assumptions: date ranges, space-status coverage, maintenance concurrency, soft delete, FK-safe ordering, idempotence strategy, and expected-error rationale. Do not duplicate schema-level decisions from `docs/design-decisions.md`.
- Keep the output file SQL-only. SQL comments are fine; Markdown prose is not.

## Idempotence

Choose and document one strategy near the top of the SQL:

- Cleanup-and-reseed: delete only Task 06-owned rows in reverse FK order, using stable natural keys or a Task 06 prefix/tag. Account for `booking_approvals`, `booking_sessions`, and `space_facilities` before deleting parent rows. Never delete arbitrary team/user data.
- Guarded inserts/upserts: use `IF NOT EXISTS` or `MERGE` keyed by stable natural keys, then re-select IDs so reruns and pre-existing rows behave the same.

Prefer cleanup-and-reseed when the script owns a clearly identifiable dataset. Prefer guarded inserts when cleanup risks non-Task-06 data.

### Owned-Row Cleanup Contract

The cleanup strategy must define an ownership predicate for every table it deletes from. Use DDL-derived natural keys, such as a Task 06 prefix in business keys or a known sample email/domain, and propagate ownership to child tables through joins to owned parents.

Rules:

- Do not use unconditional `DELETE FROM [dbo].[<table>]` for any permanent table.
- Do not delete shared lookup/reference rows unless their own natural key is Task 06-owned. If a required display value is canonical rather than tagged, use guarded inserts/upserts and leave pre-existing rows in place.
- For child tables without natural keys, delete with `WHERE EXISTS` or joined `DELETE` through an owned parent row. Examples include approval/session rows through owned bookings and junction rows through owned spaces/facilities.
- For parent tables, restrict deletion by stable natural keys, not identity values or assumptions that the database contains only sample data.
- If a safe ownership predicate cannot be written for a table, switch that table to guarded inserts/upserts instead of cleanup-and-reseed.

Static audit must reject any permanent-table cleanup statement that lacks a row restriction (`WHERE`, joined `DELETE`, or `WHERE EXISTS`) tied to the stated ownership predicate.

## Stable Identity Capture

- After every insert, guarded insert, or cleanup/reseed, re-select IDs from base tables by stable natural keys.
- Never rely on temp tables populated only by successful fresh inserts.
- For child tables without natural keys (`booking_approvals`, `booking_sessions`), re-select IDs through their parent `booking_id`.
- Validate critical lookup IDs before child inserts and expected-error cases.
- If a required lookup is missing, throw a clear Task 06 setup error before negative tests run.

Example:

```sql
DECLARE @sample_space_id INT = (
    SELECT [space_id]
    FROM [dbo].[spaces]
    WHERE [space_code] = N'T06-CL-101'
);

IF @sample_space_id IS NULL
    THROW 51006, 'Task 06 setup failed: sample space T06-CL-101 was not found.', 1;
```

## FK And Trigger Order

Use this default order:

1. `departments`
2. `users`
3. `spaces`
4. `facilities`
5. `space_facilities`
6. `maintenance`
7. base `bookings`
8. `booking_approvals` for decisions
9. `booking_sessions` for check-in
10. update `booking_sessions` for completion
11. direct lifecycle updates for `cancelled`, `no_show`, and soft-delete examples
12. expected-error cases
13. verification queries

Trigger-aware rules:

- Insert active maintenance rows before BR4 tests, and do not approve valid bookings for unavailable spaces.
- Keep valid active bookings (`approved`, `checked_in`, `completed`) non-overlapping per space.
- Use `booking_approvals` for approved/rejected decisions and `booking_sessions` for check-in/completion.
- Insert a session before updating that same row with completion fields.
- Use direct `bookings.status` updates only for lifecycle states not represented by child tables, such as `cancelled` and `no_show`.
- Avoid unavailable spaces for valid bookings unless the status and trigger behavior make the row safe. Prefer `available` or `in_use` spaces for valid booking workflows.

## Expected-Error Isolation

- Set up prerequisites inside the case or reference stable rows guaranteed after the idempotent seed phase.
- Check required IDs before the failing statement.
- For trigger tests, create a valid baseline row first, then perform the invalid transition or conflicting insert.
- For lifecycle child-table tests, create the required parent state first: pending booking before approval tests, approved booking before session tests, and existing child rows before duplicate-child tests.
- For declarative tests, avoid unrelated uniqueness, FK, or NULL failures unless that exact constraint is the target.
- Roll back or explicitly clean up setup rows not meant to remain in valid sample data.
- Final row counts, status distributions, and reports must not be inflated by expected-error fixtures unless intentionally documented as valid seed data.
- Put `-- Expected error: <intended rule or constraint>` immediately before the failing statement. Name the DDL object, trigger, constraint, or rule category when practical.
- In `CATCH`, verify that `ERROR_MESSAGE()` matches the intended rule category when practical. A `PASS` printed for any arbitrary error is not acceptable evidence.
- Give every expected-error case a target object in a nearby comment or marker, such as `target: trg_booking_sessions_checkin / initial_condition branch` or `target: UQ_booking_approvals_booking_id`. The target must correspond to one DDL-derived proof-matrix row.
- Do not use one broad expected-error case to claim unrelated branches. If one case intentionally contains multiple failing statements, each failing statement needs its own `-- Expected error:` comment, pattern check, and PASS/FAIL marker so the execution log proves each target independently.
- When testing a trigger branch, match the exact DDL message fragment whenever SQL Server exposes it. When testing a declarative constraint, match the constraint name or the targeted column name.
- For state-transition triggers, write valid and invalid fixtures from the trigger's allowed/blocked predicates in DDL, not from memory. If the DDL says `d.status NOT IN (...)`, build blocked cases from the complement of that set in the current enum values.

Use this pattern when possible:

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%<intended message or constraint fragment>%';
    -- Setup rows used only by this expected-error case.
    -- Expected error: <intended rule or constraint>
    -- Failing statement goes here.
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: <case id> did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern
        PRINT 'PASS: <case id> - ' + ERROR_MESSAGE();
    ELSE
        PRINT 'FAIL: <case id> raised the wrong error - ' + ERROR_MESSAGE();
END CATCH
```

Treat caught errors as failures unless they match the intended target. NULL errors are valid only for explicit NOT NULL tests, duplicate-key errors only for duplicate-key tests, and FK errors only for intentional FK tests.

## Workflow Proof Rules

- A business rule enforced by a trigger is proved only by executing the operation that fires that trigger and checking the result or caught error.
- A lifecycle final state is proved only by its workflow operation. Directly inserting a row with a terminal status can support report data, but it does not satisfy trigger/lifecycle coverage.
- For every update-driven trigger selected for coverage, capture or query both the precondition and postcondition. The verification query must show the relevant state changed or intentionally did not change.
- For every role-gated workflow discovered in the DDL, include both a valid actor case and an invalid actor expected-error case. Derive allowed/blocked roles from the trigger/schema text, not from memory.
- For every one-to-zero-or-one child table discovered through a unique FK, include one valid child row and one duplicate-child expected-error case.
- For every trigger branch that raises an error, include a matching expected-error proof. For every trigger branch that performs an update, include a before/after verification query or PASS/FAIL block proving the update occurred.
- For trigger guards that intentionally suppress an update, include a negative side-effect proof: show the precondition, execute the guarded operation, and verify the protected state did not change.
- For every enum/status distribution claimed as complete, add a verification query whose result set lists all required values. Missing values in the final execution log must be treated as uncovered, even if the seed section comments claim coverage.

## Common Mistakes To Avoid

- Non-idempotent scripts, hardcoded IDs, child rows before parents, or enum labels not present in Task 05 DDL.
- Cleanup statements that delete permanent tables without a Task 06 ownership predicate.
- Valid bookings on `under_maintenance`, `temporarily_closed`, or `retired` spaces.
- Overlapping valid active bookings before the negative-test section.
- Directly updating `bookings.status` to `approved`, `rejected`, `checked_in`, or `completed` for rows intended to prove approval/session triggers.
- Counting a seeded final state as trigger coverage without executing the DDL operation that should produce it.
- Duplicate valid child rows for the same booking.
- Assigning `maintenance.assigned_staff_id` to a `facility_manager`.
- Plain failing inserts that abort the script instead of continuing through `TRY/CATCH`.
- Treating successful `sqlcmd` execution as completion without coverage and trajectory evidence.
- Marking a trigger branch, enum value, unique child FK, or guard condition as covered only in the trajectory without a corresponding SQL marker and execution-log proof.
- Editing `docs/schema-registry.md`, `docs/entity-registry.md`, or prior outputs during Task 06.
