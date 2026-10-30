# Review, bằng chứng và merge

Ba cơ chế mượn từ ai-workflow-template (ADR 0007), áp dụng cho mọi PR.

## 1. Giới hạn quyền của agent

- Làm trên nhánh `feature/<giai-doan>-<mục>`; **không push `main`**, **không tự merge**.
- Mỗi PR đúng **một mục** trong exec-plan đang active, đủ nhỏ để duyệt trong một lượt đọc.
- **Không thêm thư viện ngoài** (SwiftPM, Homebrew cho build, GitHub Action lạ) khi chưa có ADR ở `docs/decisions/` được duyệt (ADR 0006).
- Không sửa CI, branch protection, hook khi chưa được yêu cầu rõ.
- **Không chạm dữ liệu thật của người dùng máy:** không đọc, ghi, chép hay xoá `~/Library/Application Support/<bundle ID>/`
  và `defaults` của hai bundle ID `vn.io.nt0.examsuite`, `vn.io.nt0.examsuite.admin`. Domain của bản build UI test
  (`….uitest`) không thuộc quy tắc này. Chỉ lái app ở chế độ cô lập của UI test (AGENTS.md); `verify_local.sh --uitest`
  chỉ so tên, mtime, cỡ và băm `defaults`.

## 2. Bằng chứng gắn commit

- Điều kiện merge: commit status **`local/verify` = success trên đúng SHA cuối** của PR, do `scripts/verify_local.sh` ghi sau khi chạy đủ các bước của hai job CI (macOS: `check.sh`, xcodebuild hai scheme, kiểm bundle, kiểm String Catalog của hai app và `-exportLocalizations`; Linux: `check.sh --core` trong Docker `swift:6.1` trên đúng commit). Tóm tắt "đã test" của agent không phải bằng chứng. Kiểm bằng `gh api repos/tuann2/exam-suite/commits/<sha>/status` hoặc ô trạng thái của PR.
- Vì sao không dùng GitHub Actions cho mỗi PR (Nt0 quyết 2026-10-16): repo private dùng phút Actions có hạn (2.000 phút/tháng), job macOS tính gấp 10; mỗi lần CI tốn khoảng 42 phút tính tiền và tháng 10/2026 đã dùng 90% sau 77 lần chạy. Lý do này có từ khi repo còn private; repo public (từ 2026-10-20) chạy
  Actions miễn phí trên runner của GitHub, còn bật CI cho PR là quyết định sau của Nt0; tới lúc
  đó quy tắc dưới đây không đổi. Workflow `CI` chỉ chạy tay hoặc khi gắn tag `v*`, mỗi sự kiện một nhóm job (Nt0 chốt 2026-10-19): chạy tay chỉ hai job kiểm `core-linux`, `apps-macos`; gắn tag chỉ job `release-dmg`.
- **Ở mỗi cổng** (G2 cuối giai đoạn 3, G3 cuối giai đoạn 6), trên SHA `main` sẽ đem đi test tay/phát hành: `scripts/verify_local.sh --clean --uitest` (build lại từ đầu, gần máy sạch, kèm UI test); ghi SHA và status vào phần Validation/Result của exec-plan.
- **Hai job kiểm của workflow `CI` (máy sạch của GitHub; lúc repo còn private ~42 phút tính tiền, repo public miễn phí) chỉ chạy khi Nt0 báo** (Nt0 quyết 2026-10-16, thay quyết định chạy ở mọi cổng cùng ngày; cổng G2 không chạy; giai đoạn 6 không chạy hai job kiểm, Nt0 chốt 2026-10-19: bằng chứng cho SHA phát hành là cổng `verify_local.sh --clean --uitest`). Chạy tay: `gh workflow run CI --ref main`, ghi link run vào exec-plan đang active hoặc PR. Gắn tag `v*` chỉ chạy job `release-dmg` (đóng hai DMG trên runner macOS, tạo GitHub Release; từ v0.1.1 đây là DMG phát hành công khai, Nt0 chốt 2026-10-20), nên chỉ Nt0 đẩy tag.
- **Bản Android (`android/`, Nt0 chốt Q8 2026-10-22, ADR 0011)**: ngoại lệ của quy tắc "CI không chạy theo PR". Workflow `Android` (`.github/workflows/android.yml`, runner Linux) chạy theo mọi PR chạm `android/**`, `fixtures/**`, `schema/**` hay đề mẫu; check `android` (`android/scripts/check_android.sh`: luật riêng, lint, test, so ảnh) xanh trên SHA cuối **thay** kiểm tại chỗ phần đó. PR chạm `android/app/**` và mọi cổng Android thêm status `local/verify-android` (`android/scripts/check_android.sh --ui`: test Compose trên emulator của Mac, không chạy lại lint + test). Tag phát hành Android là `android-v*` (không khớp `v*` của macOS), chỉ Nt0 đẩy.
- **Bản iOS** (docs/product/plan-ios-v1.md, ADR 0013): ở mức full, `verify_local.sh` build bản iOS cho simulator, kiểm
  ranh giới bundle (ADR 0003) và chữ Info.plist vi/en của app iOS, export String Catalog của scheme `ExamSuiteiOS`;
  `--uitest` chạy thêm các lớp `ExamSuiteiOSUITests` mà `uitest_plan.py` chọn, trên simulator (máy và runtime:
  `EXAMSUITE_IOS_DESTINATION`). Status vẫn một `local/verify` ("iOS ok"). Tag phát hành iOS là `ios-v*`, chỉ Nt0 đẩy.
