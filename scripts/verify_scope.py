#!/usr/bin/env python3
"""Mức kiểm của scripts/verify_local.sh theo file đổi so với merge-base(origin/main, HEAD) (Nt0 chốt 2026-10-22).

  none  chỉ android/** và tài liệu: không có bước macOS nào bị ảnh hưởng. verify_local.sh chỉ kiểm danh tính git rồi ghi
        status (bằng chứng phần Android là check `android` của CI và `local/verify-android`, review-and-merge.md mục 2).
  core  thêm oracle và test của lõi Swift mà chỉ ExamKit cùng script đọc (fixtures/invalid-json, vectors, packages,
        expected-verdicts.json, schema/, Packages/ExamKit/Tests, script kiểm đề): check.sh --core trên macOS và Linux.
  full  mọi thứ khác (code app, lõi Swift, fixtures/exams và fixtures/invalid mà test giao diện cũng đọc, script, project,
        workflow CI của macOS, chính các script kiểm này): đủ bộ như trước.

Chỉ file khớp danh sách mới hạ mức; file lạ là full (an toàn khi quên cập nhật bảng). Không có file đổi (đang ở main,
cổng) cũng là full.

  python3 scripts/verify_scope.py --git           in mức cho HEAD
  python3 scripts/verify_scope.py --files a b …   in mức cho danh sách file
  python3 scripts/verify_scope.py --self-test     đối chứng dương và âm (check.sh bước 3)
"""
from __future__ import annotations

import fnmatch
import os
import subprocess
import sys

# Không ảnh hưởng bước macOS nào. Tài liệu chỉ là Markdown; docs/install.md vào DMG nhưng verify_local.sh không đóng DMG.
NEUTRAL = ["android/*", "docs/*", "AGENTS.md", "CLAUDE.md", ".github/workflows/android.yml"]
# Chỉ lõi Swift (ExamKit/ExamFile và test của chúng) cùng script Python đọc; test giao diện ExamFeatures không đọc.
CORE = [
    "fixtures/invalid-json/*", "fixtures/vectors/*", "fixtures/packages/*", "fixtures/expected-verdicts.json",
    "fixtures/README.md", "schema/*", "Packages/ExamKit/Tests/*",
    "scripts/validate_exam.py", "scripts/check_validator_parity.py",
]
LEVELS = ["none", "core", "full"]


def level_of(path: str) -> str:
    if any(fnmatch.fnmatchcase(path, p) for p in NEUTRAL):
        return "none"
    if any(fnmatch.fnmatchcase(path, p) for p in CORE):
        return "core"
    return "full"


def scope(files: list[str]) -> tuple[str, str]:
    if not files:
        return "full", "không có file đổi so với origin/main (ở main hoặc cổng)"
    levels = {f: level_of(f) for f in files}
    worst = max(levels.values(), key=LEVELS.index)
    examples = [f for f, lv in levels.items() if lv == worst][:3]
    more = "" if sum(lv == worst for lv in levels.values()) <= 3 else ", …"
    why = {"none": "chỉ android/ và tài liệu", "core": "oracle/test lõi Swift", "full": "chạm phần macOS"}[worst]
    return worst, f"{why}: {', '.join(examples)}{more}"


def changed_files() -> list[str]:
    # EXAMSUITE_VERIFY_SCOPE_BASE: ref gốc khác origin/main, chỉ để chạy thử verify_local.sh trên worktree tạm.
    ref = os.environ.get("EXAMSUITE_VERIFY_SCOPE_BASE", "origin/main")
    base = subprocess.run(["git", "merge-base", ref, "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    out = subprocess.run(["git", "diff", "--name-only", f"{base}..HEAD"], capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line]


def self_test() -> list[str]:
    cases = {
        ("android/core/src/main/kotlin/X.kt", "docs/plans/active/android-v1.md", "AGENTS.md"): "none",
        ("android/app/build.gradle.kts", ".github/workflows/android.yml"): "none",
        ("android/core/X.kt", "fixtures/invalid-json/nan.json", "Packages/ExamKit/Tests/ExamFileTests/A.swift"): "core",
        ("fixtures/vectors/composer.json", "schema/exam-v1.schema.json", "scripts/validate_exam.py"): "core",
        # Đối chứng âm: những file sau phải là full dù đi cùng file nhẹ.
        ("android/x.kt", "Packages/ExamKit/Sources/ExamKit/Scoring/Scorer.swift"): "full",
        ("docs/a.md", "Packages/ExamFeatures/Sources/SessionFeature/X.swift"): "full",
        ("fixtures/exams/kien-thuc-chung/exam.json",): "full",
        ("fixtures/invalid/one-option.json",): "full",
        ("fixtures/large-exam.digest",): "full",
        ("Packages/ExamKit/Sources/LargeExamSupport/StandardExam.swift",): "full",
        ("scripts/verify_local.sh",): "full",
        ("scripts/verify_scope.py",): "full",
        ("scripts/check.sh",): "full",
        ("project.yml",): "full",
        ("Apps/Student/Info.plist",): "full",
        (".github/workflows/ci.yml",): "full",
        ("README.md",): "full",
        ("android-notes.md",): "full",
        (): "full",
    }
    failures = []
    for files, expected in cases.items():
        actual, _ = scope(list(files))
        if actual != expected:
            failures.append(f"{list(files)}: cần {expected}, ra {actual}")
    return failures


def main(argv: list[str]) -> int:
    if argv[:1] == ["--self-test"]:
        failures = self_test()
        if failures:
            print("verify_scope: tự kiểm thất bại:", *failures, sep="\n  ")
            return 1
        print("verify_scope: tự kiểm dương/âm đạt")
        return 0
    if argv[:1] == ["--git"]:
        files = changed_files()
    elif argv[:1] == ["--files"]:
        files = argv[1:]
    else:
        print(__doc__)
        return 2
    level, reason = scope(files)
    print(f"scope: {level}")
    print(f"reason: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
