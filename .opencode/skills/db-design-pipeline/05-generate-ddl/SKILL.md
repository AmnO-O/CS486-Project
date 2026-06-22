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

---

## Source of truth order

When there is any conflict between sources, resolve it using this priority order:

1. `docs/schema-registry.md`
2. `outputs/04-design-validation-G05.md`
3. `outputs/03-logical-design-G05.md`
4. `outputs/02-erd-design-G05.md`
5. `outputs/01-business-req-analysis-G05.md`
6. `req/business-requirement.md`

Primary source is always `docs/schema-registry.md`. All other files are fallback references for clarification only. Do not override the schema registry with lower-priority sources.


**Schema Freeze Rule**


If a constraint, FK behavior, column, index, or trigger is explicitly defined in `docs/schema-registry.md`, it must be implemented exactly.

If the schema registry is silent about a constraint, the generator may add
additional integrity constraints only when:

- they do not alter cardinality
- they do not alter FK delete/update behavior
- they do not introduce new entities
- they do not contradict any approved business rule

Additional integrity safeguards may only be:
- CHECK constraints
- DEFAULT constraints

Do not introduce new UNIQUE constraints,
- new indexes,
- new foreign keys,
- new triggers, or modify existing schema-registry definitions.


Such constraints must be documented with:
```
-- Additional integrity safeguard (not part of locked schema)
```

**Schema Freeze Enforcement**

If a trigger, index, FK action, constraint, or business-rule implementation
is explicitly listed in `docs/schema-registry.md`, generate it exactly.

Do not introduce additional:

- triggers
- stored procedures
- functions
- computed columns
- automation logic
- background synchronization logic

unless they are explicitly required by:

- `docs/schema-registry.md`, or
- `outputs/04-design-validation-G05.md`

Additional integrity safeguards are allowed only as:

- CHECK constraints
- supporting non-conflicting indexes

They must not change application behavior, business-rule semantics,
or lifecycle transitions defined in the locked schema.




---

## Core DDL rules

### 1. Table mapping
- Each strong entity becomes one table.
- Each M:N relationship becomes a junction table.
- Each multivalued attribute becomes a separate table if the schema registry requires it.
- Do not create tables that are not present in the locked schema.

### 2. Primary keys
- Every table must have a primary key.
- Use the key defined in `docs/schema-registry.md`.
- If the schema uses surrogate keys, preserve them.
- Do not invent alternate primary keys unless the schema registry explicitly allows it.

### 3. Foreign keys
- Every foreign key must reference an approved parent table.
- Foreign key nullability must match the cardinality and participation constraint from Task 02.
- Do not use cascading deletes unless the schema registry explicitly allows it.
- For historical records, prefer preserving rows over destructive cascades.

### 4. Candidate keys / unique constraints
- Any candidate key identified in Task 03 or locked in the schema registry must become a `UNIQUE` constraint.
- Business identifiers such as email or space code must be protected if the schema registry marks them as unique.

### 5. CHECK constraints
Use `CHECK` for enumerated values, simple domain restrictions, and bounded numeric rules. Apply to:
- status columns
- type columns
- capacity ranges
- date/time ordering when it can be enforced locally

Keep checks readable and consistent across all tables.

### 6. DEFAULT values
Apply defaults where appropriate for:
- `created_at` → `GETDATE()`
- `updated_at` if the project convention requires it
- flags such as `is_deleted` → `0`
- initial status columns when the schema registry defines a default state

### 7. NULLability
- Mandatory attributes must be `NOT NULL`.
- Optional attributes may be nullable.
- Follow participation constraints from Task 02 and column-level requirements from Tasks 03 and 04.

### 8. Historical data preservation
- Do not destroy historical booking or maintenance records.
- Avoid schema choices that would erase audit trails.
- If soft delete is part of the locked schema, apply it consistently across all relevant tables.
- Prefer `NO ACTION` on FK delete behavior unless the schema registry explicitly authorizes `CASCADE` or `SET NULL`.

### 9. Procedural constraints / triggers
Trigger Scope Rule

Only generate triggers that are explicitly required by the
Business Rule Coverage section of `docs/schema-registry.md`.

Do not invent additional triggers unless the schema registry
or design-validation document explicitly requires them.

