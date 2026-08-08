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

## Recorded decisions (revisions & Phase 2)

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

**Requirement reference:** SRP design principle (BR6: decision recording, BR7: rejection reason, BR8: actual time recording, BR9: space condition tracking)

---

### Decision: Schema unfreeze for Phase 2 affected tables

**Task:** 8 (Requirement-Change Analysis)
**Date:** 2026-08-02

**Problem:** Phase 2 (Tasks 08–16, per `docs/project_phase2_description.md`) introduces new operating conditions and concurrency requirements. The Phase 1 SCHEMA FREEZE prevented further design changes, which would block the Phase 2 re-design specifically for the tables affected by the new requirements.

**Options considered:**
- Option A: Maintain a separate Phase-2 parallel design tree — pros: keeps Phase 1 registries untouched as pristine baseline; cons: splits ground truth across two overlapping sources, risks divergence and reconciliation effort
- Option B: Unfreeze the affected tables in place and evolve the existing registries — pros: single source of truth, builds directly on the Phase 1 baseline; cons: technically reopens frozen tables, requires an explicit re-freeze guard

**Decision:** We chose Option B. Starting at Task 08, the schema is **unfrozen** for the tables affected by the Phase 2 changes — `bookings` and `maintenance` — while all other Phase 1 tables remain frozen (locked). The affected tables carry a `🔓 P2` (unfreeze) marker in the registries; they are re-frozen once the Phase 2 re-design completes in Tasks 09/10. Unaffected tables keep their `🔒` freeze markers unchanged.

**Impact:**
- `docs/entity-registry.md` and `docs/schema-registry.md`: `🔓 P2` markers on affected tables only.
- Tables not affected by Phase 2 remain frozen; no other freeze markers change.
- Tasks 09/10 rewrite the affected registries and produce a migration delta on the Phase 1 baseline; Tasks 11–13 introduce concurrency controls.
- This decision is recorded without re-opening Phase 1 design conclusions; it concerns only the lifecycle/versioning of the affected tables.

**Requirement reference:** `docs/project_phase2_description.md`; Phase 2 source of truth (`docs/README.md`).

---

### Decision: Phase 2 — keep `spaces` unchanged; maintenance is the booking authority; recompute `current_status` on maintenance changes

**Task:** 9 (Updated ERD + Logical Design)
**Date:** 2026-08-03

**Problem:** Phase 2 (per `docs/project_phase2_description.md` §1.1) refines maintenance into two impact levels — `advisory` (space still usable) and `out-of-service` (space unusable) — with a space able to hold several concurrent active maintenance records of different levels. Phase 1 treated *every* active maintenance as a block, encoded through the single `spaces.current_status` flag. Two problems follow:
- The single `current_status` conflates **availability** and **occupancy**, which are no longer mutually exclusive (a space can be occupied — `in_use` — while carrying an advisory). A scalar flag cannot represent both.
- Phase 1 only refreshed `current_status` on maintenance *completion* (via `trg_maintenance_completion_space_status`); there was no handler to set/refresh it on maintenance INSERT/UPDATE, so the flag could go stale and contradict the true maintenance state.

**Options considered:**
- Option X: Split `spaces` into two orthogonal flags (`availability_status` + `occupancy_status`) — pros: clean, no conflation; cons: larger schema change, more trigger surface.
- Option Y: Change blocking semantics so `spaces.current_status` is *derived* from maintenance, and recompute it on every maintenance INSERT/UPDATE/resolve — pros: `spaces` schema unchanged, single source of truth in `maintenance`, minimal schema churn; cons: the flag is still a cached hint, so room-finder/overlap correctness must never trust the flag alone.

**Decision:** We chose Option Y, refined:
- **`spaces` schema unchanged** — no new columns, no split status flags.
- **Blocking correctness is enforced at booking/approval time by time-overlap against `maintenance` where `impact_level = 'out-of-service'`**, never by `spaces.current_status`. `trg_bookings_check_maintenance` and `trg_booking_approvals_check_space` must be re-filtered to `out-of-service` only. `advisory` overlaps are allowed but require the acknowledgment record.
- **`current_status` is a display/filter hint only.** Its value is **recomputed by a trigger on `maintenance` INSERT / UPDATE / resolve** from the combined-state priority rule:
  1. `retired` (manual, permanent) — highest precedence.
  2. `temporarily_closed` (manual) — overrides everything below except `retired`.
  3. `under_maintenance` — iff there is an active `out-of-service` maintenance whose period covers *now*.
  4. `in_use` — iff there is a live `booking_sessions` row (checked in).
  5. `available` — fallback (bookable, not occupied).
  - `advisory` maintenance never sets `under_maintenance`; a space under advisory-only maintenance is `available`. Recompute must respect the retained `booking_sessions` occupancy and the manual `retired`/`temporarily_closed` overrides.

