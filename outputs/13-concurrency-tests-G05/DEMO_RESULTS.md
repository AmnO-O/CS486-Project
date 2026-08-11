# Task 13 — Live Concurrency Test Demo Results

**System:** CS486 — Campus Space Management System  
**Group:** G05  
**Execution Environment:** Microsoft SQL Server 2022 (Developer Edition) in Docker Container (`cs486_sql_server`)  
**Target Database:** `CampusSpaceDB`  
**Database Isolation Mode:** `READ_COMMITTED_SNAPSHOT ON` (RCSI)  
**Output Location:** `outputs/13-concurrency-tests-G05/`  

---

## 1. Executive Summary & Architecture

The Task 13 test suite is designed as a **Comparison Suite** evaluating two concurrency control strategies under the `READ_COMMITTED_SNAPSHOT ON` (RCSI) database isolation mode:

- **Baseline (Uncontrolled - RAW DML):**  
  Direct T-SQL DML statements (`INSERT`, `UPDATE`) executed concurrently across two database sessions without Task 12 application-level locks. Under RCSI mode, `SELECT` queries inside Phase 1 triggers read committed row versions from `tempdb` without acquiring Shared Locks (S-Locks), avoiding lock-blocking. When two transactions execute concurrently before either commits, Phase 1 triggers are **bypassed**, committing overlapping rows to disk ($Q_{BR1} = 1$ or $Q_{NR6} = 1$). This empirically demonstrates the fundamental flaw of raw DML under concurrency: **data integrity corruption**.
- **Controlled (Task 12 Stored Procedures):**  
  All write operations route exclusively through Task 12 Stored Procedures (`usp_booking_instant_submit`, `usp_booking_approve`, `usp_maintenance_report`, `usp_maintenance_set_impact_level`). These procedures acquire transaction-owned application locks (`sys.sp_getapplock` on `space_booking:<space_id>`, Exclusive, 5-second timeout). This guarantees strict application-level serialization: winner gets `rc = 0`, loser receives deterministic business result codes (`51003` overlap, `51002` OOS space, `51005` lock timeout), achieving **100% data invariant preservation ($Q_{BR1} = 0$, $Q_{NR6} = 0$) without unhandled engine exceptions**.

---

## 2. Evaluation Criteria & Verification Logic

- **Baseline PASS Criterion (Flaw Demonstration):**  
  A Baseline scenario successfully passes verification when it empirically demonstrates the vulnerabilities of raw DML under concurrency—committing overlapping confirmed rows to disk ($Q_{BR1} \ge 1$ or $Q_{NR6} \ge 1$) due to trigger bypass under RCSI mode, or demonstrating uncontrolled blocking connection hangs without timeout contracts.
- **Controlled PASS Criterion (Control Verification):**  
  A Controlled scenario successfully passes verification when it satisfies three mandatory guarantees:
  1. **Data Invariant Preservation:** Zero overlapping confirmed bookings ($Q_{BR1} = 0$) and zero out-of-service maintenance conflicts ($Q_{NR6} = 0$).
  2. **Application Serialization:** Winner receives `rc = 0`; loser receives explicit structured business codes (`51003`, `51002`, `51005`).
  3. **Zero Unhandled Crashes:** 0% unhandled engine exceptions (`Msg 50000`), allowing client applications to handle responses gracefully.

---

## 3. Comprehensive Demo Results Matrix

