# 0009 Đọc trực tiếp file `.vce` khi import đề

Date: 2026-10-16

## Status

Accepted (Nt0 duyệt 2026-10-16 và chịu trách nhiệm về khía cạnh pháp lý. 2026-10-18: lời văn theo dự án cá nhân của
Nt0, nội dung quyết định không đổi. **Nt0 chốt 2026-10-20: giữ tính năng, rút gọn tài liệu khi công khai**: ADR này chỉ
giữ quyết định, phạm vi và rủi ro; mô tả định dạng chi tiết bỏ khỏi docs/notes/vce-format.md, chi tiết ở mã nguồn)

## Context

Nt0 yêu cầu bản Admin import đề từ `.txt`, `.docx` và `.vce`, và chọn **đọc `.vce` trực tiếp** thay vì yêu cầu người
dùng xuất sang Word trước (2026-10-16; docs/product/import.md).

`.vce` là định dạng nhị phân độc quyền của Avanset (VCE Designer/Player), không có đặc tả công khai. Đọc được nghĩa là
phải tự xác định cấu trúc file bằng phân tích file mẫu.

Rủi ro:

- **Pháp lý**: điều khoản giấy phép của phần mềm Avanset có thể cấm dịch ngược; luật ở một số nơi cấm vượt qua biện
  pháp bảo vệ kỹ thuật, có ngoại lệ cho mục đích tương thích (interoperability) tuỳ quốc gia. Đây không phải tư vấn
  pháp lý. Nội dung trong file `.vce` có thể thuộc bản quyền của bên thứ ba; người dùng chịu trách nhiệm với đề mình
  import.
- **Kỹ thuật**: định dạng có thể đổi theo phiên bản VCE; không có tài liệu nên khó biết đã đọc đúng hết; bộ đọc là code
  khó review.
- **Quy trình**: ADR 0001 tránh chép code GPL; không được chép code từ các công cụ chuyển đổi VCE khác (giấy phép không
  rõ hoặc GPL), chỉ được viết mới từ hiểu biết về định dạng.

## Decision

**Cho phép** bộ đọc `.vce` (giai đoạn 4) với các điều kiện:

1. Nt0 duyệt ADR này (và tự quyết việc hỏi tư vấn pháp lý) trước khi viết code đọc `.vce`.
2. Làm **spike** trước, có giới hạn thời gian, trên file mẫu tại máy. Spike không khả thi (chỉ đọc được bằng cách chép
   code hay khoá bí mật của bên thứ ba) thì **dừng và báo**, không lách; khi đó `.vce` chuyển sang hướng xuất qua docx.
   Kết quả spike: khả thi bằng phân tích file mẫu và đặc tả RVF công khai, không cần khoá bí mật hay code của bên thứ ba.
3. Viết mới (Foundation, không thêm thư viện; ADR 0006), trong module import chỉ bản Admin link (ADR 0003); không chép
   code của công cụ khác; ghi rõ trong code nguồn hiểu biết về định dạng.
4. File `.vce` thật không vào git; test dùng file tự tạo (`VceTestWriter`), file thật chỉ thử tại máy.
5. Thay đổi là **rủi ro cao** (đọc file đề): review độc lập như mọi PR đọc/ghi gói đề.

Phạm vi: một biến thể `.vce` (biến thể của các file mẫu), câu chỉ có văn bản; ảnh, loại câu khác và phiên bản khác bị bỏ
kèm báo cáo, không đoán (docs/product/import.md, mục `.vce`). File hỏng chỉ ra lỗi có mã, không crash hay treo.

Công cụ phân tích: spike được phép dùng công cụ phân tích tại máy nếu thật cần (hỏi Nt0 trước khi cài, không thêm vào
repo hay build); thực tế không dùng.

## Alternatives Considered

1. Không đọc `.vce`; người dùng xuất sang Word bằng VCE Designer hoặc công cụ chuyển đổi rồi import `.docx`
   (khuyến nghị ban đầu của agent: không rủi ro pháp lý, không phụ thuộc phiên bản VCE).
2. Hoãn `.vce` sang sau v1.

## Consequences

Positive:

- Admin import thẳng ngân hàng câu hỏi `.vce` sẵn có của người dùng, không cần phần mềm Avanset.

Tradeoffs:

- Rủi ro pháp lý ở trên do Nt0 chấp nhận; có thể phải gỡ tính năng nếu có yêu cầu.
- Có thể hỏng khi gặp phiên bản `.vce` khác; cần thông báo lỗi rõ và đường lui qua `.docx`.
- Thêm code khó review vào bản Admin.

## Follow-Up

- Spike và bộ đọc đã làm ở giai đoạn 4 (plan giai đoạn 4, bước 3 và 6); ghi chú ngắn ở docs/notes/vce-format.md.