**Impact:** Maintenance triggers are reworked so blocking is level-aware and time-overlap-based; `spaces.current_status` refresh logic mirrors the existing `NOT EXISTS` multi-ticket completion guard. Room-finder and report #4 must derive correctness from `maintenance`/`bookings` overlap, not from the flag.

**Requirement reference:** Phase 2 `docs/project_phase2_description.md` §1.1; Task 08 (C1, BR2, BR4, U5).

---

### Decision: Phase 2 — instant booking pathway: derived origin + reserved system user; concurrency enforcement deferred to Task 11

**Task:** 9 (Updated ERD + Logical Design)
**Date:** 2026-08-03

**Problem:** Phase 2 §1.2 (C2 / NR5) lets eligible space types be **auto-approved at
submission** (instant booking) while other requests keep the staff workflow, and NR6
requires the no-overlap invariant (BR1) to hold across both pathways under concurrency.
Phase 1's `booking_approvals.approver_id` is NOT NULL (BR6) and the approver must be
`facility_staff`/`facility_manager` (BR15) — an auto-approval has no real staff approver.
NR5 also requires distinguishing an instant (auto) approval from a staff approval.

**Options considered:**
- Option A: Make `approver_id` nullable only for instant approvals, with trigger
  exceptions — pros: no fake user; cons: breaks BR6/BR15 without adding exceptions to
  every approval trigger; null identity on auto-approvals.
- Option B: Reserve a **system user row** (`user_id = -1`, role `facility_manager`,
  email `system@campus.edu`) as the instant approver — pros: `approver_id` stays NOT
  NULL, BR6/BR15 intact, no new table; cons: a documented special row that reports must
  exclude from real-user counts. A **stored origin column** on `booking_approvals` was
  considered but **rejected**: it would add the functional dependency
  `approver_id → origin` (instant ⟺ approver_id = -1). Since `approver_id` is not a
  superkey and `origin` is not prime, that FD violates 3NF (project goal: minimum 3NF).
  Because the reserved user `-1` is *the* instant approver, the origin is fully
  derivable, so no column is needed.
- Option C: Keep a stored origin column but document it as an accepted denormalization —
  cons: contradicts the 3NF goal; leaves redundant state that can drift from `approver_id`.

**Decision:** We chose Option B **without a stored origin column**:
- **Derived origin (NR5):** `CASE WHEN approver_id = -1 THEN 'instant' ELSE 'staff' END`
  in queries and reports. `booking_approvals` gains **no** new column; every FD in the
  relation keeps a superkey on the left (`approval_id`, `booking_id`), so it is 3NF/BCNF.
- Reserved system user `user_id = -1` (`System Booking Service`, `role='facility_manager'`,
  `account_status='active'`), seeded via `SET IDENTITY_INSERT` in the Task 10 migration.
  Instant approvals insert `booking_approvals(approver_id = -1, decision = 'approved')`;
  BR6/BR15/BR7 remain satisfied unchanged.
- **Instant-booking eligibility** = `space_type IN ('classroom','computer_lab','project_lab',
  'meeting_room')` (U1); auto-approval test = eligibility ∧ requester `account_status='active'`
  ∧ expected_participants ≤ capacity (BR3) ∧ no overlapping approved/checked_in/completed
  booking (BR1) ∧ no overlapping `out-of-service` maintenance (BR4). The test is business
  logic reusing existing BR1/BR3/BR4 enforcement; it adds no schema.
- **Concurrency enforcement (NR6) is deferred to Task 11** — the no-overlap invariant is
  unchanged, and making it concurrency-safe introduces no ERD/logical schema in Task 09.

**Impact:** `booking_approvals` schema is unchanged from Phase 1; `users` gains a
documented reserved seed row (data, no column change). `bookings` schema is unchanged.
Reports must exclude `user_id = -1` from real-user aggregations. Task 11 designs the
serialization mechanism; Task 10 implements the DDL/migration and seeds the system user.

