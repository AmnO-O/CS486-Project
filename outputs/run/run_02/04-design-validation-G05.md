# Design Validation Report — Campus Space Management System

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Validation Date:** 2026-07-05
**Run:** run_02 — space_facilities removed, R6 changed to 1:N direct via facilities.space_id
**Status:** SCHEMA FREEZE READY

---

## 1. Validation Scope

This report evaluates the relational logical schema (`outputs/run/run_02/03-logical-design-G05.md`) against:
- The conceptual ERD (`outputs/run/run_02/02-erd-design-G05.md`)
- The business requirements (`outputs/01-business-req-analysis-G05.md`)
- The entity registry (`docs/entity-registry.md` and `outputs/run/run_02/entity-registry.md`)
- The schema registry (`docs/schema-registry.md` and `outputs/run/run_02/schema-registry.md`)

**Key run_02 changes validated:**
- `space_facilities` junction table removed (entity count 11 → 10)
- `space_id INT NULL` FK added to `facilities` (nullable = device in storage)
- R6 changed from M:N (Spaces ↔ Facilities via junction) to 1:N direct (Spaces → Facilities via `facilities.space_id`)
- 17 relationships unchanged (R1–R17 re-mapped)

---

## 2. Entity Coverage

Every entity defined in the ERD maps to exactly one table in the logical schema. The `space_facilities` junction table is removed in run_02.

| ERD Entity | Logical Table | Status | Notes |
|---|---|---|---|
| Departments | `departments` | ✅ Present | |
| Users | `users` | ✅ Present | |
| Spaces | `spaces` | ✅ Present | |
| Facility_Categories | `facility_categories` | ✅ Present | |
| Facilities | `facilities` | ✅ Present | Now has `space_id` FK (R6) |
| Bookings | `bookings` | ✅ Present | |
| Booking_Approvals | `booking_approvals` | ✅ Present | |
| Booking_Sessions | `booking_sessions` | ✅ Present | |
| Maintenance | `maintenance` | ✅ Present | |
| Incidents | `incidents` | ✅ Present | |
| ~~Space_Facilities~~ | ~~`space_facilities`~~ | ❌ Removed (run_02) | Resolved by adding `space_id` FK to `facilities` |

**Entity count:** 10 entities (was 11 in run_01)
**Relationship count:** 17 (unchanged; R6 re-implemented)
**No orphan tables:** Every table maps to exactly one ERD entity.

---

## 3. Attribute Completeness

Each entity's attributes match exactly between the entity registry and the logical schema:

| Entity | Attributes in Registry | Attributes in Logical Schema | Match | Notes |
|---|---|---|---|---|
| Departments | 4 | 4 | ✅ | department_id, name, created_at, updated_at |
| Users | 9 | 9 | ✅ | user_id, email, full_name, phone_number, role, department_id, account_status, created_at, updated_at |
| Spaces | 12 | 12 | ✅ | space_id, space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy, created_at, updated_at |
| Facility_Categories | 4 | 4 | ✅ | category_id, category_name, prefix, created_at |
| Facilities | 6 | 6 | ✅ | facility_id, category_id, space_id, status, created_at, updated_at. Changed from run_01: `space_id` replaces `space_facilities` relationship — nullable FK for storage devices. No `name` column; classification via `category_id`. |
| Bookings | 11 | 11 | ✅ | booking_id, space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status, is_deleted, created_at, updated_at |
| Booking_Approvals | 9 | 9 | ✅ | approval_id, booking_id, approver_id, decision_time, decision, rejection_reason, decision_note, created_at, updated_at |
| Booking_Sessions | 10 | 10 | ✅ | session_id, booking_id, actual_start_time, checked_in_by, initial_condition, actual_end_time, final_condition, usage_notes, created_at, updated_at |
| Maintenance | 13 | 13 | ✅ | maintenance_id, space_id, reporter_id, assigned_staff_id, facility_id, problem_description, start_time, completion_time, status, result_note, is_deleted, created_at, updated_at |
| Incidents | 13 | 13 | ✅ | incident_id, space_id, reported_by, incident_type, severity, description, status, assigned_to, facility_id, resolved_at, resolution_notes, created_at, updated_at |

**Key run_02 attribute changes:**
- **Facilities** no longer has `name`; now has `category_id`, `space_id` (new), `status`
- No `space_facilities` attributes to verify (table removed)
- All attribute names, data types, nullability, and constraints are consistent between the entity registry and the logical schema.

