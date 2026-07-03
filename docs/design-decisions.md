# Design Decisions — CS486 Database Schema

This document records the rationale behind key design choices made during the database design process.

## How to use this document

- During each task, record key decisions and trade-offs considered
- This becomes the reference for future revisions and group discussions
- Link each decision to the requirement or business rule it addresses

---

## Decision template

```markdown
### Decision: [Title]

**Task:** [1–7]
**Date:** YYYY-MM-DD

**Problem:** What challenge prompted this decision?
**Options considered:** 
- Option A: ... (pros/cons)
- Option B: ... (pros/cons)
**Decision:** We chose Option X because ...
**Impact:** How does this affect the rest of the schema?
**Requirement reference:** Which business rule(s) does this enforce?
```

---

## Recorded decisions

_(To be populated during Tasks 1–4.)_

> ⚠️ **DRAFT — NOT YET CONFIRMED.** The decisions below were drafted during the Planning phase as candidate rationale. They have **not** been verified against the actual requirements (`req/business-requirement.md`, `docs/project-overview.md`). Treat them as suggestions only — they become official **only** when worked on during their corresponding Task, verified against requirements, and their `Date:` field is filled in. Do not rely on them as locked decisions until then.

### Decision: Soft deletes for bookings and maintenance

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Bookings and maintenance records need to remain in the database for audit and reporting purposes, even after they are "deleted" by users.

**Options considered:**
- Option A: Hard delete — remove rows entirely (pros: simpler, smaller DB; cons: loses audit trail)
- Option B: Soft delete — mark with `is_deleted BIT` flag (pros: preserves history; cons: queries must always filter `WHERE is_deleted = 0`)

**Decision:** We chose soft delete because audit trail and reporting are likely business requirements in a facility booking system.

**Impact:** All queries querying bookings and maintenance must include `WHERE is_deleted = 0` filter (this can be documented in query templates).

**Requirement reference:** Business requirement likely includes "maintain booking history" — verify during Task 1.

---

### Decision: Incident reporting merged into Maintenance entity

**Task:** 2 (ERD Design)
**Date:** 2026-06-17

**Problem:** The business requirement lists "incident reporting" as a system capability, but does not define distinct attributes (e.g., severity, incident_type) that would differentiate an incident from a maintenance request.

**Options considered:**
- Option A: Separate `Incidents` entity — pros: dedicated table for incidents; cons: no distinct attributes to justify a separate table, overlaps with Maintenance
- Option B: Merge incidents into `Maintenance` entity — pros: avoids redundant table, captures all problem reports in one place; cons: cannot query incidents separately without filtering on `problem_description`

**Decision:** We chose Option B because no distinct attributes (severity, incident_type) differentiate incidents from maintenance requests in the current requirement. Incidents are captured via `problem_description` and `result_note` on the Maintenance entity.

**Impact:** If the requirement later defines distinct incident attributes, a separate `Incidents` entity should be created and documented here.

**Requirement reference:** `req/business-requirement.md` line 36 (incident reporting), `docs/project-overview.md` line 17

---

### Decision: Surrogate keys (INT IDENTITY) vs. business keys

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Primary key strategy for each table.

**Options considered:**
- Option A: Business keys only (e.g., `room_code` as PK) — pros: semantically meaningful; cons: harder to reference, longer FK columns
- Option B: Surrogate keys only (INT IDENTITY) — pros: small, efficient; cons: semantically opaque
- Option C: Hybrid — surrogate PK + unique business key — pros: best of both; cons: more storage

**Decision:** We chose hybrid (surrogate + business key unique constraint) because:
- Surrogate PKs are more efficient for FK references
- Business keys provide data integrity and queryability

**Impact:** Each table has `[table_singular]_id INT IDENTITY(1,1) PRIMARY KEY` plus one or more UNIQUE constraints for business keys (e.g., `UNIQUE (email)` on users).

**Requirement reference:** Standard database design practice; no specific requirement addresses this.

---

### Decision: Status columns as VARCHAR with CHECK vs. dedicated lookup tables

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** How to represent enum values (booking_status, space_status, user_role, etc.)?

