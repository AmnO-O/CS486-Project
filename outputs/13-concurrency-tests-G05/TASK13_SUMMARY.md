# Task 13 — Báo Cáo Tổng Hợp Bộ Kiểm Thử Đồng Thời (Concurrency Test Suite Summary)

**Hệ thống:** CS486 — Hệ thống Quản lý Không gian Cơ sở Vật chất (Campus Space Management System)  
**Nhóm thực hiện:** G05  
**Môi trường thử nghiệm:** Microsoft SQL Server 2022 (Developer Edition) trên Docker Container (`cs486_sql_server`)  
**Cơ sở dữ liệu:** `CampusSpaceDB`  
**Chế độ Cô lập Database:** `READ_COMMITTED_SNAPSHOT ON` (RCSI)  
**Thư mục lưu trữ:** `outputs/13-concurrency-tests-G05/`  

---

## 1. Muốn Test Cái Gì? (Test Objectives & Scope)

Mục tiêu cốt lõi của **Task 13** là xây dựng bộ kiểm thử đồng thời **Comparison Suite (So sánh đối ứng)** để đánh giá tính hiệu quả, tính đúng đắn và độ tin cậy của **4 Stored Procedure kiểm soát đồng thời ở Task 12** so với việc người dùng tự tương tác bằng các câu lệnh SQL thô (RAW DML).

### **Đối tượng So sánh:**
1. **Baseline (Chưa có Task 12 - RAW DML):** Giả lập người dùng/ứng dụng thực hiện trực tiếp các câu lệnh `INSERT INTO dbo.bookings`, `UPDATE dbo.maintenance`, `INSERT INTO dbo.booking_approvals` mà **không có cơ chế khóa ứng dụng (Application Lock)**.
2. **Controlled (Đã kiểm soát qua Task 12 Procedures):** Người dùng tương tác bắt buộc phải thông qua 4 Stored Procedure chuẩn hóa của Task 12:
   - `dbo.usp_booking_instant_submit` (Nộp đơn đặt phòng tức thì)
   - `dbo.usp_booking_approve` (Duyệt/từ chối đơn đặt phòng)
   - `dbo.usp_maintenance_report` (Tạo vé bảo trì không gian)
   - `dbo.usp_maintenance_set_impact_level` (Cập nhật mức độ ảnh hưởng/leo thang bảo trì)
   - *Cơ chế cốt lõi:* Cả 4 procedure cùng chia sẻ 1 cơ chế **Khóa Ứng Dụng Độc Quyền theo Không gian (`sys.sp_getapplock` trên tài nguyên `space_booking:<space_id>`)**.

---

## 2. Mã Nguồn SQL Chi Tiết Thực Thi Trong Các Case Controlled (Controlled SQL Implementation)

Dưới đây là chi tiết mã SQL lệnh gọi Stored Procedure và logic kiểm thử được sử dụng cho từng kịch bản **Controlled**:

### **Case 1: Controlled Instant vs Instant Submit (`c01`)**
- **Session A (Chiến thắng - Winner Side):**
  ```sql
  DECLARE @b_a INT, @acc_a BIT, @rc_a INT, @msg_a NVARCHAR(500);
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s1, @requester_id = @rq, @requested_start_time = @w1,
      @requested_end_time = DATEADD(hour, 2, @w1), @purpose = 'meeting',
      @expected_participants = 10, @booking_id = @b_a OUTPUT,
      @instant_accepted = @acc_a OUTPUT, @result_code = @rc_a OUTPUT, @message = @msg_a OUTPUT;
  -- Kết quả: @rc_a = 0, @instant_accepted = 1
  ```
- **Session B (Thua cuộc - Loser Side):**
  ```sql
  DECLARE @b_b INT, @acc_b BIT, @rc_b INT, @msg_b NVARCHAR(500);
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s1, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w1),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w1)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b_b OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Kết quả: @rc_b = 51003 (Overlap Conflict), đơn bị từ chối mượt mà
  ```

---

### **Case 2: Controlled Instant Submit vs Staff Approval (`c02`)**
- **Session A (Staff Duyệt Đơn):**
  ```sql
  DECLARE @rc INT, @msg NVARCHAR(500);
  EXEC dbo.usp_booking_approve
      @booking_id = @pb2a, @approver_id = @st, @decision = 'approved',
      @decision_note = N'c02 approve PB2a', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Kết quả: @rc = 0 (Thành công duyệt PB2a)
  ```
- **Session B (User Nộp Instant Đè Lên Khung Giờ PB2a):**
  ```sql
  DECLARE @b_b INT, @acc_b BIT, @rc_b INT, @msg_b NVARCHAR(500);
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s2, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w2a),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w2a)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b_b OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Kết quả: @rc_b = 51003 (BR1 Overlap - Bị từ chối do PB2a đã được duyệt)
  ```

---

