# Làm bài

Thẩm quyền: tài liệu này. Nguồn: mục "Thiết kế UX trên macOS" và sơ đồ phiên thi của
[plan-macos-v1.md](plan-macos-v1.md); DESIGN_BRIEF §5.2–5.6, §6, §7 của Open Exam Suite (đọc qua link,
không chép). Quy tắc của phiên (trạng thái, lệnh, đồng hồ) ở [exam-session.md](exam-session.md); chấm điểm
và chọn câu ở [scoring.md](scoring.md). Những chỗ đặc tả gốc không nói được ghi ở mục cuối.

Code: `SessionFeature` trong `Packages/ExamFeatures` (giao diện macOS), model trình bày có test ở `SessionModel` trong
`Packages/SharedFeatures` (dùng chung với bản iOS); lần thi lưu qua `LibraryData`. Cả hai bản app dùng chung, không khác nhau ở phần này.

## Bắt đầu

- Mở màn **Trước khi thi** từ thẻ đề: nút **Luyện tập**, **Thi**, menu chuột phải, nhấp đúp hoặc Return
  (chọn sẵn chế độ dùng lần trước, lần đầu là Luyện tập).
- Chỉ bật khi đề ở trạng thái **Sẵn sàng** (đọc nghiêm được) ở cả hai bản app. Đề có lỗi ở bản Admin
  phải sửa trước khi làm bài. Đề chưa Sẵn sàng thì nhấp đúp hoặc Return trên thẻ không làm gì, giống nút tắt
  (phương án 17).
- Lúc bấm **Bắt đầu**, app đọc lại file đề (nghiêm). Đọc không được thì không tạo phiên, báo lý do và
  cập nhật trạng thái thẻ như Làm mới trạng thái của library.md.

## Trước khi thi

`.sheet` trên cửa sổ Thư viện, dạng `Form`.

- Đầu sheet: tiêu đề, mã đề, hướng dẫn của đề (`instructions`, Markdown cơ bản) nếu có.
- **Chế độ**: Luyện tập / Thi (segmented). Đề có `hideAnswers` thì Luyện tập tắt kèm lý do
  "Đề này ẩn đáp án nên không luyện tập được".
- **Tên thí sinh**: điền sẵn tên dùng lần trước (`@AppStorage`, chung cho mọi đề); là chữ thật, không
  phải placeholder. Bỏ khoảng trắng hai đầu; để trống thì Bắt đầu bị khoá.
- **Câu hỏi**:
  - **Tất cả câu**;
  - **Theo phần**: danh sách section có ô chọn và số câu từng phần, nút Chọn hết / Bỏ chọn; mở sheet thì
    mọi phần đều được chọn;
  - **N câu ngẫu nhiên**: `Stepper` + ô số, 1…tổng số câu; mặc định N bằng tổng số câu.
