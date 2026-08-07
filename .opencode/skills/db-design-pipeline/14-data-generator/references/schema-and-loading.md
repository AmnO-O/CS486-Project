# Task 14 Schema and Loading Reference

Read this file when designing `generate.py` or `load.sql`. Confirm every item against
the current migration and registry first.

## FK load order

Use the current FK graph. The guide's current order is:

```text
departments -> users -> spaces -> facilities -> space_facilities
            -> maintenance -> bookings -> booking_approvals -> booking_sessions
            -> maintenance_impact_history -> booking_advisory_acknowledgement
```

If the current schema changes, derive a new topological order from the actual FKs.

## Current Phase 2 traps

- The reserved `users.user_id = -1` system row is seeded by Task 10. Do not recreate
  it. Instant approval origin is derived from `booking_approvals.approver_id = -1`.
- Always provide `maintenance.impact_level`; its current default is
  `out-of-service`, which blocks overlapping confirmed bookings.
- Insert advisory acknowledgement rows before approval rows. An acknowledgement must
  point to an active advisory whose interval overlaps the booking interval.
- The composite uniqueness shape is one row per `(booking_id, maintenance_id)`; do not
  add single-column uniqueness.
- Escalation history is trigger-owned on an active maintenance impact-level update.
  Use `SESSION_CONTEXT(N'current_user_id')` when the current contract requires an
  attributed actor, then clear it after the unit of work.
- Role checks apply to approvers, check-in staff, and assigned maintenance staff.
- Capacity and positive participant/time checks remain active.
- Confirmed booking statuses are discovered from the current schema. For the current
  contract they are `approved`, `checked_in`, and `completed`.
- A no-show requires an approval and no session. Cancellation must follow the legal
  status transition defined by the current triggers.

## Loading modes

Document a deliberate split in the generated README:

| Mode | Use | Required proof |
|---|---|---|
| A - entry point | Small behavior slice: instant approvals, staff approvals, maintenance impact changes, escalation history | Call the current approved procedures; capture result codes and session-context behavior |
| B - bulk | Large historical mass | Single-threaded per-space conflict bookkeeping; explicit trigger/constraint bypass decision; post-load validation |

If Mode B uses `BULK INSERT` or `bcp`, document:

- `KEEPIDENTITY` strategy for every identity FK;
- `CHECK_CONSTRAINTS` or equivalent post-load trust validation;
- `FIRE_TRIGGERS` decision and which trigger-derived values are therefore bypassed;
- `BATCHSIZE` and restart behavior;
- file encoding, delimiter, NULL representation, and absolute/relative path policy;
- whether the load is append-only or requires a clean scratch database.

Do not use SQL Server 2022-only `GENERATE_SERIES`; the target includes SQL Server 2019.
If Python writes directly, pin the driver and use an explicit fast batch strategy.

## Generator model

- One top-level seed. Derive deterministic table streams from it.
- Keep generated IDs stable when `KEEPIDENTITY` is used; reserve negative ID `-1` only
  for the system user if the schema permits it.
- Span three academic years without embedding Task 16's unresolved semester boundary.
  Use semester-like date segments and expose dates in config.
- Concentrate windows on working days/hours, include term-start submission spikes, and
  use a discrete slot grid only as a generator assumption.
- Track confirmed intervals by `space_id`; reject a candidate if it overlaps a confirmed
  interval or shares an exact start time. Non-confirmed rows may overlap to model demand.
- Create both advisory and out-of-service maintenance, active and resolved rows, and at
  least one escalation with affected approved bookings.
