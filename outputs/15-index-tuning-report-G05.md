# Task 15 - Index Tuning Report

## 1. Environment & Dataset

- Scratch database: `CS486_G05_T14`
- SQL Server instance: `LAPTOP-J7QNDDFO\SQL1` (`sqlcmd -S .\SQL1`)
- SQL Server version: SQL Server 2022, `16.0.1190.2`
- Authentication: Windows Authentication (`-E`); login `LAPTOP-J7QNDDFO\quocthang`
- Task 14 booking count: `120,000`
- Dataset date span: `2021-09-06` through `2025-06-21` (four academic years)
- Task 14 verification result: approved; G1-G8 / V1-V11 passed with zero invariant violations
- Benchmark mode: `measured`
- Cache protocol: `DBCC FREEPROCCACHE; DBCC DROPCLEANBUFFERS; SET STATISTICS IO ON; SET STATISTICS TIME ON; SET STATISTICS XML ON`
- Repetitions: three baseline runs and three candidate runs per query; median reported
- Query parameters:
  - Q1: `space_id = 205111`, proposed interval `[2021-09-06 11:00, 12:00)`
  - Q2: `[2024-09-16 10:00, 12:00)`, capacity `20`, required facilities `T14 Projector` + `T14 Whiteboard`
  - Q3: Semester 1 AY2024-2025, `[2024-09-01, 2025-02-01)`
  - Q5: all escalation-history events present in the Task 14 load

The candidate indexes were created only in the scratch database for the after-index
measurements. No Task 10 DDL, registry, or production database was changed.

## 2. Query Selection

Mandatory targets: Q1 booking conflict check and Q2 room finder.

The two additional reports selected were Q3 and Q5. Q4 was not selected because the
Task 15 fixed target set permits two reports from Q3-Q5, and Q3/Q5 gave the strongest
measured tuning opportunity: Q3 scans the confirmed booking history for a semester;
Q5 joins the approval history to the large booking and acknowledgement populations.

| Query | Baseline logical reads | Baseline CPU ms | Baseline elapsed ms | Selection reason |
|---|---:|---:|---:|---|
| Q3 | 1,269 user-table reads | 32 | 51 | Semester aggregation reads the confirmed booking history |
| Q5 | 16,100 user-table reads | 78 | 220 | Highest reporting cost; approval/booking/ack joins |

Logical-read totals exclude worktables/table-variable pages. Per-table reads are shown
in each section so the comparison remains auditable.

### 2.1 Execution Plan Evidence

Estimated Showplan XML artifacts were captured before and after candidate indexing.
The runtime metrics above remain the actual measured IO/time results; the plan
evidence below shows the access-path change that produced those metrics.

| Query | Before plan file | After plan file | Before hash | After hash | Cost delta | Main plan shift |
|---|---|---|---|---|---:|---|
| Q1 | `logs/eval/task15/plans/q1-before.sqlplan` | `logs/eval/task15/plans/q1-after.sqlplan` | `0x24B5326A72F36CA7` | `0x0A21C726B5C1C4FB` | -0.029571 | `Hash Match` removed; filtered booking seek used |
| Q2 | `logs/eval/task15/plans/q2-before.sqlplan` | `logs/eval/task15/plans/q2-after.sqlplan` | `0x9FE5ED624C086A79` | `0x08208FFCD3415A7B` | -0.618138 | active maintenance scan replaced by filtered maintenance seek |
| Q3 | `logs/eval/task15/plans/q3-before.sqlplan` | `logs/eval/task15/plans/q3-after.sqlplan` | `0xB061942267FAA70F` | `0x297D42516A74A491` | -1.229912 | filtered confirmed-booking seek replaced a broad scan |
| Q5 | `logs/eval/task15/plans/q5-before.sqlplan` | `logs/eval/task15/plans/q5-after.sqlplan` | `0x61AF3367616520B9` | `0xFA124FEA4E55386F` | -0.081248 | shared booking overlap path improved; approval side stayed largely unchanged |

The `.sqlplan` files are stored under `logs/eval/task15/plans/` and can be opened
directly in SQL Server Management Studio for reviewer audit.

## 3. Q1 - Booking Conflict Check

### 3.1 Baseline measurements

