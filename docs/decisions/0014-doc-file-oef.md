# 0014 Đọc file `.oef` của Open Exam Suite (chỉ đọc, cả ba bản Học viên và bản Admin)

Date: 2026-10-31

## Status

Accepted (Nt0 chốt QO1–QO14 của docs/product/plan-oef.md ngày 2026-10-31, "như đề xuất"; QO14 đổi: file thử là file mẫu
công khai tải về, không phải file Nt0 tự tạo)

## Context

ADR 0002 chọn gói `.exam` và ghi "Không đọc/ghi `.oef` ở v1" vì dự án chưa có file `.oef` cần chuyển. Nt0 muốn học viên
trên macOS, iOS và Android mở thẳng file `.oef` do Open Exam Suite (OES, GPLv3) soạn, không cần người có bản Admin chuyển
giúp; bản Admin thì import `.oef` để sửa.

`.oef` bản hiện tại của OES là dây Protobuf (protobuf-net) của một mô hình phẳng: thuộc tính đề, phần, câu, lựa chọn; ảnh
nằm nguyên trong câu; không có id. Hai thế hệ cũ (zip + XML; BinaryFormatter của .NET) không được OES ghi nữa, và OES hiện
tại đọc được chúng rồi lưu lại thành Protobuf. Mô hình đọc từ mã nguồn công khai của OES qua link (docs/product/plan-oef.md
Phần 1); spike trên file mẫu công khai của repo OES xác nhận cách mã hoá (trường mặc định không ghi, `char` là varint mã
UTF-16, `double` dạng fixed64).

## Decision

- **Chỉ đọc** `.oef` bản Protobuf; không ghi, không xuất sang OES. Bản cũ (zip, BinaryFormatter) nhận ra và báo "mở bằng
  Open Exam Suite rồi lưu lại" (QO1).
- **Một hợp đồng chuyển đổi** `.oef` → đề ở docs/product/exam-format.md (mục File `.oef`): ánh xạ trường, chuẩn hoá chuỗi,
  thoát Markdown (QO7), ngưỡng đậu (QO4), loại ảnh (QO8), trường lạ (QO6), luật đọc nghiêm/đọc dễ (QO5), **id dẫn xuất**
  UUID phiên bản 8 từ SHA-256: đề từ mã + tiêu đề, phần và câu theo vị trí trong file (QO2, QO3).
- **Hai bộ cài đặt, một oracle**: Swift `OEFReader` trong `ExamFile` (chỉ Foundation, ADR 0008; dùng chung hai bản macOS
  và bản iOS); Kotlin trong `android/core` (bước O3). Oracle chung `fixtures/oef/` (file sinh bằng `scripts/make_oef.py`,
  kết luận viết tay ở `expected.json`); đổi luật thì sửa hợp đồng và oracle trước.
- **Không thêm thư viện** (ADR 0006, 0012): bộ giải mã dây Protobuf tự viết, có kiểm biên và giới hạn như gói `.exam`.
- **Ranh giới hai bản app không đổi** (ADR 0003): bộ đọc ở `ExamFile` (lõi dùng chung) vì bản Học viên cần nó; bản Admin
  import qua `ExamImport` gọi đúng bộ đọc đó ở chế độ dễ, với id dẫn xuất thay id ngẫu nhiên của import (QO10), nên `.exam`
  lưu ra từ một `.oef` có cùng id và lịch sử thi nối tiếp. Bản Admin không mở `.oef` từ Finder.
- Bản Học viên macOS và iOS tham chiếu `.oef` tại chỗ như `.exam` (library.md không đổi; QO9), UTType nhập
  `vn.io.nt0.examsuite.oef` hạng Alternate (QO11); Android chuyển `.oef` thành gói `.exam` lúc thêm (mobile.md đã chép
  file vào app).
- Thứ tự: O1 (hợp đồng, oracle, bộ đọc Swift, Import đề… của Admin) → O2 (bản Học viên macOS và iOS, sau I3 của iOS) ∥ O3
  (Android) (QO12); phát hành macOS 0.2.0, Android 0.2.0 (QO13).

## Alternatives Considered

1. Chỉ bản Admin import `.oef` (phương án A của plan-oef.md): rẻ hơn, không cần id ổn định, nhưng học viên phải chờ người
   có bản Admin chuyển giúp.
2. Dùng thư viện Protobuf (swift-protobuf, protobuf của Google cho Kotlin): phải có ADR thư viện ở cả hai nền tảng, thêm
   công cụ sinh mã, trong khi dây của `.oef` chỉ cần bốn kiểu.
3. Id từ toàn bộ nội dung file: mỗi lần sửa đề trong OES thành đề mới, mục cũ trên macOS/iOS hiện Không tìm thấy file.
4. Đọc cả bản BinaryFormatter (NRBF): đặc tả công khai nhưng bộ đọc lớn và khó review gấp nhiều lần; OES chuyển được.

## Consequences

Positive:

- Học viên mở thẳng đề soạn bằng OES trên cả ba nền tảng; bản Admin import để sửa, `.exam` lưu ra thay được `.oef`.
- Sau bước chuyển, đề là `ExamPackage` bình thường: chấm điểm, lịch sử, Xem lại, PDF không đổi.

Tradeoffs:

- Hai đề khác nhau cùng mã và tiêu đề bị coi là một đề (hộp Dùng file mới / Cập nhật đề hiện ra).
- Đổi thứ tự câu trong OES làm câu đổi id: Xem lại lần thi cũ báo câu đã sửa (dấu vân tay chặn đánh dấu sai).
- OES có thể đổi định dạng mà không có số phiên bản: bản Học viên từ chối trường lạ với câu báo rõ, bản Admin bỏ qua kèm
  cảnh báo.
- Đuôi `.oef` trùng với file bài tập dạng chữ của WIMS: đọc ra "dữ liệu hỏng… hoặc không phải đề của Open Exam Suite".
- Đặt tên ảnh phải băm SHA-256 mọi ảnh mỗi lần đọc; vòng nén của `SHA256` viết lại để bản Debug đọc đề chuẩn dạng `.oef`
  trong giới hạn của large-exams.md.
- Pháp lý: định dạng của dự án mã nguồn mở; code viết mới, không chép code hay file mẫu GPL (ADR 0001).

## Follow-Up

- O2: library.md (Thêm đề nhận `.oef`), mục "Bản iOS" của mobile.md, `project.yml` (UTType, document type).
- O3: lõi Kotlin đọc `fixtures/oef/` trong `SharedOracleTest`; mục Android của mobile.md.
