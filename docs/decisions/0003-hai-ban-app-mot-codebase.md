# 0003 Một codebase, hai bản app: Học viên và Admin

Date: 2026-10-15

## Status

Accepted (2026-10-18: bundle ID và UTType đổi sang họ `vn.io.nt0` khi chuyển thành dự án cá nhân của Nt0;
quyết định không đổi. 2026-10-20, repo public: cả hai bản phát hành công khai (Nt0 chốt), nên ai cũng có thể dùng bản
Admin; bất biến "bản Học viên không chứa code soạn đề" giữ nguyên để người làm bài có app gọn, không còn là cách giới hạn
ai soạn được đề. 2026-10-30: bản iOS là bản Học viên thứ hai, cùng bất biến: `MobileShell` và target `ExamSuiteiOS` không
phụ thuộc AuthoringFeature, AuthoringData, ExamImport; ADR 0013)

## Context

Chỉ admin được soạn đề. Cách rẻ nhất để bản Học viên không soạn được đề là
không đưa code soạn đề vào bản đó, thay vì phân quyền trong app.

## Decision

Hai target Xcode trong một project: `ExamSuite` (Học viên, `vn.io.nt0.examsuite`)
và `ExamSuiteAdmin` (Admin, `vn.io.nt0.examsuite.admin`). Giao diện nằm trong
`Packages/ExamFeatures` với hai product: `StudentShell` (LibraryFeature +
SessionFeature) và `AdminShell` (thêm AuthoringFeature). **Bất biến:**
`StudentShell` và target `ExamSuite` không phụ thuộc `AuthoringFeature`, trực
tiếp hay gián tiếp. Bản Admin là Editor/Owner của UTType `vn.io.nt0.exam`, bản
Học viên là Viewer/Alternate.

## Alternatives Considered

1. Một app, ẩn chế độ soạn đề bằng cờ/cài đặt: ai cũng bật được.
2. Hai repo: trùng code, khó giữ đồng bộ.

## Consequences

Positive:

- Bản Học viên về mặt kỹ thuật không soạn được đề; dễ kiểm bằng máy.

Tradeoffs:

- Hai bundle, hai DMG; máy admin cài cả hai nên phải xử lý mở file từ Finder (spike giai đoạn 0).

## Follow-Up

- Kiểm bằng `scripts/check_boundaries.py` (đồ thị phụ thuộc + `project.yml` + import trong `Apps/Student`) và job `apps-macos` (nm binary).
