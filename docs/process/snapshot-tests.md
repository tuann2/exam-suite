# Snapshot test sáng/tối

Thẩm quyền: [ADR 0010](../decisions/0010-snapshot-testing.md), plan giai đoạn 5 bước 3. Code:
`Packages/ExamFeatures/Tests/ExamFeaturesSnapshotTests` (helper ở `Support/SnapshotHost.swift`), ảnh tham chiếu ở
`__Snapshots__/<file test>/<tên test>.<light|dark>-<rộng>x<cao>[-end].png` (`-end`: nội dung chính đã cuộn tới cuối;
cửa sổ chính 960×640, sheet Trước khi thi 600×640) và trang PDF ở `<tên test>.light-a4-page<N>.png` (giai đoạn 5 bước 8a).

## Có gì

- Cửa sổ làm bài, Trước khi thi, Kết quả, Xem lại bài, Thư viện lưới/danh sách, soạn đề (cả báo cáo import): sáng và
  tối; ba ảnh tiếng Anh (làm bài, Kết quả, Xem lại bài; chỉ sáng).
- Trang 1 của PDF kết quả và PDF đề (`ReportSnapshotTests`, export-print.md mục Kiểm chứng): PDF dựng bằng
  `ReportRenderer` như Xuất PDF…, trang vẽ ra ảnh 1x (điểm ảnh = point, A4 595×842) bằng Core Graphics
  (`SnapshotHost.assertPDFPage`), không qua cửa sổ nên không theo sáng/tối; cùng độ chính xác như ảnh cửa sổ.
- Hộp xác nhận Import đề (bản Admin; lỗi beta G6.2): ảnh sáng tiếng Việt và tiếng Anh ở **đúng cỡ cửa sổ thật**, không
  phải 960×640: cửa sổ Import đề cỡ theo nội dung (`.windowResizability(.contentSize)`) và mở ở cỡ nhỏ nhất của nội dung,
  nên ảnh đo cỡ đó trong cửa sổ chụp (`SnapshotHost.minimumContentSize`) và mang cỡ trong tên
  (`importConfirmProblems.light-480x494.png`). Nội dung đổi chiều cao thì tên ảnh đổi theo: ghi lại và xoá ảnh cũ. Cùng
  suite, không so ảnh tham chiếu: `importConfirmEmptyFieldsHaveBorder` đo trên ảnh chụp (sáng, tối) rằng ô trống có viền
  ở cả bốn cạnh (từng cạnh: dòng điểm ảnh quanh mép khung ô chữ AppKit so với nền trong ô, ngưỡng 1,12:1; đối chứng âm: ô
  không viền của `Form` `.grouped` đo phẳng, ô có nền ô mà không viền đo 1,07 sáng, 1,09 tối, dưới ngưỡng). Sau khi nâng macOS/Xcode, test đỏ vì viền hệ thống nhạt hơn thì đo lại và
  ghi số mới cạnh ngưỡng (`borderContrast`), không hạ ngưỡng xuống mức của ô không viền (1,07–1,09).
- Cùng target, không chụp ảnh: `TiledWindowLayoutTests` đo cỡ nhỏ nhất của nội dung ở độ rộng 0 (cửa sổ xếp lát của
  macOS 26; plan giai đoạn 5, Decisions 2026-10-18); `ContentSizedWindowTests` đòi cỡ nhỏ nhất bằng cỡ lý tưởng ở cửa sổ và
  sheet cỡ theo nội dung (Import đề, hộp chọn Xuất PDF/In; lỗi beta G6.2, có đối chứng âm).

## Chạy

- Runner chính thức: `swift test --package-path Packages/ExamFeatures` (bước 4 của `scripts/check.sh`, nên cũng
  trong `scripts/verify_local.sh`). Đã kiểm 2026-10-16 (macOS 26.6, Xcode 27.0): `swift test` và `xcodebuild test
  -scheme ExamFeatures-Package -only-testing:ExamFeaturesSnapshotTests` ghi ra ảnh giống hệt từng byte, nhưng chỉ
  `swift test` là bằng chứng; đừng ghi lại ảnh bằng runner khác.
- Chỉ macOS có Xcode. Cài đặt hiển thị phải ở mặc định; khác thì test báo lỗi rõ thay vì so ảnh sai (đọc được bằng API
  công khai nên được kiểm): Increase Contrast, Reduce Transparency, Differentiate Without Color, Invert colors tắt;
  cỡ chữ hệ thống mặc định (body 13 pt; Accessibility › Display › Text size).
- Màn hình nào cũng được: cửa sổ chụp luôn vẽ ở 2x (`SnapshotWindow.backingScaleFactor`), kể cả khi màn hình chính là
  màn ngoài 1x hay Mac mini với màn 1080p. Không ép được 2x thì test báo "Không vẽ được ở 2.0x" (`scaleProblem`, có
  test mô phỏng 1x trong `SnapshotHostTests`).
