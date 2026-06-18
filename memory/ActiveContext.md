---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
metadata:
  type: project
---

## Current task
Task 05 — DDL Generation ✅ *(completed 2026-06-18)*

## Status
- Task 05 output: `outputs/05-db-definition-G05.sql` ✅ (2026-06-18 — Regenerated, compiled and verified on SQL Server)
- Design decision: 3 FKs changed from SET NULL to NO ACTION (SQL Server cascade path limitation), documented in `docs/design-decisions.md`
- Compile verification: `logs/eval/task05/2026-06-18-0911-05-ddl-compile.log` ✅
- Trajectory: `logs/trajectory/task05/2026-06-18-0911-trajectory.md` ✅

## Verification summary
- 7 tables created (departments, users, spaces, facilities, space_facilities, bookings, maintenance)
- 10 foreign keys (all FK actions per schema-registry + design-decisions: 2 CASCADE, 8 NO ACTION)
- 13 CHECK constraints (including D3-D5 deferred checks from validation)
- 9 triggers (BR1-BR9 enforcement + Q3 auto space-status on maintenance completion)
- 26 indexes (7 clustered PK, 4 unique, 15 nonclustered)
- Filtered unique index `uq_bookings_active_overlap` with WHERE clause verified

## Blocking issues
- ⏳ **SCHEMA FREEZE pending group approval** — still outstanding

## Notes from last session
- DDL compiled successfully on first attempt — clean run after database drop/recreate
- All 9 triggers, 10 FKs, 13 CHECK constraints, 26 indexes verified on SQL Server
- Minor CHECK constraints (D3-D5) from validation report included: `CK__space_facilities__quantity`, `CK__bookings__actual_time_order`, `CK__maintenance__completion_time`

## Next steps
1. Proceed to Task 06 — Sample Data generation (`generate-data --group G05`)
2. Await group approval for SCHEMA FREEZE (pending)
