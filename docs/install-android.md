# Cài đặt Exam Suite trên Android

Exam Suite cho Android là bản **Học viên** (làm bài, luyện tập, xem kết quả, lịch sử thi) của dự án cá nhân của Nt0.
App không có trên Google Play. File cài `ExamSuite-<phiên bản>.apk` nằm ở trang
[Releases](https://github.com/tuann2/exam-suite/releases) của repo (mục "Exam Suite cho Android", đánh dấu Pre-release),
hoặc Nt0 gửi file qua Zalo, WhatsApp, Drive…. Soạn đề vẫn làm trên bản Admin cho macOS.

## Cần gì

- Điện thoại Android 12 trở lên. Máy tính bảng chạy được, nhưng giao diện là của điện thoại.
- File cài khoảng 30 MB; app cần thêm chỗ cho các đề (mỗi đề được sao chép vào app; đề nhiều ảnh có thể vài chục MB).

## Cài lần đầu

Tên các mục dưới đây theo Samsung (One UI) tiếng Việt; máy hãng khác có tên gần giống.

1. Mở file APK vừa nhận: chạm vào file trong Zalo, WhatsApp, Drive hay app **File của bạn** (My Files).
2. Android báo không được phép cài ứng dụng từ nguồn này. Chạm **Cài đặt** (Settings), bật **Cho phép từ nguồn này**
   (Allow from this source) cho đúng app đang mở file, rồi quay lại.
   - Máy Samsung có **Trình chặn tự động** (Auto Blocker) đang bật thì không cài được app ngoài Google Play: tắt ở
     **Cài đặt › Bảo mật và quyền riêng tư › Trình chặn tự động**, cài xong có thể bật lại.
3. Chạm **Cài đặt** (Install).
4. Google Play Protect có thể báo app chưa được xác minh hoặc chặn app không an toàn, vì app không đến từ Google Play.
   Chạm **Chi tiết khác** (More details) › **Vẫn cài đặt** (Install anyway). Đừng gửi app cho Google quét nếu không muốn.
5. Mở **Exam Suite** từ màn hình chính. Lần đầu Thư viện có hai đề mẫu.

## Mở đề

- Nhận file `.exam` trong Zalo, WhatsApp, Drive…: chạm vào file › **Mở bằng** › **Exam Suite**. Đề được thêm vào Thư
  viện và mở luôn màn Trước khi thi.
- Hoặc trong app: **Thêm đề** rồi chọn file `.exam` trong máy.
- Từ bản 0.2.0, file `.oef` của Open Exam Suite mở được theo hai cách trên: app chuyển nó thành đề của Exam Suite lúc
  thêm. File `.oef` bản cũ (trước Open Exam Suite 4) không mở được: app báo file bản cũ, hoặc báo gói đề hỏng với file
  của Open Exam Suite 1, 2. Mở file bằng Open Exam Suite, lưu lại rồi gửi lại.
- File của một đề đã có trong Thư viện (cùng mã định danh mà app soạn đề ghi trong file, không phải ô Mã đề; thường là
  bản mới của đề đó) thì app hỏi **Cập nhật đề**: lịch sử thi giữ lại; bài đang làm dở của đề đó bị bỏ.

## Làm bài trên điện thoại

- Ra khỏi app khi đang làm bài (nghe máy, khoá màn hình, chuyển app) thì bài **tự tạm dừng** và được lưu; mở lại app là
  về đúng câu, bấm **Tiếp tục**. Thời gian ở ngoài app không bị tính.
- Mỗi lúc chỉ có một bài đang làm. Mở đề khác khi còn bài dở thì app hỏi tiếp tục bài cũ hay bỏ bài cũ.
- Cỡ chữ theo cài đặt cỡ chữ của điện thoại; giao diện sáng/tối theo điện thoại. Ngôn ngữ app (tiếng Việt, tiếng Anh)
  theo ngôn ngữ của điện thoại; từ Android 13 đổi riêng cho app ở **Cài đặt › Ứng dụng › Exam Suite › Ngôn ngữ**.

## Cập nhật app

Cài file APK bản mới **đè lên** bản đang có (làm như Cài lần đầu, bước 1 và 3). Thư viện, lịch sử thi và bài đang làm dở
được giữ.

**Đừng gỡ app trước khi cài bản mới**: gỡ app là xoá hết dữ liệu của app.

## Dữ liệu của app

Thư viện (bản sao các đề), lịch sử thi, bài đang làm dở và cài đặt **chỉ nằm trong app trên điện thoại này**: không sao
lưu lên đám mây, không chuyển sang điện thoại mới. Gỡ app, xoá dữ liệu app hay đổi máy là mất. File `.exam` gốc vẫn còn
ở nơi bạn nhận (Zalo, Drive…) để thêm lại.

## Gỡ cài đặt

Nhấn giữ biểu tượng Exam Suite › **Gỡ cài đặt** (Uninstall), hoặc **Cài đặt › Ứng dụng › Exam Suite › Gỡ cài đặt**.
Mọi dữ liệu của app bị xoá cùng.

## Giấy phép

Exam Suite là phần mềm mã nguồn mở theo giấy phép Apache-2.0 (© 2026 Nt0). Cùng file APK, Nt0 gửi kèm `LICENSE.txt`
(giấy phép), `NOTICE.txt` và `THIRD_PARTY_NOTICES.txt` (thư viện đi kèm app, đều Apache-2.0); bản gốc ở
https://github.com/tuann2/exam-suite (`LICENSE`, `NOTICE`, `android/THIRD_PARTY_NOTICES.md`).

## Báo lỗi

Gửi cho Nt0: hãng và đời máy (ví dụ Samsung Galaxy S24+), phiên bản Android (**Cài đặt › Thông tin điện thoại ›
Thông tin phần mềm**), phiên bản app (**Cài đặt › Ứng dụng › Exam Suite**, dòng Phiên bản), app đã dùng để gửi file đề,
các bước làm và ảnh chụp màn hình nếu có.
