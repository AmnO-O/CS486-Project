# Business Rule Proofs

The script must contain intentional negative test cases for the most important constraints and triggers. Every expected failure must:

- Be clearly marked with `-- Expected error: ...`.
- Explain which business rule or constraint is being tested.
- Use `BEGIN TRY / BEGIN CATCH` so the full script can continue.
- Print the captured error message.
- Ensure the captured error demonstrates the intended rule, not a setup failure from missing lookup data, NULL IDs, duplicate seed rows, or unrelated FK cascades.

## Setup Discipline

Before every negative case, ensure prerequisite IDs and baseline rows exist. Use stable natural-key lookups populated from base tables, not temp tables that only contain freshly inserted rows. 

## Required Negative Cases

1. BR1 overlap prevention
   - Attempt to insert or update an `approved` booking that overlaps an existing `approved`, `checked_in`, or `completed` booking for the same space.

2. BR2 unavailable-space prevention
   - Attempt to create a booking for a space with status `under_maintenance`.
   - Attempt to create a booking for a space with status `retired`.
   - If data includes `temporarily_closed`, include that case too.

3. BR3 capacity prevention
   - Attempt to create a booking where `expected_participants` exceeds the selected space capacity.

4. BR4 unresolved-maintenance prevention
   - Attempt to create a booking that overlaps an `open` or `in_progress` maintenance window.

5. BR6 approval metadata validation
   - Attempt to transition a `pending` booking to `approved` or `rejected` without required `approver_id`, `decision_time`, or `decision_note`.

6. BR7 rejection reason validation
   - Attempt to reject a booking without `rejection_reason`.

7. BR8/BR9 check-in and completion validation
   - Attempt to transition to `checked_in` without `actual_start_time`, `checked_in_by`, or `initial_condition`.
   - Attempt to transition to `completed` without `actual_end_time` or `final_condition`.

8. Declarative constraint examples
   - Invalid enum value for one status or purpose column.
   - Invalid time range where `requested_end_time <= requested_start_time`.
   - Duplicate business key such as duplicate `users.email` or duplicate `spaces.space_code`.

9. BR11/BR13 historical preservation evidence
   - Include valid sample rows with `is_deleted = 1` for booking or maintenance history.
   - Verify these rows remain queryable and are not physically deleted.

10. BR12 audit trail evidence
   - Include verification queries showing `created_at` and `updated_at` are populated on inserted rows.

11. BR14 reporting evidence
   - Include verification queries for booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

