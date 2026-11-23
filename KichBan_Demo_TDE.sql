/* =========================================================================================
   KỊCH BẢN THỰC NGHIỆM: MÃ HÓA DỮ LIỆU TĨNH TRONG SUỐT (TDE - TRANSPARENT DATA ENCRYPTION)
   Hệ quản trị: SQL Server 2019 Enterprise Evaluation Edition
   Cơ sở dữ liệu: SecurityDemo (Hệ thống Quản lý Đào tạo & Học phí)
   
   LƯU Ý TRƯỚC KHI CHẠY DEMO:
   1. Đảm bảo đã kết nối đúng vào máy chủ bản Evaluation (không phải SQLEXPRESS).
   2. Đảm bảo thư mục C:\Backup đã tồn tại trên ổ C và đang TRỐNG.
   3. Khi trình diễn, BÔI ĐEN từng bước nhỏ và nhấn F5 (Execute), KHÔNG chạy toàn bộ file 1 lần.
========================================================================================= */


/* =========================================================================================
   BƯỚC 0: KIỂM TRA PHIÊN BẢN & DỌN DẸP MÔI TRƯỜNG TRƯỚC KHI DEMO
   - Mục đích: Đưa máy chủ về trạng thái sạch, tránh lỗi trùng tên CSDL/Certificate nếu đã chạy thử.
========================================================================================= */
USE master;
GO

-- 0.1. Kiểm tra phiên bản SQL Server (Phải là Enterprise / Evaluation / Developer mới hỗ trợ TDE)
SELECT SERVERPROPERTY('Edition') AS PhienBanSQLServer;
GO

-- 0.2. Xóa CSDL SecurityDemo nếu đã tồn tại từ lần chạy thử trước
IF DB_ID('SecurityDemo') IS NOT NULL
BEGIN
    ALTER DATABASE SecurityDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SecurityDemo;
END
GO

-- 0.3. Xóa Certificate cũ nếu đã tồn tại
IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'TDECert_SecurityDemo')
BEGIN
    DROP CERTIFICATE TDECert_SecurityDemo;
END
GO


/* =========================================================================================
   BƯỚC 1: KHỞI TẠO CSDL SECURITYDEMO, TẠO 7 BẢNG VÀ NẠP DỮ LIỆU MẪU
   - Mục đích: Xây dựng dữ liệu nghiệp vụ thực tế phục vụ kiểm chứng trước và sau mã hóa.
========================================================================================= */
USE master;
GO
CREATE DATABASE SecurityDemo;
GO

USE SecurityDemo;
GO

-- 1. Bảng Khoa
CREATE TABLE dbo.Khoa
(
    MaKhoa INT IDENTITY(1,1) NOT NULL,
    TenKhoa NVARCHAR(100) NOT NULL,
    MoTa NVARCHAR(255) NULL,
    CONSTRAINT PK_Khoa PRIMARY KEY (MaKhoa),
    CONSTRAINT UQ_Khoa_TenKhoa UNIQUE (TenKhoa)
);
GO

-- 2. Bảng SinhVien
CREATE TABLE dbo.SinhVien
(
    MaSinhVien INT IDENTITY(1,1) NOT NULL,
    MaKhoa INT NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    SoDienThoai NVARCHAR(20) NULL,
    DiaChi NVARCHAR(255) NULL,
    DiemGPA DECIMAL(3,2) NULL,
    CONSTRAINT PK_SinhVien PRIMARY KEY (MaSinhVien),
    CONSTRAINT UQ_SinhVien_Email UNIQUE (Email),
    CONSTRAINT FK_SinhVien_Khoa FOREIGN KEY (MaKhoa) REFERENCES dbo.Khoa(MaKhoa),
    CONSTRAINT CK_SinhVien_DiemGPA CHECK (DiemGPA IS NULL OR DiemGPA BETWEEN 0 AND 4)
);
GO

-- 3. Bảng GiangVien
CREATE TABLE dbo.GiangVien
(
    MaGiangVien INT IDENTITY(1,1) NOT NULL,
    MaKhoa INT NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    SoDienThoai NVARCHAR(20) NULL,
    CONSTRAINT PK_GiangVien PRIMARY KEY (MaGiangVien),
    CONSTRAINT UQ_GiangVien_Email UNIQUE (Email),
    CONSTRAINT FK_GiangVien_Khoa FOREIGN KEY (MaKhoa) REFERENCES dbo.Khoa(MaKhoa)
);
GO

