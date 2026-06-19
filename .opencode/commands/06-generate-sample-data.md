---
description: Generate realistic SQL Server sample data with valid seed rows and expected-error cases.
---

Command: generate-sample-data

Description:
Run the `db-design-pipeline:06-sample-data` skill to generate `outputs/06-sample-data-G05.sql` from the locked Task 05 DDL and registries.

Usage:
```
generate-sample-data --group G05
```

Prompt:
  Generate Task 06 sample data for the Campus Space Management System, group G05.

  Input sources:
  - `req/business-requirement.md`
  - `outputs/01-business-req-analysis-G05.md`
  - `outputs/05-db-definition-G05.sql`
  - `docs/entity-registry.md` (read-only)
  - `docs/schema-registry.md` (read-only)

  Output:
  - A single SQL Server script suitable for `outputs/06-sample-data-G05.sql`

  Include:
  1. Realistic valid data for every locked table
  2. Normal workflow scenarios for bookings and maintenance
  3. Intentional expected-error cases for key constraints and triggers
  4. Verification queries for row counts, statuses, audit fields, and reporting scenarios

  Do not:
  - modify any registry
  - modify prior output artifacts
  - invent tables, columns, enum values, or constraints outside the Task 05 DDL
  - output markdown prose inside the SQL file

Notes:
  - Use `--group G05` as the default group.
  - This command file defines the invocation interface only; the skill contains the task behavior.
  - Overwrite `outputs/06-sample-data-G05.sql` if it already exists.
