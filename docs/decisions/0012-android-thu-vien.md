# 0012 Thư viện của bản Android: nền tảng AndroidX/Kotlin, công cụ test; ngoài danh sách phải có ADR

Date: 2026-10-22

## Status

Accepted (Nt0 chốt Q5 của docs/product/plan-android-v1.md ngày 2026-10-22)

## Context

ADR 0006 giữ bản macOS chỉ một thư viện ngoài. Trên Android, gần như mọi thứ (giao diện, lưu trữ, test) đến từ thư viện
nền tảng của Google và JetBrains; đòi một ADR cho từng thư viện AndroidX là chi phí không mang lại gì. Rủi ro thật là
agent "tiện tay" thêm thư viện bên thứ ba (mạng, DI, ảnh…).

## Decision

Được dùng không cần ADR riêng (khai báo trong `android/gradle/libs.versions.toml`, phiên bản đã phát hành ít nhất hai
tuần khi thêm):

| Nhóm | Dùng cho | Phạm vi |
| --- | --- | --- |
| `androidx.*` (Compose, Material 3, Activity, Lifecycle, Navigation, Room, DataStore, `androidx.test`) | Giao diện, lưu trữ, test trên máy | App; `androidx.test`, `ui-test*` chỉ test |
| `org.jetbrains.kotlin:*`, `org.jetbrains.kotlinx:kotlinx-serialization-*`, `kotlinx-coroutines-*` | Ngôn ngữ, JSON, coroutine | App |
| JUnit (`org.junit*`, `junit:junit`), Robolectric (`org.robolectric`, MIT) | Test JVM | Chỉ test |
| `com.android.tools.screenshot` (Compose Preview Screenshot Testing) | So ảnh preview | Chỉ test |
| `com.android.tools.lint` (lint-api, lint-checks, lint-tests) | Luật lint riêng (`:lint-rules`) | Chỉ build/test |
| Plugin: `com.android.application`, `com.android.library`, `com.android.compose.screenshot`, `org.jetbrains.kotlin.*`, `com.google.devtools.ksp`, `androidx.room` | Build | Build |

Phụ thuộc bắc cầu của các thư viện trên (ví dụ Accessibility Test Framework của Google, kéo theo bởi
`androidx.compose.ui:ui-test-junit4-accessibility`) không cần ADR. Mọi thư viện hoặc plugin khác, và mọi GitHub Action
ngoài `actions/*`, chỉ thêm sau khi có ADR mới được duyệt (như ADR 0006). Zip dùng `java.util.zip`, SHA-256
`MessageDigest`, NFC `java.text.Normalizer`, PDF (v1.1) `android.graphics.pdf.PdfDocument`, Markdown cơ bản tự viết.

Kiểm: `android/scripts/check_android_rules.py` (trong `check_android.sh` và job `android` của CI): mọi mục của danh
mục thuộc danh sách trên; thư viện chỉ test/build không nằm trong `implementation`/`api`/`releaseImplementation`; build
script không khai báo toạ độ Maven trực tiếp. Có tự kiểm âm chạy mỗi lần.

## Alternatives Considered

1. Một ADR cho từng thư viện như ADR 0006: chậm, không bớt rủi ro vì nhóm nền tảng do Google/JetBrains duy trì.
2. Không kiểm máy, chỉ dựa vào review: agent đã từng thêm phụ thuộc "tiện tay" ở các dự án khác; kiểm rẻ.

## Consequences

Positive:

- Danh sách rõ, máy chặn; cây phụ thuộc chỉ gồm nền tảng.

Tradeoffs:

- Thư viện cộng đồng phổ biến (Coil, Hilt, Timber…) không dùng được nếu chưa có ADR.

## Follow-Up

- Giấy phép của thư viện đi kèm APK ghi vào `THIRD_PARTY_NOTICES.md` khi đóng APK phát hành (A4).
