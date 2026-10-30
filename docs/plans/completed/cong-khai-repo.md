# Execution Plan: Công khai repo (bản public đầu tiên, v0.1.1)

Date: 2026-10-20

## Status

Completed 2026-10-21. Repo `tuann2/exam-suite` public, một commit đầu tiên `265ab44`; cổng
`verify_local.sh --clean --uitest` đạt trên commit đó; Release `v0.1.1` do job `release-dmg` tạo. PR mang plan này là PR
#62 của repo riêng cũ (nay là `tuann2/exam-suite-archive`, private); số PR và SHA nhắc ở các mục dưới thuộc repo đó, trừ
khi ghi rõ là repo public. Plan chuyển sang `completed/` theo yêu cầu của Nt0 (2026-10-30) trong một PR riêng của repo
public.

## Outcome

Repo public `tuann2/exam-suite` có **một commit đầu tiên** chứa cây đã dọn của `main` sau PR này: giấy phép Apache-2.0
("Copyright 2026 Nt0"), không còn dấu vết công ty cũ hay email cá nhân, tên người duyệt là Nt0, lời văn của một dự án cá
nhân, phiên bản 0.1.1. Commit đó qua cổng `scripts/verify_local.sh --clean --uitest` khi repo còn private, rồi repo mới
chuyển public. Nt0 đẩy tag `v0.1.1`; job `release-dmg` của CI đóng hai DMG (build 1001, kèm `LICENSE.txt`, `NOTICE.txt`,
`THIRD_PARTY_NOTICES.txt`, hộp Giới thiệu ghi giấy phép) và tạo GitHub Release. Repo riêng cũ đổi tên thành
`tuann2/exam-suite-archive` (giữ lịch sử, PR, status `local/verify`).

## Context

- Quyết định của Nt0 ngày 2026-10-20 (mục Decisions).
- [ADR 0001](../../decisions/0001-viet-moi-swiftui-khong-chep-gpl.md) (viết mới, không chép code GPLv3; Status ghi giấy
  phép Apache-2.0), [ADR 0006](../../decisions/0006-thu-vien-ngoai.md) (thư viện ngoài; file giấy phép không phải thư
  viện, không cần ADR; Follow-Up ghi việc giữ `THIRD_PARTY_NOTICES.md`).
- Quy trình: [review-and-merge.md](../../process/review-and-merge.md) mục 3 (rủi ro cao: PR chạm fixture test, script
  kiểm, đóng gói phát hành) và mục 4 (một `verify_local.sh --uitest` mỗi PR trên SHA cuối sau review độc lập; plan đi
  cùng PR code).
- Đóng gói: `scripts/make_dmg.sh`; hướng dẫn cài đặt `docs/install.md`; `CHANGELOG.md` mục `[0.1.1]`.
- Fixture kho v1: `Packages/ExamFeatures/Tests/LibraryDataTests/Fixtures/` (README, `LibraryV1FixtureTests.swift`), bất
  biến "Kho thư viện v1 của người dùng mở được ở bản mới" (AGENTS.md).

## Scope

In scope (một PR, rủi ro cao):

1. Giấy phép: `LICENSE` (nguyên văn Apache-2.0), `NOTICE`, `THIRD_PARTY_NOTICES.md` (ZIPFoundation MIT đi kèm app, nguyên
   văn từ checkout đã resolve; các gói chỉ dùng khi test). `make_dmg.sh` chép ba file vào mỗi DMG dạng chữ trơn và kiểm.
   README mục Giấy phép; ADR 0001 Status/Consequences. Không thêm tiêu đề giấy phép vào từng file.
