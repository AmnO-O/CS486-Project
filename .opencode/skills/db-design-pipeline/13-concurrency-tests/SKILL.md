---
name: 13-concurrency-tests
description: >
  Generate the Task 13 Phase 2 concurrency tests for the Campus Space Management
  System, producing the outputs/13-concurrency-tests-G05/ directory: two-session
  SQL Server scripts that demonstrate each concurrency conflict (K1–K5 and the lock
  contract) and its prevention, asserting on the Task 12 procedures' result codes
  per the Task 11 test guidance. Supports --scope full|crash. Triggers when the
  user runs /generate-concurrency-tests or asks to write/run the Phase 2
  concurrency test suite.
---

# Task 13 - Concurrency Tests (Phase 2)

## Goal

Produce a reviewer-ready, executable test-suite directory proving the Phase 2
concurrency design: Phase 2 requires "scripts demonstrating the conflict and its
prevention" (docs/project_phase2_description.md §2) and "concurrency test results"
(§3.1). The suite runs against the Task 12 entry points on a scratch database,
uses **concurrent two-session script pairs**, and asserts on **result codes** (and
post-state), never on "who wrote first". The concurrency test guidance lives in
Task 11 §10 — re-read it every run; never hardcode scenario lists or codes from
memory.

## Skill origin