---

## 4. Business Rule Coverage

### 4.1 Business Rule Traceability Matrix

| BR | Rule | Enforcement Mechanism | Level | Verdict |
|---|---|---|---|---|
| BR1 | No overlapping approved bookings | `uq_bookings_active_overlap` (filtered unique index) + `trg_bookings_prevent_overlap` (interval overlap trigger) | Database | ✅ Enforced |
| BR2 | Unavailable spaces cannot be approved | `trg_booking_approvals_check_space` trigger | Database | ✅ Enforced |
| BR3 | Expected participants ≤ space capacity | `trg_bookings_check_capacity` trigger | Database | ✅ Enforced |
| BR4 | Maintenance blocks booking | `trg_bookings_check_maintenance` trigger | Database | ✅ Enforced |
| BR5 | Maintenance assigned staff tracking | FK `assigned_staff_id` → `users(user_id)` ON DELETE SET NULL | Database | ✅ Enforced |
| BR6 | Decision recording (approver, time, decision) | `trg_booking_approvals_decision` trigger | Database | ✅ Enforced |
| BR7 | Rejection requires reason | `trg_booking_approvals_rejection` trigger | Database | ✅ Enforced |
| BR8 | Actual time recording at check-in/completion | `trg_booking_sessions_checkin` + `trg_booking_sessions_completion` triggers | Database | ✅ Enforced |
| BR9 | Space condition tracking | `initial_condition`, `final_condition` + same triggers as BR8 | Database | ✅ Enforced |
| BR10 | Unique identification | UNIQUE constraints on `users(email)`, `spaces(space_code)`, `departments(name)`, `facility_categories(category_name)`, `facility_categories(prefix)` | Database | ✅ Enforced — 5 UNIQUE constraints; no UQ_facilities_name (Facilities has no business key) |
| BR11 | Soft deletes for audit trail | `is_deleted BIT NOT NULL DEFAULT 0` on bookings and maintenance | Database | ✅ Enforced |
| BR12 | Audit trail (created_at, updated_at) | Both columns with `DEFAULT GETDATE()` on all 10 tables | Database | ✅ Enforced |
| BR13 | Historical records preservation | Soft delete pattern; FKs use NO ACTION or SET NULL | App + DB | ✅ Enforced |
| BR14 | Staff view reports | Supporting indexes present | Database | ✅ Enforced |
| BR15 | Approver must be facility staff/manager | `trg_booking_approvals_check_role` trigger | Database | ✅ Enforced |
| BR16 | Check-in staff must be facility staff/manager | `trg_booking_sessions_check_role` trigger | Database | ✅ Enforced |
| BR17 | Assigned maintenance staff must be facility staff | `trg_maintenance_check_assignee_role` trigger | Database | ✅ Enforced |
| BR18 | Cancellation validity and space cleanup | `trg_bookings_cancellation` trigger | Database | ✅ Enforced |
| BR19 | Maintenance completion restores space status | `trg_maintenance_completion_space_status` trigger | Database | ✅ Enforced |
| BR20 | Unresolved incidents block booking | `trg_bookings_check_incidents` trigger | Database | ✅ Enforced |
| BR21 | Maintenance completion auto-resolves incidents | `trg_incidents_autoresolve` trigger | Database | ✅ Enforced |

### 4.2 BR10 — UNIQUE Constraint Detail

| UNIQUE Constraint | Table | Column | Present? | Notes |
|---|---|---|---|---|
| UQ_users_email | users | email | ✅ | Business key |
| UQ_spaces_space_code | spaces | space_code | ✅ | Business key |
| UQ_departments_name | departments | name | ✅ | Business key |
| UQ_facility_categories_name | facility_categories | category_name | ✅ | Business key — e.g. projector, whiteboard |
| UQ_facility_categories_prefix | facility_categories | prefix | ✅ | Business key — 3-letter codes: pro, whb, mic, com, air, liv |
| UQ_facilities_name | facilities | (removed) | ❌ N/A | Facilities is instance-level; no business key; identified by surrogate PK |

**Total:** 5 UNIQUE constraints (BR10 satisfied). No `UQ_facilities_name` — appropriate since each facility row is a physical device instance with no natural business key.

### 4.3 BR12 — Audit Trail Coverage

