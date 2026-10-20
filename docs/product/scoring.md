# Chấm điểm và chọn câu

Thẩm quyền: tài liệu này (chuyển thể quy tắc của Open Exam Suite `Scorer`/`Grader`,
viết lại, không chép code). Code: module `ExamKit` (giai đoạn 1). Thay đổi ở đây
là **rủi ro cao** (docs/process/review-and-merge.md).

## Chấm từng câu

- Mỗi câu chỉ **đúng hoặc sai**, không có điểm từng phần.
- Câu `single`: đúng khi đáp án chọn trùng phần tử duy nhất của `correct`.
- Câu `multiple`: đúng khi **tập** đáp án chọn bằng đúng tập `correct` (không thiếu, không thừa; thứ tự không quan trọng).
- Chưa trả lời → sai.

## Điểm và ngưỡng đậu

Với `correct` = số câu đúng, `total` = số câu trong phiên thi (sau khi chọn câu):

```text
score1000 = total == 0 ? 0 : (correct * 1000) / total     // chia lấy phần nguyên
percent   = total == 0 ? 0 : (correct * 100)  / total     // chia lấy phần nguyên, để hiển thị
passed    = score1000 >= passPercent * 10
```

`passPercent` là số nguyên 0–100 lấy từ file đề, nên hai cách so sánh
(`score1000 >= passPercent*10` và `percent >= passPercent`) cho cùng kết quả.
Màn kết quả hiển thị cả `%` và thang 1000. Giá trị thang 1000 (điểm, ngưỡng đậu × 10) luôn ghi **chữ số trơn**,
không dấu ngăn nghìn, ở mọi ngôn ngữ và mọi nơi (Kết quả, PDF, Lịch sử thi, Soạn đề): "850/1000", "1000/1000"; "1000"
là tên của thang (Nt0 chốt 2026-10-17; ngoại lệ của quy tắc số theo ngôn ngữ giao diện ở
accessibility-localization.md).

Ví dụ: 7/10 đúng → 700, 70%, đậu với `passPercent` 70. 2/3 đúng → 666, 66%, trượt với 67.

## Kết quả theo section

Với mỗi section của đề: số câu của section có mặt trong phiên thi và số câu đúng
trong đó. Section không có câu nào trong phiên vẫn xuất hiện với `0/0`. Tổng các
section bằng tổng của phiên.

## Chọn câu cho một phiên

Tuỳ chọn ở màn Trước khi thi:

| Tuỳ chọn | Quy tắc |
| --- | --- |
| Tất cả câu | Theo thứ tự trong file |
| Theo section | Chỉ các section được chọn, giữ thứ tự |
| N câu ngẫu nhiên | Xáo toàn bộ câu bằng Fisher–Yates với `seed` (UInt64), lấy N câu đầu, **giữ thứ tự sau xáo** (như bản gốc); 1 ≤ N ≤ tổng |
| Xáo câu | Fisher–Yates cùng seed trên danh sách đã chọn |
| Xáo đáp án | Xáo thứ tự hiển thị options của từng câu, chấm theo `id` gốc |

- Mỗi câu nhớ section gốc để chấm theo section.
- Cùng `seed` + cùng đề + cùng tuỳ chọn ⇒ cùng danh sách câu (test được, "làm lại" tái hiện được).
- "Luyện lại câu sai": phiên mới gồm đúng các câu sai/chưa làm của lần trước, theo `id` câu, chế độ Practice.
  Giữ thứ tự id truyền vào; id trùng giữ lần đầu.
- Lỗi: lựa chọn ra 0 câu (đề rỗng, tập section rỗng, danh sách câu rỗng) → `noQuestions`;
  N ngoài `1…tổng` → `countOutOfRange`; id section/câu không thuộc đề → `unknownSection`/`unknownQuestion`.

### Bộ sinh số ngẫu nhiên và thứ tự tiêu thụ

Code: `ExamComposer`, `SeededGenerator` trong `ExamKit/Composer`. Không dùng bộ sinh
hay `shuffled`/`random(in:)` của thư viện chuẩn Swift vì thuật toán của chúng không
được cam kết ổn định giữa phiên bản và nền tảng.

- **PRNG: SplitMix64** khởi tạo `state = seed`. Mỗi lần lấy số (mọi phép tính modulo 2^64):

  ```text
  state = state + 0x9E3779B97F4A7C15
  z = (state ^ (state >> 30)) * 0xBF58476D1CE4E5B9
  z = (z ^ (z >> 27)) * 0x94D049BB133111EB
  return z ^ (z >> 31)
  ```

  Seed 0 cho `0xE220A8397B1DCDAF, 0x6E789E6AA1B965F4, 0x06C45D188009454F, …` (test khoá giá trị).
- **Số nguyên trong `0..<n`**: `threshold = 2^64 mod n`; lấy số tiếp theo, bỏ nếu `< threshold`,
  ngược lại trả `số mod n` (rejection sampling, không lệch).
- **Fisher–Yates**: `i` từ `count − 1` xuống 1, `j = số nguyên trong 0..<(i+1)`, đổi chỗ `i` và `j`.
- **Thứ tự tiêu thụ**: một bộ sinh duy nhất từ `seed` cho cả lần tạo đề, lần lượt:
  1. N câu ngẫu nhiên: Fisher–Yates toàn bộ câu (thứ tự file, các section nối tiếp), lấy N câu đầu;
  2. Xáo câu: Fisher–Yates trên danh sách đã chọn;
  3. Xáo đáp án: từng câu theo thứ tự cuối cùng, Fisher–Yates trên thứ tự lựa chọn trong file.

  Bước không bật không tiêu thụ số nào. Đổi thuật toán hay thứ tự này làm seed đã lưu ra đề khác:
  phải coi là thay đổi rủi ro cao.

## Bằng chứng cần có (giai đoạn 1)

Test Swift Testing trong `ExamKitTests`, viết theo danh sách tình huống của
`ScorerTests`, `GraderTests`, `ExamComposerRandomTests` của bản gốc (tên tình
huống, không chép code): total 0, tất cả đúng, tất cả sai, `multiple` thiếu một,
`multiple` thừa một, biên đậu/trượt tại đúng ngưỡng, chia lấy phần nguyên, seed lặp lại.
