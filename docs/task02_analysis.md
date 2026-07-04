# Task 02 — ERD Design Analysis

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Domain:** Campus Space Management System
**Document purpose:** Analyse the conceptual ERD, explain design rationale per entity, and demonstrate why this design is the correct choice for the client.

---

## 1. Introduction

The Entity-Relationship Diagram (ERD) for the Campus Space Management System defines **11 entities** that together model the full booking lifecycle, from space registration and equipment inventory to usage requests, approval workflows, session check-in/out, maintenance handling, and incident reporting. The design centers on three pillars — **Users**, **Spaces**, and **Bookings** — supported by organizational units (**Departments**), equipment categories (**Facility_Categories**), individual device instances (**Facilities**), maintenance tracking (**Maintenance**), and incident reporting (**Incidents**). A defining architectural decision is the **Single Responsibility Principle (SRP) split** of the monolithic `Bookings` table into three focused tables (`Bookings`, `Booking_Approvals`, `Booking_Sessions`), ensuring each table owns exactly one phase of the booking lifecycle. The schema satisfies **Third Normal Form (3NF)**, eliminating data redundancy while preserving query performance.

---

## 2. Architectural Overview

The ERD is organized into three functional layers:

| Layer | Entities | Purpose |
|---|---|---|
| **Organizational layer** | Departments, Users | Who can interact with the system and what department they belong to |
| **Resource layer** | Spaces, Facilities, Space_Facilities, Facility_Categories | What physical assets exist, what equipment categories are defined, and what individual devices they contain |
| **Activity layer** | Bookings, Booking_Approvals, Booking_Sessions, Maintenance, Incidents | What events happen on the resources — requests, approvals, usage sessions, repairs, and incident reports |

The booking lifecycle is modeled as a **three-phase pipeline**:

1. **Request** (Bookings) — A user submits a time/space/purpose request with status `pending`.
2. **Decision** (Booking_Approvals) — Authorized staff approve or reject; if rejected, a `rejection_reason` is captured.
3. **Execution** (Booking_Sessions) — On arrival, staff check in (record actual start time + initial condition); on departure, staff check out (record actual end time + final condition + usage notes).

This split is the single most impactful design decision and is examined in detail in the entity sections below.

---

## 3. Entity-by-Entity Analysis

### 3.1 Departments

**Role:** Organizational unit anchor. Every user belongs to exactly one department (e.g., "Computer Science", "Physics", "Administration").

**Contribution to the common purpose:** 
  - Departments enable role-based oversight and reporting. 
  - A Department Administrator can view bookings and usage statistics filtered by their own department. 

**Why designed this way:**
- Modeled as a **separate table** (not a free-text field on Users) because departments are reference data with a stable list and a UNIQUE business key (`name`). A separate table enforces referential integrity — a User cannot belong to a non-existent department.
- Uses a **surrogate PK** (`department_id INT IDENTITY`) for efficient FK references from Users, plus a **UNIQUE constraint** on `name` for the business key — the hybrid approach recommended in design decisions.
- Attributes are minimal (only `department_id` and `name`) because no business requirement demands additional department metadata (e.g., office location, budget code). This keeps the entity lean.

---

### 3.2 Users

**Role:** Actor base. Every human interaction with the system is represented by a User record — requesting a booking, approving/rejecting, checking in, reporting maintenance, or being assigned as maintenance staff.

**Contribution to the common purpose:** 
- The entity centralizes identity (`email`, `full_name`), authorization (`role`), lifecycle (`account_status`), and organizational affiliation (`department_id → Departments`).
- All roles from the business requirements are supported, and the entity is designed to accommodate future role expansion without schema changes. 

**Why designed this way:**
- **Surrogate PK** (`user_id`) for efficient FK wiring across 7 relationships (R2–R4, R8–R9, plus implicit references). An Email **UNIQUE constraint** serves as the natural business key and login identifier.
- The `role` column uses **VARCHAR with CHECK constraint** (not a separate lookup table) because the six roles are defined in the business requirements and are unlikely to change. This avoids unnecessary joins. The same pattern applies to `account_status` (`active`, `inactive`, `suspended`).

