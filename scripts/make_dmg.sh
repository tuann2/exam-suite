#!/usr/bin/env bash
# Đóng hai DMG phát hành (plan giai đoạn 6, bước 1; docs/product/plan-macos-v1.md, mục Build và phân phối riêng; ADR 0004):
# `ExamSuite-<phiên bản>.dmg` (bản Học viên) và `ExamSuiteAdmin-<phiên bản>.dmg` (bản Admin), mỗi DMG nén chỉ đọc gồm app,
# lối tắt Applications, `Hướng dẫn cài đặt.txt` (sinh từ docs/install.md, đầu file ghi phiên bản, số build và SHA) và giấy
# phép dạng chữ trơn: `LICENSE.txt` (Apache-2.0), `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt` (sinh từ THIRD_PARTY_NOTICES.md;
# giấy phép MIT của ZIPFoundation, thư viện link vào cả hai app). DMG phát hành công khai do job `release-dmg` của CI đóng
# trên runner của GitHub (đường dẫn build trong binary dạng /Users/runner/work/…); chạy tại chỗ để kiểm trước.
#
#   scripts/make_dmg.sh                 # đóng vào dist/
#   scripts/make_dmg.sh --out <thư mục> # đóng vào thư mục khác (CI)
#   scripts/make_dmg.sh --clean         # xoá build/DerivedData-Release-DMG trước khi build (build lại từ đầu; CI dùng)
#   scripts/make_dmg.sh --print-build   # chỉ in số build của HEAD rồi thoát (CI ghi vào ghi chú phát hành)
#
# Các bước (chỉ công cụ của macOS và Xcode: xcodegen, xcodebuild, codesign, hdiutil):
#  1. Đòi working tree sạch (DMG gắn đúng một commit; SHA ghi trong file hướng dẫn) và lịch sử git đủ (không clone nông).
#  2. Build Release hai scheme vào build/DerivedData-Release-DMG với số build = 1000 + số commit của HEAD
#     (`BUILD_OFFSET` + `git rev-list --count HEAD`, truyền `CURRENT_PROJECT_VERSION` lúc build, không sửa repo), không ký
#     lúc build. Độ lệch 1000 (Nt0 chốt 2026-10-20): repo public bắt đầu từ một commit, nên bản public đầu tiên là build
#     1001, cao hơn mọi build của repo riêng trước đó (0.1.0 là build 357). Số build chỉ tăng đều khi đóng từ `main` (PR
#     merge bằng merge commit, không squash/rebase lại lịch sử); hai nhánh khác nhau có thể ra cùng số. Build thêm Debug
#     hai scheme (cùng thư mục, số build mặc định 1) làm đối chứng âm cho bước 4.
#  3. Chép hai app vào thư mục đóng gói và ký ad-hoc (`codesign --force --deep --options runtime -s -`); kiểm phiên bản, số
#     build, bundle ID thật (không phải bản `.uitest`), chỉ arm64; `Credits.rtf` (vi, en; hộp Giới thiệu của macOS) có
#     giấy phép và ZIPFoundation; trước khi ký, chép `LICENSE.txt`, `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt` vào
#     `Contents/Resources` của mỗi app (app đã cài vẫn mang giấy phép); quét chuỗi cấm trong app (thư mục đồng bộ đám mây
#     của macOS và chuỗi cấm cục bộ không lưu trong repo: thất bại; đường dẫn `/Users/<tên>/` khác runner: chỉ cảnh báo).
#  4. Kiểm đúng hai app sẽ vào DMG: `check_bundle_boundary.sh` (bản Học viên không chứa phần soạn đề, ADR 0003; không app
#     nào chứa thư viện chỉ của test, ADR 0010) và `check_release_strings.sh` (không có code chế độ cô lập của UI test).
#  5. Đóng DMG (`hdiutil create -format UDZO`), `hdiutil verify`, gắn ổ chỉ đọc vào thư mục tạm (`-nobrowse`, không hiện
#     trong Finder), `codesign --verify --deep --strict` app trong ổ, kiểm lối tắt Applications, file hướng dẫn, ba file
#     giấy phép (LICENSE.txt và NOTICE.txt trùng từng byte với bản trong repo; THIRD_PARTY_NOTICES.txt có nguyên văn giấy
#     phép của ZIPFoundation bản vừa build) và ổ có đúng các mục đó, rồi tháo ổ (cả khi lỗi; thử lại có `-force`). Tháo
#     không được kể cả `-force` thì script thất bại, nêu ổ còn gắn.
#  6. Xoá các app vừa build và vừa ký (`build/DerivedData-Release-DMG/Build/Products`, thư mục đóng gói), cả khi lỗi: chúng
#     mang bundle ID thật, LaunchServices có thể chọn chúng (nhất là bản Debug, dùng chung kho và `defaults` thật) để mở
#     `.exam` từ Finder. Chỉ còn hai DMG trong thư mục đích.
#
# Không cài vào /Applications, không mở app, không đọc hay ghi `~/Library/Application Support` hay `defaults` của người
# dùng. Ký ad-hoc: lần mở đầu phải Vẫn mở/Open Anyway (docs/install.md). Chạy lại thì ghi đè DMG cùng tên trong thư mục
# đích.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="dist"
CLEAN=0
PRINT_BUILD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="${2:?make_dmg.sh: --out cần thư mục}"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    --print-build) PRINT_BUILD=1; shift ;;
    *) echo "make_dmg.sh: tham số lạ: $1" >&2; exit 2 ;;
  esac
