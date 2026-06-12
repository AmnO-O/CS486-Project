# Entity Registry — CS486 Space Booking System

Single source of truth for every **entity and attribute** (the *conceptual* view).
For relational tables, FK wiring, indexes and the 3NF proof see
`docs/schema-registry.md`; for the reasoning behind choices see `docs/design-decisions.md`.

> Boundary: this file does **not** contain indexes, FK graphs, 3NF proofs, or
> business-rule coverage — those live in `schema-registry.md`.

## How to use this document

Per-task responsibilities (who populates/refines/locks this file, and when) are
defined once in the **Registry maintenance protocol** of
`.opencode/skills/db-design-pipeline/SKILL.md`. Follow that; do not restate it here.

---

## Format spec — canonical entity block

Every entity MUST follow this exact structure so the registry stays uniform:

```markdown
### <EntityName>

**Description:** <one sentence — the real-world thing this represents>
**Maps to table:** `<table_name>`            ← links to schema-registry.md
**Source:** outputs/0X §<section>             ← traceability

**Candidate keys:**
- `<surrogate_key>` (surrogate, PK)
- `<business_key>` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| <name> | <SQL type> | NO/YES | PK/FK/UQ/— | `CHECK IN (...)` or `FK → table` | <note> |
```

Column rules:
- **Type** — final SQL Server type by end of Task 03 (`INT`, `NVARCHAR(255)`, `DATETIME2`, `BIT`, …).
- **Nullable** — `NO` or `YES` only.
- **Key** — one of `PK`, `FK`, `UQ`, or `—`.
- **Constraint / Enum** — full enum list for CHECK columns, or `FK → <table>.<col>` for foreign keys.
- **Notes** — defaults (`DEFAULT GETDATE()`) or anything non-obvious.

Discovery-status legend: ⬜ draft · 🔄 refining · 🔒 locked (post-Task 03).

---

## Entity discovery status

_(Add one row per entity during Task 01–02.)_

| Entity | Maps to table | Task discovered | Status | Last updated |
|---|---|---|---|---|
| _(populate in Task 1)_ | — | — | ⬜ | — |

---

## Relationships registry

_(Populate from `outputs/01` §Relationships; confirm cardinalities in Task 2.)_

| # | From → To | Cardinality | Participation | Source |
|---|---|---|---|---|
| _(populate in Task 1)_ | — | — | — | — |

---

## Core entities

_(Populate from `outputs/01-business-req-analysis-G05.md`. Each block MUST follow the
Format spec above. The single block below is an EXAMPLE — delete it once real
entities are filled in.)_

> ⚠️ **EXAMPLE — DELETE WHEN POPULATING.** Shows the canonical block filled in.
> It is illustrative only and is **not** a confirmed design decision.

### Users *(example)*

**Description:** University accounts with an assigned role and department.
**Maps to table:** `users`
**Source:** outputs/01 §Entities

**Candidate keys:**
- `user_id` (surrogate, PK)
- `email` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| user_id | INT | NO | PK | — | IDENTITY(1,1) |
| email | NVARCHAR(255) | NO | UQ | UNIQUE | Business key |
| name | NVARCHAR(255) | NO | — | — | Full name |
| role | VARCHAR(50) | NO | — | `CHECK IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')` | |
| department_id | INT | NO | FK | `FK → departments.department_id` | |
| is_active | BIT | NO | — | — | Account status |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() |

---

## Revision log

| Date | Change | Reason |
|---|---|---|
| — | Created registry template | Structural planning |