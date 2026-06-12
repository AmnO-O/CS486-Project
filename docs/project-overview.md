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
	status, usage_policy
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
