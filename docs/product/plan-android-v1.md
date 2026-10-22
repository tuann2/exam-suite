# Kế hoạch xây dựng Exam Suite cho Android (bản Học viên)

Soạn: 18/10/2026 · Sửa: 21/10/2026 (tách **v1 / v1.1**, quy tắc chống test trùng, bỏ PDF và `:benchmark` khỏi v1; theo
trao đổi với Nt0 cùng ngày) · 22/10/2026: **Nt0 chốt bảng Quyết định** (từng câu; Q4, Q8, Q11, Q12 khác đề xuất ban
đầu, các chỗ liên quan trong plan đã sửa theo) · Trạng thái: **đã chốt quyết định, vào thẩm quyền khi PR A0 merge**
(A0 đưa các quyết định vào ADR và `mobile.md`). Bản iOS cùng phạm vi: [plan-ios-v1.md](plan-ios-v1.md); **thứ tự: Android
trước, iOS sau** (Q13). Bản để bình luận (bản 18/10):
https://claude.ai/code/artifact/8096f6cb-97c3-411a-aa85-ce3e52f1e19d

## Tóm tắt

Xây app Android **chỉ cho học viên luyện tập**, chia hai giai đoạn. **v1**: Thư viện (danh sách), Thêm đề và mở `.exam`
từ app khác, Trước khi thi, Làm bài (Luyện tập/Thi), Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại,
Lịch sử thi, tự tạm dừng khi xuống nền và lưu phiên dở, tiếng Việt và tiếng Anh, nhãn TalkBack, sáng/tối theo hệ thống.
**v1.1** (hoãn, Nt0 chốt 2026-10-21): Xuất PDF kết quả và chia sẻ/In, bố cục máy tính bảng, Thư viện lưới, Thông tin đề,
lọc, Khôi phục đề mẫu, rà TalkBack sâu, Reduce Motion, đo đề lớn bằng module riêng. Không có Soạn đề và Import (đề vẫn
soạn bằng bản Admin trên macOS, phát file `.exam` cho học viên). Hợp đồng sản phẩm **dùng lại nguyên** các tài liệu
`docs/product/*.md` hiện có (exam-format, scoring, exam-session, exam-taking, library, export-print,
accessibility-localization, large-exams); chỗ mobile khác macOS ghi trong một tài liệu ngắn `docs/product/mobile.md`
**dùng chung với iOS** (nền tảng nào làm trước thì tạo file).

| Hạng mục | Đề xuất |
| --- | --- |
| Công nghệ | Kotlin 2.x, Jetpack Compose + Material 3, Room, DataStore, kotlinx.serialization; minSdk 31 (Android 12, Q4), targetSdk mới nhất (A0: compileSdk và targetSdk 37, Compose 1.12 đòi compileSdk 37) |
| Lõi | Viết lại ExamKit/ExamFile bằng **Kotlin thuần (module JVM, không Android)**, kiểm **cùng kết luận với bản Swift** qua các "oracle" đã có trong repo (schema, fixtures, `expected-verdicts.json`, vector SplitMix64, dấu vân tay câu, `large-exam.digest`); payload lần thi là định dạng riêng của Android (Q11) |
| Repo | Cùng repo, thư mục `android/` (dự án Gradle độc lập), dùng chung `schema/`, `fixtures/`, đề mẫu, `docs/product/`, harness |
| Quy mô | **v1: 6 PR code, 3 cổng, 1 cặp bước song song; v1.1: 3 PR, 1 cổng** (so với 52 PR của macOS, trong đó 16 PR chỉ tài liệu) |
| Kiểm thử | v1 ≈ 280 test, 7 lớp không chồng nhau, **3 lần mở app** trên emulator; quy tắc chống trùng ở Phần 4; không có hạ tầng "chế độ cô lập" vì emulator sẵn cách ly |
| Phân phối, CI | APK ký bằng keystore của Nt0, phát riêng (Q10); workflow `android.yml` (runner Linux) **chạy theo PR** chạm `android/**` (lint + test, Q8), là bằng chứng merge cho phần đó; emulator chạy trên Mac (`local/verify-android`); workflow `CI` của macOS không đổi |

Agent thực hiện toàn bộ code; Nt0 chốt quyết định ở mục cuối, duyệt PR, test tay trên điện thoại ở cổng GA2 và GA3 (chỉ Nt0, Q12).

Căn cứ của cách chia bước và cách kiểm (số đo bản macOS, bước chia quá nhỏ, lớp test trùng, song song): [notes/ra-soat-cach-lam-macos.md](../notes/ra-soat-cach-lam-macos.md). Plan này chỉ giữ kế hoạch.

## Phần 1 · Phạm vi và hợp đồng sản phẩm

Phạm vi xếp theo mức thiết yếu cho học viên dùng điện thoại (rà 2026-10-21, Nt0 đồng ý hoãn bậc 3 sang v1.1). Cùng
danh sách áp cho iOS ([plan-ios-v1.md](plan-ios-v1.md)).

### v1

Theo [overview.md](overview.md) luồng 1–3 và các tài liệu đã chốt, bỏ phần bàn phím/menu macOS:

- **Vào đề**: mở `.exam` từ app khác (Zalo, Drive, Files… qua Intent VIEW/SEND; trên điện thoại đây là đường chính),
  nút Thêm đề (hộp chọn file hệ thống), mở lại file cùng id thì hỏi Cập nhật đề.
- **Thư viện** ([library.md](library.md)): **chỉ dạng danh sách**, tìm (không dấu), sắp xếp, Xoá khỏi thư viện có
  Hoàn tác, đề mẫu lần đầu mở (2 đề hiện có, chỉ tiếng Việt) kèm dải chào mừng, Lịch sử thi → Kết quả cũ.
