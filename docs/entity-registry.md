# Entity Registry — CS486 Space Booking System

Single source of truth for every **entity and attribute** (the *conceptual* view).
For relational tables, FK wiring, indexes and the 3NF proof see
`docs/schema-registry.md`; for the reasoning behind choices see `docs/design-decisions.md`.

> Boundary: this file does **not** contain indexes, FK graphs, 3NF proofs, or
> business-rule coverage — those live in `schema-registry.md`.

## How to use this document

Per-task responsibilities (who populates/refines/locks this file, and when) are defined once in the **Registry maintenance protocol** of
`.opencode/skills/db-design-pipeline/SKILL.md`. Follow that; do not restate it here.

---

## Format spec — canonical entity block

Every entity MUST follow this exact structure so the registry stays uniform:

```markdown
### <EntityName>

**Description:** <one sentence — the real-world thing this represents>
**Maps to table:** `<table_name>`            ← links to schema-registry.md
**Source:** outputs/0X §<section>             ← traceability

**Candidate keys:**
- `<surrogate_key>` (surrogate, PK)
- `<business_key>` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| <name> | <SQL type> | NO/YES | PK/FK/UQ/— | `CHECK IN (...)` or `FK → table` | <note> |
```

Column rules:
- **Type** — final SQL Server type by end of Task 03 (`INT`, `NVARCHAR(255)`, `DATETIME2`, `BIT`, …).
- **Nullable** — `NO` or `YES` only.
- **Key** — one of `PK`, `FK`, `UQ`, or `—`.
- **Constraint / Enum** — full enum list for CHECK columns, or `FK → <table>.<col>` for foreign keys.
- **Notes** — defaults (`DEFAULT GETDATE()`) or anything non-obvious.

Discovery-status legend: ⬜ draft · 🔄 refining · 🔒 locked (post-Task 03).

> ✅ **All entities below are 🔒 locked as of Task 03 (2026-07-01).**

---
## Relationships registry

_(Populate from `outputs/01` §Relationships; confirm cardinalities in Task 2.)_

| # | From → To | Cardinality | Participation | Source |
|---|---|---|---|---|
| R1 | Departments → Users | 1:N | Users total (each user belongs to a department) | outputs/01 §2, §3.3 |
| R2 | Users → Bookings (requester) | 1:N | Bookings total on requester | outputs/01 §4.1 |
| R3 | Users → Booking_Approvals (approver) | 1:N | Booking_Approvals partial (approver set only when a decision is made) | outputs/01 §5.1 |
| R4 | Users → Booking_Sessions (checks_in) | 1:N | Booking_Sessions partial (set only at check-in) | outputs/01 §4.3 |
| R5 | Spaces → Bookings | 1:N | Bookings total on space | outputs/01 §4.1 |
| R6 | Spaces ↔ Facilities | M:N (via Space_Facilities) | both partial | outputs/01 §3.2 |
| R7 | Spaces → Maintenance | 1:N | Maintenance total on space | outputs/01 §6.2 |
| R8 | Users → Maintenance (reporter) | 1:N | Maintenance total on reporter | outputs/01 §6.2 |
| R9 | Users → Maintenance (assigned staff) | 1:N | Maintenance partial (assignee may be set later) | outputs/01 §6.2 |
| R10 | Bookings → Booking_Approvals | 1:0..1 | Booking_Approvals total (each decision belongs to exactly one booking) | outputs/01 §5 |
| R11 | Bookings → Booking_Sessions | 1:0..1 | Booking_Sessions total (each session belongs to exactly one booking) | outputs/01 §4.3 |

---

## Core entities

_(Populated from `outputs/01-business-req-analysis-G05.md`. Names/types are
provisional in Task 01 and are finalized/locked in Task 03.)_

### Departments

**Description:** Organizational units that users belong to; used for role-based oversight and reporting.
**Maps to table:** `departments`
**Source:** outputs/01 §3.3

