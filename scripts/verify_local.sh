#!/usr/bin/env bash
# Bằng chứng merge chạy trên Mac của người điều phối, thay cho GitHub Actions (CI chỉ chạy tay hoặc khi gắn tag: Nt0 quyết
# 2026-10-16 khi repo còn private, để tiết kiệm phút Actions; docs/process/review-and-merge.md).
# Chạy đúng các bước của hai job CI trên đúng commit HEAD rồi ghi commit status `local/verify`
# lên GitHub cho SHA đó. Người duyệt kiểm status này trên SHA cuối của PR trước khi merge.
#
#   scripts/verify_local.sh               # đủ các bước, ghi status
#   scripts/verify_local.sh --no-status   # chạy thử, không ghi status
#   scripts/verify_local.sh --skip-linux  # bỏ bước Linux (Docker); status ghi rõ là đã bỏ
#   scripts/verify_local.sh --clean       # xoá sản phẩm build và project sinh ra rồi build lại từ đầu,
#                                         # gần với máy sạch của CI; bắt buộc ở các cổng (G2, G3)
#   scripts/verify_local.sh --uitest      # thêm XCUITest: chỉ các lớp bị ảnh hưởng theo file đổi so với
#                                         # merge-base(origin/main, HEAD) (bảng map ở scripts/uitest_plan.py); đủ bộ
#                                         # khi chạm hạ tầng chung, khi có --clean (cổng) hoặc --uitest-all
#   scripts/verify_local.sh --uitest-all  # như --uitest nhưng luôn đủ bộ hai target (người duyệt yêu cầu)
#   scripts/verify_local.sh --uitest-plan # chỉ in các lớp UI test sẽ chạy (không build, không chạy, không ghi status)
#   scripts/verify_local.sh --full        # luôn đủ bộ macOS, bỏ qua chọn mức theo file đổi
#   scripts/verify_local.sh --scope-plan  # chỉ in mức kiểm sẽ chạy (none/core/full) rồi thoát
#   scripts/verify_local.sh --check-identity
#                                         # chỉ kiểm danh tính git của các commit sẽ làm bằng chứng rồi thoát
#   scripts/verify_local.sh --uitest --no-autosave-check
#                                         # như trên nhưng bỏ bước so ~/Library/Autosave Information (khi chưa cấp
#                                         # Full Disk Access); status ghi "kiểm Autosave: bỏ qua"
#
# Mức kiểm theo file đổi so với merge-base(origin/main, HEAD) (scripts/verify_scope.py; Nt0 chốt 2026-10-22):
#   none  chỉ android/** và tài liệu: chỉ kiểm danh tính git rồi ghi status (phần Android: check `android` của CI);
#   core  oracle/test lõi Swift (fixtures/invalid-json, vectors, packages, expected-verdicts.json, schema/, test ExamKit):
#         check.sh --core trên macOS và bước Linux;
#   full  mọi thứ khác, và luôn khi --clean (cổng), --uitest-all, --full: đủ các bước dưới đây.
# Cần: macOS có Xcode được chọn, xcodegen, Docker (bước Linux), gh đã đăng nhập (ghi status),
# jsonschema hoặc uv (scripts/check.sh). Working tree phải sạch và HEAD đã push.
# --uitest còn cần: màn hình mở khoá và không ai dùng chuột/bàn phím trong lúc chạy (~10 phút); trình chạy test
# được macOS cho phép điều khiển máy (Accessibility/Automation: lần đầu macOS có thể hỏi, người điều phối cấp; agent
# gặp lỗi "Timed out while enabling automation mode" thì dừng và báo, không tự cấp quyền). App chạy ở chế độ cô
# lập (kho, đề mẫu, cài đặt trong /private/tmp/ExamSuiteUITests-*; bundle ID vn.io.nt0.examsuite.uitest và
# vn.io.nt0.examsuite.admin.uitest); script so kho và defaults thật của CẢ HAI bản trước và sau (bundle ID
# vn.io.nt0.examsuite, vn.io.nt0.examsuite.admin), khác nhau thì thất bại;
# và so ~/Library/Autosave Information/ (chỉ tên, mtime, cỡ): có mục mới của Exam Suite (đề chưa lưu do UI test bỏ lại)
# thì thất bại. Bản iOS (docs/product/plan-ios-v1.md) ở mức full: build cho simulator (build/DerivedData-iOS), test phần
# chỉ của iOS (MobileFeatureTests) trên simulator, kiểm ranh giới bundle (ADR 0003) và chữ Info.plist vi/en của app iOS,
# export String Catalog của scheme ExamSuiteiOS; --uitest chạy thêm các
# lớp ExamSuiteiOSUITests đã chọn trên simulator. Máy và runtime simulator: EXAMSUITE_IOS_DESTINATION (mặc định bên
# dưới, cùng máy với ảnh snapshot của bản iOS). Simulator đã tách dữ liệu khỏi máy Mac nên không so kho thật cho iOS.
# App Debug/Release mang bundle ID thật mà script build (build/DerivedData/Build/Products, build/DerivedData-Release/Build/
# Products) bị xoá ngay sau bước kiểm cuối dùng chúng và khi script dừng ở bất cứ đâu, để LaunchServices không chọn bản
# Debug (dùng chung kho thật) mở `.exam`; bản `.uitest` của bước UI test giữ lại.
set -euo pipefail
cd "$(dirname "$0")/.."

POST_STATUS=1
RUN_LINUX=1
CLEAN=0
UITEST=0
UITEST_ALL=0
UITEST_PLAN_ONLY=0
AUTOSAVE_CHECK=1
CHECK_IDENTITY_ONLY=0
FORCE_FULL=0
IOS_DESTINATION="${EXAMSUITE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.1}"
SCOPE_PLAN_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --no-status) POST_STATUS=0 ;;
    --skip-linux) RUN_LINUX=0 ;;
    --clean) CLEAN=1 ;;
    --uitest) UITEST=1 ;;
    --uitest-all) UITEST=1; UITEST_ALL=1 ;;
    --uitest-plan) UITEST_PLAN_ONLY=1 ;;
    --check-identity) CHECK_IDENTITY_ONLY=1 ;;
    --no-autosave-check) AUTOSAVE_CHECK=0 ;;
    --full) FORCE_FULL=1 ;;
    --scope-plan) SCOPE_PLAN_ONLY=1 ;;
    *) echo "verify_local.sh: tham số lạ: $arg" >&2; exit 2 ;;
  esac
done