-- 4. Bảng MonHoc
CREATE TABLE dbo.MonHoc
(
    MaMonHoc INT IDENTITY(1,1) NOT NULL,
    MaMon VARCHAR(20) NOT NULL,
    TenMonHoc NVARCHAR(100) NOT NULL,
    SoTinChi INT NOT NULL,
    CONSTRAINT PK_MonHoc PRIMARY KEY (MaMonHoc),
    CONSTRAINT UQ_MonHoc_MaMon UNIQUE (MaMon),
    CONSTRAINT CK_MonHoc_SoTinChi CHECK (SoTinChi BETWEEN 1 AND 10)
);
GO

-- 5. Bảng LopHocPhan
CREATE TABLE dbo.LopHocPhan
(
    MaLopHocPhan INT IDENTITY(1,1) NOT NULL,
    MaMonHoc INT NOT NULL,
    MaGiangVien INT NOT NULL,
    MaLop VARCHAR(20) NOT NULL,
    HocKy TINYINT NOT NULL,
    NamHoc VARCHAR(9) NOT NULL,
    CONSTRAINT PK_LopHocPhan PRIMARY KEY (MaLopHocPhan),
    CONSTRAINT UQ_LopHocPhan_MaLop UNIQUE (MaLop),
    CONSTRAINT FK_LopHocPhan_MonHoc FOREIGN KEY (MaMonHoc) REFERENCES dbo.MonHoc(MaMonHoc),
    CONSTRAINT FK_LopHocPhan_GiangVien FOREIGN KEY (MaGiangVien) REFERENCES dbo.GiangVien(MaGiangVien),
    CONSTRAINT CK_LopHocPhan_HocKy CHECK (HocKy BETWEEN 1 AND 3)
);
GO

-- 6. Bảng DangKyHoc
CREATE TABLE dbo.DangKyHoc
(
    MaDangKy INT IDENTITY(1,1) NOT NULL,
    MaSinhVien INT NOT NULL,
    MaLopHocPhan INT NOT NULL,
    Diem DECIMAL(4,2) NULL,
    NgayDangKy DATE NOT NULL,
    CONSTRAINT PK_DangKyHoc PRIMARY KEY (MaDangKy),
    CONSTRAINT FK_DangKyHoc_SinhVien FOREIGN KEY (MaSinhVien) REFERENCES dbo.SinhVien(MaSinhVien),
    CONSTRAINT FK_DangKyHoc_LopHocPhan FOREIGN KEY (MaLopHocPhan) REFERENCES dbo.LopHocPhan(MaLopHocPhan),
    CONSTRAINT UQ_DangKyHoc_SinhVien_LopHocPhan UNIQUE (MaSinhVien, MaLopHocPhan),
    CONSTRAINT CK_DangKyHoc_Diem CHECK (Diem IS NULL OR Diem BETWEEN 0 AND 10)
);
GO

-- 7. Bảng ThanhToanHocPhi
CREATE TABLE dbo.ThanhToanHocPhi
(
    MaThanhToan INT IDENTITY(1,1) NOT NULL,
    MaSinhVien INT NOT NULL,
    SoTien DECIMAL(12,2) NOT NULL,
    NgayThanhToan DATE NOT NULL,
    TrangThai NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_ThanhToanHocPhi PRIMARY KEY (MaThanhToan),
    CONSTRAINT FK_ThanhToanHocPhi_SinhVien FOREIGN KEY (MaSinhVien) REFERENCES dbo.SinhVien(MaSinhVien),
    CONSTRAINT CK_ThanhToanHocPhi_SoTien CHECK (SoTien >= 0),
    CONSTRAINT CK_ThanhToanHocPhi_TrangThai CHECK (TrangThai IN (N'Da thanh toan', N'Chua thanh toan', N'Dang xu ly'))
);
GO

