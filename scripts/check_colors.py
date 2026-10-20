#!/usr/bin/env python3
"""Màu app tự định nghĩa chỉ nằm trong bảng màu (giai đoạn 5, bước 8b).

Thẩm quyền: docs/product/accessibility-localization.md, mục Dark Mode và tương phản ("Mọi màu tự định nghĩa nằm trong bảng
màu có giá trị số … và có test tương phản; màu mới phải vào bảng màu, không viết hex trong view"); library.md phương án 8.

Vì sao: test tương phản (`PaletteContrastTests`, `SessionStyleColorTests`, `ReadingBackgroundTests`, `PresentationTests`
của AuthoringFeature, `ReportPaletteTests`) chỉ kiểm được màu có trong bảng màu dạng số. Màu viết thẳng trong view (hex, `Color(red: …)`) lọt
khỏi mọi test.

Quét mã Swift của các target giao diện (LibraryFeature, SessionFeature, AuthoringFeature, ReportFeature, AdminShell,
StudentShell) và điểm vào hai app (`Apps/Student`, `Apps/Admin`; không gồm UI test: ảnh tự dựng của test không phải
màu giao diện), bỏ comment và nội dung chuỗi, giữ mã trong nội suy:
1. Số hex 24 hoặc 32 bit (`0xRRGGBB`, `0xAARRGGBB`, kể cả ngăn từng cặp `0x01_77_77`) chỉ được ở file bảng màu
   (`PALETTE_FILES`); ngăn từng nhóm 4 (`0x0605_4B50`) là hằng nhị phân, không phải màu.
2. Hàm dựng màu từ thành phần (`Color(red:`, `SwiftUI.Color(red:`, `Color.init(red:`, `Color(white:`, `Color(hue:`,
   `Color(.sRGB, …)`, `NSColor(srgbRed:`, `NSColor(calibratedRed:`, `NSColor(white:`, `CGColor(red:`…) chỉ được ở file
   bảng màu.
3. Màu của Asset Catalog (`Color("Tên")`, `NSColor(named:)`), `#colorLiteral(…)`, màu động `NSColor(name:)` chỉ được ở
   file bảng màu (review độc lập #54).

Không quét: màu ngữ nghĩa và màu có tên của hệ thống (`.primary`, `.secondary`, `.separator`, `.white`, `Color(nsColor:
.windowBackgroundColor)`): theo Dark Mode và Increase Contrast của macOS, không thuộc quy tắc 4,5:1 của app (Nt0 chốt
2026-10-18). Độ mờ `.opacity(…)` không phân biệt được của màu hay của view bằng cú pháp nên không quét; độ mờ của màu
nằm trong `LibraryPalette` theo quy ước (`tintedBackgroundOpacity`, `dropTargetOpacity`…).

Mỗi lần chạy, hàm kiểm được thử trước trên đầu vào cố ý sai (đối chứng âm) và đầu vào đúng (đối chứng dương); không bắt
được đối chứng âm thì script thất bại.

Dùng: scripts/check_colors.py   (chạy được trên Linux; trong scripts/check.sh bước 3)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_localization import code_mask  # noqa: E402  (tách comment/chuỗi Swift, dùng chung)

ROOT = Path(__file__).resolve().parent.parent
SOURCES = Path("Packages/ExamFeatures/Sources")
SCAN_DIRS = tuple(SOURCES / target for target in (
    "LibraryFeature", "SessionFeature", "AuthoringFeature", "ReportFeature", "AdminShell", "StudentShell",
)) + (Path("Apps/Student"), Path("Apps/Admin"))
# Bảng màu dạng số (có test tương phản) và nơi dựng màu SwiftUI/AppKit từ giá trị của bảng.
PALETTE_FILES = frozenset({
    SOURCES / "LibraryFeature/Presentation/LibraryPalette.swift",
    SOURCES / "LibraryFeature/Views/PaletteColors.swift",
    SOURCES / "AuthoringFeature/Presentation/AuthoringPalette.swift",
    SOURCES / "ReportFeature/ReportTypography.swift",
    # Bộ màu của năm nền đọc (giai đoạn 6 bước 1; test tương phản: ReadingBackgroundTests).
    SOURCES / "SessionFeature/Presentation/ReadingPalette.swift",
})

# Số hex 24 bit (RRGGBB) hoặc 32 bit (AARRGGBB/RRGGBBAA), kể cả có dấu `_` ngăn (`0x01_77_77`, `0xFF017777`).
HEX_RE = re.compile(r"(?<![\w$])0[xX][0-9A-Fa-f_]+(?![\w$])")
HEX_DIGIT_COUNTS = {6, 8}


def is_color_hex(literal: str) -> bool:
    """6 hoặc 8 chữ số hex (có hay không dấu `_`). Chỉ khi **mọi** nhóm đúng 4 chữ số (`0x0605_4B50`, `0xFFFF_FFFF`) thì là
    cách viết hằng nhị phân (chữ ký zip), không phải màu; ngăn kiểu khác (`0x01_77_77`, `0x01_7777`) vẫn bị bắt."""
    groups = literal[2:].split("_")
    digits = "".join(groups)
    if len(digits) not in HEX_DIGIT_COUNTS:
        return False
    return not (len(groups) > 1 and all(len(group) == 4 for group in groups))
# Kiểu màu, có thể kèm tên module (`SwiftUI.Color`) và `.init`.
_COLOR_TYPE = r"(?<![\w$])(?:(?:SwiftUI|AppKit|UIKit|CoreGraphics)\.)?(?:Color|NSColor|CGColor|UIColor)(?:\.init)?\s*\(\s*"
CONSTRUCTOR_RE = re.compile(
    _COLOR_TYPE + r"(?:"
    r"(?:red|green|blue|white|hue|gray|srgbRed|calibratedRed|calibratedWhite|calibratedHue|deviceRed|deviceWhite|"
    r"deviceHue|displayP3Red|cyan|genericGrayGamma2_2Gray)\s*:"
    r"|\.(?:sRGB|sRGBLinear|displayP3)\s*,"
    r")"
)
# Màu trong Asset Catalog (`Color("Tên")`, `NSColor(named:)`): giá trị không ở dạng số nên không test tương phản được.
ASSET_RE = re.compile(_COLOR_TYPE + r'(?:"|named\s*:)')
# `#colorLiteral(…)`.
LITERAL_RE = re.compile(r"#colorLiteral\s*\(")
# Màu động `NSColor(name:dynamicProvider:)`: chỉ ở file bảng màu (dựng từ giá trị số của bảng).
DYNAMIC_RE = re.compile(_COLOR_TYPE + r"name\s*:")


def problems_in(path: Path, src: str) -> list[str]:
    """Vi phạm trong một file (đường dẫn tương đối với gốc repo)."""
    if path in PALETTE_FILES:
        return []
    code = code_mask(src)
    found: list[str] = []
    checks = (
        (HEX_RE, "số hex màu"),
        (CONSTRUCTOR_RE, "hàm dựng màu từ thành phần"),
        (ASSET_RE, "màu của Asset Catalog"),
        (LITERAL_RE, "#colorLiteral"),
        (DYNAMIC_RE, "màu động NSColor(name:)"),
    )
    for regex, what in checks:
        for match in regex.finditer(code):
            if regex is HEX_RE and not is_color_hex(match.group(0)):
                continue
            line = code.count("\n", 0, match.start()) + 1
            found.append(f"{path}:{line}: {what} `{src[match.start():match.end()].strip()}` ngoài bảng màu: đưa màu vào "
                         "LibraryPalette/AuthoringPalette/ReadingPalette (có test tương phản) rồi dùng màu của bảng")
    return found


def check() -> tuple[int, list[str]]:
    scanned = 0
    problems: list[str] = []
    for directory in SCAN_DIRS:
        for file in sorted((ROOT / directory).rglob("*.swift")):
            relative = file.relative_to(ROOT)
            scanned += 1
            problems += problems_in(relative, file.read_text(encoding="utf-8"))
    return scanned, problems


def self_test() -> list[str]:
    failures: list[str] = []
    view = SOURCES / "SessionFeature/Views/Example.swift"
    negatives = {
        "Color(red:": 'let c = Color(red: 0.1, green: 0.2, blue: 0.3)\n',
        "Color(white:": 'Text("a").foregroundStyle(Color(white: 0.4))\n',
        "Color(.sRGB,": 'let c = Color(.sRGB, red: 1, green: 0, blue: 0)\n',
        "NSColor(srgbRed:": 'let c = NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 1)\n',
        "NSColor(calibratedWhite:": 'let c = NSColor(calibratedWhite: 0.5, alpha: 1)\n',
        "hex": 'static let teal = Pair(light: 0x017777, dark: 0x4FC9C9)\n',
        "nội suy": 'Text("màu \\(Color(red: 1, green: 0, blue: 0))")\n',
        "SwiftUI.Color(red:": 'let c = SwiftUI.Color(red: 0.1, green: 0.2, blue: 0.3)\n',
        "Color.init(red:": 'let c = Color.init(red: 0.1, green: 0.2, blue: 0.3)\n',
        "#colorLiteral": 'let c = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 1)\n',
        "hex có _": 'static let teal = Pair(light: 0x01_77_77, dark: 0x4FC9C9)\n',
        "hex 8 chữ số": 'let argb: UInt32 = 0xFF017777\n',
        "hex ngăn lệch": 'static let teal = Pair(light: 0x01_7777, dark: 0x4FC9C9)\n',
        "Color(\"Asset\")": 'let c = Color("AccentTeal")\n',
        "NSColor(named:)": 'let c = NSColor(named: "AccentTeal")\n',
        "NSColor(name:)": 'let c = NSColor(name: "X") { _ in .red }\n',
    }
    for name, src in negatives.items():
        if not problems_in(view, src):
            failures.append(f"đối chứng âm không bị bắt: {name}")
    positives = {
        "comment": '// Nền nút #017777 (5,38:1), 0x017777\n/* Color(red: 1) */\n',
        "chuỗi": 'let s = "0x017777 Color(red: 1, green: 0, blue: 0)"\n',
        "màu của bảng": 'let c = LibraryPalette.accentFill.color(name: "A")\nText("x").foregroundStyle(.secondary)\n',
        "màu hệ thống": 'let c = Color(nsColor: .windowBackgroundColor)\nlet d = Color.white\n',
        "hex ngắn": 'let mask: UInt16 = 0xFFFF\nlet byte = 0xFF\nlet big: UInt64 = 0xFFFF_FFFF_FFFF\nlet sig: UInt32 = 0x0605_4B50\n',
    }
    for name, src in positives.items():
        if problems_in(view, src):
            failures.append(f"đối chứng dương bị báo sai ({name}): {problems_in(view, src)}")
    palette = SOURCES / "LibraryFeature/Presentation/LibraryPalette.swift"
    if problems_in(palette, negatives["hex"] + negatives["Color(red:"]):
        failures.append("file bảng màu bị báo sai")
    return failures


def main(argv: list[str]) -> int:
    failures = self_test()
    if failures:
        print("FAIL check_colors.py tự kiểm (hàm kiểm không còn bắt được vi phạm):")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    scanned, problems = check()
    if problems:
        print(f"FAIL màu ngoài bảng màu ({len(problems)} lỗi; xem docstring của scripts/check_colors.py):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"ok   {scanned} file Swift của giao diện: màu tự định nghĩa (hex, hàm dựng từ thành phần) chỉ ở bảng màu "
          "(đối chứng âm bị bắt)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
