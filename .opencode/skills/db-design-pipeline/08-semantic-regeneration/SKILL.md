---
name: semantic-regeneration-pipeline
description: >
  Regenerate downstream database design artifacts in sequence when an upstream artifact has been updated.
  Follows the principle of preserving design intent, rationale, and business assumptions while discarding outdated implementation details.
---

# Semantic Regeneration Pipeline Skill

## Core Philosophy

When an upstream design artifact is improved or updated, all downstream artifacts must be regenerated rather than patched. 
- **Upstream is the Single Source of Truth**: The newly updated upstream artifact is the absolute source of truth.
- **Previous Artifacts are Knowledge Sources**: The previous versions of downstream artifacts are treated as repositories of design rationale, optimizations, naming conventions, and business assumptions — not as code templates or baselines.
- **Preserve Intent, Discard Implementation**: Preserve the underlying concepts and design decisions (e.g., *why* a constraint or index exists) but generate the physical implementation from scratch to avoid anchoring to outdated structures.
- **No Patching**: Overwrite artifacts completely. Incremental updates and patches are strictly prohibited.

---

## Directory & Run-Based Structure

All runs are stored as subdirectories within `outputs/run/`.
- `--from-run <old_run>` specifies the directory containing the previous artifacts (e.g., `outputs/run/run_01/`).
- `--to-run <new_run>` specifies the directory where the newly regenerated artifacts will be written (e.g., `outputs/run/run_02/`).
- **Pre-requisite**: The improved upstream artifact must already exist in the target `--to-run` directory before the regeneration command is executed.

---

## General Regeneration Workflow

For each downstream task in sequence:

1. **Load Target Task Skill**: Read the task's corresponding skill file `SKILL.md` in `.opencode/skills/db-design-pipeline/<NN>-<task-name>/` to load its rules, quality standards, and formatting requirements.
2. **Extract Design Intent**: Read the old downstream artifact from `--from-run/` to extract reusable knowledge (e.g., reasons for indexes, triggers, specific check conditions, data distributions, business scenarios).
3. **Discard Implementation**: Ignore the actual syntax, column types, or queries of the old downstream artifact.
4. **Identify Upstream Changes**: Compare the old upstream artifact (from `--from-run/`) with the new upstream artifact (from `--to-run/`) to list additions, deletions, renames, and structural changes.
5. **Map Intent Decisions**: Evaluate each extracted design intent:
   - **Preserve**: Keep the intent if the underlying entity/relationship/field is unchanged.
   - **Adapt**: Modify the intent if the underlying components were renamed or re-architected.
   - **Discard**: Remove the intent if the components no longer exist.
6. **Regenerate from Scratch**: Generate the new downstream artifact completely from scratch based on the new upstream artifact and the mapped design intents. Write it to the `--to-run/` directory.
7. **Validate Consistency**: Run the validation checks defined in the target task's skill file. Ensure no references to outdated attributes or entities remain.
8. **Overwrite**: Completely overwrite the old file in the `--to-run/` directory.

---

## Step-Specific Guidelines

### 1. Logical Design (Task 03)
- **Task Skill**: `.opencode/skills/db-design-pipeline/03-logical-design/SKILL.md`
- **Previous Artifact**: `--from-run/03-logical-design-G05.md`
- **Upstream Source of Truth**: `--to-run/02-erd-design-G05.md` (the updated ERD)
- **Guidelines**:
  - Read the previous logical design to understand the purpose of indexes, triggers, naming conventions, and 3NF normalization rationale.
  - Compare the old ERD with the new ERD to identify schema alterations (e.g., new tables, column type changes, status transitions).
  - Regenerate the logical schema document completely from scratch.
  - Update `docs/entity-registry.md` and `docs/schema-registry.md` to be fully consistent with the new logical schema.

### 2. Design Validation (Task 04)
- **Task Skill**: `.opencode/skills/db-design-pipeline/04-design-validation/SKILL.md`
- **Previous Artifact**: `--from-run/04-design-validation-G05.md`
- **Upstream Sources of Truth**: `--to-run/02-erd-design-G05.md` and `--to-run/03-logical-design-G05.md`
- **Guidelines**:
  - Read the previous validation report to extract the check logic and scope.
  - Re-run all 11 validation steps and 5 criteria defined in the validation skill against the new ERD and logical design.
  - Generate a brand-new validation report in `--to-run/04-design-validation-G05.md`.

### 3. DDL Generation (Task 05)
- **Task Skill**: `.opencode/skills/db-design-pipeline/05-generate-ddl/SKILL.md`
- **Previous Artifact**: `--from-run/05-db-definition-G05.sql`
- **Upstream Source of Truth**: `docs/schema-registry.md` and `--to-run/03-logical-design-G05.md`
- **Guidelines**:
  - Read the previous DDL file only to understand database-level conventions (e.g., trigger implementation details or constraint naming rules).
  - Translate the updated schema registry into a complete, clean SQL Server DDL script.
  - Do not copy or patch the old DDL script. Write all table creation, keys, constraints, indexes, and triggers from scratch.
  - Write the output to `--to-run/05-db-definition-G05.sql`.

### 4. Seed Data (Task 06)
- **Task Skill**: `.opencode/skills/db-design-pipeline/06-sample-data/SKILL.md`
- **Previous Artifact**: `--from-run/06-sample-data-G05.sql`
- **Upstream Source of Truth**: `--to-run/03-logical-design-G05.md` (Logical Schema) and `--to-run/05-db-definition-G05.sql` (DDL)
- **Guidelines**:
  - Read the previous seed data script to understand the business scenarios simulated, records distributions, and the relationships between records.
  - Map old table and column structures to the new logical schema and DDL to determine changes in fields, foreign keys, or mandatory constraints.
  - Generate all SQL INSERT statements completely from scratch. 
  - Ensure the new statements follow the visual/structural format of the old seed data file (e.g., staging tables, batching, transaction handling, or helper variables).
  - Write the output to `--to-run/06-sample-data-G05.sql`.

### 5. SQL Queries (Task 07)
- **Task Skill**: `.opencode/skills/db-design-pipeline/07-generate-query/SKILL.md`
- **Previous Artifact**: **Do NOT read `--from-run/07-query-design-G05.sql`**.
- **Upstream Source of Truth**: `req/business-requirement.md` (Business Questions), `--to-run/05-db-definition-G05.sql` (DDL), and `--to-run/06-sample-data-G05.sql` (Seed Data)
- **Guidelines**:
  - Derive the business questions directly from `req/business-requirement.md` and reference `--to-run/01-business-req-analysis-G05.md` if necessary.
  - Write completely new SQL queries from scratch based on the updated table structures, relationships, and data types.
  - Ensure all queries are parameterized, follow the 4-field template, and use appropriate joins and filters (including soft-delete handling).
  - Write the output to `--to-run/07-query-design-G05.sql`.