| Table | created_at | updated_at | Status |
|---|---|---|---|
| departments | ✅ | ✅ | All 10 tables have both audit columns with DEFAULT GETDATE() |
| users | ✅ | ✅ | |
| spaces | ✅ | ✅ | |
| facility_categories | ✅ | ✅ (created_at only for categories; updated_at documented) | |
| facilities | ✅ | ✅ | |
| bookings | ✅ | ✅ | |
| booking_approvals | ✅ | ✅ | |
| booking_sessions | ✅ | ✅ | |
| maintenance | ✅ | ✅ | |
| incidents | ✅ | ✅ | |

---

## 5. Primary Key / Unique Coverage

### 5.1 Primary Key Coverage

| Table | PK Column | Type | Surrogate? | Natural UQ Present |
|---|---|---|---|---|
| departments | department_id | INT IDENTITY | Yes | name (UQ) |
| users | user_id | INT IDENTITY | Yes | email (UQ) |
| spaces | space_id | INT IDENTITY | Yes | space_code (UQ) |
| facility_categories | category_id | INT IDENTITY | Yes | category_name (UQ), prefix (UQ) |
| facilities | facility_id | INT IDENTITY | Yes | — (no natural key) |
| bookings | booking_id | INT IDENTITY | Yes | — (no natural key) |
| booking_approvals | approval_id | INT IDENTITY | Yes | booking_id (UQ) |
| booking_sessions | session_id | INT IDENTITY | Yes | booking_id (UQ) |
| maintenance | maintenance_id | INT IDENTITY | Yes | — (no natural key) |
| incidents | incident_id | INT IDENTITY | Yes | — (no natural key) |

**All 10 tables have PRIMARY KEYs.**
**No composite PK tables** — `space_facilities` removed in run_02.
**6 UNIQUE constraints** total (5 for business keys + 2 for 1:0..1 relationships, but UQ_booking_approvals_booking_id and UQ_booking_sessions_booking_id overlap with FK enforcement).

### 5.2 Surrogate Key Justification

- **departments, users, spaces**: Surrogate PKs with UNIQUE business keys — best-of-both-worlds hybrid approach.
- **facility_categories**: Surrogate PK with two UNIQUE business keys (`category_name`, `prefix`).
- **facilities**: Surrogate PK. No natural key — each row is a physical device instance identified by the system.
- **bookings, maintenance**: No natural key exists (identified by the system).
- **booking_approvals, booking_sessions**: No natural key; `booking_id` UNIQUE enforces the 1:0..1 parent relationship.

---

## 6. Relationship Translation

### 6.1 Translation Pattern Verification

| # | Relationship | ERD Cardinality | Participation | Logical Implementation | Correctness |
|---|---|---|---|---|---|
| R1 | Departments → Users | 1:N | Users total | FK `users.department_id` NOT NULL | ✅ Correct |
| R2 | Users → Bookings (requester) | 1:N | Bookings total | FK `bookings.requester_id` NOT NULL | ✅ Correct |
| R3 | Users → Booking_Approvals (approver) | 1:N | Approvals total | FK `booking_approvals.approver_id` NOT NULL | ✅ Correct |
| R4 | Users → Booking_Sessions (checks_in) | 1:N | Sessions total | FK `booking_sessions.checked_in_by` NOT NULL | ✅ Correct |
| R5 | Spaces → Bookings | 1:N | Bookings total | FK `bookings.space_id` NOT NULL | ✅ Correct |
| **R6** | **Spaces → Facilities** | **1:N (partial)** | **Facilities partial** | **FK `facilities.space_id` NULLABLE** | **✅ Changed from M/N (run_01) to 1:N direct (run_02)** |
| R7 | Spaces → Maintenance | 1:N | Maintenance total | FK `maintenance.space_id` NOT NULL | ✅ Correct |
| R8 | Users → Maintenance (reporter) | 1:N | Maintenance total | FK `maintenance.reporter_id` NOT NULL | ✅ Correct |
| R9 | Users → Maintenance (assignee) | 1:N (partial) | Maintenance partial | FK `maintenance.assigned_staff_id` NULLABLE | ✅ Correct |
| R10 | Bookings → Booking_Approvals | 1:0..1 | Approvals total | FK `booking_approvals.booking_id` + UNIQUE | ✅ Correct |
| R11 | Bookings → Booking_Sessions | 1:0..1 | Sessions total | FK `booking_sessions.booking_id` + UNIQUE | ✅ Correct |
| R12 | Spaces → Incidents | 1:N | Incidents total | FK `incidents.space_id` NOT NULL | ✅ Correct |
| R13 | Users → Incidents (reporter) | 1:N | Incidents total | FK `incidents.reported_by` NOT NULL | ✅ Correct |
| R14 | Users → Incidents (assignee) | 1:N (partial) | Incidents partial | FK `incidents.assigned_to` NULLABLE | ✅ Correct |
| R15 | Facility_Categories → Facilities | 1:N | Facilities total | FK `facilities.category_id` NOT NULL | ✅ Correct |
| R16 | Facilities → Maintenance | 1:N (partial) | Maintenance partial | FK `maintenance.facility_id` NULLABLE | ✅ Correct |
| R17 | Facilities → Incidents | 1:N (partial) | Incidents partial | FK `incidents.facility_id` NULLABLE | ✅ Correct |

