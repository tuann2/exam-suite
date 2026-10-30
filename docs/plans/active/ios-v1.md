# Execution Plan: Exam Suite cho iOS, v1 (bản Học viên)

Date: 2026-10-30

## Status

Active. I0 (PR #8), I1 (PR #9), I2a (PR #10) đã merge; cổng GI1 đạt. I2b trên nhánh `feature/ios-i2b`; sau đó cổng GI2
(Nt0 thử trên iPhone thật).

## Outcome

App iPhone bản Học viên (iOS 18 trở lên, bundle ID `vn.io.nt0.examsuite.ios`), cài qua Xcode lên iPhone: Thư viện (danh
sách), Thêm đề và mở `.exam` từ app khác, Trước khi thi, Làm bài, Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai,
Làm lại, Lịch sử thi, tự tạm dừng khi xuống nền, tiếng Việt và tiếng Anh, sáng/tối, màn Giới thiệu. Hành vi theo tài liệu
macOS, chỉ khác ở bảng "Chỗ iOS khác macOS" của [plan-ios-v1.md](../../product/plan-ios-v1.md) Phần 2. Bản macOS không
đổi hành vi. Qua cổng GI3.

## Context

- Kế hoạch: [plan-ios-v1.md](../../product/plan-ios-v1.md) (phạm vi Phần 2, kiến trúc Phần 3, lộ trình Phần 4, kiểm thử
  Phần 5, rủi ro Phần 6, bảng Quyết định Nt0 chốt 2026-10-30).
- Hợp đồng: `docs/product/{exam-format,scoring,exam-session,exam-taking,library,accessibility-localization,large-exams}.md`;
  [mobile.md](../../product/mobile.md) chỉ áp phần "Bản iOS" (bảng của Android không áp).
- Quyết định: ADR 0013 (bản iOS: hành vi theo macOS, ba package theo nền tảng), 0003 (ranh giới bản Học viên), 0006
  (thư viện), 0008 (lõi), 0010 (snapshot).
- Quy trình: [review-and-merge.md](../../process/review-and-merge.md); quy tắc chống test trùng ở plan Android Phần 4.

## Scope

In scope: các bước I0–I3 của plan-ios-v1.md Phần 4, mỗi bước một PR.

Out of scope: mục v1.1 (PDF, iPad, lưới, Thông tin đề, lọc, Khôi phục đề mẫu, Nền đọc, rà VoiceOver đủ bảng, Reduce
Motion); lưu phiên dở; TestFlight, Ad Hoc, App Store; Soạn đề, Import.

## Approach

I0 (khung, script, spike) → I1 (`Packages/SharedFeatures`: dời LibraryData, tách `InterfaceCore`, `SessionModel`; rủi ro
cao) → I2 (giao diện iPhone, nhận file, tự tạm dừng; cổng GI2) → I3 (hoàn thiện, bản 0.1.0 cài qua Xcode; cổng GI3).
Không có cặp song song.

## Risks And Recovery

- Rủi ro ở plan-ios-v1.md Phần 6.
- I0 chỉ thêm (package `MobileFeatures`, target iOS, dòng mới trong script) cộng bundle ID của iOS trong
  `AppLaunchStorage`; `Packages/ExamFeatures` không đổi `platforms`; gỡ là revert PR. I1 chạm bản macOS và đường dẫn đề
  mẫu của Android: revert cả PR.

## Progress

- [x] I0 Chuẩn bị (PR #8, merge 2026-10-30): ADR 0013, ADR 0003 ghi bản iOS; `mobile.md` mục "Bản iOS"; plan-ios-v1.md
      theo ba package; AGENTS.md, review-and-merge.md phần iOS; `AppLaunchStorage` biết hai bundle ID iOS (bản thật);
      package `MobileFeatures` (khung, chưa phụ thuộc); target `ExamSuiteiOS` (Info.plist, `InfoPlist.xcstrings` vi/en),
      `ExamSuiteiOSUITests` (một test mở app); `check_boundaries.py`, `check_bundle_boundary.sh`,
      `check_localization.py`, `check_quit_sheets.py`, `uitest_plan.py`, `verify_local.sh` biết bản iOS; spike
      (Decisions). Rủi ro cao (vùng ranh giới hai bản app): review độc lập xong, đã sửa theo review. `local/verify`
      xanh trên 72b6dac.
- [x] I1 `Packages/SharedFeatures`: dời LibraryData, tách model trình bày (rủi ro cao; PR #9, merge 2026-10-30).
      Cổng GI1 đạt (`local/verify` xanh trên c7aa612, UI test đủ bộ, macOS không đổi). Đã làm: package
      `SharedFeatures` (LibraryData, InterfaceCore, SessionModel; macOS và iOS), ExamKit thêm `.iOS(.v18)`, ExamFeatures
      và MobileFeatures phụ thuộc nó, `MobileShell` gắn `.interfaceLocale()`, `MobileFeatureTests` (kho trên simulator),
      dời khoá catalog, script kiểm và tài liệu biết package mới, đường dẫn đề mẫu của Android và bộ lọc của CI Android.
      Review độc lập xong, đã sửa theo review.
- [x] I2a Giao diện iPhone, nhận file, tự tạm dừng (rủi ro cao; PR #10, merge 2026-10-31): `PauseReason.background`,
      `AttemptModel.autoPause(reason:)` (macOS gọi với `systemSleep`); LibraryData mở quyền security scope trên iOS
      (`SecurityScopedAccess`); `MobileFeature`: Thư viện danh sách (Gần đây, Lịch sử thi, tìm, sắp xếp, trạng thái file,
      Tìm file…, kéo để làm mới, vuốt để Xoá kèm Hoàn tác, dải chào mừng, Thêm đề), Trước khi thi, làm bài (đồng hồ ba
      mức, cảnh báo, che khi tạm dừng, Kiểm tra đáp án, bảng câu hỏi dạng sheet, ảnh phóng to), Rà soát & nộp, Kết quả,
      Xem lại bài, Luyện lại câu sai, Làm lại, mở lần thi cũ; điều phối phiên của iOS; file mở từ app khác (`Inbox` →
      `Received/`); catalog `vi`/`en`; 12 `MobileFeatureTests`; ba XCUITest kèm kiểm trợ năng;
      `check_release_strings.sh` kiểm bản Release iOS. Review độc lập và re-review xong, đã sửa theo review.
- [ ] I2b Snapshot iPhone sáng/tối và cỡ chữ lớn (nhánh `feature/ios-i2b`): `MobileSnapshotTests` (17 ảnh: làm bài câu
      dài (đầu và cuối) và ảnh lớn, Kết quả nhiều phần (đầu và cuối), Xem lại bài đề ẩn đáp án, Thư viện, sáng/tối; làm
      bài, Kết quả, Xem lại bài ở cỡ chữ `accessibility1`), ADR 0010 và 0006 ghi thêm test target này, `check_boundaries.py` luật 5 cho phép
      `Packages/MobileFeatures/Tests`, `verify_local.sh` chạy ảnh cùng `MobileFeatureTests`; dòng đề chưa Sẵn sàng của
      Thư viện không làm mờ (ảnh cho thấy lý do lỗi khó đọc). Cổng GI2 sau I2b.
- [ ] I3 Hoàn thiện, bản 0.1.0. Cổng GI3.

## Decisions

- 2026-10-30, Nt0: chốt QI1–QI15 của plan-ios-v1.md (bảng Quyết định): hành vi theo macOS (QI9), tự tạm dừng khi
  `.background` (QI10), v1 chỉ cài qua Xcode bằng Personal Team (QI4, QI14), Dynamic Type và Nền đọc ở v1.1 (QI11), file
  nhận từ app khác đúng như macOS (QI12), đang có bài thì giữ màn làm bài (QI12b).
- 2026-10-30, I0, spike biên dịch (Xcode 27.1, đích `generic/platform=iOS Simulator`): `ExamKit-Package` (ExamKit,
  ExamFile, LargeExamSupport) build không lỗi, không cảnh báo. Scheme `StudentShell`: LibraryData (kể cả `@Model` của
  SwiftData) biên dịch được; LibraryFeature dừng ở bước quét phụ thuộc vì `import AppKit` (`LibraryModel.swift` báo đầu
  tiên). File không import AppKit của LibraryFeature, SessionFeature chỉ dùng API có trên iOS (`WindowGroup`, `Table`,
  `NavigationSplitView`, `openWindow`) hoặc nhắc AppKit trong chú thích; các file model định tách ở I1 không dùng AppKit.
- 2026-10-30, I0, phát hiện: `UITestLaunchOptions.isTestBuild` coi mọi bundle ID `vn.io.nt0.examsuite.*` khác hai bản
  macOS là bản UI test, nên app iOS (`vn.io.nt0.examsuite.ios`) sẽ dừng ngay khi mở. I0 thêm hai bundle ID của iOS
  (`.ios`, `.ios.debug`) vào `LibraryConfiguration.productionBundleIdentifiers`; `.ios.debug.uitest` là bản build test.
- 2026-10-30, I0, spike chạy được trên simulator (iPhone 17, iOS 26.1), khi package khung tạm phụ thuộc LibraryData (đã
  gỡ khỏi I0, xem mục kế): kho SwiftData mở, tạo đủ 2 đề mẫu từ bundle của LibraryData; bookmark tìm lại file khi thư mục
  chứa nó đổi chỗ (thay cho container đổi đường dẫn sau khi cập nhật app); swift-snapshot-testing chụp và so được ảnh
  `UIHostingController` (cần `TEST_RUNNER_EXAMSUITE_SNAPSHOT_RECORD` vì simulator chỉ nhận biến môi trường có tiền tố
  `TEST_RUNNER_`; hai mục trùng ngày thêm thì thứ tự danh sách không cố định, ảnh lệch); chế độ cô lập của UI test:
  trình chạy test tạo thư mục ở `/private/tmp` có file đánh dấu, app trên simulator đọc được, kho nằm trong đó; đối
  chứng âm: build không đuôi `.uitest` (bundle ID `.ios.debug`, bản thật) bị từ chối, test đỏ. Test kho đem sang I1, test
  snapshot và hỗ trợ UI test cô lập sang I2.
- 2026-10-30, I0, phát hiện chặn: thêm `.iOS(.v18)` vào `platforms` của `Packages/ExamFeatures` làm
  `xcodebuild -exportLocalizations` của cả hai scheme macOS thất bại ("Unable to resolve module dependency: 'AppKit'" ở
  LibraryFeature), kể cả khi project không có target iOS: export build mọi target có catalog theo mọi nền tảng package
  khai báo. `-sdk macosx`, `-destination platform=macOS` không gỡ được; `SUPPORTED_PLATFORMS=macosx` cho export chạy
  nhưng đánh dấu stale mọi khoá `InfoPlist.xcstrings` của hai app macOS (đã hoàn lại).
- 2026-10-30, Nt0: chọn **dời LibraryData sang package dùng chung `Packages/SharedFeatures`, làm ở I1** (ExamFeatures giữ
  chỉ macOS; sửa đường dẫn đề mẫu trong `android/data/build.gradle.kts` và bộ lọc của `.github/workflows/android.yml` cùng
  I1). Ghi vào ADR 0013. I0 không đổi `platforms` của ExamKit, ExamFeatures; package `MobileFeatures` của I0 chưa phụ
  thuộc gì.
- 2026-10-30, I0, export: với ExamFeatures chỉ macOS và `MobileFeatures` chỉ iOS, `-exportLocalizations` chạy được cho cả
  ba scheme (`ExamSuite`, `ExamSuiteAdmin`, `ExamSuiteiOS`) và catalog đã commit không đổi.
- 2026-10-30, I0, tên app iOS: `CFBundleDisplayName` = `$(EXAMSUITE_DISPLAY_NAME)` ("Exam Suite Debug" ở Debug). Khoá này
  trong `Apps/StudentiOS/InfoPlist.xcstrings` đánh dấu không dịch (`shouldTranslate: false`): catalog không biên dịch nó
  vào `InfoPlist.strings`, nên app dùng giá trị của Info.plist theo cấu hình build (đã kiểm trên app Debug). Export ghi giá
  trị vi của khoá này theo cấu hình Debug. Bản dịch vi/en của ba khoá còn lại chép từ catalog của bản Học viên macOS rồi để
  Xcode ghi lại bằng export. `check_localization.py --built-apps` bỏ qua khoá không dịch và báo nếu nó lại có trong
  `InfoPlist.strings`.
- 2026-10-30, I0, ký: target iOS `CODE_SIGN_STYLE: Automatic`, `CODE_SIGN_IDENTITY: Apple Development`, simulator `-`;
  không `DEVELOPMENT_TEAM` trong repo (truyền lúc build cho máy thật). Build simulator không cần tài khoản.
- 2026-10-30, I0, chưa làm (để đúng bước): luật `scene-locale` cho bản iOS (I1, khi `.interfaceLocale()` ở InterfaceCore);
  mức `ios` của `verify_scope.py` (đường dẫn iOS hiện là mức full; đề xuất khi cần ở I2, Nt0 duyệt); nhận `.exam` từ app
  Tệp, Safari, hộp chia sẻ và thư mục `Inbox` (I2, khi app có màn Thư viện).
- 2026-10-30, I0, review độc lập (phiên agent mới, trên 176972a): REQUEST CHANGES, một mục chặn: plan-ios-v1.md xếp I0
  là rủi ro thường, trái review-and-merge.md mục 3 (I0 chạm `project.yml`, `Apps/**`, `scripts/check_boundaries.py`).
  Sửa: I0 là rủi ro cao, một review độc lập (chính lần này). Bảy mục không chặn sửa trong cùng PR:
  - AGENTS.md, docs/README.md ghi ADR 0013 và plan iOS đã chốt;
  - review-and-merge.md khớp `uitest_plan.py` (phần chỉ của iOS chỉ chạy lớp iOS), thêm
    `Packages/MobileFeatures/Package.swift` vào vùng ranh giới hai bản app;
  - plan-ios-v1.md bỏ chữ cũ (module dùng chung, mức `ios`, vùng rủi ro của SharedFeatures, việc lùi sang I2);
  - `check_localization.py --built-apps` chỉ cho `CFBundleDisplayName` của bản iOS đánh dấu không dịch
    (`UNTRANSLATED_INFO_KEYS`): trước đó khoá Info.plist của macOS đánh dấu không dịch thì mất bản dịch mà không bước
    nào báo; có đối chứng âm cho khoá macOS và khoá iOS ngoài danh sách (tắt phép kiểm thì đối chứng báo: đã thử);
  - `check_bundle_boundary.sh` đòi ký hiệu MobileShell trong app iOS (đối chứng dương, như AuthoringFeature của bản
    Admin; app iOS chỉ có Info.plist thì thất bại: đã thử);
  - `AppLaunchStorageTests` đọc `EXAMSUITE_IOS_CONFIG_SUFFIX` theo cấu hình từ project.yml (đổi đuôi Debug thì test
    đỏ: đã thử);
  - mô tả status đặt "iOS ok" sau phần UI test: trước đó "kiểm Autosave: bỏ qua" bị cắt ở 140 ký tự khi chạy
    incremental, chọn lớp theo file đổi.

  Việc review nêu cho bước sau ghi vào dòng I1, I2 của plan-ios-v1.md: bảng map `uitest_plan.py`, `unlisted_bundles`,
  `check_test_only_module` biết `Packages/SharedFeatures` (I1); `check_release_strings.sh` thêm bản Release iOS,
  `LaunchUITests` thay bằng test chế độ cô lập (I2).
- 2026-10-30, I0, re-review (cùng phiên review, trên a0d0bfb): APPROVE. Ba mục chữ không chặn sửa trong cùng PR: tóm
  tắt của plan-ios-v1.md ghi I0 là rủi ro cao; AGENTS.md trỏ mục "Bản iOS" của mobile.md, plan iOS đang làm, bước UI
  test có target iOS; "iOS ok" trong mô tả status có thể bị cắt (review-and-merge.md, plan-ios-v1.md Phần 5).
- 2026-10-30, I0: LaunchServices của macOS ghi nhận các app iOS build cho simulator (`build/DerivedData-iOS*`, cả bản
  `.uitest` có `LSHandlerRank` Alternate) và chúng khai báo nhận `vn.io.nt0.exam`, nhưng mang cờ `launch-disabled`,
  `requires-iphone-simulator` (`lsregister -dump`): macOS không mở `.exam` bằng chúng. `verify_local.sh` không xoá
  chúng (khác app Debug/Release macOS mang bundle ID thật).
- 2026-10-30, I0, Nt0: VS Code chưa có Full Disk Access, chạy `verify_local.sh --uitest --no-autosave-check` (status
  ghi "kiểm Autosave: bỏ qua", như cổng 265ab44).

- 2026-10-30, I0, `verify_local.sh --uitest --no-autosave-check` trên 72b6dac (Nt0 vắng): bản Học viên và bản Admin
  "Timed out while enabling automation mode" (macOS cần xác thực để bật Automation Mode), bản iOS đạt; status failure.
  Theo AGENTS.md: dừng, không chạy lại; chạy lại khi Nt0 có mặt để xác thực.
- 2026-10-30, I1, `reportReviewLevel` (Phần 3 của plan để I1 chọn): chọn cách đề xuất, protocol riêng. `SessionPreferences`
  (SessionModel) chỉ còn tên thí sinh và chế độ lần trước; `ReportPreferences` (SessionFeature) có `reportReviewLevel`,
  `UserDefaultsSessionPreferences` thoả nó bằng extension ở SessionFeature (cùng khoá `report.resultsReviewLevel`, nên
  `defaults` của lớp này thành `public`). `SessionCoordinator.reportPreferences` truyền xuống cửa sổ như `reportServices`
  (`SessionAppController` gán); thiếu thì Xuất PDF/In không chạy, như thiếu `reportServices`. Không tách phần Foundation
  của ReportFeature (việc của J1).
- 2026-10-30, I1, Hiện trong Finder: `LibraryModel` ở InterfaceCore không import AppKit; `revealFiles` mặc định không làm
  gì, `LibraryModel.persistent(configuration:defaults:)` dời sang LibraryFeature (`Model/LibraryModel+Finder.swift`) và
  truyền `NSWorkspace`, nên hai shell gọi như cũ, app macOS không đổi hành vi.
- 2026-10-30, I1, test: `LibraryDataTests` (tự đủ, có fixture kho v1) dời sang SharedFeatures như plan. Test của phần tách
  sang InterfaceCore, SessionModel ở lại test target của ExamFeatures (`LibraryFeatureTests`, `SessionFeatureTests`…),
  chỉ đổi `import` (`@testable import` qua package chạy được: SwiftPM bật testability cho mọi module khi build test). Lý
  do: support test (`Harness`, `FakeLibrary`, `FeatureWorkspace`) dùng chung với test của phần AppKit và PDF; dời test
  thì phải chép support thành hai bản. Số test không đổi: 788 = 104 (SharedFeatures) + 684 (ExamFeatures). Đổi nội dung
  test ngoài `import`, vì khoá hay bundle đổi module: `LocalizationTests` (LibraryFeature, SessionFeature),
  `CatalogLanguagesTests` (thêm bundle InterfaceCore, SessionModel; InterfaceCore là bundle chọn ngôn ngữ),
  `InterfaceLocaleTests`, `LocalizationSupport.catalogText`, `ErrorMessagesTests.catalogKeys` (catalog InterfaceCore),
  `AppLaunchStorageTests.chosenFileHookIsDebugOnly` (quét cả Sources của SharedFeatures, MobileFeatures, để không mất
  `AppLaunchStorage.swift`); test giả `FakePreferences`, `FixedPreferences` khai báo thêm `ReportPreferences`,
  `ResultsReportFlowTests`, `ContentSizedWindowTests` gán `reportPreferences`.
- 2026-10-30, I1, `public` thêm cho đúng năm khai báo SessionFeature dùng qua package: `PlainMarkdown.attributed`,
  `PreExamModel.start()`, `PreExamModel.rememberStartedChoices()`, `ResultsModel.init(submission:content:environment:)`,
  `UserDefaultsSessionPreferences.defaults`; mọi khai báo khác đã `public` từ trước.
- 2026-10-30, I1, iOS: `MobileFeature` phụ thuộc cả ba module dùng chung (I1 chưa dùng) để bản build iOS của
  `verify_local.sh` biên dịch chúng cho iOS: bằng chứng "không AppKit" do trình biên dịch, không thêm luật script.
  `MobileFeatureTests` (một test: kho mở, đề mẫu, bookmark khi thư mục đổi chỗ) nằm trong scheme `ExamSuiteiOS` (XcodeGen
  `package: MobileFeatures/MobileFeatureTests`); `verify_local.sh` mức full chạy `-only-testing:MobileFeatureTests` sau
  bước build iOS, không có test nào chạy là thất bại.
- 2026-10-30, I1, catalog (QI6): script một lần, không commit: chép catalog cũ thành catalog mới, `xcstringstool sync` với
  `.stringsdata` của target, bỏ khoá stale; làm cả với catalog cũ. InterfaceCore 150 khoá, SessionModel 85, LibraryFeature
  232 → 86, SessionFeature 199 → 134 (khoá dùng ở cả hai nơi có ở cả hai), catalog khác không đổi; không khoá nào thiếu
  `en`. Sau đó `-exportLocalizations` ba scheme không đổi file nào.
- 2026-10-30, I1, script: `check_bundle_boundary.sh` không cần đổi (bundle của module chỉ Admin vẫn mang tên
  `ExamFeatures_…`; bundle `SharedFeatures_…` có chữ do `check_localization.py --built-apps` kiểm: `BUILT_APPS`,
  `BUILT_IOS_APPS`, `unlisted_bundles`). `check_test_only_module` duyệt mọi package. `Packages/SharedFeatures/Package.resolved`
  được commit (SwiftPM tạo khi build; chỉ ghim ZIPFoundation 0.9.20 như ExamKit).
- 2026-10-30, I1, review độc lập (phiên agent mới, trên 88211ad): REQUEST CHANGES, một mục chặn:
  `scripts/measure_large.sh` chỉ chạy `Timing` của ExamKit và ExamFeatures, nên lần đo Release sau mất các dòng Thư viện
  (`LibraryTimingTests` đã sang SharedFeatures). Sửa: chạy cả SharedFeatures. Mục không chặn đã sửa: AGENTS.md (ràng buộc
  của ReportFeature), accessibility-localization.md (`ErrorMessages` ở InterfaceCore), docstring luật 7 của
  `check_boundaries.py`, plan-ios-v1.md (test của InterfaceCore, SessionModel ở lại ExamFeatures, nên PR chạm
  SharedFeatures vẫn chạy test của ExamFeatures), chú thích `revealFiles` (code macOS dựng Thư viện qua
  `LibraryModel.persistent`), test `appControllerWiresReportFlow` (`SessionAppControllerTests`: bản app gắn
  `reportServices` và `reportPreferences`, khoá defaults như cũ; đối chứng: bỏ dòng gán thì test đỏ). Ghi lại, không
  sửa:
  - `.github/workflows/ci.yml`, job `apps-macos` (chỉ chạy tay) chỉ chạy `swift test` của ExamKit và ExamFeatures, nên
    không còn chạy `LibraryDataTests` (104 test, kể cả test kho v1). AGENTS.md không cho sửa CI khi chưa được yêu cầu:
    chờ Nt0 quyết (thêm một bước `swift test --package-path Packages/SharedFeatures`, hoặc gọi `scripts/check.sh`).
  - `PreExamModel.start()`, `rememberStartedChoices()` nay `public`: module khác gọi thẳng được, bỏ qua kiểm Huỷ và "mỗi
    lúc một phiên" của `SessionCoordinator.startPreExam()`. Màn iOS ở I2 đi qua một điều phối tương đương.
- 2026-10-30, I1, re-review (cùng phiên review, trên 10a7263): APPROVE. Sửa thêm một nit: test
  `appControllerWiresReportFlow` so chuỗi khoá `report.resultsReviewLevel`, không so hằng.
- 2026-10-31, I2, tách đôi: I2a (giao diện, nhận file, tự tạm dừng, UI test) và I2b (snapshot iPhone). Snapshot cần
  sửa ADR 0010 (SnapshotTesting chỉ ở test của ExamFeatures), `check_boundaries.py` luật 5, `Package.resolved` của
  MobileFeatures: một thay đổi chính sách riêng nên để PR riêng cho dễ review; I2a không thiếu bằng chứng hành vi
  (unit test, UI test, kiểm trợ năng). Plan cho phép tách đôi I2.
- 2026-10-31, I2a, điều phối phiên của iOS (`MobileSessionCoordinator`, `MobileSession`): viết riêng ở MobileFeature,
  không dời `SessionCoordinator` của macOS (gắn cửa sổ, Xuất PDF/In, hộp hỏi AppKit). Cùng luật: mỗi lúc một phiên, đọc
  lại file đề khi mở và khi bắt đầu, kiểm lại sau mỗi lần chờ, Làm lại / Luyện lại câu sai, Bỏ bài không lưu.
  `SessionOpenOutcome`, `SessionNotice` dời sang SessionModel để hai bên dùng chung; chữ của hộp hỏi Thư viện
  (`LibraryPrompt.alertTitle`, `alertMessage`) dời từ LibraryFeature sang InterfaceCore.
- 2026-10-31, I2a, mở file từ app khác: hộp chia sẻ, "Mở bằng" (Zalo, Mail, AirDrop) giao bản chép trong
  `Documents/Inbox`; app dời sang `Application Support/<bundle ID>/Received/` (trùng tên thì thêm số) rồi đi qua đúng
  luồng Thêm đề của Thư viện (`LibraryModel.openFromFinder`). App Tệp mở tại chỗ (`LSSupportsOpeningDocumentsInPlace`):
  không dời, thêm bằng bookmark trong lúc mở quyền security scope. Đang có phiên thì hộp hỏi của Thư viện chờ tới khi
  về Thư viện (QI12b).
- 2026-10-31, I2a, quyền đọc file ngoài container trên iOS: `SecurityScopedAccess.with(_:)` bọc mọi chỗ đọc file đề của
  Thư viện (kiểm file, đọc, tạo bookmark khi thêm, làm mới) và lần đọc của phiên thi (`LibraryStoreSessionLibrary`,
  phân giải lại bookmark: `fileBookmark(_:)`). macOS: `#if os(iOS)`, gọi thẳng, không đổi hành vi.
- 2026-10-31, I2a, UI test luồng 2 (plan để I2 chốt cách mở file): XCUITest không lái được hộp chia sẻ của app khác
  hay hộp chọn file của iOS, nên luồng 2 thêm file bằng Thêm đề với file truyền vào (`-ExamSuiteUITestChosenFile`, như
  bản Admin macOS): bản chép của đề mẫu, nên Thư viện hỏi Dùng file mới / Huỷ. Phần dời khỏi `Inbox` kiểm bằng
  `MobileFeatureTests`; nhận file thật từ Zalo/Drive kiểm tay ở GI2.
- 2026-10-31, I2a, màu và trợ năng: màu nhấn teal và màu trạng thái từ bảng màu số (`MobilePalette.swift`, file bảng
  màu của `check_colors.py`); chữ phụ là chữ chính mờ 75% (màu `.secondary` của iOS chỉ khoảng 3,5:1 với chữ nhỏ, kiểm
  trợ năng báo); tiêu đề nhóm là dòng đầu của nhóm (header của `List` bị ép chữ phụ); thanh nút dưới nền đặc. Kiểm trợ
  năng của iOS (mọi loại) ở các màn: Thư viện, Trước khi thi (Luyện tập), làm bài, Rà soát & nộp, Kết quả Đậu, Xem lại
  bài (luồng 1); Trước khi thi (Thi), Rà soát khoá, bảng câu hỏi, Kết quả Trượt (luồng 2); Tạm dừng (luồng 3). Không kiểm
  hộp thoại (Bỏ bài?, Dùng file mới), ảnh phóng to, bảng câu hỏi ở cỡ vừa. Ngoại lệ ghi trong
  `Support/PhoneApp.swift`: nút đang tắt (WCAG
  1.4.3), nút của mọi thanh điều hướng đang có (cỡ chữ cố định, Large Content Viewer), chữ tĩnh trong `List` báo nhầm
  "Dynamic Type partially unsupported" (ảnh chụp ở Accessibility L cho thấy chúng phóng to và xuống dòng).
- 2026-10-31, I2a, review độc lập (phiên mới, trên 8d6ee99): REQUEST CHANGES, hai mục chặn, đã sửa:
  1. Ảnh phóng to vẫn hiện khi tự tạm dừng (sheet gắn ở màn làm bài, không theo câu): ảnh đóng khi câu bị che (Tạm
     dừng, Rà soát) và không mở lại, như sheet ảnh của macOS; luồng 3 kiểm (phóng to, xuống nền, Tiếp tục).
  2. Luồng 2 không kiểm trợ năng: thêm ở Rà soát khoá, bảng câu hỏi, Kết quả Trượt. Kiểm mới bắt được: số câu 10–12
     ở Rà soát xuống dòng ("1/0") ở cỡ chữ lớn (ô rộng theo cỡ chữ, số dài thu nhỏ); hiệu ứng mờ mép dưới của iOS 26
     làm nhạt chữ sát thanh nút (tắt ở vùng cuộn ngay trên thanh nút nền đặc: câu hỏi, Rà soát, Xem lại bài). Kiểm báo
     nhầm khi màn đang chuyển (Rà soát khoá hiện ra bằng hoạt cảnh mờ dần, cây trợ năng không đổi): kiểm chờ ít nhất
     1 giây rồi tới khi cây trợ năng đứng yên; ngoại lệ "Dynamic Type" theo nhãn đổi thành chữ tĩnh của `List`/`Form`
     (khớp nhãn và khung, chỉ báo "partially unsupported"; nhãn báo nhầm đổi theo lần chạy; chữ của MobileFeature chỉ
     dùng text style), có ảnh ở Accessibility L làm bằng chứng; bảng câu hỏi kiểm ở cỡ lớn của sheet (ở cỡ vừa, chữ của
     màn bên dưới thấy mà không đọc được, kiểm báo nhầm; cỡ vừa không được kiểm).
  Re-review (phiên mới, trên ecd5844): APPROVE. Làm thêm theo gợi ý: thu hẹp ngoại lệ như trên; kiểm Trước khi thi ở
  Thi sau khi gõ số phút (ô số mới); Thư viện bỏ chọn sau khi cuộn để lần sau cùng đề vẫn cuộn; ngưỡng cỡ lớn của sheet
  theo chiều cao màn. Chưa có máy kiểm nào giữ "MobileFeature không dùng cỡ chữ cố định"; snapshot cỡ chữ lớn ở I2b phủ
  một phần. Kiểm mới ở Trước khi thi (Thi) và các lần chạy lặp cho thấy thêm hai chỗ báo nhầm, đã xử lý:
  - Tương phản chập chờn ở chữ chính của `List` (tiêu đề nhóm của Rà soát khoá), vì lượt kiểm Dynamic Type đổi cỡ chữ
    và `List` dựng lại dòng có hoạt cảnh. Nay kiểm tương phản chạy riêng, trước các loại khác, trên màn chưa đổi gì:
    hai lần chạy liên tiếp đạt.
  - Tương phản của nút trên thanh điều hướng ("Huỷ" của Trước khi thi, khi form đã cuộn tới ô thời gian): nút là kính
    Liquid Glass lấy màu từ nội dung cuộn bên dưới. Cùng nút đó đạt khi form chưa cuộn; màu chữ #006666 ≈7:1 trên nền
    trắng. Ngoại lệ tương phản cho phần tử nằm trọn trong thanh điều hướng, như cỡ chữ của thanh.
  Sửa thêm theo các mục không chặn, để iOS theo macOS: hộp "Bỏ bài?" có dòng phụ (exam-taking.md phương án 16); Rà
  soát mở được bảng câu hỏi từ thanh điều hướng (chỉ để xem khi khoá, chạm ô ở Rà soát chưa khoá thì quay lại làm bài
  tại câu đó, như macOS); Trước khi thi có ô số cho Số câu và Thời gian cạnh nút tăng/giảm; Thư viện cuộn tới đề vừa thêm/chọn
  (`LibraryModel.reveal`); hộp hỏi của Thư viện chờ cả khi sheet Trước khi thi đang mở; luồng 3 kiểm vuốt từ cạnh trái
  và trên nội dung không rời màn làm bài; `pauseInReview` chạy thêm `background`.
  Hộp hỏi của Thư viện chờ ở **mọi** màn của phiên (làm bài, Kết quả, Xem lại), không chỉ khi còn bài chưa nộp: trên
  iPhone màn của phiên che Thư viện, hộp hỏi Dùng file mới / Huỷ thuộc về Thư viện nên hiện khi về Thư viện; đề vẫn
  được thêm ngay. Không phải luật mới về dữ liệu (macOS hiện hộp trên cửa sổ Thư viện, luôn thấy được); ghi ở đây để
  Nt0 xem lại ở GI2.
  Còn lại cho GI2/I3 (không sửa ở I2a): `.inactive` (banner cuộc gọi) không tạm dừng (QI10, thử ở GI2); ảnh trong
  trình chuyển app có thể chụp câu hỏi; file iCloud chưa tải đọc lúc offline có thể báo "File hỏng" thay vì "Không
  tìm thấy file" (không dùng `NSFileCoordinator`; chỉ máy thật kiểm được); ảnh của câu giải mã trong `body`, không
  thu nhỏ (bộ nhớ, đo ở I3, QI15).
- 2026-10-31, I2b, cách chụp ảnh iPhone: test của package chạy trong tiến trình `xctest` của simulator, không có
  `UIApplication`, nên `drawHierarchy(in:afterScreenUpdates:)` ra ảnh trống; chụp bằng `CALayer.render(in:)`.
  `Snapshotting.image(on:)` của thư viện chụp ngay sau khi dựng, nên `List` ra trống, thiếu tiêu đề và nút của thanh
  điều hướng. Vì vậy test tự dựng cửa sổ 390×844 (vùng an toàn như `.iPhone13`), chụp tới khi hai lần liên tiếp giống
  nhau, rồi so bằng `assertSnapshot` (chiến lược ảnh, `perceptualPrecision` 0,98). Thư viện chụp không có
  `NavigationStack`: chia đôi cho thấy `.searchable` cùng `.refreshable` trong `NavigationStack` làm `render(in:)` không
  vẽ gì của nội dung (từng modifier riêng thì vẽ được). Không sửa màn thật chỉ để chụp được. Tiêu đề, nút của thanh
  điều hướng và nút của thanh dưới hệ thống có trong ảnh tối, không có trong ảnh sáng (ổn định giữa các lần chạy):
  ảnh sáng không bắt được hồi quy của các thanh đó, kính của iOS 26 kiểm tay ở GI2.
- 2026-10-31, I2b, review độc lập (phiên mới, trên 8d191f1): REQUEST CHANGES, đã sửa: múi giờ ghim cho cả tiến trình
  (`NSTimeZone.default`, như bản macOS; trước chỉ ghim `\.timeZone` của SwiftUI nên ngày giờ của Thư viện và Kết quả
  theo múi giờ của máy); thêm ảnh cỡ chữ lớn của Xem lại bài (mobile.md đòi làm bài, Kết quả, Xem lại) và ảnh cuối màn
  (`-end`: mười lựa chọn của câu dài, bảng Theo phần đủ tám phần), như ảnh `-end` của bản macOS; chụp ít nhất ba lần,
  báo lỗi khi ảnh không đứng yên sau 20 lần (cuối Kết quả và Xem lại bài cỡ chữ lớn cũng chụp không có
  `NavigationStack`, cùng lý do với Thư viện); `verify_local.sh` đòi cả hai target iOS có test chạy và suite "Snapshot
  iPhone" đạt; tài liệu sửa cho đúng (thanh điều hướng, vùng an toàn của iPhone tai thỏ, `Package.resolved` chỉ ghim
  cho `swift package`, project do XcodeGen sinh resolve theo `from:`). Còn lại: ảnh 390×844 (không phải cỡ iPhone 17
  402×874, không có bề ngang 375); ngôn ngữ của simulator không ghim (chữ qua `localized` khoá `vi`, `Text` theo
  `\.locale` của môi trường).
- 2026-10-31, I2b, dòng đề chưa Sẵn sàng (đề lỗi): I2a đặt `.disabled` cho cả dòng nên lý do lỗi bị làm mờ (thấy trên
  ảnh Thư viện). Nay dòng không mờ, chạm không làm gì (`startSession` từ chối), VoiceOver không đọc là nút; giống thẻ
  của macOS (chỉ nút Luyện tập/Thi tắt).

## Validation

Ghi theo từng bước.

I0:

- 176972a: `scripts/verify_local.sh --no-status` (mức full, chưa UI test): đạt, gồm build và ranh giới bundle của app
  iOS (AuthoringFeature, AuthoringData: 0 ký hiệu), chữ Info.plist vi/en của app iOS, export ba scheme không đổi
  catalog, bước Linux. `ExamSuiteiOSUITests` (`LaunchUITests`) đạt trên simulator iPhone 17, iOS 26.1.
- 176972a: `scripts/verify_local.sh --uitest --no-autosave-check` (đủ bộ): Admin 4 test, iOS 1 test đạt; kho,
  `defaults` thật không đổi; bản Học viên không chạy được test nào ("Timed out while enabling automation mode": trình
  chạy test không bật được Automation Mode, lỗi hạ tầng, không phải lỗi test). Status `local/verify` failure trên SHA
  này; chạy lại trên SHA sau khi sửa theo review.
- 72b6dac (SHA cuối, Nt0 có mặt để xác thực Automation Mode): `scripts/verify_local.sh --uitest --no-autosave-check`
  đạt, mức full, UI test đủ bộ (Học viên 6, Admin 4, iOS 1 test), kho thật không đổi; status `local/verify` success.
- Sau khi sửa theo review: tự kiểm của `check_localization.py --require-en`, `--built-apps` trên app iOS,
  `check_bundle_boundary.sh` (bản `.uitest` macOS và app iOS; đối chứng âm), `AppLaunchStorageTests` (16 test) đạt.

I1 (nhánh `feature/ios-i1`):

- `swift test --package-path Packages/SharedFeatures`: 104 test đạt (`LibraryDataTests`).
  `swift test --package-path Packages/ExamFeatures`: 684 test đạt. Tổng 788, bằng trước khi tách; sau khi sửa theo
  review thêm `appControllerWiresReportFlow` (789).
- `MobileFeatureTests` trên simulator iPhone 17, iOS 26.1: 1 test đạt; bản build iOS biên dịch LibraryData, InterfaceCore,
  SessionModel không lỗi, không cảnh báo.
- `xcodebuild -exportLocalizations` ba scheme: không đổi catalog nào.
- `check_localization.py --require-en --freshness`: đạt; đối chứng: bỏ một khoá của SessionModel thì bị bắt.
  `--built-apps` trên app iOS (bundle InterfaceCore, SessionModel có vi, en): đạt.
- Tự kiểm của `uitest_plan.py` (đối chứng: bỏ `SharedFeatures/Sources` khỏi `CODE_PATTERNS`, bỏ `MobileFeatures/Tests`
  khỏi `NO_UI_PATTERNS` thì tự kiểm thất bại), `verify_scope.py`, `check_boundaries.py`, `check_colors.py`,
  `check_quit_sheets.py`, `check_localization.py`: đạt.

I1, sau review: `local/verify` xanh trên c7aa612 (mức full, UI test đủ bộ: Học viên 6, Admin 4, iOS 1; kho thật không
đổi; Linux ok), check `android` của CI xanh; PR #9 merge.

I2a (nhánh `feature/ios-i2`):

- `MobileFeatureTests` trên simulator iPhone 17, iOS 26.1: 12 test đạt.
- `ExamSuiteiOSUITests`: ba lớp đạt (`PhonePracticeFlowUITests`, `PhoneExamFlowUITests`, `PhoneLeaveAppUITests`), kiểm
  trợ năng không còn vấn đề ngoài ngoại lệ đã ghi.
- `xcodebuild -exportLocalizations` ba scheme: lần thứ hai không đổi catalog; `check_localization.py --require-en` đạt.
- Sau review và re-review: `MobileFeatureTests` 12 test đạt; ba lớp `ExamSuiteiOSUITests` đạt, kể cả từ simulator vừa
  khởi động (lần chạy trước khi thêm chờ màn đứng yên có báo nhầm chập chờn ở Rà soát khoá); ảnh ở Accessibility L của
  Rà soát khoá và bảng câu hỏi (bằng chứng cho ngoại lệ); `check_localization.py --require-en`, `check_colors.py`,
  `check_quit_sheets.py`, `uitest_plan.py --self-test` đạt.

I2a, sau review: `local/verify` xanh trên 2a32ae6 (mức full, UI test đủ bộ: Học viên 6, Admin 4, iOS 3; kho thật không
đổi; Linux ok); PR #10 merge.

I2b (nhánh `feature/ios-i2b`):

- `MobileSnapshotTests` trên simulator iPhone 17, iOS 26.1: 10 test (17 ảnh) đạt hai lần liên tiếp, lần hai từ
  simulator vừa khởi động; `MobileFeatureTests` 12 test đạt cùng lần chạy.
- Đối chứng âm: thay ảnh tham chiếu `library-light` bằng ảnh tối thì `libraryList` đỏ (suite "Snapshot iPhone" thất
  bại); trả ảnh lại thì xanh.
- Xem từng ảnh (390×844, ≤ 126 KB): đề ẩn đáp án không có "Đáp án đúng" và giải thích; dòng Đề có lỗi không mờ; ảnh
  `-end` thấy lựa chọn C đang chọn tới J, và đủ tám phần cùng "Phần yếu nhất".
- `check_boundaries.py` (có `swift package describe`), `check_localization.py --require-en`, `check_colors.py`,
  `uitest_plan.py --self-test`, `verify_scope.py --self-test`: đạt.

## Result

Chưa có.
