# EduGame Hub — Firebase Spark Free (v1.4)

**Mục tiêu:** Tạo website thư viện game cho giáo viên và tự xuất bản game HTML qua PowerShell, **không nhập thẻ, không liên kết Cloud Billing**.

Bản v1.3 dùng:

- Firebase Hosting (2 site trong cùng project: 1 site giao diện, 1 site game tách origin).
- Cloud Firestore (chỉ lưu tiêu đề, mô tả, danh mục, trạng thái hiển thị).
- Firebase Authentication/Google Sign-In (đăng nhập để bật/tắt hiển thị trong danh mục).
- File HTML được copy trực tiếp vào `game-host/play/` và `game-host/download/`, sau đó triển khai bằng Firebase CLI. Không dùng Firebase Storage.

**Không chạy Java backend** trong bản Free. Thư mục `backend/` được giữ nguyên để tham khảo/khôi phục bản Blaze trong tương lai; không phải cấu phần đang chạy của website này.

## Cài đặt chỉ với Terminal Windows

Mở PowerShell trong thư mục `EduGameHub`:

```powershell
cd D:\EduGameHub-Free\EduGameHub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SETUP-FREE.ps1
```

Script tự làm các bước: kiểm tra Google Cloud CLI/Firebase CLI, yêu cầu đăng nhập Google nếu cần, tạo/reuse Firebase Project (Spark), tạo **default Hosting site trước** (quy định mới từ 15/10/2026), tự bật Cloud Firestore API + Identity Toolkit API, chờ kích hoạt, kiểm tra/tạo Firestore Native, tạo Web App và bật Google Sign-In, cấp Firestore rules, tạo site game thứ hai, deploy Hosting, đăng mẫu **Đua vịt Grand Prix Pro** rồi mở web.

Đăng nhập Google một lần trên trình duyệt theo quy trình của Google có thể vẫn cần; đó **không** phải nhập thẻ thanh toán. Tài khoản cần đủ quyền tạo Firebase Project; nếu đã chạm giới hạn dự án miễn phí, script không thể vượt qua hạn mức.

Có thể chạy lại cùng lệnh nếu xảy ra lỗi; Project ID được lưu ở `.edugame-setup.json`.

**Nếu chưa cài công cụ**, sử dụng:

```powershell
winget install -e --id OpenJS.NodeJS.LTS
winget install -e --id Google.CloudSDK
npm install -g firebase-tools
```

Đóng và mở lại Terminal nếu lệnh `npm`, `firebase` hoặc `gcloud` chưa nhận sau khi cài.

## Đăng game HTML mới bằng Terminal

```powershell
cd D:\EduGameHub-Free\EduGameHub
.\PUBLISH-GAME.ps1 -File "G:\Drive của tôi\my-game.html" -Title "Game trả bài mới" -Category "Đố vui" -Description "Chơi bằng máy chiếu"
```

Để cố định slug:

```powershell
.\PUBLISH-GAME.ps1 -File "G:\Drive của tôi\my-game.html" -Title "Game trả bài mới" -Slug "game-tra-bai" -Category "Trắc nghiệm"
```

Script từ chối file không phải `.html`, file >5 MB, tạo bản `play/` và `download/`, deploy **chỉ site game**, rồi ghi metadata trong Firestore REST API bằng tài khoản `gcloud` (Google Cloud IAM, không dùng private key trong code). `game-host/download/` gửi `Content-Disposition: attachment` giúp trình duyệt tải file thay vì mở game.

Thêm file HTML mới **không cần biên dịch Java, không cần Firebase Storage**.

## Cách quản trị

- Khách/giáo viên: tìm game, chơi trong iframe, mở tab chơi riêng, tải HTML.
- Admin: nhấn `Quản trị` trên website, Google Sign-In bằng đúng email mà `SETUP-FREE.ps1` đã dùng. Trong Admin có thể ẩn/hiện game khỏi danh mục.
- **Ẩn khỏi danh mục không xóa file đã upload**: ai có link game trực tiếp vẫn có thể mở. Muốn gỡ file khỏi hosting, xóa `game-host/play/<slug>.html` và `game-host/download/<slug>.html`, sau đó chạy `firebase deploy --only hosting:games --project <Project-ID>`. Metadata còn trong Firestore; để ẩn ở giao diện Admin, chọn “Ẩn khỏi danh mục”.
- `PUBLISH-GAME.ps1` chỉ tin cậy quyền Google Cloud của người dùng đang đăng nhập, giáo viên không được upload trực tiếp.

## Kiểm tra sau khi triển khai

- Truy cập địa chỉ được script in: `https://<APP-SITE-ID>.web.app`.
- Danh mục phải có **Đua vịt Grand Prix Pro**.
- `Chơi ngay`: mở iframe có game; game chạy trên origin riêng `https://<GAMES-SITE-ID>.web.app`.
- `Tải về`: tải file HTML. File game mẫu có tải Tailwind và Google Fonts từ CDN nên chơi offline hoàn toàn có thể thiếu style/font.
- `Quản trị`: Google popup xuất hiện, admin được cấp quyền ẩn/hiện danh mục.

