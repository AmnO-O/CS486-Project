# Task 13 — Concurrency Test Suite Summary Report

**System:** CS486 — Campus Space Management System  
**Group:** G05  
**Test Environment:** Microsoft SQL Server 2022 (Developer Edition) in Docker Container (`cs486_sql_server`)  
**Target Database:** `CampusSpaceDB`  
**Database Isolation Mode:** `READ_COMMITTED_SNAPSHOT ON` (RCSI)  
**Output Location:** `outputs/13-concurrency-tests-G05/`  

---

## 1. Test Objectives & Scope

The core objective of **Task 13** is to build a comprehensive **Comparison Suite** evaluating the effectiveness, correctness, and reliability of the **4 concurrency control Stored Procedures implemented in Task 12** against raw T-SQL Data Manipulation Language (RAW DML) operations.

### **Comparison Target Groups:**
1. **Baseline (Uncontrolled - RAW DML):** Simulates direct user or application interaction executing T-SQL statements (`INSERT INTO dbo.bookings`, `UPDATE dbo.maintenance`, `INSERT INTO dbo.booking_approvals`) **without application-level locks (`sys.sp_getapplock`)**.
2. **Controlled (Task 12 Stored Procedures):** All user interactions route exclusively through Task 12 entry points:
   - `dbo.usp_booking_instant_submit` (Instant booking submission)
   - `dbo.usp_booking_approve` (Staff booking approval/rejection)
   - `dbo.usp_maintenance_report` (Space maintenance ticket creation)
   - `dbo.usp_maintenance_set_impact_level` (Maintenance impact escalation/downgrade)
   - *Core Mechanism:* All 4 procedures share an **Exclusive SQL Server Application Lock resource per space (`sys.sp_getapplock` on `space_booking:<space_id>`)**.

---

## 2. Controlled T-SQL Implementation Details

The following section outlines the stored procedure invocations and test logic executed across the **Controlled** test scenarios:

### **Case 1: Controlled Instant vs Instant Submit (`c01`)**
- **Session A (Winner Side):**
  ```sql
  DECLARE @b_a INT, @acc_a BIT, @rc_a INT, @msg_a NVARCHAR(500);
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s1, @requester_id = @rq, @requested_start_time = @w1,
      @requested_end_time = DATEADD(hour, 2, @w1), @purpose = 'meeting',
      @expected_participants = 10, @booking_id = @b_a OUTPUT,
      @instant_accepted = @acc_a OUTPUT, @result_code = @rc_a OUTPUT, @message = @msg_a OUTPUT;
  -- Result: @rc_a = 0, @instant_accepted = 1
  ```
- **Session B (Loser Side - Concurrent Overlapping Submit):**
  ```sql
  DECLARE @b_b INT, @acc_b BIT, @rc_b INT, @msg_b NVARCHAR(500);
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s1, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w1),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w1)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b_b OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Result: @rc_b = 51003 (Overlap Conflict), cleanly rejected
  ```

---

### **Case 2: Controlled Instant Submit vs Staff Approval (`c02`)**
- **Session A (Staff Approver):**
  ```sql
  DECLARE @rc INT, @msg NVARCHAR(500);
  EXEC dbo.usp_booking_approve
      @booking_id = @pb2a, @approver_id = @st, @decision = 'approved',
      @decision_note = N'c02 approve PB2a', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Result: @rc = 0 (PB2a approval successful)
  ```
- **Session B (Concurrent Instant Submit over PB2a Window):**
  ```sql
  DECLARE @b_b INT, @acc_b BIT, @rc_b INT, @msg_b NVARCHAR(500);
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s2, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w2a),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w2a)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b_b OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Result: @rc_b = 51003 (BR1 Overlap Conflict)
  ```

---

