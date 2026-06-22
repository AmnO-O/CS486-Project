---
description: Implement the database using SQL DDL with tables, keys, constraints, checks, and default values where appropriate.
---

Use skill in:
- `.opencode/skills/db-design-pipeline/SKILL.md`
- `.opencode/skills/db-design-pipeline/05-generate-ddl/SKILL.md`

Required inputs:
- `outputs/01-business-req-analysis-G05.md`
- `outputs/02-erd-design-G05.md`
- `outputs/03-logical-design-G05.md`
- `outputs/04-design-validation-G05.md`
- `docs/schema-registry.md`
- `.env` *(SQL Auth only — skip when using Windows Auth `-E`)*

For clarification only:
- `req/business-requirement.md`
- `docs/project-overview.md`

---

## Before generating SQL

1. Read memory files in order:
   - `memory/Progress.md` → verify Task 04 is marked complete
   - `memory/ActiveContext.md` → check for blockers; stop and report if any

2. Load environment (SQL Auth only):
   - Read `.env` → extract `SA_PASSWORD`

3. Verify schema is locked:
   - Read `docs/schema-registry.md`
   - Confirm all tables, columns, PKs, FKs, and CHECK constraints are fully specified
   - If anything is missing → **stop and report**; do not generate DDL against an incomplete schema

---


### Usage:
```bash
generate-ddl --group G05
```
- Use `--group G05` as the default group.

Generate:
* `outputs/05-db-definition-G05.sql`

---

## Generate

Output: `outputs/05-db-definition-G05.sql`

Includes: tables, constraints, indexes, and triggers.

**First two lines of the script must be:**
```sql
SET QUOTED_IDENTIFIER ON
GO
```
This is required for filtered indexes on SQL Server. Omitting it causes a compile error.

---

### Compile on local SQL Server

Choose **one** authentication mode and use it consistently for all four commands:

| Mode | When to use | Syntax |
|------|------------|--------|
| **Windows Auth** | Default for local/solo work. No password needed. | `-E` |
| **SQL Auth** | Use when connecting as `sa` on a shared team server. | `-U sa -P "$SA_PASSWORD"` |

Replace `<AUTH>` in all commands below with either `-E` or `-U sa -P "$SA_PASSWORD"`.

**a. Create database (if not exists):**
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

**c. Verify all tables were created:**
```bash
sqlcmd -S localhost -C <AUTH> \
  -d CS486_G05 \
  -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES \
      WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;"
```

**d. If any error — drop, recreate, then re-run from step (a):**
```bash
sqlcmd -S localhost -C <AUTH> \
  -Q "DROP DATABASE IF EXISTS CS486_G05;"
```

> **Rule:** Do NOT edit `docs/schema-registry.md` to match the code.
> If a mismatch exists, fix the SQL — the schema registry is the source of truth.

---

## On success

- Append verification output to `logs/eval/task05/YYYY-MM-DD-HHmm-05-ddl-compile.log`
- Update `memory/Progress.md`: mark Task 05 as complete
- Update `memory/ActiveContext.md`: clear any blockers, set next active task to Task 06