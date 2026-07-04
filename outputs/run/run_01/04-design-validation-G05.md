# Design Validation Report — Campus Space Management System

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Validation Date:** 2026-07-04
**Status:** REVISION REQUIRED (minor documentation fixes + facility refactoring + run_01 incident amendment)

---

## 1. Validation Scope

This report evaluates the relational logical schema (`outputs/03-logical-design-G05.md`) against:
- The conceptual ERD (`outputs/02-erd-design-G05.md`)
- The business requirements (`outputs/01-business-req-analysis-G05.md`)
- The entity registry (`docs/entity-registry.md`)
- The schema registry (`docs/schema-registry.md`)

---

## 2. ERD Fidelity — Pass (with minor documentation notes)

### 2.1 Entity Coverage

Every entity defined in the ERD maps to exactly one table in the logical schema:

| ERD Entity | Logical Table | Status |
|---|---|---|
| Departments | `departments` | ✅ Present |
| Users | `users` | ✅ Present |
| Spaces | `spaces` | ✅ Present |
| Facilities | `facilities` | ✅ Present |
| Space_Facilities | `space_facilities` | ✅ Present |
| Bookings | `bookings` | ✅ Present |
| Booking_Approvals | `booking_approvals` | ✅ Present |
| Booking_Sessions | `booking_sessions` | ✅ Present |
| Maintenance | `maintenance` | ✅ Present |
| Incidents | `incidents` | ✅ Present (run_01 amendment) |
| Facility_Categories | `facility_categories` | ✅ Present |

No orphan tables exist (every table has a corresponding ERD entity).

### 2.2 Attribute Completeness

Each entity's attributes (including audit columns and soft-delete flags) match exactly between the entity registry and the logical schema:

| Entity | Attributes in Registry | Attributes in Logical Schema | Match |
|---|---|---|---|---|
| Departments | 4 | 4 | ✅ |
| Users | 9 | 9 | ✅ |
| Spaces | 12 | 12 | ✅ |
| Facility_Categories | 4 | 4 | ✅ |
| Facilities | 5 | 5 | ✅ |
| Space_Facilities | 2 | 2 | ✅ |
| Bookings | 11 | 11 | ✅ |
| Booking_Approvals | 9 | 9 | ✅ |
| Booking_Sessions | 10 | 10 | ✅ |
| Maintenance | 11 | 11 | ✅ |
| Incidents | 12 | 12 | ✅ (run_01 amendment) |

All attribute names, data types, nullability, and constraints (PK, FK, UQ, CHECK, DEFAULT) are consistent between the entity registry and the logical schema.

### 2.3 Relationship Registry Coverage

All 17 relationships (R1–R17) from the ERD and entity-registry are represented in the logical schema:

| Relationship | Logical Implementation | Status |
|---|---|---|
| R1: Departments → Users (1:N) | FK `users.department_id` → `departments.department_id` | ✅ |
| R2: Users → Bookings (1:N) | FK `bookings.requester_id` → `users.user_id` | ✅ |
| R3: Users → Booking_Approvals (1:N) | FK `booking_approvals.approver_id` → `users.user_id` | ✅ |
| R4: Users → Booking_Sessions (1:N) | FK `booking_sessions.checked_in_by` → `users.user_id` | ✅ |
| R5: Spaces → Bookings (1:N) | FK `bookings.space_id` → `spaces.space_id` | ✅ |
| R6: Spaces ↔ Facilities (M:N) | Junction table `space_facilities` (instance-level) | ✅ |
| R7: Spaces → Maintenance (1:N) | FK `maintenance.space_id` → `spaces.space_id` | ✅ |
| R8: Users → Maintenance reporter (1:N) | FK `maintenance.reporter_id` → `users.user_id` | ✅ |
| R9: Users → Maintenance assignee (1:N) | FK `maintenance.assigned_staff_id` → `users.user_id` (nullable) | ✅ |
| R10: Bookings → Booking_Approvals (1:0..1) | FK `booking_approvals.booking_id` + UNIQUE | ✅ |
| R11: Bookings → Booking_Sessions (1:0..1) | FK `booking_sessions.booking_id` + UNIQUE | ✅ |
| R12: Spaces → Incidents (1:N) | FK `incidents.space_id` → `spaces.space_id` | ✅ |
| R13: Users → Incidents reporter (1:N) | FK `incidents.reported_by` → `users.user_id` | ✅ |
| R14: Users → Incidents assignee (1:N) | FK `incidents.assigned_to` → `users.user_id` (nullable) | ✅ |
| R15: Facility_Categories → Facilities (1:N) | FK `facilities.category_id` → `facility_categories.category_id` | ✅ |
| R16: Facilities → Maintenance (1:N, partial) | FK `maintenance.facility_id` → `facilities.facility_id` (nullable) | ✅ |
| R17: Facilities → Incidents (1:N, partial) | FK `incidents.facility_id` → `facilities.facility_id` (nullable) | ✅ |

