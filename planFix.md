# planFix.md — Booking ↔ Advisory-Ack Trigger Fix Plan (rev 4 — FINAL)

**Branch:** `feature/booking-ack-trigger` (created from `main` @ 533de68)
**Date:** 2026-08-09
**Owner:** CS486 G05 — Database Design Agent
**Status:** APPROVED FOR GENERATION — order 10 → 12 → 11 → 13 → docs
**Review pass:** rev 2 added R6–R8 (verification gates); rev 3 folded in the
investigation (R7 resolved+corrected, R9 wording, R10 b03 check, R2 strengthened).
This pass (rev 4) closes R6, R8, and R10 with in-repo evidence, drops the two
§4.3 "debt" items already closed in doc 11 rev 3.4, and scopes R9 to a single line.

---

## 0. What changed in this pass (rev 4 — delta vs rev 3)

- **R6 → CLOSED with the literal diff.** Both predicates are quoted verbatim,
  side-by-side, in §3 (R6) below: the new trigger's INSERT-eligible predicate is the
  exact logical complement of `trg_booking_advisory_ack_validate`'s rejection
  predicate (`10-schema-migration-G05.sql:538-543`), with matched strictness
  (`<`↔`>=`, `>↔<=`) and identical NULL semantics on `completion_time`. No ack row
  produced by the trigger can be rejected by 8c. The same diff comment block will be
  embedded directly in Task 10's migration above the new trigger at generation.
- **R8 → CLOSED.** "Report #4" (doc 09) and "Q5" (Task 16) are the **same artifact
  under two names** — doc 11 itself states it: *"report #4 (doc 09 §C.1/§A.2.3;
  implemented by Task 16 query Q5 — 'confirmed bookings affected by escalation')"*
  (`outputs/11-concurrency-design-G05.md:386-388`); Task 16's Q5 header says
  "Supports Phase 2 Report #4" (`outputs/16-analytical-queries-G05.sql:328-331`);
  doc 09:443 defines report #4 as "Approved bookings affected on escalation."
  Standardize to **Report #4 (Q5, `usp_task16_q5_escalation_impact`)**.
- **R10 → CLOSED.** b03-B's assertions never read the ack table: the script only
  counts confirmed-bookings × out-of-service-maintenance overlaps (`b03_escalation_b.sql:34-45`)
  and prints M3's impact level; grep over `outputs/13-concurrency-tests-G05/baseline/*.sql`
  shows zero ack references. The trigger's side effect (one inert ack row on b03-B's
  raw insert) cannot change any b03 outcome. Cleanup is safe: c13 documents that
  booking deletion cascades approvals+acks (`c13_ack_repair.sql:52`). Both b03
  scripts remain untouched except a comment correction (see §4.4).
- **§4.3 debt items DROPPED.** Rev 3 reintroduced two "while this doc is open" items
  that were **already closed in doc 11 rev 3.4**: (a) §9 already names the baseline
  BR2 availability gate ("checks 2–5 … **plus the baseline BR2 availability gate**",
  `11:439-441`); (b) revision-log entry 3.4 (2026-08-08) already records the
  Report #4/K5 scope finding, the Q5 citation, and the §9 gate fix (`11:531`). Task 11
  gets **one** new 4.0 revision-log entry for this trigger change only.
- **R9 → scoped to one line.** Repo-wide grep for "confirmed" in ack context: the
  only "requester confirmed" instance is doc 09 A.2.3's `acknowledged_at` note
  (`outputs/09-updated-erd-and-logical-design-G05.md:160`). All other "confirmed"
  hits are the BR1 booking-status sense ("confirmed bookings") and must NOT be
  touched. R9 = reword that one line + use the new wording in everything we write
  this round.

R1–R5, R7, and the implicit-consent evidence (V1/V2/V3 from prior passes) are
unchanged and remain sound as written.

---

## 1. Goal

Two distinct things this change is for — worth keeping separate, since only one of
them is actually new:

1. **Already true, not new:** `usp_booking_instant_submit` already inserts the
   booking and its ack rows inside one transaction (W1 steps 8–9 today). The "click
   Book → one atomic write, click Not → nothing written" UI story was already
   correct before this trigger existed.
