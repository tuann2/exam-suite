#!/usr/bin/env python3
"""Chọn lớp XCUITest cần chạy theo file đổi (docs/notes/g5-ui-test-trung-lap.md, T1; review-and-merge.md mục 2).

`scripts/verify_local.sh --uitest` gọi script này với danh sách file đổi so với `git merge-base origin/main HEAD`, rồi
chỉ build và chạy các lớp được chọn (`-only-testing:<target>/<lớp>`); target không có lớp nào thì không build, không
chạy. **Đủ bộ** khi:
- chạm hạ tầng chung (UITestSupport, target UI test, project.yml, Package.swift/resolved, code chế độ cô lập, chính
  script này hay verify_local.sh);
- chạm module dùng chung mọi cửa sổ (dòng `full=True` của bảng: LibraryFeature, LibraryData kể cả đề mẫu,
  SessionFeature, lõi ExamKit/ExamFile);
- `--all` (verify_local.sh `--clean`, `--uitest-all`);
- file code app không khớp dòng nào (target mới…), kèm cảnh báo;
- bảng map chưa khớp lớp thật (xem dưới), kèm cảnh báo.

Tự kiểm bảng map: mọi lớp `XCTestCase` trong `Apps/*UITests/**` (tìm bằng `class X: XCTestCase`) phải là **lớp chính**
của ít nhất một dòng module (không tính dòng shell, vốn chọn mọi lớp của bản đó), và mọi tên lớp trong bảng phải còn
tồn tại. Sai thì kế hoạch là đủ bộ kèm cảnh báo (verify_local.sh không bị chặn), còn `--self-test` (trong check.sh)
**thất bại**, để lớp mới phải được xếp vào module trước khi merge.

  python3 scripts/uitest_plan.py --files <đường dẫn>…   # kế hoạch cho danh sách file
  python3 scripts/uitest_plan.py --git                  # file đổi so với merge-base của origin/main và HEAD
  python3 scripts/uitest_plan.py --all --reason "…"     # đủ bộ
  python3 scripts/uitest_plan.py --self-test            # tự kiểm bảng map và logic chọn (có đối chứng âm; check.sh)

Kết quả (verify_local.sh đọc):
  mode: selected | full | none
  reason: <lý do>
  ExamSuiteUITests: <lớp…>
  ExamSuiteAdminUITests: <lớp…>
  ExamSuiteiOSUITests: <lớp…>      (bản iOS trên simulator, docs/product/plan-ios-v1.md)
  warning: <cảnh báo>            (0 hoặc nhiều dòng)

Chỉ đọc tên file và mã nguồn UI test, không chạy gì.
"""
from __future__ import annotations

import fnmatch
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

