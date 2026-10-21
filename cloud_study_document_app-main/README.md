# Ứng Dụng Quản Lý Tài Liệu Học Tập (Study Document App)
### Kiến Trúc Cashew Local-First Tích Hợp Google Firebase Cloud

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20Cloud-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Architecture](https://img.shields.io/badge/Architecture-Cashew%20Local--First-9C27B0)](https://github.com/pvhung2112/cloud_study_document_app)
[![Cloud Ready](https://img.shields.io/badge/Cloud-Ready%20%26%20Sync-10B981)](https://github.com/pvhung2112/cloud_study_document_app)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 👥 Danh Sách Nhóm Sinh Viên Thực Hiện

| STT | Họ và Tên | Mã Sinh Viên | Vai Trò | Nhiệm Vụ Phụ Trách |
| :---: | :--- | :---: | :--- | :--- |
| **1** | **Phạm Văn Hưng** | `2351170598` | **Trưởng nhóm / Core Architect** | Cấu hình dự án Flutter, hoạch định kiến trúc Local-First, tích hợp Google Firebase REST API, điều phối luồng đồng bộ dữ liệu & kiểm soát mã nguồn. |
| **2** | **Trịnh Trung Kiên** | `2251172396` | **Thành viên / Frontend Developer** | Thiết kế giao diện UI/UX theo ngôn ngữ Cashew Design, xây dựng màn hình Kho tài liệu học tập (3 Tabs: Bài giảng, Bài tập, Tham khảo) & Danh mục môn học. |
| **3** | **Đỗ Việt Tiến** | `2251243452` | **Thành viên / Frontend Developer** | Thiết kế giao diện Tìm kiếm thời gian thực, Bộ lọc phân loại đa tiêu chí (theo môn, tags, độ ưu tiên) & Hộp thoại Cloud Firebase Sync Modal. |
| **4** | **Cao Đức Đạo** | `2351170581` | **Thành viên / Backend & Database** | Quản lý cơ sở dữ liệu Local-First (DAO Layer, Reactive Streams), thiết lập cấu trúc Cloud Firestore & kiểm soát bảo mật Firebase Security Rules. |
| **5** | **Trương Tuấn Hải** | `2351170590` | **Thành viên / Cloud Research & Documentation** | Nghiên cứu nền tảng Google Firebase (Auth & Storage), xây dựng Slide thuyết trình nhóm, viết tài liệu hướng dẫn Setup & biên soạn Báo cáo Kỹ thuật. |

---

## 🌟 Tổng Quan Dự Án

**Study Document App** là hệ thống quản lý học tập cá nhân hóa được thiết kế dựa trên triết lý **Local-First Architecture** học hỏi từ ứng dụng mã nguồn mở nổi tiếng **Cashew**, kết hợp nâng cấp dịch vụ đám mây **Google Firebase Cloud (Firestore REST API & Authentication)**.

### Mục Tiêu Cốt Lõi:
1. **Trải nghiệm mượt mà không độ trễ (Zero-latency UI):** Mọi thao tác CRUD tài liệu, môn học, mục tiêu đều được phản hồi tức thì trên bộ nhớ cục bộ (Local-First).
2. **Khả năng hoạt động Offline 100%:** Sinh viên có thể tạo, chỉnh sửa và tra cứu tài liệu ngay cả khi mất mạng internet.
3. **Đồng bộ Đám mây Tin cậy (Two-Way Cloud Sync):** Khi có kết nối mạng, `StudySyncClient` tự động đồng bộ 2 chiều với Google Cloud Firestore, giải quyết xung đột theo nguyên tắc *Last-Write-Wins (LWW)*.
4. **Đa nền tảng vượt trội:** Sử dụng Firestore REST API thuần qua `package:http`, tương thích hoàn hảo trên Web, Windows Desktop, macOS, Linux và Mobile mà không phụ thuộc platform native Firebase SDK.

---

## 🏛️ Sơ Đồ Kiến Trúc Hệ Thống

![Sơ đồ kiến trúc Cloud Firebase](cloud_architecture_diagram.jpg)

### 📐 Bản Vẽ Kiến Trúc Hệ Thống (Mermaid Architecture Diagram)

```mermaid
graph TB
    classDef clientClass fill:#d0e1fd,stroke:#4a86e8,stroke-width:2px,color:#000;
    classDef authClass fill:#ffe599,stroke:#d6b656,stroke-width:2px,color:#000;
    classDef dbClass fill:#d9ead3,stroke:#6aa84f,stroke-width:2px,color:#000;
    classDef storageClass fill:#fce5cd,stroke:#e69138,stroke-width:2px,color:#000;
    classDef cdnClass fill:#e1d5e7,stroke:#9673a6,stroke-width:2px,color:#000;

    subgraph ClientDevice [" 📱 THIẾT BỊ NGƯỜI DÙNG (LOCAL-FIRST CLIENT) "]
        UI["Flutter Presentation Layer<br/>(Tabs Bài giảng, Bài tập, Lọc Môn học)"]:::clientClass
        LocalStore[("Local SQLite / In-Memory Store<br/>(Nguồn sự thật tại máy khách)")]:::clientClass
        SyncClient["Local-First Sync Engine<br/>(Hàng đợi đồng bộ nền & Giải quyết xung đột)"]:::clientClass
    end

    subgraph FirebaseCloud [" ☁️ GOOGLE FIREBASE CLOUD ECOSYSTEM "]
        Auth["Firebase Authentication<br/>(Google Sign-In OAuth 2.0 / JWT Token)"]:::authClass
        Firestore[("Cloud Firestore NoSQL<br/>(Tài liệu, Môn học, Trạng thái, Metadata)")]:::dbClass
        Storage["Firebase Cloud Storage<br/>(Chứa File PDF Slide, DOCX, ZIP Bài tập)"]:::storageClass
        CDN["Google Global Cloud CDN<br/>(Bộ nhớ đệm phân phối file tốc độ cao)"]:::cdnClass
    end

    UI -->|"1. Thao tác ghi/sửa tức thì"| LocalStore
    LocalStore -->|"2. Lắng nghe thay đổi"| SyncClient
    SyncClient -->|"3. Gửi Token xác thực"| Auth
    Auth -->|"4. Cấp quyền truy cập (UID/Claims)"| SyncClient
    SyncClient -->|"5. Đồng bộ Metadata JSON hai chiều"| Firestore
    UI -->|"6. Tải tệp tài liệu lên trực tiếp"| Storage
    Storage -->|"7. Phân phối tệp qua CDN"| CDN
    CDN -->|"8. Tải tệp xuống nhanh chóng"| UI
```


### Phân Tách 4 Tầng Kiến Trúc Chuẩn Cashew:

```
study_document_app/
├── lib/
│   ├── struct/                 # TẦNG 1: Domain Entities & Core Services
│   │   ├── studyDocument.dart           # Thực thể Tài liệu học tập (Lectures, Assignments, References)
│   │   ├── studyCourse.dart             # Thực thể Môn học & màu nhận diện
│   │   ├── studyGoal.dart               # Thực thể Mục tiêu học tập & tiến độ
│   │   ├── studySyncClient.dart         # Client đồng bộ Firebase Cloud Firestore REST API
│   │   ├── firebaseCloudStorageService.dart # Dịch vụ quản lý tệp đính kèm Cloud
│   │   └── reminderService.dart         # Dịch vụ nhắc hạn nộp bài tập
│   ├── database/               # TẦNG 2: Data Access Layer (DAO & Reactive Streams)
│   │   ├── documentDao.dart             # Truy xuất tài liệu, tìm kiếm, lọc, Streams
│   │   ├── courseDao.dart               # Quản lý môn học, thống kê tài liệu môn
│   │   └── goalDao.dart                 # Quản lý mục tiêu học tập
│   ├── widgets/                # TẦNG 3: Reusable UI Widgets (Cashew Design System)
│   │   ├── studyDocumentCard.dart       # Thẻ tài liệu bo góc 16px, icon phân loại
│   │   ├── studySidebarNav.dart         # Thanh điều hướng Sidebar viền hồng đặc trưng
│   │   └── studyFilterChips.dart        # Thanh lọc phân loại mềm mại
│   └── pages/                  # TẦNG 4: Business Pages & Workflows
│       ├── studyDocumentsPage.dart      # Kho tài liệu (3 Tabs), Nút đồng bộ Cloud & Modal
│       ├── studyCoursesPage.dart        # Màn hình quản lý môn học
│       ├── studyGoalsPage.dart          # Màn hình tiến độ mục tiêu
│       └── studySearchFilterPage.dart   # Màn hình tìm kiếm đa tiêu chí
└── test/                       # BỘ KIỂM THỬ ĐƠN VỊ
```

---

## 🚀 Các Tính Năng Nổi Bật

- **📑 Quản lý Kho Tài liệu Học tập:** Phân loại theo 3 nhóm cốt lõi: *Bài giảng (Lectures)*, *Bài tập (Assignments)*, và *Tài liệu Tham khảo (References)*.
- **🔍 Tìm kiếm Thời Gian Thực & Bộ Lọc Đa Tiêu Chí:** Tìm theo từ khóa trong tiêu đề, nội dung, mã môn học, hoặc lọc theo thẻ tags và cờ ghim ưu tiên.
- **☁️ Đồng bộ Google Cloud Firestore:**
  - Kết nối trực tiếp đến project Firebase: `study-document-cloud`.
  - Hộp thoại **Firebase Cloud Sync Modal** hiển thị trực quan trạng thái kết nối, số tài liệu trên Cloud, thời gian đồng bộ gần nhất và nút kích hoạt đồng bộ tức thì.
- **🛡️ Cơ chế Hoạt động Ngoại tuyến (Offline Fallback):** Hệ thống hàng đợi đồng bộ (`SyncQueue`) tự động lưu lại các bản ghi tạo mới khi offline và đẩy lên Cloud ngay khi mạng hoạt động lại.
- **🎯 Quản lý Mục Tiêu & Môn Học:** Gắn môn học tương ứng kèm màu sắc nhận diện, theo dõi tiến độ hoàn thành bài tập theo từng mục tiêu học kỳ.

---

## 📦 Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

### Yêu Cầu Môi Trường:
- **Flutter SDK:** >= 3.0.0
- **Dart SDK:** >= 3.0.0
- Trình duyệt Chrome hoặc môi trường Windows Desktop

### Các Bước Thực Hiện:

```powershell
# 1. Clone repository về máy
git clone https://github.com/pvhung2112/cloud_study_document_app.git
cd cloud_study_document_app

# 2. Cài đặt các gói phụ thuộc
flutter pub get

# 3. Kiểm tra chất lượng mã nguồn (Linter)
flutter analyze

# 4. Khởi chạy ứng dụng trên Web Chrome
flutter run -d chrome

# Hoặc khởi chạy trên Windows Desktop
flutter run -d windows
```

---

## 📑 Báo Cáo Kỹ Thuật & Ấn Phẩm Thuyết Trình

Toàn bộ tài liệu giải trình kỹ thuật và slide nhóm được đính kèm đầy đủ trong dự án:

1. 🎨 **Slide Thuyết Trình (Canva chính thức):**  
   👉 [Slide thuyết trình](https://www.canva.com/design/DAHXgJp2D-Q/XdIccVLAMSyM2NgV1ar3zw/edit?ui=eyJBIjp7fX0)

2. 📄 **Báo Cáo Tích Hợp Google Cloud Firebase:**  
   👉 [`BAO_CAO_TICH_HOP_CLOUD_FIREBASE.md`](./BAO_CAO_TICH_HOP_CLOUD_FIREBASE.md)  
   *(Giải thích chi tiết các mục phân tích kiến trúc, điểm nghẽn hạ tầng, lựa chọn dịch vụ Cloud, giải thuật đồng bộ 2 chiều, đánh giá chi phí - bảo mật - hiệu suất và hướng dẫn setup).*

3. 🖥️ **Slide Thuyết Trình Nhóm Tương Tác Offline (HTML/JS):**  
   👉 [`SLIDE_THUYET_TRINH_FIREBASE.html`](./SLIDE_THUYET_TRINH_FIREBASE.html)  
   *(Trình chiếu trực tiếp trên mọi trình duyệt: hiệu ứng chuyển slide, phím mũi tên `←` `→`, giao diện hiện đại phục vụ báo cáo).*

4. 📝 **Đề Cương Nội Dung Slide (Markdown):**  
   👉 [`SLIDE_THUYET_TRINH_FIREBASE_CLOUD.md`](./SLIDE_THUYET_TRINH_FIREBASE_CLOUD.md)

---

## ⚖️ Giấy Phép & Bản Quyền
Dự án được phát triển phục vụ mục đích học tập và nghiên cứu môn học theo giấy phép [MIT License](LICENSE).