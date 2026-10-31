# Execution Plan: mở file `.oef` của Open Exam Suite (macOS, iOS, Android)

Date: 2026-10-31

## Status

Active. O1 trên nhánh `feature/oef-o1`.

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

- [ ] O1 Hợp đồng, oracle, bộ đọc Swift, Import đề… (rủi ro cao). Cổng GO1. Đã làm: ADR 0014; exam-format.md mục File
      `.oef`; import.md mục `.oef`; ghi chú ở ADR 0002, 0003; `ProtobufWire`, `OEFReader`, `OEFProblem`/`OEFNote`/
      `OEFLimits`, `ExamSourceReader`, `ExamFileError.oef` (ExamFile); `scripts/make_oef.py` + 15 fixture
      `fixtures/oef/` + `expected.json` viết tay; `OEFReaderTests` (oracle, vector), `OEFRobustnessTests` (cắt cụt,
      đột biến có seed, giới hạn); câu báo `ErrorMessages` (InterfaceCore) và lớp phân loại của `ExamFileInspector`; Admin:
      `ImportSourceFormat.oef`, `OEFImporter`, mã và chi tiết mục báo cáo mới, `ImportError.unreadableOEF`,
      `AuthoringMessages`, `OEFImportTests`, ca `.oef` thật trong `ImportFlowModelTests`; catalog vi/en; ngân sách
      `oef.read` + test `Timing` (`OEFEncoding` chỉ cho test trong LargeExamSupport); vòng nén `SHA256`.
- [ ] O2 Bản Học viên macOS và iOS (rủi ro cao). Sau I3 của iOS.
- [ ] O3 Android (rủi ro cao). Song song O2.

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
- 2026-10-31: `fixtures/oef/**` và `scripts/make_oef.py` để mức `full` của `verify_scope.py` (mặc định với đường dẫn chưa
  có trong bảng): test của ExamFeatures (`OEFImportTests`, `ImportFlowModelTests`) đọc `fixtures/oef/`.

## Validation

- O1, 2026-10-31: `scripts/check.sh` đạt trước review và trên trạng thái cuối sau re-review (một lượt giữa chừng đỏ ở
  `OEFImportTests` vì fixture `truong-la` thêm trường lạ ở lựa chọn; đã sửa test); `make_oef.py --check` 32 file; `Timing`
  `oef.read` 1,11 s Debug (giới hạn 6 s); catalog ổn định qua `-exportLocalizations` ba scheme. Thử tại máy trên file mẫu
  công khai của OES (Decisions). Review độc lập: 1 chặn, 4 nên sửa, nit; đã sửa. Re-review: không chặn, 2 nên sửa, 2 nit; đã sửa (Decisions). `verify_local.sh --uitest`:
  chờ (CoreSimulator của máy cũ hơn Xcode, `simctl` treo; cần Nt0 cài thành phần bổ sung của Xcode).