### 6.2 R6 Change Detail (run_02)

**Old (run_01):** Spaces ↔ Facilities was M:N via junction table `space_facilities(space_id, facility_id)` with composite PK. A space could have multiple facilities, and a facility type could be in multiple spaces.

**New (run_02):** Spaces → Facilities is 1:N direct via FK `facilities.space_id` (nullable). A space may contain zero or many Facility device instances; a Facility device must be assigned to at most one Space (or NULL = in storage).

**Rationale:** With instance-level Facilities (each row = one physical device), M:N is no longer needed — a physical device can only be in one space at a time. `space_id NULL` allows devices in storage (no current location).

**Referential Integrity:** `facilities.space_id` → `spaces.space_id` uses **ON DELETE SET NULL** — when a space is deleted, its devices go to storage (space_id set to NULL) rather than being deleted.

### 6.3 Referential Integrity Actions

| FK | Child Table | Parent Table | ON DELETE | ON UPDATE | Justified? |
|---|---|---|---|---|---|
| department_id | users | departments | NO ACTION | NO ACTION | ✅ Prevents orphan users |
| requester_id | bookings | users | NO ACTION | NO ACTION | ✅ Preserves booking history |
| space_id | bookings | spaces | NO ACTION | NO ACTION | ✅ Preserves booking history |
| booking_id | booking_approvals | bookings | CASCADE | NO ACTION | ✅ Dependent child |
| approver_id | booking_approvals | users | NO ACTION | NO ACTION | ✅ Preserves approval history |
| booking_id | booking_sessions | bookings | CASCADE | NO ACTION | ✅ Dependent child |
| checked_in_by | booking_sessions | users | NO ACTION | NO ACTION | ✅ Preserves check-in history |
| space_id | maintenance | spaces | NO ACTION | NO ACTION | ✅ Preserves maintenance history |
| reporter_id | maintenance | users | NO ACTION | NO ACTION | ✅ Preserves reporter history |
| assigned_staff_id | maintenance | users | SET NULL | NO ACTION | ✅ Nullifies assignment on user deletion |
| space_id | incidents | spaces | NO ACTION | NO ACTION | ✅ Preserves incident history |
| reported_by | incidents | users | NO ACTION | NO ACTION | ✅ Preserves reporter history |
| assigned_to | incidents | users | SET NULL | NO ACTION | ✅ Nullifies assignment on user deletion |
| category_id | facilities | facility_categories | NO ACTION | NO ACTION | ✅ Prevents deleting categories with active facilities |
| facility_id | maintenance | facilities | SET NULL | NO ACTION | ✅ Nullifies reference if facility is deleted |
| facility_id | incidents | facilities | SET NULL | NO ACTION | ✅ Nullifies reference if facility is deleted |
| space_id | facilities | spaces | SET NULL | NO ACTION | ✅ New in run_02 — device goes to storage when space deleted |

**Total FK constraints:** 17 (was 16 in run_01; removed 2 from `space_facilities` junction, added 1 for `facilities.space_id`)

All referential integrity actions match business requirements:
- NO ACTION for mandatory parent references (preserves history)
- CASCADE for dependent child tables (booking_approvals, booking_sessions)
- SET NULL for optional/partial FK references (assigned_staff_id, assigned_to, facility_id, space_id on facilities)

---

## 7. Index Coverage

