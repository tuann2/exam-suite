# Execution Plan: Giai đoạn 5 · Báo cáo, hoàn thiện

Date: 2026-10-16

## Status

Completed (đóng 2026-10-18 trong PR bước 10 "G5.10 Đóng giai đoạn 5…", nhánh `feature/g5-dong`; lập 2026-10-16).
Giai đoạn 5 không có cổng. Merge vào `main`: #36, #39–#41, #43–#46, #48–#55 (và #56, tài liệu của Nt0); chỉ còn PR
bước 10 (#57) chờ merge, sau cổng `verify_local.sh --clean --uitest` trên SHA cuối của nó do người điều phối chạy (xem
Result). Giai
đoạn 6: [giai-doan-6-beta-rieng.md](giai-doan-6-beta-rieng.md).

## Outcome

Cả hai bản app xuất PDF và in **kết quả** (kèm phần xem lại tuỳ chọn, đúng quy tắc `hideAnswers` và câu đã sửa); bản
Admin xuất PDF và in **đề** (có hoặc không đáp án). Giao diện có **tiếng Việt và tiếng Anh** qua String Catalog, đạt
mục tiêu **VoiceOver** theo màn, **Dark Mode** đạt tương phản, bố cục giữ ở 960×640; đề 2.000 câu có ảnh đạt ngân sách
hiệu năng đã duyệt. Giai đoạn 5 không có cổng (plan-macos-v1.md, Lộ trình); cổng G3 ở giai đoạn 6 (beta riêng).

## Context

- Thẩm quyền sản phẩm (viết cho giai đoạn này, mục "Phương án đã chốt" ở cuối mỗi file):
  [export-print.md](../../product/export-print.md),
  [accessibility-localization.md](../../product/accessibility-localization.md),
  [large-exams.md](../../product/large-exams.md). Quy tắc hiển thị kết quả/xem lại: exam-taking.md (phương án 4, 12,
  13, 18); tương phản: library.md phương án 8; soạn đề: authoring.md.
- Lộ trình: plan-macos-v1.md "Báo cáo, hoàn thiện: PDF kết quả và đề, in, VoiceOver, Dark Mode, tiếng Việt/Anh, tối ưu
  đề lớn"; Kiểm thử: snapshot sáng/tối (câu dài, 8+ lựa chọn, ảnh lớn, nhiều section, 960×640); kiểm tay mỗi beta:
  VoiceOver, Dark Mode, màn hình ngoài.
- ADR 0003 (PDF đề chỉ bản Admin), 0006 (không thư viện mới khi chưa có ADR), 0008 (lõi không đổi vì dịch),
  **0010 (snapshot test bằng swift-snapshot-testing, chỉ trong test; Accepted 2026-10-16)**.