**Requirement reference:** Phase 2 `docs/project_phase2_description.md` §1.2; Task 08 (C2, NR5, NR6, U1); project goal "normalized to at least 3NF".

---

### Decision: U3 — escalation to out-of-service affects only already-approved bookings

**Task:** 11 (Concurrency Design)
**Date:** 2026-08-04

**Problem:** Task 08 U3 asked whether an advisory → `out-of-service` escalation also
affects **pending** booking requests overlapping the maintenance period, or only
already-approved bookings (which NR4 requires to be identified for staff contact).

**Options considered:**
- Option A: Only approved bookings — escalation performs **no booking DML**; pending
  bookings stay `pending` and any later approval attempt fails the existing
  out-of-service gate (`trg_booking_approvals_check_space`, deterministic `51002`).
- Option B: Also auto-cancel overlapping pending bookings via a maintenance-side
  trigger — raises questions about who records the cancellation and why.
- Option C: Also auto-reject overlapping pending bookings with a fixed reason —
  interacts with BR7 (rejection requires reason) and approval metadata.

**Decision:** We chose **Option A**. It matches the Phase 2 wording of NR4 exactly
("already-approved bookings … must be identified"), is consistent with the recorded
BR2 decision (availability is checked at approval time, not request time), and adds
no new trigger or schema — the existing approval gate is the single enforcement
point. NR4's affected-booking report (#4) covers approved bookings only.

**Impact:** Task 11 workflow 9.3 (escalation/downgrade) does not mutate bookings;
Task 13 adds a regression scenario proving pending bookings stay `pending` and are
rejected with `51002` at approval time; Task 16 report #4 is unaffected.

**Requirement reference:** Phase 2 `docs/project_phase2_description.md` §1.1 (NR4);
Task 08 U3; `outputs/09` §7 (carried forward).

---

### Decision: Task 11 — per-space transaction-owned `sp_getapplock` critical section for NR6

**Task:** 11 (Concurrency Design)
**Date:** 2026-08-04

**Problem:** NR6 requires that two approved bookings never overlap on the same space,
across both the instant and the staff approval pathway, even under concurrency (Task
08 conflicts K1–K4). The Phase 1 enforcement (`trg_bookings_prevent_overlap` +
`uq_bookings_active_overlap`) is check-then-act without serialization and cannot
prevent two concurrent writers from both passing before either commits.

**Options considered:**
- A: `SERIALIZABLE` + key-range locks on the overlap indexes — correct only if every
  writer's interval predicates lock the same ranges; high proof burden, plan-sensitive.
- B: `UPDLOCK, HOLDLOCK` range reads — same "every writer must be perfect" burden,
  escalation path easy to miss (K3 resurfaces).
- C: Transaction-owned `sys.sp_getapplock` per space (`space_booking:<space_id>`)
  shared by all write paths — coarse but deterministic, zero schema change.
- D: Optimistic concurrency with version columns — requires schema the approved
  Task 09 design explicitly excluded (no-schema-change for NR6 enforcement).
- E: Trigger-only (baseline) — insufficient by construction.

**Decision:** We chose **Option C**: every write path that can confirm or invalidate a
booking interval on a space (instant booking, staff approval, maintenance
escalation/downgrade) acquires an exclusive, transaction-owned application lock on
`space_booking:<space_id>` **before** its overlap reads, then re-checks the invariants
(BR1 confirmed-overlap, BR4 out-of-service overlap, NR2 ack completeness, BR2 manual
overrides, BR3 capacity) inside the critical section, immediately before the write.
Existing triggers and the filtered unique index are retained as defense-in-depth.
Isolation stays READ COMMITTED; lock timeout 5 s; deterministic result codes
51001–51009; retry only on `51005`/`51006`. **No schema change** — consistent with
Task 09 §B.3.

**Impact:** Task 12 implements `usp_booking_instant_submit`, `usp_booking_approve`,
`usp_maintenance_set_impact_level` as the only write entry points; Task 13
demonstrates winner/loser outcomes (T1–T8). Application must set/clear
`SESSION_CONTEXT(N'current_user_id')` per unit of work.

**Requirement reference:** Phase 2 `docs/project_phase2_description.md` §1.2 (NR6);
Task 08 K1–K4; Task 09 B.3; `outputs/11-concurrency-design-G05.md`.

---

### Decision: K5 — maintenance-ticket creation is a locked write path (4th entry point)