**Options considered:**
- Option A: Lookup tables (e.g., `booking_statuses` table) — pros: normalized, extensible; cons: extra joins, more tables
- Option B: VARCHAR with CHECK constraint — pros: simpler queries, fewer tables; cons: not truly normalized, harder to add new statuses

**Decision:** We chose VARCHAR with CHECK constraint for statuses because:
- Enums in the requirement (student, lecturer, pending, approved, etc.) are fixed and unlikely to change
- Simpler queries without extra joins
- Still enforces data integrity via CHECK constraints

**Impact:** Status and role columns use `VARCHAR(50) CHECK (column IN ('value1', 'value2', ...))` pattern.

**Requirement reference:** Enum values defined in requirement: see `docs/tech-stack.md` for full list.

---

### Decision: Junction table for space-facility many-to-many

**Task:** 2 (ERD Design)
**Date:** 2026-06-15

**Problem:** A space can have multiple facilities (projector, AC, whiteboard), and a facility can be in multiple spaces. How to model this?

**Options considered:**
- Option A: Repeating groups (multiple columns) — pros: simpler table structure; cons: not normalized, inflexible
- Option B: Junction table `space_facilities` — pros: proper 3NF, flexible; cons: extra table and joins

**Decision:** We chose junction table `space_facilities(space_id, facility_id)` because the requirement likely specifies this as a many-to-many relationship and we are required to reach 3NF.

**Impact:** Queries looking for "spaces with projector" require a JOIN to `space_facilities` and `facilities`.

**Requirement reference:** Requirement mentions "equipment" per space; model as many-to-many.

---

### Decision: DATETIME2 for all timestamps

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Which MSSQL date/time type to use?

**Options considered:**
- Option A: `DATETIME` (8 bytes, 3.33ms precision) — cons: lower precision, smaller range
- Option B: `DATETIME2` (6–8 bytes, 100ns precision) — pros: higher precision, wider range; cons: slightly more storage

**Decision:** We chose `DATETIME2` per tech stack convention to ensure sub-millisecond precision for booking time comparisons.

**Impact:** All timestamp columns use `DATETIME2`. Booking conflict detection and time range queries are more precise.

**Requirement reference:** Tech stack specification: see `docs/tech-stack.md`.

---

### Decision: Building/floor as free-text VARCHAR fields

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Whether to model building and floor as separate reference tables or as free-text fields on the spaces table (Q5).

**Options considered:**
- Option A: Separate `buildings` and `floors` reference tables — pros: normalized, enforces consistency; cons: extra tables and joins with no corresponding query requirement
- Option B: Free-text `NVARCHAR` fields on `spaces` — pros: simpler schema, sufficient for current requirements

**Decision:** We chose Option B (free-text) because no requirement demands building/floor CRUD or cross-building reporting that would justify the extra normalization.

**Impact:** Building and floor values may have minor inconsistencies (e.g., "Bldg A" vs "Building A"), but this is acceptable for the current scope.

**Requirement reference:** Unresolved ambiguity Q5 in outputs/01 §8.

---

### Decision: Usage policy as free-text NVARCHAR(MAX)

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** How to represent usage policy for spaces — free text, coded rules, or document reference (Q2)?

**Options considered:**
- Option A: Coded rules (lookup table of policy types) — pros: queryable; cons: requirements do not define a fixed policy set
- Option B: Free-text NVARCHAR(MAX) — pros: flexible, simple; cons: not structured

**Decision:** We chose Option B (free-text) because no fixed set of policies is defined and the requirement does not call for policy-based querying.

**Impact:** `usage_policy` on spaces is an optional free-text field.

**Requirement reference:** Unresolved ambiguity Q2 in outputs/01 §8.

---

### Decision: Q3 — Maintenance completion auto-updates space status

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Can a space be booked after maintenance is resolved but before space status is manually updated to 'available' (Q3)?