-- Nạp dữ liệu mẫu vào 7 bảng
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Khoa (TenKhoa, MoTa) VALUES
    (N'Công nghệ thông tin', N'Đào tạo công nghệ thông tin và khoa học máy tính'),
    (N'Kinh tế', N'Đào tạo kinh tế và quản trị kinh doanh'),
    (N'Ngoại ngữ', N'Đào tạo ngôn ngữ và văn hóa nước ngoài'),
    (N'Kỹ thuật', N'Đào tạo các ngành kỹ thuật và công nghệ');

    INSERT INTO dbo.GiangVien (MaKhoa, HoTen, Email, SoDienThoai) VALUES
    (1, N'Nguyễn Văn An', 'an.nguyen@university.edu.vn', '0901000001'),
    (1, N'Trần Thị Bình', 'binh.tran@university.edu.vn', '0901000002'),
    (2, N'Lê Văn Cường', 'cuong.le@university.edu.vn', '0901000003'),
    (2, N'Phạm Thị Dung', 'dung.pham@university.edu.vn', '0901000004'),
    (3, N'Hoàng Thị Hà', 'ha.hoang@university.edu.vn', '0901000005'),
    (3, N'Đỗ Văn Hùng', 'hung.do@university.edu.vn', '0901000006'),
    (4, N'Vũ Minh Khang', 'khang.vu@university.edu.vn', '0901000007'),
    (4, N'Bùi Thị Lan', 'lan.bui@university.edu.vn', '0901000008');

    INSERT INTO dbo.MonHoc (MaMon, TenMonHoc, SoTinChi) VALUES
    ('CNTT01', N'Cơ sở dữ liệu', 3),
    ('CNTT02', N'Lập trình C#', 3),
    ('CNTT03', N'Mạng máy tính', 3),
    ('CNTT04', N'An toàn thông tin', 3),
    ('CNTT05', N'Cấu trúc dữ liệu và giải thuật', 4),
    ('KT01', N'Nguyên lý kế toán', 3),
    ('KT02', N'Quản trị học', 3),
    ('NN01', N'Tiếng Anh cơ bản', 3),
    ('KTTH01', N'Kỹ thuật điện', 3),
    ('KTTH02', N'Điện tử cơ bản', 3);

    INSERT INTO dbo.SinhVien (MaKhoa, HoTen, Email, SoDienThoai, DiaChi, DiemGPA) VALUES
    (1, N'Nguyễn Minh Anh', 'sv001@gmail.com', '0912000001', N'Hà Nội', 3.50),
    (1, N'Trần Quốc Bảo', 'sv002@gmail.com', '0912000002', N'Hà Nội', 3.20),
    (1, N'Lê Hoàng Nam', 'sv003@gmail.com', '0912000003', N'Hải Phòng', 3.80),
    (1, N'Phạm Ngọc Mai', 'sv004@gmail.com', '0912000004', N'Bắc Ninh', 3.60),
    (1, N'Đỗ Thành Long', 'sv005@gmail.com', '0912000005', N'Hà Nội', 2.90),
    (1, N'Vũ Thu Trang', 'sv006@gmail.com', '0912000006', N'Hưng Yên', 3.40),
    (2, N'Nguyễn Đức Anh', 'sv007@gmail.com', '0912000007', N'Hà Nội', 3.10),
    (2, N'Bùi Khánh Linh', 'sv008@gmail.com', '0912000008', N'Hà Nam', 3.70),
    (2, N'Hoàng Minh Đức', 'sv009@gmail.com', '0912000009', N'Hà Nội', 2.80),
    (2, N'Đặng Thu Hà', 'sv010@gmail.com', '0912000010', N'Nam Định', 3.30),
    (3, N'Phan Quỳnh Anh', 'sv011@gmail.com', '0912000011', N'Hà Nội', 3.90),
    (3, N'Nguyễn Hải Yến', 'sv012@gmail.com', '0912000012', N'Hải Dương', 3.50),
    (3, N'Trần Minh Tú', 'sv013@gmail.com', '0912000013', N'Hà Nội', 3.00),
    (3, N'Võ Thị Ngọc', 'sv014@gmail.com', '0912000014', N'Thái Bình', 3.60),
    (3, N'Lê Anh Tuấn', 'sv015@gmail.com', '0912000015', N'Hà Nội', 2.70),
    (4, N'Đinh Văn Phúc', 'sv016@gmail.com', '0912000016', N'Hà Nội', 3.20),
    (4, N'Ngô Thị Hương', 'sv017@gmail.com', '0912000017', N'Bắc Giang', 3.80),
    (4, N'Đào Minh Quân', 'sv018@gmail.com', '0912000018', N'Hà Nội', 3.40),
    (4, N'Phạm Hoài Thương', 'sv019@gmail.com', '0912000019', N'Vĩnh Phúc', 3.10),
    (4, N'Vũ Thành Đạt', 'sv020@gmail.com', '0912000020', N'Hà Nội', 3.70);

    INSERT INTO dbo.LopHocPhan (MaMonHoc, MaGiangVien, MaLop, HocKy, NamHoc) VALUES
    (1, 1, 'CSDL01', 1, '2026-2027'), (1, 2, 'CSDL02', 1, '2026-2027'),
    (2, 1, 'CSharp01', 1, '2026-2027'), (2, 2, 'CSharp02', 2, '2026-2027'),
    (3, 2, 'MANG01', 1, '2026-2027'), (4, 1, 'ATTT01', 2, '2026-2027'),
    (5, 2, 'CTDL01', 2, '2026-2027'), (6, 3, 'KT01', 1, '2026-2027'),
    (6, 4, 'KT02', 2, '2026-2027'), (7, 3, 'QTH01', 1, '2026-2027'),
    (8, 5, 'TA01', 1, '2026-2027'), (8, 6, 'TA02', 2, '2026-2027'),
    (9, 7, 'KTD01', 1, '2026-2027'), (9, 8, 'KTD02', 2, '2026-2027'),
    (10, 7, 'DT01', 1, '2026-2027');

    INSERT INTO dbo.DangKyHoc (MaSinhVien, MaLopHocPhan, Diem, NgayDangKy) VALUES
    (1, 1, 8.50, '2026-08-15'), (2, 1, 7.50, '2026-08-15'), (3, 1, 9.00, '2026-08-16'), (4, 1, 8.00, '2026-08-16'),
    (5, 2, 7.00, '2026-08-17'), (6, 2, 8.50, '2026-08-17'), (1, 2, 9.00, '2026-08-18'),
    (2, 3, 8.00, '2026-08-18'), (3, 3, 7.50, '2026-08-19'), (4, 3, 9.50, '2026-08-19'),
    (5, 4, 6.50, '2026-08-20'), (6, 4, 8.00, '2026-08-20'),
    (1, 5, 8.50, '2026-08-21'), (2, 5, 7.00, '2026-08-21'), (3, 5, 9.00, '2026-08-22'),
    (4, 6, 8.00, '2026-08-22'), (5, 6, 7.50, '2026-08-23'), (6, 6, 9.00, '2026-08-23'),
    (7, 8, 8.00, '2026-08-24'), (8, 8, 9.00, '2026-08-24'), (9, 8, 7.00, '2026-08-25'),
    (10, 9, 8.50, '2026-08-25'), (7, 9, 7.50, '2026-08-26'), (8, 10, 9.00, '2026-08-26'),
    (11, 11, 9.50, '2026-08-27'), (12, 11, 8.50, '2026-08-27'), (13, 11, 7.50, '2026-08-28'),
    (14, 12, 8.00, '2026-08-28'), (15, 12, 7.00, '2026-08-29'), (11, 12, 9.00, '2026-08-29'),
    (16, 13, 8.50, '2026-08-30'), (17, 13, 9.00, '2026-08-30'), (18, 13, 7.50, '2026-08-31'),
    (19, 14, 8.00, '2026-08-31'), (20, 14, 9.50, '2026-09-01'),
    (16, 15, 7.00, '2026-09-01'), (17, 15, 8.50, '2026-09-02'), (18, 15, 9.00, '2026-09-02'),
    (19, 15, 7.50, '2026-09-03'), (20, 15, 8.00, '2026-09-03');

    INSERT INTO dbo.ThanhToanHocPhi (MaSinhVien, SoTien, NgayThanhToan, TrangThai) VALUES
    (1, 5500000, '2026-08-10', N'Da thanh toan'), (2, 5500000, '2026-08-10', N'Da thanh toan'),
    (3, 5500000, '2026-08-11', N'Da thanh toan'), (4, 5500000, '2026-08-11', N'Dang xu ly'),
    (5, 5500000, '2026-08-12', N'Chua thanh toan'), (6, 5500000, '2026-08-12', N'Da thanh toan'),
    (7, 6000000, '2026-08-13', N'Da thanh toan'), (8, 6000000, '2026-08-13', N'Dang xu ly'),
    (9, 6000000, '2026-08-14', N'Chua thanh toan'), (10, 6000000, '2026-08-14', N'Da thanh toan'),
    (11, 5000000, '2026-08-15', N'Da thanh toan'), (12, 5000000, '2026-08-15', N'Da thanh toan'),
    (13, 5000000, '2026-08-16', N'Chua thanh toan'), (14, 5000000, '2026-08-16', N'Dang xu ly'),
    (15, 5000000, '2026-08-17', N'Da thanh toan'), (16, 6500000, '2026-08-18', N'Da thanh toan'),
    (17, 6500000, '2026-08-18', N'Dang xu ly'), (18, 6500000, '2026-08-19', N'Chua thanh toan'),
    (19, 6500000, '2026-08-19', N'Da thanh toan'), (20, 6500000, '2026-08-20', N'Da thanh toan');

    COMMIT TRANSACTION;
    PRINT N'Tạo CSDL SecurityDemo và nạp dữ liệu mẫu thành công!';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


