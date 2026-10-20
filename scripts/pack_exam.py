#!/usr/bin/env python3
"""Đóng gói thư mục (exam.json + media/) thành file .exam (zip, deterministic).

Dùng: scripts/pack_exam.py <thư-mục-gói> [<thư-mục-đích>]
Tên file lấy từ `title` trong exam.json. Không kiểm tra schema; chạy
validate_exam.py trước. Định dạng: docs/product/exam-format.md.
"""
from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    src = Path(argv[0]).resolve()
    dest_dir = Path(argv[1]).resolve() if len(argv) > 1 else src.parent
    manifest = src / "exam.json"
    if not manifest.is_file():
        print(f"pack_exam.py: không thấy {manifest}")
        return 1
    title = json.loads(manifest.read_text(encoding="utf-8-sig"))["title"]
    safe = "".join(ch if ch.isalnum() or ch in " -_." else "_" for ch in title).strip() or "exam"
    dest_dir.mkdir(parents=True, exist_ok=True)
    out = dest_dir / f"{safe}.exam"
    files = [manifest] + sorted(p for p in (src / "media").rglob("*") if p.is_file()) if (src / "media").is_dir() else [manifest]
    fixed_time = (2026, 1, 1, 0, 0, 0)
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for p in files:
            info = zipfile.ZipInfo(p.relative_to(src).as_posix(), date_time=fixed_time)
            info.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(info, p.read_bytes())
    print(f"ok   {out} ({len(files)} file)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