# Mức kiểm (scripts/verify_scope.py): ép full ở cổng và khi người duyệt yêu cầu đủ bộ.
verify_scope() {
  if [[ $CLEAN == 1 ]]; then printf 'scope: full\nreason: --clean (cổng)\n'
  elif [[ $UITEST_ALL == 1 ]]; then printf 'scope: full\nreason: --uitest-all\n'
  elif [[ $FORCE_FULL == 1 ]]; then printf 'scope: full\nreason: --full\n'
  else python3 scripts/verify_scope.py --git
  fi
}
SCOPE_PLAN="$(verify_scope)"
SCOPE="$(sed -n 's/^scope: //p' <<< "$SCOPE_PLAN")"
[[ "$SCOPE" =~ ^(none|core|full)$ ]] || { echo "verify_local.sh: mức kiểm sai dạng: $SCOPE_PLAN" >&2; exit 2; }
if [[ $SCOPE_PLAN_ONLY == 1 ]]; then
  echo "$SCOPE_PLAN"
  exit 0
fi

# Lớp UI test sẽ chạy (docs/notes/g5-ui-test-trung-lap.md, T1): theo file đổi so với merge-base(origin/main, HEAD);
# đủ bộ khi --clean (cổng), --uitest-all, chạm hạ tầng chung, hoặc bảng map chưa khớp lớp thật (cảnh báo).
uitest_plan() {
  if [[ $CLEAN == 1 ]]; then
    python3 scripts/uitest_plan.py --all --reason "--clean (cổng)"
  elif [[ $UITEST_ALL == 1 ]]; then
    python3 scripts/uitest_plan.py --all --reason "--uitest-all"
  else
    python3 scripts/uitest_plan.py --git
  fi
}
if [[ $UITEST_PLAN_ONLY == 1 ]]; then
  uitest_plan
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] || { echo "verify_local.sh: chỉ chạy trên macOS." >&2; exit 2; }
if [[ $AUTOSAVE_CHECK == 0 && $UITEST == 0 ]]; then
  echo "verify_local.sh: --no-autosave-check chỉ dùng cùng --uitest." >&2
  exit 2
fi
# Bước UI test so ~/Library/Autosave Information trước–sau. macOS (TCC) có thể chặn đọc thư mục này cả với Terminal:
# kiểm ngay từ đầu (trước khi build ~10 phút) và dừng nếu không đọc được, không để bước so đạt mà không kiểm gì.
AUTOSAVE_DIR="$HOME/Library/Autosave Information"
AUTOSAVE_HINT="cấp Full Disk Access (Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Truy cập toàn bộ ổ đĩa) cho app chạy script (Terminal, iTerm hoặc VS Code), mở lại app đó rồi chạy lại; hoặc chạy với --no-autosave-check (status ghi \"kiểm Autosave: bỏ qua\")"
if [[ $UITEST == 1 && $AUTOSAVE_CHECK == 1 && -e "$AUTOSAVE_DIR" ]] && ! ls -A "$AUTOSAVE_DIR" >/dev/null; then
  echo "verify_local.sh: không đọc được $AUTOSAVE_DIR (macOS chặn quyền). Cách sửa: $AUTOSAVE_HINT." >&2
  exit 2
