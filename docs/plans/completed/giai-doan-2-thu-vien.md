# Execution Plan: Giai đoạn 2 · Thư viện

Date: 2026-10-15

## Status

Completed (2026-10-15). Nt0 test tay đạt trên bản Release; không có cổng (G2 sau giai đoạn 3).

## Outcome

Cả hai bản app mở vào cửa sổ Thư viện thật: thêm đề bằng nút, kéo thả và (bản Học viên) mở từ Finder;
thẻ đề có thông tin và trạng thái file mất/hỏng/cần app mới; tìm, lọc, sắp xếp, lưới/danh sách;
đề mẫu lần đầu mở app; danh sách lịch sử thi; dữ liệu lưu bằng SwiftData, mỗi bản app một kho.
Giai đoạn này không có cổng; cổng G2 ở cuối giai đoạn 3.

## Context

- Thẩm quyền sản phẩm: [docs/product/library.md](../../product/library.md) (viết cho giai đoạn này),
  exam-format.md (chế độ đọc nghiêm/dễ), plan-macos-v1.md (UX, dữ liệu riêng của app, rủi ro SwiftData).
- ADR 0003 (bản Học viên không chứa AuthoringFeature), 0006 (không thêm thư viện), 0008 (lõi Foundation-only:
  SwiftData và SwiftUI chỉ nằm trong `Packages/ExamFeatures`).
- Kết luận spike giai đoạn 0: bản Học viên nhận file từ Finder nhưng bỏ qua vì chưa có xử lý; bản Admin mở
  `.exam` từ Finder vào DocumentGroup.
- Quy trình: docs/process/review-and-merge.md. Bước 1–3 là rủi ro cao (lưu trữ dữ liệu người dùng, đọc file đề,
  ranh giới hai bản app).

## Scope

In scope: module `LibraryData` (dữ liệu, không giao diện), đề mẫu, `LibraryFeature` (giao diện Thư viện,
Lịch sử thi), nối vào hai bản app, mở file từ Finder ở bản Học viên, nút Sửa ở bản Admin, test tự động cho
phần dữ liệu, chạy test ExamFeatures trên CI macOS.

Out of scope: Trước khi thi và làm bài (giai đoạn 3), soạn đề và Đề mới (giai đoạn 4), Cài đặt/About/String
Catalog/biểu tượng app (giai đoạn 5), XCUITest (từ giai đoạn 3).

## Approach

Ba bước code, mỗi bước một PR trên nhánh `feature/g2-<bước>`. Bước 1 và 2 chạy song song; bước 3 dựng trên
API thật của bước 1.

1. **`LibraryData`** (target mới trong `Packages/ExamFeatures`, chỉ Foundation, Observation, SwiftData,
   UniformTypeIdentifiers, OSLog, ExamKit, ExamFile; không SwiftUI):
   - SwiftData `@Model` cho mục thư viện và lần thi, `VersionedSchema` v1; kho riêng theo bundle ID;
     kho hỏng thì đổi tên và tạo mới.
   - Lớp repository; bản SwiftData và bản trong bộ nhớ cho test/preview.
   - Một `@Observable @MainActor` store mà giao diện bind vào: tải, thêm file (nhiều file, báo cáo kết quả),
     trùng id (cùng file/khác file cần xác nhận), làm mới trạng thái chạy nền, tìm lại file, xoá + hoàn tác,
     đề mẫu (tạo lần đầu, khôi phục), thêm/đọc lần thi, lần thi gần nhất của từng đề.
   - Hàm thuần cho tìm (không dấu), lọc, sắp xếp (thứ tự tiếng Việt), "Gần đây" 30 ngày.
   - Cấu hình theo bản app: chế độ đọc (nghiêm/dễ), là Admin hay không, đường dẫn kho và thư mục đề mẫu.
   - `UTType.examPackage` chuyển từ AuthoringFeature sang đây để bản Học viên dùng được.
   - Lần thi lưu các trường tóm tắt (để liệt kê, sắp xếp) cộng một `payload: Data` để giai đoạn 3 tự quyết nội dung.
   - Target test `LibraryDataTests`; `scripts/check.sh` bước 4 chạy `swift test` cho ExamFeatures; CI macOS
     chạy cùng lệnh (kế hoạch quy định job macOS chạy test).