### **Case 3: Controlled Escalation vs In-flight Submit (`c03` / `c03b`)**
- **Session A (Leo Thang Bảo Trì):**
  ```sql
  DECLARE @rc INT, @msg NVARCHAR(500);
  EXEC dbo.usp_maintenance_set_impact_level
      @maintenance_id = @m3, @new_impact_level = 'out-of-service',
      @actor_id = @st, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Kết quả: @rc = 0 (M3 leo thang lên out-of-service thành công)
  ```
- **Session B (Nộp Instant & Duyệt Đơn Trùng Giờ OOS):**
  ```sql
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s3, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w3),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w3)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b_b OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Kết quả: @rc_b = 51002 (BR4: Chặn do phòng OOS)
  ```

---

### **Case 4: Controlled AppLock Timeout & Retry (`c05`)**
- **Session A (Giữ Khóa Trong Giao Dịch 8 Giây):**
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
- **Session B (Trúng Timeout 5s, Sau Đó Retry Thành Công):**
  ```sql
  EXEC dbo.usp_maintenance_report
      @space_id = @s4, @reporter_id = @st,
      @problem_description = N'c05 contender ticket',
      @impact_level = 'advisory', @status = 'open',
      @maintenance_id = @tk_b OUTPUT, @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Kết quả 1: @rc_b = 51005 (AppLock Timeout)

  WAITFOR DELAY '00:00:04';
  EXEC dbo.usp_maintenance_report
      @space_id = @s4, @reporter_id = @st,
      @problem_description = N'c05 contender ticket retry',
      @impact_level = 'advisory', @status = 'open',
      @maintenance_id = @tk_b OUTPUT, @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Kết quả 2: @rc_b = 0 (Thành công tạo vé)
  ```

---

### **Case 5: Controlled Ticket vs Submit (`c09`)**
- **Session A (Tạo Vé Bảo Trì OOS Mới):**
  ```sql
  EXEC dbo.usp_maintenance_report
      @space_id = @s5, @reporter_id = @st,
      @problem_description = N'c09 OOS ticket',
      @impact_level = 'out-of-service', @status = 'open',
      @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Kết quả: @rc = 0 (Vé OOS được tạo thành công)
  ```
- **Session B (Nộp Đơn Instant Trùng Khung Vé OOS Mới):**
  ```sql
  EXEC dbo.usp_booking_instant_submit
      @space_id = @s5, @requester_id = @rq,
      @requested_start_time = DATEADD(minute, 30, @w5),
      @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w5)),
      @purpose = 'meeting', @expected_participants = 10,
      @booking_id = @b5 OUTPUT, @instant_accepted = @acc_b OUTPUT,
      @result_code = @rc_b OUTPUT, @message = @msg_b OUTPUT;
  -- Kết quả: @rc_b = 51002 (BR4: Chặn nộp đơn do vé OOS vừa được tạo)
  ```

---

### **Case 6: Controlled Staff vs Staff Approval (`c10`)**
- **Session A (Staff A Duyệt PB10a Trước):**
  ```sql
  EXEC dbo.usp_booking_approve
      @booking_id = @pb10a, @approver_id = @st, @decision = 'approved',
      @decision_note = N'c10 first approval',
      @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Kết quả: @rc = 0 (Duyệt thành công PB10a)
  ```
- **Session B (Staff B Duyệt PB10b Trùng Giờ Sau Đó):**
  ```sql
  EXEC dbo.usp_booking_approve
      @booking_id = @pb10b, @approver_id = @st, @decision = 'approved',
      @decision_note = N'c10 second approval',
      @result_code = @rc OUTPUT, @message = @msg OUTPUT;
  -- Kết quả: @rc = 51003 (Overlap Conflict - Từ chối duyệt PB10b do PB10a đã được duyệt)
  ```

---

### **Case 7: Soft-gate Fallback (`c11`)**
```sql
EXEC dbo.usp_booking_instant_submit
    @space_id = @s6, @requester_id = @rq,
    @requested_start_time = @w6, @requested_end_time = DATEADD(hour, 2, @w6),
    @purpose = 'lecture', -- Mục đích không hợp lệ cho meeting_room
    @expected_participants = 10, @booking_id = @b6 OUTPUT,
    @instant_accepted = @acc OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
-- Kết quả: @rc = 0, @instant_accepted = 0 (Đơn tự rơi về trạng thái 'pending' để Staff duyệt sau)
```

---

### **Case 8: Fallback vs Instant Overlap (`c12`)**
```sql
EXEC dbo.usp_booking_instant_submit ... @purpose = 'lecture', ... @booking_id = @b_pending OUTPUT;
EXEC dbo.usp_booking_instant_submit ... @purpose = 'meeting', ... @result_code = @rc_instant OUTPUT; -- @rc = 0, @instant = 1
EXEC dbo.usp_booking_approve ... @booking_id = @b_pending, ... @result_code = @rc_app OUTPUT; -- @rc = 51003 (Chặn duyệt)
```