STUDENT = "ExamSuiteUITests"
ADMIN = "ExamSuiteAdminUITests"
IOS = "ExamSuiteiOSUITests"
TARGETS = (STUDENT, ADMIN, IOS)
TARGET_DIRS = {STUDENT: "Apps/StudentUITests", ADMIN: "Apps/AdminUITests", IOS: "Apps/StudentiOSUITests"}
CLASS_PATTERN = re.compile(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b")


@dataclass(frozen=True)
class Row:
    """Một dòng của bảng: file khớp `patterns` thì chọn `classes` (lớp chính của module; dòng `full` chọn đủ bộ, lớp
    chính chỉ dùng cho tự kiểm). Dòng `shell` chọn mọi lớp của bản đó và không tính vào tự kiểm."""
    name: str
    patterns: list[str]
    classes: dict[str, list[str]] = field(default_factory=dict)
    full: bool = False
    shell: str | None = None


F = "Packages/ExamFeatures/Sources/"
M = "Packages/MobileFeatures/"
# ---- BẢNG MAP (sửa ở đây khi thêm lớp UI test hay target) -----------------------------------------------------------
# Mẫu fnmatch trên đường dẫn từ gốc repo ("*" khớp cả "/"). Kiểm theo code thật 2026-10-18 (bước 9 giai đoạn 5, sửa
# theo review độc lập #55; bước 10 gộp lớp chung đoạn mở đầu: xuất PDF kết quả nằm trong PracticeFlowUITests, đóng cửa sổ
# và ⌘Q khi hộp Vẫn nộp? trong ExamFlowUITests, mở app cô lập trong LibraryWindowRestoreUITests/EditExamFlowUITests,
# xuất PDF đề trong NewExamFlowUITests).

# Hạ tầng chung và code chế độ cô lập của UI test: đủ bộ cả hai target.
FULL_PATTERNS = [
    "Apps/UITestSupport/*", "Apps/StudentUITests/*", "Apps/AdminUITests/*",
    "project.yml",
    "Packages/ExamFeatures/Package.swift", "Packages/ExamFeatures/Package.resolved",
    "Packages/ExamKit/Package.swift", "Packages/ExamKit/Package.resolved",
    # Chế độ cô lập: thư mục tạm, kho, defaults (AppLaunchStorage), đồng hồ nhanh (SessionServices), file thay hộp chọn
    # file của bản Admin (AuthoringWindow). Hai file đầu đã nằm trong module đủ bộ; ghi lại để rõ.
    F + "LibraryData/AppLaunchStorage.swift", F + "SessionFeature/Services/SessionServices.swift",
    F + "AuthoringFeature/Views/AuthoringWindow.swift",
    "scripts/verify_local.sh", "scripts/uitest_plan.py",
]

ROWS: list[Row] = [
    # Cửa sổ làm bài; `SessionAppController` còn gắn trang trí Thư viện, menu (cả Xuất PDF…/In… ⌘P của cửa sổ soạn đề qua
    # `ReportCommandTarget`) vào mọi cửa sổ của hai bản: đủ bộ.
    Row("SessionFeature", [F + "SessionFeature/*"], full=True, classes={
        STUDENT: ["PracticeFlowUITests", "ExamFlowUITests", "SessionWindowRestoreUITests", "EnglishInterfaceUITests"],
        ADMIN: ["NewExamFlowUITests"]}),
    # Thư viện của hai bản; LibraryFeature còn giữ PresentationTermination (⌘Q khi có sheet), InterfaceStrings,
    # InterfaceLocale, ErrorMessages, LibraryPalette mà mọi cửa sổ dùng; LibraryData giữ kho, lần thi (Thử đề này) và
    # đề mẫu mà mọi UI test dùng: đủ bộ.
    Row("LibraryFeature, LibraryData", [F + "LibraryFeature/*", F + "LibraryData/*"], full=True, classes={
        STUDENT: ["LibraryWindowRestoreUITests", "PracticeFlowUITests"],
        ADMIN: ["EditExamFlowUITests"]}),
    # Lõi đọc nghiêm, kiểm, chấm, ghi đề và đồng hồ phiên: luồng UI lưu/mở lại đề, đọc nghiêm, hẹn giờ: đủ bộ.
    # LargeExamSupport chỉ ở test: không có ở đây.
    Row("ExamKit, ExamFile", ["Packages/ExamKit/Sources/ExamKit/*", "Packages/ExamKit/Sources/ExamFile/*"], full=True,
        classes={STUDENT: ["PracticeFlowUITests", "ExamFlowUITests"],
                 ADMIN: ["NewExamFlowUITests", "EditExamFlowUITests", "ImportExamUITests"]}),
    # PDF và In dùng chung hai bản (đoạn xuất PDF ở đuôi luồng 1 và trong luồng 4).
    Row("ReportFeature", [F + "ReportFeature/*"],
        classes={STUDENT: ["PracticeFlowUITests"], ADMIN: ["NewExamFlowUITests"]}),
    # Phần chỉ của Admin: cửa sổ soạn đề, lệnh Đề mới/Import đề… (cả khi mở app).
    Row("AuthoringFeature, AuthoringData, ExamImport", [F + "AuthoringFeature/*", F + "AuthoringData/*", F + "ExamImport/*"],
        classes={ADMIN: ["EditExamFlowUITests", "ImportExamUITests", "NewExamFlowUITests"]}),
    # Chữ giao diện của catalog (catalog của module đủ bộ đã chọn đủ bộ ở dòng của nó): giao diện tiếng Anh; luồng 1 có
    # đoạn xuất PDF kết quả với Region en_US (ngày giờ theo ngôn ngữ giao diện).
    Row("String Catalog", ["Packages/ExamFeatures/*.xcstrings", "Apps/Student/*.xcstrings", "Apps/Admin/*.xcstrings"],
        classes={STUDENT: ["EnglishInterfaceUITests", "PracticeFlowUITests"]}),
    # Bản iOS (docs/product/plan-ios-v1.md): màn hình iPhone. Bước I0 chỉ có test mở app; ba luồng thay ở bước I2.
    Row("MobileFeature", [M + "Sources/MobileFeature/*"], classes={IOS: ["LaunchUITests"]}),
    # Shell và điểm vào của từng bản: mọi lớp của bản đó.
    Row("StudentShell, Apps/Student", [F + "StudentShell/*", "Apps/Student/*"], shell=STUDENT),
    Row("AdminShell, Apps/Admin", [F + "AdminShell/*", "Apps/Admin/*"], shell=ADMIN),
    # Shell, manifest, điểm vào, target UI test của bản iOS: mọi lớp iOS (không chạy hai bản macOS).
    Row("MobileShell, Apps/StudentiOS", [M + "Sources/MobileShell/*", M + "Package.swift", M + "Package.resolved",
                                         "Apps/StudentiOS/*", "Apps/StudentiOSUITests/*"], shell=IOS),
]

# Đường dẫn code app mà không dòng nào ở trên khớp (target mới…): đủ bộ kèm cảnh báo, để map được bổ sung.
CODE_PATTERNS = [F + "*", "Packages/ExamKit/Sources/*", M + "*", "Apps/*"]
# Code chỉ của test: không chạy UI test.
NO_UI_PATTERNS = ["Packages/ExamKit/Sources/LargeExamSupport/*"]
# ---- HẾT BẢNG MAP ----------------------------------------------------------------------------------------------------


def discover_classes(root: Path) -> dict[str, set[str]]:
    """Lớp `XCTestCase` theo target, tìm trong mọi file Swift của thư mục target (kể cả nhiều lớp mỗi file)."""
    found: dict[str, set[str]] = {}
    for target, directory in TARGET_DIRS.items():
        names: set[str] = set()
        for path in (root / directory).rglob("*.swift"):
            names.update(CLASS_PATTERN.findall(path.read_text(encoding="utf-8")))
        found[target] = names
    return found


def owners(rows: list[Row]) -> dict[str, set[str]]:
    """Lớp chính của các dòng module (không tính dòng shell)."""
    names: dict[str, set[str]] = {t: set() for t in TARGETS}
    for row in rows:
        if row.shell is None:
            for target, classes in row.classes.items():
                names[target].update(classes)
    return names


def map_warnings(discovered: dict[str, set[str]], rows: list[Row]) -> list[str]:
    mapped = owners(rows)
    warnings = []
    for target in TARGETS:
        for name in sorted(discovered[target] - mapped[target]):
            warnings.append(f"lớp {target}/{name} chưa là lớp chính của dòng module nào trong scripts/uitest_plan.py: "
                            "chạy đủ bộ")
        for name in sorted(mapped[target] - discovered[target]):
            warnings.append(f"bảng map có {target}/{name} nhưng không còn lớp đó: chạy đủ bộ")
    return warnings


def matches(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def plan(files: list[str], discovered: dict[str, set[str]], *, run_all: bool = False, reason: str = "",
         rows: list[Row] = ROWS) -> dict:
    """{mode, reason, classes: {target: [lớp…]}, warnings: […]}"""
    warnings = map_warnings(discovered, rows)
    full = {t: sorted(discovered[t]) for t in TARGETS}

    def full_plan(why: str) -> dict:
        return {"mode": "full", "reason": why, "classes": full, "warnings": warnings}

    def listed(paths: list[str]) -> str:
        return ", ".join(paths[:3]) + ("…" if len(paths) > 3 else "")

    if run_all:
        return full_plan(reason or "yêu cầu đủ bộ")
    if warnings:
        return full_plan("bảng map chưa khớp lớp UI test")
    infra = [f for f in files if matches(f, FULL_PATTERNS)]
    if infra:
        return full_plan(f"chạm hạ tầng chung: {listed(infra)}")
    shared = sorted({row.name for f in files for row in rows if row.full and matches(f, row.patterns)})
    if shared:
        return full_plan(f"chạm module dùng chung: {', '.join(shared)}")
    selected: dict[str, set[str]] = {t: set() for t in TARGETS}
    unmapped = []
    for f in files:
        if matches(f, NO_UI_PATTERNS):
            continue
        hit = [row for row in rows if matches(f, row.patterns)]
        for row in hit:
            if row.shell:
                selected[row.shell].update(discovered[row.shell])
            for target, classes in row.classes.items():
                selected[target].update(classes)
        if not hit and matches(f, CODE_PATTERNS):
            unmapped.append(f)
    if unmapped:
        warnings.append(f"code app không có trong bảng map: {listed(unmapped)}")
        return full_plan("file code app chưa map")
    classes = {t: sorted(selected[t]) for t in TARGETS}
    if not any(classes.values()):
        return {"mode": "none", "reason": "không file nào đổi chạm giao diện", "classes": classes, "warnings": warnings}
    return {"mode": "selected", "reason": "theo file đổi", "classes": classes, "warnings": warnings}


def render(result: dict) -> str:
    lines = [f"mode: {result['mode']}", f"reason: {result['reason']}"]
    lines += [f"{t}: {' '.join(result['classes'][t])}".rstrip() for t in TARGETS]
    lines += [f"warning: {w}" for w in result["warnings"]]
    return "\n".join(lines)


def changed_files() -> tuple[list[str] | None, str]:
    """File đổi so với merge-base(origin/main, HEAD); None khi không tính được (khi đó chạy đủ bộ). Không dò đổi tên:
    file đổi tên tính cả đường dẫn cũ và mới."""
    try:
        base = subprocess.run(["git", "merge-base", "origin/main", "HEAD"], capture_output=True, text=True,
                              check=True).stdout.strip()
        out = subprocess.run(["git", "diff", "--name-only", "--no-renames", f"{base}..HEAD"], capture_output=True,
                             text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        return None, f"không tính được file đổi so với origin/main ({error})"
    return [line for line in out.splitlines() if line], base[:7]


EXPECTED = {
    STUDENT: {"EnglishInterfaceUITests", "ExamFlowUITests", "LibraryWindowRestoreUITests", "PracticeFlowUITests",
              "SessionWindowRestoreUITests"},
    ADMIN: {"EditExamFlowUITests", "ImportExamUITests", "NewExamFlowUITests"},
    IOS: {"LaunchUITests"},
}


def self_test(root: Path) -> None:
    # Tìm lớp: đúng các lớp thật của repo (đổi lớp UI test thì sửa EXPECTED cùng bảng map), kể cả nhiều lớp mỗi file.
    real = discover_classes(root)
    assert real == EXPECTED, f"lớp UI test thật khác EXPECTED: {real}"
    assert CLASS_PATTERN.findall("final class A: XCTestCase {}\nclass B : XCTestCase {}\nclass C: NSObject {}") == ["A", "B"]
    # Bảng map thật khớp (check.sh thất bại ở đây nếu có lớp chưa xếp vào module nào).
    assert not map_warnings(real, ROWS), map_warnings(real, ROWS)
    classes = {t: set(c) for t, c in EXPECTED.items()}
    full_student, full_admin, full_ios = sorted(classes[STUDENT]), sorted(classes[ADMIN]), sorted(classes[IOS])

    def is_full(result: dict) -> bool:
        return result["mode"] == "full" and result["classes"] == {
            STUDENT: full_student, ADMIN: full_admin, IOS: full_ios}

    # Đối chứng âm của tự kiểm: lớp mới chỉ có ở dòng shell (không là lớp chính của module nào) → đủ bộ + cảnh báo.
    extra = {**classes, STUDENT: classes[STUDENT] | {"NewThingUITests"}}
    result = plan(["Packages/ExamFeatures/Sources/StudentShell/StudentShell.swift"], extra)
    assert result["mode"] == "full" and "NewThingUITests" in result["classes"][STUDENT] and any(
        "NewThingUITests" in w for w in result["warnings"]), result
    # Bỏ một lớp khỏi mọi dòng module (chỉ còn ở dòng shell) → cảnh báo.
    trimmed = [Row(r.name, r.patterns,
                   {t: [c for c in cs if c != "LibraryWindowRestoreUITests"] for t, cs in r.classes.items()},
                   r.full, r.shell) for r in ROWS]
    gap = plan(["docs/a.md"], classes, rows=trimmed)
    assert gap["mode"] == "full" and any("LibraryWindowRestoreUITests" in w for w in gap["warnings"]), gap
    # Tên thừa trong bảng (lớp đã xoá) → cảnh báo.
    stale = {**classes, STUDENT: classes[STUDENT] - {"SessionWindowRestoreUITests"}}
    assert any("SessionWindowRestoreUITests" in w for w in plan(["docs/a.md"], stale)["warnings"])
    # Lớp đã gộp ở bước 10 (giai đoạn 5) không còn trong bảng: tên cũ trong bảng là tên thừa.
    for merged in ["ExportResultsUITests", "CloseWindowUITests", "QuitWhileConfirmingUITests", "LaunchIsolationUITests",
                   "ExportExamUITests", "AdminLaunchUITests"]:
        assert all(merged not in cs for r in ROWS for cs in r.classes.values()), merged

    # Module dùng chung → đủ bộ (review #55 B1, S2).
    for shared in [F + "LibraryFeature/Views/HistoryView.swift", F + "LibraryFeature/Localization/InterfaceStrings.swift",
                   F + "LibraryData/Resources/Samples/lam-quen-exam-suite/exam.json", F + "LibraryData/LibraryStore.swift",
                   F + "SessionFeature/Views/SessionWindowView.swift", "Packages/ExamKit/Sources/ExamKit/Scorer.swift",
                   "Packages/ExamKit/Sources/ExamFile/ExamPackageReader.swift"]:
        assert is_full(plan([shared], classes)), shared
    # Hạ tầng và chế độ cô lập → đủ bộ (đối chứng âm: kèm một file chỉ chọn vài lớp).
    for infra in ["Apps/UITestSupport/IsolatedApp.swift", "scripts/verify_local.sh", "Packages/ExamFeatures/Package.swift",
                  "Apps/StudentUITests/Support/StudentFlow.swift", F + "AuthoringFeature/Views/AuthoringWindow.swift"]:
        assert is_full(plan([F + "ReportFeature/ReportRenderer.swift", infra], classes)), infra
    # Chỉ ReportFeature: hai lớp có đoạn xuất PDF (luồng 1 + PDF kết quả, luồng 4 + PDF đề).
    report = plan([F + "ReportFeature/ReportFlow.swift"], classes)
    assert report["mode"] == "selected" and report["classes"] == {
        STUDENT: ["PracticeFlowUITests"], ADMIN: ["NewExamFlowUITests"], IOS: []}, report
    # Chỉ AuthoringFeature: không build, không chạy bản Học viên.
    authoring = plan([F + "AuthoringFeature/Model/AuthoringEditor.swift"], classes)
    assert authoring["classes"] == {STUDENT: [], ADMIN: full_admin, IOS: []}, authoring
    # Shell của bản Học viên: mọi lớp Học viên, không lớp Admin.
    shell = plan([F + "StudentShell/StudentShell.swift"], classes)
    assert shell["classes"] == {STUDENT: full_student, ADMIN: [], IOS: []}, shell
    # Catalog của AuthoringFeature: lớp Admin + tiếng Anh, xuất PDF kết quả.
    strings = plan([F + "AuthoringFeature/Resources/Localizable.xcstrings"], classes)
    assert strings["classes"] == {STUDENT: ["EnglishInterfaceUITests", "PracticeFlowUITests"], ADMIN: full_admin,
                                  IOS: []}, strings
    # Bản iOS: màn hình iPhone chỉ chọn lớp iOS; shell, manifest, điểm vào, catalog của app iOS, target UI test iOS
    # chọn mọi lớp iOS; không chạy hai bản macOS (đối chứng âm: kèm file của bản Học viên macOS thì có lớp Học viên).
    mobile = plan([M + "Sources/MobileFeature/RootView.swift"], classes)
    assert mobile["mode"] == "selected", mobile
    assert mobile["classes"] == {STUDENT: [], ADMIN: [], IOS: ["LaunchUITests"]}, mobile
    for ios_file in [M + "Sources/MobileShell/MobileShell.swift", M + "Package.swift",
                     "Apps/StudentiOS/InfoPlist.xcstrings", "Apps/StudentiOSUITests/LaunchUITests.swift"]:
        ios_only = plan([ios_file], classes)
        assert ios_only["classes"] == {STUDENT: [], ADMIN: [], IOS: full_ios}, (ios_file, ios_only)
    both = plan([M + "Sources/MobileFeature/RootView.swift", "Apps/Student/StudentApp.swift"], classes)
    assert both["classes"] == {STUDENT: full_student, ADMIN: [], IOS: ["LaunchUITests"]}, both
    # Module dùng chung và hạ tầng chung: đủ bộ gồm cả bản iOS.
    assert is_full(plan(["project.yml"], classes)) and full_ios
    # Tài liệu, unit test, script khác, LargeExamSupport: không lớp nào.
    none = plan(["docs/plans/active/x.md", "Packages/ExamFeatures/Tests/SessionFeatureTests/A.swift", "scripts/check.sh",
                 "Packages/ExamKit/Sources/LargeExamSupport/Timing.swift"], classes)
    assert none["mode"] == "none", none
    # Target code mới chưa map → đủ bộ kèm cảnh báo.
    unknown = plan([F + "NewFeature/A.swift"], classes)
    assert is_full(unknown) and unknown["warnings"], unknown
    # --all (--clean, --uitest-all).
    assert is_full(plan([], classes, run_all=True, reason="--clean"))
    # Định dạng verify_local.sh đọc.
    text = render(report)
    assert text.splitlines()[0] == "mode: selected" and f"{ADMIN}: NewExamFlowUITests" in text, text


def main(argv: list[str]) -> int:
    root = Path(__file__).resolve().parent.parent
    if argv[:1] == ["--self-test"]:
        try:
            self_test(root)
        except AssertionError as error:
            print(f"FAIL uitest_plan.py: {error}", file=sys.stderr)
            return 1
        print("ok   uitest_plan.py: mọi lớp Apps/*UITests là lớp chính của một dòng module (lớp chưa xếp, tên thừa → đủ bộ "
              "+ cảnh báo), module dùng chung và hạ tầng → đủ bộ, chọn theo file đổi (đối chứng âm bị bắt)")
        return 0
    discovered = discover_classes(root)
    if argv[:1] == ["--all"]:
        reason = argv[2] if argv[1:2] == ["--reason"] and len(argv) > 2 else ""
        print(render(plan([], discovered, run_all=True, reason=reason)))
        return 0
    if argv[:1] == ["--files"]:
        print(render(plan(argv[1:], discovered)))
        return 0
    if argv[:1] == ["--git"]:
        files, base = changed_files()
        if files is None:
            print(render(plan([], discovered, run_all=True, reason=base)))
        else:
            result = plan(files, discovered)
            result["reason"] += f" ({len(files)} file đổi so với {base})"
            print(render(result))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
