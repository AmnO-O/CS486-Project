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
|---|---|---|
| Template (in progress) | [TO BE UPDATED] | Not yet frozen |

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

> ⚠️ **EXAMPLE — DELETE WHEN POPULATING.** Illustrates the canonical table block.
> Not a confirmed design decision.

```
users  (example)
  user_id INT PRIMARY KEY IDENTITY(1,1)
  email NVARCHAR(255) UNIQUE NOT NULL
  name NVARCHAR(255) NOT NULL
  role VARCHAR(50) NOT NULL CHECK(role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager'))
  department_id INT NOT NULL FK → departments
  is_active BIT NOT NULL
  created_at DATETIME2 NOT NULL DEFAULT GETDATE()
  updated_at DATETIME2 NOT NULL DEFAULT GETDATE()
```

---

## Indexes

_(Add during Task 3/5 only if a query or constraint warrants them. One row per index;
state the table, columns, and why.)_

| Index | Table (columns) | Rationale |
|---|---|---|
| _(populate later)_ | — | — |

---

## 3NF normalization proof

_(Fill in during Task 3 — one row per table.)_

| Table | 1NF | 2NF | 3NF | Notes |
|---|---|---|---|---|
| _(populate in Task 3)_ | — | — | — | — |

---

## Business rule coverage

_(Fill in during Task 4 — map each business rule from `outputs/01` to what enforces it.)_

| Business Rule | Enforced by (table/column/constraint) | Status |
|---|---|---|
| _(populate in Task 4)_ | — | ✓ Pass / ❌ Fail |

---

## Revision log

| Date | Change | By | Task |
|---|---|---|---|
| — | Schema template created | Planning | — |

---

## ⚠️ LOCK GATE

**This schema is locked once:**
1. Task 4 (Design Validation) is marked ✅ in `memory/Progress.md`
2. All 4 group members have approved the schema

**Once locked, changes require group consensus and a documented `design-decisions.md` entry.**
