# planFix.md — Booking ↔ Advisory-Ack Trigger Fix Plan (rev 3 — FINAL)

**Branch:** `feature/booking-ack-trigger` (created from `main` @ 533de68)
**Date:** 2026-08-09
**Owner:** CS486 G05 — Database Design Agent
**Status:** APPROVED FOR GENERATION — order 10 → 12 → 11 → 13 → docs

---

## 0. Verdicts closed this round (delta vs rev 2)

| # | Verdict | Detail |
|---|---|---|
| V1 | **ACK contract = implicit acknowledgment — CONFIRMED, not ambiguous** | The requirement contract is "the system **records that the requester was informed**" — a bookkeeping obligation, not consent capture. Evidence chain: `docs/project_phase2_description.md:16` → `docs/project-overview.md:61-62` → `outputs/08:68-70` (NR2) → `outputs/09:150-153` (A.2.3) → `docs/entity-registry.md:363`. No UI spec, no consent parameter in any procedure signature, no consent column anywhere. Approved designs already fabricate acks: W1 step 9 unconditional (11:326-329; 12:363-374) and W2 DD6 repair invents acks on the requester's behalf (11:77; 12:586-625), with c13 asserting that as correct behavior. A trigger cannot prove a popup was read — the requirement never asked it to. **The proposed trigger preserves the contract.** |
| V2 | **R6 CLOSED (verified)** | New trigger predicate is the exact logical complement of `trg_booking_advisory_ack_validate` (10-schema-migration-G05.sql:538-543) with matched strictness (`<`↔`>=`, `>↔<=`, same NULL semantics on `completion_time`, same status/impact filters) → an ack insert produced by the trigger can never be rejected by 8c. Keep a generation-time line-diff as a checklist item; add a complement-guard comment inside the trigger source. |
| V3 | **R7 CLOSED — the b03-B claim is FALSE** | `trg_booking_approvals_check_space` is defined `ON booking_approvals` (10-schema-migration-G05.sql:451-452), not `ON bookings`. b03-B inserts into `bookings` only (`status='approved'`, b03_escalation_b.sql:18-23) and never into `booking_approvals` → the 51004 gate never fires on that path regardless of ack completeness. **There is no latent 51004 to fix.** True effect of the new trigger on b03-B: its raw insert may auto-create one inert ack row (only if M3 still reads advisory at that instant); both Q_NR6 assertions are unaffected. Remove the "fixes latent 51004" claim from R1/R5/4.4. |
| V4 | **R8 CLOSED — same artifact** | Report #4 (09:443) ≡ Q5 (`usp_task16_q5_escalation_impact`, header comment "Supports Phase 2 Report #4", 16:328-331) ≡ doc 11's "report #4" (11:487). One query, three names → standardize to **Report #4 (Q5, `usp_task16_q5_escalation_impact`)**. The Report #4 / K5 scope gap (submit-wins bookings undiscoverable via the ack-joined report) remains OPEN and out of scope for this change. |
| V5 | **4.3 bundled debt ALREADY CLOSED in rev 3.4** | §9 already names the baseline BR2 availability gate (11:439-441), and revision log 3.4 (2026-08-08) already records the Report #4/K5 finding + Q5 citation + §9 gate wording (11:531). → Remove both bundled-debt bullets from 4.3; no no-op edits, no redundant fourth log line. |
| V6 | **Wording standard** | Wherever docs say the requester "confirmed", write "the system **recorded that the requester was informed / deemed acknowledged at booking time**" (e.g. `acknowledged_at` note at 09:160). Forestalls the exact confusion this review raised. |

R1–R5 from rev 2 are otherwise unchanged — the unconditional-fire rationale, the 3-layer completeness framing, the implicit-consent trade-off, the honest Task 14 reframing, and the "atomicity was already true vs. non-contractual-DML defense is the real value" goal split are all sound as written.

---

## 1. Goal

Two distinct things this change is for — worth keeping separate, since only one of them is actually new:

1. **Already true, not new:** `usp_booking_instant_submit` already inserts the booking and its ack rows inside one transaction (W1 steps 8–9 today). The "click Book → one atomic write, click Not → nothing written" UI story was already correct before this trigger existed.
2. **Actually new:** today, a `bookings` row can exist with zero ack rows if something writes to the table outside the four Task 12 procedures (raw DML, an ad-hoc fix, a bug). The trigger's real job is closing that gap — see R5. Making the schema itself enforce "a booking row implies ack rows for every advisory active at insert time" moves this guarantee from "application code remembered to do it" to "the database won't allow otherwise," for every insert path, including ones nobody wrote a procedure for.