**Task:** 12 (Concurrency Implementation — K5 gap closure, retro)
**Date:** 2026-08-05

**Problem:** All three Task 11 entry points acquire the per-space critical section `space_booking:<space_id>`, but creating a NEW maintenance ticket (`INSERT INTO dbo.maintenance`) goes through no entry point and no applock. Because `impact_level` is `NOT NULL DEFAULT 'out-of-service'` (Task 09 A.3 backfill semantics, migration L165), ANY raw INSERT — even one omitting the column — creates a blocking ticket. A ticket creation racing an in-flight booking confirmation is the K3 shape (escalation vs in-flight booking) entered through an unlocked door: under READ COMMITTED the booking-side BR4 pre-check may miss the uncommitted ticket, then commit an approved booking overlapping an out-of-service ticket — a BR4/NR6 violation.

**Options considered:**
- Option A: Document as out-of-contract DML (Task 11 §7 escape hatch) — leaves the race open; ticket creation is not a bypass but the ONLY legitimate path, so the escape hatch does not apply.
- Option B: Trigger gating raw out-of-service INSERTs (SESSION_CONTEXT) — schema change (new trigger = Task 10 retro) and, per Task 11's own option-E analysis, triggers cannot serialize two READ COMMITTED writers; insufficient by construction.
- Option C: 4th entry point `usp_maintenance_report` acquiring the SAME applock when the ticket starts at out-of-service — closes the race exactly like K3/K4: the booking side's post-lock re-check sees the committed ticket; the ticket side serializes with concurrent confirmations.

**Decision:** We chose **Option C** — `dbo.usp_maintenance_report` (new, additive object; **no schema change**):
- Parameters: `@space_id`, `@reporter_id`, `@problem_description`, `@start_time`, `@impact_level` (DEFAULT `'advisory'`), `@maintenance_id`/`@result_code`/`@message` OUTPUT.
- Acquires `space_booking:<space_id>` (Exclusive, Transaction owner, 5 s) **only** when `@impact_level = 'out-of-service'` — advisory creation needs no lock (advisory blocks nothing, mirroring the escalation/downgrade logic).
- Does **not** reject when overlapping confirmed bookings exist: per U3/NR4 existing bookings are kept and listed in report #4 (Task 16 reads `maintenance` generally).
- **No new result codes** — reuse `0` / `51005` / `51006` / `51011` (identical semantics to the other entry points).
- Lock is acquired purely for serialization; the BR4 rejection stays on the booking side's post-lock re-check.
- The proc always passes `impact_level` explicitly (avoids the column DEFAULT `'out-of-service'` trap at the entry point).

**Impact:** Task 08's conflict inventory gains **K5** (retro — the creation path was never listed as a separate scenario, K3 only covered escalation of existing tickets); Task 11 gains §9.4 plus K5 references in §4.2/§7/§8.5/§11.1; Task 12 implements the proc + smoke S7; Task 13 gains scenario T9 (ticket creation vs instant submit/approve).

**Requirement reference:** BR4, NR6, NR4/U3; Task 08 K1–K5; Task 11 §9.4; `docs/project_phase2_description.md` §1.1/§1.2.

---

### Decision: Task 11 revision — entry-point scope = 4; K5 closed via `usp_maintenance_report`

**Task:** 11 (Concurrency Design — revision, v2.0)
**Date:** 2026-08-06

**Problem:** An interim decision earlier the same day narrowed Task 11 to 3 entry
points and declared maintenance-ticket creation out-of-scope (documented residual
risk), contradicting the recorded K5 decision (Task 12, 2026-08-05) which promotes
`usp_maintenance_report` to a 4th locked write path. The contradiction must be
resolved in one direction; leaving K5 as a documented hole in the no-overlap
invariant (NR6) — while the fix is a single procedure reusing the same per-space
applock — was rejected in review.

**Options considered:**
- Option A: keep the 3-entry-point scope; K5 remains a declared residual risk
  (BR4/NR6 violation window when a blocking ticket insert races an in-flight
  confirmation under READ COMMITTED).
- Option B: final scope of 4 entry points — ticket creation
  (`usp_maintenance_report`) is a first-class write procedure acquiring
  `space_booking:<space_id>` (Exclusive, Transaction owner, 5 s) **only** when the
  ticket starts at `out-of-service`; advisory creation needs no lock (it blocks
  nothing, it only adds an NR2 obligation); the procedure always passes
  `@impact_level` explicitly, avoiding the column-level DEFAULT `'out-of-service'`
  trap.

