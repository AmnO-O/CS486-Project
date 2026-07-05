# Logical Database Design — Campus Space Management System

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Date:** 2026-07-05
**Status:** Regenerated — 11-table schema, +facility_assignments, R6 bridged through assignments, facilities.space_id cached (run_03)

---

## 1. Logical Design Overview

This document translates the conceptual ERD (Task 02) and entity definitions (`docs/entity-registry.md`) into a relational logical schema targeting Microsoft SQL Server (T-SQL, SQL Server 2019+). Every table, column, constraint, and index is justified by the business requirements (`outputs/01-business-req-analysis-G05.md`) and the entity registry.

**Scope:**
- 11 tables: `departments`, `users`, `spaces`, `facility_categories`, `facilities`, `facility_assignments`, `bookings`, `booking_approvals`, `booking_sessions`, `maintenance`, `incidents`
- 19 relationships mapped (R1–R19)
- All business rules (BR1–BR23) enforced via constraints, indexes, and triggers
- Normalized to at least 3NF

---

## 2. Table Definitions

### 2.1 departments

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| department_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| name | NVARCHAR(255) | NO | UQ | — | — | Business key |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.2 users

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| user_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| email | NVARCHAR(255) | NO | UQ | — | — | Business key (A1, BR10) |
| full_name | NVARCHAR(255) | NO | — | — | — | |
| phone_number | NVARCHAR(50) | YES | — | — | — | Optional (A7) |
| role | VARCHAR(50) | NO | — | — | — | CHECK IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager') |
| department_id | INT | NO | — | departments(department_id) | — | FK to departments (R1) |
| account_status | VARCHAR(50) | NO | — | — | 'active' | CHECK IN ('active','inactive','suspended') |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.3 spaces

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| space_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| space_code | NVARCHAR(50) | NO | UQ | — | — | Business key (BR10) |
| space_name | NVARCHAR(255) | NO | — | — | — | Display name |
| space_type | VARCHAR(50) | NO | — | — | — | CHECK IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace') |
| building | NVARCHAR(100) | NO | — | — | — | Free-text (Q5) |
| floor | NVARCHAR(50) | NO | — | — | — | Free-text (Q5) |
| room_number | NVARCHAR(50) | NO | — | — | — | |
| capacity | INT | NO | — | — | — | CHECK (capacity > 0) |
| current_status | VARCHAR(50) | NO | — | — | 'available' | CHECK IN ('available','in_use','under_maintenance','temporarily_closed','retired') |
| usage_policy | NVARCHAR(MAX) | YES | — | — | — | Free-text (Q2) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.4 facility_categories

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| category_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| category_name | VARCHAR(50) | NO | UQ | — | — | Business key; values: projector, whiteboard, microphone, computer, air_conditioner, livestreaming_equipment |
| prefix | CHAR(3) | NO | UQ | — | — | 3-char code; values: pro, whb, mic, com, air, liv |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.5 facilities

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| facility_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| category_id | INT | NO | — | facility_categories(category_id) | — | FK to facility_categories (R15) |
| space_id | INT | YES | — | spaces(space_id) | — | FK to spaces (R6); NULL = device in storage |
| status | VARCHAR(20) | NO | — | — | 'active' | CHECK IN ('active','inactive','retired','lost') |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.6 bookings

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| booking_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| space_id | INT | NO | — | spaces(space_id) | — | FK to spaces (R5) |
| requester_id | INT | NO | — | users(user_id) | — | FK to users (R2) |
| requested_start_time | DATETIME2 | NO | — | — | — | |
| requested_end_time | DATETIME2 | NO | — | — | — | CHECK (requested_end_time > requested_start_time) |
| purpose | VARCHAR(50) | NO | — | — | — | CHECK IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event') |
| expected_participants | INT | NO | — | — | — | CHECK (expected_participants > 0) |
| status | VARCHAR(50) | NO | — | — | 'pending' | CHECK IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show') |
| is_deleted | BIT | NO | — | — | 0 | Soft delete (A4, BR11) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.7 booking_approvals

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| approval_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| booking_id | INT | NO | UQ | bookings(booking_id) | — | FK + UQ — 1:0..1 (R10) |
| approver_id | INT | NO | — | users(user_id) | — | FK to users (R3); must be facility_staff/facility_manager |
| decision_time | DATETIME2 | NO | — | — | — | When decision was made |
| decision | VARCHAR(50) | NO | — | — | — | CHECK IN ('approved','rejected') |
| rejection_reason | NVARCHAR(MAX) | YES | — | — | — | Required when decision='rejected' (BR7) |
| decision_note | NVARCHAR(MAX) | YES | — | — | — | Optional notes |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.8 booking_sessions

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| session_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| booking_id | INT | NO | UQ | bookings(booking_id) | — | FK + UQ — 1:0..1 (R11) |
| actual_start_time | DATETIME2 | NO | — | — | — | Set at check-in |
| checked_in_by | INT | NO | — | users(user_id) | — | FK to users (R4); must be facility_staff/facility_manager |
| initial_condition | NVARCHAR(MAX) | YES | — | — | — | Optional but recommended at check-in |
| actual_end_time | DATETIME2 | YES | — | — | — | Set at completion |
| final_condition | NVARCHAR(MAX) | YES | — | — | — | Optional but recommended at completion |
| usage_notes | NVARCHAR(MAX) | YES | — | — | — | Free-text usage notes |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.9 maintenance

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| maintenance_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| space_id | INT | NO | — | spaces(space_id) | — | FK to spaces (R7) |
| reporter_id | INT | NO | — | users(user_id) | — | FK to users (R8) |
| assigned_staff_id | INT | YES | — | users(user_id) | — | FK to users (R9); nullable until assigned |
| facility_id | INT | YES | — | facilities(facility_id) | — | FK to facilities (R16); nullable if maintenance is space-level, not device-level |
| problem_description | NVARCHAR(MAX) | NO | — | — | — | |
| start_time | DATETIME2 | NO | — | — | — | When reported |
| completion_time | DATETIME2 | YES | — | — | — | When resolved |
| status | VARCHAR(50) | NO | — | — | 'open' | CHECK IN ('open','in_progress','resolved') |
| result_note | NVARCHAR(MAX) | YES | — | — | — | Resolution summary |
| is_deleted | BIT | NO | — | — | 0 | Soft delete (A4, BR11) |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.10 incidents

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| incident_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| space_id | INT | NO | — | spaces(space_id) | — | FK to spaces (R12) |
| reported_by | INT | NO | — | users(user_id) | — | FK to users (R13) |
| incident_type | VARCHAR(50) | NO | — | — | — | CHECK IN ('theft','vandalism','accident','safety_hazard','policy_violation','lost_found','other') |
| severity | VARCHAR(20) | NO | — | — | 'medium' | CHECK IN ('low','medium','high','critical') |
| description | NVARCHAR(MAX) | NO | — | — | — | Detailed incident description |
| status | VARCHAR(30) | NO | — | — | 'reported' | CHECK IN ('reported','investigating','resolved','closed') |
| assigned_to | INT | YES | — | users(user_id) | — | FK to users (R14); nullable until assigned |
| facility_id | INT | YES | — | facilities(facility_id) | — | FK to facilities (R17); nullable if incident is space-level, not device-level |
| resolved_at | DATETIME2 | YES | — | — | — | Auto-set by trigger when maintenance resolves |
| resolution_notes | NVARCHAR(MAX) | YES | — | — | — | Resolution details |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

