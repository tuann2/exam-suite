# 0013 Bản iOS: SwiftUI, hành vi theo bản macOS, dùng lại lõi và tầng dữ liệu Swift

Date: 2026-10-30

## Status

Accepted (Nt0 chốt QI1–QI15 của docs/product/plan-ios-v1.md ngày 2026-10-30, và cách tách package cùng ngày sau spike
của bước I0)

## Context

Bản Android (ADR 0011) đã xong v1. Bản iOS dùng được lại lõi Swift (ExamKit, ExamFile chỉ Foundation, ADR 0008) và tầng
dữ liệu Thư viện (LibraryData, không giao diện), nên không cần lõi thứ hai như Android. Nt0 muốn bản iOS **hành vi như
bản macOS**, không theo các luật riêng của Android trong `docs/product/mobile.md` (sao chép đề vào app, Cập nhật đề, lưu
phiên dở, không sao lưu).

Spike của bước I0 cho thấy một ràng buộc của công cụ: `xcodebuild -exportLocalizations` (cách repo đồng bộ String
Catalog, AGENTS.md mục "Chuỗi giao diện") build mọi target có catalog của mỗi package theo **mọi nền tảng package khai
báo**. Thêm `.iOS` vào `platforms` của `Packages/ExamFeatures`, nơi LibraryFeature, SessionFeature, ReportFeature,
AuthoringFeature `import AppKit`, làm export của cả hai scheme macOS thất bại, dù project không có target iOS. Ép SDK,
đích hay `SUPPORTED_PLATFORMS` không gỡ được mà không làm sai catalog Info.plist của hai app macOS.

## Decision

- **Chỉ bản Học viên** trên iPhone, iOS 18 trở lên (cùng thế hệ SDK với macOS 15 của repo), Swift 6, SwiftUI, SwiftData
  (kho hiện có). Bundle ID `vn.io.nt0.examsuite.ios`; bản Debug `vn.io.nt0.examsuite.ios.debug`, tên "Exam Suite Debug";
  build UI test thêm đuôi `.uitest` như hai bản macOS. ADR 0003 áp nguyên: bản iOS không chứa AuthoringFeature,
  AuthoringData, ExamImport.
- **Hành vi theo tài liệu macOS** (library.md, exam-taking.md, exam-session.md, scoring.md…): tham chiếu file tại chỗ bằng
  bookmark, trùng id như library.md, không lưu phiên dở, dữ liệu vào bản sao lưu của hệ thống. Chỗ khác do nền tảng
  và một quyết định mới (app xuống nền thì tự tạm dừng) ghi ở mục "Bản iOS" của `docs/product/mobile.md`.
- **Ba package Swift theo nền tảng**:
  - `Packages/ExamFeatures`: giao diện macOS, **chỉ khai báo macOS**.
  - `Packages/SharedFeatures` (tạo ở bước I1): module dùng chung macOS và iOS, không AppKit/UIKit: LibraryData (dời từ
    ExamFeatures), InterfaceCore, SessionModel (tách từ LibraryFeature, SessionFeature). Khai báo macOS và iOS.
  - `Packages/MobileFeatures`: giao diện iPhone (MobileFeature, MobileShell), chỉ khai báo iOS, chỉ build bằng
    `xcodebuild` với đích iOS.
  - `Packages/ExamKit` thêm iOS khi SharedFeatures cần (bước I1).
- **Cùng `project.yml`**: target `ExamSuiteiOS` chỉ phụ thuộc product `MobileShell`; UI test `ExamSuiteiOSUITests` chạy
  trên simulator.
- **Bằng chứng merge**: vẫn một status `local/verify`; ở mức full, `scripts/verify_local.sh` build bản iOS cho simulator,
  kiểm ranh giới bundle (ADR 0003) và chữ Info.plist vi/en của app iOS, export catalog của scheme `ExamSuiteiOS`;
  `--uitest` chạy các lớp iOS mà `scripts/uitest_plan.py` chọn.
- **Phân phối v1**: chỉ cài qua Xcode bằng Personal Team miễn phí (bản cài hết hạn sau 7 ngày); team ID không ghi vào
  repo. Phát cho người khác (TestFlight, Ad Hoc, tài khoản trả phí) là quyết định sau. App Store công khai ngoài phạm vi.
  Phiên bản riêng, bắt đầu 0.1.0, tag `ios-v*`.

## Alternatives Considered

1. Hành vi theo luật mobile của Android (`mobile.md`): cần thêm sao chép đề, Cập nhật đề, phiên dở (`snapshot`/`restore`
   trong lõi), loại khỏi sao lưu; thêm một PR rủi ro cao. Nt0 chọn hành vi macOS.
2. Giữ một package ExamFeatures cho cả hai nền tảng, bọc `#if os(macOS)` mọi file của target chỉ macOS (khoảng 100
   file): chưa chắc export không đánh dấu khoá là stale, và mọi file macOS mới sau này phải bọc.
3. Thay `-exportLocalizations` bằng `xcstringstool sync` từ `.stringsdata`: đổi quy trình chuỗi giao diện đã dùng từ giai
   đoạn 5 và bước kiểm của `verify_local.sh`.
4. Chép model trình bày sang iOS thay vì tách module dùng chung: hai bản luật (hideAnswers, câu đã sửa, trạng thái file)
   phải sửa song song.

## Consequences

Positive:

- Một nguồn cho lõi, tầng dữ liệu và model trình bày; test hiện có đi theo module. Không oracle parity như Android.
- Export String Catalog chạy được cho cả ba scheme mà không đổi quy trình.

Tradeoffs:

- Dời LibraryData (bước I1) đổi đường dẫn đề mẫu mà `android/data/build.gradle.kts` và bộ lọc đường dẫn của
  `.github/workflows/android.yml` trỏ tới (Nt0 duyệt sửa hai chỗ này cùng bước I1), và đổi tên bundle tài nguyên trong
  app macOS (`ExamFeatures_LibraryData.bundle` thành `SharedFeatures_LibraryData.bundle`).
- iOS có thể dừng app khi app ở nền; không có phiên dở thì bài đang làm mất (chấp nhận ở v1).
- Cài lên iPhone thật cần Xcode và cắm máy mỗi 7 ngày.

## Follow-Up

- Bước I1: tạo `Packages/SharedFeatures`, dời LibraryData, tách InterfaceCore, SessionModel; luật `scene-locale` thêm
  MobileShell và Apps/StudentiOS khi `.interfaceLocale()` vào InterfaceCore.
- Bước I2: test target snapshot trong `Packages/MobileFeatures` (sửa ADR 0010 và `check_boundaries.py` cùng PR).
