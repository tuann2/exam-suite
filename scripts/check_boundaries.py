#!/usr/bin/env python3
"""Kiểm tra các ranh giới kiến trúc đã được chấp nhận.

1. Packages/ExamKit (module ExamKit, ExamFile) chỉ import Foundation,
   ZIPFoundation (riêng ExamFile) và lẫn nhau — không SwiftUI/AppKit/SwiftData/
   Combine/UIKit/Cocoa — để test chạy được trên Linux.
   Thẩm quyền: docs/decisions/0008-loi-foundation-only.md
2. Bản Học viên không chứa code Soạn đề hay import đề: StudentShell (Packages/ExamFeatures)
   không phụ thuộc, trực tiếp hay gián tiếp, vào AuthoringFeature, AuthoringData, ExamImport;
   target ExamSuite trong project.yml chỉ phụ thuộc đúng product StudentShell (danh sách cho phép, không
   target/framework/templates khác); Apps/Student không import chúng. Bản iOS cũng là bản Học viên: MobileShell
   (Packages/MobileFeatures) không phụ thuộc (gián tiếp) chúng hay AdminShell, target ExamSuiteiOS chỉ phụ thuộc đúng
   product MobileShell, Apps/StudentiOS không import chúng (docs/product/plan-ios-v1.md Phần 3). Đồ thị phụ thuộc
   gồm cả module dùng chung của Packages/SharedFeatures (LibraryData, InterfaceCore, SessionModel).
   Thẩm quyền: docs/decisions/0003-hai-ban-app-mot-codebase.md,
   docs/plans/completed/giai-doan-4-soan-de.md (Decisions 2026-10-16)
3. AuthoringData (mô hình chỉnh sửa đề, không giao diện) chỉ import Foundation, ExamKit, ExamFile;
   ExamImport (import đề, không giao diện) chỉ import Foundation, ExamKit, ExamFile, ZIPFoundation.
   Thẩm quyền: docs/plans/completed/giai-doan-4-soan-de.md (bước 1, 2), docs/product/import.md
4. Thư viện ngoài ZIPFoundation chỉ được import trong ExamFile và ExamImport (Admin, đọc .docx)
   cùng test target của hai module đó; không ở module, test hay app nào khác.
   Thẩm quyền: docs/decisions/0006-thu-vien-ngoai.md (Nt0 duyệt thêm ExamImport 2026-10-16)
5. swift-snapshot-testing (product SnapshotTesting) chỉ trong test: `import SnapshotTesting` chỉ ở
   Packages/ExamFeatures/Tests/**; trong Package.swift product này chỉ nằm trong `.testTarget`; không target
   nào khác của gói (theo `swift package describe`) phụ thuộc nó; project.yml (hai app, UI test) không nhắc tới nó
   và chỉ dùng gói cục bộ `path: Packages/<tên>` (đọc spec đã phân giải bằng `xcodegen dump --type json` nếu có
   xcodegen, không thì theo ngữ pháp dòng chặt). Không dùng product khác của gói đó (InlineSnapshotTesting kéo
   swift-syntax).
   Thẩm quyền: docs/decisions/0010-snapshot-testing.md
6. Gói SwiftPM ngoài chỉ có ZIPFoundation và swift-snapshot-testing (`.package(url:)` trong mọi Package.swift);
   gói cục bộ chỉ trong Packages/; mọi target (kể cả test, theo `swift package describe`) chỉ dùng product ExamKit,
   ExamFile, ZIPFoundation, SnapshotTesting, LargeExamSupport (hai product sau chỉ ở test, luật 5 và 7) và product
   của gói cục bộ Packages/SharedFeatures (LibraryData, InterfaceCore, SessionModel); gói có `.package(url:)` phải có Package.resolved, và file đó chỉ ghim
   cặp (identity, location) của hai gói đó và các gói mà manifest của swift-snapshot-testing kéo theo (tải về nhưng
   không biên dịch, không link vào target nào của ta).
   Thẩm quyền: docs/decisions/0006-thu-vien-ngoai.md, docs/decisions/0010-snapshot-testing.md
7. LargeExamSupport (đề chuẩn và đo thời gian, chỉ cho test) chỉ được test target phụ thuộc: không target
   thường hay product nào khác của mọi package trong Packages/, không file nào trong Packages/*/Sources (ngoài chính nó)
   hay Apps import nó, project.yml không nhắc nó. Thẩm quyền: docs/product/large-exams.md (đề chuẩn sinh khi chạy
   test), docs/plans/completed/giai-doan-5-hoan-thien.md (bước 2, Decisions)
8. ReportFeature (PDF/In dùng chung hai bản app) chỉ phụ thuộc trực tiếp ExamKit, ExamFile, LibraryData,
   InterfaceCore (tra chữ qua InterfaceStrings; thay LibraryFeature từ bước I1 của plan iOS); không phụ thuộc (gián
   tiếp) module chỉ của bản Admin; mã nguồn
   không import module Admin, shell hay SessionFeature (SessionFeature dựng báo cáo kết quả và phụ thuộc
   ReportFeature, không ngược lại).
   Thẩm quyền: docs/decisions/0003-hai-ban-app-mot-codebase.md, docs/product/export-print.md (Cách làm),
   docs/plans/completed/giai-doan-5-hoan-thien.md (bước 5, Decisions 5a)

Mỗi lần chạy, các hàm kiểm được thử trước trên đầu vào cố ý sai (đối chứng âm) và đầu vào đúng
(đối chứng dương); hàm kiểm không bắt được đối chứng âm thì script thất bại, để phép kiểm không
âm thầm hỏng.

Dùng: scripts/check_boundaries.py            (cần `swift` trên PATH cho mục 2)
      scripts/check_boundaries.py --no-swift (bỏ qua phần cần swift package describe)
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FORBIDDEN_IN_CORE = {"SwiftUI", "AppKit", "SwiftData", "Combine", "UIKit", "Cocoa", "CoreData"}
ALLOWED_IN_CORE = {
    "ExamKit": {"Foundation", "ExamKit"},
    "ExamFile": {"Foundation", "ExamKit", "ExamFile", "ZIPFoundation"},
}
# Module chỉ bản Admin được chứa (ADR 0003). ExamImport (giai đoạn 4, bước 2) có thể chưa tồn tại:
# kiểm đồ thị/project.yml/import vẫn đúng khi module chưa có.
ADMIN_ONLY_MODULES = ("AuthoringFeature", "AuthoringData", "ExamImport")
# Module không giao diện của bản Admin (trong Packages/ExamFeatures/Sources): import được phép.
ALLOWED_IN_ADMIN_DATA = {
    "AuthoringData": {"Foundation", "ExamKit", "ExamFile", "AuthoringData"},
    # docs/product/import.md: bộ chuyển đổi không giao diện; ZIPFoundation để đọc .docx (ADR 0006).
    "ExamImport": {"Foundation", "ExamKit", "ExamFile", "ZIPFoundation", "ExamImport"},
}
# Câu lệnh import của Swift 6: thuộc tính tuỳ ý (`@testable`, `@preconcurrency`, `@_exported`,
# `@_implementationOnly`, `@_spi(X)`…), mức truy cập (`public`/`package`/`internal`/… import), loại khai báo
# (`import struct X.Y`). Trước `import` chỉ khoảng trắng trong dòng ([ \t]) để regex không nuốt dòng trước;
# nhiều câu lệnh trên một dòng (`import A; import B`) được tách theo `;` trong `imported_modules`.
_ATTRIBUTE = r"@[A-Za-z_][A-Za-z0-9_]*(?:\([^)\n]*\))?[ \t]+"
IMPORT_RE = re.compile(
    r"^[ \t]*(?:" + _ATTRIBUTE + r")*"
    r"(?:(?:public|package|internal|fileprivate|private|open)[ \t]+)?"
    r"(?:" + _ATTRIBUTE + r")*"
    r"import\s+(?:(?:struct|class|enum|protocol|typealias|func|var|let)\s+)?([A-Za-z_][A-Za-z0-9_]*)",
    re.M,
)


def imported_modules(text: str) -> list[str]:
    """Tên module được import trong `text` (một file Swift)."""
    return IMPORT_RE.findall(text.replace(";", "\n"))


def source_files(directory: Path) -> list[tuple[str, str]]:
    """(đường dẫn hiển thị, nội dung) của mọi file .swift trong `directory`."""
    return [(str(f.relative_to(ROOT)), f.read_text(encoding="utf-8")) for f in sorted(directory.rglob("*.swift"))]


def import_problems(module: str, allowed: set[str], files: list[tuple[str, str]], hint: str) -> list[str]:
    problems: list[str] = []
    for path, text in files:
        for name in imported_modules(text):
            if name in FORBIDDEN_IN_CORE or name not in allowed:
                problems.append(f"{path} import {name}: module {module} chỉ được import {sorted(allowed)} ({hint}).")
    return problems


def check_module_imports() -> list[str]:
    problems: list[str] = []
    for module, allowed in ALLOWED_IN_CORE.items():
        problems += import_problems(
            module, allowed, source_files(ROOT / "Packages" / "ExamKit" / "Sources" / module),
            "docs/decisions/0008-loi-foundation-only.md; chuyển code phụ thuộc Apple framework sang Packages/ExamFeatures",
        )
    for module, allowed in ALLOWED_IN_ADMIN_DATA.items():
        directory = ROOT / "Packages" / "ExamFeatures" / "Sources" / module
        if not directory.is_dir():
            problems.append(f"Packages/ExamFeatures/Sources/{module}: không thấy thư mục module (đổi tên thì sửa script).")
            continue
        problems += import_problems(
            module, allowed, source_files(directory),
            "không giao diện, docs/plans/completed/giai-doan-4-soan-de.md bước 1–2 và docs/product/import.md; "
            "giao diện thuộc AuthoringFeature",
        )
    return problems


# Thư mục (Packages/<gói>/<Sources|Tests>/<target>) được import ZIPFoundation (ADR 0006).
ZIP_ALLOWED_DIRS = {("Sources", "ExamFile"), ("Sources", "ExamImport"), ("Tests", "ExamFileTests"),
                    ("Tests", "ExamImportTests")}


def check_zipfoundation_imports(root: Path = ROOT) -> list[str]:
    """Mọi file .swift trong Packages/*/{Sources,Tests} và Apps: chỉ thư mục trong ZIP_ALLOWED_DIRS được import
    ZIPFoundation."""
    problems: list[str] = []
    files = sorted((root / "Packages").glob("*/*/*/**/*.swift")) + sorted((root / "Apps").rglob("*.swift"))
    for swift in files:
        rel = swift.relative_to(root)
        if "/.build/" in "/" + rel.as_posix():
            continue
        parts = rel.parts
        if parts[0] == "Packages" and len(parts) > 4 and (parts[2], parts[3]) in ZIP_ALLOWED_DIRS:
            continue
        if "ZIPFoundation" in imported_modules(swift.read_text(encoding="utf-8")):
            problems.append(
                f"{rel} import ZIPFoundation: chỉ ExamFile, ExamImport và test của chúng được dùng ZIPFoundation "
                "(docs/decisions/0006-thu-vien-ngoai.md). Đọc/ghi zip qua ExamFile hoặc ExamImport."
            )
    return problems