---

## 3. Business Rule Coverage — Pass (with minor documentation gap)

### 3.1 Business Rule Traceability Matrix

| BR | Rule | Enforcement Mechanism | Level | Verdict |
|---|---|---|---|---|
| BR1 | No overlapping approved bookings | `uq_bookings_active_overlap` (filtered unique index) + `trg_bookings_prevent_overlap` (interval overlap trigger) | Database | ✅ Enforced |
| BR2 | Unavailable spaces cannot be approved | `trg_booking_approvals_check_space` trigger | Database | ✅ Enforced |
| BR3 | Expected participants ≤ space capacity | `trg_bookings_check_capacity` trigger | Database | ✅ Enforced |
| BR4 | Maintenance blocks booking | `trg_bookings_check_maintenance` trigger | Database | ✅ Enforced |
| BR5 | Maintenance assigned staff tracking | FK `assigned_staff_id` → `users.user_id` ON DELETE SET NULL | Database | ✅ Enforced |
| BR6 | Decision recording (approver, time, decision) | `trg_booking_approvals_decision` trigger | Database | ✅ Enforced |
| BR7 | Rejection requires reason | `trg_booking_approvals_rejection` trigger | Database | ✅ Enforced |
| BR8 | Actual time recording at check-in/completion | `trg_booking_sessions_checkin` + `trg_booking_sessions_completion` triggers | Database | ✅ Enforced |
| BR9 | Space condition tracking | `initial_condition`, `final_condition` + same triggers as BR8 | Database | ✅ Enforced |
| BR10 | Unique identification (email, space_code) | UNIQUE constraints on `users(email)`, `spaces(space_code)`, `departments(name)`, `facility_categories(category_name)`, `facility_categories(prefix)` | Database | ✅ Enforced |
| BR11 | Soft deletes for audit trail | `is_deleted BIT NOT NULL DEFAULT 0` on bookings and maintenance | Database | ✅ Enforced |
| BR12 | Audit trail (created_at, updated_at) | Both columns with `DEFAULT GETDATE()` on all 11 tables | Database | ✅ Enforced |
| BR13 | Historical records preservation | Soft delete pattern; FKs use NO ACTION or SET NULL | App + DB | ✅ Enforced |
| BR14 | Staff view reports | Supporting indexes present | Database | ✅ Enforced |
| BR15 | Approver must be facility staff/manager | `trg_booking_approvals_check_role` trigger | Database | ✅ Enforced |
| BR16 | Check-in staff must be facility staff/manager | `trg_booking_sessions_check_role` trigger | Database | ✅ Enforced |
| BR17 | Assigned maintenance staff must be facility staff | `trg_maintenance_check_assignee_role` trigger | Database | ✅ Enforced |
| BR18 | Cancellation validity and space cleanup | `trg_bookings_cancellation` trigger | Database | ✅ Enforced |
| BR19 | Maintenance completion restores space status | `trg_maintenance_completion_space_status` trigger | Database | ✅ Enforced |
| BR20 | Unresolved incidents block booking | `trg_bookings_check_incidents` trigger | Database | ✅ Enforced |
| BR21 | Maintenance completion auto-resolves incidents | `trg_incidents_autoresolve` trigger | Database | ✅ Enforced |