- **Trước khi thi, Làm bài, Rà soát & nộp, Kết quả, Xem lại bài, Luyện lại câu sai, Làm lại**
  ([exam-taking.md](exam-taking.md), [exam-session.md](exam-session.md), [scoring.md](scoring.md)): giữ nguyên quy tắc,
  kể cả `hideAnswers`, câu đã sửa sau lần thi, Kiểm tra đáp án ở Luyện tập, đánh dấu câu, bảng câu hỏi, đồng hồ ba mức
  và cảnh báo 5/1 phút, so với lần trước, phần yếu nhất, bộ lọc của Xem lại.
- **Riêng mobile**: tự tạm dừng khi app xuống nền và **lưu phiên dở**, mở lại đúng chỗ ở trạng thái Tạm dừng
  (`mobile.md`).
- Tiếng Việt (nguồn) và tiếng Anh từ PR đầu, thuật ngữ theo bảng đã duyệt ở
  [accessibility-localization.md](accessibility-localization.md); số/phần trăm/ngày giờ theo locale của ngôn ngữ giao
  diện; thang 1000 chữ số trơn; ngôn ngữ riêng cho app (Android 13 trở lên) có sẵn nhờ `strings.xml`.
- TalkBack: mọi điều khiển có nhãn, trạng thái luôn biểu tượng + chữ (viết cùng lúc với view; rà sâu theo bảng VoiceOver
  để v1.1); theme sáng/tối theo hệ thống; tương phản bảng màu theo phương án 8 của library.md; cỡ chữ theo **cỡ chữ hệ
  thống** (`sp`), không có menu Phóng to riêng.
- Đề 2.000 câu có ảnh mở và cuộn được; ngân sách của [large-exams.md](large-exams.md) áp dụng, **đo tay trên máy thật**
  ở A4 và ghi số, không có module đo trong v1.

### v1.1 (hoãn, Nt0 chốt 2026-10-21)

| Tính năng | Lý do hoãn | Bước |
| --- | --- | --- |
| Xuất PDF kết quả, chia sẻ, In qua `PrintManager` ([export-print.md](export-print.md) phần Học viên) | Người dùng điện thoại ít cần; bỏ được một PR, một quyết định (Q9), một rủi ro và một chỗ test trùng khỏi v1 | B1 |
| Bố cục máy tính bảng (cột bên cho bảng câu hỏi), Thư viện dạng lưới, Thông tin đề, lọc Thư viện, Khôi phục đề mẫu | Danh sách và dòng tóm tắt đủ trên màn hẹp; bản phone chạy được trên tablet | B2 |
| Rà TalkBack sâu theo bảng mục tiêu VoiceOver, Reduce Motion, `:benchmark` đo đề chuẩn | Nhãn cơ bản đã có từ v1; Compose theo cài đặt hệ thống phần lớn tự động; số đo tay ở A4 đủ cho beta | B3 |

### Không làm

Cỡ chữ nội dung riêng trong app (trùng với cỡ chữ hệ thống); bàn phím ngoài.

### Ngoài phạm vi mobile

Soạn đề, import, PDF đề; đồng bộ lịch sử giữa máy (payload Android khác `AttemptRecord` của macOS theo Q11: muốn đồng
bộ về sau phải có bộ chuyển đổi); Google Play công khai.

### Khác macOS (viết vào `docs/product/mobile.md`, dùng chung với iOS; Nt0 chốt ở Q6, Q7)

| Chủ đề | macOS | Mobile (đề xuất) | Lý do |
| --- | --- | --- | --- |
| File đề trong Thư viện | Tham chiếu tại chỗ bằng bookmark; trạng thái Không tìm thấy file, Tìm file…, Làm mới khi file đổi | **Sao chép vào bộ nhớ riêng của app** (`filesDir/exams/<id>.exam`) khi thêm; không có trạng thái mất file; mở lại file cùng id → hỏi **Cập nhật đề** / Huỷ | Android không có bookmark bền; quyền URI của hộp chọn file mất khi file đổi chỗ hay ổ gỡ. Bỏ được cả nhóm Làm mới/Tìm lại (≈ 1/3 LibraryData) |
| App xuống nền khi đang làm bài | Không tự tạm dừng (phương án 11); đóng cửa sổ thì hỏi rồi bỏ bài, không lưu phiên dở (phương án 2) | **Tự tạm dừng khi app xuống nền** (`onStop`) và **lưu phiên dở** để mở lại đúng chỗ ở trạng thái Tạm dừng; nút Back ở màn làm bài hỏi "Bỏ bài?" như macOS | Hệ điều hành có thể giết tiến trình bất kỳ lúc nào khi ở nền; học viên nhận cuộc gọi, khoá màn hình là chuyện thường |
| Đồng hồ | `SuspendingClock` (không chạy khi máy ngủ) | `SystemClock.uptimeMillis()` (không chạy khi deep sleep) + tạm dừng khi xuống nền | Cùng ngữ nghĩa "thời gian ngủ không bị trừ" |
| Bảng câu hỏi | Inspector bên phải | Bottom sheet trên điện thoại (cột bên ở tablet: v1.1) | Màn nhỏ |
| Phím tắt | Bảng phím đầy đủ | Không hỗ trợ | Không có bàn phím |
| Cỡ chữ nội dung | Menu Xem › Phóng to, 100–150% | Theo cỡ chữ hệ thống, không có menu riêng | Hệ điều hành đã có |
| Thư viện | Lưới và danh sách | v1 chỉ danh sách; lưới ở v1.1 | Màn hẹp |
| Xuất PDF | Hộp Lưu + hộp In | **v1.1**: hộp chia sẻ hệ thống (lưu Downloads/gửi), In qua `PrintManager`; giữ ba mức xem lại như macOS | Quy ước Android |
| Ngôn ngữ | Theo macOS, không có ô chọn trong app | Theo hệ thống + ngôn ngữ riêng cho app (Android 13 trở lên, Settings › App languages); không có ô chọn trong app | Cùng phương án 1 |
| Tên app | Exam Suite | Exam Suite (gói `vn.io.nt0.examsuite.android`) | — |

