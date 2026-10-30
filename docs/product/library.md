# Thư viện đề

Thẩm quyền: tài liệu này. Nguồn: mục "Thiết kế UX trên macOS" và "Định dạng đề và dữ liệu"
của [plan-macos-v1.md](plan-macos-v1.md); DESIGN_BRIEF §5.1, §5.8, §7 của Open Exam Suite
(đọc qua link, không chép). Những chỗ đặc tả gốc không nói được ghi ở mục cuối
"Phương án đã chốt" (Nt0 duyệt 2026-10-15).

Code: `LibraryData` (dữ liệu, không giao diện) và `LibraryModel` (model trình bày, InterfaceCore) trong
`Packages/SharedFeatures` (dùng chung với bản iOS), `LibraryFeature` (SwiftUI của bản macOS) trong
`Packages/ExamFeatures`. Cả hai bản app dùng chung; khác nhau ghi rõ ở từng mục.

## Cửa sổ

- Một cửa sổ Thư viện duy nhất cho mỗi bản app, tối thiểu 960×640, co giãn được; giữ bố cục ở 200%.
- Bản Học viên: đóng cửa sổ Thư viện thì app thoát; mở `.exam` từ Finder khi đó khởi động lại app vào Thư viện.
  Bản Admin: luôn mở Thư viện khi khởi động, kể cả khi khởi động bằng một file `.exam` (mở kèm cửa sổ soạn đề).
- `NavigationSplitView`: sidebar có **Tất cả đề**, **Gần đây**, **Lịch sử thi**; vùng nội dung bên phải.
- Thanh công cụ: **Thêm đề** (⌘O), tìm kiếm (⌘F), sắp xếp, lọc, chuyển **lưới / danh sách**.
  Bản Admin thêm **Đề mới** từ giai đoạn 4.
- Màu nhấn teal (`#017777`) cho Thư viện, Luyện tập, Thi; burgundy (`#801638`) dành cho Soạn đề.
  Cách dùng teal cho chữ và biểu tượng ở giao diện sáng/tối: phương án 8.
- Theo giao diện sáng/tối của hệ thống.

## Thẻ đề (lưới) và dòng (danh sách)

Mỗi đề hiện: tiêu đề, mã đề, số câu, số phần, thời gian làm bài, ngưỡng đậu (%), lần thi gần
nhất (điểm %, ngày, đậu/trượt bằng biểu tượng + chữ). Danh sách là `Table` có các cột tương ứng
và sắp xếp được theo cột, theo thứ tự: Tên đề, **Trạng thái**, Mã đề, Số câu, Số phần, Thời gian, Ngưỡng đậu, Lần thi gần
nhất (Nt0 chốt 2026-10-18: trạng thái ngay sau tên đề để luôn thấy ở cửa sổ 960 có thanh bên, nơi tám cột không vừa;
cửa sổ hẹp có thể phải cuộn ngang các cột sau).

Trạng thái của đề, luôn bằng biểu tượng + chữ, không chỉ dựa vào màu:

| Trạng thái | Khi nào | Bước tiếp theo trên thẻ |
| --- | --- | --- |
| Sẵn sàng | File đọc được theo chế độ của bản app | — |
| Đang kiểm tra | Chưa có kết quả đọc file lần này | — |
| Không tìm thấy file | Bookmark không phân giải được, file đã xoá hoặc ở ổ chưa gắn | **Tìm file…**, **Xoá khỏi thư viện** |
| File hỏng | Không đọc được gói kể cả ở chế độ dễ (zip hỏng, thiếu `exam.json`, JSON không phân tích được, quá lớn, không có quyền đọc) | Lý do; **Xoá khỏi thư viện** |
| Cần app mới hơn | `formatVersion` lớn hơn app hiểu | "Cập nhật Exam Suite"; **Xoá khỏi thư viện** |
| Đề có lỗi | Bản Học viên: đọc dễ được nhưng đọc nghiêm thất bại (lỗi kiểm tra, trường lạ, khoá trùng, dấu phẩy thừa…) | Lý do; **Xoá khỏi thư viện** |
| Có lỗi (Admin) | Bản Admin: đọc dễ được nhưng bản Học viên sẽ từ chối | Lý do; **Sửa** |

