# CS486 Space Booking Database Design — Documentation Index

**Required reading order for onboarding:**

1. **[project-overview.md](./project-overview.md)** — What this project is, who uses it, what problem it solves
2. **[tech-stack.md](./tech-stack.md)** — Technology conventions, vocabulary, and syntax rules
3. **[db-design-pipeline.md](./db-design-pipeline.md)** — The 7-step workflow and each task's objectives
4. **[entity-registry.md](./entity-registry.md)** — All entities and their attributes (Tasks 1–7)
5. **[schema-registry.md](./schema-registry.md)** — The normalized relational schema (Tasks 3–5)
6. **[design-decisions.md](./design-decisions.md)** — Why we made each schema choice

---

## Quick reference

| Document | Purpose | Updates when |
|---|---|---|
| project-overview.md | Product definition | Project scope changes |
| tech-stack.md | Vocabulary & standards | Conventions change |
| db-design-pipeline.md | Workflow & gate criteria | Tasks added/modified |
| entity-registry.md | Entity definitions | Entities are discovered (Task 1→3) |
| schema-registry.md | Final normalized schema | Schema is finalized (Task 4) |
| design-decisions.md | Design rationale | Decisions are made |

---

## Session workflow

1. **Start of session:** Read memory files in this order: `memory/ProductContext.md` → `memory/TechStack.md` → `memory/Progress.md` → `memory/ActiveContext.md`
2. **Begin task:** Read the appropriate file from this docs/ folder based on which task is active
3. **During task:** Refer to the skill in `.opencode/skills/db-design-pipeline/` for detailed step-by-step instructions
4. **End of task:** Update `memory/Progress.md` and `memory/ActiveContext.md`

---

## Deliverables (outputs/)

| Task | Output file | Status |
|---|---|---|
| 1 — Business analysis | `outputs/01-business-analysis-G05.md` | Not started |
| 2 — ERD design | `outputs/02-erd-design-G05.md` | Not started |
| 3 — Logical design | `outputs/03-logical-design-G05.md` | Not started |
| 4 — Design validation | `outputs/04-design-validation-G05.md` | Not started |
| 5 — SQL DDL | `outputs/05-ddl-G05.sql` | Not started |
| 6 — Sample data | `outputs/06-sample-data-G05.sql` | Not started |
| 7 — Query design | `outputs/07-query-design-G05.sql` | Not started |

---

## Group: G05

All outputs follow the naming convention: `outputs/0X-<step-name>-G05.*`
