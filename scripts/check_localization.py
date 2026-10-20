#!/usr/bin/env python3
"""Kiểm chuỗi giao diện và String Catalog (giai đoạn 5, bước 4; đòi đủ bản tiếng Anh từ bước 7c).

Thẩm quyền: docs/product/accessibility-localization.md (mục Ngôn ngữ: tiếng Việt là ngôn ngữ nguồn, mỗi target có
chữ giao diện có `Localizable.xcstrings`, chữ trong package phải chỉ rõ bundle của module), plan
docs/plans/completed/giai-doan-5-hoan-thien.md bước 4, kết luận spike docs/notes/g5-spike-pdf-l10n.md (quên `bundle:`
không gây lỗi hay cảnh báo, chỉ quét mã nguồn mới bắt được).

1. Quét mã nguồn (Packages/ExamFeatures/Sources, Apps/Student, Apps/Admin). Chữ giao diện trong package mặc định tra
   bundle CHÍNH của app, nên phải tra catalog của module:
   - `Text("…")`, `String(localized: "…")`, `LocalizedStringResource("…")`, `AttributedString(localized: "…")` phải có
     `bundle: .module`;
   - API SwiftUI nhận khoá chuỗi mà không có tham số bundle (`Button`, `Label`, `Toggle`, `Picker`, `Section`,
     `TextField`, `Menu`, `LabeledContent`, `.help`, `.accessibilityLabel`, `.alert`, `prompt:`…) không được nhận chuỗi
     literal: dùng hàm `localized("…")` của module (trả `String` đã tra catalog của module);
   - không dùng kiểu `LocalizedStringKey` (không mang bundle; tham số chữ của view nhận `String` đã tra);
   - ở target có chữ giao diện (mọi target trừ LibraryData, AuthoringData, ExamImport: câu tiếng Việt ở đó chỉ cho
     nhật ký và test, giao diện dựng câu theo mã, bước 7b), chuỗi literal có chữ tiếng Việt có dấu phải nằm trong một
     lời gọi tra catalog ở trên. Chữ không phải giao diện (log cho người phát triển) đánh dấu `// l10n-ignore` trên dòng.
   - luật `core-text` (target có chữ giao diện và Apps; bước 7b, accessibility-localization.md phương án 2): câu tiếng
     Việt của lõi và target dữ liệu không lên giao diện. Báo truy cập `.errorDescription`, `.localizedDescription`,
     `.failureReason`, `.recoverySuggestion` (đường lọt chung của `ExamFileError` và mọi `LocalizedError`), `.logMessage`,
     `.logDescription`, `.logName` (câu nhật ký của chi tiết lỗi lõi `JSONProblem`/`MigrationProblem`/`WriteProblem` và của
     LibraryData, AuthoringData, ExamImport), và `.message` của `ValidationIssue`: sau biến tên `issue`/`issues`/
     `…Issue(s)` hoặc biến khai báo kiểu `ValidationIssue`/`[ValidationIssue]` trong cùng file (không tính
     `ErrorMessages.message`/`AuthoringMessages.message`; vấn đề nằm trong biến tên khác có kiểu suy ra thì không thấy).
     Dùng `ErrorMessages.message(for:)` (LibraryFeature) hoặc `AuthoringMessages.message(for:)`; câu của hệ thống cho lỗi
     ngoài Exam Suite qua `ErrorMessages.systemDescription` (dòng đó có `// l10n-ignore` kèm lý do).
   - luật `region-locale` (mọi target được quét; bước 7a): số, phần trăm, ngày giờ định dạng theo locale của ngôn ngữ
     giao diện, không theo Region của macOS (accessibility-localization.md, mục Ngôn ngữ). Báo `Locale.current`,
     `Locale.autoupdatingCurrent` (kể cả dạng `locale: .current`, `Locale = .autoupdatingCurrent`), `.formatted()` không
     đối số hoặc có nhãn `date:`/`time:`, `.formatted(.number…)` (kiểu định dạng viết tắt, trừ `.iso8601`) không có
     `.locale(…)`, `…FormatStyle(…)` không có `locale:` (trừ ISO 8601), `Date.FormatStyle(…)` không có `calendar:` (lịch
     theo Region), lớp `…Formatter()` cũ và hàm tĩnh của chúng (`DateFormatter.localizedString(from:…)`,
     `ByteCountFormatter.string(fromByteCount:…)`…), `String(format:)` không có `locale:` và
     `String.localizedStringWithFormat`; quét cả mã trong nội suy `\\(…)` của chuỗi. Dùng `InterfaceLocale.current`
     (LibraryFeature), `InterfaceLocale.number(_:)`, `.locale(InterfaceLocale.current)`, `InterfaceLocale.calendar`;
     trong view SwiftUI `Text(n, format: .number)` theo `\\.locale` của môi trường (gốc scene gắn `.interfaceLocale()`),
     không bị báo.
   - luật `scene-locale` (StudentShell, AdminShell và điểm vào của hai app ở Apps/Student, Apps/Admin): mỗi scene ở cấp
     ngoài cùng của `var body: some Scene` gắn `.interfaceLocale()`, trừ scene gộp khai báo trong shell (`struct …:
     Scene`, body của nó được kiểm); shell hay app không còn `body` nào của Scene cũng là lỗi (luật không được rỗng).
   - luật `test-hook` (bước 7c): chỗ ép ngôn ngữ chỉ cho test (`InterfaceStrings.languageOverride`,
     `.processLanguageOverride`) không xuất hiện trong Sources/Apps ngoài file khai báo nó (InterfaceStrings.swift).
2. Catalog (`*.xcstrings` trong Packages/ExamFeatures/Sources và Apps): JSON hợp lệ, `sourceLanguage` là `vi`; mỗi
   khoá có giá trị tiếng Việt (khoá nguồn khác rỗng; `InfoPlist.xcstrings` có `vi` tường minh vì khoá là tên khoá
   Info.plist); không khoá `stale` (không còn trong code: xoá khỏi catalog); không bản dịch nào rỗng (catalog biên
   dịch chữ rỗng thì giao diện hiện chữ rỗng). `--require-en` (bật từ bước 7c của plan giai đoạn 5 ở `check.sh` mọi chế
   độ và `verify_local.sh`): mỗi khoá cần dịch có bản `en` ở trạng thái `translated` (cả biến thể plural và
   substitution); đối số của chuỗi `en` (số vị trí và kiểu, token `%#@tên@` tính theo `argNum`/`formatSpecifier`) khớp
   chuỗi nguồn, cho phép đổi thứ tự bằng số vị trí; có substitution thì mọi đặc tả khác có số vị trí; biến thể plural đủ
   `one`/`other`, chỉ dùng đối số của nguồn (dạng `one` được bỏ số), biến thể của substitution chỉ dùng `%arg`.
3. `--freshness <thư mục .build>` (macOS, sau `swift build`/`swift test` của Packages/ExamFeatures): đồng bộ bản sao
   của từng `Localizable.xcstrings` với các `.stringsdata` do trình biên dịch ghi (`xcrun xcstringstool sync`), so
   nội dung JSON với file đã commit; khác (khoá mới chưa vào catalog, khoá không còn dùng) thì thất bại kèm danh sách
   khoá. Không sửa file nào. `scripts/verify_local.sh` còn kiểm bằng `xcodebuild -exportLocalizations` (gồm cả
   `InfoPlist.xcstrings`).

Mỗi lần chạy, các hàm kiểm được thử trước trên đầu vào cố ý sai (đối chứng âm) và đầu vào đúng (đối chứng dương);
hàm kiểm không bắt được đối chứng âm thì script thất bại, để phép kiểm không âm thầm hỏng.

4. `--built-apps <Build/Products/Debug>` (sau khi build hai scheme): bundle chính của mỗi app có `vi.lproj` và
   `en.lproj` (thiếu một thì cả app kẹt một ngôn ngữ), `CFBundleDevelopmentRegion` là vi, mỗi khoá của
   `InfoPlist.xcstrings` tra được ở cả hai ngôn ngữ và bằng bản của catalog cho ngôn ngữ đó (tên app không dịch: bằng
   giá trị gốc); bundle tài nguyên của mỗi target có catalog nằm trong app với ngôn ngữ nguồn vi, và mọi bundle có chữ đã
   biên dịch có cùng tập `*.lproj` (review #50 N2: `InterfaceLocale` chọn ngôn ngữ theo bundle LibraryFeature), có `en`
   khi `--require-en`; bundle có chữ mà không có trong `BUILT_APPS` cũng là lỗi.

Dùng: scripts/check_localization.py                          (quét mã nguồn + catalog; chạy được trên Linux)
      scripts/check_localization.py --freshness <.build>     (thêm kiểm catalog đủ khoá; cần xcrun xcstringstool)
      scripts/check_localization.py --built-apps <Products>  (thêm kiểm hai app đã build)
      thêm --allow-missing-stringsdata vào --freshness: không thất bại khi hệ build không ghi .stringsdata
      scripts/check_localization.py --require-en             (đòi đủ bản tiếng Anh; check.sh, verify_local.sh luôn truyền)
"""
from __future__ import annotations

import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = Path("Packages/ExamFeatures/Sources")
APP_DIRS = (Path("Apps/Student"), Path("Apps/Admin"))
# Target dữ liệu (không giao diện): câu tiếng Việt ở đây chỉ cho nhật ký và test (`logMessage`); tầng giao diện dựng câu
# theo mã (bước 7b, accessibility-localization.md phương án 2). Quy tắc "chữ tiếng Việt phải qua catalog" không áp dụng
# ở đây; luật `core-text` canh để câu đó không lên giao diện.
PLAIN_STRING_TARGETS = {"LibraryData", "AuthoringData", "ExamImport"}
IGNORE_MARK = "l10n-ignore"
HELPER = "localized"

# API nhận chuỗi literal làm khoá (LocalizedStringKey) và CÓ tham số `bundle:`.
BUNDLE_APIS = ("Text",)
# Khởi tạo tra catalog, phải có `bundle:` (đối số đầu có nhãn `localized:` hoặc không nhãn).
LOCALIZED_INITS = ("String", "AttributedString", "LocalizedStringResource")
# API SwiftUI nhận khoá chuỗi nhưng KHÔNG có tham số bundle: chuỗi literal ở đối số đầu luôn sai.
KEY_ONLY_TYPES = (
    "Button", "Label", "Toggle", "Picker", "Section", "TextField", "SecureField", "Menu", "LabeledContent",
    "Stepper", "ContentUnavailableView", "GroupBox", "DisclosureGroup", "Link", "ProgressView", "Window",
    "WindowGroup", "CommandMenu", "ControlGroup", "DatePicker", "ColorPicker", "NavigationLink", "ShareLink",
    "MenuBarExtra", "Gauge", "Slider", "Tab", "TableColumn", "LocalizedStringKey",
)
KEY_ONLY_MODIFIERS = (
    "help", "accessibilityLabel", "accessibilityHint", "accessibilityValue", "accessibilityInputLabels",
    "accessibilityAction", "accessibilityActions", "navigationTitle", "navigationSubtitle", "alert",
    "confirmationDialog", "badge", "searchable", "fileImporter", "fileExporter", "toolbarTitleMenu",
    "accessibilityRotor", "accessibilityCustomContent", "fileDialogMessage", "fileDialogConfirmationLabel",
    "dialogSuppressionToggle",
)
# Tham số có nhãn nhận khoá chuỗi (LocalizedStringKey) ở bất kỳ lời gọi nào.
KEY_LABELS = ("prompt", "named", "titleKey", "withTitle")
# Giá trị `bundle:` được chấp nhận: bundle tài nguyên của chính module (catalog của target).
MODULE_BUNDLES = (".module", "Bundle.module", "#bundle")
# Thuộc tính chữ của AppKit (NSAlert, NSSavePanel/NSOpenPanel, NSMenuItem, NSWindow…) nhận String trơn: gán chuỗi literal
# có chữ cái là chữ không qua catalog, kể cả chữ ASCII ("Delete exam?").
APPKIT_TEXT_PROPERTIES = (
    "messageText", "informativeText", "prompt", "message", "title", "nameFieldLabel", "nameFieldStringValue",
    "toolTip", "placeholderString",
)


