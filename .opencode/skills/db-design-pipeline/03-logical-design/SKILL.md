---
name: 03-logical-design
description: Produce the logical schema design from the Entity Registry and ERD for Task 03.
---

# Task 03 — Logical Design

## Purpose
Produce the logical schema design deliverable for Task 03 from the entity registry, ERD, and business requirements documents provided by the caller.

---

## Inputs
- Entity Registry (path provided by caller)
- ERD design document (path provided by caller)
- Business requirements analysis (path provided by caller)
- --group (optional, default: G05)

---

## Outputs
- Logical design document (path specified by caller)
- Schema registry (path specified by caller — updated with table and column definitions)
- Entity registry (path specified by caller — updated with finalized names/types/constraints)

---

## Behavior / Steps

1. Read the provided input documents (entity registry, ERD design, business requirements).
2. For each entity in the entity registry, map it to a logical table.
3. For each attribute in the entity registry, define a column with:
   - Name (apply naming conventions)
   - Data type (SQL Server compatible: INT, NVARCHAR, DATETIME2, DECIMAL, BIT, etc.)
   - Nullable/NOT NULL based on entity requirements
   - Default values where appropriate
   - Unique constraints for candidate keys
4. For each relationship in the entity registry:
   - Map to a foreign key constraint in the child table
   - Use appropriate referential integrity rules (ON DELETE CASCADE, ON DELETE SET NULL, etc.)
   - If M:N, create a junction/associative table with composite PK
5. Implement business rule constraints as CHECK constraints, UNIQUE constraints, and (where appropriate) INSTEAD OF / AFTER triggers for cross-row, cross-table, or status-transition validation.
6. Define indexes on:
   - Primary keys
   - Foreign keys
   - High-cardinality search columns (e.g., email, booking dates)
7. Prove normalization to at least 3NF:
   - 1NF: All values are atomic; no repeating groups
   - 2NF: No partial dependencies on composite keys
   - 3NF: No transitive dependencies; all non-key attributes depend solely on the PK
8. Document naming conventions applied (e.g., plural table names, snake_case columns, FK_Source_Target format).
9. Record constraint implementation details (how business rules are enforced).
10. Note any deviations from the ERD with justification.
11. Format the result as a final markdown deliverable and update the schema registry.

---

## Cognitive Rules / Guidelines

- **Role**: Act as a logical database design engineer and SQL schema architect.
- **Input sources only**: the documents provided by the caller (entity registry, ERD, business requirements).
- **Output intent**: Produce a detailed, reviewer-ready logical design that bridges the ERD and SQL DDL.
- **Do NOT embed hardcoded templates** — templates/responses are provided by the runtime when needed.

### Design Priorities (in order)
1. Preserve all entities from the ERD as tables
2. Preserve all relationships as FKs or junction tables
3. Implement explicit business rules as CHECK/UNIQUE constraints
4. Choose SQL Server-compatible data types
5. Optimize for 3NF normalization
6. Define supporting indexes


### Trigger Guidelines

- Use triggers (AFTER or INSTEAD OF) only when a business rule cannot be enforced using CHECK constraints, UNIQUE constraints, or foreign keys (e.g., cross-row validation, cross-table checks, or status transition rules).
- Prefer database-level enforcement for critical integrity rules.
- For entities with complex lifecycles (especially Bookings), create triggers to:
  - Enforce conditional NOT NULL requirements (e.g., `actual_start_time` must be set when `status = 'checked_in'`).
  - Validate complex conditions such as time overlaps, capacity limits, or maintenance conflicts.
- Name triggers clearly using the pattern `trg_<table>_<purpose>`.
- Avoid trigger overuse: combine related rules into fewer triggers when possible for better maintainability and performance.

**Common Trigger Patterns (for reference only):**
- Status transition validation
- Preventing overlapping bookings
- Checking space availability and maintenance conflicts
- Auto-updating related entity status (e.g., maintenance resolved → space status)

### Formatting Expectations

Each section must use structured markdown tables with the following columns:

**Section 2 — Table Definitions** (7 columns):

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| Column name | SQL data type | NO/YES | PK / UQ / — | `parent_table(column)` or — | literal or — | free-text notes |

Rationale: separates constraint types (PK, UQ, FK) into dedicated columns so readers can verify key design at a glance. `Default` gets its own column instead of being buried in Notes.

**Section 3 — Relationship Mapping** (6 columns):

