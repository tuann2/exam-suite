# Số đo đề lớn, bản iOS

Đề chuẩn của [large-exams.md](../product/large-exams.md) (2.000 câu, 200 ảnh, gói 60 MB; `python3
scripts/gen_large_exam.py --out dist/`), đo trên **simulator, bản Debug** (QI15 của plan-ios-v1.md, như bản Android:
Nt0 chốt 2026-10-23; máy thật ở J3 nếu bản beta thấy chậm). Bản Debug không được tối ưu khi biên dịch, nên chậm hơn bản
Release. Simulator chạy trên CPU của Mac, nhanh hơn iPhone. Vì vậy số dưới đây chỉ để so tương đối và tìm mục vượt
ngân sách, không phải số của máy thật. Ngân sách lấy từ bảng của large-exams.md (cột "Ngân sách Release"; đổi câu so với
một khung hình 16 ms). Số chỉ ghi, không chặn merge. Mục mới nhất ở trên.

Cách đo: một test tạm trong `MobileFeatureTests` (không commit, như lượt đi của bản Android) chạy lượt đi trên model và
màn của bản iOS, đồng hồ `ContinuousClock` trên main actor:

| Mã | Thao tác |
| --- | --- |
| `app.ready` | Tạo model của app, tải kho, tạo hai đề mẫu lần đầu (`MobileAppModel`, `LibraryModel.start`) |
| `library.import` | Thêm đề chuẩn từ app Tệp (`MobileAppModel.open`: kiểm file, đọc nghiêm, ghi kho, chọn đề) |
| `library.view` | Dựng màn Thư viện lần đầu trong cửa sổ (lần dựng SwiftUI đầu tiên của tiến trình) / lần sau (`.warm`) |
| `preExam.read` | Mở Trước khi thi (đọc nghiêm đề) |
| `attempt.start` | Bắt đầu: đọc lại nghiêm, tạo đề và phiên, model màn làm bài |
| `attempt.view` | Dựng màn làm bài (câu 1) trong cửa sổ |
| `navigator.view` | Dựng bảng câu hỏi 2.000 ô |
| `attempt.command` | Một lệnh làm bài (Câu sau, chọn đáp án) **kèm dựng lại màn** đang hiện; 60 lần Câu sau, 15 lần chọn |
| `memory.attempt` | Bộ nhớ của tiến trình (`phys_footprint`) sau 60 câu |
| `attempt.submit` | Rà soát rồi Nộp: chấm, lưu lần thi, Kết quả |
| `review.open` | Mở Xem lại bài (dựng 2.000 dòng) |
| `review.command` | Đổi bộ lọc Xem lại (ba bộ lọc) |
| `history.open` | Mở lần thi vừa nộp từ Lịch sử thi tới Xem lại bài (giải mã payload, đọc nghiêm đề) |

## 2026-10-31 · I3, simulator

Máy: simulator iPhone 17, iOS 26.1, trên Mac Apple silicon; Xcode 27.1; bản Debug. Hai lượt mỗi cột (đổi câu ở cột
Sau: năm lượt), ghi lượt chậm hơn (lệnh lặp lại: trung bình / chậm nhất). "Trước": nhánh I3 trước khi sửa; "Sau": sau
khi ảnh của câu giải mã ngoài main thread (`QuestionImage`).

| Mã | Ngân sách (large-exams.md) | Trước | Sau | Ghi chú |
| --- | --- | --- | --- | --- |
| `app.ready` | Mở app ≤ 1 s | 81 ms | 86 ms | lần mở đầu: kho trống, hai đề mẫu (chưa phải thư viện 50 đề) |
| `library.import` | Thêm đề ≤ 1,5 s | 507 ms | 513 ms | |
| `library.view` | — | 2.907 ms / 86 ms | 2.960 ms / 81 ms | lần đầu gồm khởi động SwiftUI của tiến trình (test chạy trong `xctest`, không phải app); lần sau 86 ms |
| `preExam.read` | (trong Bắt đầu ≤ 1,5 s) | 747 ms | 588 ms | |
| `attempt.start` | Bắt đầu ≤ 1,5 s | 521 ms | 530 ms | cộng `attempt.view`: 653 ms trước, 710 ms sau |
| `attempt.view` | (trong Bắt đầu) | 132 ms | 180 ms | |
| `navigator.view` | — | 72 ms | 77 ms | |
| `attempt.command` | Đổi câu ≤ 16 ms | 9,3 / **103 ms** | 5,0–6,3 / 14,4–15,1 ms | trước: **vượt**, câu có ảnh giải mã đồng bộ trong `body`; sau: ba lượt khi máy rảnh. Hai lượt khi máy bận chậm rải rác cả ở câu không có ảnh (10,6 / 264 ms; 11,9 / 62 ms) |
| `memory.attempt` | Bộ nhớ ≤ 400 MB | 129 MB | 127 MB | simulator, chỉ để so |
| `attempt.submit` | Nộp ≤ 500 ms | **762 ms** | **763 ms** | Debug; giới hạn của test Debug macOS là 2 s |
| `review.open` | Mở Xem lại ≤ 1,5 s | 552 ms | 579 ms | |
| `review.command` | Đổi bộ lọc ≤ 50 ms | 24,6 / 36,8 ms | 25,0 / 37,5 ms | |
| `history.open` | Mở lần thi cũ ≤ 1,5 s | 997 ms | 1.004 ms | |

Sửa: ảnh của câu (màn làm bài, chi tiết Xem lại bài) giải mã ngoài main thread khi câu đổi (`QuestionImage`,
`preparingForDisplay`), như `.task(id: data)` của bản macOS; ảnh hỏng hiện "Không hiện được ảnh của câu này" như macOS.
Nộp bài 762 ms ở bản Debug: cùng code chấm và lưu với bản macOS (test `Timing` của macOS đo ở Debug với giới hạn 2 s);
chưa sửa, đo lại trên máy thật ở GI3 nếu thấy chậm.