# Luật region-locale: locale theo Region của macOS (Locale.current…) và API định dạng mặc định theo nó.
REGION_LOCALE_PATTERNS = (
    re.compile(r"(?<![\w.])(?:Foundation\.)?(?:NS)?Locale\s*\.\s*(?:current|autoupdatingCurrent)\b"),
    re.compile(r"(?<![\w])[Ll]ocale\s*\??\s*[:=]\s*\.(?:current|autoupdatingCurrent)\b"),
    re.compile(r"\.locale\s*\(\s*\.(?:current|autoupdatingCurrent)\s*\)"),
)
LEGACY_FORMATTERS = (
    "DateFormatter", "NumberFormatter", "DateComponentsFormatter", "DateIntervalFormatter", "ByteCountFormatter",
    "MeasurementFormatter", "RelativeDateTimeFormatter", "ListFormatter", "PersonNameComponentsFormatter",
)
# Luật core-text: câu tiếng Việt của lõi (ExamKit, ExamFile) và target dữ liệu không lên giao diện (bước 7b).
CORE_TEXT_MEMBERS = (
    "errorDescription", "localizedDescription", "failureReason", "recoverySuggestion", "logMessage", "logDescription",
    "logName",
)
CORE_TEXT_MEMBER_RE = re.compile(r"\.\s*(" + "|".join(CORE_TEXT_MEMBERS) + r")\b")
# `.message` của `ValidationIssue` (lõi, tên giữ vì script và test dùng): sau biến (cùng dòng) tên `issue`, `issues`,
# `firstIssue`, `validationIssues`…, hoặc tên khai báo kiểu `ValidationIssue`/`[ValidationIssue]` trong cùng file
# (`_ v: ValidationIssue`, `let all: [ValidationIssue]`), kể cả key path `issues.map(\.message)`. Không tính
# `ErrorMessages.message(for:)`/`AuthoringMessages.message(for:)` (hàm dựng câu của catalog). Tên kiểu
# (`PreExamIssue.…`) viết hoa nên không khớp. Giới hạn: vấn đề nằm trong biến tên khác mà kiểu suy ra (`let x =
# issues[0]`, `$0` trong closure) thì luật không thấy; test so câu theo mã (`ErrorMessagesTests`) và review bù.
MESSAGE_ACCESS = r"[^\n;]*?(?<!ErrorMessages)(?<!AuthoringMessages)\\?\.message\b"
ISSUE_MESSAGE_RE = re.compile(r"(?<!\w)(?:issues?|[a-z]\w*Issues?)\b" + MESSAGE_ACCESS)
ISSUE_DECLARATION_RE = re.compile(r"(?<![\w.])([a-z_]\w*)\s*:\s*\[?\s*ValidationIssue\b")
CORE_TEXT_HINT = ("câu tiếng Việt của lõi/target dữ liệu chỉ cho nhật ký: giao diện dựng câu của catalog theo mã "
                  "(accessibility-localization.md phương án 2, bước 7b). Dùng ErrorMessages.message(for:) (LibraryFeature) "
                  "hoặc AuthoringMessages.message(for:) (AuthoringFeature); lỗi ngoài Exam Suite: "
                  "ErrorMessages.systemDescription(of:). Không phải chữ giao diện (nhật ký) thì thêm "
                  f"`// {IGNORE_MARK}` kèm lý do.")

REGION_HINT = ("số, phần trăm, ngày giờ của giao diện theo ngôn ngữ giao diện, không theo Region của macOS "
               "(accessibility-localization.md, mục Ngôn ngữ). Dùng InterfaceLocale.current, "
               "InterfaceLocale.number(_:)/percent(_:) hoặc .locale(InterfaceLocale.current); không phải chữ giao diện "
               f"thì thêm `// {IGNORE_MARK}` kèm lý do.")


@dataclass(frozen=True)
class Literal:
    start: int  # vị trí ký tự mở (kể cả `#` của raw string)
    end: int  # vị trí sau ký tự đóng
    content: str  # nội dung giữa hai dấu nháy (nội suy giữ nguyên dạng mã)
    depth: int  # 0: trong mã; >0: nằm trong nội suy của chuỗi khác


@dataclass(frozen=True)
class Problem:
    path: str
    line: int
    rule: str
    message: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: [{self.rule}] {self.message}"


# ---------------------------------------------------------------------------------------------------------------
# Tách mã Swift: comment, chuỗi literal (thường, nhiều dòng, raw), nội suy lồng nhau.


def lex(src: str) -> tuple[str, list[Literal]]:
    """Trả (mã đã che, các chuỗi literal). Mã đã che giữ nguyên độ dài và xuống dòng: comment thành khoảng trắng,
    nội dung chuỗi (kể cả nội suy) thành `_`, giữ dấu nháy, để tìm ngoặc và dấu phẩy không vấp vào chữ."""
    masked, literals, _ = _lex(src)
    return masked, literals


def code_mask(src: str) -> str:
    """Như mã đã che của `lex`, nhưng **giữ mã trong nội suy** `\\( … )` của chuỗi: chỉ phần chữ của chuỗi (và dấu `\\`
    mở nội suy) thành `_`. Cho luật nhìn cả biểu thức nằm trong chuỗi, ví dụ `localized("Nộp lúc \\(d.formatted())")`."""
    _, _, code = _lex(src)
    return code


def _lex(src: str) -> tuple[str, list[Literal], str]:
    n = len(src)
    literals: list[Literal] = []
    comments: list[tuple[int, int]] = []
    text_spans: list[tuple[int, int]] = []  # phần chữ của mọi chuỗi (mọi độ sâu), không gồm mã nội suy

    def string_at(i: int) -> bool:
        j = i
        while j < n and src[j] == "#":
            j += 1
        return j < n and src[j] == '"' and (j > i or src[i] == '"')

    def lex_string(i: int, depth: int) -> int:
        j = i
        hashes = 0
        while src[j] == "#":
            hashes += 1
            j += 1
        multiline = src.startswith('"""', j)
        j += 3 if multiline else 1
        close = ('"""' if multiline else '"') + "#" * hashes
        escape = "\\" + "#" * hashes
        start = j
        segment = j
        while j < n:
            if src.startswith(escape, j):
                k = j + len(escape)
                if k < n and src[k] == "(":
                    text_spans.append((segment, k))
                    j = lex_code(k + 1, depth + 1, stop_at_paren=True)
                    segment = j
                    continue
                j = k + 1
                continue
            if src.startswith(close, j):
                text_spans.append((segment, j))
                literals.append(Literal(i, j + len(close), src[start:j], depth))
                return j + len(close)
            if not multiline and src[j] == "\n":
                text_spans.append((segment, j))
                return j  # chuỗi không đóng: bỏ qua phần còn lại của dòng
            j += 1
        text_spans.append((segment, j))
        return j

    def lex_code(i: int, depth: int, stop_at_paren: bool) -> int:
        parens = 0
        while i < n:
            c = src[i]
            if src.startswith("//", i):
                end = src.find("\n", i)
                end = n if end < 0 else end
                if depth == 0:
                    comments.append((i, end))
                i = end
            elif src.startswith("/*", i):
                level, j = 1, i + 2
                while j < n and level:
                    if src.startswith("/*", j):
                        level, j = level + 1, j + 2
                    elif src.startswith("*/", j):
                        level, j = level - 1, j + 2
                    else:
                        j += 1
                if depth == 0:
                    comments.append((i, j))
                i = j
            elif (c == '"' or c == "#") and string_at(i):
                i = lex_string(i, depth)
            elif c == "(":
                parens += 1
                i += 1
            elif c == ")":
                if stop_at_paren and parens == 0:
                    return i + 1
                parens -= 1
                i += 1
            else:
                i += 1
        return i

    lex_code(0, 0, stop_at_paren=False)
    masked = list(src)
    for a, b in comments:
        for k in range(a, b):
            if masked[k] != "\n":
                masked[k] = " "
    code = list(masked)
    for a, b in text_spans:
        for k in range(a, b):
            if code[k] != "\n":
                code[k] = "_"
    for lit in literals:
        if lit.depth:
            continue
        open_len = src.index('"', lit.start) - lit.start + (3 if src.startswith('"""', src.index('"', lit.start)) else 1)
        close_len = open_len
        for k in range(lit.start + open_len, lit.end - close_len):
            if masked[k] != "\n":
                masked[k] = "_"
    return "".join(masked), literals, "".join(code)