| Metric | Run 1 | Run 2 | Run 3 | Median |
|---|---:|---:|---:|---:|
| Logical reads: `bookings` | 13 | 13 | 13 | 13 |
| Logical reads: `users` | 8 | 8 | 8 | 8 |
| Logical reads: `spaces` | 2 | 2 | 2 | 2 |
| User-table logical reads | 23 | 23 | 23 | 23 |
| Physical reads: `bookings` | 8 | 8 | 8 | 8 |
| CPU ms | 0 | 0 | 0 | 0 |
| Elapsed ms | 6 | 7 | 6 | 6 |

### 3.2 Plan analysis

- Existing relevant indexes: `idx_bookings_space_id`, `idx_bookings_time_range`,
  `idx_bookings_requested_start`, and filtered unique
  `uq_bookings_active_overlap (space_id, requested_start_time)`.
- The existing `idx_bookings_time_range` has the correct leading equality key and
  supports the start-time portion of the half-open overlap predicate, but it is not
  filtered to confirmed, non-deleted rows and does not cover the returned requester/
  status/purpose columns.
- Baseline reads were already small for this selective single-space parameter. The
  after-plan used the new filtered covering access path and reduced `bookings` reads
  from 13 to 4. The `users` and `spaces` joins remained stable.
- Estimated/actual row counts were stable: two conflicting rows returned in all runs.
  The benchmark is a selective point check, so elapsed time is more sensitive to cache,
  scheduler, and compile noise than logical reads.

### 3.3 Candidate index

```sql
-- Candidate only; applied in CS486_G05_T14 for measurement.
CREATE NONCLUSTERED INDEX idx_bookings_confirmed_space_time_cover
ON dbo.bookings (space_id, requested_start_time, requested_end_time)
INCLUDE (requester_id, status, purpose, expected_participants)
WHERE is_deleted = 0
  AND status IN ('approved', 'checked_in', 'completed');
```

- Candidate name: `idx_bookings_confirmed_space_time_cover`
- Key columns/order: `(space_id, requested_start_time, requested_end_time)`
- Included columns: `requester_id, status, purpose, expected_participants`
- Filter predicate: confirmed statuses and `is_deleted = 0`
- Expected benefit: narrower confirmed-booking access path; fewer residual rows and
  fewer lookups for the Q1 projection
- Cost: additional filtered index maintenance for confirmed-booking inserts/status
  transitions; overlaps remain a residual interval predicate, not a native range type

### 3.4 Comparison after candidate

| Metric | Baseline median | Candidate median | Delta | Delta % |
|---|---:|---:|---:|---:|
| `bookings` logical reads | 13 | 4 | -9 | -69.2% |
| User-table logical reads | 23 | 14 | -9 | -39.1% |
| CPU ms | 0 | 0 | 0 | n/a at 1 ms resolution |
| Elapsed ms | 6 | 3 | -3 | -50.0% |

Plan change: the filtered candidate became the narrower confirmed-booking access path;
remaining `users`/`spaces` lookups stayed unchanged. The exact overlap predicate still
requires residual evaluation.

### 3.5 Recommendation

**Adopt, subject to reviewer approval.** The candidate reduces the hot-path booking
reads and halves median elapsed time in this run. Keep `uq_bookings_active_overlap`
and the Task 11 concurrency lock design; this index is an access-path optimization,
not a replacement for correctness enforcement.

## 4. Q2 - Room Finder

### 4.1 Baseline measurements

| Metric | Run 1 | Run 2 | Run 3 | Median |
|---|---:|---:|---:|---:|
| `bookings` logical reads | 120 | 120 | 120 | 120 |
| `maintenance` logical reads | 1,107 | 1,107 | 1,107 | 1,107 |
| `space_facilities` logical reads | 274 | 274 | 274 | 274 |
| `facilities` logical reads | 345 | 345 | 345 | 345 |
| `spaces` logical reads | 212 | 212 | 212 | 212 |
| User-table logical reads | 2,058 | 2,058 | 2,058 | 2,058 |
| CPU ms | 63 | 78 | 78 | 78 |
| Elapsed ms | 84 | 94 | 90 | 90 |

### 4.2 Plan analysis

- Existing relevant indexes: `idx_bookings_time_range`, `idx_bookings_status`,
  `idx_maintenance_space_id`, `idx_maintenance_status`, clustered
  `PK_space_facilities (space_id, facility_id)`, and
  `idx_space_facilities_facility_id`.
