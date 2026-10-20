# Execution Plan: Giai đoạn 0 · Chuẩn bị và spike

Date: 2026-10-15

## Status

Completed

## Outcome

Repo sẵn sàng cho agent làm giai đoạn 1: hai target app build được bằng Xcode
trên Mac của Nt0, Swift Package lõi test được trên Linux, CI xanh, harness và
tài liệu thẩm quyền đầy đủ, hai rủi ro tuần 1 (mở file từ Finder khi cài cả hai
bản; độ ổn định schema) đã có kết luận.

## Context

- Kế hoạch: docs/product/plan-macos-v1.md (mục Lộ trình, giai đoạn "Chuẩn bị, spike").
- Quyết định: docs/decisions/0001–0008.
- Quy trình: docs/process/review-and-merge.md.

## Scope

In scope:

- Khung repo, package, project.yml, schema v1, fixture, script kiểm tra, CI, harness, ADR.
- Spike: DocumentGroup cho `.exam` trong bản Admin; hành vi Finder khi cài cả hai bản.
- Tạo remote GitHub, bật branch protection, chạy CI lần đầu.

Out of scope:

- Model, chấm điểm, đọc/ghi gói (giai đoạn 1).

## Approach

1. Dựng khung không cần Xcode (xong 2026-10-15, xem Progress).
2. Cài Xcode, `xcodegen generate`, build hai target, sửa project.yml nếu cần.
3. Spike Finder/DocumentGroup trên máy cài cả hai bản; ghi kết luận vào Decisions bên dưới (và ADR mới nếu đổi cách mở file).
4. Tạo remote, push `main`, bật branch protection, xác nhận cả hai job CI xanh.

## Risks And Recovery

- Xcode chưa cài trên Mac này (chỉ Command Line Tools): SwiftData `@Model` và
  xcodebuild không chạy được. Cài Xcode 26 từ App Store/developer.apple.com trước bước 2.
- Runner `macos-15` trên GitHub có thể không có Xcode 26: job `apps-macos` chọn
  Xcode mới nhất có sẵn; nếu thiếu SDK macOS 15, đổi runner hoặc hạ tạm `swift-tools-version`.
- `com.pkware.zip-archive` conformance có thể khiến Archive Utility tranh mở `.exam`:
  spike kiểm tra; dự phòng chỉ conform `public.data`.
- Rollback: mọi thứ trong git; chưa có dữ liệu người dùng.

## Progress

- [x] 2026-10-15 Cài repository-harness 0.1.10 (`--claude`), điền AGENTS.md, docs/README.md.
- [x] 2026-10-15 ADR 0001–0008; tài liệu sản phẩm overview/exam-format/scoring/exam-session; quy trình review.
- [x] 2026-10-15 `Packages/ExamKit` (ExamKit, ExamFile + ZIPFoundation 0.9.20), smoke test xanh bằng `swift test` trên macOS (CLT).
- [x] 2026-10-15 `Packages/ExamFeatures` (Library/Session/Authoring, StudentShell/AdminShell) build bằng `swift build`.
- [x] 2026-10-15 `project.yml` hai target + UTType `.exam` (theo bundle ID cũ; nay `vn.io.nt0.exam`); `Apps/Student`, `Apps/Admin`.
- [x] 2026-10-15 `schema/exam-v1.schema.json`, 2 đề mẫu tự soạn, 8 fixture sai; `scripts/validate_exam.py --all` xanh.
- [x] 2026-10-15 `scripts/check_boundaries.py`, `scripts/check.sh`; bằng chứng âm chạy tay (xem Validation).
- [x] 2026-10-15 `.github/workflows/ci.yml` (core-linux, apps-macos) — chưa chạy lần nào vì chưa có remote.
- [x] 2026-10-15 Cài Xcode 27.0 (27A266a); `brew install xcodegen` 2.46.0; `xcodegen generate`; build `ExamSuite` và `ExamSuiteAdmin` BUILD SUCCEEDED; cả hai app khởi động được. Info.plist sinh ra đúng bundle ID, vai Viewer/Editor, UTType `.exam` (theo bundle ID cũ).
- [x] 2026-10-15 `sudo xcode-select -s /Applications/Xcode.app` (Nt0 chạy); `xcode-select -p` nay trỏ Xcode.
- [x] 2026-10-15 Spike DocumentGroup + mở `.exam` khi đăng ký cả hai bản với LaunchServices; kết luận ở Decisions.
- [x] 2026-10-15 Tạo remote `tuann2/exam-suite` (private) bằng `gh repo create`, push `main`.
- [x] 2026-10-15 Branch protection: GitHub Free không cho trên repo private (403). Nt0 quyết định **kỷ luật thủ công**: người duyệt tự kiểm CI xanh trên SHA cuối trước khi merge; agent không push `main`.
- [x] 2026-10-15 CI lần đầu (run 38679775576) xanh cả hai job: `core-linux` 80s, `apps-macos` 116s trên `macos-15`; không phải sửa job. Nâng `actions/checkout` lên v5 theo cảnh báo Node 20.
- [ ] (chuyển sang giai đoạn 1, tuỳ chọn) SwiftLint/SwiftFormat.
- [x] 2026-10-15 Trả lời câu hỏi mở (macOS ≥ 15 trên mọi Mac dùng thử; kết quả thi lưu cục bộ; Nt0 duyệt PR; `.exam` không trùng); ADR 0004 chốt.
- [ ] (chuyển sang giai đoạn 1, tuỳ chọn) Thay 2 đề mẫu bằng 2–3 đề thật của người dùng thử.