- The design does **not** store passwords or authentication secrets — this is a database design, not an application. Authentication is handled externally.

---

### 3.3 Spaces

**Role:** Resource core. Spaces are the bookable physical assets that the entire system revolves around — auditoriums, classrooms, computer labs, project labs, meeting rooms, and student workspaces.

**Contribution to the common purpose:** 
- Spaces are referenced by Bookings (what is being booked), Space_Facilities (what equipment is inside), and Maintenance (what space needs repair). 
- The entity tracks location (`building`, `floor`, `room_number`), capacity (for participant limits), current availability (`current_status`), and usage rules (`usage_policy`).

**Why designed this way:**
- `building` and `floor` are **free-text NVARCHAR fields**, not separate reference tables. This is a deliberate trade-off (Decision Q5 in design-decisions.md): no business requirement demands cross-building reporting or building CRUD that would justify extra normalization. The cost is potential minor inconsistency ("Bldg A" vs "Building A"), which is acceptable for the current scope.
- `current_status` uses **VARCHAR with CHECK constraint**: `'available'`, `'in_use'`, `'under_maintenance'`, `'temporarily_closed'`, `'retired'`. The status drives Business Rule 2 (spaces that are not `'available'` cannot be booked) and is auto-updated by triggers on maintenance completion and booking check-in/out.

---

### 3.4 Facilities

**Role:** Individual device inventory. Represents a single physical piece of equipment — e.g., "Projector #3 in Lab 201", "Computer #15 in Office 101". Each row is one physical device, not a category entry.

**Contribution to the common purpose:** Facilities enable precise asset tracking — staff can report a problem with a specific device, maintenance can be assigned to a particular projector, and an incident can be logged against a stolen microphone. Per-category counts are derived via `COUNT(*) GROUP BY category_id` rather than stored redundantly.

**Why designed this way:**
- The entity stores a `category_id FK → facility_categories` to classify the device (projector, whiteboard, etc.), and a `status` column (`active`, `inactive`, `retired`, `lost`) to track lifecycle. This replaces the original single `name` column, which could only represent categories, not individual units.
- A unique facility code is derived at query time as `CONCAT(fc.prefix, '_', f.facility_id)` — e.g., `pro_3`, `com_15`. This avoids a trigger-based ID generation pattern while still providing a human-readable identifier.
- Facilities are **not** tied directly to Spaces — the M:N relationship is resolved by `Space_Facilities`, maintaining 3NF.
- The refactoring from category-level to instance-level (Decision: run_01 amendment) enables FK references from Maintenance and Incidents to target a specific device, supporting Business Rules R16 and R17.

---

### 3.5 Space_Facilities

**Role:** Junction (associative) entity resolving the many-to-many relationship between Spaces and individual Facility device instances.