**Options considered:**
- Option A: Manual only — staff must update space status separately (pros: human oversight; cons: gap window for errors)
- Option B: Automatic trigger on maintenance completion — when maintenance status changes to 'resolved', auto-set space status to 'available' (pros: eliminates gap; cons: assumes maintenance completion always means space is usable)

**Decision:** We chose Option B (automatic trigger) plus a cross-check trigger on booking insertion that checks for overlapping unresolved maintenance regardless of space status (defense-in-depth).

**Impact:** Two triggers: `trg_maintenance_completion_space_status` (on maintenance UPDATE → resolved) and `trg_bookings_check_maintenance` (on bookings INSERT/UPDATE). Both documented in the logical design.

**Requirement reference:** Business Rule 4, outputs/01 §6.4.

---

### Decision: Q4 — Automatic no-show detection

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Is no-show detection automatic or manual (Q4)?

**Options considered:**
- Option A: Manual — facility staff mark no-show (pros: human judgment; cons: may be forgotten)
- Option B: Automatic scheduled job — periodically sets no-show for approved bookings without check-in past end time (pros: ensures all no-shows captured; cons: edge cases if check-in happens late)

**Decision:** We chose Option B (automatic scheduled job) because the `no_show` status is part of the booking lifecycle and should not require manual intervention. The job runs periodically and transitions `approved` bookings with `actual_start_time IS NULL` and `requested_end_time < GETDATE()` to `no_show`.

**Impact:** No schema changes; the scheduled job is an operational artifact external to the database. Documented in the logical design.

**Requirement reference:** outputs/01 §4.2 (no_show status) and Assumption A5.

---

### Decision: Account status enum finalized

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** The entity registry listed `account_status` as a "provisional enum" without specific values. The requirement (§2) mentions "Account Status" exists but does not enumerate values.

**Options considered:**
- Option A: Open-ended VARCHAR without CHECK — pros: flexible; cons: no integrity
- Option B: CHECK constraint with standard values — pros: data integrity; cons: requires DDL change to add values

**Decision:** We chose Option B with values `('active','inactive','suspended')` and DEFAULT `'active'` — reasonable for university account lifecycle management.

**Impact:** `users.account_status` is `VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (account_status IN ('active','inactive','suspended'))`.

**Requirement reference:** outputs/01 §2 (Account Status as attribute).

---

### Decision: Rejection reason as separate column on booking_approvals (Q1)

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** Should the rejection reason be stored as a separate column or merged into the decision note (Q1), and on which table after the SRP split?

**Options considered:**
- Option A: Merge into `decision_note` on `booking_approvals` — pros: fewer columns; cons: harder to query/validate separately
- Option B: Separate `rejection_reason NVARCHAR(MAX) NULL` column on `booking_approvals` — pros: clear semantic distinction, easier to enforce BR7 via trigger

**Decision:** We chose Option B because Business Rule 7 explicitly requires "rejection reason must be stored" — a dedicated column on `booking_approvals` makes enforcement and querying cleaner.

**Impact:** `booking_approvals.rejection_reason` is optional (`NULL`), with trigger-level enforcement requiring it when `decision = 'rejected'`.

**Requirement reference:** Business Rule 7, outputs/01 §7.3.

---

### Decision: Role-enforcement triggers upgraded to database-level (BR15–BR17)

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** The ERD Section 4 lists role constraints (approver must be facility_staff/manager, check-in staff must be facility_staff/manager, assigned maintenance staff must be facility_staff) as application-level only, providing no defense if the application layer is bypassed.

**Options considered:**
- Option A: Keep at application-level only — pros: simpler schema; cons: no database-level enforcement
- Option B: Database-level triggers — pros: defense-in-depth; cons: more objects to maintain

**Decision:** We chose Option B — three `AFTER INSERT/UPDATE` triggers validate user roles before allowing operations:
- `trg_booking_approvals_check_role` on `booking_approvals`
- `trg_booking_sessions_check_role` on `booking_sessions`
- `trg_maintenances_check_assignee_role` on `maintenances`

**Impact:** Role validation is enforced at both application and database layers. Trigger names follow `trg_<table>_<action>` convention.

