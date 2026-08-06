# Concurrency Design — Campus Space Management System (Phase 2)

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Phase:** 2 · **Task:** 11
**Date:** 2026-08-06
**Doc version:** 2.0

---

## 1. Overview

Task 11 designs how the system prevents the concurrency anomalies introduced by the
Phase 2 operating conditions, and especially the NR6 invariant:

> Two approved bookings must never use the same space during overlapping time
> periods — regardless of whether they are created through instant booking or staff
> approval, even when users and staff operate concurrently.

The design covers **four** critical-section entry points — **instant booking
submission**, **staff approval**, **maintenance escalation/downgrade**, and
**maintenance ticket creation**. The maintenance-ticket-creation path is covered
because it is the legitimate way a blocking (`out-of-service`) maintenance record is
born, and leaving it outside the critical section would leave a hole in the same
BR4/NR6 invariant the rest of the design protects. The availability/room-finder read
path is treated as an advisory hint (§6.5). This document is design-only: it hands a
precise contract to Task 12 (implementation) and Task 13 (tests) but contains no
runnable implementation or test script.

---

## 2. Concurrency Identification

### 2.1 Conflict inventory (from Task 08)

All five conflicts identified in `outputs/08-requirement-change-analysis-G05.md` §5
stem from a **check-then-act on the same space's overlap without atomicity or
serialization between the check and the write**.

| # | Conflict | Correctness it can break | Relevant workflows |
|---|---|---|---|
| K1 | Lost update / read-then-write race on availability — two near-simultaneous requests for the same space/period both read "free" and both record their booking | BR1 / NR6 | Instant submit, staff approval |
| K2 | Distinct pathway overlap (instant vs staff) — an instant submission and a staff approval target the same space/period concurrently; each checks availability independently and both approve | BR1 / NR6 | Instant submit, staff approval |
| K3 | Escalation vs in-flight booking — an advisory is escalated to `out-of-service` while a booking overlapping the period is being placed/confirmed; the booking commits on a stale "advisory only" view | BR4 / NR4 | Maintenance escalation, instant submit, staff approval |
| K4 | State read during transition — a room-finder/availability read observes a pre-/post-transition view and reports a space free when a competing booking was just approved (or maintenance escalated) | BR1 / NR6 / NR4 | Read-only paths; final confirmation re-checks |
| K5 | Maintenance-ticket creation vs in-flight booking — a NEW ticket inserted directly (the column default is `out-of-service`) on a space races an in-flight confirmation; the booking-side BR4 pre-check misses the uncommitted ticket and commits an approved booking over the blocking ticket | BR4 / NR6 | Maintenance ticket creation, instant submit, staff approval |

> **Scope note.** All four write workflows — including **K5, maintenance-ticket
> creation** — are covered by this design. The design closes K5 by making ticket
> creation a locked entry point that shares the per-space critical section (§6.4)
> whenever the ticket starts at the blocking impact level. Only a raw,
> out-of-contract `INSERT INTO dbo.maintenance` that bypasses the entry point
> reintroduces the window; that non-contractual access is documented as an
> application-boundary risk (§7.2, §10), not silently shipped as an approved
> workflow.

### 2.2 How the design prevents each conflict

Every workflow that can **change whether a time interval on a space is confirmed**
(instant submit, staff approval, escalation/downgrade, ticket creation) serializes on
one logical resource per space, re-checks the invariants **after** acquiring the lock
and **immediately before** the write, then writes. K1, K2, K3, and K5 therefore cannot
both commit. K4 is neutralized because the final authority always lives in the locked
confirmation steps — a read result is only ever a hint.

---

## 3. Design Decisions

