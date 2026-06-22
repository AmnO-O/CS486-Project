---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
metadata:
  type: project
---

## Current task
Task 05 — DDL Generation ✅ *(regenerated 2026-06-20)*

## Status
- Task 05 output: `outputs/05-db-definition-G05.sql` ✅ (2026-06-20 — Regenerated from scratch, compiled and verified on SQL Server)
- Design decision: `maintenances.assigned_staff_id` kept as `SET NULL` (only 1 cascade FK to users from maintenances — no SQL Server cascade path conflict)
- Compile verification: `logs/eval/task05/2026-06-20-0330-05-ddl-compile.log` ✅

## Verification summary
- 7 tables created (departments, users, spaces, facilities, space_facilities, bookings, maintenances)
- 10 foreign keys (2 CASCADE on space_facilities, 1 SET NULL on maintenances.assigned_staff_id, 7 NO ACTION)
- 13 CHECK constraints (including D3-D5 deferred checks: quantity > 0, completion_time >= start_time, actual_end_time >= actual_start_time)
- 9 triggers (BR1-BR9 enforcement + trg_maintenances_completion_space_status for Q3)
- 15 triggers total (9 business-rule + 6 updated_at auto-stamp)
- 26 indexes (7 PK clustered, 4 UNIQUE nonclustered, 14 nonclustered, 1 filtered unique nonclustered)
- Filtered unique index `uq_bookings_active_overlap` with WHERE clause verified
- All CHECK constraints match schema-registry + D3/D4/D5 recommendations from validation report
- All FK cascade paths verified: no multiple-cascade-path conflict
- Naming conventions per `docs/tech-stack.md`: PK_, FK_, UQ_, CK_, idx_, trg_ prefixes

## Blocking issues
- ⏳ **SCHEMA FREEZE pending group approval** — still outstanding

## Next steps
1. Proceed to Task 06 — Sample Data generation (`generate-data --group G05`)
2. Await group approval for SCHEMA FREEZE (pending)