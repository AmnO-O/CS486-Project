# Schema Registry — CS486 Campus Space Management System

Relational schema: table definitions, FK wiring, indexes, and 3NF proof.
For conceptual entity/attribute definitions see `docs/entity-registry.md`.

---

## Table inventory

| # | Table | Type | Status | Maps from |
|---|---|---|---|---|
| 1 | departments | entity | 🔒 | Departments |
| 2 | users | entity | 🔒 | Users |
| 3 | spaces | entity | 🔒 | Spaces |
| 4 | facilities | entity | 🔒 | Facilities |
| 5 | space_facilities | junction | 🔒 | Spaces ↔ Facilities (R6) |
| 6 | bookings | entity | 🔒 | Bookings |
| 7 | booking_approvals | entity | 🔒 | Booking_Approvals |
| 8 | booking_sessions | entity | 🔒 | Booking_Sessions |
| 9 | maintenance | entity | 🔒 | Maintenance |

## CREATE TABLE dependency order

1. departments
2. users
3. spaces
4. facilities
5. space_facilities
6. bookings
7. booking_approvals
8. booking_sessions
9. maintenance

---

### departments

**Status:** 🔒 locked
**Maps from entity:** Departments
**Primary key:** department_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| department_id | INT | NO | PK | IDENTITY(1,1) | Surrogate primary key |
| name | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | Audit timestamp |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | Audit timestamp |

**Foreign keys:** None.

---

### users

