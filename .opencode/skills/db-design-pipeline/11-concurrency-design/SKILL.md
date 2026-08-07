---
name: 11-concurrency-design
description: >
  Generate the Phase 2 concurrency design document for the Campus Space Management
  System, writing outputs/11-concurrency-design-G05.md by reading the current
  project sources, resolving the task's open questions, selecting a SQL Server
  concurrency-control strategy, and handing a precise design to Task 12
  implementation and Task 13 tests. The skill is method-generic: every domain fact
  (conflicts, statuses, entry points, error codes, lock keys) is re-derived from
  the current repository files each run, never hardcoded. Triggers when the user
  runs /generate-concurrency-design or asks to design the Phase 2 concurrency
  solution.
---

# Task 11 - Concurrency Design (Phase 2)

## Goal

Produce a Markdown design that explains how the system prevents the concurrency
anomalies identified in the requirement-change analysis (Task 08), protecting the
invariant(s) that the Phase 2 changes expose to concurrent writes. For this project
the core invariant is:

> Two approved bookings must never use the same space during overlapping time
> periods, regardless of whether they are created through instant booking or staff
> approval, even when users and staff operate concurrently.

Re-read the current approved sources every run; if the current files state the
invariant (or its ID, e.g. NR6) differently, use the current wording — never quote
the text above from memory.

Task 11 is design **only**: precise enough for Task 12 to implement and Task 13 to
test, but it must not contain full runnable implementation or test scripts.

## Required inputs (read in this order)

Re-read the current repo every run. Do not reuse object names, decisions, task
statuses, conflict IDs, or trigger behavior from an old run unless the current
files still say so.

