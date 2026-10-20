# Execution Plan: Giai đoạn 4 · Soạn đề và import

Date: 2026-10-16

## Status

Completed, tạm đóng 2026-10-17 (Nt0 quyết): code giai đoạn 4 đã merge và cài lên máy; **cổng G2 và test tay chưa
chạy**, Nt0 test trên bản cài `611475a`. Xem Result.

## Outcome

Bản Admin soạn đề hoàn chỉnh: Đề mới, sửa đề trong cửa sổ ba cột (cây đề, trình soạn, xem trước), ảnh, kiểm lỗi
không chặn lưu, hoàn tác/làm lại, lưu/tự lưu/khôi phục của macOS, Thử đề này; **import đề từ `.txt`, `.docx`** (và
`.vce` nếu ADR 0009 được duyệt và spike khả thi). Cuối giai đoạn: cổng **G2** (hoãn từ giai đoạn 3) — nhóm dùng thử
soạn/import đề thật rồi làm trọn bài, không gặp lỗi chặn.

## Context

- Thẩm quyền sản phẩm: [authoring.md](../../product/authoring.md), [import.md](../../product/import.md) (viết cho giai
  đoạn này), exam-format.md (ràng buộc, đọc dễ, không chặn lưu), exam-taking.md (Thử đề này dẫn vào Trước khi thi),
  library.md (phương án 7, 11: mở để sửa, khởi động bằng file).
- ADR 0003 (bản Học viên không chứa code soạn đề/import), 0006 (không thêm thư viện), 0008 (lõi Foundation-only),
  **0009 (đọc `.vce`, Accepted 2026-10-16)**.
- Có sẵn: `ExamDocument` (FileDocument chỉ xem, `DocumentGroup(viewing:)`), `ExamValidator`, `ExamPackageReader/Writer`
  (đọc dễ/nghiêm, SHA-256 tên ảnh), `QuestionFingerprint` (băm theo đường dẫn ảnh: không đổi tên ảnh cũ),
  SessionFeature (Trước khi thi, cửa sổ làm bài: dùng lại cho Thử đề và có thể cho xem trước).
- Việc chuyển từ giai đoạn 3: cổng G2; chế độ cô lập cho UI test chưa nối AdminShell; UI test bấm chuột ở bước cần
  Điều hướng bàn phím (exam-taking.md phương án 19).
- Quy trình: docs/process/review-and-merge.md (`local/verify`, UI test bắt buộc ở PR chạm giao diện, không kích hoạt
  Actions). File mẫu thật ở `docs/archive/` không vào git.

## Scope

In scope: module chỉnh sửa đề (không giao diện), module import txt/docx (không giao diện), spike + bộ đọc `.vce` (có
điều kiện), giao diện soạn đề + import trong `AuthoringFeature`, nối AdminShell (thay `DocumentGroup(viewing:)`, Đề mới,
Import đề…, Thử đề này), ranh giới bản Học viên cho các module mới, XCUITest bản Admin (luồng 4, 5) với chế độ cô lập,
cổng G2.

Out of scope: xuất PDF/In đề (giai đoạn 5), String Catalog (giai đoạn 5), loại câu mới (v2), import định dạng khác
ngoài ba định dạng trên.

## Approach

Mỗi bước một PR trên nhánh `feature/g4-<bước>`. Bước 1, 2, 3 chạy song song; bước 4 dựng trên 1 và 2; bước 5 trên 4;
bước 6 sau spike.

1. **`AuthoringData`** (target mới trong `Packages/ExamFeatures`, không SwiftUI/AppKit, chỉ bản Admin link; rủi ro cao):
   thao tác thuần trên `Exam` + media: thêm/sửa/xoá/nhân bản/chuyển/sắp xếp phần, câu, lựa chọn (chữ cái theo vị trí,
   đáp án đúng đi theo nội dung), đổi loại câu, thêm/thay/xoá ảnh (SHA-256, không đổi tên ảnh cũ, bỏ ảnh không dùng khi
   lưu), mỗi thao tác trả thao tác ngược để `UndoManager` dùng; ánh xạ `ValidationIssue` → vị trí trên cây; đề mới mặc
   định. Cập nhật `check_boundaries.py` (bản Học viên không phụ thuộc `AuthoringData`, `ExamImport`) và kiểm bundle.
   Test `AuthoringDataTests` (ghi bằng `ExamPackageWriter` rồi đọc lại ra đúng, kể cả ảnh).
2. **`ExamImport`** (target mới, không giao diện, chỉ bản Admin; rủi ro cao vì tạo đề): bộ chuyển đổi txt và docx theo
   import.md, trả `Exam` + media + báo cáo (bỏ/cảnh báo kèm vị trí) + giá trị gợi ý (tiêu đề, mã, ngưỡng, thời gian).
   Test trên file **tự soạn** cho từng quy tắc; thử tại máy với file thật trong `docs/archive/` (không commit), ghi số
   câu/bỏ/cảnh báo vào PR.
3. **Spike `.vce`** (ADR 0009 đã duyệt; REA chỉ khi cần, hỏi Nt0 trước khi cài): xác định cấu trúc và cách đọc trên mẫu VCE 1 (file thật tại máy), có giới
   hạn thời gian; kết quả (khả thi hay không, vì sao) ghi vào Decisions; không chép code của công cụ khác. Không khả
   thi thì dừng, báo Nt0, cập nhật ADR 0009.
4. **Giao diện soạn đề + import** (`AuthoringFeature`, AdminShell; rủi ro cao: lưu file soạn đề, ranh giới):
   `ReferenceFileDocument`, cửa sổ ba cột, trình soạn đề/phần/câu/lựa chọn, ảnh, xem trước, thanh lỗi bấm để nhảy, hoàn
   tác, Thử đề này (lưu → đọc nghiêm → thêm vào Thư viện → Trước khi thi), Đề mới, Import đề… (hộp xác nhận, báo cáo),
   phím tắt theo authoring.md. Có thể tách 4a (cửa sổ + soạn) và 4b (import, Thử đề) nếu PR quá lớn.
5. **XCUITest bản Admin** (rủi ro cao): nối chế độ cô lập vào AdminShell (bundle ID `.admin.uitest`), target UI test cho
   bản Admin: luồng 4 (đề mới → thuộc tính → phần → câu nhiều đáp án có ảnh → lỗi thiếu đáp án → sửa → xem trước → lưu →
   Thử đề), luồng 5 (mở đề → kéo thả sắp xếp → hoàn tác → đóng khi chưa lưu → Huỷ), import file tự soạn. Khôi phục sau
   crash: test tay. `verify_local.sh --uitest` chạy cả hai target, so kho/defaults thật của cả hai bản.
