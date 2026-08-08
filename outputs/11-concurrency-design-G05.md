# Concurrency Design — Campus Space Management System (Phase 2)

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Phase:** 2 · **Task:** 11
**Date:** 2026-08-08
**Doc version:** 3.4

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
path is treated as an advisory hint (§7.5). This document is design-only: it hands a
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
> creation a locked entry point that shares the per-space critical section (§6.1)
> whenever the ticket starts at the blocking impact level. Only a raw,
> out-of-contract `INSERT INTO dbo.maintenance` that bypasses the entry point
> reintroduces the window; that non-contractual access is documented as an
> application-boundary risk (§7.4 boundary, §11), not silently shipped as an approved
> workflow.

### 2.2 How the design prevents each conflict

Every workflow that can **change whether a time interval on a space is confirmed**
(instant submit, staff approval, escalation/downgrade, ticket creation) serializes on
one logical resource per space, re-checks the invariants **after** acquiring the lock
and **immediately before** the write, then writes. K1, K2, K3, and K5 therefore cannot
both commit. K4 is neutralized because the final authority always lives in the locked
confirmation steps — a read result is only ever a hint.

---

## 3. Resolved Design Ambiguities & Decisions

| # | Question | Decision + rationale | Effect on Tasks 12 / 13 / reporting |
|---|---|---|---|
| DD1 | Does escalation to `out-of-service` affect **pending** requests too? | **No — approved bookings only.** Escalation does **no booking DML**; pending bookings stay `pending` and are rejected with `51002` only at approval time (BR2/NR4). | W3 writes no booking row. T4: later approval fails `51002`. Report #4 covers approved only. |
| DD2 | Which write paths must be inside the critical section? | **All four** — instant submit, staff approval, escalation/downgrade, ticket creation. Omitting the last leaves K5 (BR4/NR6 hole); one shared lock (§6.1) closes it. | Task 12 implements all four. T9 covers K5. Report #4 unchanged (escalation-scoped; §7.4). |
| DD3 | How are read-only room-finder / availability reads treated? | **Advisory hints only** — reads never serialize or confirm; the locked confirmation paths re-check (NR6). | Confirmations re-read predicates post-lock. No read "freshness" asserted. |
| DD4 | How is `changed_by` captured on maintenance level changes? | **`sys.sp_set_session_context(N'current_user_id', <id>)`** set at unit start, cleared at end; fallback = reserved approver `-1` (Task 10 handoff). | T13 asserts history attribution with and without context. |
| DD5 | How do **soft-gate failures** (instant check 1 — purpose membership) behave? | **Pending fallback, not an error** (A09-6): booking is created `pending` (hard gates still enforced), no auto-approval row, returns `0` with `@instant_accepted = 0`; W2 decides later. Hard-gate failures keep the §6.3 codes. Purpose membership is the **only** soft gate (v2.5 duration cap removed upstream). | Task 12 implements W1 (`@instant_accepted` OUT) and W2 (approval of such `pending` rows). T11/T12 assert; no new error code introduced. |
| DD6 | At **staff approval** the NR2-completeness gate (`trg_booking_approvals_check_space`, §4.2) fails `51004` when ack rows are missing — what repairs the set? | **W2 is the repair source.** Under the lock, W2 re-reads the active advisories overlapping the interval and inserts any missing ack rows (`acknowledged_by` = requester, `acknowledged_at` = now); never invents rows for non-overlapping advisories. | Task 12 W2 step 5. T13 asserts the approval succeeds and ack rows exist. No schema change. |

---

## 4. Current Database Baseline & Contract

Schema facts below come from the frozen Phase 1 DDL
(`outputs/05-db-definition-G05.sql`) and the approved Phase 2 migration
(`outputs/10-schema-migration-G05.sql`); the logical rationale is documented in
`outputs/09-updated-erd-and-logical-design-G05.md`.

### 4.1 The "confirmed" booking status set (BR1 / NR6)

- **`'approved'`, `'checked_in'`, `'completed'`** (with `is_deleted = 0`) form the
  confirmed predicate for every overlap check; `pending` / `rejected` / `cancelled` /
  `no_show` are **not** confirmed.

