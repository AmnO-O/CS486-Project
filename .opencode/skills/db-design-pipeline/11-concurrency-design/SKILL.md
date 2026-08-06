---
name: 11-concurrency-design
description: >
  Generate the Task 11 Phase 2 concurrency design document for the Campus Space
  Management System. The skill creates outputs/11-concurrency-design-G05.md by
  reading the current project sources, resolving Task 11 open questions, selecting
  a SQL Server concurrency-control strategy, and handing a precise design to Task
  12 implementation and Task 13 tests. Triggers when the user runs
  /generate-concurrency-design or asks to design the Phase 2 concurrency solution.
---

# Task 11 - Concurrency Design (Phase 2)

## Goal

Produce a Markdown design that explains how the system prevents concurrency
anomalies in Phase 2, especially the NR6 invariant:

> Two approved bookings must never use the same space during overlapping time
> periods, regardless of whether they are created through instant booking or staff
> approval, even when users and staff operate concurrently.

Task 11 is design **only**: precise enough for Task 12 to implement and Task 13 to
test, but it must not contain full runnable implementation or test scripts.

## Adaptive Source Rule

Re-read the current repo every run. Do not reuse object names, decisions, task
statuses, or trigger behavior from an old run unless the current files still say so.
Read, in order:

- `memory/Progress.md` — task gates, open questions.
- `memory/ActiveContext.md` — current handoff.
- `outputs/08-requirement-change-analysis-G{{group}}.md` — conflict inventory.
- `outputs/09-updated-erd-and-logical-design-G{{group}}.md` — approved schema design.
- `outputs/10-schema-migration-G{{group}}.sql` + rollback — when Task 10 is
  approved/current (implemented contract and audit/trigger surface).
- Registries, `docs/design-decisions.md`, `docs/tech-stack.md`, and
  `docs/project_phase2_description.md` — cross-check names/decisions/conventions.

Priority on conflict: `docs/design-decisions.md` > memory > Task 10 contracts >
registries > Task 09 > Task 08 > phase-2 description. If sources contradict each
other, stop and report the exact conflict — never silently pick a convenient one.

## Parameters

- `{{group}}` — group id; default `G05`.
- `{{max_concurrency}}` — number of critical-section entry points the design covers;
  default `3`. Valid values: `4` (instant submit, staff approval, maintenance
  escalation/downgrade, maintenance ticket creation), `3` (instant submit, staff
  approval, escalation/downgrade; ticket creation out-of-scope), `2` (instant submit,
  staff approval; escalation/downgrade also out-of-scope).

Output must cover **exactly** `{{max_concurrency}}` entry points in the workflows
list and the Task 12 handoff. Conflicts whose prevention depends on a dropped entry
point must be declared **out-of-scope with residual risk** in the matrix — never
silently omitted.

## Task Gates (before writing)

- Tasks 08–10 approved per `memory/Progress.md`; Task 11 is next (unless an explicit
  revise run).
- Every Task 11 open question is resolved in memory or has a final user decision in
  this turn; otherwise **stop before output**.
- The chosen strategy must not contradict `docs/design-decisions.md`.
- Do NOT update `memory/Progress.md`/`ActiveContext.md` (wait for user approval) and
  do NOT modify registries or prior task outputs.

## Outputs

- `outputs/11-concurrency-design-G{{group}}.md`
- `docs/design-decisions.md` — append Task 11 KEY design decisions (resolved open
  questions, selected strategy, entry-point scope change) ONLY when a decision is
  actually made. Never append revision/audit/log rows for regeneration, revision, or
  formatting runs.
- `logs/eval/task11/YYYY-MM-DD-HHmm-11-concurrency-design-check.log`
- `logs/trajectory/task11/YYYY-MM-DD-HHmm-trajectory.md`

## Design Scope

Design:

- How each Task 08 conflict is prevented, within the `{{max_concurrency}}`
  entry-point scope (dropped conflicts → out-of-scope with residual risk).
