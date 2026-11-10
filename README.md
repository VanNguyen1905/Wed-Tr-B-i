# 🎮 EduGame Hub — Kho trò chơi tương tác dành cho giáo viên

<p align="center">
  <strong>Biến giờ trả bài thành giờ chơi thú vị</strong><br>
  Nền tảng giúp thầy cô tìm kiếm, chơi trực tuyến và tải về các trò chơi HTML phục vụ giảng dạy.
</p>

<p align="center">
  <a href="https://github.com/VanNguyen1905/Wed-Tr-B-i"><img src="https://img.shields.io/badge/GitHub-Source_Code-181717?logo=github" alt="GitHub"></a>
  <img src="https://img.shields.io/badge/Firebase-Spark_Free-FFCA28?logo=firebase&logoColor=black" alt="Firebase Spark">
  <img src="https://img.shields.io/badge/Frontend-HTML%20%7C%20CSS%20%7C%20JavaScript-2563EB" alt="HTML CSS JavaScript">
  <img src="https://img.shields.io/badge/Version-1.7.1-10B981" alt="Version 1.7.1">
</p>

## 📖 Giới thiệu

**EduGame Hub** là thư viện trò chơi giáo dục trực tuyến dành cho giáo viên, có giao diện tiếng Việt và hoạt động trên trình duyệt. Thầy cô có thể tìm trò chơi theo từ khóa/danh mục, chơi ngay trong cửa sổ của website, mở trò chơi ở tab riêng hoặc tải tệp HTML về máy.

Dự án sử dụng **Firebase Spark (gói miễn phí)**. Nội dung game và giao diện được lưu trên **hai Firebase Hosting site tách biệt**; thông tin như tên game, mô tả, danh mục và trạng thái công khai được lưu ở **Cloud Firestore**. Người quản trị đăng nhập bằng Google để bật/tắt trạng thái hiển thị trong thư viện.

> **Phạm vi bản hiện hành:** Chạy bằng Firebase Hosting + Firestore + Authentication; **không cần chạy backend Java/Spring Boot**, Cloud Run hay Firebase Storage. Chi phí và hạn mức sử dụng phụ thuộc chính sách Firebase Spark tại thời điểm triển khai.

## ✨ Chức năng chính

| Đối tượng | Chức năng |
| --- | --- |
| Giáo viên / khách truy cập | Xem danh sách game công khai, tìm kiếm, lọc theo danh mục, chơi game trực tuyến, mở tab riêng, tải tệp HTML. |
| Quản trị viên | Đăng nhập Google, xem trò chơi, ẩn/hiện trò chơi trong danh mục. |
| Chủ dự án qua PowerShell | Thiết lập hệ thống Firebase, xuất bản game HTML, gỡ game, kiểm thử trước và sau triển khai. |

### Luồng hoạt động

```text
Người dùng → Website (Firebase Hosting: app)
                    ├─ Đọc danh mục → Cloud Firestore (games)
                    ├─ Đăng nhập quản trị → Firebase Authentication (Google)
                    └─ Chơi / tải game → Firebase Hosting: games (origin riêng)

Chủ dự án → PowerShell + Firebase CLI / gcloud
             ├─ Đăng file HTML lên Hosting: games
             └─ Ghi metadata vào Firestore bằng quyền Google Cloud IAM
```

## 🛠️ Công nghệ sử dụng

- **Frontend:** HTML5, CSS3, JavaScript (ES Modules), giao diện responsive.
- **Firebase:** Hosting (hai site), Cloud Firestore, Authentication (Google Sign-In).
- **Quản trị và triển khai:** Windows PowerShell 5.1, Firebase CLI, Google Cloud CLI.
- **Game mẫu:** `sample/duck-grand-prix-pro.html`.
- **Mã nguồn lưu trữ:** Git và GitHub.

Thư mục `backend/` chứa **mã nguồn Java Spring Boot cũ chỉ để tham khảo**; không được dùng trong cấu hình Firebase Spark hiện tại.

## 📁 Cấu trúc dự án