- **Mức kiểm của `local/verify` theo file đổi** (Nt0 chốt 2026-10-22, `scripts/verify_scope.py`): `verify_local.sh` vẫn chạy ở mọi PR và luôn kiểm danh tính git, nhưng chỉ chạy phần macOS bị ảnh hưởng. **none**: chỉ `android/**`, `docs/**`, `AGENTS.md`, `CLAUDE.md`, workflow Android: không bước macOS nào (vài giây). **core**: thêm oracle và test của lõi Swift mà test giao diện không đọc (`fixtures/invalid-json`, `vectors`, `packages`, `expected-verdicts.json`, `schema/`, `Packages/ExamKit/Tests`, `validate_exam.py`, `check_validator_parity.py`): `check.sh --core` trên macOS và Linux (khoảng 1,5 phút). **full**: mọi thứ khác (code app, lõi Swift, `fixtures/exams`, `fixtures/invalid`, script, project, workflow macOS), file chưa có trong bảng, và luôn khi `--clean` (cổng), `--uitest-all`, `--full`. Mô tả status mở đầu bằng tên mức ("mức none:", "mức core:", "mức full:"); file chuyển chỗ tính cả đường dẫn cũ. `verify_local.sh --scope-plan` in mức trước khi chạy.
- **Danh tính git** (Nt0 chốt 2026-10-20, repo public): commit dùng địa chỉ ẩn của GitHub (`<id>+<tài khoản>@users.noreply.github.com`); `verify_local.sh` dừng trước mọi bước build khi một commit bất kỳ từ merge-base với `origin/main` tới HEAD (trên `main`: HEAD) có email tác giả khác địa chỉ đó, hay email người commit khác địa chỉ đó và khác `noreply@github.com` (merge trên web GitHub); đối chứng dương và âm chạy mỗi lần; `--check-identity` chỉ chạy bước này. Cách sửa: commit ở đỉnh chưa push thì `git commit --amend --no-edit --reset-author`, còn lại viết lại các commit của nhánh trước khi merge. Commit có từ trước khi công khai (chỉ ở repo riêng cũ) chỉ được miễn khi người điều phối đặt `EXAMSUITE_IDENTITY_ALLOW=<sha>[,<sha>]` cho đúng lần chạy đó (cảnh báo từng commit; status ghi "miễn danh tính N commit"). Trên GitHub: bật "Keep my email addresses private" và "Block command line pushes that expose my email".
- **UI test** (`scripts/verify_local.sh --uitest`: XCUITest `ExamSuiteUITests` của bản Học viên, luồng bàn phím
  1–3 của overview.md, rồi `ExamSuiteAdminUITests` của bản Admin): PR chạm code app (`Packages/ExamFeatures/Sources/**`,
  lõi `Packages/ExamKit/Sources/{ExamKit,ExamFile}/**`, `Apps/**`) chạy **các lớp test bị ảnh hưởng** theo bảng map của
  `scripts/uitest_plan.py` (file đổi so với `git merge-base origin/main HEAD`, không dò đổi tên); **đủ bộ** khi chạm
  hạ tầng chung (`Apps/UITestSupport/**`, `Apps/StudentUITests/**`, `Apps/AdminUITests/**`, `project.yml`,
  `Package.swift`/`Package.resolved` của ExamFeatures và ExamKit, code chế độ cô lập, `verify_local.sh`,
  `uitest_plan.py`), khi chạm module dùng chung mọi cửa sổ (LibraryFeature,
  LibraryData kể cả đề mẫu, SessionFeature, lõi ExamKit/ExamFile: luồng UI lưu/mở lại đề, đọc nghiêm, đồng hồ phiên),
  khi file code app chưa có trong bảng, ở cổng (`--clean --uitest`) và khi người duyệt yêu cầu (`--uitest-all`).
  `LargeExamSupport` (chỉ ở test), tài liệu, unit test, script khác: không chạy UI test. Phần chỉ của bản iOS
  (`Packages/MobileFeatures/**`, `Apps/StudentiOS/**`, `Apps/StudentiOSUITests/**`) chỉ chạy lớp `ExamSuiteiOSUITests`
  theo bảng map, không chạy hai bản macOS. Target
  không có lớp nào thì không build, không chạy; hai target dùng chung `build/DerivedData-UITest` (`build-for-testing`
  một lần mỗi scheme, rồi `test-without-building -only-testing:<target>/<lớp>`). Xem trước các lớp sẽ chạy:
  `scripts/verify_local.sh --uitest-plan` (không build, không ghi status). Sau khi sửa theo review độc lập mà không đổi
  vùng giao diện khác, chạy lại chỉ các lớp đã map. Lớp UI test mới (mọi `class …: XCTestCase` trong `Apps/*UITests/**`)
  phải là lớp chính của ít nhất một dòng module của bảng (dòng shell không tính): thiếu thì `check.sh` thất bại
  (`uitest_plan.py --self-test`), còn `verify_local.sh` chạy đủ bộ kèm cảnh báo. Không vào CI (Nt0 quyết 2026-10-15; T1, T2, T5 của
  [notes/g5-ui-test-trung-lap.md](../notes/g5-ui-test-trung-lap.md), Nt0 chốt 2026-10-18).
  Mô tả status ghi "UI test ok (Học viên N, Admin M, iOS K test, theo file đổi, kho thật không đổi)" (N, M, K là số test **đã
  chạy**; "đủ bộ" thay "theo file đổi" khi chạy đủ), thêm "; K lần chạy lại do lỗi hạ tầng" nếu có, "UI test bỏ qua
  (không lớp nào bị ảnh hưởng)" hoặc "UI test bỏ qua" (mô tả dài quá 140 ký tự, giới hạn của GitHub, bị cắt phần cuối). Mỗi test UI thất bại được chạy lại một lần; script chỉ chấp nhận khi mọi lỗi của lần đầu là lỗi hạ tầng của XCUITest (tổng hợp sự kiện hết giờ, mất kết nối, chưa được cấp quyền…), lỗi assert của test thì vẫn thất bại. Target không có test nào đạt hoặc có test bị bỏ qua (`skipped`) cũng là thất bại. App crash ở lần đầu XCUITest báo giống lỗi hạ tầng ("Lost connection… is not running"), nên script so tên file trong `~/Library/Logs/DiagnosticReports/` bắt đầu bằng `Exam Suite` (Học viên, Admin, cả bản `.uitest`; chỉ đọc tên, không đọc nội dung) trước và sau mỗi target: có báo cáo crash mới thì thất bại dù lần chạy lại đạt. Bản `.uitest` có vai `None` với `.exam` (LSHandlerRank theo `EXAMSUITE_DOC_HANDLER_RANK` trong project.yml) để Finder không chọn nó mở file; script kiểm Info.plist của bản `.uitest` vừa build sau khi chạy. Khi status có "lần chạy lại", người duyệt mở log `build/verify-<sha>.log` (người điều phối dán đoạn lỗi vào PR) để chắc đó là lỗi hạ tầng; người duyệt PR chạm giao diện
  kiểm dòng này. Cần: màn hình mở khoá, máy chỉ có một màn hình (rút màn hình ngoài: đã kiểm ở cổng G3; bật
  Mirror chưa thử; Nt0 chốt 2026-10-19, plan giai đoạn 6), không ai dùng chuột/bàn phím trong lúc chạy, trình chạy test được macOS
  cho phép điều khiển máy (Accessibility, Automation Mode; macOS có thể hỏi xác thực, người điều phối cấp; agent gặp lỗi
  "Timed out while enabling automation mode" hoặc hộp thoại cấp quyền thì dừng và báo, không tự cấp quyền hay sửa
  TCC). App chạy ở chế độ cô lập (kho, đề mẫu, cài đặt trong thư mục tạm; bundle ID `vn.io.nt0.examsuite.uitest`,
  `vn.io.nt0.examsuite.admin.uitest`); script chạy cả hai target kể cả khi target đầu thất bại, rồi so cả cây
  `~/Library/Application Support/<bundle ID>/` (tên, mtime, cỡ từng file), `defaults` và đề mở gần đây thật của **cả hai bản** trước và sau (bundle ID `vn.io.nt0.examsuite`, `vn.io.nt0.examsuite.admin`), khác nhau thì thất bại; so cả `~/Library/Autosave Information/` (macOS tự lưu đề chưa lưu vào đây, không theo bundle ID): có mục mới hay đổi mang tên Exam Suite, `vn.io.nt0.examsuite` hoặc đuôi `.exam` thì thất bại (chỉ đọc tên, mtime, cỡ; mục mới khác chỉ ghi chú trong log). macOS (TCC) chặn đọc thư mục này nếu app chạy script (Terminal, iTerm, VS Code) chưa có **Full Disk Access**: script dừng ngay từ đầu, không bao giờ đạt mà không kiểm. Chưa cấp được thì chạy `--uitest --no-autosave-check`: status ghi "kiểm Autosave: bỏ qua" ngay sau "kho thật không đổi", người duyệt thấy rõ. Ứng dụng ở chế độ cô lập có `CFFIXED_USER_HOME` trỏ vào thư mục tạm, nên Foundation đặt thư mục tự lưu trong thư mục nhà tạm; so thư mục thật là lớp chặn thứ hai. Bước cần Điều hướng bàn
  phím (Full Keyboard Access) của macOS mà máy chạy test tắt thì test dùng chuột và ghi `needsFullKeyboardAccess`
  trong log (danh sách ở `Apps/StudentUITests/Support/StudentFlow.swift`).
