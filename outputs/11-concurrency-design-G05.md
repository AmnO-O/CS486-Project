# Concurrency Design — Campus Space Management System (Phase 2)

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Phase:** 2 · **Task:** 11
**Date:** 2026-08-04

---

## 1. Overview

### 1.1 Task scope

Task 11 designs how the Phase 2 system prevents concurrency anomalies, above all the
NR6 invariant:

> Two approved bookings must never use the same space during overlapping time periods,
> regardless of whether the bookings are created through instant booking or staff
> approval, even when multiple users or staff operate concurrently.

Task 11 is a **design handoff**. It selects the SQL Server concurrency mechanism,
defines the transaction/locking/error/retry contract, and specifies the workflow
designs that Task 12 will implement as database entry points and that Task 13 will
demonstrate with concurrent-session tests.

**Task 11 does not:**
- implement Task 12 stored procedures, triggers, or runnable SQL;
- create Task 13 two-session test files;
- tune indexes or record execution-plan timings (Task 15);
- write analytical queries (Task 16);
- add new schema — the design below introduces **no schema change** (no new tables,
  columns, indexes, or triggers); the only new database object is the fourth
  entry-point stored procedure `usp_maintenance_report` (§9.4, closes K5), which
  Task 12 implements like the other three.

### 1.2 Dependencies read

| Source | Role |
|---|---|
| `docs/project_phase2_description.md` | Authoritative Phase 2 source (NR6 wording, §1.2) |
| `docs/design-decisions.md` | Recorded decisions (Option-B unfreeze; derived origin `approver_id = -1`; `current_status` recompute; `SESSION_CONTEXT` audit) |
| `docs/tech-stack.md` | SQL Server 2019+ / T-SQL, naming conventions, enums |
| `docs/schema-registry.md` | Tables, indexes, business-rule coverage (current source of truth) |
| `docs/entity-registry.md` | Conceptual entities/relationships |
| `memory/Progress.md` | Task approvals and open-question status (U3 ⬜ → resolved this run) |
| `memory/ActiveContext.md` | Task 10 handoff notes (SESSION_CONTEXT contract) |
| `outputs/08-requirement-change-analysis-G05.md` | Conflict inventory K1–K5 (K5 — maintenance-ticket creation race — added retro in Task 12 rev 1, mirrored here in §4.2/§7/§9.4/§10) |
| `outputs/09-updated-erd-and-logical-design-G05.md` | Approved Phase 2 design (Areas 1–3) |
| `outputs/10-schema-migration-G05.sql` (+ rollback) | Implemented DB/app contract (triggers, tables, system user `-1`) |

---

## 2. Gate and Source Check

### 2.1 Upstream approval status

| Upstream | Status | Gate for Task 11 |
|---|---|---|
| Task 08 — requirement-change analysis | ✅ Approved | Conflict inventory K1–K5 read from current output (K5 added retro in Task 12 rev 1) |
| Task 09 — updated ERD + logical design | ✅ Approved | Approved schema/rationale read from current output |
| Task 10 — schema migration + rollback | ✅ Approved (2026-08-04) | Implemented trigger/table/app contract read from current SQL |
| Task 11 | ⬜ next unstarted Phase 2 task | **Gate passes** — run mode `overwrite` on first generation |

### 2.2 Open questions relevant to Task 11

| # | Question | Status before this run | Status now |
|---|---|---|---|
| U3 | Does escalation to out-of-service affect pending requests or only already-approved bookings? | ⬜ pending (assigned to Task 11) | ✅ **Resolved this run** by explicit user decision (see §3) |
| U4 | "Semester" reporting window definition | ⬜ assigned to Task 16 | Not a Task 11 gate; carried forward unchanged |

No other open question gates Task 11. The Task 11 skill's gate is therefore cleared.

### 2.3 Source conflicts found

None. `docs/design-decisions.md`, both registries, and the Task 08/09/10 outputs agree
on: the confirmed-status set, the impact-level semantics, the derived instant origin
(`approver_id = -1`), the ack table shape, and the trigger inventory. No contradiction
required a silent choice.

---

## 3. Resolved Task 11 Ambiguities

### 3.1 U3 — Escalation scope: pending vs approved bookings