```text
EduGameHub/
├── frontend/
│   ├── index.html             # Trang thư viện game
│   ├── style.css              # Giao diện và responsive
│   ├── main.js                # Tìm kiếm, lọc, chơi, đăng nhập, quản trị
│   └── firebase-config.js     # Cấu hình web Firebase (được setup cập nhật)
├── game-host/
│   ├── index.html
│   └── 404.html               # Máy chủ game tách biệt
├── sample/
│   └── duck-grand-prix-pro.html
├── lib/
│   └── Setup-Helpers.ps1      # Hàm hỗ trợ các lệnh setup
├── backend/                   # Backend Spring Boot phiên bản cũ (không chạy)
├── SETUP-FREE.ps1             # Thiết lập hệ thống Firebase Spark
├── CONTINUE-SAFE.ps1          # Kiểm thử, tiếp tục setup, kiểm tra online
├── PUBLISH-GAME.ps1           # Đăng game HTML
├── REMOVE-GAME.ps1            # Gỡ game theo slug
├── TEST-LOCAL.ps1             # Kiểm thử cục bộ, không truy cập cloud
├── TEST-ONLINE.ps1            # Kiểm thử Firebase sau triển khai
├── firebase.json              # Hai target hosting: app và games
├── firestore.rules            # Quy tắc quyền truy cập Firestore
├── README-FREE.md             # Hướng dẫn Firebase Spark chi tiết
└── README.md
```

## 🚀 Bắt đầu trên Windows

### 1. Yêu cầu

- Windows với **PowerShell 5.1+** (các script được viết cho Windows PowerShell).
- **Git**, **Node.js LTS** và npm.
- **Firebase CLI**, **Google Cloud CLI (gcloud)**.
- Tài khoản Google có quyền quản lý Firebase project tương ứng.

Cài các công cụ cần thiết nếu máy chưa có:

```powershell
winget install -e --id Git.Git
winget install -e --id OpenJS.NodeJS.LTS
winget install -e --id Google.CloudSDK
npm install -g firebase-tools
```

Đóng/mở lại Terminal sau khi cài công cụ nếu hệ thống chưa nhận lệnh `git`, `npm`, `firebase` hoặc `gcloud`.

### 2. Lấy mã nguồn

```powershell
git clone https://github.com/VanNguyen1905/Wed-Tr-B-i.git
cd Wed-Tr-B-i
```

Hoặc giải nén gói dự án và mở **thư mục `EduGameHub`** trong VS Code, rồi chọn **Terminal → New Terminal → PowerShell**.

### 3. Kiểm tra mã nguồn trước khi setup

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-LOCAL.ps1
```

Lệnh này kiểm tra nội bộ, không deploy hay truy cập Firebase thật. Nếu có lỗi, xử lý lỗi trước khi triển khai.

### 4. Cấu hình và triển khai Firebase Spark

Với Firebase project đã được dự án sử dụng trước đó:

```powershell
firebase login
gcloud auth login
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\SETUP-FREE.ps1 -ProjectId "edugamehub-free-41819"
```

Hoặc dùng quy trình tiếp tục/kiểm tra kết hợp, **chỉ khi đang muốn làm việc trên Firebase project được cấu hình sẵn**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CONTINUE-SAFE.ps1
```

**Lưu ý:** Các lệnh setup có thể thay đổi tài nguyên của Firebase project (Hosting/Firestore/rules). Không chạy nếu chưa kiểm tra tài khoản và project đích. Bật nhà cung cấp đăng nhập **Google** trong Firebase Console → Authentication → Sign-in method nếu script yêu cầu.

