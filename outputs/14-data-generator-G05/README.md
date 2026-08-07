# Task 14 - Data Generator (Phase 2), Group G05

Deterministic, stdlib-only Python generator for the migrated Phase 2 schema
(`outputs/10-schema-migration-G05.sql` on top of `outputs/05-db-definition-G05.sql`).
Produces one CSV per table, a bulk loader, and a verification script.

## Files

| File | Purpose |
|---|---|
| `generate.py` | Deterministic CSV generation. Standard library only. |
| `config.example.json` | Seed, volumes, calendar, status weights, output dir. |
| `load.sql` | SQL1-compatible `BULK INSERT` loader with explicit `KEEPIDENTITY` / `CHECK_CONSTRAINTS` / `BATCHSIZE`, plus the automatic Mode-A escalation-history slice. |
| `verify.sql` | G1-G8 acceptance checks, reviewer-runnable, no hardcoded row counts. |
| `requirements.txt` | Explicit stdlib-only note (no third-party dependency). |

Generated CSVs and `manifest.json` are written to `_generated/` (not committed; see
`.gitignore` policy below).

## Acceptance targets and measured evidence

All measurements below are from an actual run of `generate.py` against
`config.example.json` (seed `20260807`, 120,000 bookings) on this machine, verified
independently with a second Python script that recomputes the invariants directly
from the CSVs and through a live SQL Server load on `localhost\SQL1` (see
"Execution evidence").

| # | Target | Measured result |
|---|---|---|
| G1 | `bookings` between 100,000 and 500,000 | 120,000 - PASS |
| G2 | booking span >= 3 academic years | 2021-09-06 to 2025-06-21 = 1,384 days (>= 1,095) - PASS |
| G3 | both impact levels present; escalation produces history | advisory 1,396 / out-of-service 1,204 present in the bulk data; `maintenance_impact_history` is populated by the automatic Mode-A slice in `load.sql` (the AFTER-UPDATE trigger never fires from bulk-generated rows - see "Design decisions") |
| G4 | `cancelled`/`no_show` present in realistic proportion | cancelled 26,593 (22.2%), no_show 6,000 (5.0%), rejected 8,400 (7.0%) of 120,000 |
| G5 | every confirmed booking overlapping an active advisory has an ack | 0 NR2 violations (independent CSV check) |
| G6 | both instant and staff approval origins present | instant (`approver_id=-1`) 4,600 approved; staff 66,007 approved + 8,400 rejected |
| G7 | no two confirmed bookings overlap on one space | 0 overlap violations, 0 exact-start collisions (independent CSV check) |
| G8 | same seed reproduces the same dataset | two independent runs with the same seed produced byte-identical SHA-256 hashes for all 10 CSVs (both at 4,000-row smoke scale and at the full 120,000-row scale) |

## Mode A/B split

- **Mode B (bulk, ~120k rows):** `departments`, `users`, `spaces`, `facilities`,
  `space_facilities`, `maintenance`, `bookings`, `booking_approvals`,
  `booking_sessions`, `booking_advisory_acknowledgement`. The generator is
  single-threaded and owns the full booking schedule per space (a 30-minute slot
  occupancy set per `space_id`), so it satisfies BR1/NR6 by construction without
  needing the Task 12 applock - there is no concurrent writer. This is the
  documented single-threaded exception in the Task 14 skill (`14-data-generator/SKILL.md`,
  "Loading design").
- **Mode A (entry-point, small slice):** `maintenance_impact_history` is **not**
  emitted as CSV. `trg_maintenance_impact_history` is `AFTER UPDATE` only (Task 10),
  so ticket creation never produces history rows regardless of load path. `load.sql`
  automatically runs two `UPDATE dbo.maintenance SET impact_level = ...` statements
  (escalate then downgrade) on one T14-owned active advisory ticket, with
  `SESSION_CONTEXT('current_user_id')` set to a real `facility_manager` so
  `changed_by` is attributed correctly. This produces the escalation history
  required by G3/NR3 and gives Task 16 report #4 a non-empty case to query without a
  separate manual step.

## Why legacy BULK parsing instead of FORMAT='CSV'

The original loader used `BULK INSERT ... WITH (FORMAT='CSV', FIELDQUOTE='"')`.
On the project machine's `localhost\SQL1` instance, that path failed with SQL Server
error 7301 from the `BULK` provider before any row was imported. To make the artifact
portable for teammates, `generate.py` now emits delimiter-safe CSV text: generated
string values contain no embedded commas, tabs, CR/LF, or double quotes. `load.sql`
therefore uses SQL Server 2019-compatible legacy parsing:

```sql
FIELDTERMINATOR = ',',
ROWTERMINATOR = '0x0a'
```

