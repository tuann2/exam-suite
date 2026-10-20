# Import đề từ file khác (bản Admin)

Thẩm quyền: tài liệu này (Nt0 yêu cầu 2026-10-16: trước mắt **`.txt`, `.docx`, `.vce`**). Kết quả import là một đề
theo [exam-format.md](exam-format.md), mở trong cửa sổ soạn đề ([authoring.md](authoring.md)). `.vce` phụ thuộc
ADR 0009 (Accepted).

Code: bộ chuyển đổi thuần (không giao diện) trong module riêng chỉ bản Admin link (ADR 0003), dùng Foundation,
`XMLParser` và ZIPFoundation (ADR 0006: không thêm thư viện; bộ đọc `.vce` chỉ Foundation); hộp thoại và báo cáo
trong `AuthoringFeature`.

**File mẫu**: các file thật trong `docs/archive/` (bộ câu hỏi có bản quyền của bên thứ ba) **không đưa vào git**
(`.gitignore`); chỉ dùng tại máy để thử bộ chuyển đổi. Test trong repo dùng file **tự soạn** đúng từng định dạng.

## Luồng

1. **Import đề…** (menu File, bản Admin) → chọn một file `.txt`, `.docx` hoặc `.vce`.
2. App đọc và chuyển đổi (chạy nền, có tiến độ cho file lớn; huỷ được). Tiến độ và hộp xác nhận (bước 3) ở **cửa sổ
   riêng "Import đề"** (gọi được cả khi chỉ có cửa sổ soạn đề đang mở); đóng cửa sổ đó là **Huỷ** (phương án 16).
3. **Hộp thoại xác nhận** (Nt0 chốt: hỏi khi import): tiêu đề, mã đề, **ngưỡng đậu (%)** và **thời gian Thi (phút)**,
   điền sẵn từ file nếu có (docx: `Passing Score: 800` → 80%, `Time Limit: 120 min` → 120). **Tiêu đề, ngưỡng đậu và
   thời gian là bắt buộc**: không có thì để trống và phải nhập. **Mã đề tuỳ chọn** (như `code` của exam-format.md): để
   trống thì đề không có mã; đã nhập thì phải khớp mẫu `[A-Za-z0-9._-]{1,32}` (phương án 18). Giá trị kiểm theo
   exam-format.md (tiêu đề 1–200 ký tự, ngưỡng 0–100, thời gian 1–600); **Import** chỉ bật khi mọi ô hợp lệ. Cùng tóm
   tắt: số phần, số câu, số câu bị bỏ, số cảnh báo. **Import** / **Huỷ**.
4. Mở **cửa sổ soạn đề chưa lưu** chứa đề đã chuyển (Nt0 chốt). Không ghi file nào tự động; admin xem, sửa, rồi Lưu
   thành `.exam`.
5. **Báo cáo import** mở cùng cửa sổ (ẩn/hiện được): từng câu bị bỏ hoặc có cảnh báo, kèm vị trí trong file gốc
   (số câu, số dòng với txt) và lý do. Lỗi kiểm tra của đề (exam-format.md) hiện trên thanh lỗi như mọi đề.

- **Id**: `id` đề, phần, câu sinh **ngẫu nhiên mỗi lần import** (Nt0 chốt). Import lại cùng file là một đề mới; muốn
  giữ lịch sử thi thì sửa trên `.exam` đã lưu.
- Câu thiếu dữ liệu tối thiểu (không có lựa chọn nào) bị **bỏ** và ghi vào báo cáo. Câu có dữ liệu nhưng vi phạm ràng
  buộc (không có đáp án đúng, đáp án ngoài lựa chọn, một lựa chọn…) vẫn **giữ** để sửa trong cửa sổ soạn đề; thanh lỗi
  chỉ ra.
