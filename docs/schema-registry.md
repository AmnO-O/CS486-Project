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
| 7 | maintenance | entity | 🔒 | Maintenance |

## CREATE TABLE dependency order

1. departments
2. users
3. spaces
4. facilities
5. space_facilities
6. bookings
7. maintenance

---

### departments

**Status:** 🔒 locked
**Maps from entity:** Departments
**Primary key:** department_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
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
|---|---|---|---|---|---|
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
|---|---|---|---|
| department_id | departments.department_id | NO ACTION | NO ACTION |

---

### spaces

**Status:** 🔒 locked
**Maps from entity:** Spaces
**Primary key:** space_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
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
|---|---|---|---|---|---|
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
|---|---|---|---|---|---|
| space_id | INT | NO | PK, FK | FK → spaces.space_id | Composite PK part |
| facility_id | INT | NO | PK, FK | FK → facilities.facility_id | Composite PK part |
| quantity | INT | YES | — | — | Optional count |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| space_id | spaces.space_id | CASCADE | NO ACTION |
| facility_id | facilities.facility_id | CASCADE | NO ACTION |

---

### bookings

**Status:** 🔒 locked
**Maps from entity:** Bookings
**Primary key:** booking_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| booking_id | INT | NO | PK | IDENTITY(1,1) | |
| space_id | INT | NO | FK | FK → spaces.space_id | R5 |
| requester_id | INT | NO | FK | FK → users.user_id | R2 |
| requested_start_time | DATETIME2 | NO | — | — | |
| requested_end_time | DATETIME2 | NO | — | CHECK (requested_end_time > requested_start_time) | |
| purpose | VARCHAR(50) | NO | — | CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')) | |
| expected_participants | INT | NO | — | CHECK (expected_participants > 0) | |
| status | VARCHAR(50) | NO | — | CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')), DEFAULT 'pending' | |
| approver_id | INT | YES | FK | FK → users.user_id | R3; application-level: must be facility_staff/facility_manager |
| decision_time | DATETIME2 | YES | — | — | Application-level: required when status = approved/rejected |
| decision_note | NVARCHAR(MAX) | YES | — | — | |
| rejection_reason | NVARCHAR(MAX) | YES | — | — | Application-level: required when status = rejected (BR7) |
| actual_start_time | DATETIME2 | YES | — | — | Set at check-in |
| checked_in_by | INT | YES | FK | FK → users.user_id | R4 |
| initial_condition | NVARCHAR(MAX) | YES | — | — | Set at check-in |
| actual_end_time | DATETIME2 | YES | — | — | Set at completion |
| final_condition | NVARCHAR(MAX) | YES | — | — | Set at completion |
| usage_notes | NVARCHAR(MAX) | YES | — | — | Set at completion |
| is_deleted | BIT | NO | — | DEFAULT 0 | Soft delete (BR11) |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| space_id | spaces.space_id | NO ACTION | NO ACTION |
| requester_id | users.user_id | NO ACTION | NO ACTION |
| approver_id | users.user_id | SET NULL | NO ACTION |
| checked_in_by | users.user_id | SET NULL | NO ACTION |

---

### maintenance

**Status:** 🔒 locked
**Maps from entity:** Maintenance
**Primary key:** maintenance_id (surrogate)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| maintenance_id | INT | NO | PK | IDENTITY(1,1) | |
| space_id | INT | NO | FK | FK → spaces.space_id | R7 |
| reporter_id | INT | NO | FK | FK → users.user_id | R8 |
| assigned_staff_id | INT | YES | FK | FK → users.user_id | R9, BR5; set when assigned |
| problem_description | NVARCHAR(MAX) | NO | — | — | |
| start_time | DATETIME2 | NO | — | — | When reported |
| completion_time | DATETIME2 | YES | — | — | When resolved |
| status | VARCHAR(50) | NO | — | CHECK (status IN ('open','in_progress','resolved')), DEFAULT 'open' | |
| result_note | NVARCHAR(MAX) | YES | — | — | Resolution summary |
| is_deleted | BIT | NO | — | DEFAULT 0 | Soft delete (BR11) |
| created_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | — | DEFAULT GETDATE() | |

**Foreign keys:**

| Column | References | On Delete | On Update |
|---|---|---|---|
| space_id | spaces.space_id | NO ACTION | NO ACTION |
| reporter_id | users.user_id | NO ACTION | NO ACTION |
| assigned_staff_id | users.user_id | SET NULL | NO ACTION |

---

## Indexes

