# Changelog bản Android

Theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), phiên bản theo semver; tag `android-v<phiên bản>`. Bản
macOS ghi ở `CHANGELOG.md` gốc repo. Cách đóng APK: `docs/process/android-release.md`; cài đặt: `docs/install-android.md`.

## [Unreleased]

### Added

- Mở file **`.oef` của Open Exam Suite** (bản Protobuf, Open Exam Suite 4 trở lên) như `.exam`: Thêm đề, Mở bằng, Chia
  sẻ. App nhận file theo nội dung (không cần đuôi), chuyển thành đề lúc thêm, cùng đề và cùng mã định danh với bản macOS
  đọc cùng file; đề có lỗi thì báo lý do, không thêm. File `.oef` bản cũ báo cần lưu lại bằng Open Exam Suite.

### Changed

- File không phải gói `.exam` hay `.oef` báo "File không phải file đề (.exam hoặc .oef)".

## [0.1.0] – beta riêng

Bản Android đầu tiên của Exam Suite, bản **Học viên**: APK đăng ở GitHub Releases dạng Pre-release (không có trên Google
Play), ký bằng keystore của Nt0, Android 12 trở lên, giao diện điện thoại. `versionCode` 1. Chứng chỉ ký `CN=Nt0`, SHA-256
`8dfc356e7714effe98d9635269541302d5251b4ba5ff51460b5a39b51ea2ebe2` (mọi bản sau phải cùng chứng chỉ này). Nt0 dùng thử
bản debug trên Samsung Galaxy S24+ (đề gửi qua WhatsApp) ở cổng GA2, rồi bản release đã ký ở cổng GA3 (cùng máy; có nghe
TalkBack bốn màn chính): đạt.

### Added

- **Thư viện** dạng danh sách: tìm (không dấu), sắp xếp, Xoá khỏi thư viện có Hoàn tác, hai đề mẫu kèm dải chào mừng,
  Lịch sử thi và Kết quả của lần thi cũ.
- **Vào đề**: mở `.exam` từ app khác (Zalo, WhatsApp, Drive, File của bạn… qua Mở bằng hay Chia sẻ), nút Thêm đề; mở
  lại cùng đề (cùng mã định danh trong file) thì hỏi **Cập nhật đề** (giữ lịch sử thi). Đề được sao chép vào app.
- **Trước khi thi, Làm bài, Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại** theo đúng quy tắc của bản
  macOS (chấm điểm, chọn câu có seed, `hideAnswers`, câu đã sửa sau lần thi, Kiểm tra đáp án ở Luyện tập, đánh dấu câu,
  bảng câu hỏi, đồng hồ và cảnh báo 5/1 phút, so với lần trước, phần yếu nhất, bộ lọc của Xem lại). Lõi Kotlin cùng kết
  luận với lõi Swift trên bộ kiểm chung của repo.
- **Riêng điện thoại**: ra khỏi app khi đang làm bài thì tự tạm dừng và lưu bài dở; mở lại app (kể cả sau khi Android
  dừng app) về đúng câu ở trạng thái Tạm dừng. Mỗi lúc một bài: mở đề khác khi còn bài dở thì hỏi Tiếp tục đề cũ / Bỏ bài
  và làm đề mới / Huỷ.
- Tiếng Việt và tiếng Anh (theo ngôn ngữ của điện thoại, hoặc riêng cho app từ Android 13); sáng/tối theo hệ thống; cỡ
  chữ theo cài đặt của điện thoại tới 150%; TalkBack đọc được các điều khiển; màu Đúng/Sai/cảnh báo cùng bảng màu đạt
  tương phản của bản macOS.
- Đề 2.000 câu có ảnh: thêm đề, Bắt đầu, đổi câu, nộp, mở lần thi cũ trong ngân sách của large-exams.md khi đo trên
  emulator với bản debug; nộp bài và ra khỏi app không chặn giao diện (số đo: `docs/notes/android-measurements.md`).
- Dữ liệu chỉ nằm trong app trên máy: không sao lưu lên đám mây, không chuyển sang máy mới.