| # | Conflict Scenario | Baseline Behavior (RAW DML Flaw) | Controlled Behavior (Task 12 Serialization) | Controlled Result Code | Invariant Audit ($Q_{BR1} / Q_{NR6}$) |
|:---:|:---|:---|:---|:---:|:---:|
| **1** | **K1: Instant vs Instant Submit** (`b01` vs `c01`) | **TRIGGER BYPASSED ($Q_{BR1}=1$):** Both sessions insert concurrently without blocking; 2 overlapping confirmed bookings committed to disk. | **PASS (Serialized):** Winner receives `rc=0`, concurrent submit rejected cleanly with business code `51003`. | `rc = 51003` (Overlap Conflict) | **$Q_{BR1} = 0$** |
| **2** | **K2: Instant Submit vs Staff Approval** (`b02` vs `c02`) | **TRIGGER BYPASSED ($Q_{BR1}=1$):** Session B inserts approved booking overlapping pending approval held uncommitted by Session A; both commit ($Q_{BR1}=1$). | **PASS (Serialized):** Operations strictly serialized; overlapping submit during pending approval rejected cleanly. | `rc = 51003` (BR1 Overlap) | **$Q_{BR1} = 0$** |
| **3** | **K3: Escalation vs In-flight Submit** (`b03` vs `c03` / `c03b`) | **TRIGGER BYPASSED ($Q_{NR6}=1$):** Booking confirmed while maintenance advisory, then maintenance escalated to out-of-service; overlap committed ($Q_{NR6}=1$). | **PASS (BR4 Protection):** AppLock serializes operations; booking during OOS window rejected cleanly with `51002`. | `rc = 51002` (BR4 OOS Space) | **$Q_{NR6} = 0$** |
| **4** | **T5/T7: AppLock Timeout & Retry** (`b05` vs `c05`) | **UNCONTROLLED BLOCKING:** Session B blocks for 18+ seconds waiting for Session A's transaction release without timeout contracts. | **PASS (Contracted Timeout):** Session B times out after 5s returning retryable code `51005`; retry succeeds (`rc=0`) after release. | `rc = 51005` (Lock Timeout) | **$Q_{BR1} = 0$** |
| **5** | **K5: OOS Ticket vs Submit** (`b09` vs `c09`) | **TRIGGER BYPASSED ($Q_{NR6}=1$):** Booking confirmed at $t=1\text{s}$, then OOS ticket created at $t=3\text{s}$; both commit ($Q_{NR6}=1$). | **PASS (Serialized):** OOS ticket creation serialized with instant booking; confirmed bookings protected. | `rc = 51002` / `rc = 0` | **$Q_{NR6} = 0$** |
| **6** | **Staff Race: Staff vs Staff** (`b10` vs `c10`) | **TRIGGER BYPASSED ($Q_{BR1}=1$):** Two staff members concurrently approving overlapping pending bookings both commit ($Q_{BR1}=1$). | **PASS (Serialized):** First approval succeeds (`rc=0`), second approval rejected cleanly with `51003`. | `rc = 51003` (Overlap Conflict) | **$Q_{BR1} = 0$** |
| **7** | **Soft-gate Fallback** (`c11`) | *Task 12 Feature* | **PASS:** Disallowed purpose (`lecture` on `meeting_room`) falls back to `pending` status (`instant_accepted=0`). | `rc = 0`, `instant = 0` | **$Q_{BR1} = 0$** |
| **8** | **Fallback vs Instant Overlap** (`c12`) | *Task 12 Feature* | **PASS:** Pending fallback booking does not block new instant bookings; subsequent approval of fallback rejected. | `rc = 51003` on approval | **$Q_{BR1} = 0$** |
| **9** | **Advisory Ack Repair** (`c13`) | *Task 12 Feature* | **PASS:** Staff approval under advisory maintenance automatically writes `booking_advisory_acknowledgement`. | `rc = 0` | **$Q_{BR1} = 0$** |

---

## 4. Live Execution Logs by Scenario (`SUMMARY.log`)

### **Demo 4.1: Baseline Instant vs Instant (`b01`) — Trigger Bypassed ($Q_{BR1}=1$)**
- **Session A:**
  ```text
  b01-A: holding confirmed booking 5245 uncommitted at W1.
  b01-A: committed booking 5245.
  PASS b01-A: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=1).
  b01-A: cleanup done.
  ```
- **Session B:**
  ```text
  b01-B: committed overlapping confirmed booking 5246.
  PASS b01-B: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=1).
  b01-B: cleanup left to session A.
  ```