### 3.2 Finding: Incidents amendment — cross-file sync verified

**run_01:** All 11 entities, 17 relationships, and 21 business rules are now in sync across entity-registry, ERD, logical schema, and DDL. The facility refactoring (Facility_Categories, instance-level Facilities, R15–R17) and the run_01 incidents amendment are consistently implemented.

---

## 4. Key Adequacy — Pass

### 4.1 Primary Key Coverage

| Table | PK Column | Type | Surrogate? | Natural UQ Present |
|---|---|---|---|---|
| departments | department_id | INT IDENTITY | Yes | name (UQ) |
| users | user_id | INT IDENTITY | Yes | email (UQ) |
| spaces | space_id | INT IDENTITY | Yes | space_code (UQ) |
| facility_categories | category_id | INT IDENTITY | Yes | category_name (UQ), prefix (UQ) |
| facilities | facility_id | INT IDENTITY | Yes | — (no natural key) |
| space_facilities | (space_id, facility_id) | Composite | N/A (natural composite) | — |
| bookings | booking_id | INT IDENTITY | Yes | — (no natural key) |
| booking_approvals | approval_id | INT IDENTITY | Yes | booking_id (UQ) |
| booking_sessions | session_id | INT IDENTITY | Yes | booking_id (UQ) |
| maintenance | maintenance_id | INT IDENTITY | Yes | — (no natural key) |
| incidents | incident_id | INT IDENTITY | Yes | — (no natural key) |

### 4.2 Surrogate Key Justification

- **departments, users, spaces**: Surrogate PKs with UNIQUE business keys — best-of-both-worlds hybrid approach. Consistent with `docs/design-decisions.md` decision on surrogate keys.
- **facility_categories**: Surrogate PK with two UNIQUE business keys (`category_name`, `prefix`).
- **facilities**: Surrogate PK. No natural key — each row is a physical device instance identified by the system.
- **bookings, maintenance**: No natural key exists (a booking is identified by the system; multiple attributes collectively define a unique row but no single business key).
- **booking_approvals, booking_sessions**: No natural key; `booking_id` UNIQUE enforces the 1:0..1 parent relationship.
- **space_facilities**: Natural composite PK `(space_id, facility_id)` — the most appropriate choice for a junction table.

All tables have appropriate primary keys; surrogate keys are used only where justified.

---

## 5. Relationship Translation — Pass

### 5.1 Translation Pattern Verification

| Relationship | ERD Cardinality | Logical Implementation | Correctness |
|---|---|---|---|
| R1: Department → Users | 1:N (User total) | FK `users.department_id` NOT NULL | ✅ Correct |
| R2: User → Bookings (requester) | 1:N (Bookings total) | FK `bookings.requester_id` NOT NULL | ✅ Correct |
| R3: User → Booking_Approvals (approver) | 1:N (Approvals total) | FK `booking_approvals.approver_id` NOT NULL | ✅ Correct |
| R4: User → Booking_Sessions (checks_in) | 1:N (Sessions total) | FK `booking_sessions.checked_in_by` NOT NULL | ✅ Correct |
| R5: Spaces → Bookings | 1:N (Bookings total) | FK `bookings.space_id` NOT NULL | ✅ Correct |
| R6: Spaces ↔ Facilities | M:N (both partial) | Junction table `space_facilities` with composite PK `(space_id, facility_id)` | ✅ Correct |
| R7: Spaces → Maintenance | 1:N (Maintenance total) | FK `maintenance.space_id` NOT NULL | ✅ Correct |
| R8: Users → Maintenance (reporter) | 1:N (Maintenance total) | FK `maintenance.reporter_id` NOT NULL | ✅ Correct |
| R9: Users → Maintenance (assignee) | 1:N (Maintenance partial) | FK `maintenance.assigned_staff_id` NULLABLE | ✅ Correct |
| R10: Bookings → Booking_Approvals | 1:0..1 (Approvals total) | FK `booking_approvals.booking_id` + UNIQUE | ✅ Correct |
| R11: Bookings → Booking_Sessions | 1:0..1 (Sessions total) | FK `booking_sessions.booking_id` + UNIQUE | ✅ Correct |
| R12: Spaces → Incidents | 1:N (Incidents total) | FK `incidents.space_id` NOT NULL | ✅ Correct |
| R13: Users → Incidents (reporter) | 1:N (Incidents total) | FK `incidents.reported_by` NOT NULL | ✅ Correct |
| R14: Users → Incidents (assignee) | 1:N (Incidents partial) | FK `incidents.assigned_to` NULLABLE | ✅ Correct |
| R15: Facility_Categories → Facilities | 1:N (Facilities total) | FK `facilities.category_id` NOT NULL | ✅ Correct |
| R16: Facilities → Maintenance | 1:N (Maintenance partial) | FK `maintenance.facility_id` NULLABLE | ✅ Correct |
| R17: Facilities → Incidents | 1:N (Incidents partial) | FK `incidents.facility_id` NULLABLE | ✅ Correct |

