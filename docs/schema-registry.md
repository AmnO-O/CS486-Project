# Schema Registry — CS486 Database Schema (3NF)

Single source of truth for the **relational schema** (the *technical* view): tables,
columns, PK/FK wiring, indexes, the 3NF proof, and business-rule coverage. Locked
after Task 4 (Design Validation) reaches SCHEMA FREEZE.

For conceptual entity/attribute definitions see `docs/entity-registry.md`; for the
reasoning behind choices see `docs/design-decisions.md`.

> Boundary: this file does **not** repeat business/role prose or candidate-key
> analysis — those live in `entity-registry.md`.

## How to use this document

Per-task responsibilities (who populates/locks this file, and when) are defined once
in the **Registry maintenance protocol** of
`.opencode/skills/db-design-pipeline/SKILL.md`. Follow that; do not restate it here.

---

## Schema status

| Status | Last updated | Locked by |
|---|---|---|---|
| Populated from outputs/03 | 2026-06-15 | Not yet frozen (Task 04 pending) |

---

## Format spec — canonical table block

Each table MUST follow this relational-notation style:

```
<table_name>
  <column> <TYPE> <PK | FK → other_table | UNIQUE | NULL | DEFAULT ...> [CHECK(...)]
  ...
  PRIMARY KEY (...)            ← only when composite
```

---

## Table definitions (relational notation)

_(Populate from `outputs/03-logical-design-G05.md` after Task 3 is marked ✅.
The block below is an EXAMPLE — delete it once real tables are filled in.)_

```
departments
  department_id INT PRIMARY KEY IDENTITY(1,1)
  name NVARCHAR(255) NOT NULL UNIQUE
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()

users
  user_id INT PRIMARY KEY IDENTITY(1,1)
  email NVARCHAR(255) NOT NULL UNIQUE
  full_name NVARCHAR(255) NOT NULL
  phone_number NVARCHAR(50) NULL
  role VARCHAR(50) NOT NULL CHECK(role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager'))
  department_id INT NOT NULL FK → departments
  account_status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK(account_status IN ('active','inactive','suspended'))
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()

spaces
  space_id INT PRIMARY KEY IDENTITY(1,1)
  space_code NVARCHAR(50) NOT NULL UNIQUE
  space_name NVARCHAR(255) NOT NULL
  space_type VARCHAR(50) NOT NULL CHECK(space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace'))
  building NVARCHAR(100) NOT NULL
  floor NVARCHAR(50) NOT NULL
  room_number NVARCHAR(50) NOT NULL
  capacity INT NOT NULL CHECK(capacity > 0)
  current_status VARCHAR(50) NOT NULL DEFAULT 'available' CHECK(current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired'))
  usage_policy NVARCHAR(MAX) NULL
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()

facilities
  facility_id INT PRIMARY KEY IDENTITY(1,1)
  name NVARCHAR(255) NOT NULL UNIQUE
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()

space_facilities
  space_id INT NOT NULL FK → spaces
  facility_id INT NOT NULL FK → facilities
  quantity INT NULL
  PRIMARY KEY (space_id, facility_id)

bookings
  booking_id INT PRIMARY KEY IDENTITY(1,1)
  space_id INT NOT NULL FK → spaces
  requester_id INT NOT NULL FK → users
  requested_start_time DATETIME2 NOT NULL
  requested_end_time DATETIME2 NOT NULL CHECK(requested_end_time > requested_start_time)
  purpose VARCHAR(50) NOT NULL CHECK(purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event'))
  expected_participants INT NOT NULL CHECK(expected_participants > 0)
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show'))
  approver_id INT NULL FK → users
  decision_time DATETIME2 NULL
  decision_note NVARCHAR(MAX) NULL
  rejection_reason NVARCHAR(MAX) NULL
  actual_start_time DATETIME2 NULL
  checked_in_by INT NULL FK → users
  initial_condition NVARCHAR(MAX) NULL
  actual_end_time DATETIME2 NULL
  final_condition NVARCHAR(MAX) NULL
  usage_notes NVARCHAR(MAX) NULL
  is_deleted BIT NOT NULL DEFAULT 0
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()

maintenance
  maintenance_id INT PRIMARY KEY IDENTITY(1,1)
  space_id INT NOT NULL FK → spaces
  reporter_id INT NOT NULL FK → users
  assigned_staff_id INT NULL FK → users
  problem_description NVARCHAR(MAX) NOT NULL
  start_time DATETIME2 NOT NULL
  completion_time DATETIME2 NULL
  status VARCHAR(50) NOT NULL DEFAULT 'open' CHECK(status IN ('open','in_progress','resolved'))
  result_note NVARCHAR(MAX) NULL
  is_deleted BIT NOT NULL DEFAULT 0
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()
```

---

## Indexes

_(Add during Task 3/5 only if a query or constraint warrants them. One row per index;
state the table, columns, and why.)_

| Index | Table (columns) | Rationale |
|---|---|---|---|
| idx_users_department_id | users(department_id) | FK join performance |
| idx_users_email | users(email) | Business key lookup (UNIQUE) |
| idx_spaces_space_code | spaces(space_code) | Business key lookup (UNIQUE) |
| idx_spaces_current_status | spaces(current_status) | Filter by availability / maintenance |
| idx_bookings_space_id | bookings(space_id) | FK join / overlap detection |
| idx_bookings_requester_id | bookings(requester_id) | FK join / user history |
| idx_bookings_approver_id | bookings(approver_id) | FK join |
| idx_bookings_checked_in_by | bookings(checked_in_by) | FK join |
| idx_bookings_status | bookings(status) | Filter by lifecycle status |
| idx_bookings_time_range | bookings(space_id, requested_start_time, requested_end_time) | Overlap detection query (BR1) |
| idx_bookings_requested_start | bookings(requested_start_time) | Scheduling queries |
| idx_maintenance_space_id | maintenance(space_id) | FK join |
| idx_maintenance_reporter_id | maintenance(reporter_id) | FK join |
| idx_maintenance_assigned_staff_id | maintenance(assigned_staff_id) | FK join |
| idx_maintenance_status | maintenance(status) | Filter by lifecycle |
| uq_bookings_active_overlap | bookings(space_id, requested_start_time) [WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0] | Prevent exact same-start collisions for confirmed bookings (BR1) |

---

## 3NF normalization proof

_(Fill in during Task 3 — one row per table.)_

| Table | 1NF | 2NF | 3NF | Notes |
|---|---|---|---|---|---|
| departments | ✓ | ✓ | ✓ | Single-col PK, atomic columns, no transitive deps |
| users | ✓ | ✓ | ✓ | Single-col PK, atomic columns, no transitive deps |
| spaces | ✓ | ✓ | ✓ | Single-col PK, atomic columns, no transitive deps |
| facilities | ✓ | ✓ | ✓ | Single-col PK, atomic columns, no transitive deps |
| space_facilities | ✓ | ✓ | ✓ | Composite PK, quantity depends on full key |
| bookings | ✓ | ✓ | ✓ | Single-col PK, atomic columns, no transitive deps |
| maintenance | ✓ | ✓ | ✓ | Single-col PK, atomic columns, no transitive deps |

---

## Business rule coverage

_(Fill in during Task 4 — map each business rule from `outputs/01` to what enforces it.)_

| Business Rule | Enforced by (table/column/constraint) | Status |
|---|---|---|
| _(populate in Task 4)_ | — | ✓ Pass / ❌ Fail |

---

## Revision log

| Date | Change | By | Task |
|---|---|---|---|---|
| 2026-06-15 | Populated 7 table definitions, indexes, and 3NF proof from outputs/03 | Copilot | Task 03 |
| — | Schema template created | Planning | — |

---

## ⚠️ LOCK GATE

**This schema is locked once:**
1. Task 4 (Design Validation) is marked ✅ in `memory/Progress.md`
2. All 4 group members have approved the schema

**Once locked, changes require group consensus and a documented `design-decisions.md` entry.**
