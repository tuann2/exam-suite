# Định dạng đề `.exam`

Thẩm quyền: ADR 0002. Schema máy đọc: [`schema/exam-v1.schema.json`](../../schema/exam-v1.schema.json).
Hằng số trong code: `ExamFileFormat` (Packages/ExamKit/Sources/ExamFile).

## Gói

Một đề là **một file zip đuôi `.exam`**:

```text
Kien thuc chung.exam
├── exam.json          bắt buộc, UTF-8, ở gốc gói
└── media/             tuỳ chọn, ảnh của câu hỏi
    └── 9d5dc894e10f060d.png
```

- Ảnh đặt tên theo **16–64 ký tự hex đầu của SHA-256 nội dung** + đuôi gốc
  (`png`, `jpg`, `jpeg`, `gif`, `webp`, `heic`). Ảnh trùng nội dung chỉ lưu một lần.
- Không có file nào khác ở gốc gói. App bỏ qua entry lạ khi đọc, không ghi lại chúng.
  App chỉ nạp `exam.json` ở gốc và ảnh có tên đúng mẫu `media/<hash>.<ext>` ngay trong
  `media/`; thư mục, symlink, `__MACOSX/…`, `media/a/b.png`, ảnh sai tên đều bị bỏ qua.
- **Entry trùng tên** (hai `exam.json`, hoặc hai entry cùng một đường dẫn ảnh) → từ chối
  cả gói: Python lấy entry cuối, Swift lấy entry đầu, nên không cho tồn tại.
- **Giới hạn kích thước** khi đọc (`ExamPackageLimits`), vượt là từ chối cả gói:

  | Giới hạn | Mặc định |
  | --- | --- |
  | `exam.json` sau giải nén | 32 MiB |
  | Mỗi ảnh sau giải nén | 50 MiB |
  | Tổng giải nén của các entry được nạp | 1 GiB |
  | Số entry trong zip (kể cả entry bị bỏ qua) | 20.000 |
  | Độ sâu lồng của `exam.json` (cả hai bản app; đề hợp lệ sâu khoảng 7) | 32 cấp |

- **Gói thiếu ảnh** (câu có `image` nhưng file không có trong `media/`): bản Admin mở
  được, báo lỗi qua `ExamPackage.missingMedia` và **lưu được** (không chặn lưu); bản
  Học viên từ chối mở, nêu đường dẫn ảnh thiếu.
- UTType: `vn.io.nt0.exam`, conforms to `com.pkware.zip-archive`, đuôi `exam`. Bản Admin export
  kiểu (Owner, Editor); bản Học viên import (Alternate, Viewer). UTType đổi tên ngày 2026-10-18 (dự án cá nhân của
  Nt0); định dạng gói không đổi (`formatVersion`, trường, quy tắc kiểm), và macOS nhận file theo đuôi `.exam`, nên
  file `.exam` có từ trước vẫn mở được.

## `exam.json`

Cấu trúc Exam → Section → Question → Option. Ví dụ đầy đủ: `fixtures/exams/kien-thuc-chung/exam.json`.

| Trường | Bắt buộc | Ý nghĩa |
| --- | --- | --- |
| `formatVersion` | có | Luôn `1` ở v1 |
| `id` | có | UUID ổn định của đề |
| `title` | có | Tên đề, 1–200 ký tự |
| `code` | không | Mã đề ngắn `[A-Za-z0-9._-]{1,32}` |
| `passPercent` | có | Số nguyên 0–100 (xem [scoring.md](scoring.md)) |
| `timeLimitMinutes` | có | Số nguyên 1–600, thời gian mặc định của chế độ Exam |
| `hideAnswers` | không, mặc định `false` | `true`: khoá Practice, ẩn đáp án và giải thích khi xem lại |
| `instructions` | không | Markdown cơ bản |
| `sections[]` | có, ≥ 1 | `id` UUID, `title`, `questions[]` ≥ 1 |
| `questions[].type` | có | `single` hoặc `multiple` |
| `questions[].text` | có | Markdown cơ bản |
| `questions[].image` | không | `media/<hash>.<ext>` |
| `questions[].options[]` | có, 2–26 | `{ "id": "A", "text": "…" }` |
| `questions[].correct[]` | có, ≥ 1 | Mảng id lựa chọn; `single` đúng 1 phần tử |
| `questions[].explanation` | không | Markdown cơ bản |

**Markdown cơ bản** = đậm, nghiêng, code inline; hiển thị bằng
`AttributedString(markdown:)`. Không hỗ trợ bảng, ảnh inline, HTML.