This keeps the file extension and one-CSV-per-table contract while avoiding the
provider-specific `FORMAT='CSV'` failure.

## Why bulk load without FIRE_TRIGGERS

Every Phase 1/Phase 2 business rule in this schema (BR1, BR2, BR3, BR4, BR6-BR9,
BR15-BR18, NR1-NR3) lives in an `AFTER INSERT/UPDATE` trigger. `BULK INSERT` does not
fire insert triggers unless `FIRE_TRIGGERS` is specified
(learn.microsoft.com/sql/t-sql/statements/bulk-insert-transact-sql). Firing triggers
on a 120k-row bulk load means any single rejected row (`RAISERROR` + `ROLLBACK
TRANSACTION`) aborts its whole batch, and the generator already guarantees BR1/BR3/
BR4/NR2 by construction (see "Correctness rests on the generator" below). `load.sql`
therefore omits `FIRE_TRIGGERS` and instead:

- passes `KEEPIDENTITY` on every load so identity FKs resolve correctly;
- passes `CHECK_CONSTRAINTS` so CHECK/FK constraints ARE validated during the bulk
  operation (this is the one flag that does not require `FIRE_TRIGGERS`);
- uses `BATCHSIZE=20000` so a bad batch does not roll back already-committed rows;
- documents in `verify.sql` (V10/V11) how to confirm CHECK/FK constraints are
  trusted after load, with a scratch-DB-only `WITH CHECK CHECK CONSTRAINT ALL`
  remediation if they are not.

## Correctness rests on the generator (bulk path), not on triggers

Because `bookings`/`booking_approvals`/`booking_sessions` are bulk-loaded without
`FIRE_TRIGGERS`:

- `bookings.status` is written directly by the generator (not derived from
  `trg_booking_approvals_decision`); the generator's own status/approval/session
  rows are kept mutually consistent (an `approved`/`checked_in`/`completed` booking
  always has a matching `booking_approvals` row with `decision='approved'`).
- BR1/NR6 (no confirmed overlap) is enforced by the generator's per-space slot
  occupancy bookkeeping, not by `trg_bookings_prevent_overlap` /
  `uq_bookings_active_overlap` (those remain in place as defense-in-depth and will
  also reject any real, trigger-fired write later).
- BR4 (no confirmed booking over an active out-of-service window) and NR2 (ack
  completeness for confirmed bookings over active advisories) are enforced by the
  generator's maintenance-aware scheduling, not by
  `trg_bookings_check_maintenance` / `trg_booking_approvals_check_space`.
- `verify.sql` (V2-V4) independently re-checks all three invariants against the
  loaded data, so the claim above is falsifiable rather than assumed.

