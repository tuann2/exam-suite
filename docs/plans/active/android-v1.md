# Execution Plan: Exam Suite cho Android, v1 (bản Học viên)

Date: 2026-10-22

## Status

Active. A0–A3a đã merge (`main` 3612c41), cổng GA2 đạt; **A4** trên nhánh `feature/android-a4` rẽ từ 3612c41, chờ cổng
GA3. Lộ trình ở [plan-android-v1.md](../../product/plan-android-v1.md) Phần 3. v1.1 lập plan riêng (`android-v1.1.md`) ở
bước B1.

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
- [x] A2 `:data` (PR này, rủi ro cao): kho Room v1 (`exam_entry`, `attempt`, `draft_session`; schema `data/schemas/.../1.json`),
      `LibraryStore` (kho hỏng đổi tên), `ExamLibrary` (nhập nguyên tử, Cập nhật đề, xoá có Hoàn tác, dọn lúc mở app, đề mẫu,
      lần thi, phiên dở), `LibraryQuery` (tìm không dấu, sắp xếp), `LibrarySettings` (DataStore); 29 ca Robolectric. Cùng
      PR: `verify_local.sh` chọn mức kiểm theo file đổi (Decisions).
- [x] A3b Giao diện làm bài (PR này): `AttemptModel` (Kotlin thuần) bọc `ExamSession`, `AttemptPresentation` (đồng hồ ba
      mức, nhãn A–Z theo vị trí, bảng câu hỏi theo phần, Rà soát, Kết quả: so với lần trước, phần yếu nhất), tạm dừng và
      lưu phiên dở khi xuống nền, lưu lần thi khi nộp (`AttemptStore`, nối `ExamLibrary` thật); màn Làm bài (ảnh phóng to,
      bảng câu hỏi bottom sheet, dải cảnh báo 5/1 phút, hết giờ sang Rà soát khoá, che khi tạm dừng, Kiểm tra đáp án), Rà
      soát & nộp, Kết quả, Xem lại bài (bộ lọc, `ReviewItems`), Làm lại, Luyện lại câu sai (trả `NextAttempt` cho A3a);
      chuỗi vi/en; 37 ca JVM; 11 ảnh chụp (4 màn × sáng/tối, câu dài, Kết quả, Xem lại ở cỡ chữ 150%).
- [x] A3a Thư viện và nối luồng (PR xếp chồng trên A3b): `AppModel` (mở kho, dọn và tạo đề mẫu lúc mở, khôi phục phiên dở,
      nhận `.exam` từ app khác, Cập nhật đề, mỗi lúc một phiên, Lịch sử thi), Thư viện danh sách (tìm, sắp xếp, dải chào
      mừng, Xoá + Hoàn tác), Trước khi thi (bảng kéo lên; `PreExamForm` thuần, cùng thứ tự lý do khoá với macOS), Kết quả
      lần thi cũ (`PastAttemptModel`); 52 ca JVM; 3 luồng Compose + 2 test nền tảng trên emulator; ảnh Thư viện sáng/tối.
- [x] Cổng GA2 (2026-10-22): Nt0 cài APK debug của `main` 3612c41 lên Samsung Galaxy S24+, nhận đề qua WhatsApp, làm
      trọn đề: chức năng đạt, không báo lỗi (Validation).
- [ ] A4 Hoàn thiện và beta (PR này): test tương phản bảng màu trên nền Material 3 (8 ca JVM); nhật ký đo `Timing` của bản
      debug, đo đề chuẩn, sửa ba mục vượt ngân sách (Nộp bài, xuống nền, lưu lần thi chặn luồng giao diện; chạm `:core`,
      `:data`: review độc lập); ký bản release bằng keystore ngoài repo, `versionName` 0.1.0; tên "Exam Suite Debug" cho
      bản debug; `android/CHANGELOG.md`, `android/THIRD_PARTY_NOTICES.md`, `docs/install-android.md`,
      `docs/process/android-release.md`, `docs/notes/android-measurements.md`.
- [ ] Cổng GA3: Nt0 tạo keystore, đóng APK release, cài và dùng thử trên điện thoại (kể cả rà nhanh TalkBack trên Thư
      viện, Trước khi thi, Làm bài, Kết quả); đo đề chuẩn trên máy thật.

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

