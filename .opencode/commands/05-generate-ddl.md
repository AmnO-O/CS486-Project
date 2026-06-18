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
- `.env` *(only required for SQL Auth / `sa` mode; skip when using Windows Auth `-E`)*

Business requirements may be consulted for clarification only:
* `req/business-requirement.md`
* `docs/project-overview.md`


Before generating SQL:
1. Read memory files in order:
   - `memory/Progress.md` → verify Task 04 status
   - `memory/ActiveContext.md` → check for blockers

2. Load environment variables:
   - Read `.env` → extract SA_PASSWORD *(only needed for SQL Auth / `sa` mode; skip for Windows Auth)*

3. Verify schema is locked:
   - Read `docs/schema-registry.md` — confirm all tables.
   - Confirm all columns, PKs, FKs, and CHECK constraints are specified
  
4. If any dependency is missing, stop and report it.

Usage:
```
generate-ddl --group G05
```

- Use `--group G05` as the default group.

Generate:

* `outputs/05-db-definition-G05.sql` — includes tables, constraints, indexes, AND triggers

After generation:

1. Validate output:
   - Check syntax: DDL must be valid T-SQL (SQL Server 2019+)
   - **First line of script must be `SET QUOTED_IDENTIFIER ON; GO`** — required for filtered indexes
   - Verify naming convention matches `docs/tech-stack.md`
   - Verify all PK, FK, CHECK, UNIQUE constraints match `docs/schema-registry.md`
   - Verify all triggers match Business Rule Coverage in `docs/schema-registry.md`

   - **FK cascade path check:** For each parent table, list all child FKs pointing to it.
     If two or more FKs from the same child table reference the same parent with SET NULL or CASCADE,
     SQL Server will reject it ("multiple cascade paths"). Resolve before compiling:
     keep one as SET NULL, change the rest to NO ACTION and document in `docs/design-decisions.md`.

2. Compile and verify on local SQL Server:

Choose ONE authentication mode and use it for all four commands below:

- **Windows Auth** (`-E`) — default for solo/local work. Uses your current Windows
  account; no password needed. Requires the server to accept Windows logins (always on).
- **SQL Auth** (`-U sa -P "$SA_PASSWORD"`) — use when connecting as `sa`, e.g. a shared
  team server. Requires the server in Mixed Mode with `sa` enabled (see `.env` for password).

Pick the mode that matches your setup, then substitute `<AUTH>` in each command with either
`-E` or `-U sa -P "$SA_PASSWORD"`.

- Create database if not exists:
```bash
   # Windows Auth (default):
   sqlcmd -S localhost -C -E \
   -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CS486_G05') CREATE DATABASE CS486_G05;"

   # SQL Auth (sa) alternative:
   sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD" \
   -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'CS486_G05') CREATE DATABASE CS486_G05;"
```

- Run DDL:
```bash
   # Windows Auth (default):
   sqlcmd -S localhost -C -E \
   -d CS486_G05 -i outputs/05-db-definition-G05.sql

   # SQL Auth (sa) alternative:
   sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD" \
   -d CS486_G05 -i outputs/05-db-definition-G05.sql
```

- Verify tables created:
```bash
   # Windows Auth (default):
   sqlcmd -S localhost -C -E \
   -d CS486_G05 \
   -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME;"

   # SQL Auth (sa) alternative:
   sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD" \
   -d CS486_G05 \
   -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME;"
```

- If any error → drop and recreate database, then re-run from step (a):
```bash
   # Windows Auth (default):
   sqlcmd -S localhost -C -E \
   -Q "DROP DATABASE IF EXISTS CS486_G05;"

   # SQL Auth (sa) alternative:
   sqlcmd -S localhost -C -U sa -P "$SA_PASSWORD" \
   -Q "DROP DATABASE IF EXISTS CS486_G05;"
```

Do NOT edit schema-registry.md to match code.

- On success → append verification output to logs/eval/task05/YYYY-MM-DD-HHMM-05-ddl-compile.log
- Write trajectory file per `.opencode/skills/evaluations/trajectory-recording.md`
- Update `memory/Progress.md` and `memory/ActiveContext.md`