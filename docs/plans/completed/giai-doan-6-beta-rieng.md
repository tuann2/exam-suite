# Execution Plan: Giai đoạn 6 · Beta riêng

Date: 2026-10-18 (sửa 2026-10-18 sau khi Nt0 trả lời 8 câu hỏi; đổi tên file từ `giai-doan-6-beta-noi-bo.md` ngày
2026-10-18, mục G6 Nt0; đóng 2026-10-19)

## Status

Completed (đóng 2026-10-19 trong PR cuối "G6 Đóng giai đoạn 6: cổng G3, phát hành v0.1.0", nhánh `feature/g6-cong-g3`;
lập 2026-10-18). Merge vào `main`: #58 (G6.1), #59 (G6 Nt0), #60 (G6.2). **G3 đạt** theo kết quả test tay của Nt0
(2026-10-19, beta build 349, không lỗi; macOS 15 không kiểm, rủi ro chấp nhận). Còn sau khi PR cuối merge: cổng
`verify_local.sh --clean --uitest` trên SHA phát hành, đóng DMG, gắn tag `v0.1.0` khi Nt0 báo (Result, Các bước phát
hành). Giai đoạn 6 là giai đoạn cuối của lộ trình v1 (plan-macos-v1.md).

## Outcome

Hai DMG (bản Học viên `ExamSuite`, bản Admin `ExamSuiteAdmin`), build Release arm64 từ một SHA `main` đã qua
`scripts/verify_local.sh --clean --uitest`, ký ad-hoc, kèm hướng dẫn cài đặt; nhóm dùng thử cài từ DMG và
dùng được cả hai bản. Lỗi beta mức cao đã sửa. **Cổng G3** (plan-macos-v1.md, Lộ trình): không còn lỗi mức cao, đạt tiêu
chí ở mục Phạm vi của plan-macos-v1.md, có người test tay trên Mac (giao diện, VoiceOver, mở file từ Finder, cài từ DMG
cho cả hai bản). Qua G3 là v1.0 riêng.

## Context

- Lộ trình: [plan-macos-v1.md](../../product/plan-macos-v1.md) dòng "Beta riêng" (sửa lỗi beta, DMG cho hai bản, hướng
  dẫn cài đặt; G3) và mục "Build và phân phối riêng" (arm64, mỗi bản một DMG; bản Học viên qua ổ chung, bản Admin qua
  kênh riêng; bảng ký ad-hoc / Developer ID + notarize; cập nhật thủ công ở beta; semver và `CHANGELOG.md`). Cập nhật
  18/10/2026: giai đoạn 6 làm trong ít PR nhất có thể; CI GitHub chạy đúng một lần, khi Nt0 báo.
- Quy trình: [review-and-merge.md](../../process/review-and-merge.md) mục 1 (cổng: `verify_local.sh --clean --uitest`
  trên SHA đem đi phát hành; workflow `CI` chỉ chạy khi Nt0 báo, dự kiến một lần cho bản beta trước G3), mục 4 (nhịp
  làm việc: một `verify_local.sh --uitest` mỗi PR trên SHA cuối sau review độc lập; xếp chồng tối đa một tầng; không PR
  chỉ tài liệu; một việc nặng mỗi lúc).
- Hiện trạng: `project.yml` ký ad-hoc (`CODE_SIGN_IDENTITY: "-"`, `DEVELOPMENT_TEAM` trống), `MARKETING_VERSION`
  `0.1.0`, `CURRENT_PROJECT_VERSION` `1` ở cả hai target; chưa có biểu tượng app (không có asset catalog); `.github/workflows/ci.yml`
  chạy tay hoặc khi gắn tag `v*`, còn dòng TODO "khi gắn tag v*, archive, tạo DMG bằng hdiutil, đính kèm release".
  Bản đang cài trên máy Nt0: Release ký ad-hoc từ SHA cuối của giai đoạn 5 (Result của
  [plan giai đoạn 5](../completed/giai-doan-5-hoan-thien.md)).
- Việc chuyển sang từ trước: cổng G2 chưa chạy (giai đoạn 3, 4: Nt0 test trên bản cài); danh sách test tay của giai
  đoạn 5 (Result của plan giai đoạn 5); kiểm `~/Library/Autosave Information/` của `verify_local.sh --uitest` cần Full
  Disk Access.
- ADR 0006: không thêm thư viện khi chưa có ADR (Sparkle ngoài phạm vi). ADR 0003: bản Học viên không chứa phần soạn
  đề (`check_bundle_boundary.sh` chạy trên bản Release đem đóng DMG).
- **Automation Mode:** trình chạy test cần Automation Mode; macOS có thể hỏi xác thực (người điều phối xác nhận; không
  agent nào đổi cài đặt này).

## Scope

In scope:

- Script đóng DMG cho hai bản từ bản Release đã build (`hdiutil`), ký ad-hoc; kiểm DMG đọc được, app trong DMG đúng chữ ký,
  bản Học viên không chứa phần soạn đề, không chứa code chế độ cô lập của UI test.
- Phiên bản `0.1.0` giữ nguyên; số build tăng theo mỗi lần đóng DMG; mục phát hành trong `CHANGELOG.md`.
- Biểu tượng tạm cho hai bản (agent tạo, Nt0 thay sau).
- Hướng dẫn cài đặt tiếng Việt `docs/install.md`, bản sao trong DMG.
- **Nền đọc** cho vùng nội dung câu khi làm bài/luyện tập (Nt0 thêm 2026-10-18): 5 nền có sẵn, chọn ở menu Xem (View)
  và ở Trước khi thi.
- `ci.yml`: khi gắn tag `v…`, build hai DMG bằng cùng script và đính vào GitHub Release; chạy **đúng một lần**, khi Nt0
  báo.
- Sửa lỗi beta Nt0 báo (mức cao bắt buộc trước G3).
- Cổng G3: Nt0 tự test trên Mac của mình theo checklist; đóng plan.
- **Đổi sang dự án cá nhân của Nt0** (Nt0 thêm 2026-10-18, mục G6 Nt0): credit, bundle ID `vn.io.nt0.*`, UTType
  `vn.io.nt0.exam`, `$id` của schema, cách giới thiệu dự án trong tài liệu, hướng dẫn chuyển dữ liệu từ bản cũ.

Out of scope:

- Developer ID, notarize; Sparkle, tự cập nhật, MDM; bản Intel/universal; App Store; sandbox; đổi định dạng đề hay kho
  thư viện; tính năng mới ngoài lỗi beta và nền đọc; mã chuyển dữ liệu từ bundle ID cũ (Nt0 tự chép); cửa sổ "Có gì mới" trong app (Nt0 bỏ 2026-10-18); màu nền tự chọn (color picker); ảnh nền DMG; ảnh chụp màn hình trong hướng dẫn; nhóm dùng thử
  ngoài Nt0.

## Approach

**Ba PR**, nối tiếp, cùng rẽ từ `main`: G6.1, G6 Nt0 (mục 1b, Nt0 thêm 2026-10-18) và G6.2 (Nt0 chốt 2026-10-18: gom
tối đa; ban đầu hai PR). Mỗi PR: review độc lập bằng phiên agent mới (cả ba rủi ro cao), sửa theo review, rồi **một**
`verify_local.sh --uitest` trên SHA cuối (lớp test theo bảng map).

1. **G6.1 Beta 0.1.0: đóng gói DMG và nền đọc** (một PR; rủi ro cao: `project.yml`, cách phát hành, CI, shell hai bản).
   Bản beta cho Nt0 **là đầu ra của chính PR này**, không phải bước riêng: sau khi review xong và `local/verify` xanh trên
   SHA cuối, người điều phối chạy `make_dmg.sh` trên đúng SHA đó và đưa hai DMG cho Nt0 cài theo `docs/install.md` (thay
   cho cài thẳng vào /Applications như các giai đoạn trước). Nt0 test beta trong lúc chờ hoặc sau khi merge.

   **Đóng gói:**
   - `scripts/make_dmg.sh` (chỉ công cụ macOS: `xcodebuild`, `codesign`, `hdiutil`):
     - đòi tree sạch; build Release hai scheme vào `build/DerivedData-Release-DMG`;
     - số build `CURRENT_PROJECT_VERSION` = số commit của `HEAD` (`git rev-list --count HEAD`), truyền lúc build, không
       sửa repo mỗi lần;
     - chạy `check_bundle_boundary.sh` và `check_release_strings.sh` trên đúng hai app đó;
     - ký ad-hoc (`codesign --force --deep -s -`), đóng DMG nén chỉ đọc gồm app, lối tắt Applications và
       `Hướng dẫn cài đặt.txt`;
     - tên file `ExamSuite-0.1.0.dmg`, `ExamSuiteAdmin-0.1.0.dmg`; nhãn ổ "Exam Suite 0.1.0", "Exam Suite Admin 0.1.0";
       SHA và số build ghi trong file `.txt` đi kèm (không trong tên file);
     - kiểm `hdiutil verify`, `codesign --verify --deep --strict` trên app trong DMG (gắn ổ chỉ đọc vào thư mục tạm).
   - Biểu tượng tạm: script Swift/CoreGraphics (không thư viện mới) vẽ biểu tượng chữ đơn giản, teal cho Học viên, burgundy
     cho Admin, xuất bộ PNG vào asset catalog của từng app; khai báo trong `project.yml`. Script giữ trong repo để vẽ lại.
   - `docs/install.md` (tiếng Việt): mở DMG, kéo vào Applications, lần mở đầu với app ký ad-hoc (Open Anyway), máy admin
     cài cả hai bản và `.exam` mở bằng bản nào, cập nhật bản mới (giữ dữ liệu), gỡ cài và chỗ dữ liệu người dùng.
   - `CHANGELOG.md`: mục `[0.1.0] – beta riêng` (gồm nền đọc).
   - `ci.yml`: thay dòng TODO bằng job khi gắn tag `v*`: chạy `make_dmg.sh` trên runner macOS, tạo GitHub Release đính hai
     DMG. Không chạy trong PR này.

   **Nền đọc** (Nt0 chốt 2026-10-18; lý do: người dùng nhìn màn hình làm bài rất lâu):
   - Năm nền: **Theo hệ thống** (mặc định, theo sáng/tối của macOS), **Trắng**, **Giấy ngà** (tông ấm), **Xám dịu**,
     **Tối**. Mỗi nền là một bộ màu trong bảng màu (nền, chữ, chữ phụ, viền, nền lựa chọn đang chọn, màu Đúng/Sai/đánh
     dấu đặt trên nền đó), không viết màu trong view (`check_colors.py`).
   - Phạm vi: **vùng nội dung câu**, cùng phạm vi với cỡ chữ nội dung (phương án 5): cửa sổ làm bài, Xem lại bài, xem
     trước của Soạn đề. Bảng câu hỏi, thanh bên, thanh công cụ, thanh dưới giữ giao diện macOS. PDF/bản in luôn sáng, không
     theo nền đọc.
   - Nền đã chọn **giữ nguyên khi macOS đổi sáng/tối** (như app Sách); chỉ "Theo hệ thống" đổi theo.
   - Chọn ở **menu Xem › Nền đọc** (View › Reading Background; cạnh Phóng to/Thu nhỏ, đổi được khi đang làm bài) và ở **Trước khi thi** (ô chọn
     có mẫu nhỏ); một lựa chọn cho cả app, không theo từng đề; nhớ trong `defaults` của app (UI test dùng kho cô lập,
     như cỡ chữ nội dung).
   - Đổi thẩm quyền: accessibility-localization.md mục "Dark Mode và tương phản" ghi "không có công tắc riêng"; PR này
     thêm ngoại lệ nền đọc cho vùng nội dung câu (Nt0 chốt), và mục Kiểm thêm test tương phản cho cả năm nền.
   - Test: test tương phản mọi bộ màu của năm nền (chữ ≥ 4,5:1, biểu tượng/chữ lớn ≥ 3:1, kể cả Đúng/Sai trên lựa chọn
     đang chọn); snapshot cửa sổ làm bài ở từng nền (sáng, một ảnh mỗi nền) và "Tối" khi macOS sáng; một đoạn UI test
     đổi nền qua menu trong luồng có sẵn (không thêm lần mở app); Reduce Transparency và Increase Contrast vẫn áp dụng.

   UI test: `project.yml` đổi → đủ bộ, một lần trên SHA cuối.

