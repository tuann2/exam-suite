# Số đo đề lớn, bản Android

Đề chuẩn của [large-exams.md](../product/large-exams.md) (2.000 câu, 200 ảnh, gói 60 MB; `python3
scripts/gen_large_exam.py --out dist/`), đo trên bản **debug** (chậm hơn bản phát hành: bản debug không được tối ưu
khi biên dịch trên máy). Ngân sách là cột "Ngân sách Release" của large-exams.md; số chỉ ghi, không chặn merge (v1 không
có module đo, plan-android-v1.md Phần 4). Mục mới nhất ở trên.

Cách đo: bản debug ghi nhật ký `ExamSuiteTiming` (`vn.io.nt0.examsuite.attempt.Timing`; bản phát hành không ghi), đọc
bằng `adb logcat -s ExamSuiteTiming`. Lượt đi: mở `.exam` đề chuẩn từ app khác (Thêm đề, Trước khi thi mở ngay) → Luyện
tập → Bắt đầu → 30 lần Câu sau → 10 lần chọn đáp án rồi Câu sau → mở bảng câu hỏi, cuộn 15 lần → xuống nền rồi mở lại,
Tiếp tục → Rà soát & nộp → Nộp → Xem lại bài → ba bộ lọc → cuộn danh sách 15 lần → Về thư viện → Lịch sử thi → mở lần
thi vừa nộp. Khung hình: `adb shell dumpsys gfxinfo <gói>`; bộ nhớ: `dumpsys meminfo <gói>` (TOTAL PSS).

| Mã | Thao tác |
| --- | --- |
| `app.ready` | Mở app tới khi Thư viện hiện, tính từ lúc tiến trình bắt đầu (lần đầu: có tạo hai đề mẫu) |
| `library.import` | Thêm đề chuẩn (chép vào app, đọc nghiêm, ghi kho) |
| `preExam.read` | Mở Trước khi thi (đọc nghiêm đề) |
| `attempt.start` | Bắt đầu tới khi có câu 1: đọc lại nghiêm (`.read`), tạo đề + phiên (`.compose`, luồng giao diện), dấu vân tay 2.000 câu (`.fingerprints`, nền), model màn làm bài (`.model`, luồng giao diện) |
| `attempt.command` | Một lệnh làm bài (đổi câu, chọn đáp án) cùng dựng trạng thái màn hình, luồng giao diện |
| `attempt.background.snapshot` | Xuống nền: chụp phiên dở, luồng giao diện |
| `draft.save` | Ghi phiên dở (mã hoá + Room) |
| `attempt.submit` | Nộp: chấm, payload, dựng Xem lại, Kết quả hiện; luồng giao diện |
| `attempt.save` | Lưu lần thi sau khi Kết quả đã hiện (mã hoá + Room) |
| `review.command` | Đổi bộ lọc Xem lại (dựng danh sách 2.000 dòng), luồng giao diện |
| `history.open` | Mở Kết quả của lần thi cũ: giải mã payload, đọc nghiêm đề, dựng Xem lại (`.model`, nền) |

## 2026-10-22 · A4, emulator (trước khi đo trên máy thật)

Máy: emulator `examsuite` (Pixel 7, Android 15 arm64, `sdk_gphone64_arm64`) trên Mac Apple M4 Pro, 24 GB. "Trước": `main`
3612c41 cộng nhật ký đo; "Sau": nhánh A4. Một lượt mỗi cột (lệnh lặp lại: trung bình / chậm nhất).

| Mã | Ngân sách | Trước | Sau | Ghi chú |
| --- | --- | --- | --- | --- |
| `app.ready` | ≤ 1.000 ms | 1.144 ms | 1.102 ms | gồm khởi động của test và tạo đề mẫu lần đầu; khởi động lạnh của bản phát hành (Android tự đo, `am start -W`): 417 ms |
| `library.import` | ≤ 1.500 ms | 917 ms | 998 ms | |
| `preExam.read` | (như Bắt đầu) ≤ 1.500 ms | 445 ms | 464 ms | |
| `attempt.start` | ≤ 1.500 ms | 963 ms | 944 ms | sau: gồm 266 ms dấu vân tay trên nền |
| `attempt.start.compose` + `.model` (luồng giao diện) | ≤ 100 ms | 15 ms | 13 ms | |
| `attempt.command` | ≤ 16 ms | 1,1 / 5,4 ms | 0,9 / 3,8 ms | |
| `attempt.background.snapshot` (luồng giao diện) | ≤ 100 ms | **366 ms** | 0,1 ms | |
| `draft.save` | — | 50 ms (luồng giao diện) | 187 ms (nền) | |
| `attempt.submit` (luồng giao diện) | ≤ 100 ms | **878 ms** | 31 ms | |
| `attempt.save` | Nộp bài ≤ 500 ms | **567 ms** (luồng giao diện) | 100 ms (nền) | |
| `review.command` | ≤ 50 ms | 17 / 28 ms | 21 / 31 ms | |
| `history.open` | ≤ 1.500 ms | — | 908 ms | dựng Xem lại trên nền: 209 ms |
| Bộ nhớ khi làm bài, Xem lại (TOTAL PSS) | ≤ 400 MB | — | 120–133 MB | |

Mục vượt và cách sửa: dấu vân tay câu (SHA-256 của 2.000 câu) được tính ba lần trên luồng giao diện khi nộp (payload,
Xem lại, lưu lần thi) và một lần khi xuống nền. Sửa: `ExamSession.fingerprints` tính một lần, app gọi trước trên luồng nền
lúc Bắt đầu và khi khôi phục phiên dở; `ReviewItems` nhận dấu vân tay đã tính; mã hex tự dựng thay `String.format` từng
byte (một lượt 2.000 câu từ ~360 ms xuống ~190 ms trên emulator); mã hoá, giải mã lần thi và phiên dở của `ExamLibrary`
chạy trên `Dispatchers.Default`; Kết quả lần thi cũ dựng trên nền. Khung hình trên emulator (vẽ bằng GPU của Mac qua lớp
giả lập) không đại diện cho điện thoại nên không ghi ở đây.
