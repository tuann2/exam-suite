# Spike giai đoạn 5, bước 1: PDF bằng `ImageRenderer` và String Catalog trong Swift package

Date: 2026-10-16

Thẩm quyền: plan [giai-doan-5-hoan-thien.md](../plans/completed/giai-doan-5-hoan-thien.md) bước 1;
[export-print.md](../product/export-print.md) (phương án 1, mục Trình bày chung), [large-exams.md](../product/large-exams.md)
(ngân sách PDF), [accessibility-localization.md](../product/accessibility-localization.md) (mục Ngôn ngữ). Tài liệu này
ghi **số đo và hiện tượng quan sát được** để bước 4 và 5 làm theo; không đổi phương án đã chốt. Code thử nằm ngoài repo
(thư mục tạm của phiên, không commit); mọi số đo dưới đây có thể chạy lại theo mục "Cách chạy lại".

Máy đo: Mac của người điều phối, Apple M4 Pro, 24 GB, macOS 26.6.2; Xcode 27.0 (27A266a), Swift 6.4, SDK macOS 27,
deployment target macOS 15. Không mở app nào; chỉ chạy công cụ dòng lệnh và `swift test`/`xcodebuild build`.

## Kết luận

1. **Cách A đạt ngân sách.** PDF đề chuẩn 2.000 câu có đáp án (10% câu có ảnh): **15–18 s** ở Release, **16–17 s** ở
   Debug (ngân sách ≤ 30 s Release, giới hạn chặn ≤ 120 s Debug); bộ nhớ đỉnh **~180–200 MB** (ngân sách ≤ 1 GB);
   **928–1.022 trang** A4. Không cần dựng cách B.
2. **Phông PDF đổi sang Helvetica Neue (Nt0 chốt 2026-10-16, export-print.md phương án 13):** với phông hệ
   thống **SF Pro**, mọi chữ **Đ hoa (U+0110)** trong PDF được
   PDFKit đọc lại thành **Ð (U+00D0, chữ "eth")**; tìm "Đáp án đúng" trong PDF ra 0 kết quả. Các chữ tiếng Việt khác
   (161/162 dạng thử) đọc lại đúng. Lỗi nằm ở đường vẽ chữ theo glyph của SwiftUI **và** TextKit (cách B cũng bị), không
   ở `ImageRenderer` riêng. Đổi phông thân bài sang **Helvetica Neue** (có sẵn trong macOS, không phải phông ngoài) thì
   đọc lại đúng 100%. Đã chốt: PDF dùng Helvetica Neue cho chữ thân và đề mục, SF Mono cho mã.
3. **String Catalog trong package:** dùng **`bundle: .module`** (không dùng `#bundle`); app phải khai báo cả `vi` và `en`
   ở bundle chính (package đi theo ngôn ngữ mà bundle chính chọn); phát hiện chuỗi chưa vào catalog bằng
   **`xcodebuild -exportLocalizations` rồi `git diff --exit-code -- '*.xcstrings'`**; phát hiện **quên `bundle:`** chỉ làm
   được bằng quét mã nguồn (nguyên mẫu bắt đủ 5/5 ca thử, trên repo hiện có 588 lời gọi cần sửa ở bước 4).
4. **Hệ quả cho test:** trong tiến trình `swift test`, bundle chính không có ngôn ngữ nên chuỗi của package luôn ra
   **tiếng Anh** khi catalog có `en`; test so chữ giao diện tiếng Việt (nằm trong 31 file test có
   `#expect(… == "<chữ có dấu>")`) sẽ đỏ ở bước 7 nếu không khoá ngôn ngữ.

## 1. PDF: cách A

### Bộ đo

Công cụ dòng lệnh SwiftPM (phụ thuộc `ExamKit` và `StudentShell` của repo qua `path:`, không sửa repo):