- The relational-division branch tests two required facilities (`T14 Projector` and
  `T14 Whiteboard`) through the nested `NOT EXISTS` predicate. The clustered junction
  key `(space_id, facility_id)` and existing `idx_space_facilities_facility_id`
  remained adequate; `space_facilities` reads stayed at 274 and `facilities` reads
  at 345. No facility-bridge index was adopted from this workload.
- On the corrected two-facility workload, the dominant baseline cost was the active
  out-of-service maintenance scan at 1,107 logical reads, followed by the confirmed
  booking conflict input at 120 reads. The filtered maintenance time index reduced
  maintenance reads to 172.
- The filtered booking time-window index changed booking reads from 120 to 236 for
  this parameter set, a small read increase, while the maintenance reduction drove
  the end-to-end improvement. The result set remained one available space in all runs.

### 4.3 Candidate indexes

```sql
-- Candidate only; applied in CS486_G05_T14 for measurement.
CREATE NONCLUSTERED INDEX idx_bookings_confirmed_time_window
ON dbo.bookings (requested_start_time, requested_end_time, space_id)
WHERE is_deleted = 0
  AND status IN ('approved', 'checked_in', 'completed');

CREATE NONCLUSTERED INDEX idx_maintenance_oos_time_window
ON dbo.maintenance (start_time, completion_time, space_id)
WHERE is_deleted = 0
  AND status IN ('open', 'in_progress')
  AND impact_level = 'out-of-service';
```

- `idx_bookings_confirmed_time_window`: supports the time-window conflict CTE;
  `space_id` is included as a trailing key for the distinct result.
- `idx_maintenance_oos_time_window`: narrows the exact blocking maintenance subset
  before applying the half-open completion predicate.
- No new facility bridge index is recommended from this run. The existing clustered
  `(space_id, facility_id)` key and `idx_space_facilities_facility_id` are adequate for
  the tested two-facility relational division. Wider facility lists and different
  facility selectivities should be tested before final adoption.
- Cost: two more filtered indexes to maintain on booking/maintenance changes.

### 4.4 Comparison after candidate

| Metric | Baseline median | Candidate median | Delta | Delta % |
|---|---:|---:|---:|---:|
| `bookings` logical reads | 120 | 236 | +116 | +96.7% |
| `maintenance` logical reads | 1,107 | 172 | -935 | -84.5% |
| User-table logical reads | 2,058 | 1,239 | -819 | -39.8% |
| CPU ms | 78 | 15 | -63 | -80.8% |
| Elapsed ms | 90 | 15 | -75 | -83.3% |

Plan change: maintenance changed from a broad active-maintenance scan pattern to a
filtered time-window access path. The booking branch used the filtered time-window
index but read slightly more pages for this selective window; the end-to-end result
was still materially better because maintenance was the dominant baseline cost.

### 4.5 Recommendation

**Adopt the maintenance candidate for Q2.** It cut median elapsed time by 83.3%
(from 90 ms to 15 ms) and reduced total user-table reads by 39.8% (from 2,058 to
1,239) on the corrected two-facility workload. The maintenance candidate was the
primary driver — it eliminated the dominant baseline scan. The booking time-window
candidate caused a small Q2-only read increase for this selective window, so Q2 alone
does not justify it; retain it in the overall adoption list because Q3 gives the
strong measured win. Do not add a facility-bridge index based on this run; the
existing junction index paths were adequate for the two-facility relational division.

## 5. Report A - Q3: Approved Booking Hours per Space

### 5.1 Baseline measurements

| Metric | Run 1 | Run 2 | Run 3 | Median |
|---|---:|---:|---:|---:|
| `bookings` logical reads | 1,263 | 1,263 | 1,263 | 1,263 |
| `spaces` logical reads | 6 | 6 | 6 | 6 |
| User-table logical reads | 1,269 | 1,269 | 1,269 | 1,269 |
| CPU ms | 32 | 47 | 15 | 32 |
| Elapsed ms | 53 | 51 | 48 | 51 |

### 5.2 Plan analysis

- Existing indexes include `idx_bookings_requested_start`, but the query has both
  half-open interval predicates and the confirmed/non-deleted filter.
- The baseline scanned substantially more booking pages than the candidate. The
  semester window is selective enough for a filtered start/end access path to help,
  while the final aggregation still reads all qualifying rows.
