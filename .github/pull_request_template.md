## Mục exec-plan

<!-- Đường dẫn docs/plans/active/<file>.md và mục/bước PR này hoàn thành -->

## Thay đổi

<!-- 2–5 dòng. Một PR chỉ làm một mục trong exec-plan. -->

## Mức rủi ro

- [ ] **Cao**: chạm chấm điểm / chọn câu, đọc-ghi gói `.exam`, lưu file soạn đề,
      ranh giới hai bản app (`project.yml`, StudentShell/AdminShell), schema.
      → Cần một phiên agent mới review độc lập trước khi người duyệt
      (xem `docs/process/review-and-merge.md`). Dán kết quả review bên dưới.
- [ ] **Thường**: chỉ cần người duyệt diff.

## Bằng chứng

- CI xanh trên commit: <!-- link run, đúng SHA cuối của PR -->
- Lệnh đã chạy tại chỗ: <!-- scripts/check.sh, swift test ..., xcodebuild ... -->
- Thư viện mới: <!-- Không / ADR số ... đã được duyệt -->

## Cần người test tay

<!-- Liệt kê những gì máy không kiểm được: giao diện, VoiceOver, mở file từ Finder... hoặc "Không" -->
