#!/usr/bin/env bash
# Bản Release của hai app không chứa code chế độ cô lập của UI test (LibraryData/AppLaunchStorage.swift: mọi tham số
# `-ExamSuiteUITest…` và móc file thay hộp chọn file của bản Admin nằm trong `#if DEBUG`). Kiểm trên binary: không file
# nào trong `Contents/MacOS` và `Contents/Frameworks` của bản Release có chuỗi `ExamSuiteUITest`.
#
# Đối chứng âm: bản Debug (cùng code, có `#if DEBUG`) PHẢI có chuỗi đó, để lỗi của chính bước kiểm (sai đường dẫn, grep
# không đọc được binary…) không làm bước này đạt mà không kiểm gì.
#
#   scripts/check_release_strings.sh <thư mục Products/Release> <thư mục Products/Debug>
#
# scripts/verify_local.sh build Release hai scheme vào build/DerivedData-Release rồi gọi script này với
# build/DerivedData/Build/Products/Debug làm đối chứng.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "dùng: $0 <Products/Release> <Products/Debug>" >&2
  exit 2
fi
release="$1"
debug="$2"
needle="ExamSuiteUITest"
apps=("Exam Suite.app" "Exam Suite Admin.app")

count_in_app() { # app; in số file trong app có chuỗi (dừng nếu app không có hoặc không có binary)
  local app="$1" files=() file found=0
  [[ -d "$app/Contents/MacOS" ]] || { echo "không có $app/Contents/MacOS" >&2; return 2; }
  while IFS= read -r -d '' file; do files+=("$file"); done \
    < <(find "$app/Contents/MacOS" "$app/Contents/Frameworks" -type f -print0 2>/dev/null)
  [[ ${#files[@]} -gt 0 ]] || { echo "không có file nào trong $app/Contents/MacOS" >&2; return 2; }
  for file in "${files[@]}"; do
    if LC_ALL=C grep -aqF "$needle" "$file"; then
      found=$((found + 1))
      echo "  có $needle: ${file#"$app/"}" >&2
    fi
  done
  echo "$found"
}

status=0
for name in "${apps[@]}"; do
  n="$(count_in_app "$debug/$name" 2>/dev/null)" || { count_in_app "$debug/$name" >/dev/null; exit 2; }
  if [[ "$n" == 0 ]]; then
    echo "FAIL đối chứng âm: bản Debug $name không có $needle (bước kiểm không đọc đúng binary?)" >&2
    status=1
    continue
  fi
  n="$(count_in_app "$release/$name")" || exit 2
  if [[ "$n" != 0 ]]; then
    echo "FAIL bản Release $name có $needle ở $n file: code chế độ cô lập UI test lọt ra ngoài #if DEBUG" >&2
    status=1
  else
    echo "ok   bản Release $name không có $needle (bản Debug có: đối chứng âm đạt)"
  fi
done
exit $status
