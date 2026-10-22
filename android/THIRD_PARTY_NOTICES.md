# Thông báo bên thứ ba của bản Android (Third-party notices, Android)

Exam Suite cho Android (Copyright 2026 Nt0, giấy phép Apache-2.0, xem `LICENSE` và `NOTICE` ở gốc repo) đóng vào APK
các thành phần mã nguồn mở dưới đây, **tất cả theo giấy phép Apache-2.0** (toàn văn: `LICENSE` ở gốc repo, cùng giấy
phép với Exam Suite). Phiên bản theo `android/gradle/libs.versions.toml` và Compose BOM trong đó; danh sách nhóm lấy từ
`./gradlew :app:dependencies --configuration releaseRuntimeClasspath` (0.1.0). Thư viện chỉ dùng khi build hay test
(Robolectric, JUnit, Compose UI Test, Compose Preview Screenshot Testing, Android Lint) không vào APK.

The Android app bundles the open-source components below, all licensed under Apache-2.0 (full text: `LICENSE` at the
repository root). Build-time and test-only libraries are not included in the APK.

| Thành phần (component) | Nhóm Maven (group) | Nguồn (source) |
| --- | --- | --- |
| Android Jetpack (AndroidX): Activity, Compose (runtime, UI, foundation, animation, Material 3), Lifecycle, Room, SQLite, DataStore, Core, Collection, SavedState, Annotation, Emoji2, Startup, ProfileInstaller, Tracing, Window và các phụ thuộc của chúng | `androidx.*` | https://android.googlesource.com/platform/frameworks/support |
| Kotlin standard library | `org.jetbrains.kotlin` | https://github.com/JetBrains/kotlin |
| kotlinx.coroutines | `org.jetbrains.kotlinx` | https://github.com/Kotlin/kotlinx.coroutines |
| kotlinx.serialization | `org.jetbrains.kotlinx` | https://github.com/Kotlin/kotlinx.serialization |
| JetBrains Java Annotations | `org.jetbrains` | https://github.com/JetBrains/java-annotations |
| Okio (phụ thuộc của DataStore) | `com.squareup.okio` | https://github.com/square/okio |
| Guava ListenableFuture (phụ thuộc của AndroidX) | `com.google.guava` | https://github.com/google/guava |
| JSpecify annotations | `org.jspecify` | https://github.com/jspecify/jspecify |
| Material Icons: đường vẽ của các biểu tượng trong `app/src/main/res/drawable/ic_*.xml` | — | https://github.com/google/material-design-icons |
