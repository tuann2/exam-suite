# Execution Plan: Giai đoạn 3 · Làm bài

Date: 2026-10-15

## Status

Completed, tạm đóng 2026-10-16 (Nt0 quyết). Cổng G2 (dùng thử) hoãn tới sau giai đoạn 4 Soạn đề; xem Result.

## Outcome

Từ thẻ đề trong Thư viện, người dùng cả hai bản app làm trọn một bài Luyện tập hoặc Thi chỉ bằng bàn phím:
Trước khi thi → cửa sổ làm bài (bảng câu hỏi, đánh dấu, tạm dừng, đồng hồ, cảnh báo, hết giờ) → Rà soát & nộp →
Kết quả → Xem lại bài → Làm lại / Luyện lại câu sai. Lần thi tự lưu vào Lịch sử thi, mở lại được kết quả và
xem lại bài cũ. Cổng **G2** ở cuối giai đoạn: nhóm dùng thử làm trọn đề thật, không gặp lỗi chặn.

## Context

- Thẩm quyền sản phẩm: [exam-taking.md](../../product/exam-taking.md) (viết cho giai đoạn này),
  [exam-session.md](../../product/exam-session.md) (trạng thái, lệnh, đồng hồ, phím đã chốt),
  [scoring.md](../../product/scoring.md) (chọn câu, chấm), [library.md](../../product/library.md) (Lịch sử thi, lưu trữ).
- ADR 0003 (bản Học viên không chứa AuthoringFeature), 0006 (không thêm thư viện), 0008 (ExamKit/ExamFile chỉ
  Foundation; SwiftUI chỉ trong `Packages/ExamFeatures`).
- Có sẵn từ giai đoạn trước: `ExamSession` (state machine, `SystemSessionClock`, `retakeOptions`,
  `practiceIncorrectOptions`), `ExamComposer`, `Scorer`; `LibraryStore.addAttempt(_:payload:)`, `attempts`,
  `latestAttempt`, `attemptPayload`; bảng `AttemptItem` có `payload: Data` nên **không cần đổi schema kho**.
- Việc chuyển từ giai đoạn 2: phím Đánh dấu/Tạm dừng (đã chốt ⌘D / ⌘.), sửa đề mẫu "Làm quen" câu 7 và ảnh
  phím tắt, đối chiếu nhãn trong đề mẫu với giao diện thật, định dạng `payload`; `Codable` cho
  `ScoreResult`/`ExamPaper`/`CompositionOptions` (kết quả giai đoạn 1).
- Quy trình: docs/process/review-and-merge.md. Bước 1, 3, 4, 5 là rủi ro cao (ExamKit/ExamFile;
  `Package.swift`, `project.yml`, `Apps/**`, shell của hai bản app).

## Scope

In scope: lưu lần thi (Codable + payload + dấu vân tay câu), sửa đề mẫu "Làm quen", model trình bày và giao
diện `SessionFeature`, nối Luyện tập/Thi và Lịch sử thi ở cả hai bản app, xử lý đóng/thoát/máy ngủ, XCUITest cho
luồng 1–3 (overview.md), tài liệu, cài app, checklist test tay, cổng G2.

Out of scope: Xuất PDF và In kết quả (giai đoạn 5), String Catalog tiếng Anh (giai đoạn 5), "Thử đề này" và mọi
phần soạn đề (giai đoạn 4), lưu phiên dở để làm tiếp (phương án 2 đã chốt là không), thời hạn đọc cho Thêm đề /
Tìm file… và độ lệch đáp án đề mẫu ATTT01 (việc chuyển tiếp của giai đoạn 2, chưa xếp lịch).

## Approach

Năm bước code, mỗi bước một PR trên nhánh `feature/g3-<bước>`. Bước 1 và 2 chạy song song; bước 3 dựng trên API
thật của bước 1; bước 4 trên bước 3; bước 5 trên bước 4.

