#!/usr/bin/env python3
"""Bằng chứng scripts/validate_exam.py và ExamValidator (app) cùng kết luận trên mọi fixture.

Một file kỳ vọng ràng buộc cả hai bên: fixtures/expected-verdicts.json.
- Script này: mọi fixture có trong file kỳ vọng và ngược lại; kết luận của
  validate_exam.py (có error hay không) khớp kỳ vọng; hằng WHITE_SPACE của script
  trùng khoá "whiteSpace".
- Phía app: test Swift `ExamValidatorParityTests` (Packages/ExamKit/Tests/ExamKitTests/
  ExamValidatorTests.swift) đọc cùng file, khẳng định model + ExamValidator cho đúng
  kết luận và tập White_Space của Swift trùng khoá "whiteSpace".

Dùng: scripts/check_validator_parity.py   (cần jsonschema như validate_exam.py)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_exam  # noqa: E402

ROOT = validate_exam.ROOT
FIXTURES = ROOT / "fixtures"
EXPECTED_PATH = FIXTURES / "expected-verdicts.json"
VERDICTS = {"valid", "error", "undecodable", "examfile"}


def parse_code_points(items: list[str]) -> set[int]:
    out: set[int] = set()
    for item in items:
        lo, _, hi = item.partition("-")
        out.update(range(int(lo, 16), int(hi or lo, 16) + 1))
    return out


def fixture_paths() -> dict[str, Path]:
    """Khoá kiểu "exams/<tên>" → thư mục gói; "invalid/<tên>" → file json."""
    found: dict[str, Path] = {}
    for p in sorted((FIXTURES / "exams").glob("*/exam.json")):
        found[f"exams/{p.parent.name}"] = p.parent
    for p in sorted((FIXTURES / "invalid").glob("*.json")):
        found[f"invalid/{p.stem}"] = p
    return found


def main() -> int:
    expected_doc = json.loads(EXPECTED_PATH.read_text(encoding="utf-8"))
    expected: dict[str, str] = expected_doc["verdicts"]
    ok = True

    ws = parse_code_points(expected_doc["whiteSpace"])
    if ws != set(validate_exam.WHITE_SPACE):
        extra = sorted(set(validate_exam.WHITE_SPACE) - ws)
        missing = sorted(ws - set(validate_exam.WHITE_SPACE))
        print(f"FAIL whiteSpace: script thừa {[hex(c) for c in extra]}, thiếu {[hex(c) for c in missing]}")
        ok = False
    else:
        print(f"ok   whiteSpace: {len(ws)} code point, script và file kỳ vọng trùng nhau")

    bad_values = {k: v for k, v in expected.items() if v not in VERDICTS}
    if bad_values:
        print(f"FAIL giá trị kỳ vọng lạ (chỉ nhận {sorted(VERDICTS)}): {bad_values}")
        ok = False

    found = fixture_paths()
    unlisted = sorted(set(found) - set(expected))
    stale = sorted(set(expected) - set(found))
    if unlisted:
        print(f"FAIL fixture chưa có trong {EXPECTED_PATH.relative_to(ROOT)}: {unlisted}")
        ok = False
    if stale:
        print(f"FAIL {EXPECTED_PATH.relative_to(ROOT)} nhắc fixture không tồn tại: {stale}")
        ok = False

    validator = validate_exam.load_validator()
    for key in sorted(set(found) & set(expected)):
        errors, warnings = validate_exam.check_path(validator, found[key])
        want = expected[key]
        script_has_error = bool(errors)
        if script_has_error == (want != "valid"):
            note = f"{len(errors)} error" if errors else "không error"
            if warnings:
                note += f", {len(warnings)} warning"
            print(f"ok   {key}: kỳ vọng {want}; script {note}")
        else:
            print(f"FAIL {key}: kỳ vọng {want} (app), nhưng script "
                  + (f"báo error: {errors[0]}" if errors else "không báo error"))
            ok = False

    if ok:
        print("== parity OK: script cùng kết luận với bảng kỳ vọng mà test Swift khẳng định cho app")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
