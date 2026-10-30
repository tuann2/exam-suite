# Bản mobile (Học viên): chỗ khác bản macOS

Hợp đồng sản phẩm của bản mobile **là các tài liệu hiện có** (exam-format, scoring, exam-session, exam-taking, library,
accessibility-localization, large-exams; export-print từ v1.1). Tài liệu này chỉ ghi chỗ mobile khác macOS; chỗ không
ghi ở đây thì theo tài liệu macOS. Áp cho Android (docs/product/plan-android-v1.md). Nt0 chốt 2026-10-21 (phạm vi) và
2026-10-22 (Q1–Q13 của plan Android).

**Bản iOS không theo các mục Phạm vi và "Khác macOS" dưới đây**: hành vi theo tài liệu macOS, chỉ khác ở mục "Bản iOS"
cuối tài liệu này (Nt0 chốt 2026-10-30; docs/product/plan-ios-v1.md, ADR 0013).

## Phạm vi

- **v1**: Thư viện (danh sách), Thêm đề, mở `.exam` từ app khác, Trước khi thi, Làm bài (Luyện tập/Thi), Rà soát &
  nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại, Lịch sử thi, tự tạm dừng khi xuống nền và lưu phiên dở,
  tiếng Việt và tiếng Anh, nhãn trình đọc màn hình, sáng/tối theo hệ thống.
- **v1.1** (hoãn): Xuất PDF kết quả và chia sẻ/In, máy tính bảng (cột bên), Thư viện lưới, Thông tin đề, lọc Thư viện,
  Khôi phục đề mẫu, rà trình đọc màn hình theo đủ bảng mục tiêu, Reduce Motion.
- **Không làm**: cỡ chữ nội dung riêng trong app (dùng cỡ chữ hệ thống), phím tắt, Nền đọc.
- **Ngoài phạm vi mobile**: Soạn đề, Import, PDF đề (chỉ bản Admin macOS, ADR 0003), đồng bộ lịch sử giữa máy.

## Khác macOS

| Chủ đề | macOS (tài liệu gốc) | Mobile |
| --- | --- | --- |
| File đề trong Thư viện | Tham chiếu tại chỗ bằng bookmark; Không tìm thấy file, Tìm file…, Làm mới (library.md) | **Sao chép vào bộ nhớ riêng của app** khi thêm. Không có trạng thái mất file, Tìm file…, Làm mới. Xoá khỏi thư viện thì xoá bản sao, lịch sử giữ lại (như macOS) |
| Thêm file cùng id đề | Cùng file: chọn đề đã có; khác file: Dùng file mới / Huỷ (library.md phương án 1) | Luôn hỏi **Cập nhật đề** / **Huỷ**; Cập nhật thay bản sao, lịch sử giữ lại; mỗi id đề một mục. Đề đó đang có bài làm dở thì hộp hỏi thêm dòng "Bài đang làm dở của đề này sẽ bị bỏ" và **Cập nhật đề luôn bỏ phiên dở** (Nt0 chốt 2026-10-22) |
| Mở `.exam` từ app khác | Finder | Hộp chia sẻ và "Mở bằng" của hệ điều hành (Zalo, Drive, Files…). App nhận kiểu `application/octet-stream` (Android gán cho đuôi `.exam`) và zip, rồi tự kiểm đuôi và nội dung; file không phải đề thì báo, không thêm |
| App xuống nền khi đang làm bài | Không tự tạm dừng (exam-taking.md phương án 11); đóng cửa sổ thì hỏi rồi bỏ bài, không lưu phiên dở (phương án 2) | **Tự tạm dừng** khi app xuống nền (cuộc gọi, khoá màn hình, chuyển app) ở cả Luyện tập và Thi; thời gian ở nền không bị trừ. **Lưu phiên dở**; mở lại app (kể cả sau khi hệ điều hành dừng app) thì về đúng câu ở trạng thái Tạm dừng. Nút Quay lại ở màn làm bài hỏi "Bỏ bài?" như macOS; Bỏ bài thì xoá phiên dở, không lưu gì |
| Phiên dở khi khôi phục | Không có (không lưu phiên dở) | Phiên đang làm hay đang rà soát chưa khoá thì về **Tạm dừng**; phiên đã hết giờ hay đang rà soát khoá thì **giữ nguyên** trạng thái đó; thời gian đã làm đúng như lúc lưu (Nt0 chốt 2026-10-22) |
| Làm đề khác khi đang có bài dở | Mỗi lúc một phiên; đưa cửa sổ đang làm lên trước (exam-taking.md phương án 6) | Mỗi lúc một phiên. Đang có bài dở của đề A mà bắt đầu đề B thì hỏi "Bạn đang làm dở đề A" với **Tiếp tục đề A** / **Bỏ bài và làm đề B** / **Huỷ** (Nt0 chốt 2026-10-22) |
| Bảng câu hỏi | Inspector bên phải; khi tạm dừng chỉ hiện số ô | Bảng kéo lên từ dưới (bottom sheet); cột bên ở máy tính bảng từ v1.1. Tạm dừng thì bảng đóng hẳn (lớp phủ che cả màn) |
| Kiểm tra đáp án (Luyện tập) | Nút trên thanh dưới (exam-taking.md) | Nút ở cuối nội dung câu, dưới các lựa chọn: thanh dưới của điện thoại chỉ đủ chỗ cho Câu trước, Câu sau, Đánh dấu, Bảng câu hỏi, Rà soát & nộp |
| Phím tắt | Bảng phím đầy đủ (exam-session.md) | Không có |
| Cỡ chữ | Menu Xem › Phóng to/Thu nhỏ/Cỡ thật, 100–150% (accessibility-localization.md) | Theo cỡ chữ hệ thống, không có lệnh riêng. Bố cục màn làm bài, Kết quả, Xem lại bài phải còn dùng được tới cỡ chữ hệ thống **150%** như bản macOS (Nt0 chốt 2026-10-22); kiểm bằng ảnh chụp 150% |
| Nền đọc | Năm bộ màu (accessibility-localization.md) | Không có; theo sáng/tối của hệ thống |
| Sao lưu dữ liệu app | Không có (dữ liệu chỉ trên máy) | **Không sao lưu lên đám mây, không chuyển sang máy mới** (Nt0 chốt 2026-10-22): Thư viện, file đề đã sao chép, lịch sử thi, phiên dở và cài đặt chỉ nằm trên máy; gỡ app hay đổi máy là mất |
| Ngôn ngữ | Theo macOS, không có ô chọn trong app | Theo hệ thống và "Ngôn ngữ của ứng dụng" của hệ điều hành; không có ô chọn trong app. Thuật ngữ theo bảng đã duyệt |
| Lịch sử thi | Payload `AttemptRecord` v1 | Định dạng riêng của từng bản mobile (Q11), dấu vân tay câu cùng thuật toán với macOS nên quy tắc câu đã sửa/đã xoá giống hệt |
| Xuất PDF (v1.1) | Hộp Lưu, hộp In | Hộp chia sẻ của hệ điều hành (lưu, gửi), In của hệ điều hành; ba mức xem lại như macOS. Ảnh trong PDF: chốt khi làm (Q9) |