def zipfoundation_self_test(import_forms: tuple[str, ...]) -> list[str]:
    """Đối chứng trên cây thư mục giả: import đúng chỗ không bị báo; import sai chỗ (Sources, Tests, Apps, mọi dạng
    câu lệnh import) bị bắt; dòng comment không tính."""
    import tempfile

    cases = {
        "Packages/ExamFeatures/Sources/ExamImport/Ok.swift": ("import ZIPFoundation\n", False),
        "Packages/ExamKit/Tests/ExamFileTests/Ok.swift": ("@testable import ExamFile\nimport ZIPFoundation\n", False),
        "Packages/ExamFeatures/Sources/AuthoringFeature/Comment.swift": ("// import ZIPFoundation\n", False),
        "Packages/ExamFeatures/Tests/LibraryDataTests/Bad.swift": ("  import ZIPFoundation\n", True),
        "Apps/Admin/Bad.swift": ("import class ZIPFoundation.Archive\n", True),
    }
    for i, form in enumerate(import_forms):
        cases[f"Packages/ExamFeatures/Sources/LibraryData/Bad{i}.swift"] = (
            "import Foundation\n" + form.format(m="ZIPFoundation"), True)
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for path, (text, _) in cases.items():
            (root / path).parent.mkdir(parents=True, exist_ok=True)
            (root / path).write_text(text, encoding="utf-8")
        reported = {p.split(" import ")[0] for p in check_zipfoundation_imports(root)}
    expected = {path for path, (_, bad) in cases.items() if bad}
    if reported != expected:
        return [f"đối chứng ZIPFoundation sai: báo {sorted(reported)}, cần {sorted(expected)}"]
    return []


# Luật 5–6: thư viện ngoài. SnapshotTesting chỉ trong test; chỉ hai gói ngoài.

SNAPSHOT_MODULE = "SnapshotTesting"
SNAPSHOT_PACKAGE = "swift-snapshot-testing"
SNAPSHOT_MODULES = {SNAPSHOT_MODULE, "InlineSnapshotTesting", "SnapshotTestingCustomDump"}
# Thư mục (Packages/<gói>/<Sources|Tests>) được import SnapshotTesting (ADR 0010).
SNAPSHOT_ALLOWED_DIRS = {("ExamFeatures", "Tests")}
# `.package(url:)` được phép (ADR 0006, 0010), so theo URL chữ thường đã bỏ `/` và `.git` ở cuối.
ALLOWED_PACKAGE_URLS = {
    "https://github.com/weichsel/zipfoundation",
    "https://github.com/pointfreeco/swift-snapshot-testing",
}
# Package.resolved: hai gói trên và các gói swift-snapshot-testing 1.19 khai báo cho product khác của nó
# (InlineSnapshotTesting, SnapshotTestingCustomDump). Product SnapshotTesting không phụ thuộc gì, nên các gói này
# được SwiftPM ghim nhưng không biên dịch hay link vào target nào của ta.
# Ghim theo cặp (identity, location): một ghim cùng tên nhưng trỏ tới bản fork vẫn bị chặn. Location so theo chữ
# thường, bỏ `/` và `.git` ở cuối. xctest-dynamic-overlay là tên cũ của swift-issue-reporting.
ALLOWED_RESOLVED_PINS = {
    ("zipfoundation", "https://github.com/weichsel/zipfoundation"),
    ("swift-snapshot-testing", "https://github.com/pointfreeco/swift-snapshot-testing"),
    ("swift-custom-dump", "https://github.com/pointfreeco/swift-custom-dump"),
    ("swift-syntax", "https://github.com/swiftlang/swift-syntax"),
    ("swift-issue-reporting", "https://github.com/pointfreeco/swift-issue-reporting"),
    ("xctest-dynamic-overlay", "https://github.com/pointfreeco/xctest-dynamic-overlay"),
}


def normalized_location(location: object) -> str:
    return str(location).lower().rstrip("/").removesuffix(".git")


def check_snapshot_imports(root: Path = ROOT) -> list[str]:
    """Mọi file .swift trong Packages/*/{Sources,Tests} và Apps: chỉ Packages/ExamFeatures/Tests/** được import
    module của swift-snapshot-testing."""
    problems: list[str] = []
    files = sorted((root / "Packages").glob("*/*/**/*.swift")) + sorted((root / "Apps").rglob("*.swift"))
    for swift in files:
        rel = swift.relative_to(root)
        if "/.build/" in "/" + rel.as_posix():
            continue
        parts = rel.parts
        if parts[0] == "Packages" and len(parts) > 3 and (parts[1], parts[2]) in SNAPSHOT_ALLOWED_DIRS:
            continue
        for name in imported_modules(swift.read_text(encoding="utf-8")):
            if name in SNAPSHOT_MODULES:
                problems.append(
                    f"{rel} import {name}: swift-snapshot-testing chỉ dùng trong Packages/ExamFeatures/Tests "
                    "(docs/decisions/0010-snapshot-testing.md). Không đưa vào code app hay lõi."
                )
    return problems


def strip_line_comments(text: str) -> str:
    """Bỏ comment `//` của Swift (không cắt `//` trong chuỗi, ví dụ URL)."""
    lines: list[str] = []
    for line in text.splitlines():
        in_string = False
        cut = len(line)
        i = 0
        while i < len(line):
            if in_string and line[i] == "\\":
                i += 2
                continue
            if line[i] == '"':
                in_string = not in_string
            elif not in_string and line.startswith("//", i):
                cut = i
                break
            i += 1
        lines.append(line[:cut])
    return "\n".join(lines)


def manifest_targets(text: str) -> list[tuple[str, str, str]]:
    """(loại, tên, nội dung) của từng khai báo target trong Package.swift (`.target(`, `.testTarget(`,
    `.executableTarget(`, `.macro(`, `.plugin(`…), bỏ comment `//`. Không cần chạy swift."""
    code = strip_line_comments(text)
    starts = [(m.start(), m.group(1)) for m in re.finditer(r"\.(\w*[tT]arget|macro|plugin)\s*\(", code)]
    result: list[tuple[str, str, str]] = []
    for index, (start, kind) in enumerate(starts):
        end = starts[index + 1][0] if index + 1 < len(starts) else len(code)
        body = code[start:end]
        name = re.search(r'name:\s*"([^"]+)"', body)
        result.append((kind, name.group(1) if name else "?", body))
    return result


def manifest_dependency_problems(path: str, text: str) -> list[str]:
    """Package.swift: `.package(url:)` chỉ là gói được duyệt; `.package(path:)` chỉ trỏ tới gói khác trong
    Packages/; product của swift-snapshot-testing chỉ là SnapshotTesting và chỉ trong `.testTarget`."""
    code = strip_line_comments(text)
    problems: list[str] = []
    for m in re.finditer(r"\.package\s*\(([^)]*)\)", code):
        args = m.group(1)
        url = re.search(r'url:\s*"([^"]+)"', args)
        local = re.search(r'path:\s*"([^"]+)"', args)
        if url:
            normalized = url.group(1).lower().rstrip("/").removesuffix(".git")
            if normalized not in ALLOWED_PACKAGE_URLS:
                problems.append(
                    f"{path}: gói ngoài {url.group(1)} chưa được duyệt. Chỉ ZIPFoundation và swift-snapshot-testing "
                    "(docs/decisions/0006-thu-vien-ngoai.md); thư viện mới cần ADR được Nt0 chấp nhận."
                )
        elif local:
            if not re.fullmatch(r"\.\./[A-Za-z][A-Za-z0-9_]*", local.group(1)):
                problems.append(f"{path}: gói cục bộ {local.group(1)} nằm ngoài Packages/ (ADR 0006).")
        else:
            problems.append(f"{path}: không hiểu .package({args.strip()}); dùng url: hoặc path: (ADR 0006).")
    for kind, name, body in manifest_targets(text):
        mentioned = set(re.findall(r'"(' + "|".join(sorted(SNAPSHOT_MODULES)) + r')"', body))
        for product in sorted(mentioned):
            if product != SNAPSHOT_MODULE:
                problems.append(
                    f"{path}: {kind} {name} dùng {product} của {SNAPSHOT_PACKAGE}: chỉ product SnapshotTesting được "
                    "duyệt (docs/decisions/0010-snapshot-testing.md)."
                )
            if kind != "testTarget":
                problems.append(
                    f"{path}: {kind} {name} phụ thuộc {product}: swift-snapshot-testing chỉ ở .testTarget "
                    "(docs/decisions/0010-snapshot-testing.md)."
                )
    return problems


