# Fixtures

Đề mẫu tự soạn (không chép từ Open Exam Suite). Dùng cho test của
ExamKit/ExamFile và kiểm tra schema trên CI.

- `exams/<tên>/exam.json` (+ `media/`): nội dung một gói `.exam` đã giải nén.
  Mọi file ở đây **phải** khớp `schema/exam-v1.schema.json`.
- `invalid/<lý-do>.json`: file cố tình sai, dùng làm bằng chứng âm cho bộ
  kiểm tra. Mọi file ở đây **phải bị** schema hoặc kiểm tra liên trường từ chối.
- `expected-verdicts.json`: kết luận mong đợi của từng fixture (`valid`, `error`,
  `undecodable`, `examfile`), ràng buộc cả `scripts/validate_exam.py` lẫn app
  (`scripts/check_validator_parity.py` và test Swift `ExamValidatorParityTests`).
  Thêm hay đổi tên fixture thì sửa file này. Khoá `issueCodes`: mã vấn đề theo thứ tự của mỗi fixture nhãn `error`,
  ràng buộc lõi Swift (`ExamValidatorTests`) và lõi Kotlin của bản Android (`android/core`).
- `invalid-json/<ca>.json` + `expected.json`: ca `exam.json` sai cú pháp hoặc chỉ chế độ đọc nghiêm bắt (khoá trùng,
  dấu phẩy thừa, `null`, độ sâu, `NaN`, surrogate lẻ, UTF-8 hỏng, BOM…) với lỗi và đường dẫn mong đợi. Oracle chung của
  hai lõi (Swift `SharedInvalidJSONTests`, Kotlin `SharedOracleTest`); script Python không đọc thư mục này.
- `vectors/composer.json`, `vectors/question-fingerprints.json`: vector cố định của SplitMix64, chọn câu và dấu vân tay
  câu, dùng chung cho hai lõi. Đổi hành vi lõi thì sửa oracle trước, rồi hai lõi cùng xanh (ADR 0011).

- `oef/<tên>.oef` + `oef/src/<tên>.json` + `oef/expected.json`: file `.oef` (Open Exam Suite, ADR 0014) tự dựng, sinh
  bằng `scripts/make_oef.py` từ mô tả JSON (`--check` so từng byte, trong `scripts/check.sh`); kết luận đọc nghiêm/đọc dễ
  và vector viết tay ở `expected.json`. Oracle chung của lõi Swift (`OEFReaderTests`) và lõi Kotlin (`SharedOracleTest`).
  Thêm file thì thêm mô tả, chạy `scripts/make_oef.py`, rồi thêm dòng vào `expected.json`. Không chép file mẫu của Open
  Exam Suite vào đây.

Đóng gói thành `.exam` để mở bằng app: `python3 scripts/pack_exam.py fixtures/exams/kien-thuc-chung dist/`.
Kiểm tra toàn bộ: `python3 scripts/validate_exam.py --all && python3 scripts/check_validator_parity.py`.