| # | Question | Decision | Rationale | Effect on Tasks 12 / 13 / reporting |
|---|---|---|---|---|
| D1 | Does escalation to `out-of-service` also affect **pending** requests, or only already-approved bookings? | **Only already-approved bookings.** Escalation performs **no booking DML**. Pending bookings stay `pending`; any later approval attempt fails the out-of-service gate with deterministic code `51002`. | Matches the Phase 2 wording of NR4 ("already-approved bookings … must be identified"); consistent with BR2 as designed in Task 09 (availability is checked at approval time, so a pending request is only evaluated when it is decided); no additional trigger or schema is needed. | Task 12: `usp_maintenance_set_impact_level` mutates no booking row. Task 13: regression scenario proving pending bookings stay `pending` and are rejected with `51002` at approval time. Report #4 (Task 16) covers approved bookings only. |
| S1 | Which write paths must be within the critical section? | **Four**: instant booking submission, staff approval, maintenance escalation/downgrade, and maintenance-ticket creation. | The Phase 2 requirement frames the no-overlap guarantee as unconditional (§1.2), and ticket creation is the entry point through which a blocking (`out-of-service`) record is legitimately born. Leaving it outside the lock would preserve K5, a BR4/NR6 violation of the same shape the other three paths guard against, while the fix is a single procedure reusing the same lock (§6.4). | Task 12 implements four procedures. Task 13 adds a K5 scenario (T9). Report #4 is unaffected (derived query). |
| K4 | How are read-only availability / room-finder reads treated? | **Advisory hints only.** Reads never serialize and never confirm a booking; the confirmation paths re-check under the lock. | A point-in-time read can be stale by definition; a hint cannot break NR6 as long as final confirmation re-checks. | Task 12: confirmation procs re-read all predicates post-lock. Task 13: no assertion that a simultaneous read is "fresh" — only that it cannot confirm a booking. |
| AUD | Audit mechanism for `changed_by` on maintenance level changes | `sys.sp_set_session_context N'current_user_id', <id>` at the start of every unit of work; clear (set NULL) at the end. Fallback = reserved system approver `-1`. | Follows the Task 10 handoff (`SESSION_CONTEXT` adopted for `trg_maintenance_impact_history`); session-scoped, so the app must set/clear per unit. | Task 12 entry points set/clear the context. Task 13 asserts history-row `changed_by` attribution with and without context. |

---

## 4. Current Database Baseline & Contract

Schema facts below come from the frozen Phase 1 DDL
(`outputs/05-db-definition-G05.sql`) and the approved Phase 2 migration
(`outputs/10-schema-migration-G05.sql`); the logical rationale is documented in
`outputs/09-updated-erd-and-logical-design-G05.md`.

### 4.1 The "confirmed" booking status set (BR1 / NR6)

| Status set | Enforced as | Notes |
|---|---|---|
| `'approved'`, `'checked_in'`, `'completed'` | the confirmed-state predicate for all overlap checks | `is_deleted = 0` is also required everywhere; `pending` / `rejected` / `cancelled` / `no_show` are not confirmed |

### 4.2 Maintenance impact levels (advisory vs out-of-service)

- `maintenance.impact_level VARCHAR(50) NOT NULL DEFAULT 'out-of-service'`,
  `CHECK (impact_level IN ('advisory','out-of-service'))` (Task 10). The default
  preserves Phase 1 blocking semantics for legacy rows and also means any
  ticket-creation statement that omits the column produces a blocking ticket —
  hence the ticket-entry procedure always passes the level explicitly (§6.4).
- **out-of-service** blocks any overlapping booking; **advisory** permits the booking
  provided the requester acknowledges it (one row per overlapping advisory).
- `trg_bookings_check_maintenance` (replaced) blocks overlapping active
  **out-of-service** maintenance on booking DML (BR4 Phase 2).
- `trg_booking_approvals_check_space` (replaced) at approval time: manual overrides,
  out-of-service overlap, and **advisory acknowledgement completeness** covering both
  pathways.
- `trg_booking_advisory_ack_validate` (new): each ack row must reference an active
  advisory overlapping the booking period.

### 4.3 Acknowledgement table & instant-origin model

- `booking_advisory_acknowledgement (ack_id, booking_id, maintenance_id, ...)` with a
  composite unique key `(booking_id, maintenance_id)` — one row per (booking, advisory).
