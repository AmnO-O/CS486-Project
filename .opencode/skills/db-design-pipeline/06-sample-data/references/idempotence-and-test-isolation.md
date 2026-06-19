# Idempotence And Test Isolation

The Task 06 SQL must run successfully on a database that may already contain previous Task 06 sample data.

## Idempotence Requirement

Choose and document one idempotence strategy in SQL comments near the top of `outputs/06-sample-data-G05.sql`:

1. Cleanup-and-reseed
   - Delete only Task 06-owned rows, in reverse FK order.
   - Use stable natural keys or a Task 06 prefix/tag to identify rows created by the sample script.
   - Do not delete arbitrary user or team data that is not clearly owned by Task 06.

2. Guarded inserts/upserts
   - Use `IF NOT EXISTS` or `MERGE` keyed by stable natural keys such as department name, email, space code, facility name, and deterministic booking markers.
   - Re-select IDs after each guarded insert so later sections work whether the row was inserted now or already existed.

Prefer cleanup-and-reseed when the script owns a clearly identifiable dataset. Prefer guarded inserts when cleanup would risk deleting non-Task-06 data.

## Stable Identity Capture

- Never rely on temp tables populated only by successful fresh inserts.
- After every insert or guarded insert, populate lookup variables or temp mapping tables by querying stable natural keys from the base tables.
- Validate lookup variables before child inserts and expected-error tests.
- If a required lookup returns NULL, stop with a clear self-detected setup error before running expected-error cases.

Example pattern:

```sql
DECLARE @sample_space_id INT = (
    SELECT [space_id]
    FROM [dbo].[spaces]
    WHERE [space_code] = N'T06-CL-101'
);

IF @sample_space_id IS NULL
    THROW 51006, 'Task 06 setup failed: sample space T06-CL-101 was not found.', 1;
```

## Expected-Error Isolation

Each expected-error case must be isolated enough to prove its intended rule:

- Set up all prerequisite rows inside the same test section or reference stable rows that are guaranteed to exist after the idempotent seed phase.
- Check every required ID before the failing statement.
- Avoid expected-error tests that can fail earlier because `space_id`, `user_id`, `department_id`, or other FK values are NULL.
- For trigger tests, create a valid baseline row first, then perform the invalid transition or conflicting insert.
- For declarative constraint tests, choose inputs that avoid unrelated uniqueness or FK failures unless that specific constraint is the target.

## Captured Error Quality Gate

A caught error counts only if it matches the intended rule. After each `CATCH`, print both the expected case label and `ERROR_MESSAGE()`.

During log parsing, treat these as failures unless they are the intended target:

- `Cannot insert the value NULL`
- `conflicted with the FOREIGN KEY constraint`
- duplicate-key errors in a non-duplicate-key test
- setup errors from missing lookup rows

Duplicate-key errors are valid only for the duplicate business-key test. FK errors are valid only for an intentional FK constraint test.

## Rerun Validation

Validate the script in at least one of these modes:

- Run Task 05 DDL, run Task 06 once, then run Task 06 a second time against the same database.
- Or run Task 06 against a database that already contains prior Task 06 sample rows.

The second run must not produce unexpected valid-seed errors. Expected-error cases must still capture the intended rule-specific failures.