- PR ghi lệnh đã chạy tại chỗ (`scripts/check.sh`, `xcodebuild …`) và phần máy không kiểm được cần người test tay.
- Trạng thái enforcement: `local/verify` là commit status do script trên Mac của người điều phối ghi, không phải runner độc lập; workflow `CI` (file `.github/workflows/ci.yml`) không tự chạy trên PR hay push `main`. **Branch protection chưa bật**: lúc repo còn private, gói GitHub Free không hỗ trợ (thử 2026-10-15, HTTP 403); repo public (từ 2026-10-20) bật được, bật hay không là quyết định sau của Nt0. Tới khi bật, người duyệt tự kiểm `local/verify` xanh trên SHA cuối trước khi bấm merge; agent không bao giờ push thẳng `main`.

## 3. Review độc lập theo rủi ro

**Rủi ro cao** khi PR chạm vào bất kỳ đường dẫn nào sau:

| Vùng | Đường dẫn |
| --- | --- |
| Chấm điểm, chọn câu | `Packages/ExamKit/Sources/ExamKit/**` (Scoring, Composer, Session) |
| Đọc/ghi gói đề, chuyển phiên bản | `Packages/ExamKit/Sources/ExamFile/**`, `schema/**`, `fixtures/**` |
| Lưu file soạn đề | `Packages/ExamFeatures/Sources/AuthoringFeature/**` (document, save, recovery) |
| Ranh giới hai bản app | `project.yml`, `Packages/ExamFeatures/Package.swift`, `Packages/MobileFeatures/Package.swift` (bản iOS là một bản Học viên, ADR 0013), `Apps/**`, `scripts/check_boundaries.py` |
| Bản Android: lõi, lưu trữ | `android/core/**`, Room schema và `ExamStore` trong `android/data/**` (plan-android-v1.md Phần 4) |

