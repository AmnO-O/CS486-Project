---
name: 14-data-generator
description: >
  Generate, revise, or validate the Phase 2 Task 14 data-generator deliverable for
  the CS486 G05 Campus Space Management System: a reproducible generator producing
  >=3 academic years and 100,000-500,000 bookings with maintenance impact levels,
  escalation history, cancellations, no-shows, instant/staff approvals, and advisory
  acknowledgements. Use when the user runs /generate-data-generator or asks about the
  Task 14 directory, generate.py, load.sql, verify.sql, dataset volume/seed/realism,
  or bulk loading the generated dataset into SQL Server.
---

# Task 14 - Data Generator (Phase 2)

## Goal

Produce `outputs/14-data-generator-G{{group}}/`: a deterministic generator whose
dataset is large, realistic, and **provably legal** against the migrated Phase 2
schema. Task 14 writes data, never schema. Task 15 and Task 16 consume this dataset,
so reproducibility is part of the deliverable, not a nicety.

## Authority and reading policy

This skill plus its `references/` are the **complete normative instructions** for
Task 14. Detailed material lives in the references; load a reference only when the
active workflow needs it, and do not pull unrelated project files by reflex.

| Need | Read |
|---|---|
| Source priority, gates, `rg` extraction patterns, external citation register | `references/source-map.md` |
| Bulk-load mechanics, volumes, time model, realism detail | `references/schema-and-loading.md` |
| Full validation SQL, static checks, failure-mode checklist, trajectory | `references/validation-and-completion.md` |

Never load `logs/`, `node_modules/`, `.git/`, or generated CSV files. In large SQL and
Markdown sources, use `rg -n` and read only the matched blocks.

## Acceptance targets

| # | Target | Basis |
|---|---|---|
| G1 | `bookings` rows >= 100,000, <= 500,000 | Phase 2 description section 2 |
| G2 | booking span >= 3 academic years | Phase 2 description section 2 |
| G3 | both impact levels present; escalations recorded in the impact-history table | Phase 2 section 1.1, NR1/NR3 |
| G4 | `cancelled` and `no_show` present in a documented realistic proportion | Phase 2 §2 |
| G5 | every confirmed booking overlapping an active advisory has its acknowledgement | Phase 2 section 1.1, NR2 |
| G6 | both approval origins present: instant (`approver_id = -1`) and staff | Task 09 Area 2 / NR5 |
| G7 | no two non-deleted confirmed bookings overlap on one space | BR1 / NR6 |
| G8 | same seed and config reproduce the same dataset | reproducibility |

## Source-of-truth order

1. `docs/project_phase2_description.md` - volume, span, required contents.
2. `docs/design-decisions.md` - recorded decisions; never contradict.
3. `outputs/10-schema-migration-G{{group}}.sql` - deployed Phase 2 objects and triggers.
4. `outputs/05-db-definition-G{{group}}.sql` - Phase 1 baseline and remaining triggers.
5. `outputs/11-concurrency-design-G{{group}}.md` and
   `outputs/12-concurrency-implementation-G{{group}}.sql` - write entry points and codes.
6. `docs/schema-registry.md`, then `docs/entity-registry.md`.
7. `docs/tech-stack.md` - SQL Server 2019+, T-SQL, naming.

Inherited hard rule from Task 06: never change the schema to make data fit. On any
conflict between sources, stop and report the exact paths and facts.

## Output contract

```text
outputs/14-data-generator-G{{group}}/
  README.md            # gates, volumes, seed, distributions, Mode A/B split, run + restart policy
  config.example.json  # seed, counts, date span, weights, batch size, output dir
  generate.py          # deterministic generation -> one CSV per table
  load.sql             # bulk load: FK order, KEEPIDENTITY, BATCHSIZE, trigger decision
  verify.sql           # G1-G8 / V1-V6 checks
  requirements.txt     # pinned dependencies, or an explicit stdlib-only note
logs/eval/task14/<YYYY-MM-DD-HHmm>-14-data-generator-check.log
logs/trajectory/task14/<YYYY-MM-DD-HHmm>-trajectory.md
```