2. Phiên bản 0.1.1: `MARKETING_VERSION` ở cả hai chỗ của `project.yml`; CHANGELOG `## [0.1.1] – bản public đầu tiên`.
3. Bỏ mọi dấu vết công ty cũ: `docs/install.md` bỏ mục chuyển dữ liệu từ bundle ID cũ; `verify_local.sh` chỉ so kho,
   `defaults`, Autosave của hai bundle ID hiện hành; quy tắc an toàn (AGENTS.md, review-and-merge.md) chỉ nêu
   `vn.io.nt0.examsuite`, `vn.io.nt0.examsuite.admin` (vẫn trừ `.uitest`); plan đã xong viết lại trung tính ("bundle
   ID cũ"); xoá hai ghi chú `docs/archive/*.md` đã theo dõi; fixture và test (mục 5).
4. Tên riêng của người duyệt thành "Nt0" ở mọi file theo dõi (tài liệu, comment, thông báo của test/script); bỏ hoặc
   khái quát ghi chú riêng của máy người điều phối (màn hình ngoài, xác thực Automation Mode, khung cửa sổ đo trên máy).
5. Tạo lại `Library-v1.store` một lần với đường dẫn trung tính (mục Decisions), so cũ/mới bằng sqlite3.
6. README cho người đọc public (tóm tắt tiếng Anh ở đầu).
7. Ghi chú CI: comment "tiết kiệm phút Actions" ghi rõ là lý do từ thời repo private; không đổi trigger của `ci.yml`.
8. Theo quyết định thêm của Nt0 (Decisions, 2026-10-20 lần hai): cả hai DMG công khai; tên file đề chứng chỉ thương
   mại thành nhãn trung tính; rút gọn tài liệu `.vce` (ADR 0009, docs/notes/vce-format.md, comment mô tả phép che);
   lời văn "team"/"nội bộ"/bộ phận pháp lý thành lời văn của dự án cá nhân (ADR 0004 đổi tên file); số build = 1000 +
   số commit; `Credits.rtf` vi/en cho hộp Giới thiệu của hai app; DMG phát hành do CI đóng khi đẩy tag; `verify_local.sh`
   đòi email ẩn của GitHub ở HEAD.
9. Theo review độc lập #62: thông báo MIT của repository-harness (file chép vào repo); `make_dmg.sh` chọn đúng khối giấy
   phép của mục ZIPFoundation và kiểm phiên bản gói vừa build; status `local/verify` không ghi tên máy; `make_dmg.sh` quét
   chuỗi cấm trong app (mẫu chung trong repo, chuỗi cấm cục bộ ngoài repo); thứ tự an toàn của bước b; các nit.
10. Theo review lại #62 (cdd2965): chuỗi cấm riêng không còn trong repo dưới bất kỳ dạng nào (B3); phép kiểm danh tính
   xét mọi commit của nhánh, miễn commit trước khi công khai qua `EXAMSUITE_IDENTITY_ALLOW` (S7); giấy phép trong
   `Contents/Resources` của app; hook `pre-push` không phân biệt hoa thường, chặn cả URL có `/` cuối; các nit.

Out of scope:

- Tạo, đổi tên, đổi chế độ hiển thị, push repo GitHub; đẩy tag; tạo Release (người điều phối và Nt0 làm sau merge).
- Bật CI cho PR, bật branch protection trên repo public (quyết định sau của Nt0).
- Đổi hành vi app, giao diện, định dạng đề.
- Viết lại lịch sử git của repo riêng (repo public bắt đầu từ một commit mới).

## Approach

Một PR trên `feature/chuan-bi-public`: đổi tài liệu và script bằng thay thế có kiểm (đếm đúng một chỗ mỗi lần thay), tạo
lại fixture bằng generator có sẵn (`regenerateV1Fixture`, đường ghi thật của app), so fixture cũ/mới bằng sqlite3, chạy đủ
kiểm của repo và một lần `make_dmg.sh` vào thư mục tạm. Review độc lập (rủi ro cao) rồi một `verify_local.sh --uitest` trên
SHA cuối (đủ bộ vì chạm `verify_local.sh`, `Apps/*UITests/**`).

## Risks And Recovery

- **Số PR và SHA trong tài liệu không mở được ở repo mới:** `docs/plans/`, `docs/notes/`, CHANGELOG nhắc `#58`, SHA
  `e639986`… của repo riêng. Chấp nhận; README ghi rõ; repo `exam-suite-archive` giữ lịch sử cho Nt0.
- **Đẩy nhầm lịch sử cũ lên repo mới:** sau `gh repo rename`, bản sao cũ (`~/code/Exam_suite`, các worktree của nó) vẫn
  có `origin` là `tuann2/exam-suite`; khi repo mới lấy tên đó, `git push` từ bản sao cũ sẽ đẩy lịch sử riêng (email tác giả
  cũ, PR) vào repo mới. Bước b: đổi `origin` ngay sau khi đổi tên, cài hook `pre-push` chặn URL của repo mới trong bản
  sao cũ, tạo repo mới ở chế độ **private**, cổng chạy trên repo private, Nt0 xem lại rồi mới chuyển public. Bản sao khác
  của repo cũ (nếu có) cũng phải đổi `origin` và cài hook.
- **File đề có bản quyền trong `docs/archive/` của bản sao cũ** (bị `.gitignore` bỏ qua): repo public dựng từ
  `git archive` của `main`, không từ thư mục làm việc, nên các file đó không vào được. Không chép `docs/archive/` sang
  bản sao mới.
- **Job `release-dmg` hỏng trên runner** (Xcode của runner thiếu SDK, lỗi mạng…): không có Release. Sửa và chạy lại job
  (Re-run của lần chạy theo tag), hoặc Nt0 tạo Release tay từ DMG đóng tại chỗ trên đúng commit gắn tag
  (`gh release create v0.1.1 <hai DMG> --verify-tag`). DMG của CI không trùng từng byte với DMG đóng tại chỗ.
- **Số build:** 1000 + số commit (Nt0 chốt); repo public có một commit nên bản đầu là build 1001, cao hơn build 357 của
  0.1.0. Bản Debug giữ 1.
- **Binary mang đường dẫn tuyệt đối của máy build** (Swift ghi đường dẫn file nguồn): DMG phát hành do CI đóng nên đường
  dẫn là `/Users/runner/…`; `make_dmg.sh` thất bại khi app trúng mẫu chung (thư mục đồng bộ đám mây) hay chuỗi cấm cục
  bộ (không lưu trong repo), chỉ cảnh báo với đường dẫn `/Users/<tên>/` khác runner. Runner CI không có chuỗi cấm cục
  bộ, nên bản quét cục bộ là việc của người điều phối (bước a, c).
- **Cổng cần môi trường riêng:** máy chỉ có một màn hình (rút màn hình ngoài: đã kiểm; bật Mirror chưa thử), màn hình mở
  khoá, không ai dùng chuột/bàn phím; trình chạy test cần Accessibility và Automation Mode (macOS có thể hỏi xác thực);
  app chạy script có Full Disk Access (hoặc `--no-autosave-check`, status ghi rõ); git của máy dùng email ẩn của GitHub
  (`verify_local.sh` dừng nếu HEAD có email khác).
- **Fixture kho v1 tạo lại:** chỉ một lần, bằng generator có sẵn khi V1 còn là schema mới nhất; so cũ/mới cho thấy chỉ
  đường dẫn đề mẫu đổi (mục Validation). Recovery: bản cũ còn trong lịch sử của `exam-suite-archive` (commit ccdccd3).
- **Bản sao lưu dữ liệu bundle ID cũ trên máy của Nt0** không còn được quy tắc an toàn và `verify_local.sh` của repo
  nhắc tới. Agent trên máy đó vẫn không được chạm `~/Library/Application Support` của app (chỉ chế độ cô lập); Nt0 tự giữ
  nhắc riêng nếu cần.
- Recovery chung: PR chỉ đổi tài liệu, script, fixture test, tài nguyên Credits, phiên bản; revert PR là về v0.1.0. Repo
  mới sai khi còn private: xoá repo mới (Nt0), đổi tên `exam-suite-archive` về `exam-suite`, gỡ hook. Đã public mà sai:
  chuyển lại private hoặc xoá Release/tag, sửa, làm lại từ bước a.

## Các bước sau merge (người điều phối và Nt0)

0. **Danh tính git và GitHub** (Nt0, trước mọi bước): `git config --global user.name Nt0`, `git config --global
   user.email 43159607+tuann2@users.noreply.github.com`; trên GitHub (Settings › Emails) bật **Keep my email addresses
   private** và **Block command line pushes that expose my email**.

a. **Commit đơn từ `main`** (người điều phối, thư mục tạm, không push). Chạy trong subshell `( … )` để lỗi không đóng
   cửa sổ Terminal; mọi phép kiểm dừng với mã lỗi khác 0 (fail-closed, kể cả lỗi của `git grep`). Người điều phối chạy
   **bản quét riêng** (mẫu chữ không lưu trong repo: biến `EXAMSUITE_LEAK_PATTERNS` là một biểu thức ERE, hoặc file
   `~/.config/exam-suite/leak-patterns` mỗi dòng một mẫu ERE, không dòng trống) và **bản quét chung** (thư mục đồng bộ
   đám mây của macOS); không ghi mẫu riêng vào repo, PR hay plan:

   ```bash
   (
   set -euo pipefail
   fail() { echo "DỪNG: $*" >&2; exit 1; }
   scan() { local rc=0; git grep -q "$@" || rc=$?; [ "$rc" -eq 1 ] || fail "bản quét trả $rc (0: còn chuỗi cấm, 2: lỗi)"; }
   PRIVATE=(); [ -n "${EXAMSUITE_LEAK_PATTERNS:-}" ] && PRIVATE+=(-e "$EXAMSUITE_LEAK_PATTERNS")
   [ -r ~/.config/exam-suite/leak-patterns ] && PRIVATE+=(-f ~/.config/exam-suite/leak-patterns)
   [ ${#PRIVATE[@]} -gt 0 ] || fail "thiếu mẫu riêng (EXAMSUITE_LEAK_PATTERNS hoặc ~/.config/exam-suite/leak-patterns)"
   ARCHIVE=~/code/Exam_suite
   git -C "$ARCHIVE" fetch origin
   MAIN_TREE="$(git -C "$ARCHIVE" rev-parse 'origin/main^{tree}')"
   PUB="$(mktemp -d)/exam-suite"; mkdir -p "$PUB"
   git -C "$ARCHIVE" archive --format=tar origin/main | tar -x -C "$PUB"
   cd "$PUB" && git init -q -b main
   git config user.name Nt0 && git config user.email 43159607+tuann2@users.noreply.github.com
   git add -A && git commit -q -m "Exam Suite 0.1.1: bản public đầu tiên"
   [ "$(git rev-parse 'HEAD^{tree}')" = "$MAIN_TREE" ] || fail "cây khác origin/main của repo riêng"
   [ "$(git rev-list --count HEAD)" = 1 ] || fail "không phải đúng một commit"
   scan -I -i -E "${PRIVATE[@]}"                          # bản quét riêng, file chữ
   scan -a -i -E "${PRIVATE[@]}"                          # bản quét riêng, cả file nhị phân (fixture, ảnh)
   scan -I -i -E -e 'One[D]rive|Cloud[S]torage'           # bản quét chung
   [ "$(git log --format='%ae %ce')" = "43159607+tuann2@users.noreply.github.com 43159607+tuann2@users.noreply.github.com" ] \
     || fail "danh tính commit"
   echo "OK $PUB $(git rev-parse HEAD)"
   )
   ```

b. **Nt0 đổi tên repo cũ, khoá bản sao cũ, tạo repo mới ở chế độ private** (agent không làm), theo đúng thứ tự:

   ```bash
   PUB=<đường dẫn bước a in ra>       # biến của bước a mất khi subshell kết thúc; đặt lại đúng thư mục đó
   [ -d "$PUB/.git" ] && echo "PUB đúng: $PUB" || echo "PUB SAI: $PUB, DỪNG, không chạy tiếp"   # kiểm trước bước 1
   gh repo rename exam-suite-archive -R tuann2/exam-suite                                          # 1
   git -C ~/code/Exam_suite remote set-url origin https://github.com/tuann2/exam-suite-archive.git  # 2
   cat > ~/code/Exam_suite/.git/hooks/pre-push <<'EOF'                                              # 3
   #!/bin/sh
   # Bản sao lưu trữ: không bao giờ push lên repo public tuann2/exam-suite (plan cong-khai-repo.md, bước b).
   # So không phân biệt hoa thường, chấp nhận cả `.git` và `/` ở cuối URL.
   url="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
   case "$url" in
     *tuann2/exam-suite|*tuann2/exam-suite/|*tuann2/exam-suite.git|*tuann2/exam-suite.git/)
       echo "pre-push: bản sao này là repo lưu trữ, không push lên $2" >&2
       exit 1 ;;
   esac
   exit 0
   EOF
   chmod +x ~/code/Exam_suite/.git/hooks/pre-push
   H=~/code/Exam_suite/.git/hooks/pre-push
   for u in https://github.com/tuann2/exam-suite https://github.com/tuann2/exam-suite.git \
            https://github.com/tuann2/exam-suite/ https://github.com/TUANN2/Exam-Suite.git git@github.com:tuann2/exam-suite.git; do
     "$H" origin "$u" </dev/null 2>/dev/null && echo "HOOK SAI: không chặn $u"      # phải bị chặn
   done
   "$H" origin https://github.com/tuann2/exam-suite-archive.git </dev/null || echo "HOOK SAI: chặn nhầm repo lưu trữ"
   gh repo create tuann2/exam-suite --private                                                      # 4
   git -C "$PUB" remote add origin https://github.com/tuann2/exam-suite.git                        # 5
   git -C "$PUB" push -u origin main
   ```

   Hook nằm trong `.git/hooks` của bản sao cũ nên áp cho cả các worktree của nó (`git config core.hooksPath` phải rỗng).
   Kiểm: `gh repo view tuann2/exam-suite --json visibility` ra `PRIVATE`, repo có một commit.
c. **Cổng trên repo private** (người điều phối, bước 6): clone đủ lịch sử repo mới vào thư mục mới (không dùng bản sao
   cũ), `scripts/verify_local.sh --clean --uitest` (jsonschema: `uv` trên PATH hoặc `EXAMSUITE_UV`; **không** đặt
   `EXAMSUITE_IDENTITY_ALLOW`: repo mới chỉ có commit noreply); status `local/verify` nằm trên commit đó. Tuỳ chọn: `scripts/make_dmg.sh --out <thư mục tạm>` để thử đóng gói trước (DMG tại chỗ không đăng,
   xoá sau). Ghi SHA, status vào Result.
d. **Nt0 xem lại rồi chuyển public** (bước 7, 8): xem repo trên GitHub (README, LICENSE, NOTICE, một commit, không có
   `docs/archive/`), rồi `gh repo edit tuann2/exam-suite --visibility public --accept-visibility-change-consequences`.
e. **Nt0 đẩy tag, CI phát hành** (bước 9): trong bản sao mới, `git tag -a v0.1.1 -m "Exam Suite 0.1.1"` trên đúng commit
   đã qua cổng, `git push origin v0.1.1`. Job `release-dmg` kiểm tag khớp `MARKETING_VERSION`, chạy
   `scripts/make_dmg.sh --clean` trên runner (giấy phép, Credits, quét chuỗi lộ, số build 1001) rồi tạo Release `v0.1.1`
   với hai DMG và ghi chú lấy từ mục `[0.1.1]` của CHANGELOG. Không tạo Release trước khi đẩy tag (job sẽ đỏ khi Release
   đã có). Theo dõi: `gh run watch -R tuann2/exam-suite`. Tải DMG đóng tại chỗ lên Release sau đó là tuỳ chọn.

## Checklist (người điều phối và Nt0)

- [x] PR này: review độc lập APPROVE (rủi ro cao; review lại sau khi sửa); `local/verify` xanh trên SHA cuối; Nt0
      merge. UI test không chạy trên PR này (Nt0 chốt 2026-10-20: PR không đổi code app, chỉ comment, tài liệu, file
      giấy phép, `Credits.rtf`, phiên bản; UI test đủ bộ chạy ở cổng bước c trên cùng cây).
- [x] 0. Danh tính git của bản sao repo public là `Nt0 <43159607+tuann2@users.noreply.github.com>` (Nt0 chốt
      2026-10-20: cấu hình riêng cho thư mục chứa bản sao public, cấu hình toàn cục giữ nguyên); merge trên web GitHub ra
      tác giả noreply.
- [x] a. Script bước a in `OK` (cây trùng `origin/main`, một commit, không dấu vết ở file chữ và nhị phân, danh tính Nt0
      noreply).
- [x] b. Repo riêng thành `exam-suite-archive`; `origin` của mọi bản sao cũ trỏ repo đó; hook `pre-push` chặn URL của
      repo mới (hai lệnh thử ở bước b đúng); repo mới **private**, có đúng một commit.
- [x] c. Cổng `verify_local.sh --clean --uitest` đạt trên commit của repo private (một màn hình, Automation Mode, Full
      Disk Access).
- [x] d. Nt0 xem repo private rồi chuyển public.
- [x] e. Đẩy tag `v0.1.1`; job `release-dmg` xanh; Release `v0.1.1` có hai DMG (build 1001) và ghi chú từ CHANGELOG;
      sha256 ghi vào Result.
- [ ] Nt0 thử tay DMG của Release: mở ba file giấy phép trong ổ (TextEdit, tiếng Việt đúng), cài, Vẫn mở, **Giới thiệu
      về Exam Suite** ghi 0.1.1 (1001) và giấy phép, ZIPFoundation (giao diện tiếng Việt và tiếng Anh, cả hai bản).
      Chưa ghi nhận kết quả khi đóng plan.
- [ ] Quyết định sau (không chặn bản public): bật CI cho PR, branch protection.
- [x] Result; chuyển plan sang `docs/plans/completed/`.

## Progress

- [x] Giấy phép: `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`; `make_dmg.sh` chép và kiểm; README; ADR 0001, 0006.
- [x] 0.1.1: `project.yml`, CHANGELOG.
- [x] Dọn dấu vết công ty cũ: install.md, verify_local.sh, AGENTS.md, review-and-merge.md, plan đã xong, `git rm` hai
      ghi chú `docs/archive/*.md` (link trong docs/README.md sửa).
- [x] Tên riêng của người duyệt → "Nt0" (504 chỗ, 80 file; cộng một chỗ họ tên không dấu ở plan-macos-v1.md); ghi
      chú riêng của máy khái quát hoá.
- [x] Fixture `Library-v1.store` tạo lại, so cũ/mới.
- [x] README public; ghi chú CI và branch protection cho repo public.
- [x] Review độc lập #62: REQUEST CHANGES (B2 thông báo của harness, awk của `make_dmg.sh`; S1 tên máy trong status; S2
      chuỗi lộ trong binary; S5 thứ tự bước b; nit) và tám quyết định thêm của Nt0: đã sửa trong commit sau caf466c.