1. `AGENTS.md` — global pipeline constraints and rules.
2. `docs/README.md` + `db-design-pipeline` skill — required reading order.
3. `memory/Progress.md` — task gates, open questions.
4. `memory/ActiveContext.md` — current handoff.
5. `outputs/08-requirement-change-analysis-G{{group}}.md` — conflict inventory.
6. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` — approved schema design.
7. `outputs/10-schema-migration-G{{group}}.sql` + rollback — when Task 10 is
   approved/current (implemented contract and audit/trigger surface).
8. `docs/design-decisions.md`, `docs/schema-registry.md`, `docs/entity-registry.md`,
   `docs/tech-stack.md`, `docs/project_phase2_description.md` — cross-check
   names/decisions/conventions.

If any required file is missing, stop and report the exact gap.

## Source of truth priority

1. `docs/design-decisions.md`
2. `memory/Progress.md` / `memory/ActiveContext.md`
3. Task 10 contracts (`outputs/10-*`)
4. `docs/schema-registry.md` / `docs/entity-registry.md`
5. `outputs/09-updated-erd-and-logical-design-G{{group}}.md`
6. `outputs/08-requirement-change-analysis-G{{group}}.md`
7. `docs/project_phase2_description.md`

If sources contradict each other, stop and report the exact conflict — never
silently pick a convenient one.

## Parameters

| Parameter | Meaning | Default (this project) |
|---|---|---|
| `{{group}}` | group identifier | `G05` |
| `{{max_concurrency}}` | number of critical-section entry points the design covers; valid `2`, `3`, `4` | `3` |
| `{{entry_points}}` | ordered list of write-path entry points, taken from the current Task 08/09/decision files | `instant booking submit, staff approval, maintenance escalation/downgrade, maintenance ticket creation` |
| `{{lock_resource}}` | lock resource-key template `<domain_resource>:<id>` used in critical sections | `space_booking:<space_id>` |

The output must cover **exactly** `{{max_concurrency}}` entry points, always
starting with the first two in `{{entry_points}}` and adding the rest in list order
until the count is met. Conflicts whose prevention depends on a dropped entry point
must be declared **out-of-scope with residual risk** in the coverage matrix — never
silently omitted.

**Scope discipline (do not re-open recorded closures).** A scope reduction is only
permitted if nothing recorded already requires the dropped path. Before lowering
`{{max_concurrency}}`, check `docs/design-decisions.md` for a decision covering that
entry point (this project: the recorded K5 decision promotes maintenance-ticket
creation to a 4th locked entry point). If a recorded decision already covers it, do
NOT reduce scope and re-ship the hole: either keep the entry point in scope (default
`4`) or surface the conflict and obtain an explicit user decision, then record the
supersede in `docs/design-decisions.md`. Never present a **cheaply fixable hole** (a
gap closed by one small procedure that reuses a lock the other paths already use) as
a designed residual risk — that is scope-shaving, not a trade-off.

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

- How each conflict in the Task 08 inventory is prevented, within the
  `{{max_concurrency}}` entry-point scope (dropped conflicts → out-of-scope with
  residual risk).
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

Extract from the current files before writing, and say explicitly when a detail is
absent:

- Confirmed booking status sets (this project: the BR1/NR6 set).
- Maintenance impact levels distinguishing advisory vs out-of-service (or whatever
  the current design defines).
- Acknowledgement table/relationship (this project:
  `booking_advisory_acknowledgement`).
- Instant-approval origin model (reserved approver row vs stored origin column).
- Existing triggers/indexes that enforce overlap and maintenance rules.
- Session-context audit contract (`SESSION_CONTEXT` key names, reserved user).
- Task 08 conflict IDs (this project: K1–K5).
- Task 11 open-question decisions.

Design from this snapshot; never from memory of an earlier run.

## Design Principles (P1–P5)

> **Label namespaces:** the labels below are **P1–P5** (design principles), not
> R#-numbers, because R# is already the relationship-ID namespace in the Phase 1
> registry and is reused in the Task 08/09 documents (R1 = Spaces→Maintenance, R3 =
> Users→Booking_Approvals, R5, R10, …). Never use a bare R# label in Task 11 output
> for anything other than a relationship reference. Choose a principle-label
> namespace that cannot collide with identifiers already in use in the current
> documents.

- **P1 — Post-lock re-check in EVERY write workflow.** Pre-lock reads are fast-path
  only. Every workflow that confirms/invalidates an interval must re-read its target
  row(s) inside the critical section and re-run checks immediately before writing,
  then return the deterministic no-op/conflict code. Applied to all workflows,
  including maintenance escalation/downgrade (typically forgotten).
- **P2 — Gate-coverage parity.** List each workflow's checks side by side and diff.
  If a gap traces to an upstream task, document the trace but fix it in the
  procedure-level design here — never edit upstream outputs/registries. Prefer early
  deterministic procedure rejection over relying on a trigger to roll back.
- **P3 — One result code per cause-family; shared buckets must be explicit.** Codes
  are 1:1 with distinguishable **cause families**; business-rejection gates never
  share a code (Task 13 asserts on codes; e.g. an overlap must map to a dedicated
  overlap code — this project: `51003` — never to the same code as capacity or a
  missing ack). A generic context/validation code (this project: `51001` =
  row-not-found / wrong-state / invalid-input) is permitted ONLY if the doc
  explicitly labels it a *bucket* in the error-contract table and itemizes the
  causes it carries per workflow. Never write the strong claim "each code names ONE
  cause" (or "never overloaded") unless the workflow step tables actually show a
  distinct code for every distinct cause — otherwise soften to "cause-family" or
  split the code.
- **P4 — Shape fragments match the contract exactly.** Any pseudocode must agree with
  the timeout/deadlock/error tables. For `sp_getapplock`, map EACH return value to its
  own code (-1→timeout, -2→cancelled, -3→deadlock victim). Mark deliberate
  simplifications as such.
- **P5 — Lock granularity is argued, not assumed.** Disclosing a coarse-granularity
  risk with mitigations is not enough — justify the granularity choice itself
  relative to the narrower alternative. When the lock key could plausibly be finer
  (e.g., per-resource vs per-resource+period — this project: per-space vs
  per-space+day), the doc must explicitly state why the coarser key was selected
  (usually correctness/simplicity: multi-day intervals would require acquiring a
  *set* of day-keys with ordering rules and cross-midnight pitfalls) and quantify
  acceptability against the expected volume found in the repo (this project: Task 14
  ≥100k bookings over 3 academic years ⇒ tens of writes/day per busy space, sub-ms
  critical sections vs a 5 s timeout). If a finer key would be more correct or the
  volume argument does not hold, the coarser choice is a design flaw — say so and
  pick the better key instead of papering over it.

## Hardness Gates (output-quality, ENFORCED by scan before finishing)

The generated document is a design deliverable, not a transcript of how it was made.
Every gate below is verified by scanning the finished file with Select-String
(ripgrep), and the scan lines + results are recorded in the eval log:

- **G1 — Canonical 1..12 structure.** The `## N.` headings must be exactly `1..12`,
  each ONCE, in order — no duplicates (e.g., two `## 4.`), no gaps, no stray tokens
  between headings. Re-run this scan after EVERY rewrite; full-file rewrites drift
  numbering easily.
