# Soạn đề (bản Admin)

Thẩm quyền: tài liệu này. Nguồn: mục "Thiết kế UX trên macOS" và "Kiến trúc kỹ thuật" của
[plan-macos-v1.md](plan-macos-v1.md); DESIGN_BRIEF §5.7, §6 (luồng 4, 5), §7 của Open Exam Suite (đọc qua link,
không chép). Định dạng và ràng buộc của đề: [exam-format.md](exam-format.md). Import từ file khác:
[import.md](import.md). Những chỗ đặc tả gốc không nói được ghi ở mục cuối.

Code: `AuthoringFeature` trong `Packages/ExamFeatures`, chỉ bản Admin link (ADR 0003). Bản Học viên không có màn
hình, menu hay code nào của phần này.

## Mở cửa sổ soạn đề

- **Đề mới** (⌘N, menu File; nút trên thanh công cụ Thư viện của bản Admin): cửa sổ soạn đề với đề trống chưa lưu.
- **Sửa** (⌘E) trên thẻ đề, **Mở để sửa…** (⇧⌘O), nhấp đúp file `.exam` trong Finder: mở file vào cửa sổ soạn đề
  (library.md, phương án 7 và 11).
- **Import đề…** (menu File): xem [import.md](import.md); tiến độ và hộp xác nhận ở cửa sổ riêng "Import đề" (đóng cửa
  sổ đó là Huỷ; phương án 14); kết quả là cửa sổ soạn đề chưa lưu.
- Mỗi file một cửa sổ (`DocumentGroup` + `ReferenceFileDocument`); mở lại file đang mở thì đưa cửa sổ đó lên trước.
- Đọc chế độ **dễ** (exam-format.md): đề có lỗi vẫn mở và sửa được.

Đề mới gồm: `id` mới, tiêu đề "Đề mới", ngưỡng đậu 70%, thời gian 60 phút, `hideAnswers` tắt, một phần "Phần 1"
chưa có câu (đề như vậy có lỗi "phần không có câu" cho tới khi thêm câu; vẫn lưu được).

## Cửa sổ

`NavigationSplitView` ba cột, màu nhấn burgundy (`#801638`, cách dùng cho chữ/biểu tượng theo phương án 8 của
library.md); tối thiểu 960×640.

- **Trái: cây đề**: dòng Đề (thuộc tính), các phần, câu trong từng phần. Mỗi câu: số thứ tự, dòng đầu nội dung,
  biểu tượng có ảnh / nhiều đáp án, dấu lỗi hoặc cảnh báo (biểu tượng + chữ, không chỉ màu). Ô tìm lọc theo nội dung
  câu. Nút **Thêm phần**, **Thêm câu**.
- **Giữa: trình soạn**: thuộc tính đề, thuộc tính phần, hoặc câu, theo dòng đang chọn trên cây.
- **Phải: xem trước** (`.inspector`, ẩn/hiện được): câu đang chọn hiển thị như cửa sổ làm bài (Markdown, ảnh, lựa
  chọn theo thứ tự file), có công tắc kiểu Luyện tập / Thi; cập nhật ngay khi gõ. Chỉ đọc. **Luyện tập** hiện như sau
  Kiểm tra đáp án (đánh dấu đáp án đúng, hiện giải thích); **Thi** chỉ hiện câu hỏi và lựa chọn. Đề `hideAnswers` vẫn
  xem trước được kiểu Luyện tập (chỉ admin thấy xem trước) (phương án 9).
- **Đáy cột giữa: thanh lỗi**: số lỗi và cảnh báo; mở ra danh sách, bấm một dòng thì chọn đúng đề/phần/câu và trường
  đó. Dòng "Bản Học viên sẽ từ chối đề này" khi đề đọc nghiêm thất bại (như hiện nay). Thanh lỗi nằm ở đáy cột trình
  soạn, không trải dưới cây đề và xem trước (phương án 10).
- Thanh tiêu đề: tên file và trạng thái lưu của macOS ("Đã sửa", "Đã lưu").

## Thuộc tính đề

Tiêu đề, mã đề, ngưỡng đậu (%, kèm thang 1000 hiển thị cạnh), thời gian Thi mặc định (phút), **Ẩn đáp án**
(`hideAnswers`: khoá Luyện tập và ẩn đáp án khi xem lại), hướng dẫn (Markdown cơ bản). Ràng buộc theo
exam-format.md; giá trị ngoài ràng buộc vẫn nhập được nhưng hiện lỗi.