- Q3 returned 120 spaces and 901 qualifying confirmed booking intervals for the
  selected U4 window; result cardinality was stable.

### 5.3 Candidate index

```sql
-- Candidate only; applied in CS486_G05_T14 for measurement.
CREATE NONCLUSTERED INDEX idx_bookings_confirmed_time_window
ON dbo.bookings (requested_start_time, requested_end_time, space_id)
WHERE is_deleted = 0
  AND status IN ('approved', 'checked_in', 'completed');
```

This is the same candidate used for Q2. Reusing one index avoids duplicating nearly
identical access paths. The key order seeks the semester start boundary first; the end
predicate remains residual. For Q2's corrected two-facility workload the booking index
showed a small read increase, but Q3's semester-wide scan benefits more clearly from
the filtered confirmed-booking access path.

### 5.4 Comparison after candidate

| Metric | Baseline median | Candidate median | Delta | Delta % |
|---|---:|---:|---:|---:|
| `bookings` logical reads | 1,263 | 238 | -1,025 | -81.2% |
| User-table logical reads | 1,269 | 244 | -1,025 | -80.8% |
| CPU ms | 32 | 16 | -16 | -50.0% |
| Elapsed ms | 51 | 20 | -31 | -60.8% |

Plan change: the confirmed filtered time-window access path reduced the booking input
from 1,263 to 238 logical reads; the small `spaces` side remained stable.

### 5.5 Recommendation

**Adopt.** Q3 is the strongest clean win: 81.2% fewer booking reads and 60.8% lower
median elapsed time with unchanged U4 semantics and unchanged result cardinality.

## 6. Report B - Q5: Confirmed Bookings Affected by Escalation

### 6.1 Baseline measurements

| Metric | Run 1 | Run 2 | Run 3 | Median |
|---|---:|---:|---:|---:|
| `booking_approvals` logical reads | 4,915 | 4,985 | 4,915 | 4,915 |
| `bookings` logical reads | 3,321 | 3,321 | 3,322 | 3,321 |
| `booking_advisory_acknowledgement` logical reads | 2,620 | 2,620 | 2,620 | 2,620 |
| `users` logical reads | 3,930 | 3,930 | 3,930 | 3,930 |
| `spaces` logical reads | 1,310 | 1,310 | 1,310 | 1,310 |
| User-table logical reads | 16,100 | 16,100 | 16,101 | 16,100 |
| CPU ms | 78 | 109 | 78 | 78 |
| Elapsed ms | 220 | 240 | 218 | 220 |

### 6.2 Plan analysis

- Existing indexes: unique `UQ_booking_approvals_booking_id`,
  `idx_booking_approvals_approver_id`, composite unique acknowledgement index
  `(booking_id, maintenance_id)`, and `idx_booking_advisory_ack_maintenance`.
- The Q5 join is driven by escalation history, then approval time, space/time overlap,
  acknowledgement pair, and requester/contact joins. The existing approval indexes do
  not support `decision = 'approved'` plus `decision_time <= escalation_time`.
- The candidate approved-time index did not materially reduce approval reads in this
  loaded distribution, but the booking overlap candidate reduced `bookings` reads from
  about 3,321 to 10. This produced a moderate end-to-end improvement because users and
  acknowledgement joins remain dominant.
- Q5 returned the same affected-booking result set in all before/after runs; the Task 16
  execution evidence reports 655 affected confirmed bookings with zero duplicate
  `(history_id, booking_id)` pairs.

### 6.3 Candidate index

```sql
-- Candidate only; applied in CS486_G05_T14 for measurement.
CREATE NONCLUSTERED INDEX idx_booking_approvals_approved_time
ON dbo.booking_approvals (decision_time, booking_id)
WHERE decision = 'approved';

-- Shared with Q1/Q2/Q3; especially effective for the Q5 overlap join.
CREATE NONCLUSTERED INDEX idx_bookings_confirmed_space_time_cover
ON dbo.bookings (space_id, requested_start_time, requested_end_time)
INCLUDE (requester_id, status, purpose, expected_participants)
WHERE is_deleted = 0
  AND status IN ('approved', 'checked_in', 'completed');
```

- The approved-time index is a targeted candidate for the approval-side temporal join.
- The shared booking candidate provides the space/time overlap seek and enough booking
  columns for the Q5 projection before requester lookup.