def call_arguments(masked: str, open_paren: int) -> tuple[list[tuple[int, int]], int]:
    """Các đối số cấp cao nhất (vị trí đầu, cuối, đã bỏ khoảng trắng) của lời gọi mở ở `open_paren`, và vị trí sau
    dấu đóng ngoặc."""
    args: list[tuple[int, int]] = []
    depth = 0
    start = open_paren + 1
    i = start
    n = len(masked)
    while i < n:
        c = masked[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                args.append((start, i))
                break
            depth -= 1
        elif c == "," and depth == 0:
            args.append((start, i))
            start = i + 1
        i += 1
    trimmed = []
    for a, b in args:
        while a < b and masked[a].isspace():
            a += 1
        while b > a and masked[b - 1].isspace():
            b -= 1
        if b > a:
            trimmed.append((a, b))
    return trimmed, i + 1


LABEL_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*:(?!:)")


def split_label(masked: str, a: int, b: int) -> tuple[str | None, int]:
    """Nhãn của đối số (nếu có) và vị trí đầu giá trị."""
    m = LABEL_RE.match(masked, a, b)
    if m:
        j = m.end()
        while j < b and masked[j].isspace():
            j += 1
        return m.group(1), j
    return None, a


def has_vietnamese(text: str) -> bool:
    """Chữ cái có dấu (tiếng Việt và chữ Latin có dấu khác) hoặc đ/Đ."""
    for ch in text:
        if ch in "đĐ":
            return True
        if ord(ch) > 127 and unicodedata.category(ch).startswith("L"):
            base = unicodedata.normalize("NFD", ch)[0]
            if base.isascii() and base.isalpha():
                return True
        if unicodedata.category(ch) == "Mn":
            return True
    return False


def has_letters(content: str) -> bool:
    """Phần chữ của literal (bỏ nội suy `\\(…)`) có chữ cái."""
    out, i, n = [], 0, len(content)
    while i < n:
        if content[i] == "\\":
            j = i + 1
            while j < n and content[j] == "#":
                j += 1
            if j < n and content[j] == "(":
                depth, j = 1, j + 1
                while j < n and depth:
                    depth += {"(": 1, ")": -1}.get(content[j], 0)
                    j += 1
                i = j
                continue
            i = j + 1
            continue
        out.append(content[i])
        i += 1
    return any(ch.isalpha() for ch in out)


def line_of(src: str, index: int) -> int:
    return src.count("\n", 0, index) + 1


def scan_source(path: str, src: str, check_vietnamese: bool) -> list[Problem]:
    masked, literals = lex(src)
    by_start = {lit.start: lit for lit in literals if lit.depth == 0}
    lines = src.splitlines()
    approved: set[int] = set()
    flagged: set[int] = set()  # literal đã bị báo ở luật bundle/key-only: không báo lại ở plain-text
    problems: list[Problem] = []

    def ignored(index: int) -> bool:
        number = line_of(src, index)
        return IGNORE_MARK in lines[number - 1] if number - 1 < len(lines) else False

    def literal_arg(a: int, b: int) -> Literal | None:
        lit = by_start.get(a)
        return lit if lit is not None and lit.end == b else None

    def report(index: int, rule: str, message: str) -> None:
        if not ignored(index):
            problems.append(Problem(path, line_of(src, index), rule, message))

    def calls(names: tuple[str, ...], member: bool):
        prefix = r"\." if member else r"(?<![\w.])(?:SwiftUI\.)?"
        pattern = re.compile(prefix + r"(" + "|".join(names) + r")\s*\(")
        for m in pattern.finditer(masked):
            args, _ = call_arguments(masked, m.end() - 1)
            yield m, args

    def bundle_value(args: list[tuple[int, int]]) -> str | None:
        """Giá trị của đối số `bundle:` (mã nguồn, bỏ khoảng trắng), `None` khi không có."""
        for a, b in args:
            label, value = split_label(masked, a, b)
            if label == "bundle":
                return re.sub(r"\s+", "", src[value:b])
        return None

    def top_level_literals(a: int, b: int) -> list[Literal]:
        """Literal nằm ở cấp ngoặc 0 của biểu thức masked[a:b]: literal đứng một mình, các nhánh `?:`, vế của `+`,
        vế phải của `??`; không tính literal trong lời gọi, mảng hay closure con (`localized("…")`, `Text("…")`)."""
        found: list[Literal] = []
        depth, i = 0, a
        while i < b:
            lit = by_start.get(i)
            if lit is not None:
                if depth == 0:
                    found.append(lit)
                i = lit.end
                continue
            c = masked[i]
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
            i += 1
        return found

    def expression_end(start: int, stops: str) -> int:
        """Vị trí kết thúc biểu thức bắt đầu ở `start`: ký tự trong `stops` ở cấp 0, hoặc ngoặc đóng của cấp ngoài."""
        depth, i = 0, start
        while i < len(masked):
            lit = by_start.get(i)
            if lit is not None:
                i = lit.end
                continue
            c = masked[i]
            if c in "([{":
                depth += 1
            elif c in ")]}":
                if depth == 0:
                    return i
                depth -= 1
            elif depth == 0 and c in stops:
                return i
            i += 1
        return i

    def text_literals(a: int, b: int) -> list[Literal]:
        """Chuỗi literal của biểu thức chữ: literal đứng một mình (kể cả không có chữ cái), hoặc mọi literal cấp 0
        có chữ cái (`cond ? "A" : "B"`, `"Exam " + name`)."""
        single = literal_arg(a, b)
        if single is not None:
            return [single]
        return [lit for lit in top_level_literals(a, b) if has_letters(lit.content)]

    def flag_all(lits: list[Literal]) -> None:
        flagged.update(lit.start for lit in lits)

    # Text("…") phải có đúng `bundle: .module`.
    for m, args in calls(BUNDLE_APIS, member=False):
        if not args:
            continue
        label, value = split_label(masked, *args[0])
        if label is not None:
            continue  # Text(verbatim:), Text(_:format:)…
        lits = text_literals(value, args[0][1])
        if not lits:
            continue
        bundle = bundle_value(args)
        if bundle in MODULE_BUNDLES:
            approved.update(lit.start for lit in lits)
            continue
        flag_all(lits)
        if bundle is None and literal_arg(value, args[0][1]) is None:
            report(m.start(1), "bundle", f"{m.group(1)}(…) có chuỗi literal trong biểu thức (nhánh `?:`, phép `+`) mà "
                   f'không tra catalog của module. Viết từng nhánh {m.group(1)}("…", bundle: .module) hoặc '
                   f'{HELPER}("…"); chữ không cần dịch thì {m.group(1)}(verbatim:).')
        elif bundle is None:
            report(m.start(1), "bundle", f'{m.group(1)}("…") thiếu `bundle: .module`: chữ sẽ tra bundle chính của app '
                   f'thay vì catalog của module. Viết {m.group(1)}("…", bundle: .module), hoặc '
                   f'{m.group(1)}(verbatim: "…") nếu không phải chữ cần dịch.')
        else:
            report(m.start(1), "bundle", f"{m.group(1)}(…, bundle: {bundle}) không tra catalog của module: viết đúng "
                   "`bundle: .module`.")
    # String(localized:), AttributedString(localized:), LocalizedStringResource(…) phải có đúng `bundle: .module`.
    for m, args in calls(LOCALIZED_INITS, member=False):
        if not args:
            continue
        label, value = split_label(masked, *args[0])
        name = m.group(1)
        if name in ("String", "AttributedString") and label != "localized":
            continue
        if name == "LocalizedStringResource" and label not in (None, "stringLiteral"):
            continue
        lits = text_literals(value, args[0][1])
        bundle = bundle_value(args)
        if bundle in MODULE_BUNDLES:
            approved.update(lit.start for lit in lits)
            continue
        flag_all(lits)
        shown = f"{name}(localized:)" if label == "localized" else f"{name}(…)"
        if bundle is None:
            report(m.start(1), "bundle", f"{shown} thiếu `bundle: .module`: chữ sẽ tra bundle chính của app. Dùng "
                   f'{HELPER}("…") (hàm của module) hoặc thêm `bundle: .module`.')
        else:
            report(m.start(1), "bundle", f"{shown} với `bundle: {bundle}` không tra catalog của module: dùng "
                   f'{HELPER}("…") hoặc `bundle: .module`.')
    # API chỉ nhận khoá, không có tham số bundle: không được có chuỗi literal trong đối số đầu.
    for member, names in ((False, KEY_ONLY_TYPES), (True, KEY_ONLY_MODIFIERS)):
        for m, args in calls(names, member):
            name = m.group(1)
            if name == "LocalizedStringKey":
                continue  # báo ở luật "LocalizedStringKey" bên dưới
            if not args:
                continue
            label, value = split_label(masked, *args[0])
            if label is not None:
                continue
            lits = text_literals(value, args[0][1])
            if lits:
                flag_all(lits)
                shown = f".{name}" if member else name
                report(m.start(1), "key-only", f"{shown}(…) nhận chuỗi literal (khoá chuỗi không có tham số bundle, "
                       f"hoặc String trơn qua nhánh `?:`/phép `+`): chữ không tra catalog của module. Viết "
                       f'{shown}({HELPER}("…"), …), mỗi nhánh một {HELPER}("…").')
    # Tham số có nhãn nhận khoá chuỗi: prompt: "…", named: "…", withTitle: "…".
    for m in re.finditer(r"(?<![\w.])(" + "|".join(KEY_LABELS) + r")\s*:\s*", masked):
        lits = text_literals(m.end(), expression_end(m.end(), ","))
        if lits:
            flag_all(lits)
            report(m.start(1), "key-only", f'`{m.group(1)}: "…"` nhận chuỗi không tra catalog của module. Viết '
                   f'`{m.group(1)}: {HELPER}("…")` hoặc Text("…", bundle: .module).')
    # Thuộc tính chữ của AppKit: alert.messageText = "…", panel.prompt = "…".
    for m in re.finditer(r"\.(" + "|".join(APPKIT_TEXT_PROPERTIES) + r")\s*=(?!=)\s*", masked):
        lits = [lit for lit in top_level_literals(m.end(), expression_end(m.end(), "\n;"))
                if has_letters(lit.content)]
        if lits:
            flag_all(lits)
            report(m.start(1), "key-only", f".{m.group(1)} = \"…\" gán chữ trơn cho AppKit: viết "
                   f'.{m.group(1)} = {HELPER}("…").')
    # Kiểu LocalizedStringKey không mang bundle.
    for m in re.finditer(r"(?<![\w.])LocalizedStringKey\b", masked):
        report(m.start(), "key-type", "Không dùng LocalizedStringKey trong package: khoá không mang bundle, Text(khoá) "
               f'tra bundle chính của app. Tham số chữ của view nhận String đã tra bằng {HELPER}("…").')
    # Hàm của module: localized("…").
    for m in re.finditer(r"(?<![\w.])" + HELPER + r"\s*\(", masked):
        args, _ = call_arguments(masked, m.end() - 1)
        if args:
            lit = literal_arg(*args[0])
            if lit is not None:
                approved.add(lit.start)
    # Chú thích cho người dịch (`comment: "…"`) không phải chữ giao diện.
    for m in re.finditer(r"(?<![\w.])comment\s*:\s*", masked):
        if m.end() in by_start:
            approved.add(m.end())
    # Luật region-locale: không định dạng theo Region của macOS. Quét cả mã trong nội suy của chuỗi (`code`).
    code = code_mask(src)
    for pattern in REGION_LOCALE_PATTERNS:
        for m in pattern.finditer(code):
            report(m.start(), "region-locale", f"`{re.sub(r'\\s+', '', code[m.start():m.end()])}` theo Region: "
                   + REGION_HINT)
    for m in re.finditer(r"\.formatted\s*\(", code):
        args, _ = call_arguments(code, m.end() - 1)
        if not args:
            report(m.start(), "region-locale", "`.formatted()` không đối số định dạng theo Region: " + REGION_HINT)
            continue
        label, _ = split_label(code, *args[0])
        if label in ("date", "time"):
            report(m.start(), "region-locale", f"`.formatted({label}:…)` luôn theo Region (không nhận locale): dùng "
                   "Date.FormatStyle(…, locale:, calendar:, timeZone:). " + REGION_HINT)
            continue
        first = re.sub(r"\s+", "", code[args[0][0]:args[0][1]])
        if first.startswith(".iso8601"):
            continue  # ISO 8601 không phụ thuộc locale
        if first.startswith(".") and ".locale(" not in first:
            report(m.start(), "region-locale", f"`.formatted({first.split('(')[0]}…)` không có `.locale(…)` nên theo "
                   "Region: " + REGION_HINT)
    for m in re.finditer(r"(?<![\w.])((?:[A-Z]\w*\.)*\w*FormatStyle)\s*(?:<[^<>()]*>)?\s*\(", code):
        if "ISO8601" in m.group(1):
            continue
        args, end = call_arguments(code, m.end() - 1)
        labels = {split_label(code, a, b)[0] for a, b in args}
        chained = re.match(r"\s*\.locale\s*\(", code[end:end + 40]) is not None
        if not chained and "locale" not in labels:
            report(m.start(), "region-locale", f"`{m.group(1)}(…)` không có `locale:` nên theo Region: " + REGION_HINT)
        elif m.group(1).endswith("Date.FormatStyle") and "calendar" not in labels:
            report(m.start(), "region-locale", f"`{m.group(1)}(…)` không có `calendar:` nên lịch theo Region (Phật "
                   "lịch, lịch Nhật…): truyền `calendar: InterfaceLocale.calendar` (Gregorian).")
    for m in re.finditer(r"(?<![\w.])(" + "|".join(LEGACY_FORMATTERS) + r")\s*\(\s*\)", code):
        report(m.start(), "region-locale", f"`{m.group(1)}()` mặc định theo Region: dùng FormatStyle có locale; "
               + REGION_HINT)
    for m in re.finditer(r"(?<![\w.])(" + "|".join(LEGACY_FORMATTERS) + r")\s*\.\s*(localizedString|string)\s*\(",
                         code):
        report(m.start(), "region-locale", f"`{m.group(1)}.{m.group(2)}(…)` (hàm tĩnh) theo Region: " + REGION_HINT)
    for m in re.finditer(r"(?<![\w.])String\s*\(\s*format\s*:", code):
        args, _ = call_arguments(code, code.index("(", m.start()))
        if not any(split_label(code, a, b)[0] == "locale" for a, b in args):
            report(m.start(), "region-locale", "`String(format:)` không có `locale:` (số không ngăn nghìn, không theo "
                   "ngôn ngữ giao diện): " + REGION_HINT)
    for m in re.finditer(r"\blocalizedStringWithFormat\b", code):
        report(m.start(), "region-locale", "`String.localizedStringWithFormat` theo Region: " + REGION_HINT)
    if check_vietnamese:
        # Luật core-text: câu tiếng Việt của lõi/target dữ liệu không lên giao diện (quét cả mã trong nội suy).
        for m in CORE_TEXT_MEMBER_RE.finditer(code):
            report(m.start(), "core-text", f"`.{m.group(1)}`: " + CORE_TEXT_HINT)
        issue_hits = {m.start() for m in ISSUE_MESSAGE_RE.finditer(code)}
        typed = set(ISSUE_DECLARATION_RE.findall(code))
        if typed:
            names = "|".join(sorted(re.escape(n) for n in typed))
            issue_hits |= {m.start() for m in re.finditer(r"(?<![\w.])(?:" + names + r")\b" + MESSAGE_ACCESS, code)}
        for start in sorted(issue_hits):
            report(start, "core-text", "`.message` của vấn đề kiểm đề (`ValidationIssue`): " + CORE_TEXT_HINT)
        for lit in literals:
            if lit.start in approved or lit.start in flagged or not has_vietnamese(lit.content):
                continue
            report(lit.start, "plain-text", "Chuỗi tiếng Việt không qua catalog: chữ giao diện phải viết "
                   f'{HELPER}("…") hoặc Text("…", bundle: .module). Không phải chữ giao diện (log cho người phát '
                   f"triển) thì thêm `// {IGNORE_MARK}` trên dòng.")
    return problems


def source_targets(root: Path) -> list[tuple[Path, bool]]:
    """(thư mục, có kiểm chuỗi tiếng Việt trơn không) của mọi target được quét."""
    targets: list[tuple[Path, bool]] = []
    sources = root / SOURCES
    if sources.is_dir():
        for d in sorted(p for p in sources.iterdir() if p.is_dir()):
            targets.append((d, d.name not in PLAIN_STRING_TARGETS))
    for d in APP_DIRS:
        if (root / d).is_dir():
            targets.append((root / d, True))
    return targets


def check_sources(root: Path = ROOT) -> list[Problem]:
    problems: list[Problem] = []
    for directory, vietnamese in source_targets(root):
        for f in sorted(directory.rglob("*.swift")):
            path = str(f.relative_to(root))
            src = f.read_text(encoding="utf-8")
            problems += scan_source(path, src, vietnamese)
            problems += test_hook_problems(path, src)
    return problems


# Luật test-hook: chỗ ép ngôn ngữ chỉ cho test (`InterfaceStrings.languageOverride`, `.processLanguageOverride`; bước 7c)
# chỉ được đặt trong file khai báo nó; code của app (Sources, Apps) không được dùng (app luôn theo ngôn ngữ của macOS).
TEST_HOOK_FILE = "Packages/ExamFeatures/Sources/LibraryFeature/Localization/InterfaceStrings.swift"
TEST_HOOK_RE = re.compile(r"(?<![\w])\$?(languageOverride|processLanguageOverride)\b")


def test_hook_problems(path: str, src: str) -> list[Problem]:
    if Path(path).as_posix() == TEST_HOOK_FILE:
        return []
    code = code_mask(src)
    return [Problem(path, line_of(src, m.start()), "test-hook",
                    f"`{m.group(1)}` chỉ cho test (ép ngôn ngữ tra chữ): không dùng trong code của app; test dùng qua "
                    "`@testable import LibraryFeature`.")
            for m in TEST_HOOK_RE.finditer(code)]


# Luật scene-locale: mọi scene của hai shell gắn `.interfaceLocale()` (môi trường `\\.locale` theo ngôn ngữ giao diện),
# để số và ngày trong mọi cửa sổ, sheet, hộp thoại không theo Region (accessibility-localization.md, ghi chú bước 7a).
SHELL_TARGETS = ("StudentShell", "AdminShell")
SCENE_BODY_RE = re.compile(r"\bvar\s+body\s*:\s*some\s+(?:SwiftUI\.)?Scene\s*\{")
SCENE_LOCALE_MODIFIER = ".interfaceLocale("


def matching_brace(masked: str, open_brace: int) -> int:
    depth = 0
    for k in range(open_brace, len(masked)):
        if masked[k] in "([{":
            depth += 1
        elif masked[k] in ")]}":
            depth -= 1
            if depth == 0:
                return k
    return len(masked)


def scene_statements(masked: str, a: int, b: int) -> list[tuple[int, int]]:
    """Các biểu thức scene ở cấp ngoài cùng của `body` (masked[a:b]): mỗi biểu thức bắt đầu ở một dòng cấp 0 không mở
    đầu bằng `.`; dòng cấp 0 mở đầu bằng `.` (modifier) và dòng nằm trong ngoặc thuộc biểu thức đang mở."""
    statements: list[tuple[int, int]] = []
    depth, k, current = 0, a, None
    while k < b:
        line_end = masked.find("\n", k, b)
        line_end = b if line_end < 0 else line_end
        text = masked[k:line_end]
        stripped = text.strip()
        if depth == 0 and stripped and not stripped.startswith("."):
            if current is not None:
                statements.append((current, k))
            current = k + len(text) - len(text.lstrip())
        for c in text:
            if c in "([{":
                depth += 1
            elif c in ")]}":
                depth -= 1
        k = line_end + 1
    if current is not None:
        statements.append((current, b))
    return statements


def scene_locale_problems(path: str, src: str, composite: frozenset[str] = frozenset()) -> tuple[list[Problem], int]:
    """(lỗi, số `body` của Scene tìm được) của một file. `composite`: tên scene gộp khai báo trong shell (`struct …:
    Scene`, body của nó được kiểm riêng), dùng ở điểm vào của app không cần gắn lại."""
    masked, _ = lex(src)
    lines = src.splitlines()
    problems: list[Problem] = []
    bodies = 0
    for m in SCENE_BODY_RE.finditer(masked):
        bodies += 1
        close = matching_brace(masked, m.end() - 1)
        for a, b in scene_statements(masked, m.end(), close):
            depth, found = 0, False
            for k in range(a, b):
                c = masked[k]
                if depth == 0 and masked.startswith(SCENE_LOCALE_MODIFIER, k):
                    found = True
                    break
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
            line = line_of(src, a)
            head = re.match(r"[\w.]+", masked[a:b])
            if head is not None and head.group(0) in composite and "{" not in masked[a:b]:
                found = True
            if found or IGNORE_MARK in lines[line - 1]:
                continue
            problems.append(Problem(path, line, "scene-locale", f"Scene `{head.group(0) if head else '?'}` không gắn "
                                    "`.interfaceLocale()` ở cấp ngoài cùng: số, phần trăm, ngày giờ trong cửa sổ của nó "
                                    "sẽ theo Region của macOS thay vì ngôn ngữ giao diện (accessibility-localization.md, "
                                    "ghi chú bước 7a). Thêm `.interfaceLocale()` sau scene (như `.defaultAppStorage`)."))
    return problems, bodies


SCENE_TYPE_RE = re.compile(r"\bstruct\s+(\w+)\s*:[^{]*\bScene\b")


def composite_scenes(root: Path = ROOT) -> frozenset[str]:
    """Tên các scene gộp khai báo trong hai shell (`public struct StudentScenes: Scene`)."""
    names: set[str] = set()
    for target in SHELL_TARGETS:
        for f in sorted((root / SOURCES / target).rglob("*.swift")):
            names.update(SCENE_TYPE_RE.findall(lex(f.read_text(encoding="utf-8"))[0]))
    return frozenset(names)


def check_scene_locale(root: Path = ROOT) -> list[Problem]:
    """Hai shell, và điểm vào của hai app (Apps/Student, Apps/Admin, review #50 N3): scene của app hoặc là scene gộp của
    shell (đã kiểm) hoặc gắn `.interfaceLocale()`."""
    problems: list[Problem] = []
    composite = composite_scenes(root)
    for directory in [SOURCES / target for target in SHELL_TARGETS] + list(APP_DIRS):
        bodies = 0
        for f in sorted((root / directory).rglob("*.swift")):
            found, count = scene_locale_problems(str(f.relative_to(root)), f.read_text(encoding="utf-8"), composite)
            problems += found
            bodies += count
        if bodies == 0:
            problems.append(Problem(str(directory), 0, "scene-locale", "không tìm thấy `var body: some Scene` "
                                    "nào: shell hay app đổi chỗ khai báo scene thì sửa luật scene-locale trong "
                                    "check_localization.py cho đúng (không bỏ kiểm)."))
    return problems


# ---------------------------------------------------------------------------------------------------------------
# Catalog.

FORMAT_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDuUxXoOfeEgGcCsSpaAi]|%%")
# Token substitution của String Catalog: `%#@tên@` (hoặc `%2$#@tên@`); đối số và kiểu ở `substitutions[tên]`.
SUBSTITUTION_RE = re.compile(r"%(?:(\d+)\$)?#@([A-Za-z_][A-Za-z0-9_]*)@")


