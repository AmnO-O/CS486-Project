
# CS486 Space Booking Database Design — Documentation Index

**Required reading order for onboarding:**

1. **[project-overview.md](./project-overview.md)** — What this project is, who uses it, what problem it solves 
2. **[tech-stack.md](./tech-stack.md)** — Technology conventions and vocabulary

3. **[entity-registry.md](./entity-registry.md)** — Entities and attributes (Tasks 1–7)
4. **[schema-registry.md](./schema-registry.md)** — Normalized relational schema (Tasks 3–5) 
5. **[design-decisions.md](./design-decisions.md)** — Design rationale and trade-offs 

---

## Phase 2 (Tasks 08–16)

The project is extended to a **two-phase, 16-task pipeline**.

- **Phase 1 (Tasks 01–07)** is complete, approved, and **locked** — the 9-table
  schema under `entity-registry.md` / `schema-registry.md` was frozen (SCHEMA FREEZE).
- **Phase 2 (Tasks 08–16)** extends that frozen baseline. The authoritative Phase 2
  requirement source is **`docs/project_phase2_description.md`**. It adds
  maintenance impact levels, advisory acknowledgements, concurrent/instant booking,
  schema migration, a ≥100k-row data generator, index tuning, and analytical queries.

> For any Phase 2 task, first read `docs/project_phase2_description.md` — the
> authoritative Phase 2 source. `project-overview.md` also has a concise Phase 2 scope
> summary (already read at onboarding); treat it as a summary, not as an additional
> authoritative input. Then read the relevant `docs/` file and sub-skill under
> `.opencode/skills/db-design-pipeline/`. The Phase-2 re-design unfreezes the affected
> tables; see the Phase-2 markers in the registries. Support for tasks 08–16 exists under
> `outputs/`, `logs/trajectory/task08/`…`task16/`, and `memory/Progress.md`.

**Quick start (3-step checklist)**

- Read the required docs above in order.
- Verify project memory files exist and read them: `memory/MEMORY.md`, `memory/ActiveContext.md`, `memory/Progress.md`.

---

## Session workflow

1. **Start of session:** Read memory files in this order: `memory/MEMORY.md` → `memory/ActiveContext.md` → `memory/Progress.md`. If present, also review `docs/project-overview.md` and `docs/tech-stack.md`.
2. **Begin task:** Open the docs file for the active pipeline step (see the reading order above).
3. **During task:** Follow the procedural skill at `.opencode/skills/db-design-pipeline/` for detailed step-by-step guidance.
4. **End of task:** After user approval (Post-Task Handshake Protocol in `AGENTS.md`), update `memory/Progress.md` and `memory/ActiveContext.md` with results and any open questions.

---

## Where to find tools and skills

- Procedural skills and templates: `.opencode/skills/db-design-pipeline/`
- Outputs folder: `outputs/` (naming: `outputs/0X-<step-name>-G05.*`)

---

## Group: G05

All outputs follow the naming convention: `outputs/0X-<step-name>-G05.*`