1. **Lưu lần thi** (`feature/g3-luu-lan-thi`, ExamKit + ExamFile, rủi ro cao):
   - `Codable` với khoá JSON cố định cho `QuestionSelection`, `CompositionOptions` (seed `UInt64` mã hoá không mất
     chính xác), `PaperItem`, `ExamPaper`, `QuestionOutcome`, `SectionScore`, `ScoreResult` (giải mã kiểm tính nhất
     quán: tổng theo phần, `outcomes` khớp `questionIDs`).
   - `AttemptRecord` (ExamKit): `payloadVersion` = 1, tuỳ chọn, thời gian cho phép, `ExamPaper`, đáp án, đánh dấu,
     câu đã Kiểm tra đáp án, `ScoreResult`, dấu vân tay từng câu; tạo từ `ExamSession` đã nộp; mã hoá/giải mã JSON;
     `payloadVersion` lớn hơn app hiểu → lỗi riêng.
   - Dấu vân tay câu (ExamFile, dùng `SHA256` có sẵn): SHA-256 của dạng chuẩn của câu (khoá sắp xếp, NFC, gồm
     loại câu, nội dung, ảnh, lựa chọn, đáp án đúng, giải thích). Test khoá giá trị cố định như vector SplitMix64,
     vì đổi dạng chuẩn làm mọi lần thi cũ báo "đã sửa".
   - Test vòng mã hoá–giải mã, JSON mẫu cố định (golden) để phát hiện đổi khoá, payload hỏng, phiên bản mới hơn;
     chạy cả Linux và macOS.
2. **Đề mẫu "Làm quen"** (`feature/g3-de-mau`): câu 7 và ảnh phím tắt theo ⌘D / ⌘. (ảnh tự tạo, tên SHA-256);
   đối chiếu mọi nhãn trong đề (ví dụ "Check answer" → "Kiểm tra đáp án", "Rà soát & nộp") với exam-taking.md;
   `validate_exam.py --all`, `LibrarySampleTests`, `BundledSampleTests` xanh.
3. **Model trình bày `SessionFeature`** (`feature/g3-session-model`, không view, có test `SessionFeatureTests`):
   - `PreExamModel`: lựa chọn, kiểm hợp lệ + lý do khoá Bắt đầu, dòng tóm tắt, tạo `ExamPaper` với seed tiêm vào,
     Làm lại và Luyện lại câu sai điền sẵn.
   - `AttemptModel` (`@Observable @MainActor`): bọc `ExamSession` với đồng hồ tiêm vào, tick định kỳ, sự kiện →
     thông báo VoiceOver/dải cảnh báo, ánh xạ phím A–Z theo vị trí hiển thị, máy ngủ, mức đồng hồ.
   - Rà soát (số đếm, danh sách, câu hỏi xác nhận), Kết quả (so với lần trước cùng chế độ, phần yếu nhất, lưu lần
     thi qua giao thức để test), Xem lại (bộ lọc + số lượng, `hideAnswers`, câu đã xoá/đã sửa theo dấu vân tay,
     Luyện lại câu sai từ lần cũ).
   - Điều phối phiên: mỗi lúc một phiên, chính sách hỏi khi đóng/thoát.
4. **Giao diện + nối app** (`feature/g3-session-ui`, rủi ro cao): view theo exam-taking.md; scene cửa sổ làm bài ở
   StudentShell và AdminShell; bật Luyện tập/Thi/Return/nhấp đúp trên thẻ; Lịch sử thi mở Kết quả; menu **Bài thi**;
   hỏi khi đóng cửa sổ/⌘Q; tạm dừng khi máy ngủ; tên thí sinh và chế độ lần trước bằng `@AppStorage`. Build hai
   app, kiểm ranh giới bundle, mở thử với đề mẫu và đề 2.000 câu.
5. **XCUITest** (`feature/g3-uitest`, rủi ro cao): target UI test cho bản Học viên chạy luồng 1–3 của overview.md
   chỉ bằng bàn phím; kho trong bộ nhớ và thời hạn ngắn qua launch argument chỉ có ở Debug. Chạy trên Mac của
   người điều phối trước khi mở PR, **không** đưa vào CI (Nt0 quyết 2026-10-15); PR ghi lệnh và kết quả.
6. **Người điều phối**: tài liệu (AGENTS.md bản đồ code và bất biến mới, CHANGELOG), cài hai app vào
   /Applications, checklist dùng thử, cổng G2 với nhóm dùng thử, đóng plan. Trước cổng G2, trên SHA `main` đem đi
   cài và dùng thử: `scripts/verify_local.sh --clean --uitest`, ghi SHA và status vào Result. Không chạy workflow
   `CI` ở cổng này (Nt0 quyết 2026-10-16).