### 4.2 Maintenance impact levels (advisory vs out-of-service)

- `impact_level VARCHAR(50) NOT NULL DEFAULT 'out-of-service'`, `CHECK (impact_level IN
  ('advisory','out-of-service'))` (Task 10). The default preserves Phase 1 blocking
  semantics for legacy/ad-hoc rows, so the ticket procedure always passes the level
  explicitly (§7.4).
- **out-of-service** blocks any overlapping booking; **advisory** permits it provided the
  requester acknowledges it (one ack row per overlapping advisory).
- Triggers: `trg_bookings_check_maintenance` — blocks overlapping active out-of-service
  maintenance on booking DML (BR4); `trg_booking_approvals_check_space` — approval-time
  manual overrides, out-of-service overlap, and advisory acknowledgement completeness;
  `trg_booking_advisory_ack_validate` (new) — each ack row must reference an active
  advisory overlapping the booking period.

### 4.3 Acknowledgement table & instant-origin model

- `booking_advisory_acknowledgement (ack_id, booking_id, maintenance_id, ...)` with the
  composite unique `(booking_id, maintenance_id)` — one row per (booking, advisory).
- Instant auto-approval = a `booking_approvals` row with `approver_id = -1` (the
  reserved system approver, `role='facility_manager'`); origin is **derived**, never
  stored (3NF, Task 09).

### 4.4 Existing defense-in-depth objects (kept; not sufficient alone)

| Object | Purpose | Limitation under concurrency |
|---|---|---|
| `uq_bookings_active_overlap` (filtered unique index: `space_id, requested_start_time`, confirmed statuses) | cheap same-start collision guard | same-start only; no interval overlap, no serialization |
| `trg_bookings_prevent_overlap` (interval overlap trigger, BR1) | rejects the 10–12 vs 11–13 shape | fires inside the writer's own transaction — two concurrent writers can each pass before either commits (classic check-then-act) |
| `trg_bookings_check_maintenance`, `trg_booking_approvals_check_space` | BR4 / BR2 / NR2 gates | same window — a competing writer or ticket can commit between the read and the write |

> Conclusion: necessary but insufficient. The design adds **serialization around the
> read→re-check→write window**; these triggers and the filtered index remain as backstop
> defense-in-depth.

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

For completeness, the **rejected** candidate strategies that were evaluated are shown
briefly; the selection is argued entirely in §5.2, so the chosen strategy is not
repeated here.

| Strategy | Anomalies prevented | Why not chosen |
|---|---|---|
| (a) `SERIALIZABLE` + key-range locks | Overlap races on a narrow predicate | Fails criterion 1 — serializes by predicate, not by space; needs **identical** interval-range locks from every write path, but the four write shapes differ; an off-by-one range re-opens K3/K5; plan-sensitive |
| (b) `UPDLOCK, HOLDLOCK` range reads | Same range-blocks as (a) | Same "identical ranges" burden as (a); partial range locking leaks past gaps |
| (c) Optimistic concurrency (version columns / `ROWVERSION`) | Conflicts only detected if a version column exists | Fails criterion 2 — requires the schema change (version column) that Task 09 deliberately kept out |
| (d) Trigger-only (baseline) | — | Fails criterion 1 — cannot serialize two READ COMMITTED writers; this is precisely the race that Task 11 exists to close |
| (e) RCSI / snapshot isolation | Read-consistency only; K4 | Read-side mechanism only, writers check-then-act race (K1/K2) remains unsolved |

### 5.2 Selection

**Selected: transaction-owned `sys.sp_getapplock` on `space_booking:<space_id>`.**
Valid on SQL Server 2019+ with READ COMMITTED (the database default; no new
configuration required). This is the only candidate that satisfies **all five**
criteria the design stands on:

1. **One shared critical section per space across all four write paths** — the same
   per-space lock is taken by instant submit, staff approval, escalation/downgrade,
   and ticket creation, so every pair of writers on the same space serializes. That
   is exactly what closes K1, K2, K3 and K5 simultaneously (K4 by construction,
   §7.5).