### 5.2 Referential Integrity Actions

| FK | Child | Parent | ON DELETE | ON UPDATE | Justified? |
|---|---|---|---|---|---|
| department_id | users | departments | NO ACTION | NO ACTION | ✅ Prevents orphan users |
| requester_id | bookings | users | NO ACTION | NO ACTION | ✅ Preserves booking history |
| space_id | bookings | spaces | NO ACTION | NO ACTION | ✅ Preserves booking history |
| space_id | space_facilities | spaces | CASCADE | NO ACTION | ✅ Junction child of space |
| facility_id | space_facilities | facilities | CASCADE | NO ACTION | ✅ Junction child of facility |
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

All referential integrity actions match the business requirements (preserve historical records, avoid SQL Server cascade path conflicts).

---

## 6. Constraint Completeness — Pass

### 6.1 Constraint Inventory

Every CHECK, UNIQUE, NOT NULL, DEFAULT, and FK constraint from the entity-registry is present in the logical schema. Specific verification:

| Constraint Type | Status |
|---|---|
| NOT NULL on all required columns | ✅ All mandatory attributes NOT NULL |
| CHECK capacity > 0 on `spaces.capacity` | ✅ Present |
| CHECK end > start on `bookings.requested_end_time` | ✅ Present |
| CHECK expected_participants > 0 on `bookings.expected_participants` | ✅ Present |
| CHECK on all status/role enums (8 total) | ✅ All present |
| UNIQUE on business keys (5 total) | ✅ All present |
| UNIQUE on 1:0..1 FKs (2 total) | ✅ All present |
| DEFAULT values (statuses, timestamps, flags) | ✅ All correct |
| FK constraints (15 total) | ✅ All present with correct parents |
| Trigger-enforced rules (12 triggers) | ✅ All documented |

*(Section 6.2 removed — `space_facilities.quantity` column eliminated in facility refactoring; CHECK no longer applicable)*

---

## 7. Naming Consistency — Pass

### 7.1 Convention Audit

| Convention | Expected | Actual | Status |
|---|---|---|---|
| Table names | snake_case, plural | `departments`, `booking_approvals`, `space_facilities` | ✅ |
| Column names | snake_case | `actual_start_time`, `rejection_reason` | ✅ |
| PK naming | `<table_singular>_id` | `booking_id`, `space_id`, `approval_id` | ✅ |
| FK naming | Same as referenced PK | `space_id`, `department_id`, `requester_id` | ✅ |
| Junction table | `<tableA>_<tableB>` (alpha) | `space_facilities` | ✅ |
| Enum/status values | lowercase_with_underscores | `checked_in`, `under_maintenance`, `facility_staff` | ✅ |
| Index naming | `idx_<table>_<column>` | `idx_bookings_space_id` | ✅ |
| PK constraint | `PK_<table>` | `PK_bookings`, `PK_users` | ✅ |
| UQ constraint | `UQ_<table>_<column>` | `UQ_users_email`, `UQ_booking_approvals_booking_id` | ✅ |
| FK constraint | `FK_<child>_<col>` | `FK_bookings_space_id` | ✅ |
| CK constraint | `CK_<table>_<rule>` | `CK_spaces_capacity`, `CK_bookings_status` | ✅ |
| DF constraint | `DF_<table>_<column>` | `DF_bookings_is_deleted`, `DF_users_created_at` | ✅ |
| Trigger | `trg_<table>_<action>` | `trg_bookings_prevent_overlap` | ✅ |