- **Xáo thứ tự câu**, **Xáo thứ tự đáp án** (mặc định tắt).
- **Thời gian** (chỉ Thi): mặc định `timeLimitMinutes` của đề, đổi được 1–600 phút.
- **Dòng tóm tắt** cập nhật theo lựa chọn: "60 câu · 90 phút · đậu 70%" (Luyện tập: "60 câu · không giới
  hạn giờ · đậu 70%").
- Lựa chọn ra 0 câu hoặc giá trị ngoài khoảng: **Bắt đầu** bị khoá, lý do hiện ngay dưới dòng tóm tắt;
  không có hộp thoại lỗi sau khi bấm.
- Nút **Bắt đầu** (Return, mặc định) và **Huỷ** (Esc).
- Lựa chọn của sheet (chế độ, cách chọn câu, xáo, thời gian) **không** nhớ giữa các đề; chỉ nhớ tên thí sinh
  và chế độ dùng lần trước. Riêng **Làm lại** mở sheet với đúng lựa chọn của lần vừa làm.
- Seed mới cho mỗi lần Bắt đầu (ngẫu nhiên của hệ thống), lưu vào lần thi.

## Cửa sổ làm bài

- Bắt đầu mở **một cửa sổ làm bài riêng** (cho phép toàn màn hình, tối thiểu 960×640); sheet đóng, cửa sổ
  Thư viện vẫn còn. Tiêu đề cửa sổ: tên đề, chế độ.
- **Mỗi lúc chỉ một phiên.** Đang có phiên chưa nộp mà bấm Luyện tập/Thi đề khác thì đưa cửa sổ đang làm
  lên trước và báo "Đang có bài chưa nộp".
- Rà soát, Kết quả và Xem lại diễn ra trong cùng cửa sổ này.

### Câu hỏi

- Đầu: tên phần, "Câu 3/60", biểu tượng đánh dấu nếu câu đã đánh dấu.
- Nội dung câu (Markdown cơ bản), ảnh nếu có (vừa khung, bấm để phóng to trong sheet; Esc đóng).
- Lựa chọn theo thứ tự hiển thị của phiên (đã xáo nếu bật), nhãn A, B, C… theo **vị trí hiển thị**, không
  theo id gốc. `single` là hàng chọn một (radio), `multiple` là ô đánh dấu kèm gợi ý "Chọn N đáp án" (N = số đáp án đúng của câu, như đặc tả gốc).
  Hàng rộng hết khung, chữ dài xuống dòng, bấm vào chỗ nào của hàng cũng được.
- Phím chữ A–Z chọn/bỏ chọn lựa chọn ở vị trí đó; chữ vượt số lựa chọn thì bỏ qua.

### Bảng câu hỏi

- `.inspector` bên phải, ẩn/hiện được (⌃⌘I theo chuẩn macOS), nhóm theo phần.
- Mỗi ô một số thứ tự; trạng thái **Đã làm / Chưa làm / Đánh dấu / Đang xem** luôn có biểu tượng hoặc hình
  dạng khác nhau, không chỉ dựa vào màu. Bấm ô để tới câu đó.
- Thanh tiến độ: "Đã làm 12/60" (chỉ đếm câu có đáp án).

### Thanh công cụ và thanh dưới

- Thanh công cụ: đồng hồ, **Tạm dừng**, ẩn/hiện bảng câu hỏi.
- Đồng hồ ở Thi đếm ngược, dạng `mm:ss` (từ 60 phút trở lên là `h:mm:ss`); ba mức **bình thường**,
  **sắp hết** (≤ 5 phút) và **gấp** (≤ 1 phút), mỗi mức đổi biểu tượng kèm màu.
  Luyện tập hiện thời gian đã làm, không đếm ngược.
- Thanh dưới: **Câu trước**, **Câu sau**, **Đánh dấu**, **Rà soát & nộp**; Luyện tập thêm **Kiểm tra đáp án**.

### Kiểm tra đáp án (chỉ Luyện tập)

- Bật khi câu hiện tại có đáp án và chưa kiểm tra.
- Sau khi bấm: từng lựa chọn hiện **Đúng** (lựa chọn đúng) hoặc **Sai** (lựa chọn đã chọn nhưng sai) bằng
  biểu tượng + chữ; dòng kết quả "Đúng" / "Chưa đúng"; khung giải thích nếu đề có. Đáp án câu đó bị khoá
  (exam-session.md). VoiceOver đọc kết quả.

### Tạm dừng

- **Tạm dừng** (nút hoặc ⌘.): lớp phủ che **toàn bộ** nội dung câu và lựa chọn, bảng câu hỏi cũng chỉ
  hiện số ô; nút **Tiếp tục** (Return hoặc ⌘.). Đồng hồ dừng.
- Máy sắp ngủ: tự tạm dừng (`systemSleep`), lớp phủ ghi "Đã tạm dừng vì máy ngủ". Thức dậy vẫn ở tạm dừng.
- App mất tiêu điểm hay thu nhỏ cửa sổ **không** tự tạm dừng.
- Tạm dừng được ở Rà soát chưa khoá, như exam-session.md.

### Cảnh báo và hết giờ

- Còn 5 phút và 1 phút: dải thông báo không chặn trên đầu câu ("Còn 5 phút"), tự ẩn sau vài giây; VoiceOver
  đọc ngay (thông báo ưu tiên cao).
- Hết giờ: chuyển **ngay** sang Rà soát khoá với dải "Đã hết giờ. Xem lại rồi bấm Nộp bài"; VoiceOver đọc.
  Không tự nộp.

## Rà soát & nộp

Mở bằng nút hoặc ⌘Return.

- Ba số: **Đã làm**, **Chưa làm**, **Đánh dấu**.
- Hai danh sách nút số câu: câu chưa làm, câu đã đánh dấu. Bấm một câu thì quay lại làm bài tại câu đó
  (không có khi rà soát khoá).
- Toàn bộ bảng câu hỏi để tham khảo.
- Nút **Quay lại làm bài** (Esc; không có khi rà soát khoá) và **Nộp bài** (nút chính, Return).
- Nộp khi còn câu chưa làm: `.confirmationDialog` "Còn 6 câu chưa làm. Vẫn nộp?" với **Nộp bài** / **Quay lại**;
  **Quay lại** là mặc định (Return và Esc đều là Quay lại), phải chủ động bấm **Nộp bài** (phương án 14).
  Không còn câu chưa làm thì nộp luôn, không hỏi.
- Trong lúc có hộp thoại hay sheet trên cửa sổ làm bài (xác nhận nộp, hỏi Bỏ bài, ảnh phóng to), phím và lệnh
  menu **Bài thi** không tác dụng lên bài phía sau.
- Đồng hồ vẫn chạy khi rà soát chưa khoá (exam-session.md).

## Đóng cửa sổ hoặc thoát app khi chưa nộp

- Đóng cửa sổ làm bài hoặc thoát app (⌘Q) khi phiên chưa nộp: hỏi "Bài chưa nộp sẽ mất. Bỏ bài?" kèm dòng phụ
  "Bỏ bài thì không lưu gì và lần này không có trong Lịch sử thi." (phương án 16), với **Tiếp tục làm** (mặc
  định) / **Bỏ bài**. Ở Thi, đồng hồ vẫn chạy trong lúc hộp thoại hiện. Mỗi lúc chỉ một hộp hỏi: đang hỏi mà
  đóng/thoát lần nữa thì không hiện hộp thứ hai.
- Thoát app gồm ⌘Q, Thoát từ Dock, đăng xuất, khởi động lại, tắt máy: cùng lời hỏi. Sheet đang mở (Trước khi thi, ảnh
  phóng to…) không chặn thoát: sheet đóng theo (lựa chọn đang điền ở Trước khi thi không giữ). Chọn **Tiếp tục làm** khi
  đăng xuất/tắt máy thì macOS huỷ đăng xuất/tắt máy (macOS báo app đã huỷ), bài giữ nguyên.
- Hộp hỏi hai nút hay có nút huỷ hoại đang mở ("Còn N câu chưa làm. Vẫn nộp?", "Bài chưa nộp sẽ mất. Bỏ bài?") thì
  **chặn thoát** như mặc định của macOS (Nt0 chốt 2026-10-17): ⌘Q và Thoát từ Dock không tác dụng, đăng xuất/tắt máy bị
  huỷ; trả lời hộp hỏi trước rồi mới thoát được.
- Bỏ bài: không lưu gì, không có trong lịch sử thi. Không lưu phiên dở để làm tiếp.
- App bị tắt đột ngột (crash, mất điện) khi đang làm: bài mất, không hỏi gì khi mở lại.
- Đã nộp thì đóng cửa sổ không hỏi (lần thi đã lưu).

## Kết quả

Hiện ngay sau khi nộp, trong cửa sổ làm bài. Lần thi **tự lưu** vào Lịch sử thi lúc nộp (cả Luyện tập và
Thi, kể cả phiên Luyện lại câu sai). Lưu không được thì báo lỗi trên màn Kết quả; kết quả vẫn xem được
tới khi đóng cửa sổ.

- Dòng chính lớn: **Đậu** / **Trượt** bằng biểu tượng + chữ (cùng chữ với Lịch sử thi).
- Điểm: phần trăm và thang 1000 ("72% · 720/1000"); một thanh tiến độ có vạch ngưỡng đậu.
- Thông tin: thí sinh, mã đề, chế độ, ngày giờ nộp, thời gian làm / thời gian cho phép (Thi), số câu đúng/tổng.
- **So với lần trước**: lần thi trước đó của cùng đề, **cùng chế độ** (+8% / −5% / bằng). Không có lần trước
  thì không hiện dòng này.
- **Theo phần**: mỗi section một dòng (thanh, đúng/tổng, %). Section 0/0 hiện "Không có câu" và không có
  thanh. Đánh dấu **phần yếu nhất** (% thấp nhất trong các phần có câu; bằng nhau thì phần đứng trước) khi có
  từ hai phần có câu trở lên. % so sánh là % hiển thị (chia lấy phần nguyên, scoring.md), nên 1/3 và 33/100
  cùng là 33% và tính là bằng nhau.
- Nút: **Xem lại bài** (chính, Return; phương án 15), **Làm lại**, **Về thư viện** (đóng cửa sổ làm bài, đưa
  Thư viện lên trước).
  **Xuất PDF…** và **In…** (cả lần mở từ Lịch sử thi; menu Tệp, In… ⌘P): [export-print.md](export-print.md).
- **Làm lại**: mở Trước khi thi trên cửa sổ Thư viện với đúng lựa chọn của lần vừa làm (seed mới khi Bắt đầu).

## Xem lại bài

`NavigationSplitView` trong cửa sổ làm bài.

- Trái: danh sách câu theo thứ tự phiên, bộ lọc **Tất cả / Sai / Chưa làm / Đã đánh dấu / Đúng** kèm số
  lượng. Mỗi dòng có biểu tượng + chữ trạng thái. **Sai** chỉ gồm câu đã trả lời nhưng sai; câu chưa làm
  có bộ lọc **Chưa làm** riêng (Đúng, Sai, Chưa làm chia hết các câu; Đã đánh dấu cắt ngang).
- Phải: câu, ảnh, mọi lựa chọn theo thứ tự đã hiện lúc làm; đánh dấu **Bạn chọn**, **Đáp án đúng**
  bằng biểu tượng + chữ; giải thích nếu có.
- Câu trước / sau (← / →) đi trong bộ lọc đang chọn.
- Mở từ Kết quả: bộ lọc Tất cả. **Xem câu sai** trên Kết quả mở bộ lọc Sai (không gồm câu chưa làm).
- **Luyện lại câu sai**: phiên Luyện tập mới gồm đúng các câu sai và chưa làm, theo thứ tự phiên, không xáo
  (`practiceIncorrectOptions`). Mở Trước khi thi đã chọn sẵn Luyện tập và danh sách câu đó (chỉ đổi được tên
  thí sinh). Không có khi không còn câu sai hoặc đề có `hideAnswers`.

### Đề ẩn đáp án (`hideAnswers`)

- Kết quả hiện đủ (điểm, theo phần).
- Xem lại: hiện câu, lựa chọn của người làm và **Đúng / Sai / Chưa làm** của từng câu (bộ lọc dùng được).
  **Không** hiện đáp án đúng và giải thích.

## Lịch sử thi

Bổ sung cho mục Lịch sử thi của library.md.

- Chọn một lần thi (nhấp đúp hoặc Return) mở **Kết quả** của lần đó trong cửa sổ làm bài (không có nút Làm
  lại nếu đề không còn trong thư viện, hoặc không đọc được chi tiết lần thi vì không biết lựa chọn của lần đó;
  phương án 12).
- Điểm, đúng/tổng và theo phần lấy từ dữ liệu lần thi, luôn xem được kể cả khi đề đã xoá khỏi thư viện
  hoặc mất file.
- **Xem lại bài** của lần cũ lấy nội dung câu từ **file đề hiện tại** (cùng id đề, có trong thư viện, đọc
  nghiêm được). Không có file thì nút tắt kèm lý do.
  - Câu không còn trong đề: dòng "Câu này đã bị xoá khỏi đề" thay cho nội dung.
  - Câu đã sửa sau lần thi (loại câu, nội dung, ảnh (theo đường dẫn), lựa chọn, đáp án đúng hoặc giải thích khác lúc thi): hiện nội dung và lựa chọn
    **hiện tại** (thứ tự trong file), dải cảnh báo "Câu này đã được sửa sau lần thi" và dòng "Không hiện lựa
    chọn của bạn vì câu đã sửa sau lần thi"; **không** đánh dấu **Bạn chọn** / **Đáp án đúng** trên lựa chọn
    (mã lựa chọn đi theo vị trí nên đáp án lúc thi có thể trỏ nhầm sang lựa chọn khác); Đúng/Sai/Chưa làm vẫn
    là kết quả lúc thi (phương án 13). Giải thích của **file đề hiện tại** vẫn hiện khi đề không `hideAnswers`
    (phương án 18).
  - Câu không đổi: như Xem lại bài của lần vừa nộp.
  - Ẩn hay hiện đáp án đúng và giải thích theo `hideAnswers` của **file đề hiện tại** (payload không ghi
    giá trị lúc thi).
- **Luyện lại câu sai** từ lần cũ: chỉ lấy các câu còn trong đề.

## Dữ liệu một lần thi

Các trường tóm tắt đã có trong `Attempt` (library.md). `payload` là JSON có `payloadVersion`, gồm:

- tuỳ chọn tạo đề (`CompositionOptions`, có seed) và thời gian cho phép (Thi);
- thứ tự câu và thứ tự hiển thị lựa chọn của phiên (`ExamPaper`);
- đáp án theo id câu và id lựa chọn gốc; câu đã đánh dấu; câu đã Kiểm tra đáp án;
- kết quả chấm (`ScoreResult`: theo phần, kết quả từng câu);
- **dấu vân tay từng câu** lúc thi (SHA-256 nội dung câu ở dạng chuẩn), để Xem lại biết câu nào đã sửa.

Đọc payload không được (hỏng, `payloadVersion` mới hơn app): tóm tắt vẫn hiện, Kết quả chi tiết và Xem lại
tắt kèm lý do "Không đọc được chi tiết lần thi này".

Code: `AttemptRecord` (ExamKit) tạo từ phiên đã nộp, mã hoá/giải mã payload (khoá JSON cố định, seed ghi thành
chuỗi thập phân để giữ đủ 64 bit; đọc thì kiểm `payloadVersion` trước, rồi kiểm nhất quán giữa đề đã tạo, đáp
án, kết quả và dấu vân tay). Dấu vân tay: `QuestionFingerprint` (ExamFile), dạng chuẩn gồm loại câu, nội dung,
ảnh, lựa chọn theo thứ tự file, tập đáp án đúng, giải thích; chuỗi NFC; không gồm id câu. Đổi khoá JSON hoặc dạng
chuẩn phải tăng `payloadVersion` kèm bước đọc bản cũ (test JSON mẫu và vector cố định chặn đổi vô tình).

## Bàn phím và trợ năng

| Hành động | Phím |
| --- | --- |
| Chọn đáp án theo vị trí | A–Z |
| Câu trước / sau | ← / → |
| Câu tiếp theo | Return |
| Đánh dấu | ⌘D |
| Tạm dừng / tiếp tục | ⌘. |
| Kiểm tra đáp án (Luyện tập) | ⌘K |
| Rà soát & nộp | ⌘Return |
| Ẩn/hiện bảng câu hỏi | ⌃⌘I |
| Quay lại làm bài (Rà soát chưa khoá) | Esc |

- Phím chữ, ←/→ và Return chỉ tác dụng khi tiêu điểm không nằm trong ô nhập chữ.
- Mọi lệnh có trong menu **Bài thi** của cửa sổ làm bài kèm phím tắt, tắt khi không hợp lệ ở trạng thái hiện tại.
- VoiceOver: mọi điều khiển có nhãn; đọc khi đổi câu ("Câu 3 trên 60, Phần Mạng": "Phần" + tên phần, trừ khi
  tên đã có dạng "Phần <số>…" như "Phần 2: Mạng" thì đọc nguyên tên), khi có cảnh báo
  giờ, hết giờ, kết quả Kiểm tra đáp án và kết quả nộp bài. Mỗi ô bảng câu hỏi đọc số câu + trạng thái.
- Đúng/sai/đánh dấu/cảnh báo luôn có biểu tượng + chữ. Tôn trọng Reduce Motion. Tương phản theo phương án 8
  của library.md.
- Bố cục giữ được ở 960×640 với câu dài, 8+ lựa chọn, ảnh lớn; chuỗi tiếng Việt qua `LocalizedStringKey`
  để giai đoạn 5 đưa vào String Catalog.

## Phương án đã chốt (Nt0 duyệt 2026-10-15)

1. **Phím Đánh dấu / Tạm dừng:** ⌘D / ⌘. (thay F / P). Đề mẫu "Làm quen" câu 7 và ảnh phím tắt sửa theo.
2. **Đóng cửa sổ hoặc thoát khi chưa nộp:** hỏi rồi bỏ bài; không lưu phiên dở.
3. **Xem lại lần thi cũ:** nội dung câu lấy từ file đề hiện tại; câu đã xoá thì báo, câu đã sửa thì cảnh báo.
4. **Đề `hideAnswers`:** Xem lại hiện đúng/sai từng câu, ẩn đáp án đúng và giải thích.
5. **Chỉ đề Sẵn sàng mới làm bài được**, ở cả bản Admin (đề Có lỗi phải sửa trước).
6. **Mỗi lúc một phiên**; bấm làm đề khác khi đang có bài thì đưa cửa sổ đang làm lên trước.
7. **Tên thí sinh bắt buộc**, nhớ tên lần trước chung cho mọi đề.
8. **So với lần trước:** lần trước của cùng đề và cùng chế độ.
9. **Kiểm tra đáp án** có phím ⌘K; **Ẩn/hiện bảng câu hỏi** ⌃⌘I.
10. **Hết giờ chuyển ngay** sang Rà soát khoá (không có màn Hết giờ riêng), dải thông báo trên đầu.
11. **App mất tiêu điểm không tự tạm dừng**; chỉ máy ngủ mới tự tạm dừng.
12. **Lần thi cũ không đọc được chi tiết** (payload hỏng, mới hơn app hoặc lệch tóm tắt): không có **Làm lại**
    (không biết lựa chọn của lần đó), cùng với chi tiết và Xem lại bị tắt.
13. **Câu đã sửa sau lần thi** khi xem lại lần cũ: hiện nội dung hiện tại kèm cảnh báo "Câu này đã được sửa
    sau lần thi" và dòng "Không hiện lựa chọn của bạn vì câu đã sửa sau lần thi"; không đánh dấu Bạn chọn /
    Đáp án đúng; Đúng/Sai/Chưa làm lúc thi giữ nguyên. Thay cho quy tắc "Bạn đã chọn một đáp án không còn
    trong đề".
14. **Rà soát & nộp:** Return là **Nộp bài** (nút chính). Hộp "Còn N câu chưa làm. Vẫn nộp?" để **Quay lại** là
    mặc định (Return và Esc đều là Quay lại), người dùng phải chủ động bấm **Nộp bài**. Không còn câu chưa làm
    thì nộp luôn (Nt0 chốt 2026-10-15).
15. **Kết quả:** Return là **Xem lại bài** (nút chính) (Nt0 chốt 2026-10-15).
16. **Hộp hỏi Bỏ bài** có dòng phụ "Bỏ bài thì không lưu gì và lần này không có trong Lịch sử thi."
    (Nt0 chốt 2026-10-15).
17. **Đề chưa Sẵn sàng:** nhấp đúp hoặc Return trên thẻ không làm gì, giống nút Luyện tập/Thi đang tắt; không mở
    Thông tin như giai đoạn 2 (Nt0 chốt 2026-10-15; library.md mục Thẻ đề).
18. **Bổ sung phương án 13:** câu đã sửa sau lần thi vẫn hiện lời giải thích của file đề hiện tại khi đề không
    `hideAnswers` (Nt0 chốt 2026-10-15).
19. **"Hoàn toàn bằng bàn phím" giả định bật Điều hướng bàn phím của macOS** (Full Keyboard Access, System
    Settings → Keyboard), như mọi app macOS: khi bật, Tab tới được mọi nút và điều khiển (chọn Thi, N câu ngẫu
    nhiên, Nộp bài trong hộp xác nhận, Xem câu sai, Kết quả, Làm lại, Bỏ bài). Không thêm phím tắt riêng cho các
    nút đó. App không tự bật được Điều hướng bàn phím (Nt0 chốt 2026-10-16).
