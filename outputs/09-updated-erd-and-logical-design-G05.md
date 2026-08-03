# Updated ERD + Logical Design — Campus Space Management System (Phase 2)

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Phase:** 2 · **Task:** 09
**Date:** 2026-08-03

---

## 1. Overview

This document updates the Phase 1 ERD and logical schema for the Phase 2 extension on
top of the frozen baseline (`docs/design-decisions.md` — schema unfrozen for the
affected tables `maintenance` and `bookings`, Option B).

**This run covers all three Phase 2 change areas** (C1–C3 from Task 08):

| Area | Phase 1 baseline | Phase 2 design |
|---|---|---|
| **1 — Maintenance impact levels** | every active maintenance blocks booking | `maintenance.impact_level` (`advisory` \| `out-of-service`); only `out-of-service` blocks an overlapping booking; escalation/downgrade logged; advisory acknowledgement recorded |
| **2 — Concurrent/instant booking** | booking approval is staff-only, recorded in `booking_approvals` | eligible space types may be auto-approved at submission; `booking_approvals.approval_source` records the origin; a reserved system user acts as the instant approver |
| **3 — Analytical reporting** | staff-view reports (BR14) | four new reports; all answerable as queries over the existing + Area-1 schema — **no schema change required** |

Task 09 designs **ERD and logical schema only**. The migration scripts (Task 10), the
concurrency controls/mechanisms (Tasks 11–13), index tuning (Task 15), and the query
implementations (Task 16) are out of scope here.

---

## 2. Section A — Area 1: Maintenance impact levels & advisory acknowledgement

### A.1 Updated ERD (Area 1 only)

```mermaid
erDiagram
    Maintenance {
        int maintenance_id PK
        int space_id
        int reporter_id
        int assigned_staff_id
        string problem_description
        datetime start_time
        datetime completion_time
        string status
        string impact_level
        string result_note
    }

    Maintenance_Impact_History {
        int history_id PK
        int maintenance_id
        int changed_by
        string prior_level
        string new_level
        datetime changed_at
    }

    Booking_Advisory_Acknowledgement {
        int ack_id PK
        int booking_id
        int maintenance_id
        datetime acknowledged_at
        int acknowledged_by
    }

    Maintenance ||--o{ Maintenance_Impact_History : "has_level_changes"
    Users ||--o{ Maintenance_Impact_History : "records"
    Maintenance ||--o{ Booking_Advisory_Acknowledgement : "notified_by"
    Bookings ||--o{ Booking_Advisory_Acknowledgement : "acknowledges"
```

Relationship notes (new / changed only):

| Relationship | Cardinality | Participation | Meaning |
|---|---|---|---|
| Maintenance → Maintenance_Impact_History | 1:N | total on history | every level change belongs to exactly one maintenance record |
| Users → Maintenance_Impact_History | 1:N | total on history | each change is recorded by exactly one user (`changed_by`) |
| Maintenance → Booking_Advisory_Acknowledgement | 1:N | total on ack | each acknowledgement refers to exactly one maintenance record |
| Bookings → Booking_Advisory_Acknowledgement | 1:N | total on ack | each acknowledgement is attached to exactly one booking |

> The acknowledgement table resolves the many-to-many "a booking may be informed of
> several advisories; one advisory may affect several bookings" into an associative
> table with one row per (booking, advisory) pair.

### A.2 Logical tables

#### A.2.1 `maintenance` (changed — add `impact_level`)

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| … *(all Phase 1 columns unchanged)* | | | | | | |
| **impact_level** | VARCHAR(50) | NO | — | — | `'out-of-service'` | NEW (NR1). CHECK IN ('advisory','out-of-service'). Default preserves Phase 1 blocking for legacy rows on migration. |

**Constraint / behavior changes (schema-affecting only):**
- **BR2/BR4 (re-filtered):** only `out-of-service` maintenance blocks an overlapping
  booking. The re-scoping touches the enforcement triggers (`trg_bookings_check_maintenance`,
  `trg_booking_approvals_check_space`) and is implemented in Task 10/11 — the logical
  schema change here is only the `impact_level` column itself.