- **G2 — No run-machinery / CLI / agent language.** Forbidden tokens in the
  deliverable: CLI flags (`--create`, `--mode`, `--max_concurrency`), "user-ratified",
  "this turn", "regeneration"/"overwrite" used as a run attribute, "Agent"/"agent
  negotiation", timestamp/UUID run identifiers. Decisions are written as decisions,
  not as an execution narrative.
- **G3 — Citations = deliverable set only.** The deliverable cites ONLY deliverable
  files: `outputs/05-*`, `outputs/08-*`, `outputs/09-*`, `outputs/10-*` (+ phase-2
  description only if quoting a requirement). NEVER cite `docs/design-decisions.md`,
  `docs/schema-registry.md`, or `docs/entity-registry.md` as authoritative inside the
  deliverable — fold the needed facts inline or attribute them to the approved output
  they came from. Scan for `docs/` references and fail on any.
- **G4 — Headings inside tables/cells are consistent** — every cross-reference
  (§N, section N, step N) points at a heading/row that actually exists in the file;
  check both directions.
- **G5 — Error-code claim vs. actual workflow mapping.** Crosscheck the §6.3
  error-contract table against the per-workflow step tables (§7): every code a
  workflow returns must appear in the contract with its cause-family; and the
  strength of the doc's claim must match reality (see P3). If a code is returned for
  multiple causes, the doc must label it a bucket — never let an absolute claim
  ("each code names ONE cause") coexist with a code used for several distinct causes.
- **G6 — Conflict→test completeness for concurrency matrix.** Every conflict in the
  matrix (§8; IDs from the current Task 08 inventory — this project: K1–K5) must map
  to at least one Task 13 scenario. Additionally cover the **same-path homogeneous
  pairings** (each entry point vs itself: instant-vs-instant, staff-vs-staff,
  escalation-vs-escalation) or explicitly explain why a pairing is redundant with an
  existing scenario — do not silently leave only the cross-path cases. A strict
  reviewer will notice asymmetric coverage (e.g., a missing staff-vs-staff scenario
  when instant-vs-instant is present).
- **G7 — Granularity trade-off is argued in the doc.** Scan §5/§6/§11 for the
  coarse-vs-narrow lock-key discussion: the resource-key choice must state WHY the
  chosen granularity (vs the narrower alternative) and must ground acceptability in
  the expected volume from the repo (this project: Task 14 ≥100k bookings over 3
  years ⇒ tens of writes/day per busy space vs the lock timeout). If §11 discloses a
  contention risk but §6 never argues the key choice, the gate fails. Also
  cross-check that no overclaim exists: if the volume math does not support the
  coarser key, the doc must not wave it away.

## Candidate Strategies (evaluate ≥3, then select)

Standard pool: (a) `SERIALIZABLE` + key-range locks; (b) `UPDLOCK, HOLDLOCK` range
reads; (c) transaction-owned `sys.sp_getapplock` per resource; (d) optimistic version
checks (only if version columns exist/are proposed); (e) trigger-only (baseline).
For each: anomaly prevented, residual gap, Task 12 complexity, concurrency impact,
fit with current schema/triggers/indexes/SQL Server 2019+.

Selection criteria: valid on SQL Server 2019+; every write path shares one critical
section per resource; invariant re-checked after lock acquisition, before write;
keeps the current normalized schema; simple to implement and demonstrate.

A common fit is a transaction-owned `sp_getapplock` resource `{{lock_resource}}`
(this project: `space_booking:<space_id>`) with final re-checks + existing
trigger/index defense-in-depth. This is a recommendation, not a requirement —
justify the choice over alternatives from the current files.