Keep bulky CSV output out of Git; commit the generator and config instead.

## Schema the generator must satisfy

Nine Phase 1 tables plus two Phase 2 tables. Current FK order:

```text
departments -> users -> spaces -> facilities -> space_facilities
            -> maintenance -> bookings -> booking_approvals -> booking_sessions
            -> maintenance_impact_history -> booking_advisory_acknowledgement
```

Re-derive the order from the actual FKs if the schema has changed.

## Non-negotiable data facts

These are the traps that make a plausible-looking generator produce a dataset the
project's own triggers reject. Verify each against the current migration before use.

- **Reserved system user.** `users.user_id = -1` (System Booking Service,
  `system@campus.edu`, `facility_manager`) is seeded by the Task 10 migration via
  `SET IDENTITY_INSERT`. Never recreate it; use it as the approver for every instant
  approval. Origin is derived from `approver_id = -1`; there is no origin column,
  because a stored one was rejected for 3NF reasons. Reports must exclude `-1` from
  real-user aggregations.
- Task 09 v2.6 / Task 10 v5 baseline: `spaces.usage_policy` and `spaces.max_hours` are
  absent, while `space_type_allowed_purpose` is a migration-owned reference table seeded
  by Task 10. Task 14 must not generate or populate that table.
- Instant approvals are legal only when `(space_type, purpose)` exists in
  `space_type_allowed_purpose`; the generator and `verify.sql` must both check this.
- **`maintenance.impact_level` is `NOT NULL DEFAULT 'out-of-service'`.** Any INSERT
  omitting it silently creates a blocking ticket. Always pass it explicitly.
- **Advisory acknowledgement is a gate, not decoration.**
  `trg_booking_approvals_check_space` rejects an `approved` decision while any
  overlapping active advisory lacks its acknowledgement row. Insert acknowledgements
  **before** the approval row.
- **Acknowledgement correspondence is validated.**
  `trg_booking_advisory_ack_validate` requires the referenced maintenance to be
  active, `advisory`, and time-overlapping the booking's requested window. Random
  `(booking, maintenance)` pairs fail.
- **`UQ_booking_advisory_ack_booking_maintenance`** is one composite UNIQUE over
  `(booking_id, maintenance_id)`. Many acknowledgements per booking are fine;
  duplicates of the same pair are not.
- **`uq_bookings_active_overlap`** is a filtered unique index on
  `(space_id, requested_start_time)` for confirmed, non-deleted rows. Two confirmed
  bookings sharing an exact start time on one space fail even when the intervals
  would otherwise be legal.
- **Status is trigger-driven, not free-form.** `trg_booking_approvals_decision` sets
  `bookings.status` from the decision; the check-in trigger sets `checked_in`; the
  completion trigger sets `completed` and requires `final_condition`; cancellation is
  allowed only from `pending`/`approved`.
- **Role gates.** Approver must be `facility_staff`/`facility_manager` (BR15),
  check-in staff likewise (BR16), maintenance assignee `facility_staff` (BR17).
- **`no_show` shape.** An approval exists, the window has passed, and no
  `booking_sessions` row exists.
- **Impact history is `AFTER UPDATE` only.** Ticket creation produces no history row;
  only a level change on an active ticket does. Produce escalation history by updating
  `impact_level`, never by inserting history rows directly.
- **Attribution.** `changed_by` reads `SESSION_CONTEXT(N'current_user_id')` and falls
  back to `-1`. For realistic attribution, set it via `sys.sp_set_session_context` per
  unit of work and clear it afterwards.
- **Capacity.** `expected_participants` must not exceed `spaces.capacity` (BR3).

## Loading design

Choose and document the split; mixing is intentional:

| Mode | Use | Trade-off |
|---|---|---|
| A - entry point | A few hundred/thousand behavior proofs: instant/staff booking, escalation/downgrade, maintenance report | Slow; exercises applocks, triggers, result codes, and audit behavior |
| B - bulk | Roughly 100k historical rows | Fast; correctness rests on deterministic generator bookkeeping plus post-load checks |

