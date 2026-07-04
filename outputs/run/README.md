# Hướng dẫn sử dụng Semantic Regeneration Pipeline (Tái sinh Schema & Artifacts)

Thư mục này dùng để lưu trữ các phiên bản chạy khác nhau (các "run") của database design pipeline (ví dụ: `run_01`, `run_02`,...).

Khi bạn thay đổi thiết kế ở một bước upstream (ví dụ: cập nhật ERD), thay vì phải sửa thủ công toàn bộ các file downstream (Logical Schema, DDL, Seed Data, SQL Queries) gây mất thời gian và dễ sai sót, bạn có thể dùng command `/regenerate-from` để tự động tái sinh toàn bộ pipeline phía sau.

---

## 🌟 Triết lý cốt lõi: Bảo tồn Ý định Thiết kế (Design Intent)

Agent không thực hiện sửa chắp vá (patching) trực tiếp lên code cũ, mà sẽ **tái sinh mới hoàn toàn (regenerate from scratch)** dựa trên các nguyên tắc:
* **Old run = Knowledge Source**: File cũ ở run trước chỉ được dùng để hiểu ý định thiết kế (tại sao có trigger này, tại sao cần index này, dữ liệu giả lập phân bổ ra sao,...).
* **New Upstream = Single Source of Truth**: Artifact mới sửa đổi của bạn là nguồn sự thật duy nhất.
* **Preserve Intent, Discard Implementation**: Giữ lại ý đồ nghiệp vụ và tối ưu hóa thiết kế, nhưng viết lại hoàn toàn mã nguồn (SQL/DDL) mới dựa trên cấu trúc bảng mới.

---

## 🛠️ Quy trình thực hiện (Step-by-Step)

Giả sử bạn đã có thiết kế ở thư mục `outputs/run/run_01/` và muốn chỉnh sửa ERD để tạo phiên bản thiết kế mới ở `run_02`:

### Bước 1: Tạo thư mục Run mới
Hãy tạo thư mục mới `outputs/run/run_02/` bằng cách sao chép (copy) toàn bộ thư mục `outputs/run/run_01/`.

### Bước 2: Cập nhật file thiết kế Upstream cần cải tiến
Mở file upstream bạn muốn chỉnh sửa trong run mới và chỉnh sửa trực tiếp (Ví dụ: Chỉnh sửa ERD tại `outputs/run/run_02/02-erd-design-G05.md`).

### Bước 3: Chạy Command `/regenerate-from` trên OpenCode
Bật OpenCode và chạy lệnh sau:

```text
/regenerate-from --from ERD --from-run run_01 --to-run run_02
```

Lệnh này sẽ tự động:
1. So sánh ERD cũ (`run_01`) và ERD mới (`run_02`) để tìm các thay đổi.
2. Đọc Logical Schema cũ (`run_01`) để lấy ý định thiết kế (index, triggers, naming).
3. Tạo lại Logical Schema mới tại `run_02` và đồng bộ registries (`docs/entity-registry.md` & `docs/schema-registry.md`).
4. Chạy lại Validation và lưu báo cáo ở `run_02`.
5. Tạo lại file DDL SQL (`05-db-definition-G05.sql`) mới ở `run_02`.
6. Đọc phân bổ dữ liệu mẫu từ `run_01` và tạo lại file Seed Data (`06-sample-data-G05.sql`) phù hợp với cấu trúc bảng mới ở `run_02`.
7. Viết lại hoàn toàn các truy vấn SQL (`07-query-design-G05.sql`) tương ứng ở `run_02` từ đầu mà không bị ảnh hưởng bởi code SQL cũ.

---

## 📋 Các tham số của Command

```bash
regenerate-from --from <Step> --from-run <old_run> --to-run <new_run> [--group G05]
```

* `--from`: Bước upstream đã được cập nhật thủ công. Các giá trị hợp lệ:
  - `BusinessReq` (Task 1)
  - `ERD` (Task 2)
  - `LogicalSchema` (Task 3)
  - `Validation` (Task 4)
  - `DDL` (Task 5)
  - `SeedData` (Task 6)
* `--from-run`: Thư mục chứa run cũ (ví dụ: `run_01`).
* `--to-run`: Thư mục chứa run mới (ví dụ: `run_02`).
* `--group`: Tên nhóm thiết kế (Mặc định: `G05`).