/* =========================================================================================
   BƯỚC 2: XUẤT BẢN SAO LƯU THÔ (CHƯA MÃ HÓA) & CHỨNG MINH LỖ HỔNG ĐỌC LÉN
   - Thao tác trực tiếp sau khi chạy lệnh:
     Mở C:\Backup\SecurityDemo_ChuaMaHoa.bak bằng Notepad -> Ctrl + F tìm 'ATTT01' hoặc 'CNTT04'.
     Kết quả: Dữ liệu hiện rõ nguyên văn (plaintext) dù không cần đăng nhập SQL Server.
========================================================================================= */
USE master;
GO

BACKUP DATABASE SecurityDemo 
TO DISK = 'C:\Backup\SecurityDemo_ChuaMaHoa.bak' 
WITH INIT;
GO


/* =========================================================================================
   BƯỚC 3: THIẾT LẬP CHUỖI KHÓA PHÂN CẤP VÀ BẬT MÃ HÓA TDE (AES-256)
   - Hệ thống phân cấp khóa:
     Service Master Key -> Database Master Key -> Server Certificate -> DEK -> Dữ liệu
========================================================================================= */
USE master;
GO

-- 3.1. Tạo Database Master Key trong CSDL hệ thống master (nếu chưa có)
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword!123';
END
GO

