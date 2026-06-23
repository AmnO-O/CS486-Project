---
name: 06-sample-data
description: Generate SQL Server sample data for Task 06, including realistic valid seed data, documented expected-error cases, sqlcmd execution evidence, trajectory updates, and memory updates for the Campus Space Management System database project.
---

# Task 06 - Sample Data Preparation

## Goal

Create `outputs/06-sample-data-G05.sql`, a SQL Server sample-data script that proves the Task 05 schema supports normal workflows and important exceptional cases for the Campus Space Management System.

The script must be reviewer-ready, executable after `outputs/05-db-definition-G05.sql`, and useful as a foundation for Task 07 query design.

## Source Of Truth

Resolve conflicts in this order:

1. `outputs/05-db-definition-G05.sql`
2. `docs/schema-registry.md`
3. `docs/entity-registry.md`
4. `outputs/01-business-req-analysis-G05.md`
5. `req/business-requirement.md`
6. `docs/project-overview.md`

Do not change the schema. If valid sample data cannot be produced without changing a table, column, constraint, trigger, or enum, stop and report the conflict.

## Required Inputs

Read these before generating data:

- `req/business-requirement.md`
- `outputs/01-business-req-analysis-G05.md`
- `outputs/05-db-definition-G05.sql`
- `docs/entity-registry.md` as read-only
- `docs/schema-registry.md` as read-only

## Outputs

Write only these Task 06 deliverables, plus required trajectory and allowed memory updates:

- `outputs/06-sample-data-G05.sql`
- `logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt`

## Hard Boundaries

- Do not edit `docs/entity-registry.md`.
- Do not edit `docs/schema-registry.md`.
- Do not edit prior output artifacts.
- Do not invent tables, columns, enum values, triggers, or constraints absent from Task 05 DDL.
- Keep the final SQL file as SQL only. Use SQL comments, not Markdown prose.

## Workflow

1. Read the required inputs and identify all locked table names, columns, constraints, triggers, enum values, identities, and FK dependencies from Task 05 DDL.
2. Read `references/data-coverage.md` and plan valid seed rows that cover all required roles, statuses, purposes, space types, facilities, maintenance scenarios, bookings, and reporting cases.
3. Read `references/idempotence-and-test-isolation.md` and choose an idempotence strategy before writing inserts or expected-error cases.
4. Read `references/business-rule-proofs.md` and plan intentional expected-error cases for the required business rules and declarative constraints.
5. Read `references/sql-style-and-ordering.md` while writing the SQL so insert order, lookup variables, trigger-aware transitions, dates, and comments stay consistent.
6. Save `outputs/06-sample-data-G05.sql`.
7. Read `references/execution-validation.md`, run `sqlcmd` after Task 05 DDL creates the database, and save the console output log.
8. Rerun the script when validating idempotence or after any fix that changes cleanup, inserts, lookup capture, or expected-error setup.
9. If execution exposes sample-data generation errors in valid seed sections, fix the SQL and rerun.
10. Read `references/completion-actions.md` before updating trajectory and memory files.

## Reference Guide

- Read `references/data-coverage.md` before choosing sample entities and rows.
- Read `references/idempotence-and-test-isolation.md` before writing inserts, cleanup, temp tables, or expected-error fixtures.
- Read `references/business-rule-proofs.md` before writing negative tests or verification queries.
- Read `references/sql-style-and-ordering.md` while composing the SQL script.
- Read `references/execution-validation.md` before running `sqlcmd` and recording execution evidence.
- Read `references/completion-actions.md` before final trajectory and memory updates.

## Core Validation Checklist

Before finalizing the SQL file, verify:

- All table and column names exist in `outputs/05-db-definition-G05.sql`.
- Insert order is FK-safe.
- Valid rows satisfy all CHECK constraints and triggers.
- No two valid active bookings overlap for the same space.
- Unavailable spaces are represented without invalid valid-booking rows.
- Every required role, booking status, booking purpose, space type, space status, and maintenance status appears at least once.
- At least one maintenance row has valid assigned staff.
- At least one booking or maintenance row demonstrates soft-delete or historical preservation.
- Every required negative case is marked with `-- Expected error: ...` and wrapped in `TRY/CATCH`.
- The script can run safely on a database that already contains previous Task 06 sample data.
- Expected-error tests cannot fail early because required lookup IDs are NULL or missing.
- Expected-error output proves the intended BR/constraint, not an unrelated NULL, FK, or duplicate-key cascade.
- The script continues after expected failures.
- Verification queries cover audit timestamps and required reporting scenarios.
- The trajectory plan includes SQL generation, `sqlcmd` execution, execution-log review, and rerun/idempotence evidence when applicable.
- Any revision made after execution is recorded in the trajectory with the failing evidence, the fix, and the replacement execution log.
- No registry or prior output file was modified.

## Completion Gate

Mark Task 06 complete only when the sample-data script is generated and execution evidence is recorded. If SQL Server or `sqlcmd` is unavailable, record the blocker explicitly in trajectory and memory.

