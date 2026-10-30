# Kế hoạch xây dựng Exam Suite cho iOS (bản Học viên)

Soạn: 21/10/2026 · Sửa: 30/10/2026 (rà lại sau khi Android v1 xong; Nt0 chốt **hành vi theo bản macOS, không theo các
luật riêng của Android trong `mobile.md`**, và **tự tạm dừng khi app xuống nền**; lộ trình còn 4 PR; cùng ngày Nt0 chốt
mọi câu của bảng Quyết định) · Trạng thái: **đã chốt quyết định, vào thẩm quyền khi PR I0 merge** (I0 chép các quyết
định vào ADR và `mobile.md`). Android làm trước (Q13 của [plan-android-v1.md](plan-android-v1.md)), v1 xong
ngày 23/10/2026 (bản 0.1.0). Phần rà soát cách làm bản macOS ở
[notes/ra-soat-cach-lam-macos.md](../notes/ra-soat-cach-lam-macos.md); quy tắc chống test trùng ở plan Android Phần 4;
cả hai không chép lại.

## Tóm tắt

Xây app iPhone **chỉ cho học viên luyện tập**, **hành vi theo các tài liệu của bản macOS** (library.md, exam-taking.md,
exam-session.md, scoring.md…). Các luật riêng của Android trong `mobile.md` (sao chép đề vào app, Cập nhật đề, lưu phiên
dở, không sao lưu) **không áp** cho iOS. iOS chỉ khác macOS ở chỗ nền tảng bắt buộc và ở một quyết định mới: app xuống
nền thì tự tạm dừng (Phần 2).

Khác Android ở một điểm quyết định chi phí: **lõi và tầng dữ liệu của bản macOS dùng lại** (ExamKit, ExamFile chỉ
`import Foundation` theo ADR 0008; LibraryData không có SwiftUI/AppKit), còn model trình bày của Thư viện, làm bài, Kết
quả, Xem lại là Swift thuần nên tách ra dùng chung được. Chỉ viết mới phần view cho màn hẹp và phần nhận file của iOS.
Không có lõi thứ hai, không cần oracle parity.

| Hạng mục | Đề xuất |
| --- | --- |
| Công nghệ | Swift 6, SwiftUI, SwiftData (kho hiện có), iOS 18+ (QI1: cùng thế hệ SDK với macOS 15 mà repo đang dùng; iPhone XS/XR 2018 trở lên) |
| Lõi | ExamKit, ExamFile dùng nguyên, chỉ thêm lý do tạm dừng `background`; LibraryData dùng nguyên (dời sang package dùng chung `Packages/SharedFeatures` ở I1), thêm phần truy cập file có security scope của iOS; ExamKit thêm `.iOS(.v18)` ở I1 |
| Giao diện | Tách model trình bày khỏi AppKit thành module dùng chung trong `Packages/SharedFeatures` (I1); view iPhone viết mới trong package riêng `Packages/MobileFeatures`; `Packages/ExamFeatures` giữ chỉ macOS (ADR 0013) |
| Repo | Cùng `project.yml`, target `ExamSuiteiOS` (bundle ID `vn.io.nt0.examsuite.ios`, QI3), UI test `ExamSuiteiOSUITests` |
| Quy mô | **v1: 4 PR, 3 cổng**; 2 PR rủi ro cao (I0 chạm `project.yml` và script kiểm ranh giới hai bản app; I1 tách module, chạm bản macOS đã phát hành); v1.1: 3 PR |
| Kiểm thử | Dùng lại mọi lớp hiện có (`check.sh`, snapshot, XCUITest, `check_localization.py`, bảng màu); mới chỉ có ảnh snapshot iPhone, 3 lần mở app XCUITest trên simulator, ~15 test cho phần iOS thêm |
| Phân phối | v1 **chỉ cài qua Xcode** bằng Personal Team miễn phí (QI4, QI14): bản cài hết hạn sau 7 ngày, cắm máy vào Mac để cài lại; chưa phát cho người khác. Khi cần phát cho học viên: đăng ký Apple Developer (99 USD/năm) và chọn TestFlight hay Ad Hoc, là quyết định mới. App Store công khai: ngoài phạm vi |
| Ràng buộc | Cổng GI2, GI3 cần **một iPhone thật**; Nt0 có hoặc mượn được (QI5) |

## Phần 1 · Vì sao iOS rẻ hơn về code nhưng khó hơn về cổng

Số đo ở `main` 282ec86 (23/10/2026; mã macOS không đổi từ 265ab44): `wc -l`, dòng `import` của từng file.

| Module | Dòng | File dính AppKit | Trên iOS |
| --- | --- | --- | --- |
| ExamKit + ExamFile | 3.685 | 0 | Dùng nguyên; thêm `PauseReason.background` (I2) |
| LibraryData | 3.012 | 0 (bookmark không security scope vì app macOS không sandbox) | Dùng nguyên (dời sang `Packages/SharedFeatures` ở I1): bookmark, trạng thái file, trùng id như library.md. iOS thêm mở/đóng quyền security scope khi tạo bookmark và khi đọc file (I2). `AppLaunchStorage` dùng được trên simulator (spike I0) |
| LibraryFeature | 3.859 | 5 / 25 (`LibraryModel` chỉ ở giá trị mặc định `NSWorkspace` của **Hiện trong Finder**, `LibraryStyle`, `PaletteColors`, `PresentationTermination`, `Localized`) | Tách phần không AppKit (~1.900 dòng): `InterfaceStrings`, `InterfaceLocale`, `ErrorMessages`, `LibraryFormat`, `LibraryPalette`, `LibraryModelTypes`, `EntryStatusPresentation`, `ImportFeedback`, `GridNavigation`, `LibraryAccessibility`, `LibraryPreferences`, và `LibraryModel` (Hiện trong Finder tiêm vào) |
| SessionFeature | 6.696 | 7 / 25 (`SessionAppController`, `ContentZoom`, `ReadingSurface`, `ReadingPalette`, `SessionStyle`, `ResultsReportSheet`, `Localized`) | Tách phần model (~2.300 dòng): `AttemptModel`, `AttemptModelTypes`, `PreExamModel`, `ResultsModel`, `AnswerReviewModel`, `SessionServices` (`SessionEnvironment`), `SessionFormat`, `PlainMarkdown`. `SessionCoordinator` ở lại macOS (cửa sổ, hỏi khi đóng, máy ngủ, Xuất PDF) |
| ReportFeature | 2.509 | 3 / 15 (`ReportPanels`: hộp Lưu và hộp báo lỗi; `ReportPrinting`: hộp In; `ReportTemporaryFiles`: dọn file tạm khi app thoát) | v1.1: bộ dựng PDF (`ImageRenderer` → `CGContext`) chạy trên iOS khi `ReportRenderer` thôi phụ thuộc LibraryFeature; ba file trên chỉ macOS, share sheet thay |

