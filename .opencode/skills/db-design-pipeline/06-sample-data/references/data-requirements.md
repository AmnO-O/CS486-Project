# Data Requirements

Every bullet here is mandatory coverage inventory unless it explicitly says "when practical". Map each item to a seed section, expected-error case, verification query, execution log marker, trajectory entry, or declared blocker.

## DDL-Derived Proof Matrix

Before choosing sample rows, derive a proof matrix from `outputs/05-db-definition-G05.sql`. Do not rely only on this reference's named BR list. Every table, constraint, unique index, FK, trigger, and lifecycle status transition in the DDL must have a planned proof owner or an explicit blocker.

### Required DDL Inventory Rows

Create one coverage row for each item below when it exists in Task 05 DDL. Use
the DDL object name or exact trigger message in the row ID so future schema
changes automatically create new audit targets instead of requiring hardcoded BR
updates.

- `TABLE_SEED`: every permanent table in Task 05 DDL.
- `FK_JOIN`: every foreign key relationship and each junction/composite-key relationship.
- `CHECK_ENUM_VALUE`: every value inside a `CHECK (... IN (...))` enum, including status, role, type, purpose, and decision values.
- `CHECK_RULE_NEGATIVE`: every non-enum CHECK rule and each enum column category that needs an invalid-value proof.
- `NOT_NULL_REQUIRED`: every NOT NULL column without a default that is written by Task 06, plus any nullable column made mandatory by trigger logic.
- `UNIQUE_KEY`: every business-key or filtered unique index that enforces uniqueness.
- `UNIQUE_CHILD_FK`: every unique FK that implements a one-to-zero-or-one child table.
- `TRIGGER_RAISE_BRANCH`: every distinct `RAISERROR`/`THROW` branch in triggers, keyed by the exact message or constraint target.
- `TRIGGER_SIDE_EFFECT`: every trigger side effect that updates another row or status.
- `STATUS_TRANSITION`: every lifecycle state transition shown by trigger code, direct-update rule, or final status distribution.
- `AUDIT_UPDATE`: every `updated_at` auto-stamp trigger category selected for proof.

If a DDL row is intentionally not executable as sample data, mark it
`declared_blocker` with a reason. Do not collapse unrelated rows under one
generic "covered by script" entry.

For each DDL object, classify the proof using these reusable patterns:

- Declarative constraints (`CHECK`, `NOT NULL`, `UNIQUE`, filtered unique indexes): include valid seed data and at least one targeted expected-error proof for each distinct rule category. A caught error proves the item only when the failing statement targets that exact constraint/rule.
- Foreign keys and junction tables: seed parent rows first, then child rows; verify child counts or joins. Child rows without natural keys must be traceable through an owned parent row.
- Role-validated foreign keys: include one valid role workflow and one invalid-role expected-error case for every role-constrained FK discovered in triggers or the schema registry.
- Trigger-enforced lifecycle transitions: exercise the operation that fires the trigger (`INSERT` or `UPDATE`) and verify the pre-state and post-state. A row seeded directly in the final state does not prove the trigger.
- Trigger-enforced blocking rules: build a valid baseline, then perform the invalid operation that should fail. Verify the caught error is about the exact trigger branch or DDL object, not a missing lookup, NULL value, unrelated FK, or accidental duplicate. Each distinct DDL `RAISERROR`/`THROW` branch needs its own proof owner unless a single case intentionally executes multiple failing statements and labels each one separately.
- Trigger side effects: for every trigger that updates another table or status, include a verification query proving the side effect and, when the trigger has a guard condition, a separate proof that the guard prevents the side effect under the blocked condition.
- Audit/update triggers: include update-driven evidence for at least one stable parent table and at least one lifecycle child table. The proof must show `updated_at` changed because of an update, not only that default timestamps exist.
- Enumerated lifecycle values: final execution evidence must show every required enum/status value claimed as covered. A comment or trajectory claim is not coverage if the final distribution query omits the value.

Coverage is complete only when every proof-matrix row maps to exactly one primary proof owner: `seed_section`, `expected_error_case`, `verification_query`, `execution_log`, `trajectory_entry`, or `declared_blocker`.

## Valid Seed Coverage

- Departments: at least 4 rows, including `School of Computer Science` and at least two other university departments.
- Users: cover all roles (`student`, `lecturer`, `teaching_assistant`, `facility_staff`, `department_admin`, `facility_manager`), mixed statuses (`active`, `inactive`, `suspended`), and unique university-style emails.
- Spaces: cover all types (`auditorium`, `classroom`, `computer_lab`, `project_lab`, `meeting_room`, `student_workspace`) and all statuses (`available`, `in_use`, `under_maintenance`, `temporarily_closed`, `retired`) with varied building, floor, room, capacity, and policy values.
- Facilities: include Projector, Whiteboard, Microphone, Computer, Livestreaming Equipment, and Air Conditioner.
- Space facilities: assign multiple facilities to multiple spaces with positive quantities.
- Maintenances: cover `open`, `in_progress`, and `resolved`; include an active ticket for an `under_maintenance` space; include valid `assigned_staff_id` from a `facility_staff` user only; include realistic problems for broken projector, AC failure, damaged furniture, cleaning, and network issues.
- Historical preservation: include at least one soft-deleted booking or maintenance row and verify it remains queryable.
- Maintenance status restoration: include final-ticket restoration to `available`. If the DDL trigger contains a guard such as `NOT EXISTS` for concurrent active tickets, seed concurrent active tickets on the same space and verify both outcomes: resolving one active ticket does not restore the space while another active ticket remains, and resolving the last active ticket restores it. This must be proved through the DDL's lifecycle operation (for example, updating active maintenance rows to `resolved`) plus before/after verification; seeding only pre-resolved rows is insufficient.