- Loại câu: 1 đáp án đúng → Một đáp án; ≥ 2 → Nhiều đáp án.
- Chuỗi chuẩn hoá NFC, bỏ khoảng trắng thừa hai đầu.
- **Lỗi mã hoá trong file gốc** (mojibake, Nt0 chốt 2026-10-16, thu hẹp cùng ngày sau review PR #32; áp dụng cho cả
  ba định dạng): coi mỗi ký tự là một byte Windows-1252 (các byte chưa định nghĩa `0x81`, `0x8D`, `0x8F`, `0x90`,
  `0x9D` ứng với U+0081, U+008D, U+008F, U+0090, U+009D); một dãy ký tự khớp trọn vẹn thành **đúng một ký tự UTF-8
  nhiều byte hợp lệ** là dãy nghi lỗi.
  - **Tự sửa** chỉ dãy chắc chắn: 3 ký tự, bắt đầu bằng `â` (0xE2), ký tự thứ hai là `€`, U+0081 hoặc `‚` (byte
    0x80–0x82), giải ra một ký tự trong U+2000–U+20CF (dấu câu chung và tiền tệ, ví dụ `â€™` → `’`, `â‚«` → `₫`),
    **trừ** ký tự định dạng/phân cách vô hình U+200B–U+200F, U+2028–U+202E, U+2060–U+206F (ví dụ `â€‹` → U+200B):
    các dãy này chỉ cảnh báo. Mỗi câu có chỗ đã sửa ghi một **cảnh báo** (vị trí, số chỗ, chuỗi trước/sau) để admin
    kiểm lại.
  - Mọi dãy nghi lỗi khác (ví dụ `Ã©`, `Â` + NBSP) **chỉ cảnh báo, không đổi chữ** (vị trí, số chỗ, các dãy): chữ hoa
    tiếng Việt đứng sát `”`, `®`, NBSP (`“CÓ”`, `NESCAFÉ®`) cũng khớp cách đọc trên nên không được tự sửa.
- File không đọc được (không phải UTF-8 với txt, zip hỏng với docx, `.vce` không giải được) → báo lý do, không mở cửa
  sổ. File **không có câu nào** (hoặc mọi câu đều bị bỏ) cũng là lỗi: báo lý do (kèm số câu bị bỏ), không mở cửa sổ.