def resolved_pin_problems(path: str, text: str) -> list[str]:
    """Package.resolved chỉ ghim cặp (identity, location) trong ALLOWED_RESOLVED_PINS, từ nguồn git từ xa."""
    try:
        pins = json.loads(text).get("pins", [])
    except json.JSONDecodeError as error:
        return [f"{path}: không đọc được JSON ({error})."]
    return [
        f"{path}: ghim gói {pin.get('identity')} ({pin.get('location')}, {pin.get('kind')}) chưa được duyệt "
        "(ADR 0006, 0010). Bỏ phụ thuộc rồi chạy lại `swift package resolve`, hoặc viết ADR."
        for pin in pins
        if (pin.get("identity"), normalized_location(pin.get("location"))) not in ALLOWED_RESOLVED_PINS
        or pin.get("kind") != "remoteSourceControl"
    ]


def missing_resolved_problems(path: str, manifest: str, has_resolved: bool) -> list[str]:
    """Gói có `.package(url:)` phải commit Package.resolved (ADR 0006, Follow-Up): thiếu thì SwiftPM tự lấy bản mới
    nhất trong khoảng `from:`, build không tái lập được."""
    if has_resolved or not re.search(r"\.package\s*\(\s*url:", strip_line_comments(manifest)):
        return []
    return [f"{path}: có `.package(url:)` nhưng thiếu Package.resolved cạnh nó; chạy `swift package resolve` và "
            "commit file (docs/decisions/0006-thu-vien-ngoai.md)."]


# Product của gói cục bộ Packages/SharedFeatures (phần dùng chung macOS và iOS, docs/product/plan-ios-v1.md Phần 3).
SHARED_PRODUCTS = {"LibraryData", "InterfaceCore", "SessionModel"}
# Product của gói khác mà target của ta được phụ thuộc (theo `swift package describe`): lõi, ZIPFoundation,
# SnapshotTesting (chỉ test target, luật 5), LargeExamSupport của ExamKit (chỉ test target, luật 7) và product của
# SharedFeatures. Mọi product khác, kể cả InlineSnapshotTesting, SnapshotTestingCustomDump hay
# product của các gói mà swift-snapshot-testing ghim (CustomDump, IssueReporting, SwiftSyntax…), là vi phạm.
ALLOWED_PRODUCT_DEPENDENCIES = (
    {"ExamKit", "ExamFile", "ZIPFoundation", SNAPSHOT_MODULE, "LargeExamSupport"} | SHARED_PRODUCTS
)


def described_snapshot_problems(package: str, data: dict) -> list[str]:
    """Theo `swift package describe` (tên product đã tính, kể cả khi manifest ghép chuỗi `"Inline" + "…"`): mọi
    target, kể cả test, chỉ phụ thuộc product trong ALLOWED_PRODUCT_DEPENDENCIES; SnapshotTesting chỉ ở test target."""
    problems: list[str] = []
    for target in data.get("targets", []):
        products = set(target.get("product_dependencies") or [])
        for product in sorted(products - ALLOWED_PRODUCT_DEPENDENCIES):
            problems.append(
                f"Packages/{package}: target {target['name']} ({target.get('type')}) phụ thuộc product {product} chưa "
                "được duyệt: chỉ ExamKit, ExamFile, ZIPFoundation, SnapshotTesting và product của "
                "Packages/SharedFeatures (ADR 0006, 0010)."
            )
        if SNAPSHOT_MODULE in products and target.get("type") != "test":
            problems.append(
                f"Packages/{package}: target {target['name']} ({target.get('type')}) phụ thuộc {SNAPSHOT_MODULE}: chỉ "
                "test target được (docs/decisions/0010-snapshot-testing.md)."
            )
    return problems


def project_yml_snapshot_mentions(raw: str) -> list[str]:
    """project.yml (hai app, UI test) không nhắc swift-snapshot-testing (bỏ dòng comment)."""
    text = "\n".join(line for line in raw.splitlines() if not line.lstrip().startswith("#")) + "\n"
    return [
        f"project.yml nhắc tới {word}: swift-snapshot-testing chỉ dùng trong test của Packages/ExamFeatures "
        "(docs/decisions/0010-snapshot-testing.md)."
        for word in sorted(SNAPSHOT_MODULES | {SNAPSHOT_PACKAGE})
        if re.search(rf"\b{re.escape(word)}\b", text)
    ]


LOCAL_PACKAGE_PATH = re.compile(r"Packages/[A-Za-z][A-Za-z0-9_-]*")


def spec_package_problems(spec: dict) -> list[str]:
    """Spec đã phân giải của XcodeGen (`xcodegen dump --type json`): mỗi gói ở `packages:` chỉ có đúng khoá `path`,
    trỏ tới `Packages/<tên>`; không `localPackages:`; không target nào dùng product của swift-snapshot-testing."""
    problems: list[str] = []
    packages = spec.get("packages") or {}
    if not isinstance(packages, dict):
        return [f"project.yml packages: không hiểu dạng {type(packages).__name__} (ADR 0006)."]
    for name, entry in packages.items():
        keys = sorted(entry) if isinstance(entry, dict) else [repr(entry)]
        path = entry.get("path") if isinstance(entry, dict) else None
        if keys != ["path"] or not isinstance(path, str) or not LOCAL_PACKAGE_PATH.fullmatch(path):
            problems.append(
                f"project.yml packages: {name} ({', '.join(f'{k}' for k in keys)}"
                f"{f': {path}' if isinstance(path, str) else ''}) không phải gói cục bộ trong Packages/: app chỉ "
                "dùng gói `path: Packages/<tên>` (docs/decisions/0006-thu-vien-ngoai.md)."
            )
    if spec.get("localPackages"):
        problems.append("project.yml dùng `localPackages:`: khai báo gói cục bộ ở `packages:` với `path:` (ADR 0006).")
    for target, body in (spec.get("targets") or {}).items():
        for dependency in (body or {}).get("dependencies") or []:
            if isinstance(dependency, dict) and (dependency.get("product") in SNAPSHOT_MODULES
                                                 or dependency.get("package") == SNAPSHOT_PACKAGE):
                problems.append(
                    f"project.yml target {target} phụ thuộc {dependency}: swift-snapshot-testing chỉ dùng trong test "
                    "của Packages/ExamFeatures (docs/decisions/0010-snapshot-testing.md)."
                )
    return problems


def project_yml_grammar_problems(raw: str) -> list[str]:
    """Khi không có xcodegen: khối `packages:` phải theo đúng ngữ pháp dòng
    `packages:` / `  <Tên>:` / `    path: Packages/<tên>` (lặp lại; dòng trống và dòng chỉ có comment được bỏ qua).
    Mọi dạng khác (flow `{…}`, khoá trong dấu nháy `"packages":`, thụt lề khác, comment cuối dòng, khoá thêm,
    `localPackages:`, `include:`) là thất bại, vì kiểm tĩnh không lần được."""
    lines = raw.splitlines()
    problems: list[str] = []
    name_line = re.compile(r"  ([A-Za-z][A-Za-z0-9_-]*):")
    path_line = re.compile(r"    path: (" + LOCAL_PACKAGE_PATH.pattern + r")")
    for index, line in enumerate(lines):
        # Khoá cấp gốc, kể cả trong dấu nháy (`"packages":`, `'packages':`) hay mở đầu bằng flow `{`.
        key = re.match(r"""\{?\s*(["']?)([A-Za-z_][A-Za-z0-9_]*)\1\s*:""", line)
        if not key or key.group(2) not in ("packages", "localPackages", "include"):
            continue
        if line != "packages:":
            problems.append(
                f"project.yml dòng {index + 1} `{line}`: chỉ chấp nhận khối `packages:` dạng thường (gói cục bộ "
                "`path: Packages/<tên>`); dạng này kiểm tĩnh không được, cài xcodegen để kiểm theo spec (ADR 0006)."
            )
            continue
        body = []
        for number in range(index + 1, len(lines)):
            text = lines[number]
            if not text.strip() or text.lstrip().startswith("#"):
                continue
            if not text.startswith((" ", "\t")):
                break
            body.append((number + 1, text))
        expecting_name = True
        for number, text in body:
            pattern = name_line if expecting_name else path_line
            if not pattern.fullmatch(text):
                wanted = "`  <Tên>:`" if expecting_name else "`    path: Packages/<tên>`"
                problems.append(
                    f"project.yml dòng {number} `{text.strip()}`: trong `packages:` chỉ chấp nhận {wanted} "
                    "(gói cục bộ trong Packages/, docs/decisions/0006-thu-vien-ngoai.md)."
                )
                break
            expecting_name = not expecting_name
        else:
            if not expecting_name:
                problems.append("project.yml packages: gói cuối thiếu `path: Packages/<tên>` (ADR 0006).")
    return problems