- The chosen SQL Server mechanism and why.
- Exactly `{{max_concurrency}}` database entry points for Task 12.
- Application transaction/session-context/retry/error-contract responsibilities.
- Concrete concurrent-session scenarios for Task 13.

Do NOT:

- implement procedures/triggers/migration SQL/test scripts;
- add new schema beyond what current approved sources require;
- tune performance indexes (naming existing ones the design relies on is fine);
- write analytical queries or data-generator code;
- patch prior outputs.

## Required Extraction (run-time inventory)

Confirmed booking statuses (BR1/NR6 set), maintenance levels distinguishing
advisory vs out-of-service, ack table/relationship, instant-approval origin model,
existing triggers/indexes that enforce overlap and maintenance rules, session-context
audit contract, Task 08 conflict IDs, and Task 11 open-question decisions. Design
from this snapshot; say explicitly when a detail is absent.

## Working Rules (R1–R4)

- **R1 — Post-lock re-check in EVERY write workflow.** Pre-lock reads are fast-path
  only. Every workflow that confirms/invalidates an interval must re-read its target
  row(s) inside the critical section and re-run checks immediately before writing,
  then return the deterministic no-op/conflict code. Applied to all workflows,
  including maintenance escalation/downgrade (typically forgotten).
- **R2 — Gate-coverage parity.** List each workflow's checks side by side and diff.
   If a gap traces to an upstream task, document the trace but fix it in the
  procedure-level design here — never edit upstream outputs/registries. Prefer
  early deterministic procedure rejection over relying on a trigger to roll back.
- **R3 — One result code per rejection cause.** Codes are 1:1 with distinguishable
  causes; never overload a code across business rules (Task 13 asserts on codes).
- **R4 — Shape fragments match the contract exactly.** Any pseudocode must agree with
  the timeout/deadlock/error tables. For `sp_getapplock`, map EACH return value to its
  own code (-1→timeout, -2→cancelled, -3→deadlock victim). Mark deliberate
  simplifications as such.

## Candidate Strategies (evaluate ≥3, then select)

Standard pool: (a) `SERIALIZABLE` + key-range locks; (b) `UPDLOCK, HOLDLOCK` range
reads; (c) transaction-owned `sys.sp_getapplock` per space; (d) optimistic version
checks (only if version columns exist/are proposed); (e) trigger-only (baseline).
For each: anomaly prevented, residual gap, Task 12 complexity, concurrency impact,
fit with current schema/triggers/indexes/SQL Server 2019+.

Selection criteria: valid on SQL Server 2019+; every write path shares one critical
section per space; invariant re-checked after lock acquisition, before write; keeps
the current normalized schema; simple to implement and demonstrate.

A common fit is a transaction-owned `sp_getapplock` resource
`space_booking:<space_id>` with final re-checks + existing trigger/index
defense-in-depth. This is a recommendation, not a requirement — justify the choice
over alternatives from the current files.

SQL Server notes: range overlap is not expressible as a plain UNIQUE index
(a filtered unique index catches exact same-start only); a check trigger alone can
race under concurrency; `SERIALIZABLE`/`UPDLOCK` are correct only if every writer's
predicates lock identical ranges — easy to get wrong across paths;
`sp_getapplock` serializes by logical resource with no schema change; the lock MUST
be acquired inside the same transaction as the final check+write; release-before-
write is invalid; the app must set/clear `SESSION_CONTEXT` per working set
(session-scoped, not transaction-scoped).

## Workflows to Cover (by `--max_concurrency`)

Document transaction boundaries + lock order for, in this order:

1. Instant booking submission — create/stage request; check eligibility +
   availability; create required acks; create auto-approval per origin model; one
   commit/rollback unit.
2. Staff approval — lock/read pending booking; re-check capacity, overlap,
   out-of-service maintenance, ack completeness; record decision or deterministic
   rejection.
