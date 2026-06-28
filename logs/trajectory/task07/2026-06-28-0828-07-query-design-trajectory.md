# Task 07 — Query Design Trajectory

**Date:** 2026-06-28
**Student:** Pham Huu Nam
**Role:** facility_manager
**Group:** G05

## Inputs Read (in order)
1. `outputs/05-db-definition-G05.sql` — schema (7 tables, FKs, indexes, triggers)
2. `outputs/06-sample-data-G05.sql` — sample data (rejected booking 8, resolved maintenance on space 6, no-show booking 4, completed booking 3, various space types with bookings)
3. `req/business-requirement.md` — business questions
4. `outputs/01-business-req-analysis-G05.md` — business context and BRs

## Plan
- Mode: append (explicitly specified by user)
- 5 facility_manager queries (five separate invocations):
  1. Query 6 — Rejected booking audit trail for a professor (audit/accountability)
  2. Query 7 — Risk profile: spaces with recent resolved maintenance + upcoming bookings (analytics/maintenance)
  3. Query 8 — Department no-show rate analysis for the semester (analytics/no-show)
  4. Query 9 — Cumulative usage hours for requesters competing for same space/slot (fair allocation)
  5. Query 10 — Room-type utilization summary for the semester (analytics/reporting)

## Generation
Queries 6–10 appended to `outputs/07-query-design-G05.sql`.

## Verification
- SQL Server not available for live execution in this environment.
- Syntax verified via manual review against the DDL schema.
- Log: `logs/eval/task07/2026-06-28-0828-07-query-compile.log`

## Assumptions
- Query 6: @requester_id = 2 corresponds to Prof. Robert Chen (lecturer) per seed data.
- Query 7: GETDATE() returns 2026-06-28 for the 7-day lookahead.
- Query 8: Semester window 2026-06-01 to 2026-08-31; @threshold_pct = 0 shows all departments.
- Query 9: Contested slot defaults to space_id = 5 (T06-CL-101); overlap test uses standard interval logic.
- Query 10: "Successful approval rate" = approved/checked_in/completed as proportion of all non-cancelled requests; cancelled bookings excluded from denominator.
- All queries are parameterized; users can change DECLARE values to adjust filters/windows.
- Returns zero rows if no matching data exists — SQL logic is correct.

## Status
COMPLETED — awaiting user approval for Progress.md / ActiveContext.md update.
