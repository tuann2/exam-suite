#!/usr/bin/env python3
"""Kiểm mọi sheet của hai app không chặn app thoát, và mục Thoát/Apple event thoát là của AppKit (giai đoạn 5, sửa
sau PR #42).

Thẩm quyền: docs/product/exam-taking.md (Đóng cửa sổ hoặc thoát app khi chưa nộp: thoát app, kể cả Thoát từ Dock và
đăng xuất, đi qua lời hỏi Bỏ bài), docs/product/authoring.md (Lưu, hoàn tác, khôi phục: thoát app theo tự lưu của
macOS), docs/plans/completed/giai-doan-5-hoan-thien.md (Decisions 2026-10-17, thoát app khi đang mở sheet), review độc lập
PR #42 (mục 1b: quét mọi sheet so với danh sách đã biết).

Vì sao: sheet SwiftUI mặc định chặn app thoát (SDK: `View.presentationPreventsAppTermination(_:)`; AppKit:
`NSWindow.preventsApplicationTerminationWhenModal` mặc định YES). Khi một cửa sổ còn sheet như vậy, ⌘Q không gọi
`applicationShouldTerminate` (UI test PR #42: app kẹt), còn Apple event thoát (Thoát từ Dock, đăng xuất, khởi động lại,
tắt máy) bị trả `userCanceledErr` nên đăng xuất bị huỷ. Mỗi sheet của Exam Suite vì vậy gắn
`.presentationAllowsAppTermination()` (LibraryFeature) trong nội dung của nó, để mọi đường thoát đi qua quy trình chuẩn
của AppKit (hỏi lưu đề, tự lưu, Versions, hỏi Bỏ bài).

Quét mã nguồn (Packages/ExamFeatures/Sources, Apps; bỏ comment và nội dung chuỗi):
1. Lời gọi trình bày dạng sheet/popover của SwiftUI (`.sheet(`, `.fullScreenCover(`, `.popover(`, kể cả gọi không có
   dấu chấm trong extension của View) phải (a) có trong danh sách `KNOWN_PRESENTATIONS` (đường dẫn, tên lời gọi, đối số
   đầu đã gộp khoảng trắng) kèm cách nó đóng khi app thoát, và (b) gắn `.presentationAllowsAppTermination()` **ở cấp
   ngoài cùng** của closure nội dung (closure theo sau lời gọi, hoặc đối số `content: { … }`): ngoặc nhọn sâu 1, ngoài
   ngoặc tròn/vuông. Modifier chỉ nằm trong một nhánh `if`, trong closure lồng, hay trong nội dung của một sheet lồng
   bên trong không tính. Giới hạn còn lại: closure có nhiều view ở cấp ngoài cùng mà chỉ một view gắn modifier thì vẫn
   qua; nội dung truyền bằng tên hàm (`content: makeSheet`) thì báo thiếu (gắn modifier trong closure).
2. Sheet của AppKit (`beginSheet(`, `beginCriticalSheet(`, `presentAsSheet(`) phải có trong danh sách (hiện không có;
   thêm thì đặt `preventsApplicationTerminationWhenModal = false` cho cửa sổ sheet nếu nó không được chặn thoát).
   `NSAlert`/`NSSavePanel` `.beginSheetModal(for:)` là panel của AppKit, không quét.
3. Mục trong danh sách không còn trong mã cũng là lỗi (danh sách phải khớp mã).
4. Mục Thoát và Apple event thoát là của AppKit (không thay): cấm `CommandGroup(replacing: .appTermination)` (thay mục
   Thoát làm mất ⌥⌘Q, và `terminate` gọi từ `Task` của main actor làm main queue đứng khi hỏi Bỏ bài) và mọi dùng
   `kAEQuitApplication` (cài handler Apple event thoát riêng làm mất phần trả lời loginwindow của AppKit). Lý do ở plan
   giai đoạn 5, Decisions 2026-10-17.

Không quét `.alert`, `.confirmationDialog` (SwiftUI: hộp có hơn một nút, nút huỷ hoại hay ô nhập vẫn chặn thoát theo mặc
định, như mọi app macOS khi đang hỏi: ⌘Q không làm gì, đăng xuất bị huỷ), `.fileImporter`/`.fileExporter` (hộp Mở/Lưu
của AppKit) và `.inspector` (không phải hộp thoại).

Mỗi lần chạy, hàm kiểm được thử trước trên đầu vào cố ý sai (đối chứng âm) và đầu vào đúng (đối chứng dương); hàm kiểm
không bắt được đối chứng âm thì script thất bại, để phép kiểm không âm thầm hỏng.

Dùng: scripts/check_quit_sheets.py   (chạy được trên Linux; trong scripts/check.sh bước 3)
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_localization import call_arguments, lex, split_label  # noqa: E402  (tách comment/chuỗi Swift, dùng chung)

ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = (Path("Packages/ExamFeatures/Sources"), Path("Apps"))
MODIFIER = "presentationAllowsAppTermination"
SWIFTUI_CALLS = ("sheet", "fullScreenCover", "popover")
APPKIT_CALLS = ("beginSheet", "beginCriticalSheet", "presentAsSheet")
CALL_RE = re.compile(r"(?<![\w$])(" + "|".join(SWIFTUI_CALLS + APPKIT_CALLS) + r")\s*\(")
DECLARATION_RE = re.compile(r"\b(?:func|case)\s*$")
MODIFIER_RE = re.compile(r"\." + MODIFIER + r"\s*\(\s*\)")
# Mục 4: thay mục Thoát của AppKit, hay cài handler Apple event thoát riêng.
QUIT_OVERRIDES = (
    (re.compile(r"\breplacing\s*:\s*(?:(?:SwiftUI\.)?CommandGroupPlacement)?\s*\.\s*appTermination\b"),
     "CommandGroup(replacing: .appTermination) thay mục Thoát của AppKit"),
    (re.compile(r"(?<![\w$])kAEQuitApplication\b"),
     "kAEQuitApplication: handler Apple event thoát riêng"),
)


@dataclass(frozen=True)
class Known:
    path: str
    call: str
    first_argument: str  # đối số đầu; so sau khi gộp khoảng trắng
    closes_by: str  # khi app thoát, sheet đóng thế nào (tiếng Việt)


# Mọi sheet của hai app. Thêm sheet mới: gắn `.presentationAllowsAppTermination()` trong nội dung, thêm một dòng ở đây
# (đối số đầu đúng như trong mã) kèm cách nó đóng khi thoát, và kiểm tay ⌘Q / Thoát từ Dock khi sheet đang mở (plan giai
# đoạn 5, mục Validation, danh sách test tay).
KNOWN_PRESENTATIONS: tuple[Known, ...] = (
    Known(
        "Packages/ExamFeatures/Sources/SessionFeature/Views/SessionAppController.swift",
        "sheet",
        "item: Binding( get: { coordinator.preExam }, set: { if $0 == nil { coordinator.cancelPreExam() } } )",
        "Trước khi thi (cả hai bản): SwiftUI đóng sheet, binding gọi cancelPreExam()",
    ),
    Known(
        "Packages/ExamFeatures/Sources/LibraryFeature/Views/LibraryRootView.swift",
        "sheet",
        "item: Binding( get: { model.infoExamID.map(InfoTarget.init(id:)) }, set: { target in model.infoExamID = target?.id } )",
        "Thông tin đề: SwiftUI đóng sheet, binding đặt infoExamID = nil",
    ),
    Known(
        "Packages/ExamFeatures/Sources/LibraryFeature/Views/LibraryRootView.swift",
        "sheet",
        "item: Self.problemsBinding(problems, model: model)",
        "Danh sách file không thêm được: SwiftUI đóng sheet, binding bỏ lời nhắc (chỉ để đọc, không mở lại)",
    ),
    Known(
        "Packages/ExamFeatures/Sources/SessionFeature/Views/SessionStyle.swift",
        "sheet",
        "isPresented: $isZoomed",
        "Ảnh phóng to (cửa sổ làm bài, xem trước của Soạn đề): SwiftUI đóng sheet, isZoomed = false",
    ),
    Known(
        "Packages/ExamFeatures/Sources/SessionFeature/Views/SessionWindowView.swift",
        "sheet",
        "isPresented: Binding( get: { window.reportFlow?.presentsSheet == true }, "
        "set: { presented in if !presented { window.reportFlow?.sheetDismissed() } } )",
        "Xuất PDF/In kết quả (hộp chọn, tiến độ): SwiftUI đóng sheet, binding gọi sheetDismissed() (hộp chọn: như Huỷ; "
        "tiến độ: huỷ lần dựng); file tạm còn lại xoá lúc willTerminate (ReportFileWriter)",
    ),
    Known(
        "Packages/ExamFeatures/Sources/AuthoringFeature/Views/AuthoringWindow.swift",
        "sheet",
        "isPresented: Binding( get: { reports.flow?.presentsSheet == true }, "
        "set: { presented in if !presented { reports.flow?.sheetDismissed() } } )",
        "Xuất PDF/In đề (bản Admin; hộp chọn, tiến độ): SwiftUI đóng sheet, binding gọi sheetDismissed() (hộp chọn: như "
        "Huỷ; tiến độ: huỷ lần dựng); file tạm còn lại xoá lúc willTerminate (ReportFileWriter)",
    ),
)


@dataclass(frozen=True)
class Found:
    path: str
    line: int
    call: str
    first_argument: str
    has_modifier: bool


def normalize(text: str) -> str:
    return " ".join(text.split())


def line_of(src: str, index: int) -> int:
    return src.count("\n", 0, index) + 1


def trailing_closure_end(masked: str, after_paren: int) -> int:
    """Vị trí sau closure theo sau lời gọi (`) { … }`), hoặc `after_paren` nếu không có."""
    i = after_paren
    n = len(masked)
    while i < n and masked[i] in " \t\n":
        i += 1
    if i >= n or masked[i] != "{":
        return after_paren
    depth = 0
    while i < n:
        if masked[i] == "{":
            depth += 1
        elif masked[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def content_closure(masked: str, args: list[tuple[int, int]], after: int) -> tuple[int, int] | None:
    """Closure nội dung của lời gọi: closure theo sau `)`, hoặc đối số `content: { … }`; (vị trí `{`, vị trí sau `}`)."""
    end = trailing_closure_end(masked, after)
    if end != after:
        return masked.index("{", after), end
    for a, b in args:
        label, value = split_label(masked, a, b)
        if label == "content" and masked[value: value + 1] == "{":
            return value, b
    return None


def has_top_level_modifier(masked: str, start: int, end: int) -> bool:
    """Modifier ở cấp ngoài cùng của closure `masked[start:end]` (`{` ở `start`): ngoặc nhọn sâu 1, ngoài ngoặc
    tròn/vuông, nên không tính modifier trong nhánh `if`, closure lồng hay nội dung của sheet lồng."""
    braces = 0
    others = 0
    i = start
    while i < end:
        c = masked[i]
        if c == "{":
            braces += 1
        elif c == "}":
            braces -= 1
        elif c in "([":
            others += 1
        elif c in ")]":
            others -= 1
        elif c == "." and braces == 1 and others == 0 and MODIFIER_RE.match(masked, i):
            return True
        i += 1
    return False


def scan_source(path: str, src: str) -> list[Found]:
    masked, _ = lex(src)
    found: list[Found] = []
    for m in CALL_RE.finditer(masked):
        if DECLARATION_RE.search(masked[: m.start()]):
            continue  # khai báo (`func sheet(`, `case sheet(`), không phải lời gọi
        open_paren = m.end() - 1
        args, after = call_arguments(masked, open_paren)
        first = normalize(src[args[0][0]: args[0][1]]) if args else ""
        closure = content_closure(masked, args, after)
        has_modifier = closure is not None and has_top_level_modifier(masked, *closure)
        found.append(Found(path, line_of(src, m.start()), m.group(1), first, has_modifier))
    return found


def quit_override_problems(path: str, src: str) -> list[str]:
    """Mục 4: chỗ thay mục Thoát hay cài handler Apple event thoát (bỏ comment và chuỗi)."""
    masked, _ = lex(src)
    problems: list[str] = []
    for pattern, what in QUIT_OVERRIDES:
        for m in pattern.finditer(masked):
            problems.append(
                f"{path}:{line_of(src, m.start())}: {what}. Mục Thoát (⌘Q, ⌥⌘Q) và Apple event thoát (Dock, đăng xuất) là "
                "của AppKit, không thay (AGENTS.md, bảng bất biến; plan giai đoạn 5, Decisions 2026-10-17): sheet không "
                f"chặn thoát thì gắn .{MODIFIER}(); cần hỏi trước khi thoát thì dùng applicationShouldTerminate của app "
                "delegate."
            )
    return problems


def problems_for(found: list[Found], known: tuple[Known, ...]) -> list[str]:
    problems: list[str] = []
    remaining = list(known)
    for f in found:
        key = (f.path, f.call, f.first_argument)
        match = next((k for k in remaining if (k.path, k.call, normalize(k.first_argument)) == key), None)
        where = f"{f.path}:{f.line}: .{f.call}({f.first_argument})"
        if match is None:
            problems.append(
                f"{where}: sheet/popover chưa có trong danh sách KNOWN_PRESENTATIONS của scripts/check_quit_sheets.py. "
                "Sheet SwiftUI mặc định chặn app thoát (⌘Q không làm gì, Thoát từ Dock và đăng xuất bị huỷ): gắn "
                f".{MODIFIER}() trong nội dung sheet, thêm một dòng vào danh sách kèm cách sheet đóng khi thoát, và "
                "thêm mục test tay (⌘Q, Thoát từ Dock khi sheet đang mở) vào plan."
            )
            continue
        remaining.remove(match)
        if f.call in SWIFTUI_CALLS and not f.has_modifier:
            problems.append(
                f"{where}: thiếu .{MODIFIER}() ở cấp ngoài cùng của closure nội dung (gắn vào cả view nội dung, không "
                "chỉ một nhánh if hay view con): sheet này sẽ chặn ⌘Q, Thoát từ Dock và đăng xuất."
            )
    for k in remaining:
        problems.append(
            f"{k.path}: .{k.call}({normalize(k.first_argument)}) có trong KNOWN_PRESENTATIONS nhưng không còn trong mã "
            "(đã xoá hay đổi đối số?): sửa danh sách cho khớp mã và xem lại cách sheet đóng khi thoát."
        )
    return problems


def source_files(root: Path = ROOT) -> list[tuple[str, str]]:
    files: list[tuple[str, str]] = []
    for directory in SCAN_DIRS:
        for path in sorted((root / directory).rglob("*.swift")):
            files.append((path.relative_to(root).as_posix(), path.read_text(encoding="utf-8")))
    return files


def check(root: Path = ROOT) -> tuple[list[Found], list[str]]:
    files = source_files(root)
    found = [f for path, src in files for f in scan_source(path, src)]
    overrides = [p for path, src in files for p in quit_override_problems(path, src)]
    return found, problems_for(found, KNOWN_PRESENTATIONS) + overrides


def self_test() -> list[str]:
    failures: list[str] = []
    path = "Packages/ExamFeatures/Sources/X/V.swift"
    known = (Known(path, "sheet", "isPresented: $isShown", "đối chứng"),)

    def expect(name: str, src: str, must_mention: str | None) -> None:
        problems = problems_for(scan_source(path, src), known)
        if must_mention is None:
            if problems:
                failures.append(f"đối chứng dương '{name}' bị báo sai: {problems}")
        elif not any(must_mention in p for p in problems):
            failures.append(f"đối chứng âm '{name}' không bị bắt (phải báo '{must_mention}'): {problems}")

    good = (
        "struct V: View {\n"
        "    var body: some View {\n"
        "        Color.clear\n"
        "            .sheet(isPresented: $isShown) {\n"
        "                Text(\"x\", bundle: .module)\n"
        f"                    .{MODIFIER}()\n"
        "            }\n"
        "    }\n"
        "}\n"
    )
    expect("sheet đã biết, có modifier", good, None)
    expect("sheet đã biết, xuống dòng và khoảng trắng khác",
           good.replace(".sheet(isPresented: $isShown)", ". sheet (\n                isPresented:   $isShown\n            )"),
           None)
    expect("modifier trong đối số content:",
           f"let v = x.sheet(isPresented: $isShown, content: {{ Text(\"x\").{MODIFIER}() }})\n", None)
    expect("sheet đã biết, thiếu modifier", good.replace(f".{MODIFIER}()", ".padding()"), "thiếu")
    expect("modifier chỉ trong comment", good.replace(f".{MODIFIER}()", f"// .{MODIFIER}()"), "thiếu")
    expect("modifier chỉ trong chuỗi", good.replace(f".{MODIFIER}()", f"; let s = \".{MODIFIER}()\""), "thiếu")
    expect("modifier ở sau lời gọi, ngoài closure",
           f"let v = x.sheet(isPresented: $isShown) {{ Text(\"x\") }}\n    .{MODIFIER}()\n", "thiếu")
    expect("modifier chỉ trong một nhánh if của nội dung",
           f"let v = x.sheet(isPresented: $isShown) {{\n    if c {{ A().{MODIFIER}() }} else {{ B() }}\n}}\n", "thiếu")
    expect("modifier chỉ ở sheet lồng bên trong",
           f"let v = x.sheet(isPresented: $isShown) {{\n    A().sheet(isPresented: $inner) {{ B().{MODIFIER}() }}\n}}\n",
           "thiếu")
    expect("modifier trong đối số của view con (ngoặc tròn)",
           f"let v = x.sheet(isPresented: $isShown) {{ A(content: B().{MODIFIER}()) }}\n", "thiếu")
    expect("nội dung truyền bằng tên hàm", "let v = x.sheet(isPresented: $isShown, content: makeSheet)\n", "thiếu")
    expect("modifier sau view có closure riêng",
           f"let v = x.sheet(isPresented: $isShown) {{ A {{ B() }}\n    .{MODIFIER}() }}\n", None)
    for name, extra in (
        ("sheet mới (isPresented)", "let a = x.sheet(isPresented: $other) { Text(\"y\") }\n"),
        ("sheet mới (item)", "let a = x.sheet(item: $selection) { item in Text(\"y\") }\n"),
        ("fullScreenCover", "let a = x.fullScreenCover(isPresented: $other) { Text(\"y\") }\n"),
        ("popover", "let a = x.popover(isPresented: $other) { Text(\"y\") }\n"),
        ("sheet gọi không dấu chấm trong extension",
         "extension View {\n    func zoom(_ b: Binding<Bool>) -> some View { sheet(isPresented: b) { Text(\"y\") } }\n}\n"),
        ("sheet mới có modifier vẫn phải vào danh sách",
         f"let a = x.sheet(isPresented: $other) {{ Text(\"y\").{MODIFIER}() }}\n"),
        ("sheet AppKit beginSheet", "window.beginSheet(panel) { _ in }\n"),
        ("sheet AppKit beginCriticalSheet", "window.beginCriticalSheet(panel)\n"),
        ("NSViewController.presentAsSheet", "controller.presentAsSheet(other)\n"),
    ):
        expect(name, good + extra, "chưa có trong danh sách")
    expect("sheet đã biết xuất hiện hai lần", good + good, "chưa có trong danh sách")
    expect("mục trong danh sách không còn trong mã", "struct V {}\n", "không còn trong mã")
    expect("đối số đầu khác mục trong danh sách", good.replace("$isShown", "$isOther"), "chưa có trong danh sách")
    expect("không tính: comment, chuỗi, khai báo, tên khác",
           good + "// .sheet(isPresented: $a)\n/* x.popover(isPresented: $b) */\nlet s = \".sheet(isPresented: $c)\"\n"
           "func sheet(isPresented: Bool) {}\nenum M { case sheet(Int) }\n"
           "alert.beginSheetModal(for: window) { _ in }\nlet a = window.attachedSheet\nwindow.endSheet(s)\n"
           "let p = NSPopover()\nlet t = mySheet(1)\n",
           None)
    failures += quit_override_self_test()
    return failures


def quit_override_self_test() -> list[str]:
    """Đối chứng cho mục 4."""
    failures: list[str] = []
    path = "Packages/ExamFeatures/Sources/X/Shell.swift"
    for name, src, must in (
        ("CommandGroup(replacing: .appTermination)",
         "var body: some Commands {\n    CommandGroup(replacing: .appTermination) { Button(\"Q\") {} }\n}\n", "appTermination"),
        ("replacing: CommandGroupPlacement.appTermination",
         "CommandGroup(replacing:CommandGroupPlacement .appTermination) {}\n", "appTermination"),
        ("setEventHandler … kAEQuitApplication",
         "NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(quit(_:withReplyEvent:)),\n"
         "    forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(kAEQuitApplication))\n",
         "kAEQuitApplication"),
        ("AEInstallEventHandler … kAEQuitApplication",
         "AEInstallEventHandler(AEEventClass(kCoreEventClass), AEEventID(kAEQuitApplication), handler, nil, false)\n",
         "kAEQuitApplication"),
    ):
        problems = quit_override_problems(path, src)
        if not any(must in p for p in problems):
            failures.append(f"đối chứng âm '{name}' không bị bắt: {problems}")
    allowed = (
        "CommandGroup(after: .appTermination) { Button(\"x\") {} }\n"
        "CommandGroup(replacing: .newItem) {}\n"
        "// CommandGroup(replacing: .appTermination)\n"
        "let s = \"kAEQuitApplication\"\n"
        "/* setEventHandler(…, andEventID: AEEventID(kAEQuitApplication)) */\n"
        "let reason = event.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason))\n"
    )
    if quit_override_problems(path, allowed):
        failures.append(f"đối chứng dương mục 4 bị báo sai: {quit_override_problems(path, allowed)}")
    return failures


def main(argv: list[str]) -> int:
    failures = self_test()
    if failures:
        print("FAIL check_quit_sheets.py tự kiểm (hàm kiểm không còn bắt được vi phạm):")
        for f in failures:
            print(f"  - {f}")
        return 1
    found, problems = check()
    if problems:
        print(f"FAIL thoát app: sheet chặn thoát hoặc thay đường thoát của AppKit ({len(problems)} lỗi; xem docstring của "
              "scripts/check_quit_sheets.py):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"ok   {len(found)} sheet/popover đều trong danh sách đã biết và gắn .{MODIFIER}() ở cấp ngoài cùng của nội dung "
          "(không chặn ⌘Q, Thoát từ Dock, đăng xuất); không thay mục Thoát hay Apple event thoát của AppKit "
          "(đối chứng âm bị bắt)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
