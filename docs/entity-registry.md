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

> ### 🔓 Phase 2 status (Tasks 08–16)
> - **Phase 1 (Tasks 01–07) is complete and locked.** All entities below were
>   frozen as of Task 03 (2026-07-01).
> - **Phase 2 re-design is in progress.** Per `docs/project_phase2_description.md`, the
>   schema is **unfrozen** for Phase-2 re-design of the *affected* entities (notably
>   **Maintenance** — impact levels; **Bookings** — advisory acknowledgement +
>   instant/auto-approval origin). Conceptual updates land here during **Task 09**
>   (updated ERD + logical design); until then the Phase 1 definitions below remain
>   authoritative for unchanged entities/departments/users.
> - Phase 2 also requires a **3NF re-validation** of the updated schema (Task 09) and
>   **index re-tuning** (Task 15).

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
| R12 | Maintenance → Maintenance_Impact_History | 1:N | Maintenance_Impact_History total (each level change belongs to exactly one maintenance) | outputs/08 C1/NR3 |
| R13 | Users → Maintenance_Impact_History (recorder) | 1:N | Maintenance_Impact_History total (each change is recorded by exactly one user) | outputs/08 C1/NR3 |
| R14 | Maintenance → Booking_Advisory_Acknowledgement | 1:N | Booking_Advisory_Acknowledgement total (each ack refers to exactly one maintenance) | outputs/08 C1/NR2 |
| R15 | Bookings → Booking_Advisory_Acknowledgement | 1:N | Booking_Advisory_Acknowledgement total (each ack is attached to exactly one booking) | outputs/08 C1/NR2 |

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
| user_id | INT | NO | PK | — | IDENTITY(1,1); reserved row `user_id = -1` = System Booking Service (instant approver, Phase 2 NR5) |
| email | NVARCHAR(255) | NO | UQ | UNIQUE | Business key (A1); system row uses `system@campus.edu` |
| full_name | NVARCHAR(255) | NO | — | — | Full name |
| phone_number | NVARCHAR(50) | YES | — | — | Optional (A7) |
| role | VARCHAR(50) | NO | — | `CHECK IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')` | system row: `facility_manager` (satisfies BR15) |
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
| current_status | VARCHAR(50) | NO | — | `CHECK IN ('available','in_use','under_maintenance','temporarily_closed','retired')` | DEFAULT 'available' (recomputed per Area-1 design) |
| max_hours | DECIMAL(5,2) | YES | — | `CHECK (max_hours > 0)` | Max single-booking duration (hours) for instant eligibility (Phase 2 v2.5); NULL = no cap |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Space_Type_Allowed_Purpose

**Description:** For each space type, the booking purposes permitted to be instant (auto) approved — the data-driven usage policy for instant booking.
**Maps to table:** `space_type_allowed_purpose`
**Source:** outputs/09 §B.2.4 (Phase 2, NR5 / U1 revision, Task 09 v2.5)

**Candidate keys:**
- `(space_type, purpose)` (composite, PK)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| space_type | VARCHAR(50) | NO | PK | `CHECK IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')` | Domain mirrors spaces.space_type (soft reference — no FK) |
| purpose | VARCHAR(50) | NO | PK | `CHECK IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')` | Domain mirrors bookings.purpose |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |

**Relationships (prose):** constrains instant-booking eligibility for Spaces by `space_type` *value* (a space is instant-eligible only if a pair exists for its type and the booking's purpose); no FK — the reference is by enumerated value (§B.2.4 of Task 09).

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
| approver_id | INT | NO | FK | `FK → users.user_id` | Must be facility_staff/facility_manager — enforced via trigger (BR15); system user `-1` for instant approvals; instant/staff origin derived from `approver_id = -1` (NR5) |
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
| checked_in_by | INT | NO | FK | `FK → users.user_id` | Must be facility_staff/facility_manager — enforced via trigger (BR16) |
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
| assigned_staff_id | INT | YES | FK | `FK → users.user_id` | Assignee (R9); must be facility_staff when set — enforced via trigger (BR17) |
| problem_description | NVARCHAR(MAX) | NO | — | — | |
| start_time | DATETIME2 | NO | — | — | When reported |
| completion_time | DATETIME2 | YES | — | — | When resolved |
| status | VARCHAR(50) | NO | — | `CHECK IN ('open','in_progress','resolved')` | DEFAULT 'open' |
| impact_level | VARCHAR(50) | NO | — | `CHECK IN ('advisory','out-of-service')` | DEFAULT 'out-of-service' (Phase 2, NR1); default preserves Phase 1 blocking for legacy rows |
| result_note | NVARCHAR(MAX) | YES | — | — | Resolution summary |
| is_deleted | BIT | NO | — | — | DEFAULT 0 (A4, soft delete) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

### Maintenance_Impact_History

**Description:** Audit log of impact-level escalations/downgrades applied to an open maintenance record.
**Maps to table:** `maintenance_impact_history`
**Source:** outputs/08 C1 / NR3 (Phase 2, Task 09)

**Candidate keys:**
- `history_id` (surrogate, PK)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| history_id | INT | NO | PK | — | IDENTITY(1,1) |
| maintenance_id | INT | NO | FK | `FK → maintenance.maintenance_id` | Changed record (R12) |
| changed_by | INT | NO | FK | `FK → users.user_id` | Who changed the level (R13) |
| prior_level | VARCHAR(50) | NO | — | `CHECK IN ('advisory','out-of-service')` | |
| new_level | VARCHAR(50) | NO | — | `CHECK IN ('advisory','out-of-service')` | Must differ from prior_level |
| changed_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| reason | NVARCHAR(MAX) | YES | — | — | Optional escalation/downgrade note |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |

---

### Booking_Advisory_Acknowledgement

**Description:** Records that the requester of a booking was notified of (and acknowledged) an active advisory maintenance on the space.
**Maps to table:** `booking_advisory_acknowledgement`
**Source:** outputs/08 C1 / NR2 (Phase 2, Task 09)

**Candidate keys:**
- `ack_id` (surrogate, PK)
- `(booking_id, maintenance_id)` (business, UNIQUE) — one acknowledgement per (booking, advisory)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| ack_id | INT | NO | PK | — | IDENTITY(1,1) |
| booking_id | INT | NO | FK, UQ | `FK → bookings.booking_id` | Booked request (R15) |
| maintenance_id | INT | NO | FK, UQ | `FK → maintenance.maintenance_id` | Advisory notified (R14) |
| acknowledged_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| acknowledged_by | INT | NO | FK | `FK → users.user_id` | Normally the requester |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() (BR12) |

---

## Revision log

| Date | Change | Reason |
|---|---|---|
| 2026-08-07 | Task 09 v2.5 (Area 2): `spaces.usage_policy` free-text **removed**; `spaces.max_hours` added (per-space instant-booking duration cap, NULL = no cap); new entity **Space_Type_Allowed_Purpose** (data-driven instant usage policy) | Phase 2 NR5 / U1 revision (`outputs/09` §B.2.3–B.2.5) |
| 2026-08-03 | Task 09 (Areas 2–3): documented reserved system user `user_id = -1` (System Booking Service, instant approver); instant/staff origin derived from `approver_id = -1` (no stored origin column — keeps 3NF); Area 3 reporting confirmed as no-schema-change (derived queries) | Phase 2 C2 (NR5/NR6) / C3 |
| 2026-08-03 | Task 09 (Area 1): added `maintenance.impact_level`; added entities Maintenance_Impact_History (R12, R13) and Booking_Advisory_Acknowledgement (R14, R15) | Phase 2 C1 / NR1–NR4 |
| 2026-08-02 | 🔓 Unfroze for Phase 2 re-design — project extended to 16 tasks (08–16); added Phase 2 status banner. Affected entities (Maintenance, Bookings) to be updated in Task 09 | Phase 2 kickoff (`docs/project_phase2_description.md`) |
| 2026-07-01 | Finalized and locked all 9 entities — added audit columns to Booking_Approvals and Booking_Sessions | Task 03 regeneration — logical design finalization |
| 2026-06-18 | Split Bookings into Bookings + Booking_Approvals + Booking_Sessions per SRP | Architectural refactor based on new_proposed_erd.md |
| 2026-06-15 | Revision 1: no entity changes — trigger/index decisions captured in schema-registry | Task 03 revision |
| 2026-06-15 | Finalized all attribute types, constraints, and locked (🔒) all entities | Task 03 registry maintenance — logical design |
| 2026-06-13 | Confirmed and refined 9 relationships and 7 entities for ERD generation | Task 02 registry maintenance |
| 2026-06-12 | Populated 7 entities, attributes, and 9 relationships from `outputs/01` | Task 01 registry maintenance |
| — | Created registry template | Structural planning |