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

Produce a reviewer-ready Markdown design document that explains how the system will
prevent concurrency anomalies in Phase 2, especially the NR6 invariant:

> Two approved bookings must never use the same space during overlapping time
> periods, regardless of whether they are created through instant booking or staff
> approval, even when users and staff operate concurrently.

Task 11 is a design handoff. It must be precise enough for Task 12 to implement and
Task 13 to test, but it must not contain full runnable implementation or test scripts.

## Adaptive Source Rule

This skill must stay useful when project files change. Do not bake in object names,
decisions, task statuses, or trigger behavior from a previous run unless the current
files still say so.

When generating the output:

- Extract current task status and open questions from `memory/Progress.md`.
- Extract the active task handoff from `memory/ActiveContext.md`.
- Extract current entities, tables, indexes, and business-rule coverage from the
  registries.
- Extract conflict labels and descriptions from the current Task 08 output.
- Extract approved schema/rationale from the current Task 09 output.
- Extract implemented trigger/procedure/application contracts from Task 10 only if
  Task 10 is approved or the current pipeline state says it is the upstream source.
- Treat the examples in this skill as design patterns and checks, not as replacement
  source material.

If the current files contradict one another, stop and report the exact conflict rather
than silently choosing a convenient interpretation.

## Inputs and Source-of-Truth Priority

The global reading order in `.opencode/skills/db-design-pipeline/SKILL.md` and
`docs/README.md` governs which project docs, memory files, and templates are read at
session start (`AGENTS.md`, memory files, registries, `docs/design-decisions.md`,
`docs/tech-stack.md`, `docs/templates/README.md`). Do not restate it here; only
task-specific must-read sources are listed below:

1. `docs/project_phase2_description.md` - authoritative Phase 2 source (NR6 wording).
2. `outputs/08-requirement-change-analysis-G{{group}}.md` - current conflict inventory.
3. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` - approved Phase 2 design.
4. `outputs/10-schema-migration-G{{group}}.sql` and
   `outputs/10-schema-migration-G{{group}}-rollback.sql` when Task 10 is approved or
   present as the current implemented contract.
5. Existing `outputs/11-concurrency-design-G{{group}}.md` only in `--mode revise`.

Consult the registries, `docs/design-decisions.md`, or `docs/tech-stack.md` on demand
when a claim needs cross-checking (names, decisions, conventions); they are read at
session start anyway.

Use `--group` if supplied; default to `G05`.

If any required file is missing, stop and report the exact gap. If a referenced optional
Task 10 file is absent while the task status says Task 10 is approved, stop and report
the mismatch.

When sources conflict, use this priority:

1. `docs/design-decisions.md` for recorded decisions and tradeoffs.
2. `memory/Progress.md` for task approvals and open-question status.
3. `memory/ActiveContext.md` for current handoff details.
4. `outputs/10-schema-migration-G{{group}}.sql` for implemented database and application
   contracts, when approved/current.
5. `docs/schema-registry.md` for relational objects and business-rule coverage.
6. `docs/entity-registry.md` for conceptual relationships and attributes.
7. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` for design rationale.
8. `outputs/08-requirement-change-analysis-G{{group}}.md` for conflict inventory.
9. `docs/project_phase2_description.md` and `req/business-requirement.md` for
   requirement wording.
10. `docs/tech-stack.md` for SQL Server syntax and naming conventions.

Do not edit higher-priority sources to fit the design. If a mismatch blocks design,
report it.

## Output

- `outputs/11-concurrency-design-G{{group}}.md`
- `docs/design-decisions.md` - append Task 11 key decisions made during this run,
  especially resolved Task 11 open questions and the selected concurrency strategy.
- `logs/eval/task11/YYYY-MM-DD-HHmm-11-concurrency-design-check.log`
- `logs/trajectory/task11/YYYY-MM-DD-HHmm-trajectory.md`

The output is Markdown. It may include short pseudocode or tiny T-SQL fragments only
to communicate transaction order, lock hints, error contracts, or entry-point shape.
Do not write a complete Task 12 implementation script.

## Task Gates

Before writing the Task 11 output, verify:

- Phase 2 tasks before Task 11 are approved according to `memory/Progress.md`, following
  the repository's strict task order.
- Task 11 is the next unstarted Phase 2 task, unless the current run is an explicit
  `--mode revise` of an existing Task 11 output.
- Every open question assigned to Task 11 in the "Known open questions (Phase 2)" table
  is resolved in memory or has a final decision from the user in the current turn.
- `docs/design-decisions.md` does not conflict with the selected strategy or with any
  resolved open-question answer.

Current known example: U3 asks whether escalation to out-of-service affects pending
requests or only already-approved bookings. If U3 or any successor Task 11 question is
still pending and no current-turn decision exists, stop and ask for the decision before
generating the output. Do not silently decide.

