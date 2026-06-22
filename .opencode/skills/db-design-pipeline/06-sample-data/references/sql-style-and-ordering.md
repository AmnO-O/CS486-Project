# SQL Style And Ordering

## SQL Style

- Use valid T-SQL for SQL Server 2019+.
- Start with a clear header comment naming the project, group, task, and dependency on Task 05 DDL.
- Use `SET NOCOUNT ON;`.
- **Mandatory Configuration: Use `SET QUOTED_IDENTIFIER ON;` right after the header. This is strictly required by SQL Server when inserting or updating data in tables that have Filtered Indexes.**
- Use `GO` between major sections when useful
- Use bracketed identifiers consistently with Task 05 DDL, such as `[dbo].[bookings]`.
- Avoid relying on unknown identity values.
- Re-select identity values from base tables after guarded inserts or cleanup/reseed, so reruns and pre-existing rows populate the same lookup variables.
- Prefer lookup variables populated by stable natural keys:

```sql
DECLARE @cs_department_id INT = (
    SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science'
);
```

- Keep inserted values deterministic and reviewable.
- Make the script idempotent: it must either clean up Task 06-owned rows before reseeding or guard every insert/upsert with stable natural keys.
- Use realistic dates that make status semantics clear:
  - past dates for `completed` and `no_show`
  - current or in-progress dates for `checked_in`
  - future dates for `pending` and `approved`
- Include a mandatory "Assumptions and Design Decisions" comment block after the header and before SECTION 1. Cover: date-range rationale, space-status coverage, maintenance concurrency, soft-delete choices, FK-safe ordering, idempotence strategy, and the rationale behind specific expected-error test cases. This block explains sample-data-level choices only — **do not duplicate schema-level design decisions** (those belong in `docs/design-decisions.md` with the proper template).
- Do not mix prose or Markdown into the SQL file. Inline SQL comments are allowed and encouraged.

## Insert Order

Follow FK dependency order:

1. Insert `departments`.
2. Insert `users`.
3. Insert `spaces`.
4. Insert `facilities`.
5. Insert `space_facilities`.
6. Insert `maintenances`.
7. Insert valid `bookings`.
8. Run expected-error test cases.

## Trigger-Aware Ordering

- Insert active maintenance rows before negative BR4 tests.
- Do not insert valid approved bookings against unavailable spaces.
- Ensure valid approved, checked-in, and completed bookings do not overlap on the same space.
- For `checked_in` and `completed` data, insert initially in a valid non-transition state if needed, then update with all required fields together so transition triggers pass.
- For `rejected` sample rows, set `status = 'pending'` first if needed, then update to `rejected` with complete decision metadata and rejection reason so transition triggers pass.
- Avoid using unavailable spaces for valid bookings unless the booking status and trigger behavior make it safe. Prefer valid bookings on `available` or `in_use` spaces.

## Idempotent Insert Patterns

- Use stable Task 06-specific natural keys where possible, such as deterministic emails, space codes, facility names, and booking titles or notes.
- Implement your chosen idempotence strategy (Cleanup-and-reseed or Guarded inserts) strictly following the specific rules and logic defined in `references/idempotence-and-test-isolation.md`.

## Common Mistakes To Avoid

- Writing a non-idempotent script that fails on rerun with duplicate keys.
- Hardcoding identity values that break when seed order changes.
- Inserting child rows before parent rows.
- Using enum labels from prose requirements instead of locked lowercase enum values in DDL.
- Creating valid sample bookings on `under_maintenance`, `temporarily_closed`, or `retired` spaces.
- Creating overlapping valid approved bookings before the negative-test section.
- Forgetting that status transition triggers require metadata when moving to `approved`, `rejected`, `checked_in`, or `completed`.
- Making expected-error cases plain `INSERT` statements that abort the script.
- Editing `docs/schema-registry.md` or `docs/entity-registry.md` during Task 06.