**Requirement reference:** ERD Section 4 (Logical Constraints), BR15–BR17.

---

### Decision: Space availability check moved to approval-time (BR2)

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** The old design blocked booking INSERT when `spaces.current_status NOT IN ('available','in_use')`. This prevented users from submitting pending bookings for temporarily unavailable spaces (e.g., under maintenance), forcing them to wait until the space became available again.

**Options considered:**
- Option A: Block at booking INSERT — space must be available at request time (pros: no wasted pending bookings; cons: users cannot pre-submit for soon-to-be-available spaces)
- Option B: Block only at approval time — pending bookings allowed on any space; `trg_booking_approvals_check_space` rejects approval when space is unavailable (pros: users can submit requests in advance; cons: some approved bookings may later be blocked)

**Decision:** We chose Option B because the booking workflow should allow pending requests on any space. The space status check is meaningful only at the point of approval — a space that was `under_maintenance` at request time may be `available` at approval time.

**Impact:** Pending bookings can be created on any `spaces.current_status`. Approval triggers (`trg_booking_approvals_check_space`) reject `decision = 'approved'` when space is `under_maintenance`, `temporarily_closed`, or `retired`.

**Requirement reference:** BR2, outputs/03 §7, revision v2.2.

---

### Decision: Cancellation trigger with state validation and space cleanup (BR18)

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** Cancelling a booking requires (a) validating that cancellation is only allowed from `pending` or `approved` states, and (b) cleaning up `spaces.current_status` if the space was `in_use`. Application-level handling is fragile under concurrent operations.

**Options considered:**
- Option A: Application-level only — pros: no trigger maintenance; cons: race conditions, bypass risk
- Option B: Database trigger `trg_bookings_cancellation` — pros: atomic validation + cleanup; cons: trigger complexity

**Decision:** We chose Option B — `trg_bookings_cancellation` fires on `bookings UPDATE` when `status` transitions to `'cancelled'`. It rejects cancellations from states other than `pending`/`approved` and sets `spaces.current_status = 'available'` if a related `booking_sessions` row exists.

**Impact:** Cancellation is atomic — validation and space cleanup happen in the same transaction. No orphaned `in_use` spaces.

**Requirement reference:** BR18, outputs/03 §7.

---

### Decision: Check-in requires approved booking status (BR8 enhancement)

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** Without a status check, a user could check in to a `pending` or `rejected` booking, bypassing the approval workflow.

**Options considered:**
- Option A: Allow check-in regardless of booking status — pros: simpler trigger; cons: approval workflow can be bypassed
- Option B: Require `bookings.status = 'approved'` — pros: enforces workflow; cons: edge case if status changes concurrently

**Decision:** We chose Option B — `trg_booking_sessions_checkin` validates that the related booking is `'approved'` before allowing INSERT into `booking_sessions`. Rejects check-in for `pending`, `rejected`, `cancelled`, or `completed` bookings.

**Impact:** Check-in is gated on booking approval, ensuring the approval→check-in→completion lifecycle is enforced at the database level.

**Requirement reference:** BR8, outputs/03 revision v2.3.

---

### Decision: FK CASCADE on dependent child tables after SRP split

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** After splitting `bookings` into `bookings` + `booking_approvals` + `booking_sessions`, the child tables `booking_approvals` and `booking_sessions` have no independent meaning without their parent `bookings`. SQL Server cascade path rules restrict multiple CASCADE/SET NULL FKs referencing the same parent.

**Options considered:**
- Option A: NO ACTION on all child FKs — pros: safest, no cascade path conflicts; cons: orphan records if parent is deleted
- Option B: CASCADE on `booking_approvals.booking_id` and `booking_sessions.booking_id` → bookings; NO ACTION on all FKs → users (preserves cascade path rule)

**Decision:** We chose Option B because:
- `booking_approvals` and `booking_sessions` are strictly dependent child tables — deleting a booking should cascade to its approval and session
- All FKs → users use NO ACTION to avoid multiple cascade paths (SQL Server Msg 1785)
- `maintenances.assigned_staff_id` → users uses SET NULL (single FK from maintenances → users, no conflict)

