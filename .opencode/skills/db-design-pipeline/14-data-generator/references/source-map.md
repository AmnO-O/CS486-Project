# Task 14 Source Map

Load this file first after the Task 14 skill. Use it to avoid reading every large
upstream artifact in full.

## Source priority

1. `docs/project_phase2_description.md`: >=100,000 bookings, >=3 academic years,
   required statuses/maintenance/acknowledgements, and downstream reporting needs.
2. `docs/design-decisions.md`: recorded decisions; never override silently.
3. `outputs/10-schema-migration-G{{group}}.sql`: deployed Phase 2 columns,
   constraints, indexes, defaults, triggers, seed row, and idempotence behavior.
4. `outputs/05-db-definition-G{{group}}.sql`: Phase 1 tables and remaining triggers.
5. `outputs/11-concurrency-design-G{{group}}.md` and
   `outputs/12-concurrency-implementation-G{{group}}.sql`: approved write-path and
   audit/session-context contracts when present.
6. `docs/schema-registry.md`, then `docs/entity-registry.md`.
7. `docs/tech-stack.md`: SQL Server 2019+, T-SQL naming/types.
8. This Task 14 skill and its direct references: complete generator workflow,
   loading policy, validation, and completion rules.

## Targeted extraction

Use `rg -n` before opening large files:

```text
rg -n "CREATE TABLE|CREATE TRIGGER|CREATE OR ALTER PROCEDURE|CREATE INDEX|DEFAULT|CHECK|FOREIGN KEY|IDENTITY" outputs/05-db-definition-G{{group}}.sql outputs/10-schema-migration-G{{group}}.sql
rg -n "booking|maintenance|acknowled|impact_level|approver_id|SESSION_CONTEXT|510" outputs/11-concurrency-design-G{{group}}.md outputs/12-concurrency-implementation-G{{group}}.sql
rg -n "^### |^\| .*\|" docs/schema-registry.md
```

Read the exact surrounding blocks after a match. Do not infer column behavior from
names alone.

## Gates

- Task 10 must be approved before generation.
- Tasks 11 and 12/13 must satisfy the repository's strict sequence as recorded in
  `memory/Progress.md`; if the current pipeline says an earlier task is incomplete,
  stop instead of jumping ahead.
- Directly relevant open questions must be resolved. U4 is assigned to Task 16 and
  is not a Task 14 blocker; do not hardcode a semester definition to resolve U4.
- Existing Task 06 data must not be deleted or silently merged. State whether loading
  requires a clean scratch database, appends into an isolated key range, or uses an
  explicit coexistence policy.

## Required conflict response

If requirements, decisions, migration, registries, or concurrency contract disagree,
stop before writing artifacts. Report paths, exact facts, and the blocked decision.
Do not edit upstream sources to make the generator fit.