2. **Đề mẫu**: hai đề tự soạn, tiếng Việt, nội dung đúng, có ảnh tự tạo và câu nhiều đáp án, đặt ở
   `Packages/ExamFeatures/Sources/LibraryData/Resources/Samples/<tên>/`; script và test kiểm như fixture
   (đọc nghiêm, không error, không warning).
3. **`LibraryFeature` + nối app**: giao diện theo library.md (sidebar, lưới/danh sách, thẻ và trạng thái,
   menu, Thông tin, Thêm đề, kéo thả, thông báo + Hoàn tác, dải chào mừng, Lịch sử thi, hộp thoại trùng id);
   StudentShell/AdminShell tạo store theo cấu hình; bản Học viên nhận file từ Finder; bản Admin có Sửa;
   lệnh menu File > Thêm đề…, Trợ giúp > Khôi phục đề mẫu. Build hai app, kiểm ranh giới bundle, mở thử.
4. **Người điều phối**: tài liệu (AGENTS.md bản đồ code, overview, CHANGELOG), cài hai app vào /Applications,
   checklist test tay cho Nt0, đóng plan.

## Risks And Recovery

- SwiftData lỗi hoặc khó test: mọi truy cập đi qua repository; có bản trong bộ nhớ; dự phòng GRDB cần ADR.
- Hai bản app dùng chung kho mặc định nếu quên cấu hình đường dẫn: test khẳng định đường dẫn kho theo bundle ID.
- Đọc file lớn chặn giao diện: đọc nền, giới hạn số file đọc cùng lúc; đo với đề 2.000 câu.
- Bookmark không phân giải khi ổ ngoài chưa gắn: trạng thái "Không tìm thấy file", không xoá mục.
- Mất dữ liệu thư viện khi đổi schema: `VersionedSchema` từ v1; test mở kho v1 thật đã commit
  (`Tests/LibraryDataTests/Fixtures/Library-v1.store`) và so hash phiên bản model của nó với `LibrarySchemaV1`
  hiện tại, đỏ với mọi thay đổi model V1.
- Hạ cấp app: kho do bản mới hơn tạo (schema mới hơn) không mở được bằng bản cũ nên bị dời sang
  `Library.store.broken-<thời điểm>`; thư viện và lịch sử thi biến mất khỏi bản cũ. Cài lại bản mới không tự lấy lại;
  phải đổi tên file kho thủ công.
- Kho SwiftData lạ không có phiên bản (không do app tạo) có thể bị SwiftData chuyển đổi âm thầm thay vì bị coi là
  hỏng. Khả năng thấp vì đường dẫn kho riêng theo bundle ID.
- Đọc file treo (ổ mạng không phản hồi) khi làm mới: mỗi lần kiểm file có thời hạn 120 giây, quá hạn thì bỏ qua lần
  đó. Luồng đọc treo vẫn bị giữ tới khi hệ điều hành trả về, nhưng làm mới không mở thêm lần đọc cho mục còn lần đọc
  treo, nên mỗi mục giữ nhiều nhất một luồng.
- Lệnh nhập file (Thêm đề, kéo thả, mở từ Finder) và **Tìm file…** chưa có thời hạn đọc: chọn một file trên ổ mạng
  treo thì lệnh chờ tới khi hệ điều hành trả về.
- Recovery: mọi thứ trong git; dữ liệu người dùng chỉ là kho thư viện, xoá kho thì app tạo lại (mất lịch sử thi).

## Progress

- [x] 1 LibraryData (nhánh `feature/g2-library-data`): target `LibraryData` + `LibraryDataTests` (80 test),
  `UTType.examPackage` chuyển sang LibraryData, `check.sh` bước 4 và CI `apps-macos` chạy `swift test` ExamFeatures
