# Requirement-Change Analysis — Campus Space Management System (Phase 2)

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Phase:** 2 · **Task:** 08
**Date:** 2026-08-02

---

## 1. Phase 2 Change Summary

After a one-semester pilot, the Facility Manager changed one maintenance rule and
introduced new operating conditions. The Phase 2 extension (authoritative source:
`docs/project_phase2_description.md`) makes three broad changes to the Phase 1
baseline:

| # | Change | Short description |
|---|---|---|
| C1 | **Maintenance impact levels** | A maintenance record now has an impact level: `advisory` or `out-of-service`. Phase 1 treated *every* active maintenance as blocking; Phase 2 blocks only `out-of-service` maintenance, while `advisory` maintenance leaves the space bookable but requires the requester to be notified of active advisories (with a stored acknowledgement). A space may have several active maintenance records with different impact levels; a level may be escalated/downgraded while open. |
| C2 | **Concurrent booking and approval** | Near-simultaneous requests are expected at term start. Eligible space types may be **auto-approved at submission** (instant booking) when they satisfy the usage policy; the rest keep the staff-approval workflow. Conflicting bookings for the same space must never both be approved — under concurrency, across **both** pathways. |
| C3 | **New reporting needs** | Approved-hour totals per space per semester; approved bookings by weekday/hour; a room finder (capacity + facility list, within a time period); and the set of approved bookings affected when a maintenance is escalated to `out-of-service`. |

---

## 2. Affected Entities

The following Phase 1 entities are affected by changes C1–C3.

| Entity | Phase 1 baseline (as-is) | How Phase 2 affects it |
|---|---|---|
| **Maintenance** | Single lifecycle (`open → in_progress → resolved`); all active maintenance blocks booking via BR4 and `spaces.current_status`. | **C1 (highest impact).** Must represent an `impact_level` per record and support multiple concurrent records per space with differing levels. Blocking behaviour becomes conditional on the level; `advisory` maintenance no longer blocks booking. Level escalation/downgrade while open must be supported. |
| **Bookings** | Holds request + lifecycle status; approval decision lives in `booking_approvals`. | **C1 + C2.** May need to capture that the requester was informed of active advisories (an acknowledgement) and to record the booking origin/pathway (instant vs staff-approved). The no-overlap invariant is unchanged but must now hold under concurrency. |
| **Booking_Approvals** | One decision row per booking (approve/reject by staff). | **C2.** Instant booking introduces an automatically-approved path; the approval model must distinguish auto-approval from staff approval without breaking BR6/BR7 metadata. |
| **Spaces** | Holds `current_status` incl. `under_maintenance`. | **C2/C3.** Room-finder report relies on capacity and facilities; `current_status` interaction with advisory vs out-of-service maintenance needs re-consideration (a space can be bookable but carry an advisory). |

> Entities **not** materially changed: `Departments`, `Users`, `Facilities`,
> `Space_Facilities`, `Booking_Sessions`. (`Facilities`/`Space_Facilities` are *read*
> more heavily by the new room-finder report, but their shape is unchanged.)

---

## 3. Affected Relationships

| Relationship (Phase 1 registry) | Phase 1 cardinality | How affected baseline |
|---|---|---|
| R5 Spaces → Bookings | 1:N | Unchanged cardinality, but the no-overlap rule now must hold under concurrent instant + staff approval (C2). |
| R1/R7 Spaces → Maintenance | 1:N | **C1.** Participation/cardinality unchanged, but the blocking semantics of each related maintenance becomes level-dependent; a space may relate to several concurrent active maintenance records of different levels. |
| Bookings ↔ Maintenance (via space/time) | Implicit (BR4 overlap) | **C1.** Interaction becomes conditional: `out-of-service` overlaps are forbidden; `advisory` overlaps are allowed but require a stored acknowledgement. |
| R10 Bookings → Booking_Approvals | 1:0..1 | **C2.** The approval decision's meaning is extended to include the instant/auto-approval path. |
| Booking → advisory acknowledgement | none in Phase 1 | **C1 (new).** A new dependency between a booking and the advisories it was informed about (acknowledgement) is conceptually introduced. |

---

## 4. Affected Business Rules & New-Rule Interactions

### 4.1 Phase 1 rules that change

| Phase 1 rule | Phase 1 meaning | Phase 2 change |
|---|---|---|
| **BR2** · Unavailable spaces cannot be booked | `spaces.current_status ∈ {under_maintenance, temporarily_closed, retired}` blocks booking. | **Refined.** `under_maintenance` is no longer a uniform block: it blocks only when an active maintenance **out-of-service** overlap applies. Advisory maintenance does not, by itself, make the space unbookable. |
| **BR4** · Maintenance blocks booking | Any overlapping unresolved maintenance prevents booking. | **Changed.** Only `out-of-service` maintenance blocks an overlapping booking. Advisory maintenance permits booking but triggers the notification-and-acknowledgement obligation (new rule). |

### 4.2 New Phase 2 rules (added on top of the baseline)

- **NR1 — Maintenance impact levels.** Each maintenance record carries an impact
  level (`advisory` | `out-of-service`); a space may have several active records of
  different levels at the same time.