Hành động trên thẻ:

- **Luyện tập**, **Thi**: mở màn Trước khi thi ([exam-taking.md](exam-taking.md)), chọn sẵn chế độ đó.
  Chỉ bật khi đề **Sẵn sàng**, ở cả hai bản app (exam-taking.md, phương án 5).
- Nhấp đúp hoặc Return: mở Trước khi thi với chế độ dùng lần trước; đề chưa Sẵn sàng thì không làm gì
  (hành động tắt như hai nút trên; exam-taking.md, phương án 17, Nt0 chốt 2026-10-15).
- Menu chuột phải và nút "…": **Luyện tập**, **Thi** (tắt khi đề chưa Sẵn sàng), **Thông tin** (⌘I),
  **Hiện trong Finder**, **Xem lịch sử thi**, **Xoá khỏi thư viện** (⌫); bản Admin thêm **Sửa** (⌘E) mở đề
  trong cửa sổ soạn đề.
- **Thông tin**: đường dẫn file, dung lượng, phiên bản định dạng, ngày thêm, số phần/câu/ảnh,
  thời gian, ngưỡng đậu, trạng thái và lý do.

## Thêm đề

- **Thêm đề…** (nút, ⌘O, menu File): chọn một hoặc nhiều file `.exam`.
- **Kéo thả** một hoặc nhiều file `.exam` vào cửa sổ. File không phải `.exam` bị bỏ qua và được báo.
- **Bản Học viên mở `.exam` từ Finder** (nhấp đúp, Open With, kéo vào biểu tượng Dock): thêm vào thư viện,
  mở cửa sổ Thư viện nếu đang đóng và chọn đề đó. Bản Admin mở `.exam` từ Finder vào cửa sổ soạn đề
  như hiện nay (kết luận spike giai đoạn 0).
- Đọc theo chế độ của bản app: Học viên **nghiêm**, Admin **dễ** (exam-format.md).
- File được **tham chiếu tại chỗ** bằng bookmark, không chép vào app; vẫn tìm được khi file đổi tên
  hoặc di chuyển trên cùng ổ.
- Thêm nhiều file một lúc: thêm những file được, cuối cùng báo gọn những file không thêm được kèm lý do.
- Mỗi id đề chỉ có một mục trong thư viện (xem "Phương án đã chốt" cho trường hợp trùng).

## Đề mẫu và lần đầu mở app

- Lần đầu mở app (chưa từng tạo đề mẫu), app ghi **2 đề mẫu tự soạn** vào
  `~/Library/Application Support/<bundle ID>/Samples/` và thêm vào thư viện, kèm dải chào mừng có thể đóng.
- Xoá đề mẫu khỏi thư viện thì không tự tạo lại. Menu Trợ giúp có **Khôi phục đề mẫu**.
- Nội dung đề mẫu nằm trong repo ở `Packages/SharedFeatures/Sources/LibraryData/Resources/Samples/<tên>/`
  (`exam.json` + `media/`), được kiểm theo schema như fixture và đọc nghiêm được, không có cả warning:
  `scripts/validate_exam.py --all` và test `LibrarySampleTests` (ExamFileTests). Ảnh vẽ bằng
  `scripts/samples/make_sample_images.swift`.
- Quy tắc riêng cho đề mẫu trong repo (Nt0 duyệt 2026-10-15), không áp cho đề của người dùng: mỗi thư mục con
  không ẩn của `Samples/` là một đề và phải có `exam.json`; mọi chuỗi ở dạng NFC; tên ảnh đúng 16 ký tự hex đầu
  của SHA-256 nội dung; không có ảnh thừa. Kiểm ở `validate_exam.py --all` (NFC chỉ script kiểm) và `LibrarySampleTests`.