done

if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
  echo "make_dmg.sh: repo là clone nông, số build (git rev-list --count HEAD) sẽ sai; clone đủ lịch sử (CI: actions/checkout với fetch-depth: 0)." >&2
  exit 2
fi
# Số build của bản đóng gói (bước 2). Chỗ duy nhất tính số build; CI đọc qua --print-build.
BUILD_OFFSET=1000
BUILD="$((BUILD_OFFSET + $(git rev-list --count HEAD)))"
if [[ $PRINT_BUILD == 1 ]]; then
  echo "$BUILD"
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] || { echo "make_dmg.sh: chỉ chạy trên macOS." >&2; exit 2; }
if [[ -n "$(git status --porcelain)" ]]; then
  echo "make_dmg.sh: working tree chưa sạch; commit trước để DMG gắn đúng một commit." >&2
  exit 2
fi

SHA="$(git rev-parse HEAD)"
DERIVED="build/DerivedData-Release-DMG"
WORK="build/dmg"
STUDENT_APP="Exam Suite.app"
ADMIN_APP="Exam Suite Admin.app"
GUIDE="Hướng dẫn cài đặt.txt"
# Giấy phép trong mỗi DMG: tên trong ổ, file nguồn trong repo (THIRD_PARTY_NOTICES.md chuyển thành chữ trơn như hướng dẫn).
LICENSE_FILES=("LICENSE.txt" "NOTICE.txt" "THIRD_PARTY_NOTICES.txt")
MOUNT=""

detach_mount() { # tháo ổ đang gắn (thử lại có -force), xoá thư mục gắn; tháo không được thì báo và trả 1
  [[ -n "$MOUNT" && -d "$MOUNT" ]] || { MOUNT=""; return 0; }
  if hdiutil detach "$MOUNT" -quiet || { sleep 2; hdiutil detach "$MOUNT" -force -quiet; }; then
    rmdir "$MOUNT" 2>/dev/null || true
    MOUNT=""
    return 0
  fi
  # Không xoá MOUNT: ổ còn gắn. Đường thành công (make_dmg) dừng script với lỗi này (set -e) thay vì báo xong khi còn ổ
  # gắn; cleanup thử tháo thêm một lần, vẫn không được thì script thoát với mã lỗi.
  echo "FAIL không tháo được ổ $MOUNT (kể cả -force); tháo tay: hdiutil detach \"$MOUNT\" -force" >&2
  return 1
}
remove_built_apps() { # app mang bundle ID thật vừa build/ký: không để lại cho LaunchServices (bước 6)
  rm -rf "$DERIVED/Build/Products" "$WORK"
}
cleanup() {
  local code=$?
  detach_mount || code=1
  remove_built_apps
  exit "$code"
}
trap cleanup EXIT

