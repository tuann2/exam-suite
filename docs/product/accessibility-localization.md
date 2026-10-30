# Trợ năng, Dark Mode và ngôn ngữ

Thẩm quyền: tài liệu này (giai đoạn 5), gom các yêu cầu trợ năng đã rải ở library.md, exam-taking.md, authoring.md và
mục "Thiết kế UX trên macOS" của [plan-macos-v1.md](plan-macos-v1.md) ("mọi nút có nhãn VoiceOver… Chuỗi hiển thị
đặt trong String Catalog, có sẵn tiếng Việt và tiếng Anh"). Yêu cầu riêng của từng màn vẫn ở tài liệu của màn đó;
ở đây là mục tiêu phủ, quy tắc chung và cách kiểm. Số phương án dẫn tới mục cuối (Nt0 chốt 2026-10-16).

## VoiceOver

Quy tắc chung (đã có, nhắc lại để kiểm theo một danh sách):

- Mọi điều khiển có nhãn; nút chỉ có biểu tượng có `accessibilityLabel` bằng chữ; ảnh trang trí ẩn khỏi VoiceOver.
- Trạng thái (đúng/sai/chưa làm/đánh dấu/lỗi/cảnh báo/đậu/trượt) đọc bằng chữ, không chỉ qua màu hay biểu tượng.
- Thay đổi quan trọng mà tiêu điểm không đi tới thì **thông báo** (`AccessibilityNotification.Announcement`).
- Tiêu đề vùng có thuộc tính tiêu đề (`.isHeader`) để đi bằng rotor Headings.
- Ảnh câu hỏi: nhãn "Ảnh của câu hỏi" (đề v1 không có chữ thay thế cho ảnh; thêm trường mô tả ảnh cần `formatVersion`
  mới, ngoài v1).

### Mục tiêu phủ theo màn

| Màn | Phải đọc được | Thông báo tự động | Cách kiểm |
| --- | --- | --- | --- |
| Thư viện (lưới/danh sách) | Sidebar, thanh công cụ (Thêm đề, Đề mới (Admin), tìm, sắp xếp, lọc, kiểu xem); mỗi thẻ một câu tóm tắt (tiêu đề, mã, số câu, trạng thái, lần thi gần nhất) với hành động trợ năng như menu chuột phải | Kết quả Thêm đề, Xoá khỏi thư viện + Hoàn tác (dải thông báo) | `LibraryAccessibility` (test hiện có) + audit |
| Lịch sử thi | Mỗi dòng: ngày giờ, đề, thí sinh, chế độ, điểm, đậu/trượt | — | Test câu đọc + audit |
| Thông tin đề, dải chào mừng | Nhãn từng trường, nút đóng | — | Audit |
| Trước khi thi | Nhãn mọi ô của Form; lý do Bắt đầu bị khoá đọc được ngay sau dòng tóm tắt | — | Audit + tay |
| Cửa sổ làm bài | Đầu câu ("Câu 3 trên 60, Phần Mạng"); mỗi lựa chọn đọc chữ cái + nội dung + đã chọn/chưa; đồng hồ (giá trị, mức sắp hết/gấp); mỗi ô bảng câu hỏi đọc số + trạng thái; lớp phủ Tạm dừng | Đổi câu, cảnh báo 5/1 phút, hết giờ, kết quả Kiểm tra đáp án (exam-taking.md) | `AttemptModel` (test hiện có) + audit + tay |
| Rà soát & nộp | Ba số, hai danh sách câu, hộp xác nhận nộp | — | Audit + tay |
| Kết quả | Đậu/Trượt, điểm, so với lần trước, từng dòng Theo phần (tên, đúng/tổng, %, "phần yếu nhất"), lỗi lưu | Kết quả nộp bài | Test câu đọc + audit |
| Xem lại bài | Bộ lọc kèm số lượng; mỗi dòng câu đọc số + trạng thái; lựa chọn đọc "Bạn chọn", "Đáp án đúng"; dải "đã sửa sau lần thi" | — | `AnswerReviewModel` + audit |
| Xuất PDF / In (giai đoạn 5) | Hộp chọn (lựa chọn, lý do bị tắt), sheet tiến độ có Huỷ | Xuất xong / lỗi | Audit + tay; hộp Lưu và In là của macOS |
| Soạn đề (Admin) | Dòng cây đề đọc số, dòng đầu, có ảnh/nhiều đáp án, lỗi/cảnh báo; mọi ô của trình soạn có nhãn (không dựa vào placeholder); dòng lựa chọn đọc chữ cái + "đúng"/"không đúng"; thanh lỗi đọc số lỗi/cảnh báo và từng dòng; xem trước đọc như cửa sổ làm bài | Lưu xong, kiểm đề có lỗi mới (không đọc mỗi lần gõ) | Test `AuthoringPresentation` + audit + tay |
| Import đề (Admin) | Tiến độ, hộp xác nhận, bảng báo cáo (mỗi dòng: vị trí, mức, nội dung) | Import xong / lỗi | Audit + tay |

"Audit" là kiểm trợ năng tự động trong XCUITest (`XCUIApplication.performAccessibilityAudit`, phương án 7) ở mỗi màn
mà luồng UI test đi qua; loại kiểm nào không có trên macOS thì bỏ và ghi lại. "Tay" là danh sách test tay VoiceOver ở
plan giai đoạn 5.

## Dark Mode và tương phản

- App theo giao diện sáng/tối của hệ thống; không có công tắc riêng. **Ngoại lệ** (Nt0 chốt 2026-10-18, plan giai đoạn
  6): **nền đọc** của vùng nội dung câu (mục Nền đọc bên dưới) do người dùng chọn; nền đã chọn giữ nguyên khi macOS đổi
  sáng/tối, chỉ "Theo hệ thống" (mặc định) đổi theo. Phần còn lại của app vẫn theo hệ thống.
- Màu dùng lại quy tắc **phương án 8 của library.md**: chữ nhỏ ≥ 4,5:1, chữ lớn và biểu tượng ≥ 3:1 trên nền thật của
  chúng, ở **cả hai** giao diện. Màu nhấn teal và burgundy đặt trên nền thì dùng biến thể sáng/tối riêng như `#4FC9C9` /
  `#006666`.
- Mọi màu tự định nghĩa nằm trong bảng màu có giá trị số (`LibraryPalette`, `AuthoringPalette`; `SessionStyle` dựng từ
  `LibraryPalette`; năm bộ màu của nền đọc `ReadingPalette`; màu PDF `ReportTypography.Gray`) và có test tương phản; màu
  mới phải vào bảng màu, không viết hex trong view.
- Còn lại dùng màu ngữ nghĩa của hệ thống (`.primary`, `.secondary`, `.separator`, nền cửa sổ) để Dark Mode và
  **Increase Contrast** của macOS tự điều chỉnh. Không thêm bảng màu riêng cho Increase Contrast ở v1 (phương án 6).
- **Màu ngữ nghĩa của hệ thống được miễn quy tắc 4,5:1 / 3:1 của app** (Nt0 chốt 2026-10-18): chúng theo Dark Mode và
  Increase Contrast của macOS, Increase Contrast kiểm tay. Quy tắc áp cho màu app tự định nghĩa (`LibraryPalette`,
  `AuthoringPalette`, `SessionStyle`, màu PDF) và mọi nền pha màu hay có độ trong mà app đặt (chữ `.primary` đặt lên nền
  đó cũng phải đạt). Vì vậy chữ `.secondary` đo được dưới 4,5:1 ở ghi chú bước 8a (4,06:1; 3,72:1; 4,45:1; 4,42:1) không
  phải sửa.
- Nền nhạt có độ mờ (`tintedBackgroundOpacity`) phải đạt tỉ lệ trên với chữ đặt lên nó ở cả hai giao diện (tính trên
  màu đã trộn với nền cửa sổ).
- Tôn trọng **Reduce Motion** (đã có) và **Reduce Transparency** (nền mờ thay bằng nền đặc).
- PDF và bản in luôn sáng (export-print.md).
- Kiểm: test tương phản bảng màu; test tương phản **năm bộ màu của nền đọc** ở cả giao diện sáng và tối của macOS
  (`ReadingBackgroundTests`: chữ, chữ phụ, teal, Đúng/Sai/đánh dấu ≥ 4,5:1 trên nền, lựa chọn đang chọn, khung giải thích,
  dòng báo; biểu tượng ≥ 3:1; nhãn Đúng/Sai sau Kiểm tra đáp án đo trên ảnh chụp ở mọi nền cố định,
  `ReadingBackgroundScopeTests`); snapshot sáng/tối các màn chính (ADR 0010); test tay Dark Mode và Increase Contrast.

### Nền đọc (giai đoạn 6, Nt0 chốt 2026-10-18)

Người dùng nhìn màn hình làm bài rất lâu, nên vùng nội dung câu có nền chọn được (plan giai đoạn 6, bước 1, Decisions).

- **Năm nền:** Theo hệ thống (mặc định: vẽ như trước, theo sáng/tối của macOS và màu ngữ nghĩa của hệ thống), Trắng, Giấy
  ngà (tông ấm), Xám dịu (nền xám bớt chói, chữ tối), Tối. Mỗi nền cố định là một bộ màu số (`ReadingPalette`: nền, chữ,
  chữ phụ, viền, teal, Đúng/Sai/đánh dấu, khung giải thích; nền của lựa chọn đang chọn và của dòng báo là màu pha lên nền,
  trộn sẵn thành màu đặc). Trong vùng nội dung câu của nền cố định **không dùng màu ngữ nghĩa** của hệ thống (`.primary`,
  `.secondary`, `.separator`, `.background`): chữ `.secondary` của giao diện tối sẽ nằm trên nền Giấy ngà; vùng đó còn ép
  giao diện sáng/tối theo độ sáng của nền (thanh cuộn, chữ đang chọn). Không có màu tự chọn (color picker).
- **Phạm vi:** đúng phạm vi của cỡ chữ nội dung (phương án 5): nội dung câu của cửa sổ làm bài, chi tiết câu của Xem lại
  bài, xem trước của Soạn đề. Bảng câu hỏi, thanh bên, thanh công cụ, thanh dưới, Rà soát & nộp, lớp phủ Tạm dừng, dải
  cảnh báo giờ, sheet mở từ vùng nội dung (ảnh phóng to) giữ giao diện macOS. PDF và bản in luôn sáng (export-print.md).
- **Chọn:** menu **Xem › Nền đọc** (tên menu theo macOS, Nt0 chốt 2026-10-18; tiếng Anh View › Reading Background),
  ngay sau Phóng to / Thu nhỏ / Cỡ thật, bật ở cùng các cửa sổ với ba mục đó (đổi được khi đang làm bài), dấu ✓ ở nền đang
  chọn; và ở **Trước khi thi** (nhóm nút radio có mẫu màu nhỏ, cuối Form). Một lựa chọn cho cả app, nhớ bằng `@AppStorage`
  khoá `content.readingBackground` trong `defaults` của scene như cỡ chữ nội dung (UI test: suite trong thư mục cô lập).
- **VoiceOver:** mục menu đọc tên nền và trạng thái chọn (dấu ✓ của macOS); ô chọn của Trước khi thi là nút radio có
  nhãn, đọc trạng thái chọn; mẫu màu ẩn khỏi VoiceOver.
- **Lựa chọn bị khoá** sau Kiểm tra đáp án: macOS làm mờ nút bị tắt cùng nội dung của nó (chữ của lựa chọn đo
  2,7–4,5:1 trên các nền, review độc lập #58); là điều khiển bị tắt, được miễn như ở giao diện theo hệ thống từ trước.
  Nhãn Đúng/Sai vẽ ngoài nút nên không bị làm mờ (#54) và có test trên ảnh chụp ở mọi nền cố định
  (`ReadingBackgroundScopeTests`, kèm đối chứng âm nhãn bị làm mờ).
- **Reduce Transparency:** nền cố định chỉ dùng màu đặc, không có độ trong. **Increase Contrast:** nền Theo hệ thống theo
  macOS như mọi nơi; nền cố định giữ bộ màu (đã đạt 4,5:1 trên mọi nền của vùng), không có bảng màu riêng cho Increase
  Contrast (phương án 6); kiểm tay ở G3.

## Cỡ chữ

macOS không có Dynamic Type như iOS: thiết lập cỡ chữ của System Settings chỉ áp dụng cho một số app của Apple, và
`dynamicTypeSize` của SwiftUI trên macOS không đổi theo hệ thống. Cách người dùng phóng to hiện nay: Zoom của macOS,
đổi độ phân giải màn hình.

- Bố cục giữ được ở cửa sổ tối thiểu 960×640 với câu dài, 8+ lựa chọn, ảnh lớn (plan-macos-v1.md, Kiểm thử).
- "Giữ bố cục ở 200%" (library.md, mục Cửa sổ) hiểu là: với cỡ chữ nội dung lớn nhất của phương án 5 (hoặc Zoom
  200% của macOS), không chữ nào bị cắt hay chồng; vùng nội dung cuộn được.
- Phương án 5: **Phóng to / Thu nhỏ / Cỡ thật** (⌘+ / ⌘− / ⌘0, menu Xem › Phóng to…) cho **vùng nội dung câu** ở cửa sổ
  làm bài, Xem lại bài và xem trước của Soạn đề, bốn mức (100%, 115%, 130%, 150%), nhớ bằng `@AppStorage`; không đổi cỡ
  chữ của thanh công cụ, sidebar, bảng câu hỏi.

## Ngôn ngữ (String Catalog)

### Chọn ngôn ngữ

- **Tiếng Việt là ngôn ngữ nguồn** (development language `vi`); có bản tiếng Anh (`en`).
- App **theo ngôn ngữ của macOS**: thứ tự ngôn ngữ ưu tiên của hệ thống, hoặc ngôn ngữ riêng cho app ở System Settings ›
  General › Language & Region › Applications. Không có ô chọn ngôn ngữ trong app (phương án 1). Ngôn ngữ ưu tiên
  không có vi/en thì macOS chọn ngôn ngữ kế tiếp trong danh sách; không có cái nào thì dùng tiếng Việt.

### Dịch gì

| Dịch | Không dịch |
| --- | --- |
| Chữ của giao diện: nút, menu, nhãn, trợ giúp (`help`), hộp thoại, dải thông báo, trạng thái, thông báo lỗi | Nội dung đề: tiêu đề, hướng dẫn, phần, câu, lựa chọn, giải thích |
| Nhãn và thông báo VoiceOver | Tên thí sinh, tên file, đường dẫn |
| Nhãn của PDF/bản in (export-print.md) | Đề mẫu của Thư viện (phương án 3) |
| Chuỗi Info.plist hiện cho người dùng (tên kiểu tài liệu "Đề Exam Suite"…) | Tên app "Exam Suite"; chữ cái lựa chọn A–Z; phím tắt |
| Thông báo lỗi kiểm đề, đọc file, thư viện, import (phương án 2) | Nhật ký/log cho người phát triển |

- Ngày giờ, số, phần trăm định dạng theo **locale** của ngôn ngữ giao diện (`FormatStyle`), không ghép chuỗi tay.
  **Ngoại lệ** (Nt0 chốt 2026-10-17): giá trị thang 1000 luôn chữ số trơn, không ngăn nghìn, ở mọi ngôn ngữ ("850/1000",
  "1000/1000"; cột "Thang 1000" của Lịch sử thi "1000"): "1000" là tên của thang (scoring.md).
- Tiếng Anh có số nhiều: dùng biến thể plural của String Catalog ("1 question" / "2 questions"); tiếng Việt một dạng.
- Thuật ngữ tiếng Anh theo bảng dưới (theo cách gọi của DESIGN_BRIEF Open Exam Suite, đọc qua link), để menu, nút,
  VoiceOver và đề mẫu "Làm quen" nói cùng một tên.

| Tiếng Việt | Tiếng Anh |
| --- | --- |
| Thư viện / Đề / Phần / Câu / Lựa chọn | Library / Exam / Section / Question / Option |
| Luyện tập / Thi | Practice / Exam |
| Trước khi thi | Before You Start |
| Kiểm tra đáp án | Check Answer |
| Đánh dấu | Flag |
| Rà soát & nộp / Nộp bài | Review & Submit / Submit |
| Kết quả / Đậu / Trượt / Ngưỡng đậu | Results / Pass / Fail / Passing score |
| Xem lại bài / Luyện lại câu sai | Review Answers / Practice Incorrect |
| Bạn chọn / Đáp án đúng / Chưa làm | Your answer / Correct answer / Unanswered |
| Lịch sử thi / Thí sinh | History / Candidate |
| Soạn đề / Đề mới / Thử đề này / Import đề | Editor / New Exam / Try This Exam / Import Exam |

Thuật ngữ thêm ở bước 7c (agent dịch theo phương án 4; **Nt0 duyệt 2026-10-17**, cùng các chỉnh câu chữ của review
độc lập #52). Viết hoa kiểu tiêu đề (Title Case) cho mục menu, nút, tiêu đề cửa sổ và mục, cột, thẻ trạng thái, nhóm
lựa chọn; kiểu câu (sentence case) cho nhãn ô, câu thông báo và tiêu đề hộp báo, trợ giúp, VoiceOver; "…" cho lệnh mở
hộp thoại (theo Apple HIG). "Library" viết hoa khi gọi tên cửa sổ/tính năng Thư viện, kể cả trong câu ("Removed “X”
from the Library."):

| Tiếng Việt | Tiếng Anh (đề xuất) | Ghi chú |
| --- | --- | --- |
| lần thi | attempt | "%lld attempts", "Last Attempt", "Show All Attempts" |
| Bài thi (menu của cửa sổ làm bài) / Làm bài (tên cửa sổ làm bài) | Attempt / Attempt | Không dùng "Exam": bản Admin có cả menu **Đề** của cửa sổ soạn đề ("Exam"), hai menu cùng tên "Exam" sẽ lẫn |
| Làm bài (mục trong cửa sổ soạn đề: ngưỡng đậu, thời gian Thi, Ẩn đáp án) | Exam Settings | Khoá của catalog AuthoringFeature, khác khoá "Làm bài" của SessionFeature |
| Thời gian Thi (soạn đề, PDF đề) | Time limit for Exam mode / Time limit (Exam mode) | "Exam" ở đây là chế độ Thi |
| Đề (menu và mục Đề của cửa sổ soạn đề) | Exam | Theo bảng trên |
| Bảng câu hỏi | Question Navigator | Ẩn/Hiện Bảng câu hỏi: Hide/Show Question Navigator |
| Câu sau / Câu trước / Câu tiếp theo (Return) | Next Question / Previous Question / Continue | "Continue" để menu không có hai mục "Next Question" |
| Đánh dấu / Bỏ đánh dấu / Đã đánh dấu | Flag / Unflag / Flagged | |
| Tạm dừng / Tiếp tục (sau tạm dừng) | Pause / Resume | |
| Quay lại làm bài | Back to Questions | |
| Bỏ bài / Tiếp tục làm | Discard / Keep Working | Hộp "Bài chưa nộp sẽ mất. Bỏ bài?" |
| Đã làm / Đúng / Sai, Chưa đúng | Answered / Correct / Incorrect | "Unanswered" theo bảng trên |
| Xem câu sai / Làm lại / Về thư viện | Review Incorrect / Retake / Back to Library | |
| Phần yếu nhất / So với lần trước | Weakest section / Compared with last attempt | |
| Theo phần / Chọn câu / Tất cả câu / N câu ngẫu nhiên | By Section / Question Selection / All Questions / N Random Questions | Đề mục Kết quả và PDF; nhóm lựa chọn của Trước khi thi (cùng khoá "Theo phần") |
| Kết quả (câu VoiceOver sau khi nộp) | Result: … | Màn và đề mục vẫn "Results" |
| Đậu từ … / đậu … (dòng tóm tắt) | Passing score … / passing score … | Theo "Ngưỡng đậu" của bảng trên |
| Phím … (gợi ý VoiceOver của lựa chọn) | Press … | |
| Không <thao tác> được (tiêu đề hộp báo của soạn đề) | Couldn’t <thao tác> ("Couldn’t assign a new ID") | Mỗi thao tác một khoá câu trọn vẹn (`EditAction`) |
| Nộp lúc / Thời gian làm / Số câu đúng | Submitted / Time taken / Correct answers | |
| Thêm đề / Thêm đề… | Add Exams / Add Exams… | Chọn được nhiều file |
| Đề mẫu (nhãn) / Khôi phục đề mẫu | Sample / Restore Sample Exams | |
| Xoá khỏi thư viện / Tìm file… / Thông tin / Xem kết quả | Remove from Library / Locate File… / Get Info / Show Results | |
| Sẵn sàng / Đang kiểm tra / Có lỗi / Đề có lỗi / Cần app mới hơn / Không tìm thấy file / File hỏng | Ready / Checking / Has Errors / Invalid Exam / Needs Newer App / File Not Found / Damaged File | Thẻ trạng thái của Thư viện |
| Lọc: Có vấn đề | With Problems | |
| Thang 1000 (cột Lịch sử thi) | Out of 1000 | |
| Bản Học viên / Bản Admin | Student app / Admin app | |
| Mở để sửa… / Mở gần đây | Open for Editing… / Open Recent | |
| Cây đề / Thanh lỗi / Tìm trong cây đề (menu Sửa) | Exam outline / Issue bar / Find in Outline | |
| Mã đề | Exam code | |
| Xem lại bài (đề mục của PDF) | Answer Review | Nút và màn vẫn "Review Answers" |
| Chỉ đề (không đáp án) / Có đáp án và giải thích | Questions only (no answers) / With answers and explanations | PDF đề; tên file "(questions only)" / "(with answers)" |
| Tên mặc định ghi vào đề: Đề mới / Phần N / Phần chung | New Exam / Section N / General Section | Theo ngôn ngữ giao diện lúc tạo (ghi chú bước 7c) |
| Tên kiểu tài liệu | vi "Đề Exam Suite", en "Exam Suite Exam" | Info.plist; tên app "Exam Suite" không dịch |

Thuật ngữ thêm ở giai đoạn 6 (agent dịch theo phương án 4; **Nt0 duyệt 2026-10-18**):

| Tiếng Việt | Tiếng Anh | Ghi chú |
| --- | --- | --- |
| Xem (menu) | View | Tên menu của macOS (không gọi "Hiển thị"); Phóng to / Thu nhỏ / Cỡ thật, Nền đọc nằm ở đây |
| Nền đọc | Reading Background | Menu con của Xem (View) và nhãn ô chọn của Trước khi thi |
| Theo hệ thống / Trắng / Giấy ngà / Xám dịu / Tối | Match System / White / Sepia / Soft Gray / Dark | Tên năm nền (mục menu, nút radio) |

### Cách làm

- Mỗi target có chữ giao diện có `Localizable.xcstrings` riêng: InterfaceCore, SessionModel (`Packages/SharedFeatures`,
  dùng chung với bản iOS, tách từ LibraryFeature, SessionFeature ở bước I1 của plan-ios-v1.md; `InterfaceStrings`,
  `InterfaceLocale`, `ErrorMessages` ở InterfaceCore), LibraryFeature, SessionFeature, ReportFeature, AuthoringFeature,
  AdminShell (`Packages/ExamFeatures`). StudentShell không có chữ giao diện nên không có catalog;
  target dữ liệu (LibraryData, AuthoringData, ExamImport) không có catalog: lỗi trả mã, tầng giao diện dựng câu (ghi chú
  bước 7b), và chữ app ghi vào nội dung đề đi vào từ tầng giao diện (ghi chú bước 7c). Package khai báo
  `defaultLocalization: "vi"`; app khai báo `CFBundleDevelopmentRegion = vi`, `knownRegions` gồm `vi`, `en`, và
  `InfoPlist.xcstrings` cho chuỗi Info.plist.
- Chữ trong Swift package mặc định tra **bundle của app**, không phải bundle của module: `Text("…")` và
  `String(localized:)` trong package phải chỉ rõ bundle của module (`bundle: .module`, hoặc `#bundle` nếu chạy được với
  macOS 15). Bước spike của plan chốt cách nào và cách bắt chỗ quên (script hoặc test).
- Bản Học viên không chứa catalog của AuthoringFeature/AuthoringData/ExamImport (đi theo module, ADR 0003).
- **Lõi ExamKit/ExamFile** (Foundation-only, test trên Linux, ADR 0008) không đổi: vẫn sinh lỗi có **mã** (ví dụ
  `ValidationIssue.code`) và câu tiếng Việt cho log/script; tầng giao diện dịch từ mã + vị trí sang chuỗi của catalog
  (phương án 2). Chỗ nào lõi chưa có mã thì thêm mã, không đổi kết luận đọc/kiểm đề.
- Chuỗi mới viết thẳng bằng tiếng Việt trong code như hiện nay; catalog được cập nhật khi build; bản dịch tiếng Anh
  do agent viết theo bảng thuật ngữ, Nt0 duyệt (phương án 4).

### Kiểm

- `scripts/check_localization.py --require-en` (chạy được ở mọi nơi; bật từ bước 7c trong `check.sh` mọi chế độ, kể cả
  `--core`, và trong `verify_local.sh`): đọc mọi `.xcstrings`; mỗi khoá có `en` ở trạng thái `translated` (không `new`,
  `needs_review`, `stale`), không rỗng, kể cả biến thể plural và substitution; đối số (số vị trí và kiểu: `%lld`, `%@`)
  của `en` khớp nguồn `vi`, đổi thứ tự bằng số vị trí (`%2$@`); biến thể plural đủ `one`/`other`. `vi` là khoá (hoặc giá
  trị `vi` khi có số vị trí), không có trạng thái riêng. Dạng `other` của plural phải có đủ đối số của nguồn, của
  substitution phải có `%arg` (chỉ dạng `one` được bỏ số). Luật `test-hook`: chỗ ép ngôn ngữ chỉ cho test không có trong
  code của app.
- Chữ trong code chưa vào catalog: bước build/xuất localization của Xcode (`xcodebuild -exportLocalizations` hoặc đồng
  bộ catalog khi build, chốt ở spike) chạy trong `verify_local.sh`; catalog thay đổi sau bước đó thì thất bại kèm
  danh sách khoá.
- Test Swift: `LocalizedStringResource(<khoá>, bundle: .module)` đặt `.locale = Locale(identifier: "en")` rồi
  `String(localized:)` cho vài khoá mẫu mỗi module ra chữ tiếng Anh (catalog được đóng gói đúng bundle). Test khoá ngôn
  ngữ theo cách này vì tham số `locale` của `String(localized:bundle:locale:)` chỉ định dạng số/ngày, không chọn ngôn
  ngữ, và trong `swift test` chuỗi của package mặc định ra tiếng Anh khi catalog có `en` (spike giai đoạn 5,
  docs/notes/g5-spike-pdf-l10n.md).
- Mọi catalog có cùng các ngôn ngữ (review #50 N2: `InterfaceLocale` chọn ngôn ngữ theo catalog của InterfaceCore, của
  LibraryFeature trước bước I1 của plan iOS):
  `check_localization.py --built-apps` (mọi bundle catalog trong hai app đã build có cùng `*.lproj`, có `en`) và
  `CatalogLanguagesTests` (bundle của `swift test`; ưu tiên tiếng Anh ra `en` cho số và chữ ở mọi module).
- XCUITest: Thư viện, Trước khi thi, màn Làm bài (menu Attempt) và Rà soát & nộp ở tiếng Anh (`-AppleLanguages (en)`, tìm
  phần tử theo định danh), kiểm vài nhãn tiếng Anh và không có chữ tiếng Việt của giao diện ở các màn đi qua
  (`EnglishInterfaceUITests`). Hộp xác nhận nộp, Kết quả, Xem lại bài tiếng Anh: snapshot `resultsEnglish`,
  `answerReviewEnglish`, `LocalizationTests` (câu hỏi của hộp xác nhận), `EnglishResultsReportTests` (rút gọn UI test ở
  bước 10 giai đoạn 5; trước đó UI test đi hết luồng 1).
- Tay: chạy app bằng tiếng Anh ở 960×640, xem chữ dài bị cắt.

### Ghi chú hiện thực (giai đoạn 5, bước 4)

Ghi lại cách đã làm ở bước 4 (hạ tầng, chưa dịch); không đổi phương án đã chốt ở dưới. Quy ước viết code và lệnh ở
AGENTS.md, mục "Chuỗi giao diện".

- **Catalog:** `Localizable.xcstrings` (`sourceLanguage` vi, chưa có mục `en`) ở LibraryFeature, SessionFeature,
  AuthoringFeature, AdminShell. StudentShell chưa có chữ giao diện nên chưa có catalog; LibraryData, AuthoringData,
  ExamImport không có catalog: từ bước 7b chúng trả lỗi có mã, tầng giao diện dựng câu (ghi chú bước 7b bên dưới). Package khai báo
  `defaultLocalization: "vi"`. Catalog do `xcodebuild -exportLocalizations` ghi (định dạng của Xcode).
- **Gọi trong code:** `Text("…", bundle: .module)`; các API khác và chuỗi của model trình bày qua `localized("…")` của
  từng target, gọi `InterfaceStrings.resolve(_:bundle:)` (LibraryFeature). Trong app, `resolve` dùng
  `String(localized:bundle:locale:)` nên ngôn ngữ theo bundle chính; số và ngày nội suy định dạng theo locale của ngôn
  ngữ giao diện từ bước 7a (ghi chú bên dưới). Năm
  tham số kiểu `LocalizedStringKey` của view (tiêu đề ô Rà soát, menu Bài thi, nhãn ô của hộp Import) đổi thành `String`
  đã tra. Chuỗi trong nhánh `?:` của `Text`/`.help`/`Button` trước đây là `LocalizedStringKey` tra bundle chính, nay mỗi
  nhánh tra catalog của module.
- **Info.plist:** mỗi app có `InfoPlist.xcstrings` với `CFBundleName`, `CFBundleDisplayName`,
  `NSHumanReadableCopyright` và tên kiểu tài liệu "Exam Suite Exam" (khoá do `-exportLocalizations` thêm), bản `vi` và
  `en` bằng đúng giá trị gốc (chưa đổi chữ). Tên kiểu tài liệu tiếng Việt ("Đề Exam Suite", bảng "Dịch gì") để bước 7
  (đã làm ở bước 7c, ghi chú bên dưới).
  project.yml: `developmentLanguage: vi` (`developmentRegion` vi, `knownRegions` Base/en/vi), `CFBundleDevelopmentRegion`
  = `$(DEVELOPMENT_LANGUAGE)` = vi. Bundle chính của hai app có `vi.lproj` và `en.lproj`.
- **UI test** mở app với `-AppleLanguages (vi)` (`IsolatedApp`), nên tìm phần tử theo chữ tiếng Việt vẫn đúng khi có `en`.
- **Hệ quả nhìn thấy được** (Nt0 xác nhận 2026-10-17): chữ của Exam Suite không đổi ở mọi ngôn ngữ (catalog chưa có `en`, tra `en` ra khoá tiếng
  Việt). Chữ do macOS vẽ (menu chuẩn như Thoát/Cửa sổ, hộp Mở/Lưu, nút mặc định của hộp thoại) trước đây luôn tiếng Anh
  vì app không khai báo ngôn ngữ; nay theo ngôn ngữ app chọn, nên máy đặt tiếng Việt ưu tiên sẽ thấy các chữ đó bằng
  tiếng Việt (đúng phương án 1; cần test tay).
- **Test:** tiến trình không khai báo `vi` ở bundle chính (`swift test`) thì `InterfaceStrings.pinnedLocale` = vi
  (tra bằng `LocalizedStringResource` + `locale`), nên test đang so chữ tiếng Việt không phải sửa và vẫn đậu khi catalog
  có `en` (đã thử: điền `en` giả cho mọi khoá, mọi test cũ đậu; chỉ test khẳng định "chưa có en" của bước 4 đỏ như dự
  kiến). Tra theo ngôn ngữ cố định: `InterfaceStrings.resolve(_:bundle:locale:)` với `<Module>.ModuleStrings.bundle`.
- **Kiểm:** `scripts/check_localization.py` quét mã nguồn (quên `bundle:` hay `bundle:` khác `.module`, literal trong
  đối số của API chỉ nhận khoá kể cả nhánh `?:`, chữ gán cho thuộc tính của AppKit, `LocalizedStringKey`, chữ
  tiếng Việt trơn ngoài `// l10n-ignore`) và catalog (nguồn vi, không stale, không bản dịch rỗng); `--freshness`
  (`check.sh`, `.stringsdata` của `swift build` + `xcstringstool sync` trên bản sao), `--built-apps` và
  `-exportLocalizations` + catalog không đổi (`verify_local.sh`). Kiểm đủ `en` (`--require-en`) **tắt** tới bước 7
  (bật ở bước 7c).

### Ghi chú hiện thực (giai đoạn 5, bước 7a: định dạng theo ngôn ngữ giao diện)

Quy tắc "ngày giờ, số, phần trăm định dạng theo locale của ngôn ngữ giao diện (`FormatStyle`), không ghép chuỗi tay"
(mục Ngôn ngữ; Nt0 giữ 2026-10-17: không theo Region của macOS) áp cho mọi màn của hai bản và PDF/In:

- **Locale của giao diện:** `InterfaceLocale.current` (LibraryFeature, cạnh `InterfaceStrings`) = locale **chỉ có mã
  ngôn ngữ** mà **chữ của catalog** thật sự ra, nên số/ngày và chữ luôn cùng một ngôn ngữ: ngôn ngữ đầu tiên trong thứ tự
  của app (`Bundle.main.preferredLocalizations`) có trong catalog của module (`*.lproj` đã biên dịch của bundle
  LibraryFeature cộng tiếng Việt nguồn, luôn tra được); so theo mã ngôn ngữ, vùng bị bỏ; không khớp thì `vi` (phương án
  1). Bundle chính có `en.lproj` (chuỗi Info.plist) từ bước 4 nhưng catalog chưa có `en` tới bước 7c (bundle của module
  hiện không có `*.lproj` nào), nên **tới 7c mọi máy đều ra `vi`**: máy ưu tiên tiếng Anh thấy chữ tiếng Việt và số/ngày
  dạng tiếng Việt, không lẫn "Câu 1,234/2,000". Sau 7c, máy ưu tiên tiếng Anh ra `en`. Không dùng
  `Bundle.preferredLocalizations(from:forPreferences:)`: khi không khớp nó trả ngôn ngữ đầu danh sách (thử: catalog
  `en, vi`, ưu tiên `fr` → `en`), còn chữ của module ra `vi` (spike). Trong tiến trình không phải app (`swift test`) là
  `vi` đã khoá của `InterfaceStrings.pinnedLocale`. Cài đặt riêng của người dùng cho số/ngày ở Language & Region (dấu
  ngăn, 12/24 giờ, lịch) cũng không áp dụng: chúng thuộc Region; ngày giờ luôn lịch Gregorian
  (`InterfaceLocale.calendar`).
- **Kết quả:** giao diện tiếng Việt "Trang 1.175/1.175", "Câu 1.234/2.000", "2.000 câu", "85%", ngày giờ "14:05
  15/10/2026", dung lượng "1,4 MB"; giao diện tiếng Anh "1,175/1,175", "85%", "10/15/2026, 2:05 PM", "1.4 MB"; bất kể
  Region. Phần trăm trong app đều là số nguyên (scoring.md), nên chưa có dấu thập phân; `FormatStyle` sẽ cho "85,5%"
  (vi) và "85.5%" (en).
- **Chữ có số qua catalog:** `InterfaceStrings.resolve` (và `localized(_:)` của mọi target) định dạng số nội suy theo
  `InterfaceLocale.current` (trước đây `String(localized:bundle:)` mặc định theo `Locale.current`, tức Region).
- **View SwiftUI:** mọi scene của hai shell gắn `.interfaceLocale()` (môi trường `\.locale`), nên nội suy trong
  `Text("…", bundle: .module)` và `Text(n, format: .number)` theo ngôn ngữ giao diện; ô số (`TextField(value:format:)`)
  dùng `.number.locale(locale)` của môi trường. `\.locale` cũng là ngôn ngữ SwiftUI dùng để tra `Text(_:bundle:)` (spike),
  nên chữ và số cùng một ngôn ngữ.
- **PDF/In:** `ReportRenderer` gắn cùng locale cho gốc mỗi `ImageRenderer`; chữ của tài liệu đã định dạng sẵn bằng
  `localized`/`SessionFormat`.
- **Số đứng một mình** (ô của bảng câu hỏi, danh sách số câu ở Rà soát, số câu của phần và số thứ tự câu trong cây soạn
  đề, "/ 2.000" ở Trước khi thi, "Số câu đúng 1.234/2.000", "Số câu"/"Số phần" của PDF đề) có ngăn nghìn theo ngôn ngữ
  giao diện qua `Text(n, format: .number)` hoặc `InterfaceLocale.number(_:)`, không tạo khoá chỉ có số trong catalog.
- **Phần trăm** qua `IntegerFormatStyle.Percent` (`InterfaceLocale.percent`, `LibraryFormat.percent`,
  `SessionFormat.percent`), không ghép dấu `%` tay; khoá có phần trăm nhận chuỗi đã định dạng ("Đậu từ %@").
- **Thang 1000** (Nt0 chốt 2026-10-17, ngoại lệ ở mục Ngôn ngữ): mọi chỗ hiện giá trị thang 1000 (Kết quả "72% ·
  720/1000", PDF kết quả và PDF đề, ngưỡng "= 1000/1000" của soạn đề, cột "Thang 1000" của Lịch sử thi) đi qua
  `InterfaceLocale.scale1000(_:)`: chữ số trơn ở mọi ngôn ngữ. Trước đó cột Lịch sử thi và dòng của soạn đề ra "1.000".
- **Không đổi:** đồng hồ đếm giờ (`mm:ss`) không đổi
  (chỉ chữ số và `:`). Tên file gợi ý giữ dạng cố định `yyyy-MM-dd HHmm` (export-print.md). Lỗi, cảnh báo của
  LibraryData, AuthoringData, ExamImport, ExamKit, ExamFile: từ bước 7b tầng giao diện dựng câu theo mã, số theo ngôn ngữ
  giao diện (ghi chú bước 7b); câu tiếng Việt của các target đó chỉ còn cho nhật ký, số không ngăn nghìn như trước.
- **Kiểm:** test khoá dạng vi/en bằng locale tường minh (`InterfaceLocaleTests` của LibraryFeatureTests: chọn ngôn ngữ
  theo catalog (`en` khi catalog chưa có `en` → `vi`), bỏ vùng, số, phần trăm, ngày giờ, dung lượng, ba đường tra chữ,
  `Text` của SwiftUI đọc lại trên PDF; thêm ở SessionFeature, ReportFeature, AuthoringFeature);
  `scripts/check_localization.py` luật `region-locale` báo `Locale.current`/`.autoupdatingCurrent`, `FormatStyle`/
  `.formatted(…)` không có locale (kể cả `.formatted(date:time:)` và mã trong nội suy `\(…)`), `Date.FormatStyle` không
  có `calendar:`, lớp `…Formatter()` cũ và hàm tĩnh của chúng, `String(format:)` không locale; luật `scene-locale` báo
  scene của StudentShell/AdminShell thiếu `.interfaceLocale()`; UI test luồng 1 kèm Xuất PDF kết quả (`PracticeFlowUITests`) chạy
  với Region `en_US` và giao diện tiếng Việt, PDF phải có ngày giờ nộp dạng tiếng Việt. Các `locale:` tường minh của
  hàm trình bày (để test) chỉ áp cho ngày giờ, phần trăm, dung lượng; số trong chữ qua catalog luôn theo
  `InterfaceLocale.current`.

### Ghi chú hiện thực (giai đoạn 5, bước 7b: thông báo lỗi theo mã)

Phương án 2 (thông báo lỗi kiểm đề, đọc file, thư viện, import dịch theo mã ở tầng giao diện; lõi không đổi vì dịch)
làm như sau. Quyết định và lý do ở plan giai đoạn 5, Decisions bước 7b.

- **Lõi có mã và đối số:** `ValidationIssue` có `code`, `location` và `arguments` (`IssueArguments`: chuỗi, giá trị,
  giới hạn, mã lựa chọn, nơi xuất hiện trước), đủ để dựng lại câu; `ExamFileError` mọi case mang dữ liệu có mã
  (`invalidJSON(JSONProblem)`, `migrationFailed(from:reason: MigrationProblem)`, `writeFailed(WriteProblem)`). `message`
  và `errorDescription` vẫn là câu tiếng Việt cũ cho nhật ký, script, test; kết luận đọc/kiểm đề không đổi.
- **Target dữ liệu:** LibraryData (`FileProblemReason` cho trạng thái file, lỗi thêm đề, đề mẫu; `LibraryError`,
  `LibraryStoreIssue`), AuthoringData (`ExamEditError`), ExamImport (`ImportError` với `ImportReadProblem`,
  `XMLProblem`, `ImportSizeLimit`, `VceProblem`; mục báo cáo `ImportReportEntry.detail: ImportIssueDetail`) trả mã và đối
  số; câu tiếng Việt chỉ ở `logMessage`/`logDescription` (nhật ký, test). Các kiểu lỗi đó không theo `LocalizedError`.
  Không target dữ liệu nào có catalog.
- **Tầng giao diện dựng câu:** `ErrorMessages` (InterfaceCore từ bước I1 của plan iOS, trước đó LibraryFeature: kiểm
  đề, gói đề, Thư viện; SessionFeature, AuthoringFeature và bản iOS dùng chung) và `AuthoringMessages` (AuthoringFeature: sửa đề, import, vị trí trong file gốc). Mỗi tổ
  hợp mã × loại vị trí × biến thể là một khoá câu trọn vẹn có chỗ trống; danh sách (đường dẫn JSON, chữ cái lựa chọn,
  cặp mojibake, mục RVF) nối bằng dấu câu từ cụm có khoá riêng. Câu của hệ thống (Cocoa, POSIX, bộ phân tích XML) và chi
  tiết kỹ thuật (tên kiểu, mô tả của bộ giải mã) đặt nguyên vào chỗ trống.
- **Chữ người dùng thấy không đổi** ở giao diện tiếng Việt, trừ hai thay đổi có chủ ý: (1) số theo ngôn ngữ giao diện
  (bước 7a): số đếm, độ dài, giới hạn, số dòng từ 1.000 có ngăn nghìn ("4.001 ký tự", "tối đa 33.554.432"); (2) giới hạn
  số entry của `.docx` ghi "(tối đa N entry)" thay "byte" (review #51 N-b, sửa câu sai đơn vị). Mã định danh (id phần
  `.vce`, loại câu, cờ, loại bản ghi RVF) và số phiên bản định dạng (`v1`, "định dạng v2"; review #51 N-a) giữ chữ số
  trơn.
- **Kho Thư viện:** model V1 (các thuộc tính lưu của `LibrarySchemaV1`) không đổi; chỉ cách chuyển giữa `FileVerdict` và
  các trường lưu đổi. `verdictReason` vẫn lưu câu tiếng Việt của lý do; đọc lại là `.stored(câu)` và không được dùng lại,
  nên mỗi file có vấn đề (File hỏng, Đề có lỗi, Có lỗi) được đọc lại một lần mỗi lần mở app (thẻ "Đang kiểm tra" rất
  ngắn rồi ra lý do theo ngôn ngữ giao diện); file Sẵn sàng và Cần app mới hơn vẫn dùng kết luận đã lưu. Nt0 chốt
  2026-10-17: chấp nhận cách đọc lại này thay vì lưu lý do có mã.
- **Kiểm:** test Swift so từng mã/case (tiếng Việt trùng câu của lõi/target dữ liệu cho cùng đầu vào; số từ 1.000 có
  ngăn nghìn; khoá có trong catalog, tra `en` chạy được): `ErrorMessagesTests` (LibraryFeature), `AuthoringMessagesTests`
  (AuthoringFeature), lõi `ExamValidatorArgumentTests`, `ExamFileProblemsTests`. Luật `core-text` của
  `scripts/check_localization.py` báo câu tiếng Việt của lõi/target dữ liệu đi lên giao diện (`.errorDescription`,
  `.localizedDescription`, `.failureReason`, `.logMessage`, `.logDescription`, `.logName`, `.message` của vấn đề kiểm
  đề theo tên biến hoặc kiểu khai báo trong file; vấn đề trong biến có kiểu suy ra mà tên khác thì luật không thấy, test
  so câu theo mã bù); câu hệ thống qua `ErrorMessages.systemDescription(of:)`. Bản `en` của các khoá mới thêm ở bước 7c
  như mọi khoá khác.
- **Tên mặc định app ghi vào đề** ("Đề mới", "Phần 1", "Phần N" khi thêm phần, "Phần chung" khi import): Nt0 chốt
  2026-10-17 theo **ngôn ngữ giao diện lúc tạo** (giao diện tiếng Anh: "New Exam", "Section 1"); sau khi tạo là nội dung
  đề, không dịch lại. Làm ở bước 7c (ghi chú bên dưới).

### Ghi chú hiện thực (giai đoạn 5, bước 7c: bản tiếng Anh)

- **Bản `en` cho mọi khoá của mọi catalog** (LibraryFeature, SessionFeature, ReportFeature, AuthoringFeature, AdminShell;
  hai `InfoPlist.xcstrings`), theo bảng thuật ngữ và các thuật ngữ đề xuất ở trên. Khoá và giá trị `vi` không đổi, trừ
  tên kiểu tài liệu (bên dưới) và các khoá mới/bỏ ghi ở đây. Viết bản `en` bằng script sửa đúng `localizations.en` của
  JSON rồi để `xcodebuild -exportLocalizations` (hai scheme) ghi lại theo định dạng của Xcode; chạy lại lần hai không đổi
  byte nào (`verify_local.sh` kiểm). Không dùng `-importLocalizations` vì XLIFF xuất ra không có biến thể plural cho khoá
  chưa có biến thể.
- **Số nhiều:** khoá một số đếm dùng biến thể plural `one`/`other` của `en` ("1 question" / "2 questions"); khoá có
  nhiều số mà tiếng Anh cần số nhiều dùng substitution (`%#@tên@`, `argNum`, `formatSpecifier`: "1 hour 5 minutes",
  "Import report for “x”: 1 question skipped · 2 warnings"); tiếng Việt một dạng. Chuỗi `en` có nhiều đối số dùng số vị
  trí (`%1$@`, `%2$lld`). Giới hạn lớn ("tối đa %lld ký tự") và số luôn ≥ 2 theo code ("%lld times" của cặp mojibake)
  không dùng plural.
- **Câu ghép tay** (review #51 N-f): cụm của `.vce` (tên trường viết thường "question text", lý do "the file is too
  short", mục RVF "image (RVF record -3) not supported" + " (lý do)" + "; the rest was skipped") dịch sao cho ghép vào
  câu ("Skipped unsupported content in question text: …. Check against the original file.", "The .vce file can’t be read:
  the file is too short. …") vẫn đọc được; không đổi dấu nối. Hai chỗ **đổi thành câu trọn vẹn** vì tiếng Anh không
  ghép được; chữ tiếng Việt không đổi: tiêu đề Thư viện trống theo bộ lọc trước đây ghép "Không có đề nào" với tên bộ lọc
  viết thường, nay mỗi bộ lọc một khoá ("Không có đề nào sẵn sàng" / "No Ready Exams", "Không có đề nào có vấn đề" / "No
  Exams with Problems"; `LibraryFilter.emptyTitle`); tiêu đề hộp báo khi thao tác soạn đề lỗi trước đây ghép "Không" +
  tên bước Hoàn tác viết thường + "được", nay mỗi thao tác một khoá (`EditAction.failureTitle`: "Không cấp id mới được" /
  "Couldn’t assign a new ID"; review độc lập #52 N1).
- **Tên kiểu tài liệu** trong `InfoPlist.xcstrings`: `vi` "Đề Exam Suite", `en` "Exam Suite Exam" (khoá là giá trị gốc
  của project.yml); tên app và bản quyền không dịch. `check_localization.py --built-apps` so chuỗi Info.plist của app đã
  build với bản của catalog từng ngôn ngữ, tên app bằng giá trị gốc.
- **Mọi catalog cùng ngôn ngữ** (review #50 N2): `--built-apps` đòi mọi `ExamFeatures_*.bundle` có chữ đã biên dịch trong
  hai app có cùng tập `*.lproj` với bundle LibraryFeature và có `en` (bundle có chữ mà không có trong `BUILT_APPS` cũng là
  lỗi; đối chứng âm: bundle thiếu `en.lproj`, thừa `fr.lproj`, LibraryFeature chưa có `en`); `CatalogLanguagesTests`
  kiểm bundle của `swift test` và ưu tiên "en-VN" ra `en` cho số ("1,234") và chữ của cả năm module.
- **Tên mặc định ghi vào đề theo ngôn ngữ giao diện lúc tạo** (Nt0 chốt 2026-10-17): AuthoringData có
  `DefaultContentNames` (tên đề mới, tên phần thứ N; mặc định `.vietnamese`), ExamImport nhận `sharedSectionTitle:`
  (mặc định `ImportDefaults.sharedSectionTitle` "Phần chung"); hai target dữ liệu vẫn không có catalog. AuthoringFeature
  truyền tên đã tra catalog của nó lúc tạo: **Đề mới** (⌘N, `ExamAuthoringDocument()`), **Thêm phần** và câu đầu của đề
  chưa có phần (`AuthoringEditor.contentNames`, lấy lúc mở cửa sổ), **Import đề…** (`ImportFlowModel.liveRunner`). Tiếng
  Anh: "New Exam", "Section N", "General Section". Số thứ tự của phần là chữ số trơn ("Section 1234", khoá "Phần %@"):
  tên là nội dung đề. Tên đã ghi không dịch lại; tên gợi ý bỏ qua tên phần đã có, so không phân biệt hoa thường. Câu
  VoiceOver đổi câu không thêm "Phần" trước tên phần dạng "Phần <số>" hoặc "Section <số>". Đề mẫu vẫn chỉ tiếng Việt
  (phương án 3).
- **Snapshot tiếng Anh** (review độc lập #52 S2): làm bài (Luyện tập, bảng câu hỏi mở), Kết quả, Xem lại bài ở 960×640,
  ảnh sáng (`SessionSnapshotTests`, `SnapshotHost.inLanguage`, ép ngôn ngữ cho cả tiến trình qua
  `InterfaceStrings.processLanguageOverride` vì SwiftUI dựng lại view cả ngoài task của test; suite snapshot chạy tuần
  tự). Model không giữ chữ đã tra trong `static let` (tính mỗi lần đọc), để chữ theo ngôn ngữ đang tra.
- **Kiểm:** `--require-en` bật (mục Kiểm); test tra `en` theo locale cố định ở mỗi module (`LocalizationTests` của
  LibraryFeature, SessionFeature, ReportFeature, AuthoringFeature: thuật ngữ, câu có đối số, plural với 1 và 2,
  substitution; AdminShell trong `CatalogLanguagesTests`); `EnglishResultsReportTests` dựng PDF kết quả từ Kết quả + Xem
  lại với chữ `en` rồi đọc lại bằng PDFKit (nhãn tiếng Anh, nội dung đề tiếng Việt nguyên văn, không còn nhãn tiếng
  Việt), nhờ `InterfaceStrings.languageOverride` (task-local, chỉ cho test; app không đặt); `DefaultContentNamesTests`,
  `SharedSectionTitleTests`, `ExamStructureTests` cho tên mặc định; UI test `EnglishInterfaceUITests` (Thư viện, Trước khi thi, màn Làm bài, Rà soát & nộp tiếng Anh;
  `IsolatedApp(language: .english)`, `InterfaceLanguageCheck`: phần tử chỉ có chữ giao diện không có chữ cái ngoài ASCII,
  không phần tử nào mang nguyên chữ giao diện tiếng Việt đã biết; nội dung đề mẫu bị loại). Test cũ so chữ tiếng Việt
  không đổi (tiến trình test khoá `vi`). Snapshot chủ yếu tiếng Việt; có thêm ba ảnh tiếng Anh (làm bài, Kết quả, Xem
  lại bài; mục Snapshot tiếng Anh ở trên).
- **Ghi nhận khi thử:** Helvetica Neue của PDF ghép "ffi" thành một ký tự (U+FB03) nên PDFKit đọc lại "oﬃcial" (ảnh
  hưởng chép, tìm, VoiceOver, kể cả nội dung đề tiếng Anh); test tạm so sau NFKC. Đã sửa ở bước 8a (mục dưới).

### Ghi chú hiện thực (giai đoạn 5, bước 8a: bố cục, Dark Mode, PDF)

- **Snapshot sáng/tối các màn chính** (mục Dark Mode và tương phản: "Kiểm"): làm bài (câu dài 10 lựa chọn, ảnh lớn,
  Luyện tập đã kiểm tra), Trước khi thi, Kết quả, Xem lại bài (`hideAnswers`, câu đã sửa), Thư viện lưới và danh sách,
  soạn đề (câu dài, câu có ảnh và lỗi, báo cáo import): mỗi màn có ảnh sáng và ảnh tối. PDF luôn sáng: trang 1 PDF kết
  quả và PDF đề (export-print.md, Kiểm chứng). Chữ và biểu tượng vibrant trên kính (thanh bên, inspector) được vẽ đúng
  hơn khi chụp (docs/process/snapshot-tests.md), nên ảnh tối thấy được chữ thanh bên và ảnh sáng thấy được biểu tượng
  phụ; kính và vật liệu (`.bar`) vẫn chỉ kiểm tay.
- **Tương phản biểu tượng phụ của cây đề** (`.secondary` của hệ thống trong thanh bên, theo vibrancy): sáng 4,74:1 trên
  nền trắng (~4,0:1 trên nền kính sáng), tối 6,77:1, đạt "biểu tượng ≥ 3:1"; đo trên ảnh snapshot (plan giai đoạn 5,
  Decisions 2026-10-18). Màu hệ thống không vào bảng màu (`LibraryPalette`, `AuthoringPalette`); test tương phản cho mọi
  bảng màu và nền mờ là việc của bước 8b. Cùng cách đo, **chữ** `.secondary` có chỗ dưới 4,5:1 (đoạn xem trước ở thanh
  bên Xem lại bài 4,06:1, trên dòng đang chọn 3,72:1; dòng đang chọn ở giao diện tối 4,45:1; số đếm thanh bên Thư viện
  4,42:1; review độc lập #53): không sửa, màu ngữ nghĩa của hệ thống được miễn (Nt0 chốt 2026-10-18, mục Dark Mode và
  tương phản).
- **PDF không chữ ghép:** chữ Helvetica Neue của PDF tắt chữ ghép thường (`ReportTypography`: `CTFont` với
  `kLigaturesType`/`kCommonLigaturesOffSelector` và OpenType `liga` = 0), nên "official", "ffi", "fl" đọc lại nguyên
  văn (chép, tìm trong Preview, VoiceOver), cả nhãn tiếng Anh và nội dung đề. SF Mono (mã inline) không có chữ ghép
  thường. Test: `ReportRendererTests.noLigatures`, `EnglishResultsReportTests` (không còn so sau NFKC).

### Ghi chú hiện thực (giai đoạn 5, bước 8b: trợ năng)

- **VoiceOver theo bảng mục tiêu:** câu đọc nằm ở model/hàm trình bày và có test ("Test câu đọc" của bảng): Kết quả
  (`ResultsModel.verdictAccessibilityLabel`: Đậu/Trượt, điểm, ngưỡng đậu, so với lần trước; khối điểm là đề mục;
  `ResultSectionRow.accessibilityLabel`: tên, đúng/tổng, %, "Phần yếu nhất"), Xem lại bài (`AnswerReviewRow`,
  `ReviewOption.accessibilityLabel`), Lịch sử thi (`LibraryAccessibility.historyRowCells`, chính là chữ các ô của bảng: ô
  Thang 1000 đọc "850/1000"),
  hành động trợ năng của thẻ (`ExamActions.accessibilityActions`, như menu chuột phải, bỏ mục bị tắt), xem trước của Soạn đề
  (đọc như lựa chọn của cửa sổ làm bài, thêm "Đáp án đúng"). Nội dung đề có Markdown đọc chữ trơn (`PlainMarkdown`), kể cả
  dòng cây đề (trên cây vẫn hiện nguyên văn). Ảnh trong trình soạn câu nhãn "Ảnh của câu hỏi" như cửa sổ làm bài. Thêm
  `.isHeader` cho: lớp phủ Tạm dừng, hai danh sách và "Bảng câu hỏi" của Rà soát, tiêu đề Thông tin đề, dải thông báo có
  tiêu đề, danh sách "Không thêm được", tiến độ và hộp xác nhận Import đề, tóm tắt báo cáo import.
- **Thông báo còn thiếu:** Import xong ("Đã import “x”: <tóm tắt>", ưu tiên cao vì cửa sổ soạn đề mới nhận tiêu điểm; lỗi
  là hộp báo của AppKit, VoiceOver tự đọc); kiểm đề có **thêm** lỗi ("Kiểm đề: N lỗi mới"; kiểm chạy sau khi ngừng gõ 250
  ms, lỗi giảm hay giữ nguyên và lần kiểm đầu khi mở cửa sổ không đọc); lưu xong ("Đã lưu “x.exam”"): lưu là của macOS,
  nên app theo dõi lệnh **Lưu**/**Lưu thành…** của cửa sổ (`NSMenu.didSendActionNotification`) rồi chờ document có file
  và hết "Đã sửa" **và** file thật sự được ghi sau lệnh (ngày sửa file mới hơn, hoặc file khác với Lưu thành…; review
  #54 S3: Lưu thành… bị huỷ không đọc) (`SaveAnnouncementObserver`); tự lưu không đọc. Xem lại bài vẫn đọc "Câu N trên M, <trạng thái>" khi đổi
  câu bằng ←/→ (đã có trước bước 8b; cột "Thông báo tự động" của bảng ghi "—" cho màn này, nghĩa là không bắt buộc).
- **Kiểm trợ năng tự động** (phương án 7): `AccessibilityAuditor` (Apps/UITestSupport) chạy `performAccessibilityAudit`
  với mọi loại kiểm có trên macOS (`contrast`, `elementDetection`, `hitRegion`, `sufficientElementDescription`, `action`,
  `parentChild`) một lần mỗi màn: Học viên Thư viện, Trước khi thi, làm bài, Rà soát & nộp, Kết quả, Xem lại bài
  (`PracticeFlowUITests`), hộp chọn In (đoạn xuất PDF của `PracticeFlowUITests`); Admin cửa sổ soạn đề, Trước khi thi của Thử đề này
  (`NewExamFlowUITests`), hộp xác nhận và báo cáo Import đề (`ImportExamUITests`). **Không có trên macOS, bỏ:**
  `dynamicType`, `textClipped`, `trait` (SDK chỉ khai báo cho iOS/tvOS/watchOS); chữ bị cắt và cỡ chữ lớn kiểm bằng
  snapshot 150% và test tay. Vấn đề của mọi màn gom lại, test thất bại một lần khi kết thúc (đủ danh sách trong một lần
  chạy); ngoại lệ ghi loại kiểm, phần tử, lý do trong `AccessibilityAudit.swift`. Lần chạy đầu (`verify_local.sh --uitest`
  trên 6c59532) và các lần chạy riêng sau đó: **sửa trong app** nhóm gộp không có vai trò (dòng Xem lại bài, lựa chọn của
  xem trước, khung giải thích, đồng hồ, dòng báo cáo import: vai trò chữ tĩnh; dòng cây đề: vai trò nút có hành động chọn
  dòng, để câu đọc nằm ở nhãn cùng phần tử với định danh), dòng thông tin Kết quả (một câu
  "Nhãn, giá trị"), dòng báo cáo import bấm được (hành động), nhãn danh sách (không lặp vai trò "danh sách"), nhóm không tên
  (lưới thẻ, ô của từng phần ở bảng câu hỏi, danh sách số câu Rà soát, báo cáo import), nhãn của nút Sắp xếp/Lọc, chữ ô số
  Rà soát (`.primary` trên nền trung tính). **Ngoại lệ** (mỗi cái khớp đúng phần tử): (a) chữ màu hệ thống (`.secondary`,
  chữ vibrant, tiêu đề cửa sổ) và chữ màu hệ thống đã biết ở cửa sổ không phải cửa sổ đang dùng (màu của bảng màu không
  được miễn theo trạng thái cửa sổ); (b) phần tử của macOS (thanh menu, nút của
  cửa sổ, khung chứa của split view/inspector/sheet/`.searchable`, nút menu của thanh công cụ chỉ có AXShowMenu, quan hệ
  cha/con không chỉ ra phần tử); (c) báo nhầm (lựa chọn có chữ "nút" trong nội dung đề; khung giải thích có test số).
- **Tương phản:** test mọi bảng màu và nền nhạt trên nền thật (`PaletteContrastTests`: nền đo được cộng nền cửa sổ thật
  `windowBackgroundColor` đọc lúc chạy ở sáng và tối; màu của bảng làm chữ nhỏ ≥ 4,5:1 vì "Đúng", "Sai", "Đã đánh dấu"…
  mang màu đó; chữ `.primary` trên mọi nền pha màu; hàng lựa chọn đã chọn trên nền cửa sổ của **macOS 26 và macOS 15**:
  `#FFFFFF`/`#ECECEC`, tối `#1E1E1E`/`#323232`, review độc lập #54 S2). Màu đổi theo test (mức thấp nhất trên mọi nền):
  xanh sáng `#1E7B34` → `#196B2D` (3,80:1 → 4,70:1), cam sáng `#A35200` → `#934A00` (3,97:1 → 4,64:1), đỏ sáng `#C42B1C`
  → `#B22719` (4,03:1 → 4,68:1), đỏ tối `#FF6961` → `#FF918A` (3,50:1 → 4,69:1). Nhãn Đúng/Sai sau Kiểm tra đáp án vẽ ngoài
  nút lựa chọn bị khoá (nút khoá làm mờ cả nội dung, nhãn chỉ còn ~2,2:1; review #54 S1); `CheckedAnswerContrastTests` đo
  trên ảnh chụp thật. Màu của bảng trên dòng đang chọn của danh sách/bảng (nền teal, burgundy) thành chữ của hệ thống
  (`paletteForeground`, `backgroundProminence`); cây đề chọn bằng burgundy đặc `#801638` (chữ trắng ~10:1; tint của cửa sổ
  ở giao diện tối là `#F7A1B8`). Độ mờ của nền nhạt, viền nằm trong `LibraryPalette`; `scripts/check_colors.py` chặn hex
  và hàm dựng màu ngoài file bảng màu.
- **Reduce Transparency:** nền có độ trong mà app đặt (`.bar` của thanh dưới cây đề, thanh lỗi, báo cáo import, tiêu đề
  phần của bảng câu hỏi; vật liệu của thông báo ở chân Thư viện, lớp phủ kéo thả; nền nhạt pha màu của dải thông báo, nhãn
  Đề mẫu, hàng lựa chọn đã chọn; nền trung tính của khung giải thích, ô số Rà soát, rãnh thanh điểm) đi qua
  `AdaptiveBackground`: bật Reduce Transparency thì thành màu đặc (nền pha màu: màu đã trộn sẵn trên nền cửa sổ, đúng màu
  test tương phản tính; `.bar`, vật liệu: nền cửa sổ). **Reduce Motion:** dải thông báo đã có; thêm cuộn tới thẻ đang
  chọn của lưới Thư viện không hiệu ứng.
- **Cỡ chữ nội dung** (phương án 5): `ContentZoomLevel` 100/115/130/150%, khoá `@AppStorage` `content.zoomPercent` (một mức
  cho cả app, `defaults` của scene: bản app thật là `defaults` của bundle ID, UI test là suite trong thư mục tạm của
  `AppLaunchStorage`; `swift test` không ghi `defaults` của app, snapshot dùng suite tạm `ZoomDefaults`). Menu **Xem**
  (View; tài liệu trước 2026-10-18 gọi "Hiển thị"): **Phóng to** ⌘+ (cả ⌘= như Safari, không cần ⇧ trên bàn phím Mỹ: cửa sổ có nội dung câu bắt phím ⌘= của chính nó; review
  #54 S4), **Thu nhỏ** ⌘−, **Cỡ thật** ⌘0 (en "Zoom In", "Zoom Out", "Actual Size"; "Thu nhỏ" trùng tên Cửa sổ › Thu nhỏ của
  macOS tiếng Việt, giữ theo phương án 5), tắt ở giới hạn và khi cửa sổ
  đang dùng không có nội dung câu (Thư viện, Kết quả, Import đề, soạn đề khi ẩn xem trước). Đổi cỡ: nội dung câu của cửa
  sổ làm bài (đầu câu, nội dung, gợi ý số đáp án, lựa chọn, kết quả Kiểm tra đáp án, giải thích), chi tiết câu của Xem lại
  bài (kể cả dòng báo "đã sửa sau lần thi"), xem trước của Soạn đề. Không đổi: thanh công cụ, đồng hồ, thanh nút, bảng câu
  hỏi, Rà soát, danh sách câu của Xem lại bài, dải cảnh báo giờ, cây đề, trình soạn. Cỡ thật dùng đúng phông như trước;
  phóng to nhân cỡ của kiểu chữ macOS (body 13 pt…). Nhãn "Đáp án đúng" của xem trước xuống dòng khi cột hẹp (trước đây
  `.fixedSize()` tràn ở 150%). Snapshot 150% ảnh sáng: làm bài (câu dài, đầu và cuối), Luyện tập đã kiểm tra, Xem lại bài,
  xem trước của Soạn đề.

## Phương án đã chốt (Nt0 duyệt 2026-10-16)

1. **Chọn ngôn ngữ:** theo macOS (thứ tự ngôn ngữ ưu tiên, hoặc ngôn ngữ riêng cho app trong System Settings); không có
   ô chọn ngôn ngữ trong app.
2. **Phạm vi dịch:** toàn bộ chữ giao diện, kể cả thông báo lỗi từ lõi (tầng giao diện dịch theo mã lỗi; ExamKit/ExamFile
   không đổi). Nội dung đề không dịch.
3. **Đề mẫu** chỉ có tiếng Việt ở v1.
4. **Bản dịch tiếng Anh:** agent dịch theo bảng thuật ngữ; Nt0 duyệt bảng thuật ngữ và xem thử giao diện tiếng Anh
   khi test tay.
5. **Cỡ chữ nội dung câu:** có Phóng to / Thu nhỏ / Cỡ thật (⌘+ / ⌘− / ⌘0), bốn mức, chỉ vùng nội dung câu ở cửa sổ làm
   bài, Xem lại bài và xem trước của Soạn đề.
6. **Increase Contrast:** không thêm bảng màu riêng; kiểm tay.
7. **Kiểm trợ năng tự động:** `performAccessibilityAudit` trong UI test ở mỗi màn mà luồng đi qua; lỗi audit làm test
   thất bại, ngoại lệ ghi tên và lý do trong test.
8. **Bảng mục tiêu VoiceOver theo màn** (mục VoiceOver) là tiêu chí của giai đoạn 5.
