#!/usr/bin/env python3
"""Kiểm tra exam.json theo schema/exam-v1.schema.json và các ràng buộc liên trường.

Dùng:
  scripts/validate_exam.py <exam.json|thư-mục-gói> [...]
  scripts/validate_exam.py --all        # mọi fixtures/exams phải đậu, mọi fixtures/invalid phải rớt,
                                        # mọi đề mẫu của Thư viện phải đậu và không có cả warning
  scripts/validate_exam.py --expect-invalid <file.json> [...]

Kết luận "có error hay không" phải trùng với ExamKit.ExamValidator của app
(Packages/ExamKit/Sources/ExamKit/Validation/ExamValidator.swift); bảng kỳ vọng chung
fixtures/expected-verdicts.json, kiểm bằng scripts/check_validator_parity.py.
Cảnh báo (warning) của app được in ra dòng "warn" nhưng không làm file rớt, trừ đề mẫu.

Đề mẫu (SAMPLES, docs/product/library.md mục "Đề mẫu và lần đầu mở app") chặt hơn: mỗi
thư mục con không ẩn là một đề và phải có exam.json; không error, không warning, chuỗi ở dạng
Unicode NFC, mỗi ảnh trong media/ được một câu dùng và đặt tên đúng SHA-256 nội dung.
Phía app, test Swift `LibrarySampleTests` (ExamFileTests) kiểm các quy tắc đó trừ NFC: `String`
của Swift so theo tương đương chính tắc (NFC và NFD bằng nhau), nên chỉ script kiểm NFC.

Thẩm quyền: docs/product/exam-format.md. Cần gói Python `jsonschema` (>= 4.18).
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = ROOT / "schema" / "exam-v1.schema.json"
# Đề mẫu bản app ghi ra lần đầu mở; mỗi thư mục con là một gói đã giải nén (exam.json + media/).
SAMPLES = ROOT / "Packages" / "ExamFeatures" / "Sources" / "LibraryData" / "Resources" / "Samples"

try:
    import jsonschema  # noqa: F401
    from jsonschema import Draft202012Validator, FormatChecker
except ImportError:  # pragma: no cover
    sys.stderr.write(
        "validate_exam.py: thiếu gói Python 'jsonschema'. Cài: pip install jsonschema "
        "(hoặc: uv run --with jsonschema scripts/validate_exam.py ...)\n"
    )
    sys.exit(2)

# Khoảng trắng = thuộc tính Unicode White_Space (PropList.txt), đúng tập
# `Unicode.Scalar.Properties.isWhitespace` mà ExamValidator.isBlank dùng.
# KHÔNG dùng str.isspace()/str.strip(): Python coi U+001C–U+001F là khoảng trắng,
# White_Space thì không. ZWSP U+200B, U+180E, U+FEFF không thuộc White_Space.
# Danh sách này phải trùng khoá "whiteSpace" trong fixtures/expected-verdicts.json;
# test Swift kiểm khoá đó với Unicode của Swift, check_validator_parity.py kiểm với hằng này.
WHITE_SPACE_RANGES: tuple[tuple[int, int], ...] = (
    (0x0009, 0x000D),  # tab, LF, VT, FF, CR
    (0x0020, 0x0020),  # space
    (0x0085, 0x0085),  # NEL
    (0x00A0, 0x00A0),  # NBSP
    (0x1680, 0x1680),  # ogham space mark
    (0x2000, 0x200A),  # en quad … hair space
    (0x2028, 0x2029),  # line separator, paragraph separator
    (0x202F, 0x202F),  # narrow NBSP
    (0x205F, 0x205F),  # medium mathematical space
    (0x3000, 0x3000),  # ideographic space
)
WHITE_SPACE: frozenset[int] = frozenset(
    cp for lo, hi in WHITE_SPACE_RANGES for cp in range(lo, hi + 1)
)

# Mẫu trong schema. jsonschema khớp `pattern` bằng re.search, nên `$` còn khớp trước
# "\n" cuối chuỗi ("KTC01\n" lọt). App khớp tuyệt đối, nên kiểm lại bằng re.fullmatch.
_SCHEMA = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
UUID_RE = re.compile(_SCHEMA["$defs"]["uuid"]["pattern"])
OPTION_ID_RE = re.compile(_SCHEMA["$defs"]["optionId"]["pattern"])
CODE_RE = re.compile(_SCHEMA["properties"]["code"]["pattern"])
IMAGE_RE = re.compile(_SCHEMA["$defs"]["question"]["properties"]["image"]["pattern"])


def is_blank(s: str) -> bool:
    """Chuỗi rỗng hoặc chỉ gồm code point White_Space (ExamValidator.isBlank)."""
    return all(ord(c) in WHITE_SPACE for c in s)


def trimmed(s: str) -> str:
    """Bỏ code point White_Space ở hai đầu (ExamValidator.trimmed)."""
    start, end = 0, len(s)
    while start < end and ord(s[start]) in WHITE_SPACE:
        start += 1
    while end > start and ord(s[end - 1]) in WHITE_SPACE:
        end -= 1
    return s[start:end]


def load_validator() -> Draft202012Validator:
    Draft202012Validator.check_schema(_SCHEMA)
    return Draft202012Validator(_SCHEMA, format_checker=FormatChecker())


class JSONProblem(ValueError):
    pass


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    obj: dict = {}
    for key, value in pairs:
        if key in obj:
            # Python lấy giá trị cuối, JSONDecoder của app lấy giá trị đầu: không cho tồn tại.
            raise JSONProblem(f"khoá {key!r} xuất hiện hai lần trong cùng một object")
        obj[key] = value
    return obj


def _reject_constant(name: str) -> object:
    raise JSONProblem(f"{name} không phải JSON hợp lệ")


def _lone_surrogate_path(value: object, path: str = "") -> str | None:
    """App (JSONDecoder) từ chối chuỗi có surrogate lẻ như "\\ud800"; Python thì nhận."""
    if isinstance(value, str):
        return path or "<root>" if any(0xD800 <= ord(c) <= 0xDFFF for c in value) else None
    if isinstance(value, dict):
        items = value.items()
    elif isinstance(value, list):
        items = ((str(i), v) for i, v in enumerate(value))
    else:
        return None
    for k, v in items:
        if any(0xD800 <= ord(c) <= 0xDFFF for c in k):
            return f"{path}/{k}" if path else k
        found = _lone_surrogate_path(v, f"{path}/{k}" if path else k)
        if found:
            return found
    return None


def load_exam_json(json_path: Path) -> object:
    """Đọc exam.json như app: UTF-8 (BOM đầu file được bỏ qua), JSON chuẩn.

    Raise OSError/ValueError (kể cả JSONProblem) khi không đọc được.
    """
    text = json_path.read_bytes().decode("utf-8-sig")
    data = json.loads(text, object_pairs_hook=_reject_duplicate_keys, parse_constant=_reject_constant)
    where = _lone_surrogate_path(data)
    if where:
        raise JSONProblem(f"{where}: chuỗi chứa surrogate UTF-16 lẻ (không phải Unicode hợp lệ)")
    return data


def cross_field_problems(exam: dict, media_names: set[str] | None) -> tuple[list[str], list[str]]:
    """Quy tắc schema không diễn tả được hoặc jsonschema kiểm lỏng hơn app.

    Trả về (errors, warnings). Phải cùng kết luận với ExamKit.ExamValidator; mã trong
    ngoặc vuông là `IssueCode` tương ứng phía app.

    `media_names`: None = không kiểm ảnh có trong gói; khác None = tập "media/<tên>" có thật.
    """
    errors: list[str] = []
    warnings: list[str] = []
    # UUID so theo giá trị như app (UUID của Foundation): hai id chỉ khác hoa/thường là trùng.
    seen_ids: dict[str, str] = {}

    def check_uuid(value: str, where: str) -> None:
        if not UUID_RE.fullmatch(value):
            errors.append(f"{where}: id {value!r} không phải UUID dạng 8-4-4-4-12")

    def check_id(value: str, where: str) -> None:
        check_uuid(value, where)
        key = value.lower()
        if key in seen_ids:
            errors.append(
                f"{where}: id {value} trùng với id của {seen_ids[key]} (so không phân biệt hoa/thường) [duplicateID]"
            )
        else:
            seen_ids[key] = where

    def check_text(value: str, where: str, code: str) -> None:
        if is_blank(value):
            errors.append(f"{where}: rỗng hoặc chỉ có khoảng trắng (Unicode White_Space) [{code}]")

    check_id(exam["id"], "đề")
    check_text(exam["title"], "title", "titleEmpty")
    code = exam.get("code")
    if code is not None and not CODE_RE.fullmatch(code):
        errors.append(f"code: {code!r} không khớp tuyệt đối {CODE_RE.pattern} [codeInvalid]")

    seen_titles: dict[str, int] = {}
    for si, section in enumerate(exam["sections"]):
        swhere = f"sections[{si}]"
        check_id(section["id"], swhere)
        check_text(section["title"], f"{swhere}.title", "titleEmpty")
        title_key = trimmed(section["title"]).lower()
        if title_key:
            if title_key in seen_titles:
                warnings.append(
                    f"{swhere}.title: trùng tiêu đề với sections[{seen_titles[title_key]}] "
                    "(bỏ khoảng trắng hai đầu, không phân biệt hoa/thường) [duplicateSectionTitle]"
                )
            else:
                seen_titles[title_key] = si

        for qi, q in enumerate(section["questions"]):
            qwhere = f"{swhere}.questions[{qi}]"
            check_id(q["id"], qwhere)
            check_text(q["text"], f"{qwhere}.text", "questionTextEmpty")

            image = q.get("image")
            if image is not None:
                if not IMAGE_RE.fullmatch(image):
                    errors.append(f"{qwhere}.image: {image!r} không khớp tuyệt đối {IMAGE_RE.pattern} [imagePathInvalid]")
                elif media_names is not None and image not in media_names:
                    errors.append(f"{qwhere}.image: ảnh {image} không có trong gói [imageNotFound]")

            option_ids = [o["id"] for o in q["options"]]
            for oi, o in enumerate(q["options"]):
                owhere = f"{qwhere}.options[{oi}]"
                if not OPTION_ID_RE.fullmatch(o["id"]):
                    errors.append(f"{owhere}.id: {o['id']!r} không phải một chữ cái A–Z")
                elif oi < 26 and o["id"] != chr(ord("A") + oi):
                    errors.append(
                        f"{owhere}.id: là {o['id']}, phải là {chr(ord('A') + oi)} (thứ tự A, B, C…) [optionIDOutOfOrder]"
                    )
                check_text(o["text"], f"{owhere}.text", "optionTextEmpty")

            correct = q["correct"]
            for c in correct:
                if not OPTION_ID_RE.fullmatch(c):
                    errors.append(f"{qwhere}.correct: {c!r} không phải một chữ cái A–Z")
            if not correct:
                errors.append(f"{qwhere}.correct: chưa có đáp án đúng [noCorrectAnswer]")
            if len(set(correct)) != len(correct):
                errors.append(f"{qwhere}.correct: đáp án đúng bị lặp {correct} [duplicateCorrectAnswer]")
            missing = sorted({c for c in correct if c not in option_ids})
            if missing:
                errors.append(
                    f"{qwhere}.correct: {missing} không có trong options {option_ids} [correctAnswerNotInOptions]"
                )
            if q["type"] == "single" and len(correct) > 1:
                errors.append(f"{qwhere}: câu single có {len(correct)} đáp án đúng [singleHasMultipleCorrect]")
            if q["type"] == "multiple" and len(set(correct)) == 1:
                warnings.append(f"{qwhere}: câu multiple chỉ có một đáp án đúng [multipleHasSingleCorrect]")
    return errors, warnings


def media_names_of(package_dir: Path) -> set[str]:
    """Tập "media/<tên>" có thật trong gói. So khớp chính xác tên (kể cả hoa/thường) như
    app, không dùng Path.is_file vì ổ đĩa macOS không phân biệt hoa/thường."""
    media = package_dir / "media"
    if not media.is_dir():
        return set()
    return {f"media/{p.name}" for p in media.iterdir() if p.is_file()}


def check_path(validator: Draft202012Validator, path: Path) -> tuple[list[str], list[str]]:
    """Trả về (errors, warnings) cho một exam.json hoặc một thư mục gói đã giải nén."""
    if path.is_dir():
        package_dir, json_path = path, path / "exam.json"
    else:
        json_path = path
        package_dir = path.parent if (path.parent / "media").is_dir() or path.name == "exam.json" else None
    try:
        exam = load_exam_json(json_path)
    except (OSError, ValueError) as exc:
        return [f"không đọc được JSON: {exc}"], []
    errors = [
        f"{'/'.join(str(p) for p in e.absolute_path) or '<root>'}: {e.message}"
        for e in sorted(validator.iter_errors(exam), key=lambda e: list(e.absolute_path))
    ]
    if errors:
        return errors, []
    media = media_names_of(package_dir) if package_dir is not None else None
    return cross_field_problems(exam, media)


def _strings(value: object, path: str = "") -> list[tuple[str, str]]:
    """Mọi chuỗi giá trị trong JSON đã đọc, kèm đường dẫn dạng sections/0/title."""
    if isinstance(value, str):
        return [(path or "<root>", value)]
    if isinstance(value, dict):
        items = list(value.items())
    elif isinstance(value, list):
        items = [(str(i), v) for i, v in enumerate(value)]
    else:
        return []
    return [found for k, v in items for found in _strings(v, f"{path}/{k}" if path else k)]


def check_sample(validator: Draft202012Validator, package_dir: Path) -> tuple[list[str], list[str]]:
    """Như check_path, nhưng warning cũng là lỗi và thêm quy tắc riêng của đề mẫu.

    Trả về (errors, []) để in bằng report(). Đề mẫu do dự án soạn và đi kèm app, nên không
    có lý do gì để mang cảnh báo, chuỗi chưa chuẩn hoá hay ảnh thừa.
    """
    if not (package_dir / "exam.json").is_file():
        return [f"thư mục đề mẫu thiếu exam.json (mỗi thư mục con không ẩn của "
                f"{os.path.relpath(SAMPLES, ROOT)} là một đề; bỏ thư mục này hoặc thêm exam.json)"], []
    errors, warnings = check_path(validator, package_dir)
    if errors:
        return errors + [f"warn {w}" for w in warnings], []
    errors = [f"đề mẫu không được có warning (docs/product/library.md): {w}" for w in warnings]
    exam = load_exam_json(package_dir / "exam.json")
    for where, value in _strings(exam):
        if not unicodedata.is_normalized("NFC", value):
            errors.append(f"{where}: chuỗi chưa ở dạng Unicode NFC; chuẩn hoá NFC rồi lưu lại")
    used = {q["image"] for s in exam["sections"] for q in s["questions"] if "image" in q}
    media = package_dir / "media"
    # Bỏ qua file ẩn (.DS_Store do Finder tạo, đã có trong .gitignore).
    for p in sorted(media.iterdir()) if media.is_dir() else []:
        if p.name.startswith("."):
            continue
        rel = f"media/{p.name}"
        if not p.is_file():
            errors.append(f"{rel}: media/ chỉ được chứa file ảnh")
            continue
        named = hashlib.sha256(p.read_bytes()).hexdigest()[:16] + p.suffix.lower()
        if p.name != named:
            errors.append(f"{rel}: ảnh phải tên là {named} (16 ký tự hex đầu SHA-256 nội dung, exam-format.md)")
        if rel not in used:
            errors.append(f"{rel}: không câu nào dùng ảnh này; xoá khỏi media/")
    return errors, []


def report(path: Path, problems: tuple[list[str], list[str]], expect_invalid: bool) -> bool:
    errors, warnings = problems
    rel = os.path.relpath(path, ROOT)
    if expect_invalid:
        if errors:
            print(f"ok   (bị từ chối như mong đợi) {rel}: {errors[0]}")
            return True
        print(f"FAIL {rel}: file sai nhưng schema/kiểm tra liên trường KHÔNG bắt được. Sửa schema hoặc cross_field_problems.")
        return False
    if errors:
        print(f"FAIL {rel}")
        for e in errors:
            print(f"     - {e}")
        for w in warnings:
            print(f"     warn {w}")
        print("     Quy tắc: docs/product/exam-format.md; schema: schema/exam-v1.schema.json")
        return False
    print(f"ok   {rel}")
    for w in warnings:
        print(f"warn {rel}: {w}")
    return True


def main(argv: list[str]) -> int:
    validator = load_validator()
    ok = True
    if argv[:1] == ["--all"]:
        valid = sorted((ROOT / "fixtures" / "exams").glob("*/exam.json"))
        invalid = sorted((ROOT / "fixtures" / "invalid").glob("*.json"))
        samples: list[Path] = []
        if SAMPLES.is_dir():
            # Mọi thư mục con không ẩn là một đề, kể cả thư mục thiếu exam.json (check_sample báo lỗi).
            samples = sorted(d for d in SAMPLES.iterdir() if d.is_dir() and not d.name.startswith("."))
        if not valid or not invalid or not samples:
            print("FAIL: thiếu fixtures/exams/*/exam.json, fixtures/invalid/*.json hoặc "
                  f"thư mục đề mẫu trong {os.path.relpath(SAMPLES, ROOT)}")
            return 1
        for p in valid:
            ok &= report(p, check_path(validator, p.parent), expect_invalid=False)
        for p in invalid:
            ok &= report(p, check_path(validator, p), expect_invalid=True)
        for d in samples:
            ok &= report(d / "exam.json", check_sample(validator, d), expect_invalid=False)
    else:
        expect_invalid = False
        if argv[:1] == ["--expect-invalid"]:
            expect_invalid, argv = True, argv[1:]
        if not argv:
            print(__doc__)
            return 2
        for a in argv:
            p = Path(a).resolve()
            ok &= report(p, check_path(validator, p), expect_invalid)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