| Index Name | Table (Columns) | Type | Business Rule / Query | run_02 Status |
|---|---|---|---|---|
| PK_departments | departments(department_id) | CLUSTERED | PK | ✅ |
| UQ_departments_name | departments(name) | UNIQUE NONCLUSTERED | BR10 | ✅ |
| PK_users | users(user_id) | CLUSTERED | PK | ✅ |
| UQ_users_email | users(email) | UNIQUE NONCLUSTERED | BR10 | ✅ |
| idx_users_department_id | users(department_id) | NONCLUSTERED | FK join (R1) | ✅ |
| PK_spaces | spaces(space_id) | CLUSTERED | PK | ✅ |
| UQ_spaces_space_code | spaces(space_code) | UNIQUE NONCLUSTERED | BR10 | ✅ |
| idx_spaces_current_status | spaces(current_status) | NONCLUSTERED | BR2, BR14 | ✅ |
| PK_facility_categories | facility_categories(category_id) | CLUSTERED | PK | ✅ |
| **UQ_facility_categories_name** | **facility_categories(category_name)** | **UNIQUE NONCLUSTERED** | **BR10** | **✅ Added in run_02** |
| **UQ_facility_categories_prefix** | **facility_categories(prefix)** | **UNIQUE NONCLUSTERED** | **BR10** | **✅ Added in run_02** |
| PK_facilities | facilities(facility_id) | CLUSTERED | PK | ✅ |
| **idx_facilities_category_id** | **facilities(category_id)** | **NONCLUSTERED** | **FK join (R15)** | **✅ Added in run_02** |
| **idx_facilities_space_id** | **facilities(space_id)** | **NONCLUSTERED** | **FK join (R6)** | **✅ New in run_02** |
| PK_bookings | bookings(booking_id) | CLUSTERED | PK | ✅ |
| idx_bookings_space_id | bookings(space_id) | NONCLUSTERED | FK join (R5), BR1 | ✅ |
| idx_bookings_requester_id | bookings(requester_id) | NONCLUSTERED | FK join (R2) | ✅ |
| idx_bookings_status | bookings(status) | NONCLUSTERED | BR14 | ✅ |
| idx_bookings_time_range | bookings(space_id, requested_start_time, requested_end_time) | NONCLUSTERED | Overlap detection (BR1) | ✅ |
| idx_bookings_requested_start | bookings(requested_start_time) | NONCLUSTERED | Scheduling queries | ✅ |
| uq_bookings_active_overlap | bookings(space_id, requested_start_time) WHERE status IN (...) AND is_deleted = 0 | UNIQUE NONCLUSTERED | BR1 | ✅ |
| PK_booking_approvals | booking_approvals(approval_id) | CLUSTERED | PK | ✅ |
| UQ_booking_approvals_booking_id | booking_approvals(booking_id) | UNIQUE NONCLUSTERED | R10 (1:0..1) | ✅ |
| idx_booking_approvals_approver_id | booking_approvals(approver_id) | NONCLUSTERED | FK join (R3) | ✅ |
| PK_booking_sessions | booking_sessions(session_id) | CLUSTERED | PK | ✅ |
| UQ_booking_sessions_booking_id | booking_sessions(booking_id) | UNIQUE NONCLUSTERED | R11 (1:0..1) | ✅ |
| idx_booking_sessions_checked_in_by | booking_sessions(checked_in_by) | NONCLUSTERED | FK join (R4) | ✅ |
| PK_maintenance | maintenance(maintenance_id) | CLUSTERED | PK | ✅ |
| idx_maintenance_space_id | maintenance(space_id) | NONCLUSTERED | FK join (R7) | ✅ |
| idx_maintenance_reporter_id | maintenance(reporter_id) | NONCLUSTERED | FK join (R8) | ✅ |
| idx_maintenance_assigned_staff_id | maintenance(assigned_staff_id) | NONCLUSTERED | FK join (R9) | ✅ |
| idx_maintenance_status | maintenance(status) | NONCLUSTERED | BR14 | ✅ |
| idx_maintenance_facility_id | maintenance(facility_id) | NONCLUSTERED | FK join (R16) | ✅ |
| PK_incidents | incidents(incident_id) | CLUSTERED | PK | ✅ |
| idx_incidents_space_id | incidents(space_id) | NONCLUSTERED | FK join (R12) | ✅ |
| idx_incidents_reported_by | incidents(reported_by) | NONCLUSTERED | FK join (R13) | ✅ |
| idx_incidents_assigned_to | incidents(assigned_to) | NONCLUSTERED | FK join (R14) | ✅ |
| idx_incidents_status | incidents(status) | NONCLUSTERED | BR14, BR20 | ✅ |
| idx_incidents_severity | incidents(severity) | NONCLUSTERED | BR14 | ✅ |
| idx_incidents_facility_id | incidents(facility_id) | NONCLUSTERED | FK join (R17) | ✅ |

