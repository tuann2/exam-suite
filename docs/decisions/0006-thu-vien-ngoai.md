# 0006 Thư viện ngoài: chỉ ZIPFoundation; thêm thư viện phải có ADR

Date: 2026-10-15

## Status

Accepted

## Context

Mỗi thư viện ngoài là chi phí bảo trì, rủi ro giấy phép và làm agent dễ "tiện
tay" thêm phụ thuộc. Lõi phải test được trên Linux.

## Decision

- Phụ thuộc SwiftPM duy nhất được duyệt: [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)
  (MIT, thuần Swift, chạy trên Linux) `from: "0.9.19"`, chỉ trong module `ExamFile` và module `ExamImport` (chỉ bản
  Admin, đọc `.docx`; docs/product/import.md), cùng test target của hai module đó. Vẫn chỉ một thư viện ngoài.
  `scripts/check_boundaries.py` chặn `import ZIPFoundation` ở chỗ khác.
  - 2026-10-16 Nt0 duyệt: thêm ExamImport.
- Thư viện thứ hai, **chỉ trong test**: [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
  (MIT) `from: "1.19.6"`, product `SnapshotTesting`, chỉ ở test target `ExamFeaturesSnapshotTests` của
  `Packages/ExamFeatures` (ADR 0010, Nt0 duyệt 2026-10-16) và, từ bản iOS, `MobileSnapshotTests` của
  `Packages/MobileFeatures` (ADR 0010 sửa 2026-10-31, ADR 0013). Không target nào trong `Sources/`, không app nào phụ thuộc;
  `scripts/check_boundaries.py` chặn import, product lạ ở mọi target, gói ngoài khác, project.yml dùng gói không cục
  bộ và ghim lạ trong `Package.resolved`; `scripts/check_bundle_boundary.sh` kiểm hai app macOS và app iOS không có ký hiệu của nó.
  `Package.resolved` ghim thêm swift-custom-dump, swift-issue-reporting, swift-syntax vì manifest của gói khai báo cho
  product khác. Vì gói nằm trong đồ thị của `Packages/ExamFeatures`, **mọi** lần resolve gói này đều tải chúng, kể cả
  khi chỉ build app hay product không test (`swift build`, `xcodebuild` hai app): checkout mã nguồn cả bốn gói, và bản
  build sẵn MacroSupport của swift-syntax (file zip khoảng 20 MB trong cache, giải nén khoảng 115 MB ở mỗi `.build/`
  hoặc `DerivedData/SourcePackages/prebuilts`). Không gói nào trong số đó được biên dịch hay link vào app (kiểm 2026-10-17:
  không object nào trong sản phẩm build của app, `check_bundle_boundary.sh` 0 ký hiệu, 0 file).
  `--disable-experimental-prebuilts` (đo 2026-10-17, build sạch ExamFeatures kèm test) bỏ được 115 MB đó nhưng không
  nhanh hơn (34–41 s cả hai cách), nên `check.sh` không dùng; tách snapshot test sang gói riêng là cách bỏ hẳn phụ
  thuộc khỏi đồ thị của app, chưa làm.
- Mọi thư viện khác (SwiftPM, Homebrew phục vụ build, GitHub Action ngoài
  `actions/*`) chỉ được thêm sau khi có ADR mới ở thư mục này được người duyệt
  chấp nhận. Ứng viên đã biết: Sparkle (tự cập nhật, khi có Developer ID),
  GRDB (dự phòng nếu SwiftData lỗi).
- Công cụ dev không link vào app (XcodeGen, SwiftLint, SwiftFormat, Python
  `jsonschema`) được dùng không cần ADR, nhưng phải ghi trong AGENTS.md.

## Alternatives Considered

1. Tự viết đọc/ghi zip: không đáng.
2. Dùng `Compression`/`NSFileCoordinator` của Apple: không có trên Linux.

## Consequences

Positive:

- Cây phụ thuộc nhỏ, rõ; agent có rào chắn rõ ràng.

Tradeoffs:

- Thêm một bước ADR khi thật sự cần thư viện.

## Follow-Up

- `Package.resolved` được commit để build tái lập.
- Giấy phép của thư viện đi kèm app ghi ở `THIRD_PARTY_NOTICES.md` (từ 2026-10-20, repo public): nâng hay thêm thư viện
  thì sửa file đó cùng PR; `scripts/make_dmg.sh` dừng khi giấy phép của ZIPFoundation bản vừa build khác bản chép trong
  file. File giấy phép không phải thư viện, không cần ADR.
- Lỗi đã biết của ZIPFoundation 0.9.20 (xác nhận 2026-10-15, bản `development` upstream vẫn còn), ExamFile đã né (PR #7):
  1. `Archive(data:)` crash cả tiến trình với zip có offset vượt cuối dữ liệu → mọi chỗ đọc đi qua file tạm + `Archive(url:)` (`SafeArchive`).
  2. `extract(_:consumer:)` không so CRC → ExamFile tự so CRC và kích thước.
  3. Trên Linux, luồng deflate hỏng làm vòng zlib lặp vô hạn → test đổi byte trên Linux chỉ dùng gói không nén. App chỉ chạy macOS nên không ảnh hưởng người dùng; CI Linux có thể treo nếu gặp ca này.
  Khi nâng ZIPFoundation: chạy lại test fuzz trên cả hai nền tảng trước khi bỏ cách né. Nên báo issue upstream.
