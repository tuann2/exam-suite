# 0005 Không bảo vệ nội dung đề ở v1

Date: 2026-10-15

## Status

Accepted

## Context

Đề dùng để luyện tập. File `.exam` là zip + JSON mở nên ai có file cũng đọc
được đáp án và sửa được đề.

## Decision

v1 không ký số, không mã hoá đáp án, không đăng nhập. Chấp nhận rủi ro vì mục
đích là luyện tập. Nếu dùng cho thi thật, v2 thêm ký số chống sửa và mã hoá
đáp án; schema chừa chỗ bằng cách tăng `formatVersion`.

## Alternatives Considered

1. Mã hoá đáp án ngay từ v1: tốn công, khoá nằm trong app nên vẫn lộ.
2. Đề trên máy chủ: ngoài phạm vi, cần hạ tầng.

## Consequences

Positive:

- Định dạng đơn giản, script/AI sinh và sửa đề dễ dàng.

Tradeoffs:

- Không dùng được cho kỳ thi có tính pháp lý.

## Follow-Up

- Ghi rõ trong hướng dẫn cài đặt rằng đề là tài liệu luyện tập.