## Phần 2 · Kiến trúc

```text
android/
├── settings.gradle.kts · build.gradle.kts · gradle/libs.versions.toml · gradlew
├── core/        Kotlin JVM thuần (không Android SDK): model, StrictJson, ExamValidator, Scorer, ExamComposer
│                (SplitMix64), ExamSession (+SessionClock), ExamPackageReader (java.util.zip, giới hạn),
│                AttemptPayload (định dạng riêng của Android, payloadVersion 1, Q11), QuestionFingerprint (cùng thuật
│                toán với macOS), Markdown cơ bản,
│                ReviewItems (bộ dựng mục xem lại: luật ẩn/hiện của hideAnswers, câu đã sửa/xoá, mức xem lại; một nơi
│                duy nhất, Xem lại dùng ở v1, PDF dùng lại ở v1.1)
├── data/        Android library: Room (LibraryEntry, Attempt; schema v1 export), DataStore (cài đặt), ExamStore
│                (chép/xoá file đề), SampleExams (assets trỏ thẳng vào Packages/…/Resources/Samples), DraftSession
├── app/         Compose: ui/library, ui/preexam, ui/attempt, ui/results, ui/review, ui/history; ViewModel thuần
│                Kotlin (chỉ :core + coroutines) để test JVM; nhận Intent .exam   (v1.1 thêm ui/report, :benchmark)
├── lint-rules/  luật lint riêng ComposeHardcodedText (chữ cứng trong Compose; A0)
└── scripts/check_android.sh   luật riêng + lint + test (+ --ui: connectedDebugAndroidTest trên emulator) → status local/verify-android
```

- `:core` test bằng JUnit trên Linux/macOS, không cần emulator: đây là phần agent cloud làm trọn được (như ADR 0008).
- Oracle dùng chung với bản Swift, đọc qua đường dẫn tương đối (`sourceSets.test.resources.srcDir("../../fixtures")`),
  **không chép**: `schema/exam-v1.schema.json`, `fixtures/exams/*`, `fixtures/invalid/*`, `fixtures/expected-verdicts.json`
  (kể cả khoá `whiteSpace`: 25 code point ghi thành 10 dải, ví dụ `2000-200A`), `fixtures/large-exam.digest`. Vector cố định hiện nằm trong test
  Swift (SplitMix64 seed 0, `QuestionFingerprintTests`) → A1 chuyển chúng thành file
  `fixtures/vectors/*.json` dùng chung (JSON mẫu `AttemptSamples` của macOS **không** chuyển: payload Android riêng theo
  Q11, có JSON mẫu riêng trong test của `:core` để chặn đổi khoá ngầm) và sửa test Swift đọc từ đó (thay đổi nhỏ, không đổi giá trị). Ca JSON sai cú
  pháp (khoá trùng, sâu 33, `NaN`, BOM, surrogate lẻ, dấu phẩy thừa) hiện chỉ có inline trong test Swift ExamFile; 16
  fixture của `fixtures/invalid/` đều là JSON hợp lệ về cú pháp nên **không** làm đối chứng âm cho `StrictJson` được
  → A1 thêm `fixtures/invalid-json/` dùng chung và sửa test Swift đọc từ đó (cùng cách với vector).
- Thư viện: **nền tảng** (AndroidX/Jetpack, kotlinx.serialization, kotlinx.coroutines, Material 3) dùng không cần ADR
  từng cái; **test-only** Robolectric (MIT) cho `:data`, Compose UI Test và Compose Preview Screenshot Testing (AndroidX);
  **không có** thư viện bên thứ ba khác. Zip `java.util.zip`, SHA-256 `MessageDigest`, NFC `java.text.Normalizer`,
  Markdown cơ bản tự viết (~150 dòng, đậm/nghiêng/code); v1.1: PDF `android.graphics.pdf.PdfDocument`. Thêm gì khác
  phải có ADR (như ADR 0006).

### Bẫy đã biết khi viết lại lõi bằng Kotlin (ghi để agent kiểm ngay trong A1)

| Quy tắc (exam-format.md) | Bẫy Kotlin/JVM | Cách làm |
| --- | --- | --- |
| Độ dài đếm theo code point | `String.length` là đơn vị UTF-16 | `codePointCount(0, length)` |
| Khoảng trắng = 25 code point `White_Space` | `Character.isWhitespace` khác danh sách | Dùng đúng danh sách từ khoá `whiteSpace` của `expected-verdicts.json` |
| Khoá JSON trùng, `null`, dấu phẩy thừa, `NaN`, surrogate lẻ, BOM, sâu ≤ 32 → từ chối (đọc nghiêm) | kotlinx.serialization lấy khoá cuối khi trùng, không giới hạn độ sâu; `String(bytes, UTF_8)` thay byte hỏng bằng U+FFFD | Một lượt `StrictJson` (tokenizer ~200 dòng) chạy trước khi giải mã; giải mã UTF-8 bằng `CharsetDecoder` chế độ REPORT; đối chứng âm là `fixtures/invalid-json/` dùng chung (Phần 2) |
| Trường lạ: từ chối, nêu tên và vị trí | `ignoreUnknownKeys = false` (mặc định) báo tên khoá nhưng vị trí khó lấy | Lấy đường dẫn từ `StrictJson` |
| Mẫu `code`, `image`, id khớp tuyệt đối | `Regex.matches` đã là khớp cả chuỗi | Không dùng `containsMatchIn` |
| So id không phân biệt hoa/thường | — | `lowercase(Locale.ROOT)` |
| Entry zip trùng tên → từ chối cả gói; đếm cả entry bị bỏ qua (≤ 20.000); giới hạn kích thước giải nén | `ZipFile` có thể gộp entry trùng tên | Spike ở A0: dùng `ZipInputStream` đếm từng entry, tự kiểm trùng tên và cộng dồn kích thước khi đọc |
| SplitMix64, Fisher–Yates, rejection sampling, thứ tự tiêu thụ | Số có dấu | `ULong`, `toULong()`; test vector seed 0 |
| Seed ghi chuỗi thập phân đủ 64 bit trong payload | `Long` mất bit dấu | `ULong.toString()`/`toULong()` |

