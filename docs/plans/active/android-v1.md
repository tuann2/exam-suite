# Execution Plan: Exam Suite cho Android, v1 (bản Học viên)

Date: 2026-10-22

## Status

Active. Bước **A0** (chuẩn bị, khung Gradle, spike) trên nhánh `feature/android-a0`, rẽ từ `main` 265ab44; PR mang cả
hai plan mobile, tài liệu rà soát macOS và plan này. Các bước sau theo lộ trình ở
[plan-android-v1.md](../../product/plan-android-v1.md) Phần 3. v1.1 lập plan riêng (`android-v1.1.md`) ở bước B1.

## Outcome

APK bản Học viên ký bằng keystore của Nt0, cài được trên Android 12 trở lên: Thư viện (danh sách), Thêm đề và mở `.exam`
từ app khác, Trước khi thi, Làm bài, Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại, Lịch sử thi, tự tạm
dừng và lưu phiên dở khi xuống nền, tiếng Việt và tiếng Anh, sáng/tối, đúng các quy tắc của tài liệu sản phẩm và
[mobile.md](../../product/mobile.md). Lõi Kotlin cùng kết luận với lõi Swift trên oracle chung. Qua cổng GA3.

## Context

- Kế hoạch: [plan-android-v1.md](../../product/plan-android-v1.md) (phạm vi Phần 1, kiến trúc Phần 2, lộ trình Phần 3,
  kiểm thử và sáu quy tắc chống test trùng Phần 4, rủi ro Phần 5, bảng Quyết định Nt0 chốt 2026-10-22).
- Hợp đồng: `docs/product/{exam-format,scoring,exam-session,exam-taking,library,accessibility-localization,large-exams}.md`
  và [mobile.md](../../product/mobile.md).
- Quyết định: [ADR 0011](../../decisions/0011-android-kotlin-compose.md) (công nghệ, repo, bằng chứng merge),
  [ADR 0012](../../decisions/0012-android-thu-vien.md) (thư viện).
- Quy trình: [review-and-merge.md](../../process/review-and-merge.md) (mục 2 có ngoại lệ CI theo PR cho `android/`,
  mục 3 rủi ro cao, mục 4 nhịp làm việc).
- Căn cứ cách chia bước: [notes/ra-soat-cach-lam-macos.md](../../notes/ra-soat-cach-lam-macos.md).

## Scope

In scope: các bước A0–A4 của plan-android-v1.md Phần 3, mỗi bước một PR.

Out of scope: mục v1.1 (PDF, tablet, lưới, Thông tin đề, lọc, Khôi phục đề mẫu, rà trình đọc màn hình đủ bảng, Reduce
Motion, `:benchmark`); Soạn đề, Import; đồng bộ giữa máy; Google Play công khai; bản iOS.

## Approach

Theo plan-android-v1.md Phần 3: A0 → A1 (lõi, rủi ro cao) → A2 (dữ liệu, rủi ro cao) ∥ A3b (giao diện làm bài) → A3a
(Thư viện, nối luồng, cổng GA2) → A4 (hoàn thiện, beta, cổng GA3). Nhánh song song cùng rẽ từ `main` sau khi bước phụ
thuộc đã merge; không xếp chồng quá một tầng.

## Risks And Recovery

- Rủi ro ở plan-android-v1.md Phần 5.
- Toàn bộ code nằm trong `android/` cộng một workflow riêng; gỡ một bước là revert PR của bước đó, không chạm bản macOS
  (trừ A1 sửa test Swift đọc oracle chung: revert cùng PR).

## Progress

- [x] A0 Chuẩn bị (PR này): ADR 0011, 0012; `mobile.md`; plan này; AGENTS.md, review-and-merge.md (ngoại lệ CI);
      khung Gradle `:core`, `:data`, `:app`, `:lint-rules` (một test mỗi module, luật lint có ba test);
      `android/scripts/check_android.sh`, `check_android_rules.py`; `.github/workflows/android.yml`; spike (Decisions).
