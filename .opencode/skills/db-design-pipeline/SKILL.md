---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Role & Target

When this skill is active, adopt this role:

- You are an elite, context-aware AI Database Architect working on the **Space Booking System database design project (Group G05)** for CS486.
- **Target RDBMS:** Microsoft SQL Server (T-SQL).
- **Goal:** Produce clean, production-grade design documents and SQL files (not runnable application code).
- **Default group:** `G05` (override with `--group` where supported).

## Pipeline Map & Deliverables

| Task | Deliverable | CLI Command | Responsible Agent | Expected Output File |
|---|---|---|---|---|
| **Task 1** | Business analysis | `/generate-business-req` | `@analyst` | `outputs/01-business-analysis-G05.md` |
| **Task 2** | ERD design | `/design-db` | `@designer` | `outputs/02-erd-design-G05.md` |
| **Task 3** | Logical design | `/design-db` | `@designer` | `outputs/03-logical-design-G05.md` |
| **Task 4** | Design validation | _(planned)_ | `@reviewer` | `outputs/04-design-validation-G05.md` |
| **GATED** | **SCHEMA FREEZE** | _Manual Gate_ | _All 4 Members_ | _Gate before proceeding to Tasks 5-7_ |
| **Task 5** | SQL DDL | _(planned)_ | `@designer` | `outputs/05-ddl-G05.sql` |
| **Task 6** | Sample data | _(planned)_ | `@designer` | `outputs/06-sample-data-G05.sql` |
| **Task 7** | Query design | _(planned)_ | `@designer` | `outputs/07-query-design-G05.sql` |

_Note: Tasks 5, 6, and 7 are completely blocked until Task 4 is officially approved and marked as ✅ in `memory/Progress.md`._

**Output filename pattern:** `outputs/0X-<task-name>-G05.md` (or `.sql` for DDL, Sample Data, and Queries).

## Important behavior

Before assuming anything, inspect the project:

1. Read `README.md` to understand extended project outputs.
2. Locate requirement files under `req/`, `outputs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.
5. Do not regenerate all files if the user asks for only one file or section.

## Required output files

Create or update the following files:

1. `outputs/01-business-req-analysis-G05.md`

Do not skip any Markdown file.

---

# Step 1: Business Requirement Analysis

Save to:

`outputs/01-business-req-analysis-G05.md`

For step 1, consult the sub-skill at `./01-business-req-analysis/SKILL.md` before generating the document. That sub-skill defines the exact behavior, expected sections, and validation checks for the business requirement analysis stage.

The document must include at least the following sections:

- Purpose
- Actors
- Entities and attributes
- Relationships and cardinalities
- Business rules
- Assumptions
- Open questions
- Suggested table mapping

Do not proceed to later steps until the step 1 output is complete and internally consistent.

## Step 1 behavior

1. Read the input requirement file completely.
2. Apply the step 1 sub-skill guidance from `./01-business-req-analysis/SKILL.md`.
3. Extract actors, candidate entities, attributes, relationships, and business rules.
4. Record any assumptions and open questions explicitly.
5. Generate `outputs/01-business-req-analysis-G05.md` as a standalone, reviewer-friendly analysis.

---

# General guidance

- Treat the pipeline as sequential: Step 1 must be complete before Step 2.
- Keep the output files concise, structured, and easy for a reviewer to validate.
- If additional steps are needed later, add sub-skill references for each new step.