2. **No schema change** — the approach adds only procedures; the Task 09 schema (no
   version columns) stays untouched.
3. **Works with the existing backstop objects** — the triggers and filtered index of
   §4.4 remain the defense-in-depth under the lock; the strategy replaces no object,
   only serializes the read→re-check→write window they cannot close alone.
4. **Deterministic, testable contract** — each lock outcome maps 1:1 to a result code
   (`51005`/`51006` retryable; `51007` restart; §6.3), which Task 13 can assert
   deterministically.
5. **Config-free correctness** — correctness comes from the app lock, not from
   isolation levels or query hints; it holds under the database default
   READ COMMITTED and is plan-independent.

Plainly put: the invariant is re-checked **after** the lock is held and **immediately
before** the write, and COMMIT releases the lock automatically.

Why the others were dropped — each fails at least one of the five:

- **(a)/(b)** fail criterion 1: range-/hint-lock schemes are correct only when
  **every** writer locks an identical predicate range — an obligation the four
  different write shapes cannot guarantee, and exactly where K3/K5 resurface. They
  are also plan-sensitive (violates criterion 5).
- **(c)** fails criterion 2: it requires the version column that Task 09 deliberately
  excluded from the approved schema.
- **(d)** fails criterion 1 and 5: a trigger fires inside the writer's own transaction
  — two concurrent READ COMMITTED writers check and both pass before either commits;
  that is the race this task closes.
- **(e) RCSI** fails the write-write requirement: snapshot/read-committed-snapshot
  guarantees only what a **reader** sees (K4); two concurrent writers can still both
  commit — no serialization exists at the write side.
- **`TABLOCKX` (table lock)** — correct but far coarser: it serializes the whole
  `bookings` table across every space, turning a busy campus into one global queue;
  per-space resource is the right grain for the target workload.

The cost of the choice is documented, not hidden: one logical resource per popular
space means writers queue on it (mitigated by the 5 s timeout, retry codes, and the
Task 14 volume analysis — §6.1, §11).

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

### 6.3 Error contract — cause-family codes

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

> **Soft instant-gate failures are not codes.** Failing the soft instant gate (Task 09
> v2.6 check 1: purpose membership) returns `0` with
> `@instant_accepted = 0` — the booking is created `pending` for the W2 workflow
> (§7.1, DD5). No error code is spent on a non-error; the cause-family rule
> (§6.3) is preserved. The v2.5 duration-cap gate no longer exists (Task 09 v2.6 /
> Task 10 rev 5), so there is nothing else that can fail softly.

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
| 2 | **Fast-path soft hint (data-driven, Task 09 v2.6):** resolve `space_id → space_type` (JOIN `spaces`); check 1 `(space_type, purpose) ∈ space_type_allowed_purpose`. A soft failure is **not an error** — it zeroes `@instant_accepted` (fallback to pending). No duration gate exists (v2.6) | no code (fallback, §6.3 note) |
| 3 | BEGIN TRAN; acquire lock `space_booking:<space_id>` | `51005/51006/51007` |
| 4 | Re-check (hard): space not `retired`/`temporarily_closed` (BR2); capacity (BR3); requester still `active` — and **re-run the soft gate (check 1) from the post-lock read** to finalize `@instant_accepted` | `51008` / `51009` / `51001` |
| 5 | Re-check: overlapping confirmed booking (BR1) | `51003` |
| 6 | Re-check: overlapping active out-of-service (BR4) | `51002` |
| 7 | Compute overlapping active advisories (NR2) and prepare one acknowledgement row per advisory | `51004` only on trigger-rejected rows (completeness is checked again at approval) |
| 8 | INSERT `bookings (status = 'pending')` | — |
| 9 | INSERT `booking_advisory_acknowledgement` rows | — |
| 10 | **IF `@instant_accepted = 1`** (all gates passed): INSERT `booking_approvals (approver_id = -1, decision='approved')` — auto-approval; triggers flip status + backstop gates. **ELSE** (soft-gate fallback, A09-6): no approval row — the booking stays `pending` for the W2 staff workflow | trigger errors on corrupted data only |
| 11 | COMMIT; return `0` + `@booking_id` + `@instant_accepted` | — |