step() { echo "== $*"; }

if [[ $CLEAN == 1 ]]; then
  step "--clean: xoá $DERIVED"
  rm -rf "$DERIVED"
fi
step "xcodegen"
xcodegen generate --quiet

for configuration in Release Debug; do
  # Số build chỉ cho bản Release đem đóng; bản Debug (đối chứng âm) giữ số build mặc định 1, thấp hơn mọi bản đã phát
  # hành (từ 1001).
  version_settings=()
  if [[ "$configuration" == Release ]]; then version_settings=(CURRENT_PROJECT_VERSION="$BUILD"); fi
  for scheme in ExamSuite ExamSuiteAdmin; do
    step "xcodebuild $scheme ($configuration${version_settings:+, số build $BUILD})"
    xcodebuild -project ExamSuite.xcodeproj -scheme "$scheme" -configuration "$configuration" \
      -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DERIVED" \
      ${version_settings[@]+"${version_settings[@]}"} CODE_SIGNING_ALLOWED=NO -quiet build
  done
done

RELEASE="$DERIVED/Build/Products/Release"
DEBUG="$DERIVED/Build/Products/Debug"
rm -rf "$WORK"
mkdir -p "$WORK/apps"

plist() { # app, khoá
  plutil -extract "$2" raw "$1/Contents/Info.plist"
}

# Markdown thành chữ trơn: bỏ ký hiệu Markdown (tiêu đề, đậm, mã, liên kết, dòng rào ``` kể cả khi thụt lề trong danh
# sách), giữ nội dung.
markdown_to_text() { # file Markdown
  LC_ALL=C sed -E \
    -e '/^[[:space:]]*```/d' \
    -e 's/^#{1,6} +//' \
    -e 's/\*\*([^*]+)\*\*/\1/g' \
    -e 's/`([^`]+)`/\1/g' \
    -e 's/\[([^]]+)\]\(([^)]+)\)/\1 (\2)/g' \
    "$1"
}
mark_utf8() { # file chữ: TextEdit mở đúng tiếng Việt (UTF-8) cả khi không đoán được bảng mã.
  xattr -w com.apple.TextEncoding 'utf-8;134217984' "$1"
}
# Hướng dẫn cài đặt dạng chữ trơn từ docs/install.md, đầu file ghi phiên bản, số build, SHA.
write_guide() { # tên bản app, file đích
  {
    printf '%s %s (build %s)\n' "$1" "$VERSION" "$BUILD"
    printf 'Commit: %s\n' "$SHA"
    printf 'Đóng gói: %s\n\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
    markdown_to_text docs/install.md
  } > "$2"
  mark_utf8 "$2"
}
write_license_texts() { # thư mục đích: LICENSE, NOTICE nguyên văn; THIRD_PARTY_NOTICES.md thành chữ trơn
  cp LICENSE "$1/LICENSE.txt"
  cp NOTICE "$1/NOTICE.txt"
  markdown_to_text THIRD_PARTY_NOTICES.md > "$1/THIRD_PARTY_NOTICES.txt"
}
write_licenses() { # thư mục đích trong DMG: như write_license_texts, thêm cờ UTF-8 cho TextEdit (không dùng trong app:
  # thuộc tính mở rộng trên file của bundle không cần cho chữ ký)
  write_license_texts "$1"
  local name
  for name in "${LICENSE_FILES[@]}"; do mark_utf8 "$1/$name"; done
}
check_license_texts() { # thư mục, nhãn: ba file giấy phép có và đúng (LICENSE, NOTICE trùng từng byte; thông báo bên
  # thứ ba có dòng bản quyền của ZIPFoundation bản vừa build)
  cmp -s LICENSE "$1/LICENSE.txt" || { echo "FAIL $2: LICENSE.txt khác LICENSE của repo" >&2; exit 1; }
  cmp -s NOTICE "$1/NOTICE.txt" || { echo "FAIL $2: NOTICE.txt khác NOTICE của repo" >&2; exit 1; }
  [[ -s "$1/THIRD_PARTY_NOTICES.txt" ]] || { echo "FAIL $2: thiếu THIRD_PARTY_NOTICES.txt" >&2; exit 1; }
  grep -qF "$(grep -m1 'Copyright' "$ZIP_LICENSE")" "$1/THIRD_PARTY_NOTICES.txt" \
    || { echo "FAIL $2: THIRD_PARTY_NOTICES.txt thiếu dòng bản quyền của ZIPFoundation" >&2; exit 1; }
}