- Ngôn ngữ/vùng (`vi_VN`), màu nhấn xanh, thanh cuộn nổi, cỡ biểu tượng sidebar được ghim trong bộ nhớ của tiến
  trình test (không ghi `defaults`), để ngôn ngữ hay màu nhấn của máy không làm lệch ảnh.
- Thất bại thì Swift Testing đính kèm `reference.png`, `failure.png`, `difference.png` vào kết quả test.

## Ghi lại ảnh tham chiếu

Chỉ ghi lại khi **cố ý** đổi giao diện, hoặc sau khi nâng macOS/Xcode làm lệch phông/cách vẽ (ảnh tham chiếu ghi trên
Mac của người điều phối, máy chạy `verify_local.sh`):

```sh
EXAMSUITE_SNAPSHOT_RECORD=all swift test --package-path Packages/ExamFeatures --filter ExamFeaturesSnapshotTests
swift test --package-path Packages/ExamFeatures --filter ExamFeaturesSnapshotTests   # phải xanh
git status Packages/ExamFeatures/Tests/ExamFeaturesSnapshotTests/__Snapshots__
```

- `EXAMSUITE_SNAPSHOT_RECORD=failed` chỉ ghi ảnh đang khác; `missing` chỉ ghi ảnh chưa có. Không đặt biến (mặc định)
  thì không bao giờ ghi; thiếu ảnh tham chiếu là thất bại. Lần ghi luôn báo thất bại ("Record mode is on"), chạy lại
  không biến để kiểm.
- Mở từng ảnh đổi và xem bằng mắt (sáng và tối) trước khi commit; mỗi ảnh ≤ 300 KB (PNG 1x).
- Đổi do nâng macOS/Xcode: một PR riêng chỉ có ảnh, ghi phiên bản macOS/Xcode vào mô tả PR. Đổi do sửa giao diện:
  ảnh mới đi cùng PR đó. Người duyệt xem ảnh khác biệt trên GitHub.
- Thấy khối trắng hoặc chữ biến mất ở sidebar, inspector, thanh công cụ sau khi nâng macOS: cách vẽ Liquid Glass đã
  đổi; sửa `Support/GlassFlattener.swift` (tên lớp kính, bộ lọc `vibrantColorMatrix`) trước khi ghi lại.

## Giới hạn

- Phụ thuộc chỉ để test nhưng nằm trong đồ thị gói của `Packages/ExamFeatures`: mọi lần resolve (kể cả build app bằng
  `xcodebuild`) đều tải swift-snapshot-testing, swift-custom-dump, swift-issue-reporting, swift-syntax và bản build sẵn
  MacroSupport của swift-syntax (khoảng 115 MB mỗi thư mục build). Không gói nào được biên dịch hay link vào app (ADR
  0006).

- Cài đặt không đọc được bằng API công khai, nên không ghim, không kiểm: phải để mặc định trên máy ghi và máy chạy:
  Show toolbar button shapes (Accessibility › Display), kiểu biểu tượng và widget (Appearance › Icon & widget style),
  kiểu Liquid Glass Clear/Tinted (Appearance, macOS 26.1+). Thông báo khi ảnh lệch nhắc lại danh sách này.

- Liquid Glass do WindowServer ghép: khi chụp, lớp kính bị ẩn và chữ vibrant được tô theo ma trận màu của nó (xấp
  xỉ). Hiệu ứng kính, độ trong suốt và tương phản thật vẫn cần test tay Dark Mode.
- Chữ và biểu tượng vibrant (thanh bên, inspector): nội dung của lớp (chữ SwiftUI là `CATintedImage`/backing store,
  biểu tượng có màu nhân `contentsMultiplyColor`) được vẽ ra ảnh bằng `render(in:)` rồi mới áp ma trận
  `vibrantColorMatrix` và đặt vào một lớp con tạm (`GlassFlattener`, giai đoạn 5 bước 8a). Trước đó chữ thanh bên ở ảnh
  tối ra màu gốc (gần như đen) và biểu tượng phụ ở ảnh sáng không thấy: đó là lỗi của cách chụp, không phải của app.
- Vật liệu (`.background(.bar)`, nền thanh "Thêm phần / Thêm câu" của cây đề, thanh lỗi) là `CABackdropLayer` làm mờ nội
  dung phía sau, bị ẩn khi chụp: chữ cuộn dưới thanh hiện rõ trong ảnh, còn app thật làm mờ.
- Cửa sổ không lên màn hình; app và cửa sổ được coi là đang dùng (nút nổi bật có màu nhấn). Không chụp được sheet,
  popover, menu.