## Booking Lifecycle Coverage

The current Task 05 schema stores request data in `bookings`, decisions in `booking_approvals`, and check-in/completion data in `booking_sessions`. Do not put approval or session metadata in `bookings`.

- `bookings`: cover all statuses (`pending`, `approved`, `rejected`, `cancelled`, `checked_in`, `completed`, `no_show`) and purposes (`lecture`, `examination`, `seminar`, `workshop`, `meeting`, `student_activity`, `administrative_event`).
- Include future approved bookings, past completed bookings, no-show rows, booking history, upcoming bookings, spaces under maintenance, and no-show reporting examples.
- Use dates that match lifecycle semantics: past for `completed` and `no_show`, current or in-progress for `checked_in`, and future for `pending` and `approved`.
- For lifecycle-relative rows, base dates on a single execution anchor such as `@now = SYSDATETIME()` and `DATEADD(...)`. Avoid fixed calendar literals for rows or reports whose meaning depends on "past", "current", "future", or "upcoming"; fixed dates are acceptable only for explicitly historical examples.
- Reach `approved` and `rejected` through `booking_approvals`; reach `checked_in` through `booking_sessions` insert; reach `completed` by updating the same `booking_sessions` row with completion fields.
- Create valid cancellation from `pending` or `approved` before updating to `cancelled`.
- For every lifecycle state shown in final distributions, record the operation that created it. Do not count a lifecycle state as covered if it was only inserted directly while the DDL provides a trigger or transition workflow for that state.
- `booking_approvals`: include at least one approved and one rejected row; populate `booking_id`, `approver_id`, `decision_time`, and `decision`; use `facility_staff` or `facility_manager` as approver; populate `rejection_reason` for rejected decisions; include useful `decision_note`; respect one approval per booking.
- `booking_sessions`: include at least one checked-in and one completed session; populate required start, checker, initial condition, completion, final condition, and usage notes as appropriate; use `facility_staff` or `facility_manager` for `checked_in_by`; insert only after approval; respect one session per booking.

## Required Negative Cases

Each negative case must use `-- Expected error: ...`, `BEGIN TRY / BEGIN CATCH`, a unique `EXPECTED_ERROR_CASE` marker, and an error message proving the intended rule rather than a missing lookup, NULL setup value, unrelated FK failure, or accidental duplicate.

The numbered cases below are domain coverage minimums. They do not replace the
DDL inventory. If Task 05 adds, removes, or rewrites a trigger branch,
constraint, enum value, or lifecycle transition, the DDL-derived row wins and
must be covered even when no BR number below names it.

1. BR1 overlap prevention: insert or update an `approved` booking overlapping an existing `approved`, `checked_in`, or `completed` booking for the same space.
2. BR2 unavailable-space prevention: for each unavailable status present (`under_maintenance`, `retired`, `temporarily_closed`), create or reuse a pending booking and attempt approval through `booking_approvals`; ensure the captured failure proves availability, not maintenance overlap, FK, NULL, or duplicate-key setup errors.
3. BR3 capacity prevention: exceed the selected space capacity.
4. BR4 unresolved-maintenance prevention: overlap an `open` or `in_progress` maintenance window.
5. BR6 approval metadata validation: derive the required approval columns from DDL (`NOT NULL` columns and trigger checks) and include targeted omission/NULL proofs for each required metadata category. A NOT NULL error is valid only for the targeted missing column.
6. BR7 rejection reason validation: reject without `rejection_reason`.
7. BR8/BR9 session validation: cover every session trigger branch discovered in DDL, including non-approved check-in, missing check-in condition, and missing completion condition when those messages/conditions exist. Treat missing NOT NULL session columns as declarative tests only when the targeted DDL object is the NOT NULL constraint, not a trigger branch.
8. BR11/BR13 historical preservation: verify soft-deleted booking or maintenance history remains queryable.
9. BR12 audit trail: verify `created_at` and `updated_at`; include at least one update-driven proof for a parent table and one lifecycle child table.
10. BR14 reporting: verify booking history, upcoming bookings, spaces under maintenance, and no-show bookings. Reporting predicates must match the report label: for example, "upcoming" must require a future requested start time, exclude soft-deleted rows, and exclude terminal or negative statuses that are not actionable future bookings.
11. BR15/BR16/BR17 role validation: invalid approver role, invalid check-in role, and invalid maintenance assignee role. `maintenance.assigned_staff_id` must be exactly `facility_staff`; `facility_manager` is invalid there.
12. BR18 cancellation validity: derive allowed and blocked predecessors from the DDL trigger. Include at least one valid cancellation for each allowed predecessor category that appears in sample data, and one invalid cancellation for each blocked lifecycle category that appears in final data or is explicitly listed by the status enum and feasible to fixture.
13. BR19 maintenance completion/status restoration: verify every trigger side-effect and guard branch discovered in the maintenance-completion trigger, including concurrent-active-ticket behavior when the DDL contains such a guard.
14. Declarative constraints: derive targets from DDL and include invalid enum, invalid range/numeric CHECK, duplicate business key or filtered unique index, and invalid junction quantity proofs whenever those objects exist.
15. One-to-zero-or-one child constraints: for each `UNIQUE` FK child table discovered in DDL, include one valid child row and one duplicate-child expected-error proof.
