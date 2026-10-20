#!/usr/bin/env bash
# Đo đề lớn ở bản Release (docs/product/large-exams.md, mục Cách đo): build Release và chạy các test `Timing` của
# hai package với đề chuẩn (2.000 câu, 200 ảnh, sinh trong test bằng LargeExamSupport, cùng đề với
# scripts/gen_large_exam.py), rồi thêm một mục (ngày, máy, commit, bảng số) vào docs/notes/large-exam-measurements.md.
#
#   scripts/measure_large.sh                # đo và ghi vào file số đo
#   scripts/measure_large.sh --no-write     # chỉ in bảng
#   scripts/measure_large.sh --check-parser # chỉ tự kiểm bộ đọc dòng `Timing:` (không swift; check.sh gọi, cả Linux)
#
# Số Release chỉ ghi, không chặn merge (large-exams.md phương án 3); giới hạn chặn Debug nằm trong chính các test
# (scripts/check.sh). Cần macOS có Xcode (SwiftData của ExamFeatures). Không mở app, không chạm kho hay defaults thật:
# test dùng thư mục tạm và kho trong bộ nhớ. Chạy khi máy rảnh để số ổn định.
set -euo pipefail
cd "$(dirname "$0")/.."

WRITE=1
MODE=measure
if [[ "${1:-}" == "--no-write" ]]; then WRITE=0; fi
if [[ "${1:-}" == "--check-parser" ]]; then MODE=check; fi
if [[ $MODE == measure && "$(uname -s)" != "Darwin" ]]; then
  echo "measure_large.sh: cần macOS có Xcode" >&2
  exit 2