- **Khôi phục đề mẫu** thêm lại đề mẫu đã xoá khỏi thư viện và ghi lại file đề mẫu bị mất; không ghi đè đề mẫu
  đang có file. Vì vậy nội dung đề mẫu sửa ở bản app sau chỉ tới máy đã cài khi người dùng xoá rồi khôi phục.

## Làm mới trạng thái

- Khi mở app và mỗi khi cửa sổ được kích hoạt lại: phân giải bookmark (cập nhật nếu cũ), kiểm file còn không;
  nếu kích thước hoặc ngày sửa đổi khác lần đọc trước thì đọc lại và cập nhật thông tin thẻ.
- Đọc file chạy nền, không chặn giao diện; đề 2.000 câu không làm treo cửa sổ.
- Thông tin thẻ (tiêu đề, số câu…) lưu lại để thư viện hiện ngay khi mở app, trước khi kiểm xong.

## Tìm, lọc, sắp xếp, chế độ xem

- Tìm theo tiêu đề và mã đề, không phân biệt hoa thường và dấu ("toan" khớp "Toán", "d" khớp "đ").
- Lọc: **Tất cả**, **Sẵn sàng**, **Có vấn đề**.
- Sắp xếp: **Gần đây** (lần thi hoặc lần thêm gần nhất), **Tên** (theo thứ tự tiếng Việt), **Điểm lần trước**.
- **Gần đây** trên sidebar: đề có lần thi hoặc được thêm trong 30 ngày, mới nhất trước.
- Chế độ xem và cách sắp xếp được nhớ giữa các lần mở app (`@AppStorage`).

## Xoá khỏi thư viện

Chỉ xoá mục khỏi thư viện: **không xoá file, không xoá lịch sử thi**. Không hỏi lại; hiện thông báo không
chặn "Đã xoá khỏi thư viện" kèm **Hoàn tác** trong vài giây, và ⌘Z cũng hoàn tác.

## Lịch sử thi

- Sidebar **Lịch sử thi**: mọi lần thi, mới nhất trước. Mỗi dòng: ngày giờ, tên đề lúc thi, thí sinh,
  chế độ (Luyện tập/Thi), điểm %, thang 1000, đậu/trượt (biểu tượng + chữ), thời gian làm.
- **Xem lịch sử thi** từ một đề: lọc theo đề đó.
- Lịch sử gắn với id đề và còn lại khi đề bị xoá khỏi thư viện.
- Lần thi tự lưu khi nộp bài Luyện tập hoặc Thi. Nhấp đúp hoặc Return trên một lần thi mở **Kết quả** của
  lần đó; mở kết quả và xem lại một lần thi: mục Lịch sử thi của [exam-taking.md](exam-taking.md).

## Lưu trữ

- SwiftData, tách sau một lớp repository (dự phòng GRDB theo bảng rủi ro của kế hoạch).
- Kho riêng cho mỗi bản app: `~/Library/Application Support/<bundle ID>/Library.store`. Không dùng
  kho mặc định của SwiftData vì hai bản app không sandbox sẽ dùng chung một file.
- Schema có phiên bản (`VersionedSchema`) từ v1; đổi schema phải có kế hoạch chuyển đổi và test.
- Kho không mở được: app không crash; đổi tên kho cũ thành `Library.store.broken-<thời điểm>`,
  tạo kho mới và báo cho người dùng.
- Cài đặt nhỏ (chế độ xem, cách sắp xếp, đã tạo đề mẫu, đã đóng dải chào mừng) dùng `@AppStorage`.

## Bàn phím và trợ năng

| Hành động | Phím |
| --- | --- |
| Thêm đề (cả hai bản) | ⌘O |
| Mở để sửa (Admin, mở `.exam` vào cửa sổ soạn đề) | ⇧⌘O |
| Tìm | ⌘F |
| Thông tin | ⌘I |
| Xoá khỏi thư viện (có Hoàn tác) | ⌫ |
| Hoàn tác | ⌘Z |
| Sửa (Admin) | ⌘E |
| Mở đề | Return |