Hệ quả so với Android: không viết lại lõi (A1 của Android), không có tầng dữ liệu mới (A2), không có luật Thư viện
riêng, hạ tầng kiểm có sẵn (Xcode, snapshot, XCUITest, `verify_local.sh`). Đổi lại:

- **Cổng cần máy thật.** Simulator chạy được luồng 1–3, snapshot, XCUITest, mở `.exam` từ app Tệp và Safari, tự tạm
  dừng khi xuống nền; **không** chạy được VoiceOver bằng cử chỉ, không nhận file từ Zalo/Drive thật, không thử được cuộc
  gọi đến, không đo hiệu năng trên phần cứng thật. Các mục này test tay ở cổng GI2.
- **Cài lên máy thật bị giới hạn**: v1 chỉ cài qua Xcode (Personal Team), bản cài hết hạn sau 7 ngày. Phát cho người
  khác cần tài khoản trả phí, chứng chỉ, và Beta App Review nếu dùng TestFlight cho người ngoài nhóm.
- **Mọi PR iOS chạm module dùng chung đều chạy lại kiểm macOS** (snapshot, UI test đủ bộ theo bảng map), vì
  LibraryData, InterfaceCore, SessionModel (`Packages/SharedFeatures`, từ I1) chạy trong cả hai bản.

## Phần 2 · Phạm vi và chỗ iOS khác macOS

Cùng cách chia v1 / v1.1 với Android (Nt0 chốt 2026-10-21), nhưng **hành vi của từng tính năng theo tài liệu macOS**.

### v1

- Thư viện **dạng danh sách** (library.md): tìm (không dấu), sắp xếp, trạng thái file (Không tìm thấy file, Tìm file…,
  Làm mới), Xoá khỏi thư viện có Hoàn tác, đề mẫu lần đầu mở kèm dải chào mừng, Lịch sử thi → Kết quả cũ.
- Thêm đề (hộp chọn file của hệ thống) và mở `.exam` từ app khác; trùng id đề như library.md phương án 1.
- Trước khi thi, Làm bài (Luyện tập/Thi), Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại
  (exam-taking.md, exam-session.md, scoring.md), giữ nguyên mọi quy tắc, kể cả `hideAnswers`, câu đã sửa sau lần thi,
  Kiểm tra đáp án, đánh dấu câu, đồng hồ ba mức, cảnh báo 5/1 phút, so với lần trước, bộ lọc của Xem lại.
- Tự tạm dừng khi app xuống nền (QI10).
- Tiếng Việt (nguồn) và tiếng Anh; số, phần trăm, ngày giờ theo ngôn ngữ giao diện; thang 1000 chữ số trơn.
- Nhãn VoiceOver cho mọi điều khiển, trạng thái luôn có biểu tượng + chữ; sáng/tối theo hệ thống; cỡ chữ theo Dynamic
  Type (QI11).
- Màn Giới thiệu mở từ Thư viện: phiên bản, giấy phép Apache-2.0, NOTICE, ZIPFoundation (QI13).
- Đề 2.000 câu có ảnh mở và cuộn được; ngân sách của large-exams.md áp dụng, đo trên simulator (QI15).

### v1.1 (hoãn)

Xuất PDF kết quả, chia sẻ và In (export-print.md phần Học viên); iPad (cột bên cho bảng câu hỏi); Thư viện dạng lưới,
Thông tin đề, lọc Thư viện, Khôi phục đề mẫu; rà VoiceOver theo đủ bảng mục tiêu, Reduce Motion; Nền đọc (QI11).

### Không làm

Phím tắt và menu (iPhone không có); Hiện trong Finder; Soạn đề, Import, PDF đề (chỉ bản Admin macOS, ADR 0003); đồng bộ
lịch sử giữa máy; App Store công khai.

### Chỗ iOS khác macOS