### 2.11 facility_assignments

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| assignment_id | INT | NO | PK | — | IDENTITY(1,1) | Surrogate PK |
| facility_id | INT | NO | — | facilities(facility_id) | — | FK to facilities (R18); total — every assignment references a device |
| space_id | INT | NO | — | spaces(space_id) | — | FK to spaces (R19); total — target location |
| start_time | DATETIME2 | NO | — | — | — | When assignment takes effect |
| end_time | DATETIME2 | NO | — | — | — | When assignment ends; CHECK (end_time > start_time) |
| purpose | NVARCHAR(255) | YES | — | — | — | Free-text reason (e.g. event name, project) |
| status | VARCHAR(20) | NO | — | — | 'planned' | CHECK IN ('planned','active','completed','cancelled') |
| created_by | INT | NO | — | users(user_id) | — | FK to users; who created the assignment |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | Audit trail (BR12) |

**Note:** `facilities.space_id` is a cached column synced by the application layer based on the current active assignment. The source of truth for facility location over time is the `facility_assignments` table.

---

## 3. Relationship Mapping (ERD → Logical Tables)

| # | Relationship | Cardinality | Logical Implementation | Child FK Column | Parent Table |
|---|---|---|---|---|---|
| R1 | Departments → Users | 1:N | FK in `users` | department_id | departments |
| R2 | Users → Bookings (requester) | 1:N | FK in `bookings` | requester_id | users |
| R3 | Users → Booking_Approvals (approver) | 1:N | FK in `booking_approvals` | approver_id | users |
| R4 | Users → Booking_Sessions (checks_in) | 1:N | FK in `booking_sessions` | checked_in_by | users |
| R5 | Spaces → Bookings | 1:N | FK in `bookings` | space_id | spaces |
| R6 | Spaces ↔ Facilities (via assignments) | M:N (bridge) | Resolved through `facility_assignments` junction (R18 + R19); `facilities.space_id` is cached column synced by app layer | — | — |
| R7 | Spaces → Maintenance | 1:N | FK in `maintenance` | space_id | spaces |
| R8 | Users → Maintenance (reporter) | 1:N | FK in `maintenance` | reporter_id | users |
| R9 | Users → Maintenance (assigned staff) | 1:N (partial) | FK in `maintenance` (nullable) | assigned_staff_id | users |
| R10 | Bookings → Booking_Approvals | 1:0..1 | FK in `booking_approvals` (UQ) | booking_id | bookings |
| R11 | Bookings → Booking_Sessions | 1:0..1 | FK in `booking_sessions` (UQ) | booking_id | bookings |
| R12 | Spaces → Incidents | 1:N | FK in `incidents` | space_id | spaces |
| R13 | Users → Incidents (reporter) | 1:N | FK in `incidents` | reported_by | users |
| R14 | Users → Incidents (assigned_to) | 1:N (partial) | FK in `incidents` (nullable) | assigned_to | users |
| R15 | Facility_Categories → Facilities | 1:N | FK in `facilities` | category_id | facility_categories |
| R16 | Facilities → Maintenance | 1:N (partial) | FK in `maintenance` (nullable) | facility_id | facilities |
| R17 | Facilities → Incidents | 1:N (partial) | FK in `incidents` (nullable) | facility_id | facilities |
| R18 | Facilities → Facility_Assignments | 1:N | FK in `facility_assignments` (NOT NULL) | facility_id | facilities |
| R19 | Spaces → Facility_Assignments | 1:N | FK in `facility_assignments` (NOT NULL) | space_id | spaces |

**Referential Integrity Rules:**