Do not update `memory/Progress.md` or `memory/ActiveContext.md` after generation. The
user must approve first, per `AGENTS.md`.

Do not update `docs/entity-registry.md` or `docs/schema-registry.md` for Task 11 unless
the current approved sources already require a schema-object change. If the selected
concurrency design requires new schema not present in the registries, stop and report
the conflict instead of quietly editing the registries.

## Design Scope

Task 11 must design:

- How instant booking and staff approval check availability and write approval state
  atomically.
- How maintenance escalation or downgrade interacts with in-flight booking and approval
  work for the same space/time.
- How the design prevents every concurrency conflict found in the current Task 08
  output.
- Which SQL Server concurrency mechanism will be used and why.
- Which database entry points Task 12 should implement.
- What the application must do around transactions, session context, retries, and
  deterministic errors.
- What Task 13 must demonstrate with concurrent-session tests.

Task 11 must not:

- implement stored procedures, triggers, runnable migration SQL, or test scripts;
- add new schema unless the current registries already require it;
- tune performance indexes beyond naming existing indexes the design relies on;
- write analytical queries or data-generator code;
- patch prior outputs to remove upstream inconsistencies.

## Required Extraction

Before reasoning, build a short internal inventory from the current files:

- Confirmed booking statuses that count as "approved/confirmed" for BR1/NR6.
- Current maintenance columns and values that distinguish advisory and out-of-service.
- Current advisory acknowledgement table/relationship, if present.
- Current approval origin model, especially whether instant approval is derived or stored.
- Current trigger/procedure names that already enforce booking, maintenance, approval, or
  acknowledgement rules.
- Current indexes relevant to booking overlap and maintenance overlap checks.
- Current application-layer contracts, such as session context keys used for audit.
- Current Task 08 conflict IDs and descriptions.
- Current Task 11 open questions and their decisions.

Write the output from that inventory. If a detail is absent, say it is absent and design
around the absence only when the task scope allows it.

## Required Reasoning

### Invariants

State each invariant in enforceable terms, using current source wording:

- **BR1 / NR6:** no two non-deleted bookings for the same space may both be in the
  confirmed-status set with overlapping requested intervals.
- **BR4 Phase 2:** confirmation must not allow a booking that overlaps active
  out-of-service maintenance.
- **NR2:** confirmation may allow advisory overlap only when all required acknowledgement
  rows exist.
- **NR4 / Task 11 open question:** escalation behavior must follow the resolved decision
  for pending versus approved bookings.
- **NR5:** instant booking origin must follow the currently approved design; do not add a
  stored origin column unless the current registries and decisions explicitly changed.

### Workflows to cover

Document transaction boundaries and lock order for each workflow:

1. **Instant booking submission**
   - create or stage the booking request;
   - check instant eligibility and availability;
   - create required advisory acknowledgements where applicable;
   - create the auto-approval according to the current origin model;
   - commit or roll back as one unit.
2. **Staff approval**
   - lock/read the existing pending booking;
   - re-check capacity, booking overlap, out-of-service maintenance, and advisory
     acknowledgement completeness;
   - insert or record the approval decision;
   - commit or return a deterministic rejection/error.
3. **Maintenance escalation/downgrade**
   - lock/read the maintenance row and its affected space/time window;
   - record impact-level history through the current audit contract;
   - handle affected bookings according to the resolved Task 11 decision;
   - avoid racing with simultaneous booking confirmation for the same space/time.
4. **Room-finder / availability read**
   - classify the query as an advisory hint or a transactionally current confirmation
     read;
   - if it is a pre-booking hint, state that final confirmation re-checks the invariant;
   - if it is used inside confirmation, use the same critical section as the write path.

### Conflict mapping

Map every conflict from the current Task 08 output to the selected prevention strategy.
At minimum, the design must cover:

| Conflict type | Required coverage |
|---|---|
| Competing booking confirmations | Two concurrent checks cannot both approve overlapping rows. |
| Distinct pathways | Instant and staff approval share the same critical section and invariant check. |
| Maintenance escalation race | Escalation and booking confirmation cannot observe stale advisory versus out-of-service state. |
| Availability read race | Reads are either documented hints or use the confirmation critical section. |

Use the current conflict IDs and names from Task 08 when writing the final matrix.

### Candidate strategies

Evaluate at least three SQL Server strategies before selecting one. Candidate pool:

- `SERIALIZABLE` transactions plus key-range locks on current booking and maintenance
  overlap indexes.
- `UPDLOCK, HOLDLOCK` on overlap reads inside one explicit transaction.
- `sys.sp_getapplock` with a transaction-owned resource scoped by the current space key.
- Optimistic retry with version/timestamp checks, if such version columns exist or are
  proposed by current sources.
- Trigger-only enforcement from the current migration/baseline.