A single-threaded generator may use Mode B because it owns the schedule and emits no
confirmed overlap. A multi-threaded generator must partition by `space_id` or use Mode
A; never let two workers mutate one space's confirmed interval state independently.
Record the split and reason in `README.md`.

Recommended mechanism: Python -> one CSV per table -> `BULK INSERT` or `bcp` with
explicit `KEEPIDENTITY`, chosen `BATCHSIZE`, and an explicit `FIRE_TRIGGERS` decision.
Bulk paths do not fire insert triggers by default. Without `FIRE_TRIGGERS`, booking
statuses and trigger-based BR1/BR3/BR4 checks are bypassed; without
`CHECK_CONSTRAINTS`, CHECK/FK constraints may be untrusted. The loader must either
fire triggers and tolerate batch rollback, or document generator-side enforcement and
run independent post-load validation. Never claim trigger enforcement when it was
bypassed.

Use pre-assigned IDs plus `KEEPIDENTITY` consistently, or load parents and resolve
natural keys explicitly. `BATCHSIZE` gives restartable batch transactions. Do not use
SQL Server 2022-only `GENERATE_SERIES`; the target is SQL Server 2019+.

## Realistic generation model

Use a table-count configuration within these guide ranges, adapting to current schema:

| Table | Suggested volume |
|---|---:|
| departments | 6-10 |
| users | 1,000-5,000, including staff/managers and inactive/suspended accounts |
| spaces | 50-300 across all six current space types |
| facilities | 6-15 |
| space_facilities | 2-6 per space; positive/NULL quantity variation |
| maintenance | a few thousand; both impacts, open/in-progress/resolved, some soft-deleted |

Time model:

- Cover at least three academic years, split into semester-like segments without
  resolving Task 16's U4.
- Bookings mainly Monday-Saturday, about 07:00-18:00, with term-start submission
  spikes for realistic contention and index/report skew.
- Use clean discrete slots (e.g. 1h, 1.5h, 2h, 3h) as a generator assumption only;
  the schema permits arbitrary `DATETIME2` intervals.
- Vary capacity, facilities, weekdays, and hours enough for the room finder and reports.
- Include at least one escalation with overlapping approved bookings for Task 16 NR4.

Lifecycle model:

- Convert documented target weights into actual statuses: `pending`, `approved`,
  `rejected`, `cancelled`, `checked_in`, `completed`, `no_show`.
- Advisory acknowledgement is orthogonal, not a lifecycle percentage. Every confirmed
  booking overlapping every active advisory gets an acknowledgement, whether it later
  completes, cancels, or becomes no-show.
- Keep per-space confirmed intervals. Confirmed candidates must be disjoint and use a
  unique start time; `pending`, `rejected`, and `cancelled` rows may overlap to model
  demand. Never confirm over active out-of-service maintenance.
- Faker and NumPy are optional. If used, pin versions and seed them explicitly:
  Faker patch versions can alter output; NumPy RNGs are deterministic only with an
  explicit seed. A standard-library-only generator is acceptable and often cheaper.

## Required verification

`verify.sql` must be reviewer-runnable and fail or clearly flag violations. Include:

- **V1/G1-G2:** booking count, minimum start, maximum end, and three-year span.
- **V2/G7/BR1-NR6:** self-join confirmed non-deleted bookings by space and interval;
  expected zero rows.
- **V3/BR4:** confirmed bookings overlapping active non-deleted `out-of-service`
  maintenance; expected zero rows.
- **V4/NR2:** confirmed bookings overlapping active advisories without matching ack;
  expected zero rows.
- **V5/G3-G6:** grouped booking statuses, maintenance impact/status, derived approval
  origins, history count, and acknowledgement count.
