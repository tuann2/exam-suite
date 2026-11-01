#!/usr/bin/env python3
"""Sinh file `.oef` thử từ mô tả JSON (fixtures/oef/src/*.json → fixtures/oef/*.oef).

Dùng:
  scripts/make_oef.py            Ghi lại mọi fixtures/oef/<tên>.oef từ fixtures/oef/src/<tên>.json.
  scripts/make_oef.py --check    Sinh trong bộ nhớ rồi so từng byte với file đã commit; thiếu, thừa hay lệch là lỗi.
                                 Có đối chứng âm: mô tả sửa một giá trị phải ra byte khác. scripts/check.sh gọi.

File `.oef` là dây Protobuf của Open Exam Suite (docs/product/exam-format.md, mục File `.oef`; ADR 0014). Fixture tự
soạn, không chép file mẫu của Open Exam Suite (ADR 0001). Oracle chung của lõi Swift (`OEFReaderTests`) và lõi Kotlin
(`SharedOracleTest`): kết luận mong đợi ở fixtures/oef/expected.json, viết tay, không sinh từ script này.

Mô tả JSON: {"description": "…", "message": [trường…], "truncate": N (tuỳ chọn), "prefix": "hex" (tuỳ chọn)}.
`prefix` thay toàn bộ nội dung đầu file bằng byte cho sẵn (file bản cũ, file chữ); có cả `message` thì nối sau.
Một trường là [số trường, kiểu, giá trị]:
  varint   số nguyên (âm: bù hai 64 bit, như int32 âm của Protobuf)
  double   số thực, fixed64 little-endian
  fixed32  số nguyên 32 bit little-endian
  string   chuỗi, ghi UTF-8
  hex      byte cho sẵn (trường độ dài), ví dụ UTF-8 hỏng
  char     một ký tự BMP, ghi varint mã UTF-16 (char của .NET); mã khác (ví dụ > 0xFFFF) ghi bằng `varint`
  packed   danh sách ký tự, ghi một trường độ dài chứa các varint
  image    tên ảnh tự dựng: png-đỏ, png-xanh, gif-1x1, bmp-1x1; jpg-dau, webp-dau, heic-dau chỉ có byte đầu đúng
           loại (đủ cho bộ đọc nhận loại theo byte đầu, không giải mã được thành ảnh) (trường độ dài)
  message  danh sách trường của thông điệp con
  wire     [kiểu dây, giá trị]: khoá với kiểu dây cho sẵn rồi byte hex (để dựng dây hỏng)

Công cụ dev, chỉ thư viện chuẩn của Python.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OEF_DIR = ROOT / "fixtures" / "oef"
SRC_DIR = OEF_DIR / "src"


def varint(value: int) -> bytes:
    if value < 0:
        value &= (1 << 64) - 1
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def key(field: int, wire_type: int) -> bytes:
    return varint((field << 3) | wire_type)


def length_delimited(field: int, payload: bytes) -> bytes:
    return key(field, 2) + varint(len(payload)) + payload


def png(red: int, green: int, blue: int) -> bytes:
    """PNG 2×2 một màu, RGB 8 bit. Zlib chỉ dùng khối "stored" (không nén) để cùng byte với mọi bản zlib."""

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    raw = (b"\x00" + bytes([red, green, blue]) * 2) * 2
    stored = b"\x78\x01\x01" + struct.pack("<HH", len(raw), len(raw) ^ 0xFFFF) + raw + struct.pack(">I", zlib.adler32(raw))
    header = struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", stored) + chunk(b"IEND", b"")


def bmp() -> bytes:
    """BMP 1×1, 24 bit (loại ảnh Exam Suite không nhận)."""
    pixels = b"\x00\x00\xff\x00"  # một điểm ảnh BGR + đệm tới bội số 4 byte
    info = struct.pack("<IiiHHIIiiII", 40, 1, 1, 1, 24, 0, len(pixels), 2835, 2835, 0, 0)
    return b"BM" + struct.pack("<IHHI", 14 + len(info) + len(pixels), 0, 0, 14 + len(info)) + info + pixels


# GIF 1×1 tự dựng: header GIF89a, bảng màu 2 màu, một khối ảnh LZW tối thiểu.
GIF_1X1 = bytes.fromhex("47494638396101000100800000ff000000000021f90401000000002c00000000010001000002024401003b")

IMAGES = {
    "png-đỏ": lambda: png(0xC0, 0x30, 0x30),
    "png-xanh": lambda: png(0x20, 0x70, 0xC0),
    "gif-1x1": lambda: GIF_1X1,
    "bmp-1x1": bmp,
    "jpg-dau": lambda: bytes.fromhex("ffd8ffe000104a46494600010100000100010000ffd9"),
    "webp-dau": lambda: b"RIFF" + struct.pack("<I", 12) + b"WEBPVP8 " + bytes(4),
    "heic-dau": lambda: struct.pack(">I", 24) + b"ftypheic" + bytes(4) + b"mif1heic",
}


def encode_message(fields: list) -> bytes:
    out = bytearray()
    for number, kind, value in fields:
        if kind == "varint":
            out += key(number, 0) + varint(value)
        elif kind == "double":
            out += key(number, 1) + struct.pack("<d", value)
        elif kind == "fixed32":
            out += key(number, 5) + struct.pack("<I", value)
        elif kind == "string":
            out += length_delimited(number, value.encode("utf-8"))
        elif kind == "hex":
            out += length_delimited(number, bytes.fromhex(value))
        elif kind == "char":
            out += key(number, 0) + varint(ord(value))
        elif kind == "packed":
            out += length_delimited(number, b"".join(varint(ord(c)) for c in value))
        elif kind == "image":
            out += length_delimited(number, IMAGES[value]())
        elif kind == "message":
            out += length_delimited(number, encode_message(value))
        elif kind == "wire":
            wire_type, payload = value
            out += key(number, wire_type) + bytes.fromhex(payload)
        else:
            raise ValueError(f"kiểu trường lạ: {kind}")
    return bytes(out)


def build(spec: dict) -> bytes:
    data = bytes.fromhex(spec.get("prefix", "")) + encode_message(spec.get("message", []))
    if "truncate" in spec:
        data = data[: spec["truncate"]]
    return data


def sources() -> dict[str, dict]:
    return {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(SRC_DIR.glob("*.json"))}


def check() -> list[str]:
    problems = []
    specs = sources()
    if not specs:
        problems.append("fixtures/oef/src/ không có mô tả nào")
    for name, spec in specs.items():
        target = OEF_DIR / f"{name}.oef"
        if not target.exists():
            problems.append(f"thiếu fixtures/oef/{name}.oef (chạy scripts/make_oef.py)")
        elif target.read_bytes() != build(spec):
            problems.append(f"fixtures/oef/{name}.oef lệch với src/{name}.json (chạy scripts/make_oef.py)")
    for path in sorted(OEF_DIR.glob("*.oef")):
        if path.stem not in specs:
            problems.append(f"fixtures/oef/{path.name} không có mô tả trong src/")
    # Đối chứng âm: đổi một giá trị trong mô tả phải đổi byte, và cắt cụt phải ngắn hơn.
    probe = {"message": [[1, "message", [[1, "string", "Đề"], [4, "double", 700]]]]}
    changed = {"message": [[1, "message", [[1, "string", "Đề"], [4, "double", 701]]]]}
    if build(probe) == build(changed):
        problems.append("đối chứng âm: đổi ngưỡng đậu mà byte không đổi")
    if len(build({**probe, "truncate": 3})) != 3:
        problems.append("đối chứng âm: truncate không cắt đúng")
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="so file đã commit với mô tả, không ghi")
    args = parser.parse_args(argv)
    if args.check:
        problems = check()
        if problems:
            print("FAIL make_oef.py --check: " + "; ".join(problems))
            return 1
        print(f"OK make_oef.py --check: {len(sources())} file .oef khớp mô tả")
        return 0
    for name, spec in sources().items():
        (OEF_DIR / f"{name}.oef").write_bytes(build(spec))
        print(f"ghi fixtures/oef/{name}.oef")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