def argument_types(text: str, substitutions: dict | None = None) -> dict[int, str] | None:
    """Đối số (đánh số từ 1) → kiểu (`@`, `lld`…) của chuỗi định dạng; đặc tả không có số vị trí lấy số kế tiếp như
    printf. Token `%#@tên@` lấy đối số và kiểu từ `substitutions` (`argNum`, `formatSpecifier`). `None` khi chuỗi tự mâu
    thuẫn (một đối số hai kiểu, substitution không khai báo)."""
    types: dict[int, str] = {}
    following = 0
    blanked = SUBSTITUTION_RE.sub(lambda x: " " * len(x.group(0)), text)
    tokens = sorted([(m.start(), "sub", m) for m in SUBSTITUTION_RE.finditer(text)]
                    + [(m.start(), "fmt", m) for m in FORMAT_RE.finditer(blanked)], key=lambda t: t[0])
    for _, kind, m in tokens:
        if kind == "sub":
            sub = (substitutions or {}).get(m.group(2))
            if not isinstance(sub, dict) or "argNum" not in sub or "formatSpecifier" not in sub:
                return None
            index, kind_name = int(sub["argNum"]), str(sub["formatSpecifier"])
        else:
            spec = m.group(0)
            if spec == "%%":
                continue
            position = re.match(r"%(\d+)\$", spec)
            following += 1
            index = int(position.group(1)) if position else following
            kind_name = re.sub(r"^%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?", "", spec)
        if types.get(index, kind_name) != kind_name:
            return None
        types[index] = kind_name
    return types


def string_units(localization: dict) -> list[tuple[str, dict]]:
    """(đường dẫn biến thể, stringUnit) của một bản địa hoá, kể cả biến thể plural/thiết bị lồng nhau và biến thể của
    substitution (`sub.<tên>/plural.one`)."""
    units: list[tuple[str, dict]] = []
    if "stringUnit" in localization:
        units.append(("", localization["stringUnit"]))
    for kind, cases in localization.get("variations", {}).items():
        for case, sub in cases.items():
            units += [(f"{kind}.{case}" + (f"/{p}" if p else ""), u) for p, u in string_units(sub)]
    for name, sub in localization.get("substitutions", {}).items():
        units += [(f"sub.{name}" + (f"/{p}" if p else ""), u) for p, u in string_units(sub)]
    return units


def en_problems(source: str, localization: dict) -> list[str]:
    """Lỗi của bản `en` so với chuỗi nguồn `source` (giá trị vi, hoặc khoá): mỗi biến thể ở trạng thái `translated`;
    đối số (số vị trí và kiểu) của chuỗi chính (`stringUnit`, token substitution tính theo `argNum`/`formatSpecifier`)
    khớp nguồn, cho phép đổi thứ tự bằng số vị trí; biến thể plural (của khoá hay của substitution) đủ `one` và `other`,
    mỗi biến thể chỉ dùng đối số của nguồn (dạng `one` được bỏ số: "One question"); substitution chỉ dùng `%arg`."""
    out: list[str] = []
    units = string_units(localization)
    if not units:
        return ["chưa có bản en."]
    for variant, unit in units:
        if unit.get("state") != "translated":
            out.append(f"bản en {variant} ở trạng thái {unit.get('state')!r}, cần 'translated'.".replace("  ", " "))
    wanted = argument_types(source) or {}
    substitutions = localization.get("substitutions", {})
    if "stringUnit" in localization:
        got = argument_types(localization["stringUnit"].get("value", ""), substitutions)
        if got != wanted:
            out.append(f"đối số của en ({got}) khác nguồn ({wanted}): cùng số, cùng kiểu (đổi thứ tự bằng %1$@, %2$lld).")
        value = localization["stringUnit"].get("value", "")
        for name in substitutions:
            if not re.search(r"%(?:\d+\$)?#@" + re.escape(name) + "@", value):
                out.append(f"substitution {name!r} không có trong chuỗi en.")
        if substitutions and any(not re.match(r"%\d+\$", m.group(0)) and m.group(0) != "%%"
                                 for m in FORMAT_RE.finditer(SUBSTITUTION_RE.sub("", value))):
            out.append("chuỗi en có substitution thì mọi đặc tả khác phải có số vị trí (%2$@), không đếm theo thứ tự.")
    elif "variations" not in localization:
        out.append("bản en không có stringUnit hay variations.")

    def check_variations(path: str, holder: dict, allowed: dict[int, str], substitution: bool) -> None:
        for kind, cases in holder.get("variations", {}).items():
            if kind == "plural" and not {"one", "other"} <= set(cases):
                out.append(f"biến thể plural {path} thiếu {sorted({'one', 'other'} - set(cases))} (tiếng Anh cần one/other).")
            for case, sub in cases.items():
                value = sub.get("stringUnit", {}).get("value", "")
                if substitution:
                    extra = [m for m in FORMAT_RE.findall(value.replace("%arg", "")) if m != "%%"]
                    if extra:
                        out.append(f"biến thể {path}{kind}.{case} của substitution dùng {extra}: chỉ được dùng %arg.")
                    # Dạng `other` (mọi số khác 1) phải hiện số; chỉ `one` được bỏ ("One question").
                    if case == "other" and "%arg" not in value:
                        out.append(f"biến thể {path}{kind}.other của substitution không có %arg: số bị mất.")
                    continue
                got = argument_types(value)
                if got is None or any(allowed.get(i) != t for i, t in got.items()):
                    out.append(f"biến thể {path}{kind}.{case} dùng đối số {got}, nguồn có {allowed}.")
                elif case == "other" and got != allowed:
                    out.append(f"biến thể {path}{kind}.other thiếu đối số của nguồn ({got}, nguồn có {allowed}): "
                               "chỉ dạng one được bỏ số.")

    check_variations("", localization, wanted, substitution=False)
    for name, sub in substitutions.items():
        check_variations(f"sub.{name}/", sub, wanted, substitution=True)
    return out


def catalog_problems(path: str, raw: str, require_en: bool) -> list[Problem]:
    def problem(key: str, message: str) -> Problem:
        return Problem(path, 0, "catalog", f"khoá {json.dumps(key, ensure_ascii=False)}: {message}")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        return [Problem(path, e.lineno, "catalog", f"JSON hỏng: {e.msg}")]
    problems: list[Problem] = []
    if data.get("sourceLanguage") != "vi":
        problems.append(Problem(path, 0, "catalog", f"sourceLanguage là {data.get('sourceLanguage')!r}, phải là 'vi' "
                                "(tiếng Việt là ngôn ngữ nguồn, accessibility-localization.md)."))
    strings = data.get("strings")
    if not isinstance(strings, dict):
        return problems + [Problem(path, 0, "catalog", "thiếu mục `strings`.")]
    info_plist = Path(path).name == "InfoPlist.xcstrings"
    for key, entry in strings.items():
        if not key.strip():
            problems.append(problem(key, "khoá rỗng."))
        if entry.get("extractionState") == "stale":
            problems.append(problem(key, "trạng thái stale (không còn trong code): xoá khỏi catalog."))
        localizations = entry.get("localizations", {})
        translate = entry.get("shouldTranslate", True)
        vi_units = string_units(localizations.get("vi", {}))
        if info_plist and not vi_units:
            problems.append(problem(key, "InfoPlist.xcstrings cần giá trị `vi` tường minh (khoá là tên khoá Info.plist)."))
        for variant, unit in vi_units:
            if not unit.get("value", "").strip():
                problems.append(problem(key, f"giá trị vi {variant} rỗng.".replace("  ", " ")))
        for language, localization in localizations.items():
            if language == "vi":
                continue
            for variant, unit in string_units(localization):
                if not unit.get("value", ""):
                    problems.append(problem(key, f"bản {language} {variant} rỗng: catalog biên dịch chữ rỗng thì giao "
                                            "diện hiện chữ rỗng; xoá mục đó hoặc điền bản dịch.".replace("  ", " ")))
        if require_en and translate:
            source = vi_units[0][1].get("value", key) if vi_units else key
            problems += [problem(key, message) for message in en_problems(source, localizations.get("en", {}))]
    return problems


