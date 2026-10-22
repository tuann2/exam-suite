#!/usr/bin/env bash
# Lệnh kiểm tổng của android/ (plan-android-v1.md Phần 4; Nt0 chốt Q8 2026-10-22).
#
#   android/scripts/check_android.sh         luật riêng (check_android_rules.py, có tự kiểm âm) + ./gradlew lint test
#                                            + so ảnh screenshot. Đúng các bước của job `android` (.github/workflows/
#                                            android.yml): check đó xanh là bằng chứng merge cho PR không chạm
#                                            android/app/**. Chạy tại chỗ khi làm; không ghi status.
#   android/scripts/check_android.sh --ui    chỉ test Compose trên emulator (connectedDebugAndroidTest), không chạy lại
#                                            lint + test (CI đã chạy, không trùng hai nơi), rồi ghi commit status
#                                            `local/verify-android` trên HEAD. Bắt buộc ở PR chạm android/app/** và ở
#                                            cổng. Cần tree sạch, HEAD đã push, danh tính git đúng
#                                            (scripts/verify_local.sh --check-identity). Không có máy ảo đang chạy thì
#                                            khởi động AVD `${EXAMSUITE_AVD:-examsuite}` không cửa sổ, chạy xong thì tắt.
#   --no-status                              với --ui: chạy nhưng không ghi status (thử tại chỗ).
#
# Cần: JDK 17, ANDROID_HOME (mặc định ~/Library/Android/sdk); --ui cần thêm gh đã đăng nhập.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

UI=0; POST_STATUS=1
for arg in "$@"; do
  case "$arg" in
    --ui) UI=1 ;;
    --no-status) POST_STATUS=0 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "check_android.sh: tham số lạ: $arg" >&2; exit 2 ;;
  esac
done

gradle() { (cd android && ./gradlew --console=plain "$@"); }

if [[ $UI == 0 ]]; then
  echo "== luật riêng của android/ (thư viện theo ADR 0012, strings.xml)"
  python3 android/scripts/check_android_rules.py
  echo "== ./gradlew lint test validateDebugScreenshotTest"
  gradle lint test :app:validateDebugScreenshotTest
  echo "check_android.sh: đạt"
  exit 0
fi

# ---------- --ui ----------
[[ -z "$(git status --porcelain)" ]] \
  || { echo "check_android.sh --ui: working tree chưa sạch; commit hoặc stash trước để status gắn đúng commit." >&2; exit 2; }
scripts/verify_local.sh --check-identity
SHA="$(git rev-parse HEAD)"; SHORT="${SHA:0:7}"; CONTEXT="local/verify-android"
START=$(date +%s)

post_status() { # state, description
  [[ $POST_STATUS == 1 ]] || return 0
  gh api --silent "repos/{owner}/{repo}/statuses/$SHA" -f state="$1" -f context="$CONTEXT" -f description="${2:0:140}" \
    || echo "check_android.sh: không ghi được commit status (commit đã push chưa?)." >&2
}
if [[ $POST_STATUS == 1 ]]; then
  gh api --silent "repos/{owner}/{repo}/commits/$SHA" \
    || { echo "check_android.sh: commit $SHORT chưa có trên GitHub; push trước." >&2; exit 2; }
  post_status pending "Đang chạy test emulator (local)"
fi

ADB="$ANDROID_HOME/platform-tools/adb"
STARTED_EMULATOR=0
STEP="chuẩn bị emulator"
on_exit() {
  local code=$?
  [[ $code -ne 0 ]] && post_status failure "Thất bại: $STEP"
  if [[ $STARTED_EMULATOR == 1 ]]; then "$ADB" emu kill >/dev/null 2>&1 || true; fi
}
trap on_exit EXIT

if ! "$ADB" devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  AVD="${EXAMSUITE_AVD:-examsuite}"
  echo "== khởi động AVD $AVD (không cửa sổ)"
  "$ANDROID_HOME/emulator/emulator" -avd "$AVD" -no-window -no-audio -no-snapshot-save -no-boot-anim \
    > "android/build-emulator-$SHORT.log" 2>&1 &
  STARTED_EMULATOR=1
  "$ADB" wait-for-device
  for _ in $(seq 1 120); do
    [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]] && break
    sleep 2
  done
  [[ "$("$ADB" shell getprop sys.boot_completed | tr -d '\r')" == 1 ]] || { echo "emulator không khởi động xong" >&2; exit 1; }
fi

STEP="test Compose trên emulator"
echo "== ./gradlew :app:connectedDebugAndroidTest"
RESULTS=android/app/build/outputs/androidTest-results/connected/debug
rm -rf "$RESULTS"
gradle :app:connectedDebugAndroidTest

STEP="đọc kết quả test"
read -r TESTS SKIPPED < <(python3 - "$RESULTS" <<'PY'
import glob, sys, xml.etree.ElementTree as ET
tests = skipped = 0
for path in glob.glob(f"{sys.argv[1]}/*.xml"):
    root = ET.parse(path).getroot()
    for suite in ([root] if root.tag == "testsuite" else root.iter("testsuite")):
        tests += int(suite.get("tests", 0)); skipped += int(suite.get("skipped", 0))
print(tests, skipped)
PY
)
# Không test nào chạy, hoặc có test bị bỏ qua, là thất bại (như verify_local.sh với XCUITest).
[[ $TESTS -gt 0 ]] || { echo "check_android.sh --ui: không có test nào chạy" >&2; exit 1; }
[[ $SKIPPED -eq 0 ]] || { echo "check_android.sh --ui: $SKIPPED test bị bỏ qua" >&2; exit 1; }

MINUTES=$(( ($(date +%s) - START + 59) / 60 ))
post_status success "Emulator ok ($TESTS test Compose, $MINUTES phút); lint + test: check android của CI"
echo "check_android.sh --ui: đạt ($TESTS test Compose trên $SHORT)"
