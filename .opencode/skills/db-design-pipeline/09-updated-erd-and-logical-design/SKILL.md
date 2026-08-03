---
name: 09-updated-erd-and-logical-design
description: >
  Produce the updated ERD and logical (relational) schema design for Task 09,
  generating outputs/09-updated-erd-and-logical-design-G05.md, and re-run the
  3NF check. Task 09 is strictly limited to the ERD and logical schema: it
  designs the Phase 2 changes on top of the Phase 1 baseline in three scoped
  areas — maintenance impact levels + advisory acknowledgement,
  concurrent/instant booking and approval, and the new analytical reporting
  needs — but it must NOT design concurrency controls (Tasks 11–13), migration
  (Task 10), indexing (Task 15), or queries (Task 16). Supports --req <1|2|3>
  scoping. Triggers when the user runs /generate-updated-erd-and-logical-design
  or asks to update the ERD and logical design for the Phase 2 extension of the
  Campus Space Management System.
---

# Task 09 — Updated ERD and Logical Design (Phase 2)

## Goal

Produce an updated, reviewer-ready ERD + logical/relational schema in Markdown that
designs the Phase 2 changes identified in Task 08 on top of the frozen Phase 1
baseline, and re-confirms every relation is in at least 3NF.

**Task 09 concerns ONLY the ERD and the logical schema.** It answers one question per
Phase 2 requirement: *what changes to entities, relationships, attributes, PK/FK,
constraints, defaults, and indexes must the Phase 2 extension introduce to the Phase 1
baseline?*

This is a **design** task (Task 08 was analysis). It may define the Phase 2 schema
shape — affected/added entities, attributes, FKs, cardinalities, constraints,
indexes — but it must **not** produce:

- the migration scripts (Task 10),
- the concurrency controls / locking mechanisms (Tasks 11–13) — at most it records
  *schema objects* that later tasks will use, never the mechanism itself,
- index-tuning decisions on execution plans (Task 15),
- the analytical query implementations (Task 16).

**No-schema-change rule.** If a Phase 2 requirement does not result in any change to
the ERD or the logical schema, do **not** invent one to fill the section. Leave that
section blank with an explicit statement such as *"No ERD / logical schema change is
required for this requirement"* plus a one-line reason. The same applies at the
element level: only list the columns, relationships, and constraints that actually
change; never pad with speculative additions.

---

## Inputs

- `docs/project_phase2_description.md` (required) — authoritative Phase 2 source
- `outputs/08-requirement-change-analysis-G{{group}}.md` (required) — Task 08 analysis
- `docs/entity-registry.md`, `docs/schema-registry.md` — Phase 1 baseline (read to design; write the affected entities after)
- `docs/design-decisions.md` — never contradict a past decision
- `outputs/02-erd-design-G{{group}}.md`, `outputs/03-logical-design-G{{group}}.md` — Phase 1 baseline reference
- `--group` (optional, default: `G05`)

---

## Output

- `outputs/09-updated-erd-and-logical-design-G{{group}}.md`

---

## Requirement-scope argument (`--req`)

Task 09 covers three Phase 2 change areas. Each is a **numbered section** in the output.

| Area | Detail | Source |
|---|---|---|
| `1` | Maintenance impact levels + advisory acknowledgement + `current_status` handling | §1.1, Task 08 C1 / NR1–NR4 |
| `2` | Concurrent/instant booking and approval (booking origin/pathway) | §1.2, Task 08 C2 / NR5–NR6 |
| `3` | Analytical reporting needs (room finder, semester windows, etc.) | §1.3, Task 08 C3 |

### Scoping behavior (key spec)

- **No `--req`**, or **`--req all`** → regenerate the **whole** file: all sections + shared baseline, create-or-overwrite.
- **`--req <1|2|3>` given** → operate scoped:
  - if that area's section **exists** → **overwrite** that section in place (others untouched);
  - if it does **not** exist → **insert** it so sections stay ascending `1, 2, 3` (above any higher-numbered section, else at the end);
  - re-running the same `--req` replaces, never duplicates.
  - if a scoped edit invalidates another section, flag the mismatch instead of silently leaving it inconsistent.

---

## Behavior / Steps

1. Read inputs in the order above.
2. Determine scope from `--req`.
3. For each in-scope area, decide whether the requirement changes the ERD or logical
   schema **at all**:
   - if it does → produce (a) an **updated ERD excerpt** (Mermaid `erDiagram`)
     limited to the changed/added entities and relationships, and (b) the **logical
     design** tables (columns, type, nullable, PK/FK, defaults, indexes);
   - if it does **not** → write the no-schema-change statement (see Goal) and move on.
   Do not force a schema change where none is required.
4. Keep Phase 1 intact where unaffected; show changes as a diff so a reviewer can see
   exactly what extends the baseline.
5. Re-run the **3NF normalization proof** for every affected relation.
6. Resolve any Task 08 open questions that fall within this task's scope (per the
   "Known open questions (Phase 2)" table in `memory/Progress.md` and AGENTS.md: ask
   the person responsible for a decision before generating on an unresolved question).
