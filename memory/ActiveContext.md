---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
---

## Current phase
**Phase 2 (Tasks 08–16): IN PROGRESS — Task 08 ✅ 2026-08-02; Task 09 ✅ 2026-08-08 v2.6; Task 10 ✅ 2026-08-08 rev4 (v2.6 → rev5 pending); Task 11 ✅ 2026-08-08 (v2.6 → rev 3.2 pending); Task 12 🔄; Task 14 ✅ 2026-08-07**

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
  outputs/10-schema-migration-G05-rollback.sql ✅ Approved 2026-08-08 (revision 4).
  Data-preserving Phase-2 delta plus Task 09 v2.5 changes: maintenance.impact_level,
  spaces.max_hours with CHECK, dropped spaces.usage_policy, new
  maintenance_impact_history, booking_advisory_acknowledgement, and
  space_type_allowed_purpose with guarded seed rows; reserved system approver
  user_id = -1, required indexes/triggers, and validation checks. **v2.6 flag:** needs
  rev 5 — remove the cap column + its CHECK; instantiability test = checks 1–5. Scratch-DB cycle
  baseline → migration → idempotent re-run → rollback passed; post-rollback counts
  equal baseline with no data loss. Evidence under logs/trajectory/task10/ and
  logs/eval/task10/.
- Task 11 output: outputs/11-concurrency-design-G05.md ✅ Approved 2026-08-08.
  v2.0, entry-point scope 4: `usp_booking_instant_submit`, `usp_booking_approve`,
  `usp_maintenance_set_impact_level`, `usp_maintenance_report`; per-space
  transaction-owned `sys.sp_getapplock` (`space_booking:<space_id>`, Exclusive,
  5 s), READ COMMITTED, deterministic result codes 50001–50004 rejection family,
  51005 lock timeout, 51006 lock cancelled, 51011 unexpected; U3 synced
  (escalation affects approved only); K5 closed via 4th entry point; handoff to
  Task 12 (procedures table §9).
- Task 12 output: outputs/12-concurrency-implementation-G05.sql 🔄 In progress.
- Task 14 output: outputs/14-data-generator-G05/ ✅ Approved 2026-08-07.
  Generated 120,000 bookings; manifest confirms 45,431 advisory acknowledgements
  and 64,607 confirmed bookings.
## Verification summary (Phase 1 dependency for Phase 2)
- SCHEMA FREEZE approved (Task 04), DDL `outputs/05-db-definition-G05.sql`.
- Sample data / queries landed as upstream inputs for Phase 2 re-design.

## Blocking issues
- None. Phase 2 underway.

## Next steps
1. Complete Task 12 — concurrency implementation (outputs/12-concurrency-implementation-G05.sql).
2. Then Task 13 — concurrency tests.
3. Task 14 is complete; the remaining Phase 2 order is Task 16, then Task 15
   (Task 15 still depends on Task 14 and Task 16).