## Risks And Recovery

- Đổi khoá JSON hoặc dạng chuẩn dấu vân tay sau khi đã có lần thi thật: lần thi cũ không đọc được hoặc báo sai
  "đã sửa". Golden test và vector cố định; đổi thì tăng `payloadVersion` kèm bước đọc bản cũ.
- Giải mã payload tin dữ liệu sai (id câu không thuộc đề, tổng lệch): kiểm tính nhất quán, lỗi thì chỉ hiện tóm tắt.
- Đồng hồ trên giao diện lệch hoặc treo khi cửa sổ nền: thời gian luôn lấy từ `ExamSession` (mốc `uptime`), tick
  chỉ để vẽ lại; test bằng đồng hồ giả.
- Phím chữ A–Z, ←/→, Return đụng ô nhập chữ hoặc lệnh menu: bảng phím trong exam-taking.md, chỉ bắt khi tiêu điểm
  không ở ô nhập; XCUITest chạy bằng bàn phím.
- Hỏi khi đóng/thoát phải đi qua AppKit (`NSWindowDelegate`, `applicationShouldTerminate`): giữ trong shell,
  model chỉ trả chính sách; test tay ⌘Q, đóng cửa sổ, đóng từ Dock.
- Đề 2.000 câu: bảng câu hỏi dùng lưới lười, ảnh giải mã khi cần; đo khi mở thử ở bước 4.
- Ranh giới hai bản app: `SessionFeature` không phụ thuộc `AuthoringFeature`; `check_boundaries.py` và
  `check_bundle_boundary.sh` trên mỗi PR chạm shell.
- Recovery: mọi thứ trong git; không đổi schema kho (payload là `Data`), nên quay lại bản trước không làm hỏng kho;
  lần thi ghi bởi bản mới vẫn liệt kê được ở bản cũ.

## Progress