fi
# Danh tính git (Nt0 chốt 2026-10-20, repo public; review độc lập #62 S7): MỌI commit từ merge-base(origin/main, HEAD)
# tới HEAD (khi HEAD đã nằm trong origin/main, như trên main: chính HEAD) phải có email tác giả là địa chỉ ẩn của GitHub
# (`…@users.noreply.github.com`) và email người commit là địa chỉ đó hoặc `noreply@github.com` (merge commit tạo trên web
# GitHub), để email thật không lọt vào lịch sử public. Commit có từ trước khi công khai (chỉ ở repo riêng cũ) được miễn
# khi người điều phối đặt EXAMSUITE_IDENTITY_ALLOW=<sha>[,<sha>…] (SHA đủ hoặc tiền tố từ 7 ký tự) cho đúng lần chạy đó:
# mỗi commit được miễn in cảnh báo, status ghi số commit được miễn. Repo public không có commit như vậy và không đặt biến
# này. Rẻ (vài lệnh git), chạy trước mọi bước build; đối chứng dương và âm chạy mỗi lần. `--check-identity`: chỉ bước này.
noreply_email() { [[ "$1" == *@users.noreply.github.com ]]; }
identity_problems() { # email tác giả, email người commit: in từng vấn đề, không in gì nếu đạt
  noreply_email "$1" || echo "tác giả <$1>"
  noreply_email "$2" || [[ "$2" == "noreply@github.com" ]] || echo "người commit <$2>"
}
identity_allowed() { # sha: có trong EXAMSUITE_IDENTITY_ALLOW (SHA đủ hoặc tiền tố từ 7 ký tự)?
  local entry allow=()
  IFS=',' read -r -a allow <<< "${EXAMSUITE_IDENTITY_ALLOW:-}"
  for entry in ${allow[@]+"${allow[@]}"}; do
    entry="${entry//[[:space:]]/}"
    [[ ${#entry} -ge 7 && "$1" == "$entry"* ]] && return 0
  done
  return 1
}
if [[ -n "$(identity_problems "1+a@users.noreply.github.com" "noreply@github.com")" \
  || -z "$(identity_problems "a@example.com" "1+a@users.noreply.github.com")" \
  || -z "$(identity_problems "1+a@users.noreply.github.com" "a@example.com")" \
  || -z "$(identity_problems "noreply@github.com" "noreply@github.com")" ]] \
  || ! EXAMSUITE_IDENTITY_ALLOW="0123456789ab, fedcba9" identity_allowed "fedcba9876543210" \
  || EXAMSUITE_IDENTITY_ALLOW="0123" identity_allowed "0123456789ab" \
  || EXAMSUITE_IDENTITY_ALLOW="" identity_allowed "0123456789ab"; then
  echo "verify_local.sh: đối chứng của phép kiểm danh tính git sai (sửa identity_problems hoặc identity_allowed)." >&2
  exit 2
fi
IDENTITY_BASE="$(git merge-base origin/main HEAD)" \
  || { echo "verify_local.sh: không tìm được merge-base với origin/main (chạy git fetch origin trước)." >&2; exit 2; }
IDENTITY_COMMITS="$(git rev-list "$IDENTITY_BASE..HEAD")"
[[ -n "$IDENTITY_COMMITS" ]] || IDENTITY_COMMITS="$(git rev-parse HEAD)"
IDENTITY_HEAD="$(git rev-parse HEAD)"
IDENTITY_ALLOWED=0
IDENTITY_FAILED=0
while IFS= read -r commit; do
  problems="$(identity_problems "$(git log -1 --format=%ae "$commit")" "$(git log -1 --format=%ce "$commit")")"
  [[ -n "$problems" ]] || continue
  if identity_allowed "$commit"; then
    echo "CẢNH BÁO danh tính git: commit ${commit:0:12} có email không phải địa chỉ ẩn của GitHub, được MIỄN vì có trong" \
      "EXAMSUITE_IDENTITY_ALLOW (chỉ cho commit có từ trước khi công khai, không bao giờ vào repo public)." >&2
    IDENTITY_ALLOWED=$((IDENTITY_ALLOWED + 1))
    continue
  fi
  IDENTITY_FAILED=1
  if [[ "$commit" == "$IDENTITY_HEAD" && "$(git log -1 --format=%P "$commit" | wc -w)" -le 1 \
    && -z "$(git branch -r --contains "$commit")" ]]; then
    advice="commit ở đỉnh, chưa push: git commit --amend --no-edit --reset-author"
  else
    advice="viết lại các commit của nhánh trước khi merge"
  fi
  echo "verify_local.sh: commit ${commit:0:12} có email không phải địa chỉ ẩn của GitHub: $(echo $problems)." \
    "Cách sửa: $advice." >&2
done <<< "$IDENTITY_COMMITS"
if [[ $IDENTITY_FAILED == 1 ]]; then
  echo "verify_local.sh: dừng (danh tính git). Đặt git config user.email <id>+<tài khoản>@users.noreply.github.com cho" \
    "commit mới." >&2
  exit 2
fi
IDENTITY_NOTE=""
[[ $IDENTITY_ALLOWED == 0 ]] || IDENTITY_NOTE=", miễn danh tính $IDENTITY_ALLOWED commit"
if [[ $CHECK_IDENTITY_ONLY == 1 ]]; then
  echo "ok   danh tính git: $(wc -l <<< "$IDENTITY_COMMITS" | tr -d ' ') commit từ ${IDENTITY_BASE:0:12} tới ${IDENTITY_HEAD:0:12}${IDENTITY_NOTE}"
  exit 0
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "verify_local.sh: working tree chưa sạch; commit hoặc stash trước để bằng chứng gắn đúng commit." >&2
  exit 2
fi
# jsonschema cho scripts/check.sh: python3 có sẵn gói, hoặc `uv` trên PATH; uv ở chỗ khác thì đặt EXAMSUITE_UV (đường dẫn
# tới file uv) trước khi chạy.
if ! command -v uv >/dev/null 2>&1 && [[ -n "${EXAMSUITE_UV:-}" && -x "${EXAMSUITE_UV}" ]]; then
  export PATH="$(dirname "$EXAMSUITE_UV"):$PATH"
fi

SHA="$(git rev-parse HEAD)"
SHORT="${SHA:0:7}"
CONTEXT="local/verify"
LOG="build/verify-$SHORT.log"
if [[ $CLEAN == 1 ]]; then
  # Chỉ xoá những thứ do build sinh ra (đều trong .gitignore). Không dùng `git clean -X` vì nó xoá
  # cả worktree của agent trong .claude/worktrees/.
  echo "== --clean: xoá build/, Packages/*/.build, Packages/*/.swiftpm, ExamSuite.xcodeproj, Apps/*/Info.plist"
  rm -rf build Packages/*/.build Packages/*/.swiftpm ExamSuite.xcodeproj Apps/*/Info.plist
fi
mkdir -p build
: > "$LOG"
START=$(date +%s)

post_status() { # state, description
  [[ $POST_STATUS == 1 ]] || return 0
  # GitHub từ chối mô tả dài hơn 140 ký tự (HTTP 422): cắt bớt phần cuối (thời gian) thay vì mất status. Mô tả không
  # ghi tên máy (status của repo public ai cũng đọc được).
  local description
  description="$(python3 -c 'import sys; s = sys.argv[1]; print(s if len(s) <= 140 else s[:139] + "…")' "$2")"
  gh api --silent "repos/{owner}/{repo}/statuses/$SHA" \
    -f state="$1" -f context="$CONTEXT" -f description="$description" \
    || echo "verify_local.sh: không ghi được commit status (commit đã push chưa?)." >&2
}

STEP=""
# App Debug và Release build ở build/DerivedData, build/DerivedData-Release mang bundle ID thật (vn.io.nt0.*): LaunchServices
# có thể chọn chúng mở `.exam` từ Finder, và bản Debug dùng chung kho, `defaults` thật. Xoá cả thư mục Products ngay sau
# bước cuối dùng chúng (check_release_strings.sh) và khi script dừng ở bất cứ đâu (on_exit), như make_dmg.sh bước 6. Bản
# `.uitest` (build/DerivedData-UITest: bundle ID riêng, LSHandlerRank None) giữ lại để chạy lại nhanh.
REAL_APP_PRODUCTS=(build/DerivedData/Build/Products build/DerivedData-Release/Build/Products)
remove_real_apps() {
  rm -rf "${REAL_APP_PRODUCTS[@]}"
}
on_exit() {
  local code=$?
  if [[ $code -ne 0 ]]; then
    echo "== THẤT BẠI ở bước: $STEP (log: $LOG)" >&2
    post_status failure "Thất bại: $STEP"
  fi
  # Sau khi ghi status (xoá lỗi không được làm mất status thất bại), và không dừng trap vì lỗi xoá (set -e).
  remove_real_apps || echo "verify_local.sh: không xoá được app mang bundle ID thật (${REAL_APP_PRODUCTS[*]}); xoá tay." >&2
}
trap on_exit EXIT

# Job core-linux: đúng commit HEAD (git archive), cùng image và gói như CI. Dùng ở mức core và full.
LINUX_NOTE="Linux bỏ qua"
linux_check() {
  [[ $RUN_LINUX == 1 ]] || return 0
  STEP="Linux (Docker swift:6.1, check.sh --core)"
  echo "== $STEP" | tee -a "$LOG"
  git archive "$SHA" | docker run --rm -i swift:6.1 bash -c '
    set -euo pipefail
    mkdir /w && tar -x -C /w && cd /w
    apt-get update -q >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q python3 python3-jsonschema >/dev/null
    scripts/check.sh --core' 2>&1 | tee -a "$LOG"
  LINUX_NOTE="Linux ok"
}

run() { # tên bước, lệnh...
  STEP="$1"; shift
  echo "== $STEP" | tee -a "$LOG"
  "$@" 2>&1 | tee -a "$LOG"
}

if [[ $POST_STATUS == 1 ]]; then
  gh api --silent "repos/{owner}/{repo}/commits/$SHA" \
    || { echo "verify_local.sh: commit $SHORT chưa có trên GitHub; push trước." >&2; exit 2; }
  post_status pending "Đang chạy (local)"
fi

# Bundle tài nguyên cũ của swift test (AGENTS.md, mục Lệnh kiểm chứng; 2026-10-18): `swift test` đọc bản sao bundle tài
# nguyên trong từng .xctest (Contents/Resources/ExamFeatures_*.bundle, SharedFeatures_*.bundle của module dùng chung
# build cùng thư mục), không đọc Products/Debug/*.bundle. Lần chạy
# incremental trên worktree từng build ở commit cũ (catalog chưa có en) ra chữ tiếng Việt ở mọi phép tra en, cùng SHA
# chạy --clean thì đạt. Trước check.sh (chỉ khi không --clean): bundle (ở Products hay bản sao trong .xctest) thiếu thư
# mục <ngôn ngữ>.lproj của một ngôn ngữ có trong catalog (catalog vừa có thêm ngôn ngữ), hoặc bản sao trong .xctest khác
# bản ở Products, thì xoá Packages/ExamFeatures/.build để build lại từ đầu (chỉ tốn thời gian, không mất gì; status ghi
# "ExamFeatures build lại"). Sau check.sh (mọi chế độ) kiểm lại đúng bản build vừa dùng cho test: còn báo gì thì thất bại
# (bằng chứng tự kiểm, review độc lập #53 S2).
stale_resource_bundles() { # in từng vấn đề, không in gì nếu ổn hoặc chưa có bản build
  python3 - <<'PY'
import filecmp, json, pathlib

root = pathlib.Path("Packages/ExamFeatures")
products = root / ".build/out/Products/Debug"
if not products.is_dir():
    raise SystemExit(0)

def files(directory):
    return {p.relative_to(directory) for p in directory.rglob("*") if p.is_file()} if directory.is_dir() else set()

shared = pathlib.Path("Packages/SharedFeatures")
for catalog in sorted([*root.glob("Sources/*/Resources/Localizable.xcstrings"),
                       *shared.glob("Sources/*/Resources/Localizable.xcstrings")]):
    package, target = catalog.parts[1], catalog.parts[-3]
    data = json.loads(catalog.read_text(encoding="utf-8"))
    source = data.get("sourceLanguage", "vi")
    languages = sorted({
        language for entry in data.get("strings", {}).values() for language in entry.get("localizations", {})
    } - {source})
    name = f"{package}_{target}.bundle"
    product = products / name
    copies = sorted(products.glob(f"*.xctest/Contents/Resources/{name}"))
    for bundle in ([product] if product.is_dir() else []) + copies:
        for language in languages:
            if not (bundle / "Contents/Resources" / f"{language}.lproj").is_dir():
                print(f"{bundle}: thiếu {language}.lproj")
    if product.is_dir():
        reference = product / "Contents/Resources"
        for copy in copies:
            mine = copy / "Contents/Resources"
            for relative in sorted(files(reference) ^ files(mine)):
                print(f"{copy}: khác bản ở Products ({relative})")
            for relative in sorted(files(reference) & files(mine)):
                if not filecmp.cmp(reference / relative, mine / relative, shallow=False):
                    print(f"{copy}: khác bản ở Products ({relative})")
PY
}
{ echo "== Mức kiểm"; echo "$SCOPE_PLAN"; } | tee -a "$LOG"
if [[ $SCOPE != full ]]; then
  # Không chạm phần macOS: bỏ build hai app, catalog, Release, ExamFeatures, UI test (xem đầu file).
  UI_SKIPPED=""
  [[ $UITEST == 0 ]] || UI_SKIPPED=", UI test bỏ qua (mức $SCOPE)"
  if [[ $SCOPE == core ]]; then
    run "check.sh --core (lõi Swift, schema, ranh giới, quét chuỗi)" scripts/check.sh --core
    linux_check
    STEP="ghi status"
    MINUTES=$(( ($(date +%s) - START + 59) / 60 ))
    post_status success "mức core: lõi ok (check.sh --core)$IDENTITY_NOTE$UI_SKIPPED, $LINUX_NOTE, ${MINUTES} phút"
    echo "== OK: $SHORT (mức core; $LINUX_NOTE). Log: $LOG"
  else
    STEP="ghi status"
    post_status success "mức none: chỉ android/ và tài liệu, không bước macOS$IDENTITY_NOTE$UI_SKIPPED (Android: check android của CI)"
    echo "== OK: $SHORT (mức none: chỉ android/ và tài liệu). Log: $LOG"
  fi
  exit 0
