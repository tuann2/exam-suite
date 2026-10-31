# Changelog bản iOS

Theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), phiên bản theo semver; tag `ios-v<phiên bản>` (tag `v*`
là của bản macOS). Bản macOS ghi ở `CHANGELOG.md`, bản Android ở `android/CHANGELOG.md`. Cài đặt: `docs/install-ios.md`.

## [Unreleased]

## [0.1.0] – chưa phát hành (chờ cổng GI3)

Bản iPhone đầu tiên của Exam Suite, bản **Học viên**: iOS 18 trở lên, giao diện iPhone, cài qua Xcode bằng Apple ID miễn
phí (bản cài chạy 7 ngày rồi cài lại). Hành vi theo tài liệu của bản macOS; chỗ khác ghi ở bảng "Chỗ iOS khác macOS" của
`docs/product/plan-ios-v1.md`.

### Added

- **Thư viện** dạng danh sách: Tất cả đề, Gần đây, Lịch sử thi; tìm, sắp xếp; trạng thái file bằng biểu tượng và chữ,
  **Tìm file…**; kéo xuống để làm mới; vuốt để **Xoá khỏi thư viện** kèm **Hoàn tác**; hai đề mẫu kèm dải chào mừng;
  màn **Giới thiệu** (phiên bản, giấy phép Apache-2.0, NOTICE, giấy phép của ZIPFoundation).
- **Vào đề**: nút **Thêm đề** (chọn file trong app Tệp, dùng file tại chỗ như bản macOS) và mở `.exam` từ app khác (Zalo,
  Mail, AirDrop… qua Chia sẻ hay Mở bằng: iOS chép file vào app). Cùng đề, khác file thì hỏi **Dùng file mới** / **Huỷ**.
- **Trước khi thi, Làm bài, Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại** dùng chung model với bản
  macOS (chấm điểm, chọn câu có seed, `hideAnswers`, câu đã sửa sau lần thi, Kiểm tra đáp án ở Luyện tập, đánh dấu câu,
  bảng câu hỏi, đồng hồ và cảnh báo 5/1 phút, so với lần trước, bộ lọc của Xem lại).
- **Riêng iPhone**: app xuống nền khi đang làm bài thì tự tạm dừng ("Đã tạm dừng vì bạn rời app"), thời gian ở nền không bị
  trừ; nút Quay lại ở màn làm bài hỏi "Bỏ bài?", vuốt để quay lại bị tắt. Không lưu bài dở: iOS dừng app ở nền thì bài
  đang làm mất (như bản macOS khi đóng cửa sổ).
- Tiếng Việt và tiếng Anh (theo ngôn ngữ của iPhone hoặc ngôn ngữ riêng của app trong Cài đặt); sáng/tối theo hệ thống;
  cỡ chữ theo Dynamic Type, bố cục dùng được tới cỡ `accessibility1`; VoiceOver đọc được các điều khiển; màu Đúng/Sai/cảnh
  báo cùng bảng màu đạt tương phản của bản macOS.
