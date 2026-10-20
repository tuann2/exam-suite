# Tổng quan sản phẩm

Exam Suite cho macOS là app luyện tập và thi trắc nghiệm, dự án cá nhân của Nt0,
viết mới bằng Swift 6 + SwiftUI. Kế hoạch đầy đủ (phạm vi, kiến trúc, lộ trình,
rủi ro): [plan-macos-v1.md](plan-macos-v1.md). Tài liệu này và các file cùng
thư mục là **hợp đồng sản phẩm hiện hành**; khi hành vi đổi, sửa ở đây trước.

## Hai bản app, một codebase

| Bản | Target Xcode | Bundle ID | Có gì |
| --- | --- | --- | --- |
| Học viên | `ExamSuite` | `vn.io.nt0.examsuite` | Thư viện đề, Luyện tập (Practice), Thi (Exam), kết quả, xem lại |
| Admin | `ExamSuiteAdmin` | `vn.io.nt0.examsuite.admin` | Như trên + Soạn đề (`AuthoringFeature`, `DocumentGroup`) |

Bản Học viên **không chứa** code soạn đề (ADR 0003). Cả hai bản phát hành công khai (DMG ở GitHub Releases; Nt0 chốt
2026-10-20): tách hai bản để người làm bài có app gọn, không phải để giữ bí mật phần soạn đề.

## Đặc tả UX

UX bám theo `docs/DESIGN_BRIEF.md` của repo
[Open Exam Suite](https://github.com/bolorundurowb/Open-Exam-Suite/blob/master/docs/DESIGN_BRIEF.md)
(dẫn link, không chép; repo đó theo GPLv3, xem ADR 0001). Dùng thành phần chuẩn
macOS thay cho khung Avalonia tự vẽ; bảng ánh xạ màn hình ↔ thành phần macOS và
phím tắt nằm trong mục "Thiết kế UX trên macOS" của kế hoạch.

Năm luồng chính phải chạy được hoàn toàn bằng bàn phím (DESIGN_BRIEF §6), với Điều hướng bàn phím
(Full Keyboard Access) của macOS được bật (exam-taking.md phương án 19):

1. Lần đầu mở: thư viện có đề mẫu → Practice → Check answer → kết quả → xem lại.
2. Thi tính giờ: 20 câu ngẫu nhiên, đánh dấu, bỏ qua, cảnh báo sắp hết giờ, rà soát với xác nhận câu chưa làm, kết quả, xem lại câu sai, làm lại.
3. Tạm dừng và hết giờ: che câu hỏi khi tạm dừng, tiếp tục, hết giờ tự chuyển sang rà soát và nộp.
4. Soạn đề (Admin): đề mới, thuộc tính, thêm section, câu nhiều đáp án có ảnh, kiểm tra lỗi bắt câu thiếu đáp án, xem trước, lưu, Thử đề này.
5. Sửa và khôi phục (Admin): mở đề, kéo thả sắp xếp, hoàn tác, đóng khi chưa lưu, khôi phục sau crash.

## Tài liệu sản phẩm theo lĩnh vực

- [exam-format.md](exam-format.md): gói `.exam`, `exam.json`, schema, phiên bản.
- [scoring.md](scoring.md): chấm điểm, ngưỡng đậu, chọn câu ngẫu nhiên.
- [exam-session.md](exam-session.md): phiên thi, trạng thái, đồng hồ, phím tắt.
- [authoring.md](authoring.md): Soạn đề (bản Admin).
- [import.md](import.md): import đề từ `.txt`, `.docx`, `.vce` (bản Admin).
- [exam-taking.md](exam-taking.md): Trước khi thi, cửa sổ làm bài, rà soát, kết quả, xem lại bài.
- [library.md](library.md): Thư viện đề, thêm đề, trạng thái file, đề mẫu, lịch sử thi, lưu trữ.
- [export-print.md](export-print.md): xuất PDF và in kết quả, PDF và in đề (bản Admin).
- [accessibility-localization.md](accessibility-localization.md): VoiceOver, Dark Mode, cỡ chữ, tiếng Việt/Anh.
- [large-exams.md](large-exams.md): đề lớn, ngân sách hiệu năng.

## Phạm vi v1 và tiêu chí hoàn thành

Phạm vi trong/ngoài v1 ghi ở mục "Mục tiêu và phạm vi v1" của kế hoạch. Tiêu chí:

- Mọi đề do app ghi đều khớp `schema/exam-v1.schema.json`; ghi rồi đọc lại ra đúng dữ liệu, kể cả ảnh.
- Kết quả chấm điểm khớp bộ test theo [scoring.md](scoring.md).
- Bản Học viên không chứa màn hình và code soạn đề (kiểm bằng `scripts/check_boundaries.py` và CI).
- Không mất nội dung đang soạn khi app bị tắt đột ngột.
- Đề 2.000 câu có ảnh vẫn mở và cuộn mượt: đề chuẩn và ngân sách đo được ở [large-exams.md](large-exams.md)
  (Nt0 chốt 2026-10-16).

## Câu hỏi mở đã trả lời (2026-10-15, Nt0)

- Mọi Mac của người dùng đã lên macOS 15 trở lên → giữ deployment target macOS 15 (ADR 0004 chốt).
- Kết quả thi chỉ lưu cục bộ trên máy, không gửi về máy chủ hay báo cáo quản lý → kiến trúc lưu trữ giữ SwiftData cục bộ, không cần lớp đồng bộ.
- Nt0 duyệt PR và test tay ở mỗi cổng.
- Đuôi `.exam` không trùng phần mềm nào người dùng đang dùng.