7. Record assumptions and carry forward unresolved ambiguities.
8. Produce the scoped or full output per the format rules, applying the `--req`
   overwrite/insert behavior.
9. Update `docs/entity-registry.md` and `docs/schema-registry.md` for the affected
   entities (`Maintenance`, `Bookings`) consistently with this design.

---

## Formatting Requirements

1. **Overview** — scope (all / `1` / `2` / `3`), summary of what extends Phase 1.
2. **Section A — Area 1: Maintenance impact levels**
   - ERD excerpt: `Maintenance` (+ `impact_level`), `Maintenance_Impact_History`,
     `Booking_Advisory_Acknowledgement`.
   - Logical tables: `maintenance.impact_level`; `maintenance_impact_history`;
     `booking_advisory_acknowledgement`.
   - `current_status` handling **as a schema concern**: whether `spaces` needs any
     schema change to support the new status semantics (Area 1 design decision: no new
     columns); state what the logical schema does and does not add. Do not design the
     recompute trigger's algorithm here beyond what the schema requires.
3. **Section B — Area 2: Concurrent/instant booking & approval**
   - ERD excerpt for the booking and approval origin/pathway (instant vs staff).
   - Logical tables for booking and approval — schema only: the booking-origin
     attribute (`approval_source`), the approver identity model (e.g., the reserved
     system user as a documented seed row), any supporting indexes/constraints.
   - The locking / serialization mechanism of the no-overlap rule is **not** designed
     here (Tasks 11–13); only schema objects that later tasks rely on may appear.
   - If instant booking causes no schema change, write the no-schema-change statement.
4. **Section C — Area 3: Analytical reporting needs**
   - ERD excerpt **only if** a support entity/table is added to serve the reports.
   - If the reports are fully answerable by queries over the existing (or already
     designed) schema, write the no-schema-change statement with the reason; do not
     fabricate support tables.
5. **3NF re-check** — functional dependencies + proof for each affected relation.
6. **Deviations from Phase 1 — business rules & related elements** — this section is
   the place to record how Phase 1 **business rules and related elements** are changed
   under the Phase 2 requirements, together with their ERD/logical impact:
   - For each affected Phase 1 rule (e.g., BR2, BR4, BR19 for Area 1) and each
     related element (trigger, status flag, constraint), give: Phase 1 meaning →
     Phase 2 meaning → justification (from `docs/project_phase2_description.md` /
     Task 08).
   - Then list the ERD/logical deviations (old element → new element → justification).
   - Distinguish "this task changes the schema for it" from "the rule changes but only
     triggers/behavior are affected, designed/implemented in later tasks".
7. **Resolved ambiguities** — report every open question from the Task 08 unresolved
   list / `memory/Progress.md` "Known open questions (Phase 2)" table that THIS task
   resolves. Format: question → decision → section where the decision is designed.
   Questions left open for later tasks must be explicitly carried forward as unresolved.
8. **Assumptions / unresolved ambiguities** — new assumptions + carried-forward questions.
9. **Revision log** — version, date, changed sections.

Prefer short enumerated lists and tables; reference each changed entity/rule by its
Phase 1 or Phase 2 name. Distinguish "this Task designs" from "later Task designs".

---

## Guardrails & Prohibitions

- Do not invent capabilities, rules, entities, or schema objects not supported by the
  input sources.
- Do not finalize the Task 10 migration, Task 11–13 concurrency controls/mechanisms,
  Task 15 indexing, or Task 16 query implementations inside this output.
- If a requirement produces no ERD/logical change, do not pad the section — leave the
  no-schema-change statement instead.
- Do not overwrite or edit `outputs/` files other than the Task 09 output.
- Do not contradict any entry in `docs/design-decisions.md`; raise conflicts.
- After a scoped run, never leave a duplicate or out-of-order section.
- Follow `docs/tech-stack.md` naming conventions.

---

## Interoperability

- The runtime may supply a layout template when a specific visual format is required.
- The output must reflect the Phase 2 unfreeze markers (`🔓 P2`) on `Maintenance` and
  `Bookings` in the registries and keep all untouched Phase 1 tables frozen.

---

## Validation Checks (post-generation)

- Verify every in-scope Phase 2 change is designed and referenced to Task 08 rules —
  or explicitly stated as requiring no ERD/logical change.
- Verify `--req` semantics were honored (full rewrite vs overwrite-in-place vs
  insert-above-higher), with sections ascending `1, 2, 3` and no duplicates.
- Verify the 3NF proof is present for every affected relation.
- Verify Sections B and C contain only ERD/logical-schema design and no concurrency
  mechanism (Tasks 11–13) or query implementation (Task 16).
- Verify the "Deviations from Phase 1" section documents the changed Phase 1 business
  rules and related elements, not only table diffs.
- Verify the output reports every ambiguity that was resolved in this task (and marks
  the rest as carried forward unresolved).
- Verify the output does not finalize Tasks 10–16 designs.
- Verify the output is Markdown and consistent with the Phase 1 registries.

---

## Idempotency

- Full run: overwrite `outputs/09-updated-erd-and-logical-design-G{{group}}.md` entirely.
- Scoped run: single-section overwrite/insert per the `--req` rules (never a duplicate).
