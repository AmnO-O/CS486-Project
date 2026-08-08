---
name: 16-analytical-queries
description: >
  Generate, append, revise, and validate the Phase 2 Task 16 analytical SQL
  deliverable for CS486 G05. Covers Q1 booking conflict, Q2 room finder,
  Q3 approved hours, Q4 weekday/hour demand, and Q5 escalation impact.
---

# Task 16 - Analytical Queries

## Goal and output

Generate `outputs/16-analytical-queries-G{{group}}.sql`, an executable SQL Server
2019+ script containing these stable query IDs:

| ID | Query | Requirement |
|---|---|---|
| Q1 | Booking conflict check | Task 15 conflict-check target; BR1/NR6 |
| Q2 | Room finder | Report #3 |
| Q3 | Approved booking hours per space | Report #1 |
| Q4 | Approved bookings by weekday/hour | Report #2 |
| Q5 | Approved bookings affected by escalation | Report #4; NR4 |

The final Task 16 file must contain Q1-Q5. Partial sets are allowed only for an
explicit first contribution followed by safe append.

## Required reading and gates

Read in this order before generating:

1. `AGENTS.md`, `docs/README.md`.
2. `memory/MEMORY.md`, `memory/ActiveContext.md`, `memory/Progress.md`.
3. `docs/templates/README.md`, `docs/project_phase2_description.md`,
   `docs/design-decisions.md`, `docs/tech-stack.md`.
