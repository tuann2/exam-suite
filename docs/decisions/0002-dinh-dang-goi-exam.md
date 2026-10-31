# 0002 Định dạng đề: JSON + ảnh trong gói zip `.exam`, có schema và phiên bản

Date: 2026-10-15

## Status

Accepted

## Context

Dự án không có file `.oef` cũ và không cần trao đổi với Open Exam Suite. Cần định
dạng mở để AI/script sinh đề hàng loạt, dễ kiểm tra trên CI, và nâng cấp được
mà không hỏng đề cũ.

## Decision

Mỗi đề là một file zip đuôi `.exam` chứa `exam.json` và `media/`. Cấu trúc do
`schema/exam-v1.schema.json` (JSON Schema 2020-12) quy định; có `formatVersion`;
ID là UUID ổn định cho đề/section/câu; `type` là `single`|`multiple`, `correct`
luôn là mảng; `passPercent` số nguyên 0–100; ảnh đặt tên theo hash nội dung.
Chi tiết: docs/product/exam-format.md. Không đọc/ghi `.oef` ở v1.

## Alternatives Considered

1. `.oef` (protobuf) của bản gốc: tương thích nhưng khó đọc bằng mắt, kéo theo thư viện protobuf.
2. Một file JSON với ảnh base64: đơn giản nhưng file phình, ảnh trùng lưu nhiều lần.
3. Thư mục (package bundle) thay vì zip: Finder hỗ trợ tốt nhưng khó gửi qua chat/ổ chung.

## Consequences

Positive:

- Kiểm tra được bằng schema trên mọi nền tảng; sinh đề bằng script.
- Nâng cấp định dạng có kiểm soát.

Tradeoffs:

- Ai có file cũng đọc được đáp án (ADR 0005).
- Phải tự viết bộ chuyển đổi khi tăng phiên bản.

## Follow-Up

- `passPercent` là số nguyên để hai cách so sánh ngưỡng đậu (thang 1000 và %) luôn trùng (docs/product/scoring.md).
- Ràng buộc liên trường do ExamKit và `scripts/validate_exam.py` cùng kiểm.
- 2026-10-15: trường lạ → bản Học viên từ chối, bản Admin bỏ qua và không giữ khi lưu; vì vậy thêm bất kỳ trường nào cũng phải tăng `formatVersion` (docs/product/exam-format.md, mục Trường lạ).
- 2026-10-31: ADR 0014 cho phép **đọc** `.oef` bản Protobuf của Open Exam Suite (không ghi); gói `.exam` vẫn là định dạng
  duy nhất app ghi ra. Câu "Không đọc/ghi `.oef` ở v1" ở trên là quyết định của v1.