fi

FORCED_REBUILD=0
if [[ $CLEAN == 0 ]]; then
  STEP="kiểm bundle tài nguyên của swift test (trước check.sh)"
  STALE_BUNDLES="$(stale_resource_bundles)"
  if [[ -n "$STALE_BUNDLES" ]]; then
    { echo "== Bundle tài nguyên của swift test cũ: xoá Packages/ExamFeatures/.build, build lại từ đầu"
      echo "$STALE_BUNDLES"; } | tee -a "$LOG"
    rm -rf Packages/ExamFeatures/.build
    FORCED_REBUILD=1
  fi
fi

# Job apps-macos + phần lõi trên macOS.
run "check.sh (macOS: ExamKit, schema, ranh giới, ExamFeatures)" scripts/check.sh
STEP="kiểm bundle tài nguyên của swift test (sau check.sh)"
echo "== $STEP" | tee -a "$LOG"
STALE_BUNDLES="$(stale_resource_bundles)"
if [[ -n "$STALE_BUNDLES" ]]; then
  { echo "Bundle tài nguyên mà swift test vừa dùng không khớp catalog hoặc khác bản ở Products:"
    echo "$STALE_BUNDLES"
    echo "Bước tiếp theo: chạy lại scripts/verify_local.sh (lần chạy sau thấy bundle cũ thì tự xoá Packages/ExamFeatures/.build và build lại) hoặc chạy với --clean."; } | tee -a "$LOG"
  exit 1
fi
run "xcodegen" xcodegen generate
for scheme in ExamSuite ExamSuiteAdmin; do
  run "xcodebuild $scheme" xcodebuild -project ExamSuite.xcodeproj -scheme "$scheme" \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO -quiet build
done
# Bản iOS: build cho simulator (ký ad-hoc), cùng phép kiểm ranh giới bundle với bản Học viên macOS.
run "xcodebuild ExamSuiteiOS (simulator)" xcodebuild -project ExamSuite.xcodeproj -scheme ExamSuiteiOS \
  -configuration Debug -destination "$IOS_DESTINATION" -derivedDataPath build/DerivedData-iOS -quiet build