- Mọi điều khiển có nhãn VoiceOver; mỗi thẻ đọc thành một câu tóm tắt (tiêu đề, mã, số câu, trạng thái,
  lần thi gần nhất) và có các hành động trợ năng tương ứng menu.
- Điều hướng lưới bằng phím mũi tên; tiêu điểm luôn nhìn thấy được.
- Chuỗi giao diện viết bằng tiếng Việt qua `LocalizedStringKey`/`String(localized:)` để giai đoạn 5 đưa
  vào String Catalog có tiếng Anh.

## Phương án đã chốt (Nt0 duyệt 2026-10-15)

1. **Trùng id đề:** cùng file → chọn đề đã có, báo "Đề đã có trong thư viện". Khác file → hỏi
   "Đề này đã có trong thư viện từ file khác" với **Dùng file mới** / **Huỷ**. Mỗi id đề một mục.
2. **Bản Học viên thêm file không đọc được** (hỏng, có lỗi, cần app mới hơn): không thêm, báo lý do
   và bước tiếp theo. Trạng thái lỗi trên thẻ chỉ dành cho đề đã có trong thư viện mà file thay đổi sau đó.
3. **Xoá khỏi thư viện** không hỏi lại, có Hoàn tác (đặc tả gốc: xác nhận thường không dùng hộp thoại).
4. **Đề mẫu:** "Làm quen với Exam Suite" (giới thiệu cách dùng app) và "An toàn thông tin cơ bản".
5. **Luyện tập/Thi** hiện nhưng tắt cho tới giai đoạn 3. Từ giai đoạn 3: bật khi đề Sẵn sàng
   (exam-taking.md, phương án 5).
6. **Tìm file…** cho đề mất file: file chọn phải có cùng id đề; khác id thì báo và không đổi.
7. **⌘O ở bản Admin:** ⌘O là **Thêm đề…** ở cả hai bản. Mục Open… ⌘O có sẵn của cửa sổ soạn đề
   (`DocumentGroup`) được thay bằng **Mở để sửa…** (⇧⌘O, menu File), kèm **Mở gần đây** dựng lại từ danh
   sách đề mở gần đây của macOS; mỗi phím chỉ có một mục menu. Lý do: một phím một nghĩa ở cả hai bản, và đề
   mẫu "Làm quen" câu 10 dạy ⌘O là Thêm đề.
8. **Màu nhấn ở giao diện tối:** `#017777` giữ cho nền nút có chữ trắng ở cả hai giao diện
   (5,4:1). Chữ, biểu tượng và viền teal đặt trên nền (nhãn Đề mẫu, nút viền, viền chọn) dùng `#4FC9C9` ở giao
   diện tối và `#006666` ở giao diện sáng, vì `#017777` trên nền tối chỉ khoảng 2,3:1 và trên nền nhạt của nhãn
   dưới 4,5:1. Mức áp dụng: chữ nhỏ ≥ 4,5:1, chữ lớn và biểu tượng ≥ 3:1, ở cả hai giao diện.
9. **Phân loại trạng thái theo hai lần đọc:** đọc dễ được nhưng đọc nghiêm thất bại là **Đề có lỗi** (Học viên) /
   **Có lỗi** (Admin, có **Sửa**); đọc dễ cũng thất bại là **File hỏng** hoặc **Cần app mới hơn**. Ví dụ dấu phẩy thừa
   trong JSON là Đề có lỗi, để bản Admin còn mở ra sửa được.
10. **Bản Học viên đóng cửa sổ Thư viện thì app thoát** (mục Cửa sổ).
11. **Bản Admin khởi động bằng file `.exam`** mở cả cửa sổ soạn đề lẫn Thư viện (mục Cửa sổ).