## Phần 3 · Lộ trình cho agent

Nguyên tắc cỡ bước: **mỗi bước = một PR**, cỡ 2.000–8.000 dòng là bình thường (người duyệt đọc theo module, review độc
lập đọc theo quy tắc sản phẩm). Chỉ tách khi hai agent thật sự làm song song trên hai module rời. Tài liệu (exec-plan,
`mobile.md`, AGENTS.md, CHANGELOG) sửa ngay trong PR code. Kết luận spike ghi vào Decisions của exec-plan.

### v1: 6 PR, 3 cổng

```mermaid
gantt
  title Android v1: 6 PR, 3 cổng; A2 ∥ A3b
  dateFormat X
  axisFormat %s
  section Tuần tự
  A0 Chuẩn bị, ADR, khung Gradle          :a0, 0, 1
  A1 Lõi :core (rủi ro cao)               :a1, after a0, 2
  GA1 parity xanh                         :milestone, after a1, 0
  section Song song
  A2 :data (Room, ExamStore, đề mẫu)      :a2, after a1, 2
  A3b Giao diện làm bài → Xem lại         :a3b, after a1, 2
  section Tuần tự
  A3a Thư viện, Trước khi thi, nối luồng  :a3a, after a3b, 2
  GA2 dùng thử trên điện thoại            :milestone, after a3a, 0
  A4 Hoàn thiện, beta, đóng plan v1       :a4, after a3a, 1
  GA3 v1.0 riêng                          :milestone, after a4, 0
```