Chỗ không ghi thì theo tài liệu macOS. Bảng đầy đủ (Nt0 chốt 2026-10-30) chuyển sang mục "Bản iOS" của
[mobile.md](mobile.md) ở PR I0; đó là nơi sửa. Tóm tắt: tham chiếu file tại chỗ và trùng id như library.md (file nhận từ
app khác thì iOS đã chép vào `Inbox`, app dời ra rồi thêm như mọi file); app xuống nền thì tự tạm dừng ("Đã tạm dừng vì
bạn rời app"), không lưu phiên dở; nút Quay lại hỏi "Bỏ bài?"; Dynamic Type thay menu Phóng to, Nền đọc ở v1.1; màn Giới
thiệu thay hộp Giới thiệu; sao lưu theo hệ thống; v1 chỉ iPhone.

## Phần 3 · Kiến trúc

```text
Packages/ExamKit                 platforms thêm .iOS(.v18) (I1); PauseReason thêm background (I2)
Packages/SharedFeatures (MỚI, I1) dùng chung macOS và iOS (platforms .macOS(.v15), .iOS(.v18)); không AppKit, UIKit
├── LibraryData                  dời từ ExamFeatures; iOS thêm truy cập file có security scope (I2)
├── InterfaceCore                tách từ LibraryFeature: tra chữ, locale, câu báo lỗi theo mã, định dạng, bảng màu,
│                                kiểu và model của Thư viện (LibraryModel); Foundation + SwiftUI (Color)
└── SessionModel                 tách từ SessionFeature: AttemptModel, PreExamModel, ResultsModel, AnswerReviewModel,
                                 SessionEnvironment, SessionFormat, PlainMarkdown; ExamKit, ExamFile, LibraryData, InterfaceCore
Packages/ExamFeatures            chỉ macOS (không khai báo iOS: ADR 0013): LibraryFeature, SessionFeature, ReportFeature,
                                 Authoring*, ExamImport, hai shell; phụ thuộc SharedFeatures từ I1
Packages/MobileFeatures (I0)     chỉ iOS, chỉ build bằng xcodebuild (platforms .iOS(.v18))
├── MobileFeature                view iPhone: Thư viện, Trước khi thi, Làm bài, Kết quả, Xem lại, Lịch sử; nhận file
├── MobileShell                  App, scene, onOpenURL, scenePhase, chế độ cô lập của UI test
├── MobileFeatureTests (I1, I2)  phần iOS thêm
└── MobileSnapshotTests (I2)     ảnh iPhone (SnapshotTesting; ADR 0010 sửa ở I2)
Apps/StudentiOS (I0)             điểm vào, Info.plist (document types, InfoPlist.xcstrings), Assets
Apps/StudentiOSUITests (I0)      XCUITest trên simulator; hỗ trợ test riêng (I2), chỉ dùng chung đề mẫu của Apps/UITestSupport
```

- **Vì sao tách module thay vì chép** (QI2): Thư viện, Kết quả, Xem lại, Trước khi thi có nhiều quy tắc hợp đồng
  (trạng thái file, trùng id, `hideAnswers`, câu đã sửa, so với lần trước, lý do khoá) đã có test; chép sang iOS là có
  hai bản phải sửa song song, đúng cái bẫy "hai luồng PDF" của macOS. Tách ra thì macOS và iOS cùng một nguồn, test của
  model giữ nguyên tên và nội dung (I1: `LibraryDataTests` dời sang SharedFeatures; test của InterfaceCore, SessionModel
  ở lại test target của ExamFeatures vì dùng chung support với test của phần AppKit, exec-plan Decisions). Hành vi theo macOS làm phần dùng chung lớn hơn: `LibraryModel` (646 dòng) và
  test của nó dùng được cho iOS.
- **Vì sao ba package theo nền tảng** (ADR 0013, spike I0): `platforms` của SwiftPM áp cho cả package. Target chỉ iOS đặt
  trong ExamFeatures thì `swift test` trên macOS cũng biên dịch nó; snapshot iPhone đặt trong `ExamFeaturesSnapshotTests`
  thì không build được cho simulator (target này phụ thuộc AuthoringFeature, SessionFeature có AppKit). Ngược lại, thêm
  `.iOS` vào ExamFeatures làm `xcodebuild -exportLocalizations` của cả hai scheme macOS thất bại: export build mọi target
  có catalog theo mọi nền tảng package khai báo, mà LibraryFeature… `import AppKit`. Vì vậy module dùng chung (LibraryData,
  InterfaceCore, SessionModel) ở package riêng khai báo cả hai nền tảng, ExamFeatures giữ chỉ macOS, MobileFeatures chỉ iOS.
  Dời LibraryData đổi đường dẫn đề mẫu mà `android/data/build.gradle.kts` và bộ lọc của `.github/workflows/android.yml`
  trỏ tới (Nt0 duyệt sửa ở I1) và đổi tên bundle tài nguyên trong app macOS (`SharedFeatures_LibraryData.bundle`).
- **Phụ thuộc của SessionModel**: `SessionPreferences.reportReviewLevel` có kiểu `ResultsReviewLevel` của ReportFeature,
  mà ReportFeature phụ thuộc LibraryFeature (có AppKit). I1 tách `reportReviewLevel` ra protocol riêng ở SessionFeature
  (đề xuất, ít di chuyển nhất) hoặc tách phần Foundation của ReportFeature thành module riêng; I1 chọn, ghi Decisions.
  `ResultsReport+Session`, `ResultsReportFlow` ở lại SessionFeature tới v1.1.
- **Ranh giới**: package `MobileFeatures` và target `ExamSuiteiOS` không phụ thuộc AuthoringFeature, AuthoringData,
  ExamImport (ADR 0003): thêm dòng cho target iOS vào `check_boundaries.py` và `check_bundle_boundary.sh`. "Module dùng
  chung không có AppKit, module macOS không có UIKit" do trình biên dịch chặn khi `verify_local.sh` build cả hai nền (AppKit
  không có trên iOS), nên không thêm luật script (quy tắc 6 của plan Android). Luật 8 (ReportFeature) cập nhật:
  InterfaceCore thay LibraryFeature.
- **String Catalog khi chuyển file giữa target**: khoá của code chuyển đi xuất hiện ở catalog của target mới chưa có bản
  `en`. Đề xuất (QI6): một script dời đúng các mục đó từ catalog cũ sang catalog mới (chạy một lần trong I1, không commit
  script); khoá còn dùng ở cả code cũ và code mới thì chép sang cả hai. Sau đó `xcodebuild -exportLocalizations` cho **ba**
  scheme (thêm `ExamSuiteiOS`) phải không đổi gì và `check_localization.py --require-en` xanh; không sửa tay từng khoá.
  I0 đã cho `check_localization.py` quét code iOS, kiểm app iOS đã build (`--built-apps` với Products của simulator) và
  export ba scheme; I1 thêm bundle mới vào `BUILT_APPS`, `MobileShell` và Apps/StudentiOS vào luật `scene-locale` (lúc đó
  `.interfaceLocale()` ở InterfaceCore), `.stringsdata` của bản build iOS cho `--freshness` khi MobileFeatures có catalog.