1b. **G6 Nt0 Đổi sang dự án cá nhân Nt0** (một PR, rẽ từ `main` sau khi G6.1 merge; rủi ro cao: bundle ID, nơi lưu dữ
   liệu, UTType; chạm `project.yml`, `ExamFile`, `schema/`, `Apps/**`):
   - credit "© 2026 Nt0" (`project.yml`, `InfoPlist.xcstrings` vi/en của hai app);
   - bundle ID `vn.io.nt0.examsuite`, `vn.io.nt0.examsuite.admin` (UI test: đuôi `.uitest`, trình chạy `…uitests`), nhãn
     hàng đợi và subsystem log, `LibraryConfiguration`, test và hạ tầng UI test, `make_dmg.sh`, `verify_local.sh` (so
     kho/defaults thật của cả bundle ID mới lẫn bundle ID cũ);
   - UTType `vn.io.nt0.exam` (`ExamFileFormat`, khai báo export/import của hai app); `$id` của schema trên GitHub; định
     dạng gói không đổi;
   - tài liệu: "dự án cá nhân của Nt0", "beta riêng", "phân phối riêng"; quy tắc an toàn dữ liệu thật (AGENTS.md,
     review-and-merge.md) phủ cả hai họ bundle ID; `docs/install.md` mục "Chuyển dữ liệu từ bản cũ".
   UI test: `project.yml` và hạ tầng UI test đổi → đủ bộ, một lần trên SHA cuối sau review độc lập.

2. **G6.2 Sửa lỗi beta, cổng G3, phát hành** (PR cuối của giai đoạn; rẽ từ `main` sau khi G6.1 merge; thêm PR chỉ khi lỗi
   nằm ở nhiều vùng rời nhau, PR cuối mang cổng):
   - chỉ lỗi Nt0 báo khi dùng beta; mỗi lỗi có test khi máy kiểm được; lỗi cần quyết định sản phẩm thì hỏi trước;
   - cổng: `verify_local.sh --clean --uitest` trên SHA phát hành; đóng DMG từ đúng SHA đó cho Nt0 test lần cuối theo
     checklist G3; CHANGELOG, Result, chuyển plan sang `docs/plans/completed/`;
   - **lần CI duy nhất**, khi Nt0 báo sau khi G3 đạt: gắn tag `v0.1.0` trên SHA đó, CI đóng DMG và tạo GitHub Release;
     ghi run ID, thời gian, kết quả vào Result;
   - Không có lỗi nào cần sửa thì PR này chỉ còn cổng và đóng plan; khi đó gắn vào PR code gần nhất nếu có (mục 4), không
     thì là PR duy nhất được phép chỉ có tài liệu của giai đoạn (đóng giai đoạn cần bằng chứng cổng trên SHA).

Checklist G3 (Nt0 tự test trên Mac của mình, macOS 26; không giới hạn thời gian):

- Cài từ DMG cả hai bản: lần mở đầu (Vẫn mở/Open Anyway), biểu tượng (kiểm biểu tượng có bị macOS 26 đặt vào ô xám
  không: biểu tượng tạm là PNG trong khung bo góc, không phải định dạng biểu tượng mới), đề mẫu, mở `.exam` từ Finder (bản
  nào mở, đúng vai Viewer/Editor), cài đè bản mới giữ dữ liệu, gỡ cài.
- Nền đọc: thử cả năm nền khi làm bài lâu, đổi sáng/tối của macOS (nền đã chọn giữ nguyên), đổi nền khi đang làm bài,
  VoiceOver và Increase Contrast trên từng nền. Phần do AppKit vẽ trong vùng câu hỏi (thanh cuộn, chữ đang được chọn, menu
  chuột phải trên chữ) ở nền **Tối khi macOS sáng** và **Giấy ngà khi macOS tối**.
- Cổng G2 chưa chạy (giai đoạn 3, 4): làm trọn đề thật, soạn đề và import đề thật.
- Danh sách test tay của giai đoạn 5 (Result của plan giai đoạn 5): VoiceOver, Dark Mode, Increase Contrast, Reduce
  Transparency, ⌘+/⌘=/⌘0, in thật A4/Letter, tìm chữ trong Preview, cửa sổ xếp lát, Autosave, khôi phục sau crash, mở từ
  Finder, đề 2.000 câu.
- Không còn lỗi mức cao: crash, mất dữ liệu (lần thi, đề đang soạn), chấm sai điểm, không mở được đề hợp lệ, lộ đáp án
  ở đề `hideAnswers`.
- Bundle ID mới (G6 Nt0): trước khi cài DMG mới, xoá hoặc nén `.zip` **mọi** bản app cũ (bundle ID cũ) trên máy:
  Applications, Tải về, bản sao lưu từ các lần cài trước (`~/ExamSuite-backup/…`), thư mục `build/` của các bản sao repo
  (`mdfind` theo bundle ID cũ để tìm; tuỳ chọn `lsregister -gc`, install.md);
  chép dữ liệu theo `docs/install.md` (mục Chuyển dữ liệu từ bản cũ) **trước** khi mở bản mới, Thư viện và Lịch sử thi
  trở lại đủ; nhấp đúp `.exam` trong Finder (cả file có từ trước) mở bằng bản mới, Mở bằng không còn hai "Exam Suite";
  **Thêm đề…** (⌘O) của bản Học viên và hộp **Mở** của bản Admin chọn được file `.exam` có sẵn; Giới thiệu về Exam Suite
  ghi "© 2026 Nt0"; chân trang PDF kết quả là "Kết quả luyện tập, không có giá trị xác nhận".

**Kết quả G3** (Nt0 test tay 2026-10-19 trên Mac của mình, macOS 26, bản beta build 349 đóng từ 9fff274). Cột "Nt0
test" ghi đúng lời Nt0: đã test "Cài từ DMG + chuyển dữ liệu, Import + soạn đề, Nền đọc + Dark Mode, Làm bài thật, in,
VoiceOver, Thi thử"; kết quả "Không có lỗi".