Với PR rủi ro cao:

1. Sau khi code xong (`check.sh` và các lớp UI test đã map đạt tại chỗ; `local/verify` chạy **sau** review, mục 4), mở **một phiên agent mới** (không mang transcript của phiên code) với prompt:

   > Review độc lập PR #N trên repo này. Đọc `AGENTS.md`, `docs/product/<lĩnh vực>.md`, ADR liên quan và diff của PR. Không sửa code. Trả lời: (a) diff có làm đúng và chỉ đúng mục exec-plan không; (b) có vi phạm quy tắc trong tài liệu sản phẩm/ADR không, trích dẫn dòng; (c) test có phủ các tình huống bắt buộc trong tài liệu sản phẩm không, thiếu tình huống nào; (d) rủi ro còn lại. Kết luận: APPROVE / REQUEST CHANGES kèm lý do.

2. Dán kết quả vào PR (mục "Bằng chứng"). REQUEST CHANGES → phiên code sửa, lặp lại.
3. Người duyệt đọc diff + review độc lập rồi mới merge.

PR **thường**: người duyệt diff là đủ.

## 4. Nhịp làm việc (áp dụng mọi giai đoạn từ 2026-10-18, Nt0 chốt)

Căn cứ: [notes/g5-ui-test-trung-lap.md](../notes/g5-ui-test-trung-lap.md) và
[notes/ra-soat-cach-lam-macos.md](../notes/ra-soat-cach-lam-macos.md) (rà soát cách làm bản macOS, trước ở Phần 1 của
plan-android-v1.md). Áp dụng cho giai đoạn 5 từ
bước 9, giai đoạn 6 và mọi giai đoạn sau.

