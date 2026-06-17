# Workflow — Template & Registry Routing

> This file tells the AI **which templates and registries to load for each task**.
> It is the single routing index for `docs/templates/`.
>
> Read this file at the start of every task, after `docs/README.md`.

---

## Quick routing table

| Task | Read before generating | Write after generating |
|---|---|---|
| 01 Business req analysis | `req/business-requirement.md` only — do NOT read registries | → `docs/entity-registry.md` (populate) using `docs/templates/entity-registry-template.md` |
| 02 ERD | `docs/entity-registry.md` | → `docs/entity-registry.md` (refine relationships + status) |
| 03 Logical design | `docs/entity-registry.md` | → `docs/entity-registry.md` (finalize + lock: fill missing types, set all status to 🔒) · → `docs/schema-registry.md` (populate from scratch) using `docs/templates/schema-registry-template.md` |
| 04 Validation | `docs/entity-registry.md` + `docs/schema-registry.md` | → `docs/schema-registry.md` (business-rule coverage + LOCK GATE) |
| 05 DDL | `docs/schema-registry.md` | `outputs/05-db-definition-G05.sql` — transcribe only, never edit registry |
| 06 Sample data | `docs/schema-registry.md` + `docs/entity-registry.md` | `outputs/06-sample-data-G05.sql` |
| 07 Query design | `docs/schema-registry.md` + `docs/entity-registry.md` | `outputs/07-query-design-G05.sql` |

---

## When to read each template

| Template file | Read when |
|---|---|
| `docs/templates/entity-registry-template.md` | About to **write** `docs/entity-registry.md` (Task 01, 02, 03 only) |
| `docs/templates/schema-registry-template.md` | About to **write** `docs/schema-registry.md` (Task 03, 04 only) |

**Never read templates when you only need to look up data** — read the actual registry files instead.

---

## Task 01 — special rule

```
INPUT:  req/business-requirement.md  ← sole source, do NOT read registries before or during generation
OUTPUT: outputs/01-business-req-analysis-G05.md
AFTER:
  1. If docs/entity-registry.md already contains data (not empty):
     → Write YOUR OWN generated output to logs/registry-snapshots/YYYY-MM-DD-HHMM-entity-registry-task01.md
     → Do NOT read or copy docs/entity-registry.md
     → Do NOT overwrite docs/entity-registry.md
     → Stop here — human will decide whether to merge
  2. If docs/entity-registry.md is empty or does not exist:
     → Write YOUR OWN generated output to docs/entity-registry.md
  3. Follow format in docs/templates/entity-registry-template.md
```

---

## Task 03 — two separate writes (do not confuse)

```
Write 1 — finalize entity-registry.md (no template needed):
  - Fill any remaining "?" in Type / Constraint columns
  - Set ALL entity status → 🔒 locked
  - Do NOT restructure existing content


Write 2 — populate schema-registry.md:

  - If docs/schema-registry.md already contains data (not empty):
    → Write YOUR OWN generated output to logs/registry-snapshots/YYYY-MM-DD-HHMM-schema-registry-task03.md
    → Do NOT read or copy docs/schema-registry.md
    → Do NOT overwrite docs/schema-registry.md
    → Stop here — human will decide whether to merge
    If docs/schema-registry.md is empty or does not exist:
    → Write YOUR OWN generated output to docs/schema-registry.md

  - Read docs/templates/schema-registry-template.md for format
  - Source: outputs/03-logical-design-G05.md + entity-registry.md
  - Include: table definitions, FK wiring 
```

---

## Registry update checklist (after every task)

Run through this after saving `outputs/<task>-G05.<ext>`:

- [ ] Updated `docs/entity-registry.md` per protocol in `SKILL.md`
- [ ] Updated `docs/schema-registry.md` per protocol in `SKILL.md` (Task 03+)
- [ ] Appended to `docs/design-decisions.md` if any key decision was made
- [ ] Updated `memory/Progress.md`
- [ ] Updated `memory/ActiveContext.md`

---

## Design decisions — when to log

Log to `docs/design-decisions.md` whenever:
- A modeling choice has non-obvious tradeoffs (e.g. `building` as varchar vs separate table)
- The team overrides a default convention
- An open question (Q1, Q2 …) is resolved
- Any change is made after SCHEMA FREEZE

Do not log routine attribute additions or type confirmations.