- **Đề chuẩn** sinh bằng seed cố định theo large-exams.md: 2.000 câu / 20 phần; 80% một đáp án, 20% nhiều đáp án;
  5% câu 8–12 lựa chọn; câu 200–600 ký tự tiếng Việt có dấu (NFC) với đậm/nghiêng/mã inline; giải thích 50%; 200 ảnh
  PNG 1600×1000 không trùng (~380 KB mỗi ảnh, tổng 76 MB, nặng hơn mức 300 KB của bảng). Thêm ca khó: cứ 50 câu có một
  câu chứa từ rất dài (URL 110 ký tự, đường dẫn registry trong mã inline, một "từ" tiếng Việt 110 ký tự không khoảng
  trắng); 5 câu nhiều đoạn dài hơn một trang.
- **Khối**: đầu đề, đề mục phần, khối câu (đầu câu "Câu N/2000 · Phần", từng đoạn Markdown, ảnh, "Chọn N đáp án", từng
  lựa chọn với ô đánh dấu + "Đáp án đúng", khung Giải thích). View chỉ dùng `Text`/`Image`/hình, nền trắng chữ đen,
  `.environment(\.colorScheme, .light)`. Đây là PDF đề có đáp án (Admin); PDF kết quả "Xem lại tất cả" có cùng dạng khối.
- **Bộ dựng trang** (A4 595×842 pt, lề 51 pt = 18 mm, chân trang 28 pt): lượt 1 đo chiều cao từng khối bằng
  `ImageRenderer` (`proposedSize` = bề rộng vùng in, chỉ lấy kích thước, không vẽ) rồi xếp tham lam; đề mục phần đi cùng
  khối sau; khối cao hơn chỗ còn lại sang trang mới; khối cao hơn cả trang tách theo phần (đoạn/ảnh/lựa chọn/giải thích),
  phần sang trang mới mở bằng "Câu N (tiếp)". Lượt 2 vẽ từng trang vào `CGContext` PDF (`beginPDFPage` →
  `ImageRenderer.render` từng khối ở vị trí đã xếp → chân trang "Trang N/M"), mỗi trang trong `autoreleasepool`.
- **Ảnh** giải mã đồng bộ bằng `CGImageSource` (không `.task`): `thumb` = thu nhỏ còn tối đa 986 px (2× bề rộng vùng
  in), `full` = ảnh gốc.
- Đo: `Date` quanh từng lượt; khoảng chặn main actor = lâu nhất của một nhóm 20 khối khi đo và của một trang khi vẽ;
  bộ nhớ = `phys_footprint` và đỉnh `ledger_phys_footprint_peak` của tiến trình (`task_info`), như cột Bộ nhớ của Activity
  Monitor.

### Số đo (đề chuẩn 2.000 câu)

| Cấu hình | Trang | Tổng | Đo + xếp | Vẽ | Giải mã ảnh (397 lần) | Chặn lâu nhất: 20 khối đo / 1 trang vẽ | Bộ nhớ đỉnh | Cỡ PDF |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Release, SF Pro, ảnh thu nhỏ | 1.022 | **15,0 s** | 5,8 s | 9,2 s | 3,5 s | 126 ms / 24 ms | 178 MB | 43 MB |
| Release, SF Pro, ảnh gốc | 1.022 | 18,4 s | 5,3 s | 13,1 s | 2,4 s | 77 ms / 52 ms | 198 MB | 77 MB |
| Release, Helvetica Neue, ảnh thu nhỏ | 928 | **16,1 s** | 6,4 s | 9,7 s | 3,7 s | 96 ms / 36 ms | 178 MB | 41 MB |
| Debug, SF Pro, ảnh thu nhỏ | 1.022 | 15,6 s | 6,1 s | 9,5 s | 3,5 s | 80 ms / 26 ms | 178 MB | 43 MB |
| Debug, Helvetica Neue, ảnh thu nhỏ | 928 | **17,2 s** | 7,1 s | 10,0 s | 4,0 s | 168 ms / 43 ms | 170 MB | 41 MB |

- "Bộ nhớ đỉnh" gồm cả đề và 76 MB ảnh đã nạp sẵn (86 MB trước khi dựng PDF). Debug gần bằng Release vì gần hết thời
  gian nằm trong SwiftUI/Core Graphics (đã tối ưu sẵn), không ở code của mình.
