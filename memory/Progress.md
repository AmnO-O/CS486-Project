# Progress — CS486 DB Design Pipeline

## Pipeline status

| Task | Deliverable | Output file | Status | Depends on |
|---|---|---|---|---|
| Task 1 | Business analysis | `outputs/01-business-req-analysis-G05.md` | ✅ Approved | — |
| Task 2 | ERD design | `outputs/02-erd-design-G05.md` | ✅ Approved | Task 1 |
| Task 3 | Logical design | `outputs/03-logical-design-G05.md` | ✅ Approved | Task 2 |
| Task 4 | Design validation | `outputs/04-design-validation-G05.md` | ✅ Approved | Task 3 |
| Task 5 | SQL DDL | `outputs/05-db-definition-G05.sql` | ✅ Approved | Task 4 ✅ freeze |
| Task 6 | Sample data | `outputs/06-sample-data-G05.sql` | ✅ Approved | Task 5 |
| Task 7 | Query design | `outputs/07-query-design-G05.sql` | ✅ Approved  | Task 5 |
| — | Logs agent improvement | `improvement_logs.md` | ✅ Approved  | — |
| — | Git repository | — | ✅ Approved | — |
| — | Report PDF | `outputs/report-G05.pdf` | ✅ Approved | All tasks |

## Phase 2 pipeline status

**Phase 2 extends the Phase 1 baseline to a 16-task pipeline.** Source of truth:
`docs/project_phase2_description.md`. The schema is **unfrozen** for Phase-2 re-design
(see `docs/design-decisions.md`). Deliverables below follow §3.2 of the Phase 2
description; statuses below reflect the current task state.

