# Changelog

Theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), phiên bản theo semver.

## [Unreleased]

## [0.1.1] – bản public đầu tiên

Bản đầu tiên của Exam Suite ở dạng mã nguồn mở, giấy phép Apache-2.0. Cách làm bài, soạn đề và định dạng đề không đổi so
với 0.1.0. Hai DMG trên GitHub Release `v0.1.1`: `ExamSuite-0.1.1.dmg` (bản Học viên) và `ExamSuiteAdmin-0.1.1.dmg` (bản
Admin, thêm Soạn đề và Import đề). Mac Apple silicon, macOS 15 trở lên (mới test tay trên macOS 26); app ký ad-hoc nên lần
mở đầu phải bấm Vẫn mở/Open Anyway (`docs/install.md`, bản sao trong mỗi DMG).

### Added

- Giấy phép Apache-2.0 ("Copyright 2026 Nt0"): `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` (giấy phép MIT của
  ZIPFoundation, thư viện đi kèm hai app). Mỗi DMG có thêm `LICENSE.txt`, `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt`; app đã
  cài cũng mang ba file đó trong `Contents/Resources`.
- Hộp **Giới thiệu về Exam Suite** (About) của hai bản ghi giấy phép Apache-2.0, © 2026 Nt0 và ZIPFoundation (MIT), tiếng
  Việt hoặc tiếng Anh theo ngôn ngữ của app.

### Changed

- Hướng dẫn cài đặt (`docs/install.md`): tải DMG ở trang Releases; bỏ phần chỉ dành cho máy từng cài bản beta riêng.
- Số build bắt đầu từ 1001 (1000 + số commit), cao hơn mọi bản beta riêng trước đó.

## [0.1.0] – beta riêng

Bản beta riêng đầu tiên, qua cổng G3 ngày 2026-10-19; ngày phát hành là ngày của tag `v0.1.0` (GitHub Release): hai DMG
(`ExamSuite-0.1.0.dmg` bản Học viên, `ExamSuiteAdmin-0.1.0.dmg` bản Admin), Apple silicon, macOS 15 trở lên, ký ad-hoc
(lần mở đầu phải Vẫn mở/Open Anyway); cài theo `docs/install.md` (bản sao trong mỗi DMG). Số build tăng theo mỗi lần
đóng DMG (số commit). Nt0 test tay bản beta build 349 trên macOS 26 (cài từ DMG và chuyển dữ liệu, Import và soạn đề,
nền đọc và Dark Mode, làm bài thật, in, VoiceOver, thi thử): không có lỗi. Chưa kiểm trên macOS 15 (không có máy; rủi ro
đã chấp nhận).

Điểm chính của giai đoạn 6:

- **DMG và hướng dẫn cài đặt** cho hai bản, biểu tượng tạm (#58).
- **Nền đọc** cho vùng câu hỏi: năm nền, chọn ở menu Xem › Nền đọc hoặc Trước khi thi (#58).
- **Dự án cá nhân của Nt0**: bundle ID `vn.io.nt0.*`, kiểu file `vn.io.nt0.exam`, "© 2026 Nt0"; dữ liệu bản cũ chép tay
  theo hướng dẫn của bản beta riêng (#59).
- **Sửa hộp xác nhận Import đề** mất bốn ô nhập (lỗi của bản beta build 342); bốn ô nay có viền (#60).

### Added

- Giai đoạn 6, beta riêng:
  - **Nền đọc** cho vùng câu hỏi khi làm bài, Xem lại bài và xem trước của Soạn đề: Theo hệ thống (mặc định), Trắng,
    Giấy ngà, Xám dịu, Tối. Chọn ở menu Xem › Nền đọc (View › Reading Background), đổi được khi đang làm bài, hoặc ở
    Trước khi thi; một lựa chọn cho cả app, giữ nguyên khi macOS đổi sáng/tối. Bảng câu hỏi, thanh công cụ, thanh dưới
    giữ giao diện macOS; PDF và bản in luôn sáng. Mỗi nền có bộ màu riêng đạt tương phản (chữ 4,5:1, biểu tượng 3:1).
  - Đóng gói: `scripts/make_dmg.sh` (build Release, kiểm ranh giới hai bản và code UI test trên đúng app đem đóng, ký
    ad-hoc, `hdiutil verify`, kiểm chữ ký app trong DMG); biểu tượng tạm cho hai bản (`scripts/make_icons.swift`, teal và
    burgundy); hướng dẫn cài đặt tiếng Việt `docs/install.md`; CI khi gắn tag `v*` đóng hai DMG và tạo GitHub Release.

- Khung repo: Swift Package `ExamKit` (ExamKit + ExamFile), `ExamFeatures`,
  hai target app khai báo trong `project.yml`, JSON Schema v1 cho `exam.json`,
  đề mẫu, script kiểm tra, CI, harness cho AI agent.
- Lõi giai đoạn 1 (ExamKit): model đề thi, ExamValidator, chấm điểm (thang 1000 và %,
  theo section), chọn câu có seed (SplitMix64, tái lập trên mọi nền tảng), phiên thi
  (state machine, đồng hồ đơn điệu, cảnh báo 5/1 phút, hết giờ → rà soát khoá).
- ExamFile: đọc/ghi gói `.exam` với chế độ nghiêm (bản Học viên) và dễ (bản Admin),
  giới hạn kích thước và độ sâu, SHA-256 đặt tên ảnh, khung chuyển phiên bản.
- Bản Admin mở `.exam` từ Finder, hiện lỗi/cảnh báo và cho biết bản Học viên có mở được đề không.
- `scripts/validate_exam.py` cùng kết luận với app; kiểm bằng `fixtures/expected-verdicts.json`.
- CI có `timeout-minutes`.
- Giai đoạn 2, Thư viện: module `LibraryData` (kho SwiftData riêng mỗi bản app, `VersionedSchema` v1, cứu kho hỏng,
  bookmark, đọc nền có giới hạn và thời hạn, nhập đề và trạng thái file theo chế độ nghiêm/dễ, lần thi, đề mẫu);
  `LibraryFeature` (cửa sổ Thư viện, lưới/danh sách, tìm/lọc/sắp xếp, Thông tin, Thêm đề, kéo thả, Xoá + Hoàn tác,
  Lịch sử thi, trợ năng, màu đạt tương phản); bản Học viên mở `.exam` từ Finder; bản Admin có Sửa (⌘E) và
  "Mở để sửa…" (⇧⌘O); hai đề mẫu "Làm quen với Exam Suite" và "An toàn thông tin cơ bản".
- CI job macOS chạy `swift test` cho ExamFeatures.
- Giai đoạn 3, Làm bài: lưu lần thi (`AttemptRecord` có `payloadVersion`, dấu vân tay từng câu); `SessionFeature`:
  Trước khi thi, cửa sổ làm bài (bảng câu hỏi, đồng hồ ba mức, cảnh báo 5/1 phút, tạm dừng che câu hỏi, Kiểm tra đáp án),
  Rà soát & nộp, Kết quả (so với lần trước, phần yếu nhất), Xem lại bài (bộ lọc, đề ẩn đáp án, câu đã sửa sau lần thi),
  Làm lại, Luyện lại câu sai, mở lần thi cũ từ Lịch sử thi; menu Bài thi (⌘D, ⌘., ⌘K, ⌘Return, ⌃⌘I); hỏi khi đóng
  cửa sổ hoặc thoát lúc chưa nộp; tự tạm dừng khi máy ngủ; đề mẫu "Làm quen" theo phím và nhãn mới.
- XCUITest bản Học viên (luồng bàn phím 1–3, đóng cửa sổ khi chưa nộp) với chế độ cô lập chỉ ở build Debug
  (kho, đề mẫu, cài đặt trong thư mục tạm; bundle ID `.uitest`; đồng hồ nhanh).
- `scripts/verify_local.sh` (`--clean`, `--uitest`): bằng chứng merge chạy trên Mac, ghi commit status `local/verify`.
- Giai đoạn 4, Soạn đề và import (bản Admin): `AuthoringData` (sửa đề không giao diện, mỗi thao tác có thao tác ngược,
  không đổi tên ảnh cũ); cửa sổ soạn đề ba cột (cây đề có tìm và kéo thả, trình soạn đề/phần/câu/lựa chọn, ảnh, xem trước
  Luyện tập/Thi, thanh lỗi bấm để nhảy, không chặn lưu); lưu, tự lưu, Versions và hỏi khi đóng theo macOS; Đề mới (⌘N),
  Thử đề này (⌘R: lưu, đọc nghiêm, thêm vào Thư viện, mở Trước khi thi); Import đề… từ `.txt`, `.docx`, `.vce`
  (`ExamImport`: hộp xác nhận điền sẵn, báo cáo câu bỏ/cảnh báo kèm vị trí, chỉ tự sửa mojibake an toàn); chế độ cô lập
  và XCUITest cho bản Admin (luồng 4, 5, import).
- Giai đoạn 5, Báo cáo và hoàn thiện (đóng 2026-10-18, không có cổng; G3 ở giai đoạn 6):
  - PDF và In **kết quả** ở hai bản (`ReportFeature`: trang A4, Helvetica Neue + SF Mono, chân trang mọi trang): Xuất
    PDF… và In… (⌘P) ở Kết quả và Xem lại bài, hộp chọn mức xem lại (nhớ lần trước), hộp Lưu của macOS, ghi file tạm rồi
    thay, sheet tiến độ có Huỷ, hộp báo lỗi có lý do; đề `hideAnswers` không lộ đáp án, câu đã sửa sau lần thi không
    đánh dấu lựa chọn.
  - PDF và In **đề** (bản Admin, menu Tệp của cửa sổ soạn đề): Chỉ đề hoặc Có đáp án và giải thích, luôn chọn sẵn Chỉ
    đề; dòng nhắc khi đề còn lỗi hay `hideAnswers`.
  - Giao diện **tiếng Anh**: String Catalog cho mọi chữ giao diện (tiếng Việt là nguồn, bản `en` đủ, plural), tên kiểu
    tài liệu theo ngôn ngữ; số, phần trăm, ngày giờ theo ngôn ngữ giao diện (không theo Region); thông báo lỗi của lõi
    dịch theo mã ở tầng giao diện; tên mặc định ghi vào đề ("Đề mới"/"New Exam") theo ngôn ngữ lúc tạo.
  - **Trợ năng**: VoiceOver theo bảng mục tiêu (câu đọc của Kết quả, Xem lại bài, Lịch sử thi, cây đề; đề mục; thông báo
    khi Import xong, lưu xong), tương phản đạt cho mọi bảng màu sáng/tối, Reduce Transparency, Reduce Motion, cỡ chữ nội
    dung ⌘+ / ⌘− / ⌘0 (menu Xem, 100–150%).
  - Đề chuẩn 2.000 câu có ảnh và test thời gian với giới hạn chặn (`scripts/gen_large_exam.py`, `LargeExamSupport`,
    `scripts/measure_large.sh`); ngân sách cỡ file PDF.
  - Kiểm tự động mới: snapshot test sáng/tối 960×640 (swift-snapshot-testing chỉ ở test, ADR 0010); kiểm trợ năng tự
    động (`performAccessibilityAudit`) ở mọi màn của UI test; `scripts/check_localization.py` (`--require-en`,
    `--freshness`, `--built-apps`), `scripts/check_quit_sheets.py`, `scripts/check_colors.py`, `scripts/uitest_plan.py`.

### Changed

- Exam Suite là dự án cá nhân của Nt0: bundle ID `vn.io.nt0.examsuite` (bản Học viên) và `vn.io.nt0.examsuite.admin`
  (bản Admin), kiểu file `.exam` là `vn.io.nt0.exam`, bản quyền "© 2026 Nt0", `$id` của schema trên GitHub. Định dạng
  đề không đổi, file `.exam` có từ trước vẫn mở được. Thư viện, lịch sử thi và cài đặt của bản cài trước (bundle ID cũ)
  không tự chuyển sang: chép tay theo mục "Chuyển dữ liệu từ bản cũ" của hướng dẫn bản beta riêng (bỏ từ 0.1.1).
- CI GitHub Actions không còn tự chạy trên PR và push `main` (tiết kiệm phút Actions): chạy tay chỉ hai job kiểm (Linux,
  macOS); gắn tag `v*` chỉ chạy job đóng hai DMG và tạo GitHub Release, chỉ với tag đã có (`--verify-tag`).
- Đóng gói và kiểm: `scripts/make_dmg.sh` thất bại khi không tháo được ổ DMG (kể cả `-force`) thay vì báo xong;
  `scripts/verify_local.sh` xoá app Debug/Release mang bundle ID thật ngay sau khi kiểm xong (cả khi lỗi), như
  `make_dmg.sh`.
- Giai đoạn 5: Thư viện dạng danh sách đặt cột Trạng thái ngay sau Tên đề; màu xanh của giao diện sáng và đỏ của giao
  diện tối đậm/sáng hơn cho đủ tương phản; PDF không dùng chữ ghép (tìm và chép "official" đúng); Soạn đề dựng chỉ mục
  tìm của cây đề ở nền khi mở cửa sổ (lần gõ đầu vào ô tìm với đề 2.000 câu từ ~43 ms xuống ~0,2 ms, Release).
- Quy trình: `scripts/verify_local.sh --uitest` chỉ chạy các lớp UI test bị ảnh hưởng theo file đổi (đủ bộ khi chạm hạ
  tầng chung, module dùng chung và ở cổng), hai target UI test build chung một lần; UI test gộp các test chung đoạn mở
  đầu (Học viên 10 → 6 lần mở app, Admin 6 → 4) và đồng hồ nhanh của luồng 2, 3 từ 5× lên 10×.

### Fixed

- Bản Admin, lỗi của bản beta (build 342): hộp xác nhận của Import đề… không hiện bốn ô Tiêu đề, Mã đề, Ngưỡng đậu (%),
  Thời gian Thi (phút) và cắt dòng ghi chú, nên không điền được ngưỡng đậu, thời gian và nút Import luôn khoá. Cửa sổ Import
  đề nay cao vừa đủ nội dung, kể cả khi mọi ô báo lỗi và ở giao diện tiếng Anh; bốn ô có viền (ô trống thấy rõ chỗ nhập),
  chữ canh trái.
- Thư viện trống (thanh bên và danh sách lệch khỏi cửa sổ) khi macOS 26 khôi phục khung cửa sổ xếp lát.
- Bố cục: viền ảnh câu hỏi bao đúng ảnh; tiêu đề phần quanh "Câu 1/40" và nhãn "Đáp án đúng" ở xem trước Soạn đề; dải
  thông báo và lý do ở thanh nút Kết quả không còn đẩy nội dung ra ngoài cửa sổ hẹp.
- Thoát app (⌘Q, Dock, đăng xuất) khi đang mở Trước khi thi hoặc một sheet khác không còn treo app; sheet mới phải
  khai báo cách đóng khi thoát (`scripts/check_quit_sheets.py`).
- Bản Admin: crash sau khi bấm Import/Huỷ trong hộp xác nhận import; cột cây đề bị cắt và danh sách lỗi/báo cáo import
  phủ lên trình soạn ở cửa sổ soạn đề.
