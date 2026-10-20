# UI test (XCUITest) trùng lặp và tốn giờ: finding và việc cần sửa

Ghi: 18/10/2026, từ yêu cầu của Nt0 ("thêm một tính năng bé nhưng phải chạy lại toàn bộ UI test"). Tài liệu này là
**đầu vào cho agent sửa**, không phải thẩm quyền sản phẩm; quy tắc hiện hành ở `docs/process/review-and-merge.md`
mục 2 (UI test). Mọi số đo đọc từ repo tại `main` 1832c55 (sau #53, #54), commit status `local/verify` trên GitHub và hai log
`verify_local.sh --uitest` chạy ngày 18/10/2026 (`verify-548f380.log` 09:34–09:51, `verify-2213e92.log` 12:00–12:18;
log nằm trong `build/` của worktree, không commit).

## 1. Finding

### 1.1 UI test chiếm hơn một nửa thời gian `verify_local.sh`

Log `verify-548f380` (17 phút, incremental, không `--clean`):

| Phần | Thời gian | Tỉ lệ |
| --- | --- | --- |
| `check.sh` (test ExamKit, ExamFeatures kể cả snapshot, catalog) | ~3 phút | 17% |
| xcodegen, build Debug hai app, kiểm bundle, `-exportLocalizations`, build Release hai app | ~4 phút | 23% |
| UI test Học viên: build riêng vào `build/DerivedData-UITest` + chạy 10 test (09:41:47 → 09:46:20) | ~5 phút | 30% |
| UI test Admin: build riêng vào `build/DerivedData-UITest-Admin` + chạy 6 test (09:47:07 → 09:50:29) | ~4,5 phút | 26% |
| Linux (Docker `swift:6.1`, `check.sh --core`) | ~1 phút | 6% |

Commit status trên SHA cuối của các PR gần nhất (mô tả có "N phút"):

| PR | UI test | Thời gian |
| --- | --- | --- |
| #48, #49, #50, #51, #52 (chạm giao diện) | ok, Học viên 8–9, Admin 5–6 test | 13–17 phút |
| #43, #45, #46 (chạm giao diện) | ok, Học viên 5–7, Admin 5 test | 15 phút |
| #47 (chỉ tài liệu) | bỏ qua | 8 phút |
| #39, #41 (test và script) | bỏ qua | 4–5 phút |
| #30, #31, #32, #37, #38, #40 (lõi, tài liệu) | bỏ qua | 2 phút |

9 trong 10 PR gần nhất chạm vùng giao diện nên chạy đủ bộ. Mỗi PR chạy ít nhất hai lần (trước review độc lập và trên
SHA mới sau khi sửa theo review; ghi ở Progress của plan giai đoạn 5). Trong lúc chạy không được dùng chuột, bàn phím.

### 1.2 Thời gian từng test (giây, log `verify-548f380`; cột hai là log `verify-2213e92`)

| Test | Giây | Giây (lần 2) | Ghi chú |
| --- | --- | --- | --- |
| `ExamFlowUITests.testTimedExamRandomTwenty…` | 85 | 84 | Đồng hồ nhanh 5×: thi 6 phút = 72 giây thật chờ cảnh báo 5/1 phút |
| `PracticeFlowUITests.testFirstLaunchPractice…` | 22 | 78 | Lần 2 chậm gấp 3,5 lần cùng một test (tải máy) |
| `ExportResultsUITests.testPrintOptionsCancelThenExportPDF…` | 33 | 42 | Diễn lại Trước khi thi → Bắt đầu → nộp chỉ để tới màn Kết quả |
| `ExamFlowUITests.testPauseHidesQuestion…` | 31 | 30 | |
| `EnglishInterfaceUITests.testPracticeFlowInEnglish` | 30 | 29 | Luồng 1 diễn lại bằng tiếng Anh |
| `SessionWindowRestoreUITests` (#53) | 23 | 22 | Thêm ở #53 |
| `QuitWhileConfirmingUITests` | 21 | 21 | |
| `CloseWindowUITests` | 16 | 16 | |
| `LibraryWindowRestoreUITests` | 9 | 8 | |
| `LaunchIsolationUITests` | 4 | 4 | |
| `NewExamFlowUITests.testNewExamWithImageQuestion…` | 80 | 110 | |
| `ExportExamUITests` | 54 | 52 | ⌘N → gõ câu → ⌘P → hộp Lưu |
| `ImportExamUITests` | 28 | 55 | |
| `EditExamFlowUITests.testClosingUnsavedNewExam…` | 19 | 19 | |
| `EditExamFlowUITests.testSavedExamReorderUndoRedo…` | 15 | 7 + 7 | Lần 2 **thất bại cả hai lượt** → cả status thất bại, phải chạy lại từ đầu |
| `AdminLaunchUITests` | 5 | 5 | |

Tổng chạy test: Học viên 272 s / 334 s, Admin 202 s / 255 s; cộng hai lần build riêng.

### 1.3 Ba nguyên nhân

1. **Quy tắc kích hoạt theo đường dẫn quá thô.** review-and-merge.md: UI test bắt buộc khi PR chạm
   `Packages/ExamFeatures/Sources/*Feature/**`, `*Shell/**`, `Apps/**`; `verify_local.sh --uitest` luôn chạy **cả hai
   target, mọi test**. PR #48 sửa 5 file (Thư viện trống khi cửa sổ xếp lát) vẫn chạy 6 test soạn đề của Admin; PR #49
   (PDF đề, chỉ Admin) vẫn chạy 8 test Học viên.
2. **Mỗi test là một lần mở app và diễn lại cùng đoạn mở đầu.** 7 trong 10 test Học viên (`PracticeFlow`, `ExamFlow`,
   `ExportResults`, `EnglishInterface`, `CloseWindow`, `QuitWhileConfirming`, `SessionWindowRestore`) đều đi: mở app →
   Thư viện → Trước khi thi → gõ tên → Bắt đầu → trả lời; 5 test đi tới tận Kết quả. 3 trong 5 test Admin
   (`NewExamFlow`, `ExportExam`, `EditExamFlow`) bắt đầu bằng ⌘N rồi gõ câu hỏi. Test tiếng Anh diễn lại luồng 1 trong
   khi chữ tiếng Anh đã có `check_localization.py --require-en`, test catalog từng module, 3 snapshot tiếng Anh và
   `EnglishResultsReportTests` kiểm. Mỗi tính năng mới thêm một test cùng kiểu: 5 test (16/10) → 16 test (18/10, sau #53).
3. **Hai target UI test build vào hai DerivedData riêng** (`build/DerivedData-UITest`, `build/DerivedData-UITest-Admin`),
   tức hai lần build thêm toàn bộ package, ngoài hai bản Debug (`build/DerivedData`) và hai bản Release đã build ở trên.
   Cả hai target cùng `EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest`, không có lý do phải tách.

## 2. Việc cần sửa (cho agent)

Trạng thái (2026-10-18): T1, T2, T5 làm ở bước 9 giai đoạn 5 (PR #55); T3, T4 ở bước 10 (PR "G5.10 Đóng giai đoạn 5…":
Học viên 10 → 6, Admin 6 → 4 lần mở app, đồng hồ 10× vì 15× làm luồng 2 nộp sau khi hết giờ). Số đo và lựa chọn khác
notes: plan giai đoạn 5 (docs/plans/completed/giai-doan-5-hoan-thien.md), Decisions 2026-10-18 bước 10. Tên lớp ở bảng
dưới là tên lúc ghi finding.

Xếp theo lợi ích trên công sức. T1, T2, T5 chỉ chạm script và tài liệu quy trình: **rủi ro thường**, một PR. T3, T4
chạm `Apps/**` (vùng rủi ro cao theo bảng của review-and-merge.md) và tự nó cần chạy UI test: PR riêng, review độc lập.

### T1. `verify_local.sh --uitest` chọn lớp test theo file đổi

- So file đổi với `main` (`git diff --name-only $(git merge-base origin/main HEAD)..HEAD`), map thư mục → lớp test, chạy
  `xcodebuild test` với nhiều `-only-testing:<target>/<lớp>`; target không có lớp nào thì **không build, không chạy**.
- Bảng map đề xuất (agent kiểm lại theo code thật):

  | File đổi | Lớp test |
  | --- | --- |
  | `Packages/ExamFeatures/Sources/SessionFeature/**` | `PracticeFlowUITests`, `ExamFlowUITests`, `CloseWindowUITests`, `QuitWhileConfirmingUITests`, `ExportResultsUITests` |
  | `Packages/ExamFeatures/Sources/LibraryFeature/**`, `LibraryData/**` | `LaunchIsolationUITests`, `LibraryWindowRestoreUITests`, `PracticeFlowUITests`, `AdminLaunchUITests` |
  | `Packages/ExamFeatures/Sources/ReportFeature/**` | `ExportResultsUITests`, `ExportExamUITests` |
  | `Packages/ExamFeatures/Sources/AuthoringFeature/**`, `AuthoringData/**`, `ExamImport/**`, `AdminShell/**` | mọi lớp của `ExamSuiteAdminUITests` |
  | `Packages/ExamFeatures/Sources/StudentShell/**` | mọi lớp của `ExamSuiteUITests` |
  | `*.xcstrings`, `InterfaceStrings`/`InterfaceLocale` | `EnglishInterfaceUITests`, `ExportResultsUITests` |
  | `Apps/UITestSupport/**`, `Apps/*UITests/**`, `project.yml`, `Packages/ExamFeatures/Package.swift`, `LibraryData/AppLaunchStorage.swift`, `scripts/verify_local.sh` | **đủ bộ cả hai target** |
  | Có `--clean` (cổng) hoặc cờ mới `--uitest-all` | đủ bộ |

- Tự kiểm: mọi file `Apps/*UITests/*UITests.swift` phải có mặt trong map; lớp mới chưa map → chạy đủ bộ và in cảnh báo
  (không thất bại), để không ai quên mà cũng không chặn.
- Status: giữ dạng "UI test ok (Học viên N, Admin M test, kho thật không đổi…)" nhưng N, M là số test **đã chạy**, thêm
  "theo file đổi" hoặc "đủ bộ" ngay sau; mô tả vẫn ≤ 140 ký tự (phần có thể cắt để cuối).
- Giữ nguyên: so kho/defaults thật trước–sau, kiểm Autosave, báo cáo crash, chính sách chạy lại một lần, kiểm
  LSHandlerRank (chỉ với app đã build).
- Tiêu chí đạt: PR chỉ chạm `LibraryFeature` ra status ghi đúng các lớp Thư viện, tổng `verify_local.sh --uitest`
  ≤ 9 phút trên máy của Nt0; đối chứng âm: đổi một file trong `Apps/UITestSupport/` thì chạy đủ bộ; `--clean` chạy đủ bộ.

### T2. Build một lần cho UI test

- Hai target `.uitest` dùng chung `build/DerivedData-UITest`; `xcodebuild build-for-testing` một lần cho mỗi scheme rồi
  `test-without-building` với `-only-testing`. Bỏ `build/DerivedData-UITest-Admin`.
- Sửa đường dẫn trong `doc_rank_problems` (hai app cùng thư mục Products, khác tên) và các chỗ khác trong
  `verify_local.sh`, `AGENTS.md` (bảng Lệnh kiểm chứng ghi hai thư mục DerivedData).
- Tiêu chí: `check_release_strings.sh` và kiểm LSHandlerRank vẫn tìm được hai app `.uitest`; thời gian bước UI giảm
  thêm khoảng một lần build incremental (đo và ghi vào PR).

### T3. Gộp test chung đoạn mở đầu (PR riêng, rủi ro cao)

- `ExportResultsUITests` nối vào đuôi `PracticeFlowUITests` (sau Kết quả: ⌘P → Esc → Xuất PDF… → hộp Lưu vào thư mục tạm
  → đọc lại PDF). Hai điều kiện riêng của test xuất PDF phải giữ: `-AppleLocale en_US` (kiểm ngày giờ theo ngôn ngữ giao
  diện, bước 7a) và `-NSNavLastRootDirectory`; luồng 1 không bị ảnh hưởng khi có hai tham số này.
- `QuitWhileConfirmingUITests` và `CloseWindowUITests` nối vào `ExamFlowUITests.testPauseHidesQuestion…` (sau khi tiếp
  tục: ⌘Return → Nộp → hộp "Vẫn nộp?" → ⌘Q không thoát → Quay lại; rồi ⌘W → "Bỏ bài?" → Tiếp tục làm giữ đáp án; rồi đi
  tiếp tới hết giờ).
- `EnglishInterfaceUITests` rút còn Thư viện và Trước khi thi (hai màn, `expectNoVietnamese`, nhãn thẻ, dòng tóm tắt);
  phần Làm bài/Kết quả/Xem lại tiếng Anh đã có snapshot `attemptPracticeEnglish`, `resultsEnglish`, `answerReviewEnglish`
  và `EnglishResultsReportTests`. Nếu Nt0 muốn giữ kiểm menu "Attempt" tiếng Anh thì giữ tới màn Làm bài rồi dừng.
- `ExportExamUITests` nối vào đuôi `NewExamFlowUITests` (đề mới đã có câu; ⌘P → hộp chọn chọn sẵn Chỉ đề → Esc → Tệp ›
  Xuất PDF… → hộp Lưu vào thư mục tạm).
- Mỗi đoạn gộp bọc trong `XCTContext.runActivity(named:)` để log và ảnh chụp khi lỗi chỉ đúng bước. Kết quả mong đợi:
  Học viên 10 → 6 lần mở app, Admin 6 → 4; cập nhật bảng "Bất biến đã mã hoá" của AGENTS.md (tên test) và
  review-and-merge.md.

### T4. Đồng hồ nhanh hơn ở luồng 2 (cùng PR với T3)

- `ExamFlowUITests.timeScale` 5 → 10–15. Ở 15×: cảnh báo 5 phút sau ~4 giây, 1 phút sau ~20 giây, hết giờ ~24 giây;
  các `expectBanner(within:)` và `Thread.sleep` trong test tạm dừng chỉnh theo. Chạy 3 lần liền để chắc không chập chờn
  trước khi chọn hệ số; vẫn chập chờn thì giữ 5× và ghi lại.

### T5. Quy trình (cùng PR với T1, T2)

- review-and-merge.md mục 2: "UI test bắt buộc ở PR chạm giao diện" → "chạy **các lớp test bị ảnh hưởng** theo bảng map
  của `verify_local.sh`; đủ bộ khi chạm hạ tầng chung, ở cổng (`--clean --uitest`) và khi người duyệt yêu cầu
  (`--uitest-all`)". Sau khi sửa theo review độc lập mà không đổi vùng giao diện khác, chỉ cần chạy lại các lớp đã map.
- AGENTS.md: dòng `verify_local.sh --uitest` trong bảng Lệnh kiểm chứng và các câu "mỗi target một thư mục DerivedData".
- Không đổi: CI GitHub, branch protection, chính sách bằng chứng trên SHA cuối, so kho thật.

## 3. Không nên làm

- Không bỏ hẳn XCUITest cho ⌘Q khi có sheet, đóng cửa sổ khi chưa nộp, hộp Lưu của macOS, Finder: đó là những thứ chỉ
  app thật mới kiểm được (plan giai đoạn 5, Decisions về #45).
- Không thay test UI bằng cách thêm lớp kiểm mới (script, test đối chứng) cho cùng hành vi; mục tiêu là bớt lớp, không thêm.
- Không tăng `-test-iterations` hay nới `waitForExistence` để che chập chờn; test thất bại hai lượt (`EditExamFlow`
  12:18 ngày 18/10) là lỗi cần tìm nguyên nhân.