## Decisions

- 2026-10-15 **Kết luận spike mở file:** đăng ký cả hai app với LaunchServices rồi `open "Kiến thức chung.exam"` → macOS chọn **bản Admin** (claim Owner/Editor thắng claim Alternate/Viewer). `mdls` nhận đúng UTType `.exam` của app (theo bundle ID cũ); không thấy Archive Utility tranh file. Bản Admin mở thẳng cửa sổ document "Kiến thức chung.exam" (`DocumentGroup(viewing:)`), cửa sổ Thư viện không tự mở kèm. Bản Học viên khi được `open -a` với file: app chạy, chỉ hiện cửa sổ Thư viện, file bị bỏ qua vì chưa có `onOpenURL`. Hệ quả cho các giai đoạn sau: (1) giai đoạn 2 phải thêm `onOpenURL` vào bản Học viên để nhập file vào thư viện; (2) giai đoạn 4 quyết định bản Admin mở file từ Finder vào Soạn đề (hành vi hiện tại) hay hỏi Luyện/Soạn; (3) rủi ro "Archive Utility tranh `.exam`" không xảy ra trên macOS 27, giữ `conformingTo: .zip`.
- 2026-10-15 `ExamPackageInspector` (ExamFile) đọc nông gói để spike và báo lỗi file hỏng; giải mã model vẫn là giai đoạn 1.

- 2026-10-15: Dùng XcodeGen (`project.yml`) thay vì commit `.xcodeproj` để diff duyệt được và agent sửa được bằng text.
- 2026-10-15: Giao diện đặt trong package `ExamFeatures` với hai shell; target Xcode chỉ chứa `@main`, để ranh giới hai bản kiểm được bằng đồ thị phụ thuộc.
- 2026-10-15: Kiểm schema bằng Python `jsonschema` (stdlib không có validator); là công cụ dev, không link vào app.
- 2026-10-15: `swift-tools-version: 6.0` (không 6.4) để Xcode 16/Swift 6.0–6.1 trên CI build được.
- 2026-10-15: Xcode 26+ ở Debug đặt code app vào `<App>.debug.dylib`, nên kiểm "bản Học viên không chứa AuthoringFeature" phải quét mọi Mach-O trong bundle và đòi bằng chứng dương ở bản Admin: `scripts/check_bundle_boundary.sh` (CI `apps-macos` gọi).
- 2026-10-15: `Apps/*/Info.plist` do XcodeGen sinh từ `project.yml`, không commit.
- 2026-10-15: `scripts/check.sh` tự thêm `-Xswiftc -plugin-path` tới plugin Swift Testing khi chạy bằng Command Line Tools, vì build incremental của Swift 6.4 CLT thỉnh thoảng không nạp macro `@Test` (tái hiện 3/8 lần; với cờ: 3/3 xanh). Xoá workaround khi mọi máy build dùng Xcode.

## Validation

- Focused proof: `swift test --package-path Packages/ExamKit` (3 test xanh, 2026-10-15, macOS CLT Swift 6.4).
- Integration proof: `scripts/check.sh` xanh 2026-10-15 (test lõi, schema 2 đậu/8 rớt, ranh giới, build ExamFeatures).
- Negative proof (chạy tay 2026-10-15, không để lại file vi phạm): (1) thêm `import SwiftUI` vào ExamKit → `check_boundaries.py` FAIL đúng lý do; (2) thêm `AuthoringFeature` vào target `ExamSuite` trong `project.yml` → FAIL đúng lý do; (3) thêm `AuthoringFeature` vào dependencies của `StudentShell` trong `Package.swift` → FAIL đúng lý do (đồ thị `swift package describe`). Lần chạy đầu bắt nhầm một comment trong `project.yml`; đã sửa script bỏ qua dòng `#`.
- Repository-required checks: CI run 38679775576 xanh cả hai job trên commit e99546e. Branch protection không bật được (GitHub Free, repo private).
- 2026-10-15 với Xcode 27: `xcodebuild` hai scheme BUILD SUCCEEDED; `scripts/check_bundle_boundary.sh` → Học viên 0 ký hiệu AuthoringFeature, Admin 147; cả hai app khởi động; spike mở file như ghi ở Decisions. `swift test` ổn định 3/3 không cần cờ plugin khi dùng toolchain Xcode.
- Chưa kiểm được: XCUITest (chưa có test), CI (chưa có remote), chụp màn hình (chưa cấp quyền Screen Recording cho terminal).

## Result

Hoàn thành 2026-10-15. Repo `tuann2/exam-suite` có harness, ADR 0001–0008, tài
liệu sản phẩm, schema v1 + fixture, hai Swift Package, project.yml hai target,
script kiểm tra và CI xanh (run 38679775576 và run của f04c6db). Spike mở file
kết luận: LaunchServices chọn bản Admin, DocumentGroup mở đúng; bản Học viên cần
`onOpenURL` ở giai đoạn 2. Giới hạn: branch protection không có (kỷ luật thủ
công); chưa có XCUITest; đề mẫu còn là đề tự soạn. Hai việc tuỳ chọn (lint, đề
thật) chuyển sang giai đoạn 1.
