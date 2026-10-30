# Execution Plan: Exam Suite cho iOS, v1 (bản Học viên)

Date: 2026-10-30

## Status

Active. I0 xong code và review trên nhánh `feature/ios-i0`, chờ `local/verify` (UI test macOS cần Nt0 xác thực
Automation Mode). I1 trên nhánh `feature/ios-i1`, xếp chồng trên I0.

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

- [ ] I0 Chuẩn bị (nhánh `feature/ios-i0`): ADR 0013, ADR 0003 ghi bản iOS; `mobile.md` mục "Bản iOS"; plan-ios-v1.md
      theo ba package; AGENTS.md, review-and-merge.md phần iOS; `AppLaunchStorage` biết hai bundle ID iOS (bản thật);
      package `MobileFeatures` (khung, chưa phụ thuộc); target `ExamSuiteiOS` (Info.plist, `InfoPlist.xcstrings` vi/en),
      `ExamSuiteiOSUITests` (một test mở app); `check_boundaries.py`, `check_bundle_boundary.sh`,
      `check_localization.py`, `check_quit_sheets.py`, `uitest_plan.py`, `verify_local.sh` biết bản iOS; spike
      (Decisions). Rủi ro cao (vùng ranh giới hai bản app): review độc lập xong, đã sửa theo review. Còn:
      `verify_local.sh --uitest` trên SHA cuối, PR.
- [ ] I1 `Packages/SharedFeatures`: dời LibraryData, tách model trình bày (rủi ro cao). Cổng GI1. Đã làm: package
      `SharedFeatures` (LibraryData, InterfaceCore, SessionModel; macOS và iOS), ExamKit thêm `.iOS(.v18)`, ExamFeatures
      và MobileFeatures phụ thuộc nó, `MobileShell` gắn `.interfaceLocale()`, `MobileFeatureTests` (kho trên simulator),
      dời khoá catalog, script kiểm và tài liệu biết package mới, đường dẫn đề mẫu của Android và bộ lọc của CI Android.
      Review độc lập xong, đã sửa theo review. Còn: `verify_local.sh --uitest` đủ bộ, check `android` của CI, PR (sau
      khi I0 merge).
- [ ] I2 Giao diện iPhone, nhận file, tự tạm dừng. Cổng GI2.
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

## Result

Chưa có.
