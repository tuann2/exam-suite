#!/usr/bin/env python3
"""Kiểm hai luật của android/ mà Gradle và Lint không tự chặn. Có tự kiểm âm, chạy mỗi lần.

1. Thư viện (ADR 0012, Nt0 chốt Q5 2026-10-22): mọi thư viện và plugin khai báo trong gradle/libs.versions.toml thuộc
   danh sách cho phép; thư viện chỉ cho test/build không vào cấu hình implementation/api; build script không khai báo
   toạ độ Maven trực tiếp (mọi phụ thuộc đi qua danh mục).
2. Chuỗi (Decisions A0 của docs/plans/completed/android-v1.md): res/values*/strings.xml không có tools:locale, vì lint
   (AGP 9.4) có thuộc tính đó thì bỏ qua MissingTranslation mà không báo gì.

Dùng: python3 android/scripts/check_android_rules.py [--self-test-only]
"""
from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path

ANDROID = Path(__file__).resolve().parent.parent
ADR = "docs/decisions/0012-android-thu-vien.md"

# Nhóm Maven được phép (ADR 0012). Khớp theo tiền tố nhóm, hoặc đúng "nhóm:artifact" khi có dấu hai chấm.
ALLOWED_LIBRARY_PREFIXES = (
    "androidx.",                       # AndroidX/Jetpack: Compose, Activity, Room, DataStore, test
    "org.jetbrains.kotlin:",           # thư viện chuẩn Kotlin
    "org.jetbrains.kotlinx:kotlinx-serialization-",
    "org.jetbrains.kotlinx:kotlinx-coroutines-",
    "com.android.tools.lint:",         # chỉ build/test: luật lint riêng (:lint-rules)
    "com.android.tools.screenshot:",   # chỉ test: Compose Preview Screenshot
    "org.junit:", "org.junit.jupiter:", "org.junit.platform:", "junit:junit",
    "org.robolectric:",                # chỉ test
)
ALLOWED_PLUGIN_PREFIXES = (
    "com.android.application", "com.android.library", "com.android.compose.screenshot",
    "org.jetbrains.kotlin.", "com.google.devtools.ksp", "androidx.room",
)
# Chỉ cho test hoặc build: không được vào implementation/api của module sản phẩm.
TEST_OR_BUILD_ONLY_PREFIXES = (
    "com.android.tools.lint:", "com.android.tools.screenshot:", "org.junit:", "org.junit.jupiter:",
    "org.junit.platform:", "junit:junit", "org.robolectric:", "androidx.test", "androidx.compose.ui:ui-test",
)
# Cấu hình đi vào APK phát hành. debugImplementation không tính: chỉ vào bản debug (ui-test-manifest, ui-tooling).
PRODUCT_CONFIGURATIONS = ("implementation", "api", "releaseImplementation")
DIRECT_COORDINATE = re.compile(r'"[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+:[A-Za-z0-9_.+-]+"')


def accessor(key: str) -> str:
    return "libs." + re.sub(r"[-_]", ".", key)


def catalog_problems(catalog_text: str) -> tuple[list[str], dict[str, str]]:
    data = tomllib.loads(catalog_text)
    problems: list[str] = []
    modules: dict[str, str] = {}
    for key, spec in data.get("libraries", {}).items():
        module = spec if isinstance(spec, str) else spec.get("module") or f'{spec.get("group")}:{spec.get("name")}'
        module = module.rsplit(":", 1)[0] if module.count(":") == 2 else module
        modules[accessor(key)] = module
        if not module.startswith(ALLOWED_LIBRARY_PREFIXES):
            problems.append(
                f"libs.versions.toml: thư viện '{key}' ({module}) không thuộc danh sách cho phép ({ADR}). "
                "Bỏ đi, hoặc viết ADR mới và chờ Nt0 duyệt trước khi thêm."
            )
    for key, spec in data.get("plugins", {}).items():
        plugin_id = spec if isinstance(spec, str) else spec.get("id", "")
        plugin_id = plugin_id.split(":")[0]
        if not plugin_id.startswith(ALLOWED_PLUGIN_PREFIXES):
            problems.append(
                f"libs.versions.toml: plugin '{key}' ({plugin_id}) không thuộc danh sách cho phép ({ADR}). "
                "Bỏ đi, hoặc viết ADR mới và chờ Nt0 duyệt."
            )
    return problems, modules