- 2026-10-22, Nt0 (sau khi merge PR #2): `local/verify` không chạy lại toàn bộ app macOS cho PR Android. `verify_local.sh`
  chọn mức theo file đổi (`scripts/verify_scope.py`): none (chỉ `android/`, tài liệu: chỉ kiểm danh tính git), core (oracle
  và test lõi Swift mà test giao diện không đọc: `check.sh --core` + Linux, khoảng 1,5 phút), full (mọi thứ khác, file lạ,
  cổng). Thử trên worktree tạm: commit chỉ tài liệu ra none (0,2 giây), commit chỉ `fixtures/README.md` ra core (85 giây).
  Với bảng này A0 là none và A1 là core (trước đây cả hai chạy đủ bộ 6–9 phút). Làm trong PR của A2 (không mở PR riêng).

- 2026-10-22, Nt0: khôi phục phiên dở đang hết giờ hay rà soát khoá thì giữ nguyên trạng thái (mobile.md, bảng Khác macOS).
- 2026-10-22, A2, phiên bản: Room 2.8.5 (KSP 2.3.12, plugin `androidx.room` để xuất schema), sqlite-framework 2.6.2 (cùng
  Room kéo theo, khai báo tường minh), DataStore Preferences 1.2.1 (1.3.0 mới phát hành, chưa đủ hai tuần), coroutines
  1.11.0. Đều thuộc danh sách ADR 0012.
- 2026-10-22, A2, JDK: **giữ JDK 17**, Robolectric chạy ở API 34 (kết luận spike A0). Tầng dữ liệu không dùng hành vi của
  API 35+; nâng JDK 21 cả máy lẫn CI không đáng ở bước này.
- 2026-10-22, A2, file đề: `files/exams/<examId>.exam`; nhập qua `exams/.incoming/<ngẫu nhiên>.part` có trần (1 GiB + 64
  MiB: gói lớn hơn không thể đọc nghiêm được), đọc nghiêm, rồi đổi tên nguyên tử; ghi kho sau đổi tên. `recoverOnStart`
  dọn file tạm, file không có mục, mục không còn file (bị can thiệp ngoài app: bỏ mục, lịch sử giữ lại) và đề chờ Hoàn tác
  của lần trước. A3a gọi nó khi mở app.
- 2026-10-22, A2, quy tắc dữ liệu (theo library.md, mobile.md; chỗ hai tài liệu không nói là lựa chọn kỹ thuật):
  - Cùng id đề luôn trả `NeedsUpdateConfirmation`, kể cả cùng nội dung (mobile.md: luôn hỏi). Cập nhật đề giữ ngày thêm và
    lịch sử thi, bỏ cờ đề mẫu (file là của người dùng).
  - Xoá khỏi Thư viện: đánh dấu chờ Hoàn tác; `purgeRemoved` (A3a gọi khi hết thời gian Hoàn tác và lúc mở app) xoá file,
    mục và phiên dở của đề đó; lịch sử thi giữ lại. Nhập lại đề đang chờ Hoàn tác thì xoá hẳn mục cũ rồi thêm như mới.
  - Lưu lần thi xoá phiên dở của đề đó. Tên đề, mã đề lúc thi lưu ở lần thi (library.md: "tên đề lúc thi").
  - Đề mẫu: mỗi thư mục assets đóng thành gói rồi đọc nghiêm như file của người dùng; đề đã có (cùng id) thì bỏ qua. Cờ
    "đã tạo đề mẫu" ở `LibrarySettings`; A3a gọi `seedSamples` khi cờ chưa bật rồi bật cờ (xoá đề mẫu không tự tạo lại).
- 2026-10-22, A2, kho hỏng (library.md, Lưu trữ): Android mặc định **xoá** kho SQLite hỏng. `LibraryStore` đổi tên thành
  `library.db.broken-<thời điểm>` (cùng `-wal`, `-shm`) qua ba đường: đầu file không phải SQLite, truy vấn thử lỗi, và
  `onCorruption` của bộ mở kho (thay cách xoá mặc định). Test phủ đường đầu file.
- 2026-10-22, A2, schema: plugin Room ghi đè `1.json` mỗi lần build nên đổi bảng mà không tăng phiên bản không làm test
  mở kho đỏ. Test khoá thêm dấu vân tay schema v1 (`V1_IDENTITY_HASH`); đối chứng âm: thêm một cột thì Room viết lại
  `1.json` và test đỏ.
- 2026-10-22, A2, review độc lập PR #3 (REQUEST CHANGES, hai lỗi chặn), đã sửa trong cùng PR:
  - **C1**: `verify_scope.py` dùng `git diff` mặc định nhận đổi tên, nên chuyển đề mẫu hay file Swift vào `android/` bị xếp
    mức none. Sửa: `--no-renames` và `core.quotePath=false`; tự kiểm dựng repo git tạm chuyển đề mẫu vào `android/` (đối
    chứng âm: bỏ `--no-renames` thì đỏ; nội dung thử phải đủ dài, git không nhận file vài byte là đổi tên).
  - **C2**: kho hỏng thì kho mới rỗng và `recoverOnStart` xoá mọi bản sao đề. Sửa: file đề chưa có mục mà đọc nghiêm được thì
    nạp lại thành mục, chỉ xoá file không đọc được; `LibraryStore` chỉ cách ly khi SQLite báo kho hỏng hoặc Room không nhận
    schema (kho của bản app khác), lỗi tạm thời ném `LibraryStoreException` cho giao diện báo; đổi tên thất bại thì không tạo
    kho mới; kho hỏng phát hiện lúc chạy ghi `<tên>.recovered` để lần mở sau báo. Test: chuỗi kho hỏng rồi `recoverOnStart`
    giữ đề.
  - Không chặn, đã làm: Cập nhật đề ghi dấu `<examId>.updating`, `recoverOnStart` làm mới mục khi tắt giữa chừng; `Mutex`
    cho mọi thao tác ghi (đối chứng âm: bỏ khoá ở `import` thì test nhập đồng thời đỏ 3/3 lần); đề mẫu lỗi không dừng cả
    lượt; lần thi có chế độ lạ bị bỏ thay vì làm hỏng danh sách; mô tả status luôn mở đầu bằng tên mức; bỏ đoạn test lặp
    luật khôi phục của lõi. Còn lại: `.broken-*` chưa tự dọn (cần quyết định giữ bao lâu); `Collator` tiếng Việt chỉ test
    trên JVM, ICU của Android kiểm ở test emulator A3a.
- 2026-10-22, A2, re-review trên dced5b3 (phiên agent mới): **APPROVE**. Gợi ý không chặn đã làm: dấu `.recovered` chỉ xoá
  sau khi mở kho thành công và báo ngay ở lần mở phát hiện hỏng (N1); nhận đủ thông báo lệch schema của Room, test kho SQLite
  thiếu bảng của Room và đối chứng âm lỗi tạm thời (N2); `recoverOnStart` chỉ xoá file đề khi lõi báo gói hỏng (N2); dấu
  Cập nhật đề mà file chưa đổi (cùng SHA-256) thì không đổi gì (N3); xoá file thất bại thì giữ mục chờ xoá (N4). Còn lại:
  đề mẫu được nạp lại sau khi kho hỏng mất cờ đề mẫu (N5, ảnh hưởng Khôi phục đề mẫu ở v1.1); `.broken-*` chưa tự dọn (N6);
  `saveDraft` không nằm trong khoá ghi nên `loadDraft` ở A3a phải chịu được phiên dở của đề đã xoá.
- 2026-10-22, Nt0: PR #3 **không chạy `local/verify` mức full** dù sửa script kiểm; lần chạy full đầu tiên làm ở PR macOS kế
  tiếp (kiểm cả đường full mới của `verify_local.sh`). Bằng chứng của PR #3: check `android` của CI, danh tính git
  (`verify_local.sh --check-identity`), hai lượt review độc lập.
- 2026-10-22, A2, Robolectric: `AssetManager.list` của Robolectric trả đường dẫn đệ quy, của Android trả tên con trực
  tiếp; `AssetSampleSource` lấy đoạn đầu rồi thử mở `exam.json` để đúng ở cả hai.

- 2026-10-22, Nt0 (trước A3b, A3a): cỡ chữ hệ thống tới **150%** (như macOS); làm đề khác khi có bài dở: hỏi **Tiếp tục
  đề A** / **Bỏ bài và làm đề B** / **Huỷ**; Cập nhật đề khi đề có bài dở: hộp Cập nhật thêm dòng báo và luôn bỏ phiên dở.
  Ghi vào mobile.md (bảng Khác macOS).
- 2026-10-22, A3b, phụ thuộc: `lifecycle-viewmodel-compose` và `lifecycle-runtime-compose` 2.9.4 (cùng phiên bản Compose BOM
  đã kéo theo; thuộc `androidx.*` của ADR 0012); test JVM của `:app` dùng JUnit 4 và `kotlinx-coroutines-test` (đã có
  trong danh mục).
- 2026-10-22, A3b, kiến trúc: `AttemptModel` là lớp Kotlin thuần (không `ViewModel`, không Android) để test JVM;
  `AttemptViewModel` chỉ giữ nó qua xoay màn hình. Màn hình nhận `AttemptUiState` + `AttemptActions`, nên ảnh chụp dựng
  trạng thái bằng chính model trên phiên thật. Trình bày không chứa chữ giao diện (composable tra strings.xml); câu đọc của
  ô bảng câu hỏi là danh sách phần (`CellPart`) để test JVM được.
- 2026-10-22, A3b, xuống nền: `ON_STOP` mà không phải xoay màn hình (`isChangingConfigurations`) thì tạm dừng (lý do
  `BACKGROUND`, chỉ khi đang làm hay rà soát chưa khoá) và lưu phiên dở; tạm dừng do người dùng giữ lý do của người dùng.
  Phiên dở **chụp ngay lúc xuống nền** rồi mới ghi: test bắt được lỗi khi chụp lúc lệnh ghi chạy (người dùng nộp ngay sau
  đó thì `snapshot()` ném vì phiên đã nộp). Thêm `ExamLibrary.saveDraft(snapshot)` (bản nhận phiên gọi bản này).
- 2026-10-22, A3b, ghi dữ liệu: mọi lệnh ghi (phiên dở, xoá phiên dở, lưu lần thi) chạy lần lượt theo thứ tự gọi (một
  `Mutex`) trên phạm vi của app (`AppScope`), không bị huỷ khi rời màn hình: lần thi vừa nộp vẫn được lưu khi người dùng
  bấm Về thư viện ngay; phiên dở ghi trước không đè được việc xoá sau. Lần trước (so với lần trước) đọc trước khi lưu lần
  này. Lưu lỗi thì Kết quả báo "Không lưu được lần thi vào Lịch sử thi." và vẫn xem được.
- 2026-10-22, A3b, hành vi chọn: chạm lại lựa chọn đang chọn của câu một đáp án thì bỏ chọn (như phím A–Z của bản macOS,
  exam-taking.md); Kiểm tra đáp án là nút cuối nội dung câu (thanh dưới của điện thoại chỉ đủ chỗ cho Câu trước, Câu sau,
  Đánh dấu, Bảng câu hỏi, Rà soát & nộp). Tạm dừng che cả câu lẫn bảng câu hỏi (bảng là bottom sheet, không hiện khi tạm
  dừng). Luyện lại câu sai đặt ở danh sách Xem lại bài (exam-taking.md đặt nó ở Xem lại); Kết quả có Xem lại bài, Xem câu
  sai, Làm lại, Về thư viện.
- 2026-10-22, A3b, định dạng: số, phần trăm, ngày giờ theo ngôn ngữ giao diện (`interface_language` của strings.xml: vi/en),
  không theo vùng của máy; ngày giờ theo mẫu `yMdjm` của ngôn ngữ ("14:43 22/10/2026"); thang 1000 số trơn. Múi giờ tiêm
  được (`LocalTimeZone`) để ảnh chụp không phụ thuộc máy ghi ảnh.
- 2026-10-22, A3b, biểu tượng: vector theo Material Icons (Apache-2.0) trong `res/drawable`, không thêm thư viện biểu
  tượng; A4 ghi vào THIRD_PARTY_NOTICES cùng giấy phép thư viện. Màu Đúng/Sai/cảnh báo cùng giá trị `LibraryPalette` của
  macOS (`ExamPalette`); test tương phản ở A4.
- 2026-10-22, A3b, review độc lập PR #4 (REQUEST CHANGES, năm lỗi chặn), đã sửa trong cùng PR:
  - **B1**: check `android` đỏ: ảnh "ảnh lớn" lệch vài điểm ảnh giữa Mac và runner Linux (co ảnh 1600px khi vẽ). Sửa: ảnh thử
    dựng đúng bằng cỡ hiện (861px), chỉ hình chữ nhật không khử răng cưa, nên không co. Ảnh co trên màn thật không chụp.
  - **B2**: Bỏ bài rồi `ON_STOP` (rời màn hình, đóng Activity) lưu lại phiên dở vừa xoá. Sửa: model đã Bỏ bài bỏ qua mọi lệnh
    kể cả xuống nền; test chiều Bỏ bài → xuống nền.
  - **B3**: lỗi ghi phiên dở (đầy bộ nhớ, kho hỏng) làm app dừng. Sửa: lệnh ghi bắt lỗi (trừ huỷ); test với nơi lưu ném lỗi.
  - **B4**: thêm ảnh Xem lại bài ở cỡ chữ 150% (mobile.md đòi cả ba màn).
  - **B5**: luật "lần trước cùng đề, cùng chế độ" thành hàm thuần `AttemptPresentation.previousAttempt` (có `beforeMillis` cho
    Lịch sử thi ở A3a), có test.
  - Không chặn, đã làm: bỏ test kể lại luật lõi (chọn nhiều đáp án, danh sách câu Luyện lại câu sai, đồng hồ sau khôi phục,
    số đếm của bộ lọc) (N1); khoá ghi chung cả app `StoreWrites` (N2); KDoc `ExamLibrary.saveDraft` và rủi ro của
    plan-android-v1.md Phần 5 ghi đúng là lưu khi xuống nền, không lưu mỗi lần đổi đáp án (N3); hai chỗ khác exam-taking.md
    (Kiểm tra đáp án ở cuối nội dung câu, bảng câu hỏi đóng khi tạm dừng) vào bảng Khác macOS của mobile.md (N4); bảng câu
    hỏi không tự mở lại sau Tiếp tục (N8). Để A3a/A4: việc nặng trên luồng chính với đề 2.000 câu (N5, đo ở A4), thông báo
    trình đọc màn hình bằng `liveRegion` thử trên emulator (N6), lưu lần thi lỗi thì phiên dở cũ còn (N7, A3a chốt), tương
    phản bảng màu trên nền Material 3 (N9, A4).
- 2026-10-22, A3b, chưa làm (A3a): nối điều hướng, tạo `AttemptViewModel` từ Trước khi thi hay phiên dở khôi phục,
  `NextAttempt` mở Trước khi thi, đồng hồ nhanh tiêm cho test Compose, chạy thử màn làm bài trên emulator (ba luồng của
  A3a). Màn làm bài chưa mở được từ app ở PR này.

- 2026-10-22, A3a, điều hướng: **không dùng Navigation Compose**: bốn màn (Thư viện, Lịch sử thi, làm bài, Kết quả cũ) là
  ngăn xếp trong `AppModel` (ViewModel của Activity duy nhất), bớt một thư viện và tránh `ON_STOP` của destination khi pop
  (review A3b, B2). Hệ điều hành dừng app thì mở lại ở Thư viện, rồi phiên dở tự mở lại (mobile.md).
- 2026-10-22, A3a, mỗi lúc một phiên (mobile.md, Nt0 chốt): mở app có phiên dở thì vào thẳng bài đó (Tạm dừng). Hộp hỏi
  ba nút hiện khi bắt đầu đề khác lúc có bài dở trong bộ nhớ hay đã lưu: mở `.exam` từ app khác khi đang làm bài hay lúc mở
  app có phiên dở, hoặc chọn Huỷ rồi chạm đề khác. Chạm đúng đề có bài dở thì mở lại bài đó. `launchMode="singleTask"` để
  "Mở bằng" từ app khác không tạo Activity thứ hai (hai phiên).
- 2026-10-22, A3a, Thêm đề: hộp chọn file của hệ điều hành lọc `*/*` (spike A0), **một file mỗi lần** (hộp hỏi Cập nhật đề
  chỉ hiện được một); nội dung do bộ đọc nghiêm quyết, không xét đuôi tên (Drive, Zalo có thể đổi tên). Mở từ app khác
  (VIEW, SEND) thì thêm rồi mở ngay Trước khi thi của đề đó.
- 2026-10-22, A3a, câu báo lỗi đề: theo mã của `ExamFileError`/`ImportProblem` (strings.xml); đề có lỗi kiểm đề chỉ báo số
  lỗi kèm "nhờ người soạn đề sửa bằng bản Admin" (bản Học viên trên điện thoại không có màn sửa đề; chi tiết từng mã như
  `ErrorMessages` của macOS để sau nếu Nt0 cần).
- 2026-10-22, A3a, gợi ý của re-review A3b: lưu lần thi lỗi thì xoá luôn phiên dở chụp trước khi nộp (như macOS: kết quả chỉ
  còn tới khi rời màn Kết quả; không mở lại thành bài chưa nộp) (N7); lỗi ghi ghi nhật ký `Log.w` (model nhận hàm ghi log,
  test để trống). Khoá ghi chung bị treo vẫn là rủi ro đã biết.
- 2026-10-22, A3a, test trên emulator: đồng hồ nhanh tiêm qua `AppServices.clock` trong cùng tiến trình; luồng 2 mở bằng
  Intent VIEW tới file trong bộ nhớ của app (gói `fixtures/packages/pack-exam-py.exam` làm assets của androidTest). Kiểm trợ
  năng bắt được tay nắm mặc định của bảng kéo lên (32dp, rồi bị cắt khi bảng cao hết màn): Trước khi thi bỏ tay nắm (có Huỷ),
  bảng câu hỏi dùng tay nắm rộng 48dp. AVD `examsuite` ở en-US nên ba luồng đi qua giao diện tiếng Anh; tiếng Việt có ảnh
  chụp và lint. Test cũ `LaunchTest` bỏ (luồng 1 thay).
- 2026-10-22, A3a, phát hiện: chuỗi tài nguyên Android **cắt khoảng trắng đầu/cuối**: dấu ngăn " · " và ", " (câu đọc ô bảng
  câu hỏi của A3b) mất dấu cách; viết `\u0020`.
- 2026-10-22, A3a, đã làm các việc để lại từ A1/A2: `ZipPathValidator.clearCallback()` ở `Application` (Android 14+), test
  đọc `fixtures/packages` trên ART; `Collator` tiếng Việt trên ICU của Android (`PlatformTest`); `loadDraft` của đề đã xoá
  thì bỏ phiên dở. Còn lại: `.broken-*` chưa tự dọn (A2 N6).

- 2026-10-22, Nt0 (A4): phiên bản đầu `versionName` **0.1.0** (`versionCode` 1), tag `android-v0.1.0`.
- 2026-10-22, A4, tương phản (plan Phần 1: phương án 8 của library.md): bảng màu riêng `ExamPalette` (cùng giá trị
  `LibraryPalette` của macOS) đạt trên nền Material 3 thật của app, tính bằng chính `examColorScheme` của theme: chữ nhỏ
  ≥ 4,5:1 trên nền màn, bảng kéo lên, thanh trên khi cuộn, thanh dưới (tonal elevation 3dp), trên hàng lựa chọn nền nhạt;
  `onSurface` trên mọi nền nhạt; biểu tượng và thanh điểm ≥ 3:1; đối chứng âm: màu của giao diện tối trên nền sáng (và
  ngược lại) không đạt. Màu mặc định của Material 3 không thuộc quy tắc (như màu hệ thống của macOS). Vạch ngưỡng đậu trên
  thanh điểm không cần 3:1: dòng "Điểm đậu" ngay dưới ghi bằng chữ.
- 2026-10-22, A4, hiệu năng (đo trên emulator, `docs/notes/android-measurements.md`): dấu vân tay 2.000 câu (~0,2–0,4 s)
  tính tới ba lần trên luồng giao diện khi nộp và một lần khi xuống nền. Sửa: `ExamSession.fingerprints` (lazy, an toàn
  giữa luồng) dùng chung cho phiên dở, payload, khôi phục; `ReviewItems` nhận dấu vân tay đã tính (mặc định tự tính như
  trước); hex tự dựng thay `String.format`; `ExamLibrary` mã hoá/giải mã lần thi và phiên dở trên `Dispatchers.Default`;
  app tính dấu vân tay trên nền ngay sau khi màn làm bài hiện, khôi phục phiên dở và dựng Kết quả lần thi cũ trên nền.
  Kết quả dấu vân tay không đổi (vector `fixtures/vectors/question-fingerprints.json`). Chạm `:core`, `:data`: review độc
  lập.
- 2026-10-22, A4, review độc lập PR #6 (phiên agent mới): **APPROVE**, không lỗi chặn. Đã làm trong PR:
  - N1: tính dấu vân tay trước khi hiện màn làm bài kéo dài khoảng giữa lúc đồng hồ chạy và lúc màn làm bài nhận được
    ON_STOP. Dời việc tính ra sau khi hiện (nền); đóng Trước khi thi trong lúc chờ đọc đề thì không bắt đầu; app đã xuống
    nền khi màn làm bài vừa tạo (Activity không ở giữa ON_START và ON_STOP, `MainActivity` báo `AppModel`) thì tạm dừng và
    lưu ngay. Hai khoảng này có từ A3a (chờ đọc đề), PR này đóng luôn.
  - N2: `ExamLibrary.saveAttempt` chỉ đọc phiên trên luồng gọi (dựng payload ở đó), chỉ mã hoá trên nền; KDoc của
    `ExamSession.fingerprints` ghi rõ chỉ thuộc tính này an toàn giữa luồng.
  - N3: tham số của `ReviewItems` đổi tên `fingerprintsOfExam`, KDoc cảnh báo đưa dấu vân tay của bản đề khác vào sẽ làm sai
    quy tắc câu đã sửa; test dùng dấu vân tay tính từ chính đề.
  - N4: cấu hình ký báo lỗi rõ khi `EXAMSUITE_ANDROID_SIGNING` trỏ tới file không có hay file thiếu khoá.
  - N5: `app.ready` tính từ lúc yêu cầu tạo tiến trình (Android 13+), một lần mỗi tiến trình.
  - N6, N7, N8, N9: sửa câu chữ của notes (cột ngân sách từng dòng, số của từng lượt), CHANGELOG, hướng dẫn cài ("Cập nhật
    đề" theo mã định danh của đề, không phải ô Mã đề), quy trình phát hành (`local/verify`, `mkdir -p dist`).
  - N10: Apache-2.0 đòi người nhận có giấy phép: APK gửi kèm `LICENSE.txt`, `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt` (như
    DMG của macOS, ADR 0001), hướng dẫn cài có mục Giấy phép.
  - N11: AGENTS.md thêm tài liệu Android mới và quy tắc agent không đọc keystore, file mật khẩu ký, không đóng APK release
    ký thật, không xoá dữ liệu bản debug trên điện thoại của Nt0; rà nhanh TalkBack bốn màn chính đưa vào cổng GA3 (nhãn
    thiếu trên các màn ba luồng Compose đi qua đã do `enableAccessibilityChecks()` kiểm).
  - N12: test tương phản thêm nền hộp thoại (`surfaceContainerHigh`, nút chữ teal).
- 2026-10-22, A4, cách đo: lượt đi qua đề chuẩn bằng test Compose **tạm, không commit** (một lần mở app nữa trái quy tắc 3
  của plan Phần 4, và cần file đề 60 MB), chạy bằng `am instrument` không qua Orchestrator; trên điện thoại cùng lượt đó
  hoặc làm tay theo mô tả ở notes. Nhật ký `ExamSuiteTiming` chỉ bản debug (cờ `FLAG_DEBUGGABLE`).
- 2026-10-22, A4, phát hành: keystore và mật khẩu chỉ ở máy Nt0 (`~/.config/exam-suite/android-signing.properties`, ngoài
  repo vì repo public), CI **không** đóng APK (đưa keystore lên GitHub Secrets trái "keystore Nt0 giữ"). Comment đầu
  `.github/workflows/android.yml` còn ghi "A4 thêm job đóng APK ký khi gắn tag": không sửa CI khi chưa được yêu cầu, ghi ở
  đây. **Chưa bật R8** ở 0.1.0: test Compose chỉ chạy trên bản debug, bản rút gọn chưa có test luồng; APK release 26,7 MB,
  khởi động lạnh 417 ms trên emulator. Bản debug tên "Exam Suite Debug" để không trùng biểu tượng và mục "Mở bằng" với bản
  phát hành trên cùng máy.
- 2026-10-22, A4, tài liệu: CHANGELOG và thông báo bên thứ ba của Android nằm trong `android/` (file ở gốc repo đổi mức kiểm
  của `local/verify` sang full; thông báo gốc dành cho bản macOS và `make_dmg.sh` kiểm). Thư viện trong APK đều Apache-2.0.
- Còn lại sau A4 (không chặn GA3): `.broken-*` chưa tự dọn (A2 N6, cần quyết định giữ bao lâu); thông báo `liveRegion` và
  rà TalkBack sâu ở B3.

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

A3b (PR này):

- `:app` 37 ca JVM (`AttemptPresentationTest` 16, `AttemptModelTest` 21; không kể lại luật của `ExamSession`, `Scorer`,
  `ReviewItems`); `:data` vẫn đạt; 11 ảnh chụp mới (`AttemptScreenshots`: câu dài 10 lựa chọn, ảnh lớn đã Kiểm tra đáp án,
  Kết quả ba phần, Xem lại đề `hideAnswers`; sáng/tối; ba màn ở `fontScale` 1,5), đã xem từng ảnh.
- `android/scripts/check_android.sh` đạt tại chỗ (luật riêng, lint gồm `ComposeHardcodedText`, `MissingTranslation`,
  `UnusedResources`, test, so ảnh).
- Bằng chứng merge: check `android` (CI), `local/verify-android` (PR chạm `android/app/**`), `local/verify` mức none (danh
  tính git); review độc lập vì chạm `ExamLibrary` (`android/data/**`).

A3a:

- `:app` 52 ca JVM (`PreExamFormTest` 10, `PastAttemptModelTest` 5, cùng 37 ca của A3b); `check_android.sh` đạt (lint gồm
  `ComposeHardcodedText`, `Recycle`, `LocalContextGetResourceValueCall`); ảnh Thư viện sáng/tối thay ảnh khung A0.
- Emulator (Android 15, en-US), kiểm trợ năng bật: `PracticeFlowTest` (luồng 1), `ExamIntentFlowTest` (luồng 2),
  `BackgroundFlowTest` (luồng 3), `PlatformTest` (2 ca).
- Bằng chứng merge: check `android` (CI), `local/verify-android`, `local/verify` mức none; PR thường (không chạm vùng rủi ro
  cao), người duyệt diff.

GA2 (2026-10-22): Nt0 cài APK debug của `main` 3612c41 lên **Samsung Galaxy S24+**, nhận `.exam` qua **WhatsApp**, mở
bằng app và làm trọn đề: chức năng đạt, không báo lỗi.

A4 (PR này):

- `:app` 60 ca JVM (thêm `PaletteContrastTest` 8); `:core` 227 ca (thêm 2: dấu vân tay của phiên tính một lần và phiên
  dở lưu đúng chúng; `ReviewItems` dùng dấu vân tay đưa vào); `:data` vẫn đạt; `check_android.sh` đạt (lint, so ảnh).
- Đề chuẩn trên emulator, bản debug (bảng ở notes): các mục đo được trong ngân sách, trừ `app.ready` (1.156 ms so với
  1.000 ms) chưa đại diện (lần mở đầu tạo đề mẫu, tiến trình do test khởi động; bản phát hành mở lạnh 417 ms), đo lại trên
  máy thật. Bản release ký bằng khoá thử, cài và mở được trên emulator (khoá thử và APK đã xoá).
- Bằng chứng merge: check `android` (CI), `local/verify-android`, `local/verify` mức none; review độc lập vì chạm `:core`
  (`QuestionFingerprint`, `ExamSession`, `ReviewItems`) và `ExamLibrary`.

## Result

Ghi khi đóng plan sau cổng GA3.