## Câu hỏi mở

Không còn (ba câu của plan Android Nt0 chốt 2026-10-22: cỡ chữ, làm đề khác khi có bài dở, Cập nhật đề khi có bài dở;
ghi vào bảng trên).

## Bản iOS

Bản Học viên trên iPhone (docs/product/plan-ios-v1.md, ADR 0013). Phạm vi chia v1 / v1.1 như plan-ios-v1.md Phần 2.
**Hành vi theo các tài liệu macOS**; bảng dưới chỉ ghi chỗ iOS khác macOS (Nt0 chốt 2026-10-30, mã QI là câu của bảng
Quyết định trong plan). Các mục Phạm vi và "Khác macOS" ở trên là của bản Android, không áp cho iOS.

| Chủ đề | macOS (tài liệu gốc) | iOS |
| --- | --- | --- |
| File đề trong Thư viện | Bookmark tới file tại chỗ; Không tìm thấy file, Tìm file…, Làm mới; trùng id: cùng file thì chọn đề đã có, khác file thì hỏi Dùng file mới / Huỷ (library.md) | **Như macOS** với file thêm bằng hộp chọn file (app Tệp: iCloud Drive, Trên iPhone, Drive…): bookmark tạo trong lúc có quyền security scope, mở quyền mỗi lần đọc. File của nhà cung cấp đám mây chưa tải về có thể hiện Không tìm thấy file, như ổ ngoài chưa gắn trên macOS |
| Mở `.exam` từ app khác | Finder mở file tại chỗ: thêm vào Thư viện, đưa cửa sổ Thư viện lên và chọn đề (library.md) | Hộp chia sẻ và "Mở bằng" (Zalo, Mail, AirDrop…): iOS giao một bản chép trong thư mục `Inbox` của app (`Documents/Inbox`). App dời file sang `Application Support/<bundle ID>/Received/` (trùng tên thì thêm số) rồi thêm như mọi file khác; app Tệp mở file tại chỗ thì không dời, thêm bằng bookmark như file chọn bằng hộp chọn file, **đúng luật macOS, không thêm luật** (QI12): nhận lại cùng đề từ Zalo là file khác nên hỏi Dùng file mới / Huỷ; Xoá khỏi thư viện không xoá bản chép |
| App xuống nền khi đang làm bài | Mất tiêu điểm không tự tạm dừng (exam-taking.md phương án 11); máy sắp ngủ thì tự tạm dừng, lớp phủ "Đã tạm dừng vì máy ngủ" | **Tự tạm dừng** khi app sang `.background` (chuyển app, về màn hình chính, khoá màn hình), ở cả Luyện tập và Thi; lý do `background`, lớp phủ "Đã tạm dừng vì bạn rời app"; mở lại vẫn ở Tạm dừng tới khi bấm Tiếp tục. Chỉ tạm dừng khi đang làm hay rà soát chưa khoá, như máy ngủ. Không có lý do "máy ngủ" riêng: khoá màn hình đã là xuống nền (QI10) |
| Phiên dở | Không lưu (phương án 2) | **Không lưu**, như macOS. iOS có thể dừng app khi app ở nền; khi đó bài đang làm mất, không báo (QI9; rủi ro chấp nhận ở v1, plan-ios-v1.md Phần 6) |
| Đóng cửa sổ làm bài | Hỏi "Bỏ bài?" rồi bỏ bài (phương án 2) | Nút Quay lại ở màn làm bài hỏi như macOS; cử chỉ vuốt từ cạnh màn hình để quay lại bị tắt ở màn này |
| Mỗi lúc một phiên | Đưa cửa sổ đang làm lên trước (phương án 6) | Màn làm bài che cả app nên không bắt đầu được đề khác từ giao diện. Nhận `.exam` từ app khác lúc đang có bài: **giữ màn làm bài** (đang Tạm dừng vì vừa rời app), đề vẫn được thêm; hộp Dùng file mới / Huỷ (nếu trùng id) và việc chọn đề hiện khi về Thư viện (QI12b) |
| Bảng câu hỏi | Inspector bên phải; tạm dừng thì chỉ hiện số ô | Bảng kéo lên từ dưới (sheet có detent), nội dung như macOS; cột bên ở iPad (v1.1) |
| Phím tắt, menu | Bảng phím (exam-session.md), menu Bài thi, Xem | Không có; mọi lệnh là nút trên màn |
| Cỡ chữ nội dung, Nền đọc | Menu Xem: Phóng to / Thu nhỏ / Cỡ thật 100–150%, năm bộ màu Nền đọc | Cỡ chữ theo **Dynamic Type** (Cài đặt của iOS), không có nút Phóng to trong app; bố cục làm bài, Kết quả, Xem lại còn dùng được tới mức `accessibility1` (~165%, mức đầu tiên vượt 150% của macOS), kiểm bằng ảnh chụp. Nền đọc ở v1.1, v1 theo sáng/tối hệ thống (QI11) |
| Hiện trong Finder | Có | Không có |
| Giấy phép | Hộp Giới thiệu của macOS (`Credits.rtf`), file kèm DMG | Màn Giới thiệu mở từ Thư viện: phiên bản, giấy phép Apache-2.0, NOTICE, ZIPFoundation (MIT) (QI13) |
| Sao lưu | Không có trong app; Time Machine sao lưu Application Support | Theo hệ thống, như macOS (QI9): dữ liệu app vào bản sao lưu iCloud hay máy tính. Khôi phục sang máy khác mà bookmark không phân giải được thì mục hiện Không tìm thấy file, dùng Tìm file… như macOS |
| Ngôn ngữ | Theo macOS, không có ô chọn trong app | Theo hệ thống và mục "Ngôn ngữ" riêng của app trong Cài đặt (iOS 13 trở lên); không có ô chọn trong app |
| Lịch sử thi | `AttemptRecord` v1 | Cùng `AttemptRecord` v1 (LibraryData dùng chung); khác Android (Q11 của plan Android) |
| Xuất PDF (v1.1) | Hộp Lưu, hộp In | Hộp chia sẻ (`ShareLink`), In qua `UIPrintInteractionController`; ba mức xem lại như macOS |
| Máy | Mac | v1 chỉ iPhone (`TARGETED_DEVICE_FAMILY = 1`; iPad chạy bản iPhone); iPad ở v1.1 |
| Tên app | Exam Suite | Exam Suite, bundle ID `vn.io.nt0.examsuite.ios` (QI3); bản Debug thêm đuôi `.debug` và tên "Exam Suite Debug" như Android, để không đụng dữ liệu của bản cài trên cùng iPhone |