This sub-skill was created to close the missing-skill gap for Task 13 (the pipeline's Task 13 was referenced in memory and Task 11 §10, but no `13-concurrency-tests/` sub-skill existed under `.opencode/skills/db-design-pipeline/`). 

Pipeline rule: a referenced instruction file that does not exist must be reported
before generating output — this skill states the instruction set for Task 13.

## Required inputs (minimal — read ONLY these four, in this order)

Re-read the current repo every run. Do not hardcode procedure names, result codes,
lock resources, purpose domains, or scenario sets unless the current approved
sources still define them.

1. `outputs/12-concurrency-implementation-G{{group}}.sql` — the code under test:
   exact entry-point names/signatures (incl. OUT shape), result codes 51001–51009,
   lock resource/mode/owner/timeout, preflight THROWs (5201x), smoke/cleanup
   conventions, W2 ack-repair semantics. Read in full.
2. `outputs/11-concurrency-design-G{{group}}.md` — read **§6.3 only** (error-code
   table) and **§10** (per-scenario Winner/Loser expectations). This is the
   scenario contract.
3. `outputs/10-schema-migration-G{{group}}.sql` — read the **Phase 2 new-table
   DDL + seeds** section only (`space_type_allowed_purpose` reference rows — needed
   to pick an in-domain but not-allowed purpose for the soft-gate cases;
   `maintenance.impact_level`/`completion_time`; `booking_advisory_acknowledgement`/
   `maintenance_impact_history`; reserved system user -1; `SESSION_CONTEXT` key).
   Do not read the rollback script.
4. `outputs/05-db-definition-G{{group}}.sql` — read **the CREATE TABLE blocks only**
   (departments/users/spaces/bookings/booking_approvals/maintenance): column lists
   for the fixture inserts, FK cascade rules, domain CHECKs, and the Base
   `uq_bookings_active_overlap` plus `trg_bookings_prevent_overlap`/`trg_bookings_check_maintenance`
   behavior that the no-control baselines rely on.

Gate check (NOT an input — one grep before generating): `memory/Progress.md` —
Task 12 status (⏳ unapproved blocks <Task13-results> claim) and the Phase 2
open-question table (a pending U assigned to Task 13 blocks output).

## Source of truth priority (conflict → stop and report, never pick a side)

1. Task 12 output (code under test — signatures/codes the suite asserts on)
2. Task 11 output (scenario contract §10 / codes §6.3 — the expected outcomes)
3. Task 10 output (schema facts the fixture and audit queries touch)
4. Task 05 output (baseline raw-DML column/domain facts)

The mandatory deliverable name is `13-concurrency-tests-G{{group}}/`. If a
required file is missing or contradicts another, stop and report the exact gap —
never pick a convenient side.

## Parameters

| Parameter | Meaning | Default (this project) |
|---|---|---|
| `{{group}}` | group identifier | `G05` |
| `{{scope}}` | test scope; valid `full`, `crash` | `full` |
| `{{lock_resource}}` | must be read from the current Task 11 (e.g. `space_booking:<space_id>`), never hardcoded | from current Task 11 |
| `{{timeout_ms}}` | lock timeout from the current Task 11 | read from current Task 11 |

**`{{scope}} = full`**: implement every scenario named in the current Task 11 §10
(T1…T13 plus any additions), including the forced-deadlock and timeout-hold
scenarios.

**`{{scope}} = crash`**: a reduced, deterministic set that still covers every
conflict family, the lock contract, and each family's no-control twin with the
least runtime/fragility. The crash set is defined *relative to the current
Task 11 scenario list*, not hardcoded:

- include: both-order cross-path races (instant-vs-instant, instant-vs-staff,
  staff-vs-staff), escalation both orders (escalate-first vs submit-first, plus
  the pending-untouched assertion), lock-timeout + retry-after-release (+ its
  no-control blocking twin), ticket-vs-confirmation both orders, the invariant
  audit query, all single-session gates (soft-gate fallback, fallback-vs-instant,
  ack repair).
- exclude, and document each exclusion with the justification:
  - forced-deadlock scenario: fragile to reproduce as victim determinism,
    high flake risk; the deadlock code path `51007` is still statically asserted
    against Task 12's mapping in the README;
  - standalone retry scenario if retry is already folded into the min elapsed
    timeout scenario.
- Cross-cutting rule: **a conflict family may not be dropped from crash scope** — a
  careful `<conflict-id>` vs included-scenarios mapping must show ≥1 covered
  scenario each; any family left out requires an explicit user decision, and the
  exclusion is recorded in the README + memory + `docs/design-decisions.md`.

## Task Gates (before writing the suite)

- Tasks 08–12 approved per `memory/Progress.md`; Task 13 is next (unless an explicit
  revise run). **If Task 12 exists but memory still marks it unapproved, stop and
  report the gate — never test an unapproved implementation.**
- No open question assigned to Task 13 is pending (check the Phase 2
  question table).
- Do NOT update `memory` (user approves first) and do NOT modify registries or prior
  task outputs.

## Outputs

**Comparison methodology (this suite's core):** every conflict family is delivered
TWICE — a no-control twin (RAW SQL through the same tables/triggers, no entry-point
critical section) and the controlled twin (same race through the Task 12 entry
points). The comparison proves the control resolves what raw concurrency breaks.

- `outputs/13-concurrency-tests-G{{group}}/` — the deliverable folder (mandatory
  name from §3.2):
  - `README.md` — methodology (baseline vs controlled), prerequisites
    (script order `05 → 06 → 10 → 12 → 13`, sqlcmd), connection/run instructions,
    coverage matrix: conflict → scenario → baseline-expected outcome → controlled
    expected codes; results recorded (pass/fail counts, date, environment);
    non-contractual-raw-DML boundary note.
  - `00_setup.sql` / `99_cleanup.sql` — seeded fixture (small deterministic world:
    a few spaces with capacity, requester/staff users, one advisory + one
    out-of-service maintenance in the test window; soft "TEST-" naming) and reverse
    (cascade-safe deletes of seeded rows; re-runnable).
  - `baseline/bNN_<name>_a.sql` … `bNN_<name>_b.sql` — raw-SQL two-session races
    (no concurrency control). Expected = the **invariant violation materializes**
    (audit count ≥ 1) or a raw engine error surfaces (2601/2627/1205/1222/trigger
    THROW) — never a business code. Each baseline asserts its predicted outcome
    family and ends with the audit query.
  - `controlled/cNN_<name>_a.sql` … `cNN_<name>_b.sql` — the same interleaving
    through Task 12 entry points; asserts exact result codes per Task 11 §10 and
    audit = 0. Single-session gates (soft-gate fallback, fallback-vs-instant,
    ack repair) are c-scripts without a `_b` twin — they have no race and therefore
    no baseline.
  - `audit_invariant.sql` — the global BR1/NR6 invariant query
    (overlap count of confirmed bookings = 0, plus confirmed-booking-vs-active-OOS
    overlap = 0 for maintenance scenarios), appended at the end of every scenario
    body plus a suite-wide run.
  - `run_all.sh` — runs baseline pairs, then controlled pairs, then the suite
    audit, then cleanup; exit non-zero if any scenario FAILs.
- `logs/trajectory/task13/YYYY-MM-DD-HHmm-trajectory.md`
- `logs/eval/task13/YYYY-MM-DD-HHmm-task13-eval.log` — verification record
- `docs/design-decisions.md` — append ONLY for a scope decision (with
  exclusions) or a new test-technique decision recorded this run.

## Scenario Contract (re-read Task 11 §10 every run)

The Task 11 §10 table is the contract. It normally includes (re-keying language to
the current file, never pasting from memory):

- **Two-session concurrency scenarios**: K1 (two instant submits) — winner `0`,
  loser overlap code; K2 (instant vs staff) — winner approved, loser overlap code;
  K3 both orders (escalate-first → submit blocked code; submit-first → booking
  confirmed + escalation `0` + booking in the NR4 affected set, out of report #4:
  scope note); K5 both orders (ticket-first → submit blocked; submit-first →
  confirmed, with the "affected-set excludes it" note); periodic-staff staff-staff
  (same-conflict redundancy note).
- **Lock-contract scenarios**: timeout (lock held longer than `{{lock_timeout}}` →
  timeout code), retry after release, deadlock victim code if reproducible.
- **Single-session gate/repair scenarios**: soft-gate fallback (result `0` +
  `@instant_accepted = 0` + booking stays `pending` + NO auto-approval row);
  fallback-vs-instant overlap (both `0` at creation, later approval of the pending
  one blocked); advisory-ack repair inside W2 (approve `0` and the ack rows exist
  for every overlapping advisory).
- **Invariant audit** per §08 T8-style: the confirmed-overlap query, asserted
  inside every scenario ending and once by the suite.

Each scenario asserts, in order: the expected outcome from both sessions, the
required state changes to survive check-before-write semantics, and ends with the
audit query. Every assertion prints PASS/FAIL lines; a run summary aggregates.

**Baseline twin contract (no-control):** the raw twin performs the SAME logical
operations as the entry point MINUS the critical section, interleaved via
`WAITFOR DELAY` inside an open transaction (the read→wait→write window that the
applock closes). Because the Phase-1 triggers and `uq_bookings_active_overlap`
check committed data only (READ COMMITTED) and the unique index guards exact
same-start only, both raw writers commit and the invariant audit then reports the
overlap (count ≥ 1) — that IS the baseline's expected PASS condition. Where the
backstop objects instead fire (raw 2601/2627, trigger THROW), the baseline's
PASS condition is "a raw engine error surfaced with no business code". Baselines
must attribute the difference to the missing critical section, never to the
triggers.

- expected-invariants per family: K1/K2/K10 → overlapping confirmed bookings
  (BR1 audit); K3/K5 → confirmed booking overlapping active `out-of-service`
  (NR6 audit); T5-baseline → unbounded blocking (no 51005, no retry contract,
  B completes only after A's COMMIT).

## Two-session harness requirements

- **Two physical connections.** sp_getapplock and lock timeout are
  connection-scoped: "session B" must be a different sqlcmd session (process); a
  single connection cannot test concurrency. Pair scripts
  (`_a.sql`, `_b.sql`) are launched in parallel by the runner; *both start as close
  as possible*, and assertions rely on result codes, never on wall-clock order.
- **Determinism without order dependency.** When a scenario needs a fixed outcome
  (e.g. timeout), the script makes it deterministic on its own: session A holds the
  application lock inside one transaction (`WAITFOR DELAY` exceeding the timeout),
  session B's wait then times out with the exact code; session-B code is asserted
  in B's own body, so the runner does not depend on A/B arrival order.
- Deadlock-forcing scenarios (full scope only): fire both sessions' body after
  staged lock acquisition; record the victim in `results/`; do not assert a
  hardcoded victim per session — assert the *set* contains one deadlock code and
  the other succeeding, then verify global invariants.

Fixture isolation: each scenario script (i) starts with a `SET NOCOUNT ON`;
(ii) writes its results to a `results/` log captured by the runner; (iii)
`SET XACT_ABORT ON`; (iv) never reuses the other scenario's seeded rows without
mentioning it; (v) ends with the audit query; (vi) may NOT leave any of its own
rows behind — the fixture cleanup must be provable (run the validation query and
check count = 0).

Entry-point calls: call the proc standalone (they own their transactions and
ROLLBACK on failure — a nested rollback returns 266 for caller; see Task 12 N3).
Never wrap an entry point in an outer user transaction.

## SQL Server engineering notes (proven during execution)

- **N1 — Two sessions = two sqlcmd processes.** Do not try to simulate the second
  session with a second batch in the same connection/transaction; locks are
  per-connection.
- **N2 — Test IDs and messages are deterministic.** All scenario scripts reference
  the scenario ids recorded in the README; expected codes come from the current
  Task 11 error-contract numbers, never from memory.
- **N3 — Cleanup is cascade-safe.** Seed rows must flow through cascade deletes
  (e.g. deleting the seeded booking removes approvals/acks/sessions; deleting
  seeded maintenance removes history)—but two-phase seeding/deletion must not
  drop foreign data: delete in careful order (ack → bookings/maintenance →
  spaces → users) or rely on the validated cascade chain.
- **N4 — Timeout tests need a REAL wait.** Always use `WAITFOR DELAY` for precise
  timing; the sleep must materially exceed the configured lock timeout (from the
  current Task 11 — e.g. 5 s → hold ≥ 6 s).
- **N5 — Assert on codes, not on texts or row counts.** The same message text
  must never decide PASS/FAIL; code assertions only. For attribute texts (e.g.
  `rejection_reason`), assert presence by a count query.
- **N6 — sqlcmd: use `-b` (exit on T-SQL errors) and redirect the session output
  with `-o results/<date>_<id>.log`. The runner's exit code must fail the suite if
  any `FAIL` line appears (grep the results log).
- **N7 — Audit query is the final word.** Every scenario ends its body with the
  overlap audit; any non-zero row count in the results = suite FAIL.

## Output Format (the runner)

```
outputs/13-concurrency-tests-G{{group}}/
├── README.md
├── 00_setup.sql
├── 99_cleanup.sql
├── audit_invariant.sql
├── run_all.sh
├── baseline/                          (raw SQL — no concurrency control)
│   ├── b01_<slug>_a.sql   (session A) / b01_<slug>_b.sql   (session B)
│   └── ...
├── controlled/                        (same race via Task 12 entry points)
│   ├── c01_<slug>_a.sql   (session A) / c01_<slug>_b.sql   (session B)
│   ├── c11_<slug>.sql     (single-session gate — no _b twin)
│   └── ...
└── results/
    └── (run logs)
```

The runner must print a **final summary**: scenario, baseline outcome vs controlled
codes, PASS/FAIL, plus the invariant audit line; exit 0 only when everything
PASSES.

## Static Verification

If you do not have a reachable SQL Server + `sqlcmd` at generation time:

- Every scenario script must name the current Task 12 procedures with the current
  signature (extract parameter names and OUT order from task 12 output).
- Confirm the code literals (`51001`…`51009`, `0`) appear exactly as the current
  Task 11 error table defines them, without merging related codes.
- The suite must contain, at minimum per `{{scope}}`, the Contract above; the
  README states `{{scope}}` and the list.
- `run_all.sh` is present, and every scenario has its counterpart two scripts
  (A/B or the single-session listed as such in README).
- Print your findings in `logs/eval/task13/YYYY-MM-DD-HHmm-task13-eval.log`,
  stating which checks were static vs executed.

Developer note: a setup fast-cycle of the suite with a small fixture test is
critical — a syntactically wrong scenario would invalidate the evidence in the run
log. If no DB is available, declare it and keep the batch exit ordering.

## Validation Checklist (before finishing)

- Task 12 approved; current Task 11 number and scenario table exists (re-read at
  run time).
- No schema drift: suite works on the current Task 10 schema; no tables/columns
  invented by tests.
- Two-session pairing for every chosen two-session scenario; the single-session
  gates can be WITHOUT session-B scripts.
- Every included scenario: entry-point call made standalone (N3-Task12), cleanup
  complete (its own rows removed), audit query at the end.
- Codes and OUT parameter mapping current (extraction from Task 12), no code reuse
  that contradicts Task 11's 1:1 map.
- `{{scope}}` = crash exclusions are documented (README + reasoning); if a conflict
  family was dropped, the exclusion shows in `docs/design-decisions.md` + memory
  after the user approves.
- Runner script aggregates and gates the error levels (in summary `exit 0` only on
  full pass).

## Trajectory and Completion

Write `logs/trajectory/task13/YYYY-MM-DD-HHmm-trajectory.md` (evaluation template,
task 13) BEFORE any user-facing summary. Then report: what was completed;
assumptions (including the `{{scope}}` chosen); observation results or why not;
end with the AGENTS.md prompt:

> _"Ready to mark Task 13 as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

## Idempotency / reuse

- The suite is reproducible: the same group + scope → the same scenario files and
  the same expected codes (fixture seeds are fixed ids within setup).
- Revision: add T-N scenarios without breaking folder/file naming — a scenario
  file keeps its id; compatibility: de-coupled from Task 14's large data; the
  small seed is all the suite needs.
- Extending the suite (e.g. `{{scope}}=full` later) reuses `00_setup.sql` and
  `audit_invariant.sql` unchanged.