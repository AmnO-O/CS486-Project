---
description: Run Task 15 - Phase 2 index tuning and query performance report for the Campus Space Management System.
---

# Task 15 command

Run `db-design-pipeline:15-index-tuning` to generate or revise
`outputs/15-index-tuning-report-G{{group}}.md`.

## Usage

```text
15-generate-index-tuning --group G05 --mode overwrite
15-generate-index-tuning --group G05 --mode revise
15-generate-index-tuning --group G05 --mode validate
15-generate-index-tuning --group G05 --mode overwrite --reports q3,q5
15-generate-index-tuning --group G05 --mode overwrite --check-sql
```

## Arguments

- `--group G05`: group identifier. Default: `G05`.
- `--mode overwrite|revise|validate`: write mode. Default: `overwrite`.
- `--reports q3,q4|q3,q5|q4,q5`: optional explicit pair of additional reports.
  If omitted, the agent selects two from Q3-Q5 after baseline measurements.
- `--check-sql`: use the configured scratch SQL Server for benchmark execution if
  available. Never infer a live database or mutate a named baseline.

## Prompt

Generate Task 15 index-tuning report for group `{{group}}`.

Required behavior:

1. Follow `AGENTS.md`, `docs/README.md`, the main pipeline skill, and the Task 15
   skill reading order.
2. Enforce task order and dependency gates: Task 14 approved, Task 16 approved,
   and any directly relevant Phase 2 open questions resolved.
3. Tune exactly four queries: mandatory Q1 booking conflict check, mandatory Q2
   room finder, and two selected reports from Q3-Q5.
4. If `--reports` is omitted, choose the two report queries with the highest
   measured baseline logical reads or cost, and record the evidence.
5. For measured runs, capture the execution-plan evidence bundle defined in the
   Task 15 skill: before/after estimated ShowPlan XML, normalized `.sqlplan`
   files, and a plan-summary table, plus `SET STATISTICS IO/TIME`. Mark the report
   static-only when SQL Server is unavailable.
6. Compare baseline and candidate runs on the same Task 14 dataset and the same
   query parameters. Use at least three runs and report the median.
7. Output recommendations and optional DDL snippets only. Do not apply index DDL
   to production.
8. Do not modify memory files before user approval. Create trajectory/evaluation
   logs only for an actual Task 15 generation or benchmark run, not tooling edits.

## Required output

- `outputs/15-index-tuning-report-G{{group}}.md`
- Actual run: `logs/eval/task15/<timestamp>-15-index-tuning-check.log`
- Actual run: `logs/trajectory/task15/<timestamp>-trajectory.md`

## Prohibitions

- Do not hard-code or blindly prescribe indexes before inspecting the current
  query plans and existing indexes.
- Do not tune a query other than Q1, Q2, and the selected two reports.
- Do not change query semantics, U4 semester windows, concurrency procedures,
  triggers, schema, Task 14 data, Task 16 SQL, or registry files.
- Do not benchmark against a live/named baseline.

## Handshake

End with:

> _"Ready to mark Task 15 as approved and update memory/Progress.md? Or do you want revisions?"_