IOS_PRODUCTS=build/DerivedData-iOS/Build/Products/Debug-iphonesimulator
# Phần chỉ của iOS (Packages/MobileFeatures) trên simulator: kho thư viện, đề mẫu, bookmark, phiên thi của iOS
# (MobileFeatureTests) và snapshot iPhone (MobileSnapshotTests, ADR 0010). Không có test nào chạy là thất bại.
ios_unit_tests() {
  local out="build/verify-ios-unit-$SHORT.log"
  xcodebuild -project ExamSuite.xcodeproj -scheme ExamSuiteiOS -configuration Debug -destination "$IOS_DESTINATION" \
    -derivedDataPath build/DerivedData-iOS -only-testing:MobileFeatureTests -only-testing:MobileSnapshotTests test \
    > "$out" 2>&1 || { tail -40 "$out"; echo "MobileFeatureTests/MobileSnapshotTests thất bại (log: $out)."; return 1; }
  grep -E '^[✔✘] Test run with' "$out" || true
  # Mỗi target một dòng "Test run" của Swift Testing: cả hai phải có test chạy (không gộp, để một target chạy 0 test
  # cũng bị bắt).
  [[ $(grep -cE '^✔ Test run with [1-9][0-9]* tests? ' "$out") -ge 2 ]] \
    || { echo "MobileFeatureTests hoặc MobileSnapshotTests không có test nào chạy (log: $out)."; return 1; }
  grep -qE '^✔ Suite "Snapshot iPhone" passed' "$out" \
    || { echo "MobileSnapshotTests (Snapshot iPhone) không chạy (log: $out)."; return 1; }
  grep -qE '^✔ Suite "Kho thư viện trên iOS" passed' "$out" \
    || { echo "MobileFeatureTests (Kho thư viện trên iOS) không chạy (log: $out)."; return 1; }
}
run "MobileFeatureTests, MobileSnapshotTests (simulator)" ios_unit_tests
run "kiểm bundle (ADR 0003)" scripts/check_bundle_boundary.sh build/DerivedData/Build/Products/Debug "$IOS_PRODUCTS"
# String Catalog (docs/product/accessibility-localization.md, mục Kiểm): hai app có vi.lproj và en.lproj, chuỗi Info.plist
# tra được và bằng bản của InfoPlist.xcstrings, mọi bundle catalog của package có cùng ngôn ngữ và có en (--require-en,
# review #50 N2); rồi Xcode đồng bộ catalog nguồn với code của cả hai scheme (khoá mới, khoá không còn dùng, khoá Info.plist)
# và catalog đã commit không được đổi. Đổi thì xem `git diff -- '*.xcstrings'` (khoá mới, khoá stale cần xoá), commit
# catalog rồi chạy lại.
run "String Catalog: hai app có vi/en (check_localization.py --built-apps --require-en)" \
  python3 scripts/check_localization.py --require-en --built-apps build/DerivedData/Build/Products/Debug
run "String Catalog: app iOS có vi/en (check_localization.py --built-apps --require-en)" \
  python3 scripts/check_localization.py --require-en --built-apps "$IOS_PRODUCTS"
export_localizations() {
  local scheme
  for scheme in ExamSuite ExamSuiteAdmin ExamSuiteiOS; do
    rm -rf "build/l10n-export/$scheme"
    xcodebuild -exportLocalizations -project ExamSuite.xcodeproj -scheme "$scheme" -exportLanguage en \
      -localizationPath "build/l10n-export/$scheme" -derivedDataPath build/DerivedData-L10n -quiet
  done
  if [[ -n "$(git status --porcelain -- '*.xcstrings')" ]]; then
    git status --short -- '*.xcstrings'
    git --no-pager diff --stat -- '*.xcstrings'
    echo "Catalog chưa đồng bộ với code: xem git diff -- '*.xcstrings', commit catalog rồi chạy lại."
    return 1
  fi
}
run "String Catalog đủ khoá (xcodebuild -exportLocalizations, git diff)" export_localizations
# Bản Release không chứa code chế độ cô lập của UI test (`#if DEBUG`): build Release hai scheme rồi tìm chuỗi
# `ExamSuiteUITest` trong binary; bản Debug ở trên là đối chứng âm (phải có chuỗi đó).
for scheme in ExamSuite ExamSuiteAdmin; do
  run "xcodebuild $scheme (Release)" xcodebuild -project ExamSuite.xcodeproj -scheme "$scheme" \
    -configuration Release -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData-Release CODE_SIGNING_ALLOWED=NO -quiet build
done
# Bản iOS: Release cho simulator (bản Debug ở build/DerivedData-iOS là đối chứng âm).
run "xcodebuild ExamSuiteiOS (Release, simulator)" xcodebuild -project ExamSuite.xcodeproj -scheme ExamSuiteiOS \
  -configuration Release -destination "$IOS_DESTINATION" -derivedDataPath build/DerivedData-iOS-Release -quiet build
run "Release không có code UI test" scripts/check_release_strings.sh build/DerivedData-Release/Build/Products/Release \
  build/DerivedData/Build/Products/Debug build/DerivedData-iOS-Release/Build/Products/Release-iphonesimulator \
  "$IOS_PRODUCTS"
# Bước cuối dùng app mang bundle ID thật: xoá ngay (xem remove_real_apps), trước khi lái app ở bước UI test.
STEP="xoá app mang bundle ID thật vừa build (${REAL_APP_PRODUCTS[*]})"
echo "== $STEP" | tee -a "$LOG"
remove_real_apps
for products in "${REAL_APP_PRODUCTS[@]}"; do
  [[ ! -e "$products" ]] || { echo "Không xoá được $products" | tee -a "$LOG"; exit 1; }
done

