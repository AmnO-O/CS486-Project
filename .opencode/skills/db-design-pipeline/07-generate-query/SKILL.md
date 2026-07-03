---
name: 07-generate-query
description: >
  Generate SQL queries for Task 07 by writing meaningful, executable T-SQL
  statements that answer real business questions for the Campus Space Management
  System. Triggers when user runs /generate-query-design or asks to write
  business queries, design SQL queries, or produce the query design output.
---

# Task 07 — Query Design Skill

## Goal

Produce a set of meaningful, executable SQL queries that:

- answer real business questions derived from the approved requirements
- are valid T-SQL executable against the `CS486_G05` database
- follow the required 4-field output template
- use parameterized `DECLARE` blocks instead of hardcoded literals

---
## Output format
Every query must follow this exact template:

```sql
-- ============================================================
-- Query N: <short title>
-- ============================================================
-- Business question:
--   <one or two sentences — the real-world question being answered>
--
-- Target user(s):
--   <role(s) that would run this query, e.g. Facility Manager, Lecturer>
--
-- Why useful:
--   <one or two sentences — why this query matters operationally>
-- ============================================================

DECLARE @param1 <type> = <realistic default value>;
DECLARE @param2 <type> = <realistic default value>;
-- Add more parameters as needed

<SQL statement>;
GO
```

---

## Parameter style

**Always use `DECLARE` blocks** — never hardcode literals inside the query logic.

Good:
```sql
DECLARE @building      NVARCHAR(100) = N'I';
DECLARE @min_capacity  INT           = 50;
DECLARE @slot_start    DATETIME2     = '2026-06-21 09:00:00';

SELECT space_code, space_name, capacity
FROM spaces
WHERE building = @building
  AND capacity >= @min_capacity;
```

Bad:
```sql
SELECT space_code, space_name, capacity
FROM spaces
WHERE building = 'I'         -- hardcoded
  AND capacity >= 50;        -- hardcoded
```

**Rationale:** Sample data values may differ from any literal. Parameters make queries reusable and testable regardless of which data was inserted in Task 06.

---

## What makes a query meaningful

A query is meaningful if it:

- answers a question a real user would ask in the domain
- involves at least one JOIN or non-trivial filter
- returns actionable information (not just "list all rows")
- is not a trivial `SELECT *` with no conditions

A query is NOT meaningful if it:
- only reads one table with no filter
- duplicates another query with a minor change
- cannot be answered with the approved schema

---

## Query coverage requirements

Design at least 5 queries. Cover a variety of:

| Category | Example |
|---|---|
| Availability / scheduling | Find free rooms during a time slot |
| Operational / real-time | What is happening right now across all spaces |
| Maintenance | Active tickets, space readiness |
| Analytics / reporting | Usage patterns, no-show rates, utilization |
| Audit / accountability | Rejection history, decision trail |

Avoid writing 5 queries that all read the same table or answer the same type of question.

---

## SQL quality rules

- Use `INNER JOIN` / `LEFT JOIN` explicitly — never implicit comma joins.
- Use table aliases consistently.
- Use `NOT EXISTS` instead of `NOT IN` when checking against nullable columns.
- For interval overlap, use the standard test:
  ```sql
  @slot_start < b.requested_end_time
  AND @slot_end > b.requested_start_time
  ```
- For "right now" queries, use `GETDATE()` — do not hardcode a timestamp.
- Respect `is_deleted = 0` filters on `bookings` and `maintenances`.
- Use enum values exactly as defined in `docs/tech-stack.md`.

- **Filter by unique identifier when possible:** prefer filtering on surrogate
  keys (`user_id`, `space_id`, `booking_id`) over display names or free-text
  fields (`full_name`, `space_name`). Display names are not guaranteed unique and may return unexpected rows. If the query accepts a human-readable input parameter, add a comment noting the uniqueness assumption.


---

## Compile and verify

After generating each query, execute it against `CS486_G05`:

```bash
sqlcmd -S localhost -C <AUTH> \
  -d CS486_G05 \
  -i outputs/07-query-design-G05.sql
```

If a query returns zero rows, verify:
1. Sample data in Task 06 covers this scenario.
2. Parameters match actual data values.
3. Filters are not too restrictive.

A query that returns zero rows due to missing sample data is acceptable if the SQL logic is correct — document this in a comment:
```sql
-- Note: returns zero rows if no bookings exist in the given time window.
-- Logic is correct; seed data may not cover this scenario.
```

Append verification output to:
`logs/eval/task07/YYYY-MM-DD-HHmm-07-query-compile.log`

---

## After generation

1. Compile and verify all queries (steps above)
2. Append verification output to `logs/eval/task07/YYYY-MM-DD-HHmm-07-query-compile.log`

---

## Common mistakes to avoid

- Hardcoding literals inside query logic instead of using `DECLARE`
- Forgetting `is_deleted = 0` on soft-deleted tables
- Using wrong enum values — always check `docs/tech-stack.md`
- Writing queries that only touch one table with no join
- Duplicating the same business question across multiple queries
- Using `NOT IN` against nullable columns — use `NOT EXISTS` instead
- Forgetting `GO` between queries
- Computing duration with COALESCE(actual_end_time, requested_end_time) without filtering to status = 'completed' — overcounts hours for in-progress sessions
- Hardcoding numeric thresholds in CASE expressions instead of declaring them


---

## Output standard

The final SQL file must be executable after review. Each query is separated by `GO`. Comments follow the 4-field template exactly — no deviations.