**Candidate keys:**
- `department_id` (surrogate, PK)
- `name` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| department_id | INT | NO | PK | — | IDENTITY(1,1) |
| name | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Users

**Description:** University accounts with an assigned role and department.
**Maps to table:** `users`
**Source:** outputs/01 §2

**Candidate keys:**
- `user_id` (surrogate, PK)
- `email` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| user_id | INT | NO | PK | — | IDENTITY(1,1) |
| email | NVARCHAR(255) | NO | UQ | UNIQUE | Business key (A1) |
| full_name | NVARCHAR(255) | NO | — | — | Full name |
| phone_number | NVARCHAR(50) | YES | — | — | Optional (A7) |
| role | VARCHAR(50) | NO | — | `CHECK IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')` | |
| department_id | INT | NO | FK | `FK → departments.department_id` | |
| account_status | VARCHAR(50) | NO | — | `CHECK IN ('active','inactive','suspended')` | DEFAULT 'active' |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Spaces

**Description:** Bookable physical spaces across campus buildings.
**Maps to table:** `spaces`
**Source:** outputs/01 §3.1

**Candidate keys:**
- `space_id` (surrogate, PK)
- `space_code` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| space_id | INT | NO | PK | — | IDENTITY(1,1) |
| space_code | NVARCHAR(50) | NO | UQ | UNIQUE | Business key |
| space_name | NVARCHAR(255) | NO | — | — | Display name |
| space_type | VARCHAR(50) | NO | — | `CHECK IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')` | |
| building | NVARCHAR(100) | NO | — | — | Free-text building identifier |
| floor | NVARCHAR(50) | NO | — | — | Free-text floor identifier |
| room_number | NVARCHAR(50) | NO | — | — | |
| capacity | INT | NO | — | `CHECK (capacity > 0)` | |
| current_status | VARCHAR(50) | NO | — | `CHECK IN ('available','in_use','under_maintenance','temporarily_closed','retired')` | DEFAULT 'available' |
| usage_policy | NVARCHAR(MAX) | YES | — | — | Free-text (Q2) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Facilities

**Description:** Equipment item types that may be present in spaces (projector, AC, microphone, etc.).
**Maps to table:** `facilities`
**Source:** outputs/01 §3.2

**Candidate keys:**
- `facility_id` (surrogate, PK)
- `name` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| facility_id | INT | NO | PK | — | IDENTITY(1,1) |
| name | NVARCHAR(255) | NO | UQ | UNIQUE | e.g. projector, whiteboard, microphone, computer, livestreaming_equipment, air_conditioner |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Space_Facilities

**Description:** Junction resolving the many-to-many between spaces and facilities (which equipment is in which space).
**Maps to table:** `space_facilities`
**Source:** outputs/01 §3.2

**Candidate keys:**
- `(space_id, facility_id)` (composite, PK)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| space_id | INT | NO | PK, FK | `FK → spaces.space_id` | Part of composite PK |
| facility_id | INT | NO | PK, FK | `FK → facilities.facility_id` | Part of composite PK |
| quantity | INT | YES | — | — | Optional count per space |

---

### Bookings

**Description:** Space-usage requests submitted by users, tracking scheduling and lifecycle status.
**Maps to table:** `bookings`
**Source:** outputs/01 §4

**Candidate keys:**
- `booking_id` (surrogate, PK)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| booking_id | INT | NO | PK | — | IDENTITY(1,1) |
| space_id | INT | NO | FK | `FK → spaces.space_id` | |
| requester_id | INT | NO | FK | `FK → users.user_id` | Submitter (R2) |
| requested_start_time | DATETIME2 | NO | — | — | |
| requested_end_time | DATETIME2 | NO | — | `CHECK (requested_end_time > requested_start_time)` | |
| purpose | VARCHAR(50) | NO | — | `CHECK IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')` | |
| expected_participants | INT | NO | — | `CHECK (expected_participants > 0)` | vs capacity (BR3) |
| status | VARCHAR(50) | NO | — | `CHECK IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')` | DEFAULT 'pending' |
| is_deleted | BIT | NO | — | — | DEFAULT 0 (A4, soft delete) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Booking_Approvals

