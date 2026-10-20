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

## Bằng chứng

- `python3 scripts/validate_exam.py --all`: mọi `fixtures/exams/*/exam.json` đậu, mọi `fixtures/invalid/*.json` rớt (bằng chứng âm);
  đề mẫu của Thư viện đậu và không có cả warning ([library.md](library.md), mục Đề mẫu).
- Script và app cùng kết luận: `fixtures/expected-verdicts.json` ghi kết luận mong đợi của
  từng fixture (`valid`, `error`, `undecodable`, `examfile`). `scripts/check_validator_parity.py`
  kiểm phía script, test Swift `ExamValidatorParityTests` kiểm phía app trên cùng file;
  cả hai chạy trong `scripts/check.sh`. Thêm fixture thì thêm dòng vào file đó.
- Giai đoạn 1: test ghi → đọc lại (round-trip) trong `ExamFileTests`, kể cả ảnh.