SQL Server notes (general mechanism facts, verify against the current schema):
range overlap is not expressible as a plain UNIQUE index (a filtered unique index
catches exact same-start only); a check trigger alone can race under concurrency;
`SERIALIZABLE`/`UPDLOCK` are correct only if every writer's predicates lock
identical ranges — easy to get wrong across paths; `sp_getapplock` serializes by
logical resource with no schema change; the lock MUST be acquired inside the same
transaction as the final check+write; release-before-write is invalid; the app must
set/clear `SESSION_CONTEXT` per working set (session-scoped, not
transaction-scoped).

When picking the applock **resource key**, weigh granularity explicitly (P5/G7): a
per-resource key is simplest and correct, but if a narrower key is plausible
(per-resource+period — this project: per-space+day), argue why the coarser one was
kept — and bind that argument to the expected volume found in the repo (this
project: Task 14 ≥100k bookings over 3 academic years ⇒ tens of writes/day per busy
space, sub-ms critical sections vs a 5 s timeout). State the finer key as a
monitoring-driven tuning lever, not a silent omission.

## Workflows to Cover (by `{{max_concurrency}}`)

Document transaction boundaries + lock order for the first `{{max_concurrency}}`
entry points of `{{entry_points}}`, in the order given, plus the read path. For this
project the default list is:

1. Instant booking submission — create/stage request; check eligibility +
   availability; create required acks; create auto-approval per origin model; one
   commit/rollback unit.
2. Staff approval — lock/read pending booking; re-check capacity, overlap,
   out-of-service maintenance, ack completeness; record decision or deterministic
   rejection.
3. Maintenance escalation/downgrade — lock/read the maintenance row + space/window;
   record impact-level history; handle affected bookings per the resolved Task 11
   decision; no race with concurrent confirmations. (In scope only while
   `{{max_concurrency}}` >= 3.)
4. Maintenance ticket creation — applies only while `{{max_concurrency}}` = 4;
   otherwise out-of-scope with residual risk. (A raw `INSERT` into the maintenance
   table bypasses all critical sections.)
5. Availability-read / lookup path — always covered (a read path, not an entry
   point): classify as advisory hint (state that final confirmation re-checks the
   invariant) or as a confirmation read (use the same critical section). This
   project's example: the room-finder query.

If the current sources show a different entry-point set, replace the list above
with the extracted one and keep the same per-item discipline: transaction
boundaries, lock order, and residual-risk declarations for dropped items.

## Output Format

Write `outputs/11-concurrency-design-G{{group}}.md` with these sections:

1. **1. Overview** — short scope of the task.
2. **2. Concurrency Identification** — Task 08 conflicts (ID, name, description),
   which workflows can violate each, and how the design prevents it.
3. **3. Resolved Design Ambiguities & Decisions** — each Task 11 open question:
   question, final decision, rationale, impact on Tasks 12/13/reporting.
4. **4. Current Database Baseline & Contract** — relevant tables, status sets,
   reserved/system rows (this project: `user_id = -1`), defense-in-depth (filtered
   unique indexes, triggers).
5. **5. Evaluation of Candidate Strategies** — comparison table, selection
   rationale, rejection justifications.
6. **6. Transaction and Locking Architecture** — lock resource scope +
   acquisition order; isolation level + timeout; exact lock return→code mapping
   (for `sp_getapplock`: `-1`/`-2`/`-3`); 1:1 error contract (P3).
7. **7. Workflow Designs & Double-Check Specifications** — the entry points per
   `{{max_concurrency}}`, the out-of-contract listed with residual risk, the
   availability-read path (this project: room-finder).
8. **8. Conflict Coverage Matrix** — every Task 08 conflict → prevention mechanism,
   100%-for-scope proof + residual risk rows for dropped conflicts.
9. **9. Task 12 Implementation Guidance** — the `{{max_concurrency}}` entry points
   (the first two in `{{entry_points}}` always; the rest per `{{max_concurrency}}`),
   inputs/return codes, application-layer responsibilities.
10. **10. Task 13 Test Guidance** — concurrent two-session scripts (Winner/Loser)
    for every matrix conflict INCLUDING the homogeneous same-path pairings (each
    entry point vs itself: staff-vs-staff, instant-vs-instant) or an explicit
    redundancy note; deterministic assertions + codes, deadlock/timeout/retry edge
    cases.