- [ ] A1 Lõi `:core`
- [ ] A2 `:data` (chờ Nt0 chốt sao lưu dữ liệu, mobile.md Câu hỏi mở)
- [ ] A3b Giao diện làm bài (chờ Nt0 chốt mức cỡ chữ, mobile.md Câu hỏi mở)
- [ ] A3a Thư viện và nối luồng (chờ Nt0 chốt làm đề khác khi có phiên dở); cổng GA2
- [ ] A4 Hoàn thiện và beta; cổng GA3

## Decisions

- 2026-10-22, Nt0: chốt Q1–Q13 của plan-android-v1.md (bảng Quyết định); Q4 minSdk 31, Q8 CI theo PR thay lint + test
  tại chỗ, Q11 payload riêng với dấu vân tay câu của macOS, Q12 chỉ Nt0 test cổng, Q13 Android trước.
- 2026-10-22, A0, phiên bản (đều phát hành ít nhất hai tuần): Gradle 9.7.1 (AGP 9.4 cần tối thiểu 9.6), AGP 9.4.1,
  Kotlin 2.4.20, Compose BOM 2026.09.00 (Compose 1.12.1), JDK 17. Compose 1.12 đòi `compileSdk` 37, nên compileSdk và
  targetSdk 37 (theo "targetSdk mới nhất"; lint `OldTargetApi` báo lỗi với 36). Wrapper jar và bản phân phối Gradle khớp
  SHA-256 công bố; `distributionSha256Sum` ghi trong wrapper.
- 2026-10-22, A0, AGP 9: `android.sourceSets["main"].assets` ném lỗi ép kiểu trong Kotlin DSL; thư mục assets dùng chung
  (đề mẫu) thêm qua `androidComponents.onVariants { sources.assets?.addStaticSourceDirectory(…) }`.
- 2026-10-22, A0, Robolectric 4.17: ảnh API 37 chưa có; ảnh API 35 trở lên cần Java 21. `:data` chạy Robolectric ở API
  34 (`robolectric.properties`). **A2 quyết** có nâng JDK 21 (máy và CI) để test ở API 36 không.
- 2026-10-22, A0, spike nhận `.exam` (emulator Android 15): MediaStore gán `application/octet-stream` cho đuôi `.exam`
  (`.zip` là `application/zip`). Intent filter VIEW (scheme `content`) và SEND với `application/zip`,
  `application/x-zip-compressed`, `application/octet-stream` đều chọn được app; `am start -a VIEW -t
  application/octet-stream` mở được thật. **Không** khai báo `*/*`: app sẽ hiện trong "Mở bằng" của mọi loại file. App
  phải tự kiểm đuôi và chữ ký zip (A3a). Nhận thật từ Zalo, Drive: chỉ kiểm được ở GA2 trên máy thật.
- 2026-10-22, A0, spike zip (JDK 17): `ZipFile` liệt kê cả hai entry trùng tên nhưng `getEntry` lặng lẽ trả entry
  **cuối**; `ZipInputStream` đọc được từng entry. A1 đọc gói bằng `ZipInputStream`, tự kiểm trùng tên, đếm entry và cộng
  dồn kích thước giải nén khi đọc.
- 2026-10-22, A0, spike JSON: `kotlinx.serialization` (1.11.0, `Json.parseToJsonElement`) **nhận** khoá trùng (lấy giá
  trị cuối), `NaN`, độ sâu 40, surrogate lẻ (thành `?`); từ chối dấu phẩy thừa và BOM. `String(bytes, UTF_8)` thay byte
  hỏng bằng U+FFFD; `CharsetDecoder` chế độ REPORT ném `MalformedInputException`. A1 cần lượt `StrictJson` riêng trước
  khi giải mã, đúng như plan.
