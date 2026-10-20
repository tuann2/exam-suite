# 0008 Lõi ExamKit và ExamFile chỉ dùng Foundation (+ ZIPFoundation)

Date: 2026-10-15

## Status

Accepted

## Context

Chấm điểm sai và hỏng file đề là hai rủi ro lớn nhất, nên lõi phải test được
nhanh, không cần giao diện, và chạy được trên agent cloud (Linux).

## Decision

Trong `Packages/ExamKit`:

- Module `ExamKit` chỉ import `Foundation` (và chính nó).
- Module `ExamFile` chỉ import `Foundation`, `ExamKit`, `ZIPFoundation`.
- Cấm `SwiftUI`, `AppKit`, `UIKit`, `Cocoa`, `SwiftData`, `CoreData`, `Combine`.
- Model đề là struct thuần `Codable`, tách khỏi SwiftData.
- `swift test --package-path Packages/ExamKit` phải xanh trên Linux (job `core-linux`).

## Alternatives Considered

1. Cho phép Combine/SwiftData trong lõi: tiện nhưng khoá vào Apple, mất test trên Linux.

## Consequences

Positive:

- Test lõi chạy trong vài giây, trên mọi máy; agent cloud làm được giai đoạn 1.

Tradeoffs:

- Lớp SwiftData/UI phải chuyển đổi từ struct sang model lưu trữ.

## Follow-Up

- Kiểm bằng `scripts/check_boundaries.py` (quét `import`) trong `scripts/check.sh` và CI.