- Instant auto-approval is recorded by inserting
  `booking_approvals(approver_id = -1, decision = 'approved', decision_time, ...)`; the
  origin is **derived** from `approver_id = -1` (the reserved system approver row,
  `role='facility_manager'`). No origin column exists and none is introduced (3NF, Task 09).

### 4.4 Existing defense-in-depth objects (kept; not sufficient alone)

| Object | Purpose | Limitation under concurrency |
|---|---|---|
| `uq_bookings_active_overlap` (filtered unique index: `space_id, requested_start_time` where status confirmed) | cheap same-start collision guard | only same-start; not interval overlap; no serialization |
| `trg_bookings_prevent_overlap` (interval overlap trigger, BR1) | rejects the 10–12 vs 11–13 overlap shape | fires only **inside** the writer's own transaction — two concurrent writers can each pass the check before either commits (classic check-then-act) |
| `trg_bookings_check_maintenance`, `trg_booking_approvals_check_space` | BR4 / BR2 / NR2 gates | same window — a competing writer or ticket can commit between the read and the write |

> Conclusion: these objects are necessary but insufficient. This design adds
> **serialization around the read→re-check→write window**; the triggers and filtered
> index stay as backstop defense-in-depth.

### 4.5 Indexes the design relies on (existing; not tuned here)

- `idx_bookings_time_range (space_id, requested_start_time, requested_end_time)`
- `idx_maintenance_space_id (space_id)`
- `uq_bookings_active_overlap` (filtered unique index)
- `idx_maintenance_status (status)`
- composite unique `(booking_id, maintenance_id)` on the acknowledgement table

Performance tuning of these indexes is Task 15; this design only names the ones the
lock and handoff rely on.

---

## 5. Evaluation of Candidate Strategies

### 5.1 Comparison

| Strategy | Anomalies prevented | Residual gap | Implementation complexity | Concurrency impact | Fit with current schema / SQL Server 2019+ |
|---|---|---|---|---|---|
| (a) `SERIALIZABLE` + key-range locks | Overlap races on a narrow predicate | Correct **only** if every writer's interval predicates lock identical ranges — the four write paths differ in shape; easy to miss (K3/K5 resurface) | High: per-query hints, plan-sensitive | Serializes by predicate, not by space | Poor fit with trigger gates |
| (b) `UPDLOCK, HOLDLOCK` range reads | Same range-blocks as (a) | Same "every writer must be perfect" burden | High | Partial range locking; leaks | Poor fit |
| (c) transaction-owned `sp_getapplock` per space (`space_booking:<space_id>`) | K1, K2, K3, K5; K4 by construction | Coarse serialization (one logical resource per space) so popular spaces contend | Low–medium: one helper, one accounting rule | Serializes on a logical resource; no schema change | Fits — works with every existing trigger, deterministic codes, no plan-sensitivity |
| (d) Optimistic concurrency (version columns / `ROWVERSION`) | Works only with a version column | Task 09 deliberately kept the schema unchanged (no version columns) | Would need schema change | Low (retry) | Rejected — adds schema the approved design lacks |
| (e) Trigger-only (baseline) | — | Cannot serialize two READ COMMITTED writers | Low | none | Baseline only |

### 5.2 Selection

**Selected: transaction-owned `sys.sp_getapplock` on `space_booking:<space_id>`**
— strategy (c).

Valid on SQL Server 2019+ with READ COMMITTED (the database default; no RCSI or new
configuration required). One critical section per space is shared by **all four** write
paths, so instant submit, approval, escalation/downgrade, and ticket creation serialize
against each other. The invariant is re-checked after the lock is held and immediately
before the write. The approach keeps the current normalized schema untouched and is
simple to implement and demonstrate.

Against (a)/(b): they require **every** writer to lock an identical predicate range,
which is a maintenance hazard across four different write shapes and is exactly where
K3/K5 resurface. Against (d): it requires the schema change that Task 09 deliberately
avoided. Against (e): it cannot stop a race.

### 5.3 Lock acquisition contract

