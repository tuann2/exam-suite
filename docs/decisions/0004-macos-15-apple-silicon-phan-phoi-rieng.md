# 0004 macOS 15 trở lên, chỉ Apple silicon, phân phối riêng bằng DMG

Date: 2026-10-15

## Status

Accepted (2026-10-15: xác nhận mọi Mac dùng thử đã lên macOS 15+; 2026-10-18: lời văn theo dự án cá nhân của Nt0,
điều kiện nâng lên Developer ID là có tài khoản Apple Developer; 2026-10-20, repo public: đổi tên file từ
`…-phan-phoi-noi-bo.md`, Nt0 chốt bỏ cách gọi nội bộ; nội dung quyết định không đổi)

## Context

Mọi Mac dùng thử app là Apple silicon. App phân phối riêng, chưa lên Mac App Store,
chưa có tài khoản Apple Developer.

## Decision

- Deployment target macOS 15 Sequoia; `ARCHS = arm64`, loại x86_64.
- Build hai DMG (Học viên, Admin) bằng `hdiutil` trên CI khi gắn tag `v*`.
- Ký ad-hoc (`CODE_SIGN_IDENTITY = -`) ở giai đoạn beta; nâng lên Developer ID +
  notarize + Sparkle khi có tài khoản Apple Developer.
- Không sandbox ở v1; dữ liệu app ở `~/Library/Application Support/<bundle ID>`.
- Phiên bản semver, `CHANGELOG.md`.

## Alternatives Considered

1. macOS 14: mở rộng máy cài được nhưng SwiftData kém ổn định hơn.
2. Universal binary: không cần vì không còn máy Intel.

## Consequences

Positive:

- Dùng được API mới nhất của SwiftUI/SwiftData; build nhanh, DMG nhỏ.

Tradeoffs:

- Lần mở đầu phải "Open Anyway" trong System Settings khi còn ký ad-hoc.

## Follow-Up

- Đã xác nhận 2026-10-15: mọi Mac dùng thử ≥ macOS 15.
