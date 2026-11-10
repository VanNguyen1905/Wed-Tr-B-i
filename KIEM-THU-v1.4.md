# EDU GAME HUB FREE v1.4 — BÁO CÁO KIỂM THỬ

## Lỗi đã sửa

- Bản cũ gọi `firebase firestore:databases:create` khi `firestore.googleapis.com` vẫn ở trạng thái disabled, gây `HTTP 403 SERVICE_DISABLED`.
- Bản v1.4 bật `firestore.googleapis.com` và `identitytoolkit.googleapis.com` bằng `gcloud services enable` trước khi truy vấn hoặc tạo database.
- Sử dụng `gcloud firestore databases list` để phân biệt database đã tồn tại và lỗi truy cập; có cơ chế retry khi API mới bật chưa đồng bộ.
- Nếu `(default)` đã tồn tại, không tạo lại. Nếu project đã có database khác, không tự tạo database thứ hai (tránh vượt miễn phí Spark).
- Không có thao tác thêm tài khoản Billing, Cloud Run hoặc Firebase Storage.

## Đã kiểm thử ngay trên mã nguồn bàn giao

- 11 nhóm kiểm thử bằng Python `unittest`: file nguồn, JSON Hosting, cú pháp JS (`node --check`), đối chiếu 20 ID giữa HTML/JS, thứ tự enable API trước khi tạo database, bảo vệ Spark, Firestore rules, trạng thái project tồn tại, nội dung game mẫu, không đóng gói cấu hình riêng/token.
- 8 luồng UI bằng Chromium headless với Firebase **giả lập**: tải danh mục, tìm kiếm, lọc, mở/đóng game, vào phần Admin, đăng nhập giả lập, ẩn/hiện game, kiểm tra lỗi JavaScript.
- Kết quả: PASS 11/11 nhóm và PASS 8/8 luồng UI.

## Chưa thể kiểm thử ngay trong môi trường tạo ZIP

- Không có PowerShell Windows, Firebase CLI/gcloud đã đăng nhập tài khoản thật của người dùng. Vì vậy **chưa thể tuyên bố script chạy thành công end-to-end trên Firebase thật**.
- Các đoạn PowerShell sẽ được parse lại bằng trình phân tích cú pháp PowerShell chính thức khi chạy `TEST-LOCAL.ps1` trên Windows.
- Sau khi chạy `SETUP-FREE.ps1`, `TEST-ONLINE.ps1` sẽ kiểm tra Firestore API, database, hai site Hosting, HTTP 200 và document game mẫu.
- Đăng nhập Google trong trình duyệt thật cần thử thủ công một lần sau khi triển khai.

## Cách cập nhật dự án đang có

1. Giải nén ZIP bản vá vào **`D:\EduGameHub-Free`**, không phải `D:\EduGameHub-Free\EduGameHub` nếu trong ZIP đã có thư mục `EduGameHub`.
2. **Không xóa `.edugame-setup.json`** và không tạo project mới.
3. Chạy `TEST-LOCAL.ps1`, sau đó chạy lại `SETUP-FREE.ps1 -ProjectId "edugamehub-free-41819"`.
4. Khi hoàn tất, chạy `TEST-ONLINE.ps1`.
