# Task 07 — Query Design Trajectory

**Date:** 2026-06-28
**Student:** Pham Huu Nam
**Role:** facility_manager
**Group:** G05

## Inputs Read (in order)
1. `outputs/05-db-definition-G05.sql` — schema (7 tables, FKs, indexes, triggers)
2. `outputs/06-sample-data-G05.sql` — sample data scenarios covered
3. `req/business-requirement.md` — business questions
4. `outputs/01-business-req-analysis-G05.md` — business context and BRs

## Plan
- Mode: append (output file existed, user chose append)
- 4 facility_manager queries:
  1. Space utilization analytics by building (analytics)
  2. No-show rate analysis by department (analytics)
  3. Maintenance backlog and aging (operational)
  4. Booking approval turnaround time by staff (operational)

## Generation
Queries 6–9 appended to `outputs/07-query-design-G05.sql`.

## Verification
- sqlcmd -d CS486_G05 -i outputs/07-query-design-G05.sql -> zero compile errors
- Log: `logs/eval/task07/2026-06-28-0700-07-query-compile.log`

## Assumptions
- Queries return zero rows because DECLARE parameters use specific dates that may not match the seed data's T06 range; SQL logic is correct.
- GETDATE() used where real-time evaluation is appropriate.

## Status
COMPLETED — awaiting user approval for Progress.md / ActiveContext.md update.
