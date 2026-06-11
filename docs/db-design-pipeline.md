# Database Design Pipeline — 7-Step Workflow

This document describes the workflow for Tasks 1–7 of the CS486 database design project.

## Overview

The pipeline transforms raw requirements into a complete, normalized database schema with sample data and queries. Each task has a specific objective, gate criteria, and upstream/downstream dependencies.

```
Task 1              Task 2        Task 3              Task 4
Business      →     ERD      →    Logical      →      Design
Analysis           Design        Design              Validation
                                                          ↓
                                                    [SCHEMA FREEZE]
                                                      (Group approval)
                                                          ↓
Task 5              Task 6        Task 7
DDL           ←     Sample    ←    Query
              Data              Design
```

---

## Tasks 1–4 (Design phase)

### Task 1: Business Analysis

**Objective:** Extract and document requirements in a structured format.

**Inputs:**
- `req/business-requirement.md`
- `req/CS486_Project.txt`
- `req/CS486_Project.pdf`

**Outputs:**
- `outputs/01-business-analysis-G05.md`

**What to extract:**
1. Purpose and scope
2. Actors (6 user roles and their permissions)
3. Entities and their attributes
4. Relationships between entities
5. Business rules and constraints
6. Assumptions and open questions
7. Suggested initial table mapping

**Gate:** No gate before Task 2 can start. Task 1 must be marked ✅ in `memory/Progress.md`.

---

### Task 2: Conceptual ERD Design

**Objective:** Create an Entity-Relationship Diagram (ERD) showing all entities, attributes, and relationships.

**Inputs:**
- `outputs/01-business-analysis-G05.md` (Task 1 ✅)

**Outputs:**
- `outputs/02-erd-design-G05.md` (includes visual ERD + entity and relationship definitions)

**What to produce:**
1. Visual ERD (ASCII or image) showing all entities
2. Entity definitions: name, description, candidate key(s)
3. Relationship definitions: cardinality, optional vs. required, description
4. Assumptions and design decisions from this phase

**Gate:** No gate before Task 3 can start. Task 2 must be marked ✅ in `memory/Progress.md`.

---

### Task 3: Logical Design

**Objective:** Normalize the ERD into 3NF relational schema with complete column definitions.

**Inputs:**
- `outputs/02-erd-design-G05.md` (Task 2 ✅)

**Outputs:**
- `outputs/03-logical-design-G05.md` (includes normalized table definitions in relational notation)

**What to produce:**
1. All tables in relational notation: `TableName (PK, columns, constraints)`
2. For each table:
   - Surrogate primary key
   - All columns with data types
   - Foreign key references
   - NOT NULL vs. NULL
   - CHECK constraints for enums
   - Default values
3. Normalization proof: show that all tables are at least 3NF
4. Assumptions and any deviations from the ERD

**Gate:** No gate before Task 4 can start. Task 3 must be marked ✅ in `memory/Progress.md`.

---

### Task 4: Design Validation

**Objective:** Verify the logical schema against all business rules and constraints from the requirement.

**Inputs:**
- `outputs/03-logical-design-G05.md` (Task 3 ✅)
- `req/business-requirement.md` (requirement source)

**Outputs:**
- `outputs/04-design-validation-G05.md` (includes validation matrix, business rule coverage checklist)

**What to produce:**
1. Validation matrix: Business rule → Schema element(s) that enforce it
2. Checklist: ✅ Pass or ❌ Fail for each business rule
3. Coverage analysis: Are all 6 user roles and their permissions represented?
4. Completeness check: Are all entities and relationships from the requirement included?
5. Any gaps, assumptions, or design decisions that differ from the requirement

**Gate:** **SCHEMA FREEZE checkpoint**
- All 4 group members must review and approve Task 4.
- Once frozen, the schema in this output becomes **locked** and is the upstream input for Tasks 5, 6, 7.
- Do NOT start Tasks 5, 6, 7 before SCHEMA FREEZE is reached.

---

## Tasks 5–7 (Implementation phase)

### Task 5: SQL DDL

**Objective:** Generate executable SQL statements to create the database schema.

**Inputs:**
- `outputs/04-design-validation-G05.md` (Task 4 ✅ + SCHEMA FREEZE approved)

**Outputs:**
- `outputs/05-ddl-G05.sql` (executable T-SQL)

**What to produce:**
1. `CREATE TABLE` statements for all tables
2. Primary key definitions (`IDENTITY` or `UNIQUEIDENTIFIER`)
3. Foreign key constraints (`FOREIGN KEY ... REFERENCES`)
4. NOT NULL / DEFAULT / CHECK constraints
5. Comments explaining complex columns or constraints
6. Execution order (if there are cascading dependencies)

**Dialect:** Microsoft SQL Server T-SQL (MSSQL 2019+)

**Gate:** Cannot start until SCHEMA FREEZE is reached.

---

### Task 6: Sample Data

**Objective:** Generate realistic sample data for testing and demonstration.

**Inputs:**
- `outputs/05-ddl-G05.sql` (Task 5 ✅)

**Outputs:**
- `outputs/06-sample-data-G05.sql` (executable T-SQL `INSERT` statements)

**What to produce:**
1. Sample data for all tables (at least 3–5 rows per table)
2. Realistic data reflecting the use case (students, lecturers, spaces, bookings, etc.)
3. Data that exercises all key relationships and constraints
4. Comments explaining the data set (e.g., "Scenario: 2 students booking a classroom")

**Dialect:** Microsoft SQL Server T-SQL (MSSQL 2019+)

**Gate:** Cannot start until Task 5 (DDL) is complete.

---

### Task 7: Query Design

**Objective:** Generate SQL queries that answer key business questions.

**Inputs:**
- `outputs/05-ddl-G05.sql` (Task 5 ✅)

**Outputs:**
- `outputs/07-query-design-G05.sql` (executable T-SQL queries with comments)

**What to produce:**
1. At least 10 SQL queries answering business questions:
   - List all bookings for a given space in a date range
   - Find available spaces for a time slot
   - Check if a space is under maintenance
   - Get booking history per user
   - Find spaces by equipment (e.g., "projector")
   - List pending approvals
   - Calculate facility utilization
   - Detect booking conflicts (if any)
   - Other domain-specific queries
2. For each query:
   - Clear comment describing the business question
   - Query itself
   - Expected result description

**Dialect:** Microsoft SQL Server T-SQL (MSSQL 2019+)

**Gate:** Cannot start until Task 5 (DDL) is complete.

---

## Critical gates

| Gate | Trigger | Impact |
|---|---|---|
| Task 1 ✅ | Business analysis complete | Unblocks Task 2 |
| Task 2 ✅ | ERD design complete | Unblocks Task 3 |
| Task 3 ✅ | Logical design complete | Unblocks Task 4 |
| Task 4 ✅ | Design validation complete | Unblocks SCHEMA FREEZE |
| **SCHEMA FREEZE** | All 4 group members approve Task 4 | Unblocks Tasks 5, 6, 7 |
| Task 5 ✅ | DDL complete | Unblocks Tasks 6, 7 |

---

## Status tracking

Track progress in `memory/Progress.md`:
- ⬜ Not started
- 🔄 In progress
- ✅ Approved
- ⚠️ Needs revision (do not use as upstream input)

After completing each task:
1. Update status in `memory/Progress.md`
2. Rewrite `memory/ActiveContext.md` for the next task
3. Add decisions to the decisions log in `memory/Progress.md`