6. **Bộ đọc `.vce`** (nếu spike khả thi; rủi ro cao): trong `ExamImport`, cùng báo cáo và luồng như docx.
7. **Người điều phối**: tài liệu (AGENTS.md bản đồ code, bất biến mới, CHANGELOG), `verify_local.sh --clean --uitest`,
   cài hai app, **cổng G2** theo checklist (gồm soạn đề và import), đóng plan.

## Risks And Recovery

- Lưu hỏng file đề của admin: ghi bằng `ExamPackageWriter` (ghi tạm rồi thay của macOS), test ghi–đọc lại; Versions của
  macOS giữ bản cũ.
- Đổi chữ cái lựa chọn làm sai đáp án đúng: thao tác trong `AuthoringData` có test cho mọi trường hợp sắp xếp/xoá.
- Đổi tên ảnh cũ làm mọi lần thi báo "đã sửa": cấm trong `AuthoringData`, có test.
- Kiểm lỗi chậm với đề 2.000 câu: chạy nền, gộp thay đổi; đo ở bước 4.
- Bộ chuyển đổi đoán sai cấu trúc file thật: báo cáo import chi tiết, đề mở chưa lưu để admin sửa; thử trên file thật.
- `.vce`: rủi ro pháp lý/kỹ thuật theo ADR 0009; spike có điểm dừng.
- Lọt code soạn đề/import vào bản Học viên: `check_boundaries.py` + `check_bundle_boundary.sh` cho cả module mới.
- Recovery: mọi thứ trong git; không đổi schema đề hay kho thư viện.

## Progress