| Mục checklist | Nt0 test | Kết quả |
| --- | --- | --- |
| Cài từ DMG; bundle ID mới | Cài từ DMG + chuyển dữ liệu | Không có lỗi |
| Cổng G2 còn hoãn: soạn đề, import đề thật | Import + soạn đề | Không có lỗi |
| Nền đọc | Nền đọc + Dark Mode | Không có lỗi |
| Cổng G2 còn hoãn: làm trọn đề thật; danh sách test tay giai đoạn 5 | Làm bài thật, in, VoiceOver, Thi thử | Không có lỗi |
| Không còn lỗi mức cao | Beta build 349 | Không có lỗi |
| macOS 15 (review độc lập #60 S4) | Không kiểm (không có máy) | Rủi ro chấp nhận (Nt0 chốt 2026-10-19, Risks) |

Các mục con của checklist không được báo riêng từng mục: Increase Contrast, Reduce Transparency, ⌘+/⌘0, in khổ Letter,
tìm chữ trong Preview, cửa sổ xếp lát, Autosave, khôi phục sau crash, đề 2.000 câu, cài đè, gỡ cài. **G3 đạt theo quyết
định của Nt0** (2026-10-19: "Không có lỗi" sau bốn nhóm đã test). Bằng chứng máy cho SHA phát hành: cổng
`verify_local.sh --clean --uitest` (Result).

## Risks And Recovery

- **macOS chặn app ký ad-hoc** (Gatekeeper, quarantine khi tải về): hướng dẫn cài có bước Open Anyway; Nt0 kiểm bằng DMG
  đã tải lại (có cờ quarantine), không chỉ bản build tại chỗ.
- **DMG chứa nhầm bản Debug hay code chế độ cô lập:** script build Release từ tree sạch và chạy `check_release_strings.sh`,
  `check_bundle_boundary.sh` trên đúng app đem đóng.
- **Máy cài cả hai bản, Finder mở `.exam` bằng bản sai:** vai Viewer/Editor có từ giai đoạn 0; kiểm tay ở G3.
- **Ghi đè dữ liệu người dùng khi cài bản mới:** kho và cài đặt ở `~/Library/Application Support/<bundle ID>` không nằm
  trong app nên cài đè giữ nguyên; kiểm ở G3.
- **Nền đọc làm chữ khó đọc hay lẫn màu Đúng/Sai:** mỗi nền có bộ màu riêng đã kiểm tương phản bằng test; Nt0 xem thử
  từng nền ở G3.
- **CI runner macOS khác máy Nt0** (phiên bản Xcode): job chỉ chạy một lần, thất bại thì sửa trong G6.2 và Nt0 quyết có
  chạy lại không; DMG đóng tại chỗ vẫn là bản dùng được. Job `release-dmg` không chờ job test nào (Decisions 2026-10-18).
- **DMG trên GitHub Release khác DMG đã test ở G3:** CI build lại trên image macOS và Xcode của GitHub, nên DMG đính kèm
  Release **không trùng từng byte** với DMG đóng tại chỗ bằng `make_dmg.sh` từ cùng commit (cùng số build); thiếu SDK mà
  project cần thì job lỗi. Ghi chú phát hành ghi macOS/Xcode của runner và sha256 hai DMG; Nt0 chọn phát bản nào (DMG đóng
  tại chỗ hay của Release). (Ghi lúc đóng giai đoạn: G3 test tay trên DMG beta build 349 (9fff274), không phải trên DMG
  của commit gắn tag; hai commit cùng mã app, Result.)
- **Tốn phút Actions:** một lần (ước ~15 phút runner macOS, tính gấp 10); không `gh workflow run`, không gắn tag khi chưa
  được yêu cầu.
- **Bundle ID mới, bản mới không thấy dữ liệu cũ** (G6 Nt0): kho và `defaults` theo bundle ID, nên bản `vn.io.nt0.*`
  mở ra thư viện trống. Không có mã chuyển dữ liệu (Nt0 chốt); Nt0 chép bằng lệnh trong `docs/install.md`: chỉ chép
  khi thư mục mới chưa có, thư mục cũ giữ làm bản sao lưu. `verify_local.sh --uitest` so cả hai họ bundle ID.
- **Hai app cùng tên, khác UTType** (UTType theo bundle ID cũ của bản cũ, `vn.io.nt0.exam` của bản mới, cùng đuôi `.exam`): còn
  bất kỳ bản cũ nào trên đĩa (Applications, Tải về, bản sao lưu `~/ExamSuite-backup/…`, `build/` của bản sao repo) thì
  Finder hay hộp chọn file (Thêm đề…, Mở…) có thể chọn nhầm app cũ, và bản Admin Debug cũ có thể ghi vào kho cũ đang
  giữ làm bản sao lưu (review độc lập #59 S1). install.md: xoá hoặc nén `.zip` mọi bản cũ trước khi cài, tìm bằng
  `mdfind`, tuỳ chọn `lsregister -gc` (Nt0 tự chạy); kiểm tay ở G3. Người điều phối đã xoá `build/` của bản sao repo
  chính và các worktree cũ g5-dong, g5-toi-uu (2026-10-18). File `.exam` có từ trước mở được vì macOS nhận kiểu theo
  đuôi (định dạng không đổi); test `projectExamTypeIdentifiers` giữ bốn chỗ khai báo kiểu trong `project.yml` khớp
  `ExamFileFormat.uniformTypeIdentifier`.
- **App Debug mang bundle ID thật mới:** bản build ở `build/DerivedData` dùng kho và `defaults` `vn.io.nt0.*`, nay là
  dữ liệu thật; agent xoá app build xong (như `make_dmg.sh` bước 6), chỉ lái app qua UI test cô lập.
- **Chỉ kiểm trên macOS 26** (review độc lập #60 S4): bản sửa hộp xác nhận Import đề (cỡ cửa sổ theo nội dung, ô có
  viền trong `Form` `.grouped`) chỉ được test và chụp trên macOS 26.6/Xcode 27; cách SwiftUI đặt cỡ cửa sổ `.contentSize`
  và vẽ `Form`/ô `.roundedBorder` có thể khác trên macOS 15. Không có máy macOS 15 để kiểm; nếu Nt0 có, thử tay (Import
  đề… với file .txt: bốn ô có viền, ghi chú đủ, cửa sổ thu lại/lớn lên theo dòng báo lỗi). **Nt0 chấp nhận rủi ro
  (2026-10-19):** v0.1.0 phát hành chỉ với kiểm trên macOS 26; DMG vẫn ghi "macOS 15 trở lên" (deployment target không
  đổi). Rủi ro không chỉ ở hộp Import đề: cả giai đoạn chỉ test tay và chụp snapshot trên macOS 26.
- Recovery: DMG và script không đổi dữ liệu; bản cài lỗi thì cài lại DMG trước. Mọi thứ trong git. G6 Nt0: dữ liệu cũ
  ở thư mục theo bundle ID cũ không bị đổi; cài lại DMG cũ (bundle ID cũ) là về trạng thái trước.

## Progress

- [x] Lập plan (PR "G5.10 Đóng giai đoạn 5…", 2026-10-18)
- [x] Nt0 trả lời câu hỏi 1–8 (2026-10-18, Decisions)
- [x] Nt0 duyệt plan sửa (2026-10-18)
- [x] 1 G6.1 Beta 0.1.0: đóng gói DMG và nền đọc (PR #58, merge 2026-10-18)
  - [x] Nền đọc: năm bộ màu `ReadingPalette`, vùng nội dung câu (`readingSurface`) ở cửa sổ làm bài, Xem lại bài, xem
    trước của Soạn đề; menu Xem › Nền đọc; ô chọn ở Trước khi thi; catalog vi/en; test tương phản, phạm vi, nhớ lựa
    chọn; snapshot; đoạn UI test trong `PracticeFlowUITests` (2026-10-18).
  - [x] Đóng gói: `scripts/make_dmg.sh`, biểu tượng tạm (`scripts/make_icons.swift`), `docs/install.md`, CHANGELOG
    `[0.1.0]`, job `release-dmg` của `ci.yml` (chưa chạy); Info.plist lấy phiên bản/số build từ cài đặt build (2026-10-18).
  - [x] Review độc lập #58 (APPROVE sau các mục nên sửa), Nt0 trả lời câu hỏi mở, sửa theo review (2026-10-18).
  - [x] `verify_local.sh --uitest` trên SHA cuối c4dafc6: `local/verify` success (UI test đủ bộ, Học viên 6, Admin 4;
    kiểm Autosave bỏ qua); merge PR #58.
- [x] 1b G6 Nt0 Đổi sang dự án cá nhân Nt0: credit, Bundle ID `vn.io.nt0.*`, UTType, `$id`, giới thiệu (Nt0 thêm
  2026-10-18; PR #59, merge 2026-10-19)
  - [x] Bundle ID, UTType, credit, `$id` trong code, test, `project.yml`, hạ tầng UI test, script; tài liệu (giới thiệu,
    "beta riêng", "phân phối riêng", quy tắc an toàn dữ liệu thật cho cả hai họ bundle ID); `docs/install.md` mục
    Chuyển dữ liệu từ bản cũ; đổi tên plan này (2026-10-18).
  - [x] Review độc lập (rủi ro cao), sửa theo review, `verify_local.sh --uitest` đủ bộ trên SHA cuối ba7637d:
    `local/verify` success (UI test đủ bộ, Học viên 6, Admin 4; kiểm Autosave bỏ qua; Linux ok).
  - [x] DMG beta cho Nt0 (bundle ID mới); Nt0 test "Cài từ DMG + chuyển dữ liệu" trên build 349: không có lỗi
    (2026-10-19).
- [x] 2 G6.2 Sửa lỗi beta, cổng G3, lần CI duy nhất, đóng plan (PR #60, merge
  2026-10-19; cổng và đóng plan trong PR cuối, review-and-merge.md mục 4)
  - [x] Lỗi beta 1 (mức cao, chặn import; Nt0 báo 2026-10-18 trên bản cài Release build 342, macOS 26 tiếng Anh): hộp xác
    nhận Import đề mất bốn ô. Sửa bố cục, test cỡ cửa sổ, ảnh snapshot, UI test đo khung (2026-10-18; Decisions G6.2).
  - [x] Việc chờ của G6.2: `--verify-tag` ở `ci.yml`; `make_dmg.sh` thất bại khi không tháo được ổ; `verify_local.sh` xoá
    app mang bundle ID thật; ADR 0009 điều kiện 1; `docs/install.md` (mdfind bỏ sót thư mục ẩn, chữ đậm qua hai dòng)
    (2026-10-18).
  - [x] PR #60: review độc lập (APPROVE, không mục chặn); Nt0 chốt S1 (ô có viền); sửa theo review S1–S3, N1–N4, ghi
    S4 (2026-10-19).
  - [x] `verify_local.sh --uitest` đủ bộ trên SHA cuối 9fff274 của #60: `local/verify` success (Học viên 6, Admin 4; kiểm
    Autosave bỏ qua; Linux ok); merge #59, #60 (2026-10-19).
  - [x] DMG beta build 349 cho Nt0 từ 9fff274; Nt0 test "Import + soạn đề": không có lỗi. macOS 15: không có máy, không
    kiểm (Nt0 chấp nhận rủi ro, Risks).
  - [x] Lỗi beta khác: không có (Nt0 test build 349, 2026-10-19).
  - [x] PR cuối #61 "G6 Đóng giai đoạn 6": `ci.yml` (gắn tag chỉ chạy `release-dmg`; hai job kiểm chỉ chạy tay; Nt0 chốt
    2026-10-19), việc còn lại của review lại #60 (phép đo viền từng cạnh, câu `find` của install.md), CHANGELOG
    `[0.1.0]`, checklist G3 với kết quả của Nt0, Result, chuyển plan sang `docs/plans/completed/` (2026-10-19); review
    độc lập #61 (không mục chặn), sửa theo S1–S4, N1–N7.
  - [x] Các bước sau khi #61 merge (cổng trên SHA phát hành, DMG, tag do Nt0 đẩy, `release-dmg`)
    ghi ở Result, Các bước phát hành. Bằng chứng của chúng nằm ở commit status `local/verify` của commit gắn tag, lời
    nhắn của tag `v0.1.0` và GitHub Release `v0.1.0`; không ghi lại vào plan (Result).

## Decisions

- 2026-10-18 (Nt0 chốt, plan-macos-v1.md và review-and-merge.md mục 4): ít PR nhất; không PR kế hoạch riêng; CI GitHub
  chạy đúng một lần, khi Nt0 báo; cổng G3 cuối giai đoạn.
- 2026-10-18, Nt0 trả lời 8 câu hỏi mở:
  1. Ký **ad-hoc** (không Developer ID, không notarize).
  2. Giữ phiên bản **0.1.0**; số build tăng theo mỗi lần đóng DMG (đề xuất: số commit của `HEAD`).
  3. DMG **đơn giản**: `ExamSuite-0.1.0.dmg`, `ExamSuiteAdmin-0.1.0.dmg`; app + lối tắt Applications + hướng dẫn; không
     ảnh nền.
  4. Hướng dẫn cài **tiếng Việt**, `docs/install.md`, bản sao trong DMG; không ảnh chụp màn hình.
  5. CI: **gắn tag `v…`**, CI đóng hai DMG và tạo GitHub Release; được sửa `ci.yml` cho việc này; chạy một lần khi Nt0
     báo.
  6. Biểu tượng: **agent tạo tạm** (teal Học viên, burgundy Admin), Nt0 thay sau.
  7. Ban đầu chọn **có** cửa sổ "Có gì mới"; cùng ngày **Nt0 bỏ** (app không nâng cấp tính năng nhiều): chỉ
     `CHANGELOG.md` và ghi chú phát hành trên GitHub Release.
  8. G3: **Nt0 tự test** trên Mac của mình, không giới hạn thời gian; đạt khi không còn lỗi mức cao (định nghĩa ở
     checklist G3).
- 2026-10-18, Nt0: bỏ "Có gì mới"; gom còn **hai PR** (đóng gói + nền đọc + DMG beta trong G6.1; sửa lỗi + G3 + CI trong
  G6.2). Bản beta cho Nt0 là đầu ra của G6.1 (đóng DMG từ SHA cuối đã verify), không phải bước riêng.
- 2026-10-18, Nt0 thêm **Nền đọc** vào giai đoạn 6 (người dùng nhìn màn hình làm bài rất lâu): năm nền có sẵn (Theo hệ
  thống, Trắng, Giấy ngà, Xám dịu, Tối); áp cho vùng nội dung câu (cùng phạm vi cỡ chữ nội dung); nền đã chọn giữ nguyên
  khi macOS đổi sáng/tối; chọn ở menu Xem và ở Trước khi thi, nhớ cho cả app. Gộp vào PR G6.1.
- 2026-10-18, cách làm bước 1 (agent, trong khuôn Approach; Nt0 xem lại ở G3, giá trị đổi được trong một file):
  - **Bộ màu năm nền** (`SessionFeature/Presentation/ReadingPalette.swift`, nền/chữ/chữ phụ/viền/teal/Đúng/Sai/đánh
    dấu/khung giải thích): Trắng `#FFFFFF`/`#1D1D1F`; Giấy ngà `#F7F0E1`/`#3A2E22` (teal `#005A5A`, đỏ `#9E2418`…);
    Xám dịu `#D8D8D6`/`#1F1F1F` (nền xám sáng vừa, bớt chói, chữ tối, khác hẳn Tối); Tối `#1E1E1E`/`#E6E6E6` (màu tối
    của `LibraryPalette`). Mức thấp nhất của chữ nhỏ trên mọi nền của vùng (kể cả dòng báo) là 5,11:1 (chữ phụ Giấy ngà
    trên dòng báo lỗi). Theo hệ thống không đổi gì so với trước (ảnh snapshot cũ không đổi; ảnh Theo hệ thống của nền đọc
    giống hệt từng byte ảnh `attemptPracticeCheckedAnswer` cùng kịch bản).
  - **Không màu ngữ nghĩa trong vùng nội dung của nền cố định:** `.primary`/`.secondary`/`.separator`/`.background` thay
    bằng màu của bộ màu (`ReadingStyle`); vùng còn ép `colorScheme` theo độ sáng của nền (thanh cuộn, chữ đang chọn);
    sheet ảnh phóng to mở từ trong vùng trả lại giao diện của cửa sổ. Nền không lấn vùng an toàn (thanh bên và bảng câu
    hỏi của macOS 26 nổi trên nội dung; bản đầu để nền tràn xuống dưới chúng, snapshot bắt được).
  - **Menu:** menu con Nền đọc đặt ngay sau Cỡ thật, bật ở cùng các cửa sổ với Phóng to/Thu nhỏ (cửa sổ làm bài, Xem lại
    bài, cửa sổ soạn đề khi xem trước mở), tắt ở Thư viện (lựa chọn vẫn là của cả app; Trước khi thi có ô chọn). macOS
    tiếng Việt gọi menu View là **Xem**; Nt0 chốt theo macOS (bên dưới).
  - **Trước khi thi:** nhóm nút radio có mẫu màu (cuối Form), không dùng menu bật lên: nút menu của SwiftUI chỉ có hành
    động mở menu, kiểm trợ năng của UI test báo "Action is missing" (lần chạy đầu `PracticeFlowUITests`).
  - **UI test:** XCUITest không đọc được dấu ✓ của mục menu (`value` rỗng, `isSelected` là mục đang trỏ chuột; đã thử),
    nên đoạn UI test kiểm menu con bật và đủ năm nền, giá trị lưu `sepia` trong `defaults` cô lập, và màu nền thật của
    vùng câu hỏi trên ảnh chụp cửa sổ; ảnh màn hình lúc menu mở đính vào kết quả khi test hỏng (lần thử thấy dấu ✓ ở
    "Theo hệ thống"). Giữ Giấy ngà cho hết luồng: kiểm trợ năng sau Kiểm tra đáp án và ở Xem lại bài chạy trên nền đó.
  - **Đóng gói:** build Release không ký (`CODE_SIGNING_ALLOWED=NO`) rồi `codesign --force --deep --options runtime -s -`
    (giữ hardened runtime như build của Xcode; app không nhúng dylib); build Debug cùng thư mục làm đối chứng âm của
    `check_release_strings.sh`; DMG HFS+ nén UDZO. Biểu tượng tạm: chữ "E" trên teal `#017777` (Học viên), "A" trên burgundy
    `#801638` (Admin). File hướng dẫn trong DMG đặt thuộc tính `com.apple.TextEncoding` UTF-8 để TextEdit mở đúng tiếng Việt.
  - **Lỗi tìm thấy khi đóng DMG:** XcodeGen ghi cứng `CFBundleShortVersionString` "1.0" và `CFBundleVersion` "1" vào
    Info.plist, nên mọi bản trước báo phiên bản 1.0 và không đặt được số build; project.yml nay lấy hai khoá từ
    `MARKETING_VERSION` (0.1.0) và `CURRENT_PROJECT_VERSION`.
  - **CI:** job `release-dmg` chỉ khi tag `v*`, không chờ job nào (Nt0 chốt bên dưới); `make_dmg.sh --clean`; ghi chú
    phát hành lấy mục của phiên bản trong CHANGELOG.md, thêm macOS/Xcode của runner và sha256 hai DMG; tag có "-" là
    prerelease; runner `macos-15` chọn Xcode mới nhất có sẵn (có thể khác Xcode 27 của máy người điều phối). Chưa chạy.
- 2026-10-18, Nt0 trả lời câu hỏi mở của PR #58:
  1. **Xám dịu** giữ như agent làm: nền xám sáng `#D8D8D6`, chữ tối.
  2. **Thuật ngữ tiếng Anh** Reading Background / Match System / White / Sepia / Soft Gray / Dark: duyệt (bảng thuật ngữ
     của accessibility-localization.md ghi "Nt0 duyệt 2026-10-18").
  3. **Tên menu theo macOS: "Xem"** (View), không gọi "Hiển thị": tài liệu và chữ trợ giúp ghi "Xem › Nền đọc", "Xem ›
     Phóng to…" (accessibility-localization.md, plan này và plan giai đoạn 5 phần test tay, AGENTS.md, CHANGELOG.md, comment
     trong code).
  4. **CI:** job `release-dmg` không chờ job snapshot/test (`apps-macos`; review độc lập #58 S1). Bỏ cả `core-linux` khỏi
     `needs`: job đó cần mạng (apt-get) và có trần thời gian cho lỗi treo của ZIPFoundation trên Linux, nên cũng có thể đỏ vì
     môi trường; bằng chứng cho SHA gắn tag là `verify_local.sh --clean --uitest` tại chỗ (cổng G3), chạy cùng image Docker
     `swift:6.1` của `core-linux`. DMG do CI đóng là bản build lại trên image GitHub (mục Risks).
- 2026-10-18, sửa theo review độc lập #58 (APPROVE sau các mục nên sửa):
  - **S2:** phép đo nhãn Đúng/Sai trên ảnh chụp (`ReadingBackgroundScopeTests`) bản đầu bắt nhầm chữ cam "Đã đánh dấu" ở
    đầu câu là "Sai". Nay "Sai" chỉ tìm trên dòng điểm ảnh của lựa chọn đang chọn và so với nền thật của hàng (nút bị khoá
    làm mờ cả nền hàng: hàng Trắng thật là `#EFF6F6`, không phải `#E0EDED`), nhận màu theo tông (đỏ < 20°, xanh 100–160°);
    đối chứng âm: nhãn Sai trong nút `.plain` bị khoá đo 2,3–2,6:1 trên cả bốn nền (bị bắt). Đo được: Sai 5,9–7,2:1, Đúng
    6,3–9,4:1. Kịch bản ảnh làm bài của nền đọc bỏ đánh dấu câu, nên đúng kịch bản `attemptPracticeCheckedAnswer` (N7);
    màu "Đã đánh dấu" vẫn có ở ảnh Xem lại bài nền Tối.
  - **S3:** `make_dmg.sh` chỉ truyền số build cho bản Release (bản Debug đối chứng giữ số 1) và xoá
    `build/DerivedData-Release-DMG/Build/Products` cùng thư mục đóng gói sau khi đóng, cả khi lỗi: app vừa build mang bundle
    ID thật, LaunchServices có thể chọn bản Debug (dùng chung kho, `defaults` thật) để mở `.exam`.
  - **N1–N3:** `make_dmg.sh` dừng khi repo là clone nông; số build chỉ tăng đều khi đóng từ `main` với merge commit (không
    squash/rebase lại lịch sử); tháo ổ có thử lại `-force` ở mọi đường; thêm `--clean` (CI dùng).
  - **N4:** chữ của lựa chọn bị khoá sau Kiểm tra đáp án bị macOS làm mờ (đo 2,7–4,5:1 trên các nền, review độc lập): là
    điều khiển bị tắt, được miễn như giao diện theo hệ thống từ trước; không thêm màu chữ riêng khi tắt, vì nút khoá làm mờ
    cả nội dung bằng độ mờ (màu chữ đậm hơn vẫn bị làm mờ theo, như nhãn Đúng/Sai trước #54). Ghi ở accessibility-
    localization.md, mục Nền đọc.
  - **N5, N9:** checklist G3 thêm phần do AppKit vẽ trên nền đọc ngược giao diện, và biểu tượng tạm trên macOS 26.
  - **N6:** `docs/install.md`: chữ nút đúng như macOS 26 tiếng Việt (đã tra chuỗi của hệ thống: hộp "chưa được mở", nút
    Xong / Chuyển vào Thùng rác, Cài đặt "đã bị chặn để bảo vệ máy Mac của bạn", nút Vẫn mở); hỏi quyền thư mục có thể
    hiện lại sau mỗi lần cập nhật; DMG chép từ ổ mạng có thể không có cờ quarantine.
  - **N8:** 10 ảnh snapshot mới (không phải 11); mức tương phản thấp nhất 5,11:1 (kể cả dòng báo).
- 2026-10-18, Nt0: dự án cá nhân của Nt0; Bundle ID vn.io.nt0.*, UTI vn.io.nt0.exam, $id GitHub; không có mã chuyển
  dữ liệu, Nt0 tự chép. Chi tiết Nt0 chốt (mục G6 Nt0):
  1. Credit: `NSHumanReadableCopyright` "© 2026 Nt0" (`project.yml`, `InfoPlist.xcstrings` vi/en của hai app).
  2. Tiền tố bundle ID **`vn.io.nt0`** (chữ `io`, Nt0 sửa lại từ bản nháp đầu): `vn.io.nt0.examsuite`,
     `vn.io.nt0.examsuite.admin`, trình chạy UI test `…uitests`, bản build UI test đuôi `.uitest`.
  3. UTType `.exam`: `vn.io.nt0.exam`; `$id` của schema: `https://github.com/tuann2/exam-suite/schema/exam-v1.schema.json`.
     Định dạng gói không đổi (`formatVersion`, trường, quy tắc kiểm); file `.exam` có từ trước mở được (theo đuôi, kiểu
     zip). Không script hay test nào so `$id`.
  4. Giới thiệu dự án: "dự án cá nhân của Nt0"; bản beta và cách phân phối gọi là "beta riêng", "phân phối riêng". Plan
     đã xong là lịch sử: không sửa nội dung (2026-10-20, bản public: Nt0 chốt viết lại lời văn của lịch sử theo dự án cá
     nhân, plan cong-khai-repo.md).
  5. Dữ liệu người dùng: không có mã chuyển dữ liệu; Nt0 tự chép theo `docs/install.md`, mục "Chuyển dữ liệu từ bản cũ"
     (mục này bỏ khỏi bản public, plan cong-khai-repo.md). Quy tắc an toàn (AGENTS.md, review-and-merge.md mục 1) cấm
     agent chạm cả `vn.io.nt0.*` (dữ liệu thật mới) và thư mục theo bundle ID cũ (bản sao lưu); `verify_local.sh
     --uitest` so kho, `defaults` và đề gần đây của cả bốn bundle ID, và tìm cả hai tên trong Autosave Information (bản
     public chỉ còn bundle ID mới, plan cong-khai-repo.md).
  6. Không đổi lịch sử git hay email tác giả.
- 2026-10-18, cách làm mục G6 Nt0 (agent, trong khuôn quyết định trên):
  - **Còn tên bundle ID cũ có chủ ý:** fixture `Packages/ExamFeatures/Tests/LibraryDataTests/Fixtures/Library-v1.store` (đường
    dẫn đề mẫu đã ghi lúc tạo) và chuỗi tương ứng trong `LibraryV1FixtureTests.swift` (test so từng byte đã lưu): fixture
    không được tạo lại (AGENTS.md, bất biến "kho thư viện v1 mở được"); `docs/install.md` (mục chuyển dữ liệu, chỗ dữ liệu
    cũ); quy tắc an toàn và phần so dữ liệu cũ của `verify_local.sh`; plan đã xong (lịch sử); dòng Decisions này.
    2026-10-20, bản public: mọi chỗ đó đã bỏ hoặc viết trung tính, fixture tạo lại một lần (Nt0 duyệt; plan
    cong-khai-repo.md).
  - **Plan đã xong:** chỉ sửa hai link tới plan này trong plan giai đoạn 5 (đổi tên file làm link gãy); còn lại giữ
    nguyên. Không có kiểm nào đòi sửa thêm.
  - **ADR:** 0004 đổi tiêu đề sang "phân phối riêng" (tên file đổi theo ngày 2026-10-20, bản public); 0001, 0003, 0004
    ghi ngày đổi ở mục Status, quyết định không đổi.
  - **"nội bộ" giữ nguyên** khi nghĩa là nội bộ của code (Swift `internal`, "hàm nội bộ", `MARK: - Nội bộ`, "đường dẫn
    file nội bộ" của Android) hay là nội dung đề (đề mẫu, đề chuẩn 2.000 câu và `large-exam.digest`, dữ liệu snapshot,
    test import).
  - **Chân trang PDF kết quả** và cách gọi nhóm người dùng: bản đầu của PR #59 giữ nguyên và hỏi Nt0; Nt0 chốt bên dưới.
  - **Hướng dẫn chuyển dữ liệu:** lệnh `ditto` chỉ chép khi thư mục mới chưa có (đã thử với thư mục nhà giả: chép lần
    đầu, lần hai bỏ qua, thư mục cũ còn nguyên); chép `defaults` là tuỳ chọn (`defaults export … - | defaults import …
    -`, ghi đè cài đặt của bản mới). Đề mẫu đã chép vẫn trỏ tới file trong thư mục cũ (bookmark thường, không gắn app);
    xoá thư mục cũ thì dùng Trợ giúp › Khôi phục đề mẫu.
  - **`make_dmg.sh`:** khi chuyển `docs/install.md` thành file .txt trong DMG, bỏ cả dòng rào ``` thụt lề (khối lệnh của
    mục chuyển dữ liệu nằm trong danh sách).
- 2026-10-18, Nt0 trả lời hai câu hỏi mở của PR #59:
  1. **Chân trang PDF kết quả** bỏ chữ "nội bộ": "Kết quả luyện tập, không có giá trị xác nhận", en "Practice result, not
     an official certification" (export-print.md phương án 5 ghi ngày đổi). Ảnh snapshot trang 1 PDF kết quả ghi lại.
  2. **Cách gọi nhóm người dùng** thành "người dùng" / "người dùng thử" trong tài liệu hiện hành (overview.md,
     large-exams.md, ADR 0009, plan-macos-v1.md, fixtures/README.md, plan-android-v1.md); bản ghi có ngày (Context của
     ADR ngày 2026-10-15: 0001, 0002, 0004; plan đã xong) giữ nguyên lúc đó, rồi viết lại 2026-10-20 cho bản public.
- 2026-10-18, sửa theo review độc lập #59 (không có mục chặn; khuyến nghị duyệt sau hai mục nên sửa):
  - **S1:** bản app cũ ở bất cứ đâu trên đĩa còn khai báo UTType `.exam` theo bundle ID cũ: install.md bước 4 đòi xoá hoặc nén `.zip`
    mọi bản cũ trước khi cài (Applications, Tải về, bản sao lưu, `build/` của bản sao repo), lệnh `mdfind` để tìm và
    `lsregister -gc` tuỳ chọn (Nt0 chạy, agent không chạy); Risks và checklist G3 thêm kiểm Thêm đề… (⌘O), hộp Mở của
    bản Admin và nhấp đúp trong Finder.
  - **S2:** install.md có dòng nhắc ở đầu tài liệu và đầu mục "Cập nhật lên bản mới": đang dùng bản cài trước
    18/10/2026 thì làm mục Chuyển dữ liệu **trước** khi mở bản mới.
  - **N1, N2:** vị trí cửa sổ theo sang khi chép `defaults` (bước 3); bước 3 thành "Nên làm": bỏ qua thì cờ đã tạo đề
    mẫu mất, đề mẫu đã xoá hiện lại (không trùng).
  - **N3:** test `projectExamTypeIdentifiers` (LibraryDataTests, cạnh test bundle ID): bốn chỗ khai báo kiểu `.exam`
    trong `project.yml` bằng `ExamFileFormat.uniformTypeIdentifier`, không có khai báo kiểu thứ ba; đối chứng âm: đổi
    một chỗ về tên cũ thì test đỏ.
  - **N4:** quy tắc an toàn (AGENTS.md, review-and-merge.md mục 1) nêu đích danh bốn bundle ID thật, loại trừ domain
    `….uitest` của bản build UI test.
  - **N5:** ADR 0001 giữ nguyên ý: Context ngày 2026-10-15 trả lại, điều kiện "phát hành ra ngoài" giữ, câu giấy phép
    giữ ý (không bị GPLv3 ràng buộc), chỉ đổi lời văn theo dự án cá nhân; ADR 0009 cũng vậy; ghi chú Status của 0001,
    0004, 0009 nêu ngày đổi.
  - **N6:** Approach ghi ba PR (G6.1, G6 Nt0, G6.2).
- 2026-10-18, G6.2 **lỗi beta 1** (mức cao, chặn import; Nt0 báo trên bản cài Release build 342, macOS 26, giao diện
  tiếng Anh): Import đề… với một file .txt (1.019 câu, 1 phần, 4 cảnh báo) mở cửa sổ "Import Exam" chỉ có đầu đề, dòng
  tóm tắt, dòng ghi chú bị cắt còn một dòng ("The exam opened in an unsaved editor window; review it, make changes, th…")
  và hai nút Cancel/Import; không có bốn ô Tiêu đề, Mã đề, Ngưỡng đậu (%), Thời gian Thi (phút), nên Import khoá mà không
  điền được.
  - **Nguyên nhân:** cửa sổ `ImportExamWindow` dùng `.windowResizability(.contentSize)`: cỡ nhỏ nhất và lớn nhất của nội
    dung là giới hạn của cửa sổ, và cửa sổ mở ở cỡ nhỏ nhất. Hộp xác nhận đặt bốn ô trong `Form` kiểu `.grouped`, vốn là
    vùng cuộn nên cỡ nhỏ nhất gần như 0; `Text` của ghi chú co còn một dòng. Đo: cỡ nhỏ nhất của hộp 167 pt, cỡ lý tưởng
    419 pt (tên file ngắn); UI test trên bố cục cũ thấy cửa sổ 480×198 (kể cả thanh tiêu đề) và vùng cuộn của `Form` cao 0.
    Lỗi có từ khi làm hộp xác nhận (G4.4b, d7ea576); 8a (độ rộng tối thiểu cho cửa sổ xếp lát), 8b (trợ năng: đề mục, câu
    đọc) và nền đọc không chạm bố cục hộp, không làm lỗi nặng thêm.
  - **Sửa:** `.fixedSize(horizontal: false, vertical: true)` trên cả hộp xác nhận (và tiến độ, phòng tên file dài bị cắt):
    cỡ nhỏ nhất = lớn nhất = lý tưởng, cửa sổ vừa khít nội dung (480×468 khi mọi ô báo lỗi với tên file dài; 480×503 tiếng
    Anh: dòng báo lỗi mã đề, nhãn thời gian và ghi chú xuống dòng) và đổi cỡ theo khi dòng báo lỗi hiện/ẩn. Giữ `Form`
    `.grouped`, nhãn, định danh, tiêu điểm vào ô đầu còn lỗi, chữ vi/en (không khoá mới); thêm định danh
    `import.confirm.note` cho dòng ghi chú (UI test). Ô của `Form` `.grouped` không viền, chữ canh phải (kiểu Cài đặt hệ
    thống của macOS): ô trống chỉ thấy nhãn, dòng báo lỗi và con trỏ khi có tiêu điểm; giữ như thiết kế cũ. (Nt0 đổi
    2026-10-19 sau review #60: ô có viền, chữ canh trái; mục bên dưới.)
  - **Vì sao UI test không bắt:** `ImportExamUITests` điền ô bằng Tab (tiêu điểm bàn phím, gõ được vào ô cao 0) và chỉ kiểm
    `exists`, giá trị, nút Import bật. Với `Form` cao 0, khung của ô vẫn nằm trong khung cửa sổ (đè lên tóm tắt và ghi chú)
    và `isHittable` vẫn đúng (đã thử), nên phép kiểm "nằm trong cửa sổ" của cửa sổ xếp lát cũng không đủ: phải so cả với
    khung vùng cuộn chứa ô. Trên bố cục cũ, test mới đỏ ("ô Tiêu đề bị vùng cuộn cắt: (568.5, 380.5, 328.5, 18.0) không trong
    vùng cuộn (486.0, 448.5, 440.0, 0.0)"); sau khi sửa: đạt.
  - **Test thêm:** `ContentSizedWindowTests` (ExamFeaturesSnapshotTests): cỡ nhỏ nhất bằng cỡ lý tưởng ở hộp xác nhận và
    tiến độ Import đề, hộp chọn Xuất PDF…/In… của đề và của kết quả, vi và en; đối chứng âm trên view thật với
    `fitsIdealHeight: false` (cỡ nhỏ nhất thấp hơn lý tưởng hơn 150 pt). Snapshot `importConfirmProblems`,
    `importConfirmProblemsEnglish` (sáng, ở cỡ cửa sổ thật đo trong cửa sổ chụp: `SnapshotHost.minimumContentSize`; đo ngoài
    cửa sổ lệch 3 pt). `WindowLayout` (Apps/UITestSupport): `assertVisible` đòi khung đủ cao/rộng, trong cửa sổ và trong mọi
    vùng cuộn chứa phần tử; `ImportExamUITests` kiểm bốn ô (kể cả `isHittable`), dòng báo lỗi, ghi chú, hai nút trước và
    sau khi điền; `TiledWindow.assertInside` dùng chung phép kiểm này.
  - **Rà cửa sổ và sheet khác:** chỉ cửa sổ Import đề dùng `.contentSize`; cửa sổ làm bài và Thư viện dùng
    `.contentMinSize` kèm cỡ tối thiểu, cửa sổ soạn đề có cỡ tối thiểu. Sheet có vùng cuộn đặt cỡ nhỏ nhất riêng nên không
    co về 0: Trước khi thi (`Form`, `minHeight` 480), Thông tin (`Form`, 420), file không thêm được (`List`, 120), ảnh phóng
    to (`ScrollView`, 480). Hộp chọn và tiến độ Xuất PDF/In (hai bản) không có vùng cuộn; chữ dài có `fixedSize`; cỡ nhỏ
    nhất đã bằng lý tưởng (đo vi/en, nay có test). "Vẫn nộp?" là hộp thoại của hệ thống (`confirmationDialog`). Không sửa
    thêm chỗ nào.
- 2026-10-18, việc chờ của G6.2 (nhỏ, trước phát hành):
  - `ci.yml`: `gh release create … --verify-tag` (tag phải có sẵn; không để gh tự tạo tag).
  - `make_dmg.sh`: `detach_mount` bỏ `|| true`; tháo không được kể cả `-force` thì báo ổ còn gắn và trả lỗi: đường thành
    công dừng script, cleanup thử tháo lại và giữ mã lỗi, vẫn xoá app. Thử với `hdiutil` giả: tháo được → thoát 0; tháo lỗi
    → thoát 1, có dòng FAIL, app vẫn bị xoá.
  - `verify_local.sh`: xoá `build/DerivedData/Build/Products` và `build/DerivedData-Release/Build/Products` (app mang bundle
    ID thật) ngay sau `check_release_strings.sh` (bước cuối dùng chúng) và trong `on_exit` (dừng ở bất cứ đâu); giữ bản
    `.uitest` (bundle ID riêng, `LSHandlerRank` None) để chạy lại nhanh. Lần chạy sau build lại Products (chậm hơn một
    chút). `-exportLocalizations` (build/DerivedData-L10n) không tạo `.app` (đã kiểm: chỉ `.o`, `.swiftmodule`, bundle tài
    nguyên), nên không cần xoá. Thử bằng bản trích hàm với thư mục giả: đi hết hay dừng giữa chừng (mã thoát giữ nguyên)
    đều xoá app của hai thư mục Products, bản `.uitest` còn.
  - ADR 0009 điều kiện 1: "(và tự quyết việc hỏi tư vấn pháp lý)"; bản G6 Nt0 ghi "(và tự kiểm giấy phép, điều kiện pháp
    lý)", đổi nghĩa của điều kiện gốc (tự quyết việc hỏi bộ phận pháp lý). Status ghi ngày đổi.
  - `docs/install.md`: `mdfind` (Spotlight) có thể bỏ sót app trong thư mục ẩn (bản build trong `.claude/worktrees`), thêm
    `find ~ -name "Exam Suite*.app" -not -path "*/Library/*"`; hai chữ đậm qua hai dòng ở bước 1, 2 của "Mở lần đầu" để lại
    `**` trong `Hướng dẫn cài đặt.txt` của DMG (sed của `make_dmg.sh` thay theo từng dòng), nay mỗi chữ đậm nằm trên một dòng.
- 2026-10-19, review độc lập #60 (APPROVE, không mục chặn) và **Nt0 chốt S1**:
  - **S1 (Nt0 chốt):** ô trống của hộp xác nhận trông như không có ô (ô của `Form` `.grouped` không viền; đo điểm ảnh:
    vùng nhập của ô trống một màu phẳng). Bốn ô nay **có viền** (`.roundedBorder`), **không chữ gợi ý**, chữ canh trái,
    cùng độ rộng 200 pt; nhãn bên trái chiếm phần còn lại, xuống dòng khi dài. Xếp mỗi dòng bằng `HStack` (nhãn, ô) trong
    `Form`: `TextField` có nhãn hay `LabeledContent` của `Form` `.grouped` đẩy ô xuống dòng riêng khi nhãn tiếng Anh dài
    ("Time limit for Exam mode (minutes)", đã thử cả hai, ảnh xấu), và ép chữ canh phải. Ô ẩn nhãn (`labelsHidden`) nhưng
    vẫn mang nhãn cho trợ năng; chữ nhãn ẩn với VoiceOver để không đọc hai lần. Ghi ở import.md phương án 19. Ảnh ghi
    lại: `importConfirmProblems.light-480x494.png`, `importConfirmProblemsEnglish.light-480x523.png` (thay 480x468, 480x503).
    Test `importConfirmEmptyFieldsHaveBorder` (sáng, tối): trong khung ô chữ AppKit trống chưa có tiêu điểm (ngưỡng đậu,
    thời gian), tương phản giữa điểm ảnh sáng nhất và tối nhất ≥ 1,2:1; đo 1,32:1 (sáng), 3,72:1 (tối); đối chứng âm: ô
    của `Form` `.grouped` không viền đo 1,00:1. (PR cuối đổi sang đo từng cạnh, ngưỡng 1,12: Decisions 2026-10-19, việc
    còn lại của review lại #60.)
  - **S2:** lệnh `find` của install.md đi cả `~/Library` (thư mục đồng bộ đám mây, Containers; có thể làm macOS hỏi quyền) và không bỏ
    qua Library như chữ ghi. Nay `find ~ -path ~/Library -prune -o -name 'Exam Suite*.app' -print -prune` (thử với thư mục
    nhà giả: tìm được bản trong `.claude/worktrees`, Tải về, bản sao lưu; bỏ qua `~/Library`); ghi kiểm `/Applications`
    riêng (ngoài thư mục nhà).
  - **S3:** UI test ghi cao cửa sổ trước khi điền, đòi cửa sổ thu lại (> 10 pt) khi hết dòng báo lỗi; rồi gõ mã đề sai
    mẫu: có dòng báo lỗi của Mã đề, Import khoá, cửa sổ lớn lên, bố cục đủ (`assertConfirmLayout(problems: [code])`); xoá
    mã đề: Import bật lại, cửa sổ về cỡ cũ.
  - **S4:** chưa kiểm trên macOS 15: ghi ở Risks và PR, kèm test tay nếu Nt0 có máy macOS 15. Không đổi code.
  - **N1:** `verify_local.sh` `on_exit`: ghi status thất bại trước, rồi xoá app (`remove_real_apps || echo …`), để lỗi xoá
    không làm mất status (thử: xoá lỗi giả lập → status thất bại vẫn ghi, mã thoát giữ nguyên).
  - **N2:** `make_dmg.sh`: `MOUNT` chỉ đặt sau khi `hdiutil attach` thành công; gắn lỗi thì xoá thư mục tạm và báo "không
    gắn được", không báo nhầm "không tháo được" (thử với `hdiutil` giả: gắn lỗi → thoát 1, không còn thư mục tạm).
  - **N3:** UI test kiểm thứ tự từ trên xuống, không dựa vào cây trợ năng của `Form`: đáy tóm tắt ≤ đỉnh ô đầu; đáy ô hoặc
    dòng báo lỗi cuối ≤ đỉnh ghi chú; đáy ghi chú ≤ đỉnh nút.
  - **N4:** `fixedSize` dọc chuyển lên `Group` gốc của `ImportExamRoot` (mọi bước của cửa sổ), cùng tham số đối chứng âm
    `fitsIdealHeight`; `ContentSizedWindowTests` đo `ImportExamRoot` ở bước đọc và bước xác nhận (kiểm phép đo không đổi
    bước của lần import); ảnh chụp và test viền dùng `ImportExamRoot` (có màu nhấn của cửa sổ như app thật: nút Import
    tắt màu burgundy nhạt). `SnapshotHost.image` thêm `inspect` (đọc khung view AppKit trong đúng lần chụp).
- 2026-10-19, **Nt0 test beta build 349 và chốt G3** (kết quả ở mục Kết quả G3, sau checklist): không lỗi; G3 đạt;
  macOS 15 không kiểm (không có máy), Nt0 chấp nhận rủi ro (Risks). Không còn lỗi beta cần sửa, nên PR cuối chỉ còn cổng,
  đóng giai đoạn và hai việc còn lại của review lại #60 (bên dưới), cùng thay đổi `ci.yml`.
- 2026-10-19, **Nt0 chốt CI khi phát hành:** gắn tag `v0.1.0` chỉ chạy job `release-dmg`; `core-linux` và `apps-macos`
  chỉ chạy khi chạy tay (`workflow_dispatch`), không khi gắn tag. Thay cho "lần CI duy nhất" chạy cả ba job (Scope,
  Approach bước 2): giai đoạn 6 không chạy hai job kiểm trên GitHub; bằng chứng cho SHA gắn tag là cổng
  `verify_local.sh --clean --uitest` tại chỗ (đã gồm các bước của hai job kiểm, review-and-merge.md mục 2). Cách làm
  (agent): mỗi job có `if:` theo `github.event_name`: hai job kiểm `== 'workflow_dispatch'`; `release-dmg` đòi `push` và
  ref `refs/tags/v…` (trước chỉ đòi ref là tag, nên chạy tay với ref là tag cũng tạo Release). Chạy lại job hỏng của lần
  gắn tag bằng Re-run trên chính lần chạy đó (sự kiện vẫn là `push`). Hai job kiểm hiện "skipped" khi gắn tag, không tốn
  phút. Sửa theo: comment của `ci.yml`, AGENTS.md (bảng lệnh, quy tắc làm việc, bảng bất biến: "chỉ chạy tay/tag" → "chỉ
  chạy tay"), review-and-merge.md mục 2 và checklist người duyệt, plan-macos-v1.md (CI), CHANGELOG.
- 2026-10-19, việc còn lại của **review lại #60** (không chặn, làm ở PR cuối):
  - **Ngưỡng viền** của `importConfirmEmptyFieldsHaveBorder`: phép đo cũ (điểm ảnh sáng nhất và tối nhất trong cả khung ô)
    cho 1,32:1 ở giao diện sáng chỉ nhờ góc bo của hai cạnh bên; cạnh trên/dưới 1,19, dưới ngưỡng 1,2, nên test không đòi
    viền ở mọi cạnh. Nay đo **từng cạnh** (`FieldBorder`): mỗi cạnh lấy dòng (cột) điểm ảnh từ 2 điểm ảnh ngoài khung
    `NSTextField` tới 3 điểm ảnh trong khung (viền `.roundedBorder` của macOS 26 nằm sát hoặc ngay ngoài khung: hai cạnh
    bên là cột ngoài khung 1 điểm ảnh), độ sáng trung bình trên nửa giữa của cạnh (bỏ góc bo), so với nền trong ô; đòi
    cạnh yếu nhất ≥ **1,12:1**. Đo trên macOS 26.6/Xcode 27 (ảnh 1 điểm ảnh/pt): sáng trên/dưới 1,19 (`#EBEBEB` trên nền
    ô `#FFFFFF`), trái/phải 1,30–1,32 (`#E0E0E0`); tối trên/dưới 3,62 (`#757575` trên `#1E1E1E`), trái/phải 1,19
    (`#2C2C2C`). Ô có nền khác nền cửa sổ mà không viền chỉ có bậc nền cửa sổ/nền ô: 1,07 (sáng, `#F7F7F7`/`#FFFFFF`), 1,09
    (tối, `#252525`/`#1E1E1E`); 1,12 nằm giữa (review lại gợi ý "khoảng 1,1"; 1,1 chỉ hơn mức tối không viền 0,01). Đối
    chứng âm giữ nguyên (ô của `Form` `.grouped` không viền: mọi cạnh 1,00, đòi < 1,05); thêm phép thử đột biến: bỏ
    `.textFieldStyle(.roundedBorder)` của hộp xác nhận thì test đỏ ở cả sáng và tối (mọi cạnh 1,00), đã trả lại.
    docs/process/snapshot-tests.md ghi cách đo và cách xử lý khi nâng macOS/Xcode.
  - **install.md:** câu "kết quả gồm cả bản mới nếu đã cài" cạnh lệnh `find` sai: bản mới cài đúng chỗ nằm trong
    `/Applications`, lệnh không xem. Nay ghi: lệnh tìm theo tên nên không phân biệt bản cũ với bản mới; bản mới trong
    `/Applications` không có trong kết quả.
- 2026-10-19, sửa theo **review độc lập #61** (không mục chặn; `ci.yml` ở commit gắn tag là bản sẽ chạy, nên sửa trước
  cổng):
  - **S1:** Result không còn chỗ "người điều phối điền" (sẽ cần PR chỉ tài liệu, mục 4 cấm): bằng chứng cổng, số build và
    sha256 DMG đóng tại chỗ nằm ở commit status `local/verify` của commit gắn tag và lời nhắn của tag có chú thích (`git
    tag -a … -F <file>`); run ID, runner, sha256 DMG của Release nằm ở ghi chú GitHub Release (`release-dmg` thêm dòng
    "Lần chạy" có link lần chạy). Thay Approach bước 2 "ghi run ID, thời gian, kết quả vào Result".
  - **S2:** ghi chú phát hành và comment của `release-dmg` so DMG của Release với DMG đóng tại chỗ bằng `make_dmg.sh` từ
    cùng commit, không với "DMG đã test ở G3": G3 test tay trên build 349 (9fff274), cùng mã app với commit gắn tag
    (Result, Risks, AGENTS.md).
  - **S3:** `concurrency.group` thêm `github.event_name`: chạy tay với ref là tag không huỷ lần chạy phát hành của tag.
  - **S4:** Nt0 tự gắn và đẩy tag bằng lệnh người điều phối đưa (có SHA và file lời nhắn), như lệnh merge; agent không
    đẩy tag.
  - **N1:** phép đo viền bỏ dòng nằm ngoài ảnh (trước đọc thành đen); không đo được nền trong ô hay cả một cạnh thì ô
    không có số đo và test hỏng, không đạt suông.
  - **N2:** đối chứng âm thứ hai trong test: ô có nền ô (màu nền chữ của hệ thống) mà không viền, cùng bố cục hộp xác nhận;
    đo 1,07 (sáng), 1,09 (tối) ở mọi cạnh, dưới ngưỡng 1,12; test đòi bậc nền > 1,03 để đối chứng không đạt vì phẳng.
  - **N3:** CHANGELOG `## [0.1.0] – beta riêng` không ghi ngày ở đầu mục: ngày phát hành là ngày của tag (GitHub Release),
    vì sửa ngày sau cổng sẽ đổi SHA phát hành; thân mục ghi ngày qua G3 (2026-10-19). Lệch với Keep a Changelog (mục đã
    phát hành có ngày) có chủ ý.
  - **N4:** bước Automation Mode đặt ngay sau cổng (bước 2), không chờ tag; Progress không còn mục cha `[x]`
    có mục con `[ ]`.
  - **N5:** review-and-merge.md mục 2 (hai job kiểm chỉ chạy khi Nt0 báo; link lần chạy tay vào exec-plan đang active
    hoặc PR); plan-android-v1.md bỏ "chỉ chạy tay/tag như hiện nay".
  - **N6:** bảng Kết quả G3 ghi đúng lời Nt0 (bốn nhóm đã test, "Không có lỗi") và nêu các mục con không được báo riêng;
    G3 đạt theo quyết định của Nt0. CHANGELOG và Progress theo cùng lời.
  - **N7:** `ci.yml` có `permissions: contents: read` ở cấp workflow (`release-dmg` giữ quyền ghi ở cấp job); `release-dmg`
    dừng ngay ở bước đầu khi tag không khớp `MARKETING_VERSION` của `project.yml` (trước khi build).
- 2026-10-19, **cổng G3 lần đầu trên e639986 hỏng một test vì máy có màn hình ngoài** (mọi bước khác đạt): máy chạy cổng
  có thêm màn hình ngoài đặt bên trái màn hình chính; cửa sổ làm bài mở trên màn hình phụ ở (-1550, -44), và
  `window.screenshot()` trong đoạn Nền đọc của `PracticeFlowUITests` lỗi "Failed to create screenshot. Image creation
  failed" ở cả hai lần chạy. Lỗi của môi trường, nhưng test mong manh: các cổng trước đạt chỉ vì máy có một màn hình.
  **Sửa (UI test chạy đúng khi máy có nhiều màn hình):** `ScreenPixels` (Apps/StudentUITests/Support) chụp **cả màn hình**
  chứa điểm cần đọc (`XCUIScreen`), tỉ lệ điểm ảnh lấy từ ảnh chụp so với khung màn hình; khung lấy từ `NSScreen` (XCUIScreen
  không có khung công khai), ghép theo vị trí trong danh sách (cùng bắt đầu bằng màn hình chính) và kiểm bằng tỉ lệ khung
  hình, lệch thì tìm màn hình duy nhất cùng tỉ lệ; điểm ngoài mọi màn hình thì thử màn hình chính; không ghép được thì
  không trả màu và thông báo lỗi của test nêu lý do (`ScreenPixels.lastProblem`). Phép kiểm màu không đổi (Giấy ngà
  `#F7F0E1` ±8). Ảnh đính kèm lúc menu Nền đọc mở cũng chụp màn hình chứa menu. Không còn `XCUIElement.screenshot()` hay
  `XCUIScreen.main.screenshot()` trong Apps/*UITests và Apps/UITestSupport (các chỗ khác chỉ dùng khung phần tử). Không
  đổi chế độ cô lập, `-AppleLanguages`, tham số khác.
- 2026-10-19, **cổng G3 trên 5b27b5d vẫn hỏng khi còn màn hình ngoài**: `EditExamFlowUITests` (kéo dòng cây đề trên màn hình
  phụ: "not hittable", hỏng cả hai lần) và một lần chập chờn của `PracticeFlowUITests`. Cửa sổ app mở trên màn hình đang
  dùng (màn hình ngoài); XCUITest kéo thả, chụp và chờ phần tử không ổn định trên màn hình phụ. **Nt0 chốt: chạy cổng (và
  UI test) khi máy chỉ có một màn hình** (rút màn hình ngoài hoặc bật Mirror), rồi chạy lại.
- 2026-10-19, **lần chạy cổng một màn hình trên 5b27b5d hỏng ở kiểm trợ năng**, lần chạy lại đạt: màn Thư viện có một
  tooltip của macOS (loại `helpTag`, 172×18 pt, không tên) vì con trỏ chuột dừng trên nút thanh công cụ; kiểm báo
  `sufficientElementDescription`. Tooltip do macOS vẽ từ `.help` của điều khiển (điều khiển có nhãn riêng), có hay không
  tuỳ vị trí con trỏ. Thêm ngoại lệ hẹp (b) cho phần tử không tên loại `helpTag` trong `AccessibilityAudit.swift`; cổng chạy
  lại trên SHA mới.

## Validation

- Focused proof: chạy `scripts/make_dmg.sh` tại chỗ; `hdiutil verify`, `codesign --verify --deep --strict` trên app
  trong DMG; `check_bundle_boundary.sh`, `check_release_strings.sh` trên bản Release đem đóng; test tương phản năm nền đọc.
- Integration: một `scripts/verify_local.sh --uitest` mỗi PR trên SHA cuối sau review; cổng `--clean --uitest` trên SHA
  phát hành; lần CI GitHub duy nhất khi Nt0 báo: job `release-dmg` khi gắn tag `v0.1.0` (Decisions 2026-10-19).
- Repository-required checks: `local/verify` xanh trên SHA cuối mỗi PR; review độc lập cho mọi PR rủi ro cao (#58, #59,
  #60 và PR cuối #61, chạm `ci.yml`).
- Cần người test tay: checklist G3.
- Bước 1 tại chỗ (2026-10-18, trước review độc lập): `scripts/make_dmg.sh` trên commit 1c68b78 (build 330) đạt (hai DMG
  2,8 MB và 3,7 MB, `hdiutil verify`, `codesign --verify --deep --strict` trên app trong ổ chỉ đọc, kiểm ranh giới và
  chuỗi UI test); UI test riêng từng lớp ở chế độ cô lập: `PracticeFlowUITests`, `EnglishInterfaceUITests`, `NewExamFlowUITests`
  đạt; `scripts/check.sh` đạt (ghi ở PR).
- Sau sửa theo review độc lập #58 (2026-10-18): `scripts/make_dmg.sh` trên 51a223a (build 333) đạt, không còn gì trong
  `build/DerivedData-Release-DMG/Build/Products` sau khi đóng, kể cả đường lỗi (thử `--out` vào thư mục không ghi được);
  test lọc `ReadingBackground*`, `CheckedAnswerContrastTests`, `SessionSnapshotTests`, `SessionLocalizationTests` đạt (đối
  chứng âm nhãn Sai bị làm mờ 2,3–2,6:1); `scripts/check.sh` đạt. UI test không chạy lại (chỉ đổi comment và chữ thông báo
  của UI test); `verify_local.sh --uitest` đủ bộ do người điều phối chạy trên SHA cuối.
- G6 Nt0 tại chỗ (2026-10-18, trước review độc lập, trên b3d5f8f): `scripts/check.sh` đạt (kể cả "Kho v1 thật" đọc
  fixture `Library-v1.store` không tạo lại, test nơi lưu và chế độ cô lập với bundle ID mới, snapshot không đổi ảnh nào);
  `check_localization.py` (thường, `--require-en`, `--freshness`, `--built-apps`), `check_boundaries.py`,
  `check_quit_sheets.py`, `check_colors.py`, `uitest_plan.py --self-test`, `validate_exam.py --all`,
  `check_validator_parity.py` đạt; `-exportLocalizations` hai scheme không đổi catalog; build Debug và Release hai scheme,
  `check_bundle_boundary.sh` (Debug, Release), `check_release_strings.sh` đạt; Info.plist bản Release: bundle ID
  `vn.io.nt0.examsuite`/`vn.io.nt0.examsuite.admin`, `vn.io.nt0.exam` (import ở Học viên, export ở Admin), "© 2026 Nt0"
  ở vi.lproj và en.lproj. UI test riêng lớp ở chế độ cô lập (bản `.uitest`, `LSHandlerRank` None):
  `LibraryWindowRestoreUITests` (1 test), `EditExamFlowUITests` (2 test) đạt, không báo cáo crash mới.
  `scripts/make_dmg.sh --out <thư mục tạm>` (build 337) đạt; gắn ổ chỉ đọc: app mang `vn.io.nt0.*`, "© 2026 Nt0",
  "Hướng dẫn cài đặt.txt" có mục chuyển dữ liệu, không còn dòng rào ```; DMG đã xoá. App vừa build (bundle ID thật mới)
  đã xoá. Lệnh chép dữ liệu của install.md thử với thư mục nhà giả; lệnh `defaults` chỉ kiểm cú pháp.
- G6 Nt0 sau review độc lập #59 và quyết định của Nt0 (2026-10-18, trên b50d0c9): test lọc `ReportFeatureTests`,
  `ResultsReport*`, `EnglishResultsReport*`, `AppLaunchStorageTests` đạt (kể cả `projectExamTypeIdentifiers`; đối chứng
  âm: `UTTypeIdentifier` của bản Admin đổi về tên cũ thì đỏ 2 issue, đã trả lại); `-exportLocalizations` hai scheme không
  đổi catalog sau khi đổi chữ chân trang; `check_localization.py` thường và `--require-en` đạt; ảnh snapshot
  `resultsPDFFirstPage.light-a4-page1.png` ghi lại (`EXAMSUITE_SNAPSHOT_RECORD=failed`, chỉ dòng chân trang khác, vùng
  y 783–791; `examPDFFirstPage` không đổi); `scripts/check.sh` đạt (kể cả `--freshness`); UI test
  `PracticeFlowUITests` (xuất PDF kết quả, kiểm chân trang mới) đạt ở chế độ cô lập, không báo cáo crash mới.
- G6.2 tại chỗ (2026-10-18/19, trước review độc lập, xếp chồng trên ba7637d của #59): `ImportExamUITests` ở chế độ cô
  lập trên bố cục cũ với phép kiểm mới **đỏ** (cửa sổ 480×198, `Form` cao 0: "ô Tiêu đề bị vùng cuộn cắt"), sau khi sửa
  **đạt** (1 test), không báo cáo crash mới; `LibraryWindowRestoreUITests` (dùng `TiledWindow.assertInside` nay gọi
  `WindowLayout`) đạt. `ContentSizedWindowTests` đạt (kể cả đối chứng âm), hai ảnh mới `importConfirmProblems.light-480x468.png`,
  `importConfirmProblemsEnglish.light-480x503.png` (ghi bằng `EXAMSUITE_SNAPSHOT_RECORD=missing`, đã xem: đủ bốn ô, bốn dòng
  báo lỗi, ghi chú; tiếng Anh ghi chú hai dòng), không ảnh cũ nào đổi. `check_localization.py` (thường, `--require-en`,
  `--freshness`), `check_boundaries.py`, `check_quit_sheets.py`, `check_colors.py`, `uitest_plan.py --self-test` đạt;
  `-exportLocalizations` hai scheme không đổi catalog; `bash -n` hai script, `ci.yml` đọc được (YAML); `scripts/check.sh`
  đạt. UI test đủ bộ (`verify_local.sh --uitest`: chạm `Apps/UITestSupport`, `verify_local.sh`) do người điều phối chạy
  trên SHA cuối sau review.
- G6.2 sau review độc lập #60 và quyết định S1 của Nt0 (2026-10-19, trên 362674a + sửa): test lọc
  `ContentSizedWindowTests`, `importConfirm*` (kể cả `importConfirmEmptyFieldsHaveBorder` sáng/tối với đối chứng âm),
  `TiledWindowLayoutTests`, `SnapshotHostTests` đạt; hai ảnh `importConfirm*` ghi lại (`EXAMSUITE_SNAPSHOT_RECORD=missing`
  sau khi xoá ảnh cũ; đã xem: ô có viền, chữ canh trái, cột ô thẳng hàng, nhãn tiếng Anh dài xuống dòng cạnh ô), không ảnh
  khác đổi. `ImportExamUITests` ở chế độ cô lập chạy hai lần, đạt cả hai (66 s mỗi lần), không báo cáo crash mới.
  `check_localization.py` (thường, `--require-en`), `check_quit_sheets.py`, `check_colors.py`, `bash -n` hai script đạt;
  thử N1, N2 bằng bản trích hàm với `hdiutil` giả; lệnh `find` của install.md thử với thư mục nhà giả.
  `scripts/check.sh` đạt. `verify_local.sh --uitest` đủ bộ: người điều phối chạy trên SHA cuối.
- PR cuối #61 tại chỗ (2026-10-19, trên d43eff7 cộng thay đổi của PR, trước review độc lập): test lọc
  `importConfirmEmptyFieldsHaveBorder` (sáng, tối, kèm đối chứng âm), `ContentSizedWindowTests`, `importConfirmProblems*`,
  `SnapshotHostTests` đạt (11 test); phép thử đột biến bỏ `.textFieldStyle(.roundedBorder)` của hộp xác nhận: test đỏ ở
  sáng và tối (mọi cạnh 1,00), đã trả lại. `check_localization.py` (thường, `--require-en`), `check_boundaries.py`,
  `uitest_plan.py --self-test` đạt; `ci.yml` đọc được (Ruby `YAML.load_file`: `on`, `if:` của ba job), `bash -n` cả 14 khối
  `run:` đạt, đoạn `awk` của `release-dmg` lấy đúng mục `[0.1.0]` của CHANGELOG. `scripts/check.sh` đạt. UI test không
  chạy (không đổi code app; `verify_local.sh --uitest-plan`: không lớp nào). Cổng `verify_local.sh --clean --uitest` đủ bộ:
  người điều phối chạy trên SHA cuối sau review độc lập (Result).
- PR #61 sau review độc lập (2026-10-19, trên 36f9faa cộng sửa S1–S4, N1–N7): `ci.yml` đọc được (Ruby `YAML.load_file`:
  `permissions` cấp workflow `contents: read`, `concurrency.group` có `github.event_name`, `if:` và quyền của ba job),
  `bash -n` cả 15 khối `run:` đạt. Chạy thử hai bước của `release-dmg` với `gh`, `sw_vers`, `xcodebuild` giả trong repo
  tạm: kiểm tag đạt với `v0.1.0`, `v0.1.0-beta.1`, dừng (mã 1, trước build) với `v0.2.0`, `v0.1`, `vfoo` và khi
  `project.yml` có hai `MARKETING_VERSION` khác nhau; bước tạo Release với `v0.1.0` gọi `gh release create v0.1.0 …
  --verify-tag`, ghi chú có dòng commit/build ("… từ cùng commit"), Runner, "Lần chạy: https://github.com/…/actions/runs/…"
  và sha256; `v0.1.0-beta.1` thêm `--prerelease`; `v0.2.0` dừng vì không có DMG. Test lọc (11 test) đạt; đối chứng âm thứ
  hai đo 1,07 (sáng), 1,09 (tối) ở mọi cạnh; phép thử đột biến bỏ `.roundedBorder` lại đỏ ở sáng và tối, đã trả lại.
  `check_localization.py` (thường, `--require-en`) đạt; `scripts/check.sh` đạt.
- Sửa UI test nhiều màn hình (2026-10-19, trên e639986, máy có màn hình chính và một màn hình ngoài
  bên trái): `PracticeFlowUITests` chế độ cô lập chạy hai lần, đạt cả hai; lần 1 cửa sổ làm bài trên màn hình chính (màu
  đọc được (248, 243, 232), màn hình 1/2), lần 2 trên màn hình phụ (-1539, 86,5; màn hình 2/2, ảnh 3840×2160 px; màu (247,
  241, 228)). Lần thử tạm (không commit) kéo cửa sổ làm bài sang màn hình phụ rồi chạy hết luồng: đạt (khi kéo cửa sổ
  xuống dưới vùng hiển thị của màn hình phụ thì nút Xuất PDF… "not hittable", do cách kéo của lần thử). Thêm
  `LibraryWindowRestoreUITests`, `SessionWindowRestoreUITests` (cửa sổ trên màn hình phụ) chạy một lần, đạt; không báo cáo
  crash mới. `uitest_plan.py --self-test` đạt.

## Result

Đóng 2026-10-19, **qua G3**. Hai bản app có DMG riêng (`ExamSuite-0.1.0.dmg`, `ExamSuiteAdmin-0.1.0.dmg`; Release arm64,
ký ad-hoc, kiểm ranh giới hai bản và code chế độ cô lập trên đúng app đem đóng, `hdiutil verify`, chữ ký app trong DMG) và
hướng dẫn cài đặt tiếng Việt (`docs/install.md`, bản sao trong DMG, gồm chuyển dữ liệu từ bản cũ); nền đọc cho vùng câu
hỏi (năm nền, đạt tương phản); Exam Suite là dự án cá nhân của Nt0 (bundle ID `vn.io.nt0.*`, kiểu file `vn.io.nt0.exam`,
"© 2026 Nt0"); hộp xác nhận Import đề hiện đủ bốn ô có viền. Nt0 test bản beta build 349 trên macOS 26 theo checklist
G3: "Không có lỗi" (Kết quả G3, sau checklist). Bản phát hành riêng: **v0.1.0**. G3 được test tay trên DMG beta build 349
(9fff274), không phải trên DMG của commit gắn tag: #61 không chạm code app (`Packages/*/Sources`, `Apps/**`,
`project.yml`), nên commit gắn tag có cùng mã app với build 349; khác số build và câu `find` của hướng dẫn cài đặt trong
DMG.

- **Merge vào `main`:** #58 (G6.1 đóng gói DMG, nền đọc), #59 (G6 Nt0, dự án cá nhân của Nt0), #60 (G6.2 sửa lỗi beta 1
  và việc nhỏ trước phát hành). `local/verify` success: c4dafc6 (#58), ba7637d (#59), 9fff274 (#60), mỗi lần UI test đủ
  bộ (Học viên 6, Admin 4), kiểm Autosave bỏ qua. Review độc lập bằng phiên agent mới cho cả ba (không mục chặn; đã sửa
  theo các mục nên sửa và quyết định của Nt0).
- **PR cuối #61** (rủi ro cao: `ci.yml`): gắn tag chỉ chạy `release-dmg`, hai job kiểm chỉ chạy tay (Nt0 chốt
  2026-10-19); phép đo viền từng cạnh của `importConfirmEmptyFieldsHaveBorder` và câu `find` của install.md (việc còn lại
  của review lại #60); CHANGELOG `[0.1.0]` (ngày phát hành là ngày của tag); kết quả G3; đóng plan. Review độc lập #61:
  không mục chặn, đã sửa S1–S4, N1–N7 (Decisions 2026-10-19). Không tính năng mới.
- **Bằng chứng cổng G3 và DMG đóng tại chỗ** (không ghi lại ở đây; review-and-merge.md mục 4): SHA phát hành là commit mà
  tag `v0.1.0` trỏ tới (`git rev-parse 'v0.1.0^{commit}'`); bằng chứng là commit status `local/verify` trên SHA đó, mô tả
  có "macOS ok (clean)" và "đủ bộ" (`gh api repos/tuann2/exam-suite/commits/$(git rev-parse 'v0.1.0^{commit}')/statuses`);
  số build và sha256 hai DMG đóng tại chỗ nằm trong lời nhắn của tag (`git tag -l --format='%(contents)' v0.1.0`).
- **Phát hành:** GitHub Release `v0.1.0` (`gh release view v0.1.0`): ghi chú phát hành ghi commit, số build, macOS/Xcode
  của runner, sha256 hai DMG của Release và link lần chạy `release-dmg`.

**Các bước phát hành** (sau khi PR #61 merge; người điều phối làm, bước 2 và 5 do Nt0 chạy; agent không gắn tag, không
đẩy tag, không chạy CI):

1. **Cổng:** `git switch main && git pull`, tree sạch; `scripts/verify_local.sh --clean --uitest` trên SHA merge của #61
   (hoặc trên SHA cuối của #61 nếu cổng đã chạy ở đó trước khi merge). SHA này là **SHA phát hành**: DMG và tag đều trên
   đúng SHA đã qua cổng (số build = `git rev-list --count` của SHA đó, nên khác SHA thì khác số build). Status
   `local/verify` nằm trên chính SHA đó.
2. **Automation Mode:** trình chạy test cần Automation Mode; macOS có thể hỏi xác thực. Ngay khi cổng đạt (cổng là lần
   chạy UI test cuối của giai đoạn; không chờ tag), người điều phối nhắc Nt0 bật lại xác thực Automation Mode nếu đã tạm
   tắt cho UI test; **agent không bao giờ đổi cài đặt này.**
3. **DMG:** `git switch --detach <SHA phát hành>` (tree sạch), `scripts/make_dmg.sh --clean`; hai DMG vào `dist/`, file
   `.txt` đi kèm ghi phiên bản, số build, SHA. Script xoá app vừa build (bundle ID thật); không cài, không mở app. Viết
   file lời nhắn của tag (ngoài cây git hoặc trong `build/`, đã bị bỏ qua), ví dụ:

   ```text
   Exam Suite 0.1.0

   local/verify: <mô tả status local/verify trên SHA phát hành>
   Build: <số build>
   ExamSuite-0.1.0.dmg sha256 <…> (đóng tại chỗ, make_dmg.sh)
   ExamSuiteAdmin-0.1.0.dmg sha256 <…> (đóng tại chỗ, make_dmg.sh)
   ```

   sha256 lấy bằng `shasum -a 256 dist/*.dmg`.
4. **Nt0 báo đi tiếp:** đưa hai DMG cho Nt0 (cài thử nếu Nt0 muốn: mã app như build 349; khác số build và câu `find`
   trong hướng dẫn cài đặt). Chỉ sang bước 5 khi Nt0 báo.
5. **Gắn tag (Nt0 chạy):** người điều phối đưa Nt0 đúng hai lệnh, có SHA phát hành và đường dẫn file lời nhắn (như lệnh
   merge): `git tag -a v0.1.0 <SHA phát hành> -F <file lời nhắn>` rồi `git push origin v0.1.0`. Tag phải trên đúng SHA
   phát hành (không gắn lên `main` nếu `main` đã đi tiếp). Agent không bao giờ đẩy tag.
6. **CI:** gắn tag chạy workflow `CI`, chỉ job `release-dmg` (hai job kiểm hiện "skipped"): kiểm tag khớp
   `MARKETING_VERSION`, `make_dmg.sh --clean` trên runner `macos-15`, rồi `gh release create v0.1.0 … --verify-tag` đính
   hai DMG, ghi chú lấy mục `[0.1.0]` của CHANGELOG kèm commit, số build, macOS/Xcode của runner, sha256 và link lần chạy.
   Theo dõi: `gh run list --workflow CI --limit 1`, `gh run watch <run ID>`, `gh release view v0.1.0`.
7. **Không sửa plan:** tag và Release là nguồn (hai dòng bằng chứng bên trên); báo Nt0 link Release. Job lỗi: DMG đóng
   tại chỗ ở bước 3 vẫn dùng được; Nt0 quyết Re-run trên chính lần chạy đó (sự kiện vẫn là tag) hay sửa ở PR mới. DMG của
   Release không trùng từng byte với DMG ở bước 3 (Risks); Nt0 chọn phát bản nào.

**Việc còn lại** (không chặn G3, không chặn phát hành):

- **macOS 15 chưa kiểm** (Risks, Nt0 chấp nhận): có máy macOS 15 thì thử tay hộp Import đề… (bốn ô có viền, ghi chú đủ,
  cửa sổ thu lại/lớn lên) và các màn chính; lỗi thì sửa ở bản sau.
- **Biểu tượng tạm** (Decisions câu 6): Nt0 thay sau; vẽ lại bằng `scripts/make_icons.swift` hoặc thay asset catalog.
- **Kiểm Autosave của `verify_local.sh --uitest`** bỏ qua ở #58–#60 (app chạy script chưa có Full Disk Access): cấp Full
  Disk Access để cổng kiểm đủ, không thì status ghi "kiểm Autosave: bỏ qua".
- **Dữ liệu và bản app cũ (bundle ID cũ):** Nt0 giữ làm bản sao lưu; xoá khi chắc bản mới đủ dữ liệu (install.md, Lưu ý).
- **Cảnh báo isolation có từ #60** trong test viền (hàm `visit` lồng trong closure `inspect` đọc thuộc tính `@MainActor` của
  `NSView`; chỉ đánh dấu `inspect` là `@MainActor` thì lỗi biên dịch vì biến `frames` bị bắt): dọn ở PR kế tiếp cùng vùng.
- Ngoài phạm vi v1 (plan-macos-v1.md, Build và phân phối riêng): Developer ID và notarize, tự cập nhật (Sparkle), bản
  Intel. Việc tiếp theo (ví dụ bản Android, docs/product/plan-android-v1.md) lập plan mới khi Nt0 quyết.