Shape fragment (Task 12 implements this exactly; not a runnable script):

```sql
-- inside the SAME transaction as the final check + write
DECLARE @lock_rc INT = -999;
EXEC @lock_rc = sys.sp_getapplock
    @Resource    = N'space_booking:' + CONVERT(NVARCHAR(12), @space_id),
    @LockMode    = 'Exclusive',
    @LockOwner   = 'Transaction',   -- transaction-owned; released at commit/rollback
    @LockTimeout = 5000;            -- 5 s

-- Return -> code (1:1):
--   0             -> proceed (lock acquired)
--  -1 (timeout)   -> 51005 (retryable)
--  -2 (cancelled) -> 51006 (retryable)
--  -3 (deadlock)  -> 51007 (transaction rolled back by the server; caller restarts)
--  -999 (bad param)-> programmer error (THROW, not a result code)
-- The lock MUST be acquired inside the same transaction as the final check + write;
-- release-before-write is invalid.
```

After the lock the workflow re-reads its target rows and re-runs the invariant checks,
then writes; COMMIT releases the lock automatically.

---

## 6. Transaction and Locking Architecture

### 6.1 Lock resource scope and acquisition order

- **Resource:** `space_booking:<space_id>` — one fixed resource string per space,
  shared by all four entry points, so any two writers on the same space serialize.
- **Granularity rationale (per-space, not per-space+day):** a booking interval can
  span days, so a narrower `space_booking:<space_id>:<date>` key would force the
  caller to acquire a *set* of day-keys (with ordering rules and cross-midnight
  pitfalls) before the final re-check — reintroducing exactly the lock-ordering and
  deadlock complexity that a single per-space resource avoids by construction. Per-space
  is therefore chosen for **correctness-simplicity over throughput**; it requires one
  fixed resource per transaction and makes lock cycles between entry points impossible.
  Finer key granularity remains a documented future option (see §11) if measured
  contention ever demands it.
- **Mode:** `Exclusive`. **Owner:** `Transaction` (automatically released at
  COMMIT/ROLLBACK).