> **Soft vs hard (Task 09 v2.6 A09-6):** a failed soft gate (check 1 only) never rejects —
> the booking is created `pending` and the procedure returns `0` with
> `@instant_accepted = 0`; hard-gate failures return the §6.3 codes and create
> nothing. The hard gates (account `active`, capacity, BR1, BR4) are the ones that
> serialize under the per-space lock; a `pending` booking is not in the confirmed set
> (§4.1) and therefore blocks nothing in the mean time — it only matters when W2
> later confirms it.

### 7.2 W2 — Staff approval (`usp_booking_approve`)

| # | Step | Code |
|---|---|---|
| 1 | Validate `@booking_id`; fast-path read booking for `@space_id` | `51001` |
| 2 | Acquire the lock | `51005/51006/51007` |
| 3 | Re-read the booking — still `pending` | `51001` |
| 4 | Re-check BR2 / BR3 / BR1 / BR4 / NR2 | `51008/51009/51003/51002/51004` |
| 5 | **NR2 repair (DD6):** insert any ack rows missing for active advisories overlapping the interval (`acknowledged_by` = requester, `acknowledged_at` = now, per §4.2 gate) | `51001` (if rows cannot be produced) |
| 6 | INSERT `booking_approvals` with `approver_id` = staff, `decision` = approved/rejected (BR7: `rejection_reason` required when rejected) | `51001` |
| 7 | COMMIT — triggers flip status + backstop | — |

### 7.3 W3 — Maintenance escalation/downgrade (`usp_maintenance_set_impact_level`)

| # | Step | Code |
|---|---|---|
| 1 | Validate: maintenance exists, status `open`/`in_progress`, target differs from current (same level → no-op `0`) | `51001`; same level → `0` |
| 2 | Acquire the lock (from the maintenance's `space_id`) to serialize vs in-flight confirmations | `51005/51006/51007` |
| 3 | Re-read the maintenance — still actionable | `51001` |
| 4 | Set `SESSION_CONTEXT('current_user_id')`; UPDATE `maintenance SET impact_level = @new` — history trigger (NR3) + status recompute; **no booking DML** (DD1) | — |
| 5 | COMMIT; return `0` | — |

**Why lock if it writes no bookings?** Escalation to `out-of-service` changes which
intervals become invalid. Locking it against in-flight confirmations of the space
guarantees a booking is never confirmed against a stale "advisory only" view while the
escalation commits (K3). The two serialize: either the booking is rejected `51002`
(escalation won) or it is confirmed first and appears in report #4's affected set
(confirmed-then-reported per NR4). Pending requests are not mutated (DD1).

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
reject or cancel existing confirmed bookings. **Report #4 scope:** report #4 (doc 09
§C.1/§A.2.3; implemented by Task 16 query Q5 — "confirmed bookings affected by
escalation") is **escalation-scoped and ack-joined** — it surfaces only
bookings that acknowledged an active advisory at booking time (the T3a/T3b case). A
booking confirmed **before any advisory existed** on the space — the K5 submit-wins
case — has no acknowledgement row and no escalation event, so it lies **outside report
#4's scope** and needs a separate discovery path (a direct time-overlap check, out of
Task 11 scope — see the T9 note in §10). The lock is for serialization only: a
confirmation arriving after the ticket commits fails the BR4 gate with `51002`; a
confirmation that lands first stays valid. The booking side therefore holds the only
rejection; the ticket side never rejects.

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
application-governance boundary (§7.4 boundary, §11) — not a sanctioned workflow.

---

## 9. Task 12 Implementation Guidance

Exactly four entry procedures (all `dbo`), each transaction-owned and acquiring the
per-space lock:

1. `usp_booking_instant_submit`
   - Params: `@space_id, @requester_id, @purpose, @expected_participants,
     @requested_start_time, @requested_end_time` → `@booking_id OUT, @instant_accepted
     OUT, @result_code OUT, @message OUT`.
   - Soft gate (Task 09 v2.6 check 1): `(space_type, purpose)` membership in
     `space_type_allowed_purpose` (space resolved via JOIN) → `@instant_accepted = 0`
