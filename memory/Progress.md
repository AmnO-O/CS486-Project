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
description; all are ⬜ until their task runs.

| Task | Deliverable | Output | Status | Depends on |
|---|---|---|---|---|
| Task 08 | Requirement-change analysis | `outputs/08-requirement-change-analysis-G05.md` | ✅ Approved | Phase 1 (01–07) |
| Task 09 | Updated ERD + logical design (+ 3NF re-check) | `outputs/09-updated-erd-and-logical-design-G05.md` | ✅ Approved | Task 08 |
| Task 10 | Schema migration | `outputs/10-schema-migration-G05.sql` | ✅ Approved (2026-08-04) | Task 09 |
| Task 11 | Concurrency design | `outputs/11-concurrency-design-G05.md` | ✅ Approved (2026-08-05) | Task 09 |
| Task 12 | Concurrency implementation | `outputs/12-concurrency-implementation-G05.sql` | ⬜ | Task 11 |
| Task 13 | Concurrency tests | `outputs/13-concurrency-tests-G05/` | ⬜ | Task 12 |
| Task 14 | Data generator (≥100k bookings) | `outputs/14-data-generator-G05/` | ⬜ | Task 10 |
| Task 15 | Index-tuning report | `outputs/15-index-tuning-report-G05.md` | ⬜ | Task 14, Task 16 |
| Task 16 | Analytical queries | `outputs/16-analytical-queries-G05.sql` | ⬜ | Task 14 |
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
| 2026-08-05 | Task 11 approved — concurrency design: per-space transaction-owned `sp_getapplock` critical section (`space_booking:<space_id>`) shared by instant/staff/escalation paths + post-lock authoritative re-checks; READ COMMITTED, 5 s lock timeout, retry on 51005/51006 only, deterministic codes 51001–51010; triggers + filtered unique index kept as defense-in-depth; no schema change. U3 resolved: escalation affects only already-approved bookings (pending stay pending, unapprovable at approval time). Revisions 1.1 (post-lock re-read in escalation — 51009 determinism) and 1.2 (BR2 pre-check `51010 SPACE-CLOSED` in instant path; 51002 exclusive to BR4; applock return-value split -1/-2→51005 vs -3→51006) | Post-Task 11 handshake |
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
| Q2 | Usage policy — free text or coded rules? | Free-text `NVARCHAR(MAX)` | 2026-06-15 |
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
| U1 | Instant-booking eligible space types / usage-policy test | Task 09 | ✅ Eligible `{classroom, computer_lab, project_lab, meeting_room}`; test = space_type eligible ∧ requester account active ∧ expected_participants ≤ capacity (BR3) ∧ no overlapping approved/checked_in/completed booking (BR1) ∧ no overlapping out-of-service maintenance (BR4) | 2026-08-03 |
| U2 | Advisory-ack storage (attribute vs new table) | Task 09 | ✅ New table `booking_advisory_acknowledgement` (one row per (booking, advisory)) | 2026-08-03 |
| U3 | Escalation → pending vs only approved | Task 11 | ✅ Only already-approved bookings. Pending bookings are NOT mutated by an escalation — they stay `pending` and any later approval attempt (staff or instant) fails the out-of-service gate (`51002`); NR4 report #4 covers approved bookings only | 2026-08-05 |
| U4 | "Semester" reporting window definition | Task 16 | ⬜ pending | — |
| U5 | Space-status derivation from maintenance levels | Task 09 | ✅ `spaces` unchanged; `current_status` recomputed on maintenance INSERT/UPDATE/resolve via priority rule | 2026-08-03 |

---

## How to update this file

Only after user approves the output (see Post-Task Handshake Protocol in `AGENTS.md`):
1. Change status to ✅ Approved or ⚠️ Needs revision
2. Add key decisions to the decisions log
3. Update `memory/ActiveContext.md` for the next task