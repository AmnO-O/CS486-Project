# Project Overview

Purpose: produce a complete, normalized relational database design for the
CS486 course deliverable (not an application). The design must fully reflect
the official business requirements in `req/business-requirement.md`.

Summary
- Domain: Campus shared-space booking and facility management
- Deliverable: a set of repository outputs that together form the complete
	database design (ERD, relational schema, DDL, sample data, queries, and
	validation documents)

Primary users & roles
- Student — submit/view personal bookings
- Lecturer / Teaching Assistant — submit bookings for classes and events
- Facility Staff — approve/reject, check in/out, record maintenance and
	incident details
- Department Administrator — department-level oversight and reporting
- Facility Manager — manage spaces, staff, and global policies

Core domain entities (high level)
- Users: university accounts with `user_id`, name, email, phone, role,
	department, account_status
- Spaces: `space_code`, name, type, building, floor, room_number, capacity,
	status, usage_policy (for Phase 1)
- Facilities: equipment items tied to spaces (projector, AC, microphone, etc.)
- Bookings: requested periods, purpose, expected participants, status,
	approval and decision metadata, actual session times, check-in/out records
- Maintenance: problem reports, assigned staff, lifecycle and result notes

Business-critical constraints (must be enforced by schema and/or application)
- No overlapping approved bookings for the same space (time conflict constraint)
- Spaces with status `under_maintenance`, `temporarily_closed`, or `retired`
	cannot be booked
- Approval decisions must record approver, timestamp, and decision notes
- Check-in/out must record actual start/end times and space condition notes

Project constraints & standards
- Group: G05 — all output filenames must use the group number suffix `-G05`
- Output naming convention: `outputs/0X-<step-name>-G05.md` or `.sql`
- Normalization: schema must be normalized to at least 3NF
- Target RDBMS: Microsoft SQL Server (T-SQL) — use T-SQL-compatible DDL
- Requirements source: authoritative source is `req/business-requirement.md`



Reference files
- `req/business-requirement.md` — definitive business rules and examples

---

# Phase 2 scope (extension of the Phase 1 baseline)

Phase 2 (Tasks 08–16) extends the space booking system after a one-semester pilot.
Source of truth: `docs/project_phase2_description.md`. Summary:

1. **Maintenance impact levels.** A maintenance record now has an impact level:
   - `out-of-service` — space cannot be booked for any period overlapping maintenance
     (Phase 1 behaviour).
   - `advisory` — space can still be booked, but the requester must be notified of
     all active advisories at booking time and the acknowledgement stored with the
     booking.
   - A space may have several active maintenance records at once; the impact level
     may be escalated/downgraded while open. Escalation to `out-of-service` must
     surface already-approved bookings that overlap the period.
2. **Concurrent booking & approval.** Popular spaces may receive many near-simultaneous
   requests at term start; eligible space types may auto-approve at submission
   (instant booking). Concurrency control must guarantee two approved bookings can
   never overlap the same space, across both instant and staff approval paths.
3. **New reporting needs.** Approved-hour totals per space per semester; approved
   bookings by weekday/hour; capacity+facility room finder; and bookings affected by
   escalation. Followed by index tuning on the conflict check, the room finder, and
   two selected reports.
4. **Data & validation.** Generate ≥3 academic years of realistic data with ≥100,000
   bookings (incl. maintenance, cancellations, no-shows, advisory acknowledgements);
   re-verify 3NF for the updated schema.

Deliverables for the extension are Tasks 08–16 (see `docs/README.md` and
`memory/Progress.md`); the schema is unfrozen for Phase-2 re-design of affected
tables (see `docs/design-decisions.md`).