| Task | Deliverable | Output | Status | Depends on |
|---|---|---|---|---|
| Task 08 | Requirement-change analysis | `outputs/08-requirement-change-analysis-G05.md` | ✅ Approved | Phase 1 (01–07) |
| Task 09 | Updated ERD + logical design (+ 3NF re-check) | outputs/09-updated-erd-and-logical-design-G05.md | ✅ Approved (v2.6 revision 2026-08-08) | Task 08 |
| Task 10 | Schema migration | outputs/10-schema-migration-G05.sql | ✅ Approved (2026-08-10, rev6 + review pass v6.1 — NR2 insert-time ack trigger `trg_bookings_insert_advisory_acknowledgements`; R6-complement diff at 8g; smokes S1–S14 PASS) | Task 09 |
| Task 11 | Concurrency design | outputs/11-concurrency-design-G05.md | ✅ Approved (2026-08-10, v4.0 + review pass — W1 ack steps = schema trigger per R3; 3-layer completeness + implicit-consent evidence; R8 Report #4 (Q5) name; R9 wording) | Task 09 |
| Task 12 | Concurrency implementation | `outputs/12-concurrency-implementation-G05.sql` | ✅ Approved (2026-08-10, rev5 — applock return-code fix: `sp_getapplock` return 1 (granted-after-wait) accepted; `NOT IN (0,1)` guard in all 4 entry points; surfacing Task 13 c01 red) | Task 11 |
| Task 13 | Concurrency tests | `outputs/13-concurrency-tests-G05/` | ✅ Approved (2026-08-08, full baseline scope, no exclusion + **live run 2026-08-10 green on Task 12 rev5: T13-SUITE PASS, 29/29, 0 FAIL**) | Task 12 |
| Task 14 | Data generator (>=100k bookings) | outputs/14-data-generator-G05/ | Approved (2026-08-07) | Task 10 |
| Task 15 | Index-tuning report | `outputs/15-index-tuning-report-G05.md` | 🔄 In progress | Task 14, Task 16 ✅ |
| Task 16 | Analytical queries | `outputs/16-analytical-queries-G05.sql` | ✅ Approved (2026-08-08, trajectory 2026-08-08-0655) | Task 14 |
| — | Phase 2 report (PDF) | `outputs/report-P2-G05.pdf` | ⬜ | All tasks |

## Status legend

- ⬜ Not started
- 🔄 In progress
- ✅ Approved — safe to use as upstream input
- ⚠️ Needs revision — do not use as upstream input

---

## Critical gate: SCHEMA FREEZE

**Phase 1 (Tasks 5, 6, 7) is gated on SCHEMA FREEZE** → reached & ✅ approved.

**Phase 2:** the schema is **unfrozen** (Option B, `docs/design-decisions.md`) for the
affected tables so the pipeline may continue 08 → 16. A **re-freeze** of the Phase-2
schema is expected at **Task 09/10** before DDL/migration/generator work is treated as
locked upstream inputs.

Do NOT generate DDL or sample data before this gate.

---

## Decisions log

| Date | Decision | Reason |
|---|---|---|
| 2026-08-10 | Task 12 **rev5** + Task 13 live run GREEN: applock guard `<> 0` → `NOT IN (0,1)` in all 4 entry points (`sp_getapplock` return 1 = granted-after-wait = success; loser sessions re-check BR1 and return 51003 instead of THROWing 52999 — surfaced by Task 13 c01 live run). Scratch smoke S0–S6d + idempotent re-run PASS (CS486_G05_T12R5). Full T13 suite re-run on rev5: T13-SUITE PASS, 29/29, 0 FAIL (run 2026-08-10-111428); README §5 + FULL_SUITE_RUN.log + results/SUMMARY.log refreshed; design-decisions entries added (Task 10 rev6 planFix R1–R10, Task 12 rev5); R9 wording applied at outputs/09:160 | Task 13 live run exposed the defect; SQL Server documents return 1 as success |
| 2026-08-10 | Task 11 v4.0 + review pass approved — trigger-based ack materialization reframing (R3): W1 no longer inserts ack rows (steps 7/8 reworded); 3-layer completeness architecture + evidenced implicit-consent verdict with five-source citations (R2/R9 wording "recorded that the requester was informed / deemed acknowledged at booking time"); Report #4 standardized as Q5 `usp_task16_q5_escalation_impact` (R8); §4.4/§5.2 clarifications (ack trigger = primary completeness mechanism, not backstop; criterion 2 scoped to the concurrency strategy). Exactly one 4.0 log entry; entry points/lock keys/codes/DD6 unchanged | planFix rev4 FINAL (2a083cc) §4.3; trajectories 0854 + 0901 |
| 2026-08-10 | Task 12 approved (rev4 + review pass) — W1 step-8 ack INSERT removed from `usp_booking_instant_submit`; `trg_bookings_insert_advisory_acknowledgements` (Task 10 rev6) is the SINGLE insert-time ack owner (planFix R3); steps renumbered (auto-approval = W1 step 8, COMMIT = step 9); preflight 0.3 now requires the trigger (no longer merely defense-in-depth); preflight 0.2b pointer updated to rev6; smoke extended with S0/S1b/S4b proving trigger materialization on auto-approved AND pending inserts, counts mirror the rev6 trigger predicate; S0–S6d PASS on scratch + idempotent re-run | planFix rev4 FINAL (commit 2a083cc) §4.2 + §5 checklist; evidence logs/eval/task12/2026-08-10-0839-12-concurrency-compile-rev4.log, trajectories 0807 + 0839 |
| 2026-08-10 | Task 10 approved (rev6 + review pass v6.1) — NR2 insert-time layer: new trigger `trg_bookings_insert_advisory_acknowledgements` (AFTER INSERT on bookings) materializes one ack row per advisory active at insert time overlapping the booking period. Unconditional/status-agnostic (R1); single source of truth for insert-time acks (R3 — Task 12 rev4 removes W1 step-8 ack INSERT); predicate = exact complement of 8c rejection (R6, literal diff embedded at 8g); `GETDATE()` for acknowledged_at (matches ack-table default); R9 wording ("recorded that the requester was informed / deemed acknowledged"); rollback drops the trigger. Compile evidence: migration S1–S14 PASS (incl. multi-row S13, boundary S14), idempotent re-run OK, rollback R7.1–R7.6 OK on scratch DB | planFix.md rev4 FINAL (commit 2a083cc) + review pass 2026-08-10; decision entry for docs/design-decisions.md deferred to the docs step (planFix §4.5, order 10 → 12 → 11 → 13 → docs) |
| 2026-08-08 | Task 13 approved — concurrency tests suite: FULL baseline scope (b01/b02/b03/b05/b09/b10 raw twins, no exclusion) + controlled twins c01–c13 (+c03b submit-wins order), shared TEST-13 fixture (9 spaces, 2 users, M3/M9 advisories, 6 pendings), audit_invariant Q_BR1/Q_NR6, run_all.sh orchestrator (sqlcmd -b, FAIL grep); static QA passed; live run pending SQL Server instance | Post-Task 13 handshake (user: mark complete) |
| 2026-08-08 | Task 12 approved (rev3) — upstream fact used by Task 13: W1 gate order BR1 (51003) fires before BR4 (51002); usp_maintenance_report locks only for out-of-service; NULL completion_time → OOS ticket covers all later windows; err codes 0/51001–51009; applock `space_booking:<id>` 5 s | Task 13 generation evidence |
| 2026-08-08 | Task 09 v2.6 — per-space duration cap dropped (column + CHECK); instant usage-policy test back to checks 1–5 (soft gate = purpose membership only; no duration gate); downstream: 10 rev5, 11 rev3.2, 12 rev3, 13 | Post-Task 09 handshake (v2.6 revision) |
| 2026-08-08 | Task 12 approved — concurrency implementation rev3: 4 entry points per Task 11 §9, per-space `sp_getapplock` (`space_booking:<space_id>`, Exclusive, 5 s), codes 0/51001–51009 per §6.3, soft gate = check 1 (purpose membership) only, NR2-ack repair in W2, no schema change (procedures only); compiled + smoke (S1–S6d PASS) + idempotent re-run on scratch DB CS486_G05_Task12_Rev3 | Post-Task 12 handshake (rev3; aligned 09 v2.6 / 10 rev5 / 11 v3.4) |
| 2026-08-08 | Task 11 approved — v2.0 concurrency design, 4 entry points (`usp_booking_instant_submit`, `usp_booking_approve`, `usp_maintenance_set_impact_level`, `usp_maintenance_report`), per-space transaction-owned `sp_getapplock`, codes 51001–51011 | Post-Task 11 handshake |
| 2026-08-04 | Task 10 approved — Phase 2 schema migration (delta on Phase 1 baseline) + rollback script, compiled & verified on a scratch DB | Post-Task 10 handshake |
| 2026-08-04 | `changed_by` audit mechanism = `SESSION_CONTEXT(N'current_user_id')` via `sys.sp_set_session_context` (not `CONTEXT_INFO()` byte packing); fallback to reserved system user `-1`; session-scoped → app layer must set/clear per unit of work (connection-pooling leak risk, handoff to Task 11/12) | Reviewer feedback — SQL Server 2016+ recommended mechanism |
| 2026-08-04 | `trg_maintenance_recompute_space_status` guarded to status-relevant columns: `IF UPDATE(status) OR UPDATE(impact_level) OR UPDATE(start_time) OR UPDATE(completion_time) OR UPDATE(is_deleted)` — skips no-op updates; `is_deleted` required so soft-delete still recomputes | Reviewer feedback — avoid wasted recompute round-trips without regression |
| 2026-08-03 | Task 09 approved — updated ERD + logical design (Areas 1–3) | Post-Task 09 handshake |
| 2026-08-03 | Instant-booking pathway: origin **derived** from reserved system user `-1` (no stored origin column — keeps 3NF); eligibility `{classroom, computer_lab, project_lab, meeting_room}`; test = space_type eligible ∧ requester account active ∧ expected_participants ≤ capacity (BR3) ∧ no overlapping approved/checked_in/completed booking (BR1) ∧ no overlapping out-of-service maintenance (BR4); NR6 enforcement deferred to Task 11 | Phase 2 C2 / NR5–NR6 |
| 2026-08-02 | Phase 2 kickoff — project extended to 16 tasks (08–16); schema unfrozen for affected tables (`maintenance`, `bookings`); Option-B evolve-in-place | `docs/project_phase2_description.md`, design-decisions Phase-2 decision |
| 2026-06-15 | Building/floor as free-text VARCHAR fields | No query requirement for separate building/floor tables |
| 2026-06-15 | Rejection reason as separate column | BR7 requires storing rejection reason |
| 2026-06-15 | Usage policy as free-text NVARCHAR(MAX) | No fixed policy set defined |
| 2026-06-15 | Account_status enum: active/inactive/suspended | Standard university account lifecycle values |
| 2026-06-15 | All entity registry attributes finalized and locked (🔒) | Post-Task 03 finalization |
| 2026-06-17 | Design validation passed — 14/14 BR covered, 3NF confirmed, ERD fidelity 7/7 | Post-Task 04 validation |
| 2026-06-17 | Schema-registry index synchronization needed (4 missing indexes, 1 naming conflict) | Discrepancy D1/D2 in validation report |
| 2026-06-17 | SCHEMA FREEZE recommended pending group approval | Post-Task 04 |
| 2026-06-18 | BR8/BR9 upgraded from Application to Database enforcement via `trg_bookings_checkin_enforcement` and `trg_bookings_completion_enforcement` | Defense-in-depth for status-transition NOT NULL validation |
| 2026-06-18 | D1/D2 index sync resolved — 4 missing indexes added, `idx_bookings_overlap` → `idx_bookings_time_range` | Cross-file consistency between outputs/03 and schema-registry restored |
| 2026-06-18 | SCHEMA FREEZE READY — all gates passed, awaiting group approval | Index sync resolved, BR8/BR9 database-level
| 2026-06-12 | Task 01 output filename: `01-business-req-analysis-G05.md` | Matches required naming in `req/business-requirement.md` §3.2 |
| 2026-06-12 | 7 entities defined: Users, Departments, Spaces, Facilities, Space_Facilities, Bookings, Maintenance | Directly derived from requirement sections |
| 2026-06-12 | Assumption: Users have unique emails | Natural business key |
| 2026-06-12 | Assumption: Soft deletes for bookings/maintenance | Historical records requirement |

---

## Known open questions

_(All resolved — no open questions remain.)_

| # | Question | Resolution | Date |
|---|---|---|---|
| Q1 | Rejection reason — separate column or part of decision note? | Separate `rejection_reason` column | 2026-06-15 |
| Q2 | Usage policy - free text or coded rules? | Free-text decision superseded by Task 09 v2.5: data-driven space_type_allowed_purpose + duration cap; v2.6 dropped the cap (checks 1-5); usage_policy dropped | 2026-08-08 |
| Q3 | Maintenance-to-booking interaction — can a space be booked after maintenance is resolved but before status is updated? | Auto-trigger on maintenance resolution + cross-check trigger on booking insert | 2026-06-15 (revised) |
| Q4 | No-show detection — automatic or manual? | Automatic scheduled job | 2026-06-15 (revised) |
| Q5 | Building/floor — reference tables or varchar fields? | Free-text `NVARCHAR` fields | 2026-06-15 |

---

## Known open questions (Phase 2 — from Task 08)

_Unresolved design questions carried out of `outputs/08-requirement-change-analysis-G05.md` §6.
Each must be resolved before the task listed in the `Resolved before` column; the agent must ask
the person responsible for that task for a decision before generating that task's output on an
unresolved question (see AGENTS.md)._

| # | Question | Resolved before | Resolution | Date |
|---|---|---|---|---|
| U1 | Instant-booking eligible space types / usage-policy test | Task 09 | ✅ Eligible `{classroom, computer_lab, project_lab, meeting_room}`; v2.6 test = checks 1–5: `(space_type, purpose) ∈` junction ∧ account active ∧ participants ≤ capacity (BR3) ∧ no overlap (BR1) ∧ no out-of-service overlap (BR4) — no duration gate | 2026-08-03 (v2.6 2026-08-08) |
| U2 | Advisory-ack storage (attribute vs new table) | Task 09 | ✅ New table `booking_advisory_acknowledgement` (one row per (booking, advisory)) | 2026-08-03 |
| U3 | Escalation - pending vs only approved | Task 11 | Approved bookings only; escalation performs no booking DML; pending bookings stay pending and later approval fails 51002 | 2026-08-04 |
| U4 | Semester reporting window definition | Task 16 | Semester 1 [September 1, February 1); Semester 2 [February 1, July 1); summer excluded; Q3 clips duration; Q4 uses start inside window; Monday = 1 | 2026-08-07 |
| U5 | Space-status derivation from maintenance levels | Task 09 | ✅ `spaces` unchanged; `current_status` recomputed on maintenance INSERT/UPDATE/resolve via priority rule | 2026-08-03 |

---

## How to update this file

Only after user approves the output (see Post-Task Handshake Protocol in `AGENTS.md`):
1. Change status to ✅ Approved or ⚠️ Needs revision
2. Add key decisions to the decisions log
3. Update `memory/ActiveContext.md` for the next task