- **Script kiểm khác** (I0): `check_quit_sheets.py` bỏ qua `Apps/StudentiOS*` (luật ⌘Q chỉ của macOS);
  `uitest_plan.py` có target thứ ba `ExamSuiteiOSUITests`; `check_boundaries.py`, `check_bundle_boundary.sh` kiểm bản
  iOS theo ADR 0003. `verify_scope.py` chưa có mức riêng cho iOS (đường dẫn iOS là mức full; Phần 5).
- **Chế độ cô lập của UI test**: spike I0 đạt: trình chạy test tạo thư mục ở `/private/tmp` (có file đánh dấu), app trên
  simulator đọc được và đặt kho, đề mẫu trong đó qua `AppLaunchStorage` (bản build `.uitest`; đối chứng âm: bản Debug
  không đuôi bị từ chối). I0 đã cho `AppLaunchStorage` biết bundle ID của bản iOS (bản thật, không phải bản build test).
  Không cần `CFFIXED_USER_HOME` hay entitlements của macOS. Simulator đã tách dữ liệu khỏi Mac nên phần so kho thật và
  Autosave của `verify_local.sh` không áp cho iOS. `AccessibilityAuditor` thêm loại kiểm của iOS (`dynamicType`,
  `textClipped`, `trait`) ở I2; ngoại lệ của macOS không áp.
- **Thư viện**: không thêm gói nào (ZIPFoundation hỗ trợ iOS; swift-snapshot-testing chạy trên simulator).

## Phần 4 · Lộ trình cho agent

Nguyên tắc như plan Android Phần 3: mỗi bước một PR, cỡ 2.000–8.000 dòng là bình thường, chỉ tách khi hai agent thật sự
làm song song; tài liệu đi cùng PR code; kết luận spike vào Decisions của exec-plan.

### v1: 4 PR, 3 cổng

```mermaid
gantt
  title iOS v1: 4 PR, 3 cổng
  dateFormat X
  axisFormat %s
  I0 Chuẩn bị, ADR, package và target rỗng, spike   :i0, 0, 1
  I1 SharedFeatures: dời LibraryData, tách model (rủi ro cao) :i1, after i0, 2
  GI1 macOS không đổi (snapshot, UI test đủ bộ)      :milestone, after i1, 0
  I2 Giao diện iPhone, nhận file, tạm dừng          :i2, after i1, 3
  GI2 dùng thử trên iPhone thật                     :milestone, after i2, 0
  I3 Hoàn thiện, bản cài 0.1.0, đóng plan v1       :i3, after i2, 1
  GI3 bản 0.1.0 trên iPhone                         :milestone, after i3, 0
```