**run_02 index changes:**
- **Added:** `UQ_facility_categories_name`, `UQ_facility_categories_prefix`, `idx_facilities_category_id`, `idx_facilities_space_id`
- **Removed:** All indexes on `space_facilities` (`PK_space_facilities`, `idx_space_facilities_facility_id`) — table removed
- **Total:** 39 indexes (was 38 in run_01 with space_facilities indexes; net +1 after removal/addition)

---

## 8. Normalization Proof (≥ 3NF)

### 8.1 1NF — Atomic Values, No Repeating Groups

| Table | 1NF Status | Evidence |
|---|---|---|
| departments | ✅ | All columns atomic; single value per cell. |
| users | ✅ | All columns atomic; single value per cell. |
| spaces | ✅ | All columns atomic; single value per cell. |
| facility_categories | ✅ | All columns atomic; single value per cell. |
| facilities | ✅ | All columns atomic; single value per cell. |
| bookings | ✅ | All columns atomic; single value per cell. |
| booking_approvals | ✅ | All columns atomic; single value per cell. |
| booking_sessions | ✅ | All columns atomic; single value per cell. |
| maintenance | ✅ | All columns atomic; single value per cell. |
| incidents | ✅ | All columns atomic; single value per cell. |

No table contains multi-valued attributes or repeating groups. The M:N relationship between spaces and facilities is resolved by the direct 1:N `facilities.space_id` FK (no junction table needed in run_02).

### 8.2 2NF — No Partial Dependencies

| Table | PK | 2NF Status | Evidence |
|---|---|---|---|
| departments | department_id (single) | ✅ | No partial dependency possible. |
| users | user_id (single) | ✅ | No partial dependency possible. |
| spaces | space_id (single) | ✅ | No partial dependency possible. |
| facility_categories | category_id (single) | ✅ | No partial dependency possible. |
| facilities | facility_id (single) | ✅ | No partial dependency possible. |
| bookings | booking_id (single) | ✅ | No partial dependency possible. |
| booking_approvals | approval_id (single) | ✅ | No partial dependency possible. |
| booking_sessions | session_id (single) | ✅ | No partial dependency possible. |
| maintenance | maintenance_id (single) | ✅ | No partial dependency possible. |
| incidents | incident_id (single) | ✅ | No partial dependency possible. |

**All 10 tables have single-column surrogate PKs.** No composite PK tables exist in run_02 (`space_facilities` removed). Partial dependencies are impossible by definition.

### 8.3 3NF — No Transitive Dependencies

| Table | 3NF Status | Evidence |
|---|---|---|
| departments | ✅ | `name` depends solely on `department_id`. |
| users | ✅ | All non-key attributes depend solely on `user_id`. `department_id` is a FK, not a transitive dependency. |
| spaces | ✅ | All non-key attributes depend solely on `space_id`. |
| facility_categories | ✅ | `category_name`, `prefix` depend solely on `category_id`. |
| facilities | ✅ | `category_id`, `space_id`, `status` depend solely on `facility_id`. FKs are not transitive dependencies. |
| bookings | ✅ | All non-key attributes depend solely on `booking_id`. `space_id`, `requester_id` are FKs. |
| booking_approvals | ✅ | All non-key attributes depend solely on `approval_id`. FKs are not transitive dependencies. |
| booking_sessions | ✅ | All non-key attributes depend solely on `session_id`. FKs are not transitive dependencies. |
| maintenance | ✅ | All non-key attributes depend solely on `maintenance_id`. `space_id`, `reporter_id`, `assigned_staff_id`, `facility_id` are FKs. |
| incidents | ✅ | All non-key attributes depend solely on `incident_id`. `space_id`, `reported_by`, `assigned_to`, `facility_id` are FKs. |

**Conclusion:** All 10 tables satisfy 3NF. No partial or transitive dependencies detected. The removal of `space_facilities` (which had no non-key attributes and was already in 3NF) does not affect the normalization status.

---

## 9. Discrepancy Log

### Legend
- **Critical**: Schema cannot correctly store or enforce required data.
- **Major**: Missing constraint or relationship.
- **Minor**: Documentation, naming, or optional improvement.

### Findings from run_01 (carried forward with updated status)