**Decision:** We chose **Option B** (final). Task 11 v2.0 covers 4 entry points:
instant submit, staff approval, escalation/downgrade, and ticket creation. K5 is
closed in the coverage matrix and the Task 13 handoff gains scenario T9. The
interim scope-3 choice is superseded; the recorded K5 4th-entry-point treatment
(2026-08-05) stands. The BR4 rejection stays on the booking side's post-lock
re-check — ticket creation never rejects overlapping bookings (U3/NR4 semantics
unchanged).

**Impact:** `outputs/11-concurrency-design-G05.md` v2.0 implements the 4-entry-point
scope (§2.1 scope note, §6.3 result-code table, §7.4 workflow W4, §8 matrix row for
K5, §9 handoff with 4 procedures, §10 test T9). No schema change; triggers +
`uq_bookings_active_overlap` stay as defense-in-depth.

**Requirement reference:** `docs/project_phase2_description.md` §1.2 (NR6); Task 08
K1–K5; recorded K5 decision (2026-08-05); `outputs/11-concurrency-design-G05.md` §2/§7.4/§8/§9/§10.

---

### Decision: Phase 2 revision (Task 09 v2.5) — data-driven usage policy: drop `usage_policy`, add `spaces.max_hours`, new `space_type_allowed_purpose`

**Task:** 9 (Updated ERD + Logical Design — revision v2.5)
**Date:** 2026-08-07

**Problem:** Two design debts surfaced during Task 09 review (Area 2, instant booking):
1. The Phase-1 `spaces.usage_policy` free-text attribute (decision 2026-06-15) is **not
   read by any enforcement logic** — no trigger, constraint, or instant-policy test
   consumes the text — and its name collides with the actual "usage policy" = the
   instant-booking eligibility test (U1). It is a source of confusion, not of behavior.
   Note: the Task 14 generator still *writes* it
   (`outputs/14-data-generator-G05/generate.py` — headers + row builder), so the drop is
   not free — the generator must remove the column in lockstep with the Task 10 migration.
2. The instant usage-policy test (NR5 / U1) currently encodes only criteria that are
   **hardcoded or already enforced** (eligible `space_type` set, requester active,
   BR1/BR3/BR4). It lacks two criteria that ought to be data-driven: (i) the booking
   **purpose** must be permitted for the booking's `space_type`, and (ii) the requested
   **duration** must not exceed a per-space cap. Without them, each school policy change
   is a code change, and purpose/cap cannot be validated at instant-approval time.

**Options considered:**
- Purpose policy **per space_type vs per space**: per-space_type junction table (one row
  per allowed `(space_type, purpose)` pair; uniform rule; matches the requirement wording
  "for each space_type, which purposes are allowed") vs per-space junction (per-room
  flexibility, but contradicts the per-type wording and inflates the seed surface).
  Chose **per space_type**, resolved at runtime via `JOIN spaces` to get the booking's type.
- Duration cap **per space vs per type**: column `spaces.max_hours` (per-space granularity,
  consistent with `capacity`/`current_status`; NULL = no cap; no new table) vs a
  `space_type_policy` table (uniform per type). Chose **per-space column**: a cap is an
  operating property of an individual room; NULL avoids inventing values for legacy rows
  during the data-preserving migration.
- **Keep vs drop** the free-text column: keep as "informational only" (dead weight,
  name collision remains) vs drop. Chose **drop** — this reverses the 2026-06-15 decision.
- Hardcoded eligible set vs data-defined eligibility: keep the extra conjunct
  `space_type IN ('classroom',...)` vs let **junction membership** define instant
  eligibility. Chose data-defined (single source of truth); Task 10 seeds exactly the
  four previously approved types, so the effective eligible set is unchanged.
- Enforce the new criteria on **instant only** vs on **all** bookings. Chose **instant
  only**: staff approval remains purpose/duration-agnostic (staff judgment is the fallback).

**Decision:**
- **Drop** `spaces.usage_policy` (free-text NVARCHAR(MAX)) — the 2026-06-15 "usage policy
  as free-text" decision is **superseded** by this structured, data-driven test.
