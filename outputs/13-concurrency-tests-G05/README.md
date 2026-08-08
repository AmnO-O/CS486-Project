# Task 13 — Concurrency Tests (CS486 G05)

Comparison suite proving the Task 12 concurrency entry points close the races
that raw (uncontrolled) concurrency breaks. Every conflict family is delivered
**twice**: a `baseline/` twin (raw SQL, no critical section) and a `controlled/`
twin (the same race through the Task 12 procedures).

Folder: `outputs/13-concurrency-tests-G05/`

---

## 1. Prerequisites (script order)

```
05-db-definition  ->  06-sample-data  ->  10-schema-migration  ->  12-concurrency-implementation  ->  this suite
```

- SQL Server 2019+ with the `dbo` objects of Tasks 05/10/12 present
  (00_setup preflights the four Task 12 entry points and THROWs 53001 if
  missing).
- `sqlcmd` on PATH (the runner uses `sqlcmd -b -C`).
- DB name defaults to `CampusSpaceDB`; override with env:
  `SQLCMD_SERVER`, `SQLCMD_DB`, `SQLCMD_USER`, `SQLCMD_PASSWORD`
  (omitting user/password = Windows/integrated auth).

## 2. Run

```bash
cd outputs/13-concurrency-tests-G05
./run_all.sh
```

The runner, in order: setup → 6 baseline pairs → 8 controlled pairs + 3
single-session gates → suite-wide invariant audit → teardown. Every script
logs to `results/<timestamp>-<name>.log`; exit 0 only if no `FAIL` line exists
in any log and sqlcmd never errored.

## 3. Coverage matrix (conflict → scenarios → expected)

| conflict family | baseline twin (no control) | controlled twin | controlled contract (codes) |
|---|---|---|---|
| K1 instant-vs-instant | `b01_a`/`b01_b` | `c01_a`/`c01_b` | winner rc=0/instant=1, loser 51003; audit Q_BR1=0 |
| K2 instant-vs-staff (approve-first) | `b02_a`/`b02_b` | `c02_a`/`c02_b` | approve-first rc=0, overlap submit 51003; submit-first 0/1, later approve 51003 |
| K3 escalation-vs-inflight (escalate-first) | `b03_a`/`b03_b` | `c03_a`/`c03_b` | escalation rc=0; submit 51002; pending untouched (DD1/T4) |
| K3' escalation-vs-inflight (submit-first) | — (b03 covers the race) | `c03b_a`/`c03b_b` | submit-first rc=0/instant=1; escalation rc=0 after; later submit 51002 |
| T5 lock timeout + T7 retry | `b05_a`/`b05_b` (uncontrolled blocking) | `c05_a`/`c05_b` | first report 51005 (5 s timeout), retry rc=0 after release |
| K5 ticket-vs-submit (both orders) | `b09_a`/`b09_b` | `c09_a`/`c09_b` | ticket-first → submit 51002; submit-first → rc=0/1, ticket creation rc=0, no ack rows |
| staff-vs-staff same-conflict | `b10_a`/`b10_b` | `c10_a`/`c10_b` | first approval rc=0, overlapping second 51003 |
| soft-gate fallback (T11) | — (no race) | `c11` | rc=0, instant=0, stays pending, no auto-approval row |
| fallback-vs-instant overlap | — | `c12` | fallback 0/0; instant 0/1 same window; later approve of fallback 51003 |
| advisory-ack repair in W2 | — | `c13` | approve rc=0 (not 51004); ack rows exist, acknowledged_by = requester |

**Baseline PASS condition:** the invariant violation materializes (audit count
≥ 1) or a raw engine error surfaces (unique-violation 2601/2627, deadlock 1205,
lock-timeout 1222, trigger THROW) — never a Task 12 business code. Controlled
PASS condition: exact business codes above and the audit prints 0.

**Non-contractual raw-DML boundary:** baseline scripts insert rows with RAW DML
(as Phase-1 users could, absent Task 12) through the same tables, backstopped by
the Phase-1 triggers and `uq_bookings_active_overlap` (committed-data only,
exact same-start only). They attribute any failure to the **missing critical
section**, never to the backstop objects.

## 4. Fixture (00_setup.sql)

TEST-13 world: 1 department, 2 users (`test13.requester@campus.edu` lecturer,
`test13.staff@campus.edu` facility_manager), 9 meeting_rooms
(`TEST-13-01-MR`…`09-MR`, capacity 30, `available`), one advisory (M3) + one
advisory (M9) maintenance ticket, 6 seeded pending bookings (PB2a/PB2b/PB3/
PB10a/PB10b/PB13). All windows ≥ +600 days from run time — never collides with
Task 06 sample data or Task 12 smoke windows (+340..+400 days). Idempotent.

Teardown (`99_cleanup.sql`) deletes the seeded world in FK-safe order and
THROWs if any TEST-13 row remains — provable cleanup per N3.

## 5. Results (recorded)

| date | environment | scenario PASSes | FAILs | notes |
|---|---|---|---|---|
| (fill after run) | (server) | (x/y) | (n) | |

## 6. Notes / decisions recorded this run

- Baseline scope decision: FULL baseline (K1, K2, K3, K5 + lock-blocking b05
  + touch staff-vs-staff b10) — recorded in `docs/design-decisions.md`.
- Session B must be a different sqlcmd process (locks are connection-scoped) —
  the runner launches `_a` and `_b` in parallel (N1).
- Entry points are called standalone (they own transactions; never wrap them in
  an outer batch transaction — N3/Task12).