# ZIPFoundation bản vừa build (checkout của xcodebuild, có ở cả runner CI vì xcodebuild resolve gói vào $DERIVED):
# THIRD_PARTY_NOTICES.md phải có mục `### ZIPFoundation <phiên bản đã build>` và khối ```text đầu tiên **của mục đó**
# chép nguyên văn LICENSE của gói (bỏ khoảng trắng cuối dòng và dòng trống đầu), để nâng ZIPFoundation không để lại
# thông báo cũ. Các mục khác của file (gói chỉ dùng khi test, harness của repo) có khối giấy phép riêng, không so ở đây.
ZIP_DIR="$DERIVED/SourcePackages/checkouts/ZIPFoundation"
ZIP_LICENSE="$ZIP_DIR/LICENSE"
step "kiểm THIRD_PARTY_NOTICES.md với ZIPFoundation bản vừa build ($ZIP_DIR)"
[[ -s "$ZIP_LICENSE" ]] || { echo "FAIL không có $ZIP_LICENSE (checkout ZIPFoundation của bản build)" >&2; exit 1; }
ZIP_VERSION="$(git -C "$ZIP_DIR" describe --tags --exact-match HEAD 2>/dev/null || true)"
[[ -n "$ZIP_VERSION" ]] || { echo "FAIL không đọc được phiên bản (tag) của $ZIP_DIR" >&2; exit 1; }
grep -qx "### ZIPFoundation $ZIP_VERSION" THIRD_PARTY_NOTICES.md \
  || { echo "FAIL THIRD_PARTY_NOTICES.md thiếu mục \"### ZIPFoundation $ZIP_VERSION\" (phiên bản vừa build)" >&2; exit 1; }
zip_notice_block() { # khối ```text đầu tiên sau tiêu đề `### ZIPFoundation …`, dừng ở tiêu đề kế tiếp
  awk '/^#+ / { in_zip = ($0 ~ /^### ZIPFoundation /); next }
       in_zip && !inside && /^```text$/ { inside = 1; next }
       inside && /^```$/ { exit }
       inside' THIRD_PARTY_NOTICES.md
}
if ! diff <(zip_notice_block) <(sed -e 's/[[:space:]]*$//' "$ZIP_LICENSE" | sed -e '/./,$!d') >&2; then
  echo "FAIL THIRD_PARTY_NOTICES.md: khối giấy phép của mục ZIPFoundation không chép nguyên văn $ZIP_LICENSE" >&2
  exit 1
fi
echo "ok   THIRD_PARTY_NOTICES.md có mục ZIPFoundation $ZIP_VERSION với nguyên văn giấy phép MIT của bản vừa build"

