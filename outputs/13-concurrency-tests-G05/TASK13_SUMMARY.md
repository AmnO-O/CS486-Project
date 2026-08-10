# Task 13 — Báo Báo Tổng Hợp Bộ Kiểm Thử Đồng Thời (Concurrency Test Suite Summary)

**Hệ thống:** CS486 — Hệ thống Quản lý Không gian Cơ sở Vật chất (Campus Space Management System)  
**Nhóm thực hiện:** G05  
**Môi trường thử nghiệm:** Microsoft SQL Server 2022 (Developer Edition) trên Docker Container (`cs486_sql_server`)  
**Cơ sở dữ liệu:** `CampusSpaceDB`  
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

### **9 Kịch bản Kiểm thử Đồng thời (Scenario Families):**

| Mã Kịch Bản | Tên Kịch Bản | Hành vi Mô phỏng Đồng thời (Concurrent Race) |
|:---:|:---|:---|
| **K1** | **Instant vs Instant Submit** (`b01` / `c01`) | 2 User cùng nộp đơn đặt phòng tức thì (Instant) trùng khung giờ trên cùng 1 phòng. |
| **K2** | **Instant Submit vs Staff Approval** (`b02` / `c02`) | User A nộp đơn instant đè lên khung giờ mà Staff B đang duyệt 1 đơn pending khác. |
| **K3 / K3'** | **Escalation vs In-flight Submit** (`b03` / `c03` / `c03b`) | Vé bảo trì được leo thang lên Out-of-Service (OOS) đua với đơn đặt phòng mới nộp. |
| **T5 / T7** | **AppLock Timeout & Retry** (`b05` / `c05`) | Thử nghiệm giới hạn thời gian chờ khóa (5s Timeout) và cơ chế tự động thử lại sau khi nhả khóa. |
| **K5** | **OOS Ticket Creation vs Submit** (`b09` / `c09`) | Nhân viên tạo mới vé bảo trì Out-of-Service đua với đơn đặt phòng instant mới. |
| **Staff Race** | **Staff vs Staff Same-Conflict** (`b10` / `c10`) | 2 Nhân viên quản lý cùng duyệt 2 đơn pending trùng khung giờ trên cùng 1 phòng. |
| **Soft Gate** | **Soft-gate Fallback** (`c11`) | Đặt phòng có mục đích không khớp loại phòng (`lecture` trên `meeting_room`) tự động chuyển sang `pending` (fallback). |
| **Fallback Race** | **Fallback vs Instant Overlap** (`c12`) | Đơn `pending` (fallback) không được chặn đơn `instant` mới, nhưng khi duyệt đơn `pending` sau đó phải bị từ chối do bị instant chiếm lịch. |
| **Ack Repair** | **Advisory Ack Repair** (`c13`) | Tự động ghi nhận/khôi phục dòng xác nhận cảnh báo bảo trì (`booking_advisory_acknowledgement`) khi Staff duyệt đơn. |

---

## 2. Test Như Thế Nào? (Testing Methodology)

### **a) Mô hình Khởi chạy 2 Session Song Song (Dual-Session Execution):**
- Sử dụng 2 tiến trình `sqlcmd` độc lập (hoặc 2 Tab Query độc lập) đại diện cho **Session A** và **Session B**.
- Tiến trình Runner (`run_all.sh`) khởi chạy `_a.sql` và `_b.sql` đồng thời trong cùng một milisecond bằng kỹ thuật chạy nền trong Bash (`sqlcmd -i _a.sql & sqlcmd -i _b.sql & wait`) để ép SQL Server phải xử lý đua tranh khóa (Lock Contention) thực sự.

### **b) Khởi tạo Fixture Độc lập & Cô lập tuyệt đối (`00_setup.sql` & `99_cleanup.sql`):**
- **Không gian thử nghiệm độc lập:** Bộ test tự định nghĩa dữ liệu riêng (`TEST-13-Dept`, 2 user `test13.requester` / `test13.staff`, 9 phòng `TEST-13-01-MR` đến `TEST-13-09-MR`).
- **Khung giờ thử nghiệm cô lập:** Tất cả các mốc thời gian đặt phòng đều nằm ở tương lai xa $\ge +600$ ngày so me thời điểm chạy test. Điều này đảm bảo tuyệt đối không va chạm hay làm hỏng dữ liệu mẫu của Task 06 hay Task 12.
- **Quy trình đóng gói Idempotent:** Trước và sau mỗi lượt chạy test, script `99_cleanup.sql` thực hiện dọn dẹp sạch sẽ toàn bộ dòng dữ liệu `TEST-13` theo thứ tự rào cản khóa ngoại (FK-safe).

---

## 3. Cơ Chế Đánh Giá Test Là Thế Nào? (Evaluation Criteria)

### **1. Quy tắc Đánh giá Baseline (Chưa kiểm soát - RAW DML):**
- **ĐẠT (PASS Baseline):** Khi bài test thể hiện được hạn chế của DML thô thông qua:
  - Bùng nổ lỗi Trigger thô `Msg 50000` / `Msg 3609` từ `trg_bookings_prevent_overlap` (do Session B bị block chờ A commit, sau đó trigger thấy dòng đã commit và quăng exception).
  - Hoặc hiện tượng treo khóa thô không có timeout contract (Blocking).
- **KHÔNG ĐẠT:** Nếu Baseline trả về mã lỗi nghiệp vụ của Task 12 (`51001`–`51009`).

### **2. Quy tắc Đánh giá Controlled (Task 12 Procedures):**
- **ĐẠT (PASS Controlled):** Bắt buộc thỏa mãn đồng thời 3 điều kiện:
  1. **Tuần tự hóa mượt mà (Serialized):** Đúng 1 Session đến trước chiến thắng (`rc = 0`), Session đến sau bị từ chối mượt mà với mã lỗi nghiệp vụ chuẩn định danh (`rc = 51003` BR1 Overlap; `rc = 51002` BR4 OOS Space; `rc = 51005` Lock Timeout).
  2. **Tuyệt đối không Crash hệ thống:** 0% lỗi `Msg 50000` từ Trigger Phase 1.
  3. **Bảo toàn dữ liệu (Invariant Audit):** Script `audit_invariant.sql` xác nhận $Q_{BR1} = 0$ (Không có cặp trùng lịch) và $Q_{NR6} = 0$ (Không có đặt phòng trùng giờ Out-of-Service).

---

## 4. Vấn Đề Gì Xuất Hiện Sau Khi Test? (Key Findings & Insights)

### **1. Điểm yếu nghiêm trọng của Baseline (RAW DML):**
- **Sập ứng dụng Client (Unhandled Engine Exceptions):** Vì không có cơ chế khóa ứng dụng, Session B bị đứng hình chờ khóa Session A. Ngay khi Session A `COMMIT`, Session B tiếp tục chạy và bị Trigger Phase 1 chặn lại bằng lỗi **`Msg 50000`** thô bạo. Kết quả là làm **crash giao dịch tầng client (nổ 500 Internal Server Error)**.
- **Treo đứng hình vô thời hạn (Indefinite Lock Blocking):** Giao dịch bị ngưng trệ không có hợp đồng thời gian chờ (Timeout Contract).

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