4. `docs/schema-registry.md` and `docs/entity-registry.md` (read-only).
5. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` and
   `outputs/10-schema-migration-G{{group}}.sql`.
6. Approved Task 11/12 outputs when present.
7. `outputs/14-data-generator-G{{group}}/README.md`, `verify.sql`, and config.
8. `outputs/07-query-design-G{{group}}.sql` to avoid duplicate ideas.

Stop and report the exact conflict if sources disagree. Do not generate when:

- Task 14 is not approved or its dataset/loading contract is unavailable.
- A directly relevant Phase 2 question is pending.
- The work would require schema, index, procedure, trigger, or concurrency changes.

### U4 gate

Q3 and Q4 require the U4 decision in `memory/Progress.md`. If it remains pending,
stop and ask for resolution; do not infer a semester from Task 14 or Task 07.
The approved U4 convention in `docs/design-decisions.md` is:

- Semester 1: `[September 1, February 1)`.
- Semester 2: `[February 1, July 1)`.
- Summer is excluded.
- Q3 clips requested booking duration to the semester window.
- Q4 uses bookings whose `requested_start_time` is inside the window.
- Weekday numbering is Monday = 1.

Use declared `@semester_start` and `@semester_end` with a half-open predicate.

## SQL block contract

Every block must have exactly one marker and end with `GO`:

```sql
-- ============================================================
-- Task 16 Query Q1: <title>
-- ============================================================
-- task16-query-id: Q1
-- target-users: <roles>
-- business-question: <question>
-- why-useful: <operational value>
-- ============================================================
```

Rules for every query:

- Use explicit `dbo.` qualification and explicit JOIN syntax; no comma joins.
- Declare adjustable inputs in the block. Do not hide adjustable literals in logic.
- Use exact schema names, enum values, and confirmed statuses:
  `approved`, `checked_in`, `completed`.
- Filter `bookings` and `maintenance` with `is_deleted = 0` where applicable.
- Use half-open overlap: `@slot_start < row_end AND @slot_end > row_start`.
- Use `NOT EXISTS` rather than nullable `NOT IN` anti-joins.
- Keep every block independently executable after its `GO`.
- Do not include index DDL, execution plans, timings, or Task 15 results.

## Query requirements

### Q1 - Booking conflict check

Parameters: `@space_id`, `@slot_start`, `@slot_end`.
Return non-deleted bookings for that space whose status is confirmed and whose
requested interval overlaps the proposed interval. Return booking/space/requester
IDs, status, purpose, and requested times. Document the caller contract
`@slot_end > @slot_start`. This query is a read hint; Task 11/12 remains the final
concurrency-safe confirmation authority.

### Q2 - Room finder

Parameters: `@slot_start`, `@slot_end`, `@minimum_capacity`, and a local
`@required_facilities` table variable containing all facility names required by the
caller. The query supports zero, one, or many rows; the generation example must seed
at least two rows to represent a realistic multi-facility search.
Return spaces with sufficient capacity that have every requested facility. Use
relational division (`NOT EXISTS` double-nested, not a one-facility match).
Exclude `retired` and `temporarily_closed` spaces. Exclude spaces with overlapping
confirmed bookings or active non-deleted `out-of-service` maintenance
(`open`/`in_progress`). Advisory maintenance does not block availability. Do not
use `spaces.current_status` as the sole availability authority. Return identity,
location, type, capacity, facility information, and requested interval.
The example seed must include at least two distinct facilities from the Task 14
namespace (e.g. `T14 Projector` and `T14 Whiteboard`).

### Q3 - Approved hours per space

Parameters: `@semester_start`, `@semester_end`. Use the U4 window and confirmed,
non-deleted bookings. Include intervals overlapping the window and sum the requested
interval clipped to that window. Group by stable space identity and return decimal
hours in deterministic order. Do not substitute actual session duration unless a
new approved decision explicitly changes U4 semantics.

### Q4 - Approved bookings by weekday/hour

Parameters: `@semester_start`, `@semester_end`. Use the same U4 window, confirmed
statuses, and soft-delete filter. Add `SET DATEFIRST 1` in this block or use an
equivalent deterministic expression. Group by weekday number and the hour of
`requested_start_time`; return weekday label/number, hour, booking count, and
optionally distinct-space count. Do not group by localized weekday text alone.

### Q5 - Bookings affected by escalation

Join non-deleted `maintenance_impact_history` rows where
`prior_level = 'advisory'` and `new_level = 'out-of-service'` to the affected
maintenance and confirmed, non-deleted bookings using the standard overlap test.
Join `booking_advisory_acknowledgement` on the booking/maintenance pair. Do not
require the maintenance's current impact level to remain out-of-service; history
must preserve the escalation event. Return escalation history/time, maintenance,
space, booking, requester/contact, interval, and an action/status field. Report
already-approved/confirmed bookings only; never mutate or cancel bookings.

## Safe collaboration modes

### Overwrite

Requires explicit `--mode overwrite`. Re-read current sources and write the
requested canonical query set. Never silently replace an existing student's file.
If the set is partial, report the missing IDs for later append.

### Append

Requires an existing output and explicit `--mode append`. Before writing:

1. Parse existing `task16-query-id` markers and reject duplicate Q IDs.
2. Reject duplicate titles or semantically duplicate query ownership submissions.
3. Verify the existing file ends at a `GO` batch boundary.
4. Preserve all existing query blocks and ownership metadata; do not renumber or
   reformat them.
5. Append only the requested new canonical blocks, each ending in `GO`.
6. Re-run whole-file validation.

If `--mode` is omitted while the output exists, ask exactly:

> Output file exists. Append new Task 16 queries or overwrite the entire file?

Recommended split: first contribution appends Q1, Q2, Q3, and Q5; the other
contributor appends Q4. Q3/Q4 still require the U4 gate.

## Validation and verification

Before reporting, confirm:

- Q1-Q5 markers are unique and each block ends with `GO`.
- Append did not alter earlier blocks; requested IDs are present.
- Q1 has confirmed overlap logic; Q2 checks **every facility** in the table
  variable (the example must seed **at least two** rows) and both availability
  sources; Q3/Q4 share U4 semantics; Q4 weekday numbering is
  deterministic; Q5 reads escalation history rather than current level only.
- No schema/index/procedure/trigger/concurrency DDL or Task 15 measurements exist.
- The SQL is compiled/run only on a scratch database with Tasks 05/10 and Task 14
  data. Record results under `logs/eval/task16/` and trajectory under
  `logs/trajectory/task16/` for an actual generation run. Do not create those logs
  for a tooling-only skill/command edit.

## Scope and handshake

Task 16 does not modify registries, schema, Task 14, Task 15, or concurrency
artifacts. Do not update `memory/Progress.md` or `memory/ActiveContext.md` before
user approval. After an actual generation run, report query IDs, assumptions,
validation, and blockers, then end exactly with:

> _"Ready to mark Task 16 as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_