# Chuỗi cấm trong app đem đóng (S2 của review độc lập #62), quét mọi file của bundle (binary và tài nguyên):
# - mẫu chung, lưu trong repo: thư mục đồng bộ đám mây của macOS (viết `One[D]rive`, `Cloud[S]torage` để chính script và
#   tài liệu không khớp khi quét repo) → thất bại;
# - chuỗi cấm cục bộ, KHÔNG lưu trong repo: biểu thức ERE trong biến môi trường EXAMSUITE_LEAK_PATTERNS và/hoặc từng dòng
#   của file EXAMSUITE_LEAK_PATTERNS_FILE (mặc định ~/.config/exam-suite/leak-patterns; mỗi dòng một mẫu ERE, không dòng
#   trống), đọc nếu có → thất bại. Script chỉ in tên file trúng, không in mẫu;
# - đường dẫn tuyệt đối `/Users/<tên>/` (Swift ghi đường dẫn file nguồn vào binary) khác `/Users/runner/` → chỉ cảnh báo,
#   vì DMG phát hành công khai do runner CI đóng.
# Đối chứng âm: chuỗi dò tổng hợp LEAK_PROBE đi cùng một biểu thức với mọi mẫu (cùng lệnh grep), ghi vào file tạm phải bị bắt.
LEAK_PROBE="EXAMSUITE_LEAK_PROBE_7f3a"
LEAK_PATTERNS_FILE="${EXAMSUITE_LEAK_PATTERNS_FILE:-$HOME/.config/exam-suite/leak-patterns}"
leak_alternatives=('One[D]rive|Cloud[S]torage' "$LEAK_PROBE")
local_leak_count=0
if [[ -n "${EXAMSUITE_LEAK_PATTERNS:-}" ]]; then
  leak_alternatives+=("$EXAMSUITE_LEAK_PATTERNS"); local_leak_count=$((local_leak_count + 1))
fi
if [[ -r "$LEAK_PATTERNS_FILE" ]]; then
  while IFS= read -r leak_line || [[ -n "$leak_line" ]]; do
    [[ -z "$leak_line" ]] && continue
    leak_alternatives+=("$leak_line"); local_leak_count=$((local_leak_count + 1))
  done < "$LEAK_PATTERNS_FILE"
fi
LEAK_REGEX="$(printf '(%s)|' "${leak_alternatives[@]}")"
LEAK_REGEX="${LEAK_REGEX%|}"
leak_hits() { # thư mục: file trúng chuỗi cấm (mỗi dòng một file), rỗng nếu không có; grep lỗi (mẫu sai…) thì dừng
  local rc=0 out
  out="$(LC_ALL=C grep -r -a -l -i -E -e "$LEAK_REGEX" "$1")" || rc=$?
  [[ $rc -le 1 ]] || { echo "FAIL quét chuỗi cấm: grep trả $rc (mẫu ERE cục bộ sai?)" >&2; exit 1; }
  [[ -z "$out" ]] || sort <<< "$out"
}
user_paths() { # thư mục: các tiền tố /Users/<tên>/ khác /Users/runner/ trong mọi file (binary và tài nguyên)
  { LC_ALL=C grep -r -a -o -h -E '/Users/[^/[:space:][:cntrl:]]+/' "$1" || true; } | grep -v -x '/Users/runner/' \
    | sort -u | tr '\n' ' ' || true
}
leak_probe="$(mktemp -d "${TMPDIR:-/tmp}/examsuite-leak.XXXXXX")"
printf 'build path /x/%s/y\n' "$LEAK_PROBE" > "$leak_probe/probe.bin"
probe_hits="$(leak_hits "$leak_probe")"
rm -rf "$leak_probe"
[[ -n "$probe_hits" ]] || { echo "FAIL phép quét chuỗi cấm không bắt được chuỗi dò (đối chứng âm)" >&2; exit 1; }
if [[ $local_leak_count -gt 0 ]]; then
  echo "ok   quét chuỗi cấm: mẫu chung + $local_leak_count biểu thức chuỗi cấm cục bộ (không lưu trong repo, không in ra); đối chứng âm bị bắt"
else
  echo "ok   quét chuỗi cấm: chỉ mẫu chung (không có chuỗi cấm cục bộ); đối chứng âm bị bắt"
fi

