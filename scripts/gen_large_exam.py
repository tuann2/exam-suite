#!/usr/bin/env python3
"""Sinh đề chuẩn để đo hiệu năng (docs/product/large-exams.md, mục "Đề chuẩn để đo").

Dùng:
  scripts/gen_large_exam.py [--seed N] [--questions N] [--sections N] [--out THƯ-MỤC]
      Ghi THƯ-MỤC/<slug>/ (exam.json + media/, để chạy validate_exam.py) và THƯ-MỤC/<tên đề>.exam
      (đóng gói như pack_exam.py) để mở tay bằng app. Mặc định: seed 20261016, 2000 câu, 20 phần, dist/.
  scripts/gen_large_exam.py --digest [--seed N] [--questions N] [--sections N]
      Chỉ in dấu vân tay (SHA-256 của dạng chính tắc) của đề, không ghi file.
  scripts/gen_large_exam.py --check [--out THƯ-MỤC]
      So dấu vân tay của đề chuẩn mặc định với fixtures/large-exam.digest (vector cố định, một file dùng chung).
      Test Swift `StandardExamTests` (bộ sinh `StandardExam`, Packages/ExamKit/Sources/LargeExamSupport) đọc cùng
      file đó, nên script và test Swift sinh **cùng một đề** (cùng id, chữ, đáp án, cùng byte ảnh). Có đối chứng
      âm: đề sửa một ký tự phải lệch dấu vân tay. Có `--out` thì ghi luôn đề vừa kiểm (scripts/check.sh dùng để
      chạy validate_exam.py mà không sinh đề lần hai).

Đề chuẩn (cùng seed thì cùng byte):
- `questions` câu chia đều cho `sections` phần (phần đầu nhận câu dư); 20% câu nhiều đáp án (2–3 đáp án
  đúng khi 4 lựa chọn, 2–4 khi nhiều lựa chọn); mọi câu 4 lựa chọn, riêng 5% câu có 8–12 lựa chọn.
- Nội dung câu 200–600 ký tự (code point), tiếng Việt có dấu xen tiếng Anh, có Markdown đậm/nghiêng; 50% câu
  có giải thích.
- 10% câu có ảnh PNG 1600×1000 xám, nhiễu giả ngẫu nhiên (không nén được như ảnh chụp), xen kẽ 1 bit
  (~196 KB) và 2 bit (~392 KB) mỗi điểm ảnh, trung bình ~300 KB; mọi ảnh khác nhau, tên là 16 ký tự hex đầu
  SHA-256 nội dung (exam-format.md). Zlib của ảnh chỉ dùng khối "stored" (không nén) để byte giống hệt
  phía Swift trên mọi nền tảng.

Thuật toán (phải giữ đúng thứ tự rút số ngẫu nhiên; phía Swift làm y hệt):
  rng = SplitMix64(seed)  (ExamKit.SeededGenerator: next(), nextInt(below:) rejection sampling)
  id đề = uuid(rng); bốn hoán vị Fisher–Yates của 0..<n (nhiều đáp án, nhiều lựa chọn, có ảnh, có giải thích),
  lấy n*20/100, n*5/100, n*10/100, n*50/100 phần tử đầu; rồi từng phần: id phần; từng câu: id câu, số lựa
  chọn (nếu nhiều lựa chọn: 8 + nextInt(5)), nội dung, từng lựa chọn, đáp án đúng, giải thích (nếu có).
  Ảnh thứ m (theo thứ tự câu) lấy dải byte từ một khối nhiễu 1 MiB sinh bằng SplitMix64(seed ^ PNG_SALT).

Công cụ dev, chỉ thư viện chuẩn của Python. File sinh ra là sản phẩm build (dist/ đã ở .gitignore), không commit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import sys
import unicodedata
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import pack_exam  # noqa: E402  (cùng thư mục scripts/)

DEFAULT_SEED = 20261016
DEFAULT_QUESTIONS = 2000
DEFAULT_SECTIONS = 20
# SHA-256 của dạng chính tắc (canonical_text) của đề chuẩn mặc định; file một dòng, `StandardExamTests` (ExamFileTests)
# đọc cùng file. Đổi bộ sinh thì sinh lại (`--digest`) và ghi file này trong cùng PR với phần Swift.
DIGEST_FILE = ROOT / "fixtures" / "large-exam.digest"

MASK64 = (1 << 64) - 1
GAMMA = 0x9E3779B97F4A7C15
MIX1 = 0xBF58476D1CE4E5B9
MIX2 = 0x94D049BB133111EB
PNG_SALT = 0x4C41524745504E47  # "LARGEPNG"
POOL_BYTES = 1 << 20
IMAGE_WIDTH = 1600
IMAGE_HEIGHT = 1000
IMAGE_STRIDE = 104_729  # số lẻ: điểm bắt đầu trong khối nhiễu của các ảnh khác nhau (mod 2^20)

TOPICS = [
    "An toàn thông tin", "Mạng máy tính", "Hệ điều hành", "Cơ sở dữ liệu", "Lập trình Swift",
    "Kiểm thử phần mềm", "Quản lý dự án", "Điện toán đám mây", "Kiến trúc hệ thống", "Trải nghiệm người dùng",
    "Pháp luật về dữ liệu", "Kế toán cơ bản", "Kỹ năng giao tiếp", "Tiếng Anh chuyên ngành", "Quy trình nội bộ",
    "Phần cứng máy tính", "Trí tuệ nhân tạo", "Bảo trì hệ thống", "Văn hoá doanh nghiệp", "Chăm sóc khách hàng",
]

FRAGMENTS = [
    "Theo quy định hiện hành của công ty, nhân viên phải đổi mật khẩu định kỳ.",
    "Khi phát hiện email đáng ngờ, người dùng nên báo ngay cho bộ phận hỗ trợ.",
    "Hệ thống sao lưu chạy lúc nửa đêm và giữ bản sao trong ba mươi ngày.",
    "Trưởng nhóm chịu trách nhiệm duyệt mọi thay đổi trước khi triển khai.",
    "Dữ liệu khách hàng chỉ được lưu trên máy chủ đặt tại Việt Nam.",
    "Mỗi phiên làm việc tự khoá sau mười lăm phút không thao tác.",
    "Tài liệu nội bộ được phân loại theo bốn mức độ bảo mật khác nhau.",
    "Bản vá bảo mật cần được cài đặt trong vòng bảy ngày kể từ khi phát hành.",
    "Người dùng không được tự ý cài phần mềm lạ lên máy tính của công ty.",
    "Mọi yêu cầu cấp quyền truy cập phải có lý do rõ ràng và thời hạn.",
    "Biên bản họp được lưu trong thư mục chung của phòng ban.",
    "Khách hàng có quyền yêu cầu xoá dữ liệu cá nhân của mình.",
    "Ổ đĩa của máy xách tay phải được mã hoá toàn bộ.",
    "Nhật ký truy cập được giữ tối thiểu mười hai tháng.",
    "Đường truyền dự phòng tự động bật khi đường chính gặp sự cố.",
    "Câu hỏi này kiểm tra hiểu biết về quy trình xử lý sự cố.",
    "Hãy chọn phương án phù hợp nhất với tình huống được mô tả.",
    "Giả sử bạn là quản trị viên hệ thống của một chi nhánh nhỏ.",
    "Trong tình huống khẩn cấp, ưu tiên hàng đầu là an toàn của con người.",
    "Kết quả kiểm tra định kỳ được báo cáo cho ban giám đốc mỗi quý.",
    "Mật khẩu mạnh gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.",
    "Thiết bị lưu trữ di động phải được quét virus trước khi sử dụng.",
    "Phần mềm diệt virus cập nhật mẫu nhận diện hằng ngày.",
    "Quyền quản trị chỉ được cấp cho số ít người có nhu cầu thực sự.",
    "Mọi giao dịch trên hệ thống đều được ghi lại kèm thời điểm thực hiện.",
    "Đề thi gồm nhiều phần, mỗi phần tập trung vào một chủ đề riêng.",
    "Ảnh minh hoạ bên dưới mô tả sơ đồ mạng của văn phòng.",
    "Lưu ý đọc kỹ các từ phủ định như không, chưa và chẳng.",
    "Thời hạn hoàn thành báo cáo là ngày làm việc cuối cùng của tháng.",
    "Cuộc họp tổng kết diễn ra vào sáng thứ Hai đầu tiên của quý.",
    "The firewall blocks all inbound traffic except approved ports.",
    "Use multi-factor authentication for every remote login.",
    "A backup is only useful if it can be restored on time.",
    "Least privilege means granting only the access a task requires.",
    "Phishing emails often create a false sense of urgency.",
    "Log files must not contain passwords or personal data.",
    "Patch management reduces the window of known vulnerabilities.",
    "Incident response starts with containment and clear communication.",
]

OPTION_TERMS = [
    "Báo ngay cho bộ phận hỗ trợ", "Đổi mật khẩu ngay lập tức", "Tắt máy và chờ hướng dẫn",
    "Gửi email cho trưởng nhóm", "Ghi lại sự việc vào nhật ký", "Bỏ qua và tiếp tục làm việc",
    "Cài lại hệ điều hành", "Ngắt kết nối mạng", "Chuyển tiếp email cho đồng nghiệp", "Liên hệ khách hàng",
    "Mã hoá toàn bộ ổ đĩa", "Sao lưu dữ liệu quan trọng", "Kiểm tra lại quyền truy cập",
    "Cập nhật phần mềm diệt virus", "Xoá tệp đáng ngờ", "Khởi động lại máy chủ", "Tạo phiếu yêu cầu hỗ trợ",
    "Đọc lại quy định nội bộ", "Hỏi ý kiến bộ phận pháp lý", "Chờ đến cuộc họp tuần sau",
    "Enable multi-factor authentication", "Restore from the latest backup", "Escalate to the security team",
    "Rotate the API keys", "Review the access logs", "Disable the compromised account",
]

QUALIFIERS = [
    "trong vòng một giờ", "trước khi rời văn phòng", "theo đúng quy trình", "sau khi được duyệt",
    "nếu có thể", "càng sớm càng tốt", "trong ngày làm việc", "khi có yêu cầu", "mỗi tuần một lần",
    "ngay khi phát hiện", "as soon as possible", "after approval", "within 24 hours", "by default",
]


class SplitMix64:
    """Bản Python của ExamKit.SeededGenerator (SplitMix64); cùng seed cho cùng dãy số."""

    def __init__(self, seed: int) -> None:
        self.state = seed & MASK64

    def next(self) -> int:
        self.state = (self.state + GAMMA) & MASK64
        z = self.state
        z = ((z ^ (z >> 30)) * MIX1) & MASK64
        z = ((z ^ (z >> 27)) * MIX2) & MASK64
        return z ^ (z >> 31)

    def next_int(self, bound: int) -> int:
        """0..<bound không lệch (rejection sampling như SeededGenerator.nextInt(below:))."""
        assert bound > 0
        threshold = ((1 << 64) - bound) % bound
        while True:
            r = self.next()
            if r >= threshold:
                return r % bound


def make_uuid(rng: SplitMix64) -> str:
    raw = bytearray(rng.next().to_bytes(8, "big") + rng.next().to_bytes(8, "big"))
    raw[6] = (raw[6] & 0x0F) | 0x40  # phiên bản 4
    raw[8] = (raw[8] & 0x3F) | 0x80  # biến thể RFC 4122
    h = raw.hex()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


def permutation(n: int, rng: SplitMix64) -> list[int]:
    items = list(range(n))
    for i in range(n - 1, 0, -1):
        j = rng.next_int(i + 1)
        items[i], items[j] = items[j], items[i]
    return items


def paragraph(rng: SplitMix64, prefix: str, min_length: int, spread: int) -> str:
    """Nối các câu mẫu (1/8 đậm, 1/8 nghiêng) tới khi đủ độ dài đích (code point)."""
    target = min_length + rng.next_int(spread + 1)
    text = prefix
    while len(text) < target:
        fragment = FRAGMENTS[rng.next_int(len(FRAGMENTS))]
        style = rng.next_int(8)
        if style == 0:
            fragment = f"**{fragment}**"
        elif style == 1:
            fragment = f"*{fragment}*"
        text = f"{text} {fragment}" if text else fragment
    return text


def letter(index: int) -> str:
    return chr(ord("A") + index)


# ---------------------------------------------------------------- ảnh PNG


def noise_pool(seed: int) -> bytes:
    rng = SplitMix64(seed ^ PNG_SALT)
    return b"".join(rng.next().to_bytes(8, "little") for _ in range(POOL_BYTES // 8))


def _chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def png_image(pool: bytes, ordinal: int) -> bytes:
    """Ảnh thứ `ordinal`: xám 1 bit (chẵn) hoặc 2 bit (lẻ), mỗi hàng bộ lọc 0 + dải byte của khối nhiễu."""
    depth = 1 if ordinal % 2 == 0 else 2
    row_bytes = IMAGE_WIDTH * depth // 8
    offset = (ordinal * IMAGE_STRIDE) % POOL_BYTES
    raw = bytearray()
    for _ in range(IMAGE_HEIGHT):
        raw.append(0)
        end = offset + row_bytes
        if end <= POOL_BYTES:
            raw += pool[offset:end]
        else:
            raw += pool[offset:] + pool[: end - POOL_BYTES]
        offset = end % POOL_BYTES
    # Zlib: đầu 0x78 0x01, các khối stored ≤ 65535 byte, Adler-32 big-endian.
    stream = bytearray(b"\x78\x01")
    position = 0
    while True:
        block = raw[position : position + 65535]
        position += len(block)
        final = position >= len(raw)
        stream.append(1 if final else 0)
        stream += struct.pack("<HH", len(block), len(block) ^ 0xFFFF)
        stream += block
        if final:
            break
    stream += struct.pack(">I", zlib.adler32(bytes(raw)) & 0xFFFFFFFF)
    header = struct.pack(">IIBBBBB", IMAGE_WIDTH, IMAGE_HEIGHT, depth, 0, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", header) + _chunk(b"IDAT", bytes(stream)) + _chunk(b"IEND", b"")


def media_name(data: bytes) -> str:
    return f"media/{hashlib.sha256(data).hexdigest()[:16]}.png"


# ---------------------------------------------------------------- đề


def generate(seed: int, questions: int, sections: int) -> tuple[dict, dict[str, bytes]]:
    """Trả về (exam.json dạng dict, {"media/<tên>": byte ảnh})."""
    if questions < sections or sections < 1:
        raise ValueError("cần sections ≥ 1 và questions ≥ sections")
    rng = SplitMix64(seed)
    exam_id = make_uuid(rng)
    n = questions
    multiple = set(permutation(n, rng)[: n * 20 // 100])
    many_options = set(permutation(n, rng)[: n * 5 // 100])
    with_image = set(permutation(n, rng)[: n * 10 // 100])
    with_explanation = set(permutation(n, rng)[: n * 50 // 100])
    pool = noise_pool(seed) if with_image else b""

    media: dict[str, bytes] = {}
    out_sections = []
    base, extra = divmod(n, sections)
    k = 0
    for s in range(sections):
        section_id = make_uuid(rng)
        out_questions = []
        for _ in range(base + (1 if s < extra else 0)):
            question_id = make_uuid(rng)
            option_count = 8 + rng.next_int(5) if k in many_options else 4
            text = paragraph(rng, f"Câu {k + 1}.", 200, 300)
            options = [
                {"id": letter(i), "text": f"{OPTION_TERMS[rng.next_int(len(OPTION_TERMS))]} "
                                         f"{QUALIFIERS[rng.next_int(len(QUALIFIERS))]}"}
                for i in range(option_count)
            ]
            if k in multiple:
                max_correct = 3 if option_count == 4 else 4
                count = 2 + rng.next_int(max_correct - 1)
                indices = list(range(option_count))
                for i in range(count):
                    j = i + rng.next_int(option_count - i)
                    indices[i], indices[j] = indices[j], indices[i]
                correct = [letter(i) for i in sorted(indices[:count])]
            else:
                correct = [letter(rng.next_int(option_count))]
            question: dict = {
                "id": question_id,
                "type": "multiple" if k in multiple else "single",
                "text": text,
            }
            if k in with_image:
                data = png_image(pool, len(media))
                name = media_name(data)
                media[name] = data
                question["image"] = name
            question["options"] = options
            question["correct"] = correct
            if k in with_explanation:
                question["explanation"] = paragraph(rng, "", 60, 140)
            out_questions.append(question)
            k += 1
        out_sections.append({
            "id": section_id,
            "title": f"Phần {s + 1}: {TOPICS[s % len(TOPICS)]}",
            "questions": out_questions,
        })
    exam = {
        "formatVersion": 1,
        "id": exam_id,
        "title": f"Đề chuẩn {n} câu (seed {seed})",
        "code": f"DECHUAN-{n}",
        "passPercent": 70,
        "timeLimitMinutes": 180,
        "hideAnswers": False,
        "instructions": "Đề sinh tự động để đo hiệu năng (docs/product/large-exams.md). **Không** dùng để thi thật.",
        "sections": out_sections,
    }
    return exam, media


def canonical_text(exam: dict, media: dict[str, bytes]) -> str:
    """Dạng chính tắc (mỗi dòng một đối tượng, tab ngăn trường); phía Swift: StandardExam.canonicalText."""
    lines = [
        "\t".join(["exam", exam["id"], exam["title"], exam.get("code", ""), str(exam["passPercent"]),
                   str(exam["timeLimitMinutes"]), "1" if exam.get("hideAnswers") else "0",
                   exam.get("instructions", "")])
    ]
    for section in exam["sections"]:
        lines.append("\t".join(["section", section["id"], section["title"]]))
        for q in section["questions"]:
            lines.append("\t".join(["question", q["id"], q["type"], q["text"], q.get("image", ""),
                                    ",".join(q["correct"]), q.get("explanation", "")]))
            lines += ["\t".join(["option", o["id"], o["text"]]) for o in q["options"]]
    lines += [f"media\t{name}\t{len(media[name])}" for name in sorted(media)]
    return "\n".join(lines) + "\n"


def digest(exam: dict, media: dict[str, bytes]) -> str:
    return hashlib.sha256(canonical_text(exam, media).encode("utf-8")).hexdigest()


def write(exam: dict, media: dict[str, bytes], out: Path, slug: str) -> tuple[Path, Path]:
    """Ghi out/<slug>/ (exam.json + media/) rồi đóng gói thành out/<tên đề>.exam bằng pack_exam.py."""
    directory = out / slug
    if directory.exists():
        shutil.rmtree(directory)
    (directory / "media").mkdir(parents=True)
    (directory / "exam.json").write_text(json.dumps(exam, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for name, data in media.items():
        (directory / name).write_bytes(data)
    if pack_exam.main([str(directory), str(out)]) != 0:
        raise SystemExit("gen_large_exam.py: đóng gói thất bại")
    title = exam["title"]
    safe = "".join(ch if ch.isalnum() or ch in " -_." else "_" for ch in title).strip() or "exam"
    return directory, out / f"{safe}.exam"


def expected_digest() -> str:
    return DIGEST_FILE.read_text(encoding="utf-8").strip()


def self_check(out: Path | None) -> int:
    for group in (TOPICS, FRAGMENTS, OPTION_TERMS, QUALIFIERS):
        for value in group:
            if not unicodedata.is_normalized("NFC", value):
                print(f"FAIL gen_large_exam.py: chuỗi mẫu chưa ở dạng NFC: {value!r}")
                return 1
    exam, media = generate(DEFAULT_SEED, DEFAULT_QUESTIONS, DEFAULT_SECTIONS)
    questions = [q for s in exam["sections"] for q in s["questions"]]
    stats = {
        "câu": len(questions),
        "nhiều đáp án": sum(q["type"] == "multiple" for q in questions),
        "8–12 lựa chọn": sum(len(q["options"]) >= 8 for q in questions),
        "có ảnh": sum("image" in q for q in questions),
        "có giải thích": sum("explanation" in q for q in questions),
        "ảnh": len(media),
    }
    expected = {"câu": 2000, "nhiều đáp án": 400, "8–12 lựa chọn": 100, "có ảnh": 200, "có giải thích": 1000,
                "ảnh": 200}
    lengths = [len(q["text"]) for q in questions]
    problems = [f"{key}: {stats[key]} ≠ {value}" for key, value in expected.items() if stats[key] != value]
    if not (200 <= min(lengths) and max(lengths) <= 600):
        problems.append(f"độ dài nội dung câu {min(lengths)}–{max(lengths)} ngoài 200–600")
    expected_value = expected_digest()
    actual = digest(exam, media)
    if actual != expected_value:
        problems.append(f"dấu vân tay {actual} ≠ {DIGEST_FILE.relative_to(ROOT)} {expected_value} (đổi bộ sinh thì "
                        "đổi cả StandardExam phía Swift và file dấu vân tay)")
    # Đối chứng âm: sửa một ký tự của một câu hay một byte ảnh thì dấu vân tay phải lệch.
    mutated = json.loads(json.dumps(exam))
    mutated["sections"][0]["questions"][0]["text"] += "."
    renamed = dict(media)
    first = sorted(renamed)[0]
    renamed[first] = renamed[first] + b"\0"
    if digest(mutated, media) == expected_value or digest(exam, renamed) == expected_value:
        problems.append("đối chứng âm: đề đã sửa vẫn trùng dấu vân tay (canonical_text không phủ nội dung)")
    if problems:
        print("FAIL gen_large_exam.py --check: " + "; ".join(problems))
        return 1
    size = sum(len(d) for d in media.values())
    print(f"ok   đề chuẩn seed {DEFAULT_SEED}: {stats}, ảnh {size / 1e6:.1f} MB, dấu vân tay {actual} "
          f"= {DIGEST_FILE.relative_to(ROOT)} (đối chứng âm bị bắt)")
    if out is not None:
        directory, _ = write(exam, media, out.resolve(), f"de-chuan-{DEFAULT_QUESTIONS}-seed-{DEFAULT_SEED}")
        print(f"     đã ghi {directory}")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--questions", type=int, default=DEFAULT_QUESTIONS)
    parser.add_argument("--sections", type=int, default=DEFAULT_SECTIONS)
    parser.add_argument("--out", type=Path, default=None, help="thư mục ghi (mặc định dist/; với --check: không ghi)")
    parser.add_argument("--digest", action="store_true", help="chỉ in dấu vân tay, không ghi file")
    parser.add_argument("--check", action="store_true", help="so đề chuẩn mặc định với fixtures/large-exam.digest")
    args = parser.parse_args(argv)
    if args.check:
        return self_check(args.out)
    if not 0 <= args.seed <= MASK64:
        parser.error("seed phải trong 0…2^64−1")
    exam, media = generate(args.seed, args.questions, args.sections)
    if args.digest:
        print(digest(exam, media))
        return 0
    out = args.out if args.out is not None else ROOT / "dist"
    directory, package = write(exam, media, out.resolve(), f"de-chuan-{args.questions}-seed-{args.seed}")
    print(f"ok   {directory} (exam.json + {len(media)} ảnh); dấu vân tay {digest(exam, media)}")
    print(f"     kiểm: python3 scripts/validate_exam.py {directory}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