| FK Column | Child Table | Parent Table | ON DELETE | ON UPDATE | Rationale |
|-----------|-------------|--------------|-----------|-----------|----------|
| department_id | users | departments | NO ACTION | NO ACTION | Prevent deleting departments with active users |
| requester_id | bookings | users | NO ACTION | NO ACTION | Preserve booking history; use soft delete instead |
| space_id | bookings | spaces | NO ACTION | NO ACTION | Prevent deleting spaces with booking history |
| booking_id | booking_approvals | bookings | CASCADE | NO ACTION | Dependent child; no independent meaning without parent booking |
| approver_id | booking_approvals | users | NO ACTION | NO ACTION | Preserve historical approval reference |
| booking_id | booking_sessions | bookings | CASCADE | NO ACTION | Dependent child; no independent meaning without parent booking |
| checked_in_by | booking_sessions | users | NO ACTION | NO ACTION | Preserve historical check-in reference |
| space_id | maintenance | spaces | NO ACTION | NO ACTION | Prevent deleting spaces with maintenance records |
| reporter_id | maintenance | users | NO ACTION | NO ACTION | Preserve historical reporter reference |
| assigned_staff_id | maintenance | users | SET NULL | NO ACTION | Optional FK; nullify reference if staff deleted; only SET NULL FK from this table, no cascade path conflict |
| space_id | incidents | spaces | NO ACTION | NO ACTION | Preserve incident history for audit |
| reported_by | incidents | users | NO ACTION | NO ACTION | Preserve reporter reference |
| assigned_to | incidents | users | SET NULL | NO ACTION | Optional FK; nullify if staff deleted |
| category_id | facilities | facility_categories | NO ACTION | NO ACTION | Prevent deleting categories with active facilities |
| facility_id | maintenance | facilities | SET NULL | NO ACTION | Optional FK; nullify reference if facility is deleted |
| facility_id | incidents | facilities | SET NULL | NO ACTION | Optional FK; nullify reference if facility is deleted |
| space_id | facilities | spaces | SET NULL | NO ACTION | Optional FK; nullify assignment if space is deleted (device goes to storage) |
| facility_id | facility_assignments | facilities | NO ACTION | NO ACTION | Preserve assignment history; prevent deleting facilities with active assignments |
| space_id | facility_assignments | spaces | NO ACTION | NO ACTION | Preserve assignment history; prevent deleting spaces with active assignments |
| created_by | facility_assignments | users | NO ACTION | NO ACTION | Preserve historical creator reference |

---

## 4. Index Strategy