fallback to `pending`, result `0`; hard gates — doc 09 checks 2–5 (account
      `active`, capacity/BR3, BR1 overlap, BR4 out-of-service) **plus the baseline BR2
      availability gate** (`retired`/`temporarily_closed`, `51008`) — return the §6.3
      codes.
2. `usp_booking_approve`
   - Params: `@booking_id, @approver_id, @decision, @rejection_reason, @decision_note`
     → `@result_code OUT, @message OUT`.
   - NR2 repair (DD6): insert missing ack rows for overlapping advisories
     (`acknowledged_by` = requester) before the approval `INSERT`, so the §4.2
     completeness gate can never deadlock an approvable booking.
3. `usp_maintenance_set_impact_level`
   - Params: `@maintenance_id, @new_impact_level, @reason` (changed_by from
     SESSION_CONTEXT) → `@result_code OUT, @message OUT`.
4. `usp_maintenance_report` (ticket creation — the K5 closure)
   - Params: `@space_id, @reporter_id, @problem_description, @start_time, @impact_level`
     (default `'advisory'`) → `@maintenance_id OUT, @result_code OUT, @message OUT`.

Return codes: the `51001`–`51009` table (§6.3), one per cause-family; retryable `51005`/`51006`.

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
| T4 | Escalation leaves a pending booking untouched (DD1) | booking stays `pending` | later approval → `51002` |
| T5 | App lock timeout (session A holds, session B waits > 5 s) | — | `51005` |
| T6 | Forced deadlock `1205` | other session succeeds | victim `51007` |
| T7 | Retry after lock frees | second attempt `0` | — |
| T8 | Invariant audit: overlapping confirmed bookings = 0 | 0 rows | — |
| T9 | `out-of-service` ticket creation vs instant submit (K5): ticket first then submit, and submit first then ticket | submit `51002` (ticket won) or `0` + booking confirmed (submit wins; **not discoverable via report #4** — scope note below) | — |
| T10 | Two concurrent staff approvals of different pending bookings on the same space/overlap (staff-vs-staff; K1 shape through the W2 code path) | first approve `0` | other approve `51003` |
| T11 | Instant submit whose purpose is **not allowed** by `space_type_allowed_purpose` (soft gate check 1 fails — the only soft gate in v2.6; there is no duration gate, so no second sub-case exists) | result `0`, `@instant_accepted = 0`, booking stays `pending`, **no** auto-approval row | — |
| T12 | Soft-gate fallback vs instant confirmation on the same space/overlap: the pending-fallback booking is created alongside an instant-confirmed one (pending is not confirmed, §4.1); later staff approval of the pending one is rejected | both succeed — fallback `0` (`@instant_accepted = 0`, stays `pending`) and instant `0` (approved) | later approval of the pending → `51003` |
| T13 | Staff approval of a `pending` booking overlapped by an active **advisory** whose ack rows were never inserted (DD6): W2 repairs the ack set inside the critical section | approve `0`; ack rows exist for every overlapping advisory; complete-set rows present | — |

> **Report #4 scope note (T9):** report #4 (doc 09 §C.1/§A.2.3; implemented by Task 16
> query Q5 — "confirmed bookings affected by escalation") is escalation-scoped and
> ack-joined — it surfaces bookings that acknowledged an active
> advisory at booking time (T3a/T3b). The K5 submit-wins branch of T9 (booking confirmed
> before any advisory existed) has **no acknowledgement row and no escalation event**, so
> it is **outside report #4's scope**; discovering it requires a separate direct
> time-overlap check (§7.4), which Task 12/13 do not implement.

