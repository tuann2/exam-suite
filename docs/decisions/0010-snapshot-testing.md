# 0010 Snapshot test giao diện bằng swift-snapshot-testing (chỉ trong test)

Date: 2026-10-16

## Status

Accepted (Nt0 duyệt 2026-10-16)

## Context

plan-macos-v1.md (Kiểm thử và chất lượng) yêu cầu **snapshot test sáng/tối** cho câu hỏi dài, 8+ lựa chọn, ảnh lớn,
nhiều section, cửa sổ tối thiểu 960×640. Giai đoạn 5 thêm Dark Mode, tiếng Anh, PDF (docs/product/export-print.md,
accessibility-localization.md); kiểm bằng mắt từng PR không đủ. ADR 0006 cấm thêm thư viện khi chưa có ADR và đã nêu
swift-snapshot-testing là ứng viên.

Hai hướng:

1. **[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)** (Point-Free, giấy phép MIT).
   Kiểm 2026-10-16: bản mới nhất **1.19.6** (2026-09-21, sửa lỗi so ảnh theo cảm nhận bị crash trên macOS 27),
   `swift-tools-version: 6.0`, hỗ trợ Swift Testing (trait `.snapshots(record:)`, đính kèm ảnh khác biệt từ 1.19.0),
   cập nhật đều. Target `SnapshotTesting` không phụ thuộc gì; package khai báo thêm swift-custom-dump, swift-syntax,
   xctest-dynamic-overlay cho các product khác. (Sửa 2026-10-17, review #41: SwiftPM vẫn tải mọi gói đó, kể cả bản
   build sẵn MacroSupport của swift-syntax, khi resolve `Packages/ExamFeatures`, kể cả lúc chỉ build app; chỉ không
   biên dịch, không link chúng. Chi tiết và số đo ở ADR 0006.) Trên macOS chụp `NSView`/`NSViewController` (SwiftUI qua `NSHostingView`), có so ảnh
   theo độ chính xác điểm ảnh và độ chính xác cảm nhận, chế độ ghi lại (record), chiến lược tuỳ biến (ví dụ chụp trang
   PDF qua PDFKit).
2. **Tự viết** khoảng 150–250 dòng trong test support: dựng view trong `NSHostingView` với `appearance` sáng/tối, chụp
   bằng `cacheDisplay(in:to:)`, so PNG với ảnh tham chiếu theo ngưỡng sai khác, ghi lại khi đặt biến môi trường.
   Không dùng `ImageRenderer` cho việc này: trên macOS nó không vẽ control AppKit (nút, ô nhập, `List`, `ScrollView`)
   nên không chụp được màn thật.

## Decision

Dùng **swift-snapshot-testing `from: "1.19.6"`**, product `SnapshotTesting`, **chỉ trong test target** của
`Packages/ExamFeatures` (không link vào app nào). Sửa 2026-10-31 (bản iOS, ADR 0013 bước I2): thêm test target
`MobileSnapshotTests` của `Packages/MobileFeatures` (snapshot iPhone), cùng các luật dưới đây.

- `scripts/check_boundaries.py` chặn `import SnapshotTesting` ngoài `Packages/ExamFeatures/Tests/**` và
  `Packages/MobileFeatures/Tests/**`, và chặn product này trong dependencies của target không phải test (kèm đối chứng
  âm như các luật hiện có).
- Ảnh tham chiếu (PNG) commit cạnh test (`__Snapshots__/`), mỗi ảnh ≤ 300 KB; tên có `light`/`dark` và kích thước.
- So theo độ chính xác cảm nhận (`perceptualPrecision` khoảng 0,98) để chịu khác biệt khử răng cưa nhỏ giữa máy.
- Ảnh tham chiếu ghi trên Mac của người điều phối (máy chạy `verify_local.sh`); đổi phiên bản macOS lớn làm lệch phông
  thì ghi lại ảnh trong một PR riêng, người duyệt xem ảnh khác biệt.
