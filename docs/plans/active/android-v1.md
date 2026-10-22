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
- [x] A1 Lõi `:core` (PR này, rủi ro cao): model, `StrictJson`, giải mã, đọc gói nghiêm, `ExamValidator`, `Scorer`,
      `ExamComposer` (SplitMix64), `ExamSession` + phiên dở (`snapshot`/`restore`, `SnapshotCodec`), `AttemptPayload`,
      `QuestionFingerprint`, `ReviewItems`, Markdown cơ bản; oracle chung `fixtures/vectors/`, `fixtures/invalid-json/`,
      khoá `issueCodes` của `expected-verdicts.json`, test Swift đọc từ đó; 187 ca JUnit (85 ca oracle).
- [ ] A2 `:data`
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
  `locale` (tiếng Việt là nguồn); chữ có dấu hiển thị đúng. Ảnh tham chiếu ghi trên macOS và **so đạt trên runner Linux** của job
  `android` (lần chạy đầu, run 39725459093 trên 954852f): giữ cách ghi ảnh trên Mac. Màn có nhiều chữ hơn mà lệch giữa hai
  nền thì ghi lại ảnh bằng Docker Linux (A3b quyết khi gặp).
- 2026-10-22, Nt0 (duyệt PR #1): **không sao lưu lên đám mây, không chuyển sang máy mới** (mobile.md). Thực hiện bằng
  `allowBackup=false` và `dataExtractionRules` loại trừ mọi miền ở cả `cloud-backup` và `device-transfer`. Biểu tượng
  app là biểu tượng **tạm** (vector), Nt0 thay sau.
- 2026-10-22, A0: các script macOS không quét `android/` (đã kiểm: `uitest_plan.py` coi file trong `android/` là không
  chạm giao diện, `check_localization.py`, `check_colors.py`, `check_quit_sheets.py`, `check_boundaries.py` chỉ quét mã
  Swift và Package/Apps); kết quả `scripts/check.sh` ghi ở Validation.

- 2026-10-22, A1, đọc zip: **đổi kết luận spike A0** từ `ZipInputStream` sang `java.util.zip.ZipFile`. `ZipFile`
  đọc mục lục trung tâm như ZIPFoundation của bản macOS, `entries()` liệt kê đủ entry trùng tên (spike A0) nên từ chối
  được trước khi đọc, và cho đọc một ảnh lúc cần mà không giải nén lại cả gói. `getEntry` lấy entry cuối khi trùng nhưng
  không bao giờ được gọi trên gói có tên trùng. `ZipFile` không tự so CRC: bộ đọc tự so CRC và kích thước như bản macOS.
- 2026-10-22, A1, ảnh: bộ đọc kiểm mọi ảnh (tên, kích thước, CRC, trần tổng) lúc nhập đề nhưng **không giữ ảnh trong bộ
  nhớ** (`ExamPackage.mediaPaths`; app đọc bằng `readMedia` từ file đề đã sao chép vào app, mobile.md). Kết luận nhận/từ
  chối giữ như bản macOS.
- 2026-10-22, A1, khác biệt đã biết: `ZipFile` không cho biết entry là symlink nên entry symlink được đọc như file thường
  (nội dung là chữ của đường dẫn đích, không theo liên kết); bản macOS bỏ qua chúng. Chỉ khác ở gói cố tình đặt symlink tên
  `exam.json` hay tên ảnh hợp lệ, cả hai bản đều không mở được đề đúng hoặc không hiện được ảnh đó.
- 2026-10-22, A1, giải mã: bộ phân tích JSON riêng (`StrictJson`) dựng cây theo đúng cách `JSONSerialization` nhận
  (đối chiếu bằng 35 ca `fixtures/invalid-json`); số nguyên như `JSONDecoder` (thăm dò trên macOS): chữ số thuần đọc
  thành Int64, tràn là lỗi; có `.`/`e` thì qua Double, nhận nếu là số nguyên trong Int64 (`1.0`, `5e1` hợp lệ; `70.5`
  lỗi); UUID đúng 8-4-4-4-12 (Swift không nhận `1-1-1-1-1` như `UUID.fromString`). Số nguyên của đề giữ kiểu `Long`
  để kiểm đề báo đúng giá trị ngoài khoảng như bản macOS.
- 2026-10-22, A1, phiên dở (Q7): `PauseReason.BACKGROUND` mới. Khôi phục: đang làm hay rà soát chưa khoá → Tạm dừng
  (lý do xuống nền), thời gian đã làm như lúc chụp; đang tạm dừng, hết giờ, rà soát khoá → giữ nguyên trạng thái; cảnh báo
  đã phát và sự kiện chờ giữ lại. Đề đổi (id, câu, lựa chọn) hay dữ liệu mâu thuẫn → `InvalidSnapshot`, app bỏ phiên dở.
  `SnapshotCodec` có `draftVersion`; A2 lưu chuỗi này.
- 2026-10-22, A1, payload (Q11): `AttemptPayload` JSON riêng của Android, cùng nội dung và cùng luật kiểm nhất quán với
  `AttemptRecord`; JSON mẫu cố định `android/core/src/test/resources/attempt-payload-v1.json`.
- 2026-10-22, A1, oracle: bảng "fixture sai nào ra mã vấn đề nào" chuyển từ test Swift vào khoá `issueCodes` của
  `fixtures/expected-verdicts.json` (quy tắc 4: oracle chung thay ca inline); script Python bỏ qua khoá này. Vector
  SplitMix64, chọn câu, dấu vân tay và ca JSON đọc nghiêm cũng chuyển từ test Swift ra `fixtures/`; giá trị không đổi.
- 2026-10-22, A1: `ReviewItems` là nơi duy nhất của luật Xem lại (bộ lọc, `hideAnswers`, câu đã sửa/xoá, mức xem lại
  của PDF v1.1), không chứa chữ giao diện. `fixtures/large-exam.digest` chưa dùng ở Kotlin: đo đề chuẩn ở A4.

- 2026-10-22, A1, review độc lập PR #2 (REQUEST CHANGES, một lỗi chặn), đã sửa trong cùng PR:
  - **B1 (chặn)**: `ZipFile` mặc định đọc tên entry bằng UTF-8 nên gói có entry lạ mang tên không phải UTF-8 (zip tạo trên
    Windows) bị từ chối cả gói, bản macOS bỏ qua entry đó. Sửa: tên không cờ UTF-8 đọc bằng CP437 như ZIPFoundation.
    Oracle nhị phân mới `fixtures/packages/` (gói do `pack_exam.py` đóng, gói có tên entry 0x82 0xFF) cho cả hai lõi.
  - Số cực lớn: Foundation từ chối khi phân tích `1e309`, số nguyên rất dài, `0e10000`, `0e-1000` nhưng nhận `-1e400` (đo
    ở re-review). Kotlin từ chối số mà Double ra vô cực và số mũ từ 4 chữ số: cùng kết luận nhận/từ chối trên mọi ca đã đo
    (fixture `number-*`); chỉ khác loại lỗi ở số không có trong đề thật (`-1e400`, số nguyên 167–308 chữ số).
    Foundation trên Linux lại nhận `0e10000`, `0e-1000`: hai ca này đánh dấu `macOSOnly`, test Swift bỏ qua trên Linux.
  - `fixtures/invalid-json` thêm 18 ca (số, UUID, kiểu sai, thiếu khoá, khoá trùng lồng nhau, escape của bộ quét, dấu phẩy
    thừa có khoảng trắng), thay ca inline ở test Swift và Kotlin. Phát hiện: `JSONDecoder` báo "số không vừa Int" với
    đường dẫn rỗng (`<gốc>`); oracle ghi đúng như vậy, Kotlin báo giống hệt.
  - Payload và phiên dở chặt như `JSONDecoder`: khoá UUID trùng khác hoa/thường, seed có dấu `+`, số hay Bool viết trong
    ngoặc kép đều bị từ chối (`StrictPayloadJson`).
  - `ExamSession.restore` kiểm nhất quán trạng thái, lý do tạm dừng, thời gian, cảnh báo, câu đã Kiểm tra đáp án; phiên dở
    lưu dấu vân tay câu, câu đã sửa thì không khôi phục (mobile.md Câu hỏi mở).
  - Lệch nhỏ đã sửa: Σ cuối từ (Swift `lowercased()` luôn ra σ); dòng xem trước tách như `Character.isNewline`.
  - Test thêm: bảng lệnh × trạng thái (rà soát chưa khoá, hết giờ, rà soát khoá, đã nộp, đang làm); chấm tất cả đúng/sai;
    nhãn `examfile` chỉ nhận `InvalidJson` khi là dấu phẩy thừa; test Swift khôi phục ý "lenient đọc được đề lồng đúng 32
    cấp".
  - Re-review (phiên agent mới): **APPROVE**. Đã làm thêm trong PR: tên entry đọc bằng ISO-8859-1 thay CP437 (có sẵn trên
    ART; cùng kết luận vì chỉ tên ASCII có nghĩa); khoá JSON trùng và tiêu đề phần trùng so sau chuẩn hoá NFC như `String`
    của Swift; mảng `issuedWarnings` của phiên dở kiểm kiểu; oracle thêm 8 ca (UUID sai dạng, Int64 lớn nhất, số mũ lớn,
    khoá trùng NFC/NFD); test dương "tạm dừng khi có sự kiện chờ". Lệch đã biết: tên entry **có** cờ UTF-8 mà byte hỏng
    (công cụ đặt cờ sai) thì ZIPFoundation bỏ entry, `ZipFile` từ chối cả gói. `fixtures/packages/pack-exam-py.exam` đóng
    từ `kien-thuc-chung`: sửa đề đó thì đóng lại gói này.
  - Để sau (không chặn): Android 14+ (ART, targetSdk ≥ 34) `ZipFile` từ chối entry tên chứa `..` hoặc bắt đầu bằng `/`
    (ZipPathValidator) trước khi bộ đọc kịp bỏ qua; A3a gọi `dalvik.system.ZipPathValidator.clearCallback()` lúc mở đề hoặc
    chép gói qua bộ đọc riêng, kèm một test emulator đọc `fixtures/packages`. Workflow Android chỉ chạy khi PR chạm
    `android/**` hay `fixtures/**`: đổi lõi Swift ở chỗ oracle chưa phủ không làm CI Kotlin đỏ, nên mọi đổi luật lõi đi
    qua oracle trước (ADR 0011). JSON mẫu payload phụ thuộc `fixtures/exams/kien-thuc-chung`: sửa fixture đó phải sinh lại
    JSON mẫu. A2 không thêm lần kiểm thứ ba "đề mẫu không có warning".

## Validation

A0:

- Focused proof: `./gradlew test` (`FixturesWiringTest`, `SampleAssetsTest`, ba test `ComposeHardcodedTextDetectorTest`),
  `./gradlew lint`, `:app:validateDebugScreenshotTest`, `check_android_rules.py` (tự kiểm âm/dương và đối chứng âm trên
  repo: thêm OkHttp vào danh mục thì đỏ).
- End-to-end: `:app:connectedDebugAndroidTest` trên AVD `examsuite` (Android 15 arm64), kiểm trợ năng bật.
- Kết quả trên 954852f (PR #1): check `android` của CI xanh (163 s: luật riêng, lint, `:core:test`,
  `:data:testDebugUnitTest`, `:lint-rules:test`, `validateDebugScreenshotTest`); `local/verify-android` xanh (1 test
  Compose, emulator Android 15); `scripts/check.sh` macOS đạt. SHA cuối và status ghi ở mô tả PR.
- Repository-required checks: check `android` của `.github/workflows/android.yml` trên SHA cuối; `local/verify-android`
  (`check_android.sh --ui`, PR chạm `android/app/**`); `local/verify` (`scripts/verify_local.sh`, PR chạm tài liệu và
  workflow của repo: UI test macOS bỏ qua theo bảng map).

A1 (PR #2, trên SHA cuối, ghi ở mô tả PR):

- `:core` 225 ca JUnit, 114 ca đọc oracle chung (fixtures/expected-verdicts.json kể cả issueCodes, 61 ca invalid-json, 2 gói
  nhị phân, 4 vector chọn câu, SplitMix64, dấu vân tay, khoảng trắng, khoá schema, 2 đề mẫu); lõi Swift đọc cùng oracle
  (`swift test` ExamKit 201 + 129 ca).
- Review độc lập (phiên agent mới): REQUEST CHANGES, đã sửa (Decisions); re-review trên 8287c69: APPROVE.
- Bằng chứng merge: check `android` (CI) và `local/verify` trên SHA cuối.

## Result

Ghi khi đóng plan sau cổng GA3.