---

### **Demo 4.2: Baseline Instant Submit vs Staff Approval (`b02`) — Trigger Bypassed ($Q_{BR1}=1$)**
- **Session A:**
  ```text
  b02-A: fiat approval of PB2a held in transaction...
  b02-A: PB2a approval committed.
  PASS b02-A: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=1).
  b02-A: fixture restored.
  ```
- **Session B:**
  ```text
  b02-B: inserted approved booking 5253 overlapping PB2a.
  PASS b02-B: VIOLATION-OBSERVED (Q_BR1=1).
  b02-B: cleanup done.
  ```

---

### **Demo 4.3: Baseline Escalation vs In-flight Submit (`b03`) — Trigger Bypassed ($Q_{NR6}=1$)**
- **Session A:**
  ```text
  b03-A: M3 escalated (out-of-service) after B committed its booking.
  b03-A: no persist overlap recorded this round.
  b03-A: M3 restored to advisory.
  ```
- **Session B:**
  ```text
  b03-B: confirmed booking 5260 committed while M3 was still advisory.
  b03-B: M3 escalated while booking confirmed — Q audit next.
  PASS b03-B: Q_VIOLATION = 1 (1).
  b03-B: cleanup done.
  ```

---

### **Demo 4.4: Baseline AppLock Timeout & Uncontrolled Blocking (`b05`)**
- **Session A:**
  ```text
  b05-A: holding row lock on M3 (no app lock, no timeout contract).
  b05-A: released after 18 s.
  ```
- **Session B:**
  ```text
  PASS b05-B: uncontrolled blocking observed (B waited 18 s for A; no business code, no retry contract).
  b05-B: done.
  ```

---

### **Demo 4.5: Baseline OOS Ticket Creation vs Submit (`b09`) — Trigger Bypassed ($Q_{NR6}=1$)**
- **Session A:**
  ```text
  b09-A: OOS ticket 4391 committed.
  PASS b09-A: VIOLATION-OBSERVED (confirmed booking overlapping OOS ticket, Q=1).
  b09-A: ticket removed.
  ```
- **Session B:**
  ```text
  b09-B: confirmed booking 5273 committed.
  b09-B: 0 violations at time of read.
  b09-B: cleanup done.
  ```

---

### **Demo 4.6: Baseline Staff vs Staff Approval Race (`b10`) — Trigger Bypassed ($Q_{BR1}=1$)**
- **Session A:**
  ```text
  b10-A: approval of PB10a held uncommitted...
  b10-A: after B, PB10a is approved.
  PASS b10-A: VIOLATION-OBSERVED (staff-vs-staff overlapping approvals, Q_BR1=1).
  b10-A: fixture restored.
  ```
- **Session B:**
  ```text
  b10-B: PB10b approved (its re-check saw PB10a still pending).
  PASS b10-B: VIOLATION-OBSERVED (Q_BR1=1).
  b10-B: cleanup left to A (fixture restore).
  ```

---

### **Demo 4.7: Controlled Instant vs Instant Submit (`c01`)**
- **Session A (Loser Side):**
  ```text
  PASS c01-A: conflict 51003 (loser side) as designed.
  PASS c01-A: exactly one booking confirmed on the window (race serialized).
  PASS c01-A: audit Q_BR1 = 0 (no overlapping confirmed bookings).
  c01-A: cleanup done.
  ```
- **Session B (Winner Side):**
  ```text
  PASS c01-B: instant approved (winner side).
  PASS c01-B: exactly one booking confirmed on the window (race serialized).
  PASS c01-B: audit Q_BR1 = 0.
  c01-B: cleanup done.
  ```

---

### **Demo 4.8: Controlled Instant Submit vs Staff Approval (`c02`)**
- **Session A (Staff Approver):**
  ```text
  PASS c02-A: approve(PB2a) rc=0 (order-1 approve wins).
  PASS c02-A: approve(PB2b) rc=51003 (conflict with confirmed instant).
  c02-A: fixture restored.
  ```