**Consent model (V1): implicit consent.** The existence of the booking is the system's record that the requester was informed of (and is deemed to have acknowledged) the active advisories at booking time. The use of `acknowledged_by`/`acknowledged_at` records that the system **attributes** acknowledgement to the requester at booking time — it is NOT a durable proof that a person actually saw a popup, and the requirement (NR2) never asked for such proof. The popup is the notification channel NR2 requires; the "Book" click is the consent action; the database records the outcome (booking + acks), never the click itself. No new schema column (e.g. `is_explicit_consent`) is added; no current report needs one.

---

## 2. Verified current state (evidence)

| Fact | Evidence |
|---|---|
| Requirement contract = "record that the requester was informed" (implicit, not explicit consent) | `docs/project_phase2_description.md:16`; `docs/project-overview.md:61-62`; `outputs/08:68-70`; `outputs/09:150-153`; `docs/entity-registry.md:363` |
| Ack rows are created procedurally, not by the schema | `outputs/12-concurrency-implementation-G05.sql:363-374` (W1 step 8) and `:586-625` (W2 NR2 repair) |
| W1 step 8 is **unconditional** — fires for soft-gate fallback pending bookings too (no `IF @instant_accepted` guard) | `outputs/12-concurrency-implementation-G05.sql:353-384` (step 7 inserts `'pending'`, step 8 acks, step 9 gates ONLY the approval insert) |
| Ack table + UQ `(booking_id, maintenance_id)` | `outputs/10-schema-migration-G05.sql:249-318` |
| Approvals gate `trg_booking_approvals_check_space` fires **ON `booking_approvals`** (not `bookings`) and rejects on missing acks (51004) | `outputs/10-schema-migration-G05.sql:451-516` |
| Ack-row validity trigger `trg_booking_advisory_ack_validate` (predicate = complement of new trigger, V2) | `outputs/10-schema-migration-G05.sql:527-551` |
| Task 14 bulk-loads with `FIRE_TRIGGERS` **omitted by design** → new trigger never fires during generator load | `outputs/14-data-generator-G05/README.md:81-117`, `load.sql:116-121` |
| Generator already generates its own ack rows | `outputs/14-data-generator-G05/generate.py:674-689` |
| c13 asserts W2 repair from a deliberately-ackless state | `outputs/13-concurrency-tests-G05/controlled/c13_ack_repair.sql` (whole file) |
| 00_setup seeds advisory M9 **before** partial booking PB13 | `outputs/13-concurrency-tests-G05/00_setup.sql:121-166` |
| T13 baseline b03-B raw-inserts a booking with status `'approved'` overlapping advisory M3 — and **never touches `booking_approvals`** (V3) | `outputs/13-concurrency-tests-G05/baseline/b03_escalation_b.sql:18-23` |
| Q5 (escalation report) only joins acks for `approved/checked_in/completed` bookings | `outputs/16-analytical-queries-G05.sql:417-430` |
| Report #4 (doc 09) ≡ Q5 (Task 16) — same query under two names (V4) | `outputs/09:443`; `outputs/16:328-331`; `outputs/11:487` |
| Task 11 §9 already names the baseline BR2 gate; revision log 3.4 already logs the Report #4/K5 finding (V5) | `outputs/11:439-441`, `outputs/11:531` |
| `memory/Progress.md` merge conflict resolved (Task 10 rev5, 11 v3.4, 12 rev3, 13 ✅) | verified — no `<<<<<<<` markers remain |

---

## 3. Decisions (explicit, captured before generation)

### R1 — The trigger fires unconditionally on EVERY `bookings` INSERT

**Decision:** `trg_bookings_insert_advisory_acknowledgements` runs `AFTER INSERT` on `bookings` with no dependence on approval path or status.

**Rationale:** this exactly mirrors W1 step 8's existing unconditional behavior (see §2). A soft-gate fallback booking already receives acks today while staying `pending`. The trigger preserves that semantic and extends it to the raw-DML path.