- Việc chuyển từ trước: String Catalog (giai đoạn 1–4 đều hoãn tới đây; chuỗi đã viết qua `LocalizedStringKey` /
  `String(localized:)` nhưng **chưa chỉ bundle của module**, và lõi/LibraryData/ExamImport có khoảng 500 chuỗi tiếng
  Việt trơn); test tay VoiceOver và Dark Mode (giai đoạn 3, 4). Lọc cây đề khi tìm (review #34 mục 4) đã sửa trong
  #34 (`TreeSearchIndex`): đề 2.000 câu, Debug, khoảng 1,2–1,3 ms mỗi lần gõ, lần tìm đầu khoảng 28–35 ms.
- Phụ thuộc giai đoạn 4: bước 5b (UI test Admin luồng 4, 5), 6 (bộ đọc `.vce`), 7 (cổng G2) có thể chạy song song với
  bước 1–3 dưới đây; bước chạm giao diện của giai đoạn 5 nên chờ #34/#35 merge để tránh xung đột.
- Quy trình: docs/process/review-and-merge.md (`local/verify` trên SHA cuối, UI test bắt buộc ở PR chạm giao diện qua
  `scripts/verify_local.sh --uitest` do Nt0 điều phối, không kích hoạt Actions, review độc lập cho PR rủi ro cao).

## Scope

In scope: PDF/In kết quả (hai bản), PDF/In đề (Admin), String Catalog vi/en cho toàn bộ chữ giao diện, VoiceOver theo
bảng mục tiêu, Dark Mode/tương phản, cỡ chữ nội dung ⌘+/⌘−/⌘0, bộ đo và tối ưu đề lớn, snapshot test (ADR 0010), kiểm
tự động mới (catalog, PDF không lộ đáp án, audit trợ năng).

Out of scope: DMG, hướng dẫn cài, sửa lỗi beta (giai đoạn 6); Sparkle; mô tả ảnh cho VoiceOver (cần `formatVersion`
mới); bảng đáp án gom cuối đề; Page Setup riêng; dịch nội dung đề hay đề mẫu; bảng màu riêng cho Increase Contrast.

## Approach

Mỗi bước một PR trên nhánh `feature/g5-<bước>`. Bước 1, 2, 3 chạy song song. Bước 4 (catalog) chạm gần như mọi view
nên chạy **một mình** (không PR giao diện nào khác đang mở); 5–9 dựng trên 4. "UI test" = cần `local/verify` có "UI
test ok" (`verify_local.sh --uitest`, Nt0 chạy).

1. **Spike kỹ thuật** (giới hạn thời gian; PR chỉ tài liệu, code thử không merge). Ghi kết luận vào Decisions:
   - PDF: cách A của export-print.md trên đề chuẩn 2.000 câu: đo dựng trang, bộ nhớ, PDFKit đọc lại chữ tiếng Việt,
     khối quá cao, ảnh giải mã đồng bộ; không đạt thì thử B, báo Nt0.
   - String Catalog trong Swift package: `defaultLocalization`, `bundle: .module` hay `#bundle` (chạy được với macOS
     15?), catalog có được biên dịch trong `swift test` và `xcodebuild`, cách phát hiện chuỗi chưa vào catalog
     (`-exportLocalizations` hay đồng bộ khi build), cách bắt `Text`/`String(localized:)` quên bundle.
   - Rủi ro thường. UI test: không.
2. **Bộ đo đề lớn** (large-exams.md): bộ sinh đề chuẩn có seed trong test support dùng chung, `scripts/gen_large_exam.py`,
   test `Timing` cho Thư viện, Bắt đầu/đổi câu/nộp, Xem lại, Soạn đề (gõ khi đang tìm), giới hạn chặn Debug;
   `scripts/measure_large.sh` (Release). Ghi số đo đầu vào Progress. Mục nào vượt ngân sách chuyển thành việc của bước 9.
   Rủi ro thường. UI test: không (chỉ test và script).
3. **Snapshot test** (ADR 0010 đã duyệt 2026-10-16): swift-snapshot-testing `from: "1.19.6"`, product `SnapshotTesting`
   chỉ trong test target của ExamFeatures, ghi vào ADR 0006, luật `check_boundaries.py` + đối chứng âm, helper chụp `NSHostingView` sáng/tối ở 960×640, ảnh đầu: câu dài, 8+ lựa
   chọn, ảnh lớn, bảng câu hỏi nhiều phần, Kết quả, Xem lại, Thư viện, cửa sổ soạn đề. **Rủi ro cao** (chạm
   `Packages/ExamFeatures/Package.swift`): review độc lập. UI test: chỉ khi phải sửa view để chụp được (ví dụ ảnh giải
   mã đồng bộ).
4. **String Catalog: hạ tầng và tiếng Việt nguồn**: `defaultLocalization: "vi"`, catalog từng target, chỉ rõ bundle ở
   mọi chuỗi giao diện (theo kết luận bước 1), `CFBundleDevelopmentRegion`/`knownRegions` và `InfoPlist.xcstrings`
   (project.yml), `scripts/check_localization.py` (chế độ chưa đòi `en`) vào `check.sh`, bước phát hiện chuỗi chưa vào
   catalog trong `verify_local.sh`. Test khoá ngôn ngữ bằng `LocalizedStringResource(…, bundle: .module)` + `.locale`
   (accessibility-localization.md mục Kiểm, đã sửa theo spike): `swift test` mặc định ra `en` khi catalog có `en`, và
   `locale` của `String(localized:bundle:locale:)` không chọn ngôn ngữ; bước 4 thêm hàm trợ giúp test và chọn cách sửa
   các test đang so chữ tiếng Việt trước bước 7 (notes/g5-spike-pdf-l10n.md). Lõi chưa đổi. Không đổi chữ nào của app;
   ngoại lệ (Nt0 xác nhận 2026-10-17, Decisions): chữ do macOS vẽ (menu chuẩn, hộp Mở/Lưu, tên "Untitled" của tài liệu
   mới, nút mặc định của AppKit) theo ngôn ngữ app chọn nên có thể hiện tiếng Việt. **Rủi ro cao** (project.yml,
   `Apps/**`, Package.swift): review độc lập. UI test: có (mọi luồng hiện có phải xanh, chứng minh không đổi hành vi).
5. **PDF và In kết quả** (hai bản): model báo cáo thuần (quy tắc ẩn/hiện của export-print.md), bộ dựng trang + PDF
   (target mới dùng chung, ví dụ `ReportFeature`), hộp chọn, `NSSavePanel`, In qua PDFKit, menu Tệp, tiến độ/Huỷ; test
   PDFKit (không lộ đáp án `hideAnswers`, câu đã sửa không có "Bạn chọn", A4, chữ tiếng Việt); bất biến mới. Có thể tách
   5a (bộ dựng trang + phần kết quả) và 5b (phần xem lại). **Rủi ro cao** (Package.swift; quy tắc lộ đáp án): review độc
   lập. UI test: có, thêm test Học viên: Kết quả → Xuất PDF → lưu vào thư mục tạm của chế độ cô lập → file tồn tại; không
   mở hộp In thật. Chế độ cô lập đặt thư mục mặc định của hộp lưu trong thư mục tạm.
6. **PDF và In đề (Admin)**: model đề → khối (thứ tự file, hai kiểu), dùng bộ dựng trang của bước 5, menu Tệp của cửa sổ
   soạn đề, dòng cảnh báo lỗi/`hideAnswers`; code trong `AuthoringFeature`; `check_bundle_boundary.sh` vẫn 0 ký hiệu
   ở bản Học viên. Test PDFKit (bản Chỉ đề không có "Đáp án đúng"). Rủi ro thường (không chạm lưu file soạn đề), trừ khi
   phải sửa Package.swift. UI test: có, thêm test Admin: Đề mới → thêm câu → Xuất PDF Chỉ đề vào thư mục tạm.
   Song song với 8 nếu 8 chỉ chạm Thư viện/làm bài.
7. **Tiếng Anh**: dịch mọi khoá theo bảng thuật ngữ, plural, ánh xạ lỗi lõi theo mã ở tầng giao diện (phương án 2
   của accessibility-localization.md), bật `check_localization.py` đòi đủ `en`, test bundle trả chữ tiếng Anh,
   UI test luồng 1 bằng tiếng Anh (`-AppleLanguages (en)`). Sau 5, 6 để gồm chuỗi xuất PDF. Tách ba PR, làm theo thứ tự
   (2026-10-17):
   - **7a Định dạng theo ngôn ngữ giao diện** (Nt0 chốt 2026-10-17): số (ngăn nghìn: "Trang 1.175/1.175", "Câu
     1.234/2.000"), phần trăm và ngày giờ theo locale của **ngôn ngữ giao diện**, không theo Region của macOS, cho mọi
     màn và PDF/In (quy tắc sẵn có của accessibility-localization.md mục Ngôn ngữ); trước 7a app theo Region
     (`String(localized:bundle:)`, `FormatStyle` mặc định). Test khoá vi/en không phụ thuộc Region; luật quét
     `region-locale`. Không đổi chữ, không đổi lõi. Rủi ro thường. UI test: có (Xuất PDF kết quả với Region `en_US`).
   - **7b Dịch lỗi lõi theo mã** ở tầng giao diện (phương án 2): lỗi/cảnh báo của ExamKit, ExamFile, LibraryData,
     AuthoringData, ExamImport ra chữ của catalog, số trong đó theo ngôn ngữ giao diện. **Rủi ro cao** (thêm mã và đối số
     vào ExamKit/ExamFile): review độc lập. UI test: có.
   - **7c Tiếng Anh**: bản `en` của mọi khoá theo bảng thuật ngữ, plural, `--require-en`, UI test luồng 1 tiếng Anh, tên
     kiểu tài liệu tiếng Việt ("Đề Exam Suite") trong `InfoPlist.xcstrings`. **Mọi catalog có `en` cùng lúc** (review
     độc lập #50 N2): ngôn ngữ định dạng (`InterfaceLocale.current`) chọn theo catalog của LibraryFeature, nên catalog
     nào thiếu `en` sẽ ra chữ tiếng Việt kèm số dạng tiếng Anh; `--require-en` đòi đủ ở mọi catalog. **Tên mặc định app
     ghi vào nội dung đề** ("Đề mới", "Phần 1", "Phần N" khi thêm phần ở AuthoringData `ExamDraft`, "Phần chung" của
     ExamImport `ImportDefaults`) theo ngôn ngữ giao diện lúc tạo: tiếng Anh "New Exam", "Section 1"; sau khi tạo là nội
     dung đề, không dịch lại (Nt0 chốt 2026-10-17). **Ghi chú cho người dịch** (review độc lập #51 N-f): vài câu của
     import `.vce` ghép từ cụm có khoá riêng nối bằng dấu câu (`AuthoringMessages.phrase(_: RVFSkip)`: loại mục RVF +
     " (lý do)" + "; phần còn lại bị bỏ qua"; mục `.unsupportedContent`: "<tên trường>: <mục>; <mục>" đặt vào câu "Bỏ qua
     nội dung chưa hỗ trợ trong %@…"; danh sách tên trường, cặp mojibake): dịch từng cụm sao cho ghép lại vẫn đọc được,
     không đổi dấu nối. Rủi ro thường. UI test: có.
8. **Trợ năng và Dark Mode**: lấp chỗ thiếu theo bảng mục tiêu VoiceOver; `performAccessibilityAudit` trong UI test hai
   bản (phương án 7; ghi ngoại lệ); test tương phản cho mọi bảng màu và nền mờ; Reduce Transparency; cỡ chữ
   nội dung ⌘+/⌘−/⌘0 (phương án 5); snapshot tối các màn chính. Rủi ro thường. UI test: có. Tách hai PR xếp chồng
   (2026-10-18):
   - **8a Bố cục, Dark Mode, PDF, cửa sổ xếp lát**: vấn đề bố cục snapshot tìm ra ở bước 3 (sửa, hoặc chứng minh là do
     cách chụp); rà chữ nhiều dòng ngoài vùng cuộn và UI test cửa sổ xếp lát; snapshot tối còn thiếu của các màn chính;
     PDF tắt chữ ghép, snapshot trang 1 PDF; sửa nhỏ của re-review #52; tài liệu hoá bẫy build incremental.
   - **8b Trợ năng**: VoiceOver theo bảng mục tiêu, `performAccessibilityAudit`, test tương phản mọi bảng màu và nền mờ,
     Reduce Transparency, cỡ chữ nội dung ⌘+/⌘−/⌘0.
9. **Tối ưu đề lớn + tăng tốc UI test** (PR "G5.9 Tối ưu đề lớn", nhánh `feature/g5-toi-uu`, dựng trên #54; một PR,
   viết lại 2026-10-18 theo Nt0, Decisions cùng ngày):
   - Đề lớn: sửa các mục vượt ngân sách từ bước 2 (lần gõ đầu vào ô tìm của Soạn đề: dựng chỉ mục tìm nền khi mở cửa sổ,
     gỡ `withKnownIssue`), đo thêm (main actor khi nộp, đường In, PDF đề chỉ đề), đo lại cỡ file PDF và nêu phương án
     cho Nt0 (không đổi nén ảnh), `measure_large.sh` (Release) cuối bước; gộp máy trạng thái Xuất PDF/In
     (`ReportFlowRunner`, review #49); sửa nhỏ của review #54 (Lịch sử thi, ngoại lệ `parentChild`).
   - T1, T2, T5 của [notes/g5-ui-test-trung-lap.md](../../notes/g5-ui-test-trung-lap.md): `verify_local.sh --uitest`
     chọn lớp theo file đổi (`scripts/uitest_plan.py`, `--uitest-all`, `--uitest-plan`, tự kiểm trong `check.sh`), hai
     target UI test dùng chung `build/DerivedData-UITest` (`build-for-testing` + `test-without-building`),
     review-and-merge.md mục 2 và AGENTS.md. Kèm hai tài liệu nguồn của Nt0 (notes/g5-ui-test-trung-lap.md,
     product/plan-android-v1.md, cập nhật docs/README.md).
   - Rủi ro thường (không chạm lưu file, chấm điểm, ExamKit lõi; `LargeExamSupport` chỉ ở test). Vì đổi
     `verify_local.sh` nên lần `verify_local.sh --uitest` của chính PR này chạy đủ bộ một lần.
10. **Bước cuối giai đoạn 5** (một PR, PR cuối của giai đoạn; **rủi ro cao** vì chạm `Apps/**`):
    - T3: gộp UI test chung đoạn mở đầu (notes mục T3): Học viên 10 → 6 lần mở app, Admin 6 → 4; mỗi đoạn trong
      `XCTContext.runActivity(named:)`. `EnglishInterfaceUITests` rút còn Thư viện + Trước khi thi + màn Làm bài (vẫn kiểm
      menu "Attempt" tiếng Anh).
    - T4: đồng hồ nhanh 5× → 10–15×, chọn sau 3 lần chạy liền tại chỗ (chỉ các lớp bị ảnh hưởng); chập chờn thì giữ 5× và
      ghi lại.
    - `EditExamFlowUITests` thất bại hai lượt (12:18 ngày 18/10) mà gặp lại thì tìm và sửa nguyên nhân, không che.
    - Tài liệu (AGENTS.md: tên test trong bảng bất biến, review-and-merge.md), CHANGELOG; số đo Release cuối
      (`measure_large.sh`).
    - Cổng duy nhất: `verify_local.sh --clean --uitest` trên SHA cuối (một lần chạy đủ bộ, kiểm cả T3/T4 lẫn cổng).
    - Đóng plan này và lập exec-plan giai đoạn 6 **trong cùng PR** (không PR kế hoạch/tài liệu riêng); cài hai app cho
      Nt0 (người điều phối).
11. **Giai đoạn 6** (exec-plan riêng, lập ở bước 10): DMG + ký trong ít PR nhất có thể; CI GitHub chạy đúng một lần, chỉ
    khi Nt0 báo; cổng G3 (trình chạy test cần Automation Mode; macOS có thể hỏi xác thực).

### Cách làm (Nt0 chốt 2026-10-18, có hiệu lực ngay)

Nhịp làm việc (a)–(f) (một `verify_local.sh --uitest` mỗi PR trên SHA cuối sau review; lúc làm chỉ chạy lớp UI test đã
map; re-review chỉ rủi ro cao; xếp chồng tối đa một tầng; sửa nhỏ, spike, plan đi cùng PR code; một việc nặng mỗi lúc)
nay là quy tắc chung của dự án: thẩm quyền ở [review-and-merge.md mục 4](../../process/review-and-merge.md), không chép
lại ở đây.

## Risks And Recovery

- **Lộ đáp án qua PDF/in** (đề `hideAnswers`, câu đã sửa): mọi quy tắc nằm ở model báo cáo có test; test PDFKit đọc
  chữ trên PDF thật; review độc lập bước 5.
- **`ImageRenderer` chậm hoặc phân trang khó** với 2.000 câu: spike đo trước; dựng theo trang có nhường lượt, Huỷ; đường
  lui B (TextKit) đã ghi ở export-print.md.
- **Đổi bundle cho chuỗi làm mất chữ** (hiện khoá thay vì chữ) hoặc vỡ UI test: bước 4 không đổi chữ nào, UI test và
  snapshot phải giống trước; test `String(localized:bundle:)` mỗi module.
- **Xung đột merge** vì bước 4 chạm mọi view: chạy một mình, nhanh, ngay khi giai đoạn 4 merge xong phần giao diện.
- **Snapshot chập chờn** giữa máy/OS: ngưỡng cảm nhận, một máy tham chiếu, ghi lại trong PR riêng.
- **UI test ghi ra ngoài thư mục tạm** (hộp lưu PDF nhớ thư mục thật): chế độ cô lập đặt thư mục hộp lưu; bản `.uitest`
  dùng defaults riêng; `verify_local.sh --uitest` so kho/defaults thật trước–sau như hiện nay.
- **In ra máy in thật trong test**: test chỉ in vào file (`jobDisposition = .save`); hộp In chỉ test tay.
- Recovery: chỉ thêm tính năng và tài liệu; không đổi schema đề, payload lần thi hay kho thư viện. Mọi thứ trong git.

## Progress

- [x] 0 Tài liệu: export-print.md, accessibility-localization.md, large-exams.md, ADR 0010, plan này (PR #36, nhánh
  `docs/g5-ke-hoach`, dựng trên #35; merge #36)
- [x] Nt0 chốt phương án (2026-10-16): export-print.md 1–12, accessibility-localization.md 1–8, large-exams.md 1–3,
  ADR 0010
- [x] 1 Spike kỹ thuật (PDF, String Catalog trong package): [notes/g5-spike-pdf-l10n.md](../../notes/g5-spike-pdf-l10n.md)
  (PR "G5.1 Spike PDF và String Catalog", nhánh `docs/g5-spike`, dựng trên #36; code thử không commit). Cách A, đề chuẩn
  2.000 câu có đáp án: 928–1.022 trang, 15–18 s Release, 16–17 s Debug, bộ nhớ đỉnh ~180–200 MB, khoảng chặn lâu nhất
  52 ms/trang khi vẽ, tới 168 ms/20 khối khi đo (Debug); In ra file khổ Letter 9–12 s. Phông PDF: Nt0 chốt Helvetica
  Neue + SF Mono (Đ hoa của SF Pro đọc lại thành Ð).
- [x] 2 Bộ đo đề lớn (PR #39, nhánh `feature/g5-do-de-lon`, dựng trên #36): `scripts/gen_large_exam.py`, target
  `LargeExamSupport` (đề chuẩn `StandardExam` cùng đề với script, `Timing`/`TimingBudget`), test `Timing` (ExamFile
  đọc/ghi, ExamKit tạo đề + phiên, Thư viện thêm đề, thư viện chuẩn 50 đề + 200 lần thi: làm mới và mở lần thi cũ,
  Bắt đầu/đổi câu/nộp/bộ lọc Xem lại, Soạn đề mở/kiểm đề/gõ/tìm/lần tìm đầu/lưu), `scripts/measure_large.sh`. Số
  Release (2026-10-16, M4 Pro, commit ghi trong [large-exam-measurements.md](../../notes/large-exam-measurements.md)):
  mọi mục đo được đạt ngân sách, **trừ lần gõ đầu vào ô tìm của Soạn đề (dựng chỉ mục `TreeSearchIndex`) khoảng 42–45
  ms so với 8 ms (5,3–5,6× qua hai lần đo; Debug ~44–48 ms, vượt cả giới hạn chặn 16 ms nên test ghi là lỗi đã biết)**
  → việc của bước 9. Đáng chú ý khác: lưu đề chuẩn ~0,9 s / 3 s, Bắt đầu ~0,22 s / 1,5 s, mở lần thi cũ ~0,32 s /
  1,5 s, đổi câu ~0,45 ms / 16 ms. **Nộp bài ~81 ms / 500 ms nhưng chạy đồng bộ trên main actor nên đó cũng là thời
  gian main actor bị chặn: 81 ms so với ngân sách chặn 100 ms, sát**; bước 9 cân nhắc chuyển chấm + ghi payload ra nền.
  Sau review #39 thêm thư viện chuẩn 50 đề + 200 lần thi; số Release (đo lại 2026-10-16 trên a92aed4, sau khi merge
  #37/#38): làm mới 50 đề ~0,56 s / 5 s (main actor chặn ~15 ms / 50 ms), mở lần thi cũ với kho 200 lần thi ~0,32 s /
  1,5 s, nộp ~84 ms, lần tìm đầu ~43 ms (vẫn vượt 5,4×). Chưa đo ở bước này: mở app với thư
  viện 50 đề, cuộn, bộ nhớ (đo tay), PDF (chưa có code, bước 5–6), main actor chặn khi lưu đề.
- [x] 3 Snapshot test (PR #41, nhánh `feature/g5-snapshot`, dựng trên #36): swift-snapshot-testing 1.19.6 chỉ ở test target
  `ExamFeaturesSnapshotTests`, luật `check_boundaries.py` 5–6 (có đối chứng âm), `check_bundle_boundary.sh` kiểm hai app
  không có SnapshotTesting; 10 test, 24 ảnh PNG 1x (sáng/tối, 960×640; tổng 3,18 MB, lớn nhất 218 KB); chạy 3 lần liền
  và trong `check.sh` đều xanh; cách ghi lại ảnh: docs/process/snapshot-tests.md. Sau khi merge #42 (gồm #39, #44): ghi lại ảnh soạn đề
  và ảnh đổi theo; xem mô tả ở Decisions.
- [x] 4 String Catalog: hạ tầng, tiếng Việt nguồn: code xong (PR #44 "G5.4 Hạ tầng String Catalog (tiếng Việt là nguồn)",
  nhánh `feature/g5-string-catalog`, dựng trên #40); 547 lời gọi `localized("…")` + 119 `Text("…", bundle: .module)` ở
  LibraryFeature, SessionFeature, AuthoringFeature, AdminShell (500 khoá); `check.sh`, hai scheme, kiểm bundle,
  `build-for-testing` hai target UI test, `check_localization.py` (cả đối chứng âm trên repo) đạt. Chờ review độc lập
  và `verify_local.sh --uitest` (Nt0 điều phối) rồi mới đánh dấu xong
- [x] 5 PDF và In kết quả
  - [x] 5a Lõi PDF kết quả (PR "G5.5a Lõi PDF kết quả (ReportFeature)", nhánh `feature/g5-pdf-core`, dựng trên #40;
    chưa gắn giao diện): target `ReportFeature` (model `ReportDocument`/`ResultsReport`, bộ dựng trang A4
    `ReportRenderer`, tên file gợi ý `ReportFileName`, In `ReportPrinting`), `ResultsReport(results:review:level:…)`
    trong SessionFeature, luật 8 của `check_boundaries.py` (mục 6 trước khi merge #41), test PDFKit (`ReportFeatureTests`,
    `SessionFeatureTests/ResultsReportTests`). Sửa theo review độc lập #43 (lựa chọn quá dài tràn chân trang, ghi PDF
    thẳng ra file, giải mã ảnh ngoài main actor, nhường lượt theo thời gian, tên file cắt tên đề trước, thêm test).
    Số đo trên Mac của người điều phối (M4 Pro): tài liệu test 1–4 trang 0,01–0,4 s. Đo tạm (không commit) tài liệu
    kiểu "Xem lại tất cả" 2.000 câu theo đề chuẩn (20 phần, 5% câu 8–12 lựa chọn, giải thích 50%, **200 ảnh PNG
    1600×1000 khác nhau, ~305 KB mỗi ảnh**), ghi thẳng ra file: 1.200 trang, **12,3 s Debug / 12,6 s Release** (xếp
    trang 4,6 s), PDF 33 MB, bộ nhớ đỉnh của tiến trình test 212 MB (77 MB trước khi dựng, gồm 61 MB ảnh), khoảng chặn
    main actor lâu nhất 39–45 ms (nhịp main actor 5 ms). Số cũ "1.101 trang, 11–12 s" dùng một ảnh lặp lại, Core
    Graphics gộp ảnh giống nhau nên không đại diện; đã thay. Sau khi merge #39 + #44 (789b9eb): test `Timing`
    `standardExamResultsPDF` (SessionFeatureTests, suite đo `.serialized`; ngân sách `TimingBudget.reportResults*` của
    LargeExamSupport) làm bài và nộp đề chuẩn `StandardExam` qua `SessionCoordinator` rồi dựng PDF kết quả, mỗi lần đo
    gồm cả dựng `ResultsReport` + `document()` (re-review #43). Không có phần xem lại **~18 ms** (Debug và Release;
    giới hạn chặn 3 s). Xem lại tất cả 2.000 câu, 3 lần: **1.175 trang, trung vị 12,7 s Debug / 12,3 s Release**
    (giới hạn chặn Debug 120 s, ngân sách Release 30 s); main actor chặn lâu nhất **59 ms Debug / 44 ms Release** (chỉ
    ghi số; 83 ms Debug trước khi tra nhãn lặp lại một lần cho cả tài liệu); **PDF 108 MB** (Nt0 chốt giữ, xem
    Decisions 2026-10-17).
  - [x] 5b Giao diện (PR "G5.5b PDF và In kết quả: nối giao diện", nhánh `feature/g5-pdf-ui`, dựng trên #45 `43ff3e6`):
    nút **Xuất PDF…** / **In…** trên thanh dưới của Kết quả (cả lần mở từ Lịch sử thi), menu Tệp **Xuất PDF…** / **In…**
    ⌘P (thay nhóm in mặc định, bật ở Kết quả và Xem lại bài, tắt khi có sheet/hộp thoại); hộp chọn (sheet) **Phần xem
    lại bài** nhớ lần trước (`SessionPreferences.reportReviewLevel`, khoá `report.resultsReviewLevel`), tắt kèm lý do khi
    Xem lại không mở được; hộp Lưu (`NSSavePanel`, tên gợi ý), ghi file tạm cạnh file đích rồi `rename(2)`
    (`ReportFileWriter`); hộp In (`PDFDocument.printOperation`); sheet tiến độ có Huỷ khi dựng lâu hơn 0,3 s; hộp báo lỗi;
    VoiceOver đọc "Đã xuất PDF" (`ResultsReportFlow`, `ReportPanels`). Test: `ResultsReportFlowTests` (16),
    `ReportFileWriterTests` (8); ghi lại 4 ảnh snapshot `resultsManySections` (thanh dưới thêm hai nút). UI test Học viên
    `ExportResultsUITests` (⌘P mở hộp chọn, Esc huỷ; Xuất PDF… vào thư mục tạm, đọc lại PDF); hộp Lưu lái bằng
    `SavePanelDriver` dùng chung (Apps/UITestSupport; `AdminFlow.saveNewDocument` dùng lại, không đổi hành vi). Review độc
    lập #46 @8144c73: APPROVE (chỉ mục Low); `local/verify` có UI test xanh trên 8144c73 (Học viên 7, Admin 5). Vòng sửa
    sau review: Nt0 chốt export-print.md phương án 15–17 (tên việc in; đọc file đề lỗi lúc bấm thì báo lỗi, không
    xuất/in; bỏ thời điểm xuất khỏi PDF), L1–L6 và nit (Decisions dưới). Chờ `verify_local.sh --uitest` trên SHA mới.
- [x] Sửa sau review độc lập #42 (2026-10-17): thoát app khi đang mở sheet (PR #45 "G5: thoát app khi đang mở sheet
  (Dock, đăng xuất); quét sheet", nhánh `fix/g5-thoat-co-sheet`, dựng trên #43 `25343d2`): mọi sheet gắn
  `presentationAllowsAppTermination()`, trả mục Thoát và Apple event thoát về cho AppKit (bỏ `SessionQuitCommands` của
  #42, ⌥⌘Q trở lại), `scripts/check_quit_sheets.py` trong `check.sh`, test cờ của cửa sổ sheet thật. `check.sh`, hai
  scheme, `check_boundaries.py`, `check_localization.py` đạt. Review độc lập #45 (APPROVE, 84b989e) và `local/verify` có
  UI test xanh trên 84b989e. Sửa theo review (M1, L1–L4, nit): UI test Học viên ⌘Q khi hộp "Vẫn nộp?" đang mở
  (`QuitWhileConfirmingUITests`), sheet danh sách file không thêm được nhận lệnh đóng, bản quét đòi modifier ở cấp ngoài
  cùng của nội dung và cấm thay mục Thoát/handler Apple event thoát. Re-review APPROVE; `local/verify` xanh trên
  `43ff3e6` (`verify_local.sh --uitest`, Học viên 6 / Admin 5 test, gồm `QuitWhileConfirmingUITests` đạt)
- [x] 6 PDF và In đề (Admin) (PR #49 "G5.6 PDF và In đề (Admin)", nhánh `feature/g5-pdf-de`, dựng trên #48 `beb4b3d`):
  model `ExamReport` (AuthoringFeature: đề đang soạn → khối của ReportFeature, hai kiểu, thứ tự file), luồng
  `ExamReportFlow` + `ExamReportController` (hộp chọn Kiểu luôn chọn sẵn Chỉ đề, không nhớ; dòng "Đề còn N lỗi…", dòng
  nhắc `hideAnswers`; hộp Lưu, hộp In, tiến độ sau 0,3 s, huỷ, hộp báo lỗi; hộp của macOS dùng chung
  `ResultsReportServices`), sheet trên cửa sổ soạn đề (`check_quit_sheets.py`), menu Tệp **Xuất PDF…** / **In…** ⌘P qua
  nhóm in chung (`ReportCommandTarget`, `ReportMenuRoute` của SessionFeature). Test: `ExamReportTests` (12),
  `ExamReportFlowTests` (12), `reportMenuRoute` (SessionFeatureTests), `standardExamPDF` (`Timing`, ngân sách
  `TimingBudget.reportExamWithAnswers*`): đề chuẩn có đáp án **1.167 trang, PDF 105 MB, 10,7 s Debug** (lần nhanh nhất
  của 3; giới hạn chặn 120 s), main actor chặn lâu nhất **34 ms** (chỉ ghi số). UI test Admin `ExportExamUITests` (⌘N →
  câu → ⌘P hộp chọn chọn sẵn Chỉ đề, chọn Có đáp án, Esc → Tệp › Xuất PDF… lại là Chỉ đề → Return → hộp Lưu vào thư mục
  tạm → đọc lại PDF). Chạm `Packages/ExamFeatures/Package.swift` (AuthoringFeature, AuthoringFeatureTests thêm
  ReportFeature/SessionFeature) và `AuthoringFeature/**` nên **rủi ro cao**. `local/verify` có UI test xanh trên
  `d33cb33` (Học viên 8, Admin 6 test, gồm `ExportExamUITests`); review độc lập không có lỗi chặn. Sửa theo review
  (Decisions, bước 6): In không mở hộp In khi lần in bị huỷ đúng lúc dựng vừa xong (cả PDF kết quả), hộp của macOS
  không mở và không chờ quay vòng khi lần xuất đã huỷ, test trang 1 (phương án 19), câu chữ AGENTS.md. Chờ
  `verify_local.sh --uitest` trên SHA mới
- [x] 7 Tiếng Anh (tách 7a/7b/7c, 2026-10-17; Approach bước 7): code đủ ba phần, mỗi phần một PR xếp chồng (7a #50, 7b
  #51, 7c #52), chờ `verify_local.sh --uitest` và merge theo thứ tự
  - [x] 7a Định dạng số, phần trăm, ngày giờ theo ngôn ngữ giao diện (PR "G5.7a Định dạng số, phần trăm, ngày giờ theo
    ngôn ngữ giao diện", PR #50, nhánh `feature/g5-dinh-dang-locale`, dựng trên #49 `eae5ff0`): `InterfaceLocale`
    (LibraryFeature: locale chỉ có mã ngôn ngữ mà chữ của catalog ra, lịch Gregorian, `number`, `percent`,
    `.interfaceLocale()` cho view và scene), `InterfaceStrings.resolve` định dạng số nội suy theo nó; mọi scene của hai shell, gốc `ImageRenderer` của PDF
    và gốc snapshot gắn `.interfaceLocale()`; `LibraryFormat`/`SessionFormat`/`ResultsModel`/`ResultsReport`
    mặc định theo nó; phần trăm qua `FormatStyle`; số đứng một mình có ngăn nghìn (ô bảng câu hỏi, danh sách số câu ở
    Rà soát, cây soạn đề, "/ 2.000" ở Trước khi thi, "Số câu đúng", "Số câu"/"Số phần" của PDF đề); dung lượng ảnh trong
    lỗi của AuthoringData theo tiếng Việt. Luật `region-locale` của `check_localization.py` (có đối chứng âm). Test:
    `InterfaceLocaleTests` (7), thêm ở `SessionLocalizationTests` (2), `ReportLocalizationTests` (1 mới, 1 mở rộng),
    `ExamReportTests` (1); UI test `ExportResultsUITests` chạy Region `en_US`, PDF phải có ngày giờ nộp dạng tiếng Việt. Snapshot không đổi
    (tiến trình snapshot đã ghim `vi_VN`, cùng dạng với `vi`). `check.sh`, `build-for-testing` hai target UI test,
    `-exportLocalizations` hai scheme đạt. Thang 1000: Nt0 chốt 2026-10-17 luôn số trơn (Decisions), đã làm trong
    PR này (`InterfaceLocale.scale1000`; Lịch sử thi, Soạn đề hết "1.000"). Review độc lập #50 @767947c: không có lỗi chặn; sửa theo review (Decisions): ngôn ngữ định
    dạng theo catalog (không chỉ bundle chính), luật `region-locale` chặt hơn, luật mới `scene-locale`, lịch Gregorian,
    ghi rõ phạm vi của tham số `locale:`
  - [x] 7b Dịch lỗi lõi theo mã ở tầng giao diện (PR "G5.7b Thông báo lỗi dịch theo mã ở tầng giao diện", PR #51, nhánh
    `feature/g5-loi-theo-ma`, dựng trên #50 `537d087`; **rủi ro cao**: lõi ExamKit/ExamFile thêm mã và đối số):
    lõi: `ValidationIssue.arguments` (`IssueArguments`, ExamValidator điền cho mọi mã), `ExamFileError.invalidJSON`/
    `migrationFailed`/`writeFailed` mang `JSONProblem`/`MigrationProblem`/`WriteProblem` thay chuỗi, `ExamFileError:
    Hashable`; câu tiếng Việt của `message`/`errorDescription` không đổi chữ nào, kết luận đọc/kiểm đề không đổi
    (parity, `expected-verdicts.json` không đổi). LibraryData: `FileProblemReason` (lý do có mã cho trạng thái file,
    lỗi nhập, đề mẫu), `LibraryError`/`LibraryStoreIssue` bỏ `LocalizedError`/`message`, còn `logMessage` cho nhật ký;
    kho vẫn lưu câu tiếng Việt cũ, đọc lại là `.stored` và file có vấn đề được đọc lại một lần mỗi lần mở app.
    AuthoringData: `ExamEditError` bỏ `LocalizedError` (`logMessage`). ExamImport: `ImportIssueDetail` cho mọi mục báo
    cáo, `VceProblem`/`VceField`/`RVFSkip`/`MojibakeSummary`/`OptionShift`, `ImportError` mang chi tiết có mã, bỏ
    `LocalizedError`. Tầng giao diện: `ErrorMessages` (LibraryFeature: kiểm đề, gói đề, Thư viện; dùng chung SessionFeature,
    AuthoringFeature) và `AuthoringMessages` (AuthoringFeature: sửa đề, import); mọi chỗ hiện lỗi (dải thông báo, hộp
    báo, trạng thái thẻ và Thông tin, câu VoiceOver, thanh lỗi soạn đề, báo cáo import, Trước khi thi, Kết quả/Xem lại,
    lưu file, Thử đề này) đi qua chúng. Luật mới `core-text` của `check_localization.py`; `scene-locale` quét cả
    Apps/Student, Apps/Admin (N3). Sửa theo review #50: N1 (`.interfaceLocale()` đặt cả `\.calendar`), N3, N4
    (đối chứng âm chuỗi raw/nhiều dòng cho `code_mask`, test `catalogLanguages` trên bundle dựng tay, câu Decisions về
    nguồn ngôn ngữ). Test: `ErrorMessagesTests` (10), `AuthoringMessagesTests` (8), lõi `ExamValidatorArgumentTests` (5),
    `ExamFileProblemsTests` (4), `storedReasonIsReadAgain`, `interfaceLocaleSetsGregorianCalendar`. Snapshot không đổi.
    Review độc lập #51 @89f9a80: không có lỗi chặn (approve); sửa theo review (Decisions): luật `core-text` hết lọt và
    hết báo nhầm (đổi tên câu nhật ký của chi tiết lỗi lõi thành `logMessage`, thêm `.logName`, nhận biến khai báo kiểu
    `ValidationIssue`, không báo `ErrorMessages.message`/`AuthoringMessages.message`, bỏ hai `// l10n-ignore` của
    `PreExamIssue`), số phiên bản định dạng chữ số trơn, đơn vị "entry" cho giới hạn số entry của `.docx`, switch đủ case
    của mã kiểm đề, test id trùng với một phần, câu tài liệu về kho V1. Nt0 chốt hai câu hỏi (Decisions). Chờ
    `verify_local.sh --uitest` trên SHA mới
  - [x] 7c Tiếng Anh (PR #52 "G5.7c Bản tiếng Anh", nhánh `feature/g5-tieng-anh`, dựng trên #51 `fa49873`): bản `en` cho
    mọi khoá của năm catalog (LibraryFeature 230, SessionFeature 188, ReportFeature 36, AuthoringFeature 364, AdminShell
    5) và hai `InfoPlist.xcstrings` (tên kiểu tài liệu vi "Đề Exam Suite"), plural `one`/`other` và substitution, chuỗi
    nhiều đối số dùng số vị trí; thuật ngữ mới ở accessibility-localization.md (Nt0 duyệt 2026-10-17).
    `check_localization.py --require-en` bật trong `check.sh` (mọi chế độ) và `verify_local.sh` (kiểm plural,
    substitution, đối số theo số vị trí; `--built-apps` so chuỗi Info.plist với catalog và đòi mọi bundle catalog cùng
    `*.lproj` có `en`: review #50 N2), có đối chứng âm. Tên mặc định ghi vào đề theo ngôn ngữ giao diện lúc tạo
    (`DefaultContentNames` của AuthoringData, `sharedSectionTitle:` của ExamImport, AuthoringFeature truyền tên đã tra
    catalog). Tiêu đề Thư viện trống theo bộ lọc tách thành câu trọn vẹn (`LibraryFilter.emptyTitle`). Test: tra `en` ở
    mỗi module (kể cả plural với 1 và 2), `CatalogLanguagesTests` (N2, ưu tiên tiếng Anh ra `en` ở mọi module),
    `EnglishResultsReportTests` (PDF kết quả tiếng Anh đọc lại bằng PDFKit, nhờ `InterfaceStrings.languageOverride` chỉ
    cho test), `DefaultContentNamesTests`, `SharedSectionTitleTests`; UI test `EnglishInterfaceUITests` (luồng 1 tiếng
    Anh, `IsolatedApp(language: .english)`). Snapshot tiếng Việt: ghi lại `attemptPracticeCheckedAnswer` sáng và tối
    (thanh dưới thu gọn khi thiếu chỗ, S2: Luyện tập 960×640 có bảng câu hỏi nay Câu trước/Câu sau chỉ biểu tượng), các
    ảnh tiếng Việt khác không đổi. Review độc lập #52: approve kèm sửa; Nt0
    duyệt thuật ngữ (Decisions); đã sửa theo review (S1–S5, N1–N6; snapshot tiếng Anh làm bài/Kết quả/Xem lại bài).
    Chờ `verify_local.sh --uitest`
- [x] 8 Trợ năng và Dark Mode. **Tách 8a/8b** (người điều phối, 2026-10-18; Approach bước 8): 8a bố cục, Dark Mode,
      PDF, cửa sổ xếp lát (PR #53); 8b trợ năng (chỗ thiếu của bảng mục tiêu VoiceOver, `performAccessibilityAudit`,
      test tương phản mọi bảng màu và nền mờ, Reduce Transparency, cỡ chữ nội dung ⌘+/⌘−/⌘0), PR sau, dựng trên 8a.
  - [x] 8a Bố cục, Dark Mode, PDF không chữ ghép, cửa sổ xếp lát (PR #53 "G5.8a Bố cục, Dark Mode, PDF không chữ ghép,
    cửa sổ xếp lát", nhánh `feature/g5-bo-cuc`, dựng trên #52 `f4f24fa`): chi tiết và bằng chứng ở Decisions 2026-10-18.
    - Danh sách vấn đề của snapshot (Decisions bước 3): (b) đã sửa ở #52 (xác nhận); (d) viền ảnh câu hỏi bao đúng
      ảnh; tiêu đề phần quanh "Câu 1/40" và nhãn "Đáp án đúng" hai dòng ở xem trước Soạn đề: sửa; thanh "Thêm phần /
      Thêm câu" chồng chữ và biểu tượng cây đề gần như không thấy: do cách chụp (có bằng chứng), biểu tượng đạt
      ≥ 3:1; `GlassFlattener` vẽ chữ/biểu tượng vibrant đúng hơn (22 ảnh ghi lại). (c) cột Thư viện dạng danh sách:
      Nt0 chốt phương án A (cột Trạng thái ngay sau Tên đề; Decisions 2026-10-18), ghi lại `libraryList` sáng/tối.
    - Cửa sổ xếp lát: dải thông báo của phiên thi và lý do ở thanh nút Kết quả có độ rộng tối thiểu
      (`SessionStyle.wrappingTextMinWidth`); test đo `TiledWindowLayoutTests` (đối chứng âm trên chính view thật). Cửa
      sổ làm bài **không** dùng khung đã lưu (`.restorationBehavior(.disabled)`; thử nghiệm 2026-10-18 ở Decisions bước 8b
      chứng minh), nên không có khôi phục khung xếp lát để test; UI test
      `SessionWindowRestoreUITests` giữ tính chất đó, cộng kiểm bố cục chung (review độc lập #53 S1). Cửa
      sổ soạn đề (DocumentGroup) không có tên autosave nên không có UI test khung xếp lát; các cột của nó có trong test đo.
    - Snapshot tối/sáng còn thiếu: Trước khi thi, báo cáo import; trang 1 PDF kết quả và PDF đề (export-print.md, Kiểm
      chứng).
    - PDF tắt chữ ghép thường (Helvetica Neue; SF Mono không có); đo lại PDF đề chuẩn: không chậm hơn.
    - Sửa nhỏ theo re-review #52; tài liệu hoá bẫy build incremental (bundle tài nguyên cũ của `swift test`) và
      `verify_local.sh` tự build lại khi gặp.
    - `check.sh`, `build-for-testing` hai target UI test, `check_localization.py` (thường, `--require-en`, `--freshness`),
      `check_quit_sheets.py`, `check_boundaries.py` đạt. Chờ `verify_local.sh --uitest` (Nt0 điều phối).
    - Sửa theo review độc lập #53 (approve kèm sửa; `local/verify` có UI test xanh trên `7836992`, Học viên 10 / Admin
      6): S1–S3 và nit (Decisions 2026-10-18, mục "Sửa theo review độc lập #53").
  - [x] 8b Trợ năng: bảng mục tiêu VoiceOver, `performAccessibilityAudit` trong UI test hai bản (phương án 7), test tương
    phản mọi bảng màu và nền mờ, Reduce Transparency, cỡ chữ nội dung ⌘+/⌘−/⌘0 (phương án 5). Thêm từ review độc lập #53:
    - **Tương phản của màu ngữ nghĩa hệ thống** (đo trên ảnh snapshot sau khi sửa cách chụp chữ vibrant, Decisions
      2026-10-18): chữ `.secondary` dưới 4,5:1 ở vài chỗ (đoạn đầu nội dung câu ở thanh bên Xem lại bài (126) trên nền
      trắng 4,06:1, trên dòng đang chọn 3,72:1; dòng đang chọn ở giao diện tối 4,45:1; số đếm của thanh bên Thư viện
      4,42:1). **Nt0 chốt 2026-10-18: màu ngữ nghĩa của hệ thống được miễn** (Decisions bước 8b), không sửa.
    - Nhãn "Đáp án đúng" ở xem trước Soạn đề có `.fixedSize()` (`QuestionPreview.swift`, một dòng dưới chữ lựa chọn):
      khi thêm phóng to nội dung (⌘+, 150%) nhãn có thể tràn cột xem trước hẹp (240 pt); kiểm và cho xuống dòng khi cần.
      **Đã sửa** (xuống dòng; snapshot `authoringPreviewZoom150`).
    - Làm (PR "G5.8b Trợ năng: VoiceOver, kiểm trợ năng tự động, tương phản, Reduce Transparency, cỡ chữ nội dung", nhánh
      `feature/g5-tro-nang`, dựng trên #53 `548f380`; chi tiết ở Decisions 2026-10-18 bước 8b và accessibility-localization.md,
      ghi chú bước 8b):
      - VoiceOver: câu đọc của Kết quả, Xem lại bài, Lịch sử thi, xem trước, cây đề (chữ trơn) vào model có test; hành
        động trợ năng của thẻ có test; `.isHeader` còn thiếu; "Ảnh của câu hỏi" ở trình soạn; thông báo Import xong, kiểm
        đề có lỗi mới, lưu xong.
      - `performAccessibilityAudit` ở mọi màn của luồng UI test hai bản (`AccessibilityAuditor`); loại kiểm không có trên
        macOS: `dynamicType`, `textClipped`, `trait`. Chưa có ngoại lệ nào: lần chạy `verify_local.sh --uitest` đầu tiên
        cho danh sách vấn đề (nếu có) để sửa hoặc ghi ngoại lệ.
      - Tương phản: `PaletteContrastTests` (mọi bảng màu, nền nhạt, nền cửa sổ thật), `SessionStyleColorTests`,
        `ReportPaletteTests`, AuthoringStyle; đổi xanh sáng `#1C7631`, đỏ tối `#FF8077` (6 ảnh tối ghi lại);
        `scripts/check_colors.py` trong `check.sh`.
      - Reduce Transparency (`AdaptiveBackground`, `ReduceTransparencyTests`); Reduce Motion: cuộn lưới Thư viện.
      - Cỡ chữ nội dung ⌘+/⌘−/⌘0 (`ContentZoomCommands`, `ContentZoomTests`), snapshot 150% (5 ảnh sáng mới).
      - Sửa re-review #53 (a)–(d): (a) thử nghiệm chứng minh `.restorationBehavior(.disabled)` là nguyên nhân cửa sổ làm
        bài không dùng khung đã lưu; (b) `verify_local.sh` ghi bước tiếp theo; (c), (d) `ReportRendererTests`.
      - `check.sh`, `build-for-testing` hai target UI test, `check_localization.py` (thường, `--require-en`,
        `--freshness`), `check_quit_sheets.py`, `check_boundaries.py`, `check_colors.py` đạt. Chờ `verify_local.sh
        --uitest` (Nt0 điều phối).
- [x] 9 Tối ưu đề lớn + tăng tốc UI test (merge #55) (PR "G5.9 Tối ưu đề lớn", nhánh `feature/g5-toi-uu`, dựng trên #54 `4d7448a`):
  - Đề lớn: lần gõ đầu vào ô tìm của Soạn đề **42,95 → 0,23 ms Release** (Debug 44–48 → 0,56 ms): `TreeSearchIndex` dựng
    ngoài main actor khi mở cửa sổ và sau thêm/xoá/sắp xếp, thay đổi trong lúc dựng áp lại; test `Timing` so giới hạn
    chặn 16 ms (gỡ `withKnownIssue` và lưới an toàn); 4 test chỉ mục nền (`TreeAndNavigationTests`). Đo thêm (chỉ ghi
    số): nộp bài main actor chặn ~84 ms Release (sát 100 ms; ~610 ms Debug), đường In (tạo thao tác In ~1,4 ms; in
    1.168 trang ra file ~4,8 s trên main actor), PDF đề chỉ đề 1.077 trang 100 MB / 9,5 s. `measure_large.sh` trên
    328b956: **mọi mục đạt ngân sách Release** ([large-exam-measurements.md](../../notes/large-exam-measurements.md)).
  - Cỡ file PDF: đo lại cả ảnh thật (large-exams.md, Việc mở): đề có đáp án 27 MB với ảnh thật, 105 MB với ảnh nhiễu;
    Nt0 chốt giữ 2× không mất và đặt ngân sách cỡ file (`PDFSizeBudget`, Decisions 2026-10-18).
  - Gộp máy trạng thái Xuất PDF/In (review #49): `ReportFlowRunner`, `ReportServices` (đổi tên từ
    `ResultsReportServices`), `ReportAction` ở ReportFeature; hai luồng chỉ giữ hộp chọn riêng; không đổi hành vi (28 test
    của hai luồng đạt, chỉ đổi tên kiểu); UI test `ExportResultsUITests` (4 lần: lần đầu sau build thất bại ở "Xuất PDF…
    không mở hộp chọn", 3 lần sau đạt; ghi lại để theo dõi) và `ExportExamUITests` đạt ở chế độ cô lập.
  - Sửa nhỏ review #54: Lịch sử thi định dạng chữ mỗi dòng một lần (`HistoryView.cells(of:)`, test); ngoại lệ
    `parentChild` không phần tử chỉ khớp mô tả chi tiết đã biết.
  - T1, T2, T5 (notes/g5-ui-test-trung-lap.md): `scripts/uitest_plan.py` (bảng map, `--self-test` trong `check.sh`),
    `verify_local.sh --uitest-all`/`--uitest-plan`, chọn lớp theo file đổi, target không có lớp thì không build/chạy,
    `build/DerivedData-UITest` dùng chung (`build-for-testing` + `test-without-building`; thử một lớp mỗi scheme: build
    bản Admin vào thư mục chung 9 s vì dùng lại bản build package của bản Học viên, LSHandlerRank `None` ở cả hai app
    `.uitest`), review-and-merge.md mục 2, AGENTS.md. Hai tài liệu nguồn của Nt0 (26f9dc8).
  - `check.sh`, `check_localization.py` (thường, `--require-en`, `--freshness`), `check_boundaries.py`,
    `check_quit_sheets.py`, `check_colors.py` đạt. Chờ review và một `verify_local.sh --uitest` (đủ bộ vì đổi
    `verify_local.sh`; người điều phối chạy).
- [x] 10 Bước cuối giai đoạn 5 (PR "G5.10 Đóng giai đoạn 5: gộp UI test, đồng hồ nhanh, CHANGELOG, plan giai đoạn 6",
      nhánh `feature/g5-dong`, dựng trên #55 `f19b20f`, gộp `origin/main` để có #47; **rủi ro cao**, chạm `Apps/**`):
  - T3 gộp UI test chung đoạn mở đầu (chi tiết và số ở Decisions 2026-10-18 bước 10): **Học viên 10 → 6 lần mở app,
    Admin 6 → 4**. `ExportResultsUITests` → đuôi `PracticeFlowUITests`; `CloseWindowUITests`, `QuitWhileConfirmingUITests`
    → test luồng 3 của `ExamFlowUITests`; `LaunchIsolationUITests` → đầu `LibraryWindowRestoreUITests`;
    `EnglishInterfaceUITests` rút còn Thư viện, Trước khi thi, màn Làm bài (menu Attempt); `ExportExamUITests` →
    `NewExamFlowUITests` (trước bước lưu); `AdminLaunchUITests` → đầu test đề chưa lưu của `EditExamFlowUITests`. Mỗi đoạn
    gộp là một `XCTContext.runActivity`; giữ mọi phép kiểm và điểm kiểm trợ năng. `scripts/uitest_plan.py` (bảng map,
    EXPECTED, tự kiểm), AGENTS.md, accessibility-localization.md theo tên mới.
  - T4 đồng hồ nhanh: **10×** (15× đỏ cả 3 lần ở phép kiểm mới "nộp trước khi hết giờ"; 10× đạt 3 + 3 lần liền).
  - `EditExamFlowUITests` không thất bại lần nào trong bước này (đạt ở lần đo trước và sau khi gộp), nên không có lỗi
    để tìm nguyên nhân; vẫn theo dõi ở lần chạy cổng.
  - `measure_large.sh` cuối giai đoạn trên `b1c3e99`: mọi mục đạt ngân sách Release
    ([large-exam-measurements.md](../../notes/large-exam-measurements.md)).
  - CHANGELOG (giai đoạn 5: Added/Changed/Fixed), AGENTS.md, plan này sang `completed/`, docs/plans/README.md, plan giai
    đoạn 6.
  - `check.sh`, `check_localization.py` (thường, `--require-en`, `--freshness`), `check_boundaries.py`,
    `check_quit_sheets.py`, `check_colors.py`, `uitest_plan.py --self-test` đạt; mọi lớp UI test hai bản đạt ở chế độ cô
    lập. Review độc lập #57: approve kèm sửa (S1–S3, N1–N5 đã sửa, Decisions bước 10); còn cổng `verify_local.sh
    --clean --uitest` (người điều phối) và cài hai app cho Nt0.
- [x] 11 Giai đoạn 6: exec-plan [giai-doan-6-beta-rieng.md](giai-doan-6-beta-rieng.md) lập trong PR bước 10
  (câu hỏi mở cho Nt0: ký, phiên bản, DMG, hướng dẫn cài, phân phối/CI, biểu tượng, changelog trong app, tiêu chí G3)

## Decisions

- 2026-10-16: Tách ba tài liệu sản phẩm (xuất/in; trợ năng + ngôn ngữ; đề lớn) thay vì gộp vào exam-taking.md và
  authoring.md, vì cả hai bản app và nhiều màn dùng chung; tài liệu màn hình chỉ dẫn link.
- 2026-10-16: Lõi ExamKit/ExamFile không phụ thuộc localization (tầng giao diện dịch theo mã lỗi) để giữ ADR 0008 và test
  Linux.
- 2026-10-16: **Nt0 duyệt mọi phương án của PR #36**: export-print.md 1–12 (PDF bằng `ImageRenderer` theo khối + In qua
  PDFKit; PDF luôn A4, In co vừa khổ giấy; phần xem lại Không / Câu sai và chưa làm (mặc định) / Tất cả câu, nhớ lần
  trước; giải thích theo quy tắc Xem lại; chân trang "không có giá trị xác nhận"; nút trên Kết quả + menu Tệp, In… ⌘P;
  PDF đề hai kiểu, xuất nội dung đang soạn kể cả chưa lưu/còn lỗi, chỉ từ cửa sổ soạn đề; tên file gợi ý; không tự mở;
  `hideAnswers` xuất có đáp án kèm dòng nhắc), accessibility-localization.md 1–8 (theo ngôn ngữ macOS; dịch toàn bộ
  giao diện kể cả lỗi lõi theo mã; đề mẫu chỉ tiếng Việt; agent dịch, Nt0 duyệt thuật ngữ; ⌘+/⌘−/⌘0 cho nội dung câu;
  không bảng màu Increase Contrast; `performAccessibilityAudit` làm test thất bại; bảng mục tiêu VoiceOver là tiêu chí),
  large-exams.md 1–3 (đề chuẩn 2.000 câu 10% có ảnh; bảng ngân sách; giới hạn chặn Debug làm test thất bại, số Release
  chỉ ghi), ADR 0010 Accepted (swift-snapshot-testing `from: "1.19.6"`, chỉ test target, luật `check_boundaries.py`).
- 2026-10-16 (bước 3): Runner của snapshot test là `swift test` (bước 4 của `check.sh`, nên trong `verify_local.sh`).
  `xcodebuild test -scheme ExamFeatures-Package -only-testing:ExamFeaturesSnapshotTests` ghi ra ảnh giống hệt từng byte
  (macOS 26.6, Xcode 27.0) nhưng không phải bằng chứng; ghi lại ảnh chỉ bằng `swift test`.
- 2026-10-16 (bước 3): Cách chụp: màn SwiftUI trong `NSHostingView` làm `contentView` của `NSWindow` không lên màn hình
  (thanh công cụ và tiêu đề qua `sceneBridgingOptions`), vẽ cả khung cửa sổ bằng `CALayer.render(in:)` vào PNG 1x, so
  bằng chiến lược ảnh macOS của thư viện (`precision` 1, `perceptualPrecision` 0,98). `cacheDisplay` (chiến lược
  `NSView` của thư viện) không dùng được trên macOS 26: Liquid Glass ra khối trắng che sidebar, inspector, nút thanh
  công cụ. Kính được làm phẳng tạm khi chụp (ẩn lớp kính, tô chữ vibrant theo ma trận màu của nó); cửa sổ/app được coi
  là đang dùng; ngôn ngữ `vi_VN`, màu nhấn, thanh cuộn, cỡ biểu tượng sidebar ghim trong miền tham số của tiến trình
  (không ghi `defaults`); múi giờ Asia/Ho_Chi_Minh; dữ liệu, đồng hồ, seed cố định; không hoạt ảnh. Increase
  Contrast/Reduce Transparency bật thì test báo lỗi. Ghi lại: biến `EXAMSUITE_SNAPSHOT_RECORD` (mặc định không ghi).
- 2026-10-16 (bước 3): `Package.resolved` của ExamFeatures ghim thêm swift-custom-dump, swift-issue-reporting,
  swift-syntax (manifest của swift-snapshot-testing khai báo cho product khác); không biên dịch, không link (nm hai app
  0 ký hiệu). `check_boundaries.py` cho phép đúng các ghim này. Sửa 2026-10-17 (review #41, P3-2): chúng vẫn được tải
  ở mọi lần resolve, kể cả khi chỉ build app (thêm bản build sẵn MacroSupport của swift-syntax, khoảng 115 MB mỗi thư
  mục build); `--disable-experimental-prebuilts` bỏ được 115 MB nhưng không nhanh hơn, nên không thêm vào `check.sh`
  (ADR 0006).
- 2026-10-17 (bước 3, review độc lập #41): sửa P2-1 (cửa sổ chụp ép vẽ 2x, `scaleProblem` báo khi không ép được, test
  mô phỏng 1x), P2-2 (project.yml theo `xcodegen dump`, không có xcodegen thì ngữ pháp dòng chặt; năm dạng vượt rào
  vào đối chứng âm), P3-1 (mọi target, kể cả test, chỉ product ExamKit/ExamFile/ZIPFoundation/SnapshotTesting theo
  `describe`), P3-2 (câu chữ ADR 0006, 0010), P3-3 (ghim theo cặp identity–location, thiếu Package.resolved là lỗi),
  P3-4 (báo Invert colors, cỡ chữ hệ thống; liệt kê cài đặt không đọc được). Merge base `aec9e82` không đổi ảnh nào.
- 2026-10-16 (bước 3): Snapshot cho thấy, cần Nt0 xem trên app thật (không sửa trong bước này vì chạm view, cần UI
  test): (a) cửa sổ soạn đề ở 960×640 bị cắt hai bên: split view giữ độ rộng lý tưởng (cây 300 + trình soạn 780 +
  xem trước 360 ≈ 1.448) thay vì co về tối thiểu, cây đề và xem trước chỉ thấy một phần; (b) cửa sổ làm bài 960×640
  có bảng câu hỏi: nhãn "Kiểm tra đáp…", "Rà soát &…" ở thanh dưới bị cắt (Luyện tập); (c) Thư viện dạng danh sách ở
  960: cột "Lần thi gần nhất", "Trạng thái" ra ngoài khung (đề "Không tìm thấy file" không thấy trạng thái nếu không
  cuộn ngang); (d) ảnh câu hỏi nhỏ hơn khung: viền bo góc bao cả khung rộng, không bao ảnh (khoảng trống có viền bên
  phải ảnh). Chuyển cho bước 8 (Dark Mode, bố cục 960×640).
- 2026-10-17 (bước 3, merge #42 `6737abc`, gồm #39, #44): (a) đã sửa ở #42 (UI test Admin xác nhận cây đề bị cắt ở
  mép trái; độ rộng cột mới): ghi lại 4 ảnh soạn đề (`authoringQuestionEditorAndPreview`,
  `authoringImageQuestionWithIssue`, sáng/tối), giờ thấy đủ ba cột ở 960×640. 20 ảnh còn lại không đổi byte nào (chữ
  qua String Catalog của #44 hiện y như trước). Ảnh mới còn cho thấy, cần xem trên app thật: thanh "Thêm phần / Thêm
  câu" ở đáy cây đề chồng lên chữ của dòng cây phía sau (có thể do cách chụp làm phẳng kính, app thật làm mờ); tiêu đề
  phần ở xem trước xuống dòng quanh "Câu 1/40", nhãn "Đáp án đúng" xuống hai dòng; biểu tượng ảnh/nhiều đáp án của
  dòng cây chưa chọn gần như không thấy ở giao diện sáng (có thể do cách tô chữ vibrant xấp xỉ). (b)–(d) còn nguyên.
- 2026-10-16: Số đo lọc cây đề khi tìm cập nhật theo #34 đã sửa (`TreeSearchIndex`); bước 9 chỉ còn đo lại Release và
  kiểm lần tìm đầu.
- 2026-10-16 (bước 2): Đề chuẩn có **hai bộ sinh cùng thuật toán**: `scripts/gen_large_exam.py` (ghi `dist/` để mở tay,
  `validate_exam.py` kiểm) và `StandardExam` trong target mới `LargeExamSupport` của gói ExamKit (product chỉ test target
  dùng; Foundation + ExamKit + ExamFile để chạy cả trên Linux). Cùng đề được chứng minh bằng vector cố định: hai bên so
  SHA-256 dạng chính tắc với cùng một file `fixtures/large-exam.digest` (`gen_large_exam.py --check` trong `check.sh`, `StandardExamTests`; cả hai có đối chứng âm, review #39). Ảnh PNG
  dùng zlib "stored" (không nén) để byte giống nhau không phụ thuộc phiên bản zlib; nhiễu xám xen kẽ 1 bit/2 bit cho
  trung bình ~300 KB như large-exams.md. Vì chạm `Packages/ExamFeatures/Package.swift` (thêm product vào ba test
  target) nên PR này là **rủi ro cao** theo review-and-merge.md và cần review độc lập, dù plan ghi bước 2 rủi ro thường.
- 2026-10-16 (bước 2): **Nt0 duyệt** cách so giới hạn chặn: test so **lần nhanh nhất** của 3 (thao tác nặng) hoặc 5
  lần với giới hạn chặn Debug của large-exams.md, trung vị vẫn in và ghi trong báo cáo Release (large-exams.md, phương
  án đã chốt 4). Mẫu gồm nhiều biến thể (các chữ tìm, mỗi chữ đã lấy lần nhanh nhất) so biến thể chậm nhất. Thao tác lặp
  (đổi câu, gõ) in thêm sự kiện đơn lẻ chậm nhất. Phần dựng kho, đề, lần thi nằm ngoài vùng đo.
- 2026-10-16 (bước 2, review #39): Lần gõ đầu vào ô tìm (dựng chỉ mục tìm) giữ giới hạn chặn **16 ms** của dòng "mỗi lần
  gõ" (Nt0 không duyệt ngoại lệ); đang đo ~44–48 ms Debug nên phép so nằm trong `withKnownIssue` ("Bước 9: dựng chỉ mục
  tìm trước…"): test xanh khi còn vượt và báo khi bước 9 sửa xong để gỡ. Main actor chặn khi Bắt đầu chỉ ghi số (bảng
  không đặt giới hạn Debug cho mục này); làm mới 50 đề chỉ đặt giới hạn cho main actor chặn (≤ 200 ms), tổng thời gian chỉ
  ghi số.
- 2026-10-16 (bước 2, review #39): Các test đo chạy việc nặng đồng bộ trên main actor (nộp, tạo 200 lần thi) nên test
  đo của SessionFeatureTests nằm chung một suite `.serialized`: chạy song song thì làm sai số main actor chặn của nhau
  (đã gặp ~0,9 s khi làm mới 50 đề). `MainActorGapProbe.start()` chờ nhịp đầu tiên rồi mới trả về, có đối chứng âm.
- 2026-10-16 (bước 2, review #39): `check_boundaries.py` mục 5: chỉ test target phụ thuộc `LargeExamSupport` (đồ thị
  hai package, product, project.yml, import trong Sources/Apps) và chính nó chỉ import Foundation, ExamKit, ExamFile,
  CommonCrypto trong `#if canImport(CommonCrypto)`; mỗi luật có đối chứng âm.
- 2026-10-16 (bước 2): Trên macOS bộ sinh Swift đặt tên ảnh bằng SHA-256 của CommonCrypto: SHA-256 thuần Swift của
  ExamFile ở Debug chỉ ~4 MB/s (~14 s cho 60 MB ảnh mỗi tiến trình test). Linux (không CommonCrypto) vẫn dùng
  `MediaNaming`, tốn thêm khoảng chừng đó trong Docker của `verify_local.sh`. `StandardExamTests` đối chiếu hai cách.
- 2026-10-16 (bước 2): `measure_large.sh` build Release với `-enable-testing -DDEBUG`: thiếu `-DDEBUG` thì
  `AppLaunchStorageTests` (dùng code chế độ cô lập chỉ có ở Debug) không biên dịch. Code `#if DEBUG` của Sources chỉ ở
  lúc mở app và đồng hồ của UI test, không nằm trên đường đo; `Timing` ghi Release/Debug theo mức tối ưu.
- 2026-10-16 (spike bước 1, chi tiết và số đo ở [notes/g5-spike-pdf-l10n.md](../../notes/g5-spike-pdf-l10n.md)):
  - **PDF giữ cách A** (`ImageRenderer` theo khối → `CGContext` PDF, In qua `PDFDocument.printOperation`): đề chuẩn
    2.000 câu có đáp án 15–18 s Release, bộ nhớ ~200 MB, trong ngân sách; không dựng cách B. Bước 5: view báo cáo riêng
    chỉ `Text`/`Image`/hình (`ImageRenderer` không vẽ `Button` mặc định, `Toggle`, `TextField`, `ScrollView`, `List`,
    không chạy `.task` nên không dùng lại `QuestionImageView`/`QuestionPreview`), gốc view `.colorScheme(.light)`, ảnh
    giải mã đồng bộ thu về ≤ 2× bề rộng vùng in, xếp trang dùng cỡ ảnh từ thuộc tính, nhường main actor mỗi trang và mỗi
    ~8 khối, khối quá cao tách theo phần với "Câu N (tiếp)", test PDFKit trên đề nhỏ.
  - **Phông của PDF:** spike thấy SF Pro làm chữ Đ (U+0110) trong PDF đọc lại thành Ð (U+00D0): tìm/sao chép chữ
    "Đ…" hỏng; TextKit (cách B) cũng vậy. Helvetica Neue (có sẵn trong macOS) và SF Mono đọc lại đúng 100%.
  - **String Catalog**: chuỗi giao diện trong package dùng **`bundle: .module`** (không `#bundle`: chỉ có từ Xcode 26,
    CI có thể chọn Xcode 16); package đi theo ngôn ngữ bundle chính chọn nên mỗi app phải có `vi` và `en` ở bundle chính
    (`InfoPlist.xcstrings`); `swift test` luôn chọn `en` khi catalog có `en` (test phải khoá ngôn ngữ bằng
    `LocalizedStringResource` + `locale`; `String(localized:bundle:locale:)` không chọn ngôn ngữ); chuỗi chưa vào catalog
    bắt bằng `xcodebuild -exportLocalizations` + `git diff --exit-code -- '*.xcstrings'` trong `verify_local.sh`; quên
    `bundle:` chỉ bắt được bằng quét mã nguồn trong `check_localization.py` (hiện 588 lời gọi phải sửa ở bước 4).
- 2026-10-16: **Nt0 chốt phông PDF: Helvetica Neue** cho chữ thân và đề mục, **SF Mono** cho mã inline (export-print.md
  phương án 13, thay "phông hệ thống SF Pro"), vì SF Pro làm chữ Đ (U+0110) đọc lại từ PDF thành Ð (U+00D0). Bước 5, 6
  dùng phông này; test PDFKit so chữ "Đ…" nguyên văn, không chuẩn hoá Ð.
- 2026-10-16: accessibility-localization.md mục Kiểm sửa câu chữ theo spike: test khoá ngôn ngữ bằng
  `LocalizedStringResource` + `.locale` (không dùng `String(localized:bundle:locale:)`, tham số đó không chọn ngôn ngữ).
- 2026-10-17 (bước 4, chi tiết ở accessibility-localization.md "Ghi chú hiện thực" và AGENTS.md "Chuỗi giao diện"):
  - **Quy ước gọi:** `Text("…", bundle: .module)` cho `Text` (giữ Markdown/nội suy của `LocalizedStringKey`); mọi API
    khác và chuỗi của model trình bày qua hàm nội bộ `localized("…")` của từng target (một dòng gọi
    `InterfaceStrings.resolve(_:bundle:)` của LibraryFeature), vì phần lớn API SwiftUI (`Button`, `Label`, `.help`…)
    không có tham số bundle và một hàm ngắn dễ đọc hơn `String(localized: "…", bundle: .module)` ở ~550 chỗ. Kiểu
    `LocalizedStringKey` bị cấm trong package (không mang bundle).
  - **Khoá ngôn ngữ trong test đặt ở `InterfaceStrings`, không sửa từng test:** bundle chính không khai báo `vi` (trình
    chạy `swift test`) thì tra bằng `LocalizedStringResource` + `locale` vi; trong app (bundle chính có vi/en) thì
    `String(localized:bundle:)` như cũ. Lý do: các test so chữ tiếng Việt đi qua model (`AttemptModel`, `ResultsModel`,
    `LibraryFormat`…), nên chỉ sửa kỳ vọng thì không đủ; khoá ở một chỗ giữ nguyên 31 file test. Bằng chứng: điền bản
    `en` giả ("EN " + khoá) cho cả 500 khoá trong bản nháp, `swift test` ExamFeatures: mọi test cũ đậu, chỉ các test mới
    khẳng định "chưa có en"/"không khoá thì ra en" đỏ đúng dự kiến; đã hoàn nguyên catalog. Phù hợp phương án 1 (không
    có ngôn ngữ khớp thì tiếng Việt). Test tra ngôn ngữ cố định qua `InterfaceStrings.resolve(_:bundle:locale:)` +
    `<Module>.ModuleStrings.bundle`.
  - **Phạm vi catalog:** LibraryFeature, SessionFeature, AuthoringFeature, AdminShell. StudentShell không có chữ giao
    diện (chỉ log); LibraryData, AuthoringData, ExamImport giữ chuỗi trơn tới bước 7. Quét "chữ tiếng Việt trơn" áp cho
    mọi target giao diện, nhờ vậy bắt thêm các nhánh `cond ? "A" : "B"`, `NSAlert`, lý do lỗi của document; chữ không
    phải giao diện đánh dấu `// l10n-ignore` (6 dòng: log, `assertionFailure`, chuẩn hoá tìm, so tên phần của đề).
  - **InfoPlist.xcstrings:** `vi` = `en` = giá trị gốc (không đổi chữ); tên kiểu tài liệu tiếng Việt để bước 7.
    `check_localization.py --built-apps` kiểm hai app có `vi.lproj`/`en.lproj` và giá trị không đổi.
  - **Catalog đủ khoá hai lớp:** `check.sh` bước 5 (`.stringsdata` của `swift test` + `xcstringstool sync` trên bản
    sao, so JSON; tự bỏ qua có ghi chú khi hệ build không ghi `.stringsdata`) và `verify_local.sh`
    (`-exportLocalizations` hai scheme vào `build/DerivedData-L10n`, rồi `git status -- '*.xcstrings'` phải sạch). Hai
    cách cho cùng kết quả trên repo; khoá chưa dùng mà không có bản dịch thì Xcode xoá hẳn (không đánh `stale`).
  - `check_bundle_boundary.sh` kiểm thêm bundle tài nguyên: bản Học viên không có `ExamFeatures_AuthoringFeature`,
    `…AuthoringData`, `…ExamImport`, `…AdminShell.bundle`.
  - **Chữ của macOS theo ngôn ngữ app:** khai báo vi/en làm menu chuẩn, hộp Mở/Lưu, nút mặc định của AppKit theo ngôn
    ngữ app chọn (trước đây luôn tiếng Anh). Máy test UI (en-VN) không đổi; máy ưu tiên tiếng Việt sẽ thấy các chữ đó
    bằng tiếng Việt. UI test không tìm phần tử theo chữ của AppKit. Ghi vào danh sách test tay.
- 2026-10-17: **Nt0 xác nhận** (review độc lập PR #44, điểm 3): giao diện do AppKit vẽ (menu chuẩn như Thoát/Hoàn tác/
  Cửa sổ, hộp Mở/Lưu, tên "Untitled" của tài liệu mới ở bản Admin, nút mặc định) đi theo ngôn ngữ của macOS nên có thể
  hiện tiếng Việt (máy ưu tiên tiếng Việt, hoặc chỉ có ngôn ngữ ngoài vi/en). Đây là ngoại lệ có chủ đích của câu
  "không đổi chữ nào người dùng thấy" ở bước 4 (đúng phương án 1 của accessibility-localization.md).
- 2026-10-17 (sửa theo review độc lập PR #44, APPROVE):
  - `check_localization.py` báo mọi literal có chữ cái ở cấp ngoặc 0 trong đối số đầu (nhánh `?:`, phép `+`, vế phải
    `??`) của `Text` và API chỉ nhận khoá, kể cả chữ ASCII; đòi đúng `bundle: .module` (từ chối `.main`, `nil`, bundle
    khác); báo chữ có chữ cái gán cho thuộc tính chữ của AppKit (`messageText`, `informativeText`, `prompt`, `title`…)
    và `withTitle:`; thêm đối chứng âm cho từng dạng. Repo không có chỗ dính (chỉ hai dòng của `InterfaceStrings` tra
    bundle truyền vào, đánh dấu `// l10n-ignore`).
  - `--freshness` thất bại khi thư mục build không có hoặc không có `.stringsdata` nào; chỉ bỏ qua với
    `--allow-missing-stringsdata`, mà `check.sh` chỉ truyền ở CI GitHub (`CI=true`: runner có thể chọn Xcode 16, SwiftPM
    build bằng hệ native không ghi `.stringsdata`). Chọn `.stringsdata` theo thư mục `<target>(-hậu tố).build` và bản mới
    nhất của từng nguồn, không dựa vào tên thư mục `Debug`; có đối chứng.
  - Chuẩn bị bước 7: `IsolatedApp` mở app với `-AppleLanguages (vi)` (tham số dòng lệnh, không ghi `defaults`; không
    đặt `-AppleLocale` để định dạng số/ngày như cũ), để UI test tìm theo chữ tiếng Việt vẫn đúng khi catalog có `en`.
    Hệ quả: trong UI test, chữ của AppKit hiện tiếng Việt.
  - Bốn `Text` chỉ có số (`%lld`, `%lld.`, `/ %lld`) đổi sang `Text(verbatim:)` để bước 7 không phải "dịch" khoá số.
- 2026-10-17: **Nt0 chốt** (re-review #43):
  1. **Cỡ file PDF:** giữ như hiện tại (đề chuẩn, Xem lại tất cả: 108 MB, vì ảnh nhiễu của đề chuẩn không nén được và
     ảnh nhúng ở 2× cỡ hiển thị). Bước 9 đo lại với đề thật rồi mới quyết có nén ảnh khi nhúng hay không; chưa có ngân
     sách cỡ file (ghi ở large-exams.md, mục Việc mở).
  2. **Định dạng số, phần trăm, ngày giờ** (dấu ngăn nghìn như "Trang 1.175/1.175", "Câu 1.234/2.000") theo locale của
     **ngôn ngữ giao diện**, không theo Region của macOS: giữ quy tắc sẵn có của accessibility-localization.md (mục
     Ngôn ngữ); câu "theo locale hiện tại" trong ghi chú hiện thực của bước 4 bị thay. Làm cho mọi màn ở bước 7 (cùng lúc
     với tiếng Anh, để nhất quán); tới đó app vẫn theo Region. Test ReportFeature khoá dạng vi bằng ngôn ngữ tường minh
     (không phụ thuộc Region của máy).
- 2026-10-17 (bước 5a, lõi PDF kết quả):
  - **Chiều phụ thuộc:** `ReportFeature` là target dùng chung (SwiftUI, AppKit, PDFKit), không phụ thuộc SessionFeature
    hay module Admin; sau khi merge #44 nó phụ thuộc LibraryFeature chỉ để tra chữ qua `InterfaceStrings` (gạch đầu
    dòng "Chữ giao diện" dưới đây). **SessionFeature phụ thuộc ReportFeature**, không ngược lại. Lý do: nút Xuất
    PDF/In của bước 5b nằm trên màn Kết quả của SessionFeature, và PDF đề của bước 6 nằm trong AuthoringFeature; nếu
    ReportFeature phụ thuộc SessionFeature thì SessionFeature không gọi được nó (vòng phụ thuộc). Vì vậy `ResultsReport`
    (dữ liệu thuần) ở ReportFeature, còn hàm dựng `ResultsReport(results:review:level:appVersion:exportedAt:…)` ở
    SessionFeature, dựng từ `ResultsModel` và `AnswerReviewModel.detail(at:)`: quy tắc `hideAnswers`, câu đã sửa, câu
    đã xoá chỉ có một nơi (Xem lại), không chép sang PDF. Mức "Câu sai và chưa làm" = bộ lọc Sai ∪ Chưa làm của Xem
    lại (`AnswerReviewModel.questionIndices(for:)`, mới public). Luật 8 của `check_boundaries.py` + đối chứng âm.
  - **Phân trang:** mỗi khối bung thành các phần (đầu câu, dòng báo, đoạn, ảnh, lựa chọn, giải thích, dòng bảng); đo
    cả khối một lần bằng `ImageRenderer`, chỉ khối cao hơn một trang mới đo từng phần và tách giữa các phần, mảnh sau
    mở bằng "Câu N (tiếp)"; đoạn cao hơn một trang tách theo ranh giới từ (tìm nhị phân, đo lại). Đề mục giữ cùng phần
    đầu của khối sau. Chân trang ba dòng (tên đề + "Trang N/M"; "Xuất bằng Exam Suite … lúc …"; dòng lưu ý) để không
    cắt chữ như spike (bước 5b bỏ dòng giữa theo Nt0 chốt 2026-10-17, export-print.md phương án 17: còn hai dòng). Ảnh: lượt xếp lấy cỡ từ thuộc tính, lượt vẽ có sẵn ảnh đã giải mã của từng trang (thu ≤ 2× cỡ hiển
    thị), không giải mã toàn bộ trước để giữ bộ nhớ.
  - **Sửa theo review độc lập #43:** lựa chọn và đoạn chữ quá cao được tách lúc xếp trang cho vừa đúng chỗ còn lại
    (phần sau của lựa chọn giữ nhãn kèm "(tiếp)", dấu Bạn chọn/Đáp án đúng ở phần đầu), vẽ nội dung trong vùng cắt
    (clip) để không phần nào đè chân trang; PDF ghi thẳng ra file bằng `CGDataConsumer(url:)` (`render(_:to:)` cho
    Xuất PDF…, `render(_:)` trả `Data` ánh xạ từ file tạm cho In); ảnh của trang giải mã trong `Task.detached` (trang
    kế giải mã trong lúc vẽ trang này); nhường lượt khi đã chạy liền ≥ 16 ms, kể cả giữa các lần đo khi tách; đề mục mà
    cộng khối sau không vừa một trang thì khối sau được tách để không bỏ đề mục một mình cuối trang; mức Tất cả câu
    rỗng ghi "Không có câu nào.".
  - **Tên file gợi ý** (đọc phương án 10 là "tên đề dài cắt ở 120 ký tự"): cắt **tên đề** trước, giữ nguyên thí sinh
    và thời điểm nộp (hai lần thi của cùng đề không trùng tên); thí sinh chỉ bị cắt khi riêng nó dài hơn 40 ký tự; cả
    tên ≤ 120 ký tự và ≤ 255 byte UTF-8 (APFS). PDF đề: giữ "(có đáp án)"/"(đề)", cắt tên đề.
  - **Ngoài phạm vi 5a, để 5b:** chọn mức xem lại khi Xem lại không mở được (5a dựng không có phần xem lại, đúng "chỉ
    xuất phần kết quả"); ghi file tạm rồi thay; phiên bản app lấy từ `Bundle.main`; ngôn ngữ ngày giờ theo giao diện.
  - **Quan sát khi đọc lại bằng PDFKit:** chữ vẽ đúng (soát bằng ảnh trang), nhưng thứ tự chữ PDFKit trích ra có thể
    xen dòng khi một dòng chứa mã inline có khoảng trắng (`ipconfig /all`) hoặc khi chữ lựa chọn xuống dòng cạnh nhãn
    "Đáp án đúng"; test dùng chuỗi không rơi vào hai ca này. Tìm/sao chép trong Preview ở hai ca đó cần người test tay.
    Emoji trong nội dung đề vẽ bằng phông bitmap, PDFKit không đọc lại thành chữ: người test tay xác nhận emoji hiện
    trong PDF và bản in.
  - **Chữ giao diện theo quy ước bước 4 (sau khi merge #44):** chữ mới chỉ nằm ở ReportFeature, qua `localized("…")`
    của target (`Localization/Localized.swift` → `InterfaceStrings.resolve`, `ModuleStrings.bundle`), kể cả chữ vẽ vào
    PDF; catalog `Resources/Localizable.xcstrings` (nguồn `vi`) đồng bộ bằng `-exportLocalizations`. Vì
    `InterfaceStrings` nằm ở LibraryFeature, **ReportFeature phụ thuộc LibraryFeature** (như mọi target giao diện;
    LibraryFeature không phụ thuộc module Admin hay SessionFeature): `check_boundaries.py` luật 8 cho phép thêm
    LibraryFeature, vẫn cấm module Admin (trực tiếp và gián tiếp qua LibraryData/LibraryFeature), shell, SessionFeature.
  - **Sửa theo re-review #43:** `measure_large.sh` đọc dòng `Timing:` qua hàm có tự kiểm: dòng sai dạng (in tay trong
    test) bị bỏ qua và báo thay vì làm hỏng cả bảng; `check.sh` chạy `measure_large.sh --check-parser` (Python, cả
    Linux). Số trang và cỡ PDF đi vào tên mục của dòng `Timing:` đúng dạng. Chú thích cho người dịch của catalog
    ReportFeature ghi thẳng vào catalog (trường `comment`; hàm `localized()` của bước 4 không có tham số chú thích),
    `-exportLocalizations` giữ nguyên.
- 2026-10-17 (sửa sau review độc lập #42: thoát app khi đang mở sheet; #42 đã đổi ⌘Q thành "đóng sheet rồi mới
  thoát", review còn mục 1–5):
  - **Nguyên nhân** (SDK, không đoán): sheet SwiftUI mặc định **chặn app thoát**. SwiftUI (macOS 15.4)
    `View.presentationPreventsAppTermination(_:)`: "Whether a presentation prevents the app from being terminated/quit
    by the system or app termination menu item", mặc định chặn trừ khi thanh công cụ của sheet chỉ có một nút xác
    nhận/huỷ; `dialogPreventsAppTermination(_:)` cho `.alert`/`.confirmationDialog` (chặn khi có hơn một nút, nút huỷ
    hoại hay ô nhập). AppKit: `NSWindow.preventsApplicationTerminationWhenModal` (mặc định YES); release notes AppKit
    10.6 "a sheet or modal panel disables application termination", 10.3 "the AppleEvent handler for the 'quit' event
    will now return userCanceledErr if there is an application modal panel open. -applicationShouldTerminate will not
    be invoked … an application with a modal panel open will now be reported as canceling logout". Đăng xuất: app phải
    thoát hoặc trả `userCanceledErr`; quá 45 giây không trả lời thì loginwindow tự huỷ đăng xuất ("The Life Cycle of a
    Daemon", mục Terminating Processes).
  - **Thử** (app tối giản ngoài repo, không commit, như spike #42; macOS 26.6.2, SDK 27; vòng đời SwiftUI `App` +
    `NSApplicationDelegateAdaptor`, sheet trên một `NSWindow`; `terminate(nil)` gọi từ run loop như mục Thoát; Apple
    event `quit` kèm lý do đăng xuất `kAEReallyLogOut` đưa thẳng vào handler mặc định của AppKit bằng
    `NSAppleEventManager.dispatchRawAppleEvent`, không gửi tới app nào):
    - sheet mặc định (cờ YES): `terminate` trả về ngay, không hỏi delegate, sheet ở lại; Apple event: trả
      `userCanceledErr` (−128) ngay, không hỏi delegate, tức Thoát từ Dock không làm gì và đăng xuất bị huỷ;
    - sheet + `presentationPreventsAppTermination(false)` (cờ NO): cả hai đường, SwiftUI gọi binding đóng sheet **rồi**
      hỏi delegate (Apple event là sự kiện hiện tại, đọc được lý do đăng xuất); delegate huỷ thì Apple event được trả
      −128 và app dùng tiếp, đồng ý thì trả 0 và app thoát (`applicationWillTerminate`); binding bỏ qua lệnh đóng
      (`set: { _ in }`, như danh sách file không thêm được trước review #45) thì delegate huỷ xong sheet vẫn ở lại;
      đặt thẳng cờ AppKit (không qua modifier) cho kết quả như modifier;
    - `.alert` hai nút có nút huỷ hoại: chặn như sheet mặc định; một nút: không chặn;
    - `terminate` gọi từ trong một khối của main queue (như `Task` của `SessionAppController.quit()` ở #42) mà delegate
      trả `terminateLater`: main queue (mọi việc của main actor) đứng tới khi trả lời; gọi từ run loop thì không. Ở #42,
      đồng hồ làm bài (`.task` lặp 500 ms) đứng trong lúc hỏi Bỏ bài khi thoát bằng ⌘Q.
  - **Chọn:** không thay mục Thoát hay handler Apple event `quit` của AppKit; mọi sheet gắn
    `presentationAllowsAppTermination()` (LibraryFeature: macOS 15.4 trở lên dùng modifier của SwiftUI; 15.0–15.3 đặt
    `preventsApplicationTerminationWhenModal = false` cho cửa sổ sheet). Bỏ `SessionQuitCommands`,
    `SessionAppController.quit()`, `willQuitNotification`, `LibraryModel.closeSheetsForQuit()` của #42 (SwiftUI tự đóng
    sheet khi thoát) và khoá "Thoát %@" của catalog. Mọi đường thoát (⌘Q, ⌥⌘Q, Thoát từ Dock, đăng xuất/khởi động
    lại/tắt máy, AppleScript, bản Học viên đóng Thư viện) đi một đường của AppKit: hỏi lưu đề, tự lưu, Versions,
    `applicationShouldTerminate` (hỏi Bỏ bài), trả lời Apple event cho loginwindow. Nhờ vậy UI test luồng 4 (⌘Q khi
    Trước khi thi đang mở) chạy đúng cơ chế mà Thoát từ Dock và đăng xuất dựa vào.
  - **Không chọn handler Apple event riêng** (gợi ý của review #42): thay handler thì mất phần trả lời của AppKit (thử:
    `terminate` bị huỷ không ghi lỗi nào vào trả lời, phải tự ghi), phải tự đoán lúc bản Admin huỷ ở hộp hỏi lưu (hỏi
    lưu chạy bất đồng bộ, không có tín hiệu công khai), và bỏ mất xử lý lý do thoát/giữ trạng thái của handler mặc định.
  - **Các mục review #42:** (1) Dock, đăng xuất, AppleScript đi đường chuẩn như trên. (2) Không còn chờ 2 giây: không
    code nào gọi `terminate` khi còn sheet; trình bày còn chặn (hộp hỏi nhiều nút: "Vẫn nộp?", "Đề này đã có…", hộp hỏi
    của Soạn đề, hỏi Bỏ bài) thì AppKit từ chối ngay, app dùng tiếp được, đăng xuất bị huỷ gọn, như mọi app macOS khi
    đang hỏi (giữ mặc định: Nt0 chốt, gạch đầu dòng dưới; trên app thật kiểm bằng `QuitWhileConfirmingUITests`). (3)
    `scripts/check_quit_sheets.py` (trong `check.sh`, nên cả `verify_local.sh`): mọi `.sheet`/`.fullScreenCover`/
    `.popover` và sheet AppKit trong Sources/Apps phải có trong danh sách đã biết và gắn modifier, có tự kiểm âm; test
    cửa sổ thật (`PresentationTerminationTests` có đối chứng sheet mặc định chặn, sheet Thông tin, danh sách file không
    thêm được; `SessionAppControllerTests` sheet Trước khi thi). (4) ⌥⌘Q trở lại cùng mục Thoát chuẩn ("Thoát và giữ
    cửa sổ" hay "Thoát và đóng mọi cửa sổ" tuỳ cài đặt "Đóng cửa sổ khi thoát ứng dụng" của macOS); hợp với bản Admin
    (mở lại đề đang soạn); bản Học viên không có gì đáng giữ nhưng không hại. (5) Huỷ thoát (Tiếp tục làm, Huỷ ở hộp hỏi
    lưu): Trước khi thi, Thông tin, ảnh phóng to, danh sách file không thêm được đã đóng trước khi hỏi. Không mất
    dữ liệu đã lưu hay bài đang làm; lựa chọn trên Trước khi thi (tên thí sinh vừa gõ, phần, số câu, xáo trộn, thời gian, sẵn
    của Luyện lại/Làm lại) mất, phải chọn lại; danh sách file không thêm được không mở lại (chỉ để đọc). Chỉ xảy ra ở
    bản Admin (đề chưa từng lưu rồi Huỷ ở hộp hỏi lưu): bản Học viên không có bài chưa nộp khi Trước khi thi đang mở.
    exam-taking.md thêm một dòng (thoát gồm Dock, đăng xuất; sheet không chặn; hộp hỏi hai nút vẫn chặn).
  - **Còn lại (test tay):** nhánh macOS 15.0–15.3 (cờ AppKit) chưa chạy trên máy thật; Thoát từ Dock, đăng xuất trên
    app thật (mục Validation).
- 2026-10-17: **Nt0 chốt** (review độc lập #45): khi hộp hỏi hai nút hay có nút huỷ hoại đang mở ("Còn N câu chưa làm.
  Vẫn nộp?", "Bài chưa nộp sẽ mất. Bỏ bài?", hộp xác nhận xoá của Soạn đề), **giữ mặc định của macOS**: ⌘Q không tác
  dụng, Thoát từ Dock không làm gì, đăng xuất/tắt máy bị huỷ (macOS báo app đã huỷ); người dùng trả lời hộp hỏi trước.
  Không gắn `dialogPreventsAppTermination(false)`. exam-taking.md ghi quy tắc này.
- 2026-10-17 (sửa theo review độc lập #45, APPROVE):
  - **M1:** khẳng định "hộp hỏi chặn thoát thì app dùng tiếp được" trước đây chỉ dựa trên app tối giản (UI test #42 từng
    thấy sheet chặn thoát biến mất và mọi cửa sổ bị khoá). Thêm `Apps/StudentUITests/QuitWhileConfirmingUITests`: Thi →
    ⌘Return → Return → hộp "Vẫn nộp?" → ⌘Q → app vẫn chạy, hộp còn và bấm được, không hỏi Bỏ bài → Quay lại → Rà soát →
    Esc → câu 1 còn đáp án → câu 2 chọn B → nộp → ⌘Q thoát. Chỉ chạy bằng `verify_local.sh --uitest`; đạt trên
    `43ff3e6` (Học viên 6 / Admin 5 test).
  - **L1:** binding của sheet danh sách file không thêm được nhận lệnh đóng (bỏ đúng lời nhắc đang hiện,
    `LibraryPromptPresenter.problemsBinding`), như mọi sheet khác; test `importProblemsBindingAcceptsDismissal`.
  - **L2:** `check_quit_sheets.py` chỉ tính modifier ở cấp ngoài cùng của closure nội dung (không tính trong nhánh `if`,
    closure lồng, ngoặc tròn, sheet lồng); giới hạn còn lại ghi ở docstring.
  - **L3:** `check_quit_sheets.py` mục 4 cấm `CommandGroup(replacing: .appTermination)` và mọi dùng `kAEQuitApplication`
    trong Sources/Apps (ngoài comment/chuỗi), có đối chứng âm và dương (`after: .appTermination`, `kAEQuitReason`).
  - **L4:** exam-taking.md ghi hộp hỏi hai nút vẫn chặn thoát; "không mất dữ liệu" thay bằng câu chính xác (mục 5 trên).
  - Nit: `WindowFlagView` (nhánh 15.0–15.3) không nhận chuột, không vào cây trợ năng; plan giai đoạn 4 ghi cách #42 đã
    được thay.

- 2026-10-17: **Nt0 chốt** (bước 5b): sheet tiến độ của Xuất PDF/In chỉ hiện khi dựng lâu hơn **0,3 s**
  (export-print.md phương án 14), để lần xuất nhanh không làm sheet chớp lên rồi tắt.
- 2026-10-17: **Nt0 chốt** (review độc lập #46, export-print.md phương án 15–17): (D1) tên việc in = tên file gợi ý bỏ
  `.pdf` (giữ như đã làm); (D2) bấm Xuất/In với phần xem lại mà file đề không đọc được thì **đóng hộp chọn, hộp báo lỗi
  "Không đọc được file đề để làm phần xem lại" kèm lý do, không xuất/in gì**; muốn chỉ phần kết quả thì mở lại, chọn
  Không (thay cách "ở lại hộp chọn, bấm lại thì chỉ xuất kết quả" của bản đầu); (D3) **bỏ dòng thời điểm xuất** ("Xuất
  bằng Exam Suite <phiên bản> lúc <thời điểm>") khỏi chân trang PDF; thời điểm duy nhất là lúc nộp. Hiểu là bỏ cả dòng
  (phiên bản chỉ còn ở Creator) và áp cho cả PDF đề của bước 6 (export-print.md mục PDF đề sửa theo). Siêu dữ liệu
  CreationDate do Core Graphics tự ghi (không tắt được qua `CGContext` PDF), không hiện trên trang.
- 2026-10-17 (bước 5b, nối giao diện PDF/In kết quả):
  - **Luồng** `ResultsReportFlow` (SessionFeature, một lần Xuất/In trên `SessionWindowModel.reportFlow`): hộp chọn →
    (cần phần xem lại mà chưa có Xem lại đang mở) đọc file đề như nút Xem lại bài → hộp Lưu (Xuất) → dựng (tiến độ) →
    thay file / hộp In → hộp báo lỗi nếu có. Hộp của macOS qua `ResultsReportServices` (app: `.live(window:)` trên cửa
    sổ làm bài, `ReportPanels` của ReportFeature; test: bản giả). Mở từ Xem lại bài thì dùng đúng Xem lại đang mở, không
    đọc lại file đề.
  - **Đọc file đề lỗi lúc bấm Xuất/In** (thẻ còn Sẵn sàng nhưng file hỏng): theo D2 ở trên, đóng hộp chọn, hộp báo lỗi
    kèm lý do (`ResultsModel.reviewLoadFailure`), Thư viện làm mới thẻ, không xuất/in gì. Lựa chọn tắt (Xem lại không mở
    được theo trạng thái thẻ) hiện **Không** (đúng thứ sẽ xuất); lựa chọn đã nhớ không bị ghi đè. Nhớ lựa chọn khi bấm
    Xuất/In.
  - **Ghi file** (`ReportFileWriter`): file tạm ẩn tên ngắn cố định `.ExamSuite-<8 ký tự>.pdf.tmp` (27 byte, review #46
    L2: tên cũ `.<tên đích>.<UUID>.tmp` vượt 255 byte khi tên đích dài) cạnh file đích (như `ExamPackageWriter`), tạo bằng
    `O_EXCL` trước khi dựng để thư mục không ghi được báo ngay; đọc lại bằng `CGPDFDocument` ngoài main actor (đủ trang;
    Core Graphics không báo lỗi ghi khi ổ đĩa đầy; review #46 L3); `rename(2)` đè file đích. Huỷ/lỗi xoá file tạm, file
    đích cũ giữ nguyên. Lý do lỗi là chữ của app theo `errno` (không quyền, ổ đầy, chỉ đọc, thư mục không còn, file ghi ra
    hỏng, lỗi khác), như lỗi đọc file đề của Xem lại. Đường In: ánh xạ PDF và `PDFDocument(data:)`/`printOperation` vẫn
    trên main actor, chưa đo; để bước 9 đo cùng `ReportTimingTests`.
  - **Thoát app giữa chừng** (theo #45: sheet không chặn thoát): SwiftUI đóng sheet trước khi hỏi app delegate, binding
    gọi `sheetDismissed()` (hộp chọn: như Huỷ; tiến độ: huỷ lần dựng). App thoát **bình thường** (⌘Q, Thoát từ Dock, đăng
    xuất) thì file tạm còn lại (file tạm cạnh file đích của Xuất PDF và PDF tạm của In trong thư mục tạm của hệ thống;
    `ReportTemporaryFiles`) xoá ở `NSApplication.willTerminateNotification`; crash hay buộc thoát thì file tạm ẩn còn lại
    (như `ExamPackageWriter`). Sheet ghi trong `check_quit_sheets.py`. Đóng cửa sổ, về thư viện hay đổi phiên khi đang
    xuất: huỷ, không để lại file.
  - **Sửa theo review #46:** (L1) Return rồi Esc/đóng sheet ngay, trước khi lần xuất đã xếp hàng kịp chạy, giờ huỷ cả
    lần xuất đó (`cancel()`/`sheetDismissed()` ở hộp chọn huỷ `pipeline`; `perform()` dừng ngay nếu đã huỷ); (L4) trong
    lúc một lần Xuất/In đang chạy (kể cả 0,3 s đầu chưa có sheet tiến độ), cửa sổ không mở thêm sheet (ảnh phóng to,
    `SessionWindowModel.canPresentSheet`), để sheet tiến độ luôn trình bày được; (L5) nội dung sheet giữ nguyên lúc sheet
    đang đóng (hộp chọn không biến thành tiến độ khi bấm Return, không trống khi bấm Huỷ; `ResultsReportFlow.sheetContent`
    + nội dung đã hiện); (N1) sửa chú thích cũ của `ReportRenderer`; (N2) chú thích cho người dịch ở khoá mới của
    SessionFeature; (N4) UI test chờ có giới hạn thay cho ngủ cố định.
  - **Menu Tệp:** `CommandGroup(replacing: .printItem)` (Xuất PDF… không phím tắt, In… ⌘P; không còn Page Setup ⇧⌘P).
    Nhóm in là của cả app: bước 6 (PDF đề, cửa sổ soạn đề bản Admin) phải gắn In… ⌘P vào cùng nhóm này (theo cửa sổ
    đang dùng), không thêm nhóm thứ hai. `check_quit_sheets.py` mục 4 chỉ cấm thay `.appTermination`.
  - **Tên việc in** (tên gợi ý của "Lưu thành PDF" trong hộp In): tên file gợi ý bỏ `.pdf` (Nt0 chốt, D1). Phiên bản ở
    Creator: `CFBundleShortVersionString` của app. Không có thời điểm xuất (D3).
  - **UI test:** hộp Lưu không có móc (như #42): `-NSNavLastRootDirectory` + lái bằng bàn phím; logic chuyển từ
    `AdminFlow` sang `Apps/UITestSupport/SavePanelDriving.swift` dùng chung, Admin giữ nguyên các bước. Không mở hộp In
    thật.

- 2026-10-17 (lỗi Nt0 gặp trên bản cài `611475a`, sửa ở PR "G5: Thư viện trống khi cửa sổ xếp lát"): bản Học viên mở
  Thư viện thì thanh bên và danh sách trống (tiêu đề vẫn "3 đề"); thoát rồi mở lại, hoặc đóng dải chào mừng, thì hết.
  Nguyên nhân: khung cửa sổ Thư viện lưu kèm trạng thái xếp lát của macOS 26 (`"NSWindow Frame library"` có
  `tilingState`); khi khôi phục, SwiftUI đo cỡ nhỏ nhất của nội dung ở độ rộng ~0, đoạn chữ dài của dải chào mừng
  (`BannerView`, `fixedSize` dọc, nằm ngoài `ScrollView`) cao ~2.190 pt nên khung chia cột cao 2.250 pt trong cửa sổ
  783 pt, nội dung bị đẩy ra ngoài. Bản Admin của Nt0 không bị vì cửa sổ không xếp lát. Sửa: chữ của dải thông báo có
  độ rộng tối thiểu (`LibraryStyle.bannerTextMinWidth` 320 pt), không đổi giao diện ở cỡ thường. Bằng chứng:
  `LibraryWindowRestoreUITests` mở bản Học viên cô lập với đúng khung đó (tham số dòng lệnh, không ghi `defaults`), kiểm
  thanh bên, dải chào mừng, thẻ đề và ô của chế độ danh sách nằm trong cửa sổ; đỏ khi gỡ bản sửa (thẻ đề ở y = −518), xanh
  khi có. Các thử nghiệm không sửa được và đã gỡ: dựng lại khung chia cột (`.id`), buộc `NSHostingView` tính lại bố cục,
  bỏ `.windowResizability(.contentMinSize)`; AppKit (`NSSplitView`, hosting view) luôn đúng 783 pt, chỉ bố cục SwiftUI
  bên trong cột sai. Cùng dấu hiệu đã thấy ở UI test PR #42 (bản Admin, sau ⌘Q treo).

- 2026-10-17 (bước 6, PDF và In đề của bản Admin):
  - **Nt0 chốt** (export-print.md không nói, agent hỏi trước khi mở PR): (1) hộp chọn **Kiểu** mỗi lần mở luôn chọn sẵn
    **Chỉ đề (không đáp án)**, **không nhớ** lần trước (export-print.md phương án 18; `ExamReportKind.default`, không ghi
    cài đặt nào), Return xuất/in ngay; (2) thông tin đề là một khối ở **đầu trang 1**, Phần 1 tiếp ngay sau, không có
    trang bìa riêng (phương án 19). Test: `defaultKindIsQuestionsOnlyEveryTime` (chọn Có đáp án một lần, lần mở sau vẫn
    Chỉ đề), UI test Admin kiểm lựa chọn chọn sẵn.
  - **Menu Tệp dùng chung:** nhóm in (`CommandGroup(replacing: .printItem)` của `SessionCommands`) là của cả app;
    cửa sổ soạn đề gửi `focusedSceneValue(\.reportCommandTarget, …)` (`ReportCommandTarget` của SessionFeature: định
    danh đối tượng + bật/tắt + closure, so bằng định danh và bật/tắt để menu không dựng lại mỗi lần gõ), `ReportMenuRoute`
    chọn cửa sổ làm bài nếu nó đang dùng, không thì cửa sổ soạn đề. SessionFeature không biết gì về soạn đề (ADR 0003);
    bản Học viên 0 ký hiệu `ExamReport` (nm).
  - **Nội dung là ảnh chụp lúc mở hộp chọn** (`ExamDraft.package`, kể cả thay đổi chưa lưu); hộp chọn là sheet nên trong
    lúc nó mở không sửa được đề. Số lỗi của dòng "Đề còn N lỗi; PDF in đúng như đang soạn" là số lỗi mức `error` của
    `ExamValidator` trên đúng ảnh chụp đó (thanh lỗi nếu đã kiểm xong, không thì kiểm ngay), như thanh lỗi; cảnh báo không
    tính. Xuất không đổi đề, không thêm bước Hoàn tác.
  - **Trình bày** (theo mục Nội dung của export-print.md, cách hiện của PDF kết quả và xem trước của Soạn đề): khối đầu
    trang 1 (phương án 19) có trường Mã đề (nếu có), Số câu, Số phần, Thời gian Thi ("45 phút"),
    Ngưỡng đậu ("70% · 700/1000"), "Ẩn đáp án: Có" (nếu có); hướng dẫn Markdown. Đề mục mỗi phần kèm "N câu". Đầu mỗi câu
    như xem trước: tên phần + "Câu N/M" (N liên tục toàn đề). Gợi ý "Chọn N đáp án" ở cả hai kiểu (học viên cũng thấy lúc
    làm bài). Chân trang: tên đề + "Trang N/M", rồi "Mã đề: … · Có đáp án" (bỏ phần không có). Siêu dữ liệu Title
    "<tên đề> – Đề".
  - **Đề đang soạn còn lỗi in đúng như đang soạn:** tên đề/phần rỗng hiện như cây đề ("(Đề chưa có tên)", "(Phần chưa có
    tên)"), phần rỗng chỉ có đề mục "0 câu", câu rỗng/lựa chọn rỗng in rỗng, câu nhiều đáp án chưa có đáp án đúng ghi
    "Chọn 0 đáp án", đáp án đúng theo `Question.correct` (id lựa chọn) như xem trước, nhãn theo vị trí; ảnh không có trong
    gói (thiếu, sai tên) thì "Không hiện được ảnh của câu này". Tên file gợi ý từ tên đề thật (`ReportFileName.exam`).
  - **Hiệu năng:** khối của đề dựng ngoài main actor (`Task.detached`; `ExamReport.document()` thuần), rồi bộ dựng trang
    của ReportFeature như PDF kết quả. Trong lúc Xuất/In chạy, cửa sổ soạn đề không nhận chuột (`allowsHitTesting`), để 0,3
    s đầu (chưa có sheet tiến độ) không mở thêm sheet (ảnh phóng to của xem trước, hộp chọn ảnh, hỏi xoá phần), như
    `canPresentSheet` của cửa sổ làm bài; mục menu tắt khi bộ soạn đề có hộp thoại, và lúc bấm còn kiểm
    `NSWindow.attachedSheet` (sheet của AppKit không quan sát được). Cửa sổ đóng (`onDisappear`) huỷ lần đang chạy.
  - **Rủi ro cao:** chạm `Packages/ExamFeatures/Package.swift` (thêm phụ thuộc khai báo rõ ReportFeature cho
    AuthoringFeature và AuthoringFeatureTests, SessionFeature cho AuthoringFeatureTests) và `AuthoringFeature/**`
    (không chạm document, lưu, khôi phục): review độc lập trước khi người duyệt.
  - **Giới hạn đã biết (không có rủi ro dữ liệu):** trong lúc Xuất/In chạy mà chưa có sheet nào (0,3 s đầu khi dựng,
    chuyển giữa các hộp) chỉ **chuột** bị chặn trên cửa sổ soạn đề (`allowsHitTesting`); lệnh menu và phím (⌥⌘N, ⌘R Thử
    đề này, Xoá phần…) vẫn chạy. PDF dùng ảnh chụp đề lúc mở hộp chọn nên không lẫn nội dung; tệ nhất là một sheet khác
    (hộp Lưu của Thử đề này, hỏi xoá phần) không trình bày được hoặc sheet tiến độ không hiện cho tới khi sheet kia đóng.
    Không thêm chặn lệnh (review độc lập #49: chỉ thêm khi đơn giản và an toàn).
- 2026-10-17 (sửa theo review độc lập #49, không có lỗi chặn; `local/verify` có UI test xanh trên `d33cb33`):
  - **In khi lần in bị huỷ đúng lúc dựng vừa xong:** In… → Return trên đề nhỏ rồi ⌘W trong ~0,3 s: `onDisappear` huỷ sau
    lần kiểm huỷ cuối của bộ dựng trang, dựng vẫn trả thành công và hộp In mở thành hộp riêng của cả app cho một cửa sổ
    đã đóng. Sửa: `printReport` kiểm `Task.isCancelled` trước khi mở hộp In, ở cả `ExamReportFlow` và `ResultsReportFlow`
    (cùng mẫu có sẵn từ bước 5b); test `cancelAfterRenderDoesNotPrint` ở hai bên (móc `didRender` chỉ cho test, huỷ ngay
    khi dựng xong; bỏ kiểm thì test đỏ vì hộp In giả được gọi). Đường Xuất PDF không có khe này: `ReportFileWriter` kiểm
    huỷ sau khi dựng và đọc lại, ngay trước `rename(2)`, nên huỷ lúc đó không để lại file và file đích cũ giữ nguyên.
  - **`ReportPanels`:** `waitUntilNoSheet` dừng khi task đã huỷ (trước đây `try? await Task.sleep` của task đã huỷ trả về
    ngay, vòng lặp quay liền trên main actor tới 2 s); hộp Lưu, hộp In, hộp báo lỗi không mở khi lần xuất đã huỷ (trước
    và sau khi chờ sheet), để không bao giờ thành hộp riêng của cả app cho cửa sổ đã đóng. Hộp thật không unit test được;
    luồng gọi chúng có test với bản giả.
  - Test PDF trang 1 có cả thông tin đề, đề mục Phần 1 và câu 1 (phương án 19, không trang bìa): `ExamReportTests`
    `firstPageHasHeaderAndFirstQuestion` (hai kiểu) và file xuất của `ExamReportFlowTests`.
  - Câu chữ: chú thích `allowsHitTesting` của cửa sổ soạn đề nói đúng là chỉ chặn chuột; AGENTS.md (dòng
    `verify_local.sh --uitest`, `Apps/AdminUITests`, bảng bất biến) ghi UI test Xuất PDF kết quả và Xuất PDF đề.
  - Ghi việc sau: snapshot trang 1 của PDF (bước 8), gộp luồng Xuất/In trùng (bước 9).

- 2026-10-17 (bước 7a, định dạng theo ngôn ngữ giao diện; chi tiết ở accessibility-localization.md "Ghi chú hiện thực
  (giai đoạn 5, bước 7a)"):
  - **Tách bước 7** thành 7a (định dạng), 7b (lỗi lõi theo mã), 7c (tiếng Anh), làm theo thứ tự, mỗi phần một PR (yêu
    cầu của người điều phối, 2026-10-17): 7a không đổi chữ nào nên kiểm riêng được trước khi có bản dịch.
  - **Locale chỉ có ngôn ngữ** (`Locale(identifier: "vi")`/`"en"`), không ghép vùng của `Locale.current`: Nt0 chốt
    không theo Region. Ngôn ngữ là ngôn ngữ **chữ của catalog** thật sự ra: ngôn ngữ đầu tiên trong thứ tự của app
    (`Bundle.main.preferredLocalizations`, không có thì `Locale.preferredLanguages`) có trong catalog của module
    (`InterfaceLocale.catalogLanguages`: `*.lproj` đã biên dịch cộng nguồn vi), không khớp thì `vi`
    (`InterfaceLocale.resolve(preferences:available:pinned:)`; quyết định ban đầu của PR #50 lấy thẳng ngôn ngữ đầu của
    bundle chính, đã thay theo review độc lập #50, mục dưới; sửa câu này theo review #50 N4 ở bước 7b). Hệ quả: giao
    diện tiếng Anh dùng dạng Mỹ ("10/15/2026, 2:05 PM", "1,234"), kể cả khi Region là Anh hay Việt Nam; cài đặt riêng
    cho số/ngày ở Language & Region (12/24 giờ, dấu ngăn) không áp dụng; số và chữ luôn cùng ngôn ngữ, kể cả khi ngôn
    ngữ ưu tiên không có trong app (spike: `fr` → `vi`) hoặc catalog chưa có bản dịch (tới 7c: `en` → `vi`).
  - **Một chỗ định dạng cho chữ qua catalog:** `InterfaceStrings.resolve` truyền `locale: InterfaceLocale.current` cho
    `String(localized:bundle:locale:)` (tham số này chỉ định dạng, không chọn ngôn ngữ: spike), nên mọi chuỗi có số nội
    suy qua `localized(…)` không phải sửa từng chỗ. Đường test (`LocalizedStringResource.locale`) vốn định dạng theo
    ngôn ngữ đã khoá.
  - **View: môi trường thay vì truyền locale từng `Text`:** SwiftUI định dạng nội suy của `Text("…", bundle:)` và
    `Text(n, format:)` theo `\.locale` của môi trường (đã kiểm: `InterfaceLocaleTests.swiftUITextFollowsEnvironmentLocale`
    đọc lại chữ trên PDF; `Date.FormatStyle` trong `Text(_:format:)` còn bị thay cả locale và múi giờ bằng giá trị của môi
    trường). Gắn `.interfaceLocale()` ở mọi scene của hai shell (như `.defaultAppStorage`), gốc `ImageRenderer` của
    `ReportRenderer` và gốc snapshot. Ô số `TextField(value:format:)` vẫn truyền `.locale(locale)` của môi trường cho
    chắc (không đọc lại được bằng `ImageRenderer`).
  - **Số đứng một mình**: `Text(n, format: .number)` hoặc `InterfaceLocale.number(_:)` (có ngăn nghìn: "1.234" trong ô
    bảng câu hỏi), không tạo khoá chỉ có số (giữ quyết định bước 4). Phần trăm qua `IntegerFormatStyle.Percent`: với vi/en
    ra đúng chữ cũ ("85%"); dấu trừ U+2212 của "−5%" giữ nguyên (ghép với phần trăm đã định dạng).
  - **Luật `region-locale`** trong `check_localization.py` (cùng chủ với các luật chữ giao diện, chạy ở `check.sh` cả
    `--core`): quét mọi target của ExamFeatures và Apps; dạng đúng (locale tường minh, `Text(n, format:)` theo môi
    trường, ISO 8601, `TimeZone.autoupdatingCurrent`) không bị báo; đối chứng âm 18 dạng. Ngoại lệ có lý do:
    `DateFormatter` của tên file gợi ý (dạng cố định, en_US_POSIX, `// l10n-ignore`).
  - **Không đổi:** đồng hồ `mm:ss`/`h:mm:ss` (chỉ chữ số và `:`), tên file gợi ý (export-print.md), chữ trơn của lõi và
    target dữ liệu (số không ngăn nghìn tới 7b; riêng dung lượng ảnh của AuthoringData trước đây theo Region, nay theo
    tiếng Việt cho khớp câu). Lõi ExamKit/ExamFile không đổi.
  - **Câu hỏi cho Nt0 (thang 1000; đã chốt, mục dưới):** quy tắc không nói rõ "/1000" là số cần ngăn nghìn hay tên thang. Hiện (giữ
    nguyên, không chọn): Kết quả và PDF ghi "100% · 1000/1000" (số trơn, chủ ý từ G3.3 để khớp "/1000"; test khoá); PDF đề
    "100% · 1000/1000"; nhưng cột "Thang 1000" của Lịch sử thi (`Text(n, format: .number)`) và dòng "= 1.000/1000" cạnh
    ngưỡng đậu của Soạn đề (số nội suy) có ngăn nghìn khi giá trị là 1000. Cần chốt một trong hai: (a) thang 1000 luôn số
    trơn ("1000/1000", cột "1000"); (b) theo quy tắc số ("1.000/1.000", cột "1.000"). Sửa sau khi chốt (vài dòng, cùng
    PR hoặc PR sau).
- 2026-10-17 (sửa theo review độc lập #50 @767947c, không có lỗi chặn):
  - **Ngôn ngữ định dạng = ngôn ngữ chữ của catalog** (thay quyết định "lấy từ `Bundle.main.preferredLocalizations.first`"
    ở trên): bundle chính có `en.lproj` (chuỗi Info.plist) từ bước 4 nhưng catalog của module chưa có `en` tới 7c, nên
    máy ưu tiên tiếng Anh từng ra chữ tiếng Việt kèm "Câu 1,234/2,000", "Nộp lúc 10/15/2026, 2:05 PM" (cả PDF). Nay
    `InterfaceLocale.resolve(preferences:available:pinned:)`: ngôn ngữ đầu tiên trong thứ tự của app có trong catalog
    (`*.lproj` của bundle LibraryFeature cộng `vi` nguồn), không khớp thì `vi`. Đã soi bundle của app build từ
    `767947c`: `ExamFeatures_*.bundle` chỉ có `Info.plist` (`CFBundleDevelopmentRegion` vi), không có `*.lproj`;
    `Bundle.localizations` = `["vi"]`. Tự so mã ngôn ngữ thay vì `Bundle.preferredLocalizations(from:forPreferences:)`
    vì hàm đó khi không khớp trả ngôn ngữ đầu danh sách (thử: `[en, vi]`, ưu tiên `[fr]` → `en`) trong khi chữ của module
    ra `vi` (spike). Test không phụ thuộc ngôn ngữ của máy: `["en"]` với `["vi"]` → vi; `["en"]` với `["vi","en"]` → en;
    `["fr","en"]` → en; `["fr"]` → vi; `["vi"]` với `["en"]` → vi.
  - **`region-locale` chặt hơn:** báo `.formatted(date:time:)` (không nhận locale), quét cả mã trong nội suy `\(…)` của
    chuỗi (bộ tách mã ghi lại phần chữ của chuỗi, `code_mask`), hàm tĩnh `DateFormatter.localizedString(from:…)`,
    `NumberFormatter.localizedString(…)`, `ByteCountFormatter.string(fromByteCount:…)`,
    `ListFormatter.localizedString(byJoining:)`, `Date.FormatStyle(…)` không có `calendar:`; bỏ qua `.formatted(.iso8601…)`.
    Thêm 11 đối chứng âm; mã hiện tại không có chỗ dính.
  - **Luật mới `scene-locale`** (`check_localization.py`, chạy mọi nơi): mỗi scene ở cấp ngoài cùng của
    `var body: some Scene` trong StudentShell, AdminShell phải có `.interfaceLocale()` (không tính modifier nằm trong
    closure của scene); shell không còn `body` nào cũng là lỗi; 3 đối chứng âm, đối chứng dương nhiều dòng; thử bỏ
    `.interfaceLocale()` của `ImportExamWindow` thì báo đúng dòng.
  - **Lịch Gregorian:** `Date.FormatStyle` của `LibraryFormat.date/dateTime` và `SessionFormat.dateTime` truyền
    `calendar: InterfaceLocale.calendar` (trước đây `.autoupdatingCurrent`: Phật lịch hay lịch Nhật ở Region sẽ ra năm
    khác, và test ngày vi phụ thuộc lịch của máy).
  - **Tham số `locale:` tường minh** (`ResultsModel.infoRows`, `ResultsReport(results:…)`, `LibraryAccessibility`,
    `LibraryFormat`): giữ nhỏ, ghi rõ trong chú thích rằng nó chỉ áp cho ngày giờ, phần trăm, dung lượng; số trong chữ qua
    catalog luôn theo `InterfaceLocale.current` (cùng ngôn ngữ với chữ). Không đổi `+%@`/`−%@`, không đổi thang 1000.
- 2026-10-17: **Nt0 chốt** (câu hỏi thang 1000 của bước 7a): phương án (a). Giá trị thang 1000 luôn **chữ số trơn**,
  không ngăn nghìn, ở mọi ngôn ngữ và mọi nơi: "850/1000", "1000/1000". Lý do: "1000" là tên của thang, và Kết quả ghi số
  trơn có chủ ý từ G3.3. Ghi vào scoring.md và accessibility-localization.md (ngoại lệ của quy tắc số). Làm trong PR #50:
  một hàm `InterfaceLocale.scale1000(_:)` (LibraryFeature, `String(value)`, chú thích là ngoại lệ có chủ ý; luật
  `region-locale` không báo nên không cần `// l10n-ignore`) cho Kết quả (`ResultsModel.scoreText`), PDF kết quả (dùng
  `scoreText`), PDF đề (`ExamReport`), Soạn đề (`AuthoringPresentation.passScale1000`: khoá "= %lld/1000" thành
  "= %@/1000", trước đây ra "= 1.000/1000") và cột Thang 1000 của Lịch sử thi (`HistoryView.scale1000Cell`, trước đây
  `Text(n, format: .number)` ra "1.000"). VoiceOver đọc đúng chữ đó (nhãn Kết quả dùng `scoreText`; ô bảng đọc chữ của
  ô). Test: `scale1000IsPlainDigits` (ô Lịch sử thi vẽ dưới locale vi và en ra "1000", đối chứng `Text(1000, format:)`
  ra "1.000"), `passScale1000IsPlainDigits` (Soạn đề, locale vi và en).

- 2026-10-17 (bước 7b, thông báo lỗi dịch theo mã ở tầng giao diện; chi tiết ở accessibility-localization.md "Ghi chú
  hiện thực (giai đoạn 5, bước 7b)"):
  - **Lõi thêm mã, không đổi chữ hay kết luận.** `ValidationIssue` thêm `arguments` (khởi tạo cũ giữ được, đối số mặc
    định rỗng); ba case của `ExamFileError` trước đây chỉ mang chuỗi tiếng Việt (`invalidJSON`, `migrationFailed`,
    `writeFailed`) đổi kiểu tham số thành enum có mã. Không cộng thêm được (enum không có trường lưu); phương án đọc ngược
    câu tiếng Việt ra mã bị bỏ vì dễ vỡ. Test lõi chỉ đổi cách dựng giá trị kỳ vọng (`.invalidJSON(.notUTF8)` thay vì
    chuỗi), mọi câu kỳ vọng giữ nguyên; thêm test câu `errorDescription` từng chữ (`ExamFileProblemsTests`) và đối số của
    mọi mã (`ExamValidatorArgumentTests`). Parity với `validate_exam.py` và `expected-verdicts.json` không đổi.
  - **Ai giữ câu dịch:** câu của lõi và LibraryData ở catalog của LibraryFeature (`ErrorMessages`), vì cả SessionFeature
    và AuthoringFeature đều cần (ví dụ "Đề có 3 lỗi, không mở được…" ở Thư viện, Trước khi thi, file soạn đề); câu của
    AuthoringData và ExamImport ở catalog của AuthoringFeature (`AuthoringMessages`), chỉ bản Admin (ADR 0003). Target
    dữ liệu và lõi **không có catalog**: chúng chạy ngoài giao diện (lõi trên Linux, ADR 0008) và câu tiếng Việt của chúng
    chỉ còn cho nhật ký/test (`logMessage`), nên không cần chọn ngôn ngữ ở đó.
  - **Câu trọn vẹn:** mỗi tổ hợp (mã × loại vị trí × biến thể) một khoá có chỗ trống ("Phần %lld, câu %lld chưa có đáp
    án đúng…"), không ghép mảnh vị trí với lý do. Ngoại lệ có chủ ý, vì là danh sách hay chi tiết kỹ thuật: danh sách
    đường dẫn JSON, chữ cái lựa chọn, cặp mojibake, mục RVF và tên trường `.vce` (cụm từ có khoá riêng, nối bằng dấu câu);
    nơi xuất hiện trước của id trùng ("đề", "phần 2", "phần 1, câu 3") là cụm có khoá riêng đặt vào chỗ trống. Câu của
    lỗi hệ thống (Cocoa, POSIX, bộ phân tích XML) và chi tiết kỹ thuật (tên kiểu Swift, mô tả của bộ giải mã) đặt nguyên
    vào chỗ trống: macOS đã dịch theo ngôn ngữ của app, hoặc là chữ kỹ thuật không dịch.
  - **Chữ người dùng thấy không đổi**, trừ hai thay đổi có chủ ý: số (đã chốt ở bước 7a: số theo ngôn ngữ giao diện):
    số đếm, độ dài, giới hạn, số dòng từ 1.000 trở lên nay có ngăn nghìn ("Hướng dẫn dài 4.001 ký tự. Rút gọn còn tối đa
    4.000 ký tự.", "tối đa 33.554.432", "báo cáo chỉ ghi 1.000 mục đầu"; trước đây "4001", "33554432", "1000"); và giới
    hạn số entry của `.docx` ghi "entry" thay "byte" (N-b, mục sửa theo review #51 dưới). Mã định danh (id phần của
    `.vce`, loại câu, cờ, loại bản ghi RVF, query) và số phiên bản định dạng (N-a) giữ chữ số trơn như mã đề.
  - **Kho Thư viện:** model V1 (các thuộc tính lưu của `LibrarySchemaV1`) không đổi; chỉ cách chuyển giữa `FileVerdict`
    và các trường lưu đổi. `verdictReason` vẫn lưu đúng câu tiếng Việt trước 7b
    (bản app cũ đọc kho vẫn thấy đúng chữ). Đọc lại từ kho là `FileProblemReason.stored(câu)`; kết luận mang lý do đó không
    được dùng lại (`FileVerdict.isReusable`), nên file **có vấn đề** (File hỏng, Đề có lỗi, Có lỗi) được đọc lại một lần
    mỗi lần mở app dù không đổi, rồi lý do có mã dùng lại trong lần chạy đó; file Sẵn sàng và Cần app mới hơn không đọc
    lại. Đổi kỳ vọng của test `reimportedFileThatBecameUnreadable` (File hỏng: 0 → 1 lần đọc) và dạng giá trị của fixture
    kho v1 (`.failsStrict(reason: .stored("Đề có trường không được hỗ trợ: ghiChu."))`, cùng dữ liệu, không tạo lại
    fixture). Phương án lưu lý do có mã (JSON trong `verdictReason`) bị bỏ: phải cho kiểu lỗi của lõi theo `Codable` để
    phục vụ LibraryData và đổi dạng dữ liệu trong kho; đọc lại vài file có vấn đề khi mở app rẻ hơn. `.stored` hiện nguyên
    chữ nếu gặp (chỉ preview/snapshot: ảnh tham chiếu Thư viện giữ nguyên nhờ lý do dạng chữ có sẵn).
  - **Chặn tái phạm:** luật `core-text` (`check_localization.py`, mọi target có chữ giao diện và Apps) báo truy cập
    `.errorDescription`, `.localizedDescription`, `.failureReason`, `.recoverySuggestion`, `.logMessage`, `.logDescription`
    và `.message` sau biến `issue`/`issues`/`…Issue(s)`; câu hệ thống đi qua `ErrorMessages.systemDescription(of:)` (một
    dòng `// l10n-ignore`); hai chỗ đọc `PreExamIssue.message` (chữ của catalog SessionFeature) đánh dấu `// l10n-ignore`
    kèm lý do. 10 đối chứng âm, 9 dòng đối chứng dương. Target dữ liệu bỏ `LocalizedError` nên `localizedDescription` của
    chúng không còn ra tiếng Việt. Test Swift: mỗi mã/case ra chữ khác rỗng, tiếng Việt trùng câu của lõi/target dữ liệu
    cho cùng đầu vào (`ErrorMessagesTests`, `AuthoringMessagesTests`, có danh sách case đủ cho `ImportIssueDetail`).
  - **Sửa theo review #50:** N1 `.interfaceLocale()` (View và Scene) đặt cả `\.calendar = InterfaceLocale.calendar`
    (test: lịch Phật của môi trường ngoài không lọt vào view). N3 luật `scene-locale` quét cả `Apps/Student/StudentApp.swift`
    và `Apps/Admin/AdminApp.swift`: scene của app là scene gộp khai báo trong shell (`struct StudentScenes: Scene`, body
    được kiểm) hoặc phải gắn `.interfaceLocale()`; 3 đối chứng âm (scene thường, thêm scene bên cạnh scene gộp, scene gộp
    lạ). N4: đối chứng âm/dương cho `code_mask` với chuỗi raw (`\#(…)` là nội suy, `\(…)` là chữ) và nhiều dòng; test
    `catalogLanguages` dựng bundle tay (có `en.lproj` → `en`, `vi`; chỉ nguồn → `vi`; ưu tiên `en` khi catalog chưa có
    `en` → `vi`) thay test cũ luôn đúng; câu Decisions bước 7a về nguồn ngôn ngữ sửa theo quyết định hiện hành. N2 để 7c.

- 2026-10-17: **Nt0 chốt** (hai câu hỏi của bước 7b, PR #51):
  - **Đọc lại file có vấn đề**: mỗi file có vấn đề (File hỏng, Đề có lỗi, Có lỗi) trong Thư viện được đọc lại một lần mỗi
    lần mở app, thay vì lưu lý do có mã vào kho: **chấp nhận**. Thẻ hiện "Đang kiểm tra" rất ngắn.
  - **Tên mặc định app ghi vào nội dung đề** ("Đề mới", "Phần 1", "Phần N" khi thêm phần, "Phần chung" khi import, và
    tên tương tự khác): theo **ngôn ngữ giao diện lúc tạo** (tiếng Anh "New Exam", "Section 1"); sau khi tạo là nội dung
    đề, không bao giờ dịch lại. Làm ở bước 7c, không làm ở 7b (Approach bước 7c).
- 2026-10-17 (sửa theo review độc lập #51 @89f9a80, không có lỗi chặn):
  - **S1 luật `core-text`**: lõi đổi tên câu nhật ký mới của PR này cho thống nhất với target dữ liệu
    (`JSONProblem.logMessage`, `MigrationProblem.logMessage(from:)`, `WriteProblem.logMessage`; trước đó là `message`,
    lọt khỏi luật); thêm `.logName` (`VceField`); `.message` của `ValidationIssue` bắt theo tên biến (`issue…`) **và**
    theo biến khai báo kiểu `ValidationIssue`/`[ValidationIssue]` trong cùng file; không báo
    `ErrorMessages.message(for:)`/`AuthoringMessages.message(for:)`. Đổi tên biến cục bộ ở `PreExamModel`/`PreExamView`
    (`blocking`, `blockers`) nên bỏ được hai dòng `// l10n-ignore` (dấu đó tắt mọi luật trên dòng). Giới hạn còn lại, ghi
    ở script và ghi chú 7b: vấn đề nằm trong biến tên khác có kiểu suy ra (`let x = issues[0]`, `$0`) thì luật không thấy;
    test so câu theo mã bù. Đã cân nhắc `@_spi` cho `ValidationIssue.message` (chặn lúc biên dịch) nhưng bỏ: đổi bề mặt
    API của lõi, ngoài phạm vi "thêm tối thiểu". Đối chứng âm mới: 6; đối chứng dương mới: 6.
  - **N-a** số phiên bản định dạng (`unsupportedVersion`, `invalidVersion`, `migrationFailed`) là mã: chữ số trơn
    (`String(…)`), không "v1.000"; test ở phiên bản 1000.
  - **N-b** giới hạn số entry của `.docx` ghi "(tối đa N entry)" thay "byte" ở cả câu nhật ký của ExamImport và khoá giao
    diện (import.md vốn ghi "20.000 entry", không phải sửa). Đổi chữ người dùng thấy, ghi trong PR.
  - **N-c** `ErrorMessages.message(for: ValidationIssue)` switch đủ case của `IssueCode` (không `default`) và đổi
    `IssueLocation` sang số thứ tự bằng một switch đủ case: mã hay loại vị trí mới thì trình biên dịch buộc xét.
  - **N-d** test id trùng mà nơi xuất hiện trước là một phần. **N-e** câu tài liệu: model V1 không đổi, chỉ cách chuyển
    `FileVerdict` ↔ trường lưu đổi. **N-f** không đổi các câu ghép tay của `.vce` (RVF, `unsupportedContent`); ghi chú cho
    người dịch ở Approach bước 7c.
- 2026-10-17 (bước 7c, bản tiếng Anh; chi tiết ở accessibility-localization.md "Ghi chú hiện thực (giai đoạn 5, bước
  7c)"):
  - **Cách ghi bản dịch:** script sửa đúng `localizations.en` trong JSON của catalog, rồi `xcodebuild -exportLocalizations`
    hai scheme ghi lại theo định dạng của Xcode; lần xuất thứ hai không đổi byte nào. Không dùng XLIFF
    (`-importLocalizations`): XLIFF xuất ra chỉ có biến thể plural cho khoá đã có biến thể, không tạo được `one`/`other`
    mới. Khoá và giá trị `vi` không đổi (đã so trước/sau), trừ tên kiểu tài liệu và các khoá mới/bỏ ghi dưới.
  - **Thuật ngữ ngoài bảng** do agent đề xuất, ghi vào bảng thứ hai của accessibility-localization.md, chờ Nt0 duyệt
    (phương án 4); Nt0 duyệt 2026-10-17 (mục dưới). Đáng chú ý: menu **Bài thi** của cửa sổ làm bài là "Attempt",
    không phải "Exam", vì bản Admin còn menu
    **Đề** của cửa sổ soạn đề và khoá "Đề" của AuthoringFeature dùng chung cho mục Đề và vị trí lỗi cấp đề ("Exam"): hai
    menu cùng tên "Exam" sẽ lẫn. Câu tiếp theo (Return) là "Continue" để menu không có hai mục "Next Question".
  - **Số nhiều:** plural `one`/`other` cho khoá một số đếm; substitution cho khoá nhiều số; giới hạn lớn và số luôn ≥ 2
    theo code không dùng plural. Chuỗi `en` nhiều đối số luôn có số vị trí; `--require-en` so đối số theo số vị trí và kiểu
    (cho phép đổi thứ tự), đòi số vị trí khi có substitution (`check_localization.py`: 13 đối chứng âm, 7 dương cho catalog; app đã build thêm đối chứng N2).
  - **Câu ghép tay (N-f):** giữ nguyên cách ghép, dịch từng cụm để câu ghép đọc được. Đổi thành câu trọn vẹn một chỗ:
    tiêu đề Thư viện trống theo bộ lọc ("Không có đề nào" + tên bộ lọc viết thường) thành một khoá mỗi bộ lọc
    (`LibraryFilter.emptyTitle`), chữ tiếng Việt không đổi.
  - **Tên mặc định ghi vào đề** (Nt0 chốt 2026-10-17): tên đi vào target dữ liệu từ tầng giao diện
    (`DefaultContentNames`, `sharedSectionTitle:`), mặc định tiếng Việt cho test và nơi không có giao diện; target dữ liệu
    vẫn không có catalog, không SwiftUI/AppKit. Số của "Phần N"/"Section N" là chữ số trơn (khoá "Phần %@"): tên là nội
    dung đề, như mặc định tiếng Việt của AuthoringData trước đây. Câu VoiceOver đổi câu nhận cả "Section <số>" là tên phần
    đã đánh số.
  - **Test PDF tiếng Anh:** `InterfaceStrings.languageOverride` (task-local, internal, chỉ cho test) thắng ngôn ngữ đã
    khoá của tiến trình test, để dựng cả luồng Kết quả → PDF bằng chữ `en`. App không đặt nên không đổi hành vi. Đã cân
    nhắc thêm tham số ngôn ngữ cho `ResultsReport`/`ReportStrings` nhưng bỏ: chạm nhiều hàm chỉ để test.
  - **Review #50 N2:** kiểm cả hai lớp: app đã build (`--built-apps`, mọi bundle catalog cùng `*.lproj`, có `en`) và
    bundle của `swift test` (`CatalogLanguagesTests`).
  - **InfoPlist:** `vi` của tên kiểu tài liệu là "Đề Exam Suite"; `--built-apps` so chuỗi đã build với bản của catalog
    từng ngôn ngữ (trước đây so với giá trị gốc), tên app luôn bằng giá trị gốc.
  - **Ghi nhận:** PDF dùng chữ ghép "ﬃ" của Helvetica Neue ("oﬃcial" khi đọc lại bằng PDFKit); không sửa ở 7c, việc của
    bước 8 (Progress).
- 2026-10-17: **Nt0 chốt** (PR #52): menu "Bài thi" và cửa sổ "Làm bài" của phiên thi là "Attempt"; "Câu tiếp theo"
  (Return) là "Continue"; mọi thuật ngữ đề xuất của bước 7c được duyệt như đề xuất, kể cả "With Problems" (bảng thuật ngữ
  thứ hai của accessibility-localization.md ghi "Nt0 duyệt 2026-10-17"), cùng các chỉnh câu chữ của review độc lập #52.
- 2026-10-17 (sửa theo review độc lập #52 @750d332, approve kèm sửa):
  - **S1** UI test tiếng Anh: phần tử "chỉ có chữ giao diện" khớp định danh nguyên văn, bỏ `question.position` và
    `answerReview.status` (nằm trong phần tử gộp có tên phần, là nội dung đề), để phép kiểm không báo nhầm nội dung đề.
  - **S2** snapshot tiếng Anh 960×640 (ảnh sáng) cho làm bài (Luyện tập, bảng câu hỏi mở), Kết quả, Xem lại bài:
    `SnapshotHost.inLanguage` ép ngôn ngữ cho cả tiến trình (`InterfaceStrings.processLanguageOverride`, internal, chỉ cho
    test; task-local không đủ vì SwiftUI dựng lại view ngoài task của test; suite snapshot chạy tuần tự);
    `InterfaceLocale.current` cũng theo ngôn ngữ test đang ép để số/ngày cùng ngôn ngữ với chữ (app: không đổi).
  - **S3** "Tìm trong cây đề" (menu Sửa) → "Find in Outline". **S4** `--require-en`: dạng `other` của plural đủ đối số
    của nguồn, của substitution có `%arg`; 2 đối chứng âm. **S5** bước 7, 7c để `[ ]` tới khi `local/verify --uitest`
    xanh.
  - **N1** tiêu đề hộp báo khi thao tác soạn đề lỗi: `EditAction` (tên bước Hoàn tác + tiêu đề hộp báo), mỗi thao tác một
    khoá câu trọn vẹn thay khoá ghép "Không %@ được"; tiếng Việt không đổi (test so với cách ghép cũ cho mọi thao tác).
  - **N2** chữ đã tra không giữ trong `static let` (`AnswerReviewModel`, `ResultsModel`, `PreExamModel`,
    `SessionCoordinator`): tính mỗi lần đọc. **N3** `UITestLanguage` ra khỏi giữa chú thích và lớp `IsolatedApp`.
  - **N4** câu chữ tiếng Anh: "Result: …" (VoiceOver), "By Section" (Kết quả, cùng PDF; nhóm lựa chọn của Trước khi thi
    vì vậy Title Case: "All Questions (N)", "N Random Questions"), "Question Selection", "Exam Settings" (mục của soạn
    đề), "Show Results", tên ảnh "named after its SHA-256 hash", "so Practice mode isn’t available", "time limit for Exam
    mode", "Press %@", "Passing score %@"/"passing score %@", "Library" viết hoa khi gọi tên Thư viện.
  - **N5** accessibility-localization.md "Cách làm" ghi đúng target có catalog. **N6** luật `test-hook` của
    `check_localization.py` (có đối chứng âm): chỗ ép ngôn ngữ chỉ cho test không có trong code của app.

- 2026-10-18 (bước 8a; nhánh `feature/g5-bo-cuc`, dựng trên #52 `f4f24fa`):
  - **Tách bước 8** thành 8a (bố cục, Dark Mode, PDF, cửa sổ xếp lát) và 8b (trợ năng) theo yêu cầu của người điều phối
    (Approach bước 8, Progress).
  - **Cách chụp chữ và biểu tượng vibrant** (`GlassFlattener`): lớp chữ/biểu tượng trên kính (thanh bên, inspector) có
    bộ lọc `vibrantColorMatrix`; nội dung chữ của SwiftUI là `CATintedImage`/backing store (không phải `CGImage`) nên
    trước đây không được đổi màu (chữ thanh bên ra màu gốc đen: gần như không đọc được ở ảnh **tối**), còn biểu tượng SF
    Symbols có màu nhân `contentsMultiplyColor` mà `render(in:)` vẽ mất (biểu tượng ảnh/nhiều đáp án của cây đề, biểu
    tượng Gần đây/Lịch sử thi của Thư viện **không thấy** ở ảnh sáng). Chẩn đoán bằng cây lớp (loại nội dung, ma trận:
    sáng R' = R − 1, A' = 0,55·A cho `.secondary`; tối R' = R + 1, A' = 0,6·A). Nay vẽ nội dung của lớp ra ảnh bằng
    `render(in:)` (lật lại khi lớp lật nội dung), áp ma trận rồi đặt vào một lớp con tạm; ghi lại 22 ảnh có thanh
    bên/inspector, giao diện app không đổi. Còn lại không đổi: kính và vật liệu (`.bar`) vẫn ẩn khi chụp.
  - **Vấn đề bố cục của snapshot** (Decisions 2026-10-16/17, bước 3):
    - (b) thanh dưới cửa sổ làm bài: đã sửa ở #52 (`ViewThatFits`), xác nhận trên ảnh `attemptPracticeCheckedAnswer`
      (Luyện tập, có bảng câu hỏi: Câu trước/Câu sau chỉ biểu tượng, không chữ nào bị cắt) và `attemptLargeImage` (Thi:
      đủ nhãn).
    - (d) ảnh câu hỏi nhỏ hơn khung: **sửa**, bo góc và viền đặt trước khung nên bao đúng ảnh (`QuestionImageView`; cửa
      sổ làm bài, Xem lại bài, xem trước Soạn đề). Không đổi ý nghĩa của viền (vẫn là viền của ảnh); phần trống bên phải
      không còn bấm để phóng to.
    - Tiêu đề phần quanh "Câu 1/40" ở xem trước: **sửa**, `ViewThatFits` một dòng hoặc hai dòng (tên phần trên, số câu
      dưới). Nhãn "Đáp án đúng" hai dòng ở xem trước: **sửa**, nhãn một dòng ngay dưới chữ của lựa chọn (cột 240–340 pt;
      đặt bên phải thì chữ lựa chọn chỉ còn ~50 pt). Cửa sổ làm bài giữ nhãn bên phải.
    - Thanh "Thêm phần / Thêm câu" chồng lên chữ dòng cây phía sau: **do cách chụp**. Nền của thanh là `.background(.bar)`,
      cây lớp cho thấy đó là `CABackdropLayer` (bộ lọc `gaussianBlur`) cộng lớp tô nền: WindowServer làm mờ chữ phía sau,
      còn khi chụp lớp backdrop bị ẩn (không vẽ được trong tiến trình) nên chữ hiện rõ. Cuộn dưới thanh là cách của
      macOS; test tay xem trên app thật.
    - Biểu tượng ảnh/nhiều đáp án của dòng cây chưa chọn gần như không thấy ở ảnh sáng: **do cách chụp** (mục trên). Sau
      khi sửa cách chụp, biểu tượng xám (115,115,115) trên nền trắng 4,74:1, trên nền kính sáng ~(236) ~4,0:1; ảnh tối
      (165) trên (30) 6,77:1: đạt "biểu tượng ≥ 3:1" (màu `.secondary` của hệ thống, theo vibrancy). Biểu tượng
      Đúng/Sai ở danh sách câu của Xem lại bài (thanh bên) ra đen/trắng thay vì xanh/đỏ ở ảnh (chữ vẫn màu, cả trước khi
      sửa cách chụp): lớp đó có ma trận vibrancy của chữ chính, cần xem trên app thật (Nt0 2026-10-18: giữ, vào danh
      sách test tay).
    - **(c) Thư viện dạng danh sách ở 960** (đổi những gì người dùng thấy nên hỏi Nt0 trước). Đo: vùng bảng ở cửa sổ
      960 có thanh bên rộng ~742 pt; mỗi cột tốn thêm ~17 pt (khoảng cách ô) nên 8 cột ở độ rộng **lý tưởng** cần ~1.113
      pt, ở độ rộng **tối thiểu** khai báo vẫn cần ~863 pt (> 742); chữ thật cần: "Không tìm thấy file" + biểu tượng
      ~135 pt, "82% · 14/10/2026 · Đậu" + biểu tượng ~170 pt. Không thể hiện đủ 8 cột ở 960 có thanh bên mà không cắt chữ.
      Phương án: (A) đưa cột **Trạng thái** lên ngay sau Tên đề (không bỏ cột nào; trạng thái cần xử lý luôn thấy; cột
      Lần thi gần nhất có thể phải cuộn ngang) — agent đề xuất; (B) gộp Số câu và Số phần thành một cột "40 câu · 3
      phần"; (C) cho ẩn/hiện, sắp lại cột (`TableColumnCustomization`, nhớ lựa chọn); (D) rút gọn "Lần thi gần nhất"
      (ví dụ bỏ chữ Đậu/Trượt, trái library.md "biểu tượng + chữ"); (E) giữ như hiện nay (cuộn ngang). **Nt0 chốt
      2026-10-18: phương án A**: cột Trạng thái ngay sau Tên đề, các cột ít quan trọng hơn vẫn có thể phải cuộn ngang ở
      cửa sổ hẹp; thứ tự cột ghi vào library.md. Ảnh `libraryList` sáng/tối: thấy "Không tìm thấy file", "Đề có lỗi"
      không cần cuộn. Không test nào phụ thuộc thứ tự cột (UI test chỉ tìm ô Mã đề theo chữ).
  - **Cửa sổ xếp lát** (Decisions 2026-10-17 "Thư viện trống"): rà mọi `Text` có `fixedSize` dọc. Trong `ScrollView`/
    `List`/`Form` hay sheet có độ rộng cố định thì an toàn. Ngoài vùng cuộn còn hai chỗ: dải thông báo của phiên thi
    (`SessionBannerView`; ở cửa sổ làm bài nó nằm trên vùng cuộn của câu hỏi: cảnh báo giờ, hết giờ) và lý do không xem
    lại được ở thanh nút Kết quả. Sửa bằng độ rộng tối thiểu `SessionStyle.wrappingTextMinWidth` (320 pt, như
    `LibraryStyle.bannerTextMinWidth`); ảnh snapshot không đổi. Thông báo chân Thư viện có `lineLimit(3)`; thanh lỗi soạn
    đề `lineLimit(2)`; cửa sổ Import đề rộng cố định 420/480 pt.
    - Test đo `TiledWindowLayoutTests` (ExamFeaturesSnapshotTests): `NSHostingController.sizeThatFits(.zero)` của nội dung
      từng cột (cách SwiftUI đo khi khôi phục khung xếp lát) không cao hơn 640 pt: dải thông báo, Kết quả có lý do dài,
      Thư viện có dải chào mừng (lưới, danh sách; lỗi gốc #48), các cột soạn đề (mọi loại dòng, báo cáo import, danh
      sách lỗi). Đối chứng âm: bỏ độ rộng tối thiểu thì đỏ (dải 884 pt; Kết quả và Thư viện vượt 640 pt). Cả màn làm bài
      có `.inspector` nên đo ra 0, kiểm qua dải thông báo.
    - UI test `SessionWindowRestoreUITests` (Học viên, `-NSWindow Frame session` với khung xếp lát của #48, dùng chung
      `Support/TiledWindow.swift` với `LibraryWindowRestoreUITests`). Log `verify_local.sh --uitest` trên `7836992`:
      "Cửa sổ session: khung (86.0, 32.0, 1180.0, 780.0), KHÔNG dùng khung xếp lát đã lưu" (Thư viện thì có dùng): khung
      đã lưu không được áp vì scene có `.restorationBehavior(.disabled)` (thử nghiệm ở Decisions bước 8b chứng minh), và
      lần chạy đó **không** kiểm cửa sổ xếp lát nào. Sửa theo review #53 S1: test nay khẳng định điều đúng (cửa sổ làm bài không dùng khung xếp lát đã lưu, rộng
      khác 1.352 pt), phần làm bài/Rà soát/Kết quả/Xem lại trong cửa sổ chỉ là kiểm bố cục chung.
    - Cửa sổ soạn đề (`DocumentGroup`): code không đặt tên autosave khung, cửa sổ tài liệu của AppKit mặc định không có,
      và không có tên cố định để truyền `-NSWindow Frame …` (nhiều cửa sổ cùng lúc), nên không có UI test khung xếp lát;
      chưa kiểm được trên app SwiftUI có đặt hay không. Các cột của nó có trong test đo; khôi phục cửa sổ tài liệu khi mở
      lại app (Resume) và kéo xếp lát để test tay.
  - **Snapshot tối/sáng còn thiếu**: Trước khi thi (`preExamSheet`, 600×640, nội dung sheet trong cửa sổ chụp) và báo cáo
    import (`authoringImportReport`). Trang 1 PDF (export-print.md, Kiểm chứng): `resultsPDFFirstPage`,
    `examPDFFirstPage` (`ReportSnapshotTests`; PDF dựng bằng `ReportRenderer`, trang vẽ ra ảnh 1x bằng Core Graphics,
    cùng độ chính xác; tên `<test>.light-a4-page1.png`). Ghi nhận: đề có câu 1 dài (đề soạn thử của snapshot, 10 lựa
    chọn, có đáp án) thì trang 1 PDF đề chỉ có khối thông tin đề, Phần 1 và câu 1 sang trang 2 (quy tắc giữ khối câu trọn
    một trang và đề mục phần không đứng một mình); trông như trang bìa dù phương án 19 nói "không có trang bìa riêng".
    **Nt0 chốt 2026-10-18: chấp nhận như hiện nay**, giữ khối câu trọn một trang được ưu tiên (ghi cạnh phương án 19
    của export-print.md); không đổi code.
  - **PDF không chữ ghép**: `ReportTypography.body` tạo `CTFont` tắt chữ ghép thường (`kLigaturesType`/
    `kCommonLigaturesOffSelector` và OpenType `liga` = 0), giữ một `Font` cho mỗi phông và cỡ (`Mutex`). SF Mono không có
    chữ ghép thường (đã kiểm), giữ nguyên. Test `noLigatures` (đỏ với phông cũ) và `EnglishResultsReportTests` (bỏ NFKC).
    Đo lại (Debug, M4 Pro, lần nhanh nhất của 3, cùng máy cùng lúc): PDF kết quả Xem lại tất cả 12,16 s → 12,26 s, PDF
    đề có đáp án 10,94 s → 10,98 s; không giữ `Font` thì 13,52 s / 12,21 s (+11 %).
  - **Bẫy build incremental** (2026-10-18, `verify_local.sh` incremental trên worktree từng build ở commit cũ, trên
    `f4f24fa`: mọi phép tra `en` ra tiếng Việt; cùng SHA `--clean` đạt): `swift test` đọc **bản sao** bundle tài nguyên
    trong từng `.xctest/Contents/Resources/`, không đọc `Products/Debug/ExamFeatures_*.bundle`. Thử (≤ 30 phút, không
    mở app): bundle có `_CodeSignature` cũ (không liệt kê `en.lproj`) hoặc không có chữ ký, và bundle có thêm `en.lproj`
    sau khi đã được đọc ở tiến trình trước (cùng đường dẫn, cả khi giữ mtime thư mục): tiến trình mới đều tra được `en`.
    Vậy Info.plist/`_CodeSignature` cũ và cache CFBundle theo thư mục **không** giải thích được; nhiều khả năng bản sao
    trong `.xctest` cũ (Info.plist/chữ ký cũ cho thấy bước dựng bundle không chạy lại). Gói thử nhỏ (vi → thêm en → bỏ →
    thêm lại, incremental) chép lại đúng, nên chưa tái hiện được nguyên nhân chính xác. Cách xử lý: `--clean` hoặc xoá
    `Packages/ExamFeatures/.build` sau khi catalog có thêm ngôn ngữ (AGENTS.md, mục Lệnh kiểm chứng); `verify_local.sh`
    (không `--clean`) nay tự xoá `Packages/ExamFeatures/.build` trước `check.sh` khi bundle ở Products hay bản sao trong
    `.xctest` thiếu `<ngôn ngữ>.lproj` của catalog, hoặc bản sao khác bản ở Products (đã thử: bản build sạch không báo;
    bản sao thiếu `en.lproj`, khác nội dung đều báo).
  - **Test chập chờn**: `printTemporaryFileTracked` ("Ghi PDF ra file") bắt mọi file `ExamSuiteReport-*` của thư mục
    tạm hệ thống lúc đang dựng, nên khi chạy song song với "Bộ dựng trang PDF" (cũng dựng PDF vào bộ nhớ; thêm
    `noLigatures`) đôi khi bắt nhầm file của test khác (đỏ một lần ở `check.sh`). Chuyển sang suite tuần tự
    `ReportRendererTests`; không đổi điều test kiểm.
  - **Sửa theo review độc lập #53** (approve kèm sửa, không lỗi chặn; `local/verify` có UI test xanh trên `7836992`):
    - **S1** cửa sổ làm bài không có khôi phục khung xếp lát (mục Cửa sổ xếp lát ở trên): `SessionWindowRestoreUITests`
      khẳng định cửa sổ **không** dùng khung xếp lát đã lưu; plan, AGENTS.md, PR không còn nói UI test phủ khôi phục khung
      xếp lát của cửa sổ làm bài. `TiledWindowLayoutTests` bỏ đối chứng âm bằng `Text` tự dựng, đo **chính view thật**:
      `SessionBannerView`, `ReviewUnavailableReason` (lý do ở thanh nút Kết quả, tách thành view riêng) và `BannerView` của
      Thư viện nhận `textMinWidth` (mặc định là độ rộng tối thiểu; chỉ test đổi): có độ rộng tối thiểu < 200 pt ở độ rộng
      0, `nil` thì > 640 pt.
    - **S2** `verify_local.sh`: chạy lại bước kiểm bundle tài nguyên **sau** `check.sh` và thất bại nếu còn báo (bằng
      chứng tự kiểm đúng bản build vừa dùng); đặt `STEP` trước bước kiểm; khi buộc build lại thì status ghi
      "incremental, ExamFeatures build lại". Thử bằng bộ dựng thử (đoạn script thật, `check.sh` giả): năm trường hợp
      (sạch; cũ trước rồi build lại; bản sao khác sau `check.sh`; catalog hỏng; `--clean` mà bản sao thiếu `en.lproj`)
      đúng kết quả và tên bước.
    - **S3** tương phản chữ `.secondary` dưới 4,5:1 thấy được sau khi sửa cách chụp: đoạn đầu nội dung câu ở thanh bên Xem
      lại bài (126) trên trắng 4,06:1, trên dòng đang chọn 3,72:1; dòng đang chọn ở giao diện tối 4,45:1; số đếm thanh bên
      Thư viện 4,42:1. Không sửa ở 8a; chuyển cho 8b kèm câu hỏi màu ngữ nghĩa hệ thống được miễn hay phải thay (Progress
      8b).
    - **Trang 1 PDF kết quả** cũng chịu quy tắc giữ khối: trang 1 hết sau "Theo phần", còn ~235 pt trống, đề mục Xem lại
      bài và câu sai đầu tiên sang trang 2 (như PDF đề có câu 1 dài ở trên; Nt0 chốt chấp nhận giữ khối câu trọn trang).
    - Nit: chú thích `preExamSheet` (bỏ chọn phần 1–2, còn phần 3–8, 30 câu), `resultsPDFFirstPage`, `GlassFlattener` (chữ
      vibrant ra màu gốc đen, không phải trắng); `ExamImport`, `ReportFeature` khai báo là phụ thuộc của
      `ExamFeaturesSnapshotTests` trong Package.swift (target đó import chúng; `check_boundaries.py` vẫn đạt);
      `.fixedSize()` của nhãn "Đáp án đúng" ở xem trước vào 8b (⌘+).
    - **Để sau (không làm):** ảnh chụp dùng `deviceRGB` và làm mịn phông mặc định của ngữ cảnh bitmap (`SnapshotHost`);
      đổi sang sRGB/tắt làm mịn có thể ổn định hơn giữa máy nhưng phải ghi lại mọi ảnh.
  - **Sửa nhỏ theo re-review #52**: `InterfaceStrings.processLanguageOverride` qua `Mutex<Locale?>`; `SnapshotHost.inLanguage`
    kiểm tiến trình trước khi ép ngôn ngữ; chú thích thanh dưới cửa sổ làm bài; câu "Snapshot tiếng Việt không đổi" của
    bước 7c (Progress) và accessibility-localization.md (snapshot tiếng Anh đã có).

- 2026-10-18 (bước 8b; nhánh `feature/g5-tro-nang`, dựng trên #53 `548f380`):
  - **Nt0 chốt 2026-10-18: màu ngữ nghĩa của hệ thống được miễn** quy tắc 4,5:1 (chữ) / 3:1 (chữ lớn, biểu tượng) của app:
    `.secondary`, `.primary`, `.separator`, nền cửa sổ theo Dark Mode và Increase Contrast của macOS, Increase Contrast kiểm
    tay. Quy tắc áp cho màu app tự định nghĩa (`LibraryPalette`, `AuthoringPalette`, `SessionStyle`, màu PDF) và mọi nền
    pha màu/có độ trong mà app đặt. Các số đo chữ `.secondary` của review #53 (4,06:1; 3,72:1; 4,45:1; 4,42:1) vì vậy
    không phải sửa. Ghi ở accessibility-localization.md (Dark Mode và tương phản).
  - **Màu của bảng làm chữ** (đo bằng test, không đổi quy tắc): "Đúng", "Sai", "Đã đánh dấu", "Phần yếu nhất", lỗi của
    hộp xác nhận import mang màu xanh/cam/đỏ của bảng, nên test đòi mức chữ nhỏ 4,5:1 (trước đây chỉ biểu tượng 3:1) trên
    mọi nền và trên hàng lựa chọn đã chọn. Hai chỗ chưa đạt và đã đổi: xanh sáng `#1E7B34` → `#1C7631` (4,45:1 → 4,75:1 trên
    hàng đã chọn), đỏ tối `#FF6961` → `#FF8077` (4,03:1 → 4,66:1 trên `#3A3A3A`); ảnh sáng đổi dưới ngưỡng so ảnh, 6 ảnh tối
    có màu đỏ ghi lại. Nền cửa sổ thật đọc lúc chạy (`windowBackgroundColor`: macOS 26 sáng `#FFFFFF`, tối `#1E1E1E`).
  - **Dòng đang chọn**: màu của bảng trên nền chọn đậm (teal, burgundy) gần như không thấy, nên dùng chữ của hệ thống
    (`paletteForeground` theo `backgroundProminence`) cho trạng thái, kết quả, nhãn Đề mẫu, biểu tượng của cây đề và danh
    sách câu Xem lại bài; cây đề đặt tint burgundy đặc `#801638` (tint của cửa sổ ở giao diện tối `#F7A1B8`, chữ trắng chỉ
    ~1,9:1). Có xảy ra trên app thật hay không (tint của danh sách khi có tiêu điểm) là việc test tay.
  - **Reduce Transparency**: thay bằng **màu đặc cùng sắc** (nền pha màu: màu đã trộn sẵn trên nền cửa sổ thật; `.bar`, vật
    liệu: nền cửa sổ), không bỏ nền, để bố cục và màu nhìn như cũ. Nền trung tính (`.quaternary` có độ mờ: khung giải
    thích, ô số, rãnh thanh điểm) cũng đi qua cùng cách cho đủ "nền có độ trong mà app đặt".
  - **Kiểm trợ năng tự động**: gom vấn đề của mọi màn rồi làm test thất bại một lần khi test kết thúc (thay vì dừng ở màn
    đầu), để một lần `verify_local.sh --uitest` cho đủ danh sách; mỗi màn một lần kiểm. Chưa ghi ngoại lệ nào (chưa có số
    liệu: agent không chạy UI test); nếu kiểm `contrast` báo chữ màu hệ thống thì ghi ngoại lệ theo quyết định trên.
  - **Cỡ chữ nội dung**: một mức cho cả app (khoá `content.zoomPercent`); ba mục menu đi kèm scene cửa sổ làm bài (có ở cả
    hai bản), tắt ở giới hạn và khi cửa sổ đang dùng không có nội dung câu: Kết quả không có (không có nội dung câu), soạn
    đề chỉ khi xem trước đang mở. Phạm vi đổi cỡ theo phương án 5: nội dung câu (đầu câu, nội dung, lựa chọn, kết quả kiểm
    tra, giải thích; ở Xem lại bài thêm dòng báo "đã sửa"), không đổi thanh công cụ, đồng hồ, thanh nút, bảng câu hỏi, Rà
    soát, danh sách câu, dải cảnh báo giờ. Phím ⌘+ là phím có Shift trên bàn phím Mỹ (⌘⇧=); ⌘= có kích hoạt hay không là
    việc test tay.
  - **Lưu xong** (VoiceOver): lưu là của `DocumentGroup`/`NSDocument`, không có lời gọi lại; app theo dõi lệnh Lưu/Lưu
    thành… của cửa sổ (`NSMenu.didSendActionNotification`) rồi chờ document có file và hết "Đã sửa" (tối đa 120 giây, gồm
    lúc hộp Lưu đang mở); tự lưu không đọc. Chưa kiểm được trên app thật (agent không lái app): test tay VoiceOver.
  - **Thử nghiệm nguyên nhân cửa sổ làm bài không dùng khung đã lưu** (re-review #53 (a)): commit cục bộ trên nhánh
    `scratch/g5-8b-restoration-experiment` (không push, không vào PR), dựng trên `548f380`, chỉ bỏ
    `.restorationBehavior(.disabled)`. **Kết quả 2026-10-18** (người điều phối, commit thử `20120bf`, chỉ một UI test
    `-only-testing:ExamSuiteUITests/SessionWindowRestoreUITests`): test đỏ, log "Cửa sổ session: khung (0.0, 30.0, 1352.0,
    783.0), đã dùng khung xếp lát đã lưu", assertion dòng 37 đỏ. Vậy modifier **là** nguyên nhân; AGENTS.md, plan và thông
    báo của test ghi lại quan hệ nhân quả, và test giữ đúng modifier này. Nhánh thử đã xoá, không push.
  - **Lần chạy UI test đầu của kiểm trợ năng** (`verify_local.sh --uitest` trên 6c59532: 4 test đỏ vì audit, 136 vấn đề;
    `LibraryWindowRestoreUITests` đỏ vì tiêu đề dải chào mừng thành đề mục nên không còn là `staticText`, test tìm mọi loại
    phần tử theo đúng chữ). Sửa trong app những gì là lỗi của app, ghi ngoại lệ hẹp cho màu hệ thống, phần tử của macOS và
    báo nhầm (accessibility-localization.md, ghi chú bước 8b; danh sách đủ trong `AccessibilityAudit.swift` và PR). Chạy lại
    riêng từng UI test có audit (Học viên PracticeFlow, ExportResults, LibraryWindowRestore; Admin ImportExam, NewExamFlow):
    đạt.
  - **Sửa theo review độc lập #54** (không lỗi chặn): S1 nhãn Đúng/Sai sau Kiểm tra đáp án vẽ ngoài nút bị khoá (đo trên
    ảnh: `CheckedAnswerContrastTests`; audit sau ⌘K trong PracticeFlowUITests); S2 test tương phản tính cả nền cửa sổ của
    macOS 15 (`#ECECEC`, `#323232`), đổi màu: xanh sáng `#196B2D`, cam sáng `#934A00`, đỏ sáng `#B22719`, đỏ tối `#FF918A`
    (ghi lại ảnh có các màu đó, sáng và tối); S3 "Đã lưu" chỉ khi file thật sự được ghi sau lệnh (ngày sửa file hoặc đường
    dẫn đổi), gỡ observer trong `deinit`, test trường hợp Lưu thành… bị huỷ; S4 ⌘= cũng Phóng to, UI test bấm ⌘= và ⌘0 rồi
    kiểm Cỡ thật bật/tắt; S5 Lịch sử thi dựng chữ ô từ `historyRowCells`. Nit: `check_colors.py` bắt thêm
    `SwiftUI.Color(red:`, `Color.init(red:`, `#colorLiteral`, hex có `_` và 8 chữ số, `Color("Asset")`, `NSColor(named:)`,
    `NSColor(name:)` (có đối chứng âm); "Thu nhỏ" giữ theo phương án 5 dù trùng Cửa sổ › Thu nhỏ (test tay); cây đề chọn bằng
    burgundy vẫn là test tay.
  - **`verify_local.sh --uitest` trên 2213e92**: Học viên đạt hết, mọi test có audit đạt; Admin `EditExamFlowUITests` đỏ vì
    dòng cây đề mang vai trò chữ tĩnh làm nhãn rỗng (câu đọc sang giá trị). Sửa: dòng cây đề là nút có hành động chọn dòng
    (nhãn và định danh cùng phần tử). Re-review: ngoại lệ cửa sổ không hoạt động chỉ cho chữ màu hệ thống đã biết, số đếm
    `^\d+$` chỉ ở thanh bên/cây đề, nhóm có nhãn của bảng câu hỏi là nhóm chứa, đối chứng âm cho `CheckedAnswerContrastTests`
    (nhãn trong nút khoá đo dưới 4,5:1), `check_colors.py` chỉ bỏ qua hex khi mọi nhóm đúng 4 chữ số. Chạy riêng cả target
    UI test Admin (6 test) và Học viên (10 test): đạt.

- 2026-10-18, Nt0: **tối ưu các bước còn lại theo notes/g5-ui-test-trung-lap.md và plan-android-v1 Phần 1.**
  - Bước 9 gồm cả T1, T2, T5 (script và quy trình, rủi ro thường) và hai tài liệu nguồn; bước 10 gộp T3, T4, tài liệu,
    CHANGELOG, số đo cuối, cổng `--clean --uitest`, đóng plan, lập plan giai đoạn 6 và cài app vào **một** PR (rủi ro cao,
    chạm `Apps/**`); giai đoạn 6 (DMG, ký) trong ít PR nhất, CI đúng một lần khi Nt0 báo (Approach bước 9–11).
  - Cách làm (a)–(f) (thẩm quyền: review-and-merge.md mục 4, áp dụng mọi giai đoạn) có hiệu lực ngay: một `verify_local.sh --uitest` mỗi PR trên SHA cuối sau review;
    re-review chỉ với rủi ro cao; chạy lại chỉ các lớp đã map; xếp chồng tối đa một tầng; sửa nhỏ/spike/plan đi cùng
    PR code; một việc nặng mỗi lúc.
  - Bảng map của T1 kiểm theo code thật (khác bảng đề xuất của notes; Nt0 chấp nhận, sửa theo review độc lập #55, mục
    dưới): `SessionWindowRestoreUITests` vào SessionFeature; `Apps/Student/**`, `Apps/Admin/**` như shell của bản đó;
    `Package.resolved`, `uitest_plan.py` là hạ tầng (đủ bộ); file code app không khớp dòng nào (target mới) → đủ bộ kèm
    cảnh báo.
- 2026-10-18 (bước 9): **gộp luồng Xuất PDF/In làm đủ** (không chỉ đổi tên): phần chung sạch (cùng bước, cùng huỷ,
  cùng hộp), khác nhau chỉ ở hộp chọn và cách dựng khối (PDF đề dựng ngoài main actor sau hộp lưu), truyền vào
  `export`/`print` bằng closure. Chữ "Đã xuất PDF", "Không xuất được PDF", "Không in được" vẫn tra catalog của từng target
  (`ReportFlowMessages`), để không đổi catalog. Móc test (`didRender`, `onFinish`, `cancelAll`, `sheetDismissed`,
  `waitUntilIdle`) dùng mức truy cập `package`. Static `appVersion` của `ReportServices.live` đổi tên `bundleVersion`
  (trùng tên thuộc tính).
- 2026-10-18 (bước 9): **lần gõ đầu vào ô tìm**: chọn dựng chỉ mục nền khi mở cửa sổ (không phải khi ô tìm nhận tiêu
  điểm), vì ~40 ms ngoài main actor là nhỏ so với thời gian tới lần gõ đầu, và nhờ đó ⌘F rồi gõ ngay cũng không chặn.
  Test đo chờ chỉ mục nền xong ngoài vùng đo (mô phỏng thời gian từ lúc mở cửa sổ tới lần gõ đầu). Nộp bài (~84 ms main
  actor Release) đạt nên không chuyển ra nền (chạm chấm điểm/lưu lần thi, rủi ro cao).

- 2026-10-18, **Nt0 chốt** (câu hỏi của PR #55):
  1. **Cỡ file PDF:** giữ ảnh 2× không mất dữ liệu; đặt **ngân sách cỡ file** để bắt cỡ file tăng: số đo bước 9 + ~20%,
     `PDFSizeBudget` (LargeExamSupport), test so ở mọi lần chạy (cỡ file không phụ thuộc máy): PDF kết quả "Xem lại tất
     cả" ≤ 130 MB (đo 108 MB), PDF đề có đáp án ≤ 126 MB (đo 105 MB), PDF đề chỉ đề ≤ 121 MB (đo 100 MB; chỉ đo trong
     `measure_large.sh`). Đóng việc mở của large-exams.md.
  2. **Nộp bài** (~84 ms main actor Release): giữ nguyên, chỉ theo dõi (`session.submit.mainActor`); không đổi chấm điểm
     hay lưu.
  3. **Bảng map T1** khác notes: chấp nhận, kèm sửa theo review.
- 2026-10-18, **sửa theo review độc lập #55** (REQUEST CHANGES, chỉ bảng map T1):
  - B1: LibraryFeature (PresentationTermination, InterfaceStrings/InterfaceLocale, ErrorMessages, LibraryPalette dùng ở
    mọi cửa sổ), LibraryData (kho, lần thi của Thử đề này, đề mẫu mà mọi UI test dùng) và SessionFeature
    (`SessionAppController` gắn trang trí Thư viện và menu, cả ⌘P của cửa sổ soạn đề qua `ReportCommandTarget`, vào mọi
    cửa sổ của hai bản) thành **đủ bộ**. S2: lõi `ExamKit`/`ExamFile` **đủ bộ** (luồng UI lưu/mở lại, đọc nghiêm, đồng hồ
    phiên); `LargeExamSupport` không chạy UI test; review-and-merge.md mục 2 sửa theo.
  - S1: tự kiểm tính trên **lớp chính** của các dòng module (không tính dòng shell vốn chọn mọi lớp): lớp chưa là lớp
    chính của module nào thì `verify_local.sh` chạy đủ bộ kèm cảnh báo và `check.sh` (`--self-test`) thất bại. N2: tìm lớp
    bằng `class X: XCTestCase` trong mọi file của `Apps/*UITests/**`. N1: `git diff --no-renames`. N3: code chế độ cô lập
    (`AppLaunchStorage`, `SessionServices`, `AuthoringWindow`) ghi trong hạ tầng đủ bộ.
  - S3: số đo chỉ để ghi (in thật 1.168 trang bằng `NSPrintOperation`, PDF đề chỉ đề) chỉ chạy khi
    `EXAMSUITE_MEASURE_RECORD=1` (`measure_large.sh`); test so giới hạn chặn và ngân sách cỡ file chạy ở mọi lần.
  - N4: chú thích của `reportExamWithAnswersMainActor` về đúng chỗ. N5: lần dựng chỉ mục tìm nền dừng giữa chừng khi bị
    huỷ hoặc bộ soạn đề không còn (`TreeSearchIndex(_:isCancelled:)`, `withTaskCancellationHandler`; test). N6: dòng UI
    test của bảng bất biến (AGENTS.md) ghi cách chọn lớp.
- 2026-10-18, Nt0: nhịp làm việc và chính sách chọn UI test áp dụng **mọi giai đoạn còn lại**, ghi vào thẩm quyền quy
  trình lâu dài: review-and-merge.md mục 4 (mới), AGENTS.md (Quy tắc làm việc trỏ tới), plan-macos-v1.md (Lộ trình: giai
  đoạn 6 và sau theo nhịp này). docs/WORKFLOW.md không có chỗ nào trái (chỉ nói chung về plan), không sửa. Mục 3 của
  review-and-merge.md (review độc lập "sau khi `local/verify` xanh") sửa thành review trước, `local/verify` sau.

- 2026-10-18 (bước 10, T3/T4, chi tiết cài đặt theo notes/g5-ui-test-trung-lap.md mục T3, T4; không phải chính sách sản
  phẩm mới):
  - **Hai lần gộp thêm ngoài notes** để đạt mục tiêu 6/4 lần mở app (notes chỉ liệt kê đủ cho Học viên 7, Admin 5):
    `LaunchIsolationUITests` (mở app → kiểm kho, cài đặt trong thư mục tạm) vào đầu `LibraryWindowRestoreUITests`, và
    `AdminLaunchUITests` vào đầu test đề chưa lưu của `EditExamFlowUITests` (⌘Q cuối test đó vẫn là "không còn gì chưa
    lưu thì thoát ngay"). Cả hai chỉ đọc file và cây trợ năng ngay sau khi mở, không đổi trạng thái app; tham số khung xếp
    lát của Thư viện không đổi chỗ lưu kho hay cài đặt.
  - **Luồng 1 + xuất PDF:** đoạn xuất PDF bắt đầu bằng nút Kết quả của Xem lại bài (như luồng 2). Lần thi của luồng 1
    (11/12 đúng, câu 3 sai) cho mức xem lại mặc định "Câu sai và chưa làm" có câu 3, nên PDF vẫn có mục "Xem lại bài"
    (trước là lần thi 1/12 câu). `-AppleLocale en_US` và `-NSNavLastRootDirectory` đặt cho cả lần chạy: luồng 1 đạt
    nguyên vẹn với hai tham số này (mọi chữ, số và phần trăm nó kiểm theo ngôn ngữ giao diện; không mở hộp Lưu/Mở nào).
  - **Luồng 3 + đóng cửa sổ + ⌘Q khi hộp Vẫn nộp?:** Bỏ bài kết thúc lần thi nên đoạn đóng cửa sổ chạy trước, trên lần
    Luyện tập riêng (thẻ vẫn "Chưa thi lần nào"); lần Thi thứ hai mở lại Trước khi thi trong cùng app (tên thí sinh đã
    nhớ, kiểm giá trị thay vì gõ lại; `openPreExam` chọn hết ô tìm trước khi gõ mã đề). Đoạn ⌘Q chạy sau khi tiếp tục từ
    tạm dừng, với đồng hồ nhanh (trước: đồng hồ thật), nên Rà soát khoá đếm 2 câu đã làm (trước 1); ⌘Q sau khi nộp vẫn là
    bước cuối. Thời gian Thi của test này 1 → 4 phút (24 giây thật ở 10×; đoạn ⌘Q xong sau ~10 giây khi máy rảnh).
  - **Luồng 4 + PDF đề:** đoạn PDF đề chạy trên đề của luồng 4 trước bước lưu (đề chưa lưu, không lỗi, câu nhiều đáp án
    có ảnh), PDF kiểm tên đề, nội dung câu, lựa chọn SMTP/FTP, không có "Đáp án đúng"; "lưu PDF không lưu đề" kiểm bằng ⌘W
    vẫn hỏi rồi Esc = Huỷ giữ cửa sổ và thay đổi (trước: bỏ thay đổi rồi ⌘Q; bỏ thay đổi đã có ở `ImportExamUITests` và
    `EditExamFlowUITests`). PDF và file `.exam` cùng thư mục tạm `LuuDeUITest` (PDF kiểm trước khi lưu đề).
  - **Tiếng Anh:** `EnglishInterfaceUITests` dừng ở màn Làm bài sau ⌘K và menu Attempt (Approach bước 10); Rà soát, hộp
    xác nhận, Kết quả, Xem lại bài tiếng Anh: snapshot `attemptPracticeEnglish`/`resultsEnglish`/`answerReviewEnglish`,
    `LocalizationTests` (câu "N questions are unanswered. Submit anyway?"), `EnglishResultsReportTests`. Không còn UI test
    nào kiểm màn Rà soát & nộp tiếng Anh trên app thật (chỉ menu "Review & Submit"); chấp nhận theo Approach.
  - **T4:** luồng 2 trước đây mở Rà soát và đọc số câu **sau** cảnh báo 1 phút (cần ~5 giây thật), nay đọc trước rồi chờ
    cảnh báo ngay trên Rà soát (dải cảnh báo ở trên cả hai màn), sau cảnh báo chỉ còn Return → hộp hỏi → Nộp bài; thêm
    phép kiểm Kết quả "Thời gian làm, 5 phút …" (nộp trước khi hết giờ) để đồng hồ quá nhanh thành lỗi thay vì lặng lẽ
    nộp sau khi hết giờ. Đo (chế độ cô lập, lớp `ExamFlowUITests`, máy rảnh): **15×** lần đầu (chưa có phép kiểm) đạt nhưng
    nút Nộp bài bấm ở t = 36,1 s khi hết giờ dự kiến ~34,7 s; có phép kiểm thì **đỏ 3/3** ("Thời gian làm, 6 phút"); **10×**
    đạt **3/3** (test luồng 3 thi 6 phút) rồi **3/3** (thi 4 phút). Chọn 10×; `expectBanner(within:)` = mốc đồng hồ +
    10 giây (`clockSlack`), không tăng `-test-iterations`, không nới chờ. Sửa theo review độc lập #57 (S1): mở hộp "Vẫn
    nộp?" **trước** cảnh báo 1 phút (dải cảnh báo vẫn truy vấn được khi hộp đang mở), sau cảnh báo chỉ còn một cú bấm Nộp
    bài: từ lúc thấy dải tới lúc bấm ~1,0 s (t = 40,88 → 41,90; 40,70 → 41,73; 40,66 → 41,68) trong 6 s còn lại; 10× đạt
    **3/3** lần nữa. Số câu ở Rà soát so đúng giá trị (`reviewNumber`, N5) thay vì chuỗi con. `EnglishInterfaceUITests`
    thêm Rà soát & nộp tiếng Anh (⌘Return, 11 câu chưa làm, Submit, không chữ tiếng Việt; S2), vì Rà soát không có snapshot
    tiếng Anh.
  - **Số đo** (chế độ cô lập, `test-without-building`, cùng `build/DerivedData-UITest`, máy rảnh, 2026-10-18; trước =
    `f19b20f` gộp main, sau = `b1c3e99`):

    | Bản | Lần mở app (test) | Tổng giờ test | Giờ chạy target |
    | --- | --- | --- | --- |
    | Học viên trước | 10 | 335,9 s | 5 phút 51 s |
    | Học viên sau | 6 | 267,5 s | 4 phút 41 s |
    | Admin trước | 6 | 254,8 s | 4 phút 30 s |
    | Admin sau | 4 | 218,5 s | 3 phút 53 s |
    | Cộng | 16 → 10 | 590,7 → 486,0 s (−18%) | 10 phút 21 s → 8 phút 34 s |

    Từng test (s, trước → sau): luồng 2 84,7 → 53,7; luồng 3 30,4 + đóng cửa sổ 16,4 + ⌘Q 20,8 → 53,0; luồng 1 77,7 +
    xuất PDF kết quả 41,6 → 107,4; tiếng Anh 29,6 → 22,1; Thư viện xếp lát 8,3 + mở cô lập 4,3 → 9,4; cửa sổ làm bài xếp
    lát 22,0 → 21,9; luồng 4 110,5 + PDF đề 52,6 → 124,0; đề chưa lưu 19,3 + mở Admin 5,2 → 22,9; kéo thả 15,4 → 15,2;
    Import 51,8 → 56,4.

## Validation

- Focused proof: `swift test --package-path Packages/ExamFeatures` (model báo cáo, PDF đọc bằng PDFKit, bundle tiếng
  Anh, tương phản, snapshot, test `Timing`); `python3 scripts/check_localization.py`.
- Integration: `scripts/verify_local.sh --uitest` cho mọi PR chạm giao diện (luồng 1–5, xuất PDF hai bản, luồng 1 tiếng
  Anh, audit trợ năng nếu chọn); `check_boundaries.py` (SnapshotTesting chỉ ở test; PDF đề không vào bản Học viên),
  `check_bundle_boundary.sh`; `scripts/measure_large.sh` (Release) ở bước 9 và 10.
- Repository-required checks: `local/verify` xanh trên SHA cuối mỗi PR; PR rủi ro cao (3, 4, 5, và 6/7/9 nếu chạm vùng
  rủi ro cao) có review độc lập; giới hạn chặn hiệu năng (Debug) trong `swift test` là điều kiện merge, số Release chỉ
  ghi (large-exams.md phương án 3).
- Bất biến mới (thêm vào bảng của AGENTS.md ở bước 10): PDF/in không lộ đáp án khi `hideAnswers` và không đánh dấu câu đã
  sửa; catalog đủ `vi`/`en`; SnapshotTesting chỉ trong test; giới hạn chặn hiệu năng với đề chuẩn.
- **Cần người test tay** (máy không kiểm được; liệt kê trong từng PR, gom ở bước 10):
  - (bước 8a) cả hai bản, **sáng và tối ở 960×640** trên app thật: Thư viện lưới/danh sách (thanh bên: chữ và biểu tượng
    Gần đây/Lịch sử thi rõ), Trước khi thi, cửa sổ làm bài (ảnh câu hỏi: viền bo góc bao đúng ảnh, ảnh cao không còn
    khoảng trống có viền bên phải), Kết quả, Xem lại bài (biểu tượng Đúng/Sai ở danh sách câu có màu xanh/đỏ hay
    đen/trắng), soạn đề (cây đề: biểu tượng ảnh/nhiều đáp án của dòng chưa chọn thấy rõ; thanh Thêm phần / Thêm câu làm
    mờ chữ dòng phía sau; xem trước: tên phần và "Câu 1/40", nhãn "Đáp án đúng" một dòng dưới chữ lựa chọn), báo cáo
    import; Thư viện dạng danh sách: cột Trạng thái ngay sau Tên đề; **cửa sổ xếp lát trên macOS 26**: kéo cửa sổ làm bài (và Thư viện) lấp nửa/cả màn hình, thoát, mở lại; làm
    bài khi dải cảnh báo giờ đang hiện, Kết quả của lần thi cũ có file đề hỏng (lý do ở thanh nút); bản Admin: cửa sổ
    soạn đề xếp lát rồi thoát, mở lại app (khôi phục cửa sổ tài liệu); **PDF**: Xuất PDF kết quả và PDF đề có chữ
    "official"/"office"/"fluffy" (đề tiếng Anh tự soạn), mở bằng Preview: tìm "official" thấy, chép ra đúng "official"
    (không ký tự ghép), VoiceOver đọc đúng; **log UI test** `SessionWindowRestoreUITests` (`verify_local.sh --uitest`):
    dòng "Cửa sổ session: khung …, KHÔNG dùng khung xếp lát đã lưu" (trên `7836992`: khung 1180×780, đúng như mong đợi:
    `.restorationBehavior(.disabled)`); test nay đỏ nếu cửa sổ làm bài dùng khung đã lưu.
  - (bước 8b, trợ năng) cả hai bản: **VoiceOver** đi theo bảng mục tiêu của accessibility-localization.md, từng màn
    (rotor Headings thấy đề mục mới: khối điểm Kết quả, Tạm dừng, danh sách Rà soát, Thông tin đề, Import đề; hành động trợ
    năng của thẻ Thư viện VO-⌘-Space; dòng Lịch sử thi đọc "850/1000"; dòng cây đề không đọc "**"; xem trước đọc "A. …,
    Đáp án đúng"; câu đọc khi Import xong, khi kiểm đề có thêm lỗi (thêm câu mới), khi ⌘S lưu xong và khi Lưu thành…; tự
    lưu không đọc); **Increase Contrast** sáng và tối ở mọi màn (màu hệ thống tự chỉnh, màu của bảng vẫn đọc được); **Reduce
    Transparency**: thanh dưới cây đề, thanh lỗi, báo cáo import, tiêu đề phần của bảng câu hỏi, thông báo ở chân Thư viện,
    lớp phủ kéo thả thành nền đặc, chữ phía sau không còn ánh qua; dải thông báo, nhãn Đề mẫu, hàng lựa chọn đã chọn giữ
    màu; **Reduce Motion**: lưới Thư viện cuộn tới thẻ chọn bằng phím mũi tên không hiệu ứng; **dòng đang chọn có tiêu
    điểm** (danh sách câu Xem lại bài, Thư viện dạng danh sách, Lịch sử thi, cây đề sáng và tối): chữ/biểu tượng trạng thái
    trắng trên nền chọn; **⌘+ / ⌘− / ⌘0 ở 960×640** (và menu Xem › Phóng to/Thu nhỏ/Cỡ thật, tiếng Anh Zoom In/Zoom
    Out/Actual Size): làm bài, Xem lại bài, xem trước của Soạn đề ở 100/115/130/150%, không chữ nào bị cắt hay chồng, vùng
    câu hỏi cuộn được; thanh công cụ, bảng câu hỏi, cây đề giữ cỡ; mục menu tắt ở 150% (Phóng to), 100% (Thu nhỏ, Cỡ thật),
    ở Thư viện, Kết quả, soạn đề khi ẩn xem trước; mở lại app vẫn nhớ mức; ⌘= (không Shift) có phóng to không;
  - VoiceOver theo bảng mục tiêu của accessibility-localization.md, cả hai bản, cả tiếng Việt và tiếng Anh (giọng
    đọc tiếng Việt của macOS);
  - Dark Mode, Increase Contrast, Reduce Transparency, Reduce Motion trên mọi màn;
  - in ra **máy in thật** (A4 và Letter, đen trắng), "Lưu thành PDF" của hộp In, mở PDF bằng Preview: tìm chữ tiếng
    Việt, ảnh, ngắt trang, chân trang;
  - **màn hình ngoài** (khác độ phân giải/Retina, kéo cửa sổ làm bài sang, toàn màn hình), cửa sổ 960×640;
  - giao diện tiếng Anh (System Settings › Language & Region › Applications), chữ bị cắt;
  - (từ bước 4) máy ưu tiên tiếng Việt: chữ của macOS (menu chuẩn, hộp Mở/Lưu, nút mặc định) hiện tiếng Việt, chữ của
    app không đổi; Finder hiện tên kiểu tài liệu như trước;
  - đề chuẩn 2.000 câu bản Release: mở, cuộn bảng câu hỏi và Xem lại, gõ khi tìm trong cây đề, xuất PDF có Xem lại
    tất cả, bộ nhớ (Activity Monitor);
  - (sửa thoát app khi đang mở sheet, 2026-10-17) cả hai bản: **Thoát từ Dock** (chuột phải biểu tượng › Thoát) khi
    Trước khi thi đang mở: app thoát; **đăng xuất** khi Trước khi thi đang mở: app thoát, đăng xuất tiếp tục; **đăng
    xuất khi có bài chưa nộp**: hỏi "Bài chưa nộp sẽ mất. Bỏ bài?"; Tiếp tục làm → macOS báo Exam Suite huỷ đăng xuất,
    bài còn nguyên, đồng hồ vẫn chạy trong lúc hỏi; Bỏ bài → đăng xuất tiếp tục; ⌘Q khi ảnh phóng to đang mở (có bài
    chưa nộp): hỏi Bỏ bài; giữ ⌥ khi mở menu app: thấy mục ⌥⌘Q; bản Admin có đề chưa từng lưu rồi đăng xuất: hộp hỏi
    lưu của macOS, Huỷ → đăng xuất bị huỷ; khi hộp "Còn N câu chưa làm. Vẫn nộp?" đang mở: ⌘Q không làm gì, đăng xuất bị
    huỷ (mặc định của macOS, Nt0 chốt; ⌘Q đã có UI test); **Thoát từ Dock khi hộp hỏi chặn thoát đang mở** ("Vẫn
    nộp?", "Bài chưa nộp sẽ mất. Bỏ bài?", hộp xác nhận xoá của Soạn đề): không làm gì, hộp còn và trả lời được; **thoát bị huỷ khi danh sách file không thêm được đang mở**
    (Học viên: đang thi chưa nộp, mở một file `.exam` hỏng từ Finder → danh sách hiện trên Thư viện → ⌘Q → Tiếp tục
    làm): danh sách đóng, không hiện lại, Thư viện và cửa sổ làm bài dùng tiếp được, bài còn nguyên; nếu có máy macOS
    15.0–15.3: ⌘Q và Thoát từ Dock khi Trước khi thi đang mở.
  - (bước 5b, PDF/In kết quả) cả hai bản: **In…** ra máy in thật (A4 và Letter, đen trắng) và "Lưu thành PDF" của hộp
    In (tên gợi ý); **Xuất PDF…** mở bằng Preview: tìm chữ tiếng Việt, ngắt trang, chân trang; Xuất PDF đè file có sẵn
    (hộp Lưu hỏi thay); xuất vào thư mục không ghi được (hộp báo lỗi có lý do); đề chuẩn 2.000 câu "Tất cả câu": sheet
    tiến độ hiện, Huỷ không để lại file; ⌘Q và Thoát từ Dock khi sheet tiến độ đang hiện: app thoát, thư mục đích không
    còn file `.ExamSuite-….pdf.tmp`; **sheet có chớp không**: bấm Return trên hộp chọn (hộp chọn trượt ra, hộp Lưu vào)
    và bấm Huỷ (hộp chọn trượt ra nguyên nội dung, không đổi sang tiến độ hay trống), xuất nhanh không thấy sheet tiến
    độ; bấm ảnh câu hỏi trong Xem lại bài ngay sau khi bấm Xuất: không mở ảnh phóng to; **VoiceOver** trên nút Xuất PDF…/In…, hộp chọn (lựa chọn, lý do khi tắt), sheet tiến độ (chữ, Huỷ),
    câu đọc "Đã xuất PDF" và hộp báo lỗi; máy ưu tiên tiếng Việt: hộp Lưu, hộp In của macOS theo ngôn ngữ app.
  - (bước 7a, định dạng theo ngôn ngữ giao diện) cả hai bản: **giao diện tiếng Anh + Region Việt Nam** (System
    Settings › General › Language & Region › Applications đặt Exam Suite là English, Region Vietnam) và **giao diện tiếng
    Việt + Region Mỹ** (Region United States): Thư viện (thẻ "Lần gần nhất", Thông tin đề: Ngày thêm, dung lượng), Lịch
    sử thi (ngày giờ, %), Trước khi thi ("/ N", ô số câu, ô thời gian: gõ số rồi rời ô), cửa sổ làm bài (Câu N/M, Đã làm,
    bảng câu hỏi), Rà soát, Kết quả (Nộp lúc, Số câu đúng, %), Xem lại, PDF kết quả và PDF đề (Preview), cửa sổ soạn đề
    (ngưỡng đậu, thời gian Thi, cây đề): số, phần trăm, ngày giờ theo **ngôn ngữ giao diện** (tiếng Việt "1.234",
    "14:05 15/10/2026"; tiếng Anh "1,234", "10/15/2026, 2:05 PM"), không theo Region; đề lớn (đề chuẩn 2.000 câu) để
    thấy ngăn nghìn; cài 24 giờ ở Region trong khi giao diện tiếng Anh: giờ vẫn AM/PM (đúng quyết định). **Tới bước 7c**
    (catalog chưa có `en`): giao diện tiếng Anh vẫn hiện chữ **và** số/ngày dạng tiếng Việt ("Câu 1.234/2.000", "14:05
    15/10/2026"), không lẫn dạng tiếng Anh; dạng tiếng Anh chỉ kiểm được sau 7c. Region có lịch Phật hay lịch Nhật: năm
    vẫn là năm Gregorian.
  - (bước 7b, thông báo lỗi theo mã) cả hai bản, giao diện tiếng Việt: chữ của các thông báo lỗi **không đổi** so với
    trước: thêm file hỏng (không phải zip), file có trường lạ, file cần app mới hơn, file trong Thùng rác vào Thư viện
    (dòng lý do của danh sách "Không thêm được", thẻ đề, Thông tin đề, câu VoiceOver của thẻ); bản Học viên mở Trước khi
    thi của đề vừa thành có lỗi (lý do ở sheet và dải thông báo); Kết quả của lần thi cũ có file đề hỏng (lý do không xem
    lại được); bản Admin: thanh lỗi soạn đề (mọi loại lỗi, kể cả id trùng sửa tay trong exam.json), ảnh quá lớn/sai loại,
    mở file `.exam` hỏng từ Finder (hộp báo của macOS), Import đề… file `.txt` không UTF-8, `.docx` hỏng, `.vce` hỏng
    (hộp báo) và báo cáo import (lý do, cột vị trí); Thử đề này với file bị bản Học viên từ chối; khoá kho thư viện
    (dải "Dữ liệu thư viện có sự cố"). Số từ 1.000 trở lên trong các câu đó có ngăn nghìn. **Mở lại app** khi Thư viện có
    file hỏng/có lỗi: thẻ hiện "Đang kiểm tra" rất ngắn rồi đúng lý do (file có vấn đề được đọc lại một lần).
  - (bước 7c, bản tiếng Anh) cả hai bản, **giao diện tiếng Anh** (System Settings › General › Language & Region ›
    Applications: Exam Suite và Exam Suite Admin là English) ở cửa sổ 960×640: mọi màn (Thư viện lưới/danh sách, Thông
    tin đề, Lịch sử thi, Trước khi thi, làm bài, Rà soát & nộp, hộp xác nhận, Kết quả, Xem lại bài, soạn đề, thanh lỗi,
    Import đề… và báo cáo, hộp chọn Xuất PDF/In, sheet tiến độ, hộp báo lỗi): **chữ bị cắt** hay xuống dòng xấu, chữ
    tiếng Việt còn sót (trừ nội dung đề, đề mẫu); **menu** (Attempt, Exam, File: Export as PDF…/Print…, Import Exam…,
    New Exam, Open for Editing…, Help: Restore Sample Exams), Hoàn tác/Làm lại có tên bước tiếng Anh ("Undo Add Section");
    **PDF** kết quả và PDF đề (nhãn, chân trang "Page N of M", tên file gợi ý "(with answers)"/"(questions only)"; tìm chữ có
    "ffi" như "official" trong Preview); **VoiceOver** tiếng Anh theo bảng mục tiêu; Finder hiện tên kiểu tài liệu "Exam
    Suite Exam" (giao diện tiếng Việt: "Đề Exam Suite"); bản Admin: Đề mới ra "New Exam"/"Section 1", Thêm phần "Section
    2", Import đề… file không có phần ra "General Section"; đổi ngôn ngữ rồi mở lại đề: tên đã ghi không đổi. **Duyệt
    bảng thuật ngữ đề xuất** (accessibility-localization.md), nhất là menu "Attempt".
  - (bước 6, PDF/In đề, bản Admin) cửa sổ soạn đề: **Tệp › Xuất PDF…** và **In…** ⌘P (cửa sổ làm bài và Thư viện vẫn
    đúng như trước: ⌘P ở Kết quả là In kết quả, ở Thư viện thì tắt); hai kiểu, mở bằng Preview: tìm chữ tiếng Việt, ảnh,
    ngắt trang, đề mục phần không đứng một mình cuối trang, chân trang; **In…** ra máy in thật (A4 và Letter, đen trắng)
    và "Lưu thành PDF" (tên gợi ý "<tên đề> (đề)"/"(có đáp án)"); đề chưa lưu và đề còn lỗi (dòng "Đề còn N lỗi"); đề
    `hideAnswers` chọn Có đáp án (dòng nhắc); đề chuẩn 2.000 câu: sheet tiến độ, Huỷ không để lại file, ⌘Q và Thoát từ Dock
    khi sheet tiến độ đang hiện; ⌘P khi ảnh phóng to của xem trước hoặc hộp chọn ảnh đang mở: không làm gì; bấm ảnh xem
    trước ngay sau Return (không mở ảnh phóng to); **VoiceOver** trên hộp chọn (Kiểu, dòng lỗi, dòng nhắc), sheet tiến độ,
    câu "Đã xuất PDF".

## Result

Đóng 2026-10-18 (giai đoạn 5 không có cổng; G3 ở giai đoạn 6). Cả hai bản app xuất PDF và in kết quả (kèm phần xem lại,
đúng quy tắc `hideAnswers` và câu đã sửa), bản Admin xuất PDF và in đề; giao diện tiếng Việt và tiếng Anh qua String
Catalog, số/ngày theo ngôn ngữ giao diện, lỗi lõi dịch theo mã; VoiceOver theo bảng mục tiêu, kiểm trợ năng tự động trong
UI test, tương phản đạt ở sáng/tối, Reduce Transparency, cỡ chữ nội dung; bố cục giữ ở 960×640 (snapshot sáng/tối) và
khi cửa sổ xếp lát; đề chuẩn 2.000 câu có ảnh đạt mọi ngân sách Release.

- **Merge vào `main`:** #36 (kế hoạch), #40 (spike), #39 (đo đề lớn), #41 (snapshot), #44 (String Catalog), #43 (lõi PDF),
  #45 (thoát app khi có sheet), #46 (PDF/In kết quả), #48 (Thư viện trống khi xếp lát), #49 (PDF/In đề), #50–#52 (định
  dạng theo ngôn ngữ, lỗi theo mã, tiếng Anh), #53–#54 (bố cục, trợ năng), #55 (tối ưu đề lớn, UI test theo file
  đổi); #56 (tài liệu của Nt0: kế hoạch Android, finding UI test). **Chờ merge:** PR bước 10 (#57). PR rủi ro cao đều có
  review độc lập bằng phiên agent mới (#57: approve kèm sửa, đã sửa S1–S3, N1–N5).
- **Bất biến mới** (Validation): đã có trong bảng "Bất biến đã mã hoá" của AGENTS.md (PDF không lộ đáp án và không đánh
  dấu câu đã sửa; catalog đủ `vi`/`en` và `--require-en`; SnapshotTesting chỉ trong test; giới hạn chặn hiệu năng với
  đề chuẩn; kiểm trợ năng tự động; sheet không chặn thoát; định dạng theo ngôn ngữ giao diện).
- **Số đo cuối** (`measure_large.sh`, Release, `b1c3e99`): mọi mục đạt ngân sách; đáng chú ý nộp bài ~83 ms main actor
  (ngân sách chặn 100 ms, Nt0 chốt chỉ theo dõi), PDF kết quả "Xem lại tất cả" 1.168 trang 12,5 s, PDF đề có đáp án
  11,1 s, lần gõ đầu vào ô tìm Soạn đề 0,22 ms.
- **UI test** (bước 10): Học viên 6, Admin 4 lần mở app (trước 10 và 6), đồng hồ nhanh 10×; mọi lớp đạt ở chế độ cô lập
  (Decisions 2026-10-18 bước 10).
- **Bằng chứng cổng (chờ):** người điều phối chạy `scripts/verify_local.sh --clean --uitest` một lần trên SHA cuối của PR
  bước 10 sau review độc lập; ghi SHA và mô tả status vào PR và Progress của plan giai đoạn 6.

**Cài hai app cho Nt0** (người điều phối làm sau khi PR bước 10 (#57) merge; agent không cài):

1. `git switch main && git pull`; tree sạch; `scripts/verify_local.sh --clean --uitest` xanh trên đúng SHA `main` đó (nếu
   SHA khác SHA đã chạy cổng).
2. Build Release ký ad-hoc (`project.yml`: `CODE_SIGN_IDENTITY "-"`) vào thư mục riêng: `xcodegen generate`, rồi với
   từng scheme `ExamSuite`, `ExamSuiteAdmin`: `xcodebuild -project ExamSuite.xcodeproj -scheme <scheme> -configuration
   Release -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData-Install build`.
3. Kiểm trên đúng hai app đó (`build/DerivedData-Install/Build/Products/Release/Exam Suite.app`, `Exam Suite Admin.app`):
   `codesign --verify --deep --strict`, `scripts/check_release_strings.sh build/DerivedData-Install/Build/Products/Release
   build/DerivedData/Build/Products/Debug`, `scripts/check_bundle_boundary.sh build/DerivedData-Install/Build/Products/Release`.
4. Nhờ Nt0 thoát cả hai app; sao lưu bản đang cài: `ditto "/Applications/Exam Suite.app"
   ~/ExamSuite-backup/<ngày>-truoc-cai-<sha>/"Exam Suite.app"` (và bản Admin).
5. Cài: `ditto` hai app vào `/Applications` (thay bản cũ). Không mở app, không đụng `~/Library/Application Support/<bundle ID>`
   hay `defaults`: kho và cài đặt của Nt0 giữ nguyên.
6. Ghi SHA cài, ngày, chỗ sao lưu vào Progress của plan giai đoạn 6; xoá `build/DerivedData-Install`.

**Test tay còn lại cho Nt0** (máy không kiểm được; chi tiết từng bước ở Validation, mục Cần người test tay; gom vào
checklist G3 của giai đoạn 6), cả hai bản, trên bản cài:

- **VoiceOver** theo bảng mục tiêu của accessibility-localization.md, tiếng Việt và tiếng Anh (rotor Headings, hành động
  của thẻ Thư viện, câu đọc của Kết quả/Lịch sử thi/cây đề/xem trước, câu đọc khi Import xong, lưu xong, Đã xuất PDF).
- **Dark Mode** sáng và tối ở mọi màn, 960×640 (cả màn hình ngoài).
- **Increase Contrast** sáng và tối; **Reduce Transparency** (thanh dưới cây đề, thanh lỗi, báo cáo import, tiêu đề phần,
  thông báo chân Thư viện, lớp phủ kéo thả thành nền đặc); Reduce Motion.
- **⌘+ / ⌘= / ⌘0** (và ⌘−, menu Xem) ở làm bài, Xem lại bài, xem trước Soạn đề 100–150%: không chữ bị cắt/chồng,
  mục menu tắt đúng chỗ, mở lại app nhớ mức; ⌘= không Shift có phóng to.
- **In thật** ra máy in A4 và Letter (đen trắng), "Lưu thành PDF" của hộp In (tên gợi ý), PDF kết quả và PDF đề.
- **Tìm trong Preview**: chữ tiếng Việt, "official"/"office"/"fluffy" (không ký tự ghép), ngắt trang, chân trang, ảnh.
- **Cửa sổ xếp lát** trên macOS 26: Thư viện, cửa sổ làm bài, cửa sổ soạn đề lấp nửa/cả màn hình, thoát, mở lại.
- **Autosave**: bản Admin sửa đề đã có file rồi ⌘W (tự lưu, không hỏi), đề chưa lưu ⌘W hỏi; Versions (Duyệt mọi phiên
  bản); `verify_local.sh --uitest` kiểm `~/Library/Autosave Information/` khi trình chạy có Full Disk Access.
- **Khôi phục sau crash**: buộc thoát bản Admin khi đang sửa đề (đề đã có file và đề chưa lưu), mở lại: macOS khôi phục
  cửa sổ và thay đổi.
- **Mở từ Finder**: `.exam` mở bằng bản đúng vai (Học viên Viewer, Admin Editor) trên máy có cả hai bản; file hỏng, file
  cần app mới hơn; tên kiểu tài liệu "Đề Exam Suite"/"Exam Suite Exam" theo ngôn ngữ.
- **Đề chuẩn 2.000 câu** (bản Release, `python3 scripts/gen_large_exam.py --out dist/`): mở, cuộn bảng câu hỏi và Xem lại,
  gõ khi tìm trong cây đề, xuất PDF có "Xem lại tất cả" (sheet tiến độ, Huỷ không để lại file), in, bộ nhớ (Activity
  Monitor).
- Thoát từ Dock, đăng xuất khi có sheet/hộp hỏi; giao diện tiếng Anh + Region Việt Nam và tiếng Việt + Region Mỹ (số,
  ngày giờ theo ngôn ngữ giao diện).

**Chuyển sang giai đoạn 6:** DMG, ký, hướng dẫn cài, lần CI duy nhất, sửa lỗi beta, cổng G3 (gồm cổng G2 còn hoãn và test
tay ở trên); trình chạy test cần Automation Mode (macOS có thể hỏi xác thực).