2. **Actually new:** today, a `bookings` row can exist with zero ack rows if
   something writes to the table outside the four Task 12 procedures (raw DML, an
   ad-hoc fix, a bug). The trigger's real job is closing that gap — see R5. Making
   the schema itself enforce "a booking row implies ack rows for every advisory
   active at insert time" moves this guarantee from "application code remembered
   to do it" to "the database won't allow otherwise," for every insert path,
   including ones nobody wrote a procedure for.

**Consent model — implicit, evidenced:** the existence of the booking IS the
system's record that the requester was informed of (and is deemed to have
acknowledged) the active advisories at booking time. Five independent sources
describe the requirement as "record that the requester was informed," never "prove
the requester read a popup" (`docs/project_phase2_description.md:16`;
`docs/project-overview.md:61-62`; `outputs/08:68-70`; `outputs/09:150-153`;
`docs/entity-registry.md:363`), and the project's own already-approved design (DD6)
fabricates acks with zero user interaction at approval time — so this was never an
open question about *this* trigger specifically. `acknowledged_by`/`acknowledged_at`
record that the system **attributes** acknowledgement to the requester at booking
time — not durable proof that a person saw a popup, and NR2 never asked for such
proof. The popup is the notification channel; the "Book" click is the consent
action; the database records the outcome (booking + acks), never the click itself.
No new schema column (e.g. `is_explicit_consent`) is added; no current report
needs one.

---

## 2. Verified current state (evidence)

| Fact | Evidence |
|---|---|
| Requirement contract = "record that the requester was informed" (implicit, not explicit consent) | `docs/project_phase2_description.md:16`; `docs/project-overview.md:61-62`; `outputs/08:68-70`; `outputs/09:150-153`; `docs/entity-registry.md:363` |
| Ack rows are created procedurally, not by the schema | `outputs/12-concurrency-implementation-G05.sql:363-374` (W1 step 8) and `:586-625` (W2 NR2 repair) |
| W1 step 8 is **unconditional** — fires for soft-gate fallback pending bookings too (no `IF @instant_accepted` guard) | `outputs/12-concurrency-implementation-G05.sql:353-384` (step 7 inserts `'pending'`, step 8 acks, step 9 gates ONLY the approval insert) |
| Ack table + UQ `(booking_id, maintenance_id)` | `outputs/10-schema-migration-G05.sql:249-318` |
| Approvals gate rejects on missing acks (51004) — **defined `ON dbo.booking_approvals`, confirmed (R7)** | `outputs/10-schema-migration-G05.sql:451-516` (`trg_booking_approvals_check_space`) |
| Ack-row validity trigger `trg_booking_advisory_ack_validate` — **predicate = exact complement of new trigger (R6, literal diff in §3)** | `outputs/10-schema-migration-G05.sql:527-551` |
| Task 14 bulk-loads with `FIRE_TRIGGERS` **omitted by design** → new trigger never fires during generator load | `outputs/14-data-generator-G05/README.md:81-117`, `load.sql:116-121` |
| Generator already generates its own ack rows | `outputs/14-data-generator-G05/generate.py:674-689` |
| c13 asserts W2 repair from a deliberately-ackless state | `outputs/13-concurrency-tests-G05/controlled/c13_ack_repair.sql` (whole file) |
| 00_setup seeds advisory M9 **before** partial booking PB13 | `outputs/13-concurrency-tests-G05/00_setup.sql:121-166` |
| T13 baseline b03-B raw-inserts a booking with status `'approved'` overlapping advisory M3; never touches `booking_approvals` → 51004 gate never fires on this path (R7) | `outputs/13-concurrency-tests-G05/baseline/b03_escalation_b.sql:18-23` |
| **b03 assertions never read the ack table (R10, closed)** — only Q overlap counts + M3 impact print; booking deletion cascades approvals+acks | `b03_escalation_b.sql:34-45`; grep `baseline/*.sql` = 0 ack hits; `c13_ack_repair.sql:52` |
| Q5 (escalation report) only joins acks for `approved/checked_in/completed` bookings | `outputs/16-analytical-queries-G05.sql:417-430` |
| Report #4 (doc 09) ≡ Q5 (Task 16) — same query, two names (R8, closed) | `outputs/11-concurrency-design-G05.md:386-388`; `outputs/16:328-331`; `outputs/09:443` |
| Task 11 §9 already names the baseline BR2 gate; revision log 3.4 already logs the Report #4/K5 finding (no-op — do not re-edit) | `outputs/11-concurrency-design-G05.md:439-441`, `:531` |
| The only "requester confirmed" wording in the repo is doc 09 A.2.3 `acknowledged_at` note (R9 scope = this one line) | `outputs/09-updated-erd-and-logical-design-G05.md:160`; repo-wide grep |
| `memory/Progress.md` merge conflict resolved (Task 10 rev5, 11 v3.4, 12 rev3, 13 ✅) | verified — no `<<<<<<<` markers remain |