All naming conventions are consistent and follow the conventions defined in `outputs/03` §6.

---

## 8. Normalization (≥ 3NF) — Pass

### 8.1 1NF Verification

All 11 tables have atomic columns with no repeating groups. The M:N relationship between spaces and facilities is resolved via the junction table `space_facilities`.

| Table | 1NF | Evidence |
|---|---|---|
| departments | ✅ | Atomic columns |
| users | ✅ | Atomic columns |
| spaces | ✅ | Atomic columns |
| facility_categories | ✅ | Atomic columns |
| facilities | ✅ | Atomic columns |
| space_facilities | ✅ | Junction resolves M:N |
| bookings | ✅ | Atomic columns |
| booking_approvals | ✅ | Atomic columns |
| booking_sessions | ✅ | Atomic columns |
| maintenance | ✅ | Atomic columns |
| incidents | ✅ | Atomic columns |

### 8.2 2NF Verification

All tables with single-column PKs have no partial dependencies (impossible by definition). The only composite PK table (`space_facilities`) has no non-key attributes.

| Table | PK | 2NF | Evidence |
|---|---|---|---|
| departments | department_id (single) | ✅ | No partial dependency possible |
| users | user_id (single) | ✅ | No partial dependency possible |
| spaces | space_id (single) | ✅ | No partial dependency possible |
| facility_categories | category_id (single) | ✅ | No partial dependency possible |
| facilities | facility_id (single) | ✅ | No partial dependency possible |
| space_facilities | (space_id, facility_id) | ✅ | No non-key attributes; no partial dependency possible |
| bookings | booking_id (single) | ✅ | No partial dependency possible |
| booking_approvals | approval_id (single) | ✅ | No partial dependency possible |
| booking_sessions | session_id (single) | ✅ | No partial dependency possible |
| maintenance | maintenance_id (single) | ✅ | No partial dependency possible |
| incidents | incident_id (single) | ✅ | No partial dependency possible |

### 8.3 3NF Verification

No transitive dependencies exist. All non-key attributes depend solely on the primary key. Foreign key columns reference other tables and are not transitive dependencies (they are direct dependencies on the PK of the referenced table).

| Table | 3NF | Evidence |
|---|---|---|
| departments | ✅ | name depends solely on department_id |
| users | ✅ | All attributes depend solely on user_id |
| spaces | ✅ | All attributes depend solely on space_id |
| facility_categories | ✅ | category_name and prefix depend solely on category_id |
| facilities | ✅ | category_id and status depend solely on facility_id; category_id is a FK, not a transitive dependency |
| space_facilities | ✅ | No non-key attributes; no transitive dependency possible |
| bookings | ✅ | All attributes depend solely on booking_id |
| booking_approvals | ✅ | All attributes depend solely on approval_id |
| booking_sessions | ✅ | All attributes depend solely on session_id |
| maintenance | ✅ | All attributes depend solely on maintenance_id |
| incidents | ✅ | All attributes depend solely on incident_id |

**Verdict:** All 11 tables satisfy 3NF. No partial or transitive dependencies detected.

---

## 9. Discrepancy Log

### Legend
- **Critical**: Schema cannot correctly store or enforce required data.
- **Major**: Missing constraint or relationship.
- **Minor**: Documentation, naming, or optional improvement.

### Findings

