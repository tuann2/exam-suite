# 0001 Viết mới bằng SwiftUI, không fork hay chép code GPLv3

Date: 2026-10-15

## Status

Accepted (2026-10-18: lời văn theo dự án cá nhân của Nt0, nội dung quyết định không đổi. 2026-10-20: Nt0 chọn giấy phép
**Apache-2.0** ("Copyright 2026 Nt0") khi công khai repo và xác nhận nắm toàn quyền với mã nguồn; mục Context,
Consequences và Follow-Up ghi theo đó, quyết định viết mới không đổi)

## Context

Nt0 cần app luyện thi chạy native trên Mac. Open Exam Suite (C# .NET + Avalonia,
GPLv3) đã có logic và đặc tả UX tốt nhưng giao diện không theo chuẩn macOS,
phải mang runtime .NET, và chép code sẽ buộc app theo GPLv3 (không phải
tư vấn pháp lý).

## Decision

Viết mới toàn bộ bằng Swift 6 + SwiftUI. Repo gốc chỉ dùng làm **đặc tả**:
đọc `docs/DESIGN_BRIEF.md`, quy tắc chấm điểm và danh sách tình huống test, rồi
viết lại từ đặc tả. Không chép mã nguồn, không chép đề mẫu, không dịch máy từng
hàm C# sang Swift.

## Alternatives Considered

1. Dùng bản Avalonia cho macOS của repo gốc: chạy được ngay nhưng không native, preview.
2. Fork và sửa: nhanh nhưng kéo theo GPLv3 và stack .NET.

## Consequences

Positive:

- App native, nhẹ, dùng DocumentGroup/UndoManager/Versions sẵn của macOS.
- Giấy phép của app tự do (không bị GPLv3 ràng buộc). 2026-10-20 Nt0 chọn Apache-2.0: `LICENSE` (nguyên văn Apache-2.0),
  `NOTICE` ("Exam Suite / Copyright 2026 Nt0" và ghi công ZIPFoundation), `THIRD_PARTY_NOTICES.md` (giấy phép MIT của
  ZIPFoundation, thư viện link vào app; các gói chỉ dùng khi test) ở gốc repo, bản chữ trơn trong mỗi DMG
  (`scripts/make_dmg.sh`). Không thêm tiêu đề giấy phép vào từng file mã nguồn (phụ lục của Apache-2.0 chỉ khuyên, không
  bắt buộc; Nt0 chọn một `LICENSE` ở gốc repo).

Tradeoffs:

- Phải viết lại ~5.000 dòng logic + UI; tốn thời gian hơn fork.

## Follow-Up

- Người duyệt PR kiểm "không chép code/đề" (docs/process/review-and-merge.md).
- Hỏi tư vấn pháp lý nếu sau này phát hành ra ngoài. 2026-10-20: Nt0 công khai repo với giấy phép Apache-2.0
  (plan cong-khai-repo.md trong docs/plans/, CHANGELOG mục 0.1.1); Open Exam Suite vẫn chỉ được ghi công là nguồn ý tưởng UX, không có mã của nó
  trong repo.