### **Case 3: Controlled Escalation vs In-flight Submit (`c03` / `c03b`)**
- **Session A (Maintenance Escalation):**
  ```sql
  DECLARE @rc INT, @msg NVARCHAR(500);
  EXEC dbo.usp_maintenance_set_impact_level
      @maintenance_id = @m3, @new_impact_level = 'out-of-service',
      @actor_id = @st, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Result: @rc = 0 (M3 escalated to out-of-service)
  ```
- **Session B (Instant Submit & Approval under OOS Window):**
  ```sql
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s3, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w3),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w3)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b_b OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Result: @rc_b = 51002 (BR4: Rejected due to OOS space)
  ```

---

### **Case 4: Controlled AppLock Timeout & Retry (`c05`)**
- **Session A (Holds AppLock inside Transaction for 8s):**
  ```sql
  BEGIN TRANSACTION;
      EXEC dbo.usp_maintenance_report
          @space_id = @s4, @reporter_id = @st,
          @problem_description = N'c05 lock holder ticket',
          @impact_level = 'advisory', @status = 'open',
          @maintenance_id = @tk_a OUTPUT, @result_code = @rc_a OUTPUT, @message = @msg_a OUTPUT;
      WAITFOR DELAY '00:00:08';
  COMMIT TRANSACTION;
  ```
- **Session B (5s Timeout & Subsequent Retry):**
  ```sql
  EXEC dbo.usp_maintenance_report
      @space_id = @s4, @reporter_id = @st,
      @problem_description = N'c05 contender ticket',
      @impact_level = 'advisory', @status = 'open',
      @maintenance_id = @tk_b OUTPUT, @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Result 1: @rc_b = 51005 (AppLock Timeout)

  WAITFOR DELAY '00:00:04';
  EXEC dbo.usp_maintenance_report
      @space_id = @s4, @reporter_id = @st,
      @problem_description = N'c05 contender ticket retry',
      @impact_level = 'advisory', @status = 'open',
      @maintenance_id = @tk_b OUTPUT, @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Result 2: @rc_b = 0 (Ticket created successfully)
  ```

---

### **Case 5: Controlled Ticket vs Submit (`c09`)**
- **Session A (Create OOS Maintenance Ticket):**
  ```sql
  EXEC dbo.usp_maintenance_report
      @space_id = @s5, @reporter_id = @st,
      @problem_description = N'c09 OOS ticket',
      @impact_level = 'out-of-service', @status = 'open',
      @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Result: @rc = 0 (OOS ticket created successfully)
  ```
- **Session B (Submit Instant Booking over Ticket Window):**
  ```sql
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s5, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w5),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w5)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b5 OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Result: @rc_b = 51002 (BR4: Rejected due to OOS space)
  ```

---

### **Case 6: Controlled Staff vs Staff Approval (`c10`)**
- **Session A (Staff A Approves PB10a First):**
  ```sql
  EXEC dbo.usp_booking_approve
      @booking_id = @pb10a, @approver_id = @st, @decision = 'approved',
      @decision_note = N'c10 first approval',
      @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Result: @rc = 0 (PB10a approval successful)
  ```
- **Session B (Staff B Attempts Overlapping Approval on PB10b):**
  ```sql
  EXEC dbo.usp_booking_approve
      @booking_id = @pb10b, @approver_id = @st, @decision = 'approved',
      @decision_note = N'c10 second approval',
      @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Result: @rc = 51003 (Overlap Conflict - PB10b approval rejected)
  ```

---

### **Case 7: Soft-gate Fallback (`c11`)**
```sql
EXEC dbo.usp_booking_instant_submit
    @space_id = @s6, @requester_id = @rq,
    @requested_start_time = @w6, @requested_end_time = DATEADD(hour, 2, @w6),
    @purpose = 'lecture', -- Disallowed purpose for meeting_room
    @expected_participants = 10, @booking_id = @b6 OUTPUT,
    @instant_accepted = @acc OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
-- Result: @rc = 0, @instant_accepted = 0 (Falls back to 'pending' status for manual staff review)
```

---

