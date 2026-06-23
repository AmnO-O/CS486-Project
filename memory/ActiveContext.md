---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
---

## Current task
Task 06 — Sample Data ✅ *(completed 2026-06-22)*

## Status
- Task 06 output: `outputs/06-sample-data-G05.sql` (1077 lines) ✅
- Execution evidence: `logs/execution/task06/2026-06-22-0948-output.txt` ✅
- Evaluation report: `logs/eval/task06/2026-06-22-0951-eval.md` ✅ (score 5.00/5.00)
- Task 05 DDL: `outputs/05-db-definition-G05.sql` (schema frozen, used as Task 06 base) 

## Verification summary
- **7 data sections** in FK-safe order: departments → users → spaces → facilities → space_facilities → maintenances → bookings
- **9 spaces** covering all 5 space statuses (available, temporarily_closed, retired, under_maintenance, in_use)
- **11 valid bookings** covering 7 booking statuses (pending, approved, checked_in, completed, no_show, rejected, cancelled) + soft-deleted
- **5 maintenance records** covering all 3 maintenance statuses (open, in_progress, resolved) + soft-deleted
- **8 users** covering all 6 roles across 3 account statuses
- **13 expected-error (ECASE) tests** in TRY/CATCH blocks covering: BR1 overlap, BR2 unavailable space (3 variants), BR3 capacity, BR4 maintenance overlap, BR6 approval metadata, BR7 rejection reason, BR8/BR9 check-in/completion fields, duplicate email, invalid enum, invalid time range
- **13 verification queries** — row counts, enum distributions, audit timestamps, soft-delete, future bookings, maintenance, no-show, booking history
- **Idempotent** — cleanup-and-reseed strategy via T06- prefix + reverse-FK-order DELETE
- **Top eval recommendations:** (1) include common reads in trajectory; (2) run third execution to prove idempotence; (3) note ECASE 7-10 pending orphan rows in assumptions

## Blocking issues
- None — SCHEMA FREEZE approved (Task 06 dependant on it, already executed)

## Next steps
1. Proceed to Task 07 — Query Design (`generate-queries --group G05`)
2. Review top improvements from eval report (idempotence proof, trajectory completeness, ECASE orphan documentation)