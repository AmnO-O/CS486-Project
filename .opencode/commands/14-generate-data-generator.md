---
description: Run Task 14 - Phase 2 deterministic data generator for the Campus Space Management System.
---

# Task 14 command

Run `db-design-pipeline:14-data-generator` to create or revise
`outputs/14-data-generator-G{{group}}/`. This command is the compact execution
router; the Task 14 skill holds the complete normative Task 14 instructions. Load
only the references the active workflow needs.

## Usage

```text
generate-data-generator
generate-data-generator --group G05
generate-data-generator --group G05 --mode overwrite
generate-data-generator --group G05 --mode revise
generate-data-generator --group G05 --seed 20260806 --bookings 100000
```

Arguments:

- `--group G05`: output suffix; default `G05`.
- `--mode overwrite|revise`: rewrite the complete directory; default `overwrite`.
- `--seed <integer>`: one recorded deterministic seed.
- `--bookings <n>`: target count; enforce `100000 <= n <= 500000`.

## Embedded Task 14 contract

Required acceptance:

- G1: 100,000-500,000 bookings.
- G2: >=3 academic years.
- G3: advisory + out-of-service maintenance and impact-change history.
- G4: cancelled + no_show lifecycle rows in documented proportions.
- G5: complete advisory acknowledgements for confirmed overlaps.
- G6: instant (`approver_id=-1`) + staff approval origins.
- G7: no confirmed non-deleted overlap per space.
- G8: same seed/config reproduces the same generated dataset.

Required artifact directory:

```text
outputs/14-data-generator-G{{group}}/
  README.md
  config.example.json
  generate.py
  load.sql
  verify.sql
  requirements.txt
```

README records sources, volume, seed, date model, distributions, Mode A/B split,
load/restart/Task 06 coexistence policy, trigger decision, assumptions, and limits.
`generate.py` writes deterministic CSVs. `load.sql` targets SQL Server 2019+.
`verify.sql` proves V1-V6. `requirements.txt` pins every non-stdlib dependency.
Keep large CSVs out of Git.

Source priority:
`docs/project_phase2_description.md` -> `docs/design-decisions.md` ->
`outputs/10-schema-migration-G{{group}}.sql` -> `outputs/05-db-definition-G{{group}}.sql`
-> approved Task 11/12 outputs -> registries -> `docs/tech-stack.md`.
Stop on conflicts. Never change schema to fit data.

Gates: follow `AGENTS.md`, `docs/README.md`, `memory/`, `docs/templates/README.md`,
the main pipeline skill, and the Task 14 skill. Task 10 must be approved and present.
Respect strict task order. Directly relevant pending questions block generation. U4
belongs to Task 16 and does not block Task 14; do not hardcode its semester definition.
Do not update memory before user approval.

Critical current-schema rules:

- Never recreate migrated system user `-1`; use it for instant approvals. Do not add an
  approval-origin column.
- Always pass `maintenance.impact_level`; omitted value defaults to blocking
  `out-of-service`.
- Insert advisory ack rows before approval; ack must reference active overlapping
  advisory maintenance; `(booking_id, maintenance_id)` is composite-unique.
- Produce impact history through an active-row level update, not direct history INSERT.
  Attribute through `SESSION_CONTEXT(N'current_user_id')` when required; clear it.
- Respect actual FK/identity/order, roles, capacity, status transitions, completion
  requirements, soft-delete filters, exact-start filtered unique index, and confirmed
  interval non-overlap from current sources.

Loading/realism: use Mode A through approved Task 12 entry points for a small behavior
slice; use Mode B deterministic CSV + controlled bulk loading for the large mass. Keep
confirmed intervals per space. Multi-threading must partition by space or use Mode A.
Document `KEEPIDENTITY`, `CHECK_CONSTRAINTS`, `FIRE_TRIGGERS`, `BATCHSIZE`, CSV format,
restart policy, clean/append policy, and Task 06 coexistence. Do not use SQL Server
2022-only `GENERATE_SERIES`. Cover three years, working-hour/weekday variation,
term-start spikes, all space types, facilities/capacity, both maintenance impacts,
required lifecycle shapes, and an escalation with affected approved bookings.

Validation must include volume/span, confirmed-overlap, out-of-service-overlap,
advisory-ack completeness, status/impact/origin/history/ack distributions, no-show
without session, and constraint-trust checks when bulk loading bypasses checks. Run
static checks, a small same-seed smoke comparison, then `sqlcmd` only on a scratch DB.
Write Task 14 eval log and trajectory before reporting. Do not implement Tasks 12/13/15/16.

## Required reading

- `AGENTS.md`, `docs/README.md`, `memory/MEMORY.md`, `memory/ActiveContext.md`,
  `memory/Progress.md`, `docs/templates/README.md`
- `.opencode/skills/db-design-pipeline/SKILL.md`
- `.opencode/skills/db-design-pipeline/14-data-generator/SKILL.md`
- `docs/project_phase2_description.md`, `docs/design-decisions.md`, `docs/tech-stack.md`
- `docs/entity-registry.md`, `docs/schema-registry.md` read-only
- `outputs/05-db-definition-G{{group}}.sql`
- `outputs/10-schema-migration-G{{group}}.sql` and rollback
- approved Task 11/12 outputs when present
- Task 14 references only when the active workflow needs detailed loading or validation rules

## Handshake

End with completed files, assumptions, validation/blockers, then exactly:

> _"Ready to mark Task 14 as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_


