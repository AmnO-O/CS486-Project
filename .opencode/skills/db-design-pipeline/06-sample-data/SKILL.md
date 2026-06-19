---
name: 06-sample-data
description: Generate SQL Server sample data for Task 06, including realistic valid seed data and documented expected-error cases.
---

# Task 06 — Sample Data Preparation Skill

## Goal

Create `outputs/06-sample-data-G05.sql`, a SQL Server sample-data script that proves the Task 05 schema can support the Campus Space Management System's normal workflows and important exceptional cases.

The script must be reviewer-ready, executable after `outputs/05-db-definition-G05.sql`, and useful as a foundation for Task 07 query design.

---

## Source of truth order

When sources conflict, resolve using this priority order:

1. `outputs/05-db-definition-G05.sql`
2. `docs/schema-registry.md`
3. `docs/entity-registry.md`
4. `outputs/01-business-req-analysis-G05.md`
5. `req/business-requirement.md`
6. `docs/project-overview.md`

Task 06 must not change the schema. If sample data cannot be made valid without changing a table, column, constraint, trigger, or enum, stop and report the conflict instead of editing registry or DDL artifacts.

---

## Required inputs

- `req/business-requirement.md`
- `outputs/01-business-req-analysis-G05.md`
- `outputs/05-db-definition-G05.sql`
- `docs/entity-registry.md` (read-only)
- `docs/schema-registry.md` (read-only)

---

## Output

- `outputs/06-sample-data-G05.sql`

No other deliverable file should be written for Task 06 except the required trajectory and allowed memory updates.

---

## Hard boundaries

- Do not edit `docs/entity-registry.md`.
- Do not edit `docs/schema-registry.md`.
- Do not edit any prior output artifacts.
- Do not invent tables, columns, enum values, triggers, or constraints that are not present in Task 05 DDL.

---

## Data coverage requirements

Generate realistic valid data for all locked tables:

1. `departments`
   - At least 4 departments.
   - Include the School of Computer Science and at least two other university departments for reporting variety.

2. `users`
   - Include all roles:
     - `student`
     - `lecturer`
     - `teaching_assistant`
     - `facility_staff`
     - `department_admin`
     - `facility_manager`
   - Include mixed account statuses: `active`, `inactive`, `suspended`.
   - Use unique university-style emails.

3. `spaces`
   - Include all space types:
     - `auditorium`
     - `classroom`
     - `computer_lab`
     - `project_lab`
     - `meeting_room`
     - `student_workspace`
   - Include all space statuses:
     - `available`
     - `in_use`
     - `under_maintenance`
     - `temporarily_closed`
     - `retired`
   - Include varied buildings, floors, room numbers, capacities, and usage policies.

4. `facilities`
   - Include realistic facility types from the requirements:
     - Projector
     - Whiteboard
     - Microphone
     - Computer
     - Livestreaming Equipment
     - Air Conditioner

5. `space_facilities`
   - Assign multiple facilities to multiple spaces.
   - Include valid positive quantities.

6. `maintenances`
   - Include `open`, `in_progress`, and `resolved` maintenance rows.
   - Include at least one active maintenance record for a space with `current_status = 'under_maintenance'`.
   - Include at least one row with `assigned_staff_id` populated by a valid facility staff or facility manager user.
   - Include realistic problem descriptions from the requirements: broken projector, air conditioning failure, damaged furniture, cleaning issues, network problems.
   - Include at least one soft-deleted maintenance row (`is_deleted = 1`) or pair this requirement with a soft-deleted booking row to demonstrate historical preservation.

7. `bookings`
   - Include all booking statuses:
     - `pending`
     - `approved`
     - `rejected`
     - `cancelled`
     - `checked_in`
     - `completed`
     - `no_show`
   - Include all booking purposes:
     - `lecture`
     - `examination`
     - `seminar`
     - `workshop`
     - `meeting`
     - `student_activity`
     - `administrative_event`
   - Include future approved bookings for upcoming-booking reports.
   - Include past completed bookings for history reports.
   - Include no-show rows for no-show reports.
   - Include rejected rows with approver, decision time, decision note, and rejection reason.
   - Include checked-in rows with `actual_start_time`, `checked_in_by`, and `initial_condition`.
   - Include completed rows with `actual_start_time`, `checked_in_by`, `initial_condition`, `actual_end_time`, `final_condition`, and `usage_notes`.
   - Include at least one soft-deleted booking row (`is_deleted = 1`) or pair this requirement with a soft-deleted maintenance row to demonstrate historical preservation.
   - Include rows that directly support staff reports:
     - booking history
     - upcoming bookings
     - spaces under maintenance
     - no-show bookings

---

## Business-rule proof requirements