| Index | Table | Column(s) | Type |
|---|---|---|---|
| PK__departments | departments | department_id | Clustered |
| UQ__departments__name | departments | name | Unique non-clustered |
| PK__users | users | user_id | Clustered |
| UQ__users__email | users | email | Unique non-clustered |
| idx_users_department_id | users | department_id | Non-clustered |
| PK__spaces | spaces | space_id | Clustered |
| UQ__spaces__space_code | spaces | space_code | Unique non-clustered |
| idx_spaces_current_status | spaces | current_status | Non-clustered |
| PK__facilities | facilities | facility_id | Clustered |
| UQ__facilities__name | facilities | name | Unique non-clustered |
| PK__space_facilities | space_facilities | space_id, facility_id | Clustered |
| idx_space_facilities_facility_id | space_facilities | facility_id | Non-clustered |
| PK__bookings | bookings | booking_id | Clustered |
| idx_bookings_space_id | bookings | space_id | Non-clustered |
| idx_bookings_requester_id | bookings | requester_id | Non-clustered |
| idx_bookings_status | bookings | status | Non-clustered |
| idx_bookings_time_range | bookings | space_id, requested_start_time, requested_end_time | Non-clustered |
| idx_bookings_approver_id | bookings | approver_id | Non-clustered |
| idx_bookings_checked_in_by | bookings | checked_in_by | Non-clustered |
| idx_bookings_requested_start | bookings | requested_start_time | Non-clustered |
| uq_bookings_active_overlap | bookings | space_id, requested_start_time (filtered WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0) | Unique non-clustered |
| PK__maintenance | maintenance | maintenance_id | Clustered |
| idx_maintenance_space_id | maintenance | space_id | Non-clustered |
| idx_maintenance_reporter_id | maintenance | reporter_id | Non-clustered |
| idx_maintenance_assigned_staff_id | maintenance | assigned_staff_id | Non-clustered |
| idx_maintenance_status | maintenance | status | Non-clustered |

---

## 3NF Normalization Proof

All tables satisfy 1NF (atomic values, no repeating groups), 2NF (no partial dependencies — all non-composite PKs are single-column; the only composite PK, space_facilities, has its sole non-key attribute depending on the full key), and 3NF (no transitive dependencies — all non-key attributes depend solely on the primary key in every table).

---

## Business Rule Coverage

Validated during Task 04 — Design Validation (2026-06-17, re-validated 2026-06-18).

| BR # | Rule | Enforcement | Level | Status |
|---|---|---|---|---|
| BR1 | No overlapping approved bookings | `uq_bookings_active_overlap` (filtered unique index) + `trg_bookings_prevent_overlap` (interval overlap trigger) | Database | ✅ Enforced |
| BR2 | Unavailable spaces cannot be booked | `trg_bookings_check_space_status` trigger | Database | ✅ Enforced |
| BR3 | Expected participants ≤ space capacity | `trg_bookings_check_capacity` trigger | Database | ✅ Enforced |
| BR4 | Maintenance blocks booking | `trg_bookings_check_maintenance` trigger | Database | ✅ Enforced |
| BR5 | Maintenance assigned staff tracking | FK `assigned_staff_id` → `users(user_id)` | Database | ✅ Enforced |
| BR6 | Decision recording (approver, time, note) | `trg_bookings_approval_validation` trigger | Database | ✅ Enforced |
| BR7 | Rejection requires reason | `trg_bookings_rejection_reason` trigger | Database | ✅ Enforced |
| BR8 | Actual time recording at check-in/completion | `actual_start_time`, `actual_end_time` + `trg_bookings_checkin_enforcement`, `trg_bookings_completion_enforcement` (enforce NOT NULL on status transition) | Database | ✅ Enforced |
| BR9 | Space condition tracking | `initial_condition`, `final_condition` + same triggers as BR8 | Database | ✅ Enforced |
| BR10 | Unique identification (email, space_code) | UNIQUE constraints on `users(email)`, `spaces(space_code)`, `departments(name)`, `facilities(name)` | Database | ✅ Enforced |
| BR11 | Soft deletes for bookings/maintenance | `is_deleted BIT NOT NULL DEFAULT 0` | Database | ✅ Enforced |
| BR12 | Audit trail (created_at, updated_at) | Both columns with `DEFAULT GETDATE()` on all tables | Database | ✅ Enforced |
| BR13 | Historical records preservation | Soft delete mechanism | Application + DB | ✅ Enforced |
| BR14 | Staff view reports | Supporting indexes present | Database | ✅ Enforced |

**Note:** See `outputs/04-design-validation-G05.md` §2 for detailed evidence.

---

## SCHEMA FREEZE

| Gate | Status | Date |
|---|---|---|
| Entity registry locked | ✅ 🔒 | Task 03 (2026-06-15) |
| Schema registry populated | ✅ 🔒 | Task 03 (2026-06-15) |
| Design validation passed | ✅ | Task 04 (2026-06-17) — re-validated 2026-06-18 (BR8/BR9 upgraded to database-level) |
| Index sync (D1, D2) | ✅ Resolved | 2026-06-18 — added 4 missing indexes, renamed idx_bookings_overlap → idx_bookings_time_range |
| **SCHEMA FREEZE** | **⏳ Pending group approval** | — |

---

*Last updated: 2026-06-18 (BR8/BR9 upgraded, D1/D2 index sync resolved)*