`load.sql`'s Mode-A escalation slice (the two `UPDATE ... impact_level` statements)
runs as plain DML, not through a Task 12 stored procedure, so it does not exercise
the applock. That is intentional: it is a data-shape requirement (G3/NR3/report #4),
not a concurrency demonstration. Task 13 owns the concurrency proof.

## Reserved system user and other non-negotiable facts honored

- `user_id = -1` is never generated here; it is seeded by
  `outputs/10-schema-migration-G05.sql`. `load.sql` fails fast
  (`OBJECT_ID` checks) if the Phase 2 migration has not been applied, and the
  generator's own natural keys (`t14.*@campus.edu`, `T14-*`, `T14 *`) never collide
  with it.
- `maintenance.impact_level` is written explicitly on every row (never relies on
  the column default).
- Acknowledgement rows are loaded (`BULK INSERT ... booking_advisory_acknowledgement`)
  before approval rows, matching the Task 11 sequencing contract.
- All natural keys are namespaced `T14-*` / `T14 *` / `t14.*@campus.edu` so this
  dataset can coexist with the Task 06 sample data (`T06-*`) in the same database.
  IDs are pre-assigned starting at `id_base + offset` (default `id_base = 200000`),
  which is well above the Task 06 row counts, and `KEEPIDENTITY` preserves them.

## How to run

```powershell
# 1. Generate CSVs (full scale, ~120,000 bookings, ~45-55s on this machine)
python generate.py --config config.example.json

# Optional: a fast, reduced-scale smoke run for local testing (below the G1 floor,
# clearly out of acceptance scope - --smoke is required to bypass the floor check)
python generate.py --config config.example.json --out _smoke --bookings 4000 --smoke

# 2. Load into a SCRATCH SQL Server 2019+ database that already has Tasks 05 + 10 applied.
# PowerShell form is shown because paths often contain spaces.
sqlcmd -S <server> -d <scratch_db> -E -C -I -v CSV_ROOT = "<absolute path to _generated>" -i load.sql

# 3. Verify
sqlcmd -S <server> -d <scratch_db> -E -C -I -i verify.sql
```

## Run/restart/coexistence policy

- **Clean-room by default.** `load.sql` does not delete or touch Task 06 rows; the
  T14 natural-key/ID namespace keeps the two datasets disjoint in the same database.
- **Not append-safe.** Re-running `load.sql` against a database that already has a
  prior T14 load will violate the UNIQUE constraints on `users.email`,
  `spaces.space_code`, `facilities.name`, and `departments.name` (bulk load enforces
  UNIQUE/PK even without `CHECK_CONSTRAINTS`). Load into a fresh scratch database, or
  truncate the 11 tables in reverse FK order first.
- **Restartability within one load:** `BATCHSIZE=20000` on every `BULK INSERT` means
  a mid-batch failure rolls back only that batch; already-committed batches for that
  table stay loaded. Re-running the same `BULK INSERT` statement after fixing the
  cause will attempt to re-insert already-loaded batches and hit the PK/UNIQUE
  constraints - restart per-table loads against a table that was fully truncated,
  not a partially loaded one.

## Assumptions (record per the Task 14 skill)

- A09/A14-1: booking durations are drawn from a discrete 30-minute-aligned slot grid
  (1h/1.5h/2h/3h), even though `requested_start_time`/`requested_end_time` are free
  `DATETIME2` values in the schema. This is a generator-side simplification, not a
  schema property, and it is what makes the O(1)-per-slot conflict bookkeeping exact.
- A14-2: `impact_level` distribution (55% advisory / 45% out-of-service target,
  measured 53.7%/46.3% on the seeded run) and resolved-vs-open maintenance mix
  (62% target) are generator defaults tunable in `config.example.json`; the Phase 2
  description does not specify exact proportions.
- A14-3: the four academic years in `config.example.json` (`AY2021-2022` through
  `AY2024-2025`) are a generator-chosen calendar, not a resolution of Task 16's open
  question U4 (semester reporting window). The dataset spans four academic years so
  that the >= 3-academic-year requirement (G2) holds with margin even though summer
  breaks between years reduce the confirmed-booking-bearing day count; no semester
  boundary is hard-coded into the row shapes themselves.
- A14-4: `expected_participants` is drawn uniformly up to `spaces.capacity`, which
  can occasionally produce a very low headcount for a very large room; this is
  accepted as within-BR3 realistic variance, not a defect.
- A14-5: generated free-text values are delimiter-safe (commas become semicolons;
  tabs/newlines are collapsed to spaces) so SQL Server's legacy `BULK INSERT`
  parser can load the CSVs on machines where `FORMAT='CSV'` is unavailable or
  provider-broken. This changes punctuation only, not the schema or lifecycle
  distribution.

## Execution evidence

Environment: Python 3.12 and `sqlcmd` 16 are available. Live SQL Server validation
was run against `localhost\SQL1` (`CS486_G05`) after dropping/recreating the scratch
database and applying Tasks 05 + 10. Evidence gathered:

1. **Static checks:** `generate.py` parses as valid Python AST; `config.example.json`
   parses as valid JSON with `counts.bookings` inside `[100000, 500000]`.
2. **Smoke run (4,000 bookings, `--smoke`):** completed in under a second; produced
   all 10 CSVs plus `manifest.json`.
3. **Full run (120,000 bookings, default config):** completed in ~45-55 seconds;
   `manifest.json` recorded span `2021-09-06` to `2025-06-21` and
   `confirmed_count` = 64,607 of 120,000.
4. **Reproducibility (G8):** two independent full runs and two independent smoke
   runs, same seed, produced byte-identical SHA-256 hashes for all 10 CSV files in
   every comparison.
5. **Independent invariant check:** a separate, hand-written Python script (not part
   of the delivered generator) re-derived G1, G2, G7 (overlap self-join), the exact
   filtered-unique-index collision check, BR4 (booking vs. out-of-service overlap),
   NR2 (ack completeness vs. active advisories), no-show-with-session, and
   no-show-without-approved-decision directly from the generated CSVs, independently
   of `generate.py`'s own bookkeeping. All checks passed with zero violations.
6. **Live SQL Server load:** `load.sql` was executed against `localhost\SQL1` after
   Tasks 05 + 10. The loader imported all 10 CSVs and automatically created two
   `maintenance_impact_history` rows through the Mode-A escalation/downgrade slice.
7. **Live SQL Server verification:** `verify.sql` completed successfully. Final
   invariant counts were zero for confirmed booking overlaps, confirmed booking vs.
   active out-of-service maintenance, missing advisory acknowledgements,
   no-show-with-session, no-show-without-approved-decision, untrusted CHECK
   constraints, and untrusted foreign keys.