| | |
|---|---|
| **Question** | When an advisory maintenance is escalated to `out-of-service`, does the escalation also affect **pending** booking requests that overlap the maintenance period, or only **already-approved** bookings? |
| **Final decision** | **Only already-approved bookings.** Pending bookings are **not mutated** by an escalation. They remain `pending`; while the `out-of-service` overlap persists, any later approval attempt — staff or instant — fails the existing out-of-service gate in `trg_booking_approvals_check_space` (deterministic error `51002 MAINTENANCE-OOS`). NR4's affected-booking report (§1.3 report #4) covers only approved bookings, exactly as the Phase 2 requirement words it ("already-approved bookings that overlap the maintenance period must be identified"). |
| **Rationale** | (1) Phase 2 §1.1 scopes NR4 explicitly to *already-approved* bookings; extending it to pending requests would add an unrequested side effect. (2) It is consistent with the recorded BR2 decision ("block at approval time, not at request time" — pending requests may exist on any space); an escalation is exactly the case where a pending request becomes unapprovable, and the approval-time gate already expresses that. (3) It avoids a new maintenance-side trigger that would have to auto-cancel/reject pending bookings, which would force decisions on who records the decision and how BR7 (rejection requires reason) is satisfied for mass-transitioned rows. (4) No new schema or trigger — the existing gate is the single enforcement point. |
| **Downstream impact** | **Task 12:** the escalation entry point (`usp_maintenance_set_impact_level`) performs **no booking DML** — it only updates `maintenance.impact_level` (history + recompute triggers fire inside the same transaction). **Task 13:** add a scenario proving a pending booking remains `pending` after escalation and is later rejected with `51002` at approval time. **Task 16 (report #4):** unaffected — it queries approved bookings only, matching the decision. |

---

## 4. Concurrency Problem Statement

### 4.1 Invariants in enforceable terms

| Invariant | Enforceable form |
|---|---|
| **BR1 / NR6** | No two non-deleted bookings for the same space may both be in the confirmed-status set `{approved, checked_in, completed}` with overlapping requested intervals `[requested_start_time, requested_end_time)`. Holds regardless of pathway (instant vs staff) and under concurrency. |
| **BR4 (Phase 2)** | Confirmation must not allow a booking whose requested interval overlaps an active (`status IN ('open','in_progress')`, `is_deleted = 0`) maintenance record with `impact_level = 'out-of-service'`. |
| **NR2** | Confirmation may allow a booking that overlaps active `advisory` maintenance **only when** every overlapping active advisory has an acknowledgement row in `booking_advisory_acknowledgement` for that (booking, advisory) pair. |
| **NR4 / U3 (resolved)** | Escalation does not mutate pending bookings; approved bookings overlapping the escalated maintenance period are identified (report #4) so staff can contact requesters. |
| **NR5** | Instant-booking origin is **derived** (`approver_id = -1` ⇒ instant); no stored origin column exists. The concurrency design must not depend on a stored origin column. |
| **BR2 (Phase 2)** | Confirmation is refused when the space's manual override (`current_status IN ('temporarily_closed','retired')`) applies, or when the time-based `out-of-service` overlap applies. `spaces.current_status` is a hint, never the authority. |

### 4.2 Concurrency conflicts (Task 08 inventory)

| ID | Conflict | Correctness broken |
|---|---|---|
| **K1** | Lost update / read-then-write race on availability — two near-simultaneous requests for the same space and overlapping period each read "space free" and each records its approval. | BR1 / NR6 — duplicate approved overlap silently accepted |
| **K2** | Distinct pathway overlap — instant submission and staff approval for the same space/period run concurrently and each approves. | BR1 / NR6 — both pathways produce an "approved" outcome for the same overlap |
| **K3** | Escalation vs in-flight booking — an advisory escalates to `out-of-service` while an overlapping booking is being placed/approved; the booking is confirmed from a stale "advisory-only" view. | BR4 / NR4 — approved booking overlaps out-of-service maintenance |
| **K4** | State read during transition — room-finder/availability read observes the state before/after a concurrent confirmation or escalation and reports "free" (or "advisory only"). | BR1 / NR6 / NR4 — decision or hint relies on a stale reading |
| **K5** | Maintenance-ticket creation vs in-flight booking — a NEW ticket is INSERTed directly as `out-of-service` (or with the column DEFAULT, which is `out-of-service`) on a space while an overlapping booking is being placed/approved; the INSERT takes no shared lock, so the booking's BR4 pre-check can run against a stale "no maintenance" view and confirm the booking over the new blocking ticket. | BR4 / NR6 — approved booking overlaps out-of-service maintenance; K3's failure shape entered through the unguarded creation path (Task 08 K5, added retro) |

All five stem from **check-then-act on the same space's overlap without serialization
between the check and the write** (Task 08 §5). The design below selects one mechanism
that closes all five: every write path that can confirm or invalidate a booking
interval on a space — including **ticket creation starting at `out-of-service`** (§9.4)
— acquires the same per-space critical section.

---

## 5. Current Database Contract

Extracted from the current registries and the approved Task 09/10 outputs (2026-08-04).

### 5.1 Confirmed-status set

`uq_bookings_active_overlap` (filtered unique index, Phase 1, unchanged) defines the
confirmed set: `status IN ('approved','checked_in','completed') AND is_deleted = 0`.
This is the same set BR1/NR6 uses: exact same-`requested_start_time` collisions on
`(space_id, requested_start_time)` are rejected at the index level; arbitrary interval
overlaps are caught by `trg_bookings_prevent_overlap`.

### 5.2 Maintenance contract (Task 09/10)

| Object | Value |
|---|---|
| `maintenance.impact_level` | `VARCHAR(50) NOT NULL` CHECK IN (`'advisory'`,`'out-of-service'`), DEFAULT `'out-of-service'` |
| Blocking set | `impact_level='out-of-service'` ∧ `status IN ('open','in_progress')` ∧ `is_deleted=0` ∧ interval overlap |
| Advisory set | `impact_level='advisory'` ∧ active ∧ interval overlap ⇒ bookable, ack required |
| Escalation audit | `maintenance_impact_history` written by `trg_maintenance_impact_history` on level change of active rows; `changed_by` from `SESSION_CONTEXT(N'current_user_id')`, fallback `-1` |
| Space hint | `spaces.current_status` recomputed by `trg_maintenance_recompute_space_status` (priority rule); never authoritative for correctness |

### 5.3 Approval origin model

No stored origin column (Task 09 rejected it for 3NF — non-key FD `approver_id → origin`).
Origin is **derived**: `CASE WHEN approver_id = -1 THEN 'instant' ELSE 'staff' END`.
Instant approvals insert `booking_approvals(approver_id = -1, ...)`; the reserved
system user `user_id = -1` (`System Booking Service`, role `facility_manager`) is
seeded by the Task 10 migration, so BR6/BR15 remain satisfied.

### 5.4 Trigger inventory (current, after Task 10)

| Trigger | Table | Role in this design |
|---|---|---|
| `trg_bookings_prevent_overlap` (Phase 1) | bookings | BR1 interval overlap — **defense-in-depth** |
| `uq_bookings_active_overlap` (Phase 1 index) | bookings | BR1 exact-start collision — **defense-in-depth** |
| `trg_bookings_check_maintenance` (replaced, 7a) | bookings | BR4 P2 — blocks `out-of-service` overlap — defense-in-depth |
| `trg_booking_approvals_check_space` (replaced, 7b) | booking_approvals | BR2/BR4 P2 + NR2 ack-completeness gate at confirmation — defense-in-depth (fires for both pathways) |
| `trg_booking_approvals_decision` (Phase 1, BR6) | booking_approvals | syncs `bookings.status` on decision INSERT |
| `trg_booking_advisory_ack_validate` (new, 7c) | booking_advisory_acknowledgement | NR2 correspondence |
| `trg_maintenance_impact_history` (new, 7d) | maintenance | NR3 level-change history |
| `trg_maintenance_recompute_space_status` (new, 7e) | maintenance | `current_status` hint recompute |
| Phase 1 role/capacity/checkin/completion/cancellation/updated_at triggers | various | unchanged; run inside the same transaction as the DML |

> The triggers are **not** the primary anti-race guarantee: under READ COMMITTED each
> trigger's overlap read can see a state where two concurrent writers both pass before
> either commits (K1/K2). They remain valuable as deterministic error producers and as
> last-line integrity if a caller bypasses the Task 12 entry points.

### 5.5 Indexes the design relies on

| Index | Purpose |
|---|---|
| `idx_bookings_time_range (space_id, requested_start_time, requested_end_time)` | BR1 overlap reads |
| `uq_bookings_active_overlap` (filtered) | BR1 exact-start collision |
| `idx_maintenance_space_id (space_id)` | BR4 overlap reads |
| `UQ_booking_advisory_ack_booking_maintenance (booking_id, maintenance_id)` | NR2 completeness lookup |
| `idx_booking_advisory_ack_maintenance (maintenance_id)` | report #4 / ack correspondence |

Task 15 may tune these; Task 11 only *names* the ones the design relies on.

### 5.6 Application-layer contract (Task 10 handoff)

`SESSION_CONTEXT(N'current_user_id')` set via `sys.sp_set_session_context` is
**session-scoped, not transaction-scoped**. The application MUST set it before each
unit of work and clear it (`NULL`) afterwards; connection-pooling reuse can leak a
stale user id. Trigger-generated audit rows degrade to the reserved user `-1`.

---

## 6. Candidate Strategies

| # | Strategy | Anomalies prevented | Gaps / weaknesses | Task 12 complexity | Concurrency impact | Fit with current schema / SQL Server |
|---|---|---|---|---|---|---|
| **A** | `SERIALIZABLE` + key-range locks on the overlap indexes | K1, K2, K3 (range locks on bookings/maintenance overlap predicates) | Interval predicates with `>`/`<` across two tables are easy to get wrong; every code path must use the same predicate shape or locks do not match; phantom protection depends on exact index design; harder to prove correct under trigger re-checks | High (must redesign every overlap predicate + index to guarantee ranges) | Range locks block large index sections; fine-grained but error-prone | No schema change; valid 2019+; but relies on subtle lock-compatibility behavior |
| **B** | `UPDLOCK, HOLDLOCK` on overlap reads inside one explicit transaction | K1, K2 (writer-range reads) | Only works if **every** writer uses the identical range-read pattern (instant path, staff path, escalation path); a single divergent read breaks the guarantee; still easy to miss an overlap shape | Medium | Coarse range locks on the scanned range | No schema change; works on 2019+; correctness is only as good as the most careless writer |
| **C** | **`sys.sp_getapplock` — transaction-owned resource per space (`space_booking:<space_id>`)** | K1, K2, K3 (single critical section per space shared by both pathways and by escalation), K4 for confirmation-class reads | Coarse-grained per space (serializes all confirmations + escalations of one space, even for non-overlapping windows); app-level resource discipline required; hints outside the lock are still stale by design | **Low** — one proc-local statement per entry point | Highest per-space serialization of the candidates; acceptable at campus scale (a few hundred spaces; contention concentrated on popular spaces at term start) | **No schema change**; valid 2019+; resource is logical (not data-lock based), deterministic and easy to test in Task 13 |
| **D** | Optimistic concurrency (version/timestamp re-check, retry) | K1, K2 (detect at write time) | **No version columns exist** in the approved schema; adding one contradicts Task 09's no-schema-change statement for concurrency (B.3); loser-rejected retries under term-start burst create user-visible failure loops | Medium–high (new schema + retry design) | Lowest blocking; high retry rate under contention | Requires schema not present in current registries — **rejected for scope** |
| **E** | Trigger-only enforcement (current baseline) | None reliably (K1–K5 all remain possible under READ COMMITTED) | Both concurrent writers pass their trigger check before either commits; no serialization exists | None (already present) | None | Current state is the problem, not a solution |

### Tradeoff summary

- **A** and **B** protect *data ranges* and depend on every writer issuing
  lock-compatible reads; they are hard to prove correct across the four write paths
  (instant, staff, escalation/downgrade, ticket creation) and the trigger re-checks.
- **D** needs schema the approved sources deliberately excluded.
- **E** is the current (insufficient) baseline.
- **C** moves serialization from *data-range locks* to a **logical per-space critical
  section** shared by all writers, which is easy to reason about, deterministic to
  test, and requires zero schema change.

---

## 7. Selected Design

### 7.1 Strategy

**Transaction-owned `sys.sp_getapplock` on a per-space resource, combined with a
final invariant re-check inside the critical section, with the existing triggers and
the filtered unique index retained as defense-in-depth.**

- **Resource name:** `N'space_booking:' + CAST(@space_id AS NVARCHAR(16))` — one
  logical resource per `space_id`, shared by **all** write paths that can confirm or
  invalidate a booking interval on that space:
  - instant booking submission;
  - staff approval;
  - maintenance escalation **and** downgrade (they invalidate/restore availability and
    must serialize with confirmations to close K3);
  - maintenance **ticket creation starting at `out-of-service`** (§9.4) — the INSERT
    path must serialize with confirmations to close K5 (advisory creation needs no
    lock: advisory blocks nothing);
  - any "transactionally current" availability read used for a decision.
- **Lock mode:** exclusive (`@LockMode = 'Exclusive'`), `@LockOwner = 'Transaction'`
  — the lock is held until COMMIT/ROLLBACK and released automatically; it cannot be
  forgotten or released before the write.
- **Order:** the applock is acquired **before** any overlap read, and every
  invariant check is **re-executed after** acquisition, immediately before the write.

### 7.2 Why this fits SQL Server and this schema

- Valid on SQL Server 2019+ (T-SQL, `sys.sp_getapplock` available since 2005).
- **Zero schema change** — consistent with Task 09 B.3 ("making the invariant
  concurrency-safe introduces no ERD/logical schema") and with the derived-origin
  model (no stored origin column to serialize on).
- The lock is logical and deterministic: Task 12 can implement it in one statement
  per entry point, and Task 13 can test winner/loser outcomes without reasoning about
  range-lock compatibility.
- Per-space granularity matches the conflict geometry: every K-conflict is about
  **one space's** time overlap. Contention concentrates on a few popular spaces at
  term start; campus scale (Task 14: ≥100k bookings over three academic years) makes
  per-space serialization trivially sufficient.

### 7.3 Why the rejected options are weaker here

- **A (SERIALIZABLE):** correct only if the key-range locking actually covers the
  interval predicates on *both* `bookings` and `maintenance` in every path, including
  inside triggers. Any plan change (index choice, Task 15) silently weakens the
  guarantee; proof burden is high for a student-project deliverable.
- **B (UPDLOCK, HOLDLOCK):** leaves the same "every writer must be perfect" burden,
  with no single choke point; the escalation path is the easy one to miss, and K3
  would resurface.
- **D (optimistic):** requires version columns absent from the approved schema;
  adding them would contradict Task 09's explicit no-schema-change decision for NR6.
- **E (triggers only):** demonstrated insufficient — it is the baseline the conflicts
  were found in.

---

## 8. Transaction and Locking Design

### 8.1 Lock resource and scope

```
-- canonical acquisition (shape; full implementation is Task 12)
BEGIN TRANSACTION;
EXEC @rc = sys.sp_getapplock @Resource = N'space_booking:' + CONVERT(NVARCHAR(16), @space_id),
                             @LockMode = 'Exclusive',
                             @LockOwner = 'Transaction',
                             @LockTimeout = 5000;
IF @rc IN (-1, -2)  -- -1 timeout, -2 cancelled
    ROLLBACK; RETURN 51005;  -- LOCK-TIMEOUT / RETRY
IF @rc = -3         -- deadlock victim (do NOT merge into 51005 — §8.4/§8.5)
    ROLLBACK; RETURN 51006;  -- DEADLOCK / RETRY
```

- Acquired **inside** the same transaction that performs the final invariant check and
  the write. Releasing before the write is not sufficient.
- One resource per space, **not** per (space, time): coarse but safe and simple.
- The lock is **database-scoped** — the procedure and the DML must run in the same
  database/session, which the entry-point procedures guarantee by construction.

### 8.2 Acquisition order and lock discipline

1. **Always** acquire the space applock as the first statement after `BEGIN
   TRANSACTION` — before any read of `bookings`, `maintenance`, or acks.
2. A transaction holds **at most one** space critical section: instant booking and
   staff approval touch exactly one space; maintenance escalation/downgrade touches
   exactly the maintenance row's space.
3. Row locks taken later by the DML and triggers are therefore **nested inside** the
   applock; there is no second resource to cycle against, so deadlock between
   workflows is structurally avoided. (SQL Server 1205 remains possible in exotic
   interleavings with non-entry-point DML; retry rules in §8.4 cover it.)
4. If a future task ever needs multi-space maintenance DML, it must acquire the
   applocks in ascending `space_id` order or loop per space — recorded here as a
   constraint for Task 12.

### 8.3 Isolation level

- **`READ COMMITTED` (default), with `READ_COMMITTED_SNAPSHOT` OFF** is the design
  baseline. The applock, not the isolation level, is the serialization mechanism.
- Caveat recorded for Task 12/13: if the server database had RCSI ON, every
  invariant-check statement must **start after** the applock grant (its snapshot is
  then taken after the grant, so it sees the lock holder's committed writes). The
  recommended shape above (applock first statement) satisfies this automatically.
- No `SERIALIZABLE` anywhere in the write paths; the trigger re-checks keep their
  Phase 1 semantics unchanged.

### 8.4 Timeout, deadlock, and retry rules

| Event | Detection | Deterministic outcome | App action |
|---|---|---|---|
| Applock timeout (holder exceeds 5 s) | `sp_getapplock` returns -1 | `51005 LOCK-TIMEOUT` | Retry up to 3× with short backoff (e.g. 100/300/900 ms); then surface to user |
| Applock deadlock victim | returns -3 / SQL 1205 | `51006 DEADLOCK` | Same retry policy |
| Invariant violation (BR1/BR4/NR2/BR3/BR2) | trigger RAISERROR or procedure check | `51001 BOOKING-OVERLAP` / `51002 MAINTENANCE-OOS` / `51003 ACK-MISSING` / `51004 CAPACITY` / `51007 NOT-ELIGIBLE` / `51010 SPACE-CLOSED` | **No retry** — deterministic business rejection, surface to user |
| Already-decided booking | `UQ_booking_approvals_booking_id` | `51008 ALREADY-DECIDED` | No retry |
| No-op level change | procedure **re-check after lock acquisition** (authoritative — see §9.3 step 4) | `51009 NO-CHANGE` | No retry |

- `SET XACT_ABORT ON` inside the entry-point procedures so any error rolls back the
  whole unit of work, releasing the applock.
- `SET LOCK_TIMEOUT` (data-lock) default retained; the applock carries its own
  `@LockTimeout = 5000` (ms).

### 8.5 Deterministic error contract

Entry-point procedures return a **result code + message**; triggers keep their
existing `RAISERROR` messages (they are defense-in-depth, not the app-facing contract).
Task 13 must assert on codes, not on free text.

| Code | Meaning | Thrown by |
|---|---|---|
| 0 | SUCCESS | procedure |
| 51001 | overlapping confirmed booking (BR1/NR6) | procedure (post-lock, authoritative) or `trg_bookings_prevent_overlap` |
| 51002 | overlapping active out-of-service maintenance (BR4) | procedure (post-lock, authoritative) or `trg_bookings_check_maintenance` / `trg_booking_approvals_check_space` |
| 51003 | advisory acknowledgements incomplete (NR2) | procedure (post-lock, authoritative) or `trg_booking_approvals_check_space` |
| 51004 | participants exceed capacity (BR3) | procedure (post-lock, authoritative) or `trg_bookings_check_capacity` |
| 51005 | applock acquisition timeout | procedure |
| 51006 | deadlock victim (SQL 1205) | engine |
| 51007 | instant ineligibility (space type / inactive requester) | procedure (instant path only) |
| 51008 | booking already has a decision | `UQ_booking_approvals_booking_id` / procedure (fast-path + post-lock re-check) |
| 51009 | escalation/downgrade no-op (level unchanged) | procedure (post-lock re-check, authoritative) |
| 51010 | space manually closed / retired (BR2 manual override) — **distinct from 51002** (maintenance-ticket block): Task 13 must distinguish the two rejection causes | procedure (post-lock, authoritative) or `trg_booking_approvals_check_space` |

> **Code-reuse note (K5):** `51011 INVALID-INPUT` and `51012 MAINTENANCE-NOT-ACTIVE`
> are Task 12 additions recorded in the Task 12 output header. The §9.4 ticket-creation
> entry point reuses the existing `0` / `51005` / `51006` / `51011` codes and introduces
> **no new result code** — creation either succeeds or fails with input/lock errors,
> and never rejects overlapping confirmed bookings (U3/NR4 keep them, report #4 lists
> them).

---

## 9. Workflow Designs

### 9.1 Instant booking submission

```
0. App: EXEC sys.sp_set_session_context N'current_user_id', @requester_id   -- clear after unit of work
1. BEGIN TRANSACTION
2. EXEC sp_getapplock 'space_booking:<space_id>' Exclusive, Transaction, 5000
   -- fail → 51005/51006
3. Eligibility (U1 test, business logic): space_type ∈ {classroom, computer_lab,
   project_lab, meeting_room} ∧ requester account_status='active' (51007)
4. BR3: expected_participants ≤ capacity (51004)
5. BR2: space manual override — current_status IN ('temporarily_closed','retired')
   → 51010 SPACE-CLOSED.  -- the recompute trigger preserves manual overrides
   -- (priority 1–2 of the Task 09 rule), so reading the hint for THESE two values
   -- is reliable; checked at procedure level so a closed space is rejected early,
   -- before any booking/ack DML (mirrors §9.2 step 8; also closes the gap the
   -- instant eligibility test inherited from Task 09 U1, which had no BR2 check)
6. BR1: no non-deleted booking with status IN ('approved','checked_in','completed')
   overlapping [requested_start_time, requested_end_time) on this space (51001)
7. BR4: no active out-of-service maintenance overlapping the period (51002)
8. INSERT bookings (status default 'pending')  -- trg_bookings_check_maintenance,
   trg_bookings_prevent_overlap re-check (defense-in-depth)
9. NR2: for each active advisory overlapping the period →
   INSERT booking_advisory_acknowledgement(booking_id, maintenance_id,
   acknowledged_by = requester)  -- trg_booking_advisory_ack_validate re-checks
10. INSERT booking_approvals(booking_id, approver_id = -1, decision = 'approved',
    decision_time)  -- trg_booking_approvals_decision sets status='approved';
    trg_booking_approvals_check_space re-checks BR2/BR4/NR2 (defense-in-depth)
11. COMMIT  -- applock auto-released
```

All steps are one atomic unit: any trigger rejection rolls back the booking, its acks,
and the approval together. The ack rows are created **before** the approval INSERT so
the NR2 completeness gate passes on the first attempt.

### 9.2 Staff approval

```
0. App: set SESSION_CONTEXT 'current_user_id' = @approver_id
1. BEGIN TRANSACTION
2. Read the booking row; resolve its space_id; if it already has a
   booking_approvals row → 51008 ALREADY-DECIDED
3. EXEC sp_getapplock 'space_booking:<space_id>' Exclusive, Transaction, 5000
   -- fail → 51005
4. Re-read the booking (status must still be 'pending'; else 51008)
5. BR1: no other confirmed booking overlapping this booking's interval (51001)
   -- the re-check after lock acquisition is the K1/K2 killer
6. BR4: no active out-of-service maintenance overlap (51002)
7. BR2: space manual override (current_status IN ('temporarily_closed','retired')) (51010)
8. NR2: every overlapping active advisory has an ack row (51003)
9. INSERT booking_approvals(booking_id, approver_id = @approver_id,
   decision = @decision, decision_time, rejection_reason?, decision_note?)
   -- BR7/BR15 triggers + trg_booking_approvals_check_space re-check (defense-in-depth)
10. COMMIT
```

### 9.3 Maintenance escalation / downgrade

```
0. App: set SESSION_CONTEXT 'current_user_id' = @staff_id
1. BEGIN TRANSACTION
2. Fast-path read of the maintenance row (space_id, status, impact_level): if not
   active ('open'/'in_progress') → reject; if new level = current level → 51009
   NO-CHANGE.  -- also resolves space_id for the lock resource; early exit only,
   -- NOT authoritative (a concurrent change may have happened before the lock)
3. EXEC sp_getapplock 'space_booking:<space_id>' Exclusive, Transaction, 5000
   -- fail → 51005   (same critical section as confirmation paths — closes K3)
4. Authoritative re-read of the maintenance row under the lock:
   - status must still be 'open'/'in_progress' (else reject);
   - impact_level must still differ from @new_level — if it already equals it
     (e.g. a concurrent escalation of the same record committed first), → 51009
     NO-CHANGE and ROLLBACK.  -- mirrors §9.2 step 4 double-check pattern; makes
     the 51009 idempotency contract deterministic under concurrency
5. UPDATE maintenance SET impact_level = @new_level, ...
   -- trg_maintenance_impact_history inserts the history row (changed_by from
   -- SESSION_CONTEXT, fallback -1); trg_maintenance_recompute_space_status
   -- refreshes the current_status hint
6. U3 decision: NO booking DML. Pending bookings overlapping the period are left
   untouched; they are simply unapprovable until the out-of-service overlap ends
   (any later approval hits 51002 via 9.2 step 6 / trigger 7b).
   Approved bookings overlapping the period are NOT modified either — NR4 report #4
   (Task 16) identifies them for staff contact.
7. COMMIT
```

Escalation and confirmation share the critical section because escalation
*invalidates* availability (BR4) exactly where confirmation *validates* it — the two
directions must not observe each other's stale views.

### 9.4 Maintenance ticket creation (`usp_maintenance_report`)

```
0. App: set SESSION_CONTEXT 'current_user_id' = @reporter_id
1. BEGIN TRANSACTION
2. Fast-path read: the space must exist and the reporter must exist with
   account_status='active' (else 51011 INVALID-INPUT). Advisory/out-of-service
   values validated against the CHECK domain.  -- no overlap reads here: the
   creation path does NOT reject overlapping confirmed bookings (U3/NR4)
3. IF @impact_level = 'out-of-service':
   EXEC sp_getapplock 'space_booking:<space_id>' Exclusive, Transaction, 5000
   -- fail → 51005/51006. Advisory creation SKIPS the lock entirely — advisory
   -- blocks nothing, mirroring the downgrade direction of §9.3 (K5 closes only
   -- when the ticket starts blocking)
4. INSERT maintenance (space_id, reporter_id, problem_description, start_time,
   status = 'open', impact_level = @impact_level)  -- impact_level is ALWAYS
   -- passed explicitly; the column DEFAULT 'out-of-service' (Task 09 A.3) is a
   -- legacy-backfill device and must never be relied on at the entry point
   -- trg_maintenance_recompute_space_status refreshes the current_status hint;
   -- trg_maintenance_impact_history is AFTER UPDATE only → no history row on creation
5. COMMIT  -- applock (if taken) auto-released
```

The lock exists **purely for serialization**: it guarantees that any concurrent
booking confirmation on the same space either commits before the ticket (then report
#4, NR4, lists the affected booking) or re-checks after it and fails with `51002` on
the booking side. Without the lock (the K5 hole), the confirmation could commit an
approved booking that never observed the blocking ticket at all.

### 9.5 Room-finder / availability read

| Read class | Locking | Contract |
|---|---|---|
| **Pre-booking hint** (room-finder UI, report queries) | No applock; READ COMMITTED | Documented as an **advisory hint**. The final confirmation re-checks every invariant inside the critical section (§9.1/§9.2), so a stale hint can never produce a conflicting approval. |
| **Transactionally current read** (used as a decision input inside confirmation) | Applock already held by the enclosing write path | Performed after lock acquisition, seeing all committed state of the space. |
| **Report #4 (affected approved bookings on escalation)** | Read-only derived query (Task 16) | Analytical; reads `booking_advisory_acknowledgement` ↔ `maintenance` ↔ `bookings` after the escalation committed. No locking required. |

This classification converts **K4** from a correctness risk into a documented
advisory-read policy: hints may be stale, decisions never are.

---

## 10. Conflict Coverage Matrix

| Conflict (Task 08) | Prevention mechanism (this design) | Defense-in-depth | Residual risk |
|---|---|---|---|
| **K1** — lost update / read-then-write race | Both transactions must acquire the exclusive `space_booking:<space_id>` applock before their overlap check; the loser's post-lock re-check (§9.2 step 5) sees the winner's committed booking and fails with `51001` | `trg_bookings_prevent_overlap` + `uq_bookings_active_overlap` reject the second write even if a caller bypasses the entry point | None for the write paths; non-entry-point DML is out of the guaranteed contract (documented) |
| **K2** — distinct pathway overlap | Instant (§9.1) and staff (§9.2) acquire the **same** resource — one shared critical section per space; both final re-checks enforce BR1 regardless of origin | `trg_booking_approvals_check_space` + `trg_bookings_prevent_overlap` fire for both pathways | None |
| **K3** — escalation vs in-flight booking | Escalation/downgrade (§9.3) takes the same space applock; confirmation cannot complete while an escalation is uncommitted, and vice versa. If escalation commits first, the confirmation re-check sees `out-of-service` → `51002`; if confirmation commits first, NR4 report #4 identifies the affected approved booking (U3: pending untouched) | `trg_bookings_check_maintenance` / `trg_booking_approvals_check_space` re-verify the level at each DML | None; note the NR4 report reflects the level **at commit time**, which is the correct anchor |
| **K4** — state read during transition | Reads are classified (§9.5): hints are documented advisory, decision-class reads run inside the critical section after lock grant | N/A (read policy) | Stale hint visible in UI between commits — by design, never affects correctness |
| **K5** — ticket creation vs in-flight booking | Ticket creation starting at `out-of-service` (§9.4) takes the same space applock before its INSERT; a concurrent confirmation either commits first (then NR4 report #4 lists its booking) or re-checks after the ticket commits and fails with `51002`. Advisory creation takes no lock (blocks nothing) | `trg_bookings_check_maintenance` / `trg_booking_approvals_check_space` re-verify BR4 at each confirmation DML; raw `INSERT` outside the entry point remains documented out-of-contract DML | None for entry-point traffic; a raw out-of-service INSERT bypassing the entry point keeps the booking-side triggers as the last line (consistent with the documented K1–K4 contract) |

**All five conflicts close.** K1–K3 and K5 are closed by the shared per-space critical
section + post-lock invariant re-check (K5 on the booking side's re-check); K4 is
closed by the read-classification policy.

---

## 11. Task 12 Implementation Handoff

### 11.1 Database entry points to implement

| Procedure | Inputs | Outputs | Implements |
|---|---|---|---|
| `usp_booking_instant_submit` | `@space_id`, `@requester_id`, `@requested_start_time`, `@requested_end_time`, `@purpose`, `@expected_participants` | `@booking_id`, `@result_code`, `@message` | §9.1 instant workflow (single transaction: applock → eligibility → BR3/BR1/BR4 → booking → acks → auto-approval with `approver_id = -1`) |
| `usp_booking_approve` | `@booking_id`, `@approver_id`, `@decision` ('approved'\|'rejected'), `@rejection_reason`, `@decision_note` | `@result_code`, `@message` | §9.2 staff workflow (applock on the booking's space → pending re-check → BR1/BR4/BR2/NR2 → approval INSERT) |
| `usp_maintenance_set_impact_level` | `@maintenance_id`, `@new_impact_level`, `@reason` | `@result_code`, `@message` | §9.3 escalation/downgrade (fast-path read → applock on the maintenance's space → **authoritative re-read**: active + level-change checks re-run under the lock → UPDATE maintenance) |
| `usp_maintenance_report` | `@space_id`, `@reporter_id`, `@problem_description`, `@start_time`, `@impact_level` (DEFAULT `'advisory'`) | `@maintenance_id`, `@result_code`, `@message` | §9.4 ticket creation (validate → applock **only when starting at `out-of-service`** → INSERT with `impact_level` passed explicitly → COMMIT; no overlap rejection — U3/NR4 keep existing bookings, report #4 lists them; closes K5) |

Non-negotiables in the implementation:
- `SET XACT_ABORT ON`; `BEGIN TRANSACTION` first, applock second (when taken), all reads after.
- `@LockTimeout = 5000` on `sp_getapplock`; map return value `< 0` to `51005`/`51006`.
- **No schema changes** — no new tables, columns, indexes, or version columns; `usp_maintenance_report` is an additive stored procedure only.
- No stored origin column; instant approvals hard-code `approver_id = -1`.

### 11.2 Trigger changes

**None.** The existing trigger set (Phase 1 + Task 10) stays exactly as-is and is
retained as defense-in-depth. Task 12 must **not** modify or re-create triggers.

### 11.3 Application responsibilities

- Set `sys.sp_set_session_context N'current_user_id'` to the acting user **before**
  each unit of work and clear it (`NULL`) **after** (connection-pooling leak risk —
  Task 10 handoff note; trigger-generated rows degrade to `-1`).
- Call only the four entry points for the four write workflows (instant booking,
  staff approval, escalation/downgrade, ticket creation); treat result codes
  as deterministic (no string matching).
- Retry only on `51005`/`51006` (max 3 attempts, short backoff); surface
  `51001–51004, 51007–51010` to the user without retry.
- Availability/room-finder reads are hints; never show them as a booking guarantee.

---

## 12. Task 13 Test Handoff

Concurrent-session tests (two or more sessions; e.g. `sqlcmd`/SSMS scripted via the
Task 13 folder) must demonstrate:

| # | Scenario | Expected outcome |
|---|---|---|
| T1 | Two sessions call `usp_booking_instant_submit` for the **same space, overlapping windows** concurrently | Exactly one returns `0` + a `booking_id`; the other returns `51001` (its post-lock re-check sees the winner). After both: invariant query finds **no** overlapping confirmed rows |
| T2 | Session A: `usp_booking_instant_submit`; Session B: `usp_booking_approve` for a second pending booking on the same space, overlapping window | Exactly one confirmation wins (loser `51001`) — proves the shared critical section across pathways (K2) |
| T3 | Session A: `usp_maintenance_set_impact_level` advisory→out-of-service; Session B concurrently: `usp_booking_instant_submit` for an overlapping window | Either B fails `51002` (escalation committed first) **or** B succeeds and report #4 (NR4) subsequently lists B's booking as affected — never both uncommitted states observed |
| T4 | Hold the applock artificially (e.g. `sp_getapplock` + `WAITFOR` inside a transaction in session A) while session B submits | B gets `51005` after ~5 s; retry succeeds when A commits |
| T5 | `usp_maintenance_set_impact_level` with unchanged level | `51009` no-op, no `maintenance_impact_history` row |
| T5b | Two sessions escalate the **same** maintenance to the **same** level concurrently | Exactly one returns `0` with exactly one `maintenance_impact_history` row; the loser returns `51009` (its post-lock re-check at §9.3 step 4 sees the winner's committed level) — proves the 51009 idempotency contract is deterministic under concurrency, with no phantom history row |
| T6 | Escalation with a **pending** overlapping booking (U3 regression) | Booking stays `pending`; later `usp_booking_approve` returns `51002`; no auto-cancel/reject occurs |
| T7 | Instant submission against a space with overlapping active advisories | Completes `0` only with all ack rows inserted in the same transaction; a forced partial ack set rolls back atomically (NR2 completeness, K-adjacent atomicity) |
| T8 | Invariant audit after every test: `SELECT ... FROM bookings WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0` grouped by space — no interval overlap | Always empty result set (BR1/NR6 holds post-hoc) |
| T9 | Instant submission against a `retired` (or `temporarily_closed`) space, all other checks passing | Returns `51010 SPACE-CLOSED` **early** — no `bookings`/ack/approval residue left behind (assert row counts unchanged); distinct from T3's `51002` (BR4) outcome, proving the two codes are distinguishable |
| T10 | Session A: `usp_maintenance_report` creating an `out-of-service` ticket on a space; Session B concurrently: `usp_booking_instant_submit` (or `usp_booking_approve`) for an overlapping window on the same space | Never both: if the ticket commits first, B fails `51002`; if B commits first, the ticket commits after and report #4 (NR4) lists B's booking as affected. Invariant audit (T8 shape) must never find an approved booking overlapping the blocking ticket that existed at its confirmation time — closes K5 |

Each test script must print the deterministic result codes and the invariant-audit
outcome, following the Task 06/10 expected-error proof pattern (isolated
transactions).

---

## 13. Assumptions, Risks, and Out of Scope

### Assumptions

| # | Assumption | Basis |
|---|---|---|
| A11-1 | The confirmed set for NR6 is `{approved, checked_in, completed}` ∧ `is_deleted = 0`, mirroring `uq_bookings_active_overlap` | Registry + Task 09 U1 test wording |
| A11-2 | Per-space serialization is sufficient at campus scale (Task 14 target: ≥100k bookings over three academic years; a few hundred spaces) | Task 08 §5 geometry: every conflict is single-space |
| A11-3 | The application routes all four write workflows through the Task 12 entry points (instant, staff approval, escalation/downgrade, ticket creation) | Documented contract; triggers remain last-line integrity |
| A11-4 | Escalation affects only approved bookings (U3 decision); pending bookings are left pending and become unapprovable | Resolved this run (§3) |

### Risks

- **Coarse granularity:** all confirmations + escalations of one space serialize.
  Acceptable now; if a future requirement needs per-window locking, Task 11's
  resource scheme can be extended without schema change.
- **Contract bypass:** direct DML outside the entry points is outside the guaranteed
  critical section; triggers still reject the *final* conflicting write but cannot
  prevent two-pass-then-commit races — documented, not silently relied on.
- **SESSION_CONTEXT leakage** across pooled connections (Task 10 handoff) — an
  application bug can misattribute `changed_by`; correctness of NR6 is unaffected.
- **RCSI caveat:** if RCSI were enabled, re-check statements must start after the
  applock grant (guaranteed by the canonical order in §8).

### Out of scope

- Task 12 implementation SQL, Task 13 test files, Task 15 index tuning,
  Task 16 analytical queries (including report #4's exact query shape).
- Any schema addition (version columns, stored origin, notification tables).
- Multi-space maintenance batch DML (recorded ordering constraint in §8.2 if ever
  introduced).

---

## 14. Revision Log

| Version | Date | Change |
|---|---|---|
| 1.3 | 2026-08-05 | **K5 gap closure (Task 12 rev 1 retro):** new §9.4 `usp_maintenance_report` — 4th entry point for maintenance-ticket creation; applock `space_booking:<space_id>` only when the ticket starts at `out-of-service` (advisory creation skips it); `impact_level` always passed explicitly; no overlap rejection (U3/NR4 keep existing bookings); no new result codes (reuses 0/51005/51006/51011). §4.2 gains K5 row; §7.1 resource list extended; §8.5 code-reuse note; §10 matrix gains K5; §11.1/§11.3/§13 updated to four entry points; §12 gains T10. |
| 1.2 | 2026-08-05 | Review fix (§8.1, §8.4, §8.5, §9.1, §9.2, §11.3, §12): (a) **BR2 manual-override check added to the instant path** as procedure-level step 5 (code `51010 SPACE-CLOSED`) — closes the inherited U1-test gap and rejects closed spaces before any booking/ack DML, mirroring §9.2; (b) **new code `51010 SPACE-CLOSED`** — 51002 stays exclusive to BR4 (maintenance-ticket block) so Task 13 can distinguish the two rejection causes; (c) §8.1 canonical acquisition shape now splits `-1/-2 → 51005` vs `-3 → 51006`, matching §8.4/§8.5 (previously all negative returns collapsed into 51005). Added Task 13 scenario T9. |
| 1.1 | 2026-08-05 | Review fix (§9.3, §8.4, §8.5, §11.1, §12): escalation/downgrade now performs an **authoritative re-read of the maintenance row after lock acquisition** (mirrors §9.2's double-check pattern) — status must still be active and `impact_level` must still differ from `@new_level`, else `51009 NO-CHANGE` + ROLLBACK. Closes the concurrent-escalation race where two staff escalating the same record to the same level made the loser return SUCCESS instead of `51009` (contract bug only; `trg_maintenance_impact_history` already prevents phantom history rows). §8.5 thrown-by wording normalized ("procedure (post-lock, authoritative)" for 51001–51004, "fast-path + post-lock re-check" for 51008). Added Task 13 scenario T5b. |
| 1.0 | 2026-08-04 | Initial Task 11 design: per-space transaction-owned `sp_getapplock` critical section shared by instant booking, staff approval, and maintenance escalation/downgrade; post-lock invariant re-checks; READ COMMITTED + 5 s lock timeout + retry-on-51005/51006 contract; deterministic result codes 51001–51009; U3 resolved (escalation affects only approved bookings); Task 12/13 handoffs; K1–K4 coverage matrix. |
