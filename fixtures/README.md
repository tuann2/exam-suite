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
  Thêm hay đổi tên fixture thì sửa file này.

Đóng gói thành `.exam` để mở bằng app: `python3 scripts/pack_exam.py fixtures/exams/kien-thuc-chung dist/`.
Kiểm tra toàn bộ: `python3 scripts/validate_exam.py --all && python3 scripts/check_validator_parity.py`.