### **Case 8: Fallback vs Instant Overlap (`c12`)**
```sql
EXEC dbo.usp_booking_instant_submit ... @purpose = 'lecture', ... @booking_id = @b_pending OUTPUT;
EXEC dbo.usp_booking_instant_submit ... @purpose = 'meeting', ... @result_code = @rc_instant OUTPUT; -- @rc = 0, @instant = 1
EXEC dbo.usp_booking_approve ... @booking_id = @b_pending, ... @result_code = @rc_app OUTPUT; -- @rc = 51003 (Approval rejected)
```

---

### **Case 9: Advisory Ack Repair (`c13`)**
```sql
EXEC dbo.usp_booking_approve
    @booking_id = @pb13, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c13 ack repair approval',
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
-- Result: @rc = 0, automatically inserts missing row into dbo.booking_advisory_acknowledgement
```

---

## 3. Test Evaluation Criteria

### **1. Baseline Evaluation Criteria (RAW DML Flaw Demonstration):**
- **PASS Baseline:** A Baseline scenario passes verification when it **empirically demonstrates the systemic flaws of raw DML under concurrency**:
  - Exposing data integrity corruption ($Q_{BR1} \ge 1$ or $Q_{NR6} \ge 1$: two overlapping bookings committed to disk due to RCSI trigger bypass).
  - Or raising unhandled database engine exceptions (`Msg 50000` / `Msg 3609`) that crash client applications, or causing indefinite connection blocking.

### **2. Controlled Evaluation Criteria (Task 12 Stored Procedures):**
- **PASS Controlled:** A Controlled scenario passes verification when it satisfies three mandatory guarantees:
  1. **Data Invariant Preservation:** `audit_invariant.sql` confirms zero overlapping confirmed bookings ($Q_{BR1} = 0$) and zero out-of-service maintenance conflicts ($Q_{NR6} = 0$).
  2. **Smooth Application Serialization:** The winning session receives `rc = 0`; the losing session receives a structured business code (`51003` BR1 Overlap, `51002` BR4 OOS Space, `51005` Lock Timeout).
  3. **Zero Unhandled Engine Crashes:** 0% unhandled engine exceptions (`Msg 50000`) raised at the database level.

---

## 4. Key Findings & Insights

### **1. Critical Flaws of Baseline (RAW DML):**
- **Data Corruption (Trigger Bypass):** Under RCSI mode, raw `INSERT` statements execute without taking Shared Locks. Two concurrent sessions bypass Phase 1 triggers, committing overlapping approved bookings to disk ($Q_{BR1} = 1$).
- **Unhandled Application Crashes (Engine Exceptions):** If one transaction commits milliseconds earlier, the trailing transaction hits Phase 1 triggers and raises raw `Msg 50000` exceptions, causing **unhandled 500 errors in client applications**.

### **2. Architectural Superiority of Controlled (Task 12 Procedures):**
- **Effective Serialization & Crash Prevention:** Exclusive application locks (`sys.sp_getapplock` on `space_booking:<space_id>`, 5s timeout) serialize concurrent transactions at the application level before modifying table data.
- **Absolute Invariant Preservation:** Achieved $Q_{BR1} = 0$ and $Q_{NR6} = 0$ across 100% of controlled scenarios.

---

## 5. Reproduction Guide

To reproduce 100% of the test results locally, detailed execution commands for all 29 test cases are available at:

👉 **[REPRODUCE.md](file:///Users/caoquanghung/HCMUS/CS/DataBase/FinalProject/CS486-Project/outputs/13-concurrency-tests-G05/REPRODUCE.md)**

Execution logs for all scenario runs are archived at:

👉 **[DEMO_RESULTS.md](file:///Users/caoquanghung/HCMUS/CS/DataBase/FinalProject/CS486-Project/outputs/13-concurrency-tests-G05/DEMO_RESULTS.md)**  
👉 **[SUMMARY.log](file:///Users/caoquanghung/HCMUS/CS/DataBase/FinalProject/CS486-Project/outputs/13-concurrency-tests-G05/results/SUMMARY.log)**