def catalog_files(root: Path = ROOT) -> list[Path]:
    files = sorted((root / SOURCES).rglob("*.xcstrings")) if (root / SOURCES).is_dir() else []
    for d in APP_DIRS:
        files += sorted((root / d).rglob("*.xcstrings")) if (root / d).is_dir() else []
    return files


def check_catalogs(require_en: bool, root: Path = ROOT) -> list[Problem]:
    problems: list[Problem] = []
    for f in catalog_files(root):
        problems += catalog_problems(str(f.relative_to(root)), f.read_text(encoding="utf-8"), require_en)
    return problems


# ---------------------------------------------------------------------------------------------------------------
# Catalog đủ khoá: so với .stringsdata của lần build gần nhất.


def catalog_diff(old: dict, new: dict) -> list[str]:
    """Khác biệt về khoá/trạng thái giữa catalog đã commit (`old`) và bản đã đồng bộ (`new`)."""
    out: list[str] = []
    a, b = old.get("strings", {}), new.get("strings", {})
    for key in sorted(set(b) - set(a)):
        out.append(f"khoá mới chưa vào catalog: {json.dumps(key, ensure_ascii=False)}")
    for key in sorted(set(a) - set(b)):
        out.append(f"khoá bị bỏ khi đồng bộ: {json.dumps(key, ensure_ascii=False)}")
    for key in sorted(set(a) & set(b)):
        if a[key] != b[key]:
            before = a[key].get("extractionState", "-")
            after = b[key].get("extractionState", "-")
            out.append(f"khoá đổi khi đồng bộ ({before} → {after}): {json.dumps(key, ensure_ascii=False)}")
    if old.get("sourceLanguage") != new.get("sourceLanguage"):
        out.append("sourceLanguage đổi khi đồng bộ")
    return out


def stringsdata_for(build_dir: Path, target: str, sources: Path) -> list[Path]:
    """`.stringsdata` của target: nằm dưới thư mục `<target>.build` (hệ build native) hoặc `<target>-<hậu tố>.build`
    (swiftbuild: `-t`), không phụ thuộc tên cấu hình hay bố cục bên trên. Chỉ lấy file của nguồn Swift còn trong
    `sources` (build incremental để lại file của nguồn đã xoá), và với mỗi nguồn chỉ lấy bản mới nhất (thư mục build
    có thể còn bản của cấu hình hay lần build khác)."""
    stems = {f.stem for f in sources.rglob("*.swift")}
    folder = re.compile(rf"^{re.escape(target)}(-[A-Za-z0-9]+)?\.build$")
    newest: dict[str, Path] = {}
    for p in build_dir.rglob("*.stringsdata"):
        if p.stem not in stems or not any(folder.match(part) for part in p.relative_to(build_dir).parts[:-1]):
            continue
        if p.stem not in newest or p.stat().st_mtime > newest[p.stem].stat().st_mtime:
            newest[p.stem] = p
    return sorted(newest.values())


def check_freshness(build_dir: Path, allow_missing: bool = False, root: Path = ROOT) -> list[Problem] | None:
    """Lỗi về khoá chưa đồng bộ. Thư mục build không có thì luôn thất bại; không có `.stringsdata` nào thì thất bại,
    trừ khi `allow_missing` (khi đó trả `None`: bỏ qua, có ghi chú)."""
    if not build_dir.is_dir():
        return [Problem(str(build_dir), 0, "freshness", "không có thư mục build (gõ sai đường dẫn, hoặc chưa chạy "
                        "swift build/swift test của Packages/ExamFeatures).")]
    if shutil.which("xcrun") is None:
        return [Problem(str(build_dir), 0, "freshness", "cần xcrun xcstringstool (macOS có Xcode).")]
    problems: list[Problem] = []
    catalogs = sorted((root / SOURCES).rglob("Localizable.xcstrings"))
    if catalogs and not any(stringsdata_for(build_dir, c.relative_to(root / SOURCES).parts[0],
                                            root / SOURCES / c.relative_to(root / SOURCES).parts[0]) for c in catalogs):
        # Hệ build cũ của SwiftPM (`--build-system native`) không ghi .stringsdata. Chỉ bỏ qua khi người gọi nói rõ
        # (`--allow-missing-stringsdata`); bằng chứng merge vẫn có `xcodebuild -exportLocalizations` của verify_local.sh.
        if allow_missing:
            print(f"note BỎ QUA kiểm catalog đủ khoá: không có .stringsdata trong {build_dir} (hệ build không ghi); "
                  "scripts/verify_local.sh kiểm bằng xcodebuild -exportLocalizations.")
            return None
        return [Problem(str(build_dir), 0, "freshness", "không có .stringsdata của target nào: hệ build không ghi "
                        "(SwiftPM `--build-system native`) hoặc sai thư mục. Chạy swift test của Packages/ExamFeatures "
                        "với hệ build mặc định, hoặc truyền --allow-missing-stringsdata nếu biết chắc hệ build không "
                        "ghi (verify_local.sh vẫn kiểm bằng -exportLocalizations).")]
    for catalog in catalogs:
        target = catalog.relative_to(root / SOURCES).parts[0]
        rel = str(catalog.relative_to(root))
        data = stringsdata_for(build_dir, target, root / SOURCES / target)
        if not data:
            problems.append(Problem(rel, 0, "freshness", f"không thấy .stringsdata của {target} trong {build_dir}: "
                                    "chạy swift build/swift test của Packages/ExamFeatures trước."))
            continue
        with tempfile.TemporaryDirectory(prefix="check-l10n-") as tmp:
            copy = Path(tmp) / "Localizable.xcstrings"
            shutil.copyfile(catalog, copy)
            cmd = ["xcrun", "xcstringstool", "sync", str(copy)]
            for d in data:
                cmd += ["--stringsdata", str(d)]
            run = subprocess.run(cmd, capture_output=True, text=True)
            if run.returncode != 0:
                problems.append(Problem(rel, 0, "freshness", f"xcstringstool sync lỗi: {run.stderr.strip()}"))
                continue
            synced = json.loads(copy.read_text(encoding="utf-8"))
        for line in catalog_diff(json.loads(catalog.read_text(encoding="utf-8")), synced):
            problems.append(Problem(rel, 0, "freshness", line + " (cập nhật catalog: xem AGENTS.md, lệnh đồng bộ)."))
    return problems


# ---------------------------------------------------------------------------------------------------------------
# App đã build: bundle chính có vi và en, chuỗi Info.plist tra được, bundle catalog của package đúng ngôn ngữ nguồn.

# App → (InfoPlist.xcstrings nguồn, target có catalog mà app phải mang bundle tài nguyên).
BUILT_APPS = {
    "Exam Suite.app": ("Apps/Student/InfoPlist.xcstrings", ("LibraryFeature", "SessionFeature", "ReportFeature")),
    "Exam Suite Admin.app": (
        "Apps/Admin/InfoPlist.xcstrings",
        ("LibraryFeature", "SessionFeature", "ReportFeature", "AuthoringFeature", "AdminShell"),
    ),
}
APP_LANGUAGES = ("vi", "en")


def read_plist(path: Path) -> dict:
    """Plist XML/nhị phân, kể cả `.strings` do xcstringstool biên dịch (XML UTF-16 có BOM)."""
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        text = raw.decode("utf-16")
        raw = re.sub(r'encoding="[^"]*"', 'encoding="UTF-8"', text, count=1).encode("utf-8")
    return plistlib.loads(raw)


# Khoá Info.plist là tên app: không dịch (accessibility-localization.md, bảng "Dịch gì").
APP_NAME_KEYS = ("CFBundleName", "CFBundleDisplayName")


def catalog_value(catalog: dict, key: str, language: str) -> str | None:
    unit = catalog.get("strings", {}).get(key, {}).get("localizations", {}).get(language, {}).get("stringUnit", {})
    return unit.get("value")


def lproj_languages(bundle: Path) -> set[str]:
    """Ngôn ngữ có chữ đã biên dịch trong bundle: các `*.lproj` (ở `Contents/Resources`) có `.strings`/`.stringsdict`."""
    resources = bundle / "Contents/Resources"
    if not resources.is_dir():
        return set()
    return {d.stem for d in resources.glob("*.lproj")
            if any(f.suffix in (".strings", ".stringsdict") for f in d.iterdir())}


def built_app_problems(app: Path, catalog: dict, targets: tuple[str, ...], require_en: bool) -> list[Problem]:
    """Bundle chính có `vi.lproj` và `en.lproj` (package đi theo ngôn ngữ bundle chính chọn: thiếu một trong hai thì
    cả app kẹt một ngôn ngữ, spike giai đoạn 5); `CFBundleDevelopmentRegion` là vi; mỗi khoá của InfoPlist.xcstrings
    tra được ở cả hai ngôn ngữ, khác rỗng, và bằng đúng giá trị của catalog cho ngôn ngữ đó (không có bản của ngôn ngữ
    đó thì bằng giá trị gốc của Info.plist, hoặc chính khoá khi khoá là giá trị như tên kiểu tài liệu); tên app
    (`CFBundleName`, `CFBundleDisplayName`) bằng giá trị gốc ở mọi ngôn ngữ (không dịch). Chưa đòi en thì bản en còn
    phải bằng giá trị gốc (trước bước 7c không đổi chữ người dùng thấy).

    Bundle tài nguyên của mỗi target có catalog nằm trong app, ngôn ngữ nguồn vi, và **mọi bundle có chữ đã biên dịch
    có cùng tập `*.lproj`** (review độc lập #50 N2): `InterfaceLocale` chọn ngôn ngữ định dạng theo `*.lproj` của bundle
    LibraryFeature, nên bundle nào thiếu một ngôn ngữ sẽ ra chữ ngôn ngữ nguồn cạnh số/ngày của ngôn ngữ kia. Đòi en thì
    tập đó phải có en."""
    name = app.name
    problems: list[Problem] = []

    def problem(message: str) -> None:
        problems.append(Problem(name, 0, "built-app", message))

    try:
        info = read_plist(app / "Contents/Info.plist")
    except (OSError, plistlib.InvalidFileException, ValueError) as e:
        return [Problem(name, 0, "built-app", f"không đọc được Info.plist: {e}")]
    if info.get("CFBundleDevelopmentRegion") != "vi":
        problem(f"CFBundleDevelopmentRegion là {info.get('CFBundleDevelopmentRegion')!r}, phải là 'vi' (project.yml).")
    resources = app / "Contents/Resources"
    for language in APP_LANGUAGES:
        strings_file = resources / f"{language}.lproj/InfoPlist.strings"
        if not strings_file.is_file():
            problem(f"thiếu {language}.lproj/InfoPlist.strings: app phải có cả vi và en ở bundle chính "
                    "(InfoPlist.xcstrings, project.yml).")
            continue
        try:
            table = read_plist(strings_file)
        except (OSError, plistlib.InvalidFileException, ValueError) as e:
            problem(f"không đọc được {language}.lproj/InfoPlist.strings: {e}")
            continue
        for key in catalog.get("strings", {}):
            value = table.get(key)
            if not value:
                problem(f"{language}.lproj/InfoPlist.strings không có giá trị cho {key!r}.")
                continue
            base = info.get(key, key)
            expected = catalog_value(catalog, key, language) or base
            if language == "en" and not require_en:
                expected = base
            if key in APP_NAME_KEYS and value != base:
                problem(f"{language}.lproj: {key!r} = {value!r}: tên app không dịch, phải bằng giá trị gốc {base!r} "
                        "(project.yml).")
            elif value != expected:
                problem(f"{language}.lproj: {key!r} = {value!r}, khác {expected!r} của InfoPlist.xcstrings (build lại "
                        "sau khi sửa catalog; trước bước 7c bản en phải bằng giá trị gốc).")
    reference: set[str] | None = None
    for target in targets:
        bundle = resources / f"ExamFeatures_{target}.bundle"
        try:
            region = read_plist(bundle / "Contents/Info.plist").get("CFBundleDevelopmentRegion")
        except (OSError, plistlib.InvalidFileException, ValueError):
            problem(f"thiếu bundle tài nguyên ExamFeatures_{target}.bundle (catalog của {target}).")
            continue
        if region != "vi":
            problem(f"ExamFeatures_{target}.bundle có CFBundleDevelopmentRegion {region!r}, phải là 'vi' "
                    "(Package.swift defaultLocalization).")
        languages = lproj_languages(bundle)
        if reference is None:
            reference = languages
            if require_en and "en" not in languages:
                problem(f"ExamFeatures_{target}.bundle không có en.lproj: catalog của {target} chưa có bản en được "
                        "biên dịch (InterfaceLocale chọn ngôn ngữ theo bundle này).")
        elif languages != reference:
            problem(f"ExamFeatures_{target}.bundle có ngôn ngữ {sorted(languages)}, khác {sorted(reference)} của "
                    f"ExamFeatures_{targets[0]}.bundle: mọi catalog phải có cùng các ngôn ngữ (review #50 N2), nếu không "
                    "giao diện ra chữ ngôn ngữ nguồn cạnh số/ngày của ngôn ngữ kia.")
    return problems