**Contribution to the common purpose:** A space can contain multiple physical devices (e.g., Room 201 has Projector #3 and Computer #15), and the same device can be moved between spaces over its lifecycle. Each row in Space_Facilities represents exactly one device assignment to one space — the `quantity` column was removed during the facility refactoring because per-category counts are now derived via `COUNT(*) GROUP BY space_id, category_id`.

**Why designed this way:**
- This is the canonical 3NF pattern for M:N relationships and is one of the strongest indicators of normalized design quality in this schema.
- Removing `quantity` eliminates the ambiguity of whether "quantity = 5 computers" meant 5 individual trackable devices or one category entry with count 5. Now each device instance has its own `facility_id` and `status`, enabling per-device lifecycle tracking.

---

### 3.6 Bookings

**Role:** Booking request/ticket. This is the **first phase** of the three-phase booking pipeline — it captures the user's intent to use a space at a given time for a given purpose.

**Contribution to the common purpose:** 
- Bookings is the central entity that connects who (requester) wants what (space) when (start/end time) and why (purpose). 
- It drives the scheduling logic, overlap prevention, and the status lifecycle. After the SRP split, Bookings contains **only request-phase attributes**, leaving approval and session data to their respective tables.

**Why designed this way:**
- Attributes are strictly **request-phase only**. Compare with the old monolithic design that had **10 extra nullable columns** (approver_id, decision_time, etc.) — those are now in Booking_Approvals and Booking_Sessions.
- `is_deleted BIT DEFAULT 0` implements **soft delete** — records are never physically removed, preserving audit history
- `expected_participants` has a **`CHECK (expected_participants > 0)`** and is compared against `spaces.capacity` via Business Rule 3.

---

### 3.7 Booking_Approvals

**Role:** Decision record. Captures the approval or rejection decision made by authorized staff on a booking request — the **second phase** of the booking pipeline.

**Contribution to the common purpose:** Before the SRP split, approval data was stored in the Bookings table with nullable columns. Now, Booking_Approvals provides a clean, dedicated record of who decided, when, what the decision was, and (if rejected) why. This enables audit queries ("Show all rejections by staff X last month") and enforces Business Rule 6 (decision recording) and Rule 7 (rejection reason).

**Why designed this way:**
- **1:0..1 relationship** with Bookings — a booking may have zero or one approval row. This is enforced by a **UNIQUE constraint** on `booking_id`, which also serves as the FK. This guarantees that no booking can have multiple approval records.
- `decision` uses **CHECK constraint** with only two values: `'approved'` and `'rejected'` — no `'pending'` value because the row is only created when a decision is actually made.
- `rejection_reason` is a **dedicated column** (not merged into `decision_note`) because Business Rule 7 requires explicit storage and potential enforcement of rejection reasons. It is nullable at column level but enforced via trigger when `decision = 'rejected'` — this separation makes querying ("find all rejections due to capacity violation") clean and efficient.
- Role enforcement: `approver_id` is validated via trigger `trg_booking_approvals_check_role` to ensure only `facility_staff` or `facility_manager` can approve/reject (Business Rule 15).

---

### 3.8 Booking_Sessions

**Role:** Execution record. Tracks the check-in and check-out of an approved booking — the **third phase** of the booking pipeline.

**Contribution to the common purpose:** Booking_Sessions bridges the gap between what was *requested* (Bookings) and what actually *happened*. It records the real start time (which may differ from requested), the real end time, the space condition at both check-in and check-out, and who performed the check-in. This data is critical for:
- Detecting no-shows (approved booking, no session created)
- Capturing space damage (initial vs final condition comparison)
- Enforcing accountability (`checked_in_by` identifies the staff member)
- Calculating actual vs. requested duration for analytics

**Why designed this way:**
- **1:0..1 relationship** with Bookings — enforced by UNIQUE constraint on `booking_id`. A session row exists only if the booking was actually checked in.
- `actual_start_time` and `checked_in_by` are **NOT NULL** because they are recorded at the moment of check-in. `actual_end_time` is **nullable** because it is recorded later at check-out.
- `initial_condition` and `final_condition` are **NVARCHAR(MAX)**, nullable — free-text notes about space state. They are not mandatory because a quick check-in/out may not require notes, but they are available for capturing damage or issues.
- `checked_in_by` must reference a user with role `facility_staff` or `facility_manager`, enforced by trigger `trg_booking_sessions_check_role` (Business Rule 16).
- A check-in is only allowed when `bookings.status = 'approved'`, enforced by trigger `trg_booking_sessions_checkin` — this prevents bypassing the approval workflow.

---

### 3.9 Maintenance

**Role:** Repair tracker. Captures maintenance requests reported against a space or a specific piece of equipment, tracks assignment to facility staff, and records resolution.

**Contribution to the common purpose:** Maintenance ensures that space availability reflects the real physical state. When a space has an open or in-progress maintenance ticket, its `current_status` is set to `'under_maintenance'`, which blocks new approved bookings (Business Rule 2). The entity now also supports device-specific repairs via `facility_id`, complementing the `Incidents` entity (see §3.11).

**Why designed this way:**
- **Surrogate PK** (`maintenance_id`). No natural business key.
- `facility_id INT NULL FK → facilities.facility_id` (R16) supports device-specific repairs — e.g., "Projector pro_5 in Lab 201 needs bulb replacement." When NULL, maintenance targets the space as a whole.
- `reporter_id` is NOT NULL (total participation in R8 — every maintenance record must have a reporter).
- `assigned_staff_id` is **nullable** because a ticket may be reported before any staff is assigned. When set, a trigger (`trg_maintenances_check_assignee_role`) ensures the assigned user has `role = 'facility_staff'` (Business Rule 17). The FK uses **ON DELETE SET NULL** — if a staff member is deleted from Users, their assigned tickets are not lost but simply unassigned.
- `status` uses CHECK constraint: `'open'`, `'in_progress'`, `'resolved'`.
- On completion (status → `'resolved'`), two triggers fire: `trg_maintenances_completion_space_status` auto-sets `spaces.current_status = 'available'` **only if** no other active tickets exist for the same space; `trg_incidents_autoresolve` resolves any related incidents (space-level or device-specific, depending on whether `facility_id` is set).
- `is_deleted BIT DEFAULT 0` implements soft delete for historical preservation.

---

### 3.10 Facility_Categories

**Role:** Lookup/reference table defining the taxonomy of equipment types in the system — projector, whiteboard, microphone, computer, air conditioner, livestreaming equipment.

**Contribution to the common purpose:** Facility_Categories provides a controlled vocabulary that decouples device category metadata (category name, 3-letter prefix) from the individual device instances in `Facilities`. This avoids repeating `'projector'` across all 5 projector device rows, and enables efficient grouped reporting via `GROUP BY category_id`.

**Why designed this way:**
- Modeled as a **separate lookup table** (not a column on `Facilities` with CHECK constraint) because the six categories and their prefixes (`pro`, `whb`, `mic`, `com`, `air`, `liv`) are reference data with a stable, predictable set. The table uses **two UNIQUE constraints** — one on `category_name` (business key) and one on `prefix` (for human-readable facility code derivation: `CONCAT(prefix, '_', facility_id)`).
- Uses a **surrogate INT IDENTITY PK** (`category_id`) for efficient FK references from `Facilities`, avoiding the join cost of a natural-key FK on VARCHAR.
- Attributes are minimal (only `category_id`, `category_name`, `prefix`, `created_at`) because the business requirements do not demand additional category metadata (e.g., icon, description, manufacturer).

---

### 3.11 Incidents

**Role:** Incident report tracker. Captures non-maintenance issues — theft, vandalism, damage discovered during a booking session, or any event requiring investigation separate from a maintenance repair.

**Contribution to the common purpose:** Incidents provides a dedicated record for events that may or may not lead to a maintenance ticket. A stolen microphone, graffiti found on a whiteboard during check-out, or a damaged power outlet discovered by a staff member — all are logged here with `space_id`, optional `facility_id` (which specific device was involved), description, status, and resolution. The entity also supports Business Rule BR21: when a related maintenance ticket is resolved, any open incidents linked to the same facility or space are auto-resolved.

**Why designed this way:**
- **Separated from Maintenance** (unlike the original merged design) because incidents and maintenance have distinct lifecycle semantics — an incident can be resolved with a note and no repair action (e.g., "false alarm", "damage already existed"), while maintenance always implies a repair workflow. The separation also enables cleaner querying ("Show all theft-related incidents in the last month").
- `facility_id INT NULL FK → facilities.facility_id` (R17) optionally links the incident to a specific device — e.g., "Microphone mic_3 in AUD-001 was stolen."
- `status` uses CHECK constraint: `'reported'`, `'investigating'`, `'resolved'`. The auto-resolution trigger (`trg_incidents_autoresolve`) transitions status to `'resolved'` when the related maintenance ticket is completed, without manual intervention.
- `resolved_at` is nullable (set only when status becomes `'resolved'`), and `assigned_to` is nullable (incidents may be reported without immediate assignment).

---

## 4. Comparison: Monolithic vs. SRP-Split Booking Design

The most significant improvement in the current ERD is the **split of the monolithic Bookings table** into three focused tables. Below is a direct comparison:

| Aspect | Old Monolithic `Bookings` | New SRP-Split Design |
|---|---|---|
| **Number of tables** | 1 | 3 (Bookings, Booking_Approvals, Booking_Sessions) |
| **Total columns** | 17 | 8 + 8 + 9 = 25 (spread across 3 tables) |
| **Nullable columns when `status = 'pending'`** | 10 (approver_id, decision_time, decision_note, rejection_reason, actual_start_time, checked_in_by, initial_condition, actual_end_time, final_condition, usage_notes) | 0 (approval and session tables simply have no row yet) |
| **Can audit approval history?** | No — only the final decision is stored | Yes — each approval is a separate row, capturing who decided and when |
| **Can audit session history?** | No — only the final session is stored | Yes — each session is a separate row |
| **Query complexity for "active bookings"** | Simple (single table) | Simple (single table — Bookings) |
| **Query complexity for "approval decisions"** | Requires filtering where `approver_id IS NOT NULL` | Direct: `SELECT * FROM Booking_Approvals` |
| **Schema clarity** | Poor — a single row mixes request data, decision data, and session data | High — each table has a clear, single responsibility |
| **3NF compliance** | Partial — transitive dependency risk (approval data depends on decision, not on booking_id directly) | Full — each table's non-key attributes depend solely on its own PK |

**Client benefit summary:** The SRP split eliminates NULL sprawl, makes the booking lifecycle explicit and auditable, and improves schema clarity without sacrificing query performance (the 1:0..1 relationships require only simple JOINs).

---

## 5. Relationship Summary

| ID | Relationship | Cardinality | Participation | Why |
|---|---|---|---|---|---|
| R1 | Departments → Users | 1:N | Users total | Each user must belong to a department; a department may have zero or many users |
| R2 | Users → Bookings (requester) | 1:N | Bookings total | Each booking must have exactly one requester; a user may request many bookings |
| R3 | Users → Booking_Approvals (approver) | 1:N | Booking_Approvals total | Each approval must have exactly one approver; a user may approve/reject many bookings |
| R4 | Users → Booking_Sessions (checks_in) | 1:N | Booking_Sessions total | Each session must have exactly one staff who checked in; a staff may check in many sessions |
| R5 | Spaces → Bookings | 1:N | Bookings total | Each booking is for exactly one space; a space may be booked many times |
| R6 | Spaces ↔ Facilities | M:N | Both partial | A space may contain multiple physical devices; a device instance may be reassigned to different spaces over its lifecycle; resolved via Space_Facilities junction (instance-level) |
| R7 | Spaces → Maintenance | 1:N | Maintenance total | Each maintenance record is for exactly one space; a space may have many maintenance records |
| R8 | Users → Maintenance (reporter) | 1:N | Maintenance total | Each maintenance record has exactly one reporter; a user may report many issues |
| R9 | Users → Maintenance (assigned staff) | 1:N | Maintenance partial | A maintenance record may have zero or one assigned staff; a staff may be assigned many tickets |
| R10 | Bookings → Booking_Approvals | 1:0..1 | Booking_Approvals total | A booking may have zero or one approval decision; every approval belongs to exactly one booking |
| R11 | Bookings → Booking_Sessions | 1:0..1 | Booking_Sessions total | A booking may have zero or one check-in session; every session belongs to exactly one booking |
| R12 | Spaces → Incidents | 1:N | Incidents total | Each incident is for exactly one space; a space may have many incidents |
| R13 | Users → Incidents (reporter) | 1:N | Incidents total | Each incident has exactly one reporter; a user may report many incidents |
| R14 | Users → Incidents (assigned staff) | 1:N | Incidents partial | An incident may have zero or one assigned investigator; a staff may be assigned many incidents |
| R15 | Facility_Categories → Facilities | 1:N | Facilities total | Each facility device belongs to exactly one category; a category may contain many devices |
| R16 | Facilities → Maintenance | 1:N | Maintenance partial | A maintenance record may optionally target a specific device; a device may have many maintenance records |
| R17 | Facilities → Incidents | 1:N | Incidents partial | An incident may optionally involve a specific device; a device may be involved in many incidents |

---

## 6. Third Normal Form (3NF) Compliance

### 6.1 1NF — Atomic columns, no repeating groups

- **Every column in every table holds a single atomic value** — no delimited lists, no JSON/XML strings carrying multiple data points.
- **No repeating groups of columns.** The M:N relationship between Spaces and Facilities is resolved via the `Space_Facilities` junction table instead of columns like `facility_1`, `facility_2`, ... or a delimited string.
- **Every table has a primary key** — all PKs are declared and non-null.

### 6.2 2NF — No partial dependencies

2NF applies only to tables with composite primary keys. The only composite PK in the schema is `Space_Facilities(space_id, facility_id)`:
- The table has no non-key columns after the facility refactoring — `quantity` was removed. Every column is part of the key, so 2NF is trivially satisfied.
- All other tables have **single-column surrogate PKs**, making partial dependencies impossible by definition.

### 6.3 3NF — No transitive dependencies

Each non-key column depends **directly on the primary key**, not on another non-key column:

| Table | PK | Non-key columns | Depend directly on PK? |
|---|---|---|---|---|
| Departments | department_id | `name` | Yes — name is a property of the department |
| Users | user_id | `email`, `full_name`, `phone_number`, `role`, `department_id`, `account_status` | Yes — all are properties of the user. `department_id` is an FK (dependency on another entity's PK), not a transitive dependency |
| Spaces | space_id | `space_code`, `space_name`, `space_type`, `building`, `floor`, `room_number`, `capacity`, `current_status`, `usage_policy` | Yes — all are direct properties of the space |
| Facility_Categories | category_id | `category_name`, `prefix`, `created_at` | Yes — name and prefix are direct properties of the category |
| Facilities | facility_id | `category_id`, `status`, `created_at`, `updated_at` | Yes — all are direct properties of the device instance. `category_id` is an FK, not a transitive dependency |
| Space_Facilities | (space_id, facility_id) | (none — `quantity` removed) | N/A — key-only table; no non-key columns |
| Bookings | booking_id | `space_id`, `requester_id`, `requested_start_time`, `requested_end_time`, `purpose`, `expected_participants`, `status`, `is_deleted` | Yes — all are direct properties of a booking request |
| Booking_Approvals | approval_id | `booking_id`, `approver_id`, `decision_time`, `decision`, `rejection_reason`, `decision_note` | Yes — all are direct properties of the approval decision |
| Booking_Sessions | session_id | `booking_id`, `actual_start_time`, `checked_in_by`, `initial_condition`, `actual_end_time`, `final_condition`, `usage_notes` | Yes — all are direct properties of the check-in session |
| Maintenance | maintenance_id | `space_id`, `reporter_id`, `assigned_staff_id`, `facility_id`, `problem_description`, `start_time`, `completion_time`, `status`, `result_note`, `is_deleted` | Yes — all are direct properties of the maintenance ticket |
| Incidents | incident_id | `space_id`, `facility_id`, `reporter_id`, `assigned_to`, `description`, `status`, `created_at`, `resolved_at`, `resolution_note` | Yes — all are direct properties of the incident report |

**No transitive dependencies detected.** Specifically:
- Status values (`'pending'`, `'approved'`, etc.) are stored as CHECK-constrained VARCHAR literals, not as codes in a separate table that would introduce a transitive dependency.
- `department_id` in Users is an FK, not a transitive dependency — it references the PK of Departments. The department name is not stored in Users.
- `space_id` in Bookings is an FK, not a transitive dependency — all space properties are accessed via the FK join.

**Conclusion:** The schema is fully in 3NF.

### 6.4 Design decisions that preserve 3NF

| Decision | How it preserves normalization |
|---|---|
| **Junction table Space_Facilities** for M:N | Eliminates repeating groups (violation of 1NF) |
| **SRP split of Bookings** | Eliminates nullable columns that would suggest a hidden entity (violation of 3NF — approval data does not depend on booking_id alone) |
| **VARCHAR with CHECK for statuses** (instead of lookup tables) | Literal values avoid transitive dependency through a codes table; still atomic, so 1NF is satisfied |
| **Free-text building/floor** (instead of separate tables) | Still 3NF — building and floor are direct properties of a space, not transitively dependent on any other non-key column |

---

## 7. Logical Constraints and Enforcement

The ERD defines several constraints that go beyond what Mermaid ERD notation can express. These are enforced at the database level via triggers, indexes, and CHECK constraints:

| Constraint | Entity | Mechanism | Business Rule |
|---|---|---|---|---|
| Booking overlap prevention | Bookings | Filtered unique index (exact start-time collisions) + `trg_bookings_prevent_overlap` (interval overlaps) | BR1 |
| Space availability at approval time | Booking_Approvals | `trg_booking_approvals_check_space` — rejects approval when space is `under_maintenance`/`temporarily_closed`/`retired` | BR2 |
| Expected participants ≤ capacity | Bookings | CHECK constraint or application-level check | BR3 |
| Decision recording | Booking_Approvals | NOT NULL on `approver_id`, `decision_time`, `decision` | BR6 |
| Rejection reason required | Booking_Approvals | `trg_bookings_rejection_reason` — enforces `rejection_reason IS NOT NULL` when `decision = 'rejected'` | BR7 |
| Approver must be facility_staff/manager | Booking_Approvals | `trg_booking_approvals_check_role` | BR15 |
| Check-in staff must be facility_staff/manager | Booking_Sessions | `trg_booking_sessions_check_role` | BR16 |
| Assigned maintenance staff must be facility_staff | Maintenance | `trg_maintenances_check_assignee_role` | BR17 |
| Check-in requires approved status | Booking_Sessions | `trg_booking_sessions_checkin` — rejects check-in for non-approved bookings | BR8 |
| Completion updates booking + space status | Booking_Sessions | `trg_booking_sessions_completion` — sets `bookings.status = 'completed'`, `spaces.current_status = 'available'` | BR8, BR9 |
| Maintenance completion frees space | Maintenance | `trg_maintenances_completion_space_status` — sets `spaces.current_status = 'available'` only if no other active tickets exist | Q3 |
| Decision sync (approval → booking status) | Booking_Approvals | `trg_booking_approvals_decision` — auto-updates `bookings.status` to `'approved'`/`'rejected'` | BR6 |
| Soft delete | Bookings, Maintenance | `is_deleted BIT DEFAULT 0` — records are logically deleted, preserving history | BR11 |
| Updated_at auto-stamp | All 11 tables | AFTER UPDATE trigger on each table updates `updated_at = GETDATE()` | BR12 |
| Category name uniqueness | Facility_Categories | `UQ_facility_categories_name` — UNIQUE on `category_name` | BR10 |
| Category prefix uniqueness | Facility_Categories | `UQ_facility_categories_prefix` — UNIQUE on `prefix` | BR10 |
| Facility status allowed values | Facilities | `CK_facilities_status` — CHECK IN (`'active'`, `'inactive'`, `'retired'`, `'lost'`) | — |
| Incident auto-resolution on maintenance complete | Incidents | `trg_incidents_autoresolve` — resolves incidents linked to the same facility or space when the related maintenance ticket is completed | BR21 |

---

## 8. Conclusion

The ERD design for the Campus Space Management System delivers on every business goal stated in the requirements:

| Business Goal | How the ERD achieves it |
|---|---|
| **Fair scheduling** | The SRP-split Booking pipeline (request → approval → session) ensures every booking goes through a transparent, auditable workflow |
| **No overlapping bookings** | Dual-layer protection — filtered unique index for exact collisions + trigger for interval overlaps (BR1) |
| **Unavailable spaces cannot be booked** | Space status check is enforced at approval time by trigger (BR2), and maintenance completion auto-updates space status (Q3) |
| **Usage history preserved** | Soft delete (`is_deleted`) on Bookings and Maintenance ensures historical records are never lost (BR11) |
| **Audit-ready** | Booking_Approvals and Booking_Sessions provide explicit, separate records of who decided what and when |
| **3NF normalized** | 11 entities, 17 relationships — no data redundancy, no update anomalies, no insertion anomalies |
| **Device-level asset tracking** | Facility_Categories + instance-level Facilities + device-specific Maintenance/Incidents enable tracking individual equipment lifecycle and incidents |

The key architectural decisions — SRP split of bookings, M:N resolution via Space_Facilities, facility refactoring (run_01 amendment), database-level enforcement via triggers, and the hybrid surrogate+business key strategy — come together to form a design that is **correct, maintainable, and aligned with the School's needs**.

---

*Generated for CS486 Group G05 — Campus Space Management System*
