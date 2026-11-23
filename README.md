# BaoCao-BaoMat-TDE
# Thực nghiệm: Mã hóa dữ liệu tĩnh trong suốt (TDE - Transparent Data Encryption)

* **Hệ quản trị CSDL:** SQL Server 2019 Enterprise Evaluation Edition
* **Cơ sở dữ liệu thực nghiệm:** `SecurityDemo` (Hệ thống Quản lý Đào tạo & Học phí - 7 bảng)
* **Tệp kịch bản SQL:** [`KichBan_Demo_TDE.sql`](./KichBan_Demo_TDE.sql)

---

## Tóm tắt các bước thực hiện Demo

### Bước 0: Chuẩn bị môi trường
* Kết nối SSMS vào instance hỗ trợ TDE (bản Enterprise / Evaluation / Developer).
* Tạo sẵn thư mục trống `C:\Backup` trên ổ cứng để chứa tệp sao lưu và cặp khóa chứng chỉ.
* Xóa bỏ CSDL `SecurityDemo` hoặc chứng chỉ cũ (nếu có) để đảm bảo môi trường sạch trước khi chạy.

### Bước 1: Tạo CSDL `SecurityDemo` và nạp dữ liệu mẫu
* Khởi tạo CSDL `SecurityDemo` gồm 7 bảng quan hệ (`Khoa`, `SinhVien`, `GiangVien`, `MonHoc`, `LopHocPhan`, `DangKyHoc`, `ThanhToanHocPhi`) và nạp dữ liệu mẫu.

### Bước 2: Sao lưu thô (khi CHƯA mã hóa) & Chứng minh lỗ hổng đọc lén
* Chạy lệnh `BACKUP DATABASE` xuất ra tệp `C:\Backup\SecurityDemo_ChuaMaHoa.bak`.
* **Kiểm chứng:** Mở tệp `.bak` bằng **Notepad**, nhấn `Ctrl + F` tìm từ khóa `ATTT01` hoặc `CNTT04`.
* **Kết quả:** Dữ liệu hiển thị rõ nguyên văn (plaintext), chứng minh dữ liệu tĩnh trên ổ cứng dễ bị đọc trộm ở tầng hệ điều hành mà không cần đăng nhập SQL Server.

### Bước 3: Thiết lập phân cấp khóa & Bật mã hóa TDE (AES-256)
* Khởi tạo chuỗi bảo vệ phân cấp: **Service Master Key → Database Master Key → Server Certificate (`TDECert_SecurityDemo`) → Database Encryption Key (DEK - AES_256)**.
* Xuất bản sao lưu chứng chỉ (`TDECert_SecurityDemo.cer`) và khóa bí mật (`TDECert_SecurityDemo.pvk`) ra thư mục `C:\Backup`.
* Kích hoạt mã hóa (`SET ENCRYPTION ON`) và kiểm tra cột `encryption_state = 3` (đã mã hóa hoàn tất).

### Bước 4: Kiểm chứng tính "Minh bạch" & Chống đọc lén
* Xuất bản sao lưu mới `C:\Backup\SecurityDemo_DaMaHoa.bak`.
* **Kiểm chứng trên Notepad:** Tìm lại từ khóa `ATTT01` → Không tìm thấy, toàn bộ nội dung tệp đã biến đổi thành chuỗi nhị phân mã hóa.
* **Kiểm chứng trên SSMS:** Truy vấn `SELECT` trên bảng `SinhVien` vẫn trả về dữ liệu gốc bình thường mà không cần chỉnh sửa mã nguồn hay câu lệnh ứng dụng.

### Bước 5: Mô phỏng đánh cắp tệp `.bak` & Phục hồi thảm họa (Disaster Recovery)
* **5A – Giả lập mang tệp `.bak` sang máy chủ lạ:** Xóa CSDL `SecurityDemo` và gỡ bỏ `TDECert_SecurityDemo`, sau đó chạy lệnh `RESTORE DATABASE`. Hệ thống lập tức chặn và báo lỗi **`Msg 33111`** (*Cannot find server certificate with thumbprint...*).
* **5B – Khôi phục hợp pháp:** Nạp lại cặp tệp `.cer` + `.pvk` kèm mật khẩu vào `master`, sau đó chạy lại `RESTORE DATABASE`. Dữ liệu 7 bảng được khôi phục nguyên vẹn và tự động duy trì trạng thái mã hóa TDE.

---

## Bảng tổng hợp luận điểm bảo vệ

| Mục tiêu kiểm chứng | Thao tác thực hiện trên demo | Kết quả & Ý nghĩa kỹ thuật |
| :--- | :--- | :--- |
| **Rủi ro dữ liệu chưa mã hóa** | Mở `SecurityDemo_ChuaMaHoa.bak` bằng Notepad, tìm `ATTT01` | Hiển thị rõ văn bản gốc → Dễ bị đọc lén ở tầng vật lý/hệ điều hành. |
| **Hiệu quả mã hóa dữ liệu tĩnh** | Bật TDE (`AES_256`), mở `SecurityDemo_DaMaHoa.bak` bằng Notepad | Không tìm thấy chuỗi gốc, nội dung biến thành mã nhị phân → Ngăn chặn đọc lén tệp `.mdf`, `.ldf`, `.bak`. |
| **Tính minh bạch với ứng dụng** | Chạy `SELECT` trên bảng `SinhVien` và `ThanhToanHocPhi` | Trả về dữ liệu bình thường → Mã hóa/giải mã diễn ra tự động ở tầng I/O, không ảnh hưởng logic ứng dụng. |
| **Chống đánh cắp & Phục hồi sự cố** | Xóa khóa và chạy `RESTORE` (lỗi `Msg 33111`), sau đó nạp lại `.cer`/`.pvk` | Ngăn chặn khôi phục trái phép sang máy chủ lạ; đảm bảo phục hồi an toàn khi quản trị viên nắm giữ đúng khóa. |
