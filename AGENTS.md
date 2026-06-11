# CS486 — Space Booking System (Group G05)

You are working on a **database design project** for CS486.
The deliverable is design documents and SQL files, not a runnable application.
Target RDBMS: **Microsoft SQL Server (T-SQL)**.

---

## Before every task

Read these files in order before doing anything else:

1. `memory/productContext.md` — what the project is
2. `memory/techStack.md` — naming conventions, enum values, MSSQL syntax rules
3. `memory/progress.md` — which tasks are done, which are next, SCHEMA FREEZE status
4. `memory/activeContext.md` — the exact task right now

If any of these files is missing, stop and notify the user.

---

## Project structure

```
CS486-PROJECT/
├── .opencode/
│   ├── agent/          ← @orchestrator @analyst @designer @reviewer
│   ├── commands/       ← /generate-business-req /design-db
│   └── skills/         ← db-design-pipeline/
├── memory/             ← read before every task (see above)
├── req/                ← input requirements (read-only, never modify)
├── outputs/            ← all generated artifacts go here
└── logs/               ← agent improvement logs    
```

---

## General behavior rules

- **Never modify files in `req/`** — they are source of truth
- **All output goes to `outputs/`** — no exceptions
- **Output filename pattern:** `outputs/0X-<task-name>-G05.md` (or `.sql` for DDL/data/queries)
- **Do not skip tasks** — each task depends on the previous being ✅ in `progress.md`
- **Do not read `outputs/` by default** — only read a previous output when
  the current task explicitly depends on it as upstream input
- **Do not generate SQL before SCHEMA FREEZE** — Task 5, 6, 7 are blocked
  until Task 4 is approved by all 4 members and marked ✅

---

## After completing a task

1. Update `memory/progress.md` — change task status to ✅ or ⚠️
2. Update `memory/activeContext.md` — rewrite for the next task
3. Log any key decisions in the decisions table in `progress.md`

---

## Pipeline overview

| Task | Deliverable | Command | Agent | Output file |
|---|---|---|---|---|
| Task 1 | Business analysis | `/generate-business-req` | `@analyst` | `outputs/01-business-analysis-G05.md` |
| Task 2 | ERD design | `/design-db` | `@designer` | `outputs/02-erd-design-G05.md` |
| Task 3 | Logical design | `/design-db` | `@designer` | `outputs/03-logical-design-G05.md` |
| Task 4 | Design validation | _(planned)_ | `@reviewer` | `outputs/04-design-validation-G05.md` |
| — | **SCHEMA FREEZE** | — | all 4 approve | gate before Task 5–7 |
| Task 5 | SQL DDL | _(planned)_ | `@designer` | `outputs/05-ddl-G05.sql` |
| Task 6 | Sample data | _(planned)_ | `@designer` | `outputs/06-sample-data-G05.sql` |
| Task 7 | Query design | _(planned)_ | `@designer` | `outputs/07-query-design-G05.sql` |

For full pipeline: call `@orchestrator`.

---

## When in doubt

- Check `memory/activeContext.md` for the current task
- Check `memory/progress.md` for what is approved and whether SCHEMA FREEZE is reached
- Ask the user before making assumptions that affect schema design