def xcodegen_spec(project: Path) -> dict | None:
    """Spec đã phân giải bằng `xcodegen dump --type json`; nil khi không có xcodegen."""
    if shutil.which("xcodegen") is None:
        return None
    out = subprocess.run(
        ["xcodegen", "dump", "--type", "json", "--spec", str(project)],
        cwd=project.parent, capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)


def project_yml_mode() -> str:
    """Cách luật 6 kiểm project.yml trong lần chạy này (in ở dòng `ok`)."""
    return "`xcodegen dump`" if shutil.which("xcodegen") else "ngữ pháp dòng (không có xcodegen)"


def project_yml_package_problems(raw: str, spec: dict | None) -> list[str]:
    """project.yml không nhắc swift-snapshot-testing, và chỉ dùng gói cục bộ trong Packages/: theo spec của XcodeGen
    nếu có, không thì theo ngữ pháp dòng chặt."""
    return project_yml_snapshot_mentions(raw) + (
        spec_package_problems(spec) if spec is not None else project_yml_grammar_problems(raw)
    )


def check_external_packages(use_swift: bool) -> list[str]:
    problems = check_snapshot_imports()
    for manifest in sorted((ROOT / "Packages").glob("*/Package.swift")):
        rel = str(manifest.relative_to(ROOT))
        problems += manifest_dependency_problems(rel, manifest.read_text(encoding="utf-8"))
        resolved = manifest.with_name("Package.resolved")
        problems += missing_resolved_problems(rel, manifest.read_text(encoding="utf-8"), resolved.exists())
        if resolved.exists():
            problems += resolved_pin_problems(str(resolved.relative_to(ROOT)), resolved.read_text(encoding="utf-8"))
        if use_swift:
            problems += described_snapshot_problems(manifest.parent.name, package_description(manifest.parent))
    project = ROOT / "project.yml"
    problems += project_yml_package_problems(project.read_text(encoding="utf-8"), xcodegen_spec(project))
    return problems


def snapshot_self_test(import_forms: tuple[str, ...]) -> list[str]:
    """Đối chứng cho luật 5–6: import SnapshotTesting sai chỗ, product trong target thường, gói ngoài lạ, ghim lạ,
    project.yml nhắc thư viện hay dùng gói từ xa đều bị bắt; cách dùng đúng không bị báo."""
    import tempfile

    failures: list[str] = []
    cases = {
        "Packages/ExamFeatures/Tests/ExamFeaturesSnapshotTests/Ok.swift": ("import SnapshotTesting\n", False),
        "Packages/ExamFeatures/Tests/ExamFeaturesSnapshotTests/Support/Ok.swift": (
            "@testable import SessionFeature\nimport SnapshotTesting\n", False),
        "Packages/ExamFeatures/Sources/SessionFeature/Comment.swift": ("// import SnapshotTesting\n", False),
        "Packages/ExamKit/Tests/ExamKitTests/Bad.swift": ("import SnapshotTesting\n", True),
        "Packages/ExamFeatures/Sources/LibraryFeature/BadInline.swift": ("import InlineSnapshotTesting\n", True),
        "Apps/Student/Bad.swift": ("import struct SnapshotTesting.Snapshotting\n", True),
        "Apps/StudentUITests/Bad.swift": ("@testable import SnapshotTesting\n", True),
    }
    for i, form in enumerate(import_forms):
        cases[f"Packages/ExamFeatures/Sources/StudentShell/Bad{i}.swift"] = (
            "import SwiftUI\n" + form.format(m="SnapshotTesting"), True)
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for path, (text, _) in cases.items():
            (root / path).parent.mkdir(parents=True, exist_ok=True)
            (root / path).write_text(text, encoding="utf-8")
        reported = {p.split(" import ")[0] for p in check_snapshot_imports(root)}
    expected = {path for path, (_, bad) in cases.items() if bad}
    if reported != expected:
        failures.append(f"đối chứng import SnapshotTesting sai: báo {sorted(reported)}, cần {sorted(expected)}")

    good_manifest = """
        dependencies: [
            .package(path: "../ExamKit"),
            .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
            .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.19.6"),
        ],
        targets: [
            .target(name: "LibraryFeature", dependencies: ["LibraryData"]),
            // .target(name: "Old", dependencies: [.product(name: "SnapshotTesting", package: "swift-snapshot-testing")]),
            .testTarget(
                name: "ExamFeaturesSnapshotTests",
                dependencies: ["SessionFeature", .product(name: "SnapshotTesting", package: "swift-snapshot-testing")]
            ),
        ]
    """
    good_problems = manifest_dependency_problems("Package.swift", good_manifest)
    if good_problems:
        failures.append(f"đối chứng dương Package.swift bị báo sai: {good_problems}")
    library_target = '.target(name: "LibraryFeature", dependencies: ["LibraryData"])'
    bad_manifests = {
        "SnapshotTesting trong .target": good_manifest.replace(
            library_target,
            '.target(name: "LibraryFeature", dependencies: [.product(name: "SnapshotTesting", '
            'package: "swift-snapshot-testing")])'),
        "SnapshotTesting trong .executableTarget, xuống dòng": good_manifest.replace(
            library_target,
            '.executableTarget(\n name: "Tool",\n dependencies: [\n .product(\n name: "SnapshotTesting",\n'
            ' package: "swift-snapshot-testing"\n )\n ]\n )'),
        "InlineSnapshotTesting trong test": good_manifest.replace(
            'product(name: "SnapshotTesting"', 'product(name: "InlineSnapshotTesting"'),
        "gói ngoài lạ": good_manifest.replace(
            '.package(path: "../ExamKit"),',
            '.package(path: "../ExamKit"),\n .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),'),
        "gói cục bộ ngoài Packages": good_manifest.replace('.package(path: "../ExamKit")', '.package(path: "/tmp/Vendor")'),
    }
    for name, text in bad_manifests.items():
        if not manifest_dependency_problems("Package.swift", text):
            failures.append(f"đối chứng âm Package.swift '{name}' không bị bắt")

    def pin(identity: str, location: str, kind: str = "remoteSourceControl") -> dict:
        return {"identity": identity, "kind": kind, "location": location, "state": {"version": "1.0.0"}}

    good_pins = [
        pin("zipfoundation", "https://github.com/weichsel/ZIPFoundation.git"),
        pin("swift-snapshot-testing", "https://github.com/pointfreeco/swift-snapshot-testing.git"),
        pin("swift-syntax", "https://github.com/swiftlang/swift-syntax"),
    ]
    if resolved_pin_problems("Package.resolved", json.dumps({"pins": good_pins})):
        failures.append("đối chứng dương Package.resolved bị báo sai")
    bad_pins = {
        "ghim gói lạ": pin("grdb.swift", "https://github.com/groue/GRDB.swift"),
        "swift-syntax trỏ tới fork": pin("swift-syntax", "https://github.com/attacker/swift-syntax"),
        "ZIPFoundation trỏ tới fork": pin("zipfoundation", "https://gitlab.com/someone/ZIPFoundation.git"),
        "ghim cục bộ": pin("swift-snapshot-testing", "https://github.com/pointfreeco/swift-snapshot-testing",
                           kind="localSourceControl"),
    }
    for name, bad in bad_pins.items():
        if not resolved_pin_problems("Package.resolved", json.dumps({"pins": good_pins + [bad]})):
            failures.append(f"đối chứng âm Package.resolved ({name}) không bị bắt")
    remote_manifest = 'dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")]'
    if not missing_resolved_problems("Package.swift", remote_manifest, has_resolved=False):
        failures.append("đối chứng âm thiếu Package.resolved không bị bắt")
    if missing_resolved_problems("Package.swift", remote_manifest, has_resolved=True) or missing_resolved_problems(
            "Package.swift", 'dependencies: [.package(path: "../ExamKit")] // .package(url: "x")', has_resolved=False):
        failures.append("đối chứng dương Package.resolved (có file, hay chỉ gói cục bộ) bị báo sai")

    good_describe = {"targets": [
        {"name": "LibraryFeature", "type": "library", "product_dependencies": ["ExamKit"]},
        {"name": "ExamFeaturesSnapshotTests", "type": "test", "product_dependencies": ["ExamKit", "SnapshotTesting"]},
    ]}
    if described_snapshot_problems("ExamFeatures", good_describe):
        failures.append("đối chứng dương describe bị báo sai")
    for kind in ("library", "executable", "macro"):
        bad = {"targets": [{"name": "X", "type": kind, "product_dependencies": ["SnapshotTesting"]}]}
        if not described_snapshot_problems("ExamFeatures", bad):
            failures.append(f"đối chứng âm describe (target {kind} phụ thuộc SnapshotTesting) không bị bắt")
    # Product khác của gói (hay của gói nó ghim) bị bắt ở mọi loại target, kể cả test: manifest có thể ghép tên bằng
    # biểu thức (`"Inline" + "SnapshotTesting"`) mà regex không thấy, nhưng `describe` thấy tên đã tính (review #41, P3-1).
    for product in ("InlineSnapshotTesting", "SnapshotTestingCustomDump", "CustomDump", "SwiftSyntax", "IssueReporting"):
        for kind in ("test", "library"):
            bad = {"targets": [{"name": "X", "type": kind, "product_dependencies": ["ExamKit", product]}]}
            if not any(product in p for p in described_snapshot_problems("ExamFeatures", bad)):
                failures.append(f"đối chứng âm describe (target {kind} phụ thuộc {product}) không bị bắt")

    good_yml = (
        "# swift-snapshot-testing chỉ ở test (comment không tính)\n"
        "packages:\n  ExamFeatures:\n    path: Packages/ExamFeatures\ntargets:\n  ExamSuite:\n    dependencies:\n"
        "      - package: ExamFeatures\n        product: StudentShell\n"
    )
    good_spec = {"packages": {"ExamFeatures": {"path": "Packages/ExamFeatures"}},
                 "targets": {"ExamSuite": {"dependencies": [{"package": "ExamFeatures", "product": "StudentShell"}]}}}
    good_yml_problems = project_yml_package_problems(good_yml, None) + project_yml_package_problems(good_yml, good_spec)
    if good_yml_problems:
        failures.append(f"đối chứng dương project.yml bị báo sai: {good_yml_problems}")
    if not project_yml_package_problems(good_yml.replace(
            "        product: StudentShell\n",
            "        product: StudentShell\n      - package: Snap\n        product: SnapshotTesting\n"), None):
        failures.append("đối chứng âm project.yml 'app phụ thuộc SnapshotTesting' không bị bắt")
    grdb = "url: https://github.com/groue/GRDB.swift"
    # Năm dạng YAML hợp lệ (XcodeGen nhận) từng lọt qua kiểm bằng regex (review #41, P2-2), kèm spec XcodeGen dựng ra.
    bypasses = {
        "dạng flow": (
            good_yml.replace("packages:\n", "packages:\n  GRDB: {" + grdb + ", from: 7.0.0}\n"),
            {"GRDB": {"url": "https://github.com/groue/GRDB.swift", "from": "7.0.0"}}),
        "packages thụt 4 dấu cách": (
            good_yml.replace("packages:\n  ExamFeatures:\n    path: Packages/ExamFeatures\n",
                             "packages:\n    ExamFeatures:\n        path: Packages/ExamFeatures\n"
                             "    GRDB:\n        " + grdb + "\n        from: 7.0.0\n"),
            {"GRDB": {"url": "https://github.com/groue/GRDB.swift", "from": "7.0.0"}}),
        "có cả url và path": (
            good_yml.replace("packages:\n", "packages:\n  Snap:\n    " + grdb + "\n    path: Packages/Snap\n"),
            {"Snap": {"url": "https://github.com/groue/GRDB.swift", "path": "Packages/Snap"}}),
        "comment cuối dòng tên gói": (
            good_yml.replace("packages:\n", "packages:\n  GRDB: # db\n    " + grdb + "\n    from: 7.0.0\n"),
            {"GRDB": {"url": "https://github.com/groue/GRDB.swift", "from": "7.0.0"}}),
        "comment cột 0 giữa khối": (
            good_yml.replace("    path: Packages/ExamFeatures\n",
                             "    path: Packages/ExamFeatures\n# ghi chú\n  GRDB:\n    " + grdb + "\n    from: 7.0.0\n"),
            {"GRDB": {"url": "https://github.com/groue/GRDB.swift", "from": "7.0.0"}}),
        "khoá packages trong nháy kép": (
            good_yml.replace("packages:\n", '"packages":\n  GRDB:\n    ' + grdb + "\n    from: 7.0.0\n"),
            {"GRDB": {"url": "https://github.com/groue/GRDB.swift", "from": "7.0.0"}}),
        "khoá packages trong nháy đơn": (
            good_yml.replace("packages:\n", "'packages':\n  GRDB:\n    " + grdb + "\n    from: 7.0.0\n"),
            {"GRDB": {"url": "https://github.com/groue/GRDB.swift", "from": "7.0.0"}}),
        "path ngoài Packages/": (
            good_yml.replace("packages:\n", "packages:\n  Vendor:\n    path: ../Vendor/Snap\n"),
            {"Vendor": {"path": "../Vendor/Snap"}}),
    }
    for name, (text, extra) in bypasses.items():
        spec = {**good_spec, "packages": {**good_spec["packages"], **extra}}
        if not project_yml_package_problems(text, None):
            failures.append(f"đối chứng âm project.yml '{name}' (ngữ pháp dòng, không xcodegen) không bị bắt")
        if not project_yml_package_problems(text, spec):
            failures.append(f"đối chứng âm project.yml '{name}' (spec XcodeGen) không bị bắt")
    for name, spec in {
        "localPackages": {**good_spec, "localPackages": ["../Vendor"]},
        "target dùng product SnapshotTesting": {**good_spec, "targets": {"ExamSuite": {"dependencies": [
            {"package": "ExamFeatures", "product": "StudentShell"}, {"package": "Snap", "product": "SnapshotTesting"}]}}},
    }.items():
        if not spec_package_problems(spec):
            failures.append(f"đối chứng âm spec XcodeGen '{name}' không bị bắt")
    # Có xcodegen thì chạy thật `xcodegen dump` trên các dạng vượt rào: spec nó dựng ra phải bị bắt.
    if shutil.which("xcodegen") is not None:
        with tempfile.TemporaryDirectory() as tmp:
            for name, (text, _) in {"đúng": (good_yml, None), **bypasses}.items():
                project = Path(tmp) / "project.yml"
                project.write_text("name: Probe\n" + text.replace("dependencies:", "type: application\n"
                                   "    platform: macOS\n    dependencies:"), encoding="utf-8")
                found = spec_package_problems(xcodegen_spec(project))
                if name == "đúng" and found:
                    failures.append(f"đối chứng dương xcodegen dump bị báo sai: {found}")
                elif name != "đúng" and not found:
                    failures.append(f"đối chứng âm xcodegen dump '{name}' không bị bắt")
    return failures