---

## 3. Decisions (explicit, captured before generation)

### R1 — The trigger fires unconditionally on EVERY `bookings` INSERT

**Decision:** `trg_bookings_insert_advisory_acknowledgements` runs `AFTER INSERT` on
`bookings` with no dependence on approval path or status.

**Rationale:** this exactly mirrors W1 step 8's existing unconditional behavior
(see §2). A soft-gate fallback booking already receives acks today while staying
`pending`. The trigger preserves that semantic and extends it to the raw-DML path.

**Computed implications (checked, no behavior change):**
- Instant submit (c01, c03b, c12, …): procedure inserts booking; trigger acks;
  W1 step 8 removed (see R3) → same end state as today.
- Pending/soft-gate fallback: acks present at insert → approval gate already
  satisfied for insert-time advisories → same as current W1 behavior.
- Advisories created AFTER booking insert: NOT covered by this trigger → W2 repair
  (DD6) is the repair source (unchanged).
- Approval still fails 51004 only when acks are missing AND W2 could not repair
  (non-contractual DML bypassing procedures).
- Trigger fires regardless of the inserted row's `status` value — including
  `'rejected'`/`'cancelled'` if such an insert ever occurs directly, and including
  b03-B's raw `'approved'` insert (harmless to the invariant; b03 assertions
  unaffected per R10).
- **Corrected (R7/R10):** the trigger does NOT "fix a latent 51004 for b03-B" — the
  approvals gate is not on that path. Its only effect on b03-B is one inert ack row.

### R2 — 3-layer completeness architecture, consent model evidenced

| Layer | Scope | Mechanism |
|---|---|---|
| 1. At insert | Advisories active at booking-insert time | NEW trigger (this fix) |
| 2. At approval | Advisories created after booking insert (DD6 window) | W2 NR2 repair in `usp_booking_approve` (unchanged) |
| 3. Last-resort veto | Any path that bypasses 1+2 | `trg_booking_approvals_check_space` 51004 (unchanged) |

There is no inconsistency between "self-heal at insert" and "reject at approval":
each layer defends a different gap.

**Consent model — implicit, evidenced:** the requirement's own language, across
five independent sources, is "record that the requester was informed," never "prove
explicit confirmation." The one source that could read otherwise — doc 09 A.2.3's
`acknowledged_at = "when the requester confirmed"` — is loose wording, not a
distinct requirement: DD6 (already approved, implemented, and tested by c13)
fabricates ack rows with zero user interaction at approval time. If "confirmed"
meant a captured UI event, DD6 would already be a contract violation, and it isn't.
The trigger extends the same, already-accepted model to insert-time and raw-DML
cases; it introduces no new interpretation. R9 closes the ambiguous wording itself.

A raw DML insert that bypasses the UI popup will still get ack rows fabricated on
behalf of the requester (`acknowledged_by` = `inserted.requester_id`) — same trust
boundary as W1 step 8 and DD6 before it. Option 2 (`is_explicit_consent` column)
rejected: schema churn across Task 09/10/14 and no current report needs it.

### R3 — Trigger becomes SINGLE source of truth; W1 ack INSERT removed

**Decision:** remove W1 step 8's `INSERT INTO dbo.booking_advisory_acknowledgement`
from `usp_booking_instant_submit` (Task 12 rev4). The trigger replaces it under the
same transaction.

**Why not keep both with `NOT EXISTS` guards:** dual ownership of the same predicate
invites divergence — the exact class of defect R6 rules out. One owner, the schema,
is the enforceable boundary. **Confirmed necessary, not just preferred:** without
removing W1 step 8, the same `(booking_id, maintenance_id)` pair would be inserted
twice, violating the UQ constraint and breaking instant submit outright.