- **Một `verify_local.sh --uitest` mỗi PR**, trên SHA cuối sau khi đã sửa theo review độc lập. Không chạy trước review;
  review độc lập chạy chỉ đọc, song song với lúc làm.
- Trong lúc làm, agent chỉ chạy **các lớp UI test đã map** (`verify_local.sh --uitest-plan` cho biết lớp nào) ở chế độ
  cô lập. Chạy lại sau thất bại hay sau khi sửa: chỉ các lớp đã map, trừ khi hạ tầng chung đổi (mục 2).
- **Re-review chỉ với PR rủi ro cao** (mục 3). PR rủi ro thường: người điều phối xem diff của phần sửa.
- **Xếp chồng tối đa một tầng.** Nhánh mới rẽ từ `main` sau khi bước phụ thuộc đã merge.
- **Không có PR chỉ tài liệu, chỉ kế hoạch hay chỉ spike.** Kết luận spike, cập nhật plan, đóng giai đoạn và plan của
  giai đoạn sau đi vào PR code gần nhất.
- Sửa nhỏ và nit gom vào PR code kế tiếp cùng vùng.
- Không chia một thay đổi liền khối (ví dụ một module lõi thuần) thành nhiều PR rủi ro cao: một PR, một lượt review độc
  lập.
- **Không thêm lớp kiểm mới** (script, bộ test song song) cho hành vi đã được kiểm; ưu tiên ít lớp hơn
  (notes/g5-ui-test-trung-lap.md mục 3, notes/ra-soat-cach-lam-macos.md mục 3).
- Số đo chỉ để ghi (test `Timing` chỉ ghi số, không so giới hạn chặn) chạy dưới `scripts/measure_large.sh`
  (`EXAMSUITE_MEASURE_RECORD=1`), không ở mọi PR.
- Mỗi lúc **một việc nặng** (build, test, đo) trên Mac của người điều phối.

## Checklist người duyệt

- [ ] Đúng một mục exec-plan; exec-plan đã cập nhật Progress/Decisions/Validation.
- [ ] `local/verify` = success trên SHA cuối (CI GitHub không phải điều kiện merge; gắn tag chỉ chạy job `release-dmg`);
      PR chạm giao diện: mô tả status có "UI test ok" (hoặc "UI test bỏ qua (không lớp nào bị ảnh hưởng)" khi bảng
      map không chọn lớp nào); cổng: "đủ bộ".
- [ ] `local/verify` xanh ở mức đúng (mô tả status nêu mức none/core/full; mức thấp hơn mức của file đổi là sai).
- [ ] PR chạm `android/`: check `android` của CI xanh trên SHA cuối; chạm `android/app/**` hay là cổng: thêm `local/verify-android`.
- [ ] Rủi ro cao có review độc lập đính kèm.
- [ ] Không thư viện mới ngoài ADR.
- [ ] Không chép code/đề từ Open Exam Suite (ADR 0001).
- [ ] Phần cần test tay đã liệt kê; cổng (G1/G2/G3) chỉ qua sau khi người test tay trên Mac.