_DESCRIBED: dict[Path, dict] = {}


def package_description(package_dir: Path) -> dict:
    """`swift package describe --type json` của một package (nhớ lại để không chạy hai lần)."""
    if package_dir not in _DESCRIBED:
        out = subprocess.run(
            ["swift", "package", "describe", "--type", "json"],
            cwd=package_dir, capture_output=True, text=True, check=True,
        ).stdout
        _DESCRIBED[package_dir] = json.loads(out)
    return _DESCRIBED[package_dir]


def package_graph(*package_dirs: Path) -> dict[str, set[str]]:
    """Đồ thị target → phụ thuộc trực tiếp (target hay product) của các package, gộp lại: package giao diện gộp với
    Packages/SharedFeatures để phụ thuộc gián tiếp qua module dùng chung cũng được lần."""
    graph: dict[str, set[str]] = {}
    for package_dir in package_dirs:
        for t in package_description(package_dir)["targets"]:
            deps = set(t.get("target_dependencies") or []) | set(t.get("product_dependencies") or [])
            graph[t["name"]] = deps
    return graph


# Mục 7: module chỉ cho test (đề chuẩn + đo thời gian, docs/product/large-exams.md).
TEST_ONLY_MODULE = "LargeExamSupport"


def test_only_package_problems(package: str, description: dict) -> list[str]:
    """Trong một package: chỉ target kiểu test phụ thuộc LargeExamSupport; chỉ product cùng tên chứa nó."""
    problems: list[str] = []
    hint = ("chỉ test target được dùng (docs/product/large-exams.md; plan giai đoạn 5 bước 2). Bỏ phụ thuộc; code "
            "app không được kéo bộ sinh đề hay đo thời gian vào bản phát hành.")
    for t in description.get("targets", []):
        deps = set(t.get("target_dependencies") or []) | set(t.get("product_dependencies") or [])
        if t["name"] != TEST_ONLY_MODULE and t.get("type") != "test" and TEST_ONLY_MODULE in deps:
            problems.append(f"Packages/{package}: target {t['name']} ({t.get('type')}) phụ thuộc {TEST_ONLY_MODULE}: {hint}")
    for product in description.get("products", []):
        if product["name"] != TEST_ONLY_MODULE and TEST_ONLY_MODULE in (product.get("targets") or []):
            problems.append(f"Packages/{package}: product {product['name']} chứa target {TEST_ONLY_MODULE}: {hint}")
    return problems


def test_only_import_problems(root: Path = ROOT) -> list[str]:
    """Không file nào trong Packages/*/Sources (trừ chính LargeExamSupport) hay Apps import LargeExamSupport."""
    problems: list[str] = []
    files = sorted((root / "Packages").glob("*/Sources/**/*.swift")) + sorted((root / "Apps").rglob("*.swift"))
    for swift in files:
        rel = swift.relative_to(root)
        if "/.build/" in "/" + rel.as_posix():
            continue
        if rel.parts[0] == "Packages" and len(rel.parts) > 3 and rel.parts[3] == TEST_ONLY_MODULE:
            continue
        if TEST_ONLY_MODULE in imported_modules(swift.read_text(encoding="utf-8")):
            problems.append(f"{rel} import {TEST_ONLY_MODULE}: module chỉ cho test (docs/product/large-exams.md); "
                            "chuyển code đo/sinh đề vào Tests.")
    return problems


# Import được phép trong chính LargeExamSupport: như lõi (chạy cả trên Linux), thêm CommonCrypto chỉ trong
# `#if canImport(CommonCrypto)` (băm tên ảnh nhanh trên macOS; Linux dùng MediaNaming của ExamFile).
TEST_ONLY_ALLOWED_IMPORTS = {"Foundation", "ExamKit", "ExamFile", TEST_ONLY_MODULE, "CommonCrypto"}
COMMON_CRYPTO_GUARD = "canImport(CommonCrypto)"


