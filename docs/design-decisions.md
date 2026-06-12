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
**Date:** [TO BE FILLED]

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
**Date:** [TO BE FILLED]

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
**Date:** [TO BE FILLED]

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
**Date:** [TO BE FILLED]

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
**Date:** [TO BE FILLED]

**Problem:** Which MSSQL date/time type to use?

**Options considered:**
- Option A: `DATETIME` (8 bytes, 3.33ms precision) — cons: lower precision, smaller range
- Option B: `DATETIME2` (6–8 bytes, 100ns precision) — pros: higher precision, wider range; cons: slightly more storage

**Decision:** We chose `DATETIME2` per tech stack convention to ensure sub-millisecond precision for booking time comparisons.

**Impact:** All timestamp columns use `DATETIME2`. Booking conflict detection and time range queries are more precise.

**Requirement reference:** Tech stack specification: see `docs/tech-stack.md`.

---

## Assumptions documented during design

_(To be filled in during Tasks 1–4.)_

1. **Assumption:** Users have unique email addresses.
   - **Rationale:** Email is the natural business key for user identification.
   - **Task documented:** Task 1

2. **Assumption:** Departments exist (not dynamic) — can be set up via seed data.
   - **Rationale:** Department list is relatively stable; not created on-the-fly.
   - **Task documented:** Task 1

3. (To be added during tasks)

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

## Revision log

| Date | Change | By | Task |
|---|---|---|---|
| — | Template created | Copilot | Planning |

---

_This document is finalized once Task 4 (Design Validation) is marked ✅ and SCHEMA FREEZE is approved._