## Phần và câu

- **Phần**: tên (không trùng tên phần khác; trùng là lỗi). Xoá phần còn câu thì hỏi lại; có Hoàn tác. **Thêm phần**:
  phần rỗng tên "Phần N" (N = số phần + 1, tăng tiếp nếu trùng), chèn ngay sau phần đang chọn (hoặc phần chứa câu
  đang chọn); không chọn gì thì cuối đề (phương án 8, 10).
- **Thêm câu** (⌥⌘N): câu mới **một đáp án, bốn lựa chọn trống A–D, chưa có đáp án đúng** (phương án 7), chèn ngay sau
  câu đang chọn; chọn dòng phần thì cuối phần đó; không chọn gì (hoặc chọn dòng Đề) thì cuối phần cuối (phương án 8).
- **Câu**: nội dung (Markdown cơ bản), ảnh (tuỳ chọn), loại **Một đáp án** / **Nhiều đáp án**, danh sách lựa chọn,
  giải thích (tuỳ chọn).
- **Lựa chọn**: mỗi dòng có chữ cái, ô chữ, nút đánh dấu đúng (radio khi một đáp án, ô đánh dấu khi nhiều đáp án),
  nút xoá; **Thêm lựa chọn**; kéo thả để sắp xếp. Chữ cái luôn theo vị trí (A, B, C… liên tiếp, exam-format.md):
  sắp xếp hay xoá lựa chọn thì đổi chữ, và đáp án đúng đi theo nội dung của lựa chọn. 2–26 lựa chọn; ngoài khoảng
  là lỗi. Bố cục giữ được với 8+ lựa chọn.
- Đổi Nhiều đáp án → Một đáp án khi đang có hơn một đáp án đúng: giữ đáp án đúng đầu tiên, có Hoàn tác.
- **Id ổn định**: sửa câu giữ `id`; chuyển câu sang phần khác giữ `id`; **Nhân bản** tạo `id` mới. Lịch sử thi theo
  `id` câu (exam-taking.md), câu sửa sau lần thi hiện cảnh báo khi xem lại.
- **Id trùng** (đề đọc dễ): trình soạn phần/câu hiện nút **Cấp id mới** chỉ khi dòng đó có lỗi id trùng, kèm lời nhắc
  câu được cấp id mới không còn nối với lịch sử thi (phương án 10).

## Ảnh

- **Thêm/Thay ảnh…** (chọn file hoặc kéo thả vào trình soạn), **Xoá ảnh**. Định dạng: `png`, `jpg`, `jpeg`, `gif`,
  `webp`, `heic`; giữ nguyên byte gốc; tên theo SHA-256 nội dung (exam-format.md); ảnh trùng chỉ lưu một lần; ảnh không
  còn câu nào dùng thì không ghi vào file khi lưu.
- Ảnh vượt giới hạn của `ExamPackageLimits` thì từ chối với lý do.
- **Không đổi tên ảnh đã có** (dấu vân tay câu băm theo đường dẫn ảnh: đổi tên làm mọi lần thi cũ báo "đã sửa").
- Chỉ nhận ảnh là file trên máy (chọn file, kéo file từ Finder); ảnh kéo từ trình duyệt thì báo lưu về máy trước. Đọc
  file ảnh chạy nền; ảnh gắn vào đúng câu đã thả, kể cả khi câu dời chỗ trong lúc đọc; câu đã bị xoá thì bỏ ảnh và báo.
- **Ảnh sai tên trong file** (entry trong `media/` mà câu tham chiếu nhưng tên không theo SHA-256, ví dụ
  `media/photo.png`): giữ đúng exam-format.md, bộ đọc bỏ qua nên ảnh không dùng được, và **mất khi lưu**; không tự đổi
  tên. Thanh lỗi và trình soạn câu nói rõ: "Ảnh `media/photo.png` sai tên (phải theo SHA-256), không dùng được và sẽ
  bị bỏ khi lưu; dùng Thêm/Thay ảnh… để thêm lại." (khác với ảnh không có trong gói). Nt0 chốt 2026-10-16 (phương án
  11).

## Cây đề: sắp xếp, nhân bản, xoá