- [x] Review lại (rủi ro cao) phần sửa: lần hai còn B3 (mẫu chuỗi cấm lộ trong cây) và S7 (kiểm danh tính chỉ HEAD),
      lần ba APPROVE sau khi sửa (S8: bước b đặt lại `PUB`).
- [x] `verify_local.sh` trên SHA cuối sau review (dfc84bf: success, UI test bỏ qua theo quyết định ở Checklist, miễn
      danh tính 1 commit). Ghi chú gốc: `verify_local.sh --uitest` trên SHA cuối sau review (đủ bộ: chạm `verify_local.sh`, `Apps/**`). Nhánh của PR #62
      có commit caf466c (email cũ, trước khi có phép kiểm danh tính), nên lần chạy này đặt
      `EXAMSUITE_IDENTITY_ALLOW=caf466c` (chỉ cho lần chạy đó; status ghi "miễn danh tính 1 commit"); commit đó không
      bao giờ vào repo public (bước a dựng cây mới). Kiểm trước: `EXAMSUITE_IDENTITY_ALLOW=caf466c
      scripts/verify_local.sh --check-identity`.
- [x] Merge (Nt0): `0eddd40` của repo riêng.
- [x] Các bước sau merge 0, a–e (2026-10-20 đến 2026-10-21); Result.
- [x] Chuyển plan sang `docs/plans/completed/` (2026-10-30, PR riêng của repo public theo yêu cầu của Nt0, thay cho "PR
      kế tiếp có code" của mục 4).

## Decisions

- 2026-10-20, Nt0 quyết công khai dự án:
  - **Giấy phép Apache-2.0**, "Copyright 2026 Nt0"; `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` ở gốc repo, bản chữ trơn
    trong mỗi DMG; không tiêu đề giấy phép từng file.
  - **Repo public mới** `tuann2/exam-suite` với một commit đầu chứa cây đã dọn; repo riêng đổi tên `exam-suite-archive`.
    Tên repo giữ nguyên nên `$id` của schema (`https://github.com/tuann2/exam-suite/…`) vẫn đúng.
  - **Bản public đầu tiên v0.1.1** (lần một: DMG đóng tại chỗ, Nt0 tải lên Release; lần hai đổi: CI đóng khi đẩy tag).
  - **Fixture `Library-v1.store` tạo lại một lần** với đường dẫn trung tính, ngoại lệ Nt0 duyệt cho bản public; quy tắc
    "đỏ thì không tạo lại fixture" (AGENTS.md) và "không tạo lại sau khi có schema mới hơn" (Fixtures/README.md) giữ
    nguyên cho mọi lần sau.
  - **Tài liệu giữ hết** (plan, AGENTS.md, CLAUDE.md, quy trình); tên riêng của người duyệt thành "Nt0"; bỏ ghi chú
    riêng của máy Nt0.
  - Cây public không còn tên công ty cũ (mọi dạng viết, kể cả trong bundle ID và tên miền) và email cá nhân.
- 2026-10-20, cách làm (agent, trong khuôn trên):
  - Fixture tạo lại bằng generator có sẵn `LibraryV1FixtureTests/regenerateV1Fixture` (`REGENERATE_LIBRARY_V1_FIXTURE=1`,
    V1 còn là schema duy nhất), dữ liệu `LibraryV1Fixture` không đổi trừ đường dẫn đề mẫu:
    `/Users/hocvien/Library/Application Support/<bundle ID cũ>/Samples/…` thành `…/vn.io.nt0.examsuite/Samples/…`. Không
    thêm generator mới.
  - `make_dmg.sh` đặt tên ba file trong ổ `LICENSE.txt`, `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt` (TextEdit mở bằng nhấp
    đúp); kiểm LICENSE/NOTICE trùng từng byte với repo, `THIRD_PARTY_NOTICES.md` chép nguyên văn giấy phép của
    ZIPFoundation bản vừa build, ổ đúng sáu mục (kiểm theo đường dẫn và số mục, vì HFS+ trả tên dạng NFD).
  - `NOTICE` chỉ ghi bản quyền, ghi công thư viện đi kèm app và (từ review #62) harness chép vào repo; Open Exam Suite
    ghi công ở README và ADR 0001 (không phải thông báo giấy phép: không có mã của nó trong repo).
  - Yêu cầu một màn hình của UI test (Nt0 chốt 2026-10-19, plan giai đoạn 6) đưa lên AGENTS.md và review-and-merge.md
    thay ghi chú riêng về màn hình ngoài; xác thực Automation Mode ghi chung "macOS có thể hỏi xác thực".
  - `ExamKitInfo.version` (phiên bản của module lõi) giữ 0.1.0: lõi không đổi; comment ghi rõ nó theo lõi, không theo
    app.
- 2026-10-20 (lần hai, sau review độc lập #62), Nt0 quyết:
  1. **Đăng cả hai DMG** (Học viên và Admin) ở Releases. overview.md, plan-macos-v1.md, ADR 0003 sửa theo: tách hai bản để
     người làm bài có app gọn, không còn là cách giới hạn ai soạn được đề.
  2. **Tên file đề thật có bản quyền thành nhãn trung tính** ("mẫu .txt thật A", "mẫu .docx thật", "mẫu VCE 1–3") ở
     import.md, docs/notes/vce-format.md, ADR 0009, plan giai đoạn 4, `.gitignore`, docs/README.md và literal của
     `ImportFlowTests` (`MAU_TXT_A`, `MAU042`, số trung tính; ý nghĩa test không đổi).
  3. **`.vce`: giữ tính năng, rút gọn tài liệu.** docs/notes/vce-format.md còn ghi chú ngắn (cách tìm hiểu, phạm vi, kết
     quả thử), ADR 0009 chỉ giữ quyết định, phạm vi, rủi ro; comment mô tả phép che viết trung tính; không đổi code.
  4. **Nt0 nắm toàn quyền với mã nguồn**; lời văn "team", "nội bộ" (nghĩa công ty), bộ phận pháp lý, đơn vị viết lại
     theo dự án cá nhân (ADR 0001, 0002, 0004 đổi tên file thành `…-phan-phoi-rieng.md`, 0009; plan giai đoạn 0, 1, 3, 4,
     5, 6; export-print.md; comment của `validate_exam.py`). "Nội bộ" nghĩa Swift `internal` giữ nguyên. Một lựa chọn
     trong bộ chữ của đề chuẩn 2.000 câu ("Hỏi ý kiến bộ phận pháp …") đổi sang "pháp lý" ở cả hai bộ sinh
     (`StandardExamWords.swift`, `gen_large_exam.py`) và `fixtures/large-exam.digest` sinh lại (`gen_large_exam.py --digest`),
     để lệnh grep cuối không còn từ cũ; đề chuẩn vẫn 2.000 câu, 200 ảnh.
  5. **Số build = 1000 + số commit** (`make_dmg.sh`, `--print-build` cho CI); bản public đầu tiên là 1001, cao hơn 357
     của 0.1.0; bản Debug đối chứng giữ 1.
  6. **Hộp Giới thiệu** của hai app ghi giấy phép Apache-2.0, © 2026 Nt0, ZIPFoundation (MIT, Thomas Zoechling):
     `Apps/<app>/{vi,en}.lproj/Credits.rtf` (macOS tự đọc theo ngôn ngữ của app); `make_dmg.sh` kiểm có ở cả hai app
     và nhắc Apache, Nt0, ZIPFoundation.
  7. **Phát hành bằng CI:** Nt0 đẩy tag `v0.1.1` trên repo mới, job `release-dmg` đóng DMG và tạo Release; tải DMG tại
     chỗ lên sau là tuỳ chọn. Không `gh release create` trước khi đẩy tag.
  8. **Danh tính git:** Nt0 tự đổi git toàn cục sang `Nt0 <43159607+tuann2@users.noreply.github.com>` và bật hai tuỳ chọn
     giữ email riêng tư của GitHub; `verify_local.sh` dừng khi email tác giả hay người commit của HEAD không kết thúc bằng
     `@users.noreply.github.com` (người commit `noreply@github.com` của merge trên web GitHub được chấp nhận).
- 2026-10-20, sửa theo review độc lập #62 (agent):
  - **B2:** `THIRD_PARTY_NOTICES.md` thêm mục "Đi kèm trong repo, không trong app" với nguyên văn giấy phép MIT của
    repository-harness (tag `harness-v0.1.10`, "Copyright (c) 2025 Hoang Nguyen", lấy bằng `gh api` chỉ đọc); NOTICE và
    README ghi công. `make_dmg.sh` chọn khối ```text đầu tiên **của mục `### ZIPFoundation`** và đòi mục mang đúng
    phiên bản gói vừa build (tag của checkout).
  - **S1:** status `local/verify` không ghi tên máy.
  - **S2:** `make_dmg.sh` quét hai app đem đóng (sau review lại: xem B3 bên dưới); đường dẫn `/Users/<tên>/` → cảnh báo,
    liệt kê tiền tố. DMG công khai do CI đóng.
  - **S5:** bước b đổi thứ tự (đổi tên, đổi `origin`, hook `pre-push`, repo mới private, push, cổng, Nt0 xem, chuyển
    public, đẩy tag); bước a fail-closed.
  - **Nit:** review-and-merge.md và `ci.yml` cập nhật cho repo public; `verify_local.sh` bỏ đường dẫn `uv` riêng của máy
    (dùng `uv` trên PATH hoặc `EXAMSUITE_UV`); comment và AGENTS.md trỏ tới tài liệu bền (Fixtures/README.md, ADR) thay
    vì plan này; CHANGELOG `[0.1.1]` chỉ ghi điều người dùng thấy; README ghi giới hạn của `.vce` và macOS 15/26; quy
    tắc một màn hình ghi "rút màn hình ngoài: đã kiểm; bật Mirror chưa thử".

- 2026-10-20, sửa theo review lại #62 (cdd2965; tám quyết định của Nt0 được xác nhận):
  - **B3 (chặn):** mẫu tìm dạng ngoặc của tên riêng (công ty cũ, phần đầu email cũ, tên người, đường dẫn nhà) giải mã
    được ngay, nên không được nằm trong repo. Repo chỉ giữ **mẫu chung** (thư mục đồng bộ đám mây của macOS, viết
    `One[D]rive|Cloud[S]torage`); **chuỗi cấm cục bộ** đọc từ biến `EXAMSUITE_LEAK_PATTERNS` và/hoặc file
    `~/.config/exam-suite/leak-patterns` (ngoài repo), không in ra. Đối chứng âm của `make_dmg.sh` dùng chuỗi dò tổng hợp
    `EXAMSUITE_LEAK_PROBE_7f3a` trong cùng biểu thức và cùng lệnh grep với mọi mẫu; grep lỗi (mẫu cục bộ sai) thì dừng.
    `make_dmg.sh` quét cả thư mục đóng gói trước khi tạo DMG. Bước a của plan chỉ mô tả bản quét riêng và bản quét
    chung, không ghi mẫu. Lời chú thích đổi sang "chuỗi cấm cục bộ (không lưu trong repo)".
  - **S7:** phép kiểm danh tính của `verify_local.sh` xét mọi commit từ merge-base với `origin/main` tới HEAD (HEAD khi
    đã nằm trong `origin/main`); lời khuyên `--amend` chỉ cho commit ở đỉnh chưa push và không phải merge, còn lại "viết
    lại các commit của nhánh trước khi merge"; commit có từ trước khi công khai miễn qua `EXAMSUITE_IDENTITY_ALLOW`
    (cảnh báo từng commit, status ghi số commit miễn); thêm `--check-identity`; đối chứng âm gồm cả phép miễn.
  - **Nit:** `make_dmg.sh` chép `LICENSE.txt`, `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt` vào `Contents/Resources` của mỗi
    app trước khi ký và kiểm; hook `pre-push` so không phân biệt hoa thường, chặn cả `/` cuối; bước a chạy trong subshell;
    link tới plan này dùng tên plan, không đường dẫn `active/` (ADR 0001, plan giai đoạn 6); plan giai đoạn 6 bước 2 ghi
    rõ việc nhắc Nt0 bật lại xác thực Automation Mode; mã đề thử `ON-092` của `DocxImportTests` thành `ON-042`.

## Validation

- Fixture: so `old.store` (v0.1.0, sha256 `2872b807…`) với bản tạo lại bằng sqlite3: `.schema` trùng; số dòng trùng
  (ZLIBRARYITEM 3, ZATTEMPTITEM 3, Z_PRIMARYKEY 5, ACHANGE 6, ATRANSACTION 4, ATRANSACTIONSTRING 1, Z_METADATA 1,
  Z_MODELCACHE 1); mọi cột của 3 mục và 3 lần thi trùng (bookmark, payload so bằng độ dài và băm) trừ `ZLASTKNOWNPATH` của
  đề mẫu và `Z_PK` của mục (thứ tự chèn); `ATRANSACTION.ZTIMESTAMP` (thời điểm tạo, bảng lịch sử) khác; metadata trùng
  trừ UUID kho (NSStoreModelVersionHashes, NSPersistenceFrameworkVersion 1526, checksum); Z_MODELCACHE trùng; PRAGMA trùng
  (journal_mode delete, 28 trang, auto_vacuum 2); bản quét riêng (chuỗi cấm cục bộ) trên file ra 0.
  `LibraryV1FixtureTests` đạt (mở kho, hash model, Thư viện).
- `make_dmg.sh`: đối chứng âm của phép so giấy phép ZIPFoundation (đổi năm bản quyền trong mục ZIPFoundation; bỏ khối
  của mục đó khi khối của harness còn) đều báo khác; phép quét chuỗi cấm: chuỗi dò bị bắt mỗi lần, thử riêng với mẫu cục
  bộ giả qua biến và qua file (trúng), chuỗi vô hại (không trúng), mẫu ERE sai (dừng).
- `verify_local.sh --check-identity` trên nhánh của PR #62: không miễn thì dừng ở caf466c ("viết lại các commit của
  nhánh"); `EXAMSUITE_IDENTITY_ALLOW=caf466c` thì đạt kèm cảnh báo; tiền tố 4 ký tự không được nhận. Trong bản sao tạm có
  thêm commit đỉnh chưa push với email khác: dừng với lời khuyên `--amend`.
- Kiểm của repo trên SHA của PR: xem PR (check.sh, check_localization.py thường/`--require-en`/`--freshness`/
  `--built-apps`, check_boundaries.py, uitest_plan.py `--self-test`, validate_exam.py `--all`, check_validator_parity.py,
  check_quit_sheets.py, check_colors.py, `make_dmg.sh --clean --out <thư mục tạm>`), các lệnh grep cuối.
- Cổng repo mới (bước c), repo còn private:
  - `d0c3235` (2026-10-20): thất bại ở một vấn đề của kiểm trợ năng, cả hai lần chạy của `NewExamFlowUITests`: gợi ý
    "Chọn 2 đáp án" (màu nhấn của nền đọc) ở xem trước của cửa sổ soạn đề phía sau, màn "Trước khi thi của Thử đề này";
    cùng chữ đó đạt ở màn "Cửa sổ soạn đề" khi cửa sổ ở trước. 9 test UI khác đạt.
  - Sửa: thêm "Chọn 2 đáp án" vào ngoại lệ có sẵn của màn đó (chữ của xem trước phía sau, `NewExamFlowUITests`); chạy
    riêng lớp đó: đạt. Gộp vào commit đầu (Nt0 chốt, repo còn private) thành `265ab44`, đẩy bằng `--force-with-lease`;
    quét chuỗi cấm lại: 0.
  - `265ab44` (2026-10-21): `local/verify` success: macOS ok (clean), UI test ok (Học viên 6, Admin 4 test, đủ bộ, kho
    thật không đổi, kiểm Autosave: bỏ qua), Linux ok, 19 phút.

## Result

- **Repo public:** https://github.com/tuann2/exam-suite, chuyển public 2026-10-21. Commit đầu tiên `265ab44` (tác giả
  và người commit Nt0 noreply): cây của `main` repo riêng sau PR #62 (`0eddd40`) cộng bản sửa ngoại lệ kiểm trợ năng ở
  mục Validation.
- **Repo riêng cũ:** `tuann2/exam-suite-archive` (private) giữ lịch sử, PR #1–#62, status `local/verify` và Release
  `v0.1.0`. Bản sao cũ trỏ repo đó, có hook `pre-push` chặn URL của repo public.
- **Cổng:** `local/verify` success trên `265ab44` (mục Validation).
- **Phát hành:** tag `v0.1.1` → `265ab44`. Job `release-dmg` chạy ở
  https://github.com/tuann2/exam-suite/actions/runs/39617311893 (hai job kiểm skipped) và tạo Release
  https://github.com/tuann2/exam-suite/releases/tag/v0.1.1 (2026-10-21, không phải prerelease): build 1001, runner
  macOS 15.7.9, Xcode 26.3.
  - `ExamSuite-0.1.1.dmg` sha256 `57ad4c39265c216b2573d641804c45bd6f8d7b844c167bc595323a825e523ff7`
  - `ExamSuiteAdmin-0.1.1.dmg` sha256 `84e4d0bad1126e68eb65d7d560e22241d97a647c05b1e9d5959201fa3491446a`
- **Còn mở (không chặn):** Nt0 thử tay DMG của Release (hộp Giới thiệu vi/en, sáng/tối, file giấy phép trong ổ); quyết
  định bật CI cho PR và branch protection của repo public.