| Bước | Đầu ra | Phụ thuộc | Rủi ro / review | Kiểm chứng trong PR |
| --- | --- | --- | --- | --- |
| **A0 Chuẩn bị** (1 PR; Q1–Q13 đã chốt 2026-10-22) | ADR Android (Kotlin/Compose, lõi viết lại, monorepo `android/`), ADR thư viện nền tảng và test-only (số ADR theo thứ tự lúc làm; nếu iOS làm trước thì ADR mobile chung đã có, chỉ thêm phần Android); plan này vào `docs/product/`; `docs/product/mobile.md` (tạo nếu chưa có); exec-plan `docs/plans/active/android-v1.md` (một plan cho cả v1); AGENTS.md thêm mục Android (bản đồ, lệnh, bất biến); khung Gradle 3 module với 1 test mỗi module; `check_android.sh`; workflow `android.yml` chạy `pull_request` (đường dẫn `android/**`, `fixtures/**`, `schema/**`, đề mẫu `Packages/ExamFeatures/Sources/LibraryData/Resources/Samples/**`), `workflow_dispatch` và tag phát hành, job `./gradlew test lint` có cache Gradle; review-and-merge.md và AGENTS.md ghi ngoại lệ "CI theo PR" của `android/` (Nt0 chốt Q8); **spike** ghi Decisions: ảnh Compose Preview Screenshot ghi và so trên cùng nền với CI (Linux; ghi lại ảnh bằng Docker nếu macOS ra khác),  Intent nhận `.exam` (MIME `application/zip`, `application/octet-stream`, `*/*`), `ZipInputStream` với entry trùng và giới hạn, kotlinx strict mode, Compose Preview Screenshot trên AGP đang dùng, **Lint `HardcodedText` không quét `Text("…")` của Compose** → chốt một luật lint tự viết chạy trong `gradlew lint` (một lớp, có đối chứng âm) hay chỉ dựa vào review, **kiểm trợ năng bật ngay trong Compose UI Test** (không thêm lớp riêng); xác nhận các script hiện có (`check_boundaries.py`, `check_localization.py`, `check.sh`) không quét `android/` | — | Thường | `./gradlew test lint` xanh; `scripts/check.sh` của macOS không đổi kết quả |
| **A1 Lõi `:core`** (1 PR) | Model + `StrictJson` + `ExamValidator` (mã lỗi + đối số như `IssueCode`/`IssueArguments`) + `Scorer` + `ExamComposer` + `ExamSession` + `ExamPackageReader` (nghiêm; chế độ dễ chỉ để kết luận `examfile` của verdicts) + `AttemptPayload` (riêng của Android) + `QuestionFingerprint` + Markdown cơ bản + `ReviewItems`; chuyển vector cố định sang `fixtures/vectors/`, thêm `fixtures/invalid-json/`, sửa test Swift đọc từ đó | A0 | **Cao** (chấm điểm, đọc gói, chạm `fixtures/`): 1 review độc lập | ~170 test JUnit: 4 test tham số hoá theo oracle chung (verdicts, invalid-json, SplitMix64, fingerprint) và JSON mẫu payload riêng của Android, tình huống theo scoring.md/exam-session.md (lấy danh sách từ `ScorerTests`, `ExamComposerTests`, `ExamSessionTests` của repo: của mình, không phải GPL; "máy ngủ" của macOS đổi thành "tạm dừng" ở lõi; phiên dở `snapshot`/`restore` là luật lõi nên test ở lõi, ViewModel A3b chỉ test việc gọi chúng khi xuống nền); `swift test` ExamKit và ExamFile vẫn xanh (PR chạm Swift nên cần cả `local/verify`). **Cổng GA1**: Nt0 chỉ đọc báo cáo parity |
| **A2 `:data`** (1 PR) | Room v1 (schema JSON export commit, test migration rỗng → v1), `LibraryEntry` (id đề, tiêu đề, mã, số câu/phần, thời gian, ngưỡng, ngày thêm, cờ đề mẫu, đường dẫn file nội bộ, trạng thái đọc), `Attempt` (tóm tắt + payload), `ExamStore` (chép vào `filesDir`, trùng id, Cập nhật đề, xoá có Hoàn tác không xoá lịch sử), `SampleExams` (assets từ `Packages/…/Samples`, tạo lần đầu), DataStore (tên thí sinh, chế độ, sắp xếp), `DraftSession` (phiên dở) | A1 | **Cao** (schema Room, lưu lần thi): 1 review độc lập | ~40 test Robolectric (Room in-memory); 1 test đề mẫu đọc nghiêm từ assets (tính hợp lệ của đề mẫu đã có `validate_exam.py` và test Swift kiểm, không lặp lại) |
| **A3b Giao diện làm bài** (1 PR, **song song A2**) | `AttemptViewModel` bọc `ExamSession` với `SessionClock` tiêm, tick, tạm dừng khi `onStop`, lưu/khôi phục phiên dở qua giao thức (fake trong PR này); màn Làm bài (câu, ảnh phóng to, lựa chọn A–Z theo vị trí, bảng câu hỏi bottom sheet, đồng hồ ba mức, cảnh báo 5/1 phút, che khi tạm dừng, Kiểm tra đáp án), Rà soát & nộp (hộp "Còn N câu"), Kết quả (so với lần trước, phần yếu nhất), Xem lại bài (bộ lọc; nội dung từ `ReviewItems`), Luyện lại câu sai, Làm lại; chuỗi vi/en; nhãn TalkBack; theme sáng/tối; chữ theo `sp` | A1 | Thường | ~35 test ViewModel JVM **chỉ cho phần ViewModel thêm** (nhãn A–Z theo vị trí, nhóm bảng câu hỏi, định dạng đồng hồ mm:ss / h:mm:ss, tạm dừng khi `onStop`, lưu/khôi phục phiên dở, câu đọc TalkBack, nộp → lưu, so với lần trước, phần yếu nhất); **không** kể lại luật chuyển trạng thái, đồng hồ, tạm dừng đã test ở A1; screenshot Preview **chỉ phone**: câu dài 10 lựa chọn, ảnh lớn, Kết quả nhiều phần, Xem lại `hideAnswers` (sáng/tối, 8 ảnh) |
| **A3a Thư viện và nối luồng** (1 PR) | Thư viện danh sách (tìm/sắp xếp, Xoá + Hoàn tác, dải chào mừng), Thêm đề (SAF) và Intent `.exam`, Cập nhật đề, Trước khi thi (bottom sheet dạng form, tóm tắt sống, lý do khoá), Lịch sử thi → Kết quả cũ, điều hướng (Navigation Compose), nối `DraftSession` thật, mỗi lúc một phiên | A2, A3b | Thường | ~30 test ViewModel (danh sách của `LibraryModelTests`/`PreExamModelTests`, chỉ phần không thuộc lõi); Compose UI Test trên emulator **3 lần mở app**: luồng 1 (Luyện tập tới Xem lại, Luyện lại câu sai); luồng 2 **mở đầu bằng Intent `.exam`** rồi Thi, hết giờ với đồng hồ nhanh tiêm qua test rule (cùng tiến trình, không cần tham số khởi chạy); luồng 3 (Back hỏi Bỏ bài, xuống nền tạm dừng, mở lại đúng chỗ); kiểm trợ năng bật trong ba test này; screenshot Thư viện danh sách sáng/tối (2 ảnh). **Cổng GA2**: Nt0 cài APK, làm trọn một đề thật trên điện thoại |
| **A4 Hoàn thiện và beta** (1 PR + Nt0) | Port test tương phản bảng màu (`LibraryPalette`), rà nhanh nhãn TalkBack trên bốn màn chính, **đo tay** đề chuẩn (`gen_large_exam.py --out`) trên máy thật bằng log thời gian của bản debug, ghi `docs/notes/android-measurements.md`, sửa mục vượt ngân sách; cấu hình ký release (keystore Nt0 giữ, không vào git), `versionName`, CHANGELOG, hướng dẫn cài (bật nguồn không rõ), sửa lỗi beta từ GA2, đóng exec-plan v1 | A3a | Thường (cao nếu chạm `:core`) | ~10 test tương phản; `check_android.sh --ui` xanh trên SHA phát hành; **Cổng GA3** |

Ước lượng: 6 PR, mỗi PR một phiên agent; so với tốc độ macOS (52 PR / 4 ngày với hạ tầng kiểm nặng hơn), v1 có thể nằm
trong **4–6 ngày lịch** nếu Nt0 duyệt và test cổng kịp; nút thắt là GA2 (test trên máy thật).

### v1.1: 3 PR, 1 cổng (làm sau khi v1 ổn định và Nt0 có thời gian)