def test_only_module_import_problems(files: list[tuple[str, str]]) -> list[str]:
    """Import của các file trong Packages/ExamKit/Sources/LargeExamSupport: chỉ TEST_ONLY_ALLOWED_IMPORTS; CommonCrypto
    chỉ trong nhánh `#if canImport(CommonCrypto)` (không trong `#else`)."""
    problems: list[str] = []
    for path, text in files:
        branches: list[str] = []  # điều kiện của các nhánh #if đang mở ("else" khi ở nhánh #else/#elseif)
        for line in text.replace(";", "\n").splitlines():
            stripped = line.strip()
            if stripped.startswith("#if "):
                branches.append(stripped[4:].strip())
            elif stripped.startswith(("#elseif", "#else")) and branches:
                branches[-1] = "else"
            elif stripped.startswith("#endif") and branches:
                branches.pop()
            for name in imported_modules(line):
                if name not in TEST_ONLY_ALLOWED_IMPORTS:
                    problems.append(f"{path} import {name}: {TEST_ONLY_MODULE} chỉ được import "
                                    f"{sorted(TEST_ONLY_ALLOWED_IMPORTS)} (chạy cả trên Linux như lõi, ADR 0008).")
                elif name == "CommonCrypto" and COMMON_CRYPTO_GUARD not in branches:
                    problems.append(f"{path} import CommonCrypto ngoài `#if {COMMON_CRYPTO_GUARD}`: Linux không có "
                                    "CommonCrypto; bọc trong #if và giữ nhánh MediaNaming cho Linux.")
    return problems


def test_only_project_yml_problems(raw: str) -> list[str]:
    text = "\n".join(line for line in raw.splitlines() if not line.lstrip().startswith("#"))
    if re.search(rf"\b{TEST_ONLY_MODULE}\b", text):
        return [f"project.yml nhắc {TEST_ONLY_MODULE}: target app không được phụ thuộc module chỉ cho test."]
    return []


def check_test_only_module(use_swift: bool) -> list[str]:
    problems: list[str] = []
    if use_swift:
        for manifest in sorted((ROOT / "Packages").glob("*/Package.swift")):
            problems += test_only_package_problems(manifest.parent.name, package_description(manifest.parent))
    problems += test_only_import_problems()
    problems += test_only_module_import_problems(
        source_files(ROOT / "Packages" / "ExamKit" / "Sources" / TEST_ONLY_MODULE))
    problems += test_only_project_yml_problems((ROOT / "project.yml").read_text(encoding="utf-8"))
    return problems


def test_only_self_test(import_forms: tuple[str, ...]) -> list[str]:
    """Đối chứng cho mục 7: test target được dùng; target thường, product khác, import trong Sources/Apps,
    project.yml bị bắt."""
    import tempfile

    failures: list[str] = []
    good = {
        "targets": [
            {"name": "LargeExamSupport", "type": "library", "target_dependencies": ["ExamKit", "ExamFile"]},
            {"name": "ExamFileTests", "type": "test", "target_dependencies": ["ExamFile", "LargeExamSupport"]},
            {"name": "LibraryDataTests", "type": "test", "product_dependencies": ["ExamKit", "LargeExamSupport"]},
            {"name": "LibraryData", "type": "library", "product_dependencies": ["ExamKit"]},
        ],
        "products": [{"name": "LargeExamSupport", "targets": ["LargeExamSupport"]},
                     {"name": "StudentShell", "targets": ["StudentShell"]}],
    }
    if test_only_package_problems("X", good):
        failures.append(f"đối chứng dương LargeExamSupport bị báo sai: {test_only_package_problems('X', good)}")
    bad_target = json.loads(json.dumps(good))
    bad_target["targets"][3]["product_dependencies"].append("LargeExamSupport")
    bad_exec = json.loads(json.dumps(good))
    bad_exec["targets"].append({"name": "Bench", "type": "executable", "target_dependencies": ["LargeExamSupport"]})
    bad_product = json.loads(json.dumps(good))
    bad_product["products"][1]["targets"].append("LargeExamSupport")
    for name, description, mention in (("target thường", bad_target, "LibraryData"),
                                       ("executable", bad_exec, "Bench"),
                                       ("product khác", bad_product, "StudentShell")):
        if not any(mention in p for p in test_only_package_problems("X", description)):
            failures.append(f"đối chứng âm LargeExamSupport ({name}) không bị bắt")
    yml_ok = "# LargeExamSupport chỉ cho test\ntargets:\n  ExamSuite:\n    dependencies: []\n"
    if test_only_project_yml_problems(yml_ok):
        failures.append("đối chứng dương project.yml (comment) bị báo sai")
    if not test_only_project_yml_problems(yml_ok + "      - package: ExamKit\n        product: LargeExamSupport\n"):
        failures.append("đối chứng âm project.yml nhắc LargeExamSupport không bị bắt")
    cases = {
        "Packages/ExamKit/Sources/LargeExamSupport/Ok.swift": ("import ExamKit\n", False),
        "Packages/ExamKit/Tests/ExamFileTests/Ok.swift": ("import LargeExamSupport\n", False),
        "Packages/ExamFeatures/Tests/SessionFeatureTests/Ok.swift": ("@testable import LargeExamSupport\n", False),
        "Packages/ExamFeatures/Sources/LibraryData/Comment.swift": ("// import LargeExamSupport\n", False),
        "Apps/Admin/Bad.swift": ("import LargeExamSupport\n", True),
        "Packages/ExamKit/Sources/ExamFile/Bad.swift": ("import Foundation; import LargeExamSupport\n", True),
    }
    for i, form in enumerate(import_forms):
        cases[f"Packages/ExamFeatures/Sources/SessionFeature/Bad{i}.swift"] = (form.format(m=TEST_ONLY_MODULE), True)
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for path, (text, _) in cases.items():
            (root / path).parent.mkdir(parents=True, exist_ok=True)
            (root / path).write_text(text, encoding="utf-8")
        reported = {p.split(" import ")[0] for p in test_only_import_problems(root)}
    expected = {path for path, (_, bad) in cases.items() if bad}
    if reported != expected:
        failures.append(f"đối chứng import LargeExamSupport sai: báo {sorted(reported)}, cần {sorted(expected)}")
    # Import của chính LargeExamSupport.
    guarded = "#if canImport(CommonCrypto)\n    import CommonCrypto\n#endif\nimport ExamFile\nimport Foundation\n"
    if test_only_module_import_problems([("Ok.swift", guarded)]):
        failures.append(f"đối chứng dương import trong LargeExamSupport bị báo sai: "
                        f"{test_only_module_import_problems([('Ok.swift', guarded)])}")
    for name, text, mention in (
        ("SwiftUI", "import Foundation\nimport SwiftUI\n", "SwiftUI"),
        ("ZIPFoundation", "@testable import ZIPFoundation\n", "ZIPFoundation"),
        ("LibraryData", "import LibraryData\n", "LibraryData"),
        ("CommonCrypto không bọc", "import CommonCrypto\nimport Foundation\n", "CommonCrypto"),
        ("CommonCrypto ở #else", "#if canImport(CommonCrypto)\nimport Foundation\n#else\nimport CommonCrypto\n#endif\n",
         "CommonCrypto"),
        ("CommonCrypto sau #endif", "#if canImport(CommonCrypto)\n#endif\nimport CommonCrypto\n", "CommonCrypto"),
    ):
        if not any(mention in p for p in test_only_module_import_problems([("Bad.swift", text)])):
            failures.append(f"đối chứng âm import trong LargeExamSupport ({name}) không bị bắt")
    for form in import_forms:
        if not test_only_module_import_problems([("Bad.swift", form.format(m="AppKit"))]):
            failures.append(f"đối chứng âm import trong LargeExamSupport ({form.strip()}) không bị bắt")
    return failures


def transitive(graph: dict[str, set[str]], start: str) -> set[str]:
    seen: set[str] = set()
    stack = [start]
    while stack:
        n = stack.pop()
        for d in graph.get(n, ()):
            if d not in seen:
                seen.add(d)
                stack.append(d)
    return seen


def student_graph_problems(graph: dict[str, set[str]]) -> list[str]:
    """StudentShell không được phụ thuộc (gián tiếp) module chỉ của bản Admin."""
    if "StudentShell" not in graph:
        return ["Packages/ExamFeatures: không thấy target StudentShell."]
    deps = transitive(graph, "StudentShell")
    return [
        f"Packages/ExamFeatures: StudentShell phụ thuộc (gián tiếp) {bad}. Bản Học viên không được chứa code "
        "Soạn đề hay import đề (docs/decisions/0003-hai-ban-app-mot-codebase.md). Bỏ phụ thuộc hoặc chuyển "
        "phần dùng chung sang LibraryData/LibraryFeature/SessionFeature."
        for bad in ADMIN_ONLY_MODULES if bad in deps
    ]


ALLOWED_EXAMSUITE_DEPENDENCIES = [{"package": "ExamFeatures", "product": "StudentShell"}]


def examsuite_dependencies(block: str) -> tuple[list[dict[str, str]], list[str]]:
    """Danh sách `dependencies:` của khối target ExamSuite (YAML đơn giản do XcodeGen dùng) và các khoá cấp
    target có thể kéo thêm phụ thuộc (`templates`). Không cần thư viện YAML."""
    lines = block.splitlines()
    deps: list[dict[str, str]] = []
    other_keys: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^    ([A-Za-z_]+):", line)
        if m and m.group(1) in ("templates", "templateAttributes"):
            other_keys.append(m.group(1))
        if line.rstrip() == "    dependencies:":
            i += 1
            while i < len(lines) and (not lines[i].strip() or len(lines[i]) - len(lines[i].lstrip()) > 4):
                item = lines[i].strip()
                if item.startswith("- "):
                    deps.append({})
                    item = item[2:]
                if ":" in item and deps:
                    key, _, value = item.partition(":")
                    deps[-1][key.strip()] = value.strip()
                i += 1
            continue
        i += 1
    return deps, other_keys