- The existing acknowledgement unique index remains the main pair lookup path; no new
  acknowledgement index is recommended from the measured result.
- Cost: two filtered indexes. The approval candidate should be re-tested with a larger
  history table because this Task 14 load has only two escalation-history rows.

### 6.4 Comparison after candidate

| Metric | Baseline median | Candidate median | Delta | Delta % |
|---|---:|---:|---:|---:|
| `bookings` logical reads | 3,321 | 10 | -3,311 | -99.7% |
| `booking_approvals` logical reads | 4,915 | 4,913 | -2 | -0.0% |
| User-table logical reads | 16,100 | 12,787 | -3,313 | -20.6% |
| CPU ms | 78 | 78 | 0 | 0.0% |
| Elapsed ms | 220 | 187 | -33 | -15.0% |

Plan change: the booking overlap join uses the filtered space/time candidate; approval
access remains approximately unchanged because the history input is tiny and the
approval predicate is not selective enough in this dataset.

### 6.5 Recommendation

**Adopt the shared booking candidate. Defer the approval-time candidate.** The shared
index gives a clear read reduction and moderate elapsed-time gain. The approval index
is structurally reasonable but not empirically beneficial here; re-test after the system
accumulates a materially larger `booking_approvals`/history population before adopting.

## 7. Summary & Adoption Table

| Query | Candidate index | Baseline median reads | Candidate median reads | CPU/elapsed result | Decision |
|---|---|---:|---:|---|---|
| Q1 | `idx_bookings_confirmed_space_time_cover` | 23 | 14 | 0/6 ms -> 0/3 ms | Adopt |
| Q2 | `idx_bookings_confirmed_time_window` + `idx_maintenance_oos_time_window` | 2,058 | 1,239 | 78/90 ms -> 15/15 ms | Adopt maintenance; retain booking via Q3 |
| Q3 | `idx_bookings_confirmed_time_window` | 1,269 | 244 | 32/51 ms -> 16/20 ms | Adopt |
| Q5 | shared `idx_bookings_confirmed_space_time_cover` + `idx_booking_approvals_approved_time` | 16,100 | 12,787 | 78/220 ms -> 78/187 ms | Adopt shared booking; defer approval |

Recommended adoption list, subject to reviewer approval:

1. `idx_bookings_confirmed_space_time_cover`
2. `idx_bookings_confirmed_time_window`
3. `idx_maintenance_oos_time_window`

Deferred candidate:

- `idx_booking_approvals_approved_time` — retain as a documented candidate, not an
  immediate production recommendation.

## 8. Limitations & Notes

- The benchmark used the real Task 14 scratch database and Windows Authentication on
  `LAPTOP-J7QNDDFO\SQL1`, not a static simulation.
- `DBCC DROPCLEANBUFFERS` and `DBCC FREEPROCCACHE` ran successfully; the server printed
  the standard DBCC completion message. Timing remains subject to compile, scheduler,
  and concurrent-host noise.
- Estimated Showplan XML (`SET SHOWPLAN_XML ON`) was captured before and after
  indexing under `logs/eval/task15/plans/`. The text report summarizes the
  operator/access-path change and leaves the full XML in the `.sqlplan` files.
- Q1 is intentionally selective; logical reads are more reliable than sub-10 ms elapsed
  differences.
- Q2 uses two required facilities (`T14 Projector` + `T14 Whiteboard`) and the
  nested relational-division predicate. The bridge path stayed stable at 274 reads.
  Wider facility lists and different facility selectivities should be tested before
  final adoption.
- Q5 has only two escalation-history rows in the Task 14 load. The approval-time
  index needs a larger-history test before adoption.
- U4 semantics are unchanged: Q3 uses `[2024-09-01, 2025-02-01)`, clips overlapping
  booking durations, and counts confirmed statuses `approved`, `checked_in`, and
  `completed`; soft-deleted bookings are excluded.
- Existing Task 10 / Task 11 indexes and concurrency objects were preserved. This report
  recommends indexes only; it does not modify `docs/schema-registry.md` or production
  DDL.
- Evidence summary: `logs/eval/task15/2026-08-08-1150-15-index-tuning-q2-revision-check.log`; the original Q1/Q3/Q5 evidence remains under `logs/eval/task15/2026-08-08-1035-15-index-tuning-check.log`. Raw per-run Q2 files were temporary and removed after verification.