- 2026-10-22, A0, spike khoảng trắng: `Character.isWhitespace` khác danh sách `White_Space` của exam-format.md (U+00A0,
  U+0085 ra false; U+001C ra true). A1 dùng đúng danh sách từ khoá `whiteSpace` của `expected-verdicts.json` (10 dải, 25
  code point; test khung của `:core` đã đọc và đếm).
- 2026-10-22, A0, spike chuỗi: Android Lint không bắt `Text("…")` trong Compose (`HardcodedText` chỉ quét layout XML).
  Chọn **luật lint tự viết** `ComposeHardcodedText` (module `:lint-rules`, chạy trong `./gradlew lint` của `:app` và
  `:data`), không chỉ dựa vào review: bắt chuỗi literal có chữ cái truyền vào hàm `@Composable` hoặc gán cho
  `contentDescription`/`stateDescription`, kể cả string template và phép ghép; ngoại lệ bằng `@Suppress` kèm lý do.
  Đối chứng: ba test lint (dương, âm) và một lần thêm `Text("…")` thật vào app làm `lintDebug` đỏ.
- 2026-10-22, A0, phát hiện: **`tools:locale` trên `values/strings.xml` làm lint (AGP 9.4) bỏ qua `MissingTranslation`**,
  kể cả khi bật tường minh và đặt `fatal`. Bỏ thuộc tính thì cấu hình mặc định báo lỗi đúng. `values/` không có
  `tools:locale`; `check_android_rules.py` chặn thêm lại (có đối chứng âm).
- 2026-10-22, A0, spike trợ năng: `enableAccessibilityChecks()` của `ui-test-junit4-accessibility` chạy trong test
  Compose (rule `v2`); đối chứng âm (nút 10dp không nhãn) thất bại với `SpeakableTextPresentCheck`. Không lớp kiểm riêng.
- 2026-10-22, A0, spike screenshot: Compose Preview Screenshot Testing (plugin `0.0.1-alpha16`) chạy với AGP 9.4.1
  (`updateDebugScreenshotTest`, `validateDebugScreenshotTest`). layoutlib dựng ở `en-US` nên mỗi preview chụp phải ghi
  `locale` (tiếng Việt là nguồn); chữ có dấu hiển thị đúng. Ảnh tham chiếu ghi trên macOS; lần chạy đầu của job
  `android` trên Linux là đối chứng khác nền (kết quả ghi ở Validation).
- 2026-10-22, A0, tạm thời: sao lưu dữ liệu app tắt (`dataExtractionRules` loại trừ mọi miền, `allowBackup=false`),
  chờ Nt0 chốt trước A2 (mobile.md Câu hỏi mở). Biểu tượng app là biểu tượng **tạm** (vector), Nt0 thay sau.
- 2026-10-22, A0: các script macOS không quét `android/` (đã kiểm: `uitest_plan.py` coi file trong `android/` là không
  chạm giao diện, `check_localization.py`, `check_colors.py`, `check_quit_sheets.py`, `check_boundaries.py` chỉ quét mã
  Swift và Package/Apps); kết quả `scripts/check.sh` ghi ở Validation.

## Validation

A0:

- Focused proof: `./gradlew test` (`FixturesWiringTest`, `SampleAssetsTest`, ba test `ComposeHardcodedTextDetectorTest`),
  `./gradlew lint`, `:app:validateDebugScreenshotTest`, `check_android_rules.py` (tự kiểm âm/dương và đối chứng âm trên
  repo: thêm OkHttp vào danh mục thì đỏ).
- End-to-end: `:app:connectedDebugAndroidTest` trên AVD `examsuite` (Android 15 arm64), kiểm trợ năng bật.
- Repository-required checks: check `android` của `.github/workflows/android.yml` trên SHA cuối; `local/verify-android`
  (`check_android.sh --ui`, PR chạm `android/app/**`); `local/verify` (`scripts/verify_local.sh`, PR chạm tài liệu và
  workflow của repo: UI test macOS bỏ qua theo bảng map).

## Result

Ghi khi đóng plan sau cổng GA3.