**Computed implications (checked, no behavior change):**
- Instant submit (c01, c03b, c12, …): procedure inserts booking; trigger acks; W1 step 8 removed (see R3) → same end state as today.
- Pending/soft-gate fallback: acks present at insert → approval gate already satisfied for insert-time advisories → same as current W1 behavior.
- Advisories created AFTER booking insert: NOT covered by this trigger → W2 repair (DD6) is the repair source (unchanged).
- Approval still fails 51004 only when acks are missing AND W2 could not repair (non-contractual DML bypassing procedures).
- Trigger fires regardless of the inserted row's `status` value — including `'rejected'`/`'cancelled'` if such an insert ever occurs directly. Harmless (inert ack rows on a non-confirmed booking), but worth stating explicitly since "unconditional" here means unconditional on status too, not just on approval path.
- **Corrected per V3:** the trigger does NOT "fix a latent 51004 for b03-B" — the approvals gate never fires on that path. Its only effect on b03-B is possibly creating one inert ack row; assertions unchanged.

### R2 — 3-layer completeness architecture (write into Task 11 doc + design-decisions)

| Layer | Scope | Mechanism |
|---|---|---|
| 1. At insert | Advisories active at booking-insert time | NEW trigger (this fix) |
| 2. At approval | Advisories created after booking insert (DD6 window) | W2 NR2 repair in `usp_booking_approve` (unchanged) |
| 3. Last-resort veto | Any path that bypasses 1+2 | `trg_booking_approvals_check_space` 51004 (unchanged) |

There is no inconsistency between "self-heal at insert" and "reject at approval": each layer defends a different gap.

**Accepted trade-off (record explicitly):** implicit consent (V1/V6). A raw DML insert that bypasses the UI popup will get ack rows fabricated on behalf of the requester (`acknowledged_by` = `inserted.requester_id`). Same trust boundary as the existing W1 step 8. Option 2 (`is_explicit_consent` column) rejected: schema churn across Task 09/10/14 and no current report needs it.

### R3 — Trigger becomes SINGLE source of truth; W1 ack INSERT removed

**Decision:** remove W1 step 8's `INSERT INTO dbo.booking_advisory_acknowledgement` from `usp_booking_instant_submit` (Task 12 rev4). The trigger replaces it under the same transaction (booking insert fires trigger → acks materialize; atomicity).