def check_built_apps(products: Path, require_en: bool, root: Path = ROOT) -> list[Problem]:
    problems: list[Problem] = []
    for app_name, (catalog_path, targets) in BUILT_APPS.items():
        app = products / app_name
        if not app.is_dir():
            problems.append(Problem(app_name, 0, "built-app", f"không thấy {app} (build hai scheme trước)."))
            continue
        catalog = json.loads((root / catalog_path).read_text(encoding="utf-8"))
        problems += built_app_problems(app, catalog, targets, require_en)
        problems += unlisted_bundles(app, targets)
    return problems


def unlisted_bundles(app: Path, targets: tuple[str, ...]) -> list[Problem]:
    """Bundle tài nguyên có chữ đã biên dịch mà không có trong `BUILT_APPS`: phép so `*.lproj` ở trên sẽ bỏ sót nó."""
    out: list[Problem] = []
    for bundle in sorted((app / "Contents/Resources").glob("ExamFeatures_*.bundle")):
        target = bundle.stem.removeprefix("ExamFeatures_")
        if target not in targets and lproj_languages(bundle):
            out.append(Problem(app.name, 0, "built-app", f"{bundle.name} có chữ đã biên dịch nhưng {target} không có "
                               "trong BUILT_APPS của scripts/check_localization.py: thêm vào danh sách của app."))
    return out