**Why not keep the procedure insert and skip the trigger:** the trigger is the only
mechanism that also covers raw DML (ad-hoc fixes, app bugs, future code).

**Consequence worth stating explicitly:** since the trigger runs inside the same
transaction as the triggering `INSERT`, a failure inside the trigger (e.g. future
predicate drift vs 8c) rolls back the raw insert too. Desirable fail-fast behavior,
but a behavior change to raw-insert semantics — called out, not discovered during
smoke testing.

### R4 — Scope of guarantee (no overclaim)

The trigger guarantees:
> For every inserted booking, ack rows exist for every **active advisory at insert
> time** overlapping the booking period.

It does NOT guarantee: acks for advisories created between insert and approval
(DD6/W2 territory, unchanged), nor ack consistency for revoked/deleted maintenance
(handled by `trg_booking_advisory_ack_validate`).

### R5 — Task 14 honest framing (no DRY benefit); b03-B claim corrected

The trigger fires only for ordinary `INSERT` paths. Task 14's `BULK INSERT` omits
`FIRE_TRIGGERS` (by design, README 81-117) → the trigger never fires during generator
load → generator keeps its own ack-generation logic (`generate.py:674-689`).

**Stated purpose of the trigger (final, corrected):** harden the
**non-contractual-DML boundary** — guaranteed acks for booking rows written outside
Task 12 procedures. **Not** a fix for a latent 51004 in b03-B (R7: that check is on
`booking_approvals`, which b03-B never touches). Value: protects ad-hoc DBA fixes,
app bugs, and any future insert path; satisfies NR2 even when an application forgets
popup-consent plumbing. It does NOT simplify Task 14.

### R6 — Predicate equivalence: CLOSED (literal diff embedded below)

**Status:** verified and documented. Side-by-side, the new trigger's INSERT-eligible
predicate and `trg_booking_advisory_ack_validate`'s rejection predicate
(`10-schema-migration-G05.sql:538-543`) are **exact logical complements**:

| New trigger (rows eligible for ack insert) | `trg_booking_advisory_ack_validate` (rows REJECTED) — 10:538-543 |
|---|---|
| `m.is_deleted = 0` | `b.is_deleted = 1 OR m.is_deleted = 1` |
| `m.status IN ('open','in_progress')` | `m.status NOT IN ('open','in_progress')` |
| `m.impact_level = 'advisory'` | `m.impact_level <> 'advisory'` |
| `m.start_time < i.requested_end_time` | `m.start_time >= b.requested_end_time` |
| `m.completion_time IS NULL OR m.completion_time > i.requested_start_time` | `m.completion_time IS NOT NULL AND m.completion_time <= b.requested_start_time` |

Matched strictness (`<`↔`>=`, `>↔<=`), identical NULL semantics, same columns →
an ack row produced by the trigger can never be rejected by 8c.

**Remaining action at generation:** embed this exact diff as a comment block
directly above the new trigger in Task 10's migration, so the equivalence is
checkable by reading that file alone. No further verification is open.

### R7 — `trg_booking_approvals_check_space`'s trigger table: RESOLVED

**Finding:** confirmed defined `ON dbo.booking_approvals` (`10:451-516`). b03-B's
raw insert never inserts a `booking_approvals` row, so this trigger never fires on
that path — there was no latent 51004 for the ack trigger to fix. Every place the
original plan claimed otherwise (§2, R5, §4.4) is corrected. Follow-up closed by
R10 (b03 assertions unaffected).

### R8 — "Report #4" vs "Q5": RESOLVED — same artifact, standardize name

**Finding:** doc 11 itself states the relationship: *"report #4 (doc 09 §C.1/§A.2.3;
implemented by Task 16 query Q5 — 'confirmed bookings affected by escalation')"*
(`11:386-388`); Task 16's Q5 header: "Supports Phase 2 Report #4" (`16:328-331`);
doc 09:443 defines report #4 as "Approved bookings affected on escalation."
**One query, two names.** Standardize to **Report #4 (Q5,
`usp_task16_q5_escalation_impact`)** in doc 11's references and Task 16 comments
touched this round. The Report #4 / K5 scope gap (submit-wins bookings
undiscoverable via the ack-joined report) remains documented as open and is out of
scope for this change.