- [x] 2 Đề mẫu (PR #14, nhánh `feature/g2-de-mau`): "Làm quen với Exam Suite" và "An toàn thông tin cơ bản",
  kiểm như fixture (đọc nghiêm, không error, không warning)
- [x] 3 LibraryFeature + nối app (PR #16, nhánh `feature/g2-library-ui`): cửa sổ Thư viện (`Window` một bản),
  lưới/danh sách, Thông tin, Lịch sử thi, Thêm đề/kéo thả/mở từ Finder (Học viên), Xoá + Hoàn tác (⌘Z), dải chào
  mừng, lệnh menu; `StudentShell`/`AdminShell` tạo store qua app delegate; target `LibraryFeatureTests` (47 test);
  test đề mẫu thật trong LibraryDataTests (84 test sau khi gộp `45d2ade` của #15). Chờ người test tay (danh sách
  trong PR)
- [x] 4 Tài liệu, cài app, checklist test tay (PR #17): quyết định đã duyệt ghi vào library.md và exam-session.md,
  AGENTS.md, CHANGELOG; bản Release cài vào /Applications; Nt0 test tay đạt.

## Decisions

- 2026-10-15: Tách `LibraryData` (không giao diện, có test) khỏi `LibraryFeature` (SwiftUI) để logic thư viện
  test được bằng `swift test`, giao diện chỉ hiển thị trạng thái và gửi lệnh (giống cách ExamKit tách khỏi UI).
- 2026-10-15: Lần thi lưu tóm tắt + `payload: Data`; định dạng payload chốt ở giai đoạn 3 cùng `Codable`
  cho `ScoreResult`/`ExamPaper`, để giai đoạn 2 không phải sửa ExamKit.
- 2026-10-15: Nt0 duyệt cả 8 câu hỏi của giai đoạn 2: library.md "Phương án đã chốt" 1–11 (⌘O, màu tối,
  phân loại hai lần đọc, Học viên đóng cửa sổ thì thoát, Admin mở kèm Thư viện), bốn quy tắc riêng cho đề mẫu,
  hướng phím làm bài (exam-session.md: A–Z chỉ chọn đáp án), thứ tự merge #13 → #14 → #15 → #16.
- 2026-10-15 (bước 1; phân loại hai lần đọc Nt0 duyệt, phần còn lại là lấp chỗ trống đã qua review độc lập): đọc file luôn thử nghiêm trước rồi mới dễ; "đọc dễ được, đọc
  nghiêm thất bại" là **Đề có lỗi** (Học viên) / **Có lỗi** (Admin), không đọc dễ được là **File hỏng**/**Cần app mới
  hơn**. File trong Thùng rác và vị trí file giờ là đề khác (khác id) đều là **Không tìm thấy file**. "Gần đây" =
  lần thi hoặc lần thêm (cái muộn hơn) trong 30 ngày. Kết luận đọc file được lưu kèm dấu "phiên bản định dạng + phiên
  bản app"; app cập nhật thì đọc lại mọi file. **Dùng file mới** bỏ cờ đề mẫu của mục. Cờ "đã tạo đề mẫu" chỉ bật khi
  mọi đề mẫu thêm được; **Khôi phục đề mẫu** thêm lại đề mẫu đã xoá và ghi lại file đề mẫu bị mất, không đụng mục đang
  có file. Tìm theo từ: mọi từ phải nằm trong tiêu đề hoặc mã đề.
- 2026-10-15 (bước 1): việc chặn luồng với file (đọc gói, bookmark, ghi đề mẫu) chạy trên hàng đợi GCD riêng
  (`FileWork`), không chạy trong task của Swift concurrency: CI 3 nhân cho thấy 4 lần đọc cùng lúc chiếm hết thread
  pool hợp tác và làm main actor trễ 1,2 giây; test đọc nhiều file hơn số nhân để giữ bất biến này.
- 2026-10-15 (bước 1, sau review độc lập): hai lần nhập chồng nhau cùng một file mới cho "đã có", không hỏi
  thay file (so lại với vị trí hiện tại của mục bằng đường dẫn thật); nhập lại file đã có mà giờ không đọc được thì
  thẻ cập nhật trạng thái; file trong Thùng rác bị từ chối khi nhập và khi **Tìm file…** (lý do riêng, loại "File
  hỏng" để không đổi API); **Tìm file…** bỏ cờ đề mẫu như **Dùng file mới**; tên file đề mẫu tối đa 255 byte (tính
  theo dạng tách dấu), cắt ở ranh giới ký tự; làm mới có thời hạn 120 giây cho mỗi lần kiểm file.
- 2026-10-15 (bước 1): `UTType.examPackage` tra theo identifier (khai báo của bản app đang chạy), dự phòng
  `UTType(importedAs:)` khi không có khai báo (test); không dùng `exportedAs`/`importedAs` trực tiếp vì mỗi hàm chỉ hợp
  một trong hai bản app.
- 2026-10-15 (bước 3): `LibraryFeature` = `LibraryModel` (`@Observable`, một model cho cả app, giữ ở app delegate) +
  view; model chỉ giữ điều hướng, hộp thoại, thông báo và gọi `LibraryStore`. Logic tách được (trạng thái → biểu tượng
  + chữ, câu VoiceOver, gộp báo cáo thêm đề, điều hướng lưới) là hàm thuần có test.
- 2026-10-15 (bước 3): cửa sổ Thư viện là `Window` (không phải `WindowGroup`): không có "New Window"/⌘N, `openWindow`
  chỉ mở lại hoặc đưa lên trước. Hệ quả ở bản Học viên (cửa sổ duy nhất): đóng Thư viện thì app thoát (hành vi chuẩn
  của SwiftUI), mở `.exam` từ Finder khi đó khởi động lại app vào Thư viện; bản Admin vẫn chạy nhờ `DocumentGroup`.
- 2026-10-15 (bước 3): bản Học viên nhận file từ Finder bằng `NSApplicationDelegateAdaptor` + `application(_:open:)`
  (cả ba đường mở file, kể cả lúc khởi động; SwiftUI không tự tạo cửa sổ), rồi đi đúng luồng Thêm đề. Model tải kho
  ngay khi tạo, và các lần thêm/tìm file/khôi phục đề mẫu chạy lần lượt, để hai lần mở cùng một file không thành
  "trùng id khác file".
- 2026-10-15 (bước 3): ⌘O = Thêm đề ở cả hai bản; bản Admin thay Open… ⌘O của `DocumentGroup` bằng "Mở để sửa…" ⇧⌘O
  và "Mở gần đây" (library.md, phương án 7). ⌫ dùng `onDeleteCommand` của lưới/danh sách, không gắn ở menu (sẽ nuốt
  phím xoá chữ trong ô tìm kiếm); ⌘I, ⌘E, ⌘F ở menu, chỉ bật khi cửa sổ Thư viện đang được dùng (`focusedSceneValue`).
- 2026-10-15 (bước 3): ⌘Z đăng ký với `UndoManager` của cửa sổ; closure giữ target mạnh vì `UndoManager` chỉ giữ target
  unowned (test bắt được crash khi target bị giải phóng).
- 2026-10-15 (bước 3, sửa theo review độc lập, Nt0 duyệt: library.md mục 8): màu nhấn tách hai vai. Nền nút có
  chữ trắng dùng `#017777` ở cả hai giao diện (5,38:1). Chữ, biểu tượng, viền teal trên nền dùng `#006666` (sáng) và
  `#4FC9C9` (tối), đạt ≥ 4,5:1 trên mọi nền đã đo, kể cả nền nhạt của nhãn Đề mẫu. Biểu tượng trạng thái dùng sắc đậm
  hơn ở giao diện sáng để đạt ≥ 3:1. `LibraryPalette` giữ các màu dạng số và có test tương phản.

## Validation

- Focused proof: `swift test --package-path Packages/ExamFeatures` (LibraryDataTests) trên macOS.
  Bước 1: 80 test xanh (macOS 26, Xcode 27; 1 test chỉ chạy khi tạo lại fixture). Nhập rồi làm mới 20 đề 2.000
  câu, đọc cùng lúc nhiều file hơn số nhân CPU: main actor bị chặn lâu nhất 18–32 ms, trong khi một lần đọc nghiêm đề
  2.000 câu mất ~400 ms (debug). Kho v1 thật mở được; đổi tên thuộc tính trong `LibrarySchemaV1` làm test đỏ (thuộc
  tính bắt buộc: kho bị dời đi; thuộc tính tuỳ chọn: CoreData chuyển đổi âm thầm, mất giá trị); thêm thuộc tính
  tuỳ chọn chỉ test so hash model bắt được.
- Integration: `scripts/check.sh`; `xcodebuild` hai scheme; `scripts/check_bundle_boundary.sh`; mở thử hai app
  với đề mẫu, đề hỏng, file bị đổi tên/xoá.
- Bước 3 (macOS 26.6, Xcode 27), sau khi gộp `45d2ade` của #15: `swift test --package-path Packages/ExamFeatures` 131
  test xanh hai lần liền (LibraryDataTests 84, LibraryFeatureTests 47); `xcodebuild` hai scheme BUILD SUCCEEDED, không
  cảnh báo từ code; `check_bundle_boundary.sh` Học viên 0, Admin 248 ký hiệu AuthoringFeature. Đột biến: bỏ lọc "đã
  thêm" trong `ImportFeedback.init`, nhánh "xuống thẻ cuối" của `GridNavigation.move`, nền `#3A3A3A` khỏi danh sách
  nền tối, hoặc đảo sáng/tối trong `LibraryStyle.color()` thì test đỏ. Ảnh thẻ (sáng/tối, mọi trạng thái) xuất bằng
  `ImageRenderer` để tự xem, không commit. Chưa mở app có giao diện: phần test tay ghi trong PR.
- Repository-required checks: CI hai job xanh trên SHA cuối của từng PR.
- Cần người test tay: VoiceOver, Dark Mode, kéo thả từ Finder, mở file từ Finder khi cài cả hai bản.

## Test tay (Nt0, trên Mac đã cài cả hai bản)

Cài: bản Release của #16 trong `/Applications/Exam Suite.app` và `/Applications/Exam Suite Admin.app`. Đề thử
ở `~/Desktop/Exam Suite - đề thử/` (một đề tốt, một đề sai đáp án, một file hỏng). Đánh dấu từng dòng; dòng nào
sai ghi lại hiện tượng.

**Lần đầu mở (bản Học viên)**
- [x] Mở vào Thư viện có 2 đề mẫu Sẵn sàng và dải chào mừng; đóng dải thì không hiện lại.
- [x] Cửa sổ thu nhỏ tới 960×640 không vỡ bố cục; phóng to được.

**Thêm đề**
- [x] ⌘O chọn nhiều file; menu File chỉ có một mục ⌘O.
- [x] Kéo thả cả ba file đề thử cùng một file `.txt` vào cửa sổ: thêm đề tốt, báo gọn ba file còn lại kèm lý do.
- [x] Thêm lại đúng file đã có: báo "Đề đã có trong thư viện" và chọn đề đó.
- [x] Chép đề tốt sang chỗ khác, thêm bản chép: hộp thoại "từ file khác", thử cả **Dùng file mới** và **Huỷ**.
- [x] Nhấp đúp file `.exam` trong Finder khi chỉ có bản Học viên đang chạy và khi app đang tắt: thêm và chọn đề,
      không sinh cửa sổ thứ hai. (Khi cài cả hai bản, nhấp đúp mở bản Admin; dùng Open With → Exam Suite.)

**Thẻ, trạng thái, menu**
- [x] Đổi tên file đề tốt trong Finder rồi quay lại app: vẫn Sẵn sàng, Thông tin (⌘I) hiện đường dẫn mới.
- [x] Xoá (vào Thùng rác) file đề tốt rồi quay lại app: "Không tìm thấy file", có **Tìm file…** chọn lại được.
- [x] Nhấp đúp hoặc Return mở Thông tin; menu chuột phải và nút "…" đủ mục; Hiện trong Finder đúng file.
- [x] ⌫ xoá đề khỏi thư viện, có thông báo kèm **Hoàn tác**; ⌘Z hoàn tác; ⌫ trong ô tìm chỉ xoá chữ.
- [x] Tìm "an toan" ra đề "An toàn thông tin cơ bản"; lọc Có vấn đề; sắp xếp Tên; chuyển lưới/danh sách,
      đóng mở lại app vẫn nhớ chế độ xem và sắp xếp.
- [x] Trợ giúp > Khôi phục đề mẫu thêm lại đề mẫu đã xoá.
- [x] Đóng cửa sổ Thư viện: bản Học viên thoát.

**Bản Admin**
- [x] Menu File chỉ có một ⌘O (Thêm đề…), một ⇧⌘O (Mở để sửa…), một "Mở gần đây"; Edit chỉ có một ⌘F.
- [x] Đề sai đáp án hiện "Có lỗi" kèm **Sửa**; ⌘E mở đề vào cửa sổ soạn đề.
- [x] Nhấp đúp `.exam` trong Finder mở cửa sổ soạn đề (kèm Thư viện nếu app đang tắt).

**Giao diện và trợ năng**
- [x] Dark Mode: chữ và biểu tượng teal, nhãn Đề mẫu, nút Luyện tập/Thi đang tắt đọc được; dòng đang chọn của
      bảng, sidebar và ô Lưới/Danh sách không có chữ trắng trên nền teal sáng.
- [x] Lưới có tiêu điểm khi chưa chọn đề thì thấy vòng teal; phím mũi tên đi giữa các thẻ.
- [x] VoiceOver (⌘F5) đọc mỗi thẻ thành một câu (tên, mã, số câu, trạng thái, lần thi gần nhất) và có hành động.
- [x] Phóng chữ hệ thống lớn: bố cục không vỡ.

**Kho hỏng** (tuỳ chọn): thoát app, ghi đè `~/Library/Application Support/<bundle ID bản Học viên>/Library.store` bằng
một file rác, mở lại: app không crash, báo kho hỏng, có file `Library.store.broken-…` bên cạnh.

## Result

Xong 2026-10-15. Merge vào `main`: #13 (kế hoạch), #14 (đề mẫu), #15 (LibraryData), #16 (LibraryFeature, nối
app), #17 (tài liệu); CI xanh trên `25c1d86`. Mỗi PR code có review độc lập bằng phiên agent mới (#14 hai lượt, #15
ba lượt, #16 hai lượt), tóm tắt đăng trong PR. Nt0 duyệt 8 câu hỏi (library.md "Phương án đã chốt") và test tay
đạt theo checklist trên.

Số test lúc đóng: ExamKit 153 + ExamFile 110 (Linux và macOS), LibraryData 84, LibraryFeature 47 (macOS).

Chuyển sang sau:
- Giai đoạn 3: chốt phím Đánh dấu/Tạm dừng có ⌘ (exam-session.md), sửa đề mẫu "Làm quen" câu 7 và ảnh phím tắt cho
  khớp, và đối chiếu mọi nhãn trong đề này với giao diện thật (ví dụ "Check answer"); định dạng `payload` của lần thi.
- Lệnh nhập file và **Tìm file…** chưa có thời hạn đọc (ổ mạng treo thì chờ mãi); làm mới đã có.
- Đề mẫu ATTT01: 17/19 câu một đáp án có đáp án đúng là phương án dài nhất (dễ đoán theo độ dài).
- Ngày giờ và dung lượng định dạng theo vùng của máy; String Catalog ở giai đoạn 5.
- Sửa nội dung đề mẫu ở bản sau chỉ tới máy đã cài khi người dùng xoá rồi khôi phục (library.md).