def built_app_self_test() -> list[str]:
    """Đối chứng trên app giả trong thư mục tạm."""
    failures: list[str] = []

    def entry(vi: str, en: str) -> dict:
        return {"localizations": {language: {"stringUnit": {"state": "translated", "value": value}}
                                  for language, value in (("vi", vi), ("en", en))}}

    catalog = {"strings": {"CFBundleName": entry("Exam Suite", "Exam Suite"),
                           "Exam Suite Exam": entry("Đề Exam Suite", "Exam Suite Exam")}}
    renamed = {"strings": {**catalog["strings"], "CFBundleName": entry("Exam Suite", "Suite")}}
    info = {"CFBundleDevelopmentRegion": "vi", "CFBundleName": "Exam Suite"}
    vi = {"CFBundleName": "Exam Suite", "Exam Suite Exam": "Đề Exam Suite"}
    en = {"CFBundleName": "Exam Suite", "Exam Suite Exam": "Exam Suite Exam"}
    english = {"LibraryFeature": ["en"], "SessionFeature": ["en"]}

    def build(tmp: Path, info: dict, tables: dict[str, dict], bundles: dict[str, list[str]] | None,
              region: str = "vi", utf16: bool = True) -> Path:
        app = tmp / f"App{len(list(tmp.iterdir()))}.app"
        (app / "Contents/Resources").mkdir(parents=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        for language, values in tables.items():
            folder = app / f"Contents/Resources/{language}.lproj"
            folder.mkdir()
            data = plistlib.dumps(values)
            if utf16:
                data = b"\xff\xfe" + data.decode("utf-8").replace('encoding="UTF-8"', 'encoding="UTF-16"').encode("utf-16-le")
            (folder / "InfoPlist.strings").write_bytes(data)
        for target, lprojs in (bundles or {}).items():
            contents = app / f"Contents/Resources/ExamFeatures_{target}.bundle/Contents"
            contents.mkdir(parents=True)
            (contents / "Info.plist").write_bytes(plistlib.dumps({"CFBundleDevelopmentRegion": region}))
            for language in lprojs:
                folder = contents / f"Resources/{language}.lproj"
                folder.mkdir(parents=True)
                (folder / "Localizable.stringsdict").write_bytes(plistlib.dumps({}))
        return app

    targets = ("LibraryFeature", "SessionFeature")
    # (tên, Info.plist, bảng InfoPlist.strings, bundle → *.lproj, require_en, số lỗi cần, catalog)
    cases = [
        ("app đúng", info, {"vi": vi, "en": en}, english, True, 0, catalog),
        ("app đúng (plist UTF-8)", info, {"vi": vi, "en": en}, english, True, 0, catalog),
        ("chưa đòi en: en bằng gốc, bundle chưa có en", info, {"vi": vi, "en": en}, {t: [] for t in targets}, False, 0,
         catalog),
        ("thiếu en.lproj", info, {"vi": vi}, english, True, 1, catalog),
        ("thiếu vi.lproj", info, {"en": en}, english, True, 1, catalog),
        ("vùng phát triển en", {**info, "CFBundleDevelopmentRegion": "en"}, {"vi": vi, "en": en}, english, True, 1,
         catalog),
        ("vi không theo catalog (tên kiểu tài liệu chưa dịch)", info, {"vi": en, "en": en}, english, True, 1, catalog),
        ("en không theo catalog", info, {"vi": vi, "en": {**en, "Exam Suite Exam": "Exam"}}, english, True, 1, catalog),
        ("en đổi chữ khi chưa đòi en", info, {"vi": vi, "en": {**en, "Exam Suite Exam": "Exam"}},
         {t: [] for t in targets}, False, 1, catalog),
        ("tên app bị dịch", info, {"vi": vi, "en": {**en, "CFBundleName": "Suite"}}, english, True, 1, renamed),
        ("thiếu khoá", info, {"vi": {"CFBundleName": "Exam Suite"}, "en": en}, english, True, 1, catalog),
        ("thiếu bundle catalog", info, {"vi": vi, "en": en}, {"LibraryFeature": ["en"]}, True, 1, catalog),
        ("bundle catalog vùng en", info, {"vi": vi, "en": en}, english, True, 2, catalog),
        # Review #50 N2: mọi bundle có chữ cùng tập *.lproj; đòi en thì bundle LibraryFeature có en.
        ("N2: SessionFeature thiếu en.lproj", info, {"vi": vi, "en": en},
         {"LibraryFeature": ["en"], "SessionFeature": []}, True, 1, catalog),
        ("N2: SessionFeature thừa fr.lproj", info, {"vi": vi, "en": en},
         {"LibraryFeature": ["en"], "SessionFeature": ["en", "fr"]}, True, 1, catalog),
        ("N2: LibraryFeature chưa có en khi đòi en", info, {"vi": vi, "en": en},
         {t: [] for t in targets}, True, 1, catalog),
    ]
    with tempfile.TemporaryDirectory(prefix="check-l10n-app-") as tmp:
        for i, (name, plist, tables, bundles, require_en, expected, cat) in enumerate(cases):
            region = "en" if name == "bundle catalog vùng en" else "vi"
            app = build(Path(tmp), plist, tables, bundles, region=region, utf16=(i != 1))
            got = built_app_problems(app, cat, targets, require_en)
            if len(got) != expected:
                kind = "dương" if expected == 0 else "âm"
                failures.append(f"đối chứng {kind} app '{name}': cần {expected} lỗi, được {[str(p) for p in got]}")
        # Bundle có chữ mà không có trong BUILT_APPS.
        app = build(Path(tmp), info, {"vi": vi, "en": en}, {**english, "NewFeature": ["en"]})
        if len(unlisted_bundles(app, targets)) != 1 or unlisted_bundles(app, (*targets, "NewFeature")):
            failures.append("đối chứng bundle ngoài BUILT_APPS không đúng")
    return failures


# ---------------------------------------------------------------------------------------------------------------
# Đối chứng.


def self_test() -> list[str]:
    failures: list[str] = []

    def expect(name: str, problems: list[Problem], rule: str | None, count: int = 1) -> None:
        got = [p for p in problems if rule is None or p.rule == rule]
        if rule is None and problems:
            failures.append(f"đối chứng dương '{name}' bị báo sai: {[str(p) for p in problems]}")
        elif rule is not None and len(got) != count:
            failures.append(f"đối chứng âm '{name}': cần {count} lỗi [{rule}], được {[str(p) for p in problems]}")

    def scan(code: str, vietnamese: bool = True) -> list[Problem]:
        return scan_source("X.swift", code, vietnamese)

    # Đối chứng dương: dạng đúng của mọi API.
    good = '''
        Text("Thư viện", bundle: .module)
        Text("Câu \\(n) trên \\(total)", tableName: nil, bundle: .module, comment: "đầu câu")
        Text(verbatim: "·")
        Text(title)
        let s = String(localized: "Đã nộp", bundle: .module)
        let r = LocalizedStringResource("Lưu", bundle: .module)
        Button(localized("Huỷ"), role: .cancel) { }
        Label(localized("Đề mới"), systemImage: "plus")
        Toggle(localized("Trộn câu"), isOn: $shuffle)
        Section(localized("Phần \\(i)")) { }
        TextField(localized("Tiêu đề"), text: $title, prompt: Text("Nhập", bundle: .module))
        Button { } label: { Text("Mở", bundle: .module) }
        view.help(localized("Đóng")).accessibilityLabel(localized("Ảnh của câu hỏi"))
        view.searchable(text: $q, prompt: localized("Tìm"))
        view.accessibilityAction(named: localized("Xoá")) { }
        view.accessibilityIdentifier("library.grid")
        print("Đường dẫn: \\(path)") // l10n-ignore
        // Text("Trong comment") Button("Không tính")
        /* Label("Không tính", systemImage: "x") /* lồng */ .help("x") */
        let url = #"C:\\"Đường dẫn" \\#(x)"# // l10n-ignore
        let id = "row-\\(index)"
        Text(isOn ? "Hiện" : "Ẩn", bundle: .module)
        Button(isOn ? localized("Hiện") : localized("Ẩn")) { }
        Label(isOn ? localized("Hiện") : localized("Ẩn"), systemImage: "eye")
        view.help(isOn ? Text("Hiện", bundle: .module) : Text("Ẩn", bundle: .module))
        Text(name ?? "")
        Text(first + " · " + last)
        Text(items.joined(separator: ", "))
        alert.messageText = localized("Xoá đề?")
        alert.addButton(withTitle: localized("OK"))
        panel.prompt = isExport ? localized("Xuất") : localized("Chọn")
        window.title = model.title
    '''
    expect("dạng đúng", scan(good), None)
    expect("chuỗi nhiều dòng đúng", scan('let m = String(localized: """\n    Đề "đã lưu" \\(x)\n    """, bundle: .module)\n'),
           None)
    # Đối chứng âm: mỗi dòng một lỗi.
    bad_bundle = (
        'Text("Thư viện")', 'Text("Câu \\(n)", comment: "x")', 'SwiftUI.Text("Lưu")',
        'let s = String(localized: "Đã nộp")', 'let s = String(localized: key)',
        'let r = LocalizedStringResource("Lưu")', 'let a = AttributedString(localized: "**Đậm**")',
        'let m = String(localized: """\n  Đề\n  """)',
        # Biểu thức (nhánh ?:, phép +) và bundle khác `.module` (review #44, điểm 1).
        'Text(isOn ? "Show" : "Hide")', 'Text("Exam " + name)', 'Text("Thư viện", bundle: .main)',
        'Text("Thư viện", bundle: nil)', 'Text("Lưu", bundle: Bundle(for: X.self))',
        'let s = String(localized: "Đã nộp", bundle: .main)', 'let r = LocalizedStringResource("Lưu", bundle: .main)',
    )
    for code in bad_bundle:
        expect(code, scan(code + "\n", vietnamese=False), "bundle")
    bad_key = (
        'Button("Huỷ") { }', 'Button("Huỷ", role: .cancel) { }', 'Label("Đề mới", systemImage: "plus")',
        'Toggle("Trộn", isOn: $b)', 'Picker("Chế độ", selection: $m) { }', 'Section("Phần") { }',
        'TextField("Tiêu đề", text: $t)', 'Menu("Mở gần đây") { }', 'LabeledContent("Mã", value: code)',
        'Stepper("Số câu", value: $n)', 'ContentUnavailableView("Trống", systemImage: "tray")',
        'v.help("Đóng")', 'v.accessibilityLabel("Ảnh")', 'v.accessibilityHint("Mở")', 'v.navigationTitle("Thư viện")',
        'v.alert("Lỗi", isPresented: $p) { }', 'v.confirmationDialog("Xoá?", isPresented: $p) { }',
        'v.searchable(text: $q, prompt: "Tìm")', 'v.accessibilityAction(named: "Xoá") { }',
        'Window("Import đề", id: "import") { }', 'CommandMenu("Bài thi") { }',
        'Button("Mở", systemImage: "folder") { }',
        # Nhánh ?: và phép + (String trơn, không qua catalog), kể cả chữ ASCII (review #44, điểm 1).
        'Button(isOn ? "Show" : "Hide") { }', 'v.help(isOn ? "A" : "B")', 'v.navigationTitle(isOn ? "Library" : "History")',
        'Label(isOn ? "Show" : "Hide", systemImage: "eye")', 'v.accessibilityValue(isOn ? "On" : "Off")',
        'Button("Exam " + name) { }', 'v.help(name ?? "None")',
        # Thuộc tính chữ của AppKit và nút của NSAlert, kể cả chữ ASCII.
        'alert.messageText = "Delete exam?"', 'panel.prompt = "Export"', 'alert.informativeText = ok ? "Done" : "Failed"',
        'alert.addButton(withTitle: "OK")', 'panel.nameFieldLabel = "Save as:"',
    )
    for code in bad_key:
        expect(code, scan(code + "\n", vietnamese=False), "key-only")
    if len(scan('Text("Thư viện")\n')) != 1:
        failures.append("đối chứng: một literal quên bundle phải báo đúng một lỗi (không báo trùng ở plain-text)")
    expect("LocalizedStringKey", scan("let title: LocalizedStringKey\n", vietnamese=False), "key-type")
    expect("LocalizedStringKey(…)", scan('let k = LocalizedStringKey("Lưu")\n', vietnamese=False), "key-type")
    # Chữ tiếng Việt trơn (tên biến, gán, tham số tự định nghĩa, nội suy lồng, NSAlert, verbatim).
    bad_plain = (
        'let title = "Thư viện"', 'Row(title: "Đã làm")',
        'Text(verbatim: "Đáp án")', 'let s = localized("Câu \\(x ? "đúng" : "sai")")',
        'let raw = #"Đường dẫn"#', 'let m = """\n  Ghi chú\n  Đề\n  """',
    )
    for code in bad_plain:
        expect(code, scan(code + "\n"), "plain-text")
    expect("chữ tiếng Việt ở target chuỗi trơn", scan('let m = "Không đọc được"\n', vietnamese=False), None)
    expect("chữ không dấu", scan('let m = "Exam Suite"\n'), None)
    expect("so sánh thuộc tính, không gán", scan('if alert.messageText == "OK" { }\n'), None)
    expect("literal không chữ cái trong biểu thức", scan('Text(count > 0 ? "\\(count)" : "—")\n'), None)
    expect("l10n-ignore", scan('log("Không mở được") // l10n-ignore\n'), None)
    expect("comment nhiều dòng", scan('/*\n Text("Thư viện")\n Button("Huỷ") { }\n*/\n'), None)

    # Luật region-locale (bước 7a): dạng đúng không bị báo; mỗi dạng theo Region một lỗi.
    good_locale = '''
        let s = n.formatted(.number.locale(InterfaceLocale.current))
        let d = date.formatted(Date.FormatStyle(date: .numeric, locale: locale, calendar: calendar, timeZone: timeZone))
        let iso = now.formatted(.iso8601)
        let isoDay = now.formatted(.iso8601.year().month().day())
        let s = localized("Câu \\(InterfaceLocale.number(n)) lúc \\(SessionFormat.dateTime(d))")
        let id = "row-\\(index)"
        let b = bytes.formatted(ByteCountFormatStyle(style: .file, locale: locale))
        let i = now.formatted(style)
        let iso = Date.ISO8601FormatStyle(timeZone: .gmt)
        func f(locale: Locale = InterfaceLocale.current, timeZone: TimeZone = .autoupdatingCurrent) { }
        Text(n, format: .number)
        TextField(localized("Số"), value: $n, format: .number.locale(locale))
        let st = IntegerFormatStyle<Int>().locale(locale)
        let h = String(format: "%02x", locale: Locale(identifier: "en_US_POSIX"), byte)
        let f = DateFormatter() // l10n-ignore: tên file, en_US_POSIX
        // Locale.current trong comment
        let m = "Locale.current trong chuỗi"
        let c = Calendar.current
    '''
    expect("định dạng theo ngôn ngữ giao diện", scan(good_locale, vietnamese=False), None)
    bad_locale = (
        "let l = Locale.current", "let l = Locale.autoupdatingCurrent", "let l = NSLocale.current",
        "func f(locale: Locale = .autoupdatingCurrent) { }", "f(locale: .current)", "var l: Locale = .current",
        "formatter.locale = .current", "let s = n.formatted(.number.locale(.current))",
        "let s = n.formatted()", "let s = n.formatted(.number)", "let s = x.formatted(.percent.precision(.fractionLength(1)))",
        "let s = d.formatted(.dateTime.day().month())", "let s = d.formatted(Date.FormatStyle(date: .numeric))",
        "let st = ByteCountFormatStyle(style: .file)", "let f = DateFormatter()", "let f = NumberFormatter()",
        'let s = String(format: "%d", n)', 'let s = String.localizedStringWithFormat("%d", n)',
        # Review độc lập #50: nhãn date:/time:, mã trong nội suy, hàm tĩnh của Formatter, lịch của Date.FormatStyle.
        "let s = d.formatted(date: .numeric, time: .shortened)", "let s = d.formatted(time: .shortened)",
        'let s = localized("Nộp lúc \\(d.formatted())")', 'Text("Câu \\(n.formatted(.number))", bundle: .module)',
        'let s = "\\(Locale.current.identifier)"', 'let s = "a \\("b \\(n.formatted())")"',
        "let s = DateFormatter.localizedString(from: d, dateStyle: .short, timeStyle: .short)",
        "let s = NumberFormatter.localizedString(from: n, number: .decimal)",
        "let s = ByteCountFormatter.string(fromByteCount: b, countStyle: .file)",
        "let s = ListFormatter.localizedString(byJoining: items)",
        "let st = Date.FormatStyle(date: .numeric, locale: locale, timeZone: tz)",
    )
    for code in bad_locale:
        expect(code, scan(code + "\n", vietnamese=False), "region-locale")

    # Review #50 N4: bộ tách mã (`code_mask`) với chuỗi raw và chuỗi nhiều dòng. Nội suy của chuỗi raw là `\#(…)`; trong
    # chuỗi raw `\(…)` chỉ là chữ. Chuỗi nhiều dòng giữ nội suy như chuỗi thường.
    raw_mask = code_mask('let s = #"a \\(x.y) b \\#(m.n) c"#\n')
    if "m.n" not in raw_mask or "x.y" in raw_mask or "a" in raw_mask.split("=", 1)[1]:
        failures.append(f"code_mask chuỗi raw: phải giữ mã trong \\#(…), che chữ kể cả \\(…), được {raw_mask!r}")
    multi_mask = code_mask('let s = """\n  Nộp \\(d.formatted())\n  Locale.current\n  """\n')
    if "d.formatted()" not in multi_mask or "Locale.current" in multi_mask:
        failures.append(f"code_mask chuỗi nhiều dòng: phải giữ mã nội suy, che chữ, được {multi_mask!r}")
    bad_masked = (
        'let s = localized(#"Nộp lúc \\#(d.formatted())"#)',
        'let s = #"""\n  Lúc \\#(Locale.current.identifier)\n  """#',
        'let s = """\n  Nộp lúc \\(d.formatted())\n  """',
        'let s = """\n  Câu \\(n)\n  Ngày \\(d.formatted(date: .numeric, time: .omitted))\n  """',
    )
    for code in bad_masked:
        expect(code, scan(code + "\n", vietnamese=False), "region-locale")
    good_masked = (
        'let s = #"Mẫu \\(d.formatted()) trong chữ"#',
        'let s = """\n  Locale.current trong chữ\n  n.formatted()\n  """',
        'let s = #"""\n  \\(Locale.current)\n  """#',
    )
    for code in good_masked:
        expect(code, scan(code + "\n", vietnamese=False), None)

    # Luật core-text (bước 7b): câu tiếng Việt của lõi/target dữ liệu không lên giao diện ở target có chữ giao diện.
    good_core = '''
        Text(ErrorMessages.message(for: issue))
        alert.message = AuthoringMessages.message(for: error)
        let m = notice.message + failure.message + banner.message
        let p = PreExamIssue.practiceUnavailable.message
        public var errorDescription: String? { localized("Không đọc được file ảnh.") }
        // issue.message, error.localizedDescription trong comment
        let s = "issue.message, .logMessage in a string"
        let d = ErrorMessages.systemDescription(of: error) // l10n-ignore: câu của hệ thống
        log.error("\\(entry.logMessage, privacy: .public)") // l10n-ignore: nhật ký
        let m = issues.first.map { ErrorMessages.message(for: $0) } ?? ""
        Text(AuthoringMessages.message(for: issue.detail))
        func describe(_ v: ValidationIssue) -> String { ErrorMessages.message(for: v) }
        let blockers = model.issues
        let reasons = blockers.map(\\.message)
        let first = fields.map { name($0) }
    '''
    expect("dựng câu theo mã", scan(good_core), None)
    bad_core = (
        "Text(error.localizedDescription)",
        "let m = (error as? LocalizedError)?.errorDescription ?? \"\"",
        "let r = (error as NSError).localizedFailureReason ?? e.failureReason",
        "alert.informativeText = entry.logMessage",
        "Text(row.location.logDescription)",
        'let s = localized("Lỗi: \\(problem.logMessage)")',
        "Text(issue.message)",
        "let reasons = model.issues.map(\\.message)",
        "let first = validationIssues.first?.message",
        "let text = issues.isEmpty ? \"\" : issues[0].message",
        # Review độc lập #51 S1: câu nhật ký của chi tiết lỗi lõi, tên trường .vce, vấn đề nằm trong biến tên khác.
        "Text(jsonProblem.logMessage)", "let r = reason.logMessage(from: 1)", "Text(field.logName)",
        "func f(_ v: ValidationIssue) -> String { v.message }",
        "let all: [ValidationIssue] = list\nlet m = all.first?.message",
        "let m = issues.first.map { $0.message }",
    )
    for code in bad_core:
        expect(code, scan(code + "\n"), "core-text")
    expect("core-text không áp ở target dữ liệu", scan("let m = error.localizedDescription\n", vietnamese=False), None)


    # Luật scene-locale: mỗi scene ở cấp ngoài cùng của body có `.interfaceLocale()`.
    def scenes(code: str) -> list[Problem]:
        return scene_locale_problems("Shell.swift", code)[0]

    good_scenes = '''
        public var body: some Scene {
            // Comment: Window("x") không phải scene.
            LibraryWindow(
                model: library,
                decoration: Decoration(closingQuitsApp: true)
            )
            .commands {
                SidebarCommands()
            }
            .defaultAppStorage(defaults)
            .interfaceLocale()

            DocumentGroup(newDocument: { Document() }) { file in
                EditorWindow(document: file.document)
            }
            .interfaceLocale()
            .defaultSize(size)
            SessionWindowScene(sessions: sessions).interfaceLocale()
        }
    '''
    expect("scene gắn interfaceLocale", scenes(good_scenes), None)
    if scene_locale_problems("Shell.swift", good_scenes)[1] != 1:
        failures.append("đối chứng: phải đếm được một body của Scene")
    bad_scenes = (
        "var body: some Scene {\n    LibraryWindow(model: m)\n        .interfaceLocale()\n"
        "    SessionWindowScene(sessions: s)\n        .defaultAppStorage(d)\n}\n",
        "var body: some Scene {\n    WindowGroup {\n        RootView().interfaceLocale()\n    }\n}\n",
        "var body: some Scene {\n    DocumentGroup(newDocument: { D() }) { file in\n        V().interfaceLocale()\n"
        "    }\n    .commands { C() }\n}\n",
    )
    for code in bad_scenes:
        expect(code, scenes(code), "scene-locale")

    # Điểm vào của app (review #50 N3): scene gộp của shell (đã kiểm) không cần gắn lại; scene khác thì phải gắn.
    shells = frozenset(SCENE_TYPE_RE.findall("public struct StudentScenes: Scene {\n}\nstruct Other: View {}\n"))
    if shells != {"StudentScenes"}:
        failures.append(f"đối chứng: SCENE_TYPE_RE phải tìm đúng scene gộp, được {sorted(shells)}")

    def app_scenes(code: str) -> list[Problem]:
        return scene_locale_problems("App.swift", code, shells)[0]

    expect("app chỉ có scene gộp của shell", app_scenes(
        "@main\nstruct App: App {\n    var body: some Scene {\n        StudentScenes(delegate: appDelegate)\n    }\n}\n"
    ), None)
    bad_apps = (
        "var body: some Scene {\n    WindowGroup { RootView() }\n}\n",
        "var body: some Scene {\n    StudentScenes(delegate: d)\n    Settings { SettingsView() }\n}\n",
        "var body: some Scene {\n    OtherScenes(delegate: d)\n}\n",
    )
    for code in bad_apps:
        expect(code, app_scenes(code), "scene-locale")

    # Catalog.
    def catalog(strings: dict, source: str = "vi", name: str = "Localizable.xcstrings", en: bool = False) -> list[Problem]:
        raw = json.dumps({"sourceLanguage": source, "strings": strings, "version": "1.0"}, ensure_ascii=False)
        return catalog_problems(f"X/{name}", raw, en)

    ok_strings = {"Thư viện": {}, "Câu %lld": {"localizations": {"en": {"stringUnit": {"state": "new", "value": "Câu %lld"}}}}}
    expect("catalog đúng", catalog(ok_strings), None)
    expect("catalog sourceLanguage en", catalog(ok_strings, source="en"), "catalog")
    expect("catalog stale", catalog({"Cũ": {"extractionState": "stale"}}), "catalog")
    expect("catalog khoá rỗng", catalog({" ": {}}), "catalog")
    expect("catalog en rỗng", catalog({"Lưu": {"localizations": {"en": {"stringUnit": {"state": "new", "value": ""}}}}}),
           "catalog")
    expect("catalog plural vi rỗng", catalog({"%lld câu": {"localizations": {"vi": {"variations": {"plural": {
        "other": {"stringUnit": {"state": "translated", "value": ""}}}}}}}}), "catalog")
    expect("InfoPlist thiếu vi", catalog({"CFBundleName": {}}, name="InfoPlist.xcstrings"), "catalog")
    expect("InfoPlist đúng", catalog({"CFBundleName": {"localizations": {
        "vi": {"stringUnit": {"state": "translated", "value": "Exam Suite"}},
        "en": {"stringUnit": {"state": "translated", "value": "Exam Suite"}}}}}, name="InfoPlist.xcstrings"), None)
    expect("JSON hỏng", catalog_problems("X/Localizable.xcstrings", "{", False), "catalog")
    # --require-en (bật từ bước 7c): thiếu en, en chưa dịch, sai đặc tả, plural/substitution.
    def unit(value: str, state: str = "translated") -> dict:
        return {"stringUnit": {"state": state, "value": value}}

    def plural(one: str, other: str) -> dict:
        return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}

    def en(key: str, localization: dict, vi: str | None = None) -> list[Problem]:
        localizations = {"en": localization}
        if vi is not None:
            localizations["vi"] = unit(vi, "new")
        return catalog({key: {"localizations": localizations}}, en=True)

    report_vi = "Báo cáo “%1$@”: %2$lld câu bị bỏ · %3$lld cảnh báo"
    report_key = "Báo cáo “%@”: %lld câu bị bỏ · %lld cảnh báo"

    def report_en(value: str, skipped: int = 2, spec: str = "lld", one: str = "%arg question") -> dict:
        return {**unit(value), "substitutions": {
            "skipped": {"argNum": skipped, "formatSpecifier": spec, **plural(one, "%arg questions")},
            "warnings": {"argNum": 3, "formatSpecifier": "lld", **plural("%arg warning", "%arg warnings")}}}

    expect("en thiếu", catalog({"Lưu": {}}, en=True), "catalog")
    expect("en new", en("Lưu", unit("Save", "new")), "catalog")
    expect("en sai đặc tả", en("Câu %lld", unit("Question %@")), "catalog")
    expect("en thiếu đối số", en("Câu %lld", unit("Question")), "catalog")
    expect("en đúng", en("Câu %lld/%lld", unit("Question %1$lld of %2$lld"), vi="Câu %1$lld/%2$lld"), None)
    expect("en đổi thứ tự bằng số vị trí", en("%@ của %@", unit("%2$@’s %1$@"), vi="%1$@ của %2$@"), None)
    expect("en đổi thứ tự không có số vị trí", en("%@ của %lld", unit("%lld of %@"), vi="%1$@ của %2$lld"), "catalog")
    expect("en giữ %%", en("0–100 %% (%lld)", unit("0–100 %% (%lld)")), None)
    expect("en plural đúng", en("%lld câu", plural("%lld question", "%lld questions")), None)
    expect("en plural one bỏ số", en("%lld câu", plural("One question", "%lld questions")), None)
    expect("en plural thiếu other", en("%lld câu", {"variations": {"plural": {"one": unit("%lld question")}}}), "catalog")
    expect("en plural sai kiểu", en("%lld câu", plural("%@ question", "%lld questions")), "catalog")
    expect("en plural other bỏ số", en("%lld câu", plural("%lld question", "Many questions")), "catalog")
    expect("en plural chưa dịch", en("%lld câu", {"variations": {"plural": {
        "one": unit("%lld question", "needs_review"), "other": unit("%lld questions")}}}), "catalog")
    expect("en substitution đúng", en(report_key, report_en("Report “%1$@”: %#@skipped@ · %#@warnings@"), vi=report_vi),
           None)
    expect("en substitution sai argNum", en(report_key, report_en("Report “%1$@”: %#@skipped@ · %#@warnings@",
                                                                skipped=1), vi=report_vi), "catalog")
    expect("en substitution sai kiểu", en(report_key, report_en("Report “%1$@”: %#@skipped@ · %#@warnings@",
                                                               spec="@"), vi=report_vi), "catalog")
    expect("en substitution không dùng trong chuỗi", en(report_key, report_en("Report “%1$@”: %#@skipped@ · %3$lld"),
                                                        vi=report_vi), "catalog")
    expect("en substitution cạnh đặc tả không số vị trí", en(report_key, report_en("Report “%@”: %#@skipped@ · %#@warnings@"),
                                                             vi=report_vi), "catalog")
    expect("en substitution other không có %arg", en(report_key, {**unit("Report “%1$@”: %#@skipped@ · %#@warnings@"),
        "substitutions": {
            "skipped": {"argNum": 2, "formatSpecifier": "lld", **plural("%arg question", "questions")},
            "warnings": {"argNum": 3, "formatSpecifier": "lld", **plural("%arg warning", "%arg warnings")}}},
        vi=report_vi), "catalog")
    expect("en substitution dùng %lld thay %arg", en(report_key, report_en(
        "Report “%1$@”: %#@skipped@ · %#@warnings@", one="%lld question"), vi=report_vi), "catalog")
    expect("en shouldTranslate false không đòi en", catalog({"Exam Suite": {"shouldTranslate": False}}, en=True), None)
    # Luật test-hook.
    hook = 'InterfaceStrings.$languageOverride.withValue(en) { view() }'
    expect("test-hook trong app", test_hook_problems("Packages/ExamFeatures/Sources/SessionFeature/X.swift", hook),
           "test-hook")
    expect("test-hook processLanguageOverride trong app", test_hook_problems(
        "Apps/Student/X.swift", "InterfaceStrings.processLanguageOverride = en"), "test-hook")
    expect("test-hook trong file khai báo", test_hook_problems(TEST_HOOK_FILE, hook), None)
    expect("test-hook trong chú thích", test_hook_problems("X.swift", "// languageOverride chỉ cho test"), None)
    # So catalog sau đồng bộ.
    base = {"sourceLanguage": "vi", "strings": {"A": {}}}
    if catalog_diff(base, base):
        failures.append("đối chứng dương catalog_diff bị báo sai")
    if not catalog_diff(base, {"sourceLanguage": "vi", "strings": {"A": {}, "B": {}}}):
        failures.append("đối chứng âm catalog_diff: khoá mới không bị bắt")
    if not catalog_diff(base, {"sourceLanguage": "vi", "strings": {"A": {"extractionState": "stale"}}}):
        failures.append("đối chứng âm catalog_diff: khoá stale không bị bắt")
    failures += built_app_self_test()
    failures += freshness_self_test()
    return failures


