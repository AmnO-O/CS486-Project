---
name: 11-concurrency-design
description: >
  Generate the Task 11 Phase 2 concurrency design document for the Campus Space
  Management System. The skill creates outputs/11-concurrency-design-G05.md by
  selecting and justifying a SQL Server concurrency-control strategy that keeps
  approved bookings non-overlapping across instant booking and staff approval.
  Triggers when the user runs /generate-concurrency-design or asks to design the
  Phase 2 concurrency solution.
---

# Task 11 - Concurrency Design (Phase 2)

## Goal

Produce a reviewer-ready Markdown design document that explains how the system will
prevent concurrency anomalies in Phase 2, especially the NR6 invariant:

> Two approved bookings must never use the same space during overlapping time periods,
> regardless of whether they are created through instant booking or staff approval,
> even when users and staff operate concurrently.

Task 11 selects and documents the concurrency-control design. It must be precise enough
for Task 12 to implement and Task 13 to test, but it must not contain full runnable
implementation scripts.

---

## Inputs

Follow the global reading order in `.opencode/skills/db-design-pipeline/SKILL.md` and
`docs/README.md`, then read the task-specific sources below:

1. `AGENTS.md` - project rules and post-task handshake.
2. `docs/README.md` - required project reading order.
3. `memory/MEMORY.md`, then:
   - `memory/ActiveContext.md`
   - `memory/Progress.md`