**Impact:**
| FK | Child → Parent | ON DELETE |
|---|---|---|
| `booking_approvals.booking_id` → `bookings` | CASCADE |
| `booking_sessions.booking_id` → `bookings` | CASCADE |
| All FKs → `users` (except assigned_staff_id) | NO ACTION |
| `maintenances.assigned_staff_id` → `users` | SET NULL |

**Requirement reference:** SQL Server cascade path limitation (Msg 1785), SRP split, BR13.

---

### Decision: Dual-layer overlap detection (filtered unique index + interval trigger) for BR1

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** Preventing overlapping bookings for the same space requires two distinct checks: (a) exact collisions on `(space_id, requested_start_time)` for confirmed bookings, and (b) arbitrary interval overlaps (e.g. 10–12 vs. 11–13). A single mechanism cannot handle both efficiently.

**Options considered:**
- Option A: Trigger only — `trg_bookings_prevent_overlap` handles all overlap cases (pros: single mechanism; cons: trigger fires on every INSERT/UPDATE even when no collision is possible, higher overhead for exact matches)
- Option B: Filtered unique index only — `uq_bookings_active_overlap` prevents exact `(space_id, requested_start_time)` duplicates (pros: lightweight, no trigger overhead for exact matches; cons: cannot detect interval overlaps like 10–12 vs. 11–13)
- Option C: Both — filtered unique index for cheap exact-match prevention + trigger for interval overlap (pros: best performance + complete coverage; cons: two mechanisms to maintain)

**Decision:** We chose Option C because:
- The filtered unique index rejects exact start-time collisions at the index level (no trigger invocation needed)
- The trigger catches interval overlaps that the index cannot express
- Both are database-level, ensuring integrity even with concurrent submissions

**Impact:** Two enforcement points for BR1. The index is a lightweight pre-check; the trigger is the full interval check. Documented in outputs/03 §4 notes and §7.

**Requirement reference:** BR1, outputs/03 §4, §7.

---

### Decision: Decision status sync via trigger (trg_booking_approvals_decision) for BR6

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** After the SRP split, the approval decision is recorded in `booking_approvals.decision`, but `bookings.status` must reflect the decision (`'approved'` or `'rejected'`) for querying and workflow purposes. If application code updates both tables separately, a race condition or bug could leave them out of sync.

**Options considered:**
- Option A: Application-level sync — the app inserts into `booking_approvals` and separately updates `bookings.status` (pros: no trigger; cons: risk of inconsistent state if one operation fails)
- Option B: Trigger-level sync — `trg_booking_approvals_decision` auto-updates `bookings.status` atomically in the same transaction (pros: guaranteed consistency; cons: couples the two tables via trigger logic)

**Decision:** We chose Option B because the status sync is critical for data integrity — a booking with `booking_approvals.decision = 'approved'` but `bookings.status = 'pending'` would be unreachable. The trigger guarantees they stay in lockstep.

**Impact:** `bookings.status` is automatically updated on `booking_approvals` INSERT. No application code needs to manage this sync. Trigger also validates `approver_id` and `decision_time` are NOT NULL.

**Requirement reference:** BR6, outputs/03 §7.

---

### Decision: Session completion trigger (trg_booking_sessions_completion) for BR8/BR9

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** Completing a booking session requires: (a) recording `actual_end_time`, (b) validating `final_condition` is provided, (c) updating `bookings.status` to `'completed'`, and (d) freeing `spaces.current_status` to `'available'`. These must happen atomically to avoid inconsistent states (e.g., session marked complete but space remains `in_use`).

**Options considered:**
- Option A: Application-level completion — app updates `booking_sessions`, then `bookings`, then `spaces` separately (pros: no trigger; cons: three separate operations risk partial failure)
- Option B: Trigger-level completion — `trg_booking_sessions_completion` handles all side effects atomically (pros: guaranteed atomicity; cons: trigger couples three tables)

