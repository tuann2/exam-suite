# Bản mobile (Học viên): chỗ khác bản macOS

Hợp đồng sản phẩm của bản mobile **là các tài liệu hiện có** (exam-format, scoring, exam-session, exam-taking, library,
accessibility-localization, large-exams; export-print từ v1.1). Tài liệu này chỉ ghi chỗ mobile khác macOS; chỗ không
ghi ở đây thì theo tài liệu macOS. Áp cho Android (docs/product/plan-android-v1.md) và iOS
(docs/product/plan-ios-v1.md). Nt0 chốt 2026-10-21 (phạm vi) và 2026-10-22 (Q1–Q13 của plan Android).

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
| Thêm file cùng id đề | Cùng file: chọn đề đã có; khác file: Dùng file mới / Huỷ (library.md phương án 1) | Luôn hỏi **Cập nhật đề** / **Huỷ**; Cập nhật thay bản sao, lịch sử giữ lại; mỗi id đề một mục |
| Mở `.exam` từ app khác | Finder | Hộp chia sẻ và "Mở bằng" của hệ điều hành (Zalo, Drive, Files…). App nhận kiểu `application/octet-stream` (Android gán cho đuôi `.exam`) và zip, rồi tự kiểm đuôi và nội dung; file không phải đề thì báo, không thêm |
| App xuống nền khi đang làm bài | Không tự tạm dừng (exam-taking.md phương án 11); đóng cửa sổ thì hỏi rồi bỏ bài, không lưu phiên dở (phương án 2) | **Tự tạm dừng** khi app xuống nền (cuộc gọi, khoá màn hình, chuyển app) ở cả Luyện tập và Thi; thời gian ở nền không bị trừ. **Lưu phiên dở**; mở lại app (kể cả sau khi hệ điều hành dừng app) thì về đúng câu ở trạng thái Tạm dừng. Nút Quay lại ở màn làm bài hỏi "Bỏ bài?" như macOS; Bỏ bài thì xoá phiên dở, không lưu gì |
| Bảng câu hỏi | Inspector bên phải | Bảng kéo lên từ dưới (bottom sheet); cột bên ở máy tính bảng từ v1.1 |
| Phím tắt | Bảng phím đầy đủ (exam-session.md) | Không có |
| Cỡ chữ | Menu Xem › Phóng to/Thu nhỏ/Cỡ thật, 100–150% (accessibility-localization.md) | Theo cỡ chữ hệ thống, không có lệnh riêng |
| Nền đọc | Năm bộ màu (accessibility-localization.md) | Không có; theo sáng/tối của hệ thống |
| Ngôn ngữ | Theo macOS, không có ô chọn trong app | Theo hệ thống và "Ngôn ngữ của ứng dụng" của hệ điều hành; không có ô chọn trong app. Thuật ngữ theo bảng đã duyệt |
| Lịch sử thi | Payload `AttemptRecord` v1 | Định dạng riêng của từng bản mobile (Q11), dấu vân tay câu cùng thuật toán với macOS nên quy tắc câu đã sửa/đã xoá giống hệt |
| Xuất PDF (v1.1) | Hộp Lưu, hộp In | Hộp chia sẻ của hệ điều hành (lưu, gửi), In của hệ điều hành; ba mức xem lại như macOS. Ảnh trong PDF: chốt khi làm (Q9) |

## Câu hỏi mở

- **Làm đề khác khi đang có phiên dở** (macOS: mỗi lúc một phiên, đưa cửa sổ đang làm lên trước, exam-taking.md phương
  án 6): mở lại phiên dở hay hỏi Bỏ bài? Nt0 chốt trước bước A3a của Android.
- **Cỡ chữ hệ thống lớn tới đâu thì bố cục phải giữ** (macOS kiểm tới 150%): Nt0 chốt trước bước A3b của Android.
- **Sao lưu dữ liệu app** (sao lưu đám mây của hệ điều hành, chuyển sang máy mới): bản khung Android tạm **tắt cả hai**
  (dữ liệu chỉ nằm trên máy, như macOS). Nt0 chốt trước bước A2 (lưu trữ) của Android.