- **Add** `spaces.max_hours DECIMAL(5,2) NULL` — max single-booking duration
  (hours) for that space; `CHECK (max_hours > 0)`; `NULL` = no limit. This
  **amends** the 2026-08-03 "keep `spaces` unchanged" decision *only for this column* —
  the `current_status` derivation/recompute part of that decision stands.
- **Add** a new junction table `space_type_allowed_purpose` with composite PK
  `(space_type, purpose)`; one row per allowed pair; domain CHECKs mirror
  `spaces.space_type` and `bookings.purpose`; **soft reference** to `spaces.space_type`
  (no FK — no `space_types` dimension table is introduced). Instant eligibility is
  **data-defined**: a space type is instant-eligible if rows exist for it.
- **Revised instant usage-policy test (U1)** — checks 1–6:
  1. `(space_type, purpose) ∈ space_type_allowed_purpose` (soft) —
     resolves the booking's `space_id → space_type` via JOIN;
  2. requester `users.account_status = 'active'` (hard, A09-3);
  3. `expected_participants ≤ spaces.capacity` (hard — BR3);
  4. `duration ≤ max_hours*60 OR max_hours IS NULL` (soft);
  5. no overlapping confirmed booking (hard — BR1);
  6. no overlapping active `out-of-service` maintenance (hard — BR4).
- **Soft vs hard disposition:** a failed **soft** gate (1 or 4) does **not** reject the
  booking — it is created `pending` and routed to the staff-approval workflow
  (`@instant_accepted = 0`). A failed **hard** gate keeps Phase-1 trigger rejection
  semantics. The procedure contract is Task 11; implementation is Task 12.

**Impact:** Phase-2 schema gains `spaces.max_hours` and `space_type_allowed_purpose`,
and loses `usage_policy`. Task 10 migration creates/seeds the junction, adds the column,
and drops the text column (with rollback mirror). The instant-approval entry point
(`usp_booking_instant_submit`) reads the junction + `max_hours` (Task 11/12).
The data generator (Task 14) seeds per-space caps and generates purposes/durations that
conform (plus a small share that exercise the pending-fallback). Task 09 v2.5,
registries, and the U1 resolution are updated accordingly. Phase-1 outputs (03/05/06/07)
remain frozen — the removal is a Phase-2 delta via the migration. This revision also
**widens the Phase-2 unfreeze scope**: `spaces` is added to the unfrozen set, beyond the
kickoff scope of 2026-08-02 (`maintenance`, `bookings`) — recorded explicitly, not as an
implicit amendment.

**Ratified by the group on 2026-08-08** (post-review): the two data-driven criteria —
purpose membership + per-space duration cap — are confirmed as the intended reading of
the (underspecified) "usage policy" in `docs/project_phase2_description.md` §1.2.

**Requirement reference:** `docs/project_phase2_description.md` §1.2 (NR5, usage policy);
Task 08 U1 (revised); decision 2026-06-15 (superseded); decision 2026-08-03 (amended).

---

### Decision: U4 — semester reporting windows and analytical-query semantics

**Task:** 16 (Analytical Queries)
**Date:** 2026-08-07

**Problem:** Phase 2 requires semester-based reports, but the requirement does not
specify the semester boundaries, treatment of summer, or how booking intervals that
cross a reporting boundary contribute to the results. Q3 and Q4 cannot be made
reproducible without one shared reporting-window definition.

**Options considered:**
- **Option A: Institution-style fixed academic windows** — deterministic and easy to
  parameterize; requires an explicit project convention for semester boundaries.
- **Option B: Arbitrary caller-supplied six-month windows** — flexible, but does not
  define what the project means by a semester and can produce incomparable reports.

**Decision:** We chose **Option A** with the following project convention:

- Semester 1: September 1 at 00:00 through February 1 at 00:00 of the following
  calendar year.
- Semester 2: February 1 at 00:00 through July 1 at 00:00 of the same calendar year.
- Summer: July 1 through September 1; excluded from semester reports.
- Every reporting window is represented as the half-open interval
  **`[semester_start, semester_end)`**. The end timestamp is excluded.
- Q3 (total approved booking hours per space) includes confirmed bookings whose
  requested interval overlaps the semester window. Duration is based on
  `requested_start_time`/`requested_end_time`, clipped to the intersection with the
  semester window.
- Q4 (approved bookings by weekday and hour) includes confirmed bookings whose
  `requested_start_time` falls inside the semester window. Weekday numbering is
  deterministic with Monday = 1; the hour bucket is the hour of
  `requested_start_time`.
