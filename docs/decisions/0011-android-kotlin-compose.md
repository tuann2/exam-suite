# 0011 Bản Android: Kotlin + Jetpack Compose, lõi viết lại bằng Kotlin, cùng repo trong `android/`

Date: 2026-10-22

## Status

Accepted (Nt0 chốt Q1, Q2, Q3, Q4, Q8, Q11, Q13 của docs/product/plan-android-v1.md ngày 2026-10-22)

## Context

Học viên luyện thi trên điện thoại nhiều hơn trên máy Mac. Bản macOS viết bằng Swift; lõi ExamKit/ExamFile chỉ dùng
Foundation (ADR 0008) nhưng Swift trên Android còn ở mức preview, cần NDK và cầu JNI, không build/test được trong Gradle
thường. Flutter và Kotlin Multiplatform đều vẫn phải viết lại lõi lần nữa và thêm gói bên thứ ba hoặc toolchain mới
(plan-android-v1.md, ghi chú Q2). Phạm vi, thứ tự và các khác biệt với macOS đã chốt ở plan và `docs/product/mobile.md`.

## Decision

- **Chỉ bản Học viên** trên Android. Soạn đề, Import, PDF đề vẫn chỉ ở bản Admin macOS (ADR 0003 không đổi).
- **Kotlin 2.x + Jetpack Compose + Material 3**, native. minSdk 31 (Android 12); targetSdk và compileSdk mới nhất có
  bản phát hành (A0: 37). Gói `vn.io.nt0.examsuite.android`; bản debug thêm đuôi `.debug` để không bao giờ đụng dữ liệu
  bản phát hành trên cùng máy.
- **Lõi viết lại bằng Kotlin thuần** trong module `:core` (JVM, không Android SDK trên classpath, nên lõi không import
  được `android.*`: đồ thị Gradle chặn lúc biên dịch, không cần script). Lõi Kotlin phải cùng kết luận với lõi Swift trên
  **oracle dùng chung** trong `fixtures/` (kết luận kiểm đề, vector SplitMix64, dấu vân tay câu, ca JSON sai cú pháp);
  đổi hành vi lõi thì sửa oracle trước, rồi hai bên cùng xanh.
- **Payload lần thi là định dạng riêng của Android** (Q11), có JSON mẫu riêng chặn đổi khoá ngầm; dấu vân tay câu dùng
  đúng thuật toán `QuestionFingerprint` của macOS để quy tắc "câu đã sửa sau lần thi" giống hệt. Đồng bộ lịch sử giữa máy
  ngoài phạm vi; nếu làm thì cần bộ chuyển đổi và quyết định mới.
- **Cùng repo, thư mục `android/`**: dự án Gradle độc lập, đọc `schema/`, `fixtures/`, đề mẫu
  (`Packages/ExamFeatures/Sources/LibraryData/Resources/Samples/`) tại chỗ, không chép.
- **Bằng chứng merge** (Q8): workflow `.github/workflows/android.yml` chạy theo PR chạm `android/` hoặc oracle; check
  `android` xanh trên SHA cuối thay cho kiểm tại chỗ phần lint + test. PR chạm `android/app/**` và mọi cổng cần thêm
  status `local/verify-android` (test Compose trên emulator, `android/scripts/check_android.sh --ui`). PR chạm cả phần
  Swift cần thêm `local/verify` như cũ. Workflow `CI` của macOS không đổi.
- **Android trước, iOS sau** (Q13); iOS dùng lại lõi Swift (docs/product/plan-ios-v1.md).

## Alternatives Considered

1. Swift SDK for Android qua JNI: còn preview, agent không build/test trong Gradle thường.
2. Kotlin Multiplatform: vẫn hai lõi (macOS giữ Swift), thêm toolchain Kotlin/Native.
3. Flutter: lõi viết lại bằng Dart (không có NFC trong thư viện chuẩn, zip đọc cả file vào bộ nhớ), 6–8 gói bên thứ
   ba, vẫn cần code native để nhận file, mất quyền dùng lại lõi Swift trên iOS.
4. Repo riêng: phải chép hoặc submodule oracle và đề mẫu, dễ lệch, hai quy trình.

## Consequences

Positive:

- App native, không gói bên thứ ba ngoài nền tảng (ADR 0012); lõi Kotlin test trên mọi máy không cần emulator.
- Hai lõi bị oracle chung giữ cùng kết luận; ranh giới lõi do Gradle chặn.

Tradeoffs:

- Hai lõi phải giữ đồng bộ mãi; mọi đổi luật lõi chạm cả Swift và Kotlin trong cùng PR hoặc theo thứ tự oracle trước.
- Lịch sử thi Android và macOS khác định dạng.

## Follow-Up

- A1 chuyển vector cố định sang `fixtures/vectors/` và thêm `fixtures/invalid-json/`, sửa test Swift đọc từ đó.
- Branch protection vẫn chưa bật; người duyệt tự kiểm check `android` và các status trước khi merge.