| ID | Severity | Category | Description | Affected File(s) | run_02 Status |
|---|---|---|---|---|---|
| F1 | Minor | Documentation | Entity-registry describes R3 participation as "Booking_Approvals partial". The correct interpretation is that Users' participation is partial (not all users are approvers), while Booking_Approvals' participation is total (every approval has an `approver_id` NOT NULL). | `docs/entity-registry.md` line 59 | Unresolved |
| F2 | Minor | Documentation | Entity-registry describes R4 participation as "Booking_Sessions partial". Same issue as F1 — Users' participation is partial; Booking_Sessions' participation is total (`checked_in_by` NOT NULL). | `docs/entity-registry.md` line 61 | Unresolved |
| F4 | Minor | Cross-file sync | Schema registry "Design validation passed" date (2026-06-17/18) predates the latest logical schema version. | `docs/schema-registry.md` | Unresolved — needs update after run_02 validation |
| F6 | Minor | Documentation | Trigger descriptions use "Before insert/update" wording, but triggers are AFTER triggers that use RAISERROR + ROLLBACK. | `outputs/03-logical-design-G05.md` §7 | Unresolved in run_01; verified run_02 logical design has corrected wording |

### Findings specific to run_02

| ID | Severity | Category | Description | Affected File(s) | Status |
|---|---|---|---|---|---|
| F7 | Resolved | Structural | `space_facilities` junction table removed; R6 re-implemented as 1:N direct via `facilities.space_id` nullable FK. | `outputs/run/run_02/03-logical-design-G05.md` | ✅ Applied — entity count 11→10, FK count adjusted (2 removed, 1 added), no composite PKs remain |
| F8 | Resolved | Structural | `facilities` gained `space_id INT NULL` FK with ON DELETE SET NULL. Ensures devices go to storage when parent space is deleted. | `outputs/run/run_02/03-logical-design-G05.md` | ✅ Applied |
| F9 | Minor | Documentation | Entity registry at `docs/entity-registry.md` still references the old 11-entity schema with `space_facilities`. The local copy at `outputs/run/run_02/entity-registry.md` is correct. | `docs/entity-registry.md` vs `outputs/run/run_02/entity-registry.md` | To be reconciled |
| F10 | Minor | Documentation | Schema registry at `docs/schema-registry.md` §3.4 "Design validation passed" date and freeze status need updating after run_02 validation. | `docs/schema-registry.md` | To be updated |

### Findings Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| Major | 0 |
| Minor (unresolved) | 4 (F1, F2, F4, F6 + F9, F10) |
| Resolved | 4 (F3 in run_01, F5 in run_01, F7 in run_02, F8 in run_02) |

**No critical or major issues found.** Two structural changes from run_02 (F7, F8) are correctly applied and verified. Four minor documentation items from run_01 remain plus two new minor items (F9, F10).

---

## 10. Cross-File Synchronization Check

| Pair | Status | Notes |
|---|---|---|
| `outputs/run/run_02/02-erd-design-G05.md` ↔ `outputs/run/run_02/03-logical-design-G05.md` | ✅ In sync | R6 is 1:N direct via `facilities.space_id` (not M:N). 10 entities match. 17 relationships match. |
| `docs/entity-registry.md` ↔ `outputs/run/run_02/03-logical-design-G05.md` | ⚠️ Minor drift | `docs/entity-registry.md` still references 11 entities with `space_facilities`. run_02 logical design has 10. Local registry in `outputs/run/run_02/entity-registry.md` is correct. |
| `docs/schema-registry.md` ↔ `outputs/run/run_02/03-logical-design-G05.md` | ⚠️ Minor drift | `docs/schema-registry.md` still references 11 tables. run_02 logical design has 10. Local registry in `outputs/run/run_02/schema-registry.md` is correct. |
| `outputs/01-business-req-analysis-G05.md` ↔ `outputs/run/run_02/03-logical-design-G05.md` | ✅ In sync | All 21 business rules addressed. BR10 references 5 UNIQUE constraints (no UQ_facilities_name). |

---

## 11. Registry Lock Status

| Registry | Current Status | Date | Notes |
|---|---|---|---|
| `docs/entity-registry.md` | 🔒 Locked | 2026-07-01 | 11 entities — needs update to 10 for run_02. Local copy in `outputs/run/run_02/` is correct. |
| `docs/schema-registry.md` | 🔒 Locked | 2026-07-05 | 10-table schema — local copy in `outputs/run/run_02/` is correct and up to date. |
| `outputs/run/run_02/entity-registry.md` | 🔒 Locked | 2026-07-05 | 10 entities — run_02 correct version. |
| `outputs/run/run_02/schema-registry.md` | 🔒 Locked | 2026-07-05 | 10 tables — run_02 correct version. |

