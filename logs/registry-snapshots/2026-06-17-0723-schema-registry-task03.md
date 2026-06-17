# Schema Registry — CS486 Space Booking System

> Snapshot generated from `outputs/03-logical-design-G05.md` (2026-06-17).
> Current `docs/schema-registry.md` already contains data — this snapshot is for
> human merge review per Task 03 protocol.

---

## Table inventory

| # | Table | Type | Status | Maps from |
|---|---|---|---|---|
| 1 | departments | entity | 🔒 | Departments |
| 2 | users | entity | 🔒 | Users |
| 3 | spaces | entity | 🔒 | Spaces |
| 4 | facilities | entity | 🔒 | Facilities |
| 5 | space_facilities | junction | 🔒 | R6 (Spaces ↔ Facilities) |
| 6 | bookings | entity | 🔒 | Bookings |
| 7 | maintenance | entity | 🔒 | Maintenance |

## CREATE TABLE dependency order

1. departments
2. facilities
3. users
4. spaces
5. space_facilities
6. bookings
7. maintenance

---

### departments

**Status:** 🔒 locked
**Maps from entity:** Departments (see entity-registry.md)
**Primary key:** `department_id` (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| department_id | INT | NO | PK | IDENTITY(1,1) | Surrogate PK |
| name | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

---

### facilities

**Status:** 🔒 locked
**Maps from entity:** Facilities (see entity-registry.md)
**Primary key:** `facility_id` (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| facility_id | INT | NO | PK | IDENTITY(1,1) | Surrogate PK |
| name | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

---

### users

**Status:** 🔒 locked
**Maps from entity:** Users (see entity-registry.md)
**Primary key:** `user_id` (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| user_id | INT | NO | PK | IDENTITY(1,1) | Surrogate PK |
| email | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| full_name | NVARCHAR(255) | NO | — | — | |
| phone_number | NVARCHAR(50) | YES | — | — | |
| role | VARCHAR(50) | NO | — | CHECK IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager') | |
| department_id | INT | NO | FK | FK → departments.department_id | |
| account_status | VARCHAR(50) | NO | — | CHECK IN ('active','inactive','suspended') | DEFAULT 'active' |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| department_id | departments.department_id | NO ACTION | CASCADE |

---

### spaces

**Status:** 🔒 locked
**Maps from entity:** Spaces (see entity-registry.md)
**Primary key:** `space_id` (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| space_id | INT | NO | PK | IDENTITY(1,1) | Surrogate PK |
| space_code | NVARCHAR(50) | NO | UQ | UNIQUE | Business key |
| space_name | NVARCHAR(255) | NO | — | — | |
| space_type | VARCHAR(50) | NO | — | CHECK IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace') | |
| building | NVARCHAR(100) | NO | — | — | |
| floor | NVARCHAR(50) | NO | — | — | |
| room_number | NVARCHAR(50) | NO | — | — | |
| capacity | INT | NO | — | CHECK (capacity > 0) | |
| current_status | VARCHAR(50) | NO | — | CHECK IN ('available','in_use','under_maintenance','temporarily_closed','retired') | DEFAULT 'available' |
| usage_policy | NVARCHAR(MAX) | YES | — | — | |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

---

### space_facilities

**Status:** 🔒 locked
**Resolves relationship:** Spaces ↔ Facilities (R6)
**Primary key:** `(space_id, facility_id)` (composite)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| space_id | INT | NO | PK, FK | FK → spaces.space_id | Part of composite PK |
| facility_id | INT | NO | PK, FK | FK → facilities.facility_id | Part of composite PK |
| quantity | INT | YES | — | — | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| space_id | spaces.space_id | CASCADE | CASCADE |
| facility_id | facilities.facility_id | CASCADE | CASCADE |

---

### bookings

**Status:** 🔒 locked
**Maps from entity:** Bookings (see entity-registry.md)
**Primary key:** `booking_id` (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| booking_id | INT | NO | PK | IDENTITY(1,1) | |
| space_id | INT | NO | FK | FK → spaces.space_id | |
| requester_id | INT | NO | FK | FK → users.user_id | |
| requested_start_time | DATETIME2 | NO | — | — | |
| requested_end_time | DATETIME2 | NO | — | CHECK (requested_end_time > requested_start_time) | |
| purpose | VARCHAR(50) | NO | — | CHECK IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event') | |
| expected_participants | INT | NO | — | CHECK (expected_participants > 0) | |
| status | VARCHAR(50) | NO | — | CHECK IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show') | DEFAULT 'pending' |
| approver_id | INT | YES | FK | FK → users.user_id | |
| decision_time | DATETIME2 | YES | — | — | |
| decision_note | NVARCHAR(MAX) | YES | — | — | |
| rejection_reason | NVARCHAR(MAX) | YES | — | — | |
| actual_start_time | DATETIME2 | YES | — | — | |
| checked_in_by | INT | YES | FK | FK → users.user_id | |
| initial_condition | NVARCHAR(MAX) | YES | — | — | |
| actual_end_time | DATETIME2 | YES | — | — | |
| final_condition | NVARCHAR(MAX) | YES | — | — | |
| usage_notes | NVARCHAR(MAX) | YES | — | — | |
| is_deleted | BIT | NO | — | DEFAULT 0 | |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| space_id | spaces.space_id | NO ACTION | CASCADE |
| requester_id | users.user_id | NO ACTION | CASCADE |
| approver_id | users.user_id | NO ACTION | NO ACTION |
| checked_in_by | users.user_id | NO ACTION | NO ACTION |

---

### maintenance

**Status:** 🔒 locked
**Maps from entity:** Maintenance (see entity-registry.md)
**Primary key:** `maintenance_id` (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| maintenance_id | INT | NO | PK | IDENTITY(1,1) | |
| space_id | INT | NO | FK | FK → spaces.space_id | |
| reporter_id | INT | NO | FK | FK → users.user_id | |
| assigned_staff_id | INT | YES | FK | FK → users.user_id | |
| problem_description | NVARCHAR(MAX) | NO | — | — | |
| start_time | DATETIME2 | NO | — | — | |
| completion_time | DATETIME2 | YES | — | — | |
| status | VARCHAR(50) | NO | — | CHECK IN ('open','in_progress','resolved') | DEFAULT 'open' |
| result_note | NVARCHAR(MAX) | YES | — | — | |
| is_deleted | BIT | NO | — | DEFAULT 0 | |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| space_id | spaces.space_id | CASCADE | CASCADE |
| reporter_id | users.user_id | NO ACTION | CASCADE |
| assigned_staff_id | users.user_id | NO ACTION | NO ACTION |

---

*Snapshot generated 2026-06-17 for Task 03 logical design. Matches current docs/schema-registry.md content.*
