#!/usr/bin/env bash
# Chạy mọi kiểm tra máy làm được mà không cần xcodebuild. CI gọi cùng script này.
#   scripts/check.sh            # macOS hoặc Linux có swift + python3 (+ jsonschema)
#   scripts/check.sh --core     # chỉ phần chạy được trên Linux (ExamKit, schema, ranh giới)
# Bước 4 (chỉ macOS) cần Xcode được chọn: SwiftData @Model dùng macro plugin không có trong
# Command Line Tools. Phần cần xcodebuild (hai target app, XCUITest) xem AGENTS.md.
set -euo pipefail
cd "$(dirname "$0")/.."

PY=python3
if ! $PY -c "import jsonschema" >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    PY="uv run --with jsonschema>=4.18 python3"
  else
    echo "check.sh: cần gói Python jsonschema (pip install jsonschema) hoặc uv." >&2
    exit 2
  fi
fi

# Command Line Tools (không có Xcode) với Swift 6.4: build incremental thỉnh thoảng
# quên nạp macro plugin của Swift Testing ("plugin for module 'TestingMacros' not
# found"). Chỉ rõ thư mục plugin thì ổn định. Xcode và Linux không cần.
SWIFT_TEST_FLAGS=()
if [[ "$(uname -s)" == "Darwin" ]]; then
  PLUGINS="$(xcode-select -p 2>/dev/null)/usr/lib/swift/host/plugins/testing"
  if [[ "$(xcode-select -p 2>/dev/null)" == *CommandLineTools* && -d "$PLUGINS" ]]; then
    SWIFT_TEST_FLAGS=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
  fi
fi

echo "== 1/5 swift test Packages/ExamKit"
swift test --package-path Packages/ExamKit ${SWIFT_TEST_FLAGS[@]+"${SWIFT_TEST_FLAGS[@]}"}

echo "== 2/5 schema: fixtures hợp lệ đậu, fixtures/invalid rớt; script cùng kết luận với app"
$PY scripts/validate_exam.py --all
# Phía app của cùng bảng kỳ vọng (fixtures/expected-verdicts.json) đã chạy ở bước 1
# (ExamValidatorParityTests).
$PY scripts/check_validator_parity.py
# Đề chuẩn để đo (docs/product/large-exams.md): script sinh đúng đề mà test Swift dùng (cùng dấu vân tay với
# StandardExamTests ở bước 1), và đề sinh ra (exam.json + 200 ảnh) đậu schema + kiểm tra liên trường.
# Một lần sinh: --check so dấu vân tay (fixtures/large-exam.digest) rồi ghi đề đó ra thư mục tạm để kiểm schema.
LARGE_EXAM_DIR="$(mktemp -d)"
trap 'rm -rf "$LARGE_EXAM_DIR"' EXIT
$PY scripts/gen_large_exam.py --check --out "$LARGE_EXAM_DIR"
$PY scripts/validate_exam.py "$LARGE_EXAM_DIR"/de-chuan-*/

echo "== 3/5 ranh giới kiến trúc; chữ giao diện tra catalog của module (bundle: .module), catalog nguồn vi đủ bản en;"
echo "       sheet không chặn thoát app; màu tự định nghĩa chỉ ở bảng màu; bộ đọc dòng Timing của measure_large.sh;"
echo "       bảng map lớp UI test theo file đổi (uitest_plan.py); mức kiểm của verify_local.sh (verify_scope.py)"
$PY scripts/check_boundaries.py
# --require-en (bật từ giai đoạn 5 bước 7c): mọi khoá của mọi catalog có bản en đã dịch, đúng đối số, plural đủ one/other.
$PY scripts/check_localization.py --require-en
$PY scripts/check_quit_sheets.py
$PY scripts/check_colors.py
scripts/measure_large.sh --check-parser
$PY scripts/uitest_plan.py --self-test
$PY scripts/verify_scope.py --self-test

if [[ "${1:-}" == "--core" || "$(uname -s)" != "Darwin" ]]; then
  echo "== 4/5 bỏ qua swift test Packages/SharedFeatures, Packages/ExamFeatures (chỉ macOS)"
  echo "== 5/5 bỏ qua kiểm catalog đủ khoá (cần xcstringstool của Xcode)"
else
  # Phần dùng chung macOS và iOS (LibraryDataTests), rồi giao diện macOS. SwiftData @Model cần macro plugin của Xcode;
  # chỉ có Command Line Tools thì bước này không biên dịch được (xem AGENTS.md).
  echo "== 4/5 swift test Packages/SharedFeatures, Packages/ExamFeatures"
  swift test --package-path Packages/SharedFeatures ${SWIFT_TEST_FLAGS[@]+"${SWIFT_TEST_FLAGS[@]}"}
  swift test --package-path Packages/ExamFeatures ${SWIFT_TEST_FLAGS[@]+"${SWIFT_TEST_FLAGS[@]}"}
  # Khoá chuỗi trong code (.stringsdata của lần build vừa rồi) khớp Localizable.xcstrings đã commit; verify_local.sh
  # còn kiểm bằng xcodebuild -exportLocalizations (gồm InfoPlist.xcstrings).
  # Chỉ ở CI GitHub (CI=true) mới cho phép thiếu .stringsdata: runner có thể chọn Xcode 16, mà SwiftPM của nó build bằng
  # hệ native không ghi .stringsdata. Trên Mac của người điều phối (Xcode 27, hệ swiftbuild) thiếu là lỗi.
  FRESHNESS_FLAGS=()
  [[ "${CI:-}" == "true" ]] && FRESHNESS_FLAGS=(--allow-missing-stringsdata)
  echo "== 5/5 catalog đủ khoá (xcstringstool sync trên bản sao)"
  $PY scripts/check_localization.py --require-en --freshness Packages/ExamFeatures/.build ${FRESHNESS_FLAGS[@]+"${FRESHNESS_FLAGS[@]}"}
fi
echo "== OK"
