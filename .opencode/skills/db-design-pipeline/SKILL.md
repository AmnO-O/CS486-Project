---
name: db-design-pipeline
description: >
  MANDATORY — load this skill before executing any of the 7 CS486 deliverables.
  Triggers when user runs /generate-* or /evaluate commands, or asks to generate
  business requirement analysis, ERD, logical design, design validation, DDL,
  sample data, or SQL queries for the Campus Space Management System.
---

# DB Design Pipeline Skill

## Before ANY task — required reading sequence
1. `docs/README.md` → determine which files to read for this task
2. `memory/MEMORY.md` → scan, open relevant memory files
3. `docs/templates/README.md` → to determine which templates to read
4. `docs/design-decisions.md` → never contradict past decisions
5. Task-specific sub-skill: `.opencode/skills/db-design-pipeline/<NN>-<task-name>/SKILL.md`
   (e.g. `01-business-req-analysis/`).

## Quality standards
- **Task 01 only:** source of truth is `req/business-requirement.md` —
  do NOT read `docs/entity-registry.md` before generating output;
  write TO it after.

- **Task 02+:** entities and attributes → must match `docs/entity-registry.md` exactly.

- Table names and columns → must match `docs/schema-registry.md` (task 03+)
- Naming → follow `docs/tech-stack.md` conventions
- Ambiguity → refer to `req/business-requirement.md`, never assume


## Registry maintenance protocol

The schema is tracked in **two registries with different jobs**. They are the
**single source of truth** — keep them current at the end of every task and never
let an `outputs/` file diverge silently from them. **Do not duplicate content
between them**: each fact lives in exactly one file (see the boundary below).

**The two files — strict content boundary:**

| | `docs/entity-registry.md` | `docs/schema-registry.md` |
|---|---|---|
| View | **Conceptual** — what things exist | **Relational** — how they are built |
| Contains | Entities, descriptions, candidate keys, attribute list (name / type / nullable / notes), relationships in prose | Tables, columns as relational notation, PK/FK wiring, **indexes**, **3NF proof**, business-rule coverage, LOCK GATE |
| Must NOT contain | Indexes, FK graph, 3NF proof, business-rule coverage | Business/role prose descriptions, candidate-key analysis |

> If you are about to write the same fact into both files, stop — decide which view
> it belongs to and write it there only. The other file references it, not repeats it.

**Who writes what, when:**

| Task | Action on `entity-registry.md` | Action on `schema-registry.md` |
|---|---|---|
| 01 Business analysis | **Populate** from `outputs/01`: every entity (description, candidate keys, draft attributes) and **all relationships**. Names/types may be provisional. | — (not started) |
| 02 ERD | **Refine**: confirm relationships + cardinalities, resolve M:N into junction tables, update the discovery-status table. | — (not started) |
| 03 Logical design | **Lock**: finalize column names, data types, nullability, keys, and enum/CHECK constraints. | **Populate** from `outputs/03`: relational table definitions, FK wiring, candidate indexes, and the 3NF normalization proof. |
| 04 Validation | Read-only — verify every entity/attribute satisfies the business rules. On SCHEMA FREEZE, mark **locked**. | Read-only — fill the business-rule coverage table; mark **locked** (LOCK GATE) on SCHEMA FREEZE. |
| 05–07 DDL / data / queries | **Read-only.** Output must match exactly — never edit; raise a conflict instead. | **Read-only.** DDL is a transcription of this file; never edit it to match code. |

**Rules:**
- Edit registries only under `docs/`; never edit an `outputs/` file to "fix" a mismatch — the registry wins.
- Every entity and attribute must trace to a requirement or an `outputs/0X` line.
- By the end of Task 03, every attribute row in `entity-registry.md` must have its `Key` and `Constraint / Enum` columns filled.
- Each entity must follow the **Format spec — canonical entity block** at the top of `entity-registry.md`; each table must follow the relational-notation style in `schema-registry.md`.
- Keep the two files consistent: every entity in `entity-registry.md` maps to exactly one table block in `schema-registry.md` (1:1, except junction tables created in Task 02).
- Any change after SCHEMA FREEZE requires group consensus + a `docs/design-decisions.md` entry.

## After ANY task — required actions
1. Save output to `outputs/<task>-G05.<ext>`
2. Update the registries per the **Registry maintenance protocol** above
3. Write a trajectory file per `.opencode/skills/evaluations/trajectory-recording.md`
   — the task is not complete until it exists
4. Run `.opencode/commands/evaluate-task.md` on the output
5. Update `memory/Progress.md`
6. Update `memory/ActiveContext.md`
7. If a key design decision was made → append to `docs/design-decisions.md`

