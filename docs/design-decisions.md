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

### Decision: Rejection reason as separate column

**Task:** 3 (Logical Design)
**Date:** 2026-06-15

**Problem:** Should the rejection reason be stored as a separate column or merged into the decision note (Q1)?

**Options considered:**
- Option A: Merge into `decision_note` — pros: fewer columns; cons: harder to query/validate separately
- Option B: Separate `rejection_reason` column — pros: clear semantic distinction, easier to enforce BR7

**Decision:** We chose Option B because Business Rule 7 explicitly requires "rejection reason must be stored" — a dedicated column makes enforcement and querying cleaner.

**Impact:** The `bookings` table has an additional nullable `rejection_reason NVARCHAR(MAX)` column.

**Requirement reference:** Business Rule 7, outputs/01 §7.3.

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

## Trade-offs and rejected options

_(To be filled in during design phases.)_

| Rejected option | Why rejected | Task |
|---|---|---|
| (Example) Repeating groups for facilities | Not normalized to 3NF | Task 2 |
| (To be documented) | | |

---

## Open design questions

_(Unresolved items that affect schema. Should be zero by end of Task 4.)_

1. **Do we need a rejection reason field?** — If a booking is rejected, should the reason be stored?
   - **Decision needed:** Add `rejection_reason NVARCHAR(MAX)` to `booking_requests`?
   - **Status:** [To be discussed during Task 1]

2. (To be added during tasks)

---

### Decision: FK cascade actions changed from SET NULL to NO ACTION

**Task:** 5 (DDL Generation)
**Date:** 2026-06-18

**Problem:** SQL Server prevents multiple foreign keys on the same table referencing the same parent when any use `ON DELETE SET NULL` or `CASCADE` (Msg 1785 — "may cause cycles or multiple cascade paths").

**Options considered:**
- Option A: Keep SET NULL on `bookings.approver_id` and `bookings.checked_in_by` → SQL Server rejects the DDL
- Option B: Change all 3 optional FKs (`bookings.approver_id`, `bookings.checked_in_by`, `maintenance.assigned_staff_id`) to `ON DELETE NO ACTION` → DDL compiles, preserves references, consistent with BR13

**Decision:** Option B — `NO ACTION` for all 3 FKs. NO ACTION preserves the user ID in the historical record even if the referenced user is deleted, which is actually more aligned with BR13 (Historical Records Preservation) than SET NULL.

**Impact:** If a user is deleted (soft-delete is preferred anyway), the approver_id/checked_in_by/assigned_staff_id still points to a potentially deleted user record. This is acceptable because:
- Soft delete is used for all sensitive records (BR13)
- Historical accuracy is preserved (who approved/checked-in)
- Application-level checks can handle display logic for deleted users

**Requirement reference:** BR13 (Historical Records Preservation), SQL Server cascade path limitation.

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

## Revision log

| Date | Change | By | Task |
|---|---|---|---|
| 2026-06-18 | Added `updated_at` auto-stamp triggers (6 tables) — `AFTER UPDATE` keeps timestamps current beyond the initial INSERT | Agent | Task 05 DDL |
| 2026-06-18 | Maintenance-completion trigger: `NOT EXISTS` check prevents premature space-status flip with concurrent tickets | Agent | Task 05 DDL |
| 2026-06-18 | BR7 trigger scoped to status transition — `LEFT JOIN deleted` prevents false rejections on non-status updates | Agent | Task 05 DDL |
| 2026-06-18 | FK cascade actions: SET NULL → NO ACTION for 3 FKs (SQL Server cascade path limitation) | Agent | Task 05 DDL |
| 2026-06-15 | Revision 1: added Q3 (maintenance auto-status) and Q4 (auto no-show) decisions; filtered unique index for overlap | Copilot | Task 03 revision |
| 2026-06-15 | Filled in dates for all Task 2/3 decisions; added account_status, building/floor, rejection_reason, usage_policy decisions | Copilot | Task 03 |
| — | Template created | Copilot | Planning |

---

_This document is finalized once Task 4 (Design Validation) is marked ✅ and SCHEMA FREEZE is approved._