### R9 — Standardize ack-consent wording (scoped to one line)

**Decision:** replace doc 09 A.2.3's `acknowledged_at` note "when the requester
confirmed" (`outputs/09:160`) with "when the system recorded that the requester was
informed / deemed acknowledged at booking time." Repo-wide grep confirms this is the
**only** ack-context "confirmed" instance; all other "confirmed" hits are the BR1
booking-status sense and must not be touched. Use the same wording in everything
written this round (doc 11 revision, design-decisions entry).

### R10 — b03 downstream assertions: RESOLVED

**Finding:** b03-B's assertions never reference the ack table — it only counts
confirmed-bookings × out-of-service-maintenance overlaps (`b03_escalation_b.sql:34-45`)
and prints M3's impact level; grep over `baseline/*.sql` shows zero ack references.
The trigger's side effect on b03-B (one inert ack row, only when M3 still reads
advisory at that instant) cannot change any b03 outcome. Cleanup is safe: booking
deletion cascades approvals+acks (documented in `c13_ack_repair.sql:52`). b03-A and
b03-B remain untouched; only b03-B's header comment is corrected (§4.4).

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
  - **R6 (closed):** embed the verbatim side-by-side diff comment block (from §3 R6)
    directly above the trigger, plus the guard comment "must remain the exact
    complement of trg_booking_advisory_ack_validate".
  - multi-row safe (handles multi-row INSERT)
  - `SET NOCOUNT ON`, no error/threshold surprises (mirrors existing 8a-8d style)
  - confirm `SYSDATETIME()` matches the timestamp convention used elsewhere in the
    migration (ack table DEFAULT uses `GETDATE()`) — pick one consistent choice.
- Update rollback script (`10-schema-migration-G05-rollback.sql`): add the `DROP TRIGGER`.
- Compile + smoke on scratch DB, **including a seeded case where an advisory already
  overlaps a booking being inserted** — exercises R6 directly rather than reasoning
  about it in the abstract.

### 4.2 Task 12 → rev4 — concurrency implementation

- Remove W1 step 8 ack INSERT (`12-concurrency-implementation-G05.sql:363-374`);
  renumber/reword step comments (step 9 auto-approval becomes step 8, etc.) or keep
  numbering with a comment referencing the trigger.
- W2 NR2 repair (`:586-625`) — UNCHANGED (DD6 layer).
- No schema change; procedures only; error codes 0/51001–51009 unchanged.
- Smoke re-run (S1–S6d equivalent) + idempotent re-run on scratch DB.

### 4.3 Task 11 → doc revision

- W1 step wording: "prepare one acknowledgement row per advisory" →
  "ack rows are materialized by the schema trigger at booking insert
  (`trg_bookings_insert_advisory_acknowledgements`); W1 no longer inserts acks".
- Add the 3-layer completeness table (R2) and the evidenced implicit-consent
  paragraph — cite the five sources and the DD6 self-consistency argument.
- **R9:** apply the "recorded that the requester was informed / deemed acknowledged
  at booking time" wording wherever this document touches the ack contract.
- **R8:** doc 11's report #4 references → "Report #4 (Q5,
  `usp_task16_q5_escalation_impact`)".
- Add **ONE** revision-log entry (4.0, 2026-08-09) covering: trigger-based ack
  materialization at insert, R8 naming standardization, R9 consent wording.
  **The §9 "checks 2–5" undercount and the Report #4/K5 log entry are already closed
  in rev 3.4 — do NOT re-edit them.**
- No design change to entry points, lock keys, codes, or DD6.

### 4.4 Task 13 → fixture fix (c13 preserved, not weakened)

- 00_setup.sql order change: insert **PB13 first**, then **advisory M9** (currently
  M9 first at lines 123-131, PB13 last at 163-166). Preserves c13's exact assertions
  (rc=0, W2 repairs, acks attributed to requester) and makes the scenario the
  realistic DD6 case (advisory created post-booking).
- c13_ack_repair.sql: comment update only; assertions unchanged.
- **b03-B: correct the header comment only (R7/R10).** No code change: this booking
  was never subject to the 51004 gate; the only change is it may now have one inert
  ack row. b03-A untouched.