- **Timeout:** 5 seconds per acquisition.
- **Acquisition order:** a procedure acquires **at most one** application lock per
  transaction (the space's resource). No second applock in the same unit → no
  application-level lock cycle among entry points; row-level deadlocks against other
  background writers are detected as `-3` and returned `51007`.

### 6.2 Isolation and lock placement

- **Isolation level:** READ COMMITTED (database default; unchanged). `sp_getapplock`
  does not depend on the isolation level — correctness comes from the app lock, not
  from read locks.
- The app lock **must** be acquired inside the transaction that contains the final
  re-check **and** the write. Pre-transaction fast-path *reads* (eligibility hints)
  are allowed because they are re-verified after the lock is held.

### 6.3 Error contract — 1:1 codes

Result codes are the `@result_code` OUT parameter of each procedure. The mapping is
**one distinguishable cause-family per code**: within a single procedure, each
non-zero code is returned for exactly one cause family and business-rejection gates
never share a code. Code `51001` is the generic **request-context bucket**: a procedure
applies it to *any* documented context/input-validation failure (target row not found,
row not in the expected state, or invalid business input, as itemized per workflow in
§7); it is deliberately not split because all such failures share the same handling
(no retry, surface to caller).

| Code | Meaning | Retryable |
|---|---|---|
| `0` | success | — |
| `51001` | Request context invalid (target row not found / not in expected state; invalid business input) | no |
| `51002` | BR4 gate: overlapping active `out-of-service` maintenance blocks the confirmation | no |
| `51003` | BR1: overlapping confirmed booking exists on the space/interval | no |
| `51004` | NR2: advisory acknowledgement(s) missing | no |
| `51005` | App lock: timeout (`-1`) | **yes** |
| `51006` | App lock: cancelled (`-2`) | **yes** |
| `51007` | App lock: deadlock victim (`-3`) | no — restart the unit |
| `51008` | BR2: space is `retired` or `temporarily_closed` | no |
| `51009` | BR3: capacity exceeded | no |

`-999` (invalid applock parameters) is a programmer error only, not a returned code.
Only `51005`/`51006` are retryable; `51007` restarts the whole unit.

### 6.4 Application-layer responsibilities

- Set `sys.sp_set_session_context N'current_user_id', <id>` at the start of each unit
  of work; set NULL at the end (session-scoped; a pooled connection can leak the value).
- Retry `51005`/`51006` with a small bounded backoff; restart the unit on `51007`;
  business codes go to the user/approval denial.
- Never take a second app lock in the same unit; never release the lock before COMMIT.

---

## 7. Workflow Designs

Every workflow: (i) fast-path reads are hints only, (ii) acquire
`space_booking:<space_id>` (Transaction, Exclusive, 5 s), (iii) **re-read all relevant
rows and re-check every invariant immediately before writing**, (iv) COMMIT.

### 7.1 W1 — Instant booking submission (`usp_booking_instant_submit`)

| # | Step | Code (if violated) |
|---|---|---|
| 1 | Validate inputs (end > start, participants > 0) | `51001` |
| 2 | Eligibility fast-path: `space_type ∈ {classroom, computer_lab, project_lab, meeting_room}` (U1), requester `account_status='active'` | `51001` |
| 3 | BEGIN TRAN; acquire lock `space_booking:<space_id>` | `51005/51006/51007` |
| 4 | Re-check: space not `retired`/`temporarily_closed`; capacity; requester still active | `51008` / `51009` / `51001` |
| 5 | Re-check: overlapping confirmed booking (BR1) | `51003` |
| 6 | Re-check: overlapping active out-of-service (BR4) | `51002` |
| 7 | Compute overlapping active advisories (NR2) and prepare one acknowledgement row per advisory | `51004` (if they cannot be produced) |
| 8 | INSERT `bookings (status='pending')` | — |
| 9 | INSERT `booking_advisory_acknowledgement` rows | — |
| 10 | INSERT `booking_approvals (approver_id = -1, decision='approved')` — auto-approval; triggers flip status + backstop gates | trigger errors on corrupted data only |
| 11 | COMMIT; return `0` + `@booking_id` | — |

### 7.2 W2 — Staff approval (`usp_booking_approve`)

| # | Step | Code |
|---|---|---|
| 1 | Validate `@booking_id`; fast-path read booking for `@space_id` | `51001` |
| 2 | Acquire the lock | `51005/51006/51007` |
| 3 | Re-read the booking — still `pending` | `51001` |
| 4 | Re-check BR2 / BR3 / BR1 / BR4 / NR2 | `51008/51009/51003/51002/51004` |
| 5 | INSERT `booking_approvals` with `approver_id` = staff, `decision` = approved/rejected (BR7: `rejection_reason` required when rejected) | `51001` |
| 6 | COMMIT — triggers flip status + backstop | — |

### 7.3 W3 — Maintenance escalation/downgrade (`usp_maintenance_set_impact_level`)

| # | Step | Code |
|---|---|---|
| 1 | Validate: maintenance exists, status `open`/`in_progress`, target differs from current (same level → no-op `0`) | `51001`; same level → `0` |
| 2 | Acquire the lock (from the maintenance's `space_id`) to serialize vs in-flight confirmations | `51005/51006/51007` |
| 3 | Re-read the maintenance — still actionable | `51001` |
| 4 | Set `SESSION_CONTEXT('current_user_id')`; UPDATE `maintenance SET impact_level = @new` — history trigger (NR3) + status recompute; **no booking DML** (D1) | — |
| 5 | COMMIT; return `0` | — |

**Why lock if it writes no bookings?** Escalation to `out-of-service` changes which
intervals become invalid. Locking it against in-flight confirmations of the space
guarantees a booking is never confirmed against a stale "advisory only" view while the
escalation commits (K3). The two serialize: either the booking is rejected `51002`
(escalation won) or it is confirmed first and appears in report #4's affected set
(confirmed-then-reported per NR4). Pending requests are not mutated (D1).

### 7.4 W4 — Maintenance ticket creation (`usp_maintenance_report`)

The new-ticket path is a **first-class write procedure** so a blocking
(`out-of-service`) ticket can never slide past an in-flight confirmation (K5).
Because `impact_level` defaults to `out-of-service` at the column level, the procedure
always passes the level explicitly — an advisory ticket must never be created through
the default silently.

| # | Step | Code |
|---|---|---|
| 1 | Validate: space exists; reporter active; `start_time` set; `impact_level` explicit (`'advisory'` or `'out-of-service'`); problem description present | `51001` |
| 2 | **Lock only for blocking tickets:** if `@impact_level = 'out-of-service'` → BEGIN TRAN, acquire the lock; **advisory** tickets need no lock (they block nothing, they only add an NR2 obligation) | `51005/51006/51007` |
| 3 | Re-read the space row inside the critical section — exists and not soft-deleted | `51001` |
| 4 | INSERT `maintenance` (space_id, reporter_id, problem_description, start_time, status='open', impact_level=@level, …) | — |
| 5 | COMMIT (locked path); return `0` + `@maintenance_id` | — |

**Interaction with confirmed bookings:** a new `out-of-service` ticket does **not**
reject or cancel existing confirmed bookings — those are identified later via report
#4 (NR4 semantics). The lock is for serialization only: a confirmation arriving after
the ticket commits fails the BR4 gate with `51002`; a confirmation that lands first
shows up in the affected set. The booking side therefore holds the only rejection; the
ticket side never rejects.

> **Boundary (non-contractual DML):** writing `INSERT INTO dbo.maintenance` directly
> (client code that bypasses `usp_maintenance_report`) takes no lock and reopens the
> K5 window. Application code must route ticket creation through this procedure. This
> is an implementation-governance boundary, not a designed-in gap.

### 7.5 Read paths — room finder / availability

Classified as an **advisory hint**. Read-only queries answer "which spaces look free
in window W" as of a point in time; correctness of NR6 does not depend on them, and
they can never approve a booking. The final guarantee comes from W1/W2, which re-check
inside the critical section (K4).

---

## 8. Conflict Coverage Matrix

| Conflict | Prevention mechanism | Coverage |
|---|---|---|
| K1 read-then-write availability race | Both confirmation paths (W1/W2) take the same per-space lock and re-check BR1/BR4 under it | ✅ §7.1–7.2 |
| K2 distinct-pathway overlap (instant vs staff) | Same lock, same final re-check | ✅ §7.1–7.2 |
| K3 escalation vs in-flight booking | Escalation takes the same lock; serializes with confirmations | ✅ §7.3 |
| K4 stale state read | Reads are hints; only locked confirmations decide | ✅ §7.5 |
| K5 ticket creation vs in-flight booking | Ticket creation is a 4th entry path (W4) that takes the same lock when the ticket is `out-of-service` | ✅ §7.4 |

All five conflicts from Task 08 are covered. The only remaining risk is
**non-contractual raw DML** (bypassing the four procedures), which is a documented
application-governance boundary (§7.4 boundary, §10) — not a sanctioned workflow.

---

## 9. Task 12 Implementation Guidance

Exactly four entry procedures (all `dbo`), each transaction-owned and acquiring the
per-space lock:

1. `usp_booking_instant_submit`
   - Params: `@space_id, @requester_id, @purpose, @expected_participants,
     @requested_start_time, @requested_end_time` → `@booking_id OUT, @result_code OUT,
     @message OUT`.
2. `usp_booking_approve`
   - Params: `@booking_id, @approver_id, @decision, @rejection_reason, @decision_note`
     → `@result_code OUT, @message OUT`.
3. `usp_maintenance_set_impact_level`
   - Params: `@maintenance_id, @new_impact_level, @reason` (changed_by from
     SESSION_CONTEXT) → `@result_code OUT, @message OUT`.
4. `usp_maintenance_report` (ticket creation — the K5 closure)
   - Params: `@space_id, @reporter_id, @problem_description, @start_time, @impact_level`
     (default `'advisory'`) → `@maintenance_id OUT, @result_code OUT, @message OUT`.

Return codes: the `51001`–`51009` table (§6.3), one per cause; retryable `51005`/`51006`.

Application-layer duties: set/clear `SESSION_CONTEXT`; bounded retry on `51005/51006`;
restart the unit on `51007`; route ticket creation through procedure 4 (never a raw
`INSERT` of an `out-of-service` ticket).

---

## 10. Task 13 Test Guidance

Two-session scripts (Session A / Session B). Assert on **result codes**, not on "who
wrote first"; small seeded dataset; each body in its own transaction; end each with
the overlap-invariant audit query.

| # | Scenario | Winner | Loser |
|---|---|---|---|
| T1 | Two concurrent instant submits, same space and overlap (K1) | success (`0`), booking approved | `51003` |
| T2 | Instant submit vs staff approve on overlap (K2) | approved | `51003` |
| T3a | Escalation to `out-of-service` first, then instant submit | escalation `0`; submit `51002` | — |
| T3b | Instant submit first, then escalation | submit approved; escalation `0`; booking in report #4 set | — |
| T4 | Escalation leaves a pending booking untouched (D1) | booking stays `pending` | later approval → `51002` |
| T5 | App lock timeout (session A holds, session B waits > 5 s) | — | `51005` |
| T6 | Forced deadlock `1205` | other session succeeds | victim `51007` |
| T7 | Retry after lock frees | second attempt `0` | — |
| T8 | Invariant audit: overlapping confirmed bookings = 0 | 0 rows | — |
| T9 | `out-of-service` ticket creation vs instant submit (K5): ticket first then submit, and submit first then ticket | submit `51002` (ticket won) or `0` + booking in report #4 set (submit won) | — |
| T10 | Two concurrent staff approvals of different pending bookings on the same space/overlap (staff-vs-staff; K1 shape through the W2 code path) | first approve `0` | other approve `51003` |

---

## 11. Assumptions, Risks, Boundaries

- **Assumptions:** SQL Server 2019+; READ COMMITTED; no schema change beyond Task 10
  (no version columns, no RCSI requirement); confirmed-status set §4.1.
- **Risks:**
  - **Hotspot-space contention:** per-space serialization queues a popular space's
    writers; mitigated by small critical sections (no UI waits inside), 5 s timeout,
    and `51005/51006` retry. This coarse granularity is a deliberate correctness/
    simplicity-vs-throughput trade-off (see §6.1) and is acceptable at the volumes
    the system is designed for: Task 14 requires ≥100k bookings over three academic
    years (≈33k–170k/year), so even a busy room sees only tens of writes per day and
    each critical section is sub-millisecond — a 5 s timeout is multiple orders of
    magnitude above the expected wait. If monitoring ever shows real contention on a
    specific space, a finer `space_booking:<space_id>:<date>` key is the documented
    tuning lever (adoption delayed because it reintroduces day-set acquisition
    ordering).
  - **SESSION_CONTEXT leakage:** pooled connections can carry a stale
    `current_user_id`; the app sets/clears per unit; audit falls back to `-1`.
  - **Non-contractual raw DML** (any INSERT/UPDATE that bypasses the four procedures)
    reopens K5/K3; enforced by application convention and Task 13 tests, not by the
    database alone.
  - **Deadlock (`-3`):** detected and returned `51007`; restart, no silent retry.
- **Boundaries:** no schema change (this design adds no tables/columns/indexes/
  triggers; only procedures); index tuning is Task 15; analytical queries are Task 16;
  Task 12/13 implement the scripts this document only specifies.

---

## 12. Revision Log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-08-06 | First issue covering three write paths (instant submit, approval, escalation/downgrade) with the per-space app lock strategy. |
| 2.0 | 2026-08-06 | Expanded to four write paths: added `usp_maintenance_report` (ticket creation) as the K5 closure; added T9 test scenario; clarified the error-code and lock contract wording. |
