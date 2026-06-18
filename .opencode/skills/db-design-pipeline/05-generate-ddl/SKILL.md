---
name: 05-generate-ddl
description: Generate SQL DDL for Task 05 by converting the locked logical schema into SQL Server tables, keys, and constraints.
---

# Task 05 — DDL Generation Skill

## Goal
Convert the locked logical schema into a SQL Server DDL script that is:

- syntactically valid
- normalized
- constraint-complete
- aligned with the approved schema registry
- safe for historical data preservation


Primary source:
- `docs/schema-registry.md`

Fallback sources only if clarification is needed:
- `outputs/04-design-validation-G05.md`
- `outputs/03-logical-design-G05.md`
- `outputs/02-erd-design-G05.md`
- `outputs/01-business-req-analysis-G05.md`
- `req/business-requirement.md`


## Core DDL rules

### 1) Table mapping
- Each strong entity becomes one table.
- Each M:N relationship becomes a junction table.
- Each multivalued attribute becomes a separate table if the schema registry requires it.
- Do not create tables that are not present in the locked schema.

### 2) Primary keys
- Every table must have a primary key.
- Use the key defined in `docs/schema-registry.md`.
- If the schema uses surrogate keys, preserve them.
- Do not invent alternate primary keys unless the schema registry explicitly allows it.

### 3) Foreign keys
- Every foreign key must reference an approved parent table.
- Foreign key nullability must match the cardinality and participation constraint.
- Do not use cascading deletes unless the schema registry explicitly allows it.
- For historical records, prefer preserving rows over destructive cascades.

### 4) Candidate keys / unique constraints
- Any candidate key identified in Task 03 or locked in the schema registry must become `UNIQUE`.
- Business identifiers such as email or space code must be protected if the schema registry marks them as unique.

### 5) CHECK constraints
- Use `CHECK` for enumerated values, simple domain restrictions, and bounded numeric rules.
- Use `CHECK` for:
  - status columns
  - type columns
  - capacity ranges
  - date/time ordering when it can be enforced locally
- Keep checks readable and consistent.

### 6) DEFAULT values
Use defaults where appropriate for:
- `created_at`
- `updated_at` if the project convention requires it
- flags such as `is_deleted`
- initial status columns when the schema registry defines a default state

### 7) NULLability
- Mandatory attributes must be `NOT NULL`.
- Optional attributes may be nullable.
- Follow participation constraints from Task 02 and column-level requirements from Task 03/04.

### 8) Historical data preservation
- Do not destroy historical booking or maintenance records.
- Avoid schema choices that would erase audit trails.
- If soft delete is part of the locked schema, keep it consistent across relevant tables.


### 9) Procedural constraints / triggers
- Use triggers for rules that cannot be enforced declaratively.
- **Each `CREATE TRIGGER` must be the first statement in its batch — always precede with `GO`.**
- Structure:
  ```sql
    GO
    CREATE TRIGGER trg_name ON table_name ...
  ```
- If a rule is intentionally left to the application layer, document in SQL comments.

  > Source: `outputs/03-logical-design-G05.md §7` — read from there, do not infer.


### 10) SQL Server style
- Generate valid T-SQL for SQL Server 2019+.
- **Add `SET QUOTED_IDENTIFIER ON; GO` at the top of the script** — mandatory for filtered indexes. Without this, SQL Server raises Msg 1934.
- Use deterministic constraint names.
- Use clear table and column ordering.
- Use bracketed identifiers only if required by the naming convention.
- Keep the script idempotent if the project convention expects it; otherwise generate clean `CREATE TABLE` statements only.




## Recommended table creation order
Create tables in dependency order:

1. parent/master tables
2. lookup tables
3. core transaction tables
4. junction tables
5. dependent tables

If using `CREATE TABLE` only:
- define parent tables first
- then child tables with foreign keys

## Constraint naming convention
Use predictable names such as:

- `PK_<TABLE>`
- `FK_<CHILD>_<PARENT>`
- `UQ_<TABLE>_<COLUMN>`
- `CK_<TABLE>_<RULE>`

Keep names short, readable, and consistent with project conventions.

## Validation checklist
Before outputting SQL, verify:

- all required tables exist
- all required columns exist
- all PKs exist
- all FKs exist
- all candidate keys are enforced
- all required `CHECK` constraints exist
- all required defaults exist
- all required `NOT NULL` constraints exist
- all required triggers exist when the schema registry.
- no extra tables were introduced
- no schema rule from the locked registry was missed

## Common mistakes to avoid
- skipping the schema registry and coding directly from the raw requirement
- mixing analysis text with DDL output
- inventing new entities that were not approved
- forgetting junction tables for M:N relationships
- using `CHECK` where a lookup table is required, or vice versa
- adding cascade deletes that would break history
- allowing nullable foreign keys where participation is total

## Output standard
The final SQL file should be ready to run after review, with no explanatory prose mixed into the script unless the project template explicitly requires comments.