#### A.2.2 `maintenance_impact_history` (new — NR3)

Records every escalation (advisory → out-of-service) or downgrade while the maintenance
is still open.

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| history_id | INT | NO | PK | — | IDENTITY(1,1) | |
| maintenance_id | INT | NO | — | maintenance(maintenance_id) | — | ON DELETE CASCADE |
| changed_by | INT | NO | — | users(user_id) | — | user who changed the level |
| prior_level | VARCHAR(50) | NO | — | — | — | CHECK IN ('advisory','out-of-service') |
| new_level | VARCHAR(50) | NO | — | — | — | CHECK IN ('advisory','out-of-service'); must differ from prior_level |
| changed_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | |
| reason | NVARCHAR(MAX) | YES | — | — | — | optional escalation/downgrade note |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | BR12 |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | BR12 |

**Enforcement:** a trigger on `maintenance UPDATE` inserts a history row whenever
`impact_level` changes and the record is still active (status `open`/`in_progress`)
(trigger behavior — Task 10). `changed_at` timestamps the event, so the NR4 "affected
bookings at escalation time" report can be answered exactly.

#### A.2.3 `booking_advisory_acknowledgement` (new — NR2)

Records that the requester was notified of (and acknowledged) the active advisories on
a space at booking time.

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| ack_id | INT | NO | PK | — | IDENTITY(1,1) | |
| booking_id | INT | NO | UQ | bookings(booking_id) | — | UQ with maintenance_id = one ack per (booking, advisory) |
| maintenance_id | INT | NO | UQ | maintenance(maintenance_id) | — | the advisory the requester was informed about |
| acknowledged_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | when the requester confirmed |
| acknowledged_by | INT | NO | — | users(user_id) | — | normally the requester; FK → users |
| created_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | BR12 |
| updated_at | DATETIME2 | NO | — | — | DEFAULT GETDATE() | BR12 |