def build_script_problems(name: str, text: str, modules: dict[str, str]) -> list[str]:
    problems: list[str] = []
    for match in DIRECT_COORDINATE.finditer(text):
        problems.append(
            f"{name}: khai báo toạ độ Maven trực tiếp {match.group(0)} ({ADR}). Thêm vào gradle/libs.versions.toml "
            "rồi dùng libs.…, để luật danh sách cho phép kiểm được."
        )
    for configuration in PRODUCT_CONFIGURATIONS:
        for match in re.finditer(rf"(?<![A-Za-z]){configuration}\((?:platform\()?(libs\.[A-Za-z0-9.]+)", text):
            module = modules.get(match.group(1), "")
            if module.startswith(TEST_OR_BUILD_ONLY_PREFIXES):
                problems.append(
                    f"{name}: {match.group(1)} ({module}) chỉ dành cho test/build mà nằm trong {configuration}(…) "
                    f"({ADR}). Dùng testImplementation/androidTestImplementation/compileOnly của :lint-rules."
                )
    return problems


def strings_problems(name: str, text: str) -> list[str]:
    if re.search(r"\btools:locale\s*=", text):
        return [
            f"{name}: có tools:locale; lint (AGP 9.4) khi đó bỏ qua MissingTranslation mà không báo "
            "(Decisions A0, docs/plans/completed/android-v1.md). Xoá thuộc tính; tiếng Việt là values/ mặc định."
        ]
    return []


def repository_problems() -> list[str]:
    problems, modules = catalog_problems((ANDROID / "gradle/libs.versions.toml").read_text(encoding="utf-8"))
    for script in sorted(ANDROID.glob("**/*.gradle.kts")):
        if "/build/" in script.as_posix() or "/.gradle/" in script.as_posix():
            continue
        problems += build_script_problems(script.relative_to(ANDROID).as_posix(), script.read_text(encoding="utf-8"), modules)
    for strings in sorted(ANDROID.glob("*/src/*/res/values*/strings.xml")):
        problems += strings_problems(strings.relative_to(ANDROID).as_posix(), strings.read_text(encoding="utf-8"))
    return problems


def self_test() -> list[str]:
    """Đối chứng âm (mỗi luật phải bắt đúng ca cấm) và dương (ca hợp lệ không bị bắt)."""
    failures: list[str] = []
    good_catalog = """
[libraries]
compose-ui = { module = "androidx.compose.ui:ui" }
serialization = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version = "1" }
robolectric = { module = "org.robolectric:robolectric", version = "4" }
[plugins]
app = { id = "com.android.application", version = "9" }
"""
    problems, modules = catalog_problems(good_catalog)
    if problems:
        failures.append(f"danh mục hợp lệ bị bắt nhầm: {problems}")
    cases = {
        "thư viện ngoài danh sách": catalog_problems('[libraries]\nhttp = { module = "com.squareup.okhttp3:okhttp", version = "4" }\n')[0],
        "kotlinx ngoài serialization/coroutines": catalog_problems('[libraries]\nx = "org.jetbrains.kotlinx:kotlinx-datetime:0.6"\n')[0],
        "plugin ngoài danh sách": catalog_problems('[plugins]\nhilt = { id = "com.google.dagger.hilt.android", version = "2" }\n')[0],
        "thư viện test trong implementation": build_script_problems("x", "dependencies { implementation(libs.robolectric) }", modules),
        "toạ độ Maven trực tiếp": build_script_problems("x", 'dependencies { implementation("com.squareup:x:1.0") }', modules),
        "tools:locale trong strings.xml": strings_problems("x", '<resources xmlns:tools="t" tools:locale="vi"></resources>'),
    }
    for label, found in cases.items():
        if not found:
            failures.append(f"đối chứng âm không bắt được: {label}")
    allowed = build_script_problems(
        "x", "dependencies { testImplementation(libs.robolectric)\n implementation(libs.compose.ui)\n"
        " debugImplementation(libs.robolectric) }", modules)
    allowed += strings_problems("x", "<resources><string name=\"a\">A</string></resources>")
    if allowed:
        failures.append(f"ca hợp lệ bị bắt nhầm: {allowed}")
    return failures


def main() -> int:
    failures = self_test()
    if failures:
        print("check_android_rules: tự kiểm thất bại, script không tin được:", *failures, sep="\n  ")
        return 2
    if "--self-test-only" in sys.argv:
        print("check_android_rules: tự kiểm âm/dương đạt")
        return 0
    problems = repository_problems()
    if problems:
        print("check_android_rules: vi phạm", *problems, sep="\n  ")
        return 1
    print("check_android_rules: đạt (thư viện theo ADR 0012, strings.xml không có tools:locale; tự kiểm âm/dương đạt)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