| Bước | Đầu ra | Phụ thuộc | Rủi ro / review | Kiểm chứng trong PR |
| --- | --- | --- | --- | --- |
| **B1 PDF kết quả** (1 PR) | exec-plan `docs/plans/active/android-v1.1.md` (tạo ở PR này); `ResultsReport` dựng khối từ `ReviewItems` của `:core` (không viết lại luật ẩn/hiện), A4 bằng `PdfDocument` (tiến độ, huỷ, ảnh JPEG co theo trang: Q9), hộp chọn mức xem lại, chia sẻ/lưu/In; không có thời điểm xuất; chân trang mọi trang | v1 | Thường | ~5 test khối (bố cục, khối có mặt theo mức xem lại); 3 smoke PDF (số trang, A4, mở được bằng `PdfRenderer`); Xuất PDF **nối vào đuôi test Compose luồng 1**, không thêm lần mở app |
| **B2 Giao diện mở rộng** (1 PR) | Bố cục tablet (cột bên cho bảng câu hỏi, hai cột Kết quả), Thư viện lưới, Thông tin đề, lọc, Khôi phục đề mẫu | v1 | Thường | Screenshot tablet (sáng/tối) cho làm bài, Kết quả, Thư viện lưới; ~10 test ViewModel cho lọc và Thông tin |
| **B3 Trợ năng sâu và đo** (1 PR) | Rà TalkBack theo bảng mục tiêu VoiceOver của accessibility-localization.md, Reduce Motion; `:benchmark` đo đề chuẩn chạy tay nếu số đo tay ở A4 vượt hay sát ngân sách; đóng exec-plan v1.1 | B1, B2 | Thường | Benchmark chỉ ghi số; `check_android.sh --ui` xanh; **Cổng GA4**: Nt0 test tay trên điện thoại và máy tính bảng |

### Thứ tự merge và nhánh

v1: `feature/android-a0` → `feature/android-a1` → (`feature/android-a2` ∥ `feature/android-a3b`, cùng rẽ từ `main` sau khi
A1 merge) → `feature/android-a3a` → `feature/android-a4`. v1.1: `feature/android-b1` → `feature/android-b2` →
`feature/android-b3` (B1 ∥ B2 được nếu có hai agent). Không xếp chồng quá một tầng; nhánh song song không được chạm file
của nhau (A2 chỉ `android/data/**`, A3b chỉ `android/app/**` + `fixtures/` nếu cần).

## Phần 4 · Kiểm thử và bằng chứng merge

| Lớp | Công cụ | Chạy ở đâu | Phủ | Không làm (vì trùng) |
| --- | --- | --- | --- | --- |
| Lõi `:core` | JUnit 5 | Mọi nơi (Linux CI, Mac, agent cloud) | Oracle dùng chung (4 test tham số hoá), JSON mẫu payload Android, tình huống chấm điểm/chọn câu/phiên thi/đọc gói, `ReviewItems`, bẫy Kotlin ở Phần 2 | Không test đo thời gian; không viết lại từng fixture thành test riêng |
| Dữ liệu `:data` | Robolectric + Room in-memory | Mọi nơi | Schema v1, ExamStore, đề mẫu (một test đọc được), DraftSession | Không so thư mục dữ liệu thật (không cần); không kiểm lại tính hợp lệ của đề mẫu |
| ViewModel | JUnit thuần (ViewModel chỉ phụ thuộc `:core`) | Mọi nơi | Phần ViewModel thêm trên lõi (A3b, A3a) | Không kể lại luật của `ExamSession`, `Scorer`, `ReviewItems`; không lặp lại ở Compose test |
| Giao diện | Compose UI Test trên emulator (headless, Test Orchestrator `clearPackageData`) | Mac của Nt0 (`local/verify-android`) | **3 lần mở app**: luồng 1, luồng 2 (mở đầu bằng Intent `.exam`, đồng hồ nhanh), luồng 3 (Back, xuống nền); v1.1 nối Xuất PDF vào luồng 1 | Không test từng màn riêng lẻ; không thêm lần mở app cho tính năng mới nếu nối được vào luồng có sẵn; không cần quyền Accessibility, không so kho thật |
| Trợ năng | Kiểm trợ năng của Compose UI Test bật trong ba test trên | Cùng emulator | Nhãn thiếu, vùng chạm nhỏ, tương phản của phần tử | Không lớp riêng, không test thêm |
| Hiển thị | Compose Preview Screenshot Testing (sáng/tối, v1 chỉ phone) | Mọi nơi (không cần emulator) | 5 màn × 2 theme ≈ 10 ảnh; ảnh ≤ 300 KB trong git; tablet ở v1.1 | Không thêm screenshot cho màn đã có Compose test đi qua nếu không có bố cục đặc biệt; không chụp hai cỡ máy trong v1 |
| Chuỗi và locale | Android Lint (`MissingTranslation`, `ExtraTranslation`, `DefaultLocale`) + luật lint `ComposeHardcodedText` (`:lint-rules`, A0); `values/strings.xml` không `tools:locale` (lint khi đó bỏ qua MissingTranslation) | Mọi nơi | Đủ `en`, không chuỗi cứng, định dạng có locale | Không viết máy quét riêng ngoài `gradlew lint`, không test catalog từng module |
| Hiệu năng | v1: đo tay trên máy thật, ghi số; v1.1: `:benchmark` chạy tay | Máy thật | Bảng ngân sách large-exams.md | Không chặn merge |

### Quy tắc chống test trùng (rút từ [notes/ra-soat-cach-lam-macos.md](../notes/ra-soat-cach-lam-macos.md) mục 3; áp cho mọi PR Android và iOS)

1. **Mỗi luật một tầng.** Luật chuyển trạng thái, đồng hồ, chấm điểm, ẩn/hiện của Xem lại chỉ test ở `:core`. ViewModel
   test những gì ViewModel thêm; Compose test chỉ đi luồng; screenshot chỉ bố cục.
2. **Một bộ dựng mục xem lại** (`ReviewItems`) cho màn Xem lại và PDF; không viết luật ẩn/hiện lần hai ở tầng báo cáo
   (bản macOS viết hai lần nên có ~100 test PDF, notes mục 3).
3. **Không thêm lần mở app.** Tính năng mới nối vào một trong ba luồng Compose có sẵn, bọc `runActivity`/bước đặt tên;
   chỉ thêm lần mở app khi cần trạng thái khởi đầu khác hẳn.
4. **Oracle chung thay cho ca inline.** Ca kiểm của lõi viết thành file trong `fixtures/` để hai lõi (ba, nếu iOS tách
   model) cùng đọc; không có bộ ca Kotlin riêng cho hành vi đã có ở Swift.
5. **Screenshot một cỡ máy mỗi giai đoạn.** v1 phone, v1.1 thêm tablet; không chụp lại cùng màn ở hai bước.
6. **Không lớp kiểm mới cho việc công cụ đã làm.** Gradle chặn `:core` import Android; emulator cách ly dữ liệu; Lint
   kiểm chuỗi. Phát hiện khoảng trống (như chữ cứng Compose) thì bổ sung vào lớp có sẵn (`gradlew lint`), không thêm
   script.

Bằng chứng merge (Nt0 chốt Q8 2026-10-22: CI thay phần lint + test, không chạy trùng hai nơi):

| PR chạm | Cần xanh trên SHA cuối |
| --- | --- |
| Chỉ `android/core/**`, `android/data/**`, build Gradle | Check `android` của workflow `android.yml` (lint + test JVM, Robolectric, screenshot) |
| `android/app/**`, và ở mọi cổng | Check `android` **và** status `local/verify-android` do `android/scripts/check_android.sh --ui` ghi (chỉ `connectedCheck` trên emulator của Mac, không chạy lại lint + test) |
| Mọi PR | `local/verify` của `scripts/verify_local.sh`, mức theo file đổi (`verify_scope.py`): chỉ `android/` và tài liệu thì chỉ kiểm danh tính git; oracle/test lõi Swift thì `check.sh --core`; phần macOS khác thì đủ bộ |

`check_android.sh` không có `--ui` vẫn chạy được lint + test tại chỗ khi làm, nhưng không ghi status. Workflow `CI` của
macOS giữ nguyên (chỉ chạy tay, tag `v*`); branch protection vẫn chưa bật, người duyệt tự kiểm các check trước khi merge.

Vùng **rủi ro cao** (review độc lập bằng phiên agent mới, như docs/process/review-and-merge.md): `android/core/**`,
Room schema và `ExamStore` trong `android/data/**`, `fixtures/**`, `schema/**`. Chỉ 2 PR (A1, A2) rơi vào vùng này.

## Phần 5 · Rủi ro

| Rủi ro | Cách xử lý |
| --- | --- |
| Hai lõi (Swift, Kotlin) lệch nhau theo thời gian | Oracle dùng chung trong `fixtures/`; quy tắc: đổi hành vi lõi thì **sửa fixture/vector trước**, rồi hai bên cùng xanh; test Swift đọc cùng file vector và `invalid-json` từ A1 |
| Android giết tiến trình khi đang làm bài | `DraftSession` lưu khi app xuống nền (`ON_STOP`, luôn trước khi hệ điều hành dừng app ở nền); khôi phục ở trạng thái Tạm dừng (Q7) |
| Hộp chọn file không hiện `.exam` vì không có MIME | Spike A0; lọc `*/*` rồi kiểm đuôi/magic zip trong app |
| Ảnh lớn, đề 2.000 câu trên máy yếu | Giải mã ảnh theo kích thước hiển thị (`BitmapFactory.Options.inSampleSize`), `LazyColumn`; đo tay ở A4 trên điện thoại của Nt0 (Q12), ghi đời máy cùng số đo; vượt ngân sách thì B3 thêm `:benchmark` |
| Agent chép danh sách test của macOS sang và kể lại luật lõi ở ViewModel | Quy tắc 1 của Phần 4; người duyệt A3b đối chiếu tên test với `ExamSessionTests` |
| Lint không bắt chữ cứng trong Compose, agent giữa chừng viết máy quét riêng | Chốt ở spike A0 (luật lint tự viết trong `gradlew lint` hay review); quy tắc 6 |
| Agent thêm thư viện "tiện tay" | ADR thư viện liệt kê nền tảng được dùng; `check_android.sh` so `libs.versions.toml` với danh sách cho phép (1 kiểm nhỏ, có đối chứng âm) |
| PDF 2.000 câu trên điện thoại (v1.1; macOS: ~12 s, 108 MB) | Dựng nền có tiến độ/huỷ; nhúng ảnh JPEG co theo bề rộng trang (quy định ở `mobile.md`, Nt0 chốt Q9 khi làm B1) |
| Chỉ Nt0 test tay ở GA2 (Q12): một máy, lỗi theo hãng (Samsung, Xiaomi…) hay theo app gửi file (Zalo, Drive) lộ muộn | Ghi "đã thử trên máy nào, gửi file qua app nào" vào Validation của cổng; người dùng thử beta ở GA3 báo lỗi theo mẫu có hãng máy và phiên bản Android |
| Payload riêng của Android (Q11) đổi khoá ngầm, hoặc về sau muốn chuyển lịch sử sang macOS | JSON mẫu cố định trong test `:core`, đổi định dạng phải tăng `payloadVersion`; đồng bộ giữa máy là ngoài phạm vi, nếu làm thì cần bộ chuyển đổi và quyết định mới |
| Screenshot test ra khác giữa Mac và runner Linux của CI | Spike A0; ảnh tham chiếu ghi trên cùng nền với CI |
| Phạm vi phình (soạn đề trên điện thoại, đồng bộ; kéo mục v1.1 vào v1) | Khoá theo Phần 1; mục v1.1 chỉ làm trong exec-plan v1.1 |

## Quyết định (Nt0 chốt 2026-10-22)

Nt0 trả lời từng câu ngày 22/10/2026; trước đó (21/10) đã chốt phạm vi v1 / v1.1 như Phần 1 và hai nền tảng mobile đều
native. A0 chép các quyết định này vào ADR và `mobile.md`; tới lúc đó bảng này là nơi ghi.

| # | Câu hỏi | Đề xuất ban đầu | **Chốt** |
| --- | --- | --- | --- |
| Q1 | Phạm vi Android chỉ bản Học viên? | Có; Admin vẫn trên macOS | **Như đề xuất** |
| Q2 | Kotlin + Compose, viết lại lõi bằng Kotlin (không Swift SDK for Android qua JNI, không Flutter/KMP)? | Có (ghi chú dưới bảng) | **Như đề xuất** |
| Q3 | Cùng repo, thư mục `android/`? | Có, dùng chung schema/fixtures/đề mẫu/tài liệu/harness | **Như đề xuất** |
| Q4 | minSdk? | 29 (Android 10); v1 chỉ phone, tablet ở v1.1 | **minSdk 31 (Android 12)**; v1 chỉ phone, tablet ở v1.1 (B2) |
| Q5 | Thư viện nền tảng (AndroidX, kotlinx, Material 3) không cần ADR từng cái; test-only Robolectric, Compose UI Test, Compose Preview Screenshot; ngoài ra phải có ADR? | Có (một ADR thư viện, `check_android.sh` so danh sách cho phép) | **Như đề xuất** |
| Q6 | Sao chép file đề vào app; mở file cùng id thì hỏi Cập nhật đề / Huỷ? | Có (ghi `mobile.md`, dùng chung iOS) | **Như đề xuất** |
| Q7 | Xuống nền tự tạm dừng và lưu phiên dở, khôi phục ở Tạm dừng (khác macOS phương án 2, 11)? | Có (ghi `mobile.md`, dùng chung iOS) | **Như đề xuất** |
| Q8 | CI cho `android/`? | Chỉ chạy tay tới hết tháng 10 | **Bật `android.yml` theo PR** (lint + test trên runner Linux); check `android` xanh **thay** `local/verify-android` cho PR không chạm `android/app/**`; PR chạm giao diện và cổng thêm `local/verify-android --ui` (emulator trên Mac) |
| Q9 | (v1.1) PDF kết quả nhúng ảnh JPEG co theo trang? | Nhúng JPEG co theo trang | **Để tới B1 mới chốt** |
| Q10 | Phân phối beta? | APK phát riêng (keystore của Nt0) | **Như đề xuất** |
| Q11 | Payload lần thi dùng đúng `AttemptRecord` v1 của macOS? | Có | **Định dạng riêng của Android**; dấu vân tay câu **dùng lại `QuestionFingerprint` của macOS** (vector chung) để quy tắc câu đã sửa sau lần thi giống hệt |
| Q12 | Ai test tay ở cổng GA2? | Nt0 + 1 học viên | **Chỉ Nt0** |
| Q13 | Android trước hay iOS trước? | Android trước khi chưa có iPhone | **Android trước** |

Ghi chú Q2 (rà 2026-10-21): Flutter cho cả hai mobile tiết kiệm khoảng hai PR so với hai bản native, nhưng lõi vẫn phải
viết lại lần nữa bằng Dart (Dart không có chuẩn hoá Unicode NFC trong thư viện chuẩn, gói zip thuần Dart đọc cả file vào
bộ nhớ, seed 64 bit không dấu qua `BigInt`), vẫn phải viết platform channel Kotlin và Swift để nhận file, cần 6–8 gói
bên thứ ba (va ADR 0006), golden test lệch theo máy dựng, và mất quyền dùng lại lõi Swift trên iOS. KMP cũng vẫn hai
lõi (macOS giữ Swift) và thêm toolchain Kotlin/Native. Cả hai bị loại vì vậy.

## Việc cần Nt0 làm một lần (môi trường)

- **Xong 2026-10-22**: JDK Temurin 17, Android SDK ở `~/Library/Android/sdk` (platform 35, build-tools 35.0.0, emulator,
  cmdline-tools trong SDK), AVD `examsuite` (Pixel 7, Android 15 arm64, khởi động không cửa sổ ~10 giây). Dùng
  `sdkmanager`/`avdmanager` trong `$ANDROID_HOME/cmdline-tools/latest/bin`: bản của Homebrew không thấy SDK ở
  `ANDROID_HOME`. Agent dùng `./gradlew` với Gradle wrapper, không cần mở Android Studio.
- Tạo keystore release và giữ ngoài git (A4).
- Mỗi lúc một việc nặng trên Mac (emulator + Gradle); luồng song song thứ hai chạy trên máy khác hoặc agent cloud
  (`:core`, `:data`, ViewModel, screenshot đều không cần emulator).

## Hướng dẫn cho agent nhận plan

1. Đọc `AGENTS.md`, `docs/WORKFLOW.md`, plan này, `docs/product/{exam-format,scoring,exam-session,exam-taking,library,accessibility-localization,large-exams}.md` (export-print.md chỉ khi làm B1), `docs/product/mobile.md` nếu đã có, mọi ADR hiện có, `docs/process/review-and-merge.md`.
2. Bảng Quyết định đã chốt 2026-10-22; bắt đầu từ A0. Quyết định nào cần đổi thì dừng, hỏi Nt0, không tự sửa bảng.
3. Mỗi bước một PR trên nhánh `feature/android-<bước>`; không push `main`, không tự merge; cập nhật exec-plan
   `docs/plans/active/android-v1.md` (v1.1: `android-v1.1.md`) trong cùng PR; không mở PR tài liệu riêng.
4. Không thêm lớp kiểm mới cho hành vi đã có lớp kiểm trong bảng Phần 4; tuân sáu quy tắc chống trùng; không viết
   script tự kiểm cho những gì Gradle, Lint, build variant đã chặn.
5. Không kéo mục v1.1 vào PR của v1, kể cả "tiện tay".
6. Gặp quy tắc sản phẩm mơ hồ hay khác giữa macOS và mobile chưa ghi ở `mobile.md`: dừng, hỏi Nt0; không tự chọn.
7. Báo cáo PR: lệnh đã chạy, số test, phần máy không kiểm được (TalkBack thật, máy thật, cài APK) cần người test tay.