- **V5f/NR5:** instant approvals map only to seeded `(space_type, purpose)` pairs and
  the Task 09 v2.6 schema state is intact (`space_type_allowed_purpose` exists, while
  `spaces.usage_policy` and `spaces.max_hours` do not).
- **V6:** `no_show` rows without a session; expected zero rows.
- Constraint trust/catalog checks if bulk load omitted `CHECK_CONSTRAINTS`, plus a
  scratch-DB-only `WITH CHECK CHECK CONSTRAINT ALL` remediation instruction.

Do not use fixed expected counts. Distributions are informational; invariants are pass/fail.

## Implementation workflow

1. Read gate sources and build a compact inventory of actual tables, columns, FKs,
   identity behavior, status transitions, triggers, indexes, system row, and approved
   entry points.
2. Choose Mode A/B, seed policy, volumes, date bounds, output directory, and clean/
   append/restart policy; record assumptions in README/config.
3. Generate parents before children, explicit IDs when using `KEEPIDENTITY`, and legal
   lifecycle rows. Keep CSVs local and deterministic.
4. Write the six artifacts. Keep `load.sql` and `verify.sql` SQL Server 2019-compatible.
5. Run static checks. If Python is available, run a small smoke configuration and two
   same-seed runs; compare hashes, headers, counts, and no generated CSV commitment.
6. Run `sqlcmd` only against a scratch database if available. Never load Task 14 into a
   live/named baseline without explicit user direction; never silently delete Task 06.
7. Write `logs/eval/task14/...` and then `logs/trajectory/task14/...` before reporting.

## Out of scope

Do not implement Task 12 procedures, Task 13 concurrent-session tests, Task 15 index
measurements, Task 16 analytical queries, schema changes, or a stored approval-origin
column. Do not copy GPL generator code into the repository. External generator projects
in the guide are patterns only, not dependencies.

## Completion handshake

Report completed files, assumptions, validation, and blockers. Then prompt exactly:

> _"Ready to mark Task 14 as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

## Guide coverage map

The former implementation guide's 11 sections are represented without verbatim duplication:

| Former guide section | Task 14 instruction location |
|---|---|
| 1 acceptance/output | Acceptance targets + Output contract |
| 2 source priority | Source-of-truth order + `references/source-map.md` |
| 3 schema/FK/traps | Schema order + Non-negotiable data facts |
| 4 Mode A/B | Loading design |
| 5 SQL Server bulk behavior | Loading design + `references/schema-and-loading.md` |
| 6 volumes/time/lifecycle/text RNG | Realistic generation model |
| 7 V1-V6 validation | Required verification + `references/validation-and-completion.md` |
| 8 reproducibility/layout | Output contract + Implementation workflow |
| 9 citations/projects/papers | Technical choices preserved below; no external code dependency |
| 10 failure modes | Non-negotiable data facts + validation reference |
| 11 Task 15/16 handoff | Acceptance targets, realistic model, and scope boundaries |

The illustrative starting sketch is `smooth 60%`, `instant 10%`, `no-show 5%`,
`cancelled/rejected 15%`, `advisory acknowledgement 10%`. Treat it as configurable
initial guidance, not a requirement: acknowledgement is orthogonal to lifecycle, so
never spend a mutually-exclusive lifecycle percentage on it.

## Technical choices preserved from the reviewed design

Supported bulk choices are `bcp`, `BULK INSERT`, `OPENROWSET(BULK...)`, and
`SqlBulkCopy`; choose one and document why. `BULK INSERT`/`bcp`/`SqlBulkCopy` do not
fire insert triggers unless their explicit trigger option is selected. If Python writes
directly, `pyodbc` requires `fast_executemany=True` for the documented batch path. If a
.NET implementation is selected, use `Microsoft.Data.SqlClient`, not deprecated
`System.Data.SqlClient`. The generator must not depend on SQL Server 2022-only
`GENERATE_SERIES`.

External generator projects and papers are background patterns only:
do not copy GPL code, add unpinned dependencies, or let non-project domain schemas
override the project source priority. Their role belongs in README provenance only when
actually used.



