# Cài đặt Exam Suite trên iPhone

Exam Suite cho iPhone là bản **Học viên** (làm bài, luyện tập, xem kết quả, lịch sử thi) của dự án cá nhân của Nt0.
Bản 0.1.0 không có trên App Store hay TestFlight: app được cài từ mã nguồn bằng Xcode, ký bằng Apple ID miễn phí
(Personal Team). Bản cài kiểu này chạy được 7 ngày, sau đó phải cài lại (mục "Sau 7 ngày"). Soạn đề vẫn làm trên bản
Admin cho macOS.

## Cần gì

- iPhone chạy iOS 18 trở lên. iPad chạy được bản iPhone, giao diện chưa dành cho iPad.
- Mac chip Apple có Xcode (bản dùng khi phát triển: Xcode 27) và XcodeGen (`brew install xcodegen`).
- Một Apple ID. Không cần đăng ký Apple Developer Program.
- Cáp nối iPhone với Mac cho lần cài đầu.
- Mã nguồn: `git clone https://github.com/tuann2/exam-suite`, lấy tag `ios-v<phiên bản>` của bản muốn cài.

## Chuẩn bị (một lần)

1. Trên Mac: **Xcode › Settings › Accounts**, thêm Apple ID. Xcode tạo một nhóm ký tên "<tên bạn> (Personal Team)".
2. Nối iPhone với Mac, mở khoá iPhone, chọn **Tin cậy** (Trust) máy tính này.
3. Bật Chế độ nhà phát triển trên iPhone: **Cài đặt › Quyền riêng tư & Bảo mật › Chế độ nhà phát triển** (Developer
   Mode), bật, rồi khởi động lại khi được hỏi và chọn **Bật** sau khi máy lên. Mục này chỉ hiện sau khi iPhone đã nối
   với Xcode một lần.

## Cài

1. Trong thư mục mã nguồn, chạy `xcodegen generate`, rồi mở `ExamSuite.xcodeproj` bằng Xcode.
2. Ở thanh trên của Xcode, chọn scheme **ExamSuiteiOS** và chọn iPhone của bạn làm đích.
3. Chọn bản Release (bản dùng hằng ngày): **Product › Scheme › Edit Scheme… › Run › Build Configuration: Release**.
   Bản Debug là app khác ("Exam Suite Debug", bundle ID có đuôi `.debug`), dữ liệu riêng, dùng khi phát triển.
4. Chọn project, target **ExamSuiteiOS**, thẻ **Signing & Capabilities**, mục **Team**: chọn Personal Team của bạn.
   Lựa chọn này nằm trong `ExamSuite.xcodeproj` do XcodeGen sinh ra, không có trong repo; chạy lại `xcodegen generate`
   thì chọn lại.
5. **Product › Run** (⌘R). Lần đầu, iPhone báo nhà phát triển chưa được tin cậy: mở **Cài đặt › Cài đặt chung › VPN &
   Quản lý thiết bị**, chọn Apple ID của bạn, chọn **Tin cậy**. Rồi mở **Exam Suite** trên màn hình chính. Lần đầu Thư
   viện có hai đề mẫu.

Cài bằng dòng lệnh (không mở Xcode), sau khi đã làm bước Chuẩn bị:

```sh
xcodegen generate
xcodebuild -project ExamSuite.xcodeproj -scheme ExamSuiteiOS -configuration Release \
  -destination 'platform=iOS,name=<tên iPhone>' -derivedDataPath build/DerivedData-iOS-Device \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=<team ID> build
xcrun devicectl device install app --device '<tên iPhone>' \
  'build/DerivedData-iOS-Device/Build/Products/Release-iphoneos/Exam Suite.app'
```

Team ID là mã 10 ký tự của Personal Team. Đừng ghi team ID vào `project.yml` hay file nào trong repo: chỉ truyền khi
build.

## Sau 7 ngày

Bản ký bằng Personal Team hết hạn sau 7 ngày: app không mở được nữa. Nối iPhone với Mac và cài lại như mục Cài (cùng
bản Release): app được cài đè, Thư viện, lịch sử thi và cài đặt giữ nguyên. Personal Team cài được tối đa 3 app trên
một iPhone; bản Release và bản Debug là hai app.

Bundle ID `vn.io.nt0.examsuite.ios` đã đăng ký cho nhóm ký của Nt0. Người khác cài bằng Personal Team của mình thì đổi
**Bundle Identifier** của target ExamSuiteiOS ở thẻ Signing & Capabilities (ví dụ `<tên miền của bạn>.examsuite.ios`),
không sửa `project.yml`. Đừng truyền `PRODUCT_BUNDLE_IDENTIFIER` ở dòng lệnh `xcodebuild`: cài đặt đó áp cho mọi target
của lần build, kể cả bundle tài nguyên của các package. Thay đổi ở thẻ Signing nằm trong project do XcodeGen sinh: chạy
lại `xcodegen generate` (mục Cập nhật) thì đổi lại.

## Mở đề

- **Thêm đề** (nút + trong Thư viện): chọn file `.exam` trong app Tệp (iCloud Drive, Trên iPhone, Google Drive…). App
  dùng file tại chỗ, không chép: xoá hay dời file thì đề hiện "Không tìm thấy file", chọn **Tìm file…** để chỉ lại.
- Từ Zalo, Mail, AirDrop…: chạm file `.exam`, chọn **Chia sẻ** hoặc **Mở bằng**, rồi **Exam Suite**. iOS chép file vào
  app; đề có trong Thư viện. Nhận lại cùng một đề thì app hỏi **Dùng file mới** hay **Huỷ**.
- Đang làm bài mà mở file từ app khác: đề vẫn được thêm, câu hỏi (nếu có) hiện khi bạn về Thư viện.

## Cập nhật

Lấy tag của bản mới (`git fetch --tags`, `git checkout ios-v<phiên bản>`), chạy `xcodegen generate`, rồi cài lại như mục
Cài. Dữ liệu giữ nguyên.

## Gỡ cài

Nhấn giữ biểu tượng Exam Suite, chọn **Xóa ứng dụng**, rồi xác nhận **Xóa ứng dụng**. Thư viện, lịch sử thi và các file đề nhận từ app
khác mất theo app; file đề trong app Tệp không bị xoá.

## Dữ liệu nằm ở đâu

Mọi dữ liệu nằm trong vùng riêng (container) của app trên iPhone, thư mục `Application Support/vn.io.nt0.examsuite/`:
kho Thư viện, lịch sử thi, file đề nhận từ app khác (thư mục `Received/`). Bản sao lưu iCloud hay máy tính của iPhone có
dữ liệu này, như mọi app. Bản Debug (bundle ID `vn.io.nt0.examsuite.ios.debug`) là app khác, có container riêng, nên dữ
liệu của nó tách riêng.

Giấy phép: **Thư viện › menu (biểu tượng bộ lọc) › Giới thiệu** có phiên bản, giấy phép Apache-2.0, NOTICE và giấy phép
của thư viện đi kèm (ZIPFoundation).