def freshness_self_test() -> list[str]:
    """Đối chứng cho chọn .stringsdata và thư mục build sai/rỗng (không cần xcstringstool)."""
    import os

    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="check-l10n-fresh-") as tmp:
        root = Path(tmp)
        sources = root / "Sources/SessionFeature"
        sources.mkdir(parents=True)
        for name in ("A", "B"):
            (sources / f"{name}.swift").write_text("", encoding="utf-8")
        build = root / ".build"
        files = {
            "out/Intermediates.noindex/ExamFeatures.build/Debug/SessionFeature-t.build/Objects-normal/arm64/A.stringsdata": 200,
            "out/Intermediates.noindex/ExamFeatures.build/Release/SessionFeature-t.build/Objects-normal/arm64/A.stringsdata": 100,
            "arm64-apple-macosx/debug/SessionFeature.build/B.stringsdata": 150,
            "arm64-apple-macosx/debug/SessionFeature.build/Removed.stringsdata": 300,
            "arm64-apple-macosx/debug/SessionFeatureTests.build/A.stringsdata": 400,
            "arm64-apple-macosx/debug/OtherSessionFeature.build/B.stringsdata": 400,
        }
        for rel, mtime in files.items():
            path = build / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("", encoding="utf-8")
            os.utime(path, (mtime, mtime))
        got = [str(p.relative_to(build)) for p in stringsdata_for(build, "SessionFeature", sources)]
        want = sorted(["out/Intermediates.noindex/ExamFeatures.build/Debug/SessionFeature-t.build/Objects-normal/arm64/"
                       "A.stringsdata", "arm64-apple-macosx/debug/SessionFeature.build/B.stringsdata"])
        if got != want:
            failures.append(f"đối chứng chọn .stringsdata: được {got}, cần {want}")
        if not check_freshness(root / "không-có"):
            failures.append("đối chứng âm --freshness: thư mục build không có mà không thất bại")
        empty = root / "empty"
        empty.mkdir()
        if shutil.which("xcrun") is not None:
            if not check_freshness(empty, root=ROOT):
                failures.append("đối chứng âm --freshness: thư mục không có .stringsdata mà không thất bại")
            import contextlib
            import io
            with contextlib.redirect_stdout(io.StringIO()):
                skipped = check_freshness(empty, allow_missing=True, root=ROOT)
            if skipped is not None:
                failures.append("đối chứng --allow-missing-stringsdata: phải bỏ qua có ghi chú")
    return failures


def main(argv: list[str]) -> int:
    require_en = "--require-en" in argv

    def option_path(flag: str, example: str) -> Path | None:
        if flag not in argv:
            return None
        i = argv.index(flag)
        if i + 1 >= len(argv):
            raise SystemExit(f"check_localization.py: {flag} cần một thư mục (ví dụ {example}).")
        return Path(argv[i + 1]).resolve()

    build_dir = option_path("--freshness", "Packages/ExamFeatures/.build")
    products = option_path("--built-apps", "build/DerivedData/Build/Products/Debug")
    failures = self_test()
    if failures:
        print("FAIL check_localization.py tự kiểm (hàm kiểm không còn bắt được vi phạm):")
        for f in failures:
            print(f"  - {f}")
        return 1
    problems = check_sources() + check_scene_locale() + check_catalogs(require_en)
    fresh = None
    if build_dir is not None:
        fresh = check_freshness(build_dir, allow_missing="--allow-missing-stringsdata" in argv)
        problems += fresh or []
    if products is not None:
        problems += check_built_apps(products, require_en)
    if problems:
        print(f"FAIL chuỗi giao diện/String Catalog ({len(problems)} lỗi; quy ước ở AGENTS.md, mục Chuỗi giao diện):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print("ok   chuỗi giao diện tra catalog của module (bundle: .module / localized), số/ngày không theo Region "
          "(region-locale), mọi scene của hai shell và hai app gắn .interfaceLocale() (scene-locale), câu của lõi/target dữ liệu không lên giao diện (core-text), chỗ ép ngôn ngữ chỉ ở test (test-hook), catalog nguồn vi hợp lệ"
          + (", catalog đủ khoá" if fresh is not None else "")
          + (", hai app có vi/en và chuỗi Info.plist tra được" if products is not None else "")
          + (", đủ bản en" if require_en else " (không đòi en: thiếu --require-en)")
          + " (đối chứng âm bị bắt)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