| Bước | Đầu ra | Phụ thuộc | Rủi ro / review | Kiểm chứng trong PR |
| --- | --- | --- | --- | --- |
| **I0 Chuẩn bị** (1 PR; bảng Quyết định đã chốt) | ADR 0013 (iOS 18, SwiftUI, hành vi theo macOS, dùng lại lõi, ba package theo nền tảng, phân phối); ADR 0003 ghi bản iOS; `mobile.md` thêm mục "Bản iOS"; exec-plan `docs/plans/active/ios-v1.md`; AGENTS.md thêm phần iOS; package `MobileFeatures` (khung, chưa phụ thuộc), target `ExamSuiteiOS`, `ExamSuiteiOSUITests` build và mở được trên simulator; Info.plist: `UILaunchScreen` (thiếu thì app chạy chế độ tương thích), `CFBundleDocumentTypes` + `UTImportedTypeDeclarations` cho `vn.io.nt0.exam`, `LSSupportsOpeningDocumentsInPlace`, `InfoPlist.xcstrings` vi/en (tên hiện theo cấu hình build, không dịch); target iOS ghi đè cài đặt ký chung của `project.yml`; `AppLaunchStorage` biết bundle ID của bản iOS; `verify_local.sh` có bước iOS ở mức full (build simulator, ranh giới bundle, chữ Info.plist, export scheme thứ ba, UI test iOS), status vẫn một `local/verify`; script ở Phần 3. **Spike** ghi Decisions: (1) ExamKit, ExamFile, LibraryData (kể cả SwiftData) biên dịch cho simulator; (2) file LibraryFeature, SessionFeature vướng AppKit; (3) kho, đề mẫu, bookmark khi thư mục đổi chỗ chạy trên simulator; (4) swift-snapshot-testing chạy trên simulator; (5) thư mục cô lập của UI test; (6) `-exportLocalizations` với ExamFeatures khai báo iOS (thất bại, dẫn tới ADR 0013) | — | **Cao** (chạm `project.yml`, `Apps/**`, `scripts/check_boundaries.py`: vùng ranh giới hai bản app của review-and-merge.md mục 3): 1 review độc lập | `verify_local.sh --uitest` xanh với bước iOS mới; kết quả macOS không đổi; tự kiểm âm của các script đã sửa xanh |
| **I1 Tách module dùng chung** (1 PR) | `Packages/SharedFeatures` (macOS, iOS): dời LibraryData (kể cả đề mẫu, `LibraryDataTests` và fixture kho v1), tách `InterfaceCore`, `SessionModel` theo Phần 3; ExamKit thêm `.iOS(.v18)`; ExamFeatures, MobileFeatures, hai shell chuyển sang phụ thuộc; đường dẫn đề mẫu trong `android/data/build.gradle.kts` và bộ lọc của `.github/workflows/android.yml`; tên bundle tài nguyên mới trong script kiểm (`check_localization.py` `BUILT_APPS`, `unlisted_bundles`; `check_bundle_boundary.sh`); `check_boundaries.py` (`check_test_only_module`) và bảng map `uitest_plan.py` biết `Packages/SharedFeatures` (module dùng chung: đủ bộ; đường dẫn ngoài `CODE_PATTERNS` không chạy UI test); vùng rủi ro cao của review-and-merge.md thêm SharedFeatures (Phần 5); dời khoá catalog bằng script (QI6); luật 8 cập nhật, luật `scene-locale` thêm bản iOS; test hiện có đi theo code (`LibraryDataTests` sang SharedFeatures; test của InterfaceCore, SessionModel chỉ đổi import, ở lại ExamFeatures; không đổi nội dung) cộng một test kho trên iOS (`MobileFeatureTests`: kho mở, đề mẫu, bookmark khi thư mục đổi chỗ; đã thử ở spike I0); **không đổi hành vi macOS** | I0 | **Cao** (chạm `Package.swift`, ranh giới hai bản, đường dẫn đề mẫu của Android): 1 review độc lập; `verify_local.sh --uitest` đủ bộ vì chạm module dùng chung; check `android` của CI vì chạm `android/` | Snapshot macOS không đổi ảnh; `swift test` cùng số test; `-exportLocalizations` ba scheme không đổi catalog; `check_bundle_boundary.sh` như cũ; kho thư viện v1 mở được (`LibraryDataTests`). **Cổng GI1**: Nt0 chỉ đọc status |
| **I2 Giao diện iPhone và nhận file** (1 PR; tách đôi nếu vượt ~8.000 dòng) | `MobileFeature`: Thư viện danh sách (`LibraryModel` dùng chung: tìm, sắp xếp, trạng thái file, Tìm file…, Làm mới, Xoá + Hoàn tác, dải chào mừng, đề mẫu lần đầu), Thêm đề (`fileImporter`), `onOpenURL` (dời file khỏi `Inbox`; đang có bài thì giữ màn làm bài, QI12b), Trước khi thi (`PreExamModel` dùng chung), Làm bài (câu, ảnh phóng to, lựa chọn A–Z theo vị trí, bảng câu hỏi dạng sheet, đồng hồ ba mức, cảnh báo 5/1 phút, che khi tạm dừng, Kiểm tra đáp án), Rà soát & nộp, Kết quả, Xem lại, Luyện lại câu sai, Làm lại, Lịch sử thi → Kết quả cũ, `NavigationStack`; nút Quay lại hỏi "Bỏ bài?" (tắt cử chỉ vuốt); nơi lưu theo `AppLaunchStorage` (chế độ cô lập cho UI test; `LaunchUITests` của I0 mở app không cô lập, thay bằng ba test dưới đây; `check_release_strings.sh` thêm bản Release iOS); test target snapshot trong `MobileFeatures` (sửa ADR 0010 và `check_boundaries.py`); **tự tạm dừng khi xuống nền**: `PauseReason.background` ở ExamKit, hàm tự tạm dừng nhận lý do và câu lớp phủ ở `AttemptModel` (macOS vẫn gọi với `systemSleep`, hành vi không đổi), `scenePhase` ở màn làm bài; LibraryData: quyền security scope trên iOS; cỡ chữ theo QI11; nhãn VoiceOver; sáng/tối | I1 | Thường; phần ExamKit (phiên thi) và LibraryData (đọc file đề của Thư viện): 1 review độc lập | Test máy ngủ hiện có của `ExamSessionTests` và `AttemptModelTests` chạy thêm lý do `background` (không viết bộ test mới cho luật cũ); ~15 test `MobileFeatureTests` (dời file khỏi `Inbox`, nhận file lúc đang có bài, security scope, `scenePhase` → tạm dừng, Bỏ bài, nhãn theo vị trí); **không** test lại `AttemptModel`, `LibraryModel` (test đi theo module ở I1); snapshot iPhone sáng/tối: câu dài 10 lựa chọn, ảnh lớn, Kết quả nhiều phần, Xem lại `hideAnswers`, Thư viện danh sách (10 ảnh) + ảnh cỡ chữ lớn theo QI11; XCUITest trên simulator **3 lần mở app** (chế độ cô lập): luồng 1 (Luyện tập tới Xem lại, Luyện lại câu sai); luồng 2 mở đầu bằng mở file `.exam` (cách mở chốt ở I2: app Tệp, Safari, thư mục `Inbox`) rồi Thi, hết giờ với `-ExamSuiteUITestTimeScale` có sẵn; luồng 3 (Quay lại hỏi Bỏ bài, xuống nền thì Tạm dừng, mở lại vẫn Tạm dừng); `performAccessibilityAudit` qua `AccessibilityAuditor` trong ba test này. **Cổng GI2**: cài lên iPhone (QI5), làm trọn một đề thật, nhận file qua Zalo/Drive, thử **cuộc gọi đến khi đang làm bài** (dạng banner có đưa app xuống nền không; không thì xét lại QI10) |
| **I3 Hoàn thiện và bản cài** (1 PR + Nt0) | Màn Giới thiệu (QI13: phiên bản, giấy phép Apache-2.0, NOTICE, ZIPFoundation; iOS không có hộp Giới thiệu như macOS); biểu tượng 1024 px; rà nhanh VoiceOver bốn màn chính trên máy thật; đo đề chuẩn trên simulator bản Debug (QI15), ghi `docs/notes/ios-measurements.md`, sửa mục vượt ngân sách; cài lên máy thật bằng Personal Team (QI4, QI14): team ID truyền lúc build, không ghi vào `project.yml` hay repo; phiên bản riêng 0.1.0 (`MARKETING_VERSION` của target iOS) và tag `ios-v*` (tag `v*` chạy job `release-dmg` của macOS); CHANGELOG riêng của iOS (không dùng `CHANGELOG.md` gốc của macOS); hướng dẫn cài `docs/install-ios.md` (cài qua Xcode, bật Developer Mode, cài lại sau 7 ngày; không sửa `docs/install.md`: `make_dmg.sh` chép file đó vào DMG macOS); sửa lỗi beta từ GI2; đóng exec-plan v1 | I2 | Thường | `PaletteContrastTests` thêm nền của iOS (nền hệ thống sáng/tối, nền sheet); không test mới khác; `verify_local.sh --clean --uitest` trên SHA phát hành; **Cổng GI3**: bản 0.1.0 cài qua Xcode lên iPhone, Nt0 dùng thử |