For each candidate, state:

- what anomaly it prevents;
- what it fails to prevent or makes hard to prove;
- implementation complexity for Task 12;
- expected concurrency impact;
- fit with the current schema, triggers, indexes, and SQL Server version.

### Selection criteria

The selected strategy must:

- be valid for SQL Server 2019 or later;
- give all write paths that can confirm or invalidate a booking interval one shared
  critical section for the same space;
- re-check the invariant after entering the critical section and before writing;
- preserve the current normalized schema unless the current approved sources require
  otherwise;
- be simple enough to implement and demonstrate in Tasks 12 and 13.

A common good fit for this project is a transaction-owned `sys.sp_getapplock` resource
such as `space_booking:<space_id>`, combined with final re-checks and existing
trigger/index enforcement as defense-in-depth. This is a recommendation, not a
hardcoded answer; choose a different strategy if the current files make it better and
justify the tradeoff.

## Review-Driven Design Rules

These rules are general, technical lessons learned from review rounds. They stay
valid when project files change — apply them to whatever workflows, rules, and codes
the current sources define. Do not read them as hardcoded project facts.

### R1 — Post-lock authoritative re-check in EVERY write workflow

A pre-lock read is a **fast-path only**: it resolves the lock resource key and allows
an early exit, but it is never authoritative. Every write workflow that can confirm or
invalidate an interval must **re-read its target row(s) after acquiring the critical
section** and re-run the checks immediately before writing, returning the deterministic
no-op/conflict outcome there.

- Apply the double-check to **all** workflows, not just the primary one — the
  maintenance escalation/downgrade workflow is the one that is typically forgotten.
- Typical miss: two concurrent no-op operations on the same row both pass the pre-lock
  fast-path; the loser then writes unchanged values and returns SUCCESS instead of the
  documented no-op code. Data is unharmed only if an existing trigger/guard filters the
  change — the design must not rely on that for the return-code contract.

### R2 — Gate-coverage parity across workflows

Cross-check **every invariant and business rule against every workflow** that could
violate it. A rule enforced in one pathway is not automatically enforced in another
pathway. Concretely:

- List the checks each workflow performs, side by side, and diff them.
- If a gap traces back to an upstream source (e.g., an eligibility test defined in an
  earlier task that omitted an availability gate), **document the trace in the
  workflow** but fix the gap in the Task 11 procedure-level design — never edit
  upstream outputs or registries to make the design easier.
- Prefer early procedure-level rejection over "let the trigger roll back later": the
  latter wastes DML and surfaces raw trigger messages instead of deterministic codes.

### R3 — One result code per rejection cause

Result codes must be **1:1 with distinguishable rejection causes**. Never overload a
code across different business rules: if two causes are semantically distinct (e.g.,
an overlapping maintenance ticket vs. a manual space closure), they need distinct
codes, because the Task 13 test handoff asserts on codes, not on free text. Call the
distinction out explicitly where the codes are defined.

### R4 — Shape fragments must match the contract exactly

T-SQL shape fragments and workflow pseudocode are copy-paste starting points for
Task 12. They must not contradict the contract tables (timeout/deadlock/error rows).
If a mechanism returns distinguishable outcomes (e.g., `sys.sp_getapplock` return
values), the fragment must map **each** value to its documented code — do not collapse
distinct outcomes into one line unless the contract does the same. If a fragment is a
deliberate simplification, mark it as such in the fragment itself.

## Output Format

Generate `outputs/11-concurrency-design-G{{group}}.md` with these sections:

1. **Overview**
   - task scope;
   - dependencies read;
   - what Task 11 does and does not implement.
2. **Gate and Source Check**
   - upstream approval status;
   - relevant open questions and whether each is resolved;
   - any source conflicts found.
3. **Resolved Task 11 Ambiguities**
   - question;
   - final decision;
   - rationale;
   - downstream impact on Tasks 12, 13, and any affected reporting task.
4. **Concurrency Problem Statement**
   - restate NR6 and affected business rules;
   - list current Task 08 conflicts in concise form.
5. **Current Database Contract**
   - relevant current tables, statuses, triggers/procedures, indexes, system rows, and
     application-layer handoff notes;
   - what existing enforcement remains as defense-in-depth.
6. **Candidate Strategies**
   - comparison table with tradeoffs.
7. **Selected Design**
   - chosen strategy;
   - why it fits SQL Server and this schema;
   - why rejected options are weaker for this project.
8. **Transaction and Locking Design**
   - lock resource or lock-read policy;
   - acquisition order;
   - isolation level;
   - timeout behavior;
   - deadlock/retry rules;
   - deterministic error contract.
9. **Workflow Designs**
   - instant booking;
   - staff approval;
   - maintenance escalation/downgrade;
   - room-finder/availability read.