fi
if [[ "$(xcode-select -p 2>/dev/null)" == *CommandLineTools* && -z "${DEVELOPER_DIR:-}" ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

parse_timing() { # $1: chế độ (check|measure), $2: log, $3: ghi file (1|0)
  python3 - "$@" <<'PY'
import datetime, platform, re, subprocess, sys
from pathlib import Path

FIELDS = ("min", "median", "max", "runs", "gate", "worst-event", "budget", "limit")


def parse(lines: list[str]) -> tuple[list[dict[str, str]], list[str]]:
    """(các dòng bảng, các dòng `Timing:` sai dạng). Dạng đúng (`TimingSample.line` của LargeExamSupport):
    Timing: <id> | <tên> | min … | median … | max … | runs … | gate … | worst-event … | budget … | limit … | <cấu hình>
    Dòng sai dạng (in tay trong test, thiếu cột) bị bỏ qua và báo, không làm hỏng cả bảng."""
    rows: list[dict[str, str]] = []
    malformed: list[str] = []
    for line in lines:
        if not line.startswith("Timing: "):
            continue
        parts = [p.strip() for p in line[len("Timing: "):].split(" | ")]
        fields = dict(p.split(" ", 1) for p in parts[2:-1] if " " in p)
        if len(parts) != 2 + len(FIELDS) + 1 or tuple(fields) != FIELDS or not parts[0] or not parts[1]:
            malformed.append(line)
            continue
        rows.append({"id": parts[0], "label": parts[1], "config": parts[-1], **fields})
    return rows, malformed


def self_test() -> None:
    good = ("Timing: a.b | Thao tác A | min 1.00 ms | median 2.00 ms | max 3.00 ms | runs 3 | gate min | "
            "worst-event — | budget 10.00 ms | limit 20.00 ms | Release")
    # Mỗi phép kiểm của parse() có ít nhất một dòng chỉ nó bắt: số cột (cột thừa ở cuối), tên các trường (trường
    # dính chữ), mã/tên mục rỗng.
    bad = ["Timing: report.size 1175 trang, 108 MB", "Timing: x | y", "Timing: ",
           good.replace(" | gate min", ""),
           good + " | thừa",
           good.replace("median 2.00 ms", "median2.00ms"),
           good.replace("Timing: a.b |", "Timing:  |"),
           good.replace("| Thao tác A |", "|  |")]
    rows, malformed = parse(["khác", good, *bad])
    assert [r["id"] for r in rows] == ["a.b"] and rows[0]["median"] == "2.00 ms" and rows[0]["config"] == "Release", rows
    assert malformed == bad, malformed


self_test()
mode = sys.argv[1]
if mode == "check":
    print("ok   measure_large.sh: bộ đọc dòng Timing (dòng sai dạng bị bỏ qua và báo, đối chứng âm bị bắt)")
    sys.exit(0)
log, write = Path(sys.argv[2]), sys.argv[3] == "1"
rows, malformed = parse(log.read_text(encoding="utf-8").splitlines())
for line in malformed:
    print(f"measure_large.sh: bỏ qua dòng Timing sai dạng (sửa test in ra nó): {line}", file=sys.stderr)
if not rows or any(r["config"] != "Release" for r in rows):
    sys.exit("measure_large.sh: không có dòng Timing nào của bản Release trong " + str(log))

def ms(text: str) -> float | None:
    return None if text == "—" else float(text.split()[0])

def fmt(value: float | None) -> str:
    """Cách viết số tiếng Việt: dấu chấm ngăn nghìn, dấu phẩy thập phân (1.500 ms, 1,59 ms)."""
    if value is None:
        return "—"
    if value >= 100 or value == int(value):
        return f"{value:,.0f} ms".replace(",", ".")
    return f"{value:.2f} ms".replace(".", ",")

def run(*cmd: str) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "?"

commit = run("git", "rev-parse", "--short", "HEAD")
if run("git", "status", "--porcelain"):
    commit += " (có thay đổi chưa commit)"
memory = run("sysctl", "-n", "hw.memsize")
machine = (f"{run('sysctl', '-n', 'machdep.cpu.brand_string')}, "
           f"{int(memory) // 2**30 if memory.isdigit() else '?'} GB RAM, macOS {platform.mac_ver()[0]}, "
           f"{run('xcodebuild', '-version').splitlines()[0] if run('xcodebuild', '-version') != '?' else 'Xcode ?'}")
lines = [
    f"## {datetime.date.today().isoformat()} · commit {commit}",
    "",
    f"Máy: {machine}. Lệnh: `scripts/measure_large.sh` (`EXAMSUITE_MEASURE_RECORD=1 swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter Timing`).",
    "",
    "| Thao tác (đề chuẩn) | Mã | Ngân sách Release | Trung vị | Nhanh nhất | Chậm nhất | Sự kiện chậm nhất | Số lần "
    "| So ngân sách |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
]
for r in rows:
    budget, median = ms(r["budget"]), ms(r["median"])
    verdict = "đạt" if median <= budget else f"**vượt** ({median / budget:.1f}×)".replace(".", ",")
    lines.append(f"| {r['label']} | `{r['id']}` | ≤ {fmt(budget)} | {fmt(median)} | {fmt(ms(r['min']))} | "
                 f"{fmt(ms(r['max']))} | {fmt(ms(r.get('worst-event', '—')))} | {r['runs']} | {verdict} |")
section = "\n".join(lines) + "\n"
print()
print(section)
if write:
    target = Path("docs/notes/large-exam-measurements.md")
    header = (
        "# Số đo đề lớn (Release)\n\n"
        "Ghi bởi `scripts/measure_large.sh`; mục mới nhất ở trên. Ngân sách và cách đo: "
        "[large-exams.md](../product/large-exams.md). Số Release chỉ ghi, không chặn merge (phương án 3); giới hạn "
        "chặn Debug nằm trong các test `Timing` chạy ở `scripts/check.sh`. \"Trung vị\" so với ngân sách; "
        "\"Nhanh nhất\" là số các test so với giới hạn chặn Debug (Nt0 chốt 2026-10-16; riêng mẫu nhiều biến thể như "
        "chữ tìm thì so \"Chậm nhất\"). \"Sự kiện chậm nhất\" là một sự kiện đơn lẻ (đổi câu, phím) chậm nhất. Mục \"thành phần\" là một phần của thao tác người "
        "dùng, mang ngân sách của thao tác đó. Mục không có ở đây (mở app, cuộn, bộ nhớ) đo tay. Tên mục PDF ghi số trang và "
        "cỡ file.\n\n"
    )
    # Giữ các mục cũ (từ tiêu đề "## " đầu tiên), mục mới lên đầu.
    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    previous = existing[existing.index("\n## ") + 1:] if "\n## " in existing else ""
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(header + section + ("\n" + previous if previous else ""), encoding="utf-8")
    print(f"đã ghi {target}")
PY
}

if [[ $MODE == check ]]; then
  parse_timing check
  exit 0
fi

LOG_DIR=build/measure-large
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/timing-$(date +%Y%m%d-%H%M%S).log"
: > "$LOG"

# -enable-testing: các test dùng `@testable import` (bản Release mặc định không bật). -DDEBUG: vài test (chế độ cô lập
# của UI test, AppLaunchStorageTests) dùng code chỉ có ở Debug nên thiếu cờ thì test target không biên dịch; code đó
# không nằm trên đường đo (chỉ lúc mở app và đồng hồ của UI test). Bản đo vẫn tối ưu -O; dòng "Timing:" ghi Release
# theo mức tối ưu (Timing.buildConfiguration). EXAMSUITE_MEASURE_RECORD=1: bật các mục chỉ ghi số mà swift test
# thường bỏ qua (in thật ra file, PDF đề chỉ đề; Timing.recordsExtraMeasurements).
for pkg in ExamKit ExamFeatures; do
  echo "== swift test -c release Packages/$pkg (--filter Timing; build Release lần đầu mất vài phút)"
  if ! EXAMSUITE_MEASURE_RECORD=1 swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --package-path "Packages/$pkg" --filter Timing >>"$LOG" 2>&1; then
    grep -E '✘|error:' "$LOG" | tail -20 >&2 || true
    echo "measure_large.sh: swift test Packages/$pkg thất bại; xem $LOG" >&2
    exit 1
  fi
done
grep -E '^Timing: ' "$LOG"
parse_timing measure "$LOG" "$WRITE"