| # | Relationship | Cardinality | Logical Implementation | Child FK Column | Parent Table |
|---|---|---|---|---|---|
| R1 | EntityA → EntityB | 1:N / M:N / 1:0..1 | FK in table / Junction table `X` | FK column(s) | Parent table |

**Referential Integrity Rules** (separate table, 6 columns):

| FK Column | Child Table | Parent Table | ON DELETE | ON UPDATE | Rationale |
|-----------|-------------|--------------|-----------|-----------|----------|
| FK column name | child_table | parent_table | NO ACTION / SET NULL / CASCADE | NO ACTION / SET NULL / CASCADE | justification |

Example:
| `department_id` | users | departments | NO ACTION | NO ACTION | Prevent deleting departments with active users |
| `assigned_staff_id` | maintenances | users | SET NULL | NO ACTION | Optional FK; nullify reference if staff deleted |

Keep this table **separate** from the Relationship Mapping table above. Rationale: the mapping describes the conceptual relationship (ERD → tables); the referential rules describe the physical implementation (database behavior on delete/update). Two distinct concerns, two tables.

**Section 4 — Index Strategy** (6 columns):

| Index Name | Table (Columns) | Type | Filter | Business Rule / Query | Rationale |
|---|---|---|---|---|---|
| PK / UQ / idx_ name | table(columns) | CLUSTERED / NONCLUSTERED / UNIQUE | filter condition or — | e.g. BR1 or "Scheduling queries" | justification |

Rationale: `Filter` ensures filtered indexes (like `uq_bookings_active_overlap`) have their WHERE clause visible without scanning Rationale text. `Business Rule / Query` provides traceability back to requirements.

**Section 7 — Constraint Implementation** (5 columns):

| BR | Business Rule | Object Name | Implementation | Enforcement Level |
|---|---|---|---|---|
| BR1 | Rule description | trigger / index / FK name | How it works | Database / Application |

Rationale: `Object Name` gives a direct handle to the DDL object implementing the rule, making cross-referencing between logical design and DDL faster.

**Other sections:**
- Section 1 — Logical design overview: prose, 2-4 sentences.
- Section 5 — Normalization proof: 1NF / 2NF / 3NF table-by-table evidence.
- Section 6 — Naming conventions: convention → description → examples.
- Section 8 — Deviations from ERD: table with ERD element, logical design, deviation, justification.
- Section 9 — Revision log: version, date, changes.

### Guardrails and Prohibitions
- Do **not** invent entities, columns, or relationships not in the entity registry.
- Do **not** output runtime instructions or shell commands.
- Do **not** make assumptions about statuses, enums, or constraint values beyond what the business requirement and entity registry explicitly state.
- Do **not** modify prior artifacts (outputs/01 or 02); only read them.
- Do **not** use SQL Server 2008 or deprecated features without compatibility notes.
- Do **not** create tables without explicit justification (especially junction tables).
- **Add triggers for status-driven column enforcement**: For columns that are nullable at table level but must be NOT NULL when a status column transitions to a specific value (e.g., `actual_start_time` must be set when `status = 'checked_in'`), define AFTER UPDATE triggers. This provides defense-in-depth beyond application-level enforcement.

### Interoperability
- The runtime may provide a template for table definitions if a specific visual format is required.
- The skill must update `docs/schema-registry.md` with the finalized table and column metadata.
- The skill must add finalization markers to `docs/entity-registry.md` for names/types that have been locked.

---

## Validation Checks (post-generation)

- Verify all entities from the entity registry are represented as tables.
- Verify all relationships are mapped (as FKs or junction tables).
- Verify column data types are SQL Server-compatible.
- Verify business rules are implemented as constraints (CHECK, UNIQUE, FK).
- Verify normalization proof is present and justified.
- Verify naming conventions are documented and applied consistently.
- Verify no forbidden writes have occurred on prior task outputs.

---

## Idempotency
- Overwrite the output document if it exists (path specified by caller).
- Update (not overwrite) the schema registry and entity registry documents with finalized metadata (paths specified by caller).

---

## Notes
- The skill should be prompt-focused and not include runtime shell behavior.
- Emphasis on traceability: each table/column should be traceable back to the entity registry and business rules.
- SQL Server compatibility is required; document any deviations from standard ANSI SQL.
- The logical design is the bridge between conceptual (ERD) and physical (DDL); precision here reduces downstream issues in Tasks 04–07.