**Why not keep both with `NOT EXISTS` guards:** dual ownership of the same predicate invites divergence (the exact class of defects the repo's G-checks exist to catch); one owner, the schema, is the enforceable boundary.

**Why not keep the procedure insert and skip the trigger:** the trigger is the only mechanism that also covers raw DML (ad-hoc fixes, app bugs, future code).

**Consequence worth stating explicitly:** since the trigger runs inside the same transaction as the triggering `INSERT`, a failure inside the trigger (e.g. a future predicate drift vs 8c) now rolls back the *raw* insert too. This is a desirable fail-fast change, but it is a behavior change to raw-insert semantics and should be called out as such.

### R4 — Scope of guarantee (no overclaim)

The trigger guarantees:
> For every inserted booking, ack rows exist for every **active advisory at insert time** overlapping the booking period.

It does NOT guarantee: acks for advisories created between insert and approval (DD6/W2 territory, unchanged), nor ack consistency for revoked/deleted maintenance (handled by `trg_booking_advisory_ack_validate`).

### R5 — Task 14 honest framing (no DRY benefit)

The trigger fires only for ordinary `INSERT` paths. Task 14's `BULK INSERT` omits `FIRE_TRIGGERS` (by design, README 81-117) → the trigger never fires during generator load → generator keeps its own ack-generation logic (`generate.py:674-689`).

**Stated purpose of the trigger (final):** harden the **non-contractual-DML boundary** — guaranteed acks for booking rows written outside Task 12 procedures. Value: protects ad-hoc DBA fixes, app bugs, and any future insert path; satisfies NR2 even when an application forgets popup-consent plumbing. It does NOT simplify Task 14. *(The earlier "fixes a latent 51004 in b03-B" value claim is retracted per V3.)*

### R6 — Predicate equivalence (CLOSED — verified, keep checklist diff)

**Status (V2):** the new trigger's overlap predicate is the exact logical complement of `trg_booking_advisory_ack_validate`'s rejection predicate (10:538-543): same strictness (`<` vs `>=`, `>` vs `<=`), same NULL handling on `completion_time`, same status/impact/deleted filters. The ack insert can never be rejected by 8c.

**Remaining action:** at generation time, perform the literal line-by-line diff as a checklist item (belt-and-braces), and add a comment inside the new trigger source: *"must remain the exact complement of trg_booking_advisory_ack_validate"*.

### R7 — Trigger-table question (CLOSED — claim corrected per V3)

**Status (V3):** `trg_booking_approvals_check_space` is `ON booking_approvals`; b03-B inserts no `booking_approvals` row → the 51004 gate never fires on b03-B's path. Correct b03-B's test comment to the verified behavior: "raw approved insert succeeds; the approvals gate is not on this path; the new ack trigger may add one inert ack row."

### R8 — Report #4 / Q5 naming (CLOSED — same artifact, standardize)

**Status (V4):** Report #4 (doc 09) ≡ Q5 (`usp_task16_q5_escalation_impact`, Task 16) ≡ doc 11 "report #4". Standardize to **Report #4 (Q5, `usp_task16_q5_escalation_impact`)** in doc 11's W1/wording changes and Task 16 comments touched this round. The K5 submit-wins scope gap remains documented as open and out of scope for this change.

---

## 4. Task-by-task work plan (generation order: 10 → 12 → 11 → 13 → docs)

### 4.1 Task 10 → rev6 — schema migration (trigger definition)

- Add trigger `trg_bookings_insert_advisory_acknowledgements` (`AFTER INSERT ON bookings`):
  - set-based: `INSERT INTO dbo.booking_advisory_acknowledgement
    (booking_id, maintenance_id, acknowledged_at, acknowledged_by)
    SELECT i.booking_id, m.maintenance_id, SYSDATETIME(), i.requester_id
    FROM inserted i
    JOIN dbo.maintenance m
      ON m.space_id = i.space_id AND m.is_deleted = 0
     AND m.status IN ('open','in_progress') AND m.impact_level = 'advisory'
     AND m.start_time < i.requested_end_time
     AND (m.completion_time IS NULL OR m.completion_time > i.requested_start_time)`
  - **R6 checklist:** diff this predicate literally against `trg_booking_advisory_ack_validate` (10:538-543) — exact complement. Add the complement-guard source comment.
  - multi-row safe (handles multi-row INSERT)
  - `SET NOCOUNT ON`, no error/threshold surprises (mirrors existing 8a-8d style)
  - confirm `SYSDATETIME()` matches the timestamp convention used elsewhere in the migration (GETDATE() in the ack table DEFAULT) — pick one consistent choice.
- Update rollback script (`10-schema-migration-G05-rollback.sql`): add the `DROP TRIGGER`.
- Compile + smoke on scratch DB per repo convention, **including a seeded case where an advisory already overlaps a booking being inserted** — the R6-protected case must be exercised, not just reasoned about.

### 4.2 Task 12 → rev4 — concurrency implementation

- Remove W1 step 8 ack INSERT (`12-concurrency-implementation-G05.sql:363-374`); renumber/reword step comments (step 9 auto-approval becomes step 8, etc.) or keep numbering with a comment referencing the trigger.
- W2 NR2 repair (`:586-625`) — UNCHANGED (DD6 layer).
- No schema change; procedures only; error codes 0/51001–51009 unchanged.
- Smoke re-run (S1–S6d equivalent) + idempotent re-run on scratch DB.

### 4.3 Task 11 → doc revision

- W1 step wording: "prepare one acknowledgement row per advisory" → "ack rows are materialized by the schema trigger at booking insert (`trg_bookings_insert_advisory_acknowledgements`); W1 no longer inserts acks".
- Add the 3-layer completeness table (R2) + implicit-consent sentence with V6 phrasing ("recorded that the requester was informed / deemed acknowledged at booking time" — not "confirmed").
- R8 naming: doc 11's report #4 references → "Report #4 (Q5, `usp_task16_q5_escalation_impact`)".
- Add ONE revision-log entry (4.0, 2026-08-09) covering: trigger-based ack materialization at insert, R8 naming standardization, consent wording change. **No re-logging of the 3.4 items (already closed, V5).**
- No design change to entry points, lock keys, codes, or DD6.

### 4.4 Task 13 → fixture fix (c13 preserved, not weakened)

- 00_setup.sql order change: insert **PB13 first**, then **advisory M9** (currently M9 first at lines 123-131, PB13 last at 163-166). Rationale: c13's premise is "ack rows deliberately missing for (PB13, M9)". After R1 the missing-ack state is only constructible when the advisory is created AFTER the booking row. The reorder preserves c13's exact assertions (rc=0, W2 repairs, acks attributed to requester) and makes the scenario the realistic DD6 case (advisory created post-booking).
- c13_ack_repair.sql: comment update only (scenario now "advisory created after booking"); assertions unchanged.
- b03-B comment corrected per V3: no "now succeeds via the trigger" claim; state that the approvals gate is not on this path and the trigger's only effect is a possible inert ack row. Other baselines (b01/b02/b05/b09/b10): assertions unaffected.
- **NEW non-optional test case (raw-insert trigger):** raw `INSERT INTO bookings` overlapping an active advisory → assert ack rows exist immediately (and `booking_advisory_acknowledgement` count = number of overlapping advisories). This directly tests the trigger's stated primary purpose (R5) — currently only incidentally covered by b03-B.

### 4.5 Docs

- `docs/design-decisions.md` — new entry recording V1 verdict (implicit consent explicit) + R1–R8 with rationale and date; use V6 wording.
- `memory/Progress.md` — after user handshake (approval protocol), update statuses + decisions log. The pre-existing merge conflict is already resolved (Task 10 rev5, Task 11 v3.4, Task 12 rev3, Task 13 ✅ — no markers).
- `improvement_logs.md` — if warranted (process note: "plan reviewer raised predicate-equivalence + trigger-table verification; added verification gates to plan").

### 4.6 Explicitly NOT touched

- Task 09 (no schema/ERD change; consent model unchanged — wording-only option noted in V6)
- Task 14 (generator, verify.sql, load.sql — no benefit, no conflict)
- Task 15 (index tuning)
- Task 16 (Q5's join logic unaffected by *this* fix; R8 naming standardization is comment-level only; the Report #4/K5 discovery gap remains open and out of scope)
- Task 08, 05, 04, 03, 02, 01 (locked)

---

## 5. Validation checklist (after each generation)

- [ ] Trigger compiles; rollback script drops it; scratch-DB smoke passes **including a seeded advisory-overlap-at-insert case**
- [ ] R6: new trigger's predicate diffed line-by-line against `trg_booking_advisory_ack_validate` (10:538-543) — confirmed exact complement; complement-guard comment present in source
- [ ] `usp_booking_instant_submit` still returns 0 and creates acks (via trigger)
- [ ] Soft-gate fallback (c11) still returns 0 with pending + acks present
- [ ] c13 still asserts rc=0 + acks by requester from the reordered fixture
- [ ] b03-B comment corrected per V3 (no latent-51004 claim; approvals gate not on this path)
- [ ] NEW raw-insert trigger test passes (acks exist immediately after raw insert)
- [ ] UQ `(booking_id, maintenance_id)` never violated by double-insert (no W1 step 8)
- [ ] Report #4 (Q5, `usp_task16_q5_escalation_impact`) name standardized in doc 11 comments
- [ ] Task 11 revision log has exactly ONE 4.0 entry (no re-logging of 3.4-closed items)
- [ ] `memory/Progress.md` free of conflict markers; statuses accurate
- [ ] design-decisions.md entry present with V1 + R1–R8; consent wording = V6 phrasing

---

## 6. Confirmed decisions (locked)

| # | Decision | Status |
|---|---|---|
| 1 | R1 — unconditional trigger (every `bookings` INSERT, status-agnostic) | ✅ confirmed |
| 2 | R3 — remove W1 step-8 ack INSERT; trigger sole owner | ✅ confirmed contingent on R6 diff |
| 3 | R6 — predicate-equivalence verification | ✅ required (closed; keep checklist diff) |
| 4 | R7 — trigger-table verification | ✅ required (closed: claim corrected) |
| 5 | R8 — Report #4 / Q5 naming standardization | ✅ resolve now |
| 6 | Raw-insert trigger test in Task 13 | ✅ non-optional |
| 7 | V6 — "recorded that the requester was informed / deemed acknowledged" wording | ✅ adopted |
| 8 | Commit policy: incremental (planFix.md → 10 → 12 → 11 → 13 → docs) | ✅ user call: incremental |

---

## 7. Open items (none blocking; for the record)

- The Report #4 / K5 submit-wins discovery gap (advisory escalated after instant submit; booking confirmed with no ack row and no escalation event) remains documented as OUT OF SCOPE for this change — tracked in doc 11, §7.4/§10 wording.
- Live execution of the full Task 13 suite against a SQL Server instance is pending a scratch DB/container — static generation + compile checks happen first; live run per repo convention when the instance is available.