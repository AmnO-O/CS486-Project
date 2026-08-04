---
description: Run Task 11 - Phase 2 concurrency design for the Campus Space Management System.
---

Command: generate-concurrency-design

Description:
Run the `db-design-pipeline:11-concurrency-design` skill to generate
`outputs/11-concurrency-design-G05.md`, a reviewer-ready design document for
preventing conflicting approved bookings under concurrent instant booking and
staff approval.

Task 11 is a design task. It identifies concurrency conflicts, resolves the Task
11 open question, evaluates suitable SQL Server concurrency-control options, and
selects the design that Task 12 will implement. It must not write implementation
SQL scripts, test scripts, data generators, index-tuning measurements, or final
analytical queries.

Usage:
```bash
generate-concurrency-design
generate-concurrency-design --group G05
generate-concurrency-design --group G05 --mode overwrite
generate-concurrency-design --group G05 --mode revise
```

Arguments:
  --group G05       Group identifier. Default: G05.
  --mode <mode>     Write mode for `outputs/11-concurrency-design-G{{group}}.md`.
                    - overwrite: replace the whole Task 11 output
                    - revise: update the existing Task 11 output after re-reading
                      all current sources and explaining what changed
                    Default: overwrite.

Prompt:
  Generate the Task 11 concurrency design for the Phase 2 extension of the Campus
  Space Management System, group {{group}}.

  Input sources:
  - `docs/README.md` and `memory/MEMORY.md` for required reading order
  - `memory/Progress.md` and `memory/ActiveContext.md` for task status and open
    question gates
  - `docs/project_phase2_description.md` (authoritative Phase 2 source)
  - `docs/templates/README.md` for routing
  - `docs/design-decisions.md` (do not contradict)
  - `docs/tech-stack.md` for SQL Server and naming conventions
  - `outputs/08-requirement-change-analysis-G{{group}}.md` (K1-K4 conflicts)
  - `outputs/09-updated-erd-and-logical-design-G{{group}}.md` (approved schema
    and Task 11 handoff)
  - `outputs/10-schema-migration-G{{group}}.sql` (implemented Phase 2 schema and
    trigger/application-layer contract)
  - `docs/entity-registry.md` and `docs/schema-registry.md` (current source of truth)

  Output:
  - Write `outputs/11-concurrency-design-G{{group}}.md`.
  - Append any Task 11 key decisions to `docs/design-decisions.md`, especially
    the resolved U3 answer and the selected concurrency-control strategy.
  - Write a trajectory file under `logs/trajectory/task11/` before reporting completion.

  Required content:
  1. Scope and source summary.
  2. Gate check, including Task 10 approval and Task 11 open question U3.
  3. Final U3 resolution before generation: whether escalation to out-of-service
     affects pending requests or only approved bookings. If U3 is still pending in
     `memory/Progress.md`, stop and ask for a decision before generating the output.
  4. Concurrency risks from Task 08 (K1-K4), mapped to affected workflows.
  5. Design goals and invariants, especially NR6: no overlapping approved bookings
     across instant and staff approval under concurrent execution.
  6. Candidate SQL Server strategies with tradeoffs.
  7. Selected concurrency-control strategy and rationale.
  8. Transaction boundaries and lock/read/write order for each workflow:
     instant booking, staff approval, maintenance escalation, and room-finder reads.
  9. Failure behavior and retry/error contract for application callers.
  10. Handoff checklist for Task 12 implementation and Task 13 tests.
  11. Assumptions, resolved ambiguities, remaining risks, and revision log.
  12. Static verification log under `logs/eval/task11/`.

  Do not:
  - implement stored procedures, triggers, or runnable SQL scripts here
  - create Task 13 two-session test scripts
  - tune indexes or record execution-plan timing
  - write Task 16 analytical queries
  - edit Task 08/09/10 outputs or registries to make the design easier
  - edit registries unless the current approved sources already require a schema
    update; Task 11 normally has no registry changes
  - update `memory/Progress.md` or `memory/ActiveContext.md` without user approval

Notes:
  - This command file defines the invocation interface only; the skill contains the
    behavior. Read the skill at
    `.opencode/skills/db-design-pipeline/11-concurrency-design/SKILL.md`.
  - If Task 10 is not approved, or U3 is still pending and no user decision is
    provided, stop before writing the Task 11 output.