- Mỗi khối đo ~3 ms (trung bình, gồm giải mã ảnh), mỗi trang vẽ ~9–10 ms; ảnh được giải mã hai lần (đo và vẽ).
- Nhúng ảnh gốc làm PDF gần gấp đôi (77 so với 43 MB) và chậm hơn 3 s, không thấy khác khi in A4.
- **Đọc lại bằng PDFKit** cả tài liệu (`PDFDocument.string`, `findString`) mất **~29 s** với ~1.000 trang và đẩy bộ nhớ
  lên ~470 MB: chỉ dùng cho spike, không dùng trong test thường.
- **In** (`PDFDocument.printOperation(for:scalingMode: .pageScaleToFit, autoRotate: true)`, `jobDisposition = .save`
  vào file, không hộp thoại, khổ Letter): 928 trang trong **8,8–11,8 s**, trang 612×792 pt (A4 co vừa Letter), cùng số
  ký tự với PDF gốc; thứ tự đọc chữ của nhãn lựa chọn "A. B. C." đôi chỗ khác (do co trang), nội dung không mất.

### Chữ tiếng Việt đọc lại

- Chữ trong PDF là **chữ thật** (chọn, tìm, sao chép được), không phải ảnh; chuỗi đọc lại là **NFC**; Markdown đậm/
  nghiêng/mã inline giữ đúng.
- **SF Pro (phông hệ thống):** 4.369 chữ "Đ" đều đọc lại thành "Ð" (U+00D0), 0 chữ U+0110; `findString("Đáp án đúng")`
  = 0; tiêu đề đề không khớp. Thử riêng toàn bộ bảng chữ (12 nguyên âm × 6 thanh × hoa/thường, `đ`, phụ âm): sai đúng 1
  chữ là `Đ`, ở cả chữ thường đậm, chữ đậm và **New York** (serif hệ thống); **SF Mono** không sai.
- **Helvetica Neue:** 0 chữ sai; `findString("Đáp án đúng")` = 2.396 (đúng bằng số lựa chọn đúng); 1.995/2.000 câu tìm
  thấy nguyên văn (so sau khi bỏ khoảng trắng); 5 câu còn lại là các câu bị tách trang, chen "Câu N (tiếp)" giữa các
  đoạn (đúng thiết kế).
- **Vì sao:** SwiftUI và TextKit vẽ chữ theo glyph, không kèm chuỗi gốc; Core Graphics dựng bảng glyph → Unicode bằng
  tra ngược bảng ký tự của phông. SF Pro dùng **chung một glyph** cho Đ và Ð nên tra ngược ra Ð. CoreText vẽ dòng
  (`CTLineDraw`/`CTFrameDraw`) giữ chuỗi gốc nên đúng với cả SF Pro. Đã thử: `NSAttributedString.draw`, `NSTextView`
  TextKit 1 và TextKit 2 (`dataWithPDF`) đều ra Ð, nên **cách B không chữa được** khi vẫn dùng SF Pro.
- Mắt thường không thấy khác (chữ hiện đúng "Đ"); hậu quả là tìm kiếm, sao chép, trình đọc màn hình trên PDF và test
  PDFKit "chứa tên đề tiếng Việt đúng" của export-print.md.

### Phân trang

- **Từ rất dài** (URL, đường dẫn trong mã inline, "từ" 110 ký tự không khoảng trắng) xuống dòng giữa ký tự ở mép cột,
  không tràn lề, không tách dấu khỏi chữ.
- **Ảnh** vừa bề rộng vùng in, cao tối đa 1/3 trang, giữ tỉ lệ.
- **Khối cao hơn một trang**: 7–8 khối/đề chuẩn, tách đúng giữa các phần, mỗi phần mới mở bằng "Câu N (tiếp)"; không
  phần nào cao hơn một trang trong đề chuẩn. Một **đoạn** cao hơn cả trang (chưa gặp) sẽ cần tách tiếp theo câu/dòng.