- [x] 0 Tài liệu sản phẩm authoring.md, import.md, ADR 0009, plan (PR #29)
- [x] 1 AuthoringData (PR #31, nhánh `feature/g4-authoring-data`):
  `ExamDraft` + `ExamEdit` (thay đổi ngược), ảnh, `IssueTarget`/`IssueIndex`; `check_boundaries.py` (AuthoringData,
  ExamImport; tự kiểm đối chứng âm), `check_bundle_boundary.sh`; 43 test `AuthoringDataTests`
- [x] 2 ExamImport (txt, docx): target `ExamImport` (không giao diện), `ExamImportTests` trên file tự soạn, sửa
      mojibake (import.md phương án 10, PR #30); thử file thật tại máy: txt 1.019 câu, 0 bỏ; docx 40 câu, 0 bỏ
      (PR #32)
- [x] 3 Spike `.vce` (PR #30): khả thi với biến thể của file mẫu; mô tả định dạng ở
  [docs/notes/vce-format.md](../../notes/vce-format.md)
- [x] 4 Giao diện soạn đề + import, nối AdminShell
  - [x] 4a (PR #34 "G4.4a Cửa sổ soạn đề", nhánh `feature/g4-soan-de-ui`, dựng trên #33 (5a) và #32): `ExamAuthoringDocument` (`ReferenceFileDocument`, đọc dễ, ghi
        `ExamPackageWriter`, thay `ExamDocument`/`DocumentGroup(viewing:)`), `AuthoringEditor` (mọi thay đổi qua
        `ExamDraft`, Hoàn tác qua `UndoManager` của cửa sổ, gộp gõ chữ theo trường, đóng đoạn gõ trước thao tác cấu
        trúc/đổi dòng/lưu), cửa sổ ba cột (cây đề tìm/kéo thả/menu chuột phải, trình soạn đề/phần/câu/lựa chọn, ảnh,
        xem trước `.inspector` dùng `QuestionPreview` của SessionFeature, thanh lỗi), lệnh menu Đề/⌃⌘I/⌘F, Đề mới
        (⌘N, nút trên Thư viện); 44 test `AuthoringFeatureTests` (gồm 7 test cho review độc lập). Đề 2.000 câu
        (Debug): kiểm đề nền ~15 ms, mỗi lần gõ trên main actor ~0,01 ms, dựng lại cây đề ~27 ms; đang tìm: lần đầu
        ~28 ms, đổi chữ tìm ~1 ms, gõ vào câu kèm lọc lại cây ~1,3 ms
  - [x] 4b (PR #35 "G4.4b Import đề… và Thử đề này", nhánh `feature/g4-import-ui`, dựng trên #34): `ImportFlowModel` (đọc nền có tiến độ và Huỷ, `.txt`/`.docx`/`.vce`, lỗi →
        hộp thông báo không mở cửa sổ), `ImportConfirmForm` (điền sẵn, kiểm giá trị theo exam-format.md), cửa sổ
        Import đề (`ImportExamWindow`), document chưa lưu kèm báo cáo import (`ImportReportState`, bảng ẩn/hiện, bấm
        dòng nhảy tới câu); `TryExamCoordinator` (lưu → đọc nghiêm → thêm vào Thư viện như Thêm đề
        (`LibraryModel.addExamFile`; Dùng file mới thì mở tiếp) → Trước khi thi), ⌘R và nút trên thanh công cụ; AdminShell nối `AuthoringHooks`;
        51 test mới trong `AuthoringFeatureTests` (`ImportFlowTests`, `TryExamTests`, `DocumentSaverTests`), 1 trong
        `LibraryModelTests`
- [x] 5 XCUITest bản Admin, chế độ cô lập cho AdminShell
  - [x] 5a (PR #33, nhánh `feature/g4-uitest-admin`, dựng trên #32): AdminShell dùng `AppLaunchStorage` như StudentShell (kho, đề mẫu, cài đặt trong thư mục tạm; dừng
        dưới bundle ID thật hoặc khi bản `.uitest` thiếu tham số); bundle ID Admin (bundle ID cũ, nay `vn.io.nt0.examsuite.admin`) +
        `EXAMSUITE_BUNDLE_ID_SUFFIX` (UI test: bundle ID Admin thêm đuôi `.uitest`); target `ExamSuiteAdminUITests`
        (`Apps/AdminUITests`, 1 test mở app cô lập → Thư viện → ⌘Q), code chung ở `Apps/UITestSupport`;
        `verify_local.sh --uitest` chạy Học viên rồi Admin, so kho/defaults/đề gần đây thật của cả hai bản;
        `AppLaunchStorageTests` thêm phần Admin và kiểm bundle ID trong project.yml. UI test xanh (Admin 1/1).
  - [x] 5b (PR #42, nhánh `feature/g4-uitest-flows`, dựng trên #35): 4 test mới trong `ExamSuiteAdminUITests`: `NewExamFlowUITests` (luồng
        4: ⌘N → thuộc tính → Thêm phần → ⌥⌘N câu nhiều đáp án có ảnh → thanh lỗi "chưa có đáp án đúng" → đánh dấu A, C →
        xoá phần rỗng → xem trước, ⌃⌘I, Thi/Luyện tập → ⌘S vào thư mục tạm → ⌘R Trước khi thi → ⌘Q),
        `EditExamFlowUITests` (luồng 5, hành vi mặc định của macOS: ⌘E đề mẫu → kéo thả câu → ⌘Z → ⇧⌘Z → ⌘W đóng không
        hỏi, file trên đĩa đổi, mở lại thấy thứ tự mới; Đề mới có sửa → ⌘W hỏi → Esc giữ cửa sổ → bỏ),
        `ImportExamUITests` (`Fixtures/nhap-thu.txt` → hộp xác nhận điền sẵn/bắt buộc → báo cáo, ẩn/hiện, bấm dòng câu 2
        → ⌘W hỏi lưu → bỏ → ⌘Q); `AdminFlow` (bước chung, dọn dẹp thoát app bỏ thay đổi trước khi buộc dừng); tham số
        Debug `-ExamSuiteUITestChosenFile` (Decisions) + 4 test `AppLaunchStorageTests`; `UITestFixtureTests` giữ file
        import đúng; `verify_local.sh --uitest` so `~/Library/Autosave Information/`. UI test xanh trên 6737abc (Học viên 5,
        Admin 5) sau khi sửa ba lỗi app UI test tìm ra (crash Import, cột bị cắt, danh sách đáy cột giữa phủ trình soạn) và
        lỗi ⌘Q treo khi có sheet (thay hẳn ở #45). `.vce` dựng lúc chạy test: chưa làm (tuỳ chọn).
- [x] 6 Bộ đọc `.vce` (PR #38, nhánh `feature/g4-vce` dựng trên #32): `VceImporter` (magic, kích thước, CRC-32, đọc tuần tự có kiểm biên), `RVFReader`, ánh xạ như
      docx; `VceImportTests` trên file tự dựng (`VceTestWriter`), cắt cụt mọi vị trí, đột biến ngẫu nhiên; thử file
      thật tại máy: mẫu VCE 1 40 câu, 0 bỏ (đáp án 40/40 khớp docx), mẫu VCE 2 và 3 600 và 419 câu, 0 bỏ. Giao diện (#35)
      đã bỏ chặn `.vce` (merge #38 vào #35)
- [x] 7 Tài liệu (PR "G4.7 Đóng giai đoạn 4": plan, CHANGELOG, checklist G2 bổ sung), `verify_local.sh --clean --uitest`
      xanh trên `611475a`, cài Release hai app vào /Applications. **Cổng G2 chưa chạy** (Nt0 dùng thử trên bản cài)

## Decisions

- 2026-10-16: Nt0 chốt: import trước mắt `.txt`, `.docx`, `.vce` (đọc trực tiếp, theo ADR 0009); kết quả import mở
  cửa sổ soạn đề chưa lưu; ngưỡng đậu/thời gian hỏi khi import; `id` ngẫu nhiên mỗi lần; Thử đề này lưu rồi thử, có
  lịch sử; file mẫu thật trong `docs/archive/` không vào git.
- 2026-10-16: Tách `AuthoringData` và `ExamImport` (không giao diện, có test) khỏi `AuthoringFeature` (SwiftUI), như
  LibraryData/SessionFeature; đặt trong `ExamFeatures` (chỉ bản Admin link), không trong ExamKit, để code soạn đề và
  import không vào binary bản Học viên (ADR 0003).
- 2026-10-16: Nt0 duyệt ADR 0009 (đề xuất dùng REA để dịch ngược nếu cần) và các phương án authoring.md 2–6,
  import.md 6–9.
- 2026-10-16 (bước 1, chi tiết cài đặt, không phải chính sách sản phẩm mới): thay đổi nguyên thuỷ `ExamEdit` địa chỉ
  theo chỉ số (rõ ràng cả với đề đọc dễ có id trùng); thao tác tiện dụng nhận id (lần xuất hiện đầu) hoặc vị trí
  (`QuestionPath`, chỉ số phần), và cây đề/thanh lỗi định danh dòng theo vị trí (`TreeRow`), có `assignNewID` để sửa
  id trùng (sau review độc lập PR #31); sửa trong một câu là `replaceQuestion` (thay đổi ngược là bản chụp câu); thao
  tác không đổi gì trả `.none`. Trần tổng dung lượng khi thêm ảnh tính cả `exam.json` như bộ đọc. Nhiều → Một đáp án giữ đáp án đúng đầu tiên **theo thứ tự lựa
  chọn**. Thao tác trên lựa chọn bỏ mã đáp án không trỏ tới lựa chọn nào (đề đọc dễ). Ảnh trùng byte với ảnh đã có
  (kể cả tên không theo 16 hex) dùng lại đường dẫn cũ; ảnh làm gói vượt giới hạn đọc (`ExamPackageLimits`: mỗi ảnh,
  tổng, số entry) bị từ chối. Ô mã đề/hướng dẫn/giải thích để trống thì bỏ trường (không ghi chuỗi rỗng). Nhân bản
  đặt câu ngay sau câu gốc. Câu mới mặc định (`AuthoringDefaults.blankQuestion`): một đáp án, hai lựa chọn trống, chưa
  có đáp án (bước 4a đổi thành bốn, authoring.md phương án 7); tên phần mới gợi ý "Phần N" (phương án 10).
- 2026-10-16: Spike `.vce` (bước 3): **khả thi** bằng code viết mới, không cần dịch ngược phần mềm hay REA. Nội dung
  chỉ bị che đơn giản (không khoá bí mật, không nén), văn bản dạng RVF (TRichView, đặc tả công
  khai); đối chiếu docx khớp 40/40 câu, 160/160 lựa chọn, 40/40 đáp án. Chưa kiểm: ảnh, nhiều đáp án, loại câu
  khác, phiên bản `.vce` khác (docs/notes/vce-format.md). Bước 6 làm tiếp; cần Nt0 chốt cách xử lý mojibake.
- 2026-10-16: Nt0 chốt sau spike: lỗi mã hoá trong file gốc (mojibake) **tự sửa và ghi cảnh báo**, áp dụng cả
  txt/docx/vce (import.md phương án 10); Nt0 **gửi thêm file `.vce` mẫu** có ảnh và câu nhiều đáp án (không vào git)
  để bước 6 kiểm trên file thật (phương án 11).
- 2026-10-16 (bước 2): Nt0 chốt các điểm mở của PR #32, ghi vào import.md phương án 12–15: khối câu không có `A.` →
  lựa chọn bắt đầu từ nhãn đầu tiên, đánh lại theo vị trí, đáp án đổi theo, cảnh báo; `Passing Score` N > 100 → N/10
  làm tròn gần nhất (nửa lên); ảnh dùng được kế tiếp sau ảnh `emf`; đoạn nối lựa chọn docx ghép bằng xuống dòng;
  `Explanation` đứng riêng mở giải thích; văn bản lạc bị bỏ kèm cảnh báo; không có câu → lỗi; `Exam X` chỉ ngoài đề bài;
  thoát Markdown chỉ khi cần; đánh số khác `bullet` → `1. `, không đọc `pStyle`. ADR 0006 sửa: ZIPFoundation được dùng
  trong `ExamFile` và `ExamImport` (check_boundaries.py chặn chỗ khác). Kết quả import không chứa `Exam` với
  ngưỡng/thời gian giả: `ImportResult.makePackage(ImportConfirmation)` dựng đề sau hộp xác nhận.
- 2026-10-16 (bước 2, review độc lập PR #32 phát hiện 2): Nt0 thu hẹp quy tắc mojibake (import.md phương án 10): chỉ
  tự sửa dãy `â€…`/`â‚…` (3 ký tự, byte thứ hai 0x80–0x82) ra ký tự U+2000–U+20CF; dãy nghi lỗi khác chỉ cảnh báo
  (`mojibakeSuspected`), không đổi chữ, vì chữ hoa tiếng Việt sát `”`, `®`, NBSP bị sửa nhầm. Khi merge #30, giữ câu
  chữ đã thu hẹp của nhánh này.
- 2026-10-16 (bước 2, re-review PR #32): Nt0 chốt dãy mojibake "chắc chắn" giải ra ký tự định dạng/phân cách vô hình
  (U+200B–U+200F, U+2028–U+202E, U+2060–U+206F) **không** tự sửa, chỉ cảnh báo `mojibakeSuspected` (import.md phương án
  10); dấu nháy, gạch, `…`, `€`, `₫` vẫn tự sửa.
- 2026-10-16 (bước 5a, chi tiết cài đặt): bundle ID UI test của bản Admin là bundle ID Admin thêm đuôi `.uitest`
  (bundle ID thật + đuôi chung `.uitest`, đúng `.admin.uitest` của Approach), thư mục kho trong thư mục tạm vẫn theo
  bundle ID thật (`Application Support/<bundle ID Admin>/`) như bản Học viên. `verify_local.sh --uitest` chạy
  cả hai target kể cả khi target đầu thất bại (để so kho thật sau mọi lần lái app), mỗi target một DerivedData
  (`build/DerivedData-UITest`, `build/DerivedData-UITest-Admin`); so thêm file đề mở gần đây (sfl) của bản thật vì
  bản Admin dùng `NSDocumentController`; mô tả status cắt ở 140 ký tự (giới hạn GitHub). Mọi scene của bản Admin (Thư
  viện, làm bài, `DocumentGroup`) gắn `.defaultAppStorage(delegate.storage.defaults)`; scene mới cũng phải gắn (bước 4
  khi thay `DocumentGroup` giữ dòng này).
- 2026-10-16 (bước 5a, review độc lập #33, APPROVE kèm góp ý 1–7, đã sửa): `verify_local.sh --uitest` coi target 0
  test đạt hoặc có test `skipped` là thất bại; bắt crash thật bằng tên file báo cáo `Exam Suite*` mới trong
  `~/Library/Logs/DiagnosticReports/` (giữ "Lost connection"/"is not running" trong lỗi hạ tầng); so cả cây
  `Application Support/<bundle ID>/`; bản `.uitest` có LSHandlerRank `None` (build setting
  `EXAMSUITE_DOC_HANDLER_RANK`, không dùng `lsregister -u`); smoke test hai bản kiểm cờ đề mẫu nằm trong
  `Preferences/defaults.plist` của thư mục tạm; `DocumentGroup` gắn `.defaultAppStorage`.

- 2026-10-17 (bước 5b, lần chạy UI test PR #42 trên a343165): luồng 4 thất bại ở ⌘Q cuối cùng, lúc Trước khi thi (sheet
  trên Thư viện, sau Thử đề này) đang mở: sheet biến mất, mọi cửa sổ bị khoá, app không thoát. **Lỗi app ở cả hai bản**
  (Học viên cũng mở Trước khi thi bằng sheet): đã tái hiện bằng một app SwiftUI tối giản (không phải Exam Suite):
  `NSApp.terminate` khi cửa sổ còn sheet `.sheet` của SwiftUI không gọi `applicationShouldTerminate`, app ở lại; đóng
  sheet bằng `endSheet` của AppKit vẫn kẹt; đóng qua trạng thái SwiftUI rồi terminate thì thoát; hộp `.alert` (NSPanel)
  không chặn. Sửa: mục **Thoát** (⌘Q) của menu app thay bằng `SessionQuitCommands` ở cả hai bản: đóng Trước khi thi, sheet
  Thông tin và danh sách file không thêm được (qua model), ảnh phóng to (thông báo `willQuitNotification`), chờ tới khi
  không còn sheet SwiftUI (tối đa 2 giây) rồi mới `NSApp.terminate`; có bài chưa nộp thì vẫn hỏi Bỏ bài như trước. Còn
  lại (test tay): Thoát từ Dock/đăng xuất khi đang có sheet đi thẳng vào `terminate` của AppKit, chưa đổi. **Đã thay ở
  PR #45** (plan giai đoạn 5, Decisions 2026-10-17): bỏ `SessionQuitCommands`/`willQuitNotification`, mọi sheet gắn
  `presentationAllowsAppTermination()`, mục Thoát và Apple event thoát trả về cho AppKit. Cùng lần: hai
  danh sách ở đáy cùng mở thì mỗi cái tối đa 100 pt (review lại, trường hợp 8 dòng báo cáo + 8 lỗi ở 960×640).

- 2026-10-17 (bước 5b, lần chạy UI test PR #42 trên 262c410): luồng 4 và Import đề… của bản Admin thất bại ở bước lần đầu
  chạy tới (không do đổi độ rộng cột của d32193b). Bản ghi màn hình: danh sách lỗi mở (cao tới 220 pt dù chỉ 2 dòng)
  **phủ lên** phần cuối Form của trình soạn (`safeAreaInset`), các lựa chọn A–D nằm dưới lớp phủ mà vẫn được tính là đang
  hiện, nên bấm ô "Đúng" trúng chỗ trống của danh sách (còn "2 lỗi"); báo cáo import cũng chồng lên Form nên XCUITest
  không tìm được điểm bấm cho dòng báo cáo. Sửa app: báo cáo import và thanh lỗi nằm **dưới** trình soạn (VStack), danh
  sách ở đáy cao theo số dòng (28 pt/dòng, tối đa 180 pt) rồi cuộn. WindowLayoutTests kiểm không danh sách nào chồng lên
  vùng cuộn của trình soạn, trình soạn còn ≥ 200 pt (bố cục cũ thất bại: chồng 92 pt và 36 pt).

- 2026-10-17 (bước 5b, lần chạy UI test đầu của PR #42 trên 8dbc27e, chi tiết cài đặt): UI test tìm ra hai lỗi app, sửa
  trong #42. (A) Cửa sổ soạn đề mới: cột cây đề bị đẩy ra ngoài mép trái (dòng Đề ở x = −16,5; cũng là điểm 1 của snapshot
  PR #41). Đo được (WindowLayoutTests): split view của SwiftUI tính độ rộng tối thiểu = tối thiểu khai báo của cột giữa +
  độ rộng các cột phủ lên nó, cộng lần nữa các cột bên (cũ: 420 + 2 × 360 + 308 = 1.448 pt). Sửa: xem trước gắn vào cột
  giữa, cột giữa không khai báo tối thiểu (cửa sổ tối thiểu 960 pt giữ trình soạn ≥ 312 pt), cây đề 200/240/300, xem trước
  240/280/340, cửa sổ mới 1200×760 (`DocumentGroup.defaultSize`). (B) Import đề… dừng app sau Import (EXC_BREAKPOINT trong
  `BindingOperations.ForceUnwrapping`): hộp xác nhận dùng `Binding($model.form)` ép mở, đọc lại sau khi form về nil; nay ô
  đọc/ghi qua `ImportFlowModel.text(of:)`/`setText(_:of:)`, test dựng view trong `NSHostingView` (code cũ dừng bằng
  SIGTRAP). Luồng 2 của bản Học viên chọn ngẫu nhiên 20 câu nên có lúc hai câu trả lời đều đúng, Kết quả không có nút Xem
  câu sai: câu 1 nay chọn lựa chọn sai theo `Apps/UITestSupport/Fixtures/attt-correct-options.json` (BundledSampleTests
  kiểm khớp đề mẫu). Quy tắc chạy lại của `verify_local.sh` không coi lỗi đó là lỗi hạ tầng (đúng).

- 2026-10-17 (bước 5b, review độc lập PR #42 phát hiện 1): bước so `~/Library/Autosave Information/` của
  `verify_local.sh --uitest` không đọc được thư mục (TCC chặn cả Terminal khi chưa có Full Disk Access) thì **dừng**, không
  đạt mà không kiểm; `--no-autosave-check` bỏ riêng bước này và status ghi "kiểm Autosave: bỏ qua". Đã kiểm (chương trình
  Foundation riêng, không mở app): với `CFFIXED_USER_HOME=<thư mục>`, `FileManager.url(for: .autosavedInformationDirectory,
  in: .userDomainMask)` và `NSHomeDirectory()` trỏ vào `<thư mục>/Library/Autosave Information`; không có biến này thì là
  `~/Library/Autosave Information` thật. App cô lập chạy với `CFFIXED_USER_HOME` = thư mục nhà tạm (`IsolatedApp`), nên
  bản tự lưu của đề chưa lưu sẽ nằm trong thư mục tạm (UI test ghi nội dung thư mục đó vào log để xác nhận khi chạy
  thật); so thư mục thật là lớp chặn thứ hai.

- 2026-10-17 (bước 5b, review độc lập PR #42 phát hiện 2): Nt0 chốt **theo macOS** (authoring.md phương án 15): đề đã
  có file tự lưu tại chỗ, ⌘W đóng không hỏi (Versions, Hoàn lại > Bản đã lưu giữ bản trước); đề chưa từng lưu (Đề mới,
  Import đề…) hỏi Lưu / Không lưu / Huỷ. Luồng 5 kiểm hành vi **mặc định**, bỏ `-NSCloseAlwaysConfirmsChanges YES`; test đề mẫu đặt
  `-NSCloseAlwaysConfirmsChanges NO` ở miền tham số (không ghi defaults) để không phụ thuộc cài đặt của máy chạy test: đề mẫu
  sửa rồi ⌘W đóng không hỏi và mở lại thấy thay đổi; phần "Huỷ giữ cửa sổ" chuyển sang Đề mới có sửa.

- 2026-10-16 (bước 5b, móc cho UI test, chi tiết cài đặt, không phải chính sách sản phẩm mới): `-ExamSuiteUITestChosenFile
  <file>` thay hộp chọn file của macOS ở **Thêm/Thay ảnh…** và **Import đề…** của bản Admin. Chỉ biên dịch ở Debug
  (`#if DEBUG` trong `UITestLaunchOptions`, `AppLaunchStorage.uiTestChosenFile`, `AuthoringHooks.uiTestChooseImageFile`,
  AdminShell; `AppLaunchStorageTests` quét mã nguồn; `verify_local.sh` build Release hai bản và `check_release_strings.sh` kiểm
  binary không có chuỗi `ExamSuiteUITest`, bản Debug là đối chứng âm), chỉ cùng
  `-ExamSuiteUITest <thư mục>` (thiếu thì app dừng như tham số hệ số thời gian), file phải có thật, là file thường chỉ
  một liên kết cứng, và sau `realpath` nằm trong thư mục cô lập (liên kết, `..` ra ngoài, đường dẫn tương đối, liên kết
  cứng bị từ chối); kiểm lúc khởi động và kiểm lại ngay trước mỗi lần đọc (review độc lập #42 mục 5), không hợp lệ thì
  không đọc và không mở hộp chọn file. Hộp Lưu không có móc: UI test mở app với `-NSNavLastRootDirectory <thư mục
  tạm>` (miền tham số, không ghi defaults) để chỗ lưu mặc định đã là thư mục tạm, lái bằng bàn phím (tên, ⇧⌘G chờ hộp
  Đi tới thư mục mở rồi đóng, đường dẫn, Return), kiểm ô vị trí là thư mục tạm trước khi bấm Lưu (không thì Huỷ, không
  lưu), rồi kiểm file nằm trong thư mục tạm. Hộp hỏi khi đóng: Huỷ bằng Esc (không phụ thuộc ngôn ngữ của nút AppKit). Tự lưu đề chưa lưu vào
  `~/Library/Autosave Information/` không theo bundle ID: mỗi test kết thúc bằng lưu vào thư mục tạm hoặc đóng không
  lưu rồi ⌘Q; khối dọn dẹp thoát app và bỏ thay đổi trước khi `IsolatedApp` buộc dừng; `verify_local.sh --uitest` so
  mục của Exam Suite trong thư mục đó (tên, mtime, cỡ) trước–sau, có mục mới thì thất bại. Đề mở gần đây của bản
  `.uitest` ghi vào `<bundle ID Admin>.uitest.sfl*`, tách khỏi bản thật (đã so); "Mục gần đây" chung của macOS
  có thể nhận đường dẫn `/private/tmp` của test: script chỉ ghi chú, không thất bại.

- 2026-10-16 (bước 4a, chi tiết cài đặt, không phải chính sách sản phẩm mới): document giữ bản sao đề sau khoá cho
  `snapshot`/`fileWrapper`, nguồn sửa là `AuthoringEditor` (main actor). Gõ chữ: chỉ lần gõ đầu của đoạn gõ đăng ký
  thay đổi ngược (bản chụp cả câu/thuộc tính/tên phần); đoạn gõ kết thúc khi đổi trường, đổi dòng chọn, rời ô, thao tác
  khác, Hoàn tác/Làm lại, hoặc macOS chụp đề để lưu (để document được đánh dấu "Đã sửa" lại). Ô chữ nhiều dòng là
  `TextField(axis: .vertical)` (⌥↩ xuống dòng; trình soạn chữ bỏ bước Hoàn tác riêng khi rời ô), không dùng
  `TextEditor`. Cây đề là một danh sách phẳng (dòng phần + dòng câu) để `onMove` làm được cả ba kiểu kéo thả; thả câu
  ngay sau dòng phần = đầu phần đó; kéo dòng phần là kéo cả phần, thả giữa các câu của phần khác = sau phần đó; đang
  tìm thì tắt kéo thả. Kiểm đề hẹn 250 ms sau thay đổi cuối, chạy ngoài main actor. Dòng "Bản Học viên sẽ từ chối đề
  này" khi đề còn lỗi kiểm đề, hoặc file đang lưu rớt đọc nghiêm vì lý do khác (trường lạ, khoá trùng…; hết sau khi
  lưu lại). ⌘F của Thư viện và ⌃⌘I/⌘F của Soạn đề chỉ gắn phím khi cửa sổ tương ứng đang dùng. Các điểm mở của
  PR #34 Nt0 đã chốt (dòng dưới).
- 2026-10-16 (bước 4a, Nt0 chốt các điểm mở của PR #34; authoring.md phương án 7–10): câu mới **bốn** lựa chọn trống
  A–D, một đáp án, chưa có đáp án đúng (đổi `AuthoringDefaults.blankQuestion` của bước 1 từ hai lựa chọn; tham số
  `optionCount` chỉ để test); các điểm còn lại duyệt như đã làm: chèn ngay sau dòng đang chọn (không chọn gì thì cuối
  phần/cuối đề), Xem trước Luyện tập như sau Kiểm tra đáp án kể cả đề `hideAnswers`, "Phần N", Cấp id mới chỉ khi id
  trùng, quy tắc kéo thả trên cây đề, thanh lỗi ở đáy cột giữa.
- 2026-10-16 (bước 4a, review độc lập PR #34 trên bb6dfab: REQUEST CHANGES, 7 phát hiện, đã sửa): (1) cửa sổ gán
  `UndoManager` theo định danh của bộ soạn đề (Hoàn lại > Bản đã lưu dựng document mới), thiếu thì fault + assert ở
  Debug; (2) Nt0 chốt giữ exam-format.md: ảnh sai tên trong file bị bỏ khi đọc và mất khi lưu, không đổi ExamFile,
  không tự đổi tên; thanh lỗi/trình soạn nói rõ "sai tên … sẽ bị bỏ khi lưu" (authoring.md phương án 11), biết tên entry
  bằng bộ đọc thư mục trung tâm zip chỉ đọc trong AuthoringFeature; (3) ảnh đọc nền áp theo id câu; (4) cây đề lúc tìm
  dùng chữ đã chuẩn hoá theo câu và nhớ kết quả theo (phiên bản đề, chữ tìm); (5) `issues` gắn phiên bản đề, bấm vấn đề
  cũ thì kiểm ngay và tìm lại theo id; (6) chỉ nhận ảnh là file trên máy, không đọc được kích thước là lỗi; (7) lý do
  bản Học viên từ chối file chỉ hết khi đọc lại file trên đĩa thấy sạch. Menu Bài thi chỉ giữ ⌃⌘I khi lệnh đang bật.

- 2026-10-16 (bước 4b, chi tiết cài đặt, không phải chính sách sản phẩm mới): tiến độ và hộp xác nhận của Import đề…
  nằm trong một cửa sổ riêng `Window` "Import đề" (một bản, không khôi phục, đóng cửa sổ = Huỷ), mở sau hộp chọn file;
  lỗi import và `.vce` hiện bằng `NSAlert` không mở cửa sổ nào. Ô mã đề để trống thì đề không có mã; ô số nhận số
  nguyên ASCII (bỏ khoảng trắng hai đầu). Bảng báo cáo import nằm trên thanh lỗi, mở sẵn, ẩn/hiện bằng nút trên thanh
  công cụ; chỉ trong bộ nhớ (mở lại file đã lưu thì không còn). Thử đề này: đề không có thay đổi và đã có file thì
  không lưu lại; số N trong "Đề còn N lỗi" là số lỗi mức `error` của lần đọc nghiêm (lý do khác: N = số mục hoặc 1);
  Trước khi thi mở với chế độ dùng lần trước (như nhấp đúp thẻ đề).
- 2026-10-16 (bước 4b): Nt0 chốt các điểm mở của PR #35 (authoring.md phương án 12–14, import.md phương án 16): Thử đề
  với file cùng id đề khác file → **Dùng file mới** thì mở Trước khi thi luôn (`LibraryModel.addExamFile(_:afterReplacing:)`),
  Huỷ thì không thử; Thử đề mở Trước khi thi với chế độ dùng lần trước; cửa sổ riêng "Import đề", đóng là Huỷ.
- 2026-10-16 (bước 4b, review độc lập PR #35 trên b8c4fc6: APPROVE kèm điều kiện, đã sửa): Nt0 chốt **mã đề tuỳ chọn**
  ở hộp xác nhận (tiêu đề, ngưỡng, thời gian bắt buộc; mã đã nhập phải khớp mẫu; import.md phương án 18). (1) N trong
  "Đề còn N lỗi" là số lỗi `ExamValidator` trên file vừa lưu (đọc dễ, kể cả ảnh thiếu), bằng số trên thanh lỗi; file bị
  từ chối vì lý do khác (trường lạ…) hoặc không đọc được (đã chuyển/xoá, zip hỏng) báo lý do thật với tiêu đề khác; (3)
  document mở từ Import đề… được đánh dấu "Đã sửa" khi có cửa sổ (`updateChangeCount(.changeDone)`), để ⌘W/⌘Q hỏi lưu;
  (4) Thử đề lưu `NSDocument` của chính cửa sổ chứa bộ soạn đề (`AuthoringDocumentBridge`), không dùng
  `currentDocument`; (5) dòng báo cáo của câu đã xoá không bấm được, ghi "Câu này đã bị xoá khỏi đề."; (7) thêm cùng file
  lần nữa khi hộp Dùng file mới của file đó còn chờ thì bỏ hộp cũ (một hộp, kết luận đọc file mới nhất); sau Dùng file
  mới, Thử đề đọc nghiêm lại file trước khi mở Trước khi thi (kết luận của hộp hỏi lấy lúc hỏi; trạng thái thẻ cập
  nhật ở lần Làm mới trạng thái kế tiếp như trước, và Bắt đầu vẫn đọc nghiêm lại theo exam-taking.md). Bỏ chặn `.vce`
  sau khi merge #38: `ImportError.unreadableVCE` hiện hộp thông báo, không mở cửa sổ.

- 2026-10-16 (bước 6, chi tiết cài đặt theo mô tả định dạng, không phải chính sách sản phẩm mới): hai file `.vce` mẫu
  thêm (không commit) giải được: câu nhiều đáp án viết liền (`AC`), loại câu 5 cho cả một và nhiều đáp án, byte đầu bản
  ghi câu là cờ nhiều đáp án, trường 14 đầu file là bảng nhóm đề (docs/notes/vce-format.md). Bộ đọc: lỗi mức file (magic,
  kích thước, CRC-32, cắt cụt, độ dài vượt dữ liệu, nhiều/không có nhóm, byte thừa) → `ImportError.unreadableVCE`, không
  mở cửa sổ; lỗi trong một bản ghi câu → bỏ câu (`unreadableQuestion`), loại câu khác 5 → bỏ câu
  (`unsupportedQuestionType`); bản ghi RVF khác văn bản kiểu chữ 0 (ảnh, đường kẻ, bảng, kiểu chữ khác 0, query khác 0)
  → bỏ phần đó, cảnh báo `unsupportedContent`; phần −1/id lạ → tên nhóm đề, không có thì "Phần chung"; đoạn lựa chọn
  ghép bằng xuống dòng như docx (phương án 14), đoạn đề bài/giải thích thành đoạn Markdown; `xstr`/ANSI ngoài ASCII đọc
  theo Windows-1252 và cảnh báo `assumedEncoding`; trần `ImportLimits.vceBytes` 256 MiB. Mã báo cáo mới:
  `unsupportedQuestionType`, `unreadableQuestion` (bỏ câu), `unsupportedContent`, `unexpectedAnswerFormat`,
  `unknownSection`, `assumedEncoding` (cảnh báo). Ảnh, định dạng chữ, loại câu khác, nhiều nhóm vẫn chưa có file mẫu.

- 2026-10-16 (bước 6, Nt0 chốt 4 câu hỏi của PR #38, import.md phương án 17): chữ kiểu chữ khác 0 giữ dạng chữ thường,
  bỏ định dạng, cảnh báo `formattingDropped` mỗi câu; đoạn trong lựa chọn ghép bằng xuống dòng (như docx), đề bài/giải
  thích bằng đoạn Markdown; phần −1 với nhóm không tên → "Phần chung"; file nhiều nhóm đề không bị từ chối: đọc mọi bản
  ghi nhóm, câu không phần → "Phần chung" hoặc tên nhóm khi có đúng một nhóm có tên, cảnh báo `multipleGroups` mức file,
  không đoán câu thuộc nhóm nào; bản ghi nhóm hỏng → lỗi.

- 2026-10-16 (bước 6, review độc lập PR #38, người điều phối giao sửa): `ExamAssembler` tuyến tính (chỉ mục câu cho
  `detach`, từ điển tên phần; lợi cho cả txt/docx từ #32); báo cáo import giữ chi tiết 1.000 mục đầu, phần còn lại một
  mục tóm tắt mỗi mã, số đếm vẫn đủ (mọi định dạng); trần `.vce` 64 MiB; RVF bỏ CR LF sau U+2029 và dừng khối khi số
  dòng của bản ghi bị bỏ qua lấn sang bản ghi sau; `Section: X` trong giải thích `.vce` chỉ bỏ khi X là `(none)` hoặc tên
  phần trong bảng; cảnh báo phần không tên và bảng mã theo từng trường (import.md mục `.vce`, Giới hạn).

## Validation

- Focused proof: `swift test --package-path Packages/ExamFeatures` (`AuthoringDataTests`, `ExamImportTests`, test của
  AuthoringFeature); thử import file thật tại máy (ghi số liệu vào PR).
- Integration: `scripts/verify_local.sh --uitest` (cả hai target UI test khi có), `check_boundaries.py`,
  `check_bundle_boundary.sh`; mở thử đề 2.000 câu trong cửa sổ soạn đề.
- Repository-required checks: `local/verify` xanh trên SHA cuối mỗi PR; PR rủi ro cao có review độc lập.
- Cần người test tay: khôi phục sau crash, Versions, hộp hỏi lưu khi đóng/thoát, VoiceOver, Dark Mode, kéo thả ảnh từ
  Finder, cổng G2.

## Cổng G2: phần soạn đề và import

Bổ sung cho checklist "Cổng G2: dùng thử" của [giai đoạn 3](giai-doan-3-lam-bai.md) (phần bản Học
viên và phân loại lỗi vẫn dùng nguyên). Đề thật giờ do admin soạn hoặc import bằng bản Admin, không cần tự viết
`exam.json`.

Việc của admin (bản Admin):

1. **Đề mới** (⌘N hoặc nút trên Thư viện): thuộc tính đề, thêm phần, thêm câu một đáp án và nhiều đáp án, thêm ảnh
   (nút Thêm ảnh… và kéo thả ảnh từ Finder), xem thanh lỗi rồi sửa, xem trước Luyện tập/Thi (⌃⌘I), lưu (⌘S) thành
   `.exam`.
2. **Import đề…** từ file thật của người dùng thử (`.txt`, `.docx`, `.vce`): kiểm hộp xác nhận (tiêu đề, mã, ngưỡng, thời gian),
   đọc báo cáo import, so số câu và vài đáp án với file gốc, sửa câu bị báo lỗi, lưu.
3. **Thử đề này** (⌘R): làm vài câu, nộp, xem Kết quả.
4. **Sửa đề đã lưu** (⌘E từ Thư viện): kéo thả sắp xếp, Hoàn tác/Làm lại, đóng cửa sổ (tự lưu, không hỏi), mở lại thấy
   thay đổi; thử File → Revert To / Browse All Versions.
5. Đóng một **Đề mới chưa lưu** có sửa: app phải hỏi.
6. Phát file `.exam` cho người dùng bản Học viên; họ làm trọn đề theo checklist giai đoạn 3.

Việc thêm (cả hai bản, đã có trong `main` từ giai đoạn 5):

7. Ở Kết quả: **Xuất PDF…** và **In…** (⌘P) với ba mức "Phần xem lại bài"; mở PDF kiểm nội dung; đề ẩn đáp án không lộ
   đáp án đúng/giải thích.
8. ⌘Q khi đang mở Trước khi thi: app thoát ngay; ⌘Q khi đang có bài chưa nộp: app hỏi Bỏ bài.

Test tay khác (máy không kiểm được): khôi phục sau crash (Force Quit khi đang sửa đề chưa lưu rồi mở lại), bản tự lưu
không rơi vào `~/Library/Autosave Information/` khi chạy UI test (`verify_local.sh` chưa kiểm được vì cần Full Disk Access;
Nt0 test sau), VoiceOver, Dark Mode, thoát từ Dock và đăng xuất khi đang mở Trước khi thi hoặc có bài chưa nộp, chữ
của macOS (menu chuẩn, hộp Mở/Lưu) khi máy ưu tiên tiếng Việt.

Lỗi **chặn** thêm cho giai đoạn này: lưu làm hỏng hoặc mất file đề, import sai đáp án mà báo cáo không báo, bản Học viên
từ chối đề hợp lệ do bản Admin lưu.

## Result

Tạm đóng 2026-10-17 theo quyết định của Nt0: Soạn đề và import xong, đã merge và cài lên máy; **cổng G2 và test tay
chưa chạy**, Nt0 tự test trên bản cài rồi báo lỗi (nếu có) để sửa ở giai đoạn 5.

- **Merge vào `main`:** #28 (đóng giai đoạn 3), #29 (kế hoạch), #30 (spike `.vce`), #31 (AuthoringData), #32
  (ExamImport txt/docx), #37 (sửa test chập chờn), #38 (bộ đọc `.vce`), #33 (chế độ cô lập bản Admin), #34 (cửa sổ soạn
  đề), #35 (Import đề…, Thử đề này), #42 (UI test bản Admin). PR rủi ro cao đều có review độc lập bằng phiên agent mới
  và review lại sau khi sửa; tóm tắt đăng trong PR.
- **Quyết định sản phẩm:** authoring.md và import.md, các phương án đã chốt (Nt0 duyệt 2026-10-16/17), ADR 0009.
- **Thử file thật tại máy** (không commit): mẫu .txt thật A 1.019 câu, mẫu .docx thật 40 câu, mẫu VCE 1 40 câu (đáp
  án khớp docx), mẫu VCE 2 và 3 600 và 419 câu; đều 0 câu bỏ.
- **UI test tìm ra và đã sửa:** crash sau Import/Huỷ trong hộp xác nhận, cột cây đề bị cắt, danh sách lỗi/báo cáo import
  phủ lên trình soạn, ⌘Q treo khi đang có sheet SwiftUI (thay hẳn cách xử lý ở #45, giai đoạn 5).
- **Bằng chứng cuối:** `local/verify --clean --uitest` trên `611475a` (SHA cài): UI test Học viên 7, Admin 5, kho và
  defaults thật không đổi, Linux ok; **kiểm Autosave bỏ qua** (cần Full Disk Access; Nt0 chọn test sau). Release hai
  app ký ad-hoc build từ `611475a`: `codesign --verify --deep --strict` ok, không có code cô lập của UI test
  (`check_release_strings.sh`, đối chứng Debug đạt), kiểm bundle: Học viên 0, Admin 4.373 ký hiệu AuthoringFeature, không
  app nào chứa thư viện chỉ cho test.
- **Cài đặt:** /Applications 2026-10-17; bản cũ (`4737ec9`, giai đoạn 3) sao lưu ở
  `~/ExamSuite-backup/2026-10-17-truoc-cai-611475a/`. Bản cài gồm cả phần giai đoạn 5 đã merge (String Catalog, đo đề
  lớn, snapshot test, PDF và In kết quả, thoát app khi có sheet).
- **Sự cố quy trình:** 2026-10-17 VS Code treo vì chạy song song nhiều build/agent trong thư mục workspace (47 GB
  worktree); đã dọn và chuyển sang chạy tuần tự từng việc nặng.

Chuyển sang sau:

- **Cổng G2** và test tay theo checklist ở trên (Nt0).
- Kiểm `~/Library/Autosave Information/` của `verify_local.sh --uitest` (cần Full Disk Access cho trình chạy).
- `.vce` dựng lúc chạy UI test (tuỳ chọn, chưa làm).
- Bố cục thấy qua snapshot (thanh nút cây đề đè dòng, chữ "Lỗi" bị cắt, tiêu đề xem trước xuống dòng, biểu tượng mờ ở chế
  độ sáng) → giai đoạn 5 bước 8; lần gõ đầu vào ô tìm của Soạn đề ~43 ms → bước 9.
