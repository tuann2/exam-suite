# Decisions

Decision records preserve lasting product, architecture, data ownership,
security, compatibility, and validation choices that future work must inherit.

Use `docs/templates/decision.md`. Task-local implementation choices remain in
the active execution plan and do not require a separate decision.

## Index

| # | Quyết định | Trạng thái |
| --- | --- | --- |
| [0001](0001-viet-moi-swiftui-khong-chep-gpl.md) | Viết mới bằng SwiftUI, không fork/chép code GPLv3 | Accepted |
| [0002](0002-dinh-dang-goi-exam.md) | Định dạng đề: JSON + ảnh trong gói zip `.exam`, schema, `formatVersion` | Accepted |
| [0003](0003-hai-ban-app-mot-codebase.md) | Một codebase, hai bản app; bản Học viên không chứa AuthoringFeature | Accepted |
| [0004](0004-macos-15-apple-silicon-phan-phoi-rieng.md) | macOS 15+, Apple silicon, DMG phân phối riêng, ký ad-hoc | Accepted |
| [0005](0005-khong-bao-ve-de-v1.md) | Không bảo vệ nội dung đề ở v1 | Accepted |
| [0006](0006-thu-vien-ngoai.md) | Thư viện ngoài: ZIPFoundation, swift-snapshot-testing (chỉ test, ADR 0010); thêm thư viện phải có ADR | Accepted |
| [0007](0007-harness-ai-agent.md) | Harness: repository-harness + ba cơ chế từ ai-workflow-template | Accepted |
| [0008](0008-loi-foundation-only.md) | Lõi ExamKit/ExamFile chỉ dùng Foundation (+ZIPFoundation), test trên Linux | Accepted |
| [0009](0009-doc-dinh-dang-vce.md) | Đọc trực tiếp file `.vce` khi import đề (spike trước, điều kiện pháp lý) | Accepted |
| [0010](0010-snapshot-testing.md) | Snapshot test giao diện bằng swift-snapshot-testing, chỉ trong test | Accepted |
| [0011](0011-android-kotlin-compose.md) | Bản Android: Kotlin + Compose, lõi viết lại bằng Kotlin (oracle chung), cùng repo `android/`, CI theo PR cho `android/` | Accepted |
| [0012](0012-android-thu-vien.md) | Thư viện của bản Android: nền tảng AndroidX/Kotlin và công cụ test; ngoài danh sách phải có ADR | Accepted |

Quyết định tiếp theo lấy số 0013.
