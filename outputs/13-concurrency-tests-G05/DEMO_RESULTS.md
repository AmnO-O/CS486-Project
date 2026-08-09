# Task 13 — Concurrency Test Demo Results

**System:** CS486 — Campus Space Management System  
**Group:** G05  
**Test Environment:** Microsoft SQL Server 2022 (Developer Edition) in Docker Container (`cs486_sql_server`)  
**Target Database:** `CampusSpaceDB`  
**Test Suite Directory:** `outputs/13-concurrency-tests-G05/`  

---

## 1. Executive Summary & Test Suite Architecture

The Task 13 test suite is designed as a **Comparison Suite** comparing two concurrency control strategies:
- **Baseline (Uncontrolled):** Raw T-SQL DML executed concurrently across 2 database sessions without Task 12 application-level locks. This demonstrates actual **Race Conditions**, raw engine/trigger exceptions (`Msg 50000` from `trg_bookings_prevent_overlap`), or severe data invariant violations ($Q_{BR1} \ge 1$).
- **Controlled (Task 12 Procedures):** Execution through Task 12 Stored Procedures (`usp_booking_instant_submit`, `usp_booking_approve`, `usp_maintenance_report`, `usp_maintenance_set_impact_level`) utilizing per-space transaction-owned application locks (`sys.sp_getapplock` on `space_booking:<space_id>`, Exclusive, 5-second timeout). This guarantees strict serialization, deterministic business result codes (`0`, `51001`–`51009`), zero unhandled engine exceptions, and zero invariant violations ($Q_{BR1} = 0$, $Q_{NR6} = 0$).

---

## 2. Summary Matrix of Demo Scenarios

| # | Test Scenario | Baseline Behavior (Uncontrolled DML) | Controlled Behavior (Task 12 Procedures) | Result Code (Controlled) | Invariant Audit ($Q_{BR1}$) |
|:---:|:---|:---|:---|:---:|:---:|
| **1** | **K1: Instant vs Instant Submit** (`b01` vs `c01`) | **Conflict:** Session B blocks on Read Committed isolation, then fails with raw Trigger `Msg 50000` exception. | **PASS:** 1 session succeeds (`rc=0`), concurrent session serialized and rejected with business code `51003`. | `rc = 51003` (Overlap Conflict) | **$Q_{BR1} = 0$** |
| **2** | **K2: Instant Submit vs Staff Approval** (`b02` vs `c02`) | **Violation:** Both sessions commit overlapping bookings concurrently ($Q_{BR1} \ge 1$). | **PASS:** Operations strictly serialized; overlapping submit rejected cleanly. | `rc = 51003` (BR1 Overlap) | **$Q_{BR1} = 0$** |
| **3** | **K3: Escalation vs In-flight Submit** (`b03` vs `c03` / `c03b`) | **Conflict:** Maintenance escalation without locking permits overlapping booking creation during Out-of-Service transition. | **PASS:** AppLock prevents new booking submissions during Out-of-Service windows. | `rc = 51002` (BR4 OOS Space) | **$Q_{NR6} = 0$** |
| **4** | **T5/T7: AppLock Timeout & Retry** (`b05` vs `c05`) | **Conflict:** Session B blocks indefinitely waiting for Session A's transaction release. | **PASS:** Session B times out after 5 seconds returning retryable code `51005`; retry succeeds after release. | `rc = 51005` (Lock Timeout) | **$Q_{BR1} = 0$** |
| **5** | **K5: OOS Ticket vs Submit** (`b09` vs `c09`) | **Conflict:** Uncontrolled maintenance ticket creation conflicts with instant booking submissions. | **PASS:** Ticket creation serialized with instant booking; existing confirmed bookings remain intact. | `rc = 51002` / `rc = 0` | **$Q_{NR6} = 0$** |
| **6** | **Staff vs Staff Same-Conflict** (`b10` vs `c10`) | **Conflict:** Two staff members concurrently approve overlapping pending bookings. | **PASS:** First approval succeeds (`rc=0`), second approval rejected with `51003`. | `rc = 51003` (Overlap Conflict) | **$Q_{BR1} = 0$** |
| **7** | **Soft-gate Fallback** (`c11`) | *N/A (Task 12 feature)* | **PASS:** Disallowed purpose (`lecture` on `meeting_room`) falls back to `pending` status without auto-approval. | `rc = 0`, `instant_accepted = 0` | **$Q_{BR1} = 0$** |
| **8** | **Fallback vs Instant Overlap** (`c12`) | *N/A (Task 12 feature)* | **PASS:** Fallback (`pending`) booking does not block new instant bookings; subsequent approval of fallback rejected. | `rc = 51003` on approval | **$Q_{BR1} = 0$** |
| **9** | **Advisory Ack Repair** (`c13`) | *N/A (Task 12 feature)* | **PASS:** Staff approval of booking under advisory maintenance automatically writes `booking_advisory_acknowledgement`. | `rc = 0` | **$Q_{BR1} = 0$** |

