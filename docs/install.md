# Cài đặt Exam Suite

Exam Suite là dự án cá nhân của Nt0, có hai bản app:

- **Exam Suite** (bản Học viên): làm bài, luyện tập, xem kết quả. File cài: `ExamSuite-<phiên bản>.dmg`.
- **Exam Suite Admin** (bản Admin): thêm phần soạn đề và import đề. File cài: `ExamSuiteAdmin-<phiên bản>.dmg`.

Tải DMG ở trang Releases của dự án: https://github.com/tuann2/exam-suite/releases. Mỗi DMG có app, lối tắt
Applications, file "Hướng dẫn cài đặt.txt" (bản sao của hướng dẫn này; dòng đầu ghi phiên bản, số build và mã commit của
bản đóng gói) và ba file giấy phép: "LICENSE.txt" (Apache-2.0), "NOTICE.txt", "THIRD_PARTY_NOTICES.txt" (giấy phép của
thư viện đi kèm app).

## Cần gì

- Mac chip Apple (M1 trở lên). Mac chip Intel không chạy được.
- macOS 15 Sequoia trở lên.

## Cài lần đầu

1. Nhấp đúp file DMG. Một ổ đĩa mở ra ("Exam Suite <phiên bản>" hoặc "Exam Suite Admin <phiên bản>").
2. Kéo biểu tượng app vào lối tắt **Applications** trong cửa sổ đó.
3. Đẩy ổ ra: chuột phải ổ trong thanh bên của Finder › **Đẩy ra** (Eject). File DMG xoá được sau khi cài.

## Mở lần đầu: Vẫn mở (Open Anyway)

App chưa được Apple công chứng (ký ad-hoc), nên macOS chặn lần mở đầu tiên. Chỉ cần làm một lần cho mỗi bản cài
(tên nút dưới đây theo macOS 26 tiếng Việt, trong ngoặc là tiếng Anh; macOS 15 tương tự):

1. Mở app trong thư mục Applications. macOS báo **"Exam Suite" chưa được mở** ("Exam Suite" Not Opened): "Apple không
   thể xác minh rằng "Exam Suite" không chứa phần mềm độc hại…". Bấm **Xong** (Done), **không** bấm
   **Chuyển vào Thùng rác** (Move to Trash).
2. Mở **Cài đặt hệ thống › Quyền riêng tư & Bảo mật** (System Settings › Privacy & Security), cuộn xuống mục
   **Bảo mật** (Security). Có dòng **"Exam Suite" đã bị chặn để bảo vệ máy Mac của bạn** và nút **Vẫn mở** (Open Anyway).
   Bấm nút đó, xác nhận bằng mật khẩu hoặc Touch ID.
3. Mở lại app; nếu macOS hỏi lần nữa, bấm **Vẫn mở** (Open Anyway) hoặc **Mở** (Open). Từ lần sau app mở bình thường.

Lưu ý:

- Không thấy nút Vẫn mở: mở app thêm một lần cho macOS chặn lại, rồi vào lại Quyền riêng tư & Bảo mật (nút chỉ hiện
  một thời gian sau lần bị chặn).
- Từ macOS 15, chuột phải › Mở không còn bỏ qua được bước chặn này; phải dùng Vẫn mở như trên.
- DMG chép từ ổ mạng chung hay ổ USB (không tải qua trình duyệt, ứng dụng nhắn tin hay thư) có thể không mang cờ "tải từ
  Internet" (quarantine): khi đó app mở ngay, không có bước chặn và không có nút Vẫn mở. Không phải lỗi.
- macOS báo app "bị hỏng" (damaged) và không có nút Vẫn mở: file DMG có thể bị lỗi khi tải hoặc chép. Xoá app vừa cài,
  tải lại DMG từ trang Releases rồi cài lại. Vẫn lỗi thì báo người phát hành qua trang GitHub của dự án; không tự tắt
  các cơ chế bảo mật của macOS.

## Máy cài cả hai bản

- Nhấp đúp file đề `.exam` trong Finder sẽ mở bằng **bản Admin** (cửa sổ soạn đề), vì bản Admin là app chủ của kiểu file.
- Muốn làm bài với file đó: mở bản Học viên rồi dùng **Tệp › Thêm đề…** (⌘O) hoặc kéo file vào cửa sổ Thư viện; hoặc
  chuột phải file trong Finder › **Mở bằng** › **Exam Suite**.
- Hai bản có thư viện, lịch sử thi và cài đặt riêng.

## Cập nhật lên bản mới

1. Thoát app (⌘Q).
2. Mở DMG mới, kéo app vào **Applications**, chọn **Thay thế** (Replace) khi được hỏi.
3. Mở app. Bản mới có thể phải làm lại bước Vẫn mở ở trên.
4. macOS có thể hỏi lại quyền truy cập thư mục (Tài liệu, Màn hình nền, Tải về, ổ mạng…) khi app mở file đề ở đó, kể cả
   khi bản trước đã được cho phép: với app ký ad-hoc, macOS coi mỗi bản build là một app mới. Bấm **Cho phép** (Allow) như
   lần đầu.

Thư viện, lịch sử thi và cài đặt (nền đọc, cỡ chữ nội dung, tên thí sinh…) **giữ nguyên** khi cập nhật, vì chúng nằm
ngoài app (mục Gỡ cài đặt). Xem phiên bản đang cài: menu **Exam Suite › Giới thiệu về Exam Suite** (About),
số trong ngoặc là số build; so với dòng đầu file "Hướng dẫn cài đặt.txt" của DMG. Hộp Giới thiệu cũng ghi giấy phép và
thư viện đi kèm.

## Gỡ cài đặt

1. Thoát app (⌘Q).
2. Kéo app từ thư mục Applications vào Thùng rác.

Gỡ app **không** xoá dữ liệu. Dữ liệu của người dùng nằm ở:

- Bản Học viên: thư mục `~/Library/Application Support/vn.io.nt0.examsuite/` (thư viện, lịch sử thi, đề mẫu) và file
  cài đặt `~/Library/Preferences/vn.io.nt0.examsuite.plist`.
- Bản Admin: thư mục `~/Library/Application Support/vn.io.nt0.examsuite.admin/` và file cài đặt
  `~/Library/Preferences/vn.io.nt0.examsuite.admin.plist`.
- File đề `.exam` đã thêm vào thư viện vẫn ở chỗ cũ: thư viện chỉ ghi nhớ chỗ của file, không chép file.

Muốn xoá hẳn (mất thư viện và lịch sử thi, không khôi phục được): thoát app, mở Finder › **Đi › Đi tới thư mục…** (⇧⌘G),
dán từng đường dẫn ở trên rồi chuyển mục đó vào Thùng rác.
