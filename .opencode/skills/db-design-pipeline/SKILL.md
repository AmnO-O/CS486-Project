---
name: db-design-pipeline
description: >
  MANDATORY — load this skill before executing any of the 7 CS486 deliverables.
  Triggers when user runs /generate-* or /evaluate commands, or asks to generate
  business requirement analysis, ERD, logical design, design validation, DDL,
  sample data, or SQL queries for the Campus Space Management System.
---

# DB Design Pipeline Skill

## Before ANY task — required reading sequence
1. `docs/README.md` → determine which files to read for this task
2. `memory/MEMORY.md` → scan, open relevant memory files
3. `docs/design-decisions.md` → never contradict past decisions
4. Task-specific template in `templates/<task-number>-<task-name>/`

## Quality standards
- Entities and attributes → must match `docs/entity-registry.md` exactly
- Table names and columns → must match `docs/schema-registry.md` (task 03+)
- Naming → follow `docs/tech-stack.md` conventions
- Ambiguity → refer to `req/business-requirement.md`, never assume

## After ANY task — required actions
1. Save output to `outputs/<task>-G05.<ext>`
2. Run `file-evaluation.md` on the output
3. Update `memory/Progress.md`
4. Update `memory/ActiveContext.md`
5. If a key design decision was made → append to `docs/design-decisions.md`

---

## Per-task guidance

### Task 01 — Business Requirement Analysis
**Minimum**: 6 entities, 10 relationships, 10 explicit business rules
**Structure**: Business Purpose → Actors → Entities → Attributes → Relationships → Business Rules
**After**: Populate `docs/entity-registry.md`

### Task 02 — Conceptual ERD Design
**Notation**: Chen or Crow's Foot — be consistent throughout
**Must show**: cardinality + participation for every relationship
**Special cases**:
- APPROVAL: separate entity, 1:1 with BOOKING_REQUEST (partial on booking side)
- USAGE_SESSION: separate entity, 1:1 with BOOKING_REQUEST
- FACILITY: multi-valued attribute of SPACE → model as separate entity
- Booking overlap: note as application-level constraint in the diagram

### Task 03 — Logical Design
**Document each mapping**: Entity X → Table Y (list attributes and key changes)
**Conversion rules**:
- Strong entity → relation, PK stays
- Weak entity → composite PK (own partial key + owner FK)
- 1:N → FK on N side
- M:N → junction table with composite PK
- 1:1 → FK with UNIQUE on one side (choose based on participation)
- Multi-valued attribute → separate relation
**After**: Populate `docs/schema-registry.md`

### Task 04 — Design Validation
**Structure**: (1) ERD correctness, (2) Schema mapping correctness, (3) Business rule coverage, (4) Normalization check (1NF→3NF), (5) Gap analysis
**For each business rule**: state which constraint/table enforces it — or explain why it's application-level

### Task 05 — DDL
**Order**: Follow FK dependency order from `docs/schema-registry.md`
**Every status column**: CHECK constraint with all enum values
**Every FK**: explicit ON DELETE / ON UPDATE behavior
**Booking overlap**: add a comment block explaining application-level enforcement

### Task 06 — Sample Data
**INSERT order**: Follow FK dependency order
**Use explicit column lists**: `INSERT INTO users (user_id, full_name, ...) VALUES (...)`
**Coverage**: every enum value for status columns must appear at least once
**Edge cases**: 1 booking for an unavailable space (rejected), 1 no-show, 1 cancelled

### Task 07 — Query Design
**Header format per query**:
```sql
-- ============================================================
-- Query N: <title>
-- Business question: <what business question this answers>
-- Target user: <who uses this query>
-- Why useful: <business value>
-- ============================================================
```
**Required coverage**: JOIN, GROUP BY + aggregate, subquery/CTE, date filter, facility manager report