---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
---

## Current phase
**Phase 1 (Tasks 01–07): COMPLETE + LOCKED ✅**
**Phase 2 (Tasks 08–16): IN PROGRESS — Task 08 ✅ 2026-08-02; Task 09 ✅ 2026-08-03; Task 10 ✅ 2026-08-04; Task 11 ✅ 2026-08-05**

Phase 2 extends the system (see `docs/project_phase2_description.md`): maintenance impact
levels, advisory acknowledgements, concurrent/instant booking, schema migration, a
≥100k-row data generator, index tuning, and analytical queries. The schema is unfrozen
for the affected tables (Option B, `docs/design-decisions.md`).

## Status (Phase 1 baseline — reference)
- Task 07 output: `outputs/07-query-design-G05.sql` ✅
- Phase 1 schema is frozen (9 tables). Phase 2 underway.
- Task 08 output: `outputs/08-requirement-change-analysis-G05.md` ✅ Approved.
  Analyzed C1–C3, affected entities/relationships, changed BRs (BR2, BR4), new rules
  (NR1–NR6), and 4 concurrency conflicts (K1–K4). Unresolved items U1–U5 feed Task 09/11.
- Task 09 output: `outputs/09-updated-erd-and-logical-design-G05.md` ✅ Approved.
  Areas 1–3 designed (schema-only): `maintenance.impact_level` +
  `maintenance_impact_history` + `booking_advisory_acknowledgement` (Area 1);
  instant/staff origin derived from the reserved system user `-1` (`approver_id = -1`,
  no stored origin column — keeps 3NF) for instant booking, eligibility/test locked,
  concurrency enforcement deferred to Task 11 (Area 2); reporting = no-schema-change
  (Area 3). U1/U2/U5 resolved; U3→Task 11, U4→Task 16.
- Task 10 output: `outputs/10-schema-migration-G05.sql` + companion rollback
  `outputs/10-schema-migration-G05-rollback.sql` ✅ Approved 2026-08-04.
  Data-preserving delta: `maintenance.impact_level` (DF+CK, backfills legacy rows to
  `out-of-service`), new tables `maintenance_impact_history` +
  `booking_advisory_acknowledgement` (composite UQ), 4 new indexes, reserved system
  approver `user_id = -1` seed, one-time `current_status` refresh, 7 triggers
  (2 replaced: BR4/BR2+NR2 gate; 5 new: ack correspondence, impact history,
  recompute with `UPDATE()` guard incl. `is_deleted`, 2× updated_at). Compiled on a
  scratch DB: migration + idempotent re-run + rollback all exit 0; post-rollback counts
  == baseline. Trajectories under `logs/trajectory/task10/`; compile logs under
  `logs/eval/task10/`.
- Task 11 output: `outputs/11-concurrency-design-G05.md` ✅ Approved 2026-08-05.
  Selected: **per-space transaction-owned `sys.sp_getapplock`** critical section
  (`space_booking:<space_id>`) shared by instant booking, staff approval, and
  maintenance escalation/downgrade, with post-lock authoritative re-checks
  (BR1/BR2/BR3/BR4/NR2); READ COMMITTED, 5 s lock timeout, retry only on
  `51005`/`51006`, deterministic codes `51001–51010`; existing triggers +
  `uq_bookings_active_overlap` kept as defense-in-depth; **no schema change**.
  U3 resolved: escalation affects only already-approved bookings (pending stay
  pending, unapprovable at approval time). Handoff: 3 entry-point procedures for
  Task 12 (`usp_booking_instant_submit`, `usp_booking_approve`,
  `usp_maintenance_set_impact_level`); Task 13 scenarios T1–T9. Revisions 1.1/1.2
  (post-lock re-read in escalation → `51009`; BR2 check `51010 SPACE-CLOSED` in
  instant path; applock return split). Trajectories under `logs/trajectory/task11/`;
  eval logs under `logs/eval/task11/`.

## Verification summary (Phase 1 dependency for Phase 2)
- SCHEMA FREEZE approved (Task 04), DDL `outputs/05-db-definition-G05.sql`.
- Sample data / queries landed as upstream inputs for Phase 2 re-design.

## Blocking issues
- None. Phase 2 underway.

## Next steps
1. Proceed to **Task 12** — concurrency implementation (`outputs/12-concurrency-implementation-G05.sql`):
   implement the three entry points per `outputs/11-concurrency-design-G05.md` §11 —
   `usp_booking_instant_submit`, `usp_booking_approve`, `usp_maintenance_set_impact_level`
   (fast-path read → `sp_getapplock 'space_booking:<space_id>'` Exclusive/Transaction/5000
   → authoritative post-lock re-checks → write → COMMIT; `SET XACT_ABORT ON`; result codes
   `51001–51010`; `SESSION_CONTEXT(N'current_user_id')` set/cleared per unit of work with
   fallback to `-1`; **no trigger changes, no schema changes**).
2. Then Task 13 — concurrency tests (scenarios T1–T9), then 14 → 15/16 per `memory/Progress.md`.
3. Task 14 (data generator) depends on Task 10's migrated schema (`impact_level`, new
   tables, system user `-1`).