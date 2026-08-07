# Task 14 Validation and Completion

Read before writing `verify.sql`, the evaluation log, or the trajectory. Keep SQL
checks reviewer-runnable and free of hardcoded row counts.

## Acceptance matrix

| ID | Required proof |
|---|---|
| G1 | `bookings` count is >= 100000 and <= 500000 |
| G2 | booking dates span >= three academic years |
| G3 | both maintenance impact levels exist; impact changes produce history |
| G4 | cancelled and no_show bookings exist in realistic, documented proportions |
| G5 | every confirmed booking overlapping every active advisory has an acknowledgement |
| G6 | both instant (`approver_id=-1`) and staff approval origins exist |
| G7 | no overlapping non-deleted confirmed bookings share a space |
| G8 | same seed/config reproduces the same generated output |

## SQL checks

`verify.sql` must include equivalent checks against current names and statuses:

1. Count and min/max booking timestamps.
2. Self-join for confirmed interval overlap; expected zero rows.
3. Join confirmed bookings to active `out-of-service` maintenance; expected zero rows.
4. Join confirmed bookings to active overlapping advisories and anti-join acknowledgements;
   expected zero rows.
5. Grouped status, impact-level, approval-origin, history, and acknowledgement counts.
6. No-show rows without a booking session; expected no missing session rows.
7. Invalid or untrusted CHECK/FK constraints after bulk load, when bulk options bypassed
   them; use catalog inspection plus `WITH CHECK CHECK CONSTRAINT ALL` only on a scratch DB.
8. Optional duplicate exact-start check as a direct explanation of the filtered unique
   index contract.

Checks that return violations must fail the verification run or be clearly marked
`FAIL`; informational distributions must be labeled separately.

## Static checks

Before declaring the task complete:

- All six required output files exist and are non-empty.
- `generate.py` parses with Python 3 and has no unseeded random source.
- `config.example.json` parses; booking target is within 100000..500000.
- `requirements.txt` pins every non-stdlib dependency.
- `load.sql` has explicit FK order, identity, batch, constraint, and trigger decisions.
- `verify.sql` contains G1-G8 coverage and does not depend on Task 16's semester answer.
- No schema DDL, origin column, index tuning, analytical query, or Task 13 test folder
  was added.
- Generated CSVs are excluded or explicitly documented as local artifacts.

## Execution evidence

Prefer this order:

1. Static validation.
2. Small deterministic generator smoke run in a temporary output directory.
3. Compare hashes/row counts from two same-seed smoke runs.
4. Compile/run `load.sql` and `verify.sql` only on a scratch SQL Server database.
5. Record unavailable Python packages, SQL Server, `sqlcmd`, or driver as blockers.

Do not claim live database validation when only static checks ran.

## Trajectory

Write one new file under `logs/trajectory/task14/` after the artifact directory is
finalized. Record actual reads/writes/checks, assumptions, blocked execution, and any
self-detected fix. The user-facing summary must include the exact Task 14 handshake
from the Task 14 skill. Do not update memory before approval.