-- 3.2. Tạo Server Certificate chuyên dùng để bảo vệ khóa cho SecurityDemo
CREATE CERTIFICATE TDECert_SecurityDemo 
WITH SUBJECT = 'TDE Certificate for SecurityDemo';
GO

-- 3.3. Sao lưu Certificate (.cer) và Private Key (.pvk) ra ổ cứng (bắt buộc để khôi phục sau này)
BACKUP CERTIFICATE TDECert_SecurityDemo 
TO FILE = 'C:\Backup\TDECert_SecurityDemo.cer'
WITH PRIVATE KEY (
    FILE = 'C:\Backup\TDECert_SecurityDemo.pvk',
    ENCRYPTION BY PASSWORD = 'StrongPassword!123'
);
GO

-- 3.4. Tạo Database Encryption Key (DEK) dùng thuật toán AES-256 và bật TDE trên SecurityDemo
USE SecurityDemo;
GO

CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDECert_SecurityDemo;
GO

ALTER DATABASE SecurityDemo 
SET ENCRYPTION ON;
GO

-- 3.5. Kiểm tra trạng thái mã hóa (encryption_state = 3 nghĩa là đã mã hóa hoàn tất)
SELECT 
    DB_NAME(database_id) AS TenCSDL, 
    encryption_state AS TrangThaiMaHoa,
    percent_complete AS TienDoPhanTram
FROM sys.dm_database_encryption_keys 
WHERE DB_NAME(database_id) = 'SecurityDemo';
GO


