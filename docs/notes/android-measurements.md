# Số đo đề lớn, bản Android

Đề chuẩn của [large-exams.md](../product/large-exams.md) (2.000 câu, 200 ảnh, gói 60 MB; `python3
scripts/gen_large_exam.py --out dist/`), đo trên bản **debug** (chậm hơn bản phát hành: bản debug không được tối ưu
khi biên dịch trên máy). Ngân sách lấy từ bảng của large-exams.md: cột "Ngân sách Release" cho thời gian cả thao tác, cột
"Main actor chặn tối đa" cho phần chạy trên luồng giao diện (bảng dưới ghi rõ từng dòng). Số chỉ ghi, không chặn merge (v1
không có module đo, plan-android-v1.md Phần 4). Mục mới nhất ở trên.

Cách đo: bản debug ghi nhật ký `ExamSuiteTiming` (`vn.io.nt0.examsuite.attempt.Timing`; bản phát hành không ghi), đọc
bằng `adb logcat -s ExamSuiteTiming`. Lượt đi: mở `.exam` đề chuẩn từ app khác (Thêm đề, Trước khi thi mở ngay) → Luyện
tập → Bắt đầu → 30 lần Câu sau → 10 lần chọn đáp án rồi Câu sau → mở bảng câu hỏi, cuộn 15 lần → xuống nền rồi mở lại,
Tiếp tục → Rà soát & nộp → Nộp → Xem lại bài → ba bộ lọc → cuộn danh sách 15 lần → Về thư viện → Lịch sử thi → mở lần
thi vừa nộp. Khung hình: `adb shell dumpsys gfxinfo <gói>`; bộ nhớ: `dumpsys meminfo <gói>` (TOTAL PSS); mở app: `adb
shell am start -W` (TotalTime, Android tự đo tới khung hình đầu).

| Mã | Thao tác |
| --- | --- |
| `app.ready` | Mở app tới khi Thư viện sẵn sàng, tính từ lúc yêu cầu tạo tiến trình (Android 13+; một lần mỗi tiến trình) |
| `library.import` | Thêm đề chuẩn (chép vào app, đọc nghiêm, ghi kho) |
| `preExam.read` | Mở Trước khi thi (đọc nghiêm đề) |
| `attempt.start` | Bắt đầu tới khi có câu 1: đọc lại nghiêm (`.read`), tạo đề + phiên (`.compose`, luồng giao diện), model màn làm bài (`.model`, luồng giao diện) |
| `attempt.fingerprints` | Dấu vân tay 2.000 câu, trên nền ngay sau khi màn làm bài hiện |
| `attempt.command` | Một lệnh làm bài (đổi câu, chọn đáp án) cùng dựng trạng thái màn hình, luồng giao diện |
| `attempt.background.snapshot` | Xuống nền: chụp phiên dở, luồng giao diện |
| `draft.save` | Ghi phiên dở (mã hoá + Room) |
| `attempt.submit` | Nộp: chấm, payload, dựng Xem lại, Kết quả hiện; luồng giao diện |
| `attempt.save` | Lưu lần thi sau khi Kết quả đã hiện (mã hoá + Room) |
| `review.command` | Đổi bộ lọc Xem lại (dựng danh sách 2.000 dòng), luồng giao diện |
| `history.open` | Mở Kết quả của lần thi cũ: giải mã payload, đọc nghiêm đề, dựng Xem lại (`.model`, nền) |

## 2026-10-22 · A4, emulator (trước khi đo trên máy thật)

Máy: emulator `examsuite` (Pixel 7, Android 15 arm64, `sdk_gphone64_arm64`) trên Mac Apple M4 Pro, 24 GB; bản debug, lượt
đi chạy bằng test Compose tạm qua `am instrument`. "Trước": `main` 3612c41 cộng nhật ký đo; "Sau": nhánh A4 sau review
độc lập. Một lượt mỗi cột (lệnh lặp lại: trung bình / chậm nhất).

| Mã | Ngân sách (cột của large-exams.md) | Trước | Sau | Ghi chú |
| --- | --- | --- | --- | --- |
| `app.ready` | Mở app ≤ 1.000 ms (Release) | 1.144 ms | 1.156 ms | **chưa đại diện**: lần mở đầu (tạo hai đề mẫu, thư viện chưa phải 50 đề), tiến trình do test khởi động; bản phát hành mở lạnh (`am start -W`): 417 ms. Đo lại trên máy thật |
| `library.import` | Thêm đề ≤ 1.500 ms (Release) | 917 ms | 819 ms | |
| `preExam.read` | như Bắt đầu ≤ 1.500 ms (Release) | 445 ms | 460 ms | |
| `attempt.start` | Bắt đầu ≤ 1.500 ms (Release) | 963 ms | 646 ms | |
| `attempt.start.compose` + `.model` | Bắt đầu ≤ 100 ms (luồng giao diện) | 15 ms | 24 ms | |
| `attempt.fingerprints` | — (nền) | — | 266 ms | trước: tính lại khi nộp, khi xuống nền (dưới) |
| `attempt.command` | Đổi câu ≤ 16 ms (luồng giao diện) | 1,1 / 5,4 ms | 1,1 / 4,9 ms | |
| `attempt.background.snapshot` | không có dòng riêng; so với mức chặn 100 ms của Bắt đầu, Nộp bài | **366 ms** | 0,1 ms | |
| `draft.save` | — | 50 ms (luồng giao diện) | 73 ms (mã hoá trên nền) | |
| `attempt.submit` | Nộp bài ≤ 100 ms (luồng giao diện) | **878 ms** | 22 ms | |
| `attempt.save` | Nộp bài ≤ 500 ms (Release, cả thao tác) | **567 ms** (luồng giao diện) | 106 ms (mã hoá trên nền) | |
| `review.command` | Đổi bộ lọc ≤ 50 ms (Release, luồng giao diện) | 17 / 28 ms | 18 / 30 ms | |
| `history.open` | Mở lần thi cũ ≤ 1.500 ms (Release) | — | 858 ms | dựng Xem lại trên nền: 169 ms |
| Bộ nhớ khi làm bài, Xem lại (TOTAL PSS) | ≤ 400 MB | — | 120–133 MB | |

Mục vượt và cách sửa: dấu vân tay câu (SHA-256 của 2.000 câu) được tính ba lần trên luồng giao diện khi nộp (payload,
Xem lại, lưu lần thi) và một lần khi xuống nền. Sửa: `ExamSession.fingerprints` tính một lần; app tính trước trên nền ngay
sau khi màn làm bài hiện (phiên khôi phục đã có sẵn); `ReviewItems` nhận dấu vân tay đã tính; mã hex tự dựng thay
`String.format` từng byte (lượt chụp phiên dở, thực chất là một lượt dấu vân tay 2.000 câu: 366 ms → 190 ms, lượt đo
trung gian); `ExamLibrary` mã hoá, giải mã lần thi và phiên dở trên `Dispatchers.Default`; Kết quả lần thi cũ dựng trên
nền. Khung hình trên emulator (vẽ bằng GPU của Mac qua lớp giả lập) không đại diện cho điện thoại nên không ghi ở đây.