def project_yml_problems(raw: str, target: str = "ExamSuite",
                         allowed: list[dict[str, str]] = ALLOWED_EXAMSUITE_DEPENDENCIES) -> list[str]:
    """Khối target `target` (bản Học viên: ExamSuite, hay ExamSuiteiOS) của project.yml chỉ phụ thuộc đúng `allowed`
    (danh sách cho phép: không `target:`/`framework:`/`sdk:`/product khác, không `templates:`, vì phụ thuộc gián tiếp
    qua đó kiểm tĩnh không lần được), và không nhắc module của bản Admin."""
    shell = allowed[0]["product"]
    # Bỏ comment để lời giải thích trong project.yml không gây báo sai.
    text = "\n".join(line for line in raw.splitlines() if not line.lstrip().startswith("#")) + "\n"
    m = re.search(rf"^  {target}:\n(.*?)(?=^  \w|\Z)", text, re.S | re.M)
    if not m:
        return [f"project.yml: không tìm thấy target {target} (bản Học viên)"]
    block = m.group(1)
    problems = [
        f"project.yml target {target} nhắc tới {bad}: bản Học viên chỉ được phụ thuộc "
        f"{shell} (docs/decisions/0003-hai-ban-app-mot-codebase.md)."
        for bad in ("AdminShell",) + ADMIN_ONLY_MODULES if re.search(rf"\b{bad}\b", block)
    ]
    deps, other_keys = examsuite_dependencies(block)
    if deps != allowed:
        problems.append(
            f"project.yml target {target} phụ thuộc {deps}: chỉ được đúng {allowed} "
            f"(docs/decisions/0003-hai-ban-app-mot-codebase.md). Phần dùng chung đưa vào {shell}."
        )
    for key in other_keys:
        problems.append(f"project.yml target {target} dùng `{key}:`: có thể kéo phụ thuộc không kiểm được; "
                        "bỏ khoá này.")
    return problems


ALLOWED_IOS_DEPENDENCIES = [{"package": "MobileFeatures", "product": "MobileShell"}]


def mobile_graph_problems(graph: dict[str, set[str]]) -> list[str]:
    """MobileShell (bản iOS, bản Học viên) không được phụ thuộc (gián tiếp) module chỉ của bản Admin hay AdminShell."""
    if "MobileShell" not in graph:
        return ["Packages/MobileFeatures: không thấy target MobileShell."]
    deps = transitive(graph, "MobileShell")
    return [
        f"Packages/MobileFeatures: MobileShell phụ thuộc (gián tiếp) {bad}. Bản iOS là bản Học viên, không được chứa "
        "code Soạn đề hay import đề (docs/decisions/0003-hai-ban-app-mot-codebase.md)."
        for bad in ("AdminShell",) + ADMIN_ONLY_MODULES if bad in deps
    ]


def student_app_import_problems(files: list[tuple[str, str]]) -> list[str]:
    """Code của target ExamSuite (Apps/Student) không import AdminShell hay module chỉ của bản Admin."""
    return [
        f"{path} import {name}: bản Học viên không được import module Soạn đề/import đề."
        for path, text in files
        for name in imported_modules(text)
        if name in ("AdminShell",) + ADMIN_ONLY_MODULES
    ]


def check_student_shell(graph: dict[str, set[str]] | None, mobile_graph: dict[str, set[str]] | None) -> list[str]:
    problems: list[str] = []
    if graph is not None:
        problems += student_graph_problems(graph)
    if mobile_graph is not None:
        problems += mobile_graph_problems(mobile_graph)
    raw = (ROOT / "project.yml").read_text(encoding="utf-8")
    problems += project_yml_problems(raw)
    problems += project_yml_problems(raw, "ExamSuiteiOS", ALLOWED_IOS_DEPENDENCIES)
    problems += student_app_import_problems(source_files(ROOT / "Apps" / "Student"))
    problems += student_app_import_problems(source_files(ROOT / "Apps" / "StudentiOS"))
    return problems


# Mục 8: ReportFeature dùng chung hai bản app.
REPORT_MODULE = "ReportFeature"
REPORT_ALLOWED_DEPENDENCIES = {"ExamKit", "ExamFile", "LibraryData", "InterfaceCore"}
REPORT_FORBIDDEN_IMPORTS = ADMIN_ONLY_MODULES + ("AdminShell", "StudentShell", "SessionFeature")
REPORT_HINT = ("ReportFeature dùng chung cho cả hai bản app (docs/decisions/0003-hai-ban-app-mot-codebase.md, "
               "docs/product/export-print.md): chỉ được ExamKit, ExamFile, LibraryData, InterfaceCore; "
               "SessionFeature/AuthoringFeature phụ thuộc ReportFeature, không ngược lại")


def report_graph_problems(graph: dict[str, set[str]]) -> list[str]:
    """ReportFeature chỉ phụ thuộc trực tiếp REPORT_ALLOWED_DEPENDENCIES và không (gián tiếp) module chỉ của Admin."""
    if REPORT_MODULE not in graph:
        return ["Packages/ExamFeatures: không thấy target ReportFeature (đổi tên thì sửa script)."]
    problems = [
        f"Packages/ExamFeatures: ReportFeature phụ thuộc {bad} ({REPORT_HINT})."
        for bad in sorted(graph[REPORT_MODULE] - REPORT_ALLOWED_DEPENDENCIES)
    ]
    deps = transitive(graph, REPORT_MODULE)
    problems += [
        f"Packages/ExamFeatures: ReportFeature phụ thuộc (gián tiếp) {bad}: bản Học viên sẽ chứa code chỉ của Admin "
        f"({REPORT_HINT})."
        for bad in ADMIN_ONLY_MODULES if bad in deps
    ]
    return problems


def report_import_problems(files: list[tuple[str, str]]) -> list[str]:
    """Mã nguồn ReportFeature không import module Admin, shell hay SessionFeature."""
    return [
        f"{path} import {name}: {REPORT_HINT}."
        for path, text in files
        for name in imported_modules(text)
        if name in REPORT_FORBIDDEN_IMPORTS
    ]


def check_report_feature(graph: dict[str, set[str]] | None) -> list[str]:
    directory = ROOT / "Packages" / "ExamFeatures" / "Sources" / REPORT_MODULE
    if not directory.is_dir():
        return [f"Packages/ExamFeatures/Sources/{REPORT_MODULE}: không thấy thư mục module (đổi tên thì sửa script)."]
    problems = report_import_problems(source_files(directory))
    if graph is not None:
        problems += report_graph_problems(graph)
    return problems