Kiểm tra kết quả:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-ONLINE.ps1
```

Script sẽ kiểm tra dịch vụ và hai Hosting site. Tên miền chính xác được xác định từ cấu hình Firebase của dự án.

## 🕹️ Đăng một trò chơi mới

Hệ thống hỗ trợ **tệp `.html` độc lập, tối đa 5 MB** (không hỗ trợ game nhiều tệp hoặc ZIP trong quy trình hiện tại).

```powershell
.\PUBLISH-GAME.ps1 -File "D:\Games\tro-choi.html" -Title "Đố vui kiến thức" -Category "Trắc nghiệm" -Description "Trò chơi dùng trong tiết ôn tập"
```

Đặt slug tùy chọn:

```powershell
.\PUBLISH-GAME.ps1 -File "D:\Games\tro-choi.html" -Title "Đố vui kiến thức" -Slug "do-vui-kien-thuc" -Category "Đố vui"
```

Script tạo đường dẫn chơi/tải, triển khai riêng hosting game và ghi metadata Firestore. Người dùng sẽ thấy game khi metadata có trạng thái công khai.

### Gỡ game

```powershell
.\REMOVE-GAME.ps1 -Slug "do-vui-kien-thuc"
```

Script yêu cầu nhập `XOA` để xác nhận. **Ẩn game ở trang quản trị chỉ ẩn khỏi danh mục, không chặn URL truy cập trực tiếp.**

## ☁️ Đưa mã nguồn lên GitHub bằng Terminal

Repository: **[VanNguyen1905/Wed-Tr-B-i](https://github.com/VanNguyen1905/Wed-Tr-B-i)**.

Mở PowerShell **tại thư mục `EduGameHub`** chứa `README.md`, `frontend/` và `firebase.json`, rồi chạy lần lượt:

```powershell
git init
git add .
git commit -m "Initial commit: EduGame Hub"
git branch -M main
git remote add origin https://github.com/VanNguyen1905/Wed-Tr-B-i.git
git push -u origin main
```

Nếu `git remote add origin` báo remote đã tồn tại, kiểm tra bằng `git remote -v` rồi dùng `git remote set-url origin https://github.com/VanNguyen1905/Wed-Tr-B-i.git` **chỉ khi muốn thay remote hiện tại**.

Những lần cập nhật tiếp theo:

```powershell
git add .
git commit -m "Update EduGame Hub"
git push
```

> **Quan trọng:** Đẩy code lên GitHub **không đồng nghĩa deploy Firebase**. Muốn cập nhật website đã cấu hình thì phải deploy Firebase theo đúng quy trình dự án.

## 🔐 Bảo mật và hạn chế

- Không commit `.edugame-setup.json`, `.firebaserc`, thư mục `.firebase/`, tệp `.env` hoặc khóa dịch vụ. `.gitignore` đã loại trừ các tệp cục bộ phổ biến.
- `frontend/firebase-config.js` chứa cấu hình Firebase Web (dự kiến là thông tin client công khai), **không phải private key**; quyền truy cập phải được kiểm soát qua Authentication và Firestore Security Rules.
- Website game dùng **Hosting site có origin riêng** với giao diện quản trị; chỉ xuất bản game HTML đã kiểm tra.
- Quy tắc Firestore chỉ cho khách xem game công khai; chỉ quản trị viên hợp lệ được cập nhật trạng thái `published`.
- Gói Firebase Spark có **hạn mức dịch vụ**; không bảo đảm hoạt động không giới hạn.
- Game HTML phụ thuộc vào thư viện hoặc font từ CDN có thể không hoạt động hoàn toàn offline.
- Backend Java trong `backend/` là mã cũ, không cần chạy hoặc deploy cho phiên bản này.

## 📚 Tài liệu trong dự án

- [`README-FREE.md`](README-FREE.md): hướng dẫn setup, xuất bản, phân quyền và vận hành Firebase Spark.
- [`HUONG-DAN-v1.7.txt`](HUONG-DAN-v1.7.txt): các bước kiểm tra/tiếp tục setup.
- [`BAN-VA-v1.7.1.txt`](BAN-VA-v1.7.1.txt): các điều chỉnh mới nhất trong mã nguồn kèm ZIP.
- [`KIEM-THU-v1.4.md`](KIEM-THU-v1.4.md): ghi chú kiểm thử ở phiên bản trước.

---

<p align="center"><b>EduGame Hub</b> · Học tập sáng tạo · Dành cho giáo viên</p>