Ước lượng: 4 PR. I1 là PR nặng nhất về review (di chuyển ~7.200 dòng: LibraryData ~3.000 và model ~4.200, không đổi
hành vi). I1 và I2 chạm code macOS
(I2 chỉ thêm lý do tạm dừng, hành vi macOS không đổi). Android v1 xong 6 PR trong 2 ngày lịch (22–23/10); iOS ít PR hơn
nhưng **cộng thời gian chờ mượn iPhone** cho hai cổng.

### v1.1: 3 PR, 1 cổng

| Bước | Đầu ra | Kiểm chứng |
| --- | --- | --- |
| **J1 PDF kết quả** | exec-plan `ios-v1.1.md`; `ReportRenderer` thôi phụ thuộc LibraryFeature (dùng InterfaceCore), `ReportPanels`, `ReportPrinting`, `ReportTemporaryFiles` chỉ macOS; `ResultsReport+Session` dời sang module dùng chung; `ShareLink`/share sheet và `UIPrintInteractionController` thay ba hộp của macOS; ảnh JPEG co theo trang nếu Nt0 chốt Q9 cho cả hai mobile | Không test luật ẩn/hiện (đã có ở SessionFeatureTests); 2 smoke PDF trên simulator; Xuất PDF nối vào đuôi XCUITest luồng 1 |
| **J2 iPad và giao diện mở rộng** | `NavigationSplitView`, cột bên cho bảng câu hỏi, Thư viện lưới (`ExamGridView` của macOS xem dùng lại được không), Thông tin đề, lọc, Khôi phục đề mẫu; Nền đọc nếu QI11 để v1.1 | Snapshot iPad sáng/tối (3 màn) |
| **J3 Trợ năng sâu và đo** | Rà VoiceOver theo bảng mục tiêu, Reduce Motion, test `Timing` của `LargeExamSupport` chạy trên simulator nếu số đo sát ngân sách; đóng exec-plan v1.1; **Cổng GI4** trên iPhone và iPad | Số đo chỉ ghi |

### Thứ tự merge và nhánh

`feature/ios-i0` → `feature/ios-i1` → `feature/ios-i2` → `feature/ios-i3`; không có cặp song song trong v1 (I2 cần các
module tách ở I1). Xếp chồng tối đa một tầng.

## Phần 5 · Kiểm thử và bằng chứng merge

Dùng lại nguyên bảng lớp kiểm của macOS; sáu quy tắc chống trùng của plan Android Phần 4 áp nguyên. Chỉ ghi phần khác:

| Lớp | iOS |
| --- | --- |
| Lõi, dữ liệu, model trình bày | Test hiện có (I1: `LibraryDataTests` ở SharedFeatures, test của InterfaceCore và SessionModel ở test target của ExamFeatures, nên PR chạm SharedFeatures vẫn chạy `swift test` của ExamFeatures); lý do `background` chạy chung test máy ngủ hiện có (I2); không viết test mới cho hành vi cũ |
| Phần iOS thêm | ~15 test (I2) trong `MobileFeatureTests` (package `MobileFeatures`), chạy bằng `xcodebuild test` trên simulator |
| Hiển thị | `MobileSnapshotTests` (ADR 0010 sửa ở I2); iPhone sáng/tối ≈ 10 ảnh + ảnh cỡ chữ lớn; iPad ở v1.1; ảnh ghi trên Mac của Nt0, một máy simulator và một runtime cố định |
| Giao diện | XCUITest `ExamSuiteiOSUITests` trên simulator, **3 lần mở app**, chế độ cô lập (spike I0); không cần quyền Accessibility của Mac, không so kho thật, không kiểm Autosave |
| Trợ năng | `performAccessibilityAudit` trong ba test trên, loại kiểm của iOS |
| Chuỗi và locale | `check_localization.py` hiện có, thêm như Phần 3; `-exportLocalizations` ba scheme |
| Màu | `PaletteContrastTests` thêm nền của iOS (I3); `check_colors.py` thêm file bảng màu của iOS nếu có |
| Ranh giới | ADR 0003: `check_boundaries.py`, `check_bundle_boundary.sh` thêm app iOS. AppKit/UIKit: trình biên dịch chặn |
| Hiệu năng | Theo QI15 |

Bằng chứng merge: vẫn một commit status `local/verify` của `verify_local.sh`; mô tả status thêm "iOS K test" trong
phần UI test khi chạy `--uitest`, và "iOS ok" sau phần UI test (chữ này có thể bị cắt ở 140 ký tự; status success đã
gồm mọi bước iOS).
Đề xuất (Nt0 duyệt khi cần, dự kiến ở I2): `verify_scope.py` thêm mức `ios` cho PR chỉ chạm `Packages/MobileFeatures/**`,
`Apps/StudentiOS*/**`: build và test iOS cùng các script kiểm, không chạy bộ macOS (như mức `none`/`core` đã có cho
Android). PR chạm module dùng chung vẫn mức `full`, cộng bước iOS. `--uitest` chọn lớp iOS theo bảng map của
`uitest_plan.py` như hai target hiện có. Vùng rủi ro cao (review-and-merge.md mục 3): I0 thêm
`Packages/MobileFeatures/Package.swift` vào nhóm ranh giới hai bản app; I1 thêm `Packages/SharedFeatures/Package.swift`
và `Packages/SharedFeatures/Sources/{InterfaceCore,SessionModel}/**` (hợp đồng dùng chung hai nền tảng).

