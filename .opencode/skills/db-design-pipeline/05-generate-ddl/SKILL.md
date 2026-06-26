---
name: 05-generate-ddl
description: >
  Generate SQL DDL for Task 05 by converting the locked logical schema into
  SQL Server tables, keys, constraints, indexes, and triggers.
  Triggers when user runs /generate-ddl or asks to implement the database,
  generate DDL, create tables, or produce the SQL definition script for the
  Campus Space Management System.
---

# Task 05 — DDL Generation Skill

## Goal

Convert the locked logical schema into a SQL Server DDL script that is:

- syntactically valid
- constraint-complete
- aligned with the approved schema registry
- safe for historical data preservation

---

## Required inputs

Read in this order before generating:
1. `AGENTS.md` — to load global pipeline constraints, rules.
2. `memory/Progress.md` — verify Task 04 is marked complete; stop and report if not
3. `memory/ActiveContext.md` — check for blockers; stop and report if any
4. `.env` — extract `SA_PASSWORD` (SQL Auth only; skip when using Windows Auth `-E`)
5. `docs/schema-registry.md` — primary source of truth; must be fully locked
6. `outputs/04-design-validation-G05.md` — fallback for clarification
7. `outputs/03-logical-design-G05.md` — fallback for clarification
8. `outputs/02-erd-design-G05.md` — fallback for clarification
9. `outputs/01-business-req-analysis-G05.md` — fallback for clarification
10. `req/business-requirement.md` — fallback for clarification only

If schema registry is not fully locked → **stop and report**. Do not generate DDL against an incomplete schema.

---

## Schema compliance audit

Run this audit **after reading all sources and before writing any SQL**.

For every table in `docs/schema-registry.md`, verify:

| Check | Pass if |
|-------|---------|
| Table exists in logical design | Present in `outputs/03` |
| All columns present | Name, type, nullability match schema registry exactly |
| PK matches | Column(s) and IDENTITY setting match |
| All FKs present | References, ON DELETE, ON UPDATE match |
| All CHECK constraints present | Enum values match `docs/tech-stack.md` |
| All UNIQUE constraints present | Columns match |
| All DEFAULT values present | Expressions match |

For every business rule in the Business Rule Coverage section of `docs/schema-registry.md`, verify:

| Check | Pass if |
|-------|---------|
| Enforcement mechanism identified | Trigger, constraint, or FK named |
| Mechanism exists in planned output | Confirmed before writing |
| Implementation matches approved design | No deviation from schema registry |

**If any mismatch exists → STOP.**

Do not generate DDL until the mismatch is resolved. Document the resolution in `docs/design-decisions.md` before continuing.

---

## Source of truth order

When any conflict exists between sources, resolve using this priority:

1. `docs/schema-registry.md`
2. `outputs/04-design-validation-G05.md`
3. `outputs/03-logical-design-G05.md`
4. `outputs/02-erd-design-G05.md`
5. `outputs/01-business-req-analysis-G05.md`
6. `req/business-requirement.md`

Do not override the schema registry with lower-priority sources.

---

## Schema freeze rules

**If a constraint, FK behavior, column, index, or trigger is explicitly defined in `docs/schema-registry.md`, implement it exactly.**

If the schema registry is silent, additional constraints are allowed only when they:
- do not alter cardinality or FK delete/update behavior
- do not introduce new entities
- do not contradict any approved business rule

Allowed additions (silent schema only):
- `CHECK` constraints
- `DEFAULT` constraints

Not allowed without explicit schema registry approval:
- new `UNIQUE` constraints
- new indexes
- new foreign keys
- new triggers
- stored procedures, functions, computed columns, automation logic

All silent additions must be documented inline:
```sql
-- Additional integrity safeguard (not part of locked schema)
```

---

## Core DDL rules

### 1. Table mapping
- Each strong entity → one table.
- Each M:N relationship → one junction table.
- Do not create tables not present in the locked schema.

### 2. Primary keys
- Every table must have a primary key matching `docs/schema-registry.md`.
- Preserve surrogate keys; do not invent alternates.

### 3. Foreign keys
- Every FK must reference an approved parent table.
- Nullability must match participation constraints from Task 02.
- Do not use `CASCADE` unless the schema registry explicitly authorizes it.
- Prefer `NO ACTION` for historical records.
- **Multiple cascade path rule:** SQL Server rejects two FKs from the same child table to the same parent with `SET NULL` or `CASCADE`. If this occurs, keep one as `SET NULL` and change the rest to `NO ACTION`. Document in `docs/design-decisions.md`.

### 4. Unique constraints
- Every candidate key marked in the schema registry must become `UNIQUE`.

### 5. CHECK constraints
Apply to: status columns, type columns, capacity ranges, date/time ordering.
Keep enum lists consistent with `docs/tech-stack.md`.

### 6. DEFAULT values
- `created_at` → `GETDATE()`
- `is_deleted` → `0`
- Initial status columns per schema registry defaults.

### 7. NULLability
- Mandatory attributes → `NOT NULL`.
- Optional attributes → nullable.
- Follow Task 02 participation constraints and Task 03/04 column specs.

### 8. Historical data preservation
- Do not destroy booking or maintenance history.
- Soft delete (`is_deleted`) must be applied consistently where the schema registry requires it.
- Prefer `NO ACTION` on FK delete behavior unless the schema registry explicitly authorizes `CASCADE` or `SET NULL`.

