# Expected Files Reference

Ground truth for **ToolCorrectness** and **ArgumentCorrectness**. For each task,
this lists the files the agent is expected to READ (inputs) and WRITE (outputs),
plus files it must NOT touch. The evaluator compares a trajectory's
`Files touched` against this table.

Scoring intent:
- Reading an expected input and writing the expected output -> correct.
- Missing an expected input (e.g. skipping the registry) -> deduct.
- Writing a file marked read-only or forbidden -> hard fail on that metric.

## Common expected READ for every task

Every task should read enough project context to avoid contradicting the current
pipeline state:

- `AGENTS.md`
- `docs/README.md`
- `memory/MEMORY.md`
- `memory/ActiveContext.md`
- `memory/Progress.md`
- `docs/project-overview.md`
- `docs/tech-stack.md`
- `docs/design-decisions.md`
- `.opencode/skills/db-design-pipeline/SKILL.md`
- the task-specific skill/template under `.opencode/skills/db-design-pipeline/<task>/`

These common reads are expected context, not extra noise.

## Table

| Task | Expected READ | Expected WRITE | Must NOT write |
|---|---|---|---|
| 01 business-req-analysis | common reads; `req/business-requirement.md` | `outputs/01-business-req-analysis-G05.md`; `docs/entity-registry.md` (populate entities, attributes, relationships) | any `outputs/02..07`; `docs/schema-registry.md` |
| 02 erd-design | common reads; `outputs/01-business-req-analysis-G05.md`; `docs/entity-registry.md` | `outputs/02-erd-design-G05.md`; `docs/entity-registry.md` (refine relationships/cardinalities) | `docs/schema-registry.md`; any unrelated `outputs/` |
| 03 logical-design | common reads; `outputs/01-business-req-analysis-G05.md`; `outputs/02-erd-design-G05.md`; `docs/entity-registry.md` | `outputs/03-logical-design-G05.md`; `docs/schema-registry.md` (populate tables, columns, FK wiring, indexes, 3NF proof); `docs/entity-registry.md` (lock finalized names/types/constraints) | any unrelated `outputs/`; editing prior output artifacts |
| 04 design-validation | common reads; `req/business-requirement.md`; `outputs/01-business-req-analysis-G05.md`; `outputs/02-erd-design-G05.md`; `outputs/03-logical-design-G05.md`; `docs/entity-registry.md` (RO except lock marker); `docs/schema-registry.md` (RO except business-rule coverage/lock marker) | `outputs/04-design-validation-G05.md`; `docs/schema-registry.md` business-rule coverage and lock marker if SCHEMA FREEZE is approved; `docs/entity-registry.md` lock marker if approved | changing schema/entity facts beyond validation coverage or lock markers; any unrelated `outputs/` |
| 05 ddl | common reads; `outputs/01-business-req-analysis-G05.md`; `docs/schema-registry.md` (RO, locked source of truth) | `outputs/05-db-definition-G05.sql` or project variant `outputs/05-ddl-G05.sql` | `docs/schema-registry.md`; `docs/entity-registry.md`; any prior `outputs/` |
| 06 sample-data | common reads; `req/business-requirement.md`; `outputs/01-business-req-analysis-G05.md`; `outputs/05-db-definition-G05.sql` or `outputs/05-ddl-G05.sql`; `docs/entity-registry.md` (RO); `docs/schema-registry.md` (RO) | `outputs/06-sample-data-G05.sql` | any registry; any prior `outputs/` |
| 07 query-design | common reads; `req/business-requirement.md`; `outputs/01-business-req-analysis-G05.md`; `outputs/05-db-definition-G05.sql` or `outputs/05-ddl-G05.sql`; `docs/entity-registry.md` (RO); `docs/schema-registry.md` (RO) | `outputs/07-query-design-G05.sql` | any registry; any prior `outputs/` |

RO = read-only (allowed to read, must not modify).

## SQL-task expectations

- Task 05 must use `req/business-requirement.md`, `outputs/01`, and validation
  output to implement business-rule constraints, including CHECK constraints for
  statuses/enums, positive capacity/participant counts, valid time ranges, and
  feasible enforcement or documented handling of overlapping bookings and
  unavailable spaces.
- Task 06 must create realistic valid data plus intentional negative test cases
  marked with `-- Expected error: ...` where constraints should reject invalid
  rows, especially unavailable room bookings and overlapping booking periods.
- Task 07 must read the requirement and business analysis so each SQL query has a
  real business question, target user, and usefulness explanation. Expected query
  areas include booking history, upcoming bookings, no-show bookings, maintenance
  status, unavailable spaces, and utilization.

## Always-allowed (not scored against)

These may be read or appended in any task and do not count as violations:
- `docs/design-decisions.md` (read always; append only on a key decision)
- `memory/Progress.md`, `memory/ActiveContext.md` (read always; update post-task, only via handshake)
- `logs/trajectory/task0X/*` (the trajectory being written)

## Never-allowed (hard fail in any task)

- Editing a prior `outputs/` artifact to "fix" a mismatch (registry wins).
- Reading `node_modules/`, `.git/`, or unrelated large files.
- Modifying any registry after SCHEMA FREEZE without a `design-decisions.md` entry.