11. **11. System Assumptions, Risks, and Boundaries** — requirements (SQL Server
    2019+, RCSI), hotspot-resource performance risk, explicit out-of-scope
    boundaries.
12. **12. Revision Log** — date, author, summary of changes.

## Validation Checklist (before finishing)

- All Task 11 open questions resolved (or stopped before output).
- Exactly `{{max_concurrency}}` entry points: workflows + §9 handoff match; dropped
  entry points are declared and residual risk stated.
- The first two entry points share one strategy; each further entry point in
  `{{entry_points}}` joins per `{{max_concurrency}}`.
- No contradiction with the instant-approval origin model; no new schema outside
  approved sources.
- P1 (all write workflows do a post-lock re-check), P2 (gate parity), P3 (cause-family
  codes, no overclaim), P4 (fragments match contract), P5 (lock granularity argued,
  quantified against expected volume).
- `docs/design-decisions.md` appended ONLY if a decision was made this run.
- No runnable Task 12/13 scripts in the output.
- Hardness gates executed and logged: G1 (scan `## N.` headings = 1..12 unique),
  G2 (token scan for run-machinery/CLI/agent language), G3 (citation scan: no
  `docs/` references), G4 (cross-references all resolve), G7 (granularity argument +
  volume grounding present in §5/§6/§11).
- Error-code gates: G5 (claims cross-checked — no "one cause per code" overclaim;
  shared buckets explicitly labeled), P3 (codes are cause-family 1:1; retries only on
  the designated codes).
- Conflict→test mapping: G6 (every conflict from the current Task 08 inventory has
  an explicit T-scenario; same-path homogeneous pairings — each entry point vs
  itself — present or their redundancy explained).
- One canonical `docs/design-decisions.md` entry per topic: if a prior entry is
  superseded this run, it was replaced (not appended beside the stale claim).

## Static Verification

Task 11 has no SQL compile step. Write `logs/eval/task11/YYYY-MM-DD-HHmm-...-check.log`
covering: output exists and non-empty; required sections present; no full SQL
scripts embedded; sources listed; gates resolved; entry-point count ==
`{{max_concurrency}}`; dropped entry points declared; no upstream files modified
except a key-decision append to `docs/design-decisions.md`. Include the G1/G2/G3/G4
scan outcomes (headings list, forbidden-token scan, `docs/` reference scan, and the
cross-reference spot checks), the G5/G6 checks (error-code claim vs workflow code,
conflict→test trace), and the G7 result (granularity rationale + volume grounding
present or absent).

## Common mistakes to avoid

- Designing from memory: hardcoding conflict IDs, status names, trigger names,
  error codes, or volumes that the current files no longer state.
- Treating this skill's examples (NR6 wording, K1–K5, 51001/51003,
  `{{lock_resource}}`) as requirements instead of re-extracting them from the
  current files.
- Dropping an entry point without declaring residual risk in the coverage matrix.
- Skipping the post-lock re-check on any write workflow (escalation/downgrade is the
  one most often forgotten).
- Claiming "each code names ONE cause" while a code serves several causes (P3).
- Picking lock granularity without the volume-grounded argument (P5/G7).
- Writing run machinery into the deliverable: CLI flags, timestamps, "this turn",
  agent negotiation (G2).
- Leaving §7 workflow tables inconsistent with the §6.3 error contract or the §9
  handoff count.
- Citing `docs/` files as authoritative inside the deliverable (G3).
- Writing runnable Task 12/13 SQL into the design document.

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
- **Reconcile sibling artifacts in the same run as any revision.** After rewriting
  the output, immediately reconcile everything that recorded the OLD state so the
  repo never carries two versions of the truth:
  - `docs/design-decisions.md` — replace the superseded decision entry (one canonical
    entry per topic; no revision-log/audit rows for the regeneration itself).
  - Prior `logs/eval/task11/*` and `logs/trajectory/task11/*` for this task — mark
    them superseded (do not silently delete) and write new `YYYY-MM-DD-HHmm` files for
    the current run; the trajectory sets `revision_of` (and the superseded file gains a
    `superseded_by`).
- Gate G1 heading scan must be re-run after every rewrite pass (numbering drifts most
  often on rewrites, not first drafts).