## Phần 6 · Rủi ro

| Rủi ro | Cách xử lý |
| --- | --- |
| Không có iPhone lúc tới cổng GI2, GI3 | Nt0 có hoặc mượn được (QI5); hẹn ngày khi I2 gần xong; không có máy thì cổng không qua, không thay bằng simulator |
| Cần phát cho học viên trong lúc v1 chỉ cài qua Xcode | Quyết định mới: đăng ký Apple Developer (99 USD/năm, tài khoản cá nhân hiện tên thật ở trang công khai, khác bí danh Nt0 của repo), chọn TestFlight hay Ad Hoc; thêm `PrivacyInfo.xcprivacy` (app dùng `UserDefaults` và ngày giờ của file, thuộc nhóm API phải khai lý do; thiếu thì App Store Connect từ chối bản tải lên) và `ITSAppUsesNonExemptEncryption`; bundle ID đã dùng với Personal Team thì kiểm còn đăng ký được cho tài khoản trả phí không |
| iOS dừng app ở nền khi đang làm bài: bài mất, không báo | Chấp nhận ở v1 (QI9, hành vi macOS không lưu phiên dở); tự tạm dừng giữ đồng hồ đúng trong lúc ở nền. Nếu beta báo mất bài: v1.1 thêm phiên dở, cần `snapshot`/`restore` trong ExamKit theo các luật Android đã có (mobile.md), 1 PR rủi ro cao |
| Cuộc gọi dạng banner không đưa app xuống nền, đồng hồ chạy trong lúc nghe máy | Thử ở GI2; cần thì tạm dừng ở `.inactive` (QI10) |
| I1 làm lệch hành vi macOS đã phát hành | Chỉ di chuyển, không sửa; snapshot macOS phải không đổi ảnh; UI test đủ bộ; review độc lập đối chiếu danh sách file |
| Thêm iOS vào package có target AppKit làm hỏng export String Catalog của macOS (spike I0) | ExamFeatures không khai báo iOS (ADR 0013); module cho iOS chỉ ở SharedFeatures, MobileFeatures; `verify_local.sh` export ba scheme ở mọi lần mức full |
| Dời LibraryData (I1) làm lệch đường dẫn đề mẫu của bản Android | Sửa `android/data/build.gradle.kts` và bộ lọc của `.github/workflows/android.yml` trong cùng PR I1; check `android` của CI xanh trên SHA cuối |
| Dời khoá String Catalog làm mất bản `en` | Script dời một lần + `-exportLocalizations` không đổi + `--require-en`; không sửa tay |
| Bookmark trên iOS không phân giải lại được (file trên Drive chưa tải, đường dẫn container đổi sau khi cập nhật app) | Spike I0: bookmark tìm lại file khi thư mục chứa nó đổi chỗ (đạt trên simulator); trạng thái Không tìm thấy file và Tìm file… như macOS là đường lùi cho file của người dùng; file dời khỏi `Inbox` vào app thì cách tìm lại chốt ở I2 |
| Bản cài qua Personal Team hết hạn sau 7 ngày | Ghi vào `docs/install-ios.md`; cắm máy vào Mac cài lại |
| Nhận file từ Zalo/Drive không vào được app | I2 thử với app Tệp và Safari trên simulator (I0 hoãn: app chưa có màn Thư viện); Zalo/Drive chỉ kiểm được ở GI2 trên máy thật; dự phòng: hướng dẫn "Lưu vào Tệp rồi mở" |
| Đề 2.000 câu có ảnh trên iPhone cũ | `LazyVStack`, ảnh giải mã theo kích thước hiển thị (downsampling); đo theo QI15 |
| Agent chép view macOS sang iOS kéo theo AppKit | Trình biên dịch iOS chặn `import AppKit`; view iPhone viết mới, chỉ model dùng chung |

## Quyết định (Nt0 chốt 2026-10-30)

Nt0 trả lời từng câu ngày 30/10/2026. I0 chép các quyết định này vào ADR 0013 và `mobile.md`; tới lúc đó bảng này là nơi
ghi.

