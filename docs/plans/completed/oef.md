# Execution Plan: mở file `.oef` của Open Exam Suite (macOS, iOS, Android)

Date: 2026-10-31

## Status

Completed 2026-11-01. O1 (PR #13), O3 (PR #14), O2 (PR #15) đã merge; cổng GO1 và GO2 đạt (Nt0 thử ngày 2026-11-01).
Đóng trong PR phát hành (nhánh `feature/oef-phat-hanh`: macOS 0.2.0, Android 0.2.0, iOS 0.1.0); các bước sau khi PR đó
merge ở mục Result.

## Outcome

Học viên trên macOS, iOS và Android mở thẳng file `.oef` (bản Protobuf của Open Exam Suite) như file `.exam`; bản Admin
import `.oef` qua Import đề…. Cùng một file ra cùng một đề (id, chữ, ảnh) ở mọi bản, theo hợp đồng ở exam-format.md (mục
File `.oef`). Qua cổng GO1 (sau O1) và GO2 (sau O2, O3).

## Context

- Kế hoạch: [plan-oef.md](../../product/plan-oef.md) (định dạng Phần 1, hành vi Phần 2, kiến trúc Phần 4, lộ trình
  Phần 5, kiểm thử Phần 6, rủi ro Phần 7, bảng Quyết định QO1–QO14 Nt0 chốt 2026-10-31).
- Hợp đồng: exam-format.md (mục File `.oef`), import.md (mục `.oef`); O2 thêm library.md, mục "Bản iOS" của mobile.md; O3
  thêm mục Android của mobile.md.
- Quyết định: ADR 0014 (đọc `.oef`), 0002 (gói `.exam`), 0003 (ranh giới hai bản), 0006, 0012 (không thêm thư viện), 0008
  (lõi chỉ Foundation), 0011 (oracle chung với lõi Kotlin).
- Quy trình: review-and-merge.md; cả ba PR là rủi ro cao (O1: `ExamFile`, `fixtures/`; O2: `project.yml`, `Apps/**`,
  InterfaceCore; O3: `android/core`).

## Scope

In scope: các bước O1–O3 của plan-oef.md Phần 5, mỗi bước một PR.

Out of scope: ghi `.oef`; đọc bản zip + XML hay BinaryFormatter của OES; JSON/XML do OES xuất; bản Admin mở `.oef` từ
Finder.

## Approach

O1 (hợp đồng, oracle `fixtures/oef/`, `OEFReader` trong ExamFile, Import đề… nhận `.oef`) → O2 (bản Học viên macOS và iOS:
Thư viện, phiên thi đọc qua `ExamSourceReader`, UTType; sau khi I3 của iOS merge) ∥ O3 (Android: lõi Kotlin cùng oracle,
`ExamLibrary.import` chuyển `.oef` thành gói `.exam`).

## Risks And Recovery

- Rủi ro ở plan-oef.md Phần 7.
- O1 chỉ thêm (bộ đọc, oracle, nhánh `.oef` của import) cộng hai chỗ chạm code có sẵn: vòng nén của `SHA256` (viết lại để
  bản Debug đủ nhanh; `SHA256Tests`, dấu vân tay câu và tên ảnh giữ nguyên kết quả) và case `.oef` của `ExamFileError`
  (switch đủ case ở `ErrorMessages`, `ExamFileInspector`). Gỡ là revert PR.

## Progress

- [x] O1 Hợp đồng, oracle, bộ đọc Swift, Import đề… (rủi ro cao; PR #13, merge 2026-10-31, cổng GO1 thử sau). Đã làm: ADR 0014; exam-format.md mục File
      `.oef`; import.md mục `.oef`; ghi chú ở ADR 0002, 0003; `ProtobufWire`, `OEFReader`, `OEFProblem`/`OEFNote`/
      `OEFLimits`, `ExamSourceReader`, `ExamFileError.oef` (ExamFile); `scripts/make_oef.py` + 15 fixture
      `fixtures/oef/` + `expected.json` viết tay; `OEFReaderTests` (oracle, vector), `OEFRobustnessTests` (cắt cụt,
      đột biến có seed, giới hạn); câu báo `ErrorMessages` (InterfaceCore) và lớp phân loại của `ExamFileInspector`; Admin:
      `ImportSourceFormat.oef`, `OEFImporter`, mã và chi tiết mục báo cáo mới, `ImportError.unreadableOEF`,
      `AuthoringMessages`, `OEFImportTests`, ca `.oef` thật trong `ImportFlowModelTests`; catalog vi/en; ngân sách
      `oef.read` + test `Timing` (`OEFEncoding` chỉ cho test trong LargeExamSupport); vòng nén `SHA256`.
- [x] O2 Bản Học viên macOS và iOS (rủi ro cao; PR #15, merge 2026-11-01). Đã làm: hai điểm đọc của bản Học viên qua
      `ExamSourceReader` (`ExamFileInspector.defaultReader`, `SessionServices`); `inspectNewFile` nhận `.oef`; UTType
      `openExamFile`, `examSourceTypes` cho hộp chọn file của Thư viện macOS và iOS; `project.yml`: UTType import
      `vn.io.nt0.examsuite.oef` ở ba bản app, document type `.oef` hạng Alternate ở hai bản Học viên (bản `.uitest`
      None), InfoPlist.xcstrings "Đề Open Exam Suite"; Thông tin: dòng Định dạng; bản Admin: Sửa tắt với đề `.oef`, kèm
      chú thích; câu "không phải file đề .exam hay .oef"; `verify_local.sh` kiểm hạng của mọi document type của bản
      `.uitest`; test `OEFLibraryTests`, `LibraryModelTests`, `AppLaunchStorageTests`, luồng 3 iOS thêm `.oef`;
      library.md, mobile.md mục Bản iOS, CHANGELOG, CHANGELOG-ios, thuật ngữ đề xuất của accessibility-localization.md.
- [x] O3 Android (rủi ro cao; PR #14, merge 2026-10-31). Đã làm: `:core` `ProtobufWire`, `OefReader` (chỉ đọc nghiêm, file đọc qua
      ánh xạ bộ nhớ), `OefProblem`/`OefPlace`/`OefLimits`, `ExamFileError.Oef`, `ExamSourceKind` (nhận diện theo nội
      dung), `ExamPackageWriter`, `MediaNaming.path`; `SharedOracleTest` đọc `fixtures/oef/` (phần đọc nghiêm, vector),
      `OefReaderTest` (cắt cụt, đột biến có seed, giới hạn, nhận diện, ghi gói rồi đọc lại); `:data` `ExamLibrary.import`
      chuyển `.oef` thành gói trong `.incoming` rồi đọc nghiêm như cũ, `ImportProblem.NotAnExamFile`; `ExamLibraryTest`
      thêm `.oef`; `:app` câu báo vi/en (`Messages.kt`, `strings.xml`); `ExamIntentFlowTest` thêm đoạn mở `.oef`;
      exam-format.md (Nhận diện của Android), mobile.md, install-android.md, `android/CHANGELOG.md`. Kèm sửa tài liệu
      phát hành Android theo việc Nt0 đăng 0.1.0 lên GitHub Releases dạng Pre-release (2026-10-23): android-release.md,
      install-android.md, `android/CHANGELOG.md`, Q10 của plan-android-v1.md.
- [x] Cổng GO1 và GO2 (Nt0, 2026-11-01): đạt (Validation).
- [x] Phát hành (nhánh `feature/oef-phat-hanh`): macOS 0.2.0 (`MARKETING_VERSION` của hai target macOS), Android 0.2.0
      (`versionCode` 2), iOS 0.1.0 (bản đầu, đã có `.oef`); CHANGELOG ba bản; `docs/install.md` nhắc `.oef`; bước kiểm
      tag của job `release-dmg` chỉ so phiên bản của hai target macOS (Decisions); đóng plan này và exec-plan iOS v1.

## Decisions

- 2026-10-31 (spike O1, QO14): file mẫu công khai của repo Open Exam Suite: `samples/` hiện tại (Basic Science 8 câu, GMAT
  20 câu) là Protobuf; cùng file ở commit 2019 và fixture `BasicScience.legacy.oef` là BinaryFormatter (header MS-NRBF).
  protobuf-net không ghi trường mang giá trị mặc định (HideAnswers false, IsMultipleChoice false, danh sách rỗng, ảnh
  rỗng); `char` là varint mã UTF-16; `double` dạng fixed64; `No` đánh lại từ 1 mỗi phần. Không file mẫu nào có ảnh hay
  câu nhiều đáp án: phủ bằng fixture tự dựng; bộ đọc nhận Answers cả packed lẫn từng phần tử. Bộ đọc đọc nghiêm được hai
  file Protobuf (đáp án đúng như file), báo `legacyFormat` cho bốn file bản cũ. File mẫu không vào git.
- 2026-10-31: tìm `.oef` trên GitHub ra toàn file bài tập dạng chữ của WIMS (cùng đuôi, định dạng khác): thêm fixture
  `van-ban-wims` (tự soạn) và dòng rủi ro trong plan-oef.md.
- 2026-10-31 (chi tiết cài đặt, không đổi chính sách): id phần và câu đếm theo file kể cả phần, câu bị bỏ (bỏ câu không làm
  dời id câu sau, bản Admin và bản Học viên cùng id); bản Học viên gặp quá 26 lựa chọn là lỗi riêng vì `OptionID` chỉ có
  A–Z; câu không có lựa chọn ở bản Học viên để `ExamValidator` báo thay vì báo "đáp án không khớp". Ghi ở exam-format.md.
- 2026-10-31: test `Timing` `oef.read` (đề chuẩn 2.000 câu, 200 ảnh ~60 MB) lần đầu 14 s ở Debug, vượt giới hạn chặn 6 s:
  13,5 s là SHA-256 đặt tên ảnh (Swift thuần ở -Onone, mỗi `rotr`, phép dịch generic, vòng `for … in` là lời gọi hàm).
  Viết lại vòng nén bằng con trỏ, phép dịch có mặt nạ, vòng `while`: 1,14 s ở Debug. Không dùng CommonCrypto (ADR 0008:
  ExamFile chỉ Foundation).

- 2026-10-31 (review độc lập O1): sửa: Answers tính vào giới hạn số phần tử (file dựng có hàng triệu đáp án từng làm treo
  và tốn hàng GB); khử trùng đáp án lệch và chữ trùng bằng tập hợp; nối Z một lần, bỏ chữ rỗng; số thứ tự câu tính sẵn;
  giữ 20 đường dẫn trường lạ đầu; ghi chú phần không tên chỉ cho phần còn lại. Hợp đồng ở exam-format.md ghi rõ thêm (số
  trường quá lớn, so chữ cái 64 bit, bool, TimeLimit 32 bit có dấu, thứ tự kiểm từng câu và thứ tự ghi chú, HEIC chỉ xét
  nhãn chính). Oracle thêm 16 file (dây hỏng từng kiểu, phần không tên, chữ cái > 0xFFFF, trùng chữ cùng quá 26 lựa chọn,
  thời gian âm và 64 bit, ảnh JPEG/WebP/HEIC và ảnh dùng chung, nhiều trường lạ) để lõi Kotlin có đủ căn cứ.
- 2026-10-31 (re-review O1): đáp án ghi từng phần tử kiểm kiểu dây trước khi đếm; hợp đồng ghi thời điểm đếm từng loại
  phần tử; danh sách chữ đáp án lệch giữ 20 chữ đầu như đường dẫn trường lạ (`OEFLimits.listedItems`, tối thiểu 1; câu
  báo không thành chuỗi nhiều MB khi lưu làm lý do của Thư viện ở O2); gói đọc dễ giữ nguyên TimeLimit của file; fixture
  `nhieu-dap-an-lech`.
- 2026-10-31 (O3): nhánh `feature/oef-o3` xếp chồng một tầng trên O1 (review-and-merge.md cho phép một tầng) thay vì
  rẽ từ `main` sau khi O1 merge như plan-oef.md Phần 5: O1 chờ cổng GO1; kết quả như nhau sau khi O1 merge bằng merge
  commit (PR O3 đổi base sang `main`).
- 2026-10-31 (O3, chi tiết cài đặt): lõi Kotlin chỉ có đọc nghiêm (Android không có bản Admin hay bước phân loại Đề có
  lỗi), so phần đọc nghiêm của oracle; ghi ở exam-format.md. File đọc qua ánh xạ bộ nhớ (`FileChannel.map`), ảnh là vùng
  byte của file và được ghi thẳng vào gói, nên `.oef` gần 1 GiB không nạp vào heap của điện thoại. Nhận diện theo nội
  dung: plan-oef.md Phần 3 bước 1 nói `PK 03 04` là gói; thêm `PK 05 06` (zip rỗng) vào gói để zip rỗng không báo
  "`.oef` bản cũ"; "đòi đủ cấu trúc" của Phần 7 thành byte đầu `0A` (khoá của Properties): bốn file Protobuf mẫu của OES
  đều mở đầu bằng `0A`, bốn file bản cũ bằng `00`. File khác (file chữ WIMS, file rỗng) báo "không phải file đề"
  (`ImportProblem.NotAnExamFile`) thay vì "không đọc được dạng zip". Đề chuyển rồi còn phải vừa trần của gói (`exam.json`
  32 MiB, 20.000 entry): chỉ khác bản macOS ở đề gần trần; ghi ở exam-format.md.
- 2026-10-31 (review độc lập O3): không chặn. Người review tự sinh 60.000 đầu vào (protobuf ngẫu nhiên có cấu trúc và
  đột biến của 32 fixture) và chạy cả hai bộ đọc: Swift và Kotlin không lệch nhau ở mã lỗi, vị trí, đường dẫn trường
  lạ, đề đã chuyển; 326 đề đọc được ghi gói rồi đọc nghiêm lại đúng. Đã sửa: CHANGELOG và install-android.md nói rõ
  `.oef` của Open Exam Suite 1, 2 (zip) báo lỗi của gói, không phải "bản cũ" (đổi bằng cách xét tên file khi có là đổi
  hợp đồng, để Nt0 quyết); test `.oef` đổi xong vượt trần gói (`ExamLibraryTest`); oracle đọc nghiêm `.oef` chạy cả trên
  ART (`PlatformTest`: giải mã UTF-8, NFC của ART khác JDK); plan-oef.md dẫn sang luật nhận diện đã chốt; nit tài liệu.
  Danh sách đường dẫn, chữ đáp án trong câu báo của Android rút gọn còn 5 mục như các câu khác của bản Android (macOS
  hiện tới 20).
- 2026-10-31 (O2, Nt0): Thư viện bản Admin nhận `.oef` như plan (đọc dễ), nhưng **Sửa tắt** với đề `.oef`, chú thích
  "Đề .oef không sửa trực tiếp được. Dùng Import đề… để chuyển sang .exam rồi sửa." (QO10 không cho mở `.oef` vào cửa sổ
  soạn đề; hai phương án khác: Sửa mở Import đề… với file đó, hay Thư viện Admin không nhận `.oef`).
- 2026-10-31 (O2, chi tiết cài đặt): đoạn `.oef` của XCUITest iOS ở luồng 3 thay vì luồng 2 như plan-oef.md Phần 5:
  file thay hộp chọn file (`-ExamSuiteUITestChosenFile`) là một đường dẫn cho cả lần mở app, luồng 2 đã dùng nó cho
  `.exam`; luồng 3 chưa dùng nên truyền `.oef` ngay lần mở đầu, không thêm lần mở app. Thông tin của macOS thay dòng
  "Phiên bản định dạng" bằng "Định dạng: Open Exam Suite (.oef)" (đề `.oef` luôn ra phiên bản 1, không có nghĩa); iOS
  chưa có màn Thông tin.
- 2026-10-31 (review độc lập O2): không chặn; mọi đường đọc và nhận file của bản Học viên (Thêm đề, kéo thả, Finder,
  `onOpenURL`, `Received/`, Tìm file…, Làm mới, Trước khi thi, làm bài, Kết quả, Xem lại, PDF) đi qua `ExamSourceReader`.
  Đã sửa: chữ gợi ý (lớp phủ kéo thả, banner chào, Thư viện trống ở macOS và iOS) nhắc cả `.oef`; bản Admin, đề `.oef`
  có lỗi: bước Sửa thành dòng chữ chỉ sang Import đề… (chú thích của nút tắt có thể không hiện); `uitest_plan.py` map
  `fixtures/oef/co-ban.oef` sang `PhoneLeaveAppUITests`; câu của CHANGELOG-ios; test kiểm hạng của document type `.oef`;
  comment. Để GO2: chú thích Sửa ở bản Admin; máy có Open Exam Suite (nếu app khác khai báo export UTI cho `.oef`,
  LaunchServices có thể ưu tiên UTI đó: hộp chọn file của Thư viện làm mờ `.oef`, Open With không có Exam Suite;
  Import đề… không bị vì tra theo đuôi).
- 2026-10-31: `fixtures/oef/**` và `scripts/make_oef.py` để mức `full` của `verify_scope.py` (mặc định với đường dẫn chưa
  có trong bảng): test của ExamFeatures (`OEFImportTests`, `ImportFlowModelTests`) đọc `fixtures/oef/`.
- 2026-11-01 (GO1, GO2, Nt0): đạt hết theo thiết kế. Bản Admin, **Mở để sửa…** làm mờ file `.oef` trong hộp mở: đúng
  QO10, giữ nguyên (không đổi sang mở luồng Import đề…); CHANGELOG và `docs/install.md` ghi đường Import đề…. Máy Mac
  không chạy được Open Exam Suite (app Windows), nên "sửa một câu trong OES" thử bằng bản sao của file mẫu GMAT sửa chữ
  câu 1 bằng script (mã, tiêu đề giữ nguyên); mục "máy có cài Open Exam Suite" của macOS không thử được.
- 2026-11-01 (QO13, Nt0): iOS chưa phát hành 0.1.0 khi O2 merge, nên bản iOS đầu tiên **0.1.0** đã có `.oef` (thay "ở
  bản kế sau 0.1.0"); macOS 0.2.0, Android 0.2.0 như QO13.
- 2026-11-01 (phát hành, Nt0): bước "Tag must match MARKETING_VERSION" của job `release-dmg` gom mọi `MARKETING_VERSION`
  trong `project.yml`, kể cả của target iOS (0.1.0, I3), nên mọi tag `v*` sẽ dừng ở bước đầu. Nt0 chọn sửa `ci.yml`: chỉ
  so hai target macOS (`ExamSuite`, `ExamSuiteAdmin`), thiếu một trong hai thì dừng; iOS giữ đánh số riêng. Thử tại máy
  bằng chính đoạn script của bước (v0.2.0, v0.2.0-beta1 đạt; v0.1.0, v0.1.1, Admin lệch số, Admin thiếu khai báo dừng;
  bước cũ dừng với v0.2.0). Tag ba bản do Nt0 đẩy.
- 2026-11-01 (phát hành, phát hiện): `scripts/make_dmg.sh` tại máy của Nt0 dừng ở bước quét chuỗi cấm, vì một mẫu cục bộ
  (`~/.config/exam-suite/leak-patterns`, không lưu trong repo) khớp thư mục nhà, mà binary build tại máy nào cũng chứa
  đường dẫn tuyệt đối của file nguồn (kể cả của ZIPFoundation): không do thay đổi của plan này. DMG phát hành do runner
  CI đóng (chỉ `/Users/runner/`). DMG để Nt0 thử GO2 đóng với `EXAMSUITE_LEAK_PATTERNS_FILE=/dev/null` (mẫu chung vẫn
  quét), không phát hành. Sửa mẫu cục bộ hay không: Nt0 quyết.

## Validation

- O1, 2026-10-31: `scripts/check.sh` đạt trước review và trên trạng thái cuối sau re-review (một lượt giữa chừng đỏ ở
  `OEFImportTests` vì fixture `truong-la` thêm trường lạ ở lựa chọn; đã sửa test); `make_oef.py --check` 32 file; `Timing`
  `oef.read` 1,11 s Debug (giới hạn 6 s); catalog ổn định qua `-exportLocalizations` ba scheme. Thử tại máy trên file mẫu
  công khai của OES (Decisions). Review độc lập: 1 chặn, 4 nên sửa, nit; đã sửa. Re-review: không chặn, 2 nên sửa, 2 nit; đã sửa (Decisions). `verify_local.sh --uitest`
  (`--no-autosave-check`) xanh trên `d332ce2` sau khi Nt0 cập nhật CoreSimulator: mức full, UI test đủ bộ (Học viên 6,
  Admin 4, iOS 3), kho thật không đổi, Linux đạt; check `android` của CI xanh.
- O3, 2026-10-31: trên `922fed5` check `android` của CI xanh (lint, test, so ảnh; `SharedOracleTest` đọc
  `fixtures/oef/`), `local/verify-android` xanh (6 test Compose trên emulator, kể cả đoạn mở `.oef` của
  `ExamIntentFlowTest`; `PlatformTest` chạy oracle đọc nghiêm trên ART), `local/verify` mức none. Review độc lập không
  chặn (Decisions).
- O2, 2026-11-01: `scripts/check.sh` đạt trên `bdd209c`; sau sửa theo review, `swift test` có chọn lọc (`OEFLibraryTests`,
  `AppLaunchStorageTests`, `LibraryModelTests`, snapshot Thư viện, `TiledWindowLayoutTests`) đạt và catalog đứng yên qua
  `-exportLocalizations` ba scheme. `verify_local.sh --uitest --no-autosave-check` xanh trên `19c2dab`: mức full, UI test
  đủ bộ (Học viên 6, Admin 4, iOS 3, kể cả luồng 3 thêm đề `.oef`), kho thật không đổi, Linux đạt.
- GO1, GO2 (Nt0, 2026-11-01; macOS từ DMG đóng tại máy trên `main` `8cf506b`, iOS cài qua Xcode, Android bản có O3):
  đạt. Bộ file thử ngoài git: hai file mẫu Protobuf công khai của OES (GMAT 20 câu, Basic Science 8 câu), một file bản cũ
  của OES, bản GMAT sửa chữ câu 1 (Decisions), fixture tự dựng của `fixtures/oef/` (ảnh, nhiều đáp án, ẩn đáp án, có lỗi)
  và một cặp đúng/lỗi cùng tiêu đề để thấy Đề có lỗi. Đã thử: Import đề… (số câu, phần, đáp án, ngưỡng, thời gian; file bản
  cũ, file có lỗi) rồi mở `.exam` bằng bản Học viên; nhấp đúp và Mở bằng trong Finder; kéo thả; Thông tin; Thi; sửa câu
  rồi Xem lại báo câu đã sửa; thêm `.exam` do Admin chuyển (Dùng file mới / Cập nhật đề, lịch sử nối tiếp); Đề có lỗi;
  Sửa tắt ở bản Admin; iPhone nhận `.oef` qua Zalo và app Tệp; Android qua Zalo hoặc Drive.

## Result

`.oef` (bản Protobuf của Open Exam Suite 4 trở lên) mở được ở cả ba bản Học viên, bản Admin chuyển sang `.exam` qua
Import đề…; một hợp đồng (exam-format.md, mục File `.oef`), một oracle (`fixtures/oef/`), hai bộ đọc Swift và Kotlin cùng
kết luận. Phát hành cùng PR đóng plan: macOS 0.2.0, Android 0.2.0, iOS 0.1.0.

Các bước sau khi PR phát hành merge (bằng chứng nằm ở commit status và tag của SHA phát hành, không ghi lại vào plan):

1. Trên SHA `main` sau merge: `scripts/verify_local.sh --clean --uitest` (cổng macOS và iOS), `android/scripts/check_android.sh
   --ui` (cổng Android).
2. Nt0 đóng APK release ký (`docs/process/android-release.md` bước 2), cài đè lên điện thoại.
3. Nt0 đẩy ba tag trên SHA đó: `v0.2.0` (job `release-dmg` đóng hai DMG và tạo GitHub Release), `android-v0.2.0` (rồi tạo
   GitHub Release Pre-release kèm APK và ba file giấy phép, android-release.md bước 4), `ios-v0.1.0` (không có bản cài,
   cài từ mã nguồn qua Xcode).