3. Maintenance escalation/downgrade — lock/read the maintenance row + space/window;
   record impact-level history; handle affected bookings per the resolved Task 11
   decision; no race with concurrent confirmations. (Only when `{{max_concurrency}}` >= 3.)
4. Maintenance ticket creation — applies only when `{{max_concurrency}}` = 4;
   otherwise out-of-scope. (Raw `INSERT INTO dbo.maintenance` bypasses all critical
   sections.)
5. Room-finder/availability read — always covered (a read path, not an entry point):
   classify as advisory hint (state that final confirmation re-checks the invariant)
   or as a confirmation read (use the same critical section).

## Output Format

Write `outputs/11-concurrency-design-G{{group}}.md` with these sections:

1. **1. Overview** — short scope of the task.
2. **2. Concurrency Identification** — Task 08 conflicts (ID, name, description),
   which workflows can violate each, and how the design prevents it.
3. **3. Resolved Design Ambiguities & Decisions** — each Task 11 open question:
   question, final decision, rationale, impact on Tasks 12/13/reporting.
4. **4. Current Database Baseline & Contract** — relevant tables, statuses, system
   user `-1`, defense-in-depth (filtered unique indexes, triggers).
5. **5. Evaluation of Candidate Strategies** — comparison table, selection
   rationale, rejection justifications.
6. **6. Transaction and Locking Architecture** — lock resource scope +
   acquisition order; isolation level + timeout; exact `sp_getapplock` return→code
   mapping; 1:1 error contract (R3).
7. **7. Workflow Designs & Double-Check Specifications** — the entry points per
   `{{max_concurrency}}`, the out-of-contract listed with residual risk,
   room-finder read path.
8. **8. Conflict Coverage Matrix** — every Task 08 conflict → prevention mechanism,
   100%-for-scope proof + residual risk rows for dropped conflicts.
9. **9. Task 12 Implementation Guidance** — the `{{max_concurrency}}` entry points
   (instant + staff always; escalation if >=3; ticket creation if =4), inputs/return
   codes, application-layer responsibilities.
10. **10. Task 13 Test Guidance** — concurrent two-session scripts (Winner/Loser),
    expected assertions + deterministic codes, deadlock/timeout/retry edge cases.
11. **11. System Assumptions, Risks, and Boundaries** — requirements (SQL Server
    2019+, RCSI), hotspot-space performance risk, explicit out-of-scope boundaries.
12. **12. Revision Log** — date, author, summary of changes.

## Validation Checklist (before finishing)

- All Task 11 open questions resolved (or stopped before output).
- Exactly `{{max_concurrency}}` entry points: workflows + §9 handoff match; dropped
  entry points are declared and residual risk stated.
- Instant + staff approval share one strategy; escalation/downgrade when >=3;
  ticket creation when =4.
- No contradiction with the instant-approval origin model; no new schema outside
  approved sources.
- R1 (all write workflows do a post-lock re-check), R2 (gate parity), R3 (1:1 codes),
  R4 (fragments match contract).
- `docs/design-decisions.md` appended ONLY if a decision was made this run.
- No runnable Task 12/13 scripts in the output.

## Static Verification

Task 11 has no SQL compile step. Write `logs/eval/task11/YYYY-MM-DD-HHmm-...-check.log`
covering: output exists and non-empty; required sections present; no full SQL
scripts embedded; sources listed; gates resolved; entry-point count ==
`{{max_concurrency}}`; dropped entry points declared; no upstream files modified
except a key-decision append to `docs/design-decisions.md`.

## Trajectory and Completion

Write the trajectory file (evaluation template, task number 11) BEFORE any
user-facing summary. Then report: what was completed; assumptions; verification done
or why not; end with the AGENTS.md prompt:

> _"Ready to mark Task X as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

with `X` = `11`.

## Idempotency

- Overwrite (default): re-read sources, replace the whole Task 11 output.
- Revise: re-read sources, compare with the existing output, overwrite coherently.
- Never patch isolated paragraphs while leaving stale decisions elsewhere.