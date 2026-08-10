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
  Direct T-SQL DML statements (`INSERT`, `UPDATE`) executed concurrently across two database sessions without Task 12 application-level locks. Under RCSI mode, `SELECT` queries inside Phase 1 triggers read committed row versions from `tempdb` without acquiring Shared Locks (S-Locks), avoiding lock-blocking. When two transactions execute concurrently before either commits, Phase 1 triggers are **bypassed**, committing overlapping rows to disk ($Q_{BR1} = 1$) or throwing unhandled engine exceptions (`Msg 50000`). This demonstrates the fundamental flaws of raw DML: **data integrity corruption** or **unhandled application crashes (500 errors)**.
- **Controlled (Task 12 Stored Procedures):**  
  All write operations route exclusively through Task 12 Stored Procedures (`usp_booking_instant_submit`, `usp_booking_approve`, `usp_maintenance_report`, `usp_maintenance_set_impact_level`). These procedures acquire transaction-owned application locks (`sys.sp_getapplock` on `space_booking:<space_id>`, Exclusive, 5-second timeout). This guarantees strict application-level serialization: winner gets `rc = 0`, loser receives deterministic business result codes (`51003` overlap, `51002` OOS space, `51005` lock timeout), achieving **100% data invariant preservation ($Q_{BR1} = 0$, $Q_{NR6} = 0$) without unhandled engine exceptions**.

---

## 2. Evaluation Criteria & Verification Logic

- **Baseline PASS Criterion (Flaw Demonstration):**  
  A Baseline scenario successfully passes verification when it empirically demonstrates the vulnerabilities of raw DML under concurrency—either by committing overlapping confirmed rows to disk ($Q_{BR1} \ge 1$ or $Q_{NR6} \ge 1$) due to trigger bypass, or by raising an unhandled database engine exception (`Msg 50000` / `Msg 3609`) that crashes client transactions.
- **Controlled PASS Criterion (Control Verification):**  
  A Controlled scenario successfully passes verification when it satisfies three mandatory guarantees:
  1. **Data Invariant Preservation:** Zero overlapping confirmed bookings ($Q_{BR1} = 0$) and zero out-of-service maintenance conflicts ($Q_{NR6} = 0$).
  2. **Application Serialization:** Winner receives `rc = 0`; loser receives explicit structured business codes (`51003`, `51002`, `51005`).
  3. **Zero Unhandled Crashes:** 0% unhandled engine exceptions (`Msg 50000`), allowing client applications to handle responses gracefully.

---

## 3. Comprehensive Demo Results Matrix

| # | Conflict Scenario | Baseline Behavior (RAW DML Flaw) | Controlled Behavior (Task 12 Serialization) | Controlled Result Code | Invariant Audit ($Q_{BR1}$) |
|:---:|:---|:---|:---|:---:|:---:|
| **1** | **K1: Instant vs Instant Submit** (`b01` vs `c01`) | **TRIGGER BYPASSED ($Q_{BR1}=1$):** Both sessions insert concurrently without blocking; 2 overlapping confirmed bookings committed to disk. | **PASS (Serialized):** Winner receives `rc=0`, concurrent submit rejected cleanly with business code `51003`. | `rc = 51003` (Overlap Conflict) | **$Q_{BR1} = 0$** |
| **2** | **K2: Instant Submit vs Staff Approval** (`b02` vs `c02`) | **TRIGGER BYPASSED & OVERLAP ($Q_{BR1}=1$):** Session B inserts approved booking overlapping pending approval without blocking ($Q_{BR1}=1$). | **PASS (Serialized):** Operations strictly serialized; overlapping submit during pending approval rejected cleanly. | `rc = 51003` (BR1 Overlap) | **$Q_{BR1} = 0$** |
| **3** | **K3: Escalation vs In-flight Submit** (`b03` vs `c03` / `c03b`) | **UNHANDLED ENGINE EXCEPTION:** Maintenance escalation causes Session B to fail with raw engine exception `Msg 50000`. | **PASS (BR4 Protection):** AppLock serializes operations; booking during OOS window rejected cleanly with `51002`. | `rc = 51002` (BR4 OOS Space) | **$Q_{NR6} = 0$** |
| **4** | **T5/T7: AppLock Timeout & Retry** (`b05` vs `c05`) | **UNCONTROLLED BLOCKING:** Session B blocks for 18+ seconds waiting for Session A's transaction release without timeout contracts. | **PASS (Contracted Timeout):** Session B times out after 5s returning retryable code `51005`; retry succeeds (`rc=0`) after release. | `rc = 51005` (Lock Timeout) | **$Q_{BR1} = 0$** |
| **5** | **K5: OOS Ticket vs Submit** (`b09` vs `c09`) | **RAW TICKET CONFLICT:** Raw maintenance ticket creation causes trigger `Msg 50000` engine aborts against concurrent submissions. | **PASS (Serialized):** OOS ticket creation serialized with instant booking; confirmed bookings protected. | `rc = 51002` / `rc = 0` | **$Q_{NR6} = 0$** |
| **6** | **Staff Race: Staff vs Staff** (`b10` vs `c10`) | **TRIGGER BYPASSED ($Q_{BR1}=1$):** Two staff members concurrently approving overlapping pending bookings both commit ($Q_{BR1}=1$). | **PASS (Serialized):** First approval succeeds (`rc=0`), second approval rejected cleanly with `51003`. | `rc = 51003` (Overlap Conflict) | **$Q_{BR1} = 0$** |
| **7** | **Soft-gate Fallback** (`c11`) | *Task 12 Feature* | **PASS:** Disallowed purpose (`lecture` on `meeting_room`) falls back to `pending` status (`instant_accepted=0`). | `rc = 0`, `instant = 0` | **$Q_{BR1} = 0$** |
| **8** | **Fallback vs Instant Overlap** (`c12`) | *Task 12 Feature* | **PASS:** Pending fallback booking does not block new instant bookings; subsequent approval of fallback rejected. | `rc = 51003` on approval | **$Q_{BR1} = 0$** |
| **9** | **Advisory Ack Repair** (`c13`) | *Task 12 Feature* | **PASS:** Staff approval under advisory maintenance automatically writes `booking_advisory_acknowledgement`. | `rc = 0` | **$Q_{BR1} = 0$** |