The script must contain intentional negative test cases for the most important constraints and triggers. Every expected failure must:

- Be clearly marked with `-- Expected error: ...`
- Explain which business rule or constraint is being tested
- Use `BEGIN TRY / BEGIN CATCH` so the full script can continue
- Print the captured error message

Required negative cases:

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

---

## SQL style rules

- Use valid T-SQL for SQL Server 2019+.
- Start with a clear header comment naming the project, group, task, and dependency on Task 05 DDL.
- Use `SET NOCOUNT ON;`.
- Use `GO` between major sections when useful.
- Use bracketed identifiers consistently with Task 05 DDL, e.g. `[dbo].[bookings]`.
- Avoid relying on unknown identity values.
- Prefer lookup variables populated by stable natural keys:

```sql
DECLARE @cs_department_id INT = (
    SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science'
);
```

- Keep inserted values deterministic and reviewable.
- Use realistic dates that make status semantics clear:
  - past dates for `completed` and `no_show`
  - current/in-progress dates for `checked_in`
  - future dates for `pending` and `approved`
- Do not mix prose or Markdown into the SQL file. Inline SQL comments are allowed and encouraged.

---

## Insert-order rules

Follow dependency order:

1. Insert `departments`
2. Insert `users`
3. Insert `spaces`
4. Insert `facilities`
5. Insert `space_facilities`
6. Insert `maintenances`
7. Insert valid `bookings`
8. Run expected-error test cases

Important trigger-aware ordering:

- Insert active maintenance rows before negative BR4 tests.
- Do not insert valid approved bookings against unavailable spaces.
- Ensure valid approved/checked-in/completed bookings do not overlap on the same space.
- For `checked_in` and `completed` data, insert initially in a valid non-transition state if needed, then update with all required fields together so transition triggers pass.
- For `rejected` sample rows, set `status = 'pending'` first if needed, then update to `rejected` with complete decision metadata and rejection reason so transition triggers pass.
- Avoid using unavailable spaces for valid bookings unless the booking status and trigger behavior make it safe. Prefer valid bookings on `available` or `in_use` spaces.

---

## Validation checklist

Before finalizing `outputs/06-sample-data-G05.sql`, verify:

- [ ] All table and column names exist in `outputs/05-db-definition-G05.sql`.
- [ ] Insert order is FK-safe.
- [ ] Valid rows satisfy all CHECK constraints.
- [ ] Valid rows satisfy all triggers.
- [ ] No two valid active bookings overlap for the same space.
- [ ] Unavailable spaces are represented without invalid valid-booking rows.
- [ ] Every booking status appears at least once.
- [ ] Every booking purpose appears at least once.
- [ ] Every user role appears at least once.
- [ ] Every space type appears at least once.
- [ ] Every space status appears at least once.
- [ ] Every maintenance status appears at least once.
- [ ] At least one maintenance row has valid assigned staff.
- [ ] At least one booking or maintenance row demonstrates soft-delete/historical preservation.
- [ ] Every required negative case is marked with `-- Expected error: ...`.
- [ ] Negative cases are wrapped in `TRY/CATCH`.
- [ ] The script continues after expected failures.
- [ ] Verification queries cover audit timestamps and required reporting scenarios.
- [ ] The final file contains SQL only, no Markdown.
- [ ] No registry or prior output file was modified.

---

## Optional execution validation

If local SQL Server is available, run after Task 05 DDL:

```bash
sqlcmd -S localhost -C -E -d CS486_G05 -i outputs/06-sample-data-G05.sql
```

Review output for:

- No unexpected errors in valid seed sections
- Expected errors captured and printed in negative sections
- Verification queries returning nonzero row counts

If SQL Auth is required, follow the authentication convention already used for Task 05.

---

## Common mistakes to avoid

- Hardcoding identity values that break when seed order changes.
- Inserting child rows before parent rows.
- Using enum labels from the prose requirements instead of the locked lowercase enum values in DDL.
- Creating valid sample bookings on `under_maintenance`, `temporarily_closed`, or `retired` spaces.
- Creating overlapping valid approved bookings before the negative-test section.
- Forgetting that `status` transition triggers require metadata when moving to `approved`, `rejected`, `checked_in`, or `completed`.
- Making expected-error cases as plain `INSERT` statements that abort the script.
- Editing `docs/schema-registry.md` or `docs/entity-registry.md` during Task 06.

---

## Completion actions

After generating and validating the script:

1. Save `outputs/06-sample-data-G05.sql`.
2. Write a trajectory file under `logs/trajectory/task06/`.
3. Update `memory/Progress.md` to mark Task 06 complete.
4. Update `memory/ActiveContext.md` to set Task 07 as the next active task.