- **Session B (Instant Submitter):**
  ```text
  PASS c02-B: W2A instant submit rc=51003 (approved booking exists).
  PASS c02-B: W2B instant submit rc=0, instant=1 (order-2 submit wins).
  ```

---

### **Demo 4.9: Controlled Maintenance Escalation vs Submit (`c03` / `c03b`)**
- **Session A (Maintenance Escalation):**
  ```text
  PASS c03-A: escalation rc=0 (M3 -> out-of-service).
  c03: M3 restored to advisory (fixture next in c03-B).
  ```
- **Session B (Submission under OOS Window):**
  ```text
  PASS c03-B: instant submit rc=51002 (BR4: OOS overlap).
  PASS c03-B: PB3 still pending (escalation performs no booking DML, DD1).
  PASS c03-B: approve(PB3) rc=51002 (BR4 on the W2 path).
  c03-B: done.
  ```

---

### **Demo 4.10: Controlled AppLock Timeout & Retry (`c05`)**
- **Session A (Lock Holder):**
  ```text
  c05-A: holding app lock on space_booking:... for 10 s.
  c05-A: lock released.
  ```
- **Session B (5s Timeout & Successful Retry):**
  ```text
  PASS c05-B: first report rc=51005 (app lock timeout, retryable).
  PASS c05-B: retry rc=0, ticket 4404 created (T7).
  c05-B: cleanup done.
  ```

---

### **Demo 4.11: Controlled Ticket Creation vs Submit (`c09`)**
- **Session A (Ticket Creator):**
  ```text
  PASS c09-A: order-1 ticket rc=0 (maintenance_id=4407).
  c09-A: order-1 ticket deleted (fixture for order-2 clean).
  PASS c09-A: order-2 ticket rc=0 (ticket creation does no booking DML).
  c09-A: cleanup done.
  ```
- **Session B (Submitter):**
  ```text
  PASS c09-B: order-1 submit rc=51002 (BR4 against ticket).
  PASS c09-B: order-2 submit rc=0/instant=1 (submit-wins branch).
  PASS c09-B: booking still approved (ticket creation did no DML).
  PASS c09-B: zero ack rows on the submit-wins booking.
  c09-B: cleanup done.
  ```

---

### **Demo 4.12: Controlled Staff vs Staff Approval (`c10`)**
- **Session A (Staff A Approver):**
  ```text
  PASS c10-A: approve(PB10a) rc=0 (first wins).
  c10-A: fixture restored.
  ```
- **Session B (Staff B Approver):**
  ```text
  PASS c10-B: approve(PB10b) rc=51003 (overlap with the first approval).
  c10-B: done (fixture restored in A).
  ```

---

### **Demo 4.13: Controlled Soft-gate Fallback (`c11`)**
```text
PASS c11: rc=0, @instant_accepted=0 (soft gate -> fallback).
PASS c11: booking stays pending with NO auto-approval row.
c11: cleanup done.
```

---

### **Demo 4.14: Controlled Fallback vs Instant Overlap (`c12`)**
```text
PASS c12-1: fallback rc=0, instant=0 (pending).
PASS c12-2: instant rc=0, instant=1 (pending does not block).
PASS c12-3: approve(fallback) rc=51003 (BR1).
c12: cleanup done.
```

---

### **Demo 4.15: Controlled Advisory Ack Repair (`c13`)**
```text
PASS c13: approve rc=0 (W2 repaired the missing acks, no 51004).
PASS c13: ack row(s) exist for (PB13, M9), acknowledged_by = requester (1 row(s)).
c13: cleanup done.
```

---

### **Demo 4.16: Suite Invariant Audit (`audit_invariant.sql`)**
```text
PASS suite-audit: zero overlapping confirmed pairs AND zero confirmed-vs-OOS overlaps on TEST-13 spaces.
```
