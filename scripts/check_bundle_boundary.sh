#!/usr/bin/env bash
# Kiểm tra trên sản phẩm build: bản Học viên không chứa ký hiệu của module chỉ bản Admin
# (AuthoringFeature, AuthoringData, ExamImport), bản Admin thì có AuthoringFeature (bằng chứng dương
# để chắc phép quét còn hoạt động). AuthoringData/ExamImport chỉ in số ký hiệu của bản Admin, không
# bắt buộc: module chưa được AuthoringFeature dùng thì trình liên kết có thể bỏ, và ExamImport có thể chưa có.
# Cả hai bản không chứa thư viện chỉ dùng trong test: swift-snapshot-testing (SnapshotTesting) và các gói nó ghim
# (CustomDump, IssueReporting, SwiftSyntax), không ký hiệu, không file.
# Xcode 26+ ở cấu hình Debug đặt code vào "<App>.debug.dylib", nên quét mọi Mach-O trong bundle.
# Bundle tài nguyên của package (String Catalog, giai đoạn 5) đi theo module: bản Học viên không có
# ExamFeatures_<module>.bundle của module chỉ bản Admin (kể cả AdminShell), bản Admin có của AuthoringFeature
# (docs/product/accessibility-localization.md, mục Cách làm).
# Bản iOS (docs/product/plan-ios-v1.md) là một bản Học viên: cùng các kiểm của bản Học viên macOS trên app iOS đã build
# (bundle phẳng: bundle tài nguyên ở gốc .app), khi truyền thư mục Products thứ hai.
# Thẩm quyền: docs/decisions/0003-hai-ban-app-mot-codebase.md, docs/decisions/0010-snapshot-testing.md
#   scripts/check_bundle_boundary.sh <thư mục chứa "Exam Suite.app" và "Exam Suite Admin.app"> [<Products của bản iOS>]
set -euo pipefail
DIR="${1:-build/DerivedData/Build/Products/Debug}"
IOS_DIR="${2:-}"
MODULES=(AuthoringFeature AuthoringData ExamImport)
TEST_ONLY=(SnapshotTesting CustomDump IssueReporting SwiftSyntax)

count_symbols() { # app, tên module
  local app="$1" module="$2" total=0 n
  while IFS= read -r f; do
    n=$(nm "$f" 2>/dev/null | grep -c -- "$module" || true)
    total=$((total + n))
  done < <(find "$app" -type f \( -perm +111 -o -name '*.dylib' \))
  echo "$total"
}

STUDENT="$DIR/Exam Suite.app"; ADMIN="$DIR/Exam Suite Admin.app"
[[ -d "$STUDENT" && -d "$ADMIN" ]] || { echo "check_bundle_boundary.sh: không thấy hai .app trong $DIR"; exit 2; }
FAILED=0
for module in "${MODULES[@]}"; do
  S=$(count_symbols "$STUDENT" "$module"); A=$(count_symbols "$ADMIN" "$module")
  echo "$module symbols: Học viên=$S, Admin=$A"
  if [[ "$S" -ne 0 ]]; then
    echo "FAIL: bản Học viên chứa $module (docs/decisions/0003). Kiểm project.yml và StudentShell."; FAILED=1
  fi
  if [[ "$module" == AuthoringFeature && "$A" -eq 0 ]]; then
    echo "FAIL: bản Admin không có ký hiệu AuthoringFeature; phép quét không còn đúng hoặc AdminShell mất phụ thuộc."; FAILED=1
  fi
done
for module in "${MODULES[@]}" AdminShell; do
  if [[ -e "$STUDENT/Contents/Resources/ExamFeatures_$module.bundle" ]]; then
    echo "FAIL: bản Học viên chứa bundle tài nguyên ExamFeatures_$module.bundle (docs/decisions/0003)."; FAILED=1
  fi
done
if [[ ! -d "$ADMIN/Contents/Resources/ExamFeatures_AuthoringFeature.bundle" ]]; then
  echo "FAIL: bản Admin thiếu ExamFeatures_AuthoringFeature.bundle (catalog của Soạn đề); phép kiểm bundle tài nguyên không còn đúng."
  FAILED=1
fi
for module in "${TEST_ONLY[@]}"; do
  S=$(count_symbols "$STUDENT" "$module"); A=$(count_symbols "$ADMIN" "$module")
  F=$(find "$STUDENT" "$ADMIN" -iname "*$module*" | wc -l | tr -d ' ')
  echo "$module (chỉ test) symbols: Học viên=$S, Admin=$A; file=$F"
  if [[ "$S" -ne 0 || "$A" -ne 0 || "$F" -ne 0 ]]; then
    echo "FAIL: app chứa $module, thư viện chỉ dùng trong test (docs/decisions/0010). Kiểm Package.swift và project.yml."
    FAILED=1
  fi
done
IOS_NOTE=""
if [[ -n "$IOS_DIR" ]]; then
  IOS="$IOS_DIR/Exam Suite.app"
  [[ -f "$IOS/Info.plist" ]] || { echo "check_bundle_boundary.sh: không thấy app iOS trong $IOS_DIR"; exit 2; }
  for module in "${MODULES[@]}" "${TEST_ONLY[@]}"; do
    I=$(count_symbols "$IOS" "$module")
    F=$(find "$IOS" -iname "*$module*" | wc -l | tr -d ' ')
    echo "$module symbols: iOS=$I; file=$F"
    if [[ "$I" -ne 0 || "$F" -ne 0 ]]; then
      echo "FAIL: bản iOS chứa $module (docs/decisions/0003, 0010). Kiểm project.yml và Packages/MobileFeatures."; FAILED=1
    fi
  done
  if [[ -e "$IOS/ExamFeatures_AdminShell.bundle" ]]; then
    echo "FAIL: bản iOS chứa bundle tài nguyên ExamFeatures_AdminShell.bundle (docs/decisions/0003)."; FAILED=1
  fi
  # Bằng chứng dương như AuthoringFeature của bản Admin: app iOS có ký hiệu của MobileShell, để phép quét không đạt
  # khi thật ra không quét được gì.
  I=$(count_symbols "$IOS" MobileShell)
  echo "MobileShell symbols: iOS=$I"
  if [[ "$I" -eq 0 ]]; then
    echo "FAIL: bản iOS không có ký hiệu MobileShell; phép quét không còn đúng hoặc target ExamSuiteiOS mất phụ thuộc."
    FAILED=1
  fi
  IOS_NOTE=", bản iOS cũng không (bản iOS có MobileShell)"
fi
[[ $FAILED == 0 ]] || exit 1
echo "ok   bản Học viên không chứa ${MODULES[*]} (ký hiệu và bundle tài nguyên)${IOS_NOTE}; bản Admin có AuthoringFeature; không app nào chứa ${TEST_ONLY[*]}"
