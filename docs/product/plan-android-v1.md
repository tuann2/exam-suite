# Kế hoạch xây dựng Exam Suite cho Android (bản Học viên)

Soạn: 18/10/2026 · Trạng thái: **DRAFT, chờ Nt0 review và chốt mục "Quyết định cần Nt0 chốt trước A0"**; chưa
phải thẩm quyền sản phẩm cho tới khi được duyệt. Bản để bình luận: https://claude.ai/code/artifact/8096f6cb-97c3-411a-aa85-ce3e52f1e19d

## Tóm tắt

Xây app Android **chỉ cho học viên luyện tập**: Thư viện đề, Trước khi thi, Làm bài (Luyện tập/Thi), Rà soát & nộp,
Kết quả, Xem lại bài, Lịch sử thi, Xuất PDF kết quả. Không có Soạn đề và Import (đề vẫn soạn bằng bản Admin trên
macOS, phát file `.exam` cho học viên). Hợp đồng sản phẩm **dùng lại nguyên** các tài liệu `docs/product/*.md` hiện
có (exam-format, scoring, exam-session, exam-taking, library, export-print, accessibility-localization, large-exams);
chỉ viết thêm một tài liệu ngắn `docs/product/android.md` ghi những chỗ Android khác macOS.

| Hạng mục | Đề xuất |
| --- | --- |
| Công nghệ | Kotlin 2.x, Jetpack Compose + Material 3, Room, DataStore, kotlinx.serialization; minSdk 29 (Android 10), targetSdk mới nhất |
| Lõi | Viết lại ExamKit/ExamFile bằng **Kotlin thuần (module JVM, không Android)**, kiểm **cùng kết luận với bản Swift** qua các "oracle" đã có trong repo (schema, fixtures, `expected-verdicts.json`, vector SplitMix64, dấu vân tay, JSON mẫu lần thi, `large-exam.digest`) |
| Repo | Cùng repo, thư mục `android/` (dự án Gradle độc lập), dùng chung `schema/`, `fixtures/`, đề mẫu, `docs/product/`, harness |
| Quy mô | **8 PR code** (so với 52 PR của macOS, trong đó 16 PR chỉ tài liệu), 3 cổng; 2 cặp bước chạy song song |
| Kiểm thử | ~300 test, 5 lớp không chồng nhau (mục Kiểm thử); không có hạ tầng "chế độ cô lập" vì emulator sẵn cách ly |
| Phân phối | APK ký bằng keystore của Nt0, phát riêng; CI Linux (giá 1×) không chạy theo PR: chạy tay, gắn tag chỉ để phát hành (như workflow `CI` của macOS từ 2026-10-19) cho tới khi Nt0 đổi |

Agent thực hiện toàn bộ code; Nt0 chốt quyết định ở mục cuối, duyệt PR, test tay trên điện thoại ở cổng GA2 và GA3.

## Phần 1 · Rà soát cách làm bản macOS (căn cứ tối ưu)

Số liệu lấy từ repo tại `main` 290dcc8 (18/10/2026): `git log`, `gh pr list`, đếm `@Test`, `wc -l`.

### 1.1 Tốc độ và hình dạng công việc

