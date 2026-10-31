# Documentation Map

Start with the smallest authoritative surface.

## Exam Suite (consumer-owned truth)

- [`product/overview.md`](product/overview.md): sản phẩm, hai bản app, luồng chính, tiêu chí, câu hỏi mở.
- [`product/exam-format.md`](product/exam-format.md): gói `.exam`, `exam.json`, ràng buộc, phiên bản.
- [`product/scoring.md`](product/scoring.md): chấm điểm, ngưỡng đậu, chọn câu có seed.
- [`product/exam-session.md`](product/exam-session.md): trạng thái phiên thi, đồng hồ, phím tắt.
- [`product/library.md`](product/library.md): cửa sổ Thư viện, thêm đề, trạng thái file, đề mẫu, lịch sử thi, lưu trữ.
- [`product/authoring.md`](product/authoring.md): Soạn đề (bản Admin): cửa sổ ba cột, ảnh, kiểm lỗi, lưu, Thử đề này.
- [`product/import.md`](product/import.md): import đề từ `.txt`, `.docx`, `.vce`, `.oef` (bản Admin).
- [`product/exam-taking.md`](product/exam-taking.md): Trước khi thi, cửa sổ làm bài, rà soát, kết quả, xem lại bài, dữ liệu lần thi.
- [`product/export-print.md`](product/export-print.md): xuất PDF và in kết quả (hai bản), PDF và in đề (bản Admin).
- [`product/accessibility-localization.md`](product/accessibility-localization.md): VoiceOver theo màn, Dark Mode và tương phản, cỡ chữ, tiếng Việt/Anh (String Catalog).
- [`product/large-exams.md`](product/large-exams.md): đề chuẩn 2.000 câu, ngân sách hiệu năng, cách đo.
- [`product/mobile.md`](product/mobile.md): bản mobile (Học viên): phạm vi v1/v1.1 và chỗ bản Android khác bản macOS (file đề sao chép vào app, tự tạm dừng và lưu phiên dở khi xuống nền…); mục "Bản iOS": chỗ bản iOS khác bản macOS.
- [`product/plan-macos-v1.md`](product/plan-macos-v1.md): kế hoạch đầy đủ (phạm vi, kiến trúc, UX, lộ trình, rủi ro).
- [`product/plan-android-v1.md`](product/plan-android-v1.md): kế hoạch app Android bản Học viên (v1 / v1.1); Nt0 chốt quyết định 2026-10-22, làm trước iOS.
- [`product/plan-ios-v1.md`](product/plan-ios-v1.md): kế hoạch app iOS bản Học viên (v1 / v1.1); cùng cách chia v1 / v1.1 với Android nhưng hành vi theo bản macOS, chỗ khác ở mục "Bản iOS" của `mobile.md` (Nt0 chốt 2026-10-30, ADR 0013); exec-plan `plans/active/ios-v1.md`.
- [`product/plan-oef.md`](product/plan-oef.md): kế hoạch mở file `.oef` của Open Exam Suite ở ba bản Học viên và Import đề… (Nt0 chốt 2026-10-31, ADR 0014; hợp đồng ở mục File `.oef` của `exam-format.md`); exec-plan `plans/active/oef.md`.
- [`notes/vce-format.md`](notes/vce-format.md): ghi chú ngắn về định dạng `.vce` (cách tìm hiểu, phạm vi, kết quả thử; chi tiết ở mã nguồn).
- [`notes/large-exam-measurements.md`](notes/large-exam-measurements.md): số đo Release của đề chuẩn (`scripts/measure_large.sh`).
- [`notes/g5-spike-pdf-l10n.md`](notes/g5-spike-pdf-l10n.md): spike giai đoạn 5: số đo PDF bằng `ImageRenderer`, String Catalog trong Swift package (cho bước 4, 5).
- [`notes/g5-ui-test-trung-lap.md`](notes/g5-ui-test-trung-lap.md): UI test trùng lặp, số đo thời gian, việc cần sửa ở `verify_local.sh --uitest`.
- [`notes/ra-soat-cach-lam-macos.md`](notes/ra-soat-cach-lam-macos.md): rà soát cách làm bản macOS (tốc độ, bước chia quá nhỏ, lớp test trùng, song song); căn cứ cho nhịp làm việc và hai plan mobile.
- [`decisions/`](decisions/README.md): ADR 0001–0014, future work must inherit.
- [`plans/`](plans/README.md): exec-plan theo giai đoạn; `active/` đang làm, `completed/` đã qua cổng.
- [`process/review-and-merge.md`](process/review-and-merge.md): quyền của agent, bằng chứng gắn commit, review độc lập theo rủi ro.
- `../schema/`, `../fixtures/`, `../scripts/`: schema, đề mẫu, kiểm tra máy. Lệnh tổng: `scripts/check.sh`.
- `archive/`: không có trong git; chỗ để file đề thật dùng thử import tại máy, không commit (`.gitignore` bỏ qua `.vce`,
  `.txt`, `.docx`; import.md).

Harness-managed guidance:

- [`WORKFLOW.md`](WORKFLOW.md): request shape, planning, judgment, operation, validation, and completion.
- [`patterns/encoding-invariants.md`](patterns/encoding-invariants.md): turn accepted rules into native mechanical validation.
- [`templates/`](templates/): decision, exec-plan, runbook, and Harness-improvement structures.

## Consumer-Owned Truth

The consumer's README, product documents, architecture, code, tests, CI,
runtime signals, and application behavior remain authoritative. Harness does
not overwrite those with upstream product assumptions.