10. **Conflict Coverage Matrix**
    - each current Task 08 conflict mapped to prevention mechanism and residual risk.
11. **Task 12 Implementation Handoff**
    - procedures/triggers or application entry points to implement;
    - required inputs/outputs;
    - error messages/result codes;
    - application responsibilities, including session context if still current.
12. **Task 13 Test Handoff**
    - concurrent-session scenarios that must be demonstrated;
    - expected winner/loser outcomes;
    - retry/deadlock/timeout cases.
13. **Assumptions, Risks, and Out of Scope**
14. **Revision Log**

Use concise tables where they improve comparison. Trace each design choice back to a
requirement, Task 08 conflict, Task 09 design, Task 10 contract, registry entry, or
recorded decision.

## SQL Server Design Notes

Use these notes when evaluating options, but verify them against the current files:

- SQL Server cannot enforce arbitrary time-range non-overlap with a plain UNIQUE
  constraint. A filtered unique index may catch exact same-start collisions, but range
  overlap needs a transaction-safe check.
- A trigger that checks for overlaps can still race under concurrent transactions unless
  the read locks protect the checked range or all relevant writes are serialized.
- `SERIALIZABLE` with suitable indexes can protect key ranges, but interval predicates
  are easy to get wrong across multiple code paths.
- `UPDLOCK, HOLDLOCK` can work when every writer uses the same range-read pattern and
  supporting indexes are correct.
- `sys.sp_getapplock` can serialize by logical resource, commonly one resource per
  `space_id`, without changing the schema. It is coarse-grained but easy to reason
  about and test.
- `sys.sp_getapplock` returns distinguishable negative codes — typically timeout (-1),
  cancelled (-2), and deadlock victim (-3). Map each return value to its documented
  outcome separately in the contract tables AND in any acquisition fragment; collapsing
  them into a single code is a review defect even when the note says "shape only".
- Application locks must be acquired inside the same transaction that performs the final
  invariant check and write. Releasing the lock before the write is not sufficient.
- If the current implementation uses `SESSION_CONTEXT`, remember it is session-scoped,
  not transaction-scoped; the application must set and clear it per unit of work.

## Validation Checklist

Before finalizing the Task 11 output, verify:

- All directly relevant Task 11 open questions are resolved in the document, or
  generation stopped before output.
- Every current Task 08 conflict is addressed.
- Instant and staff approval share one concurrency strategy.
- Maintenance escalation/downgrade is included.
- The design does not contradict the current instant-approval origin model.
- The design does not add schema outside current approved sources.
- Task 12 receives implementable boundaries.
- Task 13 receives concrete concurrent-session scenarios.
- No runnable Task 12 implementation or Task 13 scripts are included.
- Current application handoff contracts, such as `SESSION_CONTEXT`, are referenced if
  still present.
- `docs/design-decisions.md` contains appended Task 11 decisions, or the run stopped
  before making those decisions.
- **R1:** every write workflow that can confirm or invalidate an interval performs an
  authoritative re-check after entering the critical section and before writing — no
  single-check workflow remains (escalation/downgrade included).
- **R2:** every invariant/business rule that a workflow can violate is checked in THAT
  workflow (gate parity); gaps traced upstream are fixed here, not in upstream outputs.
- **R3:** result codes are 1:1 with rejection causes; no code is overloaded across
  business rules.
- **R4:** shape fragments and pseudocode agree with the timeout/deadlock/error contract
  tables (e.g., each applock return value mapped to its own code).

## Static Verification

Task 11 is a Markdown design document, so there is no SQL compile step. Perform static
verification and record the result in:

`logs/eval/task11/YYYY-MM-DD-HHmm-11-concurrency-design-check.log`

The log should check:

- output file exists and is non-empty;
- required sections are present;
- no full implementation SQL script is embedded;
- all source files used are listed or referenced;
- no unresolved Task 11 gate remains;
- no prior outputs or registries were modified except the allowed decision-log append.

## Trajectory and Completion

After writing or revising `outputs/11-concurrency-design-G{{group}}.md`, write the
trajectory file before any user-facing task-complete summary:

`logs/trajectory/task11/YYYY-MM-DD-HHmm-trajectory.md`

Use the evaluation trajectory template, adapting the task number to `11`.

Then summarize:

1. What was completed.
2. Assumptions made.
3. Verification performed or why verification could not run.
4. The exact prompt from `AGENTS.md`:

> _"Ready to mark Task X as ✅ and update `memory/Progress.md`? Or do you want to run revisions?"_

Replace `X` with `11`.

## Idempotency

- Default mode: overwrite the full Task 11 output after re-reading current sources.
- Revise mode: re-read all current sources, compare the existing Task 11 output against
  the current sources and decisions, then overwrite with a coherent revised document.
- Never patch isolated paragraphs while leaving stale design choices elsewhere.