| Số đo | Giá trị | Nhận xét |
| --- | --- | --- |
| Thời gian giai đoạn 0 → giữa giai đoạn 5 | 4 ngày (15–18/10) | Nút thắt không phải viết code mà là chuỗi review độc lập → `verify_local.sh --uitest` → Nt0 merge |
| PR đã merge | 52, trong đó **16 PR chỉ tài liệu/kế hoạch/CI** (31%) | #1, #8, #9, #12, #13, #17, #18, #19, #22, #27, #28, #29, #30, #36, #40, #47 |
| Commit merge chéo giữa các nhánh xếp chồng | **34** (ngoài 52 merge PR) | Giai đoạn 4–5 xếp chồng 3–4 tầng (#39 → #44 → #42 → #41 → #43…), mỗi lần merge gốc phải merge lại cả chuỗi; là nguyên nhân sự cố VS Code treo 17/10 |
| Dòng Swift: mã nguồn / test / script kiểm | 30.184 / 29.012 / 4.920 | Test ≈ 1:1 với mã; script kiểm = 16% mã nguồn (11 script, 5 script có "tự kiểm âm") |
| Số test | ≈ 1.050 (ExamKit 205, ExamFile 131, LibraryData 103, LibraryFeature 79, SessionFeature 146, ReportFeature 35, AuthoringData 44, AuthoringFeature 150, ExamImport 133, snapshot 18, XCUITest 15) | Phần Học viên (không tính Authoring*/ExamImport) ≈ 730 test |
| Quyết định ghi trong exec-plan theo giai đoạn | 9 · 5 · 13 · 23 · 26 · **43** | Tăng dần; giai đoạn 5 có ~31 lượt nhắc "review độc lập" |

### 1.2 Bước bị chia quá nhỏ

| Bằng chứng | Chi phí | Cách làm cho Android |
| --- | --- | --- |
| Giai đoạn 1 tách model / chấm điểm / chọn câu / kiểm đề thành 4 PR (#2 +562, #3 +514, #4 +667, #5 +1.003 dòng), đều vùng rủi ro cao | 4 lượt review độc lập cho ~2.700 dòng cùng một "lõi thuần" dùng chung fixture | **Một PR lõi** (A1) có một lượt review độc lập |
| Spike thành PR riêng chỉ để ghi kết luận (#30 `.vce`, #40 PDF/String Catalog) | 2 PR, 2 lượt duyệt, không có code | Kết luận spike ghi vào mục Decisions của exec-plan **trong PR code kế tiếp** |
| Đóng giai đoạn và lập kế hoạch giai đoạn sau tách 2–3 PR (#18/#19; #27/#28/#29 trong một ngày; #47) | 7 PR tài liệu | **Một exec-plan cho cả Android v1**; cập nhật Progress/Decisions ngay trong PR code; đóng plan ở PR cuối |
| PR vá nhỏ tách riêng: #20 đề mẫu +428, #22 "chốt phương án" +15 dòng, #9 CI timeout +6 dòng | Mỗi PR một vòng duyệt | Đi kèm PR code gần nhất cùng vùng |
| Tiếng Anh để tới giai đoạn 5 rồi phải làm 3 PR xếp chồng (#50 +2.990, #51 +7.778, #52 +16.900 dòng, chạm 54–156 file mỗi PR) | 3 lần `verify --uitest`, 3 review, sửa lại gần như mọi view | **Song ngữ từ PR đầu**: Android chỉ có một cơ chế chuỗi (`strings.xml`), không có vấn đề "quên bundle" |

### 1.3 Test trùng lặp

| Hành vi | Số lớp đang kiểm cùng một thứ trên macOS | Vì sao có | Android chỉ cần |
| --- | --- | --- | --- |
| Chữ giao diện có trong catalog, đủ `en` | **8**: `LocalizationTests` ở 4 module, `CatalogLanguagesTests`, `check_localization.py` (6 luật, `--freshness`, `--built-apps`, `--require-en`), `-exportLocalizations` trong `verify_local.sh`, `EnglishResultsReportTests`, 3 snapshot tiếng Anh, `EnglishInterfaceUITests` | SwiftPM + String Catalog không bắt được chuỗi quên `bundle:`; phải tự viết máy quét và test đối chứng ở mọi tầng | **1 lớp**: Android Lint (`HardcodedText`, `MissingTranslation`, `ExtraTranslation`) chạy trong `gradlew lint`; cộng 1 test đọc vài chuỗi `en` qua `Resources` |
| Kiểm đề cùng kết luận với script | `validate_exam.py` + `check_validator_parity.py` + `ExamValidatorParityTests` + `ExamFileVerdictTests` + `ExamValidatorTests` (33) + `ExamPackageValidationTests` (9) + `ExamValidatorArgumentTests` | Oracle đa nền tảng là đúng; nhưng 3 suite Swift kể lại cùng tình huống của `fixtures/invalid` | **1 test tham số hoá** đọc `fixtures/expected-verdicts.json` (16 fixture sai + 3 đúng); tình huống ngoài fixture mới viết test riêng |
| Hiệu năng đề lớn | 9 file test `Timing`/`Performance` chạy ở **mọi PR** trong `swift test` Debug, `LargeExamSupport` 731 dòng, `measure_large.sh`, `gen_large_exam.py --check`, `StandardExamTests`, `GeneratedPackageTests` | Ngân sách đo ở Debug chập chờn theo tải máy; đã phải chốt "so lần nhanh nhất của N lần" để bớt chập chờn | Module `:benchmark` chạy **tay/nightly**, không chặn merge; đọc file `.exam` do `gen_large_exam.py` sinh (đã có, cùng đề chuẩn) |
| PDF | 10 file, ~100 test cho hai luồng gần giống nhau (`ResultsReportFlow` và `ExamReportFlow`; review #49 đã ghi "máy trạng thái trùng, cần gộp") + 2 UI test + 2 test đo | Hai luồng viết ở hai thời điểm | Một luồng PDF kết quả; test model khối (ẩn/hiện) ~15 test; PDF chỉ smoke (số trang, mở được) |
| Cùng một luồng làm bài | 3 lớp: model (`SessionFeatureTests` 146) + snapshot (18) + XCUITest (15), và mỗi PR giao diện phải chạy lại `verify_local.sh --uitest` trên Mac của Nt0 (máy không được đụng tới) | Hợp lý về nguyên tắc; đắt vì XCUITest cần quyền Accessibility, so kho thật trước–sau, kiểm Autosave, báo cáo crash, chạy lại; mọi PR chạm giao diện chạy đủ 16 test của cả hai bản, 7/10 test Học viên diễn lại cùng đoạn mở đầu ([notes/g5-ui-test-trung-lap.md](../notes/g5-ui-test-trung-lap.md)) | Model test (JVM, nhanh) + **5 test Compose** (3 luồng của overview.md, mở file từ Intent, xuất PDF) + screenshot test Compose Preview sáng/tối; emulator chạy headless, agent tự chạy được |
| Cách ly dữ liệu thật khi test | `AppLaunchStorage` (15 test, 464 dòng), `UITestSupport` 327 dòng, `check_release_strings.sh`, so cây Application Support/defaults/Autosave, kiểm bundle ID `.uitest` | Bản Debug macOS dùng chung kho với bản cài; sự cố 15/10 agent ghi lần thi giả vào kho thật | **Không cần**: emulator có dữ liệu riêng, Test Orchestrator `clearPackageData`; bản debug có `applicationIdSuffix ".debug"` nên không bao giờ chạm dữ liệu bản cài trên máy thật |
| Ranh giới hai bản app | `check_boundaries.py` (8 luật) + `check_bundle_boundary.sh` (`nm` hai binary) + kiểm `Package.resolved`/project.yml | Hai app từ một codebase, SwiftPM không chặn phụ thuộc gián tiếp | Chỉ một app; ranh giới `:core` không import Android do **đồ thị Gradle** (module JVM không có Android SDK) chặn lúc biên dịch |

Kết luận rút ra: phần lớn "chi phí kiểm" của bản macOS là chi phí **bù cho công cụ** (String Catalog trong SwiftPM,
Debug dùng chung kho, XCUITest cần quyền máy), không phải chi phí của sản phẩm. Trên Android, Gradle, Lint, emulator và
build variant đảm nhận các việc đó sẵn, nên không chép hạ tầng kiểm sang.

### 1.4 Song song: đã làm và nên làm

- Đã làm: mỗi giai đoạn có 2–3 bước đầu chạy song song (G2: data + đề mẫu; G4: AuthoringData + ExamImport + spike;
  G5: spike + đo + snapshot). Phần lớn lợi ích bị ăn mất bởi xếp chồng nhánh (34 merge chéo) và việc chạy nhiều build
  cùng lúc trên một Mac (VS Code treo).
- Cho Android: chỉ song song **trên hai module rời nhau, cùng rẽ từ `main` sau khi bước phụ thuộc đã merge**, không
  xếp chồng quá một tầng; tối đa 2 luồng; mỗi lúc một việc nặng (build/emulator) trên Mac của Nt0, luồng thứ hai chạy
  trên máy khác hoặc agent cloud (Linux build được mọi thứ trừ emulator).

## Phần 2 · Phạm vi và hợp đồng sản phẩm

### Trong v1

Theo [overview.md](overview.md) luồng 1–3 và các tài liệu đã chốt, bỏ phần bàn phím/menu macOS:

- Thư viện ([library.md](library.md)): lưới/danh sách, tìm (không dấu), lọc, sắp xếp, Thông tin, Xoá khỏi thư viện
  có Hoàn tác, đề mẫu lần đầu mở (2 đề hiện có, chỉ tiếng Việt), Lịch sử thi.
- Thêm đề: nút Thêm đề (hộp chọn file hệ thống), **mở `.exam` từ app khác** (Files, Drive, Zalo… qua Intent
  VIEW/SEND).
- Trước khi thi, Làm bài, Rà soát & nộp, Kết quả, Xem lại bài, Làm lại, Luyện lại câu sai, mở lần thi cũ
  ([exam-taking.md](exam-taking.md), [exam-session.md](exam-session.md), [scoring.md](scoring.md)): giữ nguyên quy tắc,
  kể cả `hideAnswers`, câu đã sửa sau lần thi, so với lần trước, phần yếu nhất.
- Xuất PDF kết quả và chia sẻ/in ([export-print.md](export-print.md) phần Học viên): cùng nội dung và quy tắc ẩn/hiện;
  mở bằng hộp chia sẻ của Android (lưu vào Downloads, gửi qua app khác, In qua `PrintManager`).
- Tiếng Việt (nguồn) và tiếng Anh từ PR đầu, thuật ngữ theo bảng đã duyệt ở
  [accessibility-localization.md](accessibility-localization.md); số/phần trăm/ngày giờ theo locale của ngôn ngữ giao
  diện; thang 1000 chữ số trơn.
- TalkBack: mọi điều khiển có nhãn; trạng thái luôn biểu tượng + chữ; theme sáng/tối theo hệ thống; tương phản theo
  phương án 8 của library.md.
- Đề 2.000 câu có ảnh mở và cuộn mượt (ngân sách của [large-exams.md](large-exams.md) áp dụng, đo trên máy thật ở
  bước A4b).

### Ngoài v1

Soạn đề, import, PDF đề; đồng bộ lịch sử giữa máy; Google Play công khai; iOS (cân nhắc sau: phần SwiftUI của macOS
dùng lại được nhiều hơn).

### Khác macOS (viết vào `docs/product/android.md`, Nt0 chốt ở Q6, Q7)

| Chủ đề | macOS | Android (đề xuất) | Lý do |
| --- | --- | --- | --- |
| File đề trong Thư viện | Tham chiếu tại chỗ bằng bookmark; trạng thái Không tìm thấy file, Tìm file…, Làm mới khi file đổi | **Sao chép vào bộ nhớ riêng của app** (`filesDir/exams/<id>.exam`) khi thêm; không có trạng thái mất file; mở lại file cùng id → hỏi **Cập nhật đề** / Huỷ | Android không có bookmark bền; quyền URI của hộp chọn file mất khi file đổi chỗ hay ổ gỡ. Bỏ được cả nhóm Làm mới/Tìm lại (≈ 1/3 LibraryData) |
| App xuống nền khi đang làm bài | Không tự tạm dừng (phương án 11); đóng cửa sổ thì hỏi rồi bỏ bài, không lưu phiên dở (phương án 2) | **Tự tạm dừng khi app xuống nền** (`onStop`) và **lưu phiên dở** để mở lại đúng chỗ ở trạng thái Tạm dừng; nút Back ở màn làm bài hỏi "Bỏ bài?" như macOS | Android có thể giết tiến trình bất kỳ lúc nào khi ở nền; học viên nhận cuộc gọi, khoá màn hình là chuyện thường |
| Đồng hồ | `SuspendingClock` (không chạy khi máy ngủ) | `SystemClock.uptimeMillis()` (không chạy khi deep sleep) + tạm dừng khi xuống nền | Cùng ngữ nghĩa "thời gian ngủ không bị trừ" |
| Bảng câu hỏi | Inspector bên phải | Bottom sheet / ngăn kéo trên điện thoại; cột bên ở máy tính bảng ngang | Màn nhỏ |
| Phím tắt | Bảng phím đầy đủ | Không bắt buộc; hỗ trợ bàn phím ngoài nếu Compose có sẵn (A–Z, ←/→) | Không có bàn phím |
| Xuất PDF | Hộp Lưu + hộp In | Hộp chia sẻ hệ thống (lưu Downloads/gửi), In qua `PrintManager`; không có hộp chọn "mức xem lại" riêng nếu Nt0 đồng ý giữ 3 lựa chọn như macOS (giữ) | Quy ước Android |
| Ngôn ngữ | Theo macOS, không có ô chọn trong app | Theo hệ thống + ngôn ngữ riêng cho app (Android 13 trở lên, Settings › App languages); không có ô chọn trong app | Cùng phương án 1 |
| Tên app | Exam Suite | Exam Suite (gói `vn.io.nt0.examsuite.android`) | — |

## Phần 3 · Kiến trúc

```text
android/
├── settings.gradle.kts · build.gradle.kts · gradle/libs.versions.toml · gradlew
├── core/        Kotlin JVM thuần (không Android SDK): model, StrictJson, ExamValidator, Scorer, ExamComposer
│                (SplitMix64), ExamSession (+SessionClock), ExamPackageReader (java.util.zip, giới hạn),
│                AttemptRecord (payloadVersion 1, cùng khoá JSON với macOS), QuestionFingerprint, Markdown cơ bản
├── data/        Android library: Room (LibraryEntry, Attempt; schema v1 export), DataStore (cài đặt), ExamStore
│                (chép/xoá file đề), SampleExams (assets trỏ thẳng vào Packages/…/Resources/Samples), DraftSession
├── app/         Compose: ui/library, ui/preexam, ui/attempt, ui/results, ui/review, ui/history, ui/report;
│                ViewModel thuần Kotlin (chỉ :core + coroutines) để test JVM; nhận Intent .exam
├── benchmark/   (tuỳ chọn, chạy tay) đo đề chuẩn theo large-exams.md
└── scripts/check_android.sh   lint + test (+ --ui: connectedCheck trên emulator) → status local/verify-android
```

- `:core` test bằng JUnit trên Linux/macOS, không cần emulator: đây là phần agent cloud làm trọn được (như ADR 0008).
- Oracle dùng chung với bản Swift, đọc qua đường dẫn tương đối (`sourceSets.test.resources.srcDir("../../fixtures")`),
  **không chép**: `schema/exam-v1.schema.json`, `fixtures/exams/*`, `fixtures/invalid/*`, `fixtures/expected-verdicts.json`
  (kể cả khoá `whiteSpace` liệt kê 25 code point), `fixtures/large-exam.digest`. Vector cố định hiện nằm trong test
  Swift (SplitMix64 seed 0, `QuestionFingerprintTests`, JSON mẫu của `AttemptSamples`) → A1 chuyển chúng thành file
  `fixtures/vectors/*.json` dùng chung và sửa test Swift đọc từ đó (thay đổi nhỏ, không đổi giá trị).
- Thư viện: **nền tảng** (AndroidX/Jetpack, kotlinx.serialization, kotlinx.coroutines, Material 3) dùng không cần ADR
  từng cái; **test-only** Robolectric (MIT) cho `:data`, Compose UI Test và Compose Preview Screenshot Testing (AndroidX);
  **không có** thư viện bên thứ ba khác ở v1. Zip `java.util.zip`, SHA-256 `MessageDigest`, NFC `java.text.Normalizer`,
  PDF `android.graphics.pdf.PdfDocument`, Markdown cơ bản tự viết (~150 dòng, đậm/nghiêng/code). Thêm gì khác phải có
  ADR (như ADR 0006).

### Bẫy đã biết khi viết lại lõi bằng Kotlin (ghi để agent kiểm ngay trong A1)

| Quy tắc (exam-format.md) | Bẫy Kotlin/JVM | Cách làm |
| --- | --- | --- |
| Độ dài đếm theo code point | `String.length` là đơn vị UTF-16 | `codePointCount(0, length)` |
| Khoảng trắng = 25 code point `White_Space` | `Character.isWhitespace` khác danh sách | Dùng đúng danh sách từ khoá `whiteSpace` của `expected-verdicts.json` |
| Khoá JSON trùng, `null`, dấu phẩy thừa, `NaN`, surrogate lẻ, BOM, sâu ≤ 32 → từ chối (đọc nghiêm) | kotlinx.serialization lấy khoá cuối khi trùng, không giới hạn độ sâu; `String(bytes, UTF_8)` thay byte hỏng bằng U+FFFD | Một lượt `StrictJson` (tokenizer ~200 dòng) chạy trước khi giải mã; giải mã UTF-8 bằng `CharsetDecoder` chế độ REPORT; `fixtures/invalid` là đối chứng âm |
| Trường lạ: từ chối, nêu tên và vị trí | `ignoreUnknownKeys = false` (mặc định) báo tên khoá nhưng vị trí khó lấy | Lấy đường dẫn từ `StrictJson` |
| Mẫu `code`, `image`, id khớp tuyệt đối | `Regex.matches` đã là khớp cả chuỗi | Không dùng `containsMatchIn` |
| So id không phân biệt hoa/thường | — | `lowercase(Locale.ROOT)` |
| Entry zip trùng tên → từ chối cả gói; đếm cả entry bị bỏ qua (≤ 20.000); giới hạn kích thước giải nén | `ZipFile` có thể gộp entry trùng tên | Spike ở A0: dùng `ZipInputStream` đếm từng entry, tự kiểm trùng tên và cộng dồn kích thước khi đọc |
| SplitMix64, Fisher–Yates, rejection sampling, thứ tự tiêu thụ | Số có dấu | `ULong`, `toULong()`; test vector seed 0 |
| Seed ghi chuỗi thập phân đủ 64 bit trong payload | `Long` mất bit dấu | `ULong.toString()`/`toULong()` |

## Phần 4 · Lộ trình cho agent

Nguyên tắc cỡ bước: **mỗi bước = một PR**, cỡ 2.000–8.000 dòng là bình thường (người duyệt đọc theo module, review độc
lập đọc theo quy tắc sản phẩm). Chỉ tách khi hai agent thật sự làm song song trên hai module rời. Tài liệu (exec-plan,
`android.md`, AGENTS.md, CHANGELOG) sửa ngay trong PR code. Kết luận spike ghi vào Decisions của exec-plan.

```mermaid
gantt
  title Android v1: 8 PR, 3 cổng; A2 ∥ A3b, A4a ∥ A4b
  dateFormat X
  axisFormat %s
  section Tuần tự
  A0 Chuẩn bị, ADR, khung Gradle          :a0, 0, 1
  A1 Lõi :core (rủi ro cao)               :a1, after a0, 2
  GA1 parity xanh                         :milestone, after a1, 0
  section Song song 1
  A2 :data (Room, ExamStore, đề mẫu)      :a2, after a1, 2
  A3b Giao diện làm bài → Xem lại         :a3b, after a1, 2
  section Tuần tự
  A3a Thư viện, Trước khi thi, nối luồng  :a3a, after a3b, 2
  GA2 dùng thử trên điện thoại            :milestone, after a3a, 0
  section Song song 2
  A4a PDF kết quả, chia sẻ, in            :a4a, after a3a, 1
  A4b TalkBack, tối, tablet, đề lớn       :a4b, after a3a, 1
  section Tuần tự
  A5 Beta: ký APK, hướng dẫn, đóng plan   :a5, after a4b, 1
  GA3 v1.0 riêng                          :milestone, after a5, 0
```

| Bước | Đầu ra | Phụ thuộc | Rủi ro / review | Kiểm chứng trong PR |
| --- | --- | --- | --- | --- |
| **A0 Chuẩn bị** (1 PR, agent + Nt0 chốt Q1–Q9 trước) | ADR 0011 (Android: Kotlin/Compose, lõi viết lại, monorepo `android/`), ADR 0012 (thư viện nền tảng và test-only); plan này vào `docs/product/`; `docs/product/android.md`; exec-plan `docs/plans/active/android-v1.md` (một plan cho cả v1); AGENTS.md thêm mục Android (bản đồ, lệnh, bất biến); khung Gradle 3 module với 1 test mỗi module; `check_android.sh`; workflow `android.yml` chỉ `workflow_dispatch`/tag; **spike** ghi Decisions: Intent nhận `.exam` (MIME `application/zip`, `application/octet-stream`, `*/*`), `ZipInputStream` với entry trùng và giới hạn, kotlinx strict mode, Compose Preview Screenshot trên AGP đang dùng; xác nhận các script hiện có (`check_boundaries.py`, `check_localization.py`, `check.sh`) không quét `android/` | — | Thường | `./gradlew test lint` xanh; `scripts/check.sh` của macOS không đổi kết quả |
| **A1 Lõi `:core`** (1 PR) | Model + `StrictJson` + `ExamValidator` (mã lỗi + đối số như `IssueCode`/`IssueArguments`) + `Scorer` + `ExamComposer` + `ExamSession` + `ExamPackageReader` (nghiêm; chế độ dễ chỉ để kết luận `examfile` của verdicts) + `AttemptRecord` + `QuestionFingerprint` + Markdown cơ bản; chuyển vector cố định sang `fixtures/vectors/` và sửa test Swift đọc từ đó | A0 | **Cao** (chấm điểm, đọc gói): 1 review độc lập | ~180 test JUnit: 4 test tham số hoá theo oracle (verdicts, SplitMix64, fingerprint, golden payload), tình huống theo scoring.md/exam-session.md (lấy danh sách từ `ScorerTests`, `ExamComposerTests`, `ExamSessionTests` của repo: của mình, không phải GPL); `swift test` ExamKit vẫn xanh. **Cổng GA1**: Nt0 chỉ đọc báo cáo parity |
| **A2 `:data`** (1 PR) | Room v1 (schema JSON export commit, test migration rỗng → v1), `LibraryEntry` (id đề, tiêu đề, mã, số câu/phần, thời gian, ngưỡng, ngày thêm, cờ đề mẫu, đường dẫn file nội bộ, trạng thái đọc), `Attempt` (tóm tắt + payload), `ExamStore` (chép vào `filesDir`, trùng id, Cập nhật đề, xoá có Hoàn tác không xoá lịch sử), `SampleExams` (assets từ `Packages/…/Samples`, tạo lần đầu, Khôi phục), DataStore (tên thí sinh, chế độ, kiểu xem, sắp xếp), `DraftSession` (phiên dở) | A1 | **Cao** (schema Room, lưu lần thi): 1 review độc lập | ~40 test Robolectric (Room in-memory); test đề mẫu đọc nghiêm từ assets |
| **A3b Giao diện làm bài** (1 PR, **song song A2**) | `AttemptViewModel` bọc `ExamSession` với `SessionClock` tiêm, tick, tạm dừng khi `onStop`, lưu/khôi phục phiên dở qua giao thức (fake trong PR này); màn Làm bài (câu, ảnh phóng to, lựa chọn A–Z theo vị trí, bảng câu hỏi bottom sheet, đồng hồ 3 mức, cảnh báo 5/1 phút, che khi tạm dừng, Kiểm tra đáp án), Rà soát & nộp (hộp "Còn N câu"), Kết quả (so với lần trước, phần yếu nhất), Xem lại bài (bộ lọc, `hideAnswers`, câu đã sửa/xoá), Luyện lại câu sai; chuỗi vi/en; nhãn TalkBack; theme sáng/tối | A1 | Thường | ~60 test ViewModel JVM (danh sách tình huống của `SessionFeatureTests`); screenshot Preview: câu dài 10 lựa chọn, ảnh lớn, Kết quả nhiều phần, Xem lại `hideAnswers` (sáng/tối, phone + tablet) |
| **A3a Thư viện và nối luồng** (1 PR) | Thư viện (lưới/danh sách, tìm/lọc/sắp xếp, Thông tin, Xoá + Hoàn tác, dải chào mừng), Thêm đề (SAF) và Intent `.exam`, Trước khi thi (bottom sheet dạng form, tóm tắt sống, lý do khoá), Lịch sử thi → Kết quả cũ, điều hướng (Navigation Compose), nối `DraftSession` thật, mỗi lúc một phiên | A2, A3b | Thường | ~30 test ViewModel; **5 test Compose** trên emulator: luồng 1, 2, 3 (đồng hồ nhanh), mở `.exam` qua Intent, (PDF ở A4a); screenshot Thư viện lưới/danh sách. **Cổng GA2**: Nt0 cài APK, làm trọn một đề thật trên điện thoại |
| **A4a PDF kết quả** (1 PR, **song song A4b**) | `ResultsReport` → khối (dùng lại quy tắc ẩn/hiện của export-print.md), dựng A4 bằng `PdfDocument` (tiến độ, huỷ), hộp chọn mức xem lại, chia sẻ/lưu/In; không có thời điểm xuất; chân trang mọi trang | A3a | Thường | ~15 test model khối (hideAnswers, câu đã sửa, mức xem lại); 3 smoke PDF (số trang, A4, mở được bằng `PdfRenderer`); 1 test Compose xuất PDF vào thư mục cache |
| **A4b Hoàn thiện** (1 PR) | Rà TalkBack theo bảng VoiceOver của accessibility-localization.md, kiểm tương phản bảng màu (port test `LibraryPalette`), bố cục tablet, Reduce Motion, cỡ chữ nội dung; `:benchmark` đo đề chuẩn (`gen_large_exam.py --out`) trên máy thật, ghi số vào `docs/notes/android-measurements.md`; sửa mục vượt ngân sách | A3a | Thường (cao nếu chạm `:core`) | Screenshot tablet; benchmark chỉ ghi số |
| **A5 Beta riêng** (1 PR + Nt0) | Cấu hình ký release (keystore Nt0 giữ, không vào git), `versionName`, CHANGELOG, hướng dẫn cài (bật nguồn không rõ / Play internal nếu chọn), sửa lỗi beta, đóng exec-plan | A4a, A4b | Thường | `check_android.sh --ui` xanh trên SHA phát hành; **Cổng GA3** |

Ước lượng: 8 PR, mỗi PR một phiên agent; so với tốc độ macOS (52 PR / 4 ngày với hạ tầng kiểm nặng hơn), toàn bộ v1
có thể nằm trong **5–7 ngày lịch** nếu Nt0 duyệt và test cổng kịp; nút thắt là GA2 (test trên máy thật).

### Thứ tự merge và nhánh

`feature/android-a0` → `feature/android-a1` → (`feature/android-a2` ∥ `feature/android-a3b`, cùng rẽ từ `main` sau khi
A1 merge) → `feature/android-a3a` → (`feature/android-a4a` ∥ `feature/android-a4b`) → `feature/android-a5`. Không xếp
chồng quá một tầng; nhánh song song không được chạm file của nhau (A2 chỉ `android/data/**`, A3b chỉ
`android/app/**` + `fixtures/` nếu cần).

## Phần 5 · Kiểm thử và bằng chứng merge

| Lớp | Công cụ | Chạy ở đâu | Phủ | Không làm (vì trùng) |
| --- | --- | --- | --- | --- |
| Lõi `:core` | JUnit 5 | Mọi nơi (Linux CI, Mac, agent cloud) | Oracle dùng chung (4 test tham số hoá), tình huống chấm điểm/chọn câu/phiên thi/đọc gói, bẫy Kotlin ở Phần 3 | Không test đo thời gian; không viết lại từng fixture thành test riêng |
| Dữ liệu `:data` | Robolectric + Room in-memory | Mọi nơi | Schema v1, ExamStore, đề mẫu, DraftSession | Không so thư mục dữ liệu thật (không cần) |
| ViewModel | JUnit thuần (ViewModel chỉ phụ thuộc `:core`) | Mọi nơi | Danh sách tình huống của `SessionFeatureTests`/`LibraryModelTests`/`PreExamModelTests` | Không lặp lại ở Compose test |
| Giao diện | Compose UI Test trên emulator (headless, Test Orchestrator `clearPackageData`) | Mac của Nt0 hoặc CI Linux có KVM | **5 test**: luồng 1, 2, 3, Intent `.exam`, xuất PDF | Không test từng màn riêng lẻ; không cần quyền Accessibility, không so kho thật |
| Hiển thị | Compose Preview Screenshot Testing (sáng/tối, phone/tablet) | Mọi nơi (không cần emulator) | ~10 màn × 2 theme; ảnh ≤ 300 KB trong git | Không thêm snapshot cho màn đã có Compose test đi qua nếu không có bố cục đặc biệt |
| Chuỗi và locale | Android Lint (`HardcodedText`, `MissingTranslation`, `ExtraTranslation`, `DefaultLocale`) | Mọi nơi | Đủ `en`, không chuỗi cứng, định dạng có locale | Không viết máy quét riêng, không test catalog từng module |
| Hiệu năng | `:benchmark` (JUnit timing hoặc Macrobenchmark) với `.exam` từ `gen_large_exam.py` | Máy thật, chạy tay | Bảng ngân sách large-exams.md | Không chặn merge |

Bằng chứng merge: `android/scripts/check_android.sh` (lint + test; `--ui` thêm `connectedCheck`) ghi commit status
`local/verify-android` giống `verify_local.sh`; PR chỉ chạm `android/` cần status này, PR chạm cả phần Swift cần cả hai.
`--ui` bắt buộc ở PR chạm `android/app/**` và ở cổng. CI GitHub (`android.yml`, runner Linux giá 1×, ước ~10 phút có
cache Gradle) chỉ chạy tay (và khi gắn tag phát hành) cho tới khi Nt0 quyết bật theo PR (Q8).

Vùng **rủi ro cao** (review độc lập bằng phiên agent mới, như docs/process/review-and-merge.md): `android/core/**`,
Room schema và `ExamStore` trong `android/data/**`, `fixtures/**`, `schema/**`. Chỉ 2 PR (A1, A2) rơi vào vùng này.

## Phần 6 · Rủi ro

| Rủi ro | Cách xử lý |
| --- | --- |
| Hai lõi (Swift, Kotlin) lệch nhau theo thời gian | Oracle dùng chung trong `fixtures/`; quy tắc: đổi hành vi lõi thì **sửa fixture/vector trước**, rồi hai bên cùng xanh; test Swift đọc cùng file vector từ A1 |
| Android giết tiến trình khi đang làm bài | `DraftSession` lưu khi tạm dừng và mỗi lần đổi đáp án; khôi phục ở trạng thái Tạm dừng (Q7) |
| Hộp chọn file không hiện `.exam` vì không có MIME | Spike A0; lọc `*/*` rồi kiểm đuôi/magic zip trong app |
| Ảnh lớn, đề 2.000 câu trên máy yếu | Giải mã ảnh theo kích thước hiển thị (`BitmapFactory.Options.inSampleSize`), `LazyColumn`; đo ở A4b trên máy thật của người dùng thử |
| PDF 2.000 câu trên điện thoại (macOS: ~12 s, 108 MB) | Dựng nền có tiến độ/huỷ; nhúng ảnh JPEG co theo bề rộng trang (quy định ở `android.md`, Nt0 chốt Q9) |
| Agent thêm thư viện "tiện tay" | ADR 0012 liệt kê nền tảng được dùng; `check_android.sh` so `libs.versions.toml` với danh sách cho phép (1 kiểm nhỏ, có đối chứng âm) |
| Phạm vi phình (soạn đề trên điện thoại, đồng bộ) | Khoá theo mục Ngoài v1 |

## Quyết định cần Nt0 chốt trước A0

| # | Câu hỏi | Đề xuất |
| --- | --- | --- |
| Q1 | Phạm vi Android chỉ bản Học viên? | Có; Admin vẫn trên macOS |
| Q2 | Công nghệ: Kotlin + Compose, viết lại lõi bằng Kotlin (không dùng Swift SDK for Android qua JNI, không Flutter/KMP)? | Có. Swift trên Android còn ở mức preview, cần NDK + cầu JNI, agent không build/test trong Gradle thường được; Kotlin thuần kiểm parity bằng oracle sẵn có |
| Q3 | Cùng repo, thư mục `android/`? | Có, để dùng chung schema/fixtures/đề mẫu/tài liệu/harness |
| Q4 | minSdk 29 (Android 10)? Có máy tính bảng không? | 29; phone trước, tablet ở A4b |
| Q5 | Thư viện nền tảng (AndroidX, kotlinx) không cần ADR từng cái; test-only Robolectric; ngoài ra cấm? | Có (ADR 0012) |
| Q6 | Thư viện **sao chép file đề vào app** thay vì tham chiếu; mở file cùng id thì hỏi Cập nhật đề? | Có |
| Q7 | Xuống nền tự tạm dừng và **lưu phiên dở**, khôi phục ở Tạm dừng (khác macOS phương án 2, 11)? | Có |
| Q8 | CI: giữ chỉ chạy tay (và gắn tag phát hành), bằng chứng là `local/verify-android`? Hay bật Linux CI theo PR cho `android/` (ước ~10 phút/PR, giá 1×)? | Giữ như macOS tới hết tháng 10; xem lại khi sang tháng |
| Q9 | PDF kết quả: nhúng ảnh JPEG co theo trang (file nhỏ) thay vì giữ nguyên như macOS? | Nhúng JPEG co theo trang |
| Q10 | Phân phối: APK qua ổ chung/Zalo với keystore của Nt0; hay Google Play Internal testing (cần tài khoản 25 USD)? | APK phát riêng trước |
| Q11 | Payload lần thi dùng đúng định dạng `AttemptRecord` v1 của macOS (giữ đường chuyển lịch sử giữa máy về sau)? | Có |
| Q12 | Cổng GA2 ai test tay, trên máy nào? | Nt0 + 1 học viên, máy thật của người dùng thử |

## Việc cần Nt0 làm một lần (môi trường)

- Cài Android Studio (hoặc cmdline-tools) + SDK + một ảnh emulator arm64 trên Mac; chấp nhận license SDK (agent không
  tự chấp nhận được). Agent dùng `./gradlew` với Gradle wrapper, không cần mở Android Studio.
- Tạo keystore release và giữ ngoài git (A5).
- Mỗi lúc một việc nặng trên Mac (emulator + Gradle); luồng song song thứ hai chạy trên máy khác hoặc agent cloud
  (`:core`, `:data`, ViewModel, screenshot đều không cần emulator).

## Hướng dẫn cho agent nhận plan

1. Đọc `AGENTS.md`, `docs/WORKFLOW.md`, plan này, `docs/product/{exam-format,scoring,exam-session,exam-taking,library,export-print,accessibility-localization,large-exams}.md`, ADR 0001–0012, `docs/process/review-and-merge.md`.
2. Chưa có chữ "đã chốt" của Nt0 ở bảng Quyết định thì dừng ở A0, không viết code.
3. Mỗi bước một PR trên nhánh `feature/android-<bước>`; không push `main`, không tự merge; cập nhật exec-plan
   `docs/plans/active/android-v1.md` trong cùng PR; không mở PR tài liệu riêng.
4. Không thêm lớp kiểm mới cho hành vi đã có lớp kiểm trong bảng Phần 5; không viết script tự kiểm cho những gì Gradle,
   Lint, build variant đã chặn.
5. Gặp quy tắc sản phẩm mơ hồ hay khác giữa macOS và Android chưa ghi ở `android.md`: dừng, hỏi Nt0; không tự chọn.
6. Báo cáo PR: lệnh đã chạy, số test, phần máy không kiểm được (TalkBack thật, máy thật, cài APK) cần người test tay.