# Chép đúng hai app sẽ vào DMG, ký ad-hoc rồi kiểm thông tin của bản đóng gói.
VERSION=""
for app in "$STUDENT_APP" "$ADMIN_APP"; do
  step "ký ad-hoc $app"
  ditto "$RELEASE/$app" "$WORK/apps/$app"
  # Giấy phép trong app (trước khi ký, để chữ ký phủ cả chúng): app đã cài vẫn mang giấy phép và thông báo MIT.
  write_license_texts "$WORK/apps/$app/Contents/Resources"
  codesign --force --deep --options runtime --sign - "$WORK/apps/$app"
  codesign --verify --deep --strict "$WORK/apps/$app"
  version="$(plist "$WORK/apps/$app" CFBundleShortVersionString)"
  build="$(plist "$WORK/apps/$app" CFBundleVersion)"
  identifier="$(plist "$WORK/apps/$app" CFBundleIdentifier)"
  archs="$(lipo -archs "$WORK/apps/$app/Contents/MacOS/$(plist "$WORK/apps/$app" CFBundleExecutable)")"
  case "$app" in
    "$STUDENT_APP") expected_id="vn.io.nt0.examsuite" ;;
    *) expected_id="vn.io.nt0.examsuite.admin" ;;
  esac
  [[ "$build" == "$BUILD" ]] || { echo "FAIL $app: số build $build, cần $BUILD" >&2; exit 1; }
  [[ "$identifier" == "$expected_id" ]] || { echo "FAIL $app: bundle ID $identifier, cần $expected_id" >&2; exit 1; }
  [[ "$archs" == "arm64" ]] || { echo "FAIL $app: kiến trúc $archs, cần arm64" >&2; exit 1; }
  # Hộp Giới thiệu của macOS đọc Credits.rtf theo ngôn ngữ của app (Apps/<app>/<vi|en>.lproj/Credits.rtf).
  for lang in vi en; do
    credits="$WORK/apps/$app/Contents/Resources/$lang.lproj/Credits.rtf"
    [[ -s "$credits" ]] || { echo "FAIL $app: thiếu $lang.lproj/Credits.rtf" >&2; exit 1; }
    for word in ZIPFoundation Apache Nt0; do
      grep -q "$word" "$credits" || { echo "FAIL $app: $lang.lproj/Credits.rtf không nhắc $word" >&2; exit 1; }
    done
  done
  check_license_texts "$WORK/apps/$app/Contents/Resources" "$app (Contents/Resources)"
  leaks="$(leak_hits "$WORK/apps/$app")"
  [[ -z "$leaks" ]] || { echo "FAIL $app có chuỗi cấm (mẫu không in ra) trong:" >&2; echo "$leaks" >&2; exit 1; }
  users="$(user_paths "$WORK/apps/$app")"
  [[ -z "$users" ]] || echo "CẢNH BÁO $app có đường dẫn tuyệt đối của máy build: $users(bản phát hành đóng trên runner CI)"
  if [[ -z "$VERSION" ]]; then
    VERSION="$version"
  elif [[ "$version" != "$VERSION" ]]; then
    echo "FAIL hai bản khác phiên bản: $VERSION và $version (project.yml, MARKETING_VERSION)" >&2
    exit 1
  fi
  echo "ok   $app $version (build $build), $identifier, $archs, ký ad-hoc, Credits.rtf vi/en, giấy phép trong app, không chuỗi cấm"
done

step "kiểm hai app sẽ vào DMG (ADR 0003, 0010; code UI test chỉ ở Debug)"
scripts/check_bundle_boundary.sh "$WORK/apps"
scripts/check_release_strings.sh "$WORK/apps" "$DEBUG"