**Mandatory pattern — each trigger must be in its own batch:**
```sql
GO
CREATE TRIGGER trg_name
ON table_name
AFTER INSERT, UPDATE
AS
BEGIN
    -- rule enforcement logic
END
GO
```

> **Rule:** Every `CREATE TRIGGER` must be the first statement in its batch.
> Always precede with `GO`. Forgetting `GO` causes a compile error on SQL Server.

Trigger requirements are defined in the **Business Rule Coverage** section of `docs/schema-registry.md`.

- Refer to `outputs/03-logical-design-G05.md §7` for context on which rules require triggers vs declarative constraints.

- Use `outputs/03-logical-design-G05.md §8` only for clarification. 

- Never add, remove, or modify schema elements that conflict with
`docs/schema-registry.md`.

If a rule is intentionally deferred to the application layer, document the reason in a SQL comment at the relevant location in the script.

### 10. SQL Server style
- Generate valid **T-SQL for SQL Server 2019+**.
- **The first two lines of the script must be:**
  ```sql
  SET QUOTED_IDENTIFIER ON
  GO
  ```
  This is mandatory for filtered indexes. Omitting it causes `Msg 1934` at compile time.
- Use deterministic, predictable constraint names (see naming convention below).
- Use clear table and column ordering.
- Use bracketed identifiers `[name]` only if required by the project naming convention in `docs/tech-stack.md`.
- Keep the script idempotent if the project convention requires it; otherwise generate clean `CREATE TABLE` statements only.

---

## Recommended table creation order

Create tables in dependency order to avoid FK reference errors:

1. Parent / master tables (e.g. `Users`, `Spaces`)
2. Lookup / reference tables
3. Core transaction tables (e.g. `Bookings`)
4. Junction tables (e.g. `SpaceFacilities`)
5. Dependent tables (e.g. `BookingApprovals`, `UsageSessions`, `MaintenanceRecords`)

---

## Constraint naming convention

Use short, predictable names that match `docs/tech-stack.md`:

| Type | Pattern | Example |
|------|---------|---------|
| Primary key | `PK_<TABLE>` | `PK_Bookings` |
| Foreign key | `FK_<CHILD>_<PARENT>` | `FK_Bookings_Users` |
| Unique | `UQ_<TABLE>_<COLUMN>` | `UQ_Users_Email` |
| Check | `CK_<TABLE>_<RULE>` | `CK_Bookings_Status` |

---

## Validation checklist

Before outputting SQL, verify every item:

**Tables and columns**
- [ ] All required tables exist
- [ ] No extra tables were introduced that are not in the schema registry
- [ ] All required columns exist with correct data types and nullability

**Constraints**
- [ ] All PKs exist
- [ ] All FKs exist and reference the correct parent columns
- [ ] All candidate keys are enforced as `UNIQUE`
- [ ] All required `CHECK` constraints exist and use correct enum values
- [ ] All required `DEFAULT` values are present
- [ ] All required `NOT NULL` constraints are applied

**Triggers**
- [ ] All required triggers exist and match the Business Rule Coverage in `docs/schema-registry.md`
- [ ] Every trigger is preceded by `GO` in its own batch

**Script integrity**
- [ ] `SET QUOTED_IDENTIFIER ON` + `GO` is the first block in the file
- [ ] No schema rule from the locked registry was missed
- [ ] No analysis text or prose is mixed into the SQL output

---

## Common mistakes to avoid

- Skipping `docs/schema-registry.md` and generating directly from raw requirements
- Mixing analysis text or markdown prose with DDL output
- Inventing new entities that were not approved in the schema registry
- Forgetting junction tables for M:N relationships
- Using `CHECK` where a lookup table is required, or vice versa
- Adding `CASCADE` deletes that would erase historical records
- Allowing nullable foreign keys where participation is total (mandatory)
- Omitting `GO` before `CREATE TRIGGER` — causes batch-level compile errors
- Forgetting `SET QUOTED_IDENTIFIER ON` at the top — causes `Msg 1934` on filtered indexes

---

## Output standard

The final SQL file must be ready to run after review.
No explanatory prose should be mixed into the script unless the project template explicitly requires inline comments.