- Xếp tham lam để lại khoảng trắng cuối trang khi khối sau không vừa (đúng quy tắc "khối câu ưu tiên nằm trọn một
  trang"); trung bình ~2 câu/trang.
- Chân trang một dòng bị cắt "…" khi tên đề dài: bước 5 cần hai dòng hoặc chỉ cắt tên đề.

### Giới hạn của `ImageRenderer` trên macOS (đã kiểm)

- **Không vẽ** (thay bằng ô vàng có biển cấm): `Button` kiểu mặc định, công tắc của `Toggle`, `TextField`, thanh của
  `ProgressView`, `ScrollView`, `List`. **Vẽ được**: `Text` (kể cả `.textSelection(.enabled)`), `Button` kiểu `.plain`
  (chỉ nhãn), `Label`/SF Symbol, hình, `Image`.
- **`.task` không chạy** (`.onAppear` có chạy). Vì vậy `QuestionImageView` của SessionFeature (giải mã ảnh trong
  `.task`) ra **khoảng trống**; vẽ `QuestionPreview` thật có ảnh thì mất ảnh, và dòng "Không hiện được ảnh" cũng không
  hiện (độ mờ 0 khi chưa giải mã).
- **Màu**: `ImageRenderer` không theo giao diện vẽ của AppKit (`NSAppearance`) mà theo `\.colorScheme` của môi trường;
  với `.dark`, `.primary` ra `#D8D8D8` và màu động `NSColor(name:)` ra biến thể tối. Phải đặt `.colorScheme(.light)` ở
  gốc mọi view báo cáo (chưa kiểm được trong app đang Dark Mode vì không chạy app; test tay ở bước 5).
- Chạy được trong tiến trình dòng lệnh không có vòng lặp `NSApplication`; phải ở main actor.

### Khuyến nghị cho bước 5 (và 6)

1. Giữ cách A. View báo cáo riêng (không dùng lại `QuestionPreview`/`QuestionImageView`); dùng lại `MarkdownText`
   (đang `internal` trong SessionFeature: chuyển sang target dùng chung hoặc mở `public`).
2. Gốc mọi view báo cáo: `.environment(\.colorScheme, .light)` + màu chữ đen tường minh.
3. Phông: Helvetica Neue cho chữ thân và đề mục, SF Mono cho mã inline (export-print.md phương án 13); test PDFKit so
   chữ "Đ…" nguyên văn (không chuẩn hoá Ð → Đ) để bắt khi có ai đổi lại SF Pro.
4. Lượt xếp trang lấy cỡ ảnh từ thuộc tính (`CGImageSourceCopyPropertiesAtIndex`, không giải mã); chỉ giải mã khi vẽ,
   thu nhỏ còn ≤ 2× bề rộng vùng in. Có thể giải mã trước ngoài main actor (`CGImageSource` an toàn đa luồng).
5. Nhường main actor (`await Task.yield()`) sau mỗi trang khi vẽ và sau mỗi ~8 khối hoặc ~30 ms khi đo, để khoảng chặn
   ≤ 100 ms (đo thấy tới 168 ms cho 20 khối ở Debug); tiến độ "Đang dựng trang N…" lấy từ đây; Huỷ kiểm giữa các trang.
6. Khối quá cao: tách theo phần như spike; đoạn quá cao thì tách theo câu (thêm test với một đoạn dài hơn một trang).
7. Test PDFKit dùng đề nhỏ (vài chục câu) cho kiểm chữ; test `Timing` 2.000 câu chỉ đo thời gian, không đọc lại toàn bộ
   chữ (~29 s).
8. In: `PDFDocument.printOperation(for:scalingMode: .pageScaleToFit, autoRotate: true)`; trong test đặt
   `jobDisposition = .save` + `jobSavingURL` vào thư mục tạm, `showsPrintPanel = false`, `showsProgressPanel = false`.

## 2. String Catalog trong Swift package

### Ví dụ tối thiểu

Package `defaultLocalization: "vi"`, macOS 15, target thư viện có `Resources/Localizable.xcstrings` (`sourceLanguage`
`vi`, bản dịch `en`, một khoá plural), một app XcodeGen (`options.developmentLanguage: vi`, `InfoPlist.xcstrings` vi/en)
phụ thuộc target đó, công cụ dòng lệnh thử tra chuỗi, và một test target.

### `bundle: .module` hay `#bundle`

- Cả hai trỏ cùng một bundle tài nguyên của target (`#bundle == .module` cho kết quả `true`).
- `#bundle` khai báo `@available(macOS 12, …)` trong SDK của Xcode 27 và biên dịch được với deployment target macOS 15
  (cả `swift build` lẫn `xcodebuild`). Ở target **không có tài nguyên**, `#bundle` là lỗi biên dịch "No resource bundle
  is available for this module" (cờ `SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE`); `.module` cũng không tồn tại ở đó.
- Macro `#bundle` chỉ có trong FoundationMacros của SDK mới (Xcode 26 trở lên); job `apps-macos` của CI chọn Xcode
  27/26/16 tuỳ máy runner. **Khuyến nghị `bundle: .module`**: cùng ngữ nghĩa, chạy với mọi Xcode.

### Catalog được biên dịch ở đâu

| Lệnh | Kết quả |
| --- | --- |
| `swift build` / `swift test` (hệ build mặc định `swiftbuild` của Swift 6.4) | `<Package>_<Target>.bundle/Contents/Resources/en.lproj/Localizable.strings` và `.stringsdict` (plural); **không có** `vi.lproj` (khoá nguồn chính là chữ tiếng Việt); `Info.plist` của bundle có `CFBundleDevelopmentRegion = vi`; trình biên dịch ghi `.stringsdata` (`-emit-localized-strings`) |
| `swift build --build-system native` (đã deprecated) | Chép nguyên file `.xcstrings` vào bundle, **không biên dịch**: tra tiếng Anh vẫn ra tiếng Việt |
| `xcodebuild build` (app XcodeGen) | Bước `CompileXCStrings` (xcstringstool): `L10n App.app/Contents/Resources/L10n_L10nDemo.bundle/Contents/Resources/en.lproj/Localizable.strings` + `.stringsdict`; `InfoPlist.xcstrings` của app ra `vi.lproj/InfoPlist.strings` và `en.lproj/InfoPlist.strings` ở bundle chính |

Không lệnh build nào sửa file catalog nguồn.

### App chọn ngôn ngữ thế nào

Thử bằng công cụ dòng lệnh nhúng `Info.plist` (`CFBundleDevelopmentRegion = vi`, `CFBundleLocalizations = vi, en`) vào
binary để bundle chính giống app, đổi thứ tự ngôn ngữ bằng tham số `-AppleLanguages` (miền tham số, không ghi
`defaults`):

| Ngôn ngữ ưu tiên | Bundle chính chọn | Chuỗi của package (`bundle: .module`) | SwiftUI `Text(_:bundle:)` (vẽ qua `ImageRenderer`) |
| --- | --- | --- | --- |
| `vi` | vi | Thư viện | Thư viện |
| `en` | en | Library | Library |
| `fr, en` | en | Library | Library |
| `fr` | vi | Thư viện | Thư viện |
| `ja` | vi | Thư viện | Thư viện |
| `fr, vi, en` | vi | Thư viện | Thư viện |

- **Package đi theo ngôn ngữ mà bundle chính chọn**, khớp phương án 1 của accessibility-localization.md (không có vi/en
  trong danh sách thì tiếng Việt). Ngôn ngữ riêng cho app trong System Settings ghi vào cùng khoá `AppleLanguages` của
  app; danh sách app ở đó chỉ hiện app có từ hai ngôn ngữ trở lên (hành vi của macOS, cần test tay).
- **Bundle chính không khai báo ngôn ngữ** (công cụ dòng lệnh trơn, và trình chạy `swift test`
  `…/usr/libexec/swift/pm`): chọn `en` dù `AppleLanguages = (vi)`; đặt `AppleLanguages` qua miền tạm (volatile) trong
  test cũng không đổi được. ⇒ App **phải** có `vi` và `en` ở bundle chính (`InfoPlist.xcstrings` hoặc
  `CFBundleLocalizations`), nếu không cả app kẹt một ngôn ngữ.
- `LocalizedStringResource` mặc định dùng `Locale.current`; với `fr`/`ja` (ngôn ngữ app không có), `Locale.current` ra
  `en_VN` trong khi tra theo bundle ra `vi`: một `Text(LocalizedStringResource)` sẽ hiện tiếng Anh cạnh chữ tiếng Việt.
  Tránh dựa vào locale mặc định của `LocalizedStringResource` ở giao diện.
- Khoá ngôn ngữ khi test: `LocalizedStringResource(key, bundle: .module)` rồi đặt `.locale = Locale(identifier: "en")`
  (hoặc `"vi"`) và `String(localized:)` → ra đúng ngôn ngữ (đã chạy trong `swift test`, cả plural "3 questions").
  **`String(localized:bundle:locale:)` không chọn ngôn ngữ** (locale chỉ định dạng số/ngày): dòng "Test Swift" của
  accessibility-localization.md mục Kiểm đã sửa theo đó (tra bằng `LocalizedStringResource` có `locale`). Với view SwiftUI: `.environment(\.locale, Locale(identifier: "en"))` đổi được
  `Text(_:bundle:)` (dùng cho snapshot/PDF tiếng Anh).

### Quên `bundle:`

- `Text("…")`, `Button("…")`, `Label("…", …)`, `String(localized: "…")`, `LocalizedStringResource("…")` trong package mà
  không có bundle tra **bundle chính** của app: khoá (chữ tiếng Việt) hiện ra cả khi giao diện tiếng Anh, **không có lỗi
  hay cảnh báo**. Đã thử: khoá có bản dịch `en` trong catalog của module vẫn hiện tiếng Việt khi quên bundle.
- Trình biên dịch vẫn trích chuỗi đó vào catalog của module (`.stringsdata` chỉ ghi khoá, chú thích, vị trí; không ghi
  bundle), nên kiểm catalog **không** bắt được lỗi này.
- Bắt bằng quét mã nguồn: nguyên mẫu Python (đối số đầu là chuỗi literal của API tiêu đề SwiftUI, `String(localized:)`,
  `LocalizedStringResource`, `AttributedString(localized:)`, `.help`/`.accessibilityLabel`… mà trong lời gọi không có
  `bundle:` hay `verbatim:`; bỏ qua dòng có `// l10n-ignore`) bắt đủ 5/5 ca quên trong ví dụ, không báo nhầm ca có
  bundle. Trên `Packages/ExamFeatures/Sources` hiện tại: **588 lời gọi** (LibraryFeature 173, SessionFeature 215,
  AuthoringFeature 194, AdminShell 6; LibraryData, AuthoringData, ExamImport, StudentShell 0), trong đó
  `String(localized:)` 277, `Text` 118, `Button` 81, `Label` 54, phần còn lại `LabeledContent`, `TextField`, `Section`,
  `Picker`, `Toggle`, `Menu`, `Stepper`, `ContentUnavailableView`. Lưới an toàn thứ hai: UI test luồng 1 tiếng Anh của
  bước 7 (không còn chữ tiếng Việt của giao diện).

### Phát hiện chuỗi chưa vào catalog

| Cách | Kết quả |
| --- | --- |
| **`xcodebuild -exportLocalizations -project … -scheme … -exportLanguage en -localizationPath <tạm>`** | **Đồng bộ catalog nguồn**: thêm khoá mới (mục rỗng), đánh dấu khoá không còn dùng `"extractionState" : "stale"`, thêm khoá Info.plist (`CFBundleName`, trạng thái `new`), ghi theo định dạng của Xcode. Chạy lần hai không đổi gì (ổn định). Phủ cả target app và mọi target package. 8 s với ví dụ |
| `swift build` rồi `xcrun xcstringstool sync <bản sao catalog> --stringsdata <các .stringsdata của target>` | Cùng khoá và trạng thái với cách trên (đã so); không cần `.xcodeproj` |
| `xcrun xcstringstool extract` (phân tích cú pháp nhẹ, không build) | **Sai** với chuỗi có nội suy (ra `%arg câu` thay `%lld câu`, đánh dấu nhầm khoá plural là stale): không dùng |

Không lệnh build nào đồng bộ catalog (khác Xcode IDE, nơi build có đồng bộ), nên bước kiểm phải chạy riêng.

### Khuyến nghị cho bước 4

1. `Package.swift`: `defaultLocalization: "vi"`; mỗi target có chữ giao diện có `Localizable.xcstrings` (resources
   `.process`); giữ hệ build mặc định của `swift test` (không ép `--build-system native`).
2. Mọi chữ giao diện trong package chỉ rõ **`bundle: .module`**: `Text("…", bundle: .module)`,
   `String(localized: "…", bundle: .module)`; với API chỉ nhận chuỗi (`Button`, `Label`, `Toggle`, `Picker`, `Section`,
   `TextField`, `Menu`, `LabeledContent`…) dùng dạng nhận `Text`/nhãn hoặc một hàm trợ giúp của module trả
   `LocalizedStringResource(key, bundle: .module)` (đã thử: trình biên dịch vẫn trích chuỗi qua tham số
   `String.LocalizationValue`, kể cả nội suy ra `%lld`); nếu dùng hàm trợ giúp thì đặt `locale` theo ngôn ngữ bundle
   chính đã chọn (`Bundle.main.preferredLocalizations.first`) để tránh lệch với `fr`/`ja` ở trên.
3. App (project.yml): `options.developmentLanguage: vi` (ra `developmentRegion = vi`, `knownRegions` Base/en/vi),
   `CFBundleDevelopmentRegion = vi`, `InfoPlist.xcstrings` có `vi` và `en` ở mỗi app (bắt buộc để app có hai ngôn ngữ);
   dịch hoặc đánh dấu không dịch `CFBundleName` mà xuất localization tự thêm.
4. `scripts/check_localization.py` (Python thuần, chạy cả Linux, trong `check.sh`): trạng thái/định dạng của catalog như
   accessibility-localization.md, cộng phần quét **quên `bundle:`** (luật trên, kèm đối chứng âm).
5. `verify_local.sh`: sau `xcodegen generate`, chạy `xcodebuild -exportLocalizations` cho hai scheme vào thư mục tạm,
   rồi `git diff --exit-code -- '*.xcstrings'`; khác thì thất bại và in khoá mới/stale. Catalog commit lần đầu nên do
   chính bước này tạo (định dạng của Xcode) để lần sau không lệch định dạng.
6. Test: thêm hàm trợ giúp tra theo ngôn ngữ cố định (`LocalizedStringResource` + `locale`); test hiện so chữ tiếng Việt
   (nằm trong 31 file của `Packages/ExamFeatures/Tests` có `#expect(… == "<chữ có dấu>")`) sẽ đỏ khi catalog có `en`
   (bước 7) vì `swift test` chọn `en`: bước 4 thêm một test khẳng định hành vi này và chọn cách sửa (so qua hàm trợ
   giúp `vi`, hoặc cho model nhận ngôn ngữ tiêm vào) trước bước 7.

## Cách chạy lại

Code thử không commit (đúng plan bước 1). Dựng lại theo mô tả ở mục 1 ("Bộ đo") và mục 2 ("Ví dụ tối thiểu"): một
package SwiftPM ngoài repo phụ thuộc `Packages/ExamKit` và `Packages/ExamFeatures` (product `StudentShell`, đủ để
`import SessionFeature`), chạy `swift build -c release` rồi công cụ với đề sinh sẵn; ví dụ String Catalog dựng bằng
`xcodegen generate` + `xcodebuild build` (không chạy app) và soi `.app/Contents/Resources`. Bộ sinh đề chuẩn chính thức
và `Timing` thuộc bước 2.
