---
name: 08-requirement-change-analysis
description: >
  Produce the requirement-change analysis for Task 08, generating
  outputs/08-requirement-change-analysis-G05.md. It identifies which Phase 1
  entities, relationships, and business rules are affected by the Phase 2
  changes, and the concurrency conflicts the new operating conditions introduce.
  Triggers when the user runs /generate-requirement-change or asks to analyze
  Phase 2 requirement changes for the Campus Space Management System.
---

# Task 08 — Requirement-Change Analysis

## Goal

Produce a concise, reviewer-ready requirement-change analysis in Markdown that:

- restates what changed from Phase 1 to Phase 2 *concise*ly
- identifies the **affected** entities, relationships, and business rules of the
  Phase 1 baseline
- determines the **possible conflicts** caused by concurrent booking and approval
  operations (analysis only — solution design is a later Phase 2 task)
- does **not** invent a final schema, columns, or tables (those are Tasks 09–10)

---

## Inputs
- `docs/project_phase2_description.md` (required) — authoritative Phase 2 source
- `docs/project-overview.md` (Phase 2 scope summary) (required)
- `outputs/01-business-req-analysis-G05.md` (Phase 1 baseline) (required)
- `docs/entity-registry.md`, `docs/schema-registry.md` (Phase 1 baseline, read-only)
- `req/business-requirement.md` (previous-task context as needed)
- `--group` (optional, default: `G05`)

## Output
- `outputs/08-requirement-change-analysis-G{{group}}.md`

---

## Behavior / Steps

1. Read the Phase 2 source and the Phase 1 baseline in the order above.
2. Identify each Phase 2 change and the Phase 1 entity / relationship / rule it touches.
3. For the concurrent booking & approval changes, enumerate the possible conflicts that may arise (do not design a fix here).
4. Note impacts on existing reports/data and anything that extends the Phase 1 scope.
5. Record assumptions and unresolved ambiguities as they appear.
6. Format the result as a final markdown deliverable.

---

## Cognitive rules / Guidelines

- Role: act as a database design analyst comparing Phase 1 vs Phase 2 requirements
  (system-level persona, not an end-user).
- Base every "affected" claim on the Phase 1 baseline and the Phase 2 source; do
  not guess.
- State what changed and what is impacted; do **not** decide the new schema,
  migration strategy, or concurrency solution.
- Do NOT embed a static, hardcoded prompt template in this skill file — responses
  are provided by the runtime or a separate `templates/` asset when needed.

---

## Analysis priorities (in order)

1. Phase 2 change summary: maintenance impact levels; concurrent/instant booking &
   approval; new reporting needs.
2. Affected entities (read-only view of the Phase 1 registry marked for Phase 2).
3. Affected relationships and the cardinality/participation they rely on.
4. Affected business rules and how the new rules interact with Phase 1 rules.
5. Possible concurrency conflicts from simultaneous booking and approval operations.
6. Assumptions and unresolved ambiguities.

---

## Formatting expectations

- Well-labelled Markdown sections matching the analysis priorities above.
- Prefer short enumerated lists and numbered items; reference each affected
  entity/rule by its Phase 1 name.
- Distinguish "analysis only" statements from "future design" topics so no Phase 2
  design is implied as final.
- Avoid prescribing table names, columns, keys, indexes, or implemented
  concurrency mechanisms.

---

## Guardrails & Prohibitions

- Do not invent capabilities, rules, or entities not supported by the input sources.
- Do not output runtime instructions, shell commands, or system orchestration.
- Do not decide or sketch the Phase 2 schema migration, concurrency implementation,
  or indexing strategy in this deliverable.
- Do not overwrite or edit `outputs/` files other than the Task 08 output; keep both
  registries read-only here.
- Do not contradict any entry in `docs/design-decisions.md` — raise conflicts instead
  of silently overriding.

---

## Interoperability

- The runtime/command may supply an output layout template if a specific format is
  required.
- The skill must enforce the validation checks below and return a structured summary
  the runtime can render into the final document.

---

## Validation checks (post-generation)

- Verify the output lists every Phase 2 change and its affected Phase 1 items.
- Verify concurrency conflicts are *identified* but not solved.
- Verify the output is markdown-formatted and does not finalize the Phase 2 schema.
- Verify the output references the Phase 1 baseline and Phase 2 source consistently
  with the registries.

---

## Idempotency

- Overwrite `outputs/08-requirement-change-analysis-G{{group}}.md` if it exists.

---

## Notes

- The skill is prompt-focused and must not include runtime shell behavior.
- This is an analysis deliverable; its downstream task (Task 09) performs the design
  update, so keep design decisions out of this file.