**Description:** Record of an approval or rejection decision made by authorized staff on a booking request.
**Maps to table:** `booking_approvals`
**Source:** outputs/01 §5

**Candidate keys:**
- `approval_id` (surrogate, PK)
- `booking_id` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| approval_id | INT | NO | PK | — | IDENTITY(1,1) |
| booking_id | INT | NO | FK, UQ | `FK → bookings.booking_id` | One decision per booking |
| approver_id | INT | NO | FK | `FK → users.user_id` | Must be facility_staff/facility_manager |
| decision_time | DATETIME2 | NO | — | — | |
| decision | VARCHAR(50) | NO | — | `CHECK IN ('approved','rejected')` | |
| rejection_reason | NVARCHAR(MAX) | YES | — | — | Required when decision = 'rejected' (BR7) |
| decision_note | NVARCHAR(MAX) | YES | — | — | |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |

---

### Booking_Sessions

**Description:** Check-in and check-out session tracking for an approved booking.
**Maps to table:** `booking_sessions`
**Source:** outputs/01 §4.3

**Candidate keys:**
- `session_id` (surrogate, PK)
- `booking_id` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| session_id | INT | NO | PK | — | IDENTITY(1,1) |
| booking_id | INT | NO | FK, UQ | `FK → bookings.booking_id` | One session per booking |
| actual_start_time | DATETIME2 | NO | — | — | |
| checked_in_by | INT | NO | FK | `FK → users.user_id` | Must be facility_staff/facility_manager |
| initial_condition | NVARCHAR(MAX) | YES | — | — | |
| actual_end_time | DATETIME2 | YES | — | — | |
| final_condition | NVARCHAR(MAX) | YES | — | — | |
| usage_notes | NVARCHAR(MAX) | YES | — | — | |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |

---

### Maintenance

**Description:** Problem reports against a space, with assignment and resolution tracking.
**Maps to table:** `maintenance`
**Source:** outputs/01 §6

**Candidate keys:**
- `maintenance_id` (surrogate, PK)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| maintenance_id | INT | NO | PK | — | IDENTITY(1,1) |
| space_id | INT | NO | FK | `FK → spaces.space_id` | Related space (R7) |
| reporter_id | INT | NO | FK | `FK → users.user_id` | Reporter (R8) |
| assigned_staff_id | INT | YES | FK | `FK → users.user_id` | Assignee (R9) |
| problem_description | NVARCHAR(MAX) | NO | — | — | |
| start_time | DATETIME2 | NO | — | — | When reported |
| completion_time | DATETIME2 | YES | — | — | When resolved |
| status | VARCHAR(50) | NO | — | `CHECK IN ('open','in_progress','resolved')` | DEFAULT 'open' |
| result_note | NVARCHAR(MAX) | YES | — | — | Resolution summary |
| is_deleted | BIT | NO | — | — | DEFAULT 0 (A4, soft delete) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

## Revision log

| Date | Change | Reason |
|---|---|---|
| 2026-07-01 | Finalized and locked all 9 entities — added audit columns to Booking_Approvals and Booking_Sessions | Task 03 regeneration — logical design finalization |
| 2026-06-18 | Split Bookings into Bookings + Booking_Approvals + Booking_Sessions per SRP | Architectural refactor based on new_proposed_erd.md |
| 2026-06-15 | Revision 1: no entity changes — trigger/index decisions captured in schema-registry | Task 03 revision |
| 2026-06-15 | Finalized all attribute types, constraints, and locked (🔒) all entities | Task 03 registry maintenance — logical design |
| 2026-06-13 | Confirmed and refined 9 relationships and 7 entities for ERD generation | Task 02 registry maintenance |
| 2026-06-12 | Populated 7 entities, attributes, and 9 relationships from `outputs/01` | Task 01 registry maintenance |
| — | Created registry template | Structural planning |