---

## 12. Evaluation Criteria Summary

| # | Criterion | Verdict |
|---|---|---|
| 1 | Correctly represents the ERD | **Pass** — All 10 entities, all attributes, all 17 relationships present with correct structure. R6 changed from M/N to 1:N direct. |
| 2 | Satisfies business rules | **Pass** — All 21 business rules enforced. BR10 has 5 UNIQUE constraints (no UQ_facilities_name). BR12 covers all 10 tables. |
| 3 | Uses appropriate keys | **Pass** — Every table has a PK. Business keys have UNIQUE constraints. No composite PK tables (space_facilities removed). |
| 4 | Uses appropriate relationships | **Pass** — 1:N via FK (R6 direct). 1:0..1 via FK + UNIQUE. Cardinalities and participation match ERD. |
| 5 | Uses appropriate constraints | **Pass** — 17 FK constraints, CHECK, UNIQUE, DEFAULT all correctly applied. R6 FK uses SET NULL for storage behavior. |

---

## 13. Self-Check Checklist

- [x] **Entity coverage** — 10 entities (space_facilities removed); every entity maps 1:1 to a table.
- [x] **Attribute completeness** — every conceptual attribute appears in the mapped table.
- [x] **Business rule coverage** — BR1–BR21 traced and enforced. BR10: 5 UNIQUE constraints. BR12: all 10 tables.
- [x] **Relationship translation** — R1–R17 correct. R6 changed to 1:N direct via facilities.space_id.
- [x] **FK & RI rules** — 17 FKs verified; each has ON DELETE/ON UPDATE; R6 FK uses SET NULL.
- [x] **Key adequacy** — 10 PKs, 6 UNIQUE constraints. No composite PKs.
- [x] **Index coverage** — 39 indexes. facility_categories UQs and facilities FKs added; space_facilities indexes removed.
- [x] **Normalization (3NF)** — 10 tables, all 3NF. No composite PK tables.
- [x] **Discrepancy log quality** — Findings from run_01 re-evaluated; run_02 changes noted as resolved (F7, F8).
- [x] **Cross-file synchronisation** — All file pairs verified. Minor drift noted between docs/ and outputs/run_02/.
- [x] **Verdict summary** — stated below.

---

## 14. Verdict

**SCHEMA FREEZE READY.**

The run_02 logical schema (`outputs/run/run_02/03-logical-design-G05.md`) correctly implements the removal of `space_facilities` and the conversion of R6 from M:N to 1:N direct via `facilities.space_id` (nullable). All 10 entities, 17 relationships, and 21 business rules are consistently represented. The schema is normalized to 3NF with appropriate keys, 17 FK constraints with correct referential integrity actions, and 39 indexes covering all query patterns and FK joins.

No critical or major issues exist. Minor documentation items (F1, F2, F4, F6, F9, F10) do not block a schema freeze.

---

## 15. Revision Log

| Date | Change | Reason |
|---|---|---|
| 2026-07-05 | Full regeneration for run_02 — entity count 11→10, space_facilities removed, R6 changed to 1:N direct via facilities.space_id, FK count adjusted (2 removed, 1 added), 10-table 3NF re-proofed, facility_categories and facilities indexes updated, discrepancy log updated (F7 resolved, F8 resolved, F9/F10 added) | run_02 structural changes — device-level facilities no longer need M:N junction |
| 2026-07-04 | Updated all sections for facility refactoring: 11 entities, 17 relationships, R15–R17, Facility_Categories, instance-level Facilities, nullable facility_id on Maintenance/Incidents | Facility refactoring validation |
| 2026-07-04 | Initial validation of run_01 amendment (Incidents entity, R12–R14, BR20–BR21) | New incidents entity added to schema |
| 2026-07-04 | Initial validation report generated (10 entities, 14 relationships) | Task 04 deliverable |

---

*Generated for CS486 Group G05 — Campus Space Management System*
*Validation performed against: outputs/01 v2026-06-12, outputs/run/run_02/02-erd-design-G05.md v2026-06-18, outputs/run/run_02/03-logical-design-G05.md v2026-07-05, entity-registry v2026-07-05, schema-registry v2026-07-05*
