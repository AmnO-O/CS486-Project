# Logical Database Design — Campus Space Management System

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Date:** 2026-06-15
**Status:** Revision 1 — improved constraint implementation and ambiguity resolution

---

## 1. Logical Design Overview

This document translates the conceptual ERD (Task 02) and entity definitions (`docs/entity-registry.md`) into a relational logical schema targeting Microsoft SQL Server (T-SQL, SQL Server 2019+). Every table, column, constraint, and index is justified by the business requirements (`outputs/01-business-req-analysis-G05.md`) and the entity registry.

**Scope:**
- 7 tables: `departments`, `users`, `spaces`, `facilities`, `space_facilities`, `bookings`, `maintenance`
- 9 relationships mapped (R1–R9)
- All business rules (BR1–BR14) enforced via constraints
- Normalized to at least 3NF

---

## 2. Table Definitions

### 2.1 departments

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| department_id | INT | NO | PRIMARY KEY | IDENTITY(1,1) |
| name | NVARCHAR(255) | NO | UNIQUE | Business key |
| created_at | DATETIME2 | NO | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | DEFAULT GETDATE() | |

### 2.2 users

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| user_id | INT | NO | PRIMARY KEY | IDENTITY(1,1) |
| email | NVARCHAR(255) | NO | UNIQUE | Business key (A1) |
| full_name | NVARCHAR(255) | NO | — | |
| phone_number | NVARCHAR(50) | YES | — | (A7) |
| role | VARCHAR(50) | NO | CHECK (role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')) | |
| department_id | INT | NO | FOREIGN KEY → departments(department_id) | |
| account_status | VARCHAR(50) | NO | CHECK (account_status IN ('active','inactive','suspended')) | DEFAULT 'active' |
| created_at | DATETIME2 | NO | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | DEFAULT GETDATE() | |

### 2.3 spaces

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| space_id | INT | NO | PRIMARY KEY | IDENTITY(1,1) |
| space_code | NVARCHAR(50) | NO | UNIQUE | Business key |
| space_name | NVARCHAR(255) | NO | — | Display name |
| space_type | VARCHAR(50) | NO | CHECK (space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')) | |
| building | NVARCHAR(100) | NO | — | Free-text (Q5) |
| floor | NVARCHAR(50) | NO | — | Free-text (Q5) |
| room_number | NVARCHAR(50) | NO | — | |
| capacity | INT | NO | CHECK (capacity > 0) | |
| current_status | VARCHAR(50) | NO | CHECK (current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired')) | DEFAULT 'available' |
| usage_policy | NVARCHAR(MAX) | YES | — | Free-text (Q2) |
| created_at | DATETIME2 | NO | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | DEFAULT GETDATE() | |

### 2.4 facilities

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| facility_id | INT | NO | PRIMARY KEY | IDENTITY(1,1) |
| name | NVARCHAR(255) | NO | UNIQUE | e.g. projector, whiteboard, microphone |
| created_at | DATETIME2 | NO | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | DEFAULT GETDATE() | |

### 2.5 space_facilities (junction table)

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| space_id | INT | NO | PRIMARY KEY, FOREIGN KEY → spaces(space_id) | Part of composite PK |
| facility_id | INT | NO | PRIMARY KEY, FOREIGN KEY → facilities(facility_id) | Part of composite PK |
| quantity | INT | YES | — | Optional count per space |

Composite PRIMARY KEY: (space_id, facility_id)

### 2.6 bookings

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| booking_id | INT | NO | PRIMARY KEY | IDENTITY(1,1) |
| space_id | INT | NO | FOREIGN KEY → spaces(space_id) | (R5) |
| requester_id | INT | NO | FOREIGN KEY → users(user_id) | (R2) |
| requested_start_time | DATETIME2 | NO | — | |
| requested_end_time | DATETIME2 | NO | CHECK (requested_end_time > requested_start_time) | |
| purpose | VARCHAR(50) | NO | CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')) | |
| expected_participants | INT | NO | CHECK (expected_participants > 0) | |
| status | VARCHAR(50) | NO | CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')) | DEFAULT 'pending' |
| approver_id | INT | YES | FOREIGN KEY → users(user_id) | (R3), set on decision |
| decision_time | DATETIME2 | YES | — | |
| decision_note | NVARCHAR(MAX) | YES | — | |
| rejection_reason | NVARCHAR(MAX) | YES | — | Required when status = 'rejected' (BR7) |
| actual_start_time | DATETIME2 | YES | — | At check-in |
| checked_in_by | INT | YES | FOREIGN KEY → users(user_id) | (R4), staff |
| initial_condition | NVARCHAR(MAX) | YES | — | At check-in |
| actual_end_time | DATETIME2 | YES | — | At completion |
| final_condition | NVARCHAR(MAX) | YES | — | At completion |
| usage_notes | NVARCHAR(MAX) | YES | — | At completion |
| is_deleted | BIT | NO | DEFAULT 0 | Soft delete (A4) |
| created_at | DATETIME2 | NO | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | DEFAULT GETDATE() | |

### 2.7 maintenance

| Column | Type | Nullable | Constraints | Notes |
|---|---|---|---|---|
| maintenance_id | INT | NO | PRIMARY KEY | IDENTITY(1,1) |
| space_id | INT | NO | FOREIGN KEY → spaces(space_id) | (R7) |
| reporter_id | INT | NO | FOREIGN KEY → users(user_id) | (R8) |
| assigned_staff_id | INT | YES | FOREIGN KEY → users(user_id) | (R9), may be set later |
| problem_description | NVARCHAR(MAX) | NO | — | |
| start_time | DATETIME2 | NO | — | When reported |
| completion_time | DATETIME2 | YES | — | When resolved |
| status | VARCHAR(50) | NO | CHECK (status IN ('open','in_progress','resolved')) | DEFAULT 'open' |
| result_note | NVARCHAR(MAX) | YES | — | Resolution summary |
| is_deleted | BIT | NO | DEFAULT 0 | Soft delete (A4) |
| created_at | DATETIME2 | NO | DEFAULT GETDATE() | |
| updated_at | DATETIME2 | NO | DEFAULT GETDATE() | |

---

## 3. Relationship Mapping (ERD → Logical Tables)

| # | Relationship | ERD Cardinality | Logical Implementation | Child FK Column | Parent Table |
|---|---|---|---|---|---|
| R1 | Departments → Users | 1:N | FK in `users` | `department_id` | `departments` |
| R2 | Users → Bookings (requester) | 1:N | FK in `bookings` | `requester_id` | `users` |
| R3 | Users → Bookings (approver) | 1:N (partial) | FK in `bookings` (nullable) | `approver_id` | `users` |
| R4 | Users → Bookings (checked-in by) | 1:N (partial) | FK in `bookings` (nullable) | `checked_in_by` | `users` |
| R5 | Spaces → Bookings | 1:N | FK in `bookings` | `space_id` | `spaces` |
| R6 | Spaces ↔ Facilities | M:N | Junction table `space_facilities` | `space_id`, `facility_id` | `spaces`, `facilities` |
| R7 | Spaces → Maintenance | 1:N | FK in `maintenance` | `space_id` | `spaces` |
| R8 | Users → Maintenance (reporter) | 1:N | FK in `maintenance` | `reporter_id` | `users` |
| R9 | Users → Maintenance (assigned staff) | 1:N (partial) | FK in `maintenance` (nullable) | `assigned_staff_id` | `users` |

**Referential integrity rules:**

| FK Column | Parent Table | ON DELETE | ON UPDATE | Rationale |
|---|---|---|---|---|
| `department_id` in `users` | departments | NO ACTION | NO ACTION | Prevent deleting departments with active users |
| `requester_id` in `bookings` | users | NO ACTION | NO ACTION | Prevent deleting users with booking history |
| `approver_id` in `bookings` | users | SET NULL | NO ACTION | Optional FK; nullify reference if approver deleted |
| `checked_in_by` in `bookings` | users | SET NULL | NO ACTION | Optional FK; nullify reference if staff deleted |
| `space_id` in `bookings` | spaces | NO ACTION | NO ACTION | Prevent deleting spaces with booking history |
| `space_id` in `space_facilities` | spaces | CASCADE | NO ACTION | If a space is deleted, its facility mappings go with it |
| `facility_id` in `space_facilities` | facilities | CASCADE | NO ACTION | If a facility type is deleted, its mappings go with it |
| `reporter_id` in `maintenance` | users | NO ACTION | NO ACTION | Prevent deleting users with maintenance reports |
| `assigned_staff_id` in `maintenance` | users | SET NULL | NO ACTION | Optional FK; nullify reference if staff deleted |
| `space_id` in `maintenance` | spaces | NO ACTION | NO ACTION | Prevent deleting spaces with maintenance records |

---

## 4. Index Strategy

| Index Name | Table (Columns) | Type | Rationale |
|---|---|---|---|
| PK__departments | departments(department_id) | CLUSTERED | PK (default) |
| PK__users | users(user_id) | CLUSTERED | PK (default) |
| PK__spaces | spaces(space_id) | CLUSTERED | PK (default) |
| PK__facilities | facilities(facility_id) | CLUSTERED | PK (default) |
| PK__space_facilities | space_facilities(space_id, facility_id) | CLUSTERED | Composite PK (default) |
| PK__bookings | bookings(booking_id) | CLUSTERED | PK (default) |
| PK__maintenance | maintenance(maintenance_id) | CLUSTERED | PK (default) |
| idx_users_department_id | users(department_id) | NONCLUSTERED | FK join performance |
| idx_users_email | users(email) | UNIQUE | Business key lookup |
| idx_spaces_space_code | spaces(space_code) | UNIQUE | Business key lookup |
| idx_spaces_current_status | spaces(current_status) | NONCLUSTERED | Filter by availability / maintenance |
| idx_bookings_space_id | bookings(space_id) | NONCLUSTERED | FK join / overlap detection |
| idx_bookings_requester_id | bookings(requester_id) | NONCLUSTERED | FK join / user history |
| idx_bookings_approver_id | bookings(approver_id) | NONCLUSTERED | FK join |
| idx_bookings_checked_in_by | bookings(checked_in_by) | NONCLUSTERED | FK join |
| idx_bookings_status | bookings(status) | NONCLUSTERED | Filter by lifecycle status |
| idx_bookings_time_range | bookings(space_id, requested_start_time, requested_end_time) | NONCLUSTERED | Overlap detection query (BR1) |
| idx_bookings_requested_start | bookings(requested_start_time) | NONCLUSTERED | Scheduling queries |
| uq_bookings_active_overlap | bookings(space_id, requested_start_time) | UNIQUE NONCLUSTERED (filtered) | WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0 — prevents exact start-time collisions for confirmed bookings; true interval overlap handled by trigger |
| idx_maintenance_space_id | maintenance(space_id) | NONCLUSTERED | FK join |
| idx_maintenance_reporter_id | maintenance(reporter_id) | NONCLUSTERED | FK join |
| idx_maintenance_assigned_staff_id | maintenance(assigned_staff_id) | NONCLUSTERED | FK join |
| idx_maintenance_status | maintenance(status) | NONCLUSTERED | Filter by lifecycle |

**Notes:**
- UNIQUE constraints (email, space_code, department name, facility name) create unique indexes implicitly in SQL Server.
- PK indexes are CLUSTERED by default in SQL Server.
- `uq_bookings_active_overlap` is a **filtered unique index** that prevents two confirmed bookings from having the same `requested_start_time` in the same space.
- True interval overlap detection (e.g. 10:00–12:00 conflicts with 11:00–13:00) requires a trigger or application check — a unique index cannot enforce range non-overlap.
- The `idx_bookings_time_range` covering index on `(space_id, requested_start_time, requested_end_time)` accelerates the overlap-checking query by providing an index seek on space_id with range scans on start/end times.

---

## 5. Normalization Proof (≥ 3NF)

### 5.1 1NF — Atomic Values, No Repeating Groups

| Table | 1NF Status | Evidence |
|---|---|---|
| departments | ✓ | All columns atomic; single value per cell. |
| users | ✓ | All columns atomic; single value per cell. |
| spaces | ✓ | All columns atomic; single value per cell. |
| facilities | ✓ | All columns atomic; single value per cell. |
| space_facilities | ✓ | Junction resolves M:N into atomic rows. |
| bookings | ✓ | All columns atomic; single value per cell. |
| maintenance | ✓ | All columns atomic; single value per cell. |

No table contains multi-valued attributes or repeating groups. The M:N relationship between spaces and facilities is resolved by the junction table `space_facilities`.

### 5.2 2NF — No Partial Dependencies

| Table | PK | 2NF Status | Evidence |
|---|---|---|---|
| departments | department_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| users | user_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| spaces | space_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| facilities | facility_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| space_facilities | (space_id, facility_id) composite | ✓ | `quantity` depends on the full composite key (which space has how many of which facility), not on space_id or facility_id alone. |
| bookings | booking_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| maintenance | maintenance_id (single) | ✓ | Single-column PK; no partial dependency possible. |

### 5.3 3NF — No Transitive Dependencies

| Table | 3NF Status | Evidence |
|---|---|---|
| departments | ✓ | All non-key attributes (`name`, `created_at`, `updated_at`) depend solely on `department_id`. |
| users | ✓ | `email`, `full_name`, `phone_number`, `role`, `department_id`, `account_status` depend solely on `user_id`. `department_id` is a FK, not a transitive dependency. |
| spaces | ✓ | All non-key attributes (`space_code`, `space_name`, `space_type`, `building`, `floor`, `room_number`, `capacity`, `current_status`, `usage_policy`) depend solely on `space_id`. No attribute depends on another non-key attribute. |
| facilities | ✓ | All non-key attributes (`name`) depend solely on `facility_id`. |
| space_facilities | ✓ | `quantity` depends on the full composite key (space_id, facility_id). No transitive dependency. |
| bookings | ✓ | All non-key attributes depend solely on `booking_id`. `space_id`, `requester_id`, `approver_id`, `checked_in_by` are FKs referencing other tables, not transitive dependencies. `rejection_reason` depends on `status` conceptually, but this is enforced via application logic/triggers, not a functional dependency that violates 3NF. |
| maintenance | ✓ | All non-key attributes depend solely on `maintenance_id`. `space_id`, `reporter_id`, `assigned_staff_id` are FKs. |

**Conclusion:** All 7 tables satisfy 3NF.

---

## 6. Naming Conventions Applied

| Object Type | Convention | Examples |
|---|---|---|
| Table names | snake_case, plural | `departments`, `space_facilities`, `bookings` |
| Column names | snake_case | `actual_start_time`, `decision_note` |
| Primary key | `<table_singular>_id` | `booking_id`, `space_id`, `user_id` |
| Foreign key | Same name as referenced PK | `space_id`, `department_id`, `requester_id` |
| Junction table | `<tableA>_<tableB>` (alpha order) | `space_facilities` |
| Enum/status values | lowercase with underscores | `checked_in`, `no_show`, `under_maintenance` |
| Index | `idx_<table>_<column>` | `idx_bookings_space_id`, `idx_users_email` |
| Data types per tech-stack | INT IDENTITY, NVARCHAR, VARCHAR(50) for enums, DATETIME2, BIT, NVARCHAR(MAX) | Per `docs/tech-stack.md` |

---

## 7. Constraint Implementation for Business Rules

| BR # | Business Rule | Implementation | Enforcement Level |
|---|---|---|---|---|
| BR1 | No overlapping approved bookings | `uq_bookings_active_overlap` (filtered unique index on space_id + requested_start_time for confirmed bookings) prevents exact same-start collisions; `trg_bookings_prevent_overlap` trigger checks (`space_id`, `requested_start_time`, `requested_end_time`) interval overlap against existing rows WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0 | Database (index + trigger) |
| BR2 | Unavailable spaces cannot be booked | `trg_bookings_check_space_status` trigger reads `spaces.current_status` and rejects INSERT/UPDATE if space status NOT IN ('available','in_use') | Database (trigger) |
| BR3 | Expected participants ≤ space capacity | `trg_bookings_check_capacity` trigger reads `spaces.capacity` and rejects if `expected_participants > capacity` | Database (trigger) |
| BR4 | Maintenance blocks booking | `trg_bookings_check_maintenance` trigger checks for overlapping maintenance WHERE status IN ('open','in_progress') for the same space and time range | Database (trigger) |
| BR5 | Maintenance assigned staff tracking | `assigned_staff_id` FK → `users(user_id)` (nullable) | FK constraint |
| BR6 | Decision recording (approver, time, note) | `trg_bookings_approval_validation` trigger enforces that when status changes TO 'approved' or 'rejected', `approver_id`, `decision_time`, and `decision_note` are NOT NULL | Database (trigger) |
| BR7 | Rejection requires reason | `trg_bookings_rejection_reason` trigger enforces that when status changes TO 'rejected', `rejection_reason` IS NOT NULL | Database (trigger) |
| BR8 | Actual time recording at check-in/completion | `actual_start_time`, `actual_end_time` columns (nullable, set on status transition) | Application (timestamp set during check-in/completion workflow) |
| BR9 | Space condition tracking | `initial_condition`, `final_condition` columns (nullable, recorded during workflow) | Application |
| BR10 | Unique identification (email, space_code) | UNIQUE constraints on `users(email)`, `spaces(space_code)`, `departments(name)`, `facilities(name)` | Database (UNIQUE index) |
| BR11 | Soft deletes for bookings/maintenance | `is_deleted BIT NOT NULL DEFAULT 0` on both tables | Database (DEFAULT) |
| BR12 | Audit trail (created_at, updated_at) | All tables have `created_at` and `updated_at` with GETDATE() defaults | Database (DEFAULT) |
| BR13 | Historical records preservation | Soft delete + no hard DELETE operations | Application + Database |
| BR14 | Staff view: booking history, upcoming, maintenance, no-shows | Supported by indexes: `idx_bookings_requester_id`, `idx_bookings_status`, `idx_bookings_requested_start`, `idx_maintenance_status`, etc. | Database (indexes) |

### Cross-table and cross-row constraints (trigger implementations)

The following business rules involve cross-table or cross-row validation that `CHECK` constraints cannot express in SQL Server (subqueries are not re-evaluated on referenced table changes). Each is enforced by an `INSTEAD OF` or `AFTER` trigger:

| Trigger | Fires On | Enforcement Logic |
|---|---|---|
| `trg_bookings_prevent_overlap` | `bookings` INSERT, UPDATE | Before insert/update, check if any existing row with the same `space_id` has status IN ('approved','checked_in','completed'), `is_deleted = 0`, and an overlapping time range: `requested_start_time < new.requested_end_time AND requested_end_time > new.requested_start_time`. If overlap found, `RAISERROR` and rollback. |
| `trg_bookings_check_space_status` | `bookings` INSERT, UPDATE | Before insert/update, check `spaces.current_status` for the booked space. Reject if NOT IN ('available','in_use'). |
| `trg_bookings_check_capacity` | `bookings` INSERT, UPDATE | Reject if `new.expected_participants > (SELECT capacity FROM spaces WHERE space_id = new.space_id)`. |
| `trg_bookings_check_maintenance` | `bookings` INSERT, UPDATE | Reject if there exists an overlapping maintenance record for the same space WHERE status IN ('open','in_progress') AND `start_time < new.requested_end_time AND (completion_time IS NULL OR completion_time > new.requested_start_time)`. |
| `trg_bookings_approval_validation` | `bookings` UPDATE | When `new.status` IN ('approved','rejected') AND `old.status` = 'pending', enforce: `new.approver_id IS NOT NULL` AND `new.decision_time IS NOT NULL` AND `new.decision_note IS NOT NULL`. |
| `trg_bookings_rejection_reason` | `bookings` UPDATE | When `new.status = 'rejected'`, enforce: `new.rejection_reason IS NOT NULL`. |
| `trg_maintenance_completion_space_status` | `maintenance` UPDATE | When `new.status = 'resolved'` AND `old.status != 'resolved'`, auto-update `spaces.current_status = 'available'` for the related space if its status is 'under_maintenance'. |

**Note on overlap detection (BR1):** The filtered unique index `uq_bookings_active_overlap` provides a lightweight pre-check for exact `(space_id, requested_start_time)` duplicates, while `trg_bookings_prevent_overlap` handles the general interval-overlap case. Both operate at the database level, ensuring data integrity even if multiple clients submit concurrent requests.

---

## 8. Deviations from ERD (with Justification)

| # | ERD Element | Logical Design | Deviation | Justification |
|---|---|---|---|---|
| D1 | Mermaid ERD shows `Users \|o--o{ Bookings: "approves"` (partial) | `approver_id INT NULL` in `bookings` with FK → users | None | Partial participation correctly modeled as nullable FK. |
| D2 | Mermaid ERD shows `Users \|o--o{ Bookings: "checks_in"` (partial) | `checked_in_by INT NULL` in `bookings` with FK → users | None | Partial participation correctly modeled as nullable FK. |
| D3 | Mermaid ERD shows `Users \|o--o{ Maintenance: "assigned_to"` (partial) | `assigned_staff_id INT NULL` in `maintenance` with FK → users | None | Partial participation correctly modeled as nullable FK. |
| D4 | ERD entity-registry lists `account_status` as provisional enum | Finalized as `CHECK IN ('active','inactive','suspended')` with DEFAULT 'active' | Finalization | Requirement §2 states "Account Status" exists but does not enumerate values. Standard account lifecycle values chosen. |
| D5 | ERD does not show explicit `is_deleted` on maintenance | `is_deleted BIT NOT NULL DEFAULT 0` on maintenance | Included | Assumption A4 requires soft deletion for both bookings and maintenance. The ERD showed it only on Bookings, but the business requirement applies to both. |
| D6 | Q5: building/floor as reference tables vs varchar fields | Stored as free-text `NVARCHAR` fields on `spaces` | No deviation from entity-registry | Consistent with entity-registry specification. Building/floor reference tables would add complexity without corresponding query requirement. |

### Resolved ambiguities

| Ambiguity | Resolution | Rationale |
|---|---|---|
| Q1: Rejection reason — separate column or part of decision note? | Separate `rejection_reason NVARCHAR(MAX) NULL` column | Business Rule 7 explicitly states "rejection reason must be stored" — storing it in a dedicated column makes querying and enforcement cleaner. |
| Q2: Usage policy — free text or coded rules? | `usage_policy NVARCHAR(MAX) NULL` (free text) | The requirement does not define a fixed set of policies; free text provides flexibility. |
| Q3: Maintenance-to-booking interaction — can a space be booked after maintenance is resolved but before space status is manually updated? | `trg_maintenance_completion_space_status` trigger auto-updates `spaces.current_status = 'available'` when a maintenance record transitions to `status = 'resolved'`. Additionally, BR4 trigger (`trg_bookings_check_maintenance`) checks for overlapping unresolved maintenance regardless of space status, providing a double safety net. | Automation removes the manual-step gap; the overlap trigger provides defense-in-depth. |
| Q4: No-show detection — automatic or manual? | Automatic: a scheduled SQL Server Agent job (or external scheduler) runs periodically, setting `status = 'no_show'` for bookings WHERE `status = 'approved'` AND `actual_start_time IS NULL` AND `requested_end_time < GETDATE()` AND `is_deleted = 0`. | Prevents unreconciled approved bookings from lingering indefinitely; reduces manual workload for facility staff. |
| Q5: Building/floor — reference tables or varchar fields? | `NVARCHAR` fields on `spaces` table | No requirement for independent building/floor CRUD or cross-building queries that would justify separate normalized tables. |

---

## 9. Revision Log

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-06-15 | Initial logical design |
| 1.1 | 2026-06-15 | Added filtered unique index `uq_bookings_active_overlap` for BR1 exact-start collision prevention; replaced generic "application-level" enforcement with 7 concrete trigger definitions; resolved Q3 (auto space-status on maintenance completion) and Q4 (automatic no-show detection); added per-FK ON DELETE referential rules; strengthened index strategy with filtered index; improved cross-column constraint documentation with detailed trigger logic |

---

*Generated for CS486 Group G05 — Campus Space Management System*