**Decision:** We chose Option B because the teardown sequence (session → booking → space) must be atomic. The trigger fires on `booking_sessions UPDATE` when `actual_end_time` transitions from NULL to NOT NULL, updating `bookings.status` and `spaces.current_status` in the same transaction.

**Impact:** Completion is a single operation from the application's perspective. Counterpart to check-in trigger — together they form the complete session lifecycle.

**Requirement reference:** BR8, BR9, outputs/03 §7.

---

### Decision: updated_at auto-stamp triggers (all 9 tables)

**Task:** 3 (Logical Design)
**Date:** 2026-07-01

**Problem:** Every table has an `updated_at DATETIME2 NOT NULL DEFAULT GETDATE()` column, but `DEFAULT` fires only on INSERT. On subsequent UPDATEs, the column must be explicitly set by the application or kept current automatically. Manual handling is error-prone.

**Options considered:**
- Option A: Application-level — the application sets `updated_at = GETDATE()` on every UPDATE (pros: no trigger overhead; cons: every code path must remember to set it; ORMs may omit it from payload)
- Option B: Trigger-level — `AFTER UPDATE` trigger on each table auto-stamps `updated_at = GETDATE()` (pros: guaranteed currency, no application burden; cons: 9 triggers to maintain)
- Option C: Trigger-level with recursion guard — same as B but with `IF NOT UPDATE([updated_at])` to prevent infinite recursion when `RECURSIVE_TRIGGERS` is ON (pros: safest; cons: slightly more complex trigger body)

**Decision:** We chose Option C because:
- Eliminates application burden for timestamp management
- Recursion guard (`IF NOT UPDATE([updated_at])`) prevents infinite loops if a trigger's own inner UPDATE retriggers itself
- Pattern repeated across all 9 tables for consistency

**Impact:** All tables have an `AFTER UPDATE` trigger that sets `updated_at = GETDATE()` when any other column changes. The guard ensures that updating only `updated_at` (e.g., from the trigger itself) is a no-op.

**Requirement reference:** BR12, outputs/03 §6, outputs/05 DDL implementation.

---

## Assumptions documented during design

1. **Assumption:** Users have unique email addresses.
   - **Rationale:** Email is the natural business key for user identification.
   - **Task documented:** Task 1

2. **Assumption:** Departments exist (not dynamic) — can be set up via seed data.
   - **Rationale:** Department list is relatively stable; not created on-the-fly.
   - **Task documented:** Task 1

3. **Assumption:** Building/floor as free-text fields is sufficient.
   - **Rationale:** No requirement demands reference-table normalization for buildings/floors.
   - **Task documented:** Task 3

---

## Revision log

### Decision: BR7 trigger scoped to status transition only

**Task:** 5 (DDL Generation)
**Date:** 2026-06-18

**Problem:** `trg_bookings_rejection_reason` checked `inserted` only, re-validating `rejection_reason IS NOT NULL` on **every** UPDATE touching a `status = 'rejected'` row. If an ORM/API omitted `rejection_reason` from a soft-delete payload (e.g. `SET is_deleted = 1`), the column could be silently set to NULL, falsely blocking the update.

**Fix:** Added a `LEFT JOIN deleted` to the trigger's `IF EXISTS` subquery so the check fires only when `status` is transitioning **to** `'rejected'`:
- On INSERT: joins no `deleted` row → enforces rule
- On UPDATE where `status` changes from `'pending'`/`'approved'` to `'rejected'` → enforces rule
- On UPDATE where `status` is already `'rejected'` → skips (no re-validation)

**Impact:** Soft-delete and any other column-level updates on rejected bookings no longer trigger false BR7 violations.

**Requirement reference:** BR7

---

### Decision: Maintenance-completion space-status trigger checks for concurrent active tickets

**Task:** 5 (DDL Generation)
**Date:** 2026-06-18

**Problem:** `trg_maintenances_completion_space_status` set `spaces.current_status = 'available'` as soon as *any* maintenance ticket transitioned to `'resolved'`, ignoring other unresolved tickets on the same space. With concurrent tickets (e.g. AC repair + network repair), resolving the first would prematurely clear the `'under_maintenance'` flag.