| # | Câu hỏi | Đề xuất ban đầu | **Chốt** |
| --- | --- | --- | --- |
| QI1 | iOS tối thiểu? | iOS 18: cùng thế hệ SDK với macOS 15 (deployment target của repo), nên SwiftData, Observation, Synchronization dùng được như bản macOS; iPhone XS/XR (2018) trở lên | **Như đề xuất** |
| QI2 | Tách `InterfaceCore`, `SessionModel` dùng chung macOS và iOS (một PR rủi ro cao chạm bản macOS) thay vì chép model sang iOS? | Tách: quy tắc hợp đồng một nguồn; chép là lặp lại lỗi hai luồng PDF | **Như đề xuất** |
| QI3 | Bundle ID, tên app? | `vn.io.nt0.examsuite.ios`, tên Exam Suite, cùng `project.yml`; bản debug `.debug`, tên "Exam Suite Debug" | **Như đề xuất** |
| QI4 | Phân phối? Phiên bản? | TestFlight; phiên bản riêng 0.1.0, tag `ios-v*` | **v1 chỉ cài qua Xcode** (Personal Team miễn phí, bản cài hết hạn sau 7 ngày); phát cho người khác là quyết định sau. Phiên bản riêng 0.1.0, tag `ios-v*` |
| QI5 | iPhone thật cho hai cổng GI2, GI3? | Hẹn trước khi bắt đầu I0 | **Nt0 có hoặc mượn được**; bắt đầu I0 |
| QI6 | Cho phép script dời khoá catalog một lần ở I1 (ngoại lệ của "không sửa tay khoá"), kiểm bằng `-exportLocalizations` không đổi và `--require-en`? | Có | **Như đề xuất** |
| QI7 | Phiên dở lưu file JSON trong container? | Có | **Bỏ**: không lưu phiên dở (QI9) |
| QI8 | Thứ tự: iOS trước hay Android trước? | Android trước | **Android trước** (chốt 2026-10-22, Q13 của plan Android) |
| QI9 | Hành vi iOS theo tài liệu macOS hay theo luật mobile của Android (`mobile.md`)? | — | **Theo macOS**: tham chiếu file tại chỗ, trùng id như library.md, không lưu phiên dở (bài mất khi iOS dừng app ở nền: chấp nhận ở v1), dữ liệu vào bản sao lưu của hệ thống như macOS; chỗ khác ở mục "Bản iOS" của `mobile.md` |
| QI10 | App xuống nền thì tự tạm dừng? | Tạm dừng khi sang `.background`, lý do `background`, lớp phủ "Đã tạm dừng vì bạn rời app" (cùng câu Android) | **Như đề xuất**; thử cuộc gọi dạng banner ở GI2, cần thì đổi sang `.inactive` |
| QI11 | Cỡ chữ nội dung và Nền đọc trên iOS? | Dynamic Type, bố cục dùng được tới `accessibility1` (~165%), kiểm bằng ảnh chụp; Nền đọc ở v1.1 | **Như đề xuất** |
| QI12 | File nhận từ app khác (iOS đã chép vào app)? | Thêm ba luật: nhận lại cùng nội dung thì chọn đề đã có; Xoá khỏi thư viện thì xoá bản chép; nhận lúc đang làm bài thì giữ bài | **Đúng như macOS, không thêm luật**: nhận lại là file khác nên hỏi Dùng file mới / Huỷ; bản chép không tự xoá |
| QI12b | Nhận `.exam` lúc đang có bài làm dở? | Giữ màn làm bài, đề vẫn được thêm; hộp Dùng file mới / Huỷ và việc chọn đề hiện khi về Thư viện | **Như đề xuất** |
| QI13 | Giấy phép hiện ở đâu trong app? | Màn Giới thiệu mở từ Thư viện | **Như đề xuất** |
| QI14 | Tài khoản Apple Developer? | Cá nhân | **Cá nhân, miễn phí trước** (Personal Team, đủ cho hai cổng); đăng ký trả phí khi cần phát cho người khác |
| QI15 | Đo đề chuẩn 2.000 câu ở đâu? | Simulator bản Debug, như Android (Nt0 chốt 2026-10-23); máy thật ở J3 nếu beta thấy chậm | **Như đề xuất** |

## Việc cần Nt0 làm một lần (môi trường)

- Xcode đã có (27.1, runtime simulator iOS 26.1 có sẵn; máy và runtime cho ảnh snapshot cố định ở I0); thêm runtime
  iOS 18 nếu muốn thử bản tối thiểu.
- Đăng nhập Apple ID trong Xcode (Settings › Accounts) để có Personal Team; không cần đăng ký Apple Developer Program ở v1.
- iPhone cho cổng GI2 và GI3 (iOS 18 trở lên): bật Developer Mode (máy khởi động lại), cài qua Xcode, rồi tin cậy nhà
  phát triển trong Cài đặt › Cài đặt chung › VPN & Quản lý thiết bị.
- Mỗi lúc một việc nặng trên Mac (build simulator, snapshot, XCUITest).

## Hướng dẫn cho agent nhận plan

1. Đọc `AGENTS.md`, `docs/WORKFLOW.md`, plan này, `docs/product/{exam-format,scoring,exam-session,exam-taking,library,accessibility-localization,large-exams}.md`
   (**hành vi iOS theo các tài liệu này**), mục "Bản iOS" của `docs/product/mobile.md`, mọi ADR hiện có (nhất là 0003,
   0013), `docs/process/review-and-merge.md`. Mục Phạm vi và bảng "Khác macOS" của Android trong `mobile.md` không áp cho
   iOS.
2. Bảng Quyết định đã chốt 2026-10-30; bắt đầu từ I0. Quyết định nào cần đổi thì dừng, hỏi Nt0, không tự sửa bảng.
3. Mỗi bước một PR trên nhánh `feature/ios-<bước>`; không push `main`, không tự merge; cập nhật exec-plan
   `docs/plans/active/ios-v1.md` trong cùng PR; không mở PR tài liệu riêng.
4. I1 chỉ di chuyển code (trừ việc gỡ `reportReviewLevel` khỏi `SessionPreferences` nếu chọn cách đó, Phần 3); thấy cần
   sửa hành vi thì dừng và ghi vào Decisions, không sửa trong PR tách.
5. View iPhone viết mới; không chép model, chỉ dùng module tách; không lưu phiên dở.
6. Không thêm lớp kiểm mới; tuân sáu quy tắc chống trùng của plan Android Phần 4; không kéo mục v1.1 vào v1.
7. Gặp quy tắc sản phẩm mơ hồ hay khác giữa macOS và iOS chưa ghi ở mục "Bản iOS" của `mobile.md`: dừng, hỏi Nt0;
   không tự chọn.
8. Không đọc, chép hay sửa chứng chỉ ký, profile, team ID; không ghi team ID vào repo; không cài, xoá dữ liệu hay gỡ app
   trên iPhone thật (việc đó Nt0 làm).
9. Báo cáo PR: lệnh đã chạy, số test, phần máy không kiểm được (VoiceOver thật, iPhone thật, cuộc gọi đến, nhận file từ Zalo/Drive)
   cần người test tay.