mkdir -p "$OUT"
make_dmg() { # app, tên file DMG, nhãn ổ, tên bản trong hướng dẫn
  local app="$1" file="$OUT/$2" volume="$3" stage="$WORK/stage-${2%.dmg}"
  step "đóng $file (nhãn ổ \"$volume\")"
  rm -rf "$stage" "$file"
  mkdir -p "$stage"
  ditto "$WORK/apps/$app" "$stage/$app"
  ln -s /Applications "$stage/Applications"
  write_guide "$4" "$stage/$GUIDE"
  write_licenses "$stage"
  # Quét lại cả thư mục đóng gói (app, hướng dẫn, giấy phép) bằng cùng chuỗi cấm, trước khi tạo DMG.
  local stage_leaks
  stage_leaks="$(leak_hits "$stage")"
  [[ -z "$stage_leaks" ]] || { echo "FAIL $file: có chuỗi cấm (mẫu không in ra) trong:" >&2; echo "$stage_leaks" >&2; exit 1; }
  hdiutil create -volname "$volume" -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$file" -quiet
  hdiutil verify "$file" -quiet
  echo "ok   hdiutil verify $file"

  # MOUNT chỉ đặt sau khi gắn được: gắn lỗi thì xoá thư mục tạm, không có ổ nào để tháo (không báo nhầm "không tháo được").
  local mount_dir
  mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/examsuite-dmg.XXXXXX")"
  if ! hdiutil attach "$file" -readonly -nobrowse -noautoopen -mountpoint "$mount_dir" -quiet; then
    rmdir "$mount_dir" 2>/dev/null || true
    echo "FAIL $file: không gắn được ổ để kiểm" >&2
    exit 1
  fi
  MOUNT="$mount_dir"
  codesign --verify --deep --strict --verbose=1 "$MOUNT/$app"
  [[ "$(readlink "$MOUNT/Applications")" == "/Applications" ]] || { echo "FAIL $file: thiếu lối tắt Applications" >&2; exit 1; }
  [[ -s "$MOUNT/$GUIDE" ]] || { echo "FAIL $file: thiếu $GUIDE" >&2; exit 1; }
  grep -q "$SHA" "$MOUNT/$GUIDE" || { echo "FAIL $file: $GUIDE không ghi SHA" >&2; exit 1; }
  [[ "$(plist "$MOUNT/$app" CFBundleVersion)" == "$BUILD" ]] || { echo "FAIL $file: số build trong ổ khác $BUILD" >&2; exit 1; }
  check_license_texts "$MOUNT" "$file"
  # Ổ có đúng các mục này (mục ẩn của hdiutil như .fseventsd không tính): thiếu hay thừa đều thất bại. Kiểm từng mục bằng
  # đường dẫn và đếm số mục, không so chuỗi tên: HFS+ trả tên dạng tách dấu (NFD), khác dạng NFC trong script.
  local contents name expected=("$app" Applications "$GUIDE" "${LICENSE_FILES[@]}")
  for name in "${expected[@]}"; do
    [[ -e "$MOUNT/$name" || -L "$MOUNT/$name" ]] || { echo "FAIL $file: thiếu $name trong ổ" >&2; exit 1; }
  done
  contents="$(cd "$MOUNT" && find . -mindepth 1 -maxdepth 1 ! -name '.*' -print | sort | tr '\n' ' ')"
  [[ "$(cd "$MOUNT" && find . -mindepth 1 -maxdepth 1 ! -name '.*' | wc -l | tr -d ' ')" == "${#expected[@]}" ]] \
    || { echo "FAIL $file: ổ có mục thừa: $contents (cần ${#expected[@]} mục)" >&2; exit 1; }
  echo "ok   app trong ổ chỉ đọc: codesign --verify --deep --strict; giấy phép đúng; nội dung: $contents"
  detach_mount
}

make_dmg "$STUDENT_APP" "ExamSuite-$VERSION.dmg" "Exam Suite $VERSION" "Exam Suite (bản Học viên)"
make_dmg "$ADMIN_APP" "ExamSuiteAdmin-$VERSION.dmg" "Exam Suite Admin $VERSION" "Exam Suite Admin (bản Admin)"

remove_built_apps
[[ ! -e "$DERIVED/Build/Products" ]] || { echo "FAIL không xoá được $DERIVED/Build/Products" >&2; exit 1; }
echo "ok   đã xoá app vừa build ($DERIVED/Build/Products) và thư mục đóng gói"
step "xong: phiên bản $VERSION, build $BUILD, commit $SHA"
for dmg in "$OUT/ExamSuite-$VERSION.dmg" "$OUT/ExamSuiteAdmin-$VERSION.dmg"; do
  echo "     $dmg  $(du -h "$dmg" | cut -f1)  sha256 $(shasum -a 256 "$dmg" | cut -c1-64)"
done