**Status:** 🔒 locked
**Maps from entity:** Users
**Primary key:** user_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| user_id | INT | NO | PK | IDENTITY(1,1) | Surrogate primary key |
| email | NVARCHAR(255) | NO | UQ | UNIQUE | Business key (A1) |
| full_name | NVARCHAR(255) | NO | — | — | |
| phone_number | NVARCHAR(50) | YES | — | — | Optional (A7) |
| role | VARCHAR(50) | NO | — | CHECK (role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')) | |
| department_id | INT | NO | FK | FK → departments.department_id | R1 |
| account_status | VARCHAR(50) | NO | — | CHECK (account_status IN ('active','inactive','suspended')), DEFAULT 'active' | |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|--------|-----------|-----------|-----------|
| department_id | departments.department_id | NO ACTION | NO ACTION |

---

### spaces

**Status:** 🔒 locked
**Maps from entity:** Spaces
**Primary key:** space_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| space_id | INT | NO | PK | IDENTITY(1,1) | |
| space_code | NVARCHAR(50) | NO | UQ | UNIQUE | Business key |
| space_name | NVARCHAR(255) | NO | — | — | |
| space_type | VARCHAR(50) | NO | — | CHECK (space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')) | |
| building | NVARCHAR(100) | NO | — | — | Free-text (Q5) |
| floor | NVARCHAR(50) | NO | — | — | Free-text (Q5) |
| room_number | NVARCHAR(50) | NO | — | — | |
| capacity | INT | NO | — | CHECK (capacity > 0) | |
| current_status | VARCHAR(50) | NO | — | CHECK (current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired')), DEFAULT 'available' | |
| usage_policy | NVARCHAR(MAX) | YES | — | — | Free-text (Q2) |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:** None.

---

### facilities

**Status:** 🔒 locked
**Maps from entity:** Facilities
**Primary key:** facility_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| facility_id | INT | NO | PK | IDENTITY(1,1) | |
| name | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:** None.

---

### space_facilities

**Status:** 🔒 locked
**Resolves relationship:** Spaces ↔ Facilities (R6)
**Primary key:** (space_id, facility_id) — composite

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| space_id | INT | NO | PK, FK | FK → spaces.space_id | Composite PK part |
| facility_id | INT | NO | PK, FK | FK → facilities.facility_id | Composite PK part |
| quantity | INT | YES | — | — | Optional count |

**Foreign keys:**

| Column | References | On Delete | On Update |
|--------|-----------|-----------|-----------|
| space_id | spaces.space_id | CASCADE | NO ACTION |
| facility_id | facilities.facility_id | CASCADE | NO ACTION |

---

### bookings

**Status:** 🔒 locked
**Maps from entity:** Bookings
**Primary key:** booking_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| booking_id | INT | NO | PK | IDENTITY(1,1) | |
| space_id | INT | NO | FK | FK → spaces.space_id | R5 |
| requester_id | INT | NO | FK | FK → users.user_id | R2 |
| requested_start_time | DATETIME2 | NO | — | — | |
| requested_end_time | DATETIME2 | NO | — | CHECK (requested_end_time > requested_start_time) | |
| purpose | VARCHAR(50) | NO | — | CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')) | |
| expected_participants | INT | NO | — | CHECK (expected_participants > 0) | |
| status | VARCHAR(50) | NO | — | CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')), DEFAULT 'pending' | |
| is_deleted | BIT | NO | — | DEFAULT 0 | Soft delete (BR11) |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|--------|-----------|-----------|-----------|
| space_id | spaces.space_id | NO ACTION | NO ACTION |
| requester_id | users.user_id | NO ACTION | NO ACTION |

---

### booking_approvals

**Status:** 🔒 locked (new — 2026-07-01)
**Maps from entity:** Booking_Approvals
**Primary key:** approval_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| approval_id | INT | NO | PK | IDENTITY(1,1) | |
| booking_id | INT | NO | UQ, FK | FK → bookings.booking_id | R10; UNIQUE enforces 1:0..1 |
| approver_id | INT | NO | FK | FK → users.user_id | R3; trigger-level: must be facility_staff/facility_manager (BR15) |
| decision_time | DATETIME2 | NO | — | — | |
| decision | VARCHAR(50) | NO | — | CHECK (decision IN ('approved','rejected')) | |
| rejection_reason | NVARCHAR(MAX) | YES | — | — | Trigger-level: required when decision='rejected' (BR7) |
| decision_note | NVARCHAR(MAX) | YES | — | — | Optional notes |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | Audit timestamp |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | Audit timestamp |

**Foreign keys:**

| Column | References | On Delete | On Update |
|--------|-----------|-----------|-----------|
| booking_id | bookings.booking_id | CASCADE | NO ACTION |
| approver_id | users.user_id | NO ACTION | NO ACTION |

---

### booking_sessions

**Status:** 🔒 locked (new — 2026-07-01)
**Maps from entity:** Booking_Sessions
**Primary key:** session_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| session_id | INT | NO | PK | IDENTITY(1,1) | |
| booking_id | INT | NO | UQ, FK | FK → bookings.booking_id | R11; UNIQUE enforces 1:0..1 |
| actual_start_time | DATETIME2 | NO | — | — | Set at check-in |
| checked_in_by | INT | NO | FK | FK → users.user_id | R4; trigger-level: must be facility_staff/facility_manager (BR16) |
| initial_condition | NVARCHAR(MAX) | YES | — | — | Optional at check-in |
| actual_end_time | DATETIME2 | YES | — | — | Set at completion |
| final_condition | NVARCHAR(MAX) | YES | — | — | Optional at completion |
| usage_notes | NVARCHAR(MAX) | YES | — | — | |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | Audit timestamp |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | Audit timestamp |

**Foreign keys:**

| Column | References | On Delete | On Update |
|--------|-----------|-----------|-----------|
| booking_id | bookings.booking_id | CASCADE | NO ACTION |
| checked_in_by | users.user_id | NO ACTION | NO ACTION |

---

### maintenance

**Status:** 🔒 locked
**Maps from entity:** Maintenance
**Primary key:** maintenance_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|--------|------|----------|-----|---------------------|-------|
| maintenance_id | INT | NO | PK | IDENTITY(1,1) | |
| space_id | INT | NO | FK | FK → spaces.space_id | R7 |
| reporter_id | INT | NO | FK | FK → users.user_id | R8 |
| assigned_staff_id | INT | YES | FK | FK → users.user_id | R9, BR5; trigger-level: must be facility_staff when set (BR17) |
| problem_description | NVARCHAR(MAX) | NO | — | — | |
| start_time | DATETIME2 | NO | — | — | |
| completion_time | DATETIME2 | YES | — | — | |
| status | VARCHAR(50) | NO | — | CHECK (status IN ('open','in_progress','resolved')), DEFAULT 'open' | |
| result_note | NVARCHAR(MAX) | YES | — | — | |
| is_deleted | BIT | NO | — | DEFAULT 0 | Soft delete (BR11) |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|--------|-----------|-----------|-----------|
| space_id | spaces.space_id | NO ACTION | NO ACTION |
| reporter_id | users.user_id | NO ACTION | NO ACTION |
| assigned_staff_id | users.user_id | SET NULL | NO ACTION |

---

## Indexes

| Index | Table | Column(s) | Type |
|-------|-------|-----------|------|
| PK_departments | departments | department_id | Clustered |
| UQ_departments_name | departments | name | Unique non-clustered |
| PK_users | users | user_id | Clustered |
| UQ_users_email | users | email | Unique non-clustered |
| idx_users_department_id | users | department_id | Non-clustered |
| PK_spaces | spaces | space_id | Clustered |
| UQ_spaces_space_code | spaces | space_code | Unique non-clustered |
| idx_spaces_current_status | spaces | current_status | Non-clustered |
| PK_facilities | facilities | facility_id | Clustered |
| UQ_facilities_name | facilities | name | Unique non-clustered |
| PK_space_facilities | space_facilities | space_id, facility_id | Clustered |
| idx_space_facilities_facility_id | space_facilities | facility_id | Non-clustered |
| PK_bookings | bookings | booking_id | Clustered |
| idx_bookings_space_id | bookings | space_id | Non-clustered |
| idx_bookings_requester_id | bookings | requester_id | Non-clustered |
| idx_bookings_status | bookings | status | Non-clustered |
| idx_bookings_time_range | bookings | space_id, requested_start_time, requested_end_time | Non-clustered |
| idx_bookings_requested_start | bookings | requested_start_time | Non-clustered |
| uq_bookings_active_overlap | bookings | space_id, requested_start_time (filtered WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0) | Unique non-clustered |
| PK_booking_approvals | booking_approvals | approval_id | Clustered |
| UQ_booking_approvals_booking_id | booking_approvals | booking_id | Unique non-clustered |
| idx_booking_approvals_approver_id | booking_approvals | approver_id | Non-clustered |
| PK_booking_sessions | booking_sessions | session_id | Clustered |
| UQ_booking_sessions_booking_id | booking_sessions | booking_id | Unique non-clustered |
| idx_booking_sessions_checked_in_by | booking_sessions | checked_in_by | Non-clustered |
| PK_maintenance | maintenance | maintenance_id | Clustered |
| idx_maintenance_space_id | maintenance | space_id | Non-clustered |
| idx_maintenance_reporter_id | maintenance | reporter_id | Non-clustered |
| idx_maintenance_assigned_staff_id | maintenance | assigned_staff_id | Non-clustered |
| idx_maintenance_status | maintenance | status | Non-clustered |

---

## Business Rule Coverage

| BR # | Rule | Enforcement | Level | Status |
|------|------|-------------|-------|--------|
| BR1 | No overlapping approved bookings | `uq_bookings_active_overlap` (filtered unique index) + `trg_bookings_prevent_overlap` (interval overlap trigger) | Database | ✅ Enforced |
| BR2 | Unavailable spaces cannot be approved | `trg_booking_approvals_check_space` trigger on `booking_approvals` INSERT when `decision='approved'` | Database | ✅ Enforced |
| BR3 | Expected participants ≤ space capacity | `trg_bookings_check_capacity` trigger | Database | ✅ Enforced |
| BR4 | Maintenance blocks booking | `trg_bookings_check_maintenance` trigger | Database | ✅ Enforced |
| BR5 | Maintenance assigned staff tracking | FK `assigned_staff_id` → `users(user_id)` with ON DELETE SET NULL | Database | ✅ Enforced |
| BR6 | Decision recording (approver, time, decision) | `trg_booking_approvals_decision` trigger | Database | ✅ Enforced |
| BR7 | Rejection requires reason | `trg_booking_approvals_rejection` trigger | Database | ✅ Enforced |
| BR8 | Actual time recording at check-in/completion | `trg_booking_sessions_checkin` (validates booking is 'approved', sets actual_start_time) + `trg_booking_sessions_completion` (validates actual_end_time at completion) | Database | ✅ Enforced |
| BR9 | Space condition tracking | `initial_condition`, `final_condition` + same triggers as BR8 | Database | ✅ Enforced |
| BR10 | Unique identification (email, space_code) | UNIQUE constraints on `users(email)`, `spaces(space_code)`, `departments(name)`, `facilities(name)` | Database | ✅ Enforced |
| BR11 | Soft deletes for bookings/maintenance | `is_deleted BIT NOT NULL DEFAULT 0` | Database | ✅ Enforced |
| BR12 | Audit trail (created_at, updated_at) | Both columns with `DEFAULT GETDATE()` on all tables | Database | ✅ Enforced |
| BR13 | Historical records preservation | Soft delete mechanism | Application + DB | ✅ Enforced |
| BR14 | Staff view reports | Supporting indexes present | Database | ✅ Enforced |
| BR15 | Approver must be facility staff/manager | `trg_booking_approvals_check_role` trigger | Database | ✅ Enforced |
| BR16 | Check-in staff must be facility staff/manager | `trg_booking_sessions_check_role` trigger | Database | ✅ Enforced |
| BR17 | Assigned maintenance staff must be facility staff | `trg_maintenance_check_assignee_role` trigger | Database | ✅ Enforced |
| BR18 | Cancellation validity and space cleanup | `trg_bookings_cancellation` trigger | Database | ✅ Enforced |
| BR19 | Maintenance completion restores space status | `trg_maintenance_completion_space_status` trigger | Database | ✅ Enforced |

**Note:** See `outputs/03-logical-design-G05.md` §7 for trigger implementation details.

---

## SCHEMA FREEZE

| Gate | Status | Date |
|------|--------|------|
| Entity registry locked | ✅ 🔒 | Task 03 (2026-07-01) — 9 entities finalized |
| Schema registry populated | ✅ 🔒 | Task 03 (2026-07-01) — regenerated with 9-table schema |
| Design validation passed | ✅ | Task 04 (2026-06-17) — re-validated 2026-06-18 |
| Index sync | ✅ Resolved | 2026-06-18 |
| **SCHEMA FREEZE** |  | — |

---

*Last updated: 2026-07-01 — 9-table schema with SRP booking split (bookings + booking_approvals + booking_sessions)*
