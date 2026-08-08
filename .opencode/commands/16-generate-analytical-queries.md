---
description: Run Task 16 - Phase 2 analytical queries for the Campus Space Management System.
---

# Task 16 command

Run `db-design-pipeline:16-analytical-queries` to create, append, revise, or
validate `outputs/16-analytical-queries-G{{group}}.sql`.

This command is the invocation interface. The Task 16 skill contains the source
priority, query contracts, U4 gate, append safety rules, and validation checklist.

## Usage

```text
16-generate-analytical-queries --group G05 --mode overwrite --query-set all 
16-generate-analytical-queries --group G05 --mode overwrite --query-set booking-conflict,room-finder,approved-booking-hours,affected-by-escalation
16-generate-analytical-queries --group G05 --mode append --query-set weekday-hour
16-generate-analytical-queries --group G05 --mode append --query-set q4 --target-users facility_manager
16-generate-analytical-queries --group G05 --mode validate
```

## Arguments

- `--group G05`: group identifier. Default: `G05`.
- `--mode <mode>`: required when the output already exists.
  - `overwrite`: explicitly replace the complete Task 16 file.
  - `append`: preserve all existing query blocks and add only new query IDs.
  - `validate`: read-only whole-file validation; never writes the output.
  - If omitted while the output exists, stop and ask:
    `Output file exists. Append new Task 16 queries or overwrite the entire file?`
- `--query-set <set>`: comma-separated query IDs or aliases. Default: `all` for
  overwrite; default: `weekday-hour` for append when the existing file contains
  Q1, Q2, Q3, and Q5.
- `--target-users <roles>`: comma-separated target roles for new blocks. Use only
  roles from the current requirements and tech stack. The agent may select a more
  specific subset per query.
- Task 15 selection: no Task 16 flag is provided. Task 15 always tunes Q1 and Q2,
  then selects two additional reporting queries after reviewing Q3-Q5.
- `--semester-start <datetime>` and `--semester-end <datetime>`: optional values
  for Q3/Q4 parameter defaults only after U4 has been resolved. They do not resolve
  U4 themselves. The decision must already be recorded in memory and
  `docs/design-decisions.md`.
- `--check-sql`: after generation, compile/run on the configured scratch SQL Server
  target if available; never use a live baseline implicitly.

## Query-set aliases

| Alias | Canonical ID | Meaning |
|---|---|---|
| `q1`, `booking-conflict`, `conflict-check` | Q1 | Booking conflict check |
| `q2`, `room-finder`, `available-spaces` | Q2 | Capacity + facilities + time room finder |
| `q3`, `approved-booking-hours`, `booking-hours` | Q3 | Total approved hours per space/semester |
| `q4`, `weekday-hour`, `approved-weekday-hour` | Q4 | Approved bookings by weekday/hour/semester |
| `q5`, `affected-by-escalation`, `escalation-impact` | Q5 | Approved bookings affected by escalation |
| `all` | Q1-Q5 | All five canonical blocks |

The aliases `booking-conflict`, `room-finder`, `approved-booking-hours`, and
`affected-by-escalation` match the first contributor's planned query set. The
remaining `weekday-hour` block can be appended by another contributor without
rewriting those four blocks.

## Prompt

Generate Task 16 analytical queries for the Campus Space Management System, group
`{{group}}`, using mode `{{mode}}` and query set `{{query_set}}`.

Required behavior:

1. Follow `AGENTS.md`, `docs/README.md`, the main pipeline skill, and the Task 16
   skill reading order.
2. Enforce strict Phase 2 ordering and the Task 14 dependency.
3. Check `memory/Progress.md` for directly relevant pending questions before writing.
   U4 blocks Q3/Q4 until the group resolves the semester window.
4. Read the current migrated schema, approved concurrency contract, and Task 14
   handoff. Do not invent columns or rely on stale Task 07 semantics.
5. In `overwrite`, write only the requested canonical blocks and leave explicit
   missing-query notes in the generation summary when the set is partial.
6. In `append`, preserve existing blocks byte-for-byte semantically, reject duplicate
   Q IDs/titles, append complete `GO`-terminated blocks, and validate the whole file.
7. Use the exact Q1-Q5 contracts from the skill.
8. Do not edit upstream outputs, registries, Task 14 artifacts, Task 15 artifacts,
   or memory files. Do not create trajectory/eval logs for a tooling-only edit.
9. On an actual generation run, create the Task 16 eval log and trajectory before
   reporting completion.

## Required output

- `outputs/16-analytical-queries-G{{group}}.sql`
- Actual generation only: `logs/eval/task16/<timestamp>-16-analytical-queries-check.log`
- Actual generation only: `logs/trajectory/task16/<timestamp>-trajectory.md`

## Ownership handoff

Recommended first contribution:

```text
--mode overwrite
--query-set booking-conflict,room-finder,approved-booking-hours,affected-by-escalation
```

Recommended follow-up contribution:

```text
--mode append
--query-set weekday-hour
```

The follow-up must preserve Q1, Q2, Q3, and Q5 exactly, then append Q4. Query
ownership is recorded in each block's `-- owner:` metadata only.

## Prohibitions

- Do not silently overwrite an existing student's queries.
- Do not treat Task 14's academic-year labels as the semester definition.
- Do not generate Q3/Q4 while U4 is pending.
- Do not add `approval_source` or any other schema column.
- Do not write indexes, stored procedures, concurrency code, or Task 15 results.
- Do not update `memory/Progress.md` or `memory/ActiveContext.md` before the user
  approves Task 16.

## Handshake

After a real Task 16 generation run, end exactly with:

> _"Ready to mark Task 16 as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_