---

### **Case 9: Advisory Ack Repair (`c13`)**
```sql
EXEC dbo.usp_booking_approve
    @booking_id = @pb13, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c13 ack repair approval',
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
-- Kết quả: @rc = 0, tự động ghi bổ sung dòng vào dbo.booking_advisory_acknowledgement
```

---

## 3. Cơ Chế Đánh Giá Test Là Thế Nào? (Evaluation Criteria)

### **1. Tiêu chí Đánh giá Baseline (Chưa kiểm soát - RAW DML Flaw Demonstration):**
- **ĐẠT (PASS Baseline):** Baseline được xác nhận **PASS khi bộc lộ thành công điểm yếu/hạn chế của DML thô dưới môi trường đồng thời**:
  - Bùng nổ thảm họa vi phạm toàn vẹn dữ liệu thực sự ($Q_{BR1} \ge 1$ hoặc $Q_{NR6} \ge 1$: 2 đơn trùng lịch cùng `approved` được ghi thành công xuống đĩa do Trigger bị bypass dưới RCSI).
  - Hoặc bùng nổ lỗi thô tầng Database Engine (`Msg 50000` / `Msg 3609` làm sập giao dịch client) hoặc treo đứng hình connection (Indefinite Blocking).

### **2. Tiêu chí Đánh giá Controlled (Task 12 Stored Procedures):**
- **ĐẠT (PASS Controlled):** Controlled được xác nhận **PASS khi đạt được 3 bảo đảm chuẩn hóa**:
  1. **Bảo toàn Dữ liệu Tuyệt đối:** Script `audit_invariant.sql` xác nhận $Q_{BR1} = 0$ (Không có cặp trùng lịch) và $Q_{NR6} = 0$ (Không có đặt phòng trùng giờ OOS).
  2. **Tuần tự hóa Giao dịch Mượt mà:** Đúng 1 Session đến trước chiến thắng (`rc = 0`), Session đến sau nhận mã nghiệp vụ chuẩn (`51003` BR1 Overlap; `51002` BR4 OOS Space; `51005` Lock Timeout).
  3. **0% Crash Hệ thống Phía Engine:** Tuyệt đối không để bùng nổ lỗi `Msg 50000` thô bạo phía Database Engine.

---

## 4. Vấn Đề Gì Xuất Hiện Sau Khi Test? (Key Findings & Insights)

### **1. Điểm yếu nghiêm trọng của Baseline (RAW DML):**
- **Lọt lưới dữ liệu trùng lịch (Data Corruption):** Dưới chế độ RCSI, các câu lệnh `INSERT` thô không bị treo khóa. Cả 2 Session cùng chèn đồng thời và qua mặt Trigger Phase 1, làm xuất hiện cặp đơn trùng lịch cùng được commit xuống đĩa ($Q_{BR1} = 1$).
- **Sập ứng dụng Client (Unhandled Engine Exceptions):** Nếu 1 giao dịch commit trước vài milisecond, giao dịch sau bị Trigger Phase 1 đâm nổ lỗi **`Msg 50000`** thô bạo, làm **crash ứng dụng phía Client (nổ lỗi 500)**.

### **2. Sự vượt trội của Controlled (Task 12 Stored Procedures):**
- **Giải quyết triệt để nghẽn khóa và crash hệ thống:** Khóa ứng dụng `sys.sp_getapplock` (`space_booking:<space_id>`, Exclusive, 5s timeout) bắt các giao dịch cùng tác động vào 1 phòng phải xếp hàng tuần tự hóa ở tầng logic trước khi đụng vào bảng dữ liệu.
- **Bảo toàn dữ liệu tuyệt đối:** Đạt $Q_{BR1} = 0$ và $Q_{NR6} = 0$ trên 100% các kịch bản controlled.

---

## 5. Hướng Dẫn Tái Hiện Kết Quả Kiểm Thử (How to Reproduce Results)

Để tái hiện lại 100% kết quả kiểm thử trên máy tính của bạn, toàn bộ câu lệnh thực thi chi tiết cho 29 test case được lưu trữ tại file riêng:

👉 **[REPRODUCE.md](file:///Users/caoquanghung/HCMUS/CS/DataBase/FinalProject/CS486-Project/outputs/13-concurrency-tests-G05/REPRODUCE.md)**

Chi tiết đầu ra nhật ký thực thi của tất cả các bài test được lưu tại:

👉 **[DEMO_RESULTS.md](file:///Users/caoquanghung/HCMUS/CS/DataBase/FinalProject/CS486-Project/outputs/13-concurrency-tests-G05/DEMO_RESULTS.md)**  
👉 **[SUMMARY.log](file:///Users/caoquanghung/HCMUS/CS/DataBase/FinalProject/CS486-Project/outputs/13-concurrency-tests-G05/results/SUMMARY.log)**