## Ràng buộc liên trường (ngoài schema)

Schema không diễn tả được các quy tắc sau; `ExamValidator` trong ExamKit (giai đoạn 1)
và `scripts/validate_exam.py` phải cùng bắt:

1. `id` của đề, mọi section và mọi câu không trùng nhau. **So không phân biệt hoa/thường**
   (UUID so theo giá trị): `aaaa…` và `AAAA…` là trùng.
2. `options[].id` đúng thứ tự `A, B, C, …` theo vị trí (xáo đáp án là việc của phiên thi, không đổi file).
3. Mọi phần tử của `correct` phải là một `options[].id` của cùng câu; không lặp; câu `single` đúng một phần tử.
4. Mọi `image` phải trỏ tới file có trong `media/` của gói (so đúng tên, kể cả hoa/thường).

Trình soạn đề (Admin) báo lỗi nhưng **không chặn lưu**; bản Học viên từ chối mở đề vi phạm và báo rõ lỗi.

## Cách đếm và so khớp

Phương án đang dùng (đề xuất trong PR #5, được merge 2026-10-15; Nt0 có thể đổi), áp dụng cho
cả app lẫn `scripts/validate_exam.py`. Riêng khoá trùng, `null` và dấu phẩy thừa trong JSON:
script và bản Học viên (chế độ đọc nghiêm, từ PR #11) đều từ chối; bản Admin đọc được và hiện dòng "Bản Học viên sẽ từ chối đề này".

- **Độ dài** (`title`, `code`, `text`, `instructions`, `explanation`) đếm theo **Unicode
  code point**, đúng cách JSON Schema `minLength`/`maxLength` đếm (Swift
  `unicodeScalars.count`, Python `len`). Ví dụ `ệ` dựng sẵn là 1, `e` + hai dấu tổ hợp là 3.
- **Nội dung chỉ toàn khoảng trắng** là lỗi như nội dung rỗng: tên đề, tiêu đề section,
  nội dung câu, nội dung lựa chọn. Khoảng trắng = code point có thuộc tính Unicode
  **`White_Space`**, đúng 25 code point: U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680,
  U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000. **Không** gồm zero-width space
  U+200B, U+180E, U+FEFF, U+001C–U+001F (Python `str.isspace()` coi U+001C–U+001F là
  khoảng trắng, nên script không dùng nó). Danh sách máy đọc: khoá `whiteSpace` trong
  `fixtures/expected-verdicts.json`.
- **Mẫu `code`, `image`, id** khớp **tuyệt đối** cả chuỗi: `"KTC01\n"` hay
  `"media/<hash>.png\n"` là sai (jsonschema dùng `re.search`, `$` còn khớp trước `\n`
  cuối, nên script kiểm lại bằng `re.fullmatch`).
- **Cảnh báo** (không phải lỗi, không chặn mở đề): hai section trùng tiêu đề sau khi bỏ
  khoảng trắng `White_Space` hai đầu và không phân biệt hoa/thường; câu `multiple` chỉ
  có một đáp án đúng. Script in dòng `warn`, không làm file rớt.
- **JSON**: BOM UTF-8 đầu file được bỏ qua. Khoá trùng trong cùng một object, `NaN`/`Infinity`,
  chuỗi có surrogate UTF-16 lẻ: script coi là lỗi.

## Trường lạ

Trường lạ là khoá không có trong schema, ở bất kỳ cấp nào (đề, section, câu, lựa chọn).
Quyết định của Nt0 ngày 2026-10-15:

| Bản | Gặp đề có trường lạ |
| --- | --- |
| Học viên | **Từ chối mở**, báo rõ tên trường lạ và vị trí của nó |
| Admin | **Mở được, bỏ qua trường lạ**; khi lưu lại, file không còn trường đó |

`schema/exam-v1.schema.json` giữ `additionalProperties: false`, khớp với bản Học viên.
`scripts/validate_exam.py` cũng coi trường lạ là lỗi.

## Phiên bản định dạng

- App đọc được mọi `formatVersion` ≤ phiên bản nó hiểu; file mới hơn → báo "đề cần phiên bản app mới hơn", không mở.
- Khi tăng phiên bản: thêm bộ chuyển đổi `v(n-1) → v(n)` trong ExamFile kèm fixture và test; app luôn ghi ra phiên bản mới nhất.
- Mọi thay đổi cấu trúc đều phải tăng `formatVersion`, **kể cả thêm trường tuỳ chọn**: bản Học viên cũ từ chối trường lạ, nên tăng phiên bản để nó báo "cần app mới hơn" thay vì báo "file sai".

## File `.oef` (chỉ đọc)

Thẩm quyền: ADR 0014; kế hoạch và lý do từng quyết định (QO1–QO14): [plan-oef.md](plan-oef.md). App đọc file `.oef` bản
Protobuf của Open Exam Suite và chuyển thành đề theo các luật dưới đây; không ghi `.oef`. Hai bộ cài đặt (Swift
`OEFReader` trong ExamFile; Kotlin trong `android/core`) phải cùng kết quả trên oracle `fixtures/oef/`; đổi luật thì sửa
mục này và oracle trước.

**Nhận diện.** macOS và iOS theo đuôi `.oef` (UTType nhập `vn.io.nt0.examsuite.oef`). File bắt đầu bằng `PK 03 04` hoặc
`PK 05 06` (zip, OES bản 1, 2) hoặc header BinaryFormatter (`00`, 4 byte root id, `FF FF FF FF`, `01 00 00 00`,
`00 00 00 00`; OES bản 3) là **bản cũ**: lỗi `legacyFormat`, cả hai chế độ.

**Dây.** Thông điệp và số trường:

| Thông điệp | Trường |
| --- | --- |
| Exam (gốc) | 1 Properties (thông điệp), 2 Sections (thông điệp, lặp) |
| Properties | 1 Title, 2 Code, 6 Instructions (chuỗi); 3 Version (varint, bỏ qua); 4 Passmark (fixed64, double); 5 TimeLimit (varint, int32); 7 HideAnswers (varint, bool) |
| Section | 1 Title (chuỗi); 2 Questions (thông điệp, lặp) |
| Question | 1 No (varint, bỏ qua); 2 Text, 8 Explanation (chuỗi); 3 ImageData (byte); 4 Answer (varint, char); 5 IsMultipleChoice (varint, bool); 6 Answers (char lặp, packed hoặc từng phần tử); 7 Options (thông điệp, lặp) |
| Option | 1 Alphabet (varint, char); 2 Text (chuỗi) |

- Trường vắng là giá trị mặc định (chuỗi rỗng, 0, false, danh sách rỗng). Trường không lặp xuất hiện nhiều lần: giá trị
  vô hướng lấy lần cuối, Properties gộp. Bool: varint khác 0 là true. TimeLimit: 32 bit thấp của varint, có dấu (varint
  `2^32 + 30` là 30; -5 ghi 10 byte là -5). `char` (Alphabet, Answer, Answers): **nguyên giá trị varint 64 bit**, so sánh
  không cắt về 16 bit (0x10041 khác A).
- **Dây hỏng** (`malformed(offset)`, cả hai chế độ), `offset` là vị trí byte từ 0: khoá có kiểu dây 3, 4, 6, 7, số
  trường 0 hoặc số trường lớn hơn 2^29 − 1 → vị trí đầu khoá; trường đã biết sai kiểu dây → vị trí đầu khoá; varint quá 10 byte, byte thứ 10 lớn hơn 1,
  hoặc varint bị cắt → vị trí đầu varint; độ dài vượt phần còn lại của thông điệp → vị trí đầu varint độ dài; fixed64,
  fixed32 bị cắt → vị trí đầu giá trị; chuỗi không phải UTF-8 hợp lệ → vị trí byte đầu của nội dung chuỗi.
- **Trường lạ** (số trường không có trong bảng, số trường ≤ 2^29 − 1): bỏ qua giá trị. Đường dẫn dạng `#3` (gốc),
  `properties.#8`, `sections[0].#5`, `sections[0].questions[2].#9`, `sections[0].questions[2].options[1].#4` (chỉ số theo
  file, từ 0), theo thứ tự gặp trên dây, không lặp, **giữ 20 đường dẫn khác nhau đầu tiên**
  (`OEFLimits.listedItems`). Đọc nghiêm: lỗi `unknownFields` (20 đường dẫn đó); đọc dễ: ghi chú `unknownField` mỗi
  đường dẫn.
- **Giới hạn** (`OEFLimits`, theo gói `.exam`; vượt là lỗi `tooLarge`, cả hai chế độ, kiểm trong lúc đọc dây): file ≤ 1
  GiB (kiểm trước khi đọc); tổng byte UTF-8 của các chuỗi ≤ 32 MiB (cộng độ dài của chuỗi **trước** khi kiểm UTF-8 của
  chuỗi đó); tổng số phần, câu, lựa chọn và phần tử của Answers ≤ 500.000. Phần, câu, lựa chọn được đếm sau khi đã kiểm
  kiểu dây và độ dài của thông điệp đó, trước khi đọc nội dung; mỗi phần tử của Answers được đếm ngay trước khi đọc varint
  của nó (dạng từng phần tử: sau khi kiểm kiểu dây). Ảnh mỗi cái ≤ 50 MiB: kiểm ở từng câu (bước 4).

**Chuyển thành đề** (thứ tự kiểm: dây và giới hạn → trường lạ → ngưỡng đậu → từng câu theo thứ tự file → còn câu không →
`ExamValidator` ở đọc nghiêm). Ở đọc nghiêm, lỗi đầu tiên gặp theo thứ tự này được ném. Ghi chú của đọc dễ theo thứ tự:
trường lạ → `invalidCode` → `passmarkOutOfRange` → `timeLimitOutOfRange` → từng phần theo file (`emptySection`, hoặc
`untitledSection` rồi ghi chú của các câu trong phần theo thứ tự câu).


1. **Chuỗi**: NFC rồi cắt `White_Space` hai đầu (như mục Cách đếm). Nội dung câu, lựa chọn, giải thích, hướng dẫn là chữ
   trơn: thoát `\`, `` ` ``, `*`, `_`, `[`, `]`, `<`, `>`, `~` bằng `\` đứng trước (không thoát `&`). Tiêu đề đề, tiêu đề
   phần, mã đề không thoát. Trường tuỳ chọn (`code`, `instructions`, `explanation`) rỗng sau khi cắt thì bỏ.
2. **Đề**: `title` ← Title. `code` ← Code nếu khớp mẫu mã, không thì bỏ (đọc dễ: ghi chú `invalidCode`). `passPercent` ←
   Passmark/10 làm tròn gần nhất, nửa lên (725 → 73; như import.md phương án 13); Passmark không hữu hạn hay ngoài
   0–1000: đọc nghiêm lỗi `passmarkOutOfRange`, đọc dễ ghi chú và để 0 (không điền sẵn khi import). `timeLimitMinutes` ←
   TimeLimit (ngoài 1–600: `ExamValidator` báo; đọc dễ ghi chú `timeLimitOutOfRange`, đề giữ nguyên giá trị trong file,
   không điền sẵn khi import). `hideAnswers` ←
   HideAnswers. `formatVersion` 1.
3. **Phần** theo thứ tự file. Phần không có câu trong file bị bỏ (đọc dễ: ghi chú `emptySection`). Tiêu đề rỗng:
   `ExamValidator` báo ở đọc nghiêm; đọc dễ ghi chú `untitledSection` (Import đề… đặt tên phần chung), chỉ khi phần còn
   câu sau bước 4. Phần còn trống vì mọi câu bị bỏ (đọc dễ) cũng bị bỏ, không thêm ghi chú phần.
4. **Câu**: lựa chọn theo thứ tự file, id đặt lại `A, B, C…` theo vị trí; Alphabet chỉ dùng để tìm đáp án. Kiểm theo thứ
   tự các gạch dưới đây.
   - Không có lựa chọn: đọc nghiêm giữ câu không lựa chọn, không đáp án, không ảnh (`ExamValidator` báo); đọc dễ bỏ câu
     (ghi chú `noOptions`). Hai chế độ đều không xét đáp án và ảnh của câu này.
   - Quá 26 lựa chọn: đọc nghiêm lỗi `tooManyOptions` (số lựa chọn trong file); đọc dễ ghi chú, chữ của Z là chữ của lựa
     chọn thứ 26 trở đi (sau bước 1) **bỏ chữ rỗng**, nối bằng `\n`, như import docx.
   - Hai lựa chọn cùng Alphabet: đọc nghiêm lỗi `duplicateOptionLetter` với chữ có lần trùng đầu tiên (theo thứ tự lựa
     chọn: `[A, B, B, A]` → B); đọc dễ một ghi chú mỗi chữ trùng theo thứ tự đó, đáp án theo lựa chọn đầu tiên mang chữ.
   - IsMultipleChoice false → `single`, đáp án là Answer (0 = không có); true → `multiple`, đáp án là Answers (Answer bỏ
     qua). Mỗi chữ đáp án → vị trí lựa chọn đầu tiên mang chữ đó (lựa chọn nối vào Z mang vị trí Z); `correct` theo thứ tự
     lựa chọn, không lặp. Chữ không khớp lựa chọn nào: đọc nghiêm lỗi `answerNotInOptions`, đọc dễ bỏ chữ đó kèm ghi chú;
     danh sách chữ theo thứ tự trong Answer/Answers, không lặp, giữ 20 chữ đầu.
   - Ảnh: ImageData rỗng thì không có ảnh. Quá 50 MiB: đọc nghiêm lỗi `imageTooLarge`, đọc dễ bỏ ảnh kèm ghi chú. Loại
     theo byte đầu: PNG (`89 50 4E 47 0D 0A 1A 0A`) → `png`, JPEG (`FF D8 FF`) → `jpg`, `GIF87a`/`GIF89a` → `gif`, `RIFF` +
     4 byte + `WEBP` → `webp`, byte 4–7 `ftyp` và nhãn chính (major brand, chỉ byte 8–11) `heic`, `heix`, `heim`, `heis`,
     `hevc`, `hevx` → `heic`. Loại khác: đọc nghiêm lỗi `unsupportedImage`, đọc dễ bỏ ảnh kèm ghi chú. Đường dẫn
     `media/<16 ký tự hex đầu của SHA-256>.<đuôi>` như mục Gói; ảnh trùng byte dùng chung một đường dẫn.
   - Chữ cái trong câu báo: ký tự in được ASCII (`!`–`~`) giữ nguyên, khác thì `U+` và giá trị hex chữ hoa, ít nhất 4 chữ
     số (`U+0000`, `U+10041`).
5. **Id**, UUID phiên bản 8 (RFC 9562): 16 byte đầu của SHA-256 (UTF-8 của chuỗi tên), đặt 4 bit phiên bản `8` và 2 bit
   biến thể `10`, viết chữ thường. Đề: `"oef-exam" + U+0000 + code + U+0000 + title` (sau bước 1, 2; `code` vắng là chuỗi
   rỗng). Phần thứ i: `"<id đề>/s<i>"`; câu thứ j của phần i: `"<id đề>/s<i>/q<j>"`, i và j đếm từ 0 **theo file, kể cả
   phần và câu bị bỏ**. Cùng file luôn ra cùng id; sửa câu trong OES giữ id đề nếu mã và tiêu đề không đổi. Hệ quả: hai đề
   khác nhau cùng mã và tiêu đề là một đề với Thư viện; chèn hay đổi thứ tự câu làm câu dời chỗ đổi id, Xem lại lần thi cũ
   báo câu đã sửa (dấu vân tay khác) chứ không đánh dấu sai.
6. Không còn câu nào: lỗi `noQuestions`, cả hai chế độ. Đọc nghiêm: lỗi mức `error` của `ExamValidator` → `validationFailed`
   như gói `.exam`.

Đọc dễ là chế độ của bản Admin (Import đề…) và của bước phân loại Đề có lỗi trong Thư viện.

## Bằng chứng

- `python3 scripts/validate_exam.py --all`: mọi `fixtures/exams/*/exam.json` đậu, mọi `fixtures/invalid/*.json` rớt (bằng chứng âm);
  đề mẫu của Thư viện đậu và không có cả warning ([library.md](library.md), mục Đề mẫu).
- Script và app cùng kết luận: `fixtures/expected-verdicts.json` ghi kết luận mong đợi của
  từng fixture (`valid`, `error`, `undecodable`, `examfile`). `scripts/check_validator_parity.py`
  kiểm phía script, test Swift `ExamValidatorParityTests` kiểm phía app trên cùng file;
  cả hai chạy trong `scripts/check.sh`. Thêm fixture thì thêm dòng vào file đó.
- Giai đoạn 1: test ghi → đọc lại (round-trip) trong `ExamFileTests`, kể cả ảnh.
- File `.oef`: `fixtures/oef/<tên>.oef` sinh bằng `scripts/make_oef.py` từ `fixtures/oef/src/<tên>.json` (`--check` so
  từng byte, trong `scripts/check.sh`); kết luận đọc nghiêm/đọc dễ và vector (id, thoát Markdown, ngưỡng đậu, loại ảnh,
  tên chữ cái) viết tay ở `fixtures/oef/expected.json`. Lõi Swift: `OEFReaderTests`, `OEFRobustnessTests` (cắt cụt, đột
  biến có seed, giới hạn); lõi Kotlin: `SharedOracleTest` (bước O3 của plan-oef.md).