---

## 4. Live Execution Logs by Scenario (`SUMMARY.log`)

### **Demo 4.1: Baseline Instant vs Instant (`b01`) — Trigger Bypassed ($Q_{BR1}=1$)**
- **Session A:**
  ```text
  b01-A: holding confirmed booking 3745 uncommitted at W1.
  b01-A: committed booking 3745.
  PASS b01-A: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=1).
  b01-A: cleanup done.
  ```
- **Session B:**
  ```text
  b01-B: committed overlapping confirmed booking 3746.
  PASS b01-B: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=1).
  b01-B: cleanup left to session A.
  ```

---

### **Demo 4.2: Controlled Instant vs Instant Submit (`c01`)**
- **Session A (Winner Side):**
  ```text
  PASS c01-A: instant approved (winner side).
  PASS c01-A: exactly one booking confirmed on the window (race serialized).
  PASS c01-A: audit Q_BR1 = 0 (no overlapping confirmed bookings).
  c01-A: cleanup done.
  ```
- **Session B (Loser Side):**
  ```text
  PASS c01-B: conflict 51003 (loser side) as designed.
  c01-B: cleanup done.
  ```

---

### **Demo 4.3: Controlled Instant Submit vs Staff Approval (`c02`)**
- **Session A (Staff Approver):**
  ```text
  PASS c02-A: approve(PB2a) rc=0 (order-1 approve wins).
  PASS c02-A: approve(PB2b) rc=51003 (conflict with confirmed instant).
  c02-A: fixture restored.
  ```
- **Session B (Instant Submitter):**
  ```text
  PASS c02-B: W2A instant submit rc=51003 (approved booking exists).
  PASS c02-B: W2B instant submit rc=0, instant=1 (order-2 instant wins).
  c02-B: cleanup done.
  ```

---

### **Demo 4.4: Controlled Maintenance Escalation vs Submit (`c03`)**
- **Session A (Maintenance Escalation):**
  ```text
  PASS c03-A: escalation rc=0 (M3 -> out-of-service).
  c03: M3 restored to advisory.
  ```
- **Session B (Submission & Approval under OOS Window):**
  ```text
  PASS c03-B: instant submit rc=51002 (BR4: OOS overlap).
  PASS c03-B: PB3 still pending (escalation performs no booking DML, DD1).
  PASS c03-B: approve(PB3) rc=51002 (BR4 on the W2 path).
  c03-B: done.
  ```

---

### **Demo 4.5: Controlled AppLock Timeout & Retry (`c05`)**
- **Session A (Lock Holder):**
  ```text
  PASS c05-A: report_maintenance held in transaction.
  c05-A: transaction committed after B timeout window.
  ```
- **Session B (5s Timeout & Successful Retry):**
  ```text
  PASS c05-B: report_maintenance timed out (rc=51005) as contracted.
  PASS c05-B: retry after A release succeeded (rc=0).
  c05-B: cleanup done.
  ```

---

### **Demo 4.6: Suite Invariant Audit (`audit_invariant.sql`)**
```text
PASS suite-audit: zero overlapping confirmed pairs AND zero confirmed-vs-OOS overlaps on TEST-13 spaces.
```