| Index Name | Table (Columns) | Type | Filter | Business Rule / Query | Rationale |
|------------|-----------------|------|--------|----------------------|-----------|
| PK_departments | departments(department_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_users | users(user_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_spaces | spaces(space_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_facilities | facilities(facility_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_facility_categories | facility_categories(category_id) | CLUSTERED | — | PK | Default clustered PK |
| idx_facilities_category_id | facilities(category_id) | NONCLUSTERED | — | FK join (R15) | Accelerate category→facility queries |
| idx_facilities_space_id | facilities(space_id) | NONCLUSTERED | — | FK join (R6) | Accelerate space→facility queries |
| PK_bookings | bookings(booking_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_booking_approvals | booking_approvals(approval_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_booking_sessions | booking_sessions(session_id) | CLUSTERED | — | PK | Default clustered PK |
| PK_maintenance | maintenance(maintenance_id) | CLUSTERED | — | PK | Default clustered PK |
| UQ_users_email | users(email) | UNIQUE NONCLUSTERED | — | BR10 | Business key uniqueness |
| UQ_spaces_space_code | spaces(space_code) | UNIQUE NONCLUSTERED | — | BR10 | Business key uniqueness |
| UQ_departments_name | departments(name) | UNIQUE NONCLUSTERED | — | BR10 | Business key uniqueness |
| UQ_facility_categories_name | facility_categories(category_name) | UNIQUE NONCLUSTERED | — | BR10 | Business key uniqueness |
| UQ_facility_categories_prefix | facility_categories(prefix) | UNIQUE NONCLUSTERED | — | BR10 | Business key uniqueness |
| UQ_booking_approvals_booking_id | booking_approvals(booking_id) | UNIQUE NONCLUSTERED | — | R10 (1:0..1) | Enforce one decision per booking |
| UQ_booking_sessions_booking_id | booking_sessions(booking_id) | UNIQUE NONCLUSTERED | — | R11 (1:0..1) | Enforce one session per booking |
| idx_users_department_id | users(department_id) | NONCLUSTERED | — | FK join (R1) | Accelerate department→user queries |
| idx_spaces_current_status | spaces(current_status) | NONCLUSTERED | — | BR2, BR14 | Filter by availability / maintenance |
| idx_bookings_space_id | bookings(space_id) | NONCLUSTERED | — | FK join (R5), overlap detection (BR1) | Accelerate space→booking queries |
| idx_bookings_requester_id | bookings(requester_id) | NONCLUSTERED | — | FK join (R2), user history (BR14) | Accelerate user→booking queries |
| idx_bookings_status | bookings(status) | NONCLUSTERED | — | BR14 | Filter by lifecycle status for reporting |
| idx_bookings_time_range | bookings(space_id, requested_start_time, requested_end_time) | NONCLUSTERED | — | Overlap detection (BR1) | Covering index for interval overlap checks |
| idx_bookings_requested_start | bookings(requested_start_time) | NONCLUSTERED | — | Scheduling queries (BR14) | Accelerate time-range queries |
| uq_bookings_active_overlap | bookings(space_id, requested_start_time) | UNIQUE NONCLUSTERED | WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0 | BR1 | Prevent exact start-time collision for confirmed bookings |
| idx_booking_approvals_approver_id | booking_approvals(approver_id) | NONCLUSTERED | — | FK join (R3) | Accelerate approver→decision queries |
| idx_booking_sessions_checked_in_by | booking_sessions(checked_in_by) | NONCLUSTERED | — | FK join (R4) | Accelerate staff→session queries |
| idx_maintenance_space_id | maintenance(space_id) | NONCLUSTERED | — | FK join (R7), BR14 | Accelerate space→maintenance queries |
| idx_maintenance_reporter_id | maintenance(reporter_id) | NONCLUSTERED | — | FK join (R8) | Accelerate reporter→maintenance queries |
| idx_maintenance_assigned_staff_id | maintenance(assigned_staff_id) | NONCLUSTERED | — | FK join (R9) | Accelerate staff→assignment queries |
| idx_maintenance_status | maintenance(status) | NONCLUSTERED | — | BR14 | Filter by maintenance lifecycle |
| idx_maintenance_facility_id | maintenance(facility_id) | NONCLUSTERED | — | FK join (R16) | Accelerate facility→maintenance queries |
| PK_incidents | incidents(incident_id) | CLUSTERED | — | PK | Default clustered PK |
| idx_incidents_space_id | incidents(space_id) | NONCLUSTERED | — | FK join (R12) | Accelerate space→incident queries |
| idx_incidents_reported_by | incidents(reported_by) | NONCLUSTERED | — | FK join (R13) | Accelerate reporter→incident queries |
| idx_incidents_assigned_to | incidents(assigned_to) | NONCLUSTERED | — | FK join (R14) | Accelerate assignee→incident queries |
| idx_incidents_status | incidents(status) | NONCLUSTERED | — | BR14, BR20 | Filter by incident lifecycle |
| idx_incidents_severity | incidents(severity) | NONCLUSTERED | — | BR14 | Filter by severity for prioritization |
| idx_incidents_facility_id | incidents(facility_id) | NONCLUSTERED | — | FK join (R17) | Accelerate facility→incident queries |
| PK_facility_assignments | facility_assignments(assignment_id) | CLUSTERED | — | PK | Default clustered PK |
| UQ_fac_assign_active | facility_assignments(facility_id) | UNIQUE NONCLUSTERED | WHERE status = 'active' | BR23 | Only one active assignment per facility |
| idx_fac_assign_facility_id | facility_assignments(facility_id) | NONCLUSTERED | — | FK join (R18) | Accelerate facility→assignment queries |
| idx_fac_assign_space_id | facility_assignments(space_id) | NONCLUSTERED | — | FK join (R19) | Accelerate space→assignment queries |
| idx_fac_assign_time_range | facility_assignments(facility_id, start_time, end_time) | NONCLUSTERED | — | BR22 (overlap detection) | Covering index for overlap checking trigger |
| idx_fac_assign_created_by | facility_assignments(created_by) | NONCLUSTERED | — | FK join | Accelerate created_by joins |

**Notes:**
- UNIQUE constraints on business keys (email, space_code, department name, category_name, prefix) create unique indexes implicitly in SQL Server.
- PK indexes are CLUSTERED by default in SQL Server.
- `uq_bookings_active_overlap` is a **filtered unique index** that prevents two confirmed bookings from using the same `(space_id, requested_start_time)` — a lightweight pre-check.
- True interval overlap detection (e.g., 10:00–12:00 vs. 11:00–13:00) requires `trg_bookings_prevent_overlap` — unique indexes cannot enforce range non-overlap.
- `idx_bookings_time_range` on `(space_id, requested_start_time, requested_end_time)` accelerates the overlap-checking trigger query via index seek on space_id with range scans on start/end times.

---

## 5. Normalization Proof (≥ 3NF)

### 5.1 1NF — Atomic Values, No Repeating Groups

| Table | 1NF Status | Evidence |
|-------|-----------|----------|
| departments | ✓ | All columns atomic; single value per cell. |
| users | ✓ | All columns atomic; single value per cell. |
| spaces | ✓ | All columns atomic; single value per cell. |
| facility_categories | ✓ | All columns atomic; single value per cell. |
| facilities | ✓ | All columns atomic; single value per cell. |
| facility_assignments | ✓ | All columns atomic; single value per cell. |
| bookings | ✓ | All columns atomic; single value per cell. |
| booking_approvals | ✓ | All columns atomic; single value per cell. |
| booking_sessions | ✓ | All columns atomic; single value per cell. |
| maintenance | ✓ | All columns atomic; single value per cell. |
| incidents | ✓ | All columns atomic; single value per cell. |

No table contains multi-valued attributes or repeating groups. Facility location is tracked via time-range assignments in `facility_assignments`; `facilities.space_id` is a cached column.

### 5.2 2NF — No Partial Dependencies

| Table | PK | 2NF Status | Evidence |
|-------|----|-----------|----------|
| departments | department_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| users | user_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| spaces | space_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| facility_categories | category_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| facilities | facility_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| facility_assignments | assignment_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| bookings | booking_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| booking_approvals | approval_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| booking_sessions | session_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| maintenance | maintenance_id (single) | ✓ | Single-column PK; no partial dependency possible. |
| incidents | incident_id (single) | ✓ | Single-column PK; no partial dependency possible. |

### 5.3 3NF — No Transitive Dependencies

| Table | 3NF Status | Evidence |
|-------|-----------|----------|
| departments | ✓ | All non-key attributes (`name`, `created_at`, `updated_at`) depend solely on `department_id`. |
| users | ✓ | `email`, `full_name`, `phone_number`, `role`, `department_id`, `account_status` depend solely on `user_id`. `department_id` is a FK, not a transitive dependency. |
| spaces | ✓ | All non-key attributes depend solely on `space_id`. No attribute depends on another non-key attribute. |
| facility_categories | ✓ | All non-key attributes (`category_name`, `prefix`) depend solely on `category_id`. |
| facilities | ✓ | All non-key attributes (`category_id`, `space_id`, `status`) depend solely on `facility_id`. `category_id` and `space_id` are FKs, not transitive dependencies. |
| facility_assignments | ✓ | `facility_id`, `space_id`, `start_time`, `end_time`, `purpose`, `status`, `created_by` depend solely on `assignment_id`. `facility_id`, `space_id`, `created_by` are FKs, not transitive dependencies. |
| bookings | ✓ | All non-key attributes depend solely on `booking_id`. `space_id`, `requester_id` are FKs referencing other tables, not transitive dependencies. |
| booking_approvals | ✓ | `booking_id`, `approver_id`, `decision_time`, `decision`, `rejection_reason`, `decision_note` depend solely on `approval_id`. FKs are not transitive dependencies. |
| booking_sessions | ✓ | `booking_id`, `actual_start_time`, `checked_in_by`, `initial_condition`, `actual_end_time`, `final_condition`, `usage_notes` depend solely on `session_id`. FKs are not transitive dependencies. |
| maintenance | ✓ | All non-key attributes depend solely on `maintenance_id`. `space_id`, `reporter_id`, `assigned_staff_id` are FKs. |
| incidents | ✓ | All non-key attributes depend solely on `incident_id`. `space_id`, `reported_by`, `assigned_to` are FKs. |

**Conclusion:** All 11 tables satisfy 3NF.

---

## 6. Naming Conventions Applied

| Object Type | Convention | Examples |
|-------------|-----------|----------|
| Table names | snake_case, plural | `departments`, `booking_approvals`, `facility_categories` |
| Column names | snake_case | `actual_start_time`, `rejection_reason` |
| Primary key | `<table_singular>_id` | `booking_id`, `space_id`, `approval_id` |
| Foreign key | Same name as referenced PK | `space_id`, `department_id`, `requester_id` |
| Enum/status values | lowercase with underscores | `checked_in`, `under_maintenance`, `facility_staff` |
| Index | `idx_<table>_<column>` | `idx_bookings_space_id`, `idx_users_email` |
| PK constraint | `PK_<table>` | `PK_bookings`, `PK_users` |
| UQ constraint | `UQ_<table>_<column>` | `UQ_users_email`, `UQ_booking_approvals_booking_id` |
| FK constraint | `FK_<child>_<col>` | `FK_bookings_space_id`, `FK_booking_approvals_approver_id` |
| CK constraint | `CK_<table>_<rule>` | `CK_bookings_status`, `CK_spaces_capacity` |
| DF constraint | `DF_<table>_<column>` | `DF_bookings_created_at`, `DF_bookings_is_deleted` |
| Trigger | `trg_<table>_<action>` | `trg_bookings_prevent_overlap`, `trg_booking_approvals_decision` |

Data types follow `docs/tech-stack.md`: INT IDENTITY for surrogate PKs, NVARCHAR for text, VARCHAR(50) for enums, DATETIME2 for timestamps, BIT for flags, NVARCHAR(MAX) for long text.

---

## 7. Constraint Implementation for Business Rules

| BR | Business Rule | Object Name | Implementation | Enforcement Level |
|----|-------------|-------------|----------------|-------------------|
| BR1 | No overlapping approved bookings | `uq_bookings_active_overlap` + `trg_bookings_prevent_overlap` | Filtered unique index prevents exact (space_id, start_time) collisions; AFTER INSERT/UPDATE trigger checks interval overlap against existing confirmed bookings | Database (index + trigger) |
| BR2 | Unavailable spaces cannot be approved | `trg_booking_approvals_check_space` | AFTER INSERT trigger on `booking_approvals` checks space availability via `spaces.current_status` when `decision='approved'`; pending bookings allowed on any space | Database (trigger) |
| BR3 | Expected participants ≤ space capacity | `trg_bookings_check_capacity` | AFTER INSERT/UPDATE trigger rejects if `expected_participants > (SELECT capacity FROM spaces WHERE space_id = new.space_id)` | Database (trigger) |
| BR4 | Maintenance blocks booking | `trg_bookings_check_maintenance` | AFTER INSERT/UPDATE trigger rejects if overlapping maintenance record exists for the same space with status IN ('open','in_progress') | Database (trigger) |
| BR5 | Maintenance assigned staff tracking | FK_maintenance_assigned_staff | `assigned_staff_id` FK → `users(user_id)` with ON DELETE SET NULL | FK constraint |
| BR6 | Decision recording (approver, time, decision) | `trg_booking_approvals_decision` | AFTER INSERT trigger on `booking_approvals` enforces `approver_id`, `decision_time` are NOT NULL; updates `bookings.status` to match `decision` | Database (trigger) |
| BR7 | Rejection requires reason | `trg_booking_approvals_rejection` | AFTER INSERT trigger on `booking_approvals` enforces `rejection_reason IS NOT NULL` when `decision = 'rejected'` | Database (trigger) |
| BR8 | Actual time recording | `trg_booking_sessions_checkin` + `trg_booking_sessions_completion` | INSERT trigger on `booking_sessions` validates booking is `'approved'` and sets `actual_start_time`; UPDATE trigger validates `actual_end_time` is set at completion and updates `bookings.status` | Database (trigger) |
| BR9 | Space condition tracking | Same as BR8 triggers | INSERT trigger validates `initial_condition` is provided at check-in; UPDATE trigger validates `final_condition` is provided at completion | Database (trigger) |
| BR10 | Unique identification (email, space_code) | `UQ_users_email`, `UQ_spaces_space_code`, `UQ_departments_name`, `UQ_facility_categories_name`, `UQ_facility_categories_prefix` | UNIQUE constraints on business key columns | Database (UNIQUE index) |
| BR11 | Soft deletes for audit trail | `DF_bookings_is_deleted`, `DF_maintenance_is_deleted` | `is_deleted BIT NOT NULL DEFAULT 0` on bookings and maintenance; no hard DELETE operations | Database (DEFAULT) |
| BR12 | Audit trail (created_at, updated_at) | Per-table columns | All 11 tables have `created_at DATETIME2 NOT NULL DEFAULT GETDATE()` and `updated_at DATETIME2 NOT NULL DEFAULT GETDATE()` | Database (DEFAULT) |
| BR13 | Historical records preservation | Soft-delete pattern | Soft delete (`is_deleted = 1`) instead of hard DELETE; all FKs use NO ACTION or SET NULL to preserve references | Application + Database |
| BR14 | Staff views (history, upcoming, maintenance, no-shows) | Multiple indexes | `idx_bookings_requester_id`, `idx_bookings_status`, `idx_bookings_requested_start`, `idx_maintenance_status`, etc. | Database (indexes) |
| BR15 | Approver must be facility staff or facility manager | `trg_booking_approvals_check_role` | AFTER INSERT trigger on `booking_approvals` checks `users.role` of `approver_id` and rejects if NOT IN ('facility_staff','facility_manager') | Database (trigger) |
| BR16 | Check-in staff must be facility staff or facility manager | `trg_booking_sessions_check_role` | AFTER INSERT trigger on `booking_sessions` checks `users.role` of `checked_in_by` and rejects if NOT IN ('facility_staff','facility_manager') | Database (trigger) |
| BR17 | Assigned maintenance staff must be facility staff | `trg_maintenance_check_assignee_role` | AFTER INSERT, UPDATE trigger on `maintenance` checks `users.role` of `assigned_staff_id` when non-NULL and rejects if NOT IN ('facility_staff') | Database (trigger) |
| BR18 | Cancellation validity and space cleanup | `trg_bookings_cancellation` | AFTER UPDATE trigger on `bookings` validates cancellation only from `pending` or `approved`; sets `spaces.current_status = 'available'` if the related space was `'in_use'` | Database (trigger) |
| BR19 | Maintenance completion restores space status | `trg_maintenance_completion_space_status` | AFTER UPDATE trigger on `maintenance` auto-updates `spaces.current_status = 'available'` when last active maintenance ticket is resolved | Database (trigger) |
| BR20 | Unresolved incidents block booking unless a completed maintenance resolution covers the incident before the booking starts | `trg_bookings_check_incidents` | AFTER INSERT, UPDATE trigger on `bookings` rejects if unresolved incidents (status IN ('reported','investigating')) exist for the same space AND no resolved maintenance for the same `(space_id, facility_id)` has `completion_time <= requested_start_time` | Database (trigger) |
| BR21 | Maintenance completion auto-resolves incidents | `trg_incidents_autoresolve` | AFTER UPDATE trigger on `maintenance` when status changes to 'resolved', auto-updates related incidents to 'resolved'. If maintenance `facility_id` IS NOT NULL, resolves incidents for the same facility AND same space; otherwise falls back to resolving all incidents in the same space | Database (trigger) |
| BR22 | Facility assignment no-overlap | `trg_facility_assignments_no_overlap` | AFTER INSERT, UPDATE trigger on `facility_assignments` rejects if overlapping time range exists for the same facility with status IN ('planned','active'). Overlap condition: `start_time < existing.end_time AND end_time > existing.start_time` | Database (trigger) |
| BR23 | Only one active assignment per facility | `uq_fac_assign_active` | Filtered UNIQUE NONCLUSTERED index ON `facility_assignments(facility_id)` WHERE `status = 'active'` | Database (index) |

### Trigger Implementation Details

The following triggers enforce cross-row and cross-table business rules that cannot be expressed as CHECK constraints (subqueries not re-evaluated on referenced table changes):

| Trigger | Fires On | Enforcement Logic |
|---------|----------|-------------------|
| `trg_bookings_prevent_overlap` | bookings INSERT, UPDATE | Before insert/update, check if any existing row with same `space_id` has status IN ('approved','checked_in','completed'), `is_deleted = 0`, and overlapping time range: `requested_start_time < new.requested_end_time AND requested_end_time > new.requested_start_time`. If overlap found, RAISERROR and rollback. |
| `trg_bookings_check_capacity` | bookings INSERT, UPDATE | Reject if `new.expected_participants > (SELECT capacity FROM spaces WHERE space_id = new.space_id)`. |
| `trg_bookings_check_maintenance` | bookings INSERT, UPDATE | Reject if there exists an overlapping maintenance record for the same space WHERE status IN ('open','in_progress') AND `start_time < new.requested_end_time AND (completion_time IS NULL OR completion_time > new.requested_start_time)`. |
| `trg_booking_approvals_decision` | booking_approvals INSERT | Enforce `approver_id` and `decision_time` are NOT NULL. Update `bookings.status` to match the `decision` value ('approved' or 'rejected'). |
| `trg_booking_approvals_check_space` | booking_approvals INSERT | When `new.decision = 'approved'`, read `spaces.current_status` via JOIN `bookings.space_id`. Reject if NOT IN ('available','in_use'). |
| `trg_booking_approvals_rejection` | booking_approvals INSERT | When `new.decision = 'rejected'`, enforce `new.rejection_reason IS NOT NULL`. If NULL, RAISERROR and rollback. |
| `trg_booking_sessions_checkin` | booking_sessions INSERT | Validate `bookings.status = 'approved'` for the related booking — reject if not. Update `bookings.status` to 'checked_in' and `spaces.current_status` to 'in_use'. Enforce `initial_condition` is provided. |
| `trg_booking_sessions_completion` | booking_sessions UPDATE | When `actual_end_time` transitions from NULL to NOT NULL, update `bookings.status` to 'completed' and `spaces.current_status` to 'available'. Enforce `final_condition` is provided. |
| `trg_booking_approvals_check_role` | booking_approvals INSERT | Read `users.role` for `new.approver_id`. If role NOT IN ('facility_staff','facility_manager'), RAISERROR and rollback. | 
| `trg_booking_sessions_check_role` | booking_sessions INSERT | Read `users.role` for `new.checked_in_by`. If role NOT IN ('facility_staff','facility_manager'), RAISERROR and rollback. | 
| `trg_maintenance_check_assignee_role` | maintenance INSERT, UPDATE | When `new.assigned_staff_id IS NOT NULL`, read `users.role`. If role != 'facility_staff', RAISERROR and rollback. |
| `trg_maintenance_completion_space_status` | maintenance UPDATE | When `new.status = 'resolved'` AND `old.status != 'resolved'`, auto-update `spaces.current_status = 'available'` for the related space IF no other unresolved maintenance tickets exist for the same space (prevents premature status flip when concurrent tickets exist). |
| `trg_bookings_cancellation` | bookings UPDATE | When `new.status = 'cancelled'` AND `old.status != 'cancelled'`, validate `old.status IN ('pending','approved')` — reject if cancelled from other states. If a `booking_sessions` row exists (space was `'in_use'`), set `spaces.current_status = 'available'`. |
| `trg_bookings_check_incidents` | bookings INSERT, UPDATE | Reject if there exists an unresolved incident (status IN ('reported','investigating')) for the same space AND no resolved maintenance covers the incident with `completion_time <= requested_start_time`. Space-level incidents (`facility_id IS NULL`) match space-level maintenance (`m.facility_id IS NULL`); device-level incidents match maintenance on the same `facility_id`. If no such maintenance exists, the incident unconditionally blocks booking. |
| `trg_incidents_autoresolve` | maintenance UPDATE | When `new.status = 'resolved'` AND `old.status != 'resolved'`, auto-update incidents to 'resolved'. If `new.facility_id IS NOT NULL`, resolve only incidents with matching `facility_id` AND same `space_id` with status IN ('reported','investigating') AND `created_at < new.completion_time`. If `new.facility_id IS NULL`, resolve all unresolved incidents in the same space (original fallback). Sets `resolved_at = new.completion_time`. |
| `trg_facility_assignments_no_overlap` | facility_assignments INSERT, UPDATE | Before insert/update, check if any existing row with same `facility_id` has status IN ('planned','active'), `assignment_id <> new.assignment_id`, and overlapping time range: `start_time < new.end_time AND end_time > new.start_time`. If overlap found, RAISERROR and rollback. Ignores assignments with status IN ('completed','cancelled') — they do not block future assignments. |

**Note on overlap detection (BR1):** The filtered unique index `uq_bookings_active_overlap` provides a lightweight pre-check for exact (space_id, requested_start_time) duplicates on confirmed bookings, while `trg_bookings_prevent_overlap` handles the general interval-overlap case. Both operate at the database level, ensuring data integrity even with concurrent submissions.

---
## 8. Deviations from ERD (with Justification)

| # | ERD Element | Logical Design | Deviation | Justification |
|---|---|---|---|---|
| D1 | `docs/entity-registry.md` lists `account_status` as provisional enum | Finalized as `CHECK IN ('active','inactive','suspended')` with DEFAULT 'active' | Finalization | Requirement §2 states "Account Status" exists but does not enumerate values. Standard account lifecycle values chosen. |
| D2 | ERD does not show explicit `is_deleted` on maintenance | `is_deleted BIT NOT NULL DEFAULT 0` on maintenance | Included | Assumption A4 requires soft deletion for both bookings and maintenance. |
| D3 | ERD does not define triggers for check-in/completion fields | `trg_booking_sessions_checkin` and `trg_booking_sessions_completion` added | Added | Business rules BR8 and BR9 require actual time and condition recording. The new `booking_sessions` table has nullable columns; triggers enforce NOT NULL on status transition, providing defense-in-depth beyond the application layer. |
| D4 | Audit columns not shown on Booking_Approvals, Booking_Sessions | `created_at` and `updated_at` added per BR12 | Added | BR12 requires audit trail on all core tables. These tables were created during the SRP split and need audit columns. |
| D5 | ERD Section 4 (Logical Constraints) lists role constraints as application-level but does not specify database triggers | Three triggers added: `trg_booking_approvals_check_role`, `trg_booking_sessions_check_role`, `trg_maintenance_check_assignee_role` | Upgraded | Role constraints were previously marked as application-only; upgraded to database-level enforcement via triggers for defense-in-depth. |
| D6 | ERD (run_01) added Incidents entity with R12–R14 | `incidents` table added with 3 FKs, CHECK constraints, and 2 triggers (`trg_bookings_check_incidents`, `trg_incidents_autoresolve`) | Added | Incident reporting requirement from business-requirement.md line 36 — separate entity justified by distinct attributes (incident_type, severity) and lifecycle |
| D7 | ERD modeled Facilities as category-level entities with a `name` column | Facilities refactored into `facility_categories` (lookup) and `facilities` (instance-level). `name` removed, `category_id` and `status` added. `Space_Facilities` `quantity` removed. `Maintenance` and `Incidents` gained nullable `facility_id` | Refactored | Enables per-device tracking: each physical device is a distinct `facilities` row with lifecycle status. `facility_categories` provides type classification. Device-level maintenance (R16) and incidents (R17) allow precise tracking without losing space-level fallback. |
| D8 | ERD (run_02) removed Space_Facilities junction | `space_id` added as nullable FK in `facilities` | Removed | With instance-level Facilities (each row = one device), M:N is no longer needed. A device can only be in one space at a time. `space_id NULL` allows devices in storage. |
| D9 | ERD (run_03) added Facility_Assignments entity | `facility_assignments` table with time-range tracking added; R6 bridged through assignments | Added | Enables facility location history tracking and future reservation planning. `facilities.space_id` retained as cached column synced by app layer (not DB trigger). BR22 (no-overlap) and BR23 (1 active/facility) added. |

### Resolved ambiguities

| Ambiguity | Resolution | Rationale |
|-----------|-----------|-----------|
| Q1: Rejection reason — separate column or part of decision note? | Separate `rejection_reason NVARCHAR(MAX) NULL` column on `booking_approvals` | Business Rule 7 explicitly states "rejection reason must be stored" — dedicated column makes enforcement and querying cleaner. |
| Q2: Usage policy — free text or coded rules? | `usage_policy NVARCHAR(MAX) NULL` (free text) on `spaces` | No fixed policy set defined in requirements. |
| Q3: Maintenance-to-booking interaction — can a space be booked after maintenance is resolved but before space status is updated? | `trg_maintenance_completion_space_status` auto-updates `spaces.current_status = 'available'` when last active maintenance is resolved. `trg_bookings_check_maintenance` provides defense-in-depth by checking overlapping unresolved maintenance regardless of space status. | Automation removes the manual-step gap; overlap trigger provides double safety net. |
| Q4: No-show detection — automatic or manual? | Automatic scheduled job sets `status = 'no_show'` for approved bookings without check-in past `requested_end_time`. | Prevents unreconciled approved bookings from lingering; reduces manual workload. |

---

## 9. Revision Log

| Version | Date | Changes |
|---------|------|---------|
| 2.8 | 2026-07-05 | Run 03 — added facility_assignments table (entity count 10→11), R6 bridged through Facility_Assignments (R18 + R19), added BR22/BR23, added 5 indexes (UQ_fac_assign_active, idx_fac_assign_*), added D9 deviation, `facilities.space_id` kept as cached column synced by app layer. | |
| 2.7 | 2026-07-05 | Run 02 — removed space_facilities junction (entity count 11→10), added space_id FK to facilities (nullable for storage), R6 changed from M:N to 1:N direct, 10-table 3NF re-proofed. | |
| 2.6 | 2026-07-04 | Facility refactoring — added `facility_categories` lookup table (11th entity), converted `facilities` to instance-level (removed `name`, added `category_id`+`status`), removed `quantity` from `space_facilities`, added `facility_id` to `maintenance`/`incidents`, added R15–R17, updated BR10/BR21/trg_incidents_autoresolve, 7 new indexes, deviation D7, 11-table normalization. | |
| 2.5 | 2026-07-04 | Added `incidents` table (run_01 amendment) — 10th entity, R12–R14, BR20–BR21, 2 new triggers, 6 new indexes, deviation D6, 10-table 3NF. | |
| 2.4 | 2026-07-01 | Added `idx_space_facilities_facility_id` to §4 Index Strategy (30 total). |
| 2.3 | 2026-07-01 | Added `bookings.status = 'approved'` validation to `trg_booking_sessions_checkin` — prevents check-in for pending/rejected bookings per §5.2 approval rules. |
| 2.2 | 2026-07-01 | Space availability check moved from INSERT-block to approval-time (`trg_booking_approvals_check_space` replacing `trg_bookings_check_space_status`); pending bookings now allowed on any space. Added `trg_bookings_cancellation` (BR18) — validates cancel-from states and cleans up space status. | 
| 2.1 | 2026-07-01 | Added 3 role-enforcement triggers (BR15-BR17): approver must be facility_staff/facility_manager, check-in staff must be facility_staff/facility_manager, assigned maintenance staff must be facility_staff. Upgraded from application-level to database-level enforcement. Added D9 deviation. | 
| 2.0 | 2026-07-01 | Regenerated with 9-table schema after SRP split of Bookings → Bookings + Booking_Approvals + Booking_Sessions. Updated all sections: 12-column table definitions (7-col format), 11 relationships + separate RI rules (6-col), 29 index entries (6-col format), 9-table normalization proof, 14 BRs with 8 triggers, updated deviations and resolved ambiguities. |
| 1.2 | 2026-06-18 | Added check-in/completion enforcement triggers; BR8/BR9 upgraded from Application to Database enforcement. |
| 1.1 | 2026-06-15 | Added filtered unique index; replaced generic enforcement with 7 trigger definitions; resolved Q3, Q4; added per-FK ON DELETE rules. |
| 1.0 | 2026-06-15 | Initial logical design (7 tables, monolithic bookings). |

---

*Generated for CS486 Group G05 — Campus Space Management System*