- Confirmed statuses for both reports are `approved`, `checked_in`, and `completed`;
  soft-deleted bookings (`is_deleted = 1`) are excluded.

**Impact:** Task 16 Q3 and Q4 use declared `@semester_start` and `@semester_end`
parameters with the same half-open-window convention. Q3 reports the usable portion
of a cross-boundary booking rather than attributing hours outside the semester. Q4
reports the booking's requested start weekday/hour, so a booking is counted in the
semester in which it begins. Task 15 must use the same parameter values and window
semantics when measuring either report.

**Requirement reference:** `docs/project_phase2_description.md` §1.3 (semester
reports); Task 08 C3; Task 09 §4 / Area 3.

---


### Decision: Task 09 v2.6 — drop the per-space duration cap

**Task:** 09 (Updated ERD + Logical Design — revision v2.6) · **Date:** 2026-08-08

The per-space duration cap added in v2.5 is **removed** (no column, no duration gate). Instant usage-policy test reverts to **checks 1–5** with purpose membership
as the sole soft gate (A09-6 pending fallback). Supersedes only the duration-cap part of the 2026-08-07 v2.5 decision.
Downstream: Tasks 10 (rev 5), 11 (rev 3.2), 12 (rev 3), 13 shall regenerate against checks 1–5 (see `outputs/09` v2.6 revision log).

---
## Revision log

| Date | Change | By | Task |
|---|---|---|---| 
| 2026-08-08 | Task 09 **v2.6** — per-space duration cap dropped (column + CHECK); usage-policy test back to **checks 1–5** (soft gate = purpose only; no duration gate); downstream: 10 (rev 5), 11 (rev 3.2), 12 (rev 3), 13 | Agent | Task 09
| 2026-08-07 | Phase 2 Task 09 v2.5 — usage policy now data-driven: `spaces.usage_policy` free-text dropped (2026-06-15 decision superseded); `spaces.max_hours` added (per-space duration cap, NULL = unlimited, amends 2026-08-03 spaces-unchanged decision); new `space_type_allowed_purpose` junction (data-defined instant eligibility, seeded for the four eligible types); instant test extended to checks 1–6 with soft (purpose/cap) → pending-fallback vs hard (capacity/overlap/out-of-service) → reject | Agent | Task 09 |
2026-08-03 | Phase 2 — instant-booking origin **derived** from `approver_id = -1` (no stored origin column — a stored one would add the non-key FD `approver_id → origin` and violate 3NF); reserved system user `-1`; eligibility set + auto-approval test (U1); NR6 enforcement deferred to Task 11 | Agent | Task 09 |
| 2026-08-03 | Phase 2 — keep `spaces` unchanged; maintenance is the booking authority; recompute `current_status` on maintenance changes (priority rule) | Agent | Task 09 |
| 2026-08-02 | Phase 2 kickoff — schema unfrozen for affected tables (`bookings`, `maintenance`) via `🔓 P2` markers; all other Phase 1 tables remain frozen | Agent | Task 08 |
| 2026-06-18 | Split `bookings` into `bookings` + `booking_approvals` + `booking_sessions` (SRP refactor) | Agent | Post-Task 5 refactor |
| 2026-06-18 | Added `updated_at` auto-stamp triggers (6 tables) — `AFTER UPDATE` keeps timestamps current beyond the initial INSERT | Agent | Task 05 DDL |
| 2026-06-18 | Maintenance-completion trigger: `NOT EXISTS` check prevents premature space-status flip with concurrent tickets | Agent | Task 05 DDL |
| 2026-06-18 | BR7 trigger scoped to status transition — `LEFT JOIN deleted` prevents false rejections on non-status updates | Agent | Task 05 DDL |
| 2026-06-15 | Revision 1: added Q3 (maintenance auto-status) and Q4 (auto no-show) decisions; filtered unique index for overlap | Copilot | Task 03 revision |
| 2026-06-15 | Filled in dates for all Task 2/3 decisions; added account_status, building/floor, rejection_reason, usage_policy decisions | Copilot | Task 03 |
| — | Template created | Copilot | Planning |

---

_This document is a living artifact — updated throughout the pipeline as design decisions are made or revised. The decision log is considered locked after SCHEMA FREEZE (end of Task 4); subsequent tasks may append revision entries for implementation-driven adjustments._