- [x] 0 Tài liệu sản phẩm exam-taking.md, plan (#19)
- [x] 1 Lưu lần thi (Codable, AttemptRecord, dấu vân tay câu) (#21, review độc lập APPROVE)
- [x] 2 Đề mẫu "Làm quen" theo phím và nhãn mới (#20)
- [x] 3 Model trình bày SessionFeature (#23, review độc lập lượt 2 APPROVE)
- [x] 4 Giao diện + nối app (#24, review độc lập lượt 2 APPROVE, Nt0 test tay OK)
- [x] 5 XCUITest (chạy trên Mac, không vào CI): chế độ cô lập + đồng hồ nhanh (Debug), target `ExamSuiteUITests`
      (5 test: mở app cô lập, luồng 1–3, hỏi khi đóng cửa sổ), `verify_local.sh --uitest` có so kho thật trước–sau;
      5/5 xanh, kho và defaults thật không đổi; #26, review độc lập APPROVE, N1–N4 đã sửa, `local/verify --uitest` xanh
- [x] 6 Tài liệu (#27), cài app Release `4737ec9` vào /Applications, checklist dùng thử, `verify_local.sh --clean`
      xanh trên `4737ec9`; cổng G2 hoãn (Nt0 quyết 2026-10-16)

## Decisions

- 2026-10-15: Nt0 chốt bốn phương án (exam-taking.md 1–4): ⌘D / ⌘.; đóng/thoát khi chưa nộp thì hỏi rồi bỏ bài;
  xem lại lần thi cũ lấy nội dung từ file đề hiện tại; đề `hideAnswers` hiện đúng/sai, ẩn đáp án.
- 2026-10-15: Payload lần thi là JSON có `payloadVersion` trong cột `payload` sẵn có, không thêm cột SwiftData,
  nên không cần `LibrarySchemaV2`.
- 2026-10-15: Phát hiện "câu đã sửa" bằng dấu vân tay từng câu (không chụp nội dung câu), theo phương án 3.
- 2026-10-15: Tách model trình bày (bước 3, test bằng `swift test`) khỏi view (bước 4), như cách giai đoạn 2 tách
  `LibraryData` khỏi `LibraryFeature`.
- 2026-10-15: Nt0 duyệt phương án 5–11 của exam-taking.md như đã viết.
- 2026-10-15: CI: thêm `swift test` ExamKit vào job `apps-macos` (Nt0 đồng ý); XCUITest không vào CI, chạy trên Mac.
- 2026-10-15 (review #21): dấu vân tay băm ảnh theo đường dẫn, nên giai đoạn 4 không được đổi tên ảnh cũ; bước 3
  lấy dấu vân tay từ đề lúc thi (`session.exam`) và đối chiếu tóm tắt `Attempt` với payload khi đọc lần thi cũ.
- 2026-10-15 (review #23, Nt0 quyết): lần thi cũ không đọc được chi tiết thì không có Làm lại (exam-taking.md
  phương án 12). Xem lại lần cũ, câu đã sửa sau lần thi: hiện nội dung hiện tại + cảnh báo + "Không hiện lựa chọn
  của bạn vì câu đã sửa sau lần thi", không đánh dấu Bạn chọn / Đáp án đúng, giữ Đúng/Sai/Chưa làm lúc thi; bỏ
  quy tắc "Bạn đã chọn một đáp án không còn trong đề" (phương án 13), vì mã lựa chọn đi theo vị trí.
- 2026-10-15 (bước 3, reviewer đồng ý, ghi vào exam-taking.md): bộ lọc Sai không gồm câu chưa làm; phần yếu nhất so
  theo % chia lấy phần nguyên; Theo phần mặc định chọn hết, N mặc định bằng tổng; xem lại lần cũ dùng `hideAnswers`
  của file đề hiện tại; VoiceOver đọc "Phần <tên>" trừ khi tên đã có dạng "Phần <số>…".
- 2026-10-16: Nt0 quyết tiết kiệm phút GitHub Actions (đã dùng 90% tháng 10 sau 77 lần chạy; job macOS tính gấp
  10, ~42 phút tính tiền mỗi lần). Workflow `CI` chỉ chạy tay hoặc khi gắn tag `v*`, dùng ở bước cuối giai đoạn 6;
  bằng chứng merge là commit status `local/verify` do `scripts/verify_local.sh` ghi sau khi chạy đủ các bước của hai
  job trên đúng commit (Linux qua Docker `swift:6.1`).
- 2026-10-16: Ở mỗi cổng (G2 ở đây, G3 cuối giai đoạn 6): `verify_local.sh --clean` + một lần chạy tay workflow `CI`
  trên SHA `main` đem đi dùng thử, để có bằng chứng máy sạch độc lập với Mac của người điều phối. Không cài runner
  tự host (chỉ một người push, agent chạy trên chính Mac này; runner trên Mac không thêm độ độc lập).

- 2026-10-15 (bước 4): SessionFeature phụ thuộc LibraryFeature (dùng `LibraryPalette` cho màu theo phương án 8
  của library.md và nối Thư viện với phiên thi); LibraryFeature không biết SessionFeature: Thư viện gửi lệnh qua
  `LibrarySessionActions`, shell gắn sheet Trước khi thi vào cửa sổ Thư viện qua `LibraryWindow(model:decoration:)`.
- 2026-10-15 (bước 4): cửa sổ làm bài là scene `Window` (một bản, id `session`) ở cả hai bản app, không mở khi
  khởi động, không khôi phục. Hỏi khi đóng bằng delegate chen trước delegate SwiftUI của cửa sổ
  (`WindowCloseGuard`, chuyển tiếp mọi thông điệp khác); thoát app qua `applicationShouldTerminate`
  (`terminateLater` + sheet trên cửa sổ làm bài). Bản Học viên: đóng Thư viện gọi `NSApp.terminate`.
- 2026-10-15 (bước 4): phím không có ⌘/⌃ (←, →, Return, Esc) chỉ gắn vào mục menu Bài thi khi lệnh đang bật
  (cửa sổ làm bài đang dùng, không có ô nhập chữ), để menu không nuốt phím của ô nhập chữ ở cửa sổ khác; A–Z
  và các phím đó cũng bắt bằng `onKeyPress` của màn làm bài. Khi cửa sổ làm bài có sheet/hộp thoại, mọi lệnh
  menu Bài thi tắt và phím không tác dụng lên bài phía sau (review #24).
- 2026-10-15 (Nt0 chốt, exam-taking.md phương án 14–18): Rà soát: Return = Nộp bài; hộp "Còn N câu chưa làm"
  để Quay lại là mặc định. Kết quả: Return = Xem lại bài. Hộp Bỏ bài có dòng phụ "Bỏ bài thì không lưu gì…".
  Đề chưa Sẵn sàng: nhấp đúp/Return không làm gì. Câu đã sửa sau lần thi vẫn hiện giải thích của file hiện tại
  (đề không `hideAnswers`).
- 2026-10-15 (bước 4, ghi chú review #23): (a) tên thí sinh và chế độ chỉ ghi vào cài đặt khi điều phối chắc
  phiên được dùng; (b) vòng chờ đọc file treo trong test có giới hạn; (e) lỗi đọc file của hệ thống thành câu
  tiếng Việt của app. (c) giữ hiện giải thích của file hiện tại cho câu đã sửa, Nt0 chốt (phương án 18);
  (d) bỏ qua.

- 2026-10-16 (bước 5, cô lập UI test): chế độ cô lập chỉ biên dịch ở Debug (`#if DEBUG`,
  `LibraryData/AppLaunchStorage.swift`; bản Release không có ký hiệu nào của nó, kiểm bằng `nm`). Bật bằng
  `-ExamSuiteUITest <thư mục>`: kho SwiftData + đề mẫu trong `<thư mục>/Application Support/<bundle ID>/`, mọi cài
  đặt nhỏ (cờ đề mẫu, `@AppStorage` của Thư viện qua `.defaultAppStorage`, tên thí sinh, chế độ lần trước) trong
  `UserDefaults(suiteName: <thư mục>/Preferences/defaults)` (suite là đường dẫn tuyệt đối nên ghi vào plist trong thư
  mục tạm). Rào chắn: thư mục phải tuyệt đối, có sẵn và có file đánh dấu `.examsuite-uitest` do test tạo; sai thì
  app dừng ngay (không rơi về kho thật). AppKit tự ghi vị trí cửa sổ/thanh chia vào `UserDefaults.standard` của
  bundle ID đang chạy và không đổi hướng được (đã thử `CFFIXED_USER_HOME`: đổi thư mục nhà nhưng không đổi
  `defaults`), nên UI test build bản Học viên với `EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest` (bundle ID
  thật thêm đuôi `.uitest`, `build/DerivedData-UITest`) và app ở chế độ cô lập từ chối chạy dưới bundle ID thật.
  Trình chạy test bị sandbox, nên thư mục tạm nằm ở `/private/tmp/ExamSuiteUITests-<uuid>` (entitlement ghi riêng
  `/private/tmp/`), tránh để app đọc container của app khác. Mỗi test tạo và xoá thư mục của mình.
- 2026-10-16 (bước 5, rút ngắn thời gian): `-ExamSuiteUITestTimeScale <hệ số>` (chỉ cùng chế độ cô lập) làm
  `SessionEnvironment.live` dùng `ScaledSessionClock` (Debug): `uptime` của `SystemSessionClock` nhân hệ số, `now`
  giữ giờ thật. Không sửa ExamKit; bản Release luôn `SystemSessionClock`. UI test dùng hệ số 5 (thi 6 phút = 72
  giây thật; cảnh báo 5 phút sau ~12 giây, 1 phút sau ~60 giây).
- 2026-10-16 (bước 5, phát hiện): Điều hướng bàn phím (Full Keyboard Access) của macOS đang tắt trên máy chạy test
  và app không bật riêng được (AppKit chỉ đọc miền chung; `-AppleKeyboardUIMode 2` và defaults riêng của app không
  có tác dụng). Khi tắt, Tab chỉ qua ô nhập chữ và danh sách, nên các bước không có phím tắt (chọn Thi và N câu
  ngẫu nhiên trong Trước khi thi, Nộp bài trong hộp "Còn N câu chưa làm", Xem câu sai, Kết quả trên Xem lại bài,
  Làm lại, Bỏ bài) UI test dùng chuột và ghi `needsFullKeyboardAccess`. **Chờ Nt0 quyết**: bật Điều hướng bàn phím
  trên máy chạy UI test (rồi đổi các bước đó sang Tab/Space), hay thêm phím tắt cho các nút đó (quyết định sản phẩm,
  exam-taking.md).
- 2026-10-16: Nt0 chốt: "hoàn toàn bằng bàn phím" giả định bật Full Keyboard Access (exam-taking.md phương án 19),
  không thêm phím tắt. UI test bấm chuột ở các bước cần Tab tới nút khi máy test tắt FKA (ghi `needsFullKeyboardAccess`
  trong log); chuyển sang Tab/Space khi máy test bật FKA là việc sau.
- 2026-10-16: `verify_local.sh --uitest` chạy lại một lần test UI thất bại (`-retry-tests-on-failure -test-iterations 2`)
  vì XCUITest đôi khi hết giờ tổng hợp sự kiện ở test đầu sau build; status ghi rõ nếu có chạy lại.
- 2026-10-16 (thay quyết định cùng ngày ở trên): Nt0 bỏ lần chạy CI ở cổng G2. Workflow `CI` chỉ chạy khi Nt0
  báo, dự kiến một lần cho bản beta giai đoạn 6. Cổng G2 dùng `verify_local.sh --clean --uitest`.
- 2026-10-16: Nt0 yêu cầu Soạn đề (giai đoạn 4) có import đề từ các định dạng phổ biến; ghi vào plan-macos-v1.md,
  định dạng cụ thể chốt khi lập plan giai đoạn 4.

## Validation

- Focused proof: `swift test --package-path Packages/ExamKit` (Codable, AttemptRecord, dấu vân tay; Linux và
  macOS, cả hai trong `verify_local.sh`); `swift test --package-path Packages/ExamFeatures` (`SessionFeatureTests`, test đề mẫu).
- Integration: `scripts/check.sh`; `xcodebuild` hai scheme; `scripts/check_bundle_boundary.sh`; XCUITest luồng 1–3
  (`scripts/verify_local.sh --uitest`, bắt buộc ở PR chạm giao diện và ở cổng G2);
  mở thử hai app với đề mẫu, đề `hideAnswers`, đề 2.000 câu, lần thi cũ sau khi sửa/xoá câu trong đề.
- Repository-required checks: từ 2026-10-16 là commit status `local/verify` (`scripts/verify_local.sh`) xanh trên SHA cuối
  của từng PR (trước đó: CI hai job); PR rủi ro cao có review độc lập.
- Cần người test tay: VoiceOver (đổi câu, cảnh báo giờ, hết giờ, Kiểm tra đáp án, kết quả), Dark Mode, toàn màn
  hình, máy ngủ rồi thức khi đang thi, ⌘Q và đóng cửa sổ khi chưa nộp, cổng G2 với nhóm dùng thử.

## Cổng G2: dùng thử

Điều kiện qua cổng (plan-macos-v1.md): nhóm dùng thử làm trọn **đề thật** của người dùng thử, không gặp lỗi chặn.

Chuẩn bị (người điều phối):

- `scripts/verify_local.sh --clean --uitest` xanh trên SHA `main` đem đi cài; ghi vào Result.
- Build Release hai app, cài vào /Applications của máy dùng thử (bản Học viên cho mọi người, bản Admin chỉ máy admin).
  App ký ad-hoc: lần đầu mở macOS chặn, vào System Settings → Privacy & Security → Open Anyway.
- Ít nhất một **đề thật** dạng `.exam`: chưa có Soạn đề (giai đoạn 4), nên chuyển bộ câu hỏi có sẵn của người dùng thử thành
  `exam.json` theo `schema/exam-v1.schema.json`, kiểm bằng `scripts/validate_exam.py`, đóng gói bằng
  `scripts/pack_exam.py`; người có chuyên môn duyệt nội dung và đáp án trước khi phát.

Việc của mỗi người dùng thử (bản Học viên):

1. Mở app, thấy hai đề mẫu; đóng dải chào mừng.
2. Thêm đề thật: nút Thêm đề (⌘O), kéo thả, hoặc nhấp đúp file trong Finder.
3. **Luyện tập** đề thật hết các câu: chọn đáp án, Kiểm tra đáp án (⌘K), đánh dấu (⌘D), Rà soát & nộp (⌘Return),
   Kết quả, Xem lại bài, Luyện lại câu sai.
4. **Thi** đề thật có tính giờ (hoặc N câu ngẫu nhiên): tạm dừng (⌘.), để cảnh báo 5 phút / 1 phút hiện, nộp bài,
   xem Kết quả và so với lần trước.
5. Mở Lịch sử thi, mở lại Kết quả của một lần thi.
6. Thử đóng cửa sổ làm bài khi chưa nộp (app phải hỏi).
7. Ghi lại: lỗi gặp phải (bước, điều thấy, điều mong đợi, ảnh chụp nếu được), chỗ khó hiểu, câu hỏi/đáp án sai nội dung.

Phân loại lỗi:

- **Chặn**: app crash, mất bài đang làm hoặc kết quả, chấm sai, không làm hết được đề, không mở được đề hợp lệ.
  Có lỗi chặn thì chưa qua cổng; sửa rồi dùng thử lại phần liên quan.
- **Thường**: sai chữ, bố cục, khó dùng, thiếu phím tắt: ghi lại, sửa ở giai đoạn sau, không chặn cổng.

## Result

Tạm đóng 2026-10-16 theo quyết định của Nt0: phần làm bài xong và cài lên máy, **cổng G2 chưa chạy**. Nt0 sẽ cho
nhóm dùng thử sau khi có Soạn đề (giai đoạn 4), để nhóm tự soạn hoặc import đề thật rồi làm bài. Checklist "Cổng G2:
dùng thử" ở trên vẫn dùng cho lần đó; plan giai đoạn 4 mang việc này theo.

- **Merge vào `main`:** #19 (kế hoạch), #20 (đề mẫu Làm quen), #21 (lưu lần thi), #22 (chốt phương án, CI), #23 (model
  SessionFeature), #24 (giao diện, nối hai app), #25 (CI tiết kiệm, `verify_local.sh`), #26 (XCUITest, chế độ cô lập),
  #27 (tài liệu bước 6). Mọi PR rủi ro cao có review độc lập bằng phiên agent mới: #21 một lượt, #23 hai lượt, #24 hai
  lượt, #26 một lượt kèm sửa N1–N4; tóm tắt đăng trong PR.
- **Quyết định sản phẩm:** exam-taking.md phương án 1–19 (Nt0 chốt 2026-10-15/16).
- **Số test lúc đóng:** ExamKit 197 + ExamFile 121 (macOS và Linux), LibraryData 91, SessionFeature 111, LibraryFeature
  48, XCUITest 5 (luồng 1–3, đóng cửa sổ khi chưa nộp, mở app cô lập).
- **Bằng chứng cuối:** `local/verify` trên `ea90987`/`5eb0791` có UI test 5/5, kho thật không đổi; `local/verify --clean`
  trên `4737ec9` (SHA cài). Release hai app ký ad-hoc, `codesign --verify` ok, không có code cô lập của test (`nm`),
  kiểm bundle: Học viên 0, Admin 199 ký hiệu AuthoringFeature. Cài vào /Applications 2026-10-16, bản cũ sao lưu.
- **Nt0 test tay OK** bản #24 theo checklist trong PR (gồm phương án 14).
- **Quy trình đổi:** CI GitHub không tự chạy (tháng 10 đã dùng 90% phút Actions); bằng chứng merge là `local/verify`;
  CI chạy một lần khi Nt0 báo cho bản beta giai đoạn 6.
- **Sự cố:** agent lái bản Debug ghi một lần thi giả "Agent Test" vào kho thật của Nt0 (2026-10-15); đã xoá có sao
  lưu theo yêu cầu. Từ đó agent chỉ lái app qua XCUITest ở chế độ cô lập; `verify_local --uitest` so kho thật trước–sau.

Chuyển sang sau:

- **Cổng G2** (giai đoạn 4 hoặc ngay sau): dùng thử theo checklist trên, cả làm bài lẫn soạn đề.
- **Import đề** từ định dạng phổ biến: yêu cầu của Nt0 cho giai đoạn 4, danh sách định dạng chốt khi lập plan.
- Chế độ cô lập chưa nối vào AdminShell (cần khi viết XCUITest cho Soạn đề).
- UI test bấm chuột ở các bước cần Điều hướng bàn phím (phương án 19); chuyển sang Tab/Space khi máy test bật FKA.
- Ghi chú review chưa làm: so trước–sau chỉ `stat` thư mục Samples; `typeCandidateName` kiểm tiêu điểm không chờ;
  chưa test gõ phím ở Rà soát khoá; hai ghi chú nhỏ về `WindowCloseGuard` (#24 lượt 2).
- Từ giai đoạn 2: thời hạn đọc cho Thêm đề / Tìm file…; đề mẫu ATTT01 lệch độ dài đáp án; String Catalog (giai đoạn 5).