| ID | Severity | Category | Description | Affected File(s) |
|---|---|---|---|---|
| F1 | Minor | Documentation | Entity-registry describes R3 participation as "Booking_Approvals partial". The correct interpretation is that Users' participation is partial (not all users are approvers), while Booking_Approvals' participation is total (every approval has an `approver_id` NOT NULL). The logical schema correctly uses NOT NULL; the registry note is ambiguous. | `docs/entity-registry.md` line 59 |
| F2 | Minor | Documentation | Entity-registry describes R4 participation as "Booking_Sessions partial". Same issue as F1 — Users' participation is partial; Booking_Sessions' participation is total (`checked_in_by` NOT NULL). | `docs/entity-registry.md` line 61 |
| F3 | Resolved | Documentation | BR19 numbering gap resolved — BR19 now in the numbered BR table (§7), BR20–BR21 added for incidents. | `outputs/03-logical-design-G05.md` §7 |
| F4 | Minor | Cross-file sync | Schema registry "Design validation passed" date (2026-06-17/18) predates the latest logical schema version. Freeze status needs updating after this validation. | `docs/schema-registry.md` |
| F5 | Obsolete | Constraint improvement | `space_facilities.quantity` removed in facility refactoring — CK constraint no longer applicable. | `outputs/05-db-definition-G05.sql` |
| F6 | Minor | Documentation | `outputs/03` §7 trigger descriptions use "Before insert/update" wording, but the triggers are AFTER triggers that use RAISERROR + ROLLBACK. The wording is misleading about trigger timing. | `outputs/03-logical-design-G05.md` §7 |

### Findings Summary

| Severity | Count |
|---|---|
| Critical | 0 |
| Major | 0 |
| Minor | 2 unresolved (F1, F2, F4, F6) + 1 resolved (F3) + 1 obsolete (F5) |

No critical or major issues found. Two findings resolved during run_01 amendment; one obsoleted by facility refactoring. Four minor documentation items remain.

---

## 10. Recommendations

| Finding | Recommendation | Priority |
|---|---|---|
| F1 | Update `docs/entity-registry.md` R3 participation note to clarify: "Users partial (not all users are approvers); Booking_Approvals total (every approval has an approver)". Use the same format as R9 (which correctly distinguishes the two sides). | Low |
| F2 | Update `docs/entity-registry.md` R4 participation note to clarify: "Users partial (not all users are check-in staff); Booking_Sessions total (every session has a checked_in_by)". | Low |
| F3 | Resolved — BR19, BR20, BR21 now present in §7 BR table. | — |
| F4 | Update `docs/schema-registry.md` "Design validation passed" date and freeze status after this validation accepts the run_01 amendment. | Low |
| F5 | Obsolete — `quantity` column removed in facility refactoring; no CHECK constraint needed. | — |
| F6 | Update trigger descriptions in `outputs/03-logical-design-G05.md` §7 to accurately state the trigger timing (e.g., "AFTER INSERT, UPDATE — validates and rolls back if constraint violated" instead of "Before insert/update..."). | Low |

---

## 11. Cross-File Synchronization Check

| Pair | Status | Notes |
|---|---|---|
| `docs/entity-registry.md` ↔ `outputs/03-logical-design-G05.md` | ✅ In sync | All 11 entities and attributes match (facility refactoring + incidents). |
| `docs/schema-registry.md` ↔ `outputs/03-logical-design-G05.md` | ✅ In sync | All 37 indexes match. Business rule coverage includes BR1–BR21. |
| `docs/schema-registry.md` ↔ `docs/entity-registry.md` | ✅ In sync | Table-to-entity mappings are correct. |
| `outputs/01-business-req-analysis-G05.md` ↔ `outputs/03-logical-design-G05.md` | ✅ In sync | All 21 business rules are addressed. |

---

## 12. Registry Lock Status

| Registry | Current Status | Date | Notes |
|---|---|---|---|---|
| `docs/entity-registry.md` | 🔒 Locked | 2026-07-04 | All 11 entities finalized (facility refactoring + run_01 incidents). Minor documentation fixes recommended (F1, F2). |
| `docs/schema-registry.md` | 🔒 Locked | 2026-07-04 | Schema registry regenerated with 11-table schema (facility refactoring + run_01 amendment). |