- Chạy trong `swift test` của ExamFeatures (macOS, có Xcode), tức trong `check.sh` và `verify_local.sh`; không chạy
  trên Linux (ExamFeatures chỉ macOS). Snapshot iPhone chạy trên simulator (`xcodebuild test -scheme ExamSuiteiOS`,
  bước iOS của `verify_local.sh` mức full), một máy và một runtime cố định (`EXAMSUITE_IOS_DESTINATION`).
- ADR 0006 (mục Decision) ghi thêm thư viện này (thư viện thứ hai, chỉ trong test) trong PR thêm phụ thuộc (bước 3
  của plan giai đoạn 5).

## Alternatives Considered

1. Tự viết (hướng 2 ở trên): không thêm phụ thuộc, nhưng phải tự làm so ảnh có ngưỡng, ảnh khác biệt khi thất bại,
   chế độ ghi lại, đính kèm vào kết quả Swift Testing; dễ chập chờn nếu so từng điểm ảnh.
2. Không snapshot; chỉ test model trình bày + XCUITest + test tay Dark Mode: rẻ nhất, nhưng lỗi bố cục (cắt chữ, chồng
   lớp ở 960×640, màu sai ở giao diện tối) chỉ lộ khi người test tay nhìn thấy.

## Consequences

Positive:

- Bắt hồi quy bố cục/màu ở sáng và tối, 960×640, chữ tiếng Anh, trang PDF, ngay trong `swift test`.
- Thư viện có sẵn đính kèm ảnh khác biệt cho Swift Testing, người duyệt xem được.

Tradeoffs:

- Thêm phụ thuộc thứ hai (dù chỉ ở test) và việc cập nhật theo macOS/Xcode mới; `Package.resolved` dài hơn.
- Ảnh tham chiếu phụ thuộc phông và cách vẽ của macOS: đổi máy/OS phải ghi lại; tăng dung lượng repo.
- Snapshot không thay test tay VoiceOver, máy in thật, màn hình ngoài.

## Follow-Up

- 2026-10-16 Nt0 duyệt; ghi vào plan giai đoạn 5 (Decisions) và bảng ADR.
- Bước snapshot của plan giai đoạn 5: thêm phụ thuộc, luật ranh giới, helper chụp sáng/tối, bộ ảnh đầu tiên (câu dài,
  8+ lựa chọn, ảnh lớn, nhiều phần, Kết quả, Xem lại, trang đầu PDF).
- 2026-10-31, bước I2b của plan iOS (ADR 0013, docs/product/plan-ios-v1.md Phần 5): `MobileSnapshotTests` dựng màn
  trong một cửa sổ cỡ iPhone 390×844, chụp bằng `CALayer.render(in:)` khi bố cục đã đứng yên, ảnh 1x, sáng/tối và cỡ
  chữ trợ năng; so ảnh bằng `assertSnapshot` của thư viện (chiến lược ảnh, cùng độ chính xác cảm nhận). Tên ảnh iPhone
  không ghi cỡ (mọi ảnh 390×844), ghi `light`/`dark`, ảnh cỡ chữ lớn ghi `largeText` (chỉ sáng).
  `Packages/MobileFeatures/Package.resolved` ghim cùng bản với ExamFeatures cho `swift package` (`check_boundaries.py`
  đọc); bản build bằng `xcodebuild` (project do XcodeGen sinh, không commit) resolve theo `from: "1.19.6"`, như
  ExamFeatures. Như ở ExamFeatures, resolve gói này (kể cả build app iOS) tải các gói mà manifest của
  swift-snapshot-testing khai báo, không biên dịch vào app (`check_bundle_boundary.sh` kiểm cả app iOS). Simulator
  chỉ nhận biến môi trường có tiền tố `TEST_RUNNER_`, nên ghi lại ảnh iPhone bằng
  `TEST_RUNNER_EXAMSUITE_SNAPSHOT_RECORD` (docs/process/snapshot-tests.md).