- Kéo thả: sắp xếp câu trong phần, chuyển câu sang phần khác, sắp xếp phần (kéo dòng phần là kéo cả phần cùng câu).
  Thả câu ngay dưới dòng phần thì câu thành câu đầu của phần đó; thả dòng phần vào giữa các câu của phần khác thì
  phần đặt sau phần đó; đang tìm (ô tìm có chữ) thì tắt kéo thả (phương án 10).
- Menu chuột phải câu: **Nhân bản**, **Chuyển tới phần ▸**, **Xoá**. Menu phần: **Đổi tên**, **Xoá phần**.
- Xoá câu không hỏi lại (có Hoàn tác).

## Kiểm lỗi

- Dùng `ExamValidator` (cùng quy tắc với bản Học viên và `validate_exam.py`), chạy lại sau mỗi thay đổi (chạy nền,
  không làm chậm gõ với đề 2.000 câu).
- Lỗi và cảnh báo theo exam-format.md; mỗi mục gắn với đề/phần/câu/lựa chọn để bấm nhảy tới.
- **Không chặn lưu** (exam-format.md).

## Lưu, hoàn tác, khôi phục

- Lưu, Lưu thành, Đổi tên, Versions, tự lưu và khôi phục sau crash: của macOS (`ReferenceFileDocument`); ⌘S, ⇧⌘S.
- Đóng cửa sổ, thoát app (⌘W, ⌘Q) theo tự lưu của macOS (Nt0 chốt 2026-10-17, phương án 15):
  - Đề **đã có file**: macOS tự lưu tại chỗ, nên đóng luôn, **không hỏi**; file trên đĩa có thay đổi. Bản trước còn
    trong Versions (**Duyệt các phiên bản**) và **Hoàn lại > Bản đã lưu**.
  - Đề **chưa từng lưu** (Đề mới, kết quả Import đề…) có thay đổi: hộp hỏi của macOS (Lưu / Không lưu / Huỷ; tên nút
    do macOS đặt); Huỷ giữ cửa sổ.
  - Người dùng bật "Hỏi giữ thay đổi khi đóng tài liệu" (Cài đặt hệ thống > Màn hình nền & Dock) thì macOS hỏi cả với
    đề đã có file; app không đổi cài đặt này.
- Hoàn tác / Làm lại (⌘Z / ⇧⌘Z) cho mọi thay đổi nội dung (gõ chữ gộp theo từng đoạn gõ, thêm/xoá/sắp xếp, ảnh, đáp
  án đúng, thuộc tính).
- Ghi file dùng `ExamPackageWriter` (đề ghi ra luôn khớp schema về cấu trúc; ghi rồi đọc lại ra đúng dữ liệu, kể cả
  ảnh: tiêu chí v1).

## Thử đề này

**Thử đề này** (⌘R, menu Đề; nút trên thanh công cụ) — Nt0 chốt 2026-10-16: **lưu rồi thử, có lịch sử**.

- Có thay đổi chưa lưu thì lưu trước (đề chưa từng lưu thì hỏi chỗ lưu như Lưu thành); huỷ lưu thì không thử.
- Sau khi lưu, đề phải đọc nghiêm được (như điều kiện "Sẵn sàng" của Thư viện, exam-taking.md phương án 5); không
  được thì không thử, báo "Đề còn N lỗi, sửa trước khi thử" và mở thanh lỗi.
- File chưa có trong Thư viện thì thêm vào (như Thêm đề); rồi mở **Trước khi thi** của đề đó (exam-taking.md) với
  **chế độ dùng lần trước** (như nhấp đúp thẻ đề), người dùng chọn Luyện tập hoặc Thi. Lần thử là một lần thi thường:
  vào Lịch sử thi (phương án 13).
- Thư viện đã có đề cùng `id` nhưng từ **file khác** (ví dụ Lưu thành bản sao): Thư viện hỏi "Đề này đã có trong thư
  viện từ file khác" (library.md, phương án 1). **Dùng file mới** → mục dùng file vừa lưu và mở Trước khi thi luôn,
  không phải bấm ⌘R lần nữa; **Huỷ** → không thử, Thư viện giữ file cũ (phương án 12).

## Bàn phím và trợ năng

| Hành động | Phím |
| --- | --- |
| Đề mới | ⌘N |
| Mở để sửa | ⇧⌘O |
| Lưu / Lưu thành | ⌘S / ⇧⌘S |
| Hoàn tác / Làm lại | ⌘Z / ⇧⌘Z |
| Thử đề này | ⌘R |
| Thêm câu (vào phần đang chọn) | ⌥⌘N |
| Thêm lựa chọn (trong trình soạn câu) | ⌥⌘↩ |
| Ẩn/hiện xem trước | ⌃⌘I |
| Tìm trong cây đề | ⌘F |