# XCUITest hai bản app (chỉ khi --uitest), Học viên rồi Admin, chỉ các lớp của kế hoạch (uitest_plan). Hai target dùng
# chung build/DerivedData-UITest với EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest (bundle ID vn.io.nt0.examsuite.uitest,
# vn.io.nt0.examsuite.admin.uitest; bản Debug ở build/DerivedData giữ bundle ID thật): `build-for-testing` một lần mỗi
# scheme cần chạy, rồi `test-without-building` với `-only-testing:<target>/<lớp>`. Target không có lớp nào thì không
# build, không chạy (T2 của notes/g5-ui-test-trung-lap.md).
UI_DERIVED=build/DerivedData-UITest
real_app_state() { # bundle ID thật; chỉ đọc: cả cây thư mục của app (stat), defaults thật (băm), đề mở gần đây (stat)
  local support="$HOME/Library/Application Support/$1"
  local recents="$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments"
  echo "-- $1"
  # Mọi file và thư mục con (kho, đề mẫu, file mới như bản nháp): tên, mtime, cỡ; mtime của thư mục không đổi khi
  # chỉ ghi đè file bên trong, nên phải stat từng file. Thư mục chưa có thì ghi rõ (vẫn so được trước–sau).
  if [[ -d "$support" ]]; then
    find "$support" -exec stat -f '%N mtime=%m size=%z' {} + 2>&1 | sort || true
  else
    echo "$support: không có"
  fi
  echo "defaults sha256: $(defaults export "$1" - 2>/dev/null | shasum -a 256 | cut -c1-64)"
  stat -f '%N mtime=%m size=%z' "$recents/$1".sfl* 2>&1 || true
}
real_state() { # kho và defaults thật của cả hai bản app (chỉ đọc)
  real_app_state vn.io.nt0.examsuite
  real_app_state vn.io.nt0.examsuite.admin
}
# Tự lưu của macOS: đề CHƯA TỪNG LƯU (Đề mới, Import đề…) được tự lưu vào ~/Library/Autosave Information/, thư mục
# chung của người dùng, KHÔNG theo bundle ID (bản .uitest không tách được như kho/defaults). UI test bản Admin phải kết
# thúc bằng lưu vào thư mục tạm hoặc đóng không lưu; test hỏng giữa chừng (app bị buộc dừng) có thể để lại bản tự lưu.
# App cô lập chạy với CFFIXED_USER_HOME = thư mục nhà tạm, và Foundation đặt thư mục tự lưu theo biến này (đã kiểm,
# plan giai đoạn 4, Decisions 2026-10-17), nên bước này là lớp chặn thứ hai.
# So trước–sau chỉ TÊN, mtime, cỡ (không đọc nội dung). AUTOSAVE_DIR đặt từ $HOME (chạy thử với HOME giả).
# Thư mục chưa có thì in rỗng (như thư mục rỗng), để "chưa có → có" chỉ liệt kê đúng các mục mới. Lỗi đọc (TCC) không
# bị nuốt: lỗi của find ra stderr và hàm trả mã khác 0, người gọi dừng.
autosave_state() { # mục của Exam Suite trong Autosave Information (mọi cấp): tên có "Exam Suite", bundle ID
  # vn.io.nt0.examsuite hoặc đuôi .exam
  [[ -e "$AUTOSAVE_DIR" ]] || return 0
  local out
  out="$(find "$AUTOSAVE_DIR" -mindepth 1 \( -ipath '*Exam Suite*' -o -ipath '*vn.io.nt0.examsuite*' \
    -o -iname '*.exam' \) \
    -exec stat -f '%N mtime=%m size=%z' {} +)" || return 1
  [[ -z "$out" ]] || sort <<< "$out"
}
autosave_all_names() { # mọi mục cấp đầu của Autosave Information (chỉ tên), để ghi chú mục mới không rõ của app nào
  [[ -e "$AUTOSAVE_DIR" ]] || return 0
  local out
  out="$(find "$AUTOSAVE_DIR" -mindepth 1 -maxdepth 1 -print)" || return 1
  [[ -z "$out" ]] || sort <<< "$out"
}
autosave_snapshot() { # nhãn; đặt AUTOSAVE_STATE, AUTOSAVE_NAMES; không đọc được thì dừng script (không đạt khi chưa kiểm)
  if ! AUTOSAVE_STATE="$(autosave_state 2> >(tee -a "$LOG" >&2))" \
    || ! AUTOSAVE_NAMES="$(autosave_all_names 2> >(tee -a "$LOG" >&2))"; then
    STEP="không đọc được ~/Library/Autosave Information $1 (cấp Full Disk Access hoặc --no-autosave-check)"
    { echo "== DỪNG: $STEP"; echo "Cách sửa: $AUTOSAVE_HINT."; } | tee -a "$LOG"
    exit 1
  fi
  { echo "== Autosave Information (mục của Exam Suite) $1"
    if [[ -e "$AUTOSAVE_DIR" ]]; then echo "${AUTOSAVE_STATE:-(không có mục nào)}"; else echo "(thư mục chưa có)"; fi
  } | tee -a "$LOG"
}
# "Mục gần đây" chung của macOS (menu Apple): NSDocumentController có thể ghi đề mở/lưu ở mọi app vào đây, không theo
# bundle ID. Chỉ ghi chú khi đổi (không thất bại): không có đường đi nào từ đây vào kho hay đề gần đây của bản thật.
global_recents_state() {
  stat -f '%N mtime=%m size=%z' "$HOME/Library/Application Support/com.apple.sharedfilelist/"com.apple.LSSharedFileList.RecentDocuments.sfl* 2>/dev/null || true
}
autosave_new_items() { # trước, sau: in các dòng mới/đổi của autosave_state
  comm -13 <(printf '%s\n' "$1") <(printf '%s\n' "$2") | grep -v '^$' || true
}
crash_reports() { # chỉ TÊN file (không đọc nội dung) báo cáo crash/treo của Exam Suite trong $DIAG_DIR
  # Tên báo cáo theo tên tiến trình: "Exam Suite-…" (Học viên), "Exam Suite Admin-…" (Admin); bản .uitest cùng tên
  # tiến trình nên cũng khớp. Trình chạy test ("ExamSuiteUITests-Runner…") không khớp.
  [[ -d "$DIAG_DIR" ]] || return 0
  find "$DIAG_DIR" -maxdepth 1 -name 'Exam Suite*' -print 2>/dev/null | sort || true
}
doc_rank_problems() { # đường dẫn app .uitest…; in app nào có LSHandlerRank của `.exam` khác None
  # Bản .uitest được LaunchServices đăng ký khi build; vai None (project.yml, EXAMSUITE_DOC_HANDLER_RANK) để Finder
  # không bao giờ chọn nó mở `.exam`.
  local app rank
  for app in "$@"; do
    rank="$(plutil -extract CFBundleDocumentTypes.0.LSHandlerRank raw "$app/Contents/Info.plist" 2>/dev/null || echo 'không đọc được')"
    [[ "$rank" == None ]] || echo "$app: LSHandlerRank=$rank"
  done
}
UI_ASSERT_ERRORS=""
UI_RETRIED=0
UI_FAILED_TARGETS=""
UI_CRASHES=""
UI_BUILT_APPS=()
run_ui_tests() { # nhãn, scheme, target UI test, tên app, lớp…; đặt UI_COUNT_<target>
  local label="$1" scheme="$2" target="$3" app="$4" failed=0 start section errors asserts count retried
  shift 4
  local classes=("$@") only=() class
  local crashes_before crashes_new
  printf -v "UI_COUNT_$target" '%s' 0
  if [[ ${#classes[@]} == 0 ]]; then
    echo "== UI test $target ($label): không lớp nào bị ảnh hưởng, không build, không chạy" | tee -a "$LOG"
    return 0
  fi
  for class in "${classes[@]}"; do only+=("-only-testing:$target/$class"); done
  crashes_before="$(crash_reports)"
  start=$(wc -l < "$LOG")
  # Bản iOS chạy trên simulator; vai với `.exam` (LSHandlerRank, doc_rank_problems) chỉ kiểm cho hai bản macOS.
  local destination='platform=macOS,arch=arm64'
  [[ "$scheme" != ExamSuiteiOS ]] || destination="$IOS_DESTINATION"
  local common=(-project ExamSuite.xcodeproj -scheme "$scheme" -configuration Debug
    -destination "$destination" -derivedDataPath "$UI_DERIVED" EXAMSUITE_BUNDLE_ID_SUFFIX=.uitest)
  if run "UI test $target: build-for-testing ($label)" xcodebuild "${common[@]}" -quiet build-for-testing; then
    [[ "$scheme" == ExamSuiteiOS ]] || UI_BUILT_APPS+=("$UI_DERIVED/Build/Products/Debug/$app")
    run "UI test $target ($label, chế độ cô lập): ${classes[*]}" xcodebuild "${common[@]}" "${only[@]}" \
      -retry-tests-on-failure -test-iterations 2 test-without-building || failed=1
  else
    failed=1
  fi
  # XCUITest thỉnh thoảng lỗi hạ tầng (hết giờ tổng hợp sự kiện ở test đầu sau build, mất kết nối…), không do
  # app. Mỗi test thất bại được chạy lại MỘT lần. Chỉ chấp nhận lần chạy lại khi MỌI lỗi của lần đầu là lỗi hạ
  # tầng; lỗi assert của test (hành vi app) thì vẫn là thất bại dù lần chạy lại đạt. Status ghi rõ nếu có chạy lại.
  section="$(tail -n +"$((start + 1))" "$LOG")"
  errors="$(grep -E ": error: -\[$target\." <<< "$section" || true)"
  asserts="$(grep -Ev "$INFRA" <<< "$errors" | grep -v '^$' || true)"
  [[ -z "$asserts" ]] || UI_ASSERT_ERRORS+="$asserts"$'\n'
  retried="$(grep -Ec '^Test Case .* failed \(' <<< "$section" || true)"
  UI_RETRIED=$((UI_RETRIED + ${retried:-0}))
  # `|| true` ở mọi grep: target thất bại không có test đạt nào, và set -e không được dừng script trước khi so kho
  # thật bên dưới.
  count="$(grep -Eo "^Test Case '.*' passed" <<< "$section" | sort -u | wc -l | tr -d ' ' || true)"
  printf -v "UI_COUNT_$target" '%s' "$count"
  # App crash ở lần chạy đầu, XCUITest báo "Lost connection to the application … is not running" (khớp INFRA) và
  # lần chạy lại có thể đạt. Báo cáo crash mới của Exam Suite trong lúc chạy target thì vẫn là thất bại.
  crashes_new="$(comm -13 <(printf '%s\n' "$crashes_before") <(printf '%s\n' "$(crash_reports)") | grep -v '^$' || true)"
  if [[ -n "$crashes_new" ]]; then
    UI_CRASHES+="$crashes_new"$'\n'
    failed=1
  fi
  if [[ $failed != 0 ]]; then
    UI_FAILED_TARGETS+=" $target"
  elif [[ "$count" == 0 ]]; then
    # xcodebuild thoát 0 mà không test nào đạt (target rỗng, bị lọc hết…): không phải bằng chứng.
    UI_FAILED_TARGETS+=" $target (0 test đạt)"
  elif grep -Eq "^Test Case '.*' skipped" <<< "$section"; then
    # Test bị bỏ qua (XCTSkip) không chứng minh gì; status "UI test ok" chỉ khi mọi test thật sự chạy và đạt.
    UI_FAILED_TARGETS+=" $target (có test bị bỏ qua)"
  fi
}
UI_NOTE="UI test bỏ qua"
if [[ $UITEST == 1 ]]; then
  STEP="UI test: chọn lớp theo file đổi (scripts/uitest_plan.py)"
  UI_PLAN="$(uitest_plan)"
  { echo "== $STEP"; echo "$UI_PLAN"; } | tee -a "$LOG"
  UI_MODE="$(sed -n 's/^mode: //p' <<< "$UI_PLAN")"
  UI_STUDENT_CLASSES="$(sed -n 's/^ExamSuiteUITests: *//p' <<< "$UI_PLAN")"
  UI_ADMIN_CLASSES="$(sed -n 's/^ExamSuiteAdminUITests: *//p' <<< "$UI_PLAN")"
  UI_IOS_CLASSES="$(sed -n 's/^ExamSuiteiOSUITests: *//p' <<< "$UI_PLAN")"
  UI_SCOPE="theo file đổi"; [[ "$UI_MODE" == full ]] && UI_SCOPE="đủ bộ"
  [[ "$UI_MODE" =~ ^(selected|full|none)$ ]] || { echo "verify_local.sh: kế hoạch UI test sai dạng" | tee -a "$LOG"; exit 1; }
fi
if [[ $UITEST == 1 && "$UI_MODE" == none ]]; then
  UI_NOTE="UI test bỏ qua (không lớp nào bị ảnh hưởng)"
  echo "== $UI_NOTE" | tee -a "$LOG"
elif [[ $UITEST == 1 ]]; then
  # Thư mục riêng của bản Admin trước T2 (nay dùng chung build/DerivedData-UITest): xoá để không chiếm chỗ.
  rm -rf build/DerivedData-UITest-Admin
  if ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes'; then
    STEP="UI test: màn hình đang khoá (XCUITest không đưa được app lên trước); mở khoá rồi chạy lại"
    echo "== $STEP" | tee -a "$LOG"
    exit 1
  fi
  INFRA='Failed to synthesize event|Timed out while|Lost connection to the application|Not authorized for performing UI testing|Failed to (launch|terminate)|is not running'
  # Báo cáo crash của macOS: so tên file trước–sau mỗi target (crash_reports), để crash thật không lẫn vào lỗi hạ tầng.
  DIAG_DIR="$HOME/Library/Logs/DiagnosticReports"
  BEFORE="$(real_state)"
  { echo "== kho/defaults thật trước UI test"; echo "$BEFORE"; } | tee -a "$LOG"
  if [[ $AUTOSAVE_CHECK == 1 ]]; then
    autosave_snapshot "trước UI test"
    AUTOSAVE_BEFORE="$AUTOSAVE_STATE"
    AUTOSAVE_NAMES_BEFORE="$AUTOSAVE_NAMES"
  else
    echo "== kiểm Autosave Information: bỏ qua (--no-autosave-check)" | tee -a "$LOG"
  fi
  RECENTS_BEFORE="$(global_recents_state)"
  # Chạy cả hai target kể cả khi target đầu thất bại, để so kho thật sau MỌI lần lái app.
  read -r -a STUDENT_CLASSES <<< "$UI_STUDENT_CLASSES"
  read -r -a ADMIN_CLASSES <<< "$UI_ADMIN_CLASSES"
  read -r -a IOS_CLASSES <<< "$UI_IOS_CLASSES"
  run_ui_tests "Học viên" ExamSuite ExamSuiteUITests "Exam Suite.app" ${STUDENT_CLASSES[@]+"${STUDENT_CLASSES[@]}"}
  run_ui_tests "Admin" ExamSuiteAdmin ExamSuiteAdminUITests "Exam Suite Admin.app" ${ADMIN_CLASSES[@]+"${ADMIN_CLASSES[@]}"}
  run_ui_tests "iOS" ExamSuiteiOS ExamSuiteiOSUITests "Exam Suite.app" ${IOS_CLASSES[@]+"${IOS_CLASSES[@]}"}
  AFTER="$(real_state)"
  { echo "== kho/defaults thật sau UI test"; echo "$AFTER"; } | tee -a "$LOG"
  if [[ "$BEFORE" != "$AFTER" ]]; then
    STEP="UI test đã đổi kho hoặc defaults thật của bản Học viên hoặc Admin (xem log)"
    echo "== DỪNG: $STEP" | tee -a "$LOG"
    exit 1
  fi
  echo "== kho/defaults thật không đổi" | tee -a "$LOG"
  [[ "$RECENTS_BEFORE" == "$(global_recents_state)" ]] \
    || echo "== ghi chú: \"Mục gần đây\" chung của macOS đã đổi trong lúc chạy UI test (có thể có đường dẫn /private/tmp của test; không ảnh hưởng bản thật)" | tee -a "$LOG"
  if [[ $AUTOSAVE_CHECK == 1 ]]; then
    autosave_snapshot "sau UI test"
    AUTOSAVE_AFTER="$AUTOSAVE_STATE"
    OTHER_NEW="$(autosave_new_items "$AUTOSAVE_NAMES_BEFORE" "$AUTOSAVE_NAMES")"
    [[ -z "$OTHER_NEW" ]] || { echo "== ghi chú: mục mới khác trong Autosave Information (không mang tên Exam Suite; kiểm tay nếu nghi do UI test):"; echo "$OTHER_NEW"; } | tee -a "$LOG"
    if [[ "$AUTOSAVE_BEFORE" != "$AUTOSAVE_AFTER" ]]; then
      STEP="UI test để lại bản tự lưu trong ~/Library/Autosave Information (xem log, xoá tay sau khi kiểm)"
      { echo "== DỪNG: $STEP"; echo "Mục mới/đổi:"; autosave_new_items "$AUTOSAVE_BEFORE" "$AUTOSAVE_AFTER"
        echo "Mục mất đi:"; comm -23 <(printf '%s\n' "$AUTOSAVE_BEFORE") <(printf '%s\n' "$AUTOSAVE_AFTER") | grep -v '^$' || true
      } | tee -a "$LOG"
      exit 1
    fi
    echo "== Autosave Information không có mục mới của Exam Suite" | tee -a "$LOG"
  fi
  # Chỉ app vừa build ở lần chạy này (thư mục chung có thể còn app cũ của target không chạy).
  RANK_PROBLEMS=""
  [[ ${#UI_BUILT_APPS[@]} == 0 ]] || RANK_PROBLEMS="$(doc_rank_problems "${UI_BUILT_APPS[@]}")"
  if [[ -n "$RANK_PROBLEMS" ]]; then
    STEP="bản .uitest nhận mở file .exam (LSHandlerRank phải là None, xem log)"
    { echo "== $STEP"; echo "$RANK_PROBLEMS"; } | tee -a "$LOG"
    exit 1
  fi
  if [[ -n "$UI_FAILED_TARGETS" ]]; then
    STEP="UI test thất bại:$UI_FAILED_TARGETS"
    { echo "== $STEP"; [[ -z "$UI_CRASHES" ]] || { echo "Báo cáo crash mới của Exam Suite:"; echo "$UI_CRASHES"; }; } \
      | tee -a "$LOG"
    exit 1
  fi
  if [[ -n "$UI_ASSERT_ERRORS" ]]; then
    STEP="UI test có lỗi assert ở lần chạy đầu (lần chạy lại đạt nhưng không chấp nhận)"
    { echo "== $STEP"; echo "$UI_ASSERT_ERRORS"; } | tee -a "$LOG"
    exit 1
  fi
  UI_COUNTS="Học viên ${UI_COUNT_ExamSuiteUITests}, Admin ${UI_COUNT_ExamSuiteAdminUITests}"
  UI_COUNTS+=", iOS ${UI_COUNT_ExamSuiteiOSUITests} test, $UI_SCOPE"
  # Bỏ kiểm Autosave thì ghi ngay sau "kho thật không đổi" (trước phần có thể bị cắt ở 140 ký tự).
  AUTOSAVE_NOTE=""
  [[ $AUTOSAVE_CHECK == 1 ]] || AUTOSAVE_NOTE=", kiểm Autosave: bỏ qua"
  UI_NOTE="UI test ok (${UI_COUNTS}, kho thật không đổi${AUTOSAVE_NOTE})"
  [[ $UI_RETRIED == 0 ]] \
    || UI_NOTE="UI test ok (${UI_COUNTS}, kho thật không đổi${AUTOSAVE_NOTE}; ${UI_RETRIED} lần chạy lại do lỗi hạ tầng)"
fi

linux_check
STEP="ghi status"
MINUTES=$(( ($(date +%s) - START + 59) / 60 ))
MODE="incremental"; [[ $CLEAN == 1 ]] && MODE="clean"
[[ $FORCED_REBUILD == 1 ]] && MODE="incremental, ExamFeatures build lại"
# "iOS ok" đặt sau phần UI test: GitHub cắt mô tả ở 140 ký tự, và "kiểm Autosave: bỏ qua" phải còn trong trường hợp hay
# gặp (incremental, chọn lớp theo file đổi).
post_status success "mức full: macOS ok ($MODE)$IDENTITY_NOTE, $UI_NOTE, iOS ok, $LINUX_NOTE, ${MINUTES} phút"
echo "== OK: $SHORT ($UI_NOTE; $LINUX_NOTE). Log: $LOG"