**Conflict → scenario trace (G6):** K1 → T1 (same-path instant) and T10 (same-path
staff); K2 → T2; K3 → T3a/T3b (and T4, escalation vs pending); K5 → T9; K4 →
T8 plus the outcome assertions of T1–T13 — K4 is closed by construction (§7.5:
reads are hints), so no scenario asserts a read's "freshness", which would
contradict the design. Homogeneous pairings: instant-vs-instant (T1) and
staff-vs-staff (T10) are covered explicitly. Escalation-vs-escalation and
ticket-vs-ticket are **redundant by design**: neither path confirms a booking
interval — escalation/downgrade and ticket creation only invalidate intervals, so
two such writers cannot create a duplicate confirmed overlap on their own; the
only observable conflict is with a confirmation (T3a/T3b/T9), which is covered.

---

## 11. Assumptions, Risks, Boundaries

- **Assumptions:** SQL Server 2019+; READ COMMITTED; no schema change beyond Task 10 (no version columns, no RCSI); confirmed-status set §4.1; instant eligibility **data-driven** — `space_type_allowed_purpose` is seeded by the Task 10 migration for the four approved types, **no duration cap anywhere** (the v2.5 `max_hours` column does not exist in rev 5), so an empty junction means no instant acceptances (all fall back to `pending`, never a code).
- **Risks:**
  - **Hotspot contention:** per-space serialization queues a busy room's writers; mitigated by small critical sections, 5 s timeout, and `51005/51006` retry. Coarse granularity is a deliberate correctness/simplicity-vs-throughput trade-off (§6.1), acceptable at the designed volumes (Task 14: ≥100k bookings over three academic years → tens of writes/day per room, sub-millisecond critical sections vs a 5 s timeout). If monitoring shows real contention, a finer `space_booking:<space_id>:<date>` key is the documented tuning lever (§6.1; delayed because it reintroduces day-key acquisition ordering).
  - **SESSION_CONTEXT leakage:** pooled connections can carry a stale `current_user_id`; the app sets/clears per unit; audit falls back to `-1`.
  - **Raw DML** bypassing the four write procedures reopens K5/K3 — closed by application convention + Task 13 tests; a database-level closure is the recommended Task 12 hardening (`DENY` table writes + `GRANT EXECUTE` only, ownership chaining; Task 14/test seeding run as an elevated principal).
  - **Deadlock (`-3`):** returned `51007`; restart, no silent retry.
- **Boundaries:** this design adds no tables/columns/indexes/triggers — only procedures; index tuning is Task 15; analytical queries are Task 16; Task 12/13 implement the scripts this document specifies.

---

## 12. Revision Log

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-08-06 | Initial design: three write paths (instant submit, staff approval, escalation/downgrade) with the per-space app lock strategy. |
| 2.0 | 2026-08-06 | Scope expanded to four write paths: `usp_maintenance_report` (ticket creation) closes K5; T9 added; error-code and lock contract clarified. |
| 2.5 | 2026-08-06 | Review: error-contract softened to cause-family codes (`51001` = generic bucket); T10 (staff-vs-staff) added; lock-granularity rationale + volume grounding (§6.1/§11); raw-DML closure via `DENY` + `GRANT EXECUTE`. |
| 3.0 | 2026-08-08 | Review: §5.1 comparison condensed to 3 columns; §5.2 rewritten as requirement-driven selection; no design change. |
| 3.1 | 2026-08-08 | Task 09 v2.5 alignment: data-driven usage policy — soft gates 1+4 (junction membership, `max_hours` cap) with `@instant_accepted = 0` pending fallback; DD5; T11/T12. |
| 3.2 | 2026-08-08 | Review fix: W2 ack-set repair closes the NR2 approval deadlock (DD6); T13; W1 step-7 wording. No strategy change. |
| 3.3 | 2026-08-08 | Task 09 v2.6 / Task 10 rev 5 alignment: duration cap removed — soft gate = check 1 (purpose) only; hard gates checks 2–5; §6.3 heading → cause-family; G6 conflict→scenario trace added. No strategy/code/scope change. |
| 3.4 | 2026-08-08 | Review: Report #4 scope limitation — the escalation-ack-joined report cannot surface K5 submit-wins bookings (no ack row, no escalation event); T9 corrected (§7.4/§10); Q5 citation clarified; §9 hard-gate list now names the baseline BR2 gate. No strategy change. |
