# 📊 BỘ SLIDE THUYẾT TRÌNH: TÌM HIỂU VỀ FIREBASE & PHƯƠNG ÁN TÍCH HỢP CLOUD
## Dành cho nhóm sinh viên thuyết trình Bài tập Lớn / Báo cáo Chuyên đề

- **Chủ đề:** Tích hợp Điện toán Đám mây (Google Firebase) cho Hệ thống Quản lý Tài liệu Học tập
- **Slide thuyết trình (Canva chính thức):** [https://www.canva.com/design/DAHXgJp2D-Q/XdIccVLAMSyM2NgV1ar3zw/edit?ui=eyJBIjp7fX0](https://www.canva.com/design/DAHXgJp2D-Q/XdIccVLAMSyM2NgV1ar3zw/edit?ui=eyJBIjp7fX0)
- **Ứng dụng triển khai:** `study_document_app` (Kiến trúc Cashew Local-First)
- **Kho lưu trữ GitHub:** [https://github.com/pvhung2112/cloud_study_document_app](https://github.com/pvhung2112/cloud_study_document_app)
- **Công nghệ chính:** Flutter • Firebase Authentication (Google Sign-In) • Cloud Firestore • Firebase Cloud Storage
- **Định dạng:** 12 Trang Slide hoàn chỉnh (Nội dung trình chiếu + Gợi ý hình ảnh + Lời thoại thuyết trình)

---

## 👥 DANH SÁCH NHÓM SINH VIÊN THỰC HIỆN

| STT | Họ và Tên | Mã Sinh Viên | Vai Trò | Nhiệm Vụ Phụ Trách |
| :---: | :--- | :---: | :--- | :--- |
| **1** | **Phạm Văn Hưng** | `2351170598` | **Trưởng nhóm / Core Architect** | Cấu hình dự án Flutter, hoạch định kiến trúc Local-First, tích hợp Google Firebase REST API, điều phối luồng đồng bộ dữ liệu & kiểm soát mã nguồn. |
| **2** | **Trịnh Trung Kiên** | `2251172396` | **Thành viên / Frontend Developer** | Thiết kế giao diện UI/UX theo ngôn ngữ Cashew Design, xây dựng màn hình Kho tài liệu học tập (3 Tabs: Bài giảng, Bài tập, Tham khảo) & Danh mục môn học. |
| **3** | **Đỗ Việt Tiến** | `2251243452` | **Thành viên / Frontend Developer** | Thiết kế giao diện Tìm kiếm thời gian thực, Bộ lọc phân loại đa tiêu chí (theo môn, tags, độ ưu tiên) & Hộp thoại Cloud Firebase Sync Modal. |
| **4** | **Cao Đức Đạo** | `2351170581` | **Thành viên / Backend & Database** | Quản lý cơ sở dữ liệu Local-First (DAO Layer, Reactive Streams), thiết lập cấu trúc Cloud Firestore & kiểm soát bảo mật Firebase Security Rules. |
| **5** | **Trương Tuấn Hải** | `2351170590` | **Thành viên / Cloud Research & Documentation** | Nghiên cứu nền tảng Google Firebase (Auth & Storage), xây dựng Slide thuyết trình nhóm, viết tài liệu hướng dẫn Setup & biên soạn Báo cáo Kỹ thuật. |

---

## 📑 MỤC LỤC BỘ SLIDE
- **Slide 1:** Trang Tiêu đề & Danh sách Nhóm thực hiện
- **Slide 2:** 4 Thành phần Cốt lõi của Hệ thống Quản lý Tài liệu
- **Slide 3:** Các Điểm nghẽn của Hạ tầng Truyền thống (Local / On-Premise)
- **Slide 4:** Lựa chọn Mô hình Cloud & So sánh Giải pháp (AWS vs Azure vs Firebase)
- **Slide 5:** Sơ đồ Kiến trúc Hệ thống Hybrid Cloud (Local-First + Firebase)
- **Slide 6:** Mô tả Luồng Dữ liệu Đồng bộ 2 Chiều (Data Flow)
- **Slide 7:** Đánh giá Tác động: Bảo mật, Chi phí và Hiệu suất
- **Slide 8:** Tìm hiểu về Nền tảng Google Firebase (Hệ sinh thái BaaS)
- **Slide 9:** Quy trình Setup Firebase cho Flutter theo chuẩn Google (`flutterfire`)
- **Slide 10:** Cấu hình Dự án với Tài khoản Nhóm thực tế (`study-document-cloud`)
- **Slide 11:** Mã nguồn Tích hợp Đăng nhập Google & Tải tệp lên Storage
- **Slide 12:** Tổng kết, Demo & Hỏi đáp (Q&A)

---

### 🖥️ SLIDE 1: TRANG TIÊU ĐỀ & GIỚI THIỆU NHÓM
- **Tiêu đề lớn:** PHƯƠNG ÁN TÍCH HỢP CLOUD CHO HỆ THỐNG QUẢN LÝ TÀI LIỆU HỌC TẬP
- **Tiêu đề phụ:** Ứng dụng Nền tảng Google Firebase & Kiến trúc Hybrid Local-First
- **Slide thuyết trình (Canva):** [Mở slide Canva](https://www.canva.com/design/DAHXgJp2D-Q/XdIccVLAMSyM2NgV1ar3zw/edit?ui=eyJBIjp7fX0)
- **Thông tin nhóm:**
  - Nhóm sinh viên thực hiện: Phạm Văn Hưng, Trịnh Trung Kiên, Đỗ Việt Tiến, Cao Đức Đạo, Trương Tuấn Hải
  - Dự án GitHub: `pvhung2112/cloud_study_document_app`
- **Gợi ý hình ảnh:** Logo Flutter kết hợp logo Firebase Cloud, hình minh họa tài liệu học tập và đám mây kết nối.
- 🎙️ **Lời thoại thuyết trình (Speaker Notes):**
  > *"Kính chào Thầy/Cô và các bạn. Hôm nay nhóm em xin trình bày phương án chuyển đổi và tích hợp điện toán đám mây cho ứng dụng Quản lý Tài liệu Học tập. Toàn bộ slide thuyết trình chính thức đã được thiết kế hoàn thiện trên Canva."*