def self_test() -> list[str]:
    """Đối chứng âm: mỗi hàm kiểm phải bắt được vi phạm cố ý. Đối chứng dương: không báo sai."""
    failures: list[str] = []

    def expect(name: str, problems: list[str], must_mention: str | None) -> None:
        if must_mention is None:
            if problems:
                failures.append(f"đối chứng dương '{name}' bị báo sai: {problems}")
        elif not any(must_mention in p for p in problems):
            failures.append(f"đối chứng âm '{name}' không bị bắt (phải báo {must_mention})")

    good_graph = {
        "StudentShell": {"LibraryData", "LibraryFeature", "SessionFeature"},
        "SessionFeature": {"LibraryData", "LibraryFeature", "ExamKit"},
        "LibraryFeature": {"LibraryData"},
        "AdminShell": {"SessionFeature", "AuthoringFeature"},
        "AuthoringFeature": {"AuthoringData", "ExamImport"},
    }
    expect("đồ thị đúng", student_graph_problems(good_graph), None)
    for bad in ADMIN_ONLY_MODULES:
        graph = {k: set(v) for k, v in good_graph.items()}
        graph["LibraryFeature"].add(bad)  # gián tiếp: StudentShell → SessionFeature → LibraryFeature → bad
        expect(f"StudentShell → … → {bad}", student_graph_problems(graph), bad)

    good_yml = (
        "targets:\n  ExamSuite:\n    type: application\n    dependencies:\n"
        "      - package: ExamFeatures\n        product: StudentShell\n"
        "  ExamSuiteAdmin:\n    dependencies:\n      - package: ExamFeatures\n        product: AdminShell\n"
    )
    expect("project.yml đúng", project_yml_problems(good_yml), None)
    for bad in ("AdminShell",) + ADMIN_ONLY_MODULES:
        bad_yml = good_yml.replace(
            "        product: StudentShell\n",
            f"        product: StudentShell\n      - package: ExamFeatures\n        product: {bad}\n",
        )
        expect(f"project.yml ExamSuite phụ thuộc {bad}", project_yml_problems(bad_yml), bad)
    # Phụ thuộc gián tiếp qua target/framework/templates khác: danh sách cho phép phải bắt.
    for extra, mention in (
        ("      - target: SharedKit\n", "SharedKit"),
        ("      - framework: Vendor.framework\n", "Vendor.framework"),
        ("      - sdk: AppKit.framework\n", "AppKit.framework"),
        ("      - package: Other\n        product: Thing\n", "Thing"),
    ):
        bad_yml = good_yml.replace("        product: StudentShell\n", "        product: StudentShell\n" + extra)
        expect(f"project.yml ExamSuite thêm {mention}", project_yml_problems(bad_yml), mention)
    expect("project.yml ExamSuite dùng templates",
           project_yml_problems(good_yml.replace("    type: application\n", "    type: application\n    templates: [Shared]\n")),
           "templates")
    expect("project.yml ExamSuite thiếu StudentShell",
           project_yml_problems(good_yml.replace("product: StudentShell", "product: LibraryFeature")), "StudentShell")

    # Bản iOS (bản Học viên): target ExamSuiteiOS chỉ MobileShell; MobileShell không kéo module Admin.
    ios_yml = good_yml + (
        "  ExamSuiteiOS:\n    dependencies:\n      - package: MobileFeatures\n        product: MobileShell\n")
    expect("project.yml ExamSuiteiOS đúng",
           project_yml_problems(ios_yml, "ExamSuiteiOS", ALLOWED_IOS_DEPENDENCIES), None)
    expect("project.yml thiếu ExamSuiteiOS", project_yml_problems(good_yml, "ExamSuiteiOS", ALLOWED_IOS_DEPENDENCIES),
           "ExamSuiteiOS")
    for bad in ("AdminShell",) + ADMIN_ONLY_MODULES:
        extra = f"      - package: ExamFeatures\n        product: {bad}\n"
        bad_yml = ios_yml.replace("        product: MobileShell\n", "        product: MobileShell\n" + extra)
        expect(f"project.yml ExamSuiteiOS phụ thuộc {bad}",
               project_yml_problems(bad_yml, "ExamSuiteiOS", ALLOWED_IOS_DEPENDENCIES), bad)
    good_mobile = {"MobileShell": {"MobileFeature"}, "MobileFeature": {"LibraryData"}}
    expect("đồ thị MobileFeatures đúng", mobile_graph_problems(good_mobile), None)
    expect("thiếu target MobileShell", mobile_graph_problems({"MobileFeature": set()}), "MobileShell")
    for bad in ("AdminShell",) + ADMIN_ONLY_MODULES:
        graph = {k: set(v) for k, v in good_mobile.items()}
        graph["MobileFeature"].add(bad)  # gián tiếp: MobileShell → MobileFeature → bad
        expect(f"MobileShell → … → {bad}", mobile_graph_problems(graph), bad)

    expect("Apps/Student import đúng",
           student_app_import_problems([("Apps/Student/App.swift", "import SwiftUI\nimport StudentShell\n")]), None)
    # Mọi dạng câu lệnh import của Swift 6 (đối chứng âm cho regex).
    import_forms = (
        "import {m}\n", "@testable import {m}\n", "@preconcurrency import {m}\n", "@_exported import {m}\n",
        "@_implementationOnly import {m}\n", "@_spi(Internal) @preconcurrency import {m}\n",
        "public import {m}\n", "package import {m}\n", "internal import {m}\n", "private import {m}\n",
        "@preconcurrency public import {m}\n", "  import struct {m}.Thing\n", "import Foundation; import {m}\n",
        "import Foundation;import {m}.Sub\n",
    )
    for form in import_forms:
        for bad in ("AdminShell",) + ADMIN_ONLY_MODULES:
            text = "import StudentShell\n" + form.format(m=bad)
            expect(f"Apps/Student: {form.strip().format(m=bad)}",
                   student_app_import_problems([("Apps/Student/App.swift", text)]), bad)
    expect("Apps/Student: import trong comment không tính",
           student_app_import_problems([("Apps/Student/App.swift", "// import AdminShell\nlet s = \"import AdminShell\"\n")]), None)

    for module, allowed in ALLOWED_IN_ADMIN_DATA.items():
        ok = "import ExamFile\nimport ExamKit\nimport Foundation\n"
        expect(f"{module} import đúng", import_problems(module, allowed, [("x.swift", ok)], ""), None)
        for bad in ("SwiftUI", "AppKit", "SwiftData", "LibraryData"):
            for form in import_forms:
                line = form.format(m=bad)
                expect(f"{module}: {line.strip()}", import_problems(module, allowed, [("x.swift", ok + line)], ""), bad)
    # ExamImport: được ZIPFoundation, không được SwiftUI/AppKit; AuthoringData không được ZIPFoundation.
    exam_import = ALLOWED_IN_ADMIN_DATA["ExamImport"]
    path = "Packages/ExamFeatures/Sources/ExamImport/X.swift"
    expect("ExamImport import ZIPFoundation",
           import_problems("ExamImport", exam_import, [(path, "import Foundation\nimport ZIPFoundation\n")], ""), None)
    for bad in ("SwiftUI", "AppKit"):
        expect(f"ExamImport import {bad}",
               import_problems("ExamImport", exam_import, [(path, f"import Foundation\nimport {bad}\n")], ""), bad)
    expect("AuthoringData import ZIPFoundation",
           import_problems("AuthoringData", ALLOWED_IN_ADMIN_DATA["AuthoringData"],
                           [("x.swift", "import ZIPFoundation\n")], ""), "ZIPFoundation")
    for module, allowed in ALLOWED_IN_CORE.items():
        for form in import_forms:
            line = form.format(m="AppKit")
            expect(f"{module}: {line.strip()}", import_problems(module, allowed, [("x.swift", "import Foundation\n" + line)], ""), "AppKit")
    failures += zipfoundation_self_test(import_forms)
    failures += snapshot_self_test(import_forms)
    failures += test_only_self_test(import_forms)

    # Mục 8: ReportFeature.
    good_report = {k: set(v) for k, v in good_graph.items()}
    good_report["ReportFeature"] = {"ExamKit", "ExamFile", "LibraryData", "InterfaceCore"}
    good_report["SessionFeature"].add("ReportFeature")
    good_report["LibraryData"] = {"ExamKit", "ExamFile"}
    good_report["InterfaceCore"] = {"LibraryData", "ExamKit", "ExamFile"}
    expect("ReportFeature đồ thị đúng", report_graph_problems(good_report), None)
    expect("ReportFeature đồ thị không phụ thuộc gì", report_graph_problems({**good_report, "ReportFeature": set()}), None)
    expect("thiếu target ReportFeature", report_graph_problems(good_graph), "ReportFeature")
    # LibraryFeature (giao diện macOS) không còn được: tra chữ qua InterfaceCore (bước I1 của plan iOS).
    for bad in ("SessionFeature", "StudentShell", "AdminShell", "LibraryFeature") + ADMIN_ONLY_MODULES:
        graph = {k: set(v) for k, v in good_report.items()}
        graph["ReportFeature"].add(bad)
        expect(f"ReportFeature → {bad}", report_graph_problems(graph), bad)
    for via in ("LibraryData", "InterfaceCore"):
        for bad in ADMIN_ONLY_MODULES:
            graph = {k: set(v) for k, v in good_report.items()}
            graph[via].add(bad)  # gián tiếp: ReportFeature → via → bad
            expect(f"ReportFeature → {via} → {bad}", report_graph_problems(graph), bad)
    report_ok = "import AppKit\nimport PDFKit\nimport SwiftUI\nimport ExamKit\nimport InterfaceCore\n"
    expect("ReportFeature import đúng",
           report_import_problems([("Packages/ExamFeatures/Sources/ReportFeature/X.swift", report_ok)]), None)
    for form in import_forms:
        for bad in REPORT_FORBIDDEN_IMPORTS:
            text = report_ok + form.format(m=bad)
            expect(f"ReportFeature: {form.strip().format(m=bad)}",
                   report_import_problems([("Packages/ExamFeatures/Sources/ReportFeature/X.swift", text)]), bad)
    return failures


def main(argv: list[str]) -> int:
    use_swift = "--no-swift" not in argv
    if use_swift and shutil.which("swift") is None:
        print("check_boundaries.py: không có `swift` trên PATH; chạy với --no-swift hoặc cài toolchain.")
        return 2
    failures = self_test()
    if failures:
        print("FAIL check_boundaries.py tự kiểm (hàm kiểm không còn bắt được vi phạm):")
        for f in failures:
            print(f"  - {f}")
        return 1
    shared = ROOT / "Packages" / "SharedFeatures"
    graph = package_graph(ROOT / "Packages" / "ExamFeatures", shared) if use_swift else None
    mobile_graph = package_graph(ROOT / "Packages" / "MobileFeatures", shared) if use_swift else None
    problems = (check_module_imports() + check_zipfoundation_imports() + check_student_shell(graph, mobile_graph)
                + check_external_packages(use_swift) + check_test_only_module(use_swift)
                + check_report_feature(graph))
    if problems:
        print("FAIL ranh giới kiến trúc:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print("ok   ExamKit/ExamFile chỉ dùng Foundation(+ZIPFoundation); ZIPFoundation chỉ ở ExamFile/ExamImport; "
          "SnapshotTesting chỉ ở test của ExamFeatures; gói ngoài chỉ ZIPFoundation, swift-snapshot-testing; "
          "AuthoringData, ExamImport không giao diện; "
          f"StudentShell, MobileShell không chứa {', '.join(ADMIN_ONLY_MODULES)}; {TEST_ONLY_MODULE} chỉ ở test; "
          f"ReportFeature chỉ phụ thuộc {', '.join(sorted(REPORT_ALLOWED_DEPENDENCIES))} (đối chứng âm bị bắt)"
          + f"; project.yml kiểm theo {project_yml_mode()}"
          + ("" if use_swift else " (bỏ qua phần swift package describe)"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