- Mọi điều khiển có nhãn VoiceOver; dòng câu trên cây đọc số, dòng đầu, trạng thái lỗi. Lỗi/cảnh báo bằng biểu
  tượng + chữ. Thao tác hoàn toàn bằng bàn phím với Điều hướng bàn phím của macOS (exam-taking.md phương án 19).
- Chuỗi giao diện tiếng Việt qua `LocalizedStringKey`/`String(localized:)` (String Catalog ở giai đoạn 5).

## Ngoài phạm vi giai đoạn 4

Xuất PDF và In đề (giai đoạn 5, [export-print.md](export-print.md)); loại câu mới (v2); ký số/mã hoá đáp án (ADR 0005).

## Phương án đã chốt (Nt0 duyệt 2026-10-16)

1. **Thử đề này:** lưu rồi thử; đề phải đọc nghiêm được; lần thử vào Lịch sử thi.
2. **Đề mới** có sẵn một phần "Phần 1", ngưỡng 70%, 60 phút.
3. **Thử đề này** tự thêm file vào Thư viện nếu chưa có.
4. **Đổi Nhiều → Một đáp án** giữ đáp án đúng đầu tiên.
5. **Xoá câu** không hỏi lại (có Hoàn tác); **xoá phần còn câu** thì hỏi lại.
6. **Phím** ⌥⌘N Thêm câu, ⌥⌘↩ Thêm lựa chọn, ⌃⌘I ẩn/hiện xem trước.

Nt0 chốt 2026-10-16 (các điểm mở của PR #34, bước 4a):

7. **Câu mới** có bốn lựa chọn trống A–D, một đáp án, chưa đánh dấu đáp án đúng.
8. **Thêm câu / Thêm phần** chèn ngay sau dòng đang chọn; không chọn gì thì cuối phần / cuối đề.
9. **Xem trước Luyện tập** như sau Kiểm tra đáp án (đáp án đúng, giải thích); **Thi** chỉ câu hỏi; đề `hideAnswers`
   vẫn xem trước được kiểu Luyện tập (chỉ admin thấy).
10. Phần mới tên **"Phần N"**; nút **Cấp id mới** chỉ hiện khi dòng có lỗi id trùng, kèm lời nhắc mất nối với lịch sử
    thi; **kéo thả**: thả ngay dưới dòng phần = đầu phần, thả phần giữa các câu = sau phần đó, tắt khi đang tìm;
    **thanh lỗi** ở đáy cột giữa.
11. **Ảnh sai tên trong file** giữ quy tắc của exam-format.md (bỏ qua khi đọc, mất khi lưu, không tự đổi tên), nhưng
    thanh lỗi và trình soạn câu nói rõ ảnh sai tên và sẽ bị bỏ khi lưu (review độc lập PR #34, phát hiện 2).

Nt0 chốt 2026-10-16 (các điểm mở của PR #35, bước 4b):

12. **Thử đề với file cùng id đề nhưng khác file** với mục đã có trong Thư viện: Thư viện hỏi Dùng file mới / Huỷ;
    **Dùng file mới** thì mở Trước khi thi luôn (không cần ⌘R lần nữa), **Huỷ** thì không thử.
13. **Thử đề** mở Trước khi thi với **chế độ dùng lần trước** (như nhấp đúp thẻ đề).
14. **Import đề…**: tiến độ và hộp xác nhận ở **cửa sổ riêng "Import đề"**; đóng cửa sổ đó là Huỷ (import.md, phương
    án 16).

Nt0 chốt 2026-10-17 (review độc lập PR #42, phát hiện 2):

15. **Đóng cửa sổ soạn đề theo macOS**: đề đã có file được tự lưu tại chỗ, ⌘W/⌘Q đóng không hỏi (Versions và Hoàn lại >
    Bản đã lưu giữ bản trước); đề chưa từng lưu (Đề mới, Import đề…) có thay đổi thì hỏi Lưu / Không lưu / Huỷ, Huỷ giữ
    cửa sổ. Thay câu cũ "khi có thay đổi chưa lưu: luôn hỏi" (không khớp hành vi mặc định của macOS).