Nếu truy cập ngay sau lần deploy đầu bị 404, chờ DNS/Hosting site mới lan truyền, sau đó tải lại. Nếu `auth/unauthorized-domain`, kiểm tra cấu hình Firebase Auth đã được deploy và domain truy cập là domain được Firebase cấp.

## Bảo mật và hạn mức

- Không deploy `backend/` lên Cloud Run, không tạo Storage bucket và **không liên kết Cloud Billing**.
- Firestore Rules cho phép khách chỉ đọc `published == true`, chỉ admin có email đã xác minh mới có thể cập nhật trường `published`. Không cho client tạo hay xóa document.
- Chính Google Cloud IAM (tài khoản CLI sở hữu project) dùng để xuất bản HTML và metadata.
- Game chạy trên Hosting site khác origin với website quản trị. Chỉ đăng các game HTML do mình làm hoặc đã kiểm duyệt.
- Site game vẫn chứa mã HTML do admin publish, nên không nhận upload từ giáo viên hoặc người lạ.
- Tất cả tài nguyên dùng hạn mức miễn phí của Spark, **không phải không giới hạn**. Website có thể bị tạm ngưng hoạt động khi vượt quota Hosting/Firestore. Kiểm tra https://firebase.google.com/pricing.
- Chỉ hỗ trợ **game HTML một tệp**. Unity WebGL nhiều tệp/ZIP chưa được hỗ trợ bởi script đăng game này.

## Kiểm tra mã trước khi xuất bản

```powershell
firebase projects:list
Get-Content .\.edugame-setup.json
Get-Content .\frontend\firebase-config.js
```

Không đưa mã service-account JSON/private key lên GitHub hay gửi cho người khác. Firebase Web config là cấu hình public, nhưng không nên sửa quyền admin trong Firestore rules ngoài script.

## Lưu ý về việc chạy script

Bạn có thể dùng tên cũ `SETUP-ALL.ps1` — trong **bản v1.3** đây chỉ là lệnh gọi `SETUP-FREE.ps1`, hoàn toàn không chứa quy trình liên kết Billing. **Đừng chạy `SETUP-ALL.ps1` của file ZIP v1.1 cũ**, vì nó triển khai Blaze/Cloud Run.

## Gỡ game vĩnh viễn (Terminal)

```powershell
.\REMOVE-GAME.ps1 -Slug "duck-grand-prix-pro"
```

Script yêu cầu gõ `XOA` để xác nhận, sau đó xóa hai file khỏi Hosting và document Firestore tương ứng. Nếu xảy ra lỗi sau khi xóa file cục bộ, có thể chạy lại lệnh để tiếp tục gỡ metadata. Xóa không thể hoàn tác trừ khi còn bản HTML trên máy để đăng lại.


## Luu y v1.4

Da thay the viec doc Hosting sites, Web Apps va Web SDK config qua `gcloud` REST bang Firebase CLI. Firebase CLI phai dang nhap dung project (xem `firebase projects:list`). `PUBLISH-GAME.ps1` van dung Google Cloud OAuth de ghi metadata; neu Firestore REST tra 403, xem `gcloud auth list` va thong tin loi chi tiet. Khong phai moi loi 403 deu do Billing.


## Quan trong v1.4: Fix loi Firestore 403 khi project moi

- Script goi `gcloud services enable firestore.googleapis.com identitytoolkit.googleapis.com --project PROJECT_ID` TRUOC khi truy van/tao database.
- Sau do goi `gcloud firestore databases list --project PROJECT_ID --format=json`; neu API chua kich hoat xong, script cho va thu lai.
- Neu `(default)` da co, **khong tao trung**. Script giu `.edugame-setup.json` va 2 Hosting sites hien tai.
- Neu Google tra loi phan quyen (`PERMISSION_DENIED`), script hien loi cua `gcloud` de xu ly, khong nghi nham la database chua ton tai.
- Khong co thao tac `billing accounts` hay lien ket Billing.

### Kiem thu truoc khi chay

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-LOCAL.ps1
```

Kiem tra file, JSON, PowerShell AST syntax, JavaScript syntax, tham chieu HTML, Firestore rules, va lenh bat API. Khong goi cloud.

### Kiem thu sau khi trien khai

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-ONLINE.ps1
```

Kiem tra Firebase Firestore, Hosting sites va truy cap HTTP 200. Can dang nhap Google/Firebase CLI.

### Gioi han kiem thu

Cac kiem thu tai may co the kiem tra ma nguon va giao dien, nhung khong thay the cac thao tac tren tai khoan Firebase va quyen IAM thuc te. Script khong the tu dong bo qua quota, quyen Google hay yeu cau chap nhan dieu khoan cua Google.