- **Giới hạn** (chống file dựng có chủ đích; review độc lập PR #38): báo cáo import giữ **chi tiết 1.000 mục đầu của mỗi
  loại mục** (nên cảnh báo không chiếm chỗ của mục bỏ câu); các mục sau của loại đó gộp thành một dòng tóm tắt ("… và N
  mục tương tự"; chỉ một mục vượt thì giữ chi tiết), số câu bị bỏ và số cảnh báo ở hộp xác nhận vẫn đếm đủ. Đọc bảng
  phần/nhóm lớn huỷ được. Kích thước file: `.txt` tối đa 32 MiB (bằng trần `exam.json`); `.docx` theo trần giải nén của gói đề (mỗi
  phần XML 128 MiB, mỗi ảnh 50 MiB, tổng 1 GiB, 20.000 entry); `.vce` tối đa 64 MiB (file mẫu 0,35–1,35 MB).
- **Markdown**: văn bản trơn chỉ được thoát ký tự Markdown (`\*`, `\_`, `\&`…) khi đọc như Markdown nó sẽ hiển thị khác
  file gốc (ví dụ `*a*` thành chữ nghiêng); không thì giữ nguyên để dễ sửa (`s3:*`, `snake_case`).

## `.txt`

Mẫu (như mẫu .txt thật A, ~1.000 câu):

```text
Q1:
<đề bài, có thể nhiều dòng>
A. <lựa chọn, có thể nhiều dòng>
B. <…>
Correct Answer: A
Explanation: <tuỳ chọn, có thể nhiều dòng>

Q2:
…
Correct Answer: A,C
```

- Mã hoá **UTF-8** (có hoặc không BOM); khác thì báo lỗi.
- **Đầu câu**: dòng chỉ gồm `Q<số>:` hoặc `QUESTION <số>` (không phân biệt hoa thường). Văn bản trước câu đầu tiên bị
  bỏ qua (ghi vào báo cáo nếu không rỗng).
- **Đề bài**: các dòng từ sau đầu câu tới lựa chọn đầu tiên.
- **Lựa chọn**: dòng bắt đầu bằng chữ in hoa `A`–`Z` liền sau là `.` hoặc `)` và một khoảng trắng; phải theo đúng thứ
  tự A, B, C… (dòng bắt đầu bằng chữ khác thứ tự được coi là dòng nối của phần trước). Các dòng sau đó tới lựa chọn kế
  tiếp hoặc dòng đáp án là phần nối của lựa chọn.
- **Khối câu không có dòng `A.`/`A)`** (trước dòng đáp án; Nt0 chốt 2026-10-16): lựa chọn đầu tiên là dòng nhãn đầu
  tiên, chữ gì cũng được; các lựa chọn sau phải liên tiếp từ chữ đó. Lựa chọn được **đánh lại A, B, C… theo vị trí**;
  chữ trong dòng đáp án đọc theo **chữ gốc** và đổi theo vị trí (lựa chọn B, C, D, E với đáp án `C` → lựa chọn A–D, đáp
  án B). Chữ đáp án không khớp lựa chọn nào vẫn là vi phạm (thanh lỗi chỉ ra). Ghi **cảnh báo** kèm vị trí. Câu có dòng
  `A.` giữ quy tắc trên.
- **Đáp án**: dòng `Correct Answer:` (hoặc `Answer:`) + chữ cái, phân cách bởi dấu phẩy, khoảng trắng hoặc viết liền
  (`A,C`, `A C`, `AC`).
- **Giải thích** (tuỳ chọn): dòng `Explanation:` và các dòng sau tới câu kế tiếp.
- **Văn bản lạc** giữa dòng đáp án và dòng `Explanation:` bị bỏ qua, ghi cảnh báo.
- **Nối dòng**: các dòng của một đoạn nối bằng một dấu cách (file chép từ PDF bị xuống dòng giữa câu); dòng kết thúc
  bằng `-` nối liền không dấu cách (`Cross-` + `Region` → `Cross-Region`); dòng trống tách đoạn (giữ là xuống đoạn
  trong Markdown).
- **Phần**: txt không có phần → một phần, tên là tên file (bỏ đuôi).
- Ảnh: không có.

## `.docx`

Mẫu: bố cục xuất từ VCE (như mẫu .docx thật):

```text
<Tiêu đề đề thi>
Number: MAU-001
Passing Score: 800
Time Limit: 120 min …
…
Exam A
QUESTION 1
<đề bài: nhiều đoạn, có thể có danh sách gạch đầu dòng/đánh số>
  A. <lựa chọn: đoạn trong danh sách đánh chữ hoa, có thể kèm đoạn nối>
  B. …
Correct Answer: D
Section: Part 2
Explanation
Explanation/Reference:
<giải thích: nhiều đoạn>
QUESTION 2
…
```

- Đọc `word/document.xml` (đoạn, chữ, danh sách) và `word/numbering.xml` (kiểu đánh số); ảnh từ `word/media/` qua
  `word/_rels/document.xml.rels`.
- **Đầu đề** (trước `QUESTION 1`): đoạn đầu tiên là tiêu đề; `Number:` → mã đề (nếu khớp mẫu mã của schema, không thì
  bỏ và cảnh báo); `Passing Score: N` → N/10 % **làm tròn gần nhất, nửa lên** (725 → 73 %, 724 → 72 %) nếu N > 100,
  ngược lại N % (ngoài 0–100 % hoặc không phải số → để trống, cảnh báo); `Time Limit: N min` → N phút. Các giá trị này
  chỉ điền sẵn vào hộp thoại xác nhận.
- **Đầu câu**: đoạn `QUESTION <số>`.
- **Lựa chọn**: đoạn trong danh sách Word có kiểu đánh số **chữ in hoa** (`upperLetter`) ở cấp đầu, theo thứ tự; hoặc
  đoạn bắt đầu bằng `A.`/`A)` như txt khi file không dùng danh sách (kể cả quy tắc khối câu không có `A.`: đánh lại
  theo vị trí, đáp án đổi theo, cảnh báo). Đoạn không đánh số ngay sau một lựa chọn (trước lựa chọn kế tiếp hoặc
  `Correct Answer`) là phần nối của lựa chọn đó, **ghép bằng xuống dòng**. Danh sách gạch đầu dòng/đánh số khác trong đề
  bài là một phần của đề bài: kiểu `bullet` → `- `, mọi kiểu đánh số khác → `1. `, `2. `… (theo `numPr` của đoạn; đánh
  số đến từ kiểu đoạn `pStyle` không được đọc).
- **Đáp án**: `Correct Answer:` như txt; các nhãn `Section:`, `Explanation` có thể dính cùng đoạn với đáp án và được
  tách ra.
- **Phần**: `Section: <tên>` gán câu vào phần tên đó (theo thứ tự xuất hiện); `Section: (none)` hoặc thiếu → phần tên
  là tiêu đề nhóm gần nhất (`Exam A`), không có thì "Phần chung". Tiêu đề nhóm (đoạn `Exam <chữ in hoa>`) chỉ được nhận
  **ngoài đề bài**; trong đề bài nó là chữ của đề bài.
- **Giải thích**: sau `Explanation/Reference:` tới câu kế tiếp; nhãn `Explanation` đứng riêng (hoặc `Explanation:`)
  cũng mở giải thích; bỏ các nhãn lặp (`Explanation`, `Explanation/Reference:`, `Section: …`). Văn bản lạc giữa dòng
  đáp án và nhãn giải thích bị bỏ qua, ghi cảnh báo.
- **Định dạng chữ**: đậm/nghiêng → Markdown `**…**` / `*…*`; định dạng khác bỏ.
- **Ảnh**: ảnh trong đề bài thành ảnh của câu (một ảnh mỗi câu theo schema); ảnh thứ hai trở đi, hoặc ảnh trong lựa
  chọn/giải thích, bị bỏ và ghi vào báo cáo. Định dạng ảnh ngoài danh sách của exam-format.md (ví dụ `emf`) bị bỏ và ghi
  vào báo cáo; khi đó ảnh **dùng được** kế tiếp trong đề bài thành ảnh của câu.
- Bảng: chuyển thành văn bản từng dòng, ô cách nhau bằng ` | `; ghi cảnh báo.

## `.vce`

Định dạng nhị phân độc quyền (Avanset VCE Designer/Player), không có tài liệu công khai. Nt0 chọn **đọc trực tiếp**
(2026-10-16) theo ADR 0009 (Accepted). Bộ đọc viết mới, chỉ Foundation, trong `ExamImport` (chỉ bản Admin); cách tìm
hiểu định dạng ở [docs/notes/vce-format.md](../notes/vce-format.md) (phân tích các file mẫu tại máy, đặc tả RVF công
khai), chi tiết cấu trúc ở mã nguồn. Ánh xạ sang cùng mô hình như docx, cùng luồng và báo cáo ở trên.

- **Biến thể đọc được**: magic `85 A8 02 01`. Trước khi đọc nội dung, bộ đọc kiểm magic, trường kích
  thước file và CRC-32 cuối file; sau đó đọc tuần tự, mọi độ dài và số lượng được so với phần dữ liệu còn lại (và
  `ImportLimits.vceBytes`, mặc định 64 MiB). Sai lệch bất kỳ (magic lạ, file cắt cụt, sai kích thước, sai CRC-32, độ
  dài vượt dữ liệu, bản ghi nhóm đề không đọc được, byte thừa sau danh sách câu) → lỗi "File .vce không đọc được: <lý do>",
  không mở cửa sổ; thông báo gợi ý import bản `.docx` xuất từ VCE.
- **Đầu đề** (chỉ điền sẵn hộp xác nhận): trường tiêu đề (rỗng → tên file bỏ đuôi); mã đề (không khớp mẫu mã của
  schema → bỏ, cảnh báo); điểm đậu N như `Passing Score` của docx (N > 100 → N/10 làm tròn nửa lên, 800 → 80 %; ngoài
  0–100 % → để trống, cảnh báo); thời gian (phút; âm hoặc quá 6 chữ số → để trống, cảnh báo).
- **Phần**: theo bảng phần của file, theo thứ tự xuất hiện. Câu có id phần −1 (không thuộc phần nào) hoặc id không có
  trong bảng → phần tên là **tên nhóm đề** (tương ứng `Exam A` của docx) khi file có **đúng một nhóm có tên**; không
  thì "Phần chung" (kể cả nhóm không tên: docx in `Exam A` nhưng `.vce` để trống, Nt0 chốt giữ "Phần chung"). Id lạ
  (khác −1) hoặc id có trong bảng nhưng phần không tên cũng vào phần thay thế, kèm cảnh báo nêu đúng lý do.
- **Bảng mã của chuỗi 1 byte** (mã, tiêu đề, tên phần, tên nhóm, chữ ANSI): ngoài ASCII thì đọc theo Windows-1252 và
  cảnh báo, mỗi trường một mục; byte chưa định nghĩa (0x81, 0x8D, 0x8F, 0x90, 0x9D) thành ký tự điều khiển vô hình theo
  quy ước ở Luồng, cảnh báo nói rõ để admin xoá hoặc sửa.
- **Nhiều nhóm đề**: đọc mọi bản ghi nhóm (số nhóm, mỗi nhóm `u8` + tên); câu không thuộc phần nào theo quy tắc trên,
  kèm **một cảnh báo mức file** rằng file có nhiều nhóm và cách nhóm câu không phần có thể khác VCE. **Không đoán** câu
  thuộc nhóm nào. Bản ghi nhóm không đọc được → lỗi "không đọc được".
- **Câu**: đề bài là khối nội dung đầu, **lựa chọn theo thứ tự khối** đánh chữ A, B, C…, giải thích là khối cuối. Số
  khối phải bằng số lựa chọn ghi trong bản ghi + 2, không thì bỏ câu (bố cục chưa biết). Quá 26 lựa chọn: từ lựa chọn
  thứ 27 nối vào Z, cảnh báo (như docx).
- **Đáp án**: chữ cái theo vị trí lựa chọn. Các file mẫu viết liền (`AC`); `A,C`/`A C` vẫn đọc nhưng cảnh báo vì khác
  mẫu. Cờ nhiều đáp án của bản ghi không khớp số chữ → cảnh báo. Đáp án rỗng → giữ câu, cảnh báo thiếu đáp án; ký tự
  khác chữ in hoa → cảnh báo không đọc được. Loại câu theo số đáp án đúng (1 → Một đáp án, ≥ 2 → Nhiều đáp án).
- **Văn bản RVF**: đọc mục văn bản lưu dạng văn bản (Unicode UTF-16, mỗi đoạn kết thúc U+2029; hoặc ANSI, đọc theo
  Windows-1252, ngoài ASCII thì cảnh báo bảng mã). Chữ có **kiểu chữ khác 0** (đậm, nghiêng…: chưa đọc bảng kiểu chữ)
  được **giữ dạng chữ thường**, chỉ bỏ định dạng, một cảnh báo mỗi câu (`formattingDropped`): không mất chữ. Đoạn của
  đề bài và giải thích thành đoạn Markdown (`\n\n`); đoạn của một lựa chọn ghép bằng **xuống dòng** `\n` (như đoạn nối
  lựa chọn của docx, phương án 14; Nt0 duyệt cho `.vce`); đoạn trống bị bỏ. Mỗi
  đoạn sửa mojibake theo quy tắc ở Luồng, rồi NFC, bỏ khoảng trắng hai đầu; thoát Markdown chỉ khi cần.
- **Giải thích**: bỏ các đoạn nhãn lặp ở đầu (`Explanation`, `Explanation/Reference:`, `Section: …`, có thể dính nhau
  trong một đoạn) như docx; chữ sau nhãn trong cùng đoạn được giữ. `Section: X` chỉ là nhãn lặp khi X là `(none)` hoặc
  trùng tên một phần trong bảng phần của file; khác thì là chữ của giải thích và được giữ (khối giải thích của `.vce`
  là chữ tự do; quy tắc docx không đổi). Giải thích rỗng → không có giải thích.
- **Chưa hỗ trợ** (chưa có file mẫu chứng minh cách đọc, không đoán):
  - Ảnh, đường kẻ, hotspot, bullet, bảng và mọi bản ghi RVF khác văn bản; chữ lưu dạng hex hoặc nhị phân: **bỏ phần
    đó, giữ phần còn lại** của đề bài/lựa chọn/giải thích,
    ghi cảnh báo kèm số câu và chỗ (đề bài, lựa chọn X, giải thích). Không đọc được tiếp sau phần lạ thì phần còn lại
    của khối đó cũng bị bỏ và được nêu trong cảnh báo.
  - Loại câu khác 5 (một/nhiều đáp án): **bỏ câu**, ghi báo cáo (`unsupportedQuestionType`).
  - Bản ghi câu không khớp bố cục: **bỏ câu**, ghi báo cáo. Mọi câu bị bỏ → lỗi, không mở cửa sổ.
  - Phiên bản `.vce` khác (magic khác): lỗi "không đọc được".
  - Định dạng chữ (đậm, nghiêng…): bỏ định dạng, giữ chữ (xem trên).
  - Mô tả đề, phiên bản đề, ngày tạo/sửa, tiêu đề tình huống (case study): không đọc.

## Kiểm chứng cần có

- Test bộ chuyển đổi (không giao diện) trên file **tự soạn** cho từng quy tắc ở trên: nối dòng, gạch nối, lựa chọn
  nhiều dòng, đáp án nhiều chữ, nhãn dính đoạn, danh sách trong đề bài, phần, giải thích, ảnh, câu bị bỏ, mã hoá sai,
  file hỏng; đề sinh ra ghi được bằng `ExamPackageWriter` và đọc lại ra đúng dữ liệu.
- Thử tại máy trên file thật trong `docs/archive/` (không commit): mẫu .txt thật A ra 1.019 câu (0 câu bỏ, sau quy tắc
  khối câu không có `A.`), mẫu .docx thật ra 40 câu, mẫu VCE 1 ra 40 câu (0 bỏ), mẫu VCE 2 và 3 (600 và 419 câu) có
  câu nhiều đáp án (0 bỏ); ghi số câu, số câu bỏ, số cảnh báo vào PR.
- `.vce`: test trên file tự dựng theo bố cục của bộ đọc (`VceTestWriter`): magic, kích thước, CRC-32, cắt cụt ở
  mọi vị trí, độ dài khổng lồ, đột biến ngẫu nhiên không crash/treo; bản ghi RVF và loại câu chưa hỗ trợ.

## Phương án đã chốt (Nt0 duyệt 2026-10-16)

1. Định dạng trước mắt: `.txt`, `.docx`, `.vce` (đọc trực tiếp, theo ADR 0009).
2. Kết quả import mở cửa sổ soạn đề chưa lưu, không ghi file tự động.
3. Ngưỡng đậu và thời gian: hỏi khi import (điền sẵn nếu file có).
4. `id` ngẫu nhiên mỗi lần import.
5. File mẫu thật không vào git; test dùng file tự soạn.
6. txt chỉ nhận UTF-8.
7. Câu không có lựa chọn nào thì bỏ; câu vi phạm ràng buộc khác thì giữ để sửa.
8. txt: một phần, tên là tên file. docx: phần theo `Section:`, thiếu thì theo nhóm `Exam A`/"Phần chung".
9. docx: chỉ ảnh đầu tiên trong đề bài được giữ; đậm/nghiêng thành Markdown; bảng thành văn bản.
10. Lỗi mã hoá trong file gốc (mojibake): tự sửa dãy giải ra đúng một ký tự UTF-8, ghi cảnh báo từng câu; cả ba định
    dạng (2026-10-16, sau spike `.vce`); thu hẹp 2026-10-16 sau review PR #32: chỉ tự sửa dãy `â€…`/`â‚…` ra ký tự
    U+2000–U+20CF; dãy khác chỉ cảnh báo. Thêm 2026-10-16 sau re-review PR #32: dãy ra ký tự vô hình U+200B–U+200F,
    U+2028–U+202E, U+2060–U+206F cũng chỉ cảnh báo, không tự sửa.
11. `.vce`: Nt0 gửi thêm file mẫu thật có ảnh và câu nhiều đáp án (không vào git) để bước 6 kiểm cả hai trường hợp
    trên file thật (2026-10-16).
12. txt và lựa chọn dạng `A.` của docx: khối câu không có dòng `A.` thì lựa chọn bắt đầu từ dòng nhãn đầu tiên, đánh lại
    A, B, C… theo vị trí, đáp án đọc theo chữ gốc và đổi theo vị trí, ghi cảnh báo (2026-10-16, sau PR #32).
13. `Passing Score: N` với N > 100: N/10 làm tròn gần nhất, nửa lên (725 → 73 %, 724 → 72 %) (2026-10-16).
14. docx: ảnh sai định dạng bị bỏ thì ảnh dùng được kế tiếp trong đề bài được giữ; đoạn nối của lựa chọn ghép bằng xuống
    dòng; `Explanation` đứng riêng mở giải thích; văn bản lạc giữa đáp án và giải thích bị bỏ kèm cảnh báo; nhóm
    `Exam X` chỉ nhận ngoài đề bài; đánh số khác `bullet` thành `1. `, không đọc đánh số theo `pStyle` (2026-10-16).
15. Chung: file không có câu nào (hoặc mọi câu bị bỏ) là lỗi, không mở cửa sổ; chỉ thoát ký tự Markdown khi hiển thị
    sẽ khác file gốc (2026-10-16).
16. Tiến độ và hộp xác nhận của Import đề… ở cửa sổ riêng "Import đề" (không phải sheet trên cửa sổ Thư viện); đóng
    cửa sổ đó là Huỷ: không mở gì, không báo lỗi (Nt0 chốt 2026-10-16, PR #35).
17. `.vce` (2026-10-16, sau PR #38): chữ có kiểu chữ khác 0 giữ dạng chữ thường, bỏ định dạng, cảnh báo mỗi câu (không
    mất chữ); đoạn trong một lựa chọn ghép bằng xuống dòng, đề bài/giải thích bằng đoạn Markdown; câu phần −1 khi nhóm
    không tên → "Phần chung"; file nhiều nhóm đề vẫn đọc (mọi bản ghi nhóm), câu không phần → "Phần chung" hoặc tên nhóm
    khi có đúng một nhóm có tên, cảnh báo mức file, không đoán câu thuộc nhóm nào; bản ghi nhóm hỏng → lỗi.
18. Hộp xác nhận: tiêu đề, ngưỡng đậu, thời gian Thi bắt buộc; **mã đề tuỳ chọn** (để trống thì đề không có mã; đã nhập
    thì phải khớp mẫu mã của exam-format.md) (Nt0 chốt 2026-10-16, sau review độc lập PR #35).
19. Hình thức hộp xác nhận (Nt0 chốt 2026-10-19, lỗi beta G6.2, review độc lập #60 S1): bốn ô **có viền**
    (`.roundedBorder`), chữ canh trái, cùng độ rộng; nhãn bên trái, xuống dòng khi dài; dòng báo lỗi ngay dưới ô; **không
    có chữ gợi ý** trong ô. Cửa sổ "Import đề" cao vừa đủ nội dung (cả khi mọi ô báo lỗi, cả tiếng Anh) và đổi cỡ theo khi
    dòng báo lỗi hiện/ẩn. Lý do: ô mặc định của biểu mẫu kiểu macOS không viền, ô trống trông như không có ô; bản beta
    build 342 còn co mất cả bốn ô.