**Fix:** Added `NOT EXISTS` subquery that checks for other active (`'open'`/`'in_progress'`) tickets for the same space before flipping the space to `'available'`. The space remains `'under_maintenance'` until the last active ticket is resolved.

**Behavior verified:**
- Two concurrent `'in_progress'` tickets → resolving Ticket A keeps space as `'under_maintenance'` ✅
- Resolving Ticket B (last active) → space transitions to `'available'` ✅

**Requirement reference:** Q3 (maintenance-to-booking interaction)

---

### Decision: Split Bookings into three tables (SRP refactor)

**Task:** Post-Task 5 (Architectural refactor)
**Date:** 2026-06-18

**Problem:** The `bookings` table violated Single Responsibility Principle — it contained attributes for booking requests (space, time, purpose), approval decisions (approver_id, decision_time, rejection_reason), and session check-in/out (actual_start_time, checked_in_by, initial/final_condition). When a booking was in `pending` status, up to 10 attributes were NULL, causing schema bloat and making the lifecycle hard to reason about.

**Options considered:**
- Option A: Keep monolithic `bookings` table — simpler but violates SRP; many nullable columns; no status-change history
- Option B: Split into `bookings` (request) + `booking_approvals` (decision) + `booking_sessions` (check-in/out) — each table focuses on one lifecycle phase; no unnecessary NULLs

**Decision:** We chose Option B because:
- Each table adheres to SRP — only columns relevant to its phase
- Eliminates NULL sprawl (approval/session columns only exist when applicable)
- Booking_Approvals captures the approval decision (approved/rejected) with a clean `decision` column replacing the old `status`-based inference
- Booking_Sessions captures the check-in/out workflow with mandatory `actual_start_time` and `checked_in_by` at check-in time
- `booking_id` is a UNIQUE FK in both child tables, enforcing 1:0..1 cardinality

**Impact:**
- `bookings` loses 10 attributes; gains no new ones (plus `is_deleted` restored per BR11)
- Existing triggers and indexes on `bookings` must be re-evaluated and migrated to the appropriate new tables
- Application code for approval and check-in flows must target the new tables
- Reporting queries now JOIN `bookings` → `booking_approvals` / `booking_sessions` for approval/session data
- `docs/entity-registry.md`, `docs/schema-registry.md`, `outputs/02-erd-design-G05.md`, and `outputs/03-logical-design-G05.md` updated accordingly

**Requirement reference:** SRP design principle; BR6 (decision recording), BR7 (rejection reason), BR8 (actual time recording), BR9 (space condition tracking)

---

## Revision log

| Date | Change | By | Task |
|---|---|---|---|
| 2026-06-18 | Split `bookings` into `bookings` + `booking_approvals` + `booking_sessions` (SRP refactor) | Agent | Post-Task 5 refactor |
| 2026-06-18 | Added `updated_at` auto-stamp triggers (6 tables) — `AFTER UPDATE` keeps timestamps current beyond the initial INSERT | Agent | Task 05 DDL |
| 2026-06-18 | Maintenance-completion trigger: `NOT EXISTS` check prevents premature space-status flip with concurrent tickets | Agent | Task 05 DDL |
| 2026-06-18 | BR7 trigger scoped to status transition — `LEFT JOIN deleted` prevents false rejections on non-status updates | Agent | Task 05 DDL |
| 2026-06-15 | Revision 1: added Q3 (maintenance auto-status) and Q4 (auto no-show) decisions; filtered unique index for overlap | Copilot | Task 03 revision |
| 2026-06-15 | Filled in dates for all Task 2/3 decisions; added account_status, building/floor, rejection_reason, usage_policy decisions | Copilot | Task 03 |
| — | Template created | Copilot | Planning |

---

_This document is a living artifact — updated throughout the pipeline as design decisions are made or revised. The decision log is considered locked after SCHEMA FREEZE (end of Task 4); subsequent tasks may append revision entries for implementation-driven adjustments._