**Enforcement:** at booking INSERT/UPDATE, if any active `advisory` maintenance overlaps
the requested period, the booking is allowed and one acknowledgement row must be
inserted per overlapping advisory. A trigger enforces the correspondence (the ack rows
must reference advisories that overlap the booking's time range) (trigger behavior — Task 10).

**Note (NR4):** no `escalation_notification` table is designed. The "approved bookings
affected when an advisory escalates to out-of-service" report is derived by joining
`booking_advisory_acknowledgement` ↔ `maintenance` where `impact_level` transitioned to
`out-of-service` (report #4, Area 3).

### A.3 `spaces.current_status` handling (U5)

**Design decision (recorded in `docs/design-decisions.md`):** `spaces` schema is
**unchanged** — no new columns, no split status flags. `current_status` becomes a
**display/filter hint** and is **recomputed by a trigger on `maintenance`
INSERT / UPDATE / resolve**, using the combined-state priority rule:

| Priority | Value | Condition |
|---|---|---|
| 1 | `retired` | manual, permanent (never auto-overridden) |
| 2 | `temporarily_closed` | manual override |
| 3 | `under_maintenance` | iff an active `out-of-service` maintenance period covers *now* |
| 4 | `in_use` | iff a live `booking_sessions` row exists (checked in) |
| 5 | `available` | fallback (bookable, not occupied) |

- `advisory` maintenance **never** sets `under_maintenance`; advisory-only space → `available`.
- The recompute must respect `booking_sessions` occupancy (`in_use`) and the manual
  `retired`/`temporarily_closed` overrides.
- The existing `trg_maintenance_completion_space_status` completion logic is folded into
  the new recompute trigger, keeping the `NOT EXISTS` multi-ticket guard (a space stays
  `under_maintenance` while any active out-of-service ticket remains).
- **Correctness never depends on the flag** — booking/approval overlap checks read
  `maintenance` directly (A.2.1). The room-finder and report #4 must also derive from
  `maintenance`/`bookings` overlap in future time interval, not from `current_status` alone.

---

## 3. Section B — Area 2: Concurrent/instant booking & approval (schema only)

### B.1 Updated ERD (Area 2 only)

```mermaid
erDiagram
    Bookings {
        int booking_id PK
        int space_id
        int requester_id
        datetime requested_start_time
        datetime requested_end_time
        int expected_participants
        string status
    }

    Booking_Approvals {
        int approval_id PK
        int booking_id
        int approver_id
        datetime decision_time
        string decision
        string approval_source
        string rejection_reason
    }

    Users {
        int user_id PK
        string email
        string role
        string account_status
    }

    Bookings ||--o| Booking_Approvals : "decided_by"
    Users ||--o{ Booking_Approvals : "approves"
```

> The instant/staff pathway is represented **as an attribute** (`approval_source`) on the
> existing `Booking_Approvals` relationship — no new entity or relationship is needed.
> The instant approver is a **reserved system user row** in `Users` (user_id = -1), so
> the approver FK (R3, BR15) is satisfied unchanged.

### B.2 Logical tables

#### B.2.1 `booking_approvals` (changed — add `approval_source`)

| Column | Type | Nullable | PK / UQ | FK Reference | Default | Notes |
|--------|------|----------|---------|-------------|---------|-------|
| … *(all Phase 1 columns unchanged)* | | | | | | |
| **approval_source** | VARCHAR(50) | NO | — | — | `'staff'` | NEW (NR5). CHECK IN ('instant','staff'). `'instant'` = auto-approval at submission by the system user; `'staff'` = existing staff workflow. Default keeps Phase 1 staff-approval semantics. |

**Constraint / behavior notes:**
- `approver_id` stays **NOT NULL**; BR6 (`trg_booking_approvals_decision`) and BR15
  (`trg_booking_approvals_check_role`) remain satisfied because instant approvals are
  recorded against the reserved system user (role `facility_manager`).
- The auto-approval **test** (eligibility + checks 1–5) is business logic applied at
  submission; it needs **no additional schema** — it reuses the existing BR1/BR3/BR4
  enforcement objects. See §7 (U1) and §8 (assumptions).

#### B.2.2 `users` (data change only — reserved system user)

**No column change.** The instant-approval path requires an approver identity that is
not a real staff member, so a **reserved seed row** is introduced (implemented in the
Task 10 migration via `SET IDENTITY_INSERT`):

| Attribute | Value | Note |
|---|---|---|
| user_id | **-1** | reserved, outside the IDENTITY range |
| email | `system@campus.edu` | unique business key (A1) |
| full_name | `System Booking Service` | display name |
| phone_number | NULL | optional |
| role | `facility_manager` | satisfies BR15 |
| department_id | (a seeded department) | FK satisfied |
| account_status | `active` | |

This row is documented in `docs/schema-registry.md` as a special record; it must be
excluded from any "real user" reports. The instant approval flow inserts
`booking_approvals(approver_id = -1, approval_source = 'instant', decision = 'approved')`.

### B.3 No-schema-change statement (concurrency enforcement)

The Phase 2 requirement that **two approved bookings can never overlap on the same
space across both pathways, even under concurrent operations** (NR6) is enforced
around the existing no-overlap objects (`uq_bookings_active_overlap` +
`trg_bookings_prevent_overlap`, BR1). That invariant is unchanged by this task;
**making it concurrency-safe is a Task 11 concern** and introduces **no additional
ERD/logical schema** here. The instant-vs-staff origin is captured by B.2.1.

---

## 4. Section C — Area 3: Analytical reporting needs

### C.1 No-schema-change statement

The four Phase 2 reports are **fully answerable as queries** over the existing Phase 1
schema plus the Area-1 additions. No support entity or table is required:

| Report | Data source (existing / designed) | Schema change? |
|---|---|---|
| #1 Total approved booking hours per space per semester | `bookings` (approved/checked_in/completed) + `spaces` | No — derived query |
| #2 Approved bookings by weekday & hour per semester | `bookings` | No — derived query |
| #3 Room finder (capacity + facility list within a period) | `spaces` + `space_facilities` + `facilities` + overlap with `bookings`/`maintenance` | No — derived query |
| #4 Approved bookings affected on escalation to out-of-service | `booking_advisory_acknowledgement` ↔ `maintenance` (Area 1) + `bookings` | No — derived query |

> The room-finder and report #4 must derive availability from `bookings`/`maintenance`
> time-overlap, **not** from `spaces.current_status` (Area 1, §A.3). Supporting indexes
> for these queries are the Task 15 index-tuning pass, not a Task 09 schema decision.

---

## 5. 3NF Re-Check

| Relation | 1NF | 2NF | 3NF | Evidence |
|---|---|---|---|---|
| `maintenance` | ✅ atomic, no repeating groups | ✅ single-column PK | ✅ no transitive dependency | `impact_level` is a direct property of `maintenance_id`; no non-key column depends on another non-key column |
| `maintenance_impact_history` | ✅ atomic | ✅ single-column PK `history_id` | ✅ no transitive dependency | `maintenance_id`, `changed_by`, `prior_level`, `new_level`, `changed_at` all depend only on `history_id` |
| `booking_advisory_acknowledgement` | ✅ atomic | ✅ single-column PK `ack_id` | ✅ no transitive dependency | `booking_id`, `maintenance_id`, `acknowledged_at`, `acknowledged_by` depend only on `ack_id`; UQ (booking_id, maintenance_id) is an alternate key, not a partial dependency |
| `booking_approvals` | ✅ atomic | ✅ single-column PK `approval_id` | ✅ no transitive dependency | `approval_source` is a direct property of the decision row (`approval_id`); no functional dependency `approval_id → non-key → other non-key`; UQ `booking_id` is an alternate key |
| `users` | ✅ atomic | ✅ single-column PK `user_id` | ✅ no transitive dependency | unchanged from Phase 1; the reserved system row does not alter the relation's FDs |

All affected relations satisfy at least 3NF. No functional dependencies beyond
key → each non-key attribute were identified; no multi-valued attributes; no
composite-key partial dependencies (single-column surrogate PKs).

---

## 6. Deviations from Phase 1 — business rules & related elements

### 6.1 Changed Phase 1 business rules (Phase 2 impact)

| BR | Phase 1 meaning | Phase 2 meaning | Schema impact (this task) | Enforcement change |
|---|---|---|---|---|
| **BR2** | Unavailable spaces cannot be approved (read `spaces.current_status`) | Availability is decided by `out-of-service` maintenance overlap; `current_status` is only a hint | none (spaces unchanged) | `trg_booking_approvals_check_space` re-sourced — Task 10/11 |
| **BR4** | Any unresolved maintenance blocks booking | Only `impact_level='out-of-service'` blocks; advisory overlaps allowed but require acknowledgement | `maintenance.impact_level` (A.2.1) + ack table (A.2.3) | `trg_bookings_check_maintenance` re-filtered — Task 10 |
| **BR19** | Maintenance completion restores space to `available` | Completion feeds the impact-aware recompute; advisory completion never touched `under_maintenance` | none | recompute trigger (A.3) — Task 10 |
| **BR1** | No overlapping approved bookings | Same invariant, now also enforced for auto-approved (instant) bookings | `booking_approvals.approval_source` (B.2.1) records the path | concurrency-safe enforcement — Task 11 |
| **BR14** | Staff view reports | New reporting set (4 reports) | none | query + indexes — Tasks 15/16 |
| **BR6/BR7/BR15** | Approver metadata / role rules | Instant path satisfies them via the reserved system user | reserved `users` row (B.2.2) | none |

### 6.2 ERD / logical schema deviations

| # | Element (Phase 1) | Phase 2 design | Deviation | Justification |
|---|---|---|---|---|
| D1 | `maintenance` had no impact concept | `impact_level VARCHAR(50) NOT NULL DEFAULT 'out-of-service'` | Added column | NR1 — impact levels; default preserves Phase 1 blocking semantics for legacy rows |
| D2 | Escalation/downgrade not modeled | new `maintenance_impact_history` | Added table | NR3 — level changes while open must be tracked; also anchors NR4 escalation-time query |
| D3 | Advisory awareness not modeled | new `booking_advisory_acknowledgement` | Added table | NR2 — must record that the requester was informed of active advisories |
| D4 | `spaces.current_status` a stale hint, set only on completion | recomputed on maintenance INSERT/UPDATE/resolve via priority rule | Behavior change | U5 / `docs/design-decisions.md` — flag must stay consistent with maintenance state; advisory must not set `under_maintenance` |
| D5 | Escalation notification not addressed | no `escalation_notification` table | Decided out of scope | NR4 is report #4 (Area 3), derivable from acknowledgement + maintenance overlap |
| D6 | Approval origin not recorded | `booking_approvals.approval_source` (`'instant'` \| `'staff'`) | Added column | NR5 — must distinguish auto-approval from staff approval |
| D7 | No approver for auto-approval | reserved system user `user_id = -1` (`role='facility_manager'`) | Added seed row (data) | keeps `approver_id NOT NULL` and BR6/BR15 intact |
| D8 | Reporting needs (C3) | no support table added | No schema change | reports are derived queries (§4) |

---

## 7. Resolved Ambiguities

| # | Question | Decision | Designed in |
|---|---|---|---|
| U1 | Which space types are eligible for instant booking; what is the usage-policy test? | Eligible set `{classroom, computer_lab, project_lab, meeting_room}`; test = checks 1∧2∧3∧4∧5 (space_type eligible, requester active, participants ≤ capacity, no overlap, no out-of-service overlap). Test is business logic reusing BR1/BR3/BR4 — no extra schema. | §B.2, §8 |
| U2 | How is the advisory acknowledgement captured/stored? | New child table `booking_advisory_acknowledgement`, one row per (booking, advisory), with `acknowledged_at` / `acknowledged_by` | §A.2.3 |
| U5 | Should `out-of-service` maintenance flip `spaces.current_status`, or is the status derived? | `spaces` unchanged; `current_status` is a display hint recomputed on maintenance INSERT/UPDATE/resolve via the priority rule; correctness comes from `maintenance` overlap | §A.3 |

Carried forward (not in Task 09 scope): **U3** (escalation → pending vs only approved — Task 11),
**U4** (semester reporting window — Task 16).

---

## 8. Assumptions / Unresolved Ambiguities

### Assumptions

| # | Assumption | Rationale |
|---|---|---|
| A09-1 | `impact_level` default `'out-of-service'` on migration so legacy maintenance rows keep Phase 1 blocking behavior | Without a default, migrated rows would become advisory and silently stop blocking |
| A09-2 | Advisory acknowledgement is recorded at booking time (insert) and keyed to the specific advisory records | NR2 says "must record that the requester was informed"; per-advisory rows make report #4 derivable |
| A09-3 | The instant-booking test includes the **requester `account_status = 'active'`** gate (check 2) | Account lifecycle attribute exists in Phase 1; an auto-approval must not go to a suspended/inactive account |
| A09-4 | The instant approver is the reserved system user `user_id = -1` (role `facility_manager`) | Keeps `approver_id NOT NULL` and satisfies BR6/BR15 without real-staff involvement |
| A09-5 | Instant auto-approval is a *submission-time* decision; the concurrency-safe enforcement of the no-overlap rule is designed in Task 11, not here | Task 09 is schema-only; the mechanism is a later task |

### Unresolved (carried forward)

| # | Question | Resolved before |
|---|---|---|
| U3 | Does escalation to out-of-service affect pending requests or only approved bookings? | Task 11 |
| U4 | Exact "semester" reporting window definition | Task 16 |

---

## 9. Revision Log

| Version | Date | Change |
|---|---|---|
| 2.0 (all) | 2026-08-03 | Full regeneration covering all three areas: Area 1 (maintenance impact levels, `maintenance_impact_history`, `booking_advisory_acknowledgement`, `current_status` recompute); Area 2 (`booking_approvals.approval_source`, reserved system user `-1`, instant eligibility/test, concurrency enforcement deferred to Task 11); Area 3 (no schema change — derived queries). |
| 1.0 (Area 1) | 2026-08-03 | Created output with Area 1 only (`--req 1`): maintenance impact levels, `maintenance_impact_history`, `booking_advisory_acknowledgement`, `current_status` recompute. Areas 2/3 pending scoped runs. |