- **NR2 — Advisory acknowledgement.** When a booking is placed for a space with
  active `advisory` maintenance, the requester must be notified of all active
  advisories and the system must record the acknowledgement with the booking.
- **NR3 — Impact-level transition.** A maintenance's impact level may be escalated
  (advisory → out-of-service) or downgraded while the record is still open.
- **NR4 — Affected-booking discovery.** If an `advisory` maintenance is escalated to
  `out-of-service`, any already-approved bookings overlapping the maintenance period
  must be queryable so staff can contact those requesters.
- **NR5 — Instant (auto) booking.** For eligible space types, requests that satisfy
  the usage policy may be approved automatically at submission, without staff review.
- **NR6 — Concurrency correctness.** Two approved bookings may never use the same
  space during overlapping periods — regardless of whether they came from instant
  booking or staff approval, and even when several users/staff operate concurrently.

### 4.3 Interaction with unaffected Phase 1 rules

- **BR1** (no overlapping approved bookings) remains the core invariant; NR5 and NR6
  extend *how* a booking becomes approved, so BR1 must be guaranteed across both paths.
- **BR3** (participants ≤ capacity) and **BR6/BR7** (decision metadata / rejection
  reason) remain; instant booking must still satisfy the metadata rules where they apply.
- **BR4/BR2/NR1–NR4** interact: whether a booking is permitted depends on the *merged*
  effect of all active maintenance on the space and on time overlap, not on a single
  status flag.

---

## 5. Possible Concurrency Conflicts

Under the new operating conditions, operations **check-then-act** on the same space's
overlap (its bookings or its maintenance) without atomicity/serialization between the
check and the write. When several users and staff act simultaneously, mishandling the
concurrency can break correctness. Possible conflicts:

| # | Conflict | How it arises | Correctness it can break |
|---|---|---|---|
| K1 | **Lost update / read-then-write race on availability** | Two near-simultaneous requests for the same space and an overlapping period each read "space free", then each records its booking; both pass their availability check before either is written. Both become approved. | **BR1 / NR6** — a duplicate approved overlap is silently accepted. |
| K2 | **Distinct pathway overlap (instant vs staff)** | An instant-booking submission and a staff approval decision target the same space/period concurrently; each path checks availability independently and both approve. | **BR1 / NR6** — the two pathways can both produce an "approved" outcome for the same overlap. |
| K3 | **Escalation vs in-flight booking** | An advisory is escalated to `out-of-service` while a booking that overlaps the period is being placed/approved; the booking may be confirmed based on a stale "advisory only" view. | **BR4 / NR4** — an approved booking overlaps `out-of-service` maintenance it should have been blocked by. |
| K4 | **State read during transition** | A room-finder or availability read at a non-isolated level observes the table before/after a concurrent change, showing a space as free when a competing booking has just been approved (or maintenance escalated). | **BR1 / NR6 / NR4** — a booking, approval decision, or room-finder result relies on a stale "free"/"advisory" reading. |

> All of K1–K4 stem from a **check-then-act on the same space overlap without
> atomicity/serialization between the check and the write**. They do not, by
> themselves, dictate a particular mechanism; the Task 11 concurrency design selects
> the approach.

---

## 6. Assumptions / Unresolved Ambiguities

### Assumptions

| # | Assumption | Rationale |
|---|---|---|
| A1 | The existing no-overlap invariant (BR1) is retained as the correctness target for the extension. | Phase 2 states this rule must remain valid under concurrency; nothing removes it. |
| A2 | Entities/relationships listed in §2–§3 are the *points of change*; the analysis does not decide their final shape. | This task identifies impact only; schema design is Task 09. |
| A3 | `advisory` maintenance affects *comfort/equipment* but not full usability, matching the Phase 2 description examples (broken projector, one faulty AC, damaged whiteboard). | §1.1 lists exactly these examples. |

### Unresolved ambiguities (to resolve in Phase 2 design)

| # | Question | Where it affects |
|---|---|---|
| U1 | Which space types are eligible for **instant (auto) booking**; is the eligibility per-type uniform and what is the usage-policy test? | NR5, C2 |
| U2 | How the **advisory acknowledgement** is captured/stored (notice checkout, timestamp, who, per-booking vs per-period) — attribute vs new table. | NR2, C1 |
| U3 | Whether **escalation to `out-of-service`** also affects pending requests or only already-approved bookings. | NR3, NR4 |
| U4 | Exact definition of "semester" reporting windows for the new analytical queries. | C3 reporting |
| U5 | Whether an `out-of-service` maintenance should also flip `spaces.current_status = 'under_maintenance'` or whether the status derive from active maintenance levels. | BR2/BR4 interaction |

---

## 7. Relationship Tokens to Design

Outcome of this analysis intended for the design phase (Task 09): the Phase 2 design
must model (i) maintenance impact level + escalation, (ii) the advisory
notification/acknowledgement on bookings, (iii) the instant vs staff approval origin,
and (iv) a way to enforce the no-overlap invariant across concurrent instant and staff
approval pathways. None of these are designed here.

---

**Next step:** Task 09 — update the ERD and the logical/relational schema to reflect
the affected entities and new rules identified above, and re-validate 3NF.

---