# Xuất PDF và In

Thẩm quyền: tài liệu này (giai đoạn 5). Nguồn: mục "Mục tiêu và phạm vi v1" (xuất PDF và in kết quả; Admin xuất PDF
đề) và "Kiến trúc kỹ thuật" (Báo cáo) của [plan-macos-v1.md](plan-macos-v1.md). Quy tắc hiển thị kết quả và xem lại
lấy nguyên từ [exam-taking.md](exam-taking.md); đề và Markdown theo [exam-format.md](exam-format.md); chấm điểm theo
[scoring.md](scoring.md). Các phương án Nt0 đã chốt (2026-10-16, 2026-10-17) ghi ở mục cuối; số phương án trong bài dẫn tới đó.

Nguyên tắc chung: PDF và bản in là **ảnh chụp đúng những gì màn hình được phép hiện**. Không có quy tắc ẩn/hiện riêng
cho giấy: cái gì Kết quả/Xem lại không hiện (đáp án đúng của đề `hideAnswers`, đánh dấu trên câu đã sửa sau lần thi)
thì PDF cũng không có.

## Bản Học viên (và bản Admin): PDF kết quả

### Mở từ đâu

- Màn **Kết quả** trong cửa sổ làm bài (sau khi nộp, hoặc mở từ Lịch sử thi): nút **Xuất PDF…** và **In…** ở thanh
  nút dưới (phương án 6).
- Menu **Tệp**: **Xuất PDF…** và **In…** (⌘P), bật khi cửa sổ làm bài đang ở Kết quả hoặc Xem lại bài; tắt khi đang
  làm bài, Rà soát hoặc có hộp thoại/sheet trên cửa sổ (như menu Bài thi, exam-taking.md).
- Cả hai bản app có tính năng này (SessionFeature dùng chung).

### Hộp chọn trước khi xuất

Sheet nhỏ trên cửa sổ làm bài, dùng chung cho Xuất PDF và In:

- **Phần xem lại bài** (phương án 3): **Không** / **Câu sai và chưa làm** / **Tất cả câu**. Nhớ lựa chọn lần trước
  (`@AppStorage`, chung mọi đề).
- Lựa chọn bị tắt kèm lý do khi Xem lại bài không mở được (đề không còn trong thư viện, mất file, đọc không được, chi
  tiết lần thi không đọc được: cùng lý do với nút Xem lại bài của exam-taking.md). Khi đó chỉ xuất phần kết quả.
- Nút **Xuất PDF…** / **In…** (mặc định, Return) và **Huỷ** (Esc).
- Bấm **Xuất PDF…** / **In…** với phần xem lại (Câu sai và chưa làm, Tất cả câu) mà lúc đó file đề không đọc được: đóng
  hộp chọn, hộp báo lỗi "Không đọc được file đề để làm phần xem lại" kèm lý do, **không xuất, không in gì** (phương án
  16). Muốn chỉ có phần kết quả thì mở lại và chọn **Không**.

### Nội dung

1. **Đầu trang đầu**: tên đề, mã đề, thí sinh, chế độ (Luyện tập/Thi), ngày giờ nộp (theo định dạng ngày giờ của ngôn
   ngữ giao diện), thời gian làm / thời gian cho phép (Thi), ngưỡng đậu.
2. **Kết quả**: **Đậu / Trượt** (biểu tượng + chữ), điểm phần trăm và thang 1000 ("72% · 720/1000"), số câu đúng/tổng,
   thanh điểm có vạch ngưỡng đậu, **So với lần trước** nếu màn Kết quả có dòng này.
3. **Theo phần**: bảng mỗi section một dòng (tên, đúng/tổng, %, thanh); "Không có câu" cho section 0/0; đánh dấu
   **phần yếu nhất** như màn Kết quả.
4. **Xem lại bài** (nếu chọn): mỗi câu một khối, theo **thứ tự phiên**, đánh số như cửa sổ làm bài:
   - tên phần, "Câu 12/60", trạng thái **Đúng / Sai / Chưa làm** (biểu tượng + chữ), **Đã đánh dấu** nếu có;
   - nội dung câu (Markdown cơ bản), ảnh nếu có;
   - các lựa chọn theo thứ tự đã hiện lúc làm, nhãn A, B, C… theo vị trí hiển thị; đánh dấu **Bạn chọn** và **Đáp án
     đúng** bằng ký hiệu + chữ (in đen trắng vẫn phân biệt được);
   - giải thích nếu đề có.
5. **Chân trang mỗi trang**: "Trang N/M", tên đề và dòng lưu ý "Kết quả luyện tập, không có giá trị xác nhận"
   (phương án 5). Không có dòng thời điểm xuất (phương án 17): thời điểm duy nhất trong PDF là ngày giờ nộp ở đầu trang.

### Quy tắc ẩn/hiện (giữ nguyên exam-taking.md)

| Trường hợp | Trong PDF |
| --- | --- |
| Đề `hideAnswers` (phương án 4 của exam-taking.md) | Có câu, lựa chọn của người làm, Đúng/Sai/Chưa làm; **không** có Đáp án đúng, **không** có giải thích. `hideAnswers` lấy từ **file đề hiện tại** như Xem lại |
| Lần thi cũ, câu đã bị xoá khỏi đề | Dòng "Câu này đã bị xoá khỏi đề" thay nội dung; Đúng/Sai/Chưa làm lúc thi giữ nguyên |
| Lần thi cũ, câu đã sửa sau lần thi (phương án 13, 18) | Nội dung và lựa chọn **hiện tại** (thứ tự file), dòng "Câu này đã được sửa sau lần thi" và "Không hiện lựa chọn của bạn vì câu đã sửa sau lần thi"; **không** đánh dấu Bạn chọn / Đáp án đúng; giải thích của file hiện tại khi đề không `hideAnswers` |
| Chi tiết lần thi không đọc được (phương án 12) | Như màn Kết quả: đầu trang và tóm tắt (đậu/trượt, điểm, đúng/tổng) cùng dòng "Không đọc được chi tiết lần thi này"; không có Theo phần, không có Xem lại |
| Lựa chọn "Câu sai và chưa làm" | Đúng như bộ lọc **Sai** cộng **Chưa làm** của Xem lại (không gồm câu đúng) |

Kiểm bằng test: đọc chữ của PDF tạo ra (PDFKit) và khẳng định không có "Đáp án đúng"/chữ của giải thích với đề
`hideAnswers`, không có "Bạn chọn" ở câu đã sửa (bất biến mới, mục Kiểm chứng).

## Bản Admin: PDF và In đề

### Mở từ đâu

- Cửa sổ soạn đề: menu **Tệp** › **Xuất PDF…** và **In…** (⌘P) (phương án 9). Không có ở bản Học viên (ADR 0003): code
  dựng PDF đề nằm trong `AuthoringFeature`.
- Xuất **nội dung đang có trong cửa sổ**, kể cả thay đổi chưa lưu; không bắt lưu trước. Đề còn lỗi kiểm đề vẫn xuất
  được; hộp chọn hiện dòng "Đề còn N lỗi; PDF in đúng như đang soạn" (phương án 8).

### Hộp chọn trước khi xuất

- **Kiểu** (phương án 7): **Có đáp án và giải thích** / **Chỉ đề (không đáp án)**. Mỗi lần mở hộp chọn luôn chọn sẵn
  **Chỉ đề**, không nhớ lựa chọn lần trước (phương án 18); Return xuất/in ngay kiểu đang chọn.
- Đề `hideAnswers` chọn Có đáp án: dòng nhắc "Đề này ẩn đáp án với học viên. Chỉ gửi bản có đáp án cho người được
  phép xem" (phương án 12). Không chặn: admin có file đề (ADR 0005).
- Nút **Xuất PDF…** / **In…** (Return) và **Huỷ** (Esc).

### Nội dung

1. **Đầu trang đầu** (một khối ở đầu trang 1, Phần 1 tiếp ngay sau trừ khi câu 1 không vừa phần còn lại của trang 1;
   không có trang bìa riêng, phương án 19): tên đề, mã
   đề, số câu, số phần, thời gian Thi mặc định, ngưỡng đậu (% và thang 1000), "Ẩn đáp án" nếu có; hướng dẫn
   (`instructions`, Markdown cơ bản).
2. **Mỗi phần**: tiêu đề phần làm đề mục; câu đánh số liên tục toàn đề (1…N) theo **thứ tự file**; lựa chọn theo thứ
   tự file, nhãn A, B, C… (exam-format.md: chữ cái theo vị trí). Không xáo.
3. **Mỗi câu**: loại (gợi ý "Chọn N đáp án" cho câu nhiều đáp án, như cửa sổ làm bài), nội dung, ảnh, lựa chọn; bản Có
   đáp án thêm đánh dấu **Đáp án đúng** (ký hiệu + chữ) trên lựa chọn đúng và khối **Giải thích**.
4. **Chân trang**: "Trang N/M", tên đề, mã đề; bản Có đáp án thêm "Có đáp án". Không có dòng thời điểm xuất (phương án
   17).

## Trình bày chung

| Mục | Quy tắc |
| --- | --- |
| Khổ giấy | PDF luôn **A4** dọc (595 × 842 pt), lề 18 mm. In dùng đúng bố cục A4 và co vừa khổ giấy đã chọn trong hộp In (Letter, A5…), không dựng lại theo khổ khác (phương án 2) |
| Giao diện | Luôn nền trắng chữ đen, **không theo Dark Mode**; không dùng màu làm tín hiệu duy nhất (đúng/sai/đánh dấu luôn có ký hiệu + chữ) để in đen trắng vẫn đọc được |
| Phông | **Helvetica Neue** (có sẵn trong macOS, đủ dấu tiếng Việt) cho chữ thân và đề mục; chữ thân 11 pt, đề mục 14–18 pt; mã inline dùng **SF Mono**. Không dùng SF Pro trong PDF: chữ Đ (U+0110) vẽ bằng SF Pro được đọc lại từ PDF thành Ð (U+00D0), hỏng tìm và sao chép (Nt0 chốt 2026-10-16, phương án 13). Phông nhúng dạng tập con trong PDF (Core Graphics làm sẵn). Không thêm phông ngoài. Tắt chữ ghép thường (fi, fl, ffi…): Helvetica Neue mặc định ghép thành một ký tự (U+FB01–FB03) làm hỏng chép, tìm và VoiceOver (giai đoạn 5 bước 8a) |
| Tiếng Việt | Chuỗi chuẩn hoá NFC trước khi vẽ; xuống dòng theo từ của hệ thống, không cắt giữa chữ có dấu. Chữ trong PDF là chữ thật (chọn, tìm, sao chép được), không phải ảnh |
| Markdown | Như màn hình (exam-format.md: đậm, nghiêng, mã inline; `MarkdownText` của SessionFeature). Liên kết hiện chữ gạch chân, không bấm được trong PDF. Chuỗi không phân tích được thì in nguyên văn |
| Ảnh | Ảnh câu hỏi vừa bề rộng vùng in, cao tối đa 1/3 trang, giữ tỉ lệ, không phóng to quá cỡ gốc; giải mã đồng bộ trước khi vẽ (không dùng `.task`). Ảnh không giải mã được: dòng "Không hiện được ảnh của câu này" |
| Ngắt trang | Không cắt giữa một dòng chữ. Khối câu (đầu câu, nội dung, ảnh, lựa chọn) ưu tiên nằm trọn một trang; khối cao hơn một trang thì ngắt giữa các lựa chọn/đoạn, đầu câu lặp lại "Câu 12 (tiếp)". Đề mục phần không đứng một mình cuối trang |
| Ngôn ngữ nhãn | Nhãn của PDF (Thí sinh, Đáp án đúng…) theo ngôn ngữ giao diện của app (accessibility-localization.md); nội dung đề giữ nguyên |
| Siêu dữ liệu PDF | Title = tên đề (+ "Kết quả" / "Đề"), Creator = "Exam Suite <phiên bản>"; không ghi tên máy hay đường dẫn file. Ngày tạo (CreationDate) do Core Graphics tự ghi vào siêu dữ liệu như mọi file PDF; không hiện trên trang |

## Tên file và hộp lưu

- Hộp lưu chuẩn của macOS (`NSSavePanel`), kiểu `.pdf`, thư mục lần trước do macOS nhớ.
- Tên gợi ý (phương án 10):
  - Kết quả: `<Tên đề> - <Thí sinh> - <yyyy-MM-dd HHmm>.pdf` (thời điểm nộp);
  - Đề: `<Tên đề> (có đáp án).pdf` hoặc `<Tên đề> (đề).pdf`; bản tiếng Anh dùng chữ của catalog.
  - Bỏ ký tự `/` và `:`, khoảng trắng/điều khiển thừa; cắt còn 120 ký tự (ở ranh giới ký tự, NFC) trước đuôi.
- Ghi file tạm rồi thay (như `ExamPackageWriter`); lỗi ghi thì báo lý do, không để file dở.
- Lưu xong không tự mở PDF (phương án 11).

## In

- **In…** mở hộp In chuẩn của macOS (máy in, số bản, khổ giấy, "Lưu thành PDF" của hệ thống), nội dung là đúng bản
  PDF ở trên, co vừa khổ giấy. Tên việc in (tên gợi ý của "Lưu thành PDF") là tên file gợi ý bỏ `.pdf` (phương án 15).
- Không có Page Setup riêng (⇧⌘P) ở v1.

## Đề lớn

- Xuất trên main actor theo từng trang có nhường lượt (giao diện không đứng), sheet tiến độ "Đang dựng trang N…" có
  **Huỷ**; huỷ thì không để lại file. Sheet tiến độ chỉ hiện khi dựng lâu hơn 0,3 s (phương án 14), cả Xuất PDF và In.
- Ngân sách thời gian và bộ nhớ: [large-exams.md](large-exams.md).

## Cách làm (chỉ API của Apple, không thêm thư viện; ADR 0006)

| Cách | Ưu | Nhược |
| --- | --- | --- |
| **A. SwiftUI `ImageRenderer` theo khối → trang PDF (`CGContext` PDF); in bằng `PDFDocument.printOperation` của PDFKit** (đã chọn) | Dùng lại view/Markdown/ký hiệu của màn hình; chữ vector chọn được; một đường cho cả PDF và In; dựng từng trang nên có tiến độ, huỷ; kiểm được bằng PDFKit (đọc chữ, đếm trang) | Tự phân trang (đo từng khối ở bề rộng trang rồi xếp); `ImageRenderer` không vẽ control AppKit (nút, ô nhập, `List`, `ScrollView`) nên view báo cáo chỉ dùng `Text`/`Image`/`Grid`/hình; chạy trên main actor |
| B. `NSAttributedString` + TextKit (`NSTextView`) qua `NSPrintOperation` (PDF bằng `pdfOperation`) | Ngắt trang theo dòng sẵn có; chữ thật; đề rất dài chạy tốt | Dựng lại toàn bộ trình bày bằng AppKit (Markdown → thuộc tính phông, bảng bằng `NSTextTable`, ảnh bằng `NSTextAttachment`); khác màn hình; khó giữ khối câu không bị cắt |
| C. `NSPrintOperation` trực tiếp trên `NSHostingView` của view màn hình | Ít code nhất | AppKit tự cắt trang ở vị trí bất kỳ (cắt ngang dòng chữ, ảnh); không có chân trang/đánh số kiểm soát được; PDF phụ thuộc kích thước cửa sổ |
| D. HTML + `WKWebView` (`printOperation`) | CSS phân trang tốt (`break-inside: avoid`) | Thêm WebKit và tiến trình web; phải thoát HTML cho nội dung đề; bất đồng bộ, khó test bằng `swift test` |

Chọn **A** (phương án 1), khớp hướng "`ImageRenderer` xuất view SwiftUI ra PDF; in qua `NSPrintOperation`" của
plan-macos-v1.md (`PDFDocument.printOperation` trả về một `NSPrintOperation`). Cấu trúc:

- Model báo cáo thuần (không SwiftUI): danh sách khối (đầu trang, kết quả, bảng theo phần, khối câu) dựng từ
  `ResultsModel`/`AnswerReviewModel` (kết quả) hoặc `Exam` (đề). Mọi quy tắc ẩn/hiện nằm ở đây, có test không cần vẽ.
- Bộ dựng trang: đo chiều cao từng khối bằng `ImageRenderer` ở bề rộng vùng in, xếp tham lam vào trang, vẽ từng trang
  vào `CGContext` PDF; khối quá cao tách theo đoạn/lựa chọn.
- Đặt chỗ: bộ dựng trang và PDF kết quả trong target mới dùng chung cho hai bản (ví dụ `ReportFeature`, SwiftUI +
  PDFKit); PDF đề trong `AuthoringFeature` (chỉ bản Admin). Bước spike của plan giai đoạn 5 đo trên đề 2.000 câu trước
  khi bắt tay vào làm; nếu A không đạt ngân sách thì quay lại B và báo Nt0.

## Kiểm chứng cần có

- Model báo cáo: test cho mọi dòng của bảng "Quy tắc ẩn/hiện", hai kiểu PDF đề, tên file gợi ý (ký tự cấm, cắt độ
  dài, NFC).
- PDF thật (PDFKit, `swift test`): số trang > 0, khổ A4, chữ đọc lại được và chứa tên đề/thí sinh tiếng Việt đúng
  (so sau NFC); đề `hideAnswers` không chứa nhãn "Đáp án đúng" và chữ giải thích; câu đã sửa không chứa "Bạn chọn";
  bản "Chỉ đề" không chứa "Đáp án đúng".
- In: `NSPrintOperation` không hiện hộp thoại, đích là file tạm (`jobDisposition = .save`), trong test.
- Snapshot trang đầu (sáng, A4) cho kết quả và đề (snapshot test, ADR 0010): `ReportSnapshotTests` (giai đoạn 5 bước
  8a). PDF thật không có ký tự chữ ghép U+FB00–FB06 ("official" đọc lại nguyên văn).
- XCUITest (chế độ cô lập): mở hộp chọn từ Kết quả, xuất vào thư mục tạm của test, file tồn tại; bản Admin xuất đề.
  Không mở hộp In thật trong UI test.
- Người test tay: in ra máy in thật (A4 và Letter), mở PDF bằng Preview, tìm chữ tiếng Việt, ảnh lớn, đề 2.000 câu.

## Phương án đã chốt (Nt0 duyệt 2026-10-16; phương án 14–19: 2026-10-17)

1. **Cách dựng PDF:** SwiftUI `ImageRenderer` theo khối → trang PDF; In bằng `PDFDocument.printOperation` của PDFKit.
   Spike đo trên đề 2.000 câu trước khi làm; không đạt ngân sách thì quay lại TextKit (B) và báo Nt0.
2. **Khổ giấy:** PDF luôn A4; In dùng bố cục A4, co vừa khổ giấy chọn trong hộp In. Không dựng lại theo Page Setup.
3. **Phần xem lại trong PDF kết quả:** ba lựa chọn **Không / Câu sai và chưa làm / Tất cả câu**, mặc định **Câu sai và
   chưa làm**, nhớ lựa chọn lần trước.
4. **Giải thích trong PDF kết quả:** có, theo đúng quy tắc của Xem lại; không có công tắc riêng.
5. **Chân trang** có dòng "Kết quả luyện tập, không có giá trị xác nhận" (en "Practice result, not an official
   certification"). Nt0 đổi lời văn 2026-10-18 cho hợp dự án cá nhân.
6. **Bản Học viên:** Xuất PDF/In mở từ nút trên màn Kết quả và menu Tệp (In… ⌘P; Xuất PDF… không phím tắt), bật ở
   Kết quả và Xem lại bài.
7. **PDF đề (Admin)** có hai kiểu: **Có đáp án và giải thích** / **Chỉ đề**. Bảng đáp án gom cuối đề để sau v1.
8. **Đề chưa lưu hoặc còn lỗi:** xuất đúng nội dung trong cửa sổ, hộp chọn hiện dòng cảnh báo số lỗi.
9. **PDF đề** chỉ mở từ cửa sổ soạn đề, không có trong menu thẻ đề của Thư viện.
10. **Tên file gợi ý:** `<Tên đề> - <Thí sinh> - <yyyy-MM-dd HHmm>.pdf` cho kết quả; `<Tên đề> (có đáp án).pdf` /
    `<Tên đề> (đề).pdf` cho đề; cắt ở 120 ký tự.
11. **Sau khi lưu PDF** không tự mở file.
12. **Đề `hideAnswers` ở bản Admin** xuất được kiểu Có đáp án, kèm dòng nhắc trong hộp chọn.
13. **Phông của PDF** (Nt0 chốt 2026-10-16, sau spike bước 1, thay "phông hệ thống SF Pro" của bản đầu): **Helvetica
    Neue** cho chữ thân và đề mục, **SF Mono** cho mã inline. Lý do: với SF Pro, chữ Đ (U+0110) được PDFKit/Preview đọc
    lại từ PDF thành Ð (U+00D0) (SF Pro dùng chung glyph cho hai chữ; SwiftUI và TextKit vẽ theo glyph), nên tìm và sao
    chép chữ "Đ…" hỏng; Helvetica Neue và SF Mono đọc lại đúng (docs/notes/g5-spike-pdf-l10n.md).
14. **Sheet tiến độ** (Nt0 chốt 2026-10-17, bước 5b): chỉ hiện khi dựng PDF lâu hơn **0,3 s** (Xuất PDF và In), để lần xuất
    nhanh (kết quả không có phần xem lại, đề nhỏ) không làm sheet chớp lên rồi tắt. Trong lúc chờ, lệnh Xuất PDF/In của
    cửa sổ tắt và cửa sổ không mở thêm sheet (ảnh phóng to); Huỷ có ngay khi sheet hiện.
15. **Tên việc in** (Nt0 chốt 2026-10-17, bước 5b): tên việc in của hộp In (cũng là tên gợi ý của "Lưu thành PDF") là
    tên file gợi ý của phương án 10, bỏ đuôi `.pdf`.
16. **Đọc file đề lỗi lúc bấm Xuất/In** (Nt0 chốt 2026-10-17, bước 5b): đã chọn phần xem lại mà file đề không đọc được
    thì đóng hộp chọn, hộp báo lỗi "Không đọc được file đề để làm phần xem lại" kèm lý do, không xuất/in gì; muốn chỉ
    phần kết quả thì mở lại, chọn **Không** (không tự đổi sang chỉ phần kết quả).
17. **Không ghi thời điểm xuất trong PDF** (Nt0 chốt 2026-10-17, bước 5b): bỏ dòng "Xuất bằng Exam Suite <phiên bản> lúc
    <thời điểm>" khỏi chân trang (PDF kết quả; PDF đề của bước 6 cũng vậy). Thời điểm duy nhất là lúc nộp bài; phiên bản
    app chỉ còn ở siêu dữ liệu Creator.
18. **Kiểu mặc định của PDF/In đề** (Nt0 chốt 2026-10-17, bước 6): mỗi lần mở hộp chọn luôn chọn sẵn **Chỉ đề (không
    đáp án)**, **không nhớ** lựa chọn lần trước; muốn bản có đáp án thì chọn mỗi lần, để không gửi nhầm đáp án cho học viên.
    Return xuất/in ngay kiểu đang chọn.
19. **Đầu PDF đề** (Nt0 chốt 2026-10-17, bước 6): thông tin đề và hướng dẫn là một khối ở đầu trang 1, Phần 1 tiếp ngay
    sau (như đầu trang của PDF kết quả); không có trang bìa riêng. **Câu 1 dài** (Nt0 chốt 2026-10-18, giai đoạn 5
    bước 8a): khối câu 1 cao hơn phần còn lại của trang 1 thì sang trang 2 cùng đề mục Phần 1, trang 1 chỉ còn khối
    thông tin đề; chấp nhận, vì giữ khối câu trọn một trang (mục Ngắt trang) được ưu tiên.