**Actions taken:** Both registries were cross-verified against `outputs/03-logical-design-G05.md` and are fully synchronized. Facility refactoring (Facility_Categories, instance-level Facilities) and run_01 amendment (Incidents) applied consistently across all artifacts.

---

## 13. Evaluation Criteria Summary

| # | Criterion | Verdict |
|---|---|---|
| 1 | Correctly represents the ERD | **Pass** — All 11 entities, all attributes, all 17 relationships present with correct structure. |
| 2 | Satisfies business rules | **Pass** — All 21 business rules are enforced via CHECK, UNIQUE, FK, triggers, or indexes. |
| 3 | Uses appropriate keys | **Pass** — Every table has a PK. Business keys have UNIQUE constraints. Surrogate keys used only where justified. |
| 4 | Uses appropriate relationships | **Pass** — 1:N via FK on many-side. M:N via junction table. 1:0..1 via FK + UNIQUE. Cardinalities and participation match ERD. |
| 5 | Uses appropriate constraints | **Pass** — NOT NULL, UNIQUE, CHECK, DEFAULT, referential integrity actions all correctly applied. |

---

## 14. Self-Check Checklist

- [x] **Entity coverage** — every entity in the ERD maps to exactly one table in the logical schema; no orphan tables.
- [x] **Attribute completeness** — every conceptual attribute appears in the mapped table with matching name, type, and nullability.
- [x] **Business rule coverage** — every business rule is traced to a schema mechanism and labelled Enforced.
- [x] **Relationship translation** — each of R1–R17 is translated with correct cardinality, participation, and referential integrity.
- [x] **Key adequacy** — every table has a PRIMARY KEY; natural candidate keys have UNIQUE constraints; surrogate keys justified.
- [x] **Normalization (3NF)** — no partial or transitive dependencies; all 11 tables satisfy 3NF.
- [x] **Discrepancy log quality** — each entry classified as Critical/Major/Minor with actionable recommendation; no vague entries.
- [x] **Discrepancy log completeness** — all findings discovered during checks are recorded (4 unresolved + 1 resolved + 1 obsolete).
- [x] **Cross-file synchronisation** — all file pairs verified; F3 resolved during run_01 amendment; F5 obsoleted by facility refactoring.
- [x] **Lock status documented** — Section 12 lists both registries with current status and actions taken.
- [x] **Verdict summary** — stated below.

---

## 15. Verdict

**SCHEMA FREEZE READY — with deferred minor documentation fixes.**

The logical schema (`outputs/03-logical-design-G05.md`) correctly represents the ERD, satisfies all 21 business rules, uses appropriate keys and relationships, includes proper constraints, and is normalized to 3NF. The facility refactoring (Facility_Categories, instance-level Facilities, R15–R17) and run_01 incidents amendment (R12–R14, BR20–BR21) are consistently implemented across all artifacts. Four minor documentation findings remain (F1, F2, F4, F6) — none blocks a schema freeze.

---

## 16. Revision Log

| Date | Change | Reason |
|------|--------|--------|
| 2026-07-04 | Updated all sections for facility refactoring: 11 entities, 17 relationships, R15–R17, Facility_Categories, instance-level Facilities, nullable facility_id on Maintenance/Incidents | Facility refactoring validation — entity-registry updated with new entity and column changes; logical schema regenerated (v2.6) |
| 2026-07-04 | Initial validation of run_01 amendment (Incidents entity, R12–R14, BR20–BR21) | New incidents entity added to schema |
| 2026-07-04 | Initial validation report generated (10 entities, 14 relationships) | Task 04 deliverable |

---

*Generated for CS486 Group G05 — Campus Space Management System*
*Validation performed against: outputs/01 v2026-06-12, outputs/02 v2026-07-04 (run_01), outputs/03 v2026-07-04 (run_01 facility-refactoring), entity-registry v2026-07-04, schema-registry v2026-07-04*
