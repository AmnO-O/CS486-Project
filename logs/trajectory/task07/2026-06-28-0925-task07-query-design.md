# Task 07 — Query Design Trajectory

**Date:** 2026-06-28  
**Student:** Pham Huu Nam  
**Target user(s):** facility_manager  
**Mode:** append (1 query added to existing file)

## Inputs read
- `outputs/05-db-definition-G05.sql` — schema & constraints
- `outputs/06-sample-data-G05.sql` — existing seed data
- `req/business-requirement.md` — business context
- `outputs/01-business-req-analysis-G05.md` — fallback context
- `outputs/07-query-design-G05.sql` — existing queries 1–8 (by Nguyen Huu Phuoc and Pham Huu Nam)

## Query generated
**Query 9** — Competitor usage analysis for fair allocation

- **Business question:** When multiple students submit competing booking requests for the same meeting room and time slot, how many cumulative hours has each requester actually used university shared spaces during the current month?
- **Parameters:** @target_space_id, @slot_start, @slot_end
- **Logic:**
  1. CTE `competing_requesters` — finds distinct user_ids with pending/approved bookings overlapping the contested slot
  2. CTE `monthly_usage` — sums actual usage minutes (completed/checked-in bookings) for each competing requester in the current month
  3. Final SELECT — joins user/department info, orders by ascending cumulative hours (fairness: least-used first)
- **Key design choices:**
  - Filters by space_id (surrogate key) per skill guidance
  - Uses DATEDIFF(MINUTE) with CASE for status-aware duration calculation
  - Avoids COALESCE(actual_end_time, requested_end_time) pitfall noted in skill
  - Orders NULLS last via CASE expression (SQL Server limitation)
  - Respects `is_deleted = 0` on all booking queries

## Compilation
- Target database: CS486_G05 (SQL Server 2022, TCP)
- Full file compiled: exit code 0, no errors
- Query 9 returns 0 rows (no competing pending/approved bookings in seed data — expected and documented)

## Verification output
`logs/eval/task07/2026-06-28-0925-07-query-compile.log`
