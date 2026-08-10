---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
---

## Current phase
**Phase 1 (Tasks 01–07): COMPLETE + LOCKED ✅**
**Phase 2 (Tasks 08–16): IN PROGRESS — Task 08 ✅ 2026-08-02; Task 09 ✅ 2026-08-08 v2.6; Task 10 ✅ 2026-08-10 rev6 + review pass v6.1 (NR2 insert-time ack trigger); Task 11 ✅ 2026-08-10 v4.0 + review pass (R3/R8/R9, 3-layer completeness); Task 12 ✅ 2026-08-10 rev5 (applock return-1 fix); Task 13 ✅ live run GREEN 2026-08-10 (T13-SUITE PASS, 29/29, 0 FAIL; README §5 + FULL_SUITE_RUN.log + SUMMARY.log refreshed); Task 14 ✅ 2026-08-07; Task 16 ✅ 2026-08-08; Task 15 🔄**

Phase 2 extends the system (see `docs/project_phase2_description.md`): maintenance impact
levels, advisory acknowledgements, concurrent/instant booking, schema migration, a
≥100k-row data generator, index tuning, and analytical queries. The schema is unfrozen
for the affected tables (Option B, `docs/design-decisions.md`).

## Status (Phase 1 baseline — reference)
- Task 07 output: `outputs/07-query-design-G05.sql` ✅
- Phase 1 schema is frozen (9 tables). Phase 2 underway.
- Task 08 output: `outputs/08-requirement-change-analysis-G05.md` ✅ Approved.
  Analyzed C1–C3, affected entities/relationships, changed BRs (BR2, BR4), new rules
  (NR1–NR6), and 4 concurrency conflicts (K1–K4). U3 is resolved in docs/design-decisions.md; U4 feeds Task 16.
- Task 09 output: `outputs/09-updated-erd-and-logical-design-G05.md` ✅ Approved
  (**v2.6 revision 2026-08-08**; base 2026-08-03, v2.5 2026-08-07).
  Areas 1–3 designed (schema-only): `maintenance.impact_level` +
  `maintenance_impact_history` + `booking_advisory_acknowledgement` (Area 1);
  instant/staff origin derived from the reserved system user `-1` (`approver_id = -1`,
  no stored origin column — keeps 3NF) (Area 2); reporting = no-schema-change (Area 3).
  **v2.5:** usage policy made data-driven — dropped `spaces.usage_policy`, added table
  `space_type_allowed_purpose` (space_type × purpose, composite PK, soft value
  reference, seeded for {classroom, computer_lab, project_lab, meeting room}).
  **v2.6:** the v2.5 per-space duration cap (column + CHECK) is removed — no duration
  gate anywhere; instant-approval test = checks 1–5 with purpose membership as the
  only soft gate (`pending` fallback), hard gate (capacity/overlap/out-of-service) →
  reject; 3NF still holds; D10/D13 deviation rows dropped (net-zero schema impact).
  Downstream: Task 10 rev 5 (no cap column), Task 11 rev 3.2, Task 12 rev 3,
  Task 13 re-generated against checks 1–5.
- Task 10 output: outputs/10-schema-migration-G05.sql + companion rollback
  outputs/10-schema-migration-G05-rollback.sql ✅ Approved 2026-08-08 (revision 5,
  Task 09 v2.6: no max_hours column anywhere; v2.5 cap dropped). Data-preserving
  Phase-2 delta plus Task 09 v2.5 changes: maintenance.impact_level,
  maintenance_impact_history, booking_advisory_acknowledgement, and
  space_type_allowed_purpose with guarded seed rows; reserved system approver
  user_id = -1, required indexes/triggers, and validation checks. Scratch-DB cycle
  baseline → migration → idempotent re-run → rollback passed; post-rollback counts
  equal baseline with no data loss. Evidence under logs/trajectory/task10/ and
  logs/eval/task10/.
- Task 11 output: outputs/11-concurrency-design-G05.md ✅ Approved 2026-08-08.
  v3.4, entry-point scope 4: `usp_booking_instant_submit`, `usp_booking_approve`,
  `usp_maintenance_set_impact_level`, `usp_maintenance_report`; per-space
  transaction-owned `sys.sp_getapplock` (`space_booking:<space_id>`, Exclusive,
5 s), READ COMMITTED, deterministic result codes 0/51001–51009 (one cause family
  per code), 51005 lock timeout / 51006 lock cancelled (retryable), 51007 restart;
  U3 synced (escalation affects approved only); K5 closed via the 4th entry point
  usp_maintenance_report (locks ONLY for out-of-service tickets; NULL
  completion_time → OOS covers all later windows); soft gate = check 1 (purpose
  membership) only (v2.6); handoff to Task 12 (procedures table §9).
- Task 12 output: outputs/12-concurrency-implementation-G05.sql ✅ Approved
  2026-08-10 (rev5 — applock fix; rev4 + review pass 2026-08-10; rev3 2026-08-08).
  Exactly the 4 entry
  points — transaction-owned `sp_getapplock` per-space (5 s), codes 0/51001–51009,
  W1 gate order: BR1 (51003) before BR4 (51002); W2 NR2-ack repair (DD6),
  SESSION_CONTEXT attribution, preflight 0.2b guards the v2.6 no-max_hours schema;
  procedures-only (no schema change). REV4: W1 step-8 ack INSERT REMOVED — the
  Task 10 rev6 trigger is the sole insert-time owner (planFix R3); steps renumbered
  (auto-approval = 8, COMMIT = 9); preflight 0.3 requires the trigger. REV5:
  `sp_getapplock` guard `<> 0` → `NOT IN (0,1)` in all 4 entry points — return 1
  (granted-after-wait) is success; surfaced by Task 13 c01 live run (loser threw
  52999 instead of 51003). Smoke S0–S6d PASS + idempotent re-run on
  scratch CS486_G05_T12R5 (evidence logs/eval/task12/2026-08-10-1015-*.log).
- Task 13 output: outputs/13-concurrency-tests-G05/ ✅ Approved 2026-08-08.
  Comparison suite: baseline/ (12 raw twins: b01/b02/b03/b05/b09/b10 × _a/_b) +
  controlled/ (17: c01–c10 pairs, c11 soft gate, c12 fallback-vs-instant,
  c13 ack-repair, c14 raw-insert trigger, c03b submit-wins order) + 00_setup.sql
  (TEST-13 fixture: dept/users × 2, 9 meeting rooms, M3/M9 advisories, 6 pending
  bookings; windows ≥ +600 days; PB13 before M9), 99_cleanup.sql (provable
  teardown), audit_invariant.sql (Q_BR1 + Q_NR6), run_all.sh (parallel sqlcmd -b
  pairs, FAIL grep, exit code), README.md. FULL baseline scope decision recorded
  in docs/design-decisions.md. planFix fixture revs done: PB13-before-M9 reorder,
  b03-B header corrected (R7/R10), c14 raw-insert trigger test, b09 rework
  (poll-based deterministic order). **LIVE RUN 2026-08-10 GREEN on Task 12
  rev5**: T13-SUITE PASS, 29/29, 0 FAIL (run 20260810-111428); README §5 row,
  FULL_SUITE_RUN.log, results/SUMMARY.log refreshed.
- Task 14 output: outputs/14-data-generator-G05/ ✅ Approved 2026-08-07.
  Generated 120,000 bookings; manifest confirms 45,431 advisory acknowledgements
  and 64,607 confirmed bookings.
- Task 15 output: outputs/15-index-tuning-report-G05.md 🔄 In progress.
- Task 16 output: outputs/16-analytical-queries-G05.sql ✅ Approved 2026-08-08 (trajectory 2026-08-08-0655).

## Verification summary (Phase 1 dependency for Phase 2)
- SCHEMA FREEZE approved (Task 04), DDL `outputs/05-db-definition-G05.sql`.
- Sample data / queries landed as upstream inputs for Phase 2 re-design.

## Blocking issues
- None. Phase 2 underway.

## Next steps
1. Complete Task 15 — index tuning report (`outputs/15-index-tuning-report-G05.md`): in progress.
2. Then Phase 2 report PDF (`outputs/report-P2-G05.pdf`).
