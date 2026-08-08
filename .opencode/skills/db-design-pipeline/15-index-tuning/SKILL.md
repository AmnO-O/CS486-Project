---
name: 15-index-tuning
description: >
  Generate the Task 15 index-tuning report for CS486 G05. Covers the booking
  conflict check (Q1), room finder (Q2), and two selected reporting queries.
  Use when the user runs /generate-index-tuning or asks about Task 15, index
  tuning, execution plan comparison, or query performance for the Campus Space
  Management System.
---

# Task 15 - Index Tuning Report (Phase 2)

## Goal

Generate `outputs/15-index-tuning-report-G05.md`, a reviewer-ready report that
identifies, proposes, and empirically validates index candidates for Q1, Q2, and
two selected reporting queries from Q3-Q5. The agent produces a **recommendation
report** — not a DDL migration script — and must not silently edit registries
or Task 10 DDL.

## Authority and reading policy

| Need | Read |
|---|---|
| Scope, gates, output contract, report skeleton | This skill |
| Phase 2 requirement, task order, deliverables | `docs/project_phase2_description.md` §1.3 |
| U4 semester semantics | `docs/design-decisions.md` §U4 |
| Confirmed Q1-Q5 implementations | `outputs/16-analytical-queries-G05.sql` and Task 16 approved status |
| Current schema, existing indexes, triggers | `docs/schema-registry.md`, `docs/design-decisions.md` §Index |
| Task 11 existing base indexes | `outputs/11-concurrency-design-G05.md` §4.5 |
| Task 14 dataset contract | `outputs/14-data-generator-G05/README.md`, `verify.sql` |
| Benchmark integrity | `.opencode/skills/db-design-pipeline/14-data-generator/references/validation-and-completion.md` |

Never load CSV files, logs, or unrelated task outputs. Use `rg -n` to extract
specific blocks from large sources.

## Gates (stop if not met)

1. Task 14 is approved in `memory/Progress.md` and its dataset is loadable.
2. Task 16 is approved in `memory/Progress.md`
3. No directly relevant Phase 2 open question is pending for Task 15.

   | Open Q | Blocks if | |
   |---|---|---|
   | U1-U5 | All resolved | ✅ |
   | Task 11 incomplete | Q1/Q2 concurrency contract or base indexes unavailable | Stop; do not benchmark the concurrency path from stale assumptions |

4. Do NOT update `memory/Progress.md`, `memory/ActiveContext.md`, or registries
   before user approval.

## Fixed query targets

Task 15 must tune exactly four query IDs:

| Priority | Query ID | Source | Reason for tuning |
|---|---|---|---|
| Required | Q1 | `outputs/16-analytical-queries-G05.sql` and Task 16 approved status block Q1 | BR1/NR6 critical path; overlap check frequency under concurrency |
| Required | Q2 | `outputs/16-analytical-queries-G05.sql` and Task 16 approved status block Q2 | Multi-way join + relational division; facility filter + availability predicates |
| Select 2 | Q3 | `outputs/16-analytical-queries-G05.sql` and Task 16 approved status block Q3 | Semester hours aggregation; U4 window semantics |
| Select 2 | Q5 | `outputs/16-analytical-queries-G05.sql` and Task 16 approved status block Q5 | Multi-table join with escalation history |

The agent selects two from Q3/Q4/Q5. The selection criterion is **highest
observed logical reads or estimated cost on the generated dataset** (i.e. which
two reports most need tuning). The chosen pair and the rationale must appear
in the report.

## Benchmark methodology

### 15.1 Benchmark environment

- Target: Task 14 dataset loaded into a clean scratch SQL Server database
  (Tasks 05 + 10 + 14 applied).
- `SET NOCOUNT ON`.
- `DBCC DROPCLEANBUFFERS` before each timed run (requires `sysadmin`; document
  if unavailable).
- `DBCC FREEPROCCACHE` before each timed run (same caveat).
- `SET STATISTICS IO ON; SET STATISTICS TIME ON;` capture for every run.
- For measured runs, capture the estimated ShowPlan XML for each before/after
  query phase, then normalize it into `.sqlplan` files under
  `logs/eval/task15/plans/`.
- Repeat the timed run at least **3 times** and report the median.
- If SQL Server is unavailable, run static analysis only (execution plan,
  missing-index suggestions, predicate analysis) and clearly label the report
  as static-only.

### 15.1.1 Execution plan evidence

- Keep one before/after estimated ShowPlan XML file pair for each tuned query:
  Q1, Q2, and the two selected reports.
- Produce `logs/eval/task15/plans/plan-summary.md` with query id, phase, plan
  hash, root operator, subtree cost, estimated rows, and main plan shift.
- Reference the `.sqlplan` files and `plan-summary.md` in a dedicated
  `## 2.1 Execution Plan Evidence` section in the report.

### 15.2 Per-query measurement protocol

For each of the four tuned queries (Q1, Q2, and the two selected reports):

**Step A — Baseline (existing indexes only).**
Run the query with its default parameters against the loaded Task 14 dataset.
Record: logical reads, physical reads, CPU time (ms), elapsed time (ms),
estimated rows, actual rows, and the actual execution plan XML (or plan hash).

**Step B — Candidate index design.**
Analyze the baseline plan to identify:
- Table/page scans on large tables (bookings, maintenance, space_facilities).
- Key lookups that add material cost.
- Predicate pushdown quality.
- Sort operations introduced by GROUP BY or JOIN.
- Missing-index DMF suggestions (accept only if they address the above).
- The Task 11 base indexes listed in `outputs/11-concurrency-design-G05.md`
  §4.5: do not propose indexes that replicate them; propose only new or
  modified covering indexes.

Propose one or more candidate indexes per query using the existing naming
convention (`idx_<table>_<columns>`). For each candidate state:
- Table and key columns (ordered for seeks, included for covering).
- Index type (NONCLUSTERED; filtered if a filter predicate applies).
- Justification: which plan operator does it eliminate or improve?

**Step C — Apply candidate and re-measure.**
Apply the candidate index. Re-run Steps A with the same parameters.
Record the same metrics.

**Step D — Comparison.**
Present a table comparing baseline vs. candidate: logical reads, CPU, elapsed,
plan difference (seek vs. scan, key lookup eliminated, sort removed).

**Step E — Recommendation.**
State whether to adopt, modify, or reject each candidate. If no candidate
improves metrics meaningfully, say so and explain why the existing indexes are
adequate.

### 15.3 Q1 overlap analysis

The overlap logic in Q1 uses:
```sql
@slot_start < b.requested_end_time AND @slot_end > b.requested_start_time
```
with `space_id` filter and status `(approved, checked_in, completed)` +
`is_deleted = 0`.

Existing index: `idx_bookings_time_range (space_id, requested_start_time, requested_end_time)`.

The report must analyze whether this composite is sufficient as-is for the
half-open overlap predicate, or whether an alternative key order (e.g.
`(space_id, requested_end_time, requested_start_time)` or a filtered index)
would reduce the index range scanned.

### 15.4 Q2 facility-division analysis

Q2 uses `NOT EXISTS` for relational division (every facility present) plus
two `DISTINCT` CTE overlap subqueries (booking + maintenance conflicts) with
`current_status NOT IN ('retired', 'temporarily_closed')`.

Existing indexes cover each individual join. The report must analyze whether
a covering index on `space_facilities (facility_id, space_id)` or
`space_facilities (space_id, facility_id)` would reduce the division scan cost.

## Report skeleton

```
# Task 15 - Index Tuning Report
## 1. Environment & Dataset
  - Task 14 dataset: record counts from verify.sql output
  - Benchmark environment description
  - SQL Server version / availability
## 2. Query Selection
  - Q1 and Q2 are mandatory
  - Two chosen from Q3/Q4/Q5 + justification (attach measured metrics)
## 2.1 Execution Plan Evidence
  - Before/after `.sqlplan` files for Q1, Q2, and the selected reports
  - `logs/eval/task15/plans/plan-summary.md`
  - Plan hash, root operator, subtree cost, estimated rows, main plan shift
## 3. Q1 — Booking Conflict Check
  - 3.1 Baseline measurements
  - 3.2 Plan analysis
  - 3.3 Candidate index(es)
  - 3.4 Comparison after candidate applied
  - 3.5 Recommendation
## 4. Q2 — Room Finder
  [same 5 subsections]
## 5. Report A — [chosen first report]
  [same 5 subsections]
## 6. Report B — [chosen second report]
  [same 5 subsections]
## 7. Summary & Adoption Table
  - Per-query: baseline metrics | candidate metrics | delta | adopt/reject
  - Total index adoption list with DDL snippets
## 8. Limitations & Notes
  - Static-only if SQL Server unavailable
  - U4 semester parameters used
  - Task 11 base indexes preserved
```

## Naming and format rules

- Index name: `idx_<table>_<column(s)>`
- No space in column list; use underscores.
- Include `INCLUDE` columns in backtick inline: `idx_bookings_q1_cover` on
  `(space_id, requested_start_time, requested_end_time) INCLUDE (requester_id, status)`.
- Report in Markdown; tables for metrics; fenced code blocks for DDL.
- Do not generate DDL that alters Task 10 schema or drops existing indexes.
- The report output is a **recommendation**, not an applied migration.
  The decision to adopt falls to the reviewer.

## Scope boundaries

- Do NOT implement Task 14 generator changes.
- Do NOT implement Task 12 concurrency procedures.
- Do NOT implement Task 16 analytical queries.
- Do NOT modify `docs/schema-registry.md`, `docs/entity-registry.md`,
  `docs/design-decisions.md`, or any `outputs/05-*.sql` / `outputs/10-*.sql`.
- Do NOT add indexes to the registry without explicit reviewer approval.
- Do NOT run benchmarks on a live/named production database.

## Completion handshake

Report: chosen Q3/Q4/Q5 pair + rationale, assumptions, benchmark availability,
and any gaps. Then end exactly with:

> _"Ready to mark Task 15 as approved and update memory/Progress.md? Or do you want revisions?"_