/* =========================================================================================
   BƯỚC 4: KIỂM CHỨNG TÍNH "MINH BẠCH" (TRANSPARENT) & CHỐNG ĐỌC LÉN
   - Thao tác trực tiếp sau khi chạy lệnh:
     Mở C:\Backup\SecurityDemo_DaMaHoa.bak bằng Notepad -> Ctrl + F tìm lại 'ATTT01'.
     Kết quả: Không tìm thấy từ khóa (đã bị mã hóa nhị phân), nhưng truy vấn trên SSMS vẫn chạy bình thường.
========================================================================================= */
-- 4.1. Người dùng/ứng dụng hợp lệ vẫn truy vấn dữ liệu bình thường không cần sửa code
SELECT TOP 5 HoTen, Email, DiemGPA 
FROM SecurityDemo.dbo.SinhVien;
GO

-- 4.2. Tạo bản sao lưu mới sau khi đã kích hoạt TDE
BACKUP DATABASE SecurityDemo 
TO DISK = 'C:\Backup\SecurityDemo_DaMaHoa.bak' 
WITH INIT;
GO


/* =========================================================================================
   BƯỚC 5: MÔ PHỎNG ĐÁNH CẮP TỆP SAO LƯU & PHỤC HỒI THẢM HỌA (DISASTER RECOVERY)
========================================================================================= */

-- -----------------------------------------------------------------------------------------
-- PHẦN 5A: Giả lập kẻ gian lấy được tệp .bak mang sang máy chủ lạ (không có chứng chỉ gốc)
-- -----------------------------------------------------------------------------------------
USE master;
GO

-- Xóa CSDL và gỡ bỏ Certificate khỏi máy chủ hiện tại
ALTER DATABASE SecurityDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE SecurityDemo;
DROP CERTIFICATE TDECert_SecurityDemo;
GO

-- Thử khôi phục tệp sao lưu đã mã hóa khi thiếu Certificate
-- [KỲ VỌNG BÁO LỖI ĐỎ Msg 33111]: SQL Server từ chối khôi phục vì thiếu chứng chỉ khớp dấu vân tay!
RESTORE DATABASE SecurityDemo 
FROM DISK = 'C:\Backup\SecurityDemo_DaMaHoa.bak';
GO


-- -----------------------------------------------------------------------------------------
-- PHẦN 5B: Khôi phục hợp pháp khi quản trị viên có đầy đủ cặp khóa dự phòng (.cer & .pvk)
-- -----------------------------------------------------------------------------------------
USE master;
GO

-- 1. Nạp lại Certificate và Private Key vào master bằng mật khẩu bảo vệ
CREATE CERTIFICATE TDECert_SecurityDemo
FROM FILE = 'C:\Backup\TDECert_SecurityDemo.cer'
WITH PRIVATE KEY (
    FILE = 'C:\Backup\TDECert_SecurityDemo.pvk',
    DECRYPTION BY PASSWORD = 'StrongPassword!123'
);
GO

-- 2. Khôi phục lại toàn bộ CSDL SecurityDemo
RESTORE DATABASE SecurityDemo 
FROM DISK = 'C:\Backup\SecurityDemo_DaMaHoa.bak';
GO

-- 3. Kiểm tra lại dữ liệu gốc và xác nhận TDE vẫn tự động duy trì trạng thái mã hóa (3)
SELECT TOP 5 
    sv.MaSinhVien, 
    sv.HoTen, 
    sv.Email, 
    tt.SoTien, 
    tt.TrangThai
FROM SecurityDemo.dbo.SinhVien sv
JOIN SecurityDemo.dbo.ThanhToanHocPhi tt ON sv.MaSinhVien = tt.MaSinhVien;

SELECT 
    DB_NAME(database_id) AS TenCSDL, 
    encryption_state AS TrangThaiMaHoaSauRestore
FROM sys.dm_database_encryption_keys 
WHERE DB_NAME(database_id) = 'SecurityDemo';
GO


/* =========================================================================================
   BƯỚC 6 (TÙY CHỌN): DỌN DẸP SẠCH HỆ THỐNG SAU KHI BÁO CÁO XONG
   - Chỉ chạy đoạn này khi đã hoàn thành buổi thuyết trình và muốn gỡ bỏ toàn bộ bài thực hành.
========================================================================================= */
/*
USE master;
GO
ALTER DATABASE SecurityDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE SecurityDemo;
DROP CERTIFICATE TDECert_SecurityDemo;
-- Chỉ chạy DROP MASTER KEY nếu trên máy chủ không còn CSDL nào khác đang bật TDE:
-- DROP MASTER KEY;
GO
*/