# Rà soát cách làm bản macOS (căn cứ tối ưu cho các giai đoạn sau và cho bản mobile)

Ghi: 18/10/2026 trong bản đầu của [plan-android-v1.md](../product/plan-android-v1.md); tách thành tài liệu riêng
21/10/2026 (Nt0 yêu cầu: plan chỉ giữ kế hoạch, phần rà soát để ở `docs/notes/`). Là **đầu vào** cho
[process/review-and-merge.md](../process/review-and-merge.md) mục 4 (nhịp làm việc) và cho hai plan mobile
([plan-android-v1.md](../product/plan-android-v1.md), [plan-ios-v1.md](../product/plan-ios-v1.md)); không phải thẩm
quyền sản phẩm. Số liệu đọc tại thời điểm ghi, không cập nhật theo `main`; cột "Android chỉ cần" / "Cách làm cho Android"
là đề xuất lúc rà soát, phiên bản hiện hành nằm trong plan.
Số liệu lấy từ repo tại `main` 290dcc8 (18/10/2026): `git log`, `gh pr list`, đếm `@Test`, `wc -l`.

## 1. Tốc độ và hình dạng công việc

| Số đo | Giá trị | Nhận xét |
| --- | --- | --- |
| Thời gian giai đoạn 0 → giữa giai đoạn 5 | 4 ngày (15–18/10) | Nút thắt không phải viết code mà là chuỗi review độc lập → `verify_local.sh --uitest` → Nt0 merge |
| PR đã merge | 52, trong đó **16 PR chỉ tài liệu/kế hoạch/CI** (31%) | #1, #8, #9, #12, #13, #17, #18, #19, #22, #27, #28, #29, #30, #36, #40, #47 |
| Commit merge chéo giữa các nhánh xếp chồng | **34** (ngoài 52 merge PR) | Giai đoạn 4–5 xếp chồng 3–4 tầng (#39 → #44 → #42 → #41 → #43…), mỗi lần merge gốc phải merge lại cả chuỗi; là nguyên nhân sự cố VS Code treo 17/10 |
| Dòng Swift: mã nguồn / test / script kiểm | 30.184 / 29.012 / 4.920 | Test ≈ 1:1 với mã; script kiểm = 16% mã nguồn (11 script, 5 script có "tự kiểm âm") |
| Số test | ≈ 1.050 (ExamKit 205, ExamFile 131, LibraryData 103, LibraryFeature 79, SessionFeature 146, ReportFeature 35, AuthoringData 44, AuthoringFeature 150, ExamImport 133, snapshot 18, XCUITest 15) | Phần Học viên (không tính Authoring*/ExamImport) ≈ 730 test |
| Quyết định ghi trong exec-plan theo giai đoạn | 9 · 5 · 13 · 23 · 26 · **43** | Tăng dần; giai đoạn 5 có ~31 lượt nhắc "review độc lập" |

## 2. Bước bị chia quá nhỏ

| Bằng chứng | Chi phí | Cách làm cho Android |
| --- | --- | --- |
| Giai đoạn 1 tách model / chấm điểm / chọn câu / kiểm đề thành 4 PR (#2 +562, #3 +514, #4 +667, #5 +1.003 dòng), đều vùng rủi ro cao | 4 lượt review độc lập cho ~2.700 dòng cùng một "lõi thuần" dùng chung fixture | **Một PR lõi** (A1) có một lượt review độc lập |
| Spike thành PR riêng chỉ để ghi kết luận (#30 `.vce`, #40 PDF/String Catalog) | 2 PR, 2 lượt duyệt, không có code | Kết luận spike ghi vào mục Decisions của exec-plan **trong PR code kế tiếp** |
| Đóng giai đoạn và lập kế hoạch giai đoạn sau tách 2–3 PR (#18/#19; #27/#28/#29 trong một ngày; #47) | 7 PR tài liệu | **Một exec-plan cho cả Android v1**; cập nhật Progress/Decisions ngay trong PR code; đóng plan ở PR cuối |
| PR vá nhỏ tách riêng: #20 đề mẫu +428, #22 "chốt phương án" +15 dòng, #9 CI timeout +6 dòng | Mỗi PR một vòng duyệt | Đi kèm PR code gần nhất cùng vùng |
| Tiếng Anh để tới giai đoạn 5 rồi phải làm 3 PR xếp chồng (#50 +2.990, #51 +7.778, #52 +16.900 dòng, chạm 54–156 file mỗi PR) | 3 lần `verify --uitest`, 3 review, sửa lại gần như mọi view | **Song ngữ từ PR đầu**: Android chỉ có một cơ chế chuỗi (`strings.xml`), không có vấn đề "quên bundle" |

## 3. Test trùng lặp

| Hành vi | Số lớp đang kiểm cùng một thứ trên macOS | Vì sao có | Android chỉ cần |
| --- | --- | --- | --- |
| Chữ giao diện có trong catalog, đủ `en` | **8**: `LocalizationTests` ở 4 module, `CatalogLanguagesTests`, `check_localization.py` (6 luật, `--freshness`, `--built-apps`, `--require-en`), `-exportLocalizations` trong `verify_local.sh`, `EnglishResultsReportTests`, 3 snapshot tiếng Anh, `EnglishInterfaceUITests` | SwiftPM + String Catalog không bắt được chuỗi quên `bundle:`; phải tự viết máy quét và test đối chứng ở mọi tầng | **1 lớp**: Android Lint (`HardcodedText`, `MissingTranslation`, `ExtraTranslation`) chạy trong `gradlew lint`; cộng 1 test đọc vài chuỗi `en` qua `Resources` |
| Kiểm đề cùng kết luận với script | `validate_exam.py` + `check_validator_parity.py` + `ExamValidatorParityTests` + `ExamFileVerdictTests` + `ExamValidatorTests` (33) + `ExamPackageValidationTests` (9) + `ExamValidatorArgumentTests` | Oracle đa nền tảng là đúng; nhưng 3 suite Swift kể lại cùng tình huống của `fixtures/invalid` | **1 test tham số hoá** đọc `fixtures/expected-verdicts.json` (16 fixture sai + 3 đúng); tình huống ngoài fixture mới viết test riêng |
| Hiệu năng đề lớn | 9 file test `Timing`/`Performance` chạy ở **mọi PR** trong `swift test` Debug, `LargeExamSupport` 731 dòng, `measure_large.sh`, `gen_large_exam.py --check`, `StandardExamTests`, `GeneratedPackageTests` | Ngân sách đo ở Debug chập chờn theo tải máy; đã phải chốt "so lần nhanh nhất của N lần" để bớt chập chờn | Module `:benchmark` chạy **tay/nightly**, không chặn merge; đọc file `.exam` do `gen_large_exam.py` sinh (đã có, cùng đề chuẩn) |
| PDF | 10 file, ~100 test cho hai luồng gần giống nhau (`ResultsReportFlow` và `ExamReportFlow`; review #49 đã ghi "máy trạng thái trùng, cần gộp") + 2 UI test + 2 test đo | Hai luồng viết ở hai thời điểm | PDF hoãn sang v1.1 (B1); khi làm: một luồng, dùng lại bộ dựng mục xem lại của màn Xem lại nên luật ẩn/hiện chỉ test một lần (~5 test khối), PDF chỉ smoke (số trang, mở được) |
| Cùng một luồng làm bài | 3 lớp: model (`SessionFeatureTests` 146) + snapshot (18) + XCUITest (15), và mỗi PR giao diện phải chạy lại `verify_local.sh --uitest` trên Mac của Nt0 (máy không được đụng tới) | Hợp lý về nguyên tắc; đắt vì XCUITest cần quyền Accessibility, so kho thật trước–sau, kiểm Autosave, báo cáo crash, chạy lại; mọi PR chạm giao diện chạy đủ 16 test của cả hai bản, 7/10 test Học viên diễn lại cùng đoạn mở đầu ([notes/g5-ui-test-trung-lap.md](g5-ui-test-trung-lap.md)) | Model test (JVM, nhanh) + **3 lần mở app trong Compose test** (luồng 1; luồng 2 mở đầu bằng Intent `.exam`; luồng 3 đồng hồ nhanh) + screenshot test Compose Preview sáng/tối; emulator chạy headless, agent tự chạy được |
| Cách ly dữ liệu thật khi test | `AppLaunchStorage` (15 test, 464 dòng), `UITestSupport` 327 dòng, `check_release_strings.sh`, so cây Application Support/defaults/Autosave, kiểm bundle ID `.uitest` | Bản Debug macOS dùng chung kho với bản cài; sự cố 15/10 agent ghi lần thi giả vào kho thật | **Không cần**: emulator có dữ liệu riêng, Test Orchestrator `clearPackageData`; bản debug có `applicationIdSuffix ".debug"` nên không bao giờ chạm dữ liệu bản cài trên máy thật |
| Ranh giới hai bản app | `check_boundaries.py` (8 luật) + `check_bundle_boundary.sh` (`nm` hai binary) + kiểm `Package.resolved`/project.yml | Hai app từ một codebase, SwiftPM không chặn phụ thuộc gián tiếp | Chỉ một app; ranh giới `:core` không import Android do **đồ thị Gradle** (module JVM không có Android SDK) chặn lúc biên dịch |

Kết luận rút ra: phần lớn "chi phí kiểm" của bản macOS là chi phí **bù cho công cụ** (String Catalog trong SwiftPM,
Debug dùng chung kho, XCUITest cần quyền máy), không phải chi phí của sản phẩm. Trên Android, Gradle, Lint, emulator và
build variant đảm nhận các việc đó sẵn, nên không chép hạ tầng kiểm sang.

## 4. Song song: đã làm và nên làm

- Đã làm: mỗi giai đoạn có 2–3 bước đầu chạy song song (G2: data + đề mẫu; G4: AuthoringData + ExamImport + spike;
  G5: spike + đo + snapshot). Phần lớn lợi ích bị ăn mất bởi xếp chồng nhánh (34 merge chéo) và việc chạy nhiều build
  cùng lúc trên một Mac (VS Code treo).
- Cho Android: chỉ song song **trên hai module rời nhau, cùng rẽ từ `main` sau khi bước phụ thuộc đã merge**, không
  xếp chồng quá một tầng; tối đa 2 luồng; mỗi lúc một việc nặng (build/emulator) trên Mac của Nt0, luồng thứ hai chạy
  trên máy khác hoặc agent cloud (Linux build được mọi thứ trừ emulator).