- **NEW non-optional test case (raw-insert trigger):** raw `INSERT INTO bookings`
  overlapping an active advisory → assert ack rows exist immediately, count =
  number of overlapping advisories. This directly tests the trigger's stated primary
  purpose (R5); today only incidentally covered by b03-B.

### 4.5 Docs

- `docs/design-decisions.md` — new entry recording R1–R10 (with R6 diff, R7/R8/R10
  findings) and the implicit-consent verdict, using R9 wording; date + rationale.
- `memory/Progress.md` — after user handshake (approval protocol), update statuses +
  decisions log. Pre-existing merge conflict already resolved (no markers).
- `improvement_logs.md` — if warranted (process note: verification gates R6–R8/R10
  added after review).

### 4.6 Explicitly NOT touched

- Task 09 (no schema/ERD change; consent model unchanged — R9 is phrasing only,
  one line)
- Task 14 (generator, verify.sql, load.sql — no benefit, no conflict)
- Task 15 (index tuning)
- Task 16 (Q5 join logic unaffected by *this* fix; R8 naming is comment-level only;
  the Report #4/K5 discovery gap remains open, out of scope)
- Task 08, 05, 04, 03, 02, 01 (locked)

---

## 5. Validation checklist (after each generation)

- [ ] Trigger compiles; rollback script drops it; scratch-DB smoke passes **including
      a seeded advisory-overlap-at-insert case**
- [ ] R6: verbatim diff comment block present above the new trigger in Task 10
      migration (matches §3 R6 table)
- [ ] `usp_booking_instant_submit` still returns 0 and creates acks (via trigger)
- [ ] Soft-gate fallback (c11) still returns 0 with pending + acks present
- [ ] c13 still asserts rc=0 + acks by requester from the reordered fixture
- [ ] b03-B header comment corrected (no latent-51004 claim; R10 verified: b03
      assertions ack-independent)
- [ ] NEW raw-insert trigger test passes (acks exist immediately after raw insert)
- [ ] UQ `(booking_id, maintenance_id)` never violated by double-insert (no W1 step 8)
- [ ] R8: Report #4 (Q5, `usp_task16_q5_escalation_impact`) name standardized in
      doc 11 comments
- [ ] R9: "when the requester confirmed" → "recorded that the requester was informed"
      applied at doc 09:160; no other ack-context "confirmed" left
- [ ] Task 11 revision log has exactly ONE 4.0 entry; 3.4 items untouched
- [ ] `memory/Progress.md` free of conflict markers; statuses accurate
- [ ] design-decisions.md entry present with R1–R10 + consent wording

---

## 6. Confirmed decisions (locked)

| # | Decision | Status |
|---|---|---|
| 1 | R1 — unconditional trigger (every `bookings` INSERT, status-agnostic) | ✅ confirmed |
| 2 | R3 — remove W1 step-8 ack INSERT; trigger sole owner | ✅ confirmed (contingent on R6 diff — now embedded) |
| 3 | R6 — predicate equivalence, literal diff | ✅ closed (diff in §3; comment block at generation) |
| 4 | R7 — trigger-table verification | ✅ closed (gate on `booking_approvals`; claim corrected) |
| 5 | R8 — Report #4 / Q5 naming | ✅ closed (same artifact; standardize name) |
| 6 | R9 — consent wording standardization | ✅ closed (scope = doc 09:160 + new text) |
| 7 | R10 — b03 downstream assertions | ✅ closed (ack-independent; cascade confirmed) |
| 8 | Raw-insert trigger test in Task 13 | ✅ non-optional |
| 9 | Commit policy: incremental (planFix.md → 10 → 12 → 11 → 13 → docs) | ✅ user call: incremental |

## 7. Open items (none blocking; for the record)

- The Report #4 / K5 submit-wins discovery gap (advisory escalated after instant
  submit; booking confirmed with no ack row and no escalation event) remains
  documented as OUT OF SCOPE for this change — tracked in doc 11, §7.4/§10 wording.
- Live execution of the full Task 13 suite against a SQL Server instance is pending
  a scratch DB/container — static generation + compile checks happen first; live run
  per repo convention when the instance is available.