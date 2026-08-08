---
name: active-context
description: Current task being worked on, blocking issues, and immediate next steps. Update at start and end of every session.
---

## Current phase
**Phase 1 (Tasks 01–07): COMPLETE + LOCKED ✅**
**Phase 2 (Tasks 08–16): IN PROGRESS — Task 08 ✅ 2026-08-02; Task 09 ✅ 2026-08-07 v2.5; Task 10 ✅ 2026-08-08 rev4; Task 11 🔄; Task 14 ✅ 2026-08-07**

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
  (base 2026-08-03; **v2.5 revision 2026-08-07**).
  Areas 1–3 designed (schema-only): `maintenance.impact_level` +
  `maintenance_impact_history` + `booking_advisory_acknowledgement` (Area 1);
  instant/staff origin derived from the reserved system user `-1` (`approver_id = -1`,
  no stored origin column — keeps 3NF) (Area 2); reporting = no-schema-change (Area 3).
  **v2.5 (Area 2 revision):** usage policy made data-driven — dropped
  `spaces.usage_policy`; added `spaces.max_hours` (nullable per-space instant-booking
  duration cap, CHECK > 0); new table `space_type_allowed_purpose` (space_type ×
  purpose, composite PK, soft value reference, seeded for {classroom, computer_lab,
  project_lab, meeting_room}); instant-approval test = checks 1–6 with soft-gate
  (purpose/cap) → `pending` fallback and hard-gate → reject. U1 re-resolved under the
  data-driven test; concurrency enforcement deferred to Task 11.
- Task 10 output: outputs/10-schema-migration-G05.sql + companion rollback
  outputs/10-schema-migration-G05-rollback.sql ✅ Approved 2026-08-08 (revision 4).
  Data-preserving Phase-2 delta plus Task 09 v2.5 changes: maintenance.impact_level,
  spaces.max_hours with CHECK, dropped spaces.usage_policy, new
  maintenance_impact_history, booking_advisory_acknowledgement, and
  space_type_allowed_purpose with 18 guarded seed rows; reserved system approver
  user_id = -1, required indexes/triggers, and validation checks. Scratch-DB cycle
  baseline → migration → idempotent re-run → rollback passed; post-rollback counts
  equal baseline with no data loss. Evidence under logs/trajectory/task10/ and
  logs/eval/task10/.
- Task 11 output: outputs/11-concurrency-design-G05.md 🔄 In progress.
  Current working scope is the 4-entry-point NR6 design; U3 is synced, and the
  remaining clean-up is handoff/review before Task 12.
- Task 14 output: outputs/14-data-generator-G05/ ✅ Approved 2026-08-07.
  Generated 120,000 bookings; manifest confirms 45,431 advisory acknowledgements
  and 64,607 confirmed bookings.
## Verification summary (Phase 1 dependency for Phase 2)
- SCHEMA FREEZE approved (Task 04), DDL `outputs/05-db-definition-G05.sql`.
- Sample data / queries landed as upstream inputs for Phase 2 re-design.

## Blocking issues
- None. Phase 2 underway.

## Next steps
1. Continue Task 11 — concurrency design (outputs/11-concurrency-design-G05.md):
   the U3 decision is already synced, so this is now a consistency/review pass before
   handoff to Task 12.
2. Then Task 12 — concurrency implementation, then Task 13 — concurrency tests.
3. Task 14 is complete; the remaining Phase 2 order is Task 16, then Task 15
   (Task 15 still depends on Task 14 and Task 16).