---

## 3. Live Execution Logs by Controlled Scenario

### **Demo 3.1: Controlled Instant Submit vs Instant Submit (`c01`)**
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

### **Demo 3.2: Controlled Instant Submit vs Staff Approval (`c02`)**
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

### **Demo 3.3: Controlled Escalation vs In-flight Submit (`c03`)**
- **Session A (Escalator):**
  ```text
  PASS c03-A: escalation rc=0 (M3 -> out-of-service).
  c03: M3 restored to advisory (fixture next in c03-B).
  ```
- **Session B (Submitter):**
  ```text
  PASS c03-B: instant submit rc=51002 (BR4: OOS overlap).
  PASS c03-B: PB3 still pending (escalation performs no booking DML, DD1).
  PASS c03-B: approve(PB3) rc=51002 (BR4 on the W2 path).
  c03-B: done.
  ```

### **Demo 3.4: Controlled AppLock Timeout & Retry (`c05`)**
- **Session A (Lock Holder):**
  ```text
  c05-A: holding app lock on space_booking:... for 20 s.
  c05-A: lock released.
  ```
- **Session B (Ticket Reporter):**
  ```text
  PASS c05-B: first report rc=51005 (app lock timeout, retryable).
  PASS c05-B: retry rc=0, ticket created (T7).
  c05-B: cleanup done.
  ```

### **Demo 3.5: Controlled OOS Ticket Creation vs Submit (`c09`)**
- **Session A (Reporter):**
  ```text
  PASS c09-A: order-1 ticket rc=0.
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

### **Demo 3.6: Controlled Staff vs Staff Approval Conflict (`c10`)**
- **Session A (Staff 1):**
  ```text
  PASS c10-A: approve(PB10a) rc=0 (first wins).
  c10-A: fixture restored.
  ```
- **Session B (Staff 2):**
  ```text
  PASS c10-B: approve(PB10b) rc=51003 (overlap with the first approval).
  c10-B: done.
  ```

### **Demo 3.7: Controlled Soft-gate Fallback (`c11`)**
- **Output:**
  ```text
  PASS c11: rc=0, @instant_accepted=0 (soft gate -> fallback).
  PASS c11: booking stays pending with NO auto-approval row.
  c11: cleanup done.
  ```

### **Demo 3.8: Controlled Fallback vs Instant Overlap (`c12`)**
- **Output:**
  ```text
  PASS c12-1: fallback rc=0, instant=0 (pending).
  PASS c12-2: instant rc=0, instant=1 (pending does not block).
  PASS c12-3: approve(fallback) rc=51003 (BR1).
  c12: cleanup done.
  ```

### **Demo 3.9: Controlled Advisory Ack Repair (`c13`)**
- **Output:**
  ```text
  PASS c13: approve rc=0 (W2 repaired the missing acks, no 51004).
  PASS c13: ack row(s) exist for (PB13, M9), acknowledged_by = requester (1 row(s)).
  c13: cleanup done.
  ```

---

## 4. Docker Reproduction Commands

### **Step 1: Reset Fixture Database (Run before each test scenario)**
```bash
docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -b -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i 99_cleanup.sql && docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -b -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i 00_setup.sql
```

### **Step 2: Run Baseline Scenario `b01` (Observe Raw Trigger 50000 Exception)**
- Terminal 1: `docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i baseline/b01_instant_instant_a.sql`
- Terminal 2: `docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i baseline/b01_instant_instant_b.sql`

### **Step 3: Run Controlled Scenarios (`c01` to `c13`)**
- Reset Fixture: (Execute Step 1 command)
- Terminal 1: `docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i controlled/c01_instant_a.sql`
- Terminal 2: `docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i controlled/c01_instant_b.sql`

### **Step 4: Run Suite-wide Invariant Audit**
```bash
docker exec -w /tmp/t13 cs486_sql_server /opt/mssql-tools18/bin/sqlcmd -C -I -S localhost -U sa -P 'StrongPassword123!' -d CampusSpaceDB -i audit_invariant.sql
```

---

## 5. Conclusion

The live test results on Docker demonstrate the key objectives of **Task 13**:
1. Confirms the vulnerabilities of uncontrolled raw DML in concurrent database environments.
2. Validates the robustness of Task 12 Stored Procedures in preventing race conditions, enforcing data invariants ($Q_{BR1} = 0$, $Q_{NR6} = 0$), and returning deterministic business result codes to the application layer.