4. `docs/project_phase2_description.md` - authoritative Phase 2 source.
5. `docs/templates/README.md` - routing and template rules.
6. `.opencode/skills/db-design-pipeline/SKILL.md` - main pipeline rules.
7. `docs/design-decisions.md` - decisions that must not be contradicted.
8. `docs/tech-stack.md` - SQL Server conventions.
9. `outputs/08-requirement-change-analysis-G{{group}}.md` - concurrency conflicts K1-K4.
10. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` - approved schema and
    Task 11 handoff.
11. `outputs/10-schema-migration-G{{group}}.sql` - implemented Phase 2 schema, trigger
    behavior, and application-layer contract.
12. `docs/entity-registry.md` and `docs/schema-registry.md` - current target schema.

Use `--group` if supplied; default to `G05`.

If any required file is missing, stop and report the exact gap.

---

## Output

- `outputs/11-concurrency-design-G{{group}}.md`
- `docs/design-decisions.md` - append Task 11 key decisions made during this run:
  resolved U3 and selected concurrency-control strategy.
- A trajectory file:
  `logs/trajectory/task11/YYYY-MM-DD-HHmm-trajectory.md`

The output is Markdown. It may include short pseudocode or T-SQL snippets only to
communicate transaction order, lock hints, error contract, or API shape. Do not write
full Task 12 implementation SQL.

---

## Task Gates

Before generating the Task 11 output, verify:

- Task 08, Task 09, and Task 10 are approved in `memory/Progress.md`.
- Task 11 is the next unstarted Phase 2 task.
- U3 from the "Known open questions (Phase 2)" table is resolved or the user has
  provided a final decision in the current turn.

U3 is directly relevant to Task 11:

`Does escalation to out-of-service affect pending requests or only approved bookings?`

If U3 is still pending and no current-turn decision exists, stop and ask for the
decision before generating the Task 11 output. Do not silently choose.

Do not update `memory/Progress.md` or `memory/ActiveContext.md` after generation.
The user must approve first, per `AGENTS.md`.

Do not update `docs/entity-registry.md` or `docs/schema-registry.md` for Task 11
unless the current approved sources already require a schema-object change. If the
selected concurrency design requires new schema not present in the registries, stop
and report the conflict instead of silently editing the registries.

---

## Source-of-Truth Priority

When sources conflict, use this priority:

1. `docs/design-decisions.md` for recorded decisions.
2. `memory/Progress.md` for task approvals and open-question status.
3. `outputs/10-schema-migration-G{{group}}.sql` for the implemented Phase 2 database
   contract that Task 11 must build on.
4. `docs/schema-registry.md` for target relational objects and business-rule coverage.
5. `outputs/09-updated-erd-and-logical-design-G{{group}}.md` for design rationale.
6. `outputs/08-requirement-change-analysis-G{{group}}.md` for conflict inventory.
7. `docs/project_phase2_description.md` for requirement wording.
8. `docs/tech-stack.md` for SQL Server syntax and naming conventions.

Do not edit higher-priority sources to fit the design. If a conflict blocks design,
report it.

---

## Design Scope

Task 11 must design:

- How instant booking and staff approval check availability and write approval state
  atomically.
- How escalation from advisory to out-of-service interacts with in-flight booking or
  approval work.
- How the design prevents K1-K4 from Task 08.
- Which SQL Server concurrency mechanism will be used and why.
- Which database entry points Task 12 should implement.
- What the application must do around transactions, session context, retries, and
  errors.
- What Task 13 must demonstrate with concurrent-session tests.

Task 11 must not:

- implement stored procedures, triggers, runnable migration SQL, or test scripts;
- add new schema unless the current registries already require it;
- tune performance indexes beyond stating which existing indexes the design relies on;
- write analytical queries or data-generator code.

---

## Required Reasoning

### Invariants

State each invariant in enforceable terms:

- **BR1 / NR6:** no two non-deleted bookings for the same space may both be in a
  confirmed status (`approved`, `checked_in`, `completed`) with overlapping requested
  intervals.
- **BR4 Phase 2:** an approval/instant approval must not confirm a booking that overlaps
  active `out-of-service` maintenance.
- **NR2:** an approval/instant approval may confirm a booking that overlaps active
  `advisory` maintenance only when all required acknowledgement rows exist.
- **NR4/U3:** escalation behavior must follow the resolved U3 decision.
- **NR5:** instant booking origin stays derived from `booking_approvals.approver_id = -1`;
  do not add an origin column.

### Workflows to cover

Document transaction boundaries and lock order for each workflow:

1. **Instant booking submission**
   - create the booking request;
   - check eligibility and availability;
   - insert required advisory acknowledgements where applicable;
   - insert the auto-approval using the reserved system user `-1`;
   - commit or roll back as one unit.
2. **Staff approval**
   - lock/read the existing pending booking;
   - re-check capacity, booking overlap, out-of-service maintenance, and advisory
     acknowledgement completeness;
   - insert the approval decision;
   - commit or return a deterministic rejection/error.
3. **Maintenance escalation/downgrade**
   - lock/read the maintenance row;
   - record the impact-level history using the Task 10 `SESSION_CONTEXT` contract;
   - handle affected bookings according to resolved U3;
   - avoid racing with simultaneous booking confirmation for the same space/time.
4. **Room-finder / availability read**
   - explain whether the query is advisory only or must be transactionally current;
   - if it is a pre-booking hint, state that final approval re-checks the invariant;
   - if it is used inside confirmation, it must use the same locking/read policy as
     the confirmation path.

### Conflict mapping

Map every Task 08 conflict to the selected prevention strategy:

| Conflict | Required coverage |
|---|---|
| K1 | Two instant/staff checks cannot both approve overlapping rows. |
| K2 | Instant and staff paths share the same critical section and invariant check. |
| K3 | Maintenance escalation and booking confirmation cannot observe stale advisory vs out-of-service state. |
| K4 | Availability reads are either safe hints or use the confirmation critical section. |

### Candidate strategies

Evaluate at least three SQL Server strategies before selecting one:

- `SERIALIZABLE` transactions plus key-range locks on `bookings` and relevant
  `maintenance` rows, using existing overlap indexes.
- `UPDLOCK, HOLDLOCK` on overlap reads inside one explicit transaction.
- `sp_getapplock` with a resource scoped by `space_id` to serialize all confirmation
  and maintenance-escalation work for the same space.
- Optimistic retry with version/timestamp checks.
- Trigger-only enforcement from Task 10 baseline.

For each candidate, state:

- what anomaly it prevents;
- what it fails to prevent or makes hard to reason about;
- implementation complexity for Task 12;
- expected concurrency impact;
- fit with the current schema and Task 10 triggers.

### Selection criteria

The selected strategy must be coherent with SQL Server 2019 and the current schema.
It must provide a single shared critical section for all write paths that can create
or invalidate a confirmed booking interval.

Prefer a design that is simple to implement and test in Task 12/13. A common acceptable
selection is:

- explicit transactions;
- `sp_getapplock` with `@LockOwner = 'Transaction'` and resource
  `space_booking:<space_id>` for confirmation/escalation work;
- re-checks of bookings and maintenance inside the lock;
- deterministic errors/retry contract;
- existing trigger/index checks kept as defense-in-depth.

This is a recommendation, not a hardcoded answer. If current project files make a
different strategy better, select the better strategy and justify the tradeoff.

---

## Output Format

Generate `outputs/11-concurrency-design-G{{group}}.md` with these sections:

1. **Overview**
   - task scope;
   - dependencies read;
   - what Task 11 does and does not implement.
2. **Resolved Task 11 Ambiguity**
   - U3 question;
   - final decision;
   - rationale;
   - downstream impact on Tasks 12/13/16.
3. **Concurrency Problem Statement**
   - restate NR6 and affected business rules;
   - list K1-K4 from Task 08 in concise form.
4. **Current Database Contract**
   - relevant Task 10 tables, triggers, indexes, system user, and `SESSION_CONTEXT`
     handoff;
   - what existing triggers remain as defense-in-depth.
5. **Candidate Strategies**
   - options table with tradeoffs.
6. **Selected Design**
   - chosen strategy;
   - why it fits SQL Server and this schema;
   - why rejected options are weaker for this project.
7. **Transaction and Locking Design**
   - shared lock resource or lock-read policy;
   - lock acquisition order;
   - isolation level;
   - timeout behavior;
   - deadlock/retry rules.
8. **Workflow Designs**
   - instant booking;
   - staff approval;
   - maintenance escalation/downgrade;
   - room-finder/availability read.
9. **Conflict Coverage Matrix**
   - K1-K4 mapped to prevention mechanism and residual risk.
10. **Task 12 Implementation Handoff**
    - stored procedures or trigger changes to implement;
    - inputs/outputs/error messages;
    - application-layer responsibilities.
11. **Task 13 Test Handoff**
    - concurrent-session scenarios that must be demonstrated.
12. **Assumptions, Risks, and Out of Scope**
13. **Revision Log**

Use concise tables where they improve comparison. Keep prose direct and trace each
design choice back to a requirement, Task 08 conflict, Task 09 design, Task 10
contract, or recorded decision.

---

## SQL Server Design Notes

Use these notes when evaluating options:

- SQL Server cannot enforce arbitrary time-range non-overlap with a plain UNIQUE
  constraint; the current filtered unique index catches exact same-start collisions
  only. Range overlap requires a transaction-safe check.
- A trigger that checks for overlaps can still be exposed to race conditions under
  concurrent transactions unless the read locks protect the range being checked or
  all relevant writes are serialized.
- `SERIALIZABLE` with suitable indexes can protect key ranges, but range predicates
  over intervals are easy to get wrong and can be hard to prove for all code paths.
- `sp_getapplock` can serialize by logical resource (`space_id`) without changing the
  schema. It is coarse-grained but easy to reason about and test.
- Application locks must be acquired inside the same transaction that performs the
  final invariant check and write. Acquiring the lock before the transaction or releasing
  it before the write is not sufficient.
- The Task 10 `SESSION_CONTEXT(N'current_user_id')` value is session-scoped. The
  application must set it before each maintenance unit of work and clear it afterwards
  to avoid connection-pooling leaks.

---

## Validation Checklist

Before finalizing the Task 11 output, verify:

- U3 is resolved in the document, or generation stopped before output.
- K1, K2, K3, and K4 are all addressed.
- Instant and staff approval use one shared concurrency strategy.
- Maintenance escalation is included, not treated as a separate afterthought.
- The design does not add `approval_source` or contradict the reserved-system-user
  decision.
- Task 12 receives implementable procedure/trigger boundaries.
- Task 13 receives concrete two-session test scenarios.
- No runnable Task 12 or Task 13 scripts are included.
- The output references Task 10's `SESSION_CONTEXT` handoff when discussing
  maintenance escalation.
- `docs/design-decisions.md` contains appended Task 11 decisions for U3 and the
  selected strategy, or the run stopped before making those decisions.

---

## Compile / Verification

Task 11 is a Markdown design document, so there is no SQL compile step. Perform static
verification:

- output file exists and is non-empty;
- required sections are present;
- no implementation SQL script is embedded;
- all source files used are listed or referenced;
- no unresolved Task 11 gate remains.

Record the static check in:

`logs/eval/task11/YYYY-MM-DD-HHmm-11-concurrency-design-check.log`

---

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

---

## Idempotency

- Default mode: overwrite the full Task 11 output after re-reading current sources.
- Revise mode: re-read all current sources, compare the existing Task 11 output
  against the current sources and decisions, then overwrite with a coherent revised
  document.
- Never patch isolated paragraphs while leaving stale design choices elsewhere.