### 9. Triggers

**Scope rule:** Only generate triggers explicitly required by the Business Rule Coverage section of `docs/schema-registry.md`. Do not invent additional triggers.

**Mandatory batch pattern:**
```sql
GO
CREATE TRIGGER trg_name
ON table_name
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- enforcement logic
END
GO
```

- Every `CREATE TRIGGER` must be the first statement in its batch — always precede with `GO`.
- Derive trigger logic from `outputs/03-logical-design-G05.md §7`.
- Use `outputs/03-logical-design-G05.md §8` (Resolved ambiguities) for clarification on time-based or conditional rules — do not infer; read from source.
- If a rule is deferred to the application layer, document it in a SQL comment.

### 10. SQL Server style
- Target: **T-SQL, SQL Server 2019+**.
- **First two lines must be:**
  ```sql
  SET QUOTED_IDENTIFIER ON
  GO
  ```
  Required for filtered indexes — omitting causes `Msg 1934`.
- Use deterministic constraint names (see naming convention below).
- No bracketed identifiers unless required by `docs/tech-stack.md`.
- Clean `CREATE TABLE` statements only — no idempotent wrappers unless specified.

---

## Recommended table creation order

1. Parent / master tables
2. Lookup / reference tables
3. Core transaction tables
4. Junction tables
5. Dependent tables

Define parent tables before child tables to avoid FK reference errors.

---

## Constraint naming convention

Matches `docs/tech-stack.md`:

| Type | Pattern | Example |
|------|---------|---------|
| Primary key | `PK_<table>` | `PK_bookings` |
| Foreign key | `FK_<child>_<col>` | `FK_bookings_space_id` |
| Unique | `UQ_<table>_<col>` | `UQ_users_email` |
| Check | `CK_<table>_<rule>` | `CK_bookings_status` |
| Trigger | `trg_<table>_<action>` | `trg_bookings_prevent_overlap` |

Use **single underscore** separators. Double underscore (`PK__table`) resembles SQL Server auto-generated names — avoid it.

---

## Compile and verify

Choose one authentication mode and use it consistently:

| Mode | When | Syntax |
|------|------|--------|
| Windows Auth | Local/solo | `-E` |
| SQL Auth | Team server | `-U sa -P "$SA_PASSWORD"` |

Replace `<AUTH>` with either option below.

**a. Create database:**
```bash
sqlcmd -S localhost -C <AUTH> \
  -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CS486_G05') \
      CREATE DATABASE CS486_G05;"
```

**b. Run DDL:**
```bash
sqlcmd -S localhost -C <AUTH> \
  -d CS486_G05 \
  -i outputs/05-db-definition-G05.sql
```

**c. Verify objects created:**
```bash
sqlcmd -S localhost -C <AUTH> -d CS486_G05 -Q "
SELECT 'Tables'   AS type, COUNT(*) AS count FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'Triggers',          COUNT(*) FROM sys.triggers        WHERE parent_class = 1
UNION ALL
SELECT 'FKs',               COUNT(*) FROM sys.foreign_keys
UNION ALL
SELECT 'CHECKs',            COUNT(*) FROM sys.check_constraints;"
```

**d. On error — drop and retry from step (a):**
```bash
sqlcmd -S localhost -C <AUTH> \
  -Q "DROP DATABASE IF EXISTS CS486_G05;"
```

> **Rule:** Do NOT edit `docs/schema-registry.md` to match the code. Fix the SQL — the registry wins.

---

## Validation checklist

Run **after generating the SQL file** to verify output correctness:

**Tables and columns**
- [ ] All required tables exist; no extra tables introduced
- [ ] All columns exist with correct types and nullability

**Constraints**
- [ ] All PKs, FKs, UNIQUEs, CHECKs, DEFAULTs match schema registry
- [ ] FK cascade paths checked — no multiple cascade path violations

**Triggers**
- [ ] All triggers match Business Rule Coverage in `docs/schema-registry.md`
- [ ] Every trigger preceded by `GO`

**Script integrity**
- [ ] `SET QUOTED_IDENTIFIER ON` + `GO` is first block
- [ ] No prose mixed into SQL output
- [ ] No schema rules missed

---

## After generation

1. Compile and verify on local SQL Server (steps above)
2. Append verification output to `logs/eval/task05/YYYY-MM-DD-HHmm-05-ddl-compile.log`
3. Write trajectory file per `.opencode/skills/evaluations/trajectory-recording.md`
4. Update `memory/Progress.md` and `memory/ActiveContext.md`
5. If any key design decision was made → append to `docs/design-decisions.md`

---

## Common mistakes to avoid

- Skipping `docs/schema-registry.md` and generating from raw requirements
- Mixing prose with DDL output
- Inventing entities not in the schema registry
- Forgetting junction tables for M:N relationships
- Adding `CASCADE` deletes that erase historical records
- Omitting `GO` before `CREATE TRIGGER` — causes batch-level compile errors
- Forgetting `SET QUOTED_IDENTIFIER ON` — causes `Msg 1934`
- Using double underscore in constraint names
- Writing trigger logic from memory — always derive from `outputs/03-logical-design-G05.md §7`
- Omitting the recursion guard (`IF NOT UPDATE`) in triggers that automatically update timestamp or audit columns which causes potential infinite trigger recursion.

---

## Output standard

The final SQL file must be ready to run after review. No explanatory prose mixed into the script unless the project template explicitly requires inline comments.