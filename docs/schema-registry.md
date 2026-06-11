# Schema Registry — CS486 Database Schema (3NF)

This document maintains the normalized relational schema that is locked after Task 4 (Design Validation) reaches SCHEMA FREEZE.

## How to use this document

- **During Tasks 1–3:** This section is drafted but not finalized
- **During Task 4 (Design Validation):** Validate this schema against all business rules
- **After Task 4 ✅ (SCHEMA FREEZE):** This becomes **LOCKED** and is the source of truth for Tasks 5, 6, 7 (DDL, sample data, queries)

---

## Schema status

| Status | Last updated | Locked by |
|---|---|---|
| Template (in progress) | [TO BE UPDATED] | Not yet frozen |

---

## Table definitions (relational notation)

_(To be populated during Tasks 1–3. Fill in from `outputs/03-logical-design-G05.md` after Task 3 is marked ✅.)_

### Expected tables (from requirement analysis)

Typical tables for this domain:

```
users
  user_id INT PRIMARY KEY
  email NVARCHAR(255) UNIQUE
  name NVARCHAR(255)
  role VARCHAR(50) CHECK(...)
  department_id INT FK → departments
  is_active BIT
  created_at DATETIME2 DEFAULT GETDATE()
  updated_at DATETIME2 DEFAULT GETDATE()

departments
  department_id INT PRIMARY KEY
  code NVARCHAR(50) UNIQUE
  name NVARCHAR(255)
  created_at DATETIME2 DEFAULT GETDATE()

spaces
  space_id INT PRIMARY KEY
  room_code NVARCHAR(50) UNIQUE
  name NVARCHAR(255)
  type VARCHAR(50) CHECK(...)
  capacity INT
  status VARCHAR(50) CHECK(...)
  created_at DATETIME2 DEFAULT GETDATE()
  updated_at DATETIME2 DEFAULT GETDATE()

booking_requests
  booking_id INT PRIMARY KEY
  space_id INT FK → spaces
  requester_id INT FK → users
  approver_id INT FK → users (nullable)
  requested_start_time DATETIME2
  requested_end_time DATETIME2
  actual_start_time DATETIME2 (nullable)
  actual_end_time DATETIME2 (nullable)
  status VARCHAR(50) CHECK(...)
  purpose VARCHAR(50) CHECK(...)
  notes NVARCHAR(MAX) (nullable)
  is_deleted BIT DEFAULT 0
  created_at DATETIME2 DEFAULT GETDATE()
  updated_at DATETIME2 DEFAULT GETDATE()

facilities
  facility_id INT PRIMARY KEY
  name NVARCHAR(255)
  created_at DATETIME2 DEFAULT GETDATE()

space_facilities
  space_id INT FK → spaces
  facility_id INT FK → facilities
  PRIMARY KEY (space_id, facility_id)

maintenance_records
  maintenance_id INT PRIMARY KEY
  space_id INT FK → spaces
  reported_by_id INT FK → users
  status VARCHAR(50) CHECK(...)
  description NVARCHAR(MAX)
  resolved_at DATETIME2 (nullable)
  is_deleted BIT DEFAULT 0
  created_at DATETIME2 DEFAULT GETDATE()
  updated_at DATETIME2 DEFAULT GETDATE()
```

---

## Indexes

_(To be added during Task 5 (DDL) if performance analysis warrants them.)_

Candidate indexes for query optimization:

```
idx_bookings_space_id ON booking_requests(space_id)
idx_bookings_requester_id ON booking_requests(requester_id)
idx_bookings_requested_time ON booking_requests(requested_start_time, requested_end_time)
idx_bookings_status ON booking_requests(status)
idx_maintenance_space_id ON maintenance_records(space_id)
idx_maintenance_status ON maintenance_records(status)
```

---

## 3NF normalization proof

_(To be filled in during Task 3.)_

| Table | 1NF | 2NF | 3NF | Notes |
|---|---|---|---|---|
| users | ✓ | ✓ | ✓ | (To be verified) |
| departments | ✓ | ✓ | ✓ | (To be verified) |
| spaces | ✓ | ✓ | ✓ | (To be verified) |
| booking_requests | ✓ | ✓ | ✓ | (To be verified) |
| facilities | ✓ | ✓ | ✓ | (To be verified) |
| space_facilities | ✓ | ✓ | ✓ | Junction table, by definition in 3NF |
| maintenance_records | ✓ | ✓ | ✓ | (To be verified) |

---

## Business rule coverage (from Task 4 validation)

_(To be filled in during Task 4 Design Validation._

| Business Rule | Enforced by | Status |
|---|---|---|
| (To be populated from requirement) | (Table/column/constraint) | ✓ Pass / ❌ Fail |

---

## Known constraints and assumptions

_(To be documented during Tasks 1–4.)_

1. (Example) Soft deletes on `booking_requests` and `maintenance_records` for audit trail
2. (Example) No cascade delete — referential integrity enforced via FK constraints
3. (To be documented from tasks)

---

## Revision log

| Date | Change | By | Task |
|---|---|---|---|
| — | Schema template created | Copilot | Planning |

---

## ⚠️ LOCK GATE

**This schema is locked once:**
1. Task 4 (Design Validation) is marked ✅ in `memory/Progress.md`
2. All 4 group members have approved the schema

**Once locked, changes require group consensus and documented approval.**

---

_For detailed entity and attribute definitions, see `docs/entity-registry.md`._
_For design rationale, see `docs/design-decisions.md`._
