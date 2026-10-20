# Số đo đề lớn (Release)

Ghi bởi `scripts/measure_large.sh`; mục mới nhất ở trên. Ngân sách và cách đo: [large-exams.md](../product/large-exams.md). Số Release chỉ ghi, không chặn merge (phương án 3); giới hạn chặn Debug nằm trong các test `Timing` chạy ở `scripts/check.sh`. "Trung vị" so với ngân sách; "Nhanh nhất" là số các test so với giới hạn chặn Debug (Nt0 chốt 2026-10-16; riêng mẫu nhiều biến thể như chữ tìm thì so "Chậm nhất"). "Sự kiện chậm nhất" là một sự kiện đơn lẻ (đổi câu, phím) chậm nhất. Mục "thành phần" là một phần của thao tác người dùng, mang ngân sách của thao tác đó. Mục không có ở đây (mở app, cuộn, bộ nhớ) đo tay. Tên mục PDF ghi số trang và cỡ file.

## 2026-10-18 · commit b1c3e99 (thay đổi chưa commit chỉ là tài liệu: CHANGELOG, plan giai đoạn 6; số đo cuối giai đoạn 5, bước 10)

Máy: Apple M4 Pro, 24 GB RAM, macOS 26.6.2, Xcode 27.0. Lệnh: `scripts/measure_large.sh` (`EXAMSUITE_MEASURE_RECORD=1 swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter Timing`).

| Thao tác (đề chuẩn) | Mã | Ngân sách Release | Trung vị | Nhanh nhất | Chậm nhất | Sự kiện chậm nhất | Số lần | So ngân sách |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tạo đề + phiên, lõi ExamKit (thành phần của Bắt đầu) | `session.compose` | ≤ 1.500 ms | 1,59 ms | 1,55 ms | 1,73 ms | — | 5 | đạt |
| Ghi gói đề chuẩn có ảnh (thành phần của Lưu đề) | `examfile.write` | ≤ 3.000 ms | 886 ms | 886 ms | 897 ms | — | 3 | đạt |
| Đọc nghiêm gói đề chuẩn (thành phần của Thêm đề, Bắt đầu) | `examfile.read` | ≤ 1.500 ms | 218 ms | 215 ms | 219 ms | — | 3 | đạt |
| Làm mới trạng thái 50 đề (5 đề chuẩn, mọi file đã đổi) | `library.refresh` | ≤ 5.000 ms | 549 ms | 511 ms | 603 ms | — | 3 | đạt |
| Làm mới 50 đề: main actor chặn dài nhất | `library.refresh.mainActor` | ≤ 50 ms | 13,67 ms | 12,11 ms | 14,17 ms | — | 3 | đạt |
| Mở Kết quả + Xem lại của lần thi cũ (payload, đọc đề; kho 50 đề, 200 lần thi) | `history.open` | ≤ 1.500 ms | 308 ms | 307 ms | 310 ms | — | 3 | đạt |
| PDF kết quả không có phần xem lại | `report.results` | ≤ 1.000 ms | 21,77 ms | 20,86 ms | 69,46 ms | — | 3 | đạt |
| PDF kết quả có Xem lại tất cả 2.000 câu (1168 trang, PDF 108 MB) | `report.results.reviewAll` | ≤ 30.000 ms | 12.503 ms | 12.332 ms | 12.824 ms | — | 3 | đạt |
| PDF kết quả có Xem lại tất cả: main actor chặn dài nhất | `report.results.reviewAll.mainActor` | ≤ 100 ms | 50,35 ms | 50,35 ms | 50,35 ms | — | 1 | đạt |
| In PDF kết quả Xem lại tất cả: mở PDF + tạo thao tác In (main actor) | `report.print.prepare` | ≤ 100 ms | 1,36 ms | 1,24 ms | 6,10 ms | — | 3 | đạt |
| In PDF kết quả Xem lại tất cả ra file (NSPrintOperation.run, main actor) | `report.print.run` | ≤ 30.000 ms | 4.815 ms | 4.815 ms | 4.815 ms | — | 1 | đạt |
| Bắt đầu (đọc lại nghiêm + tạo đề + model phiên) tới khi có câu 1 | `session.start` | ≤ 1.500 ms | 216 ms | 215 ms | 217 ms | — | 3 | đạt |
| Bắt đầu: main actor chặn dài nhất | `session.start.mainActor` | ≤ 100 ms | 8,61 ms | 7,51 ms | 9,29 ms | — | 3 | đạt |
| Đổi câu (model câu + lựa chọn + bảng câu hỏi 2.000 ô) | `session.navigate` | ≤ 16 ms | 0,47 ms | 0,46 ms | 0,48 ms | 0,69 ms | 3 | đạt |
| Nộp bài: chấm + lưu lần thi + Kết quả | `session.submit` | ≤ 500 ms | 83,40 ms | 82,06 ms | 86,91 ms | — | 3 | đạt |
| Nộp bài: main actor chặn dài nhất | `session.submit.mainActor` | ≤ 100 ms | 83,41 ms | 82,08 ms | 88,97 ms | — | 3 | đạt |
| Đổi bộ lọc Xem lại | `review.filter` | ≤ 50 ms | 5,95 ms | 5,95 ms | 6,08 ms | — | 5 | đạt |
| Thêm một đề chuẩn (đọc nghiêm, nền) tới khi Sẵn sàng | `library.import` | ≤ 1.500 ms | 213 ms | 210 ms | 217 ms | — | 3 | đạt |
| Thêm một đề chuẩn: main actor chặn dài nhất | `library.import.mainActor` | ≤ 50 ms | 6,32 ms | 6,32 ms | 6,33 ms | — | 3 | đạt |
| Soạn đề: mở cửa sổ (dựng cây đề) | `authoring.open` | ≤ 100 ms | 19,37 ms | 19,32 ms | 24,50 ms | — | 5 | đạt |
| Soạn đề: lần gõ đầu vào ô tìm (chỉ mục dựng nền khi mở cửa sổ) | `authoring.firstSearch` | ≤ 8 ms | 0,22 ms | 0,18 ms | 0,24 ms | — | 5 | đạt |
| Soạn đề: kiểm đề (nền) | `authoring.validate` | ≤ 50 ms | 7,62 ms | 7,56 ms | 8,54 ms | — | 5 | đạt |
| Soạn đề: mỗi lần gõ vào câu | `authoring.typing` | ≤ 8 ms | 0,05 ms | 0,05 ms | 0,06 ms | 0,24 ms | 5 | đạt |
| Soạn đề: gõ vào ô tìm (đổi chữ tìm, chỉ mục đã có) | `authoring.searchQuery` | ≤ 8 ms | 1,61 ms | 0,96 ms | 1,95 ms | — | 5 | đạt |
| Soạn đề: mỗi lần gõ khi ô tìm có chữ (gõ vào câu, lọc lại cây đề) | `authoring.searchTyping` | ≤ 8 ms | 1,01 ms | 1 ms | 1,01 ms | 1,08 ms | 5 | đạt |
| Soạn đề: lưu đề chuẩn có ảnh | `authoring.save` | ≤ 3.000 ms | 870 ms | 870 ms | 874 ms | — | 3 | đạt |
| PDF đề chuẩn có đáp án (Admin) (1167 trang, PDF 105 MB) | `report.exam.withAnswers` | ≤ 30.000 ms | 11.091 ms | 11.069 ms | 11.191 ms | — | 3 | đạt |
| PDF đề chuẩn có đáp án: main actor chặn dài nhất | `report.exam.withAnswers.mainActor` | ≤ 100 ms | 34,93 ms | 34,93 ms | 34,93 ms | — | 1 | đạt |
| PDF đề chuẩn chỉ đề (Admin) (1077 trang, PDF 100 MB) | `report.exam.questionsOnly` | ≤ 30.000 ms | 9.214 ms | 9.214 ms | 9.214 ms | — | 1 | đạt |

## 2026-10-18 · commit 328b956

Máy: Apple M4 Pro, 24 GB RAM, macOS 26.6.2, Xcode 27.0. Lệnh: `scripts/measure_large.sh` (`swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter Timing`).

| Thao tác (đề chuẩn) | Mã | Ngân sách Release | Trung vị | Nhanh nhất | Chậm nhất | Sự kiện chậm nhất | Số lần | So ngân sách |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tạo đề + phiên, lõi ExamKit (thành phần của Bắt đầu) | `session.compose` | ≤ 1.500 ms | 1,57 ms | 1,51 ms | 1,98 ms | — | 5 | đạt |
| Ghi gói đề chuẩn có ảnh (thành phần của Lưu đề) | `examfile.write` | ≤ 3.000 ms | 886 ms | 885 ms | 887 ms | — | 3 | đạt |
| Đọc nghiêm gói đề chuẩn (thành phần của Thêm đề, Bắt đầu) | `examfile.read` | ≤ 1.500 ms | 221 ms | 220 ms | 223 ms | — | 3 | đạt |
| Làm mới trạng thái 50 đề (5 đề chuẩn, mọi file đã đổi) | `library.refresh` | ≤ 5.000 ms | 581 ms | 571 ms | 596 ms | — | 3 | đạt |
| Làm mới 50 đề: main actor chặn dài nhất | `library.refresh.mainActor` | ≤ 50 ms | 14,11 ms | 11,86 ms | 16,79 ms | — | 3 | đạt |
| Mở Kết quả + Xem lại của lần thi cũ (payload, đọc đề; kho 50 đề, 200 lần thi) | `history.open` | ≤ 1.500 ms | 322 ms | 321 ms | 324 ms | — | 3 | đạt |
| PDF kết quả không có phần xem lại | `report.results` | ≤ 1.000 ms | 20,16 ms | 19,45 ms | 67,66 ms | — | 3 | đạt |
| PDF kết quả có Xem lại tất cả 2.000 câu (1168 trang, PDF 108 MB) | `report.results.reviewAll` | ≤ 30.000 ms | 12.627 ms | 12.573 ms | 12.891 ms | — | 3 | đạt |
| PDF kết quả có Xem lại tất cả: main actor chặn dài nhất | `report.results.reviewAll.mainActor` | ≤ 100 ms | 50,72 ms | 50,72 ms | 50,72 ms | — | 1 | đạt |
| In PDF kết quả Xem lại tất cả: mở PDF + tạo thao tác In (main actor) | `report.print.prepare` | ≤ 100 ms | 1,37 ms | 1,26 ms | 6,30 ms | — | 3 | đạt |
| In PDF kết quả Xem lại tất cả ra file (NSPrintOperation.run, main actor) | `report.print.run` | ≤ 30.000 ms | 4.825 ms | 4.825 ms | 4.825 ms | — | 1 | đạt |
| Bắt đầu (đọc lại nghiêm + tạo đề + model phiên) tới khi có câu 1 | `session.start` | ≤ 1.500 ms | 219 ms | 217 ms | 221 ms | — | 3 | đạt |
| Bắt đầu: main actor chặn dài nhất | `session.start.mainActor` | ≤ 100 ms | 10,37 ms | 6,33 ms | 11,40 ms | — | 3 | đạt |
| Đổi câu (model câu + lựa chọn + bảng câu hỏi 2.000 ô) | `session.navigate` | ≤ 16 ms | 0,49 ms | 0,48 ms | 0,49 ms | 0,66 ms | 3 | đạt |
| Nộp bài: chấm + lưu lần thi + Kết quả | `session.submit` | ≤ 500 ms | 83,18 ms | 82,73 ms | 83,65 ms | — | 3 | đạt |
| Nộp bài: main actor chặn dài nhất | `session.submit.mainActor` | ≤ 100 ms | 83,66 ms | 82,74 ms | 85,24 ms | — | 3 | đạt |
| Đổi bộ lọc Xem lại | `review.filter` | ≤ 50 ms | 6,04 ms | 5,92 ms | 6,09 ms | — | 5 | đạt |
| Thêm một đề chuẩn (đọc nghiêm, nền) tới khi Sẵn sàng | `library.import` | ≤ 1.500 ms | 216 ms | 214 ms | 222 ms | — | 3 | đạt |
| Thêm một đề chuẩn: main actor chặn dài nhất | `library.import.mainActor` | ≤ 50 ms | 6,37 ms | 6,35 ms | 6,88 ms | — | 3 | đạt |
| Soạn đề: mở cửa sổ (dựng cây đề) | `authoring.open` | ≤ 100 ms | 19,61 ms | 19,29 ms | 25,24 ms | — | 5 | đạt |
| Soạn đề: lần gõ đầu vào ô tìm (chỉ mục dựng nền khi mở cửa sổ) | `authoring.firstSearch` | ≤ 8 ms | 0,23 ms | 0,22 ms | 0,26 ms | — | 5 | đạt |
| Soạn đề: kiểm đề (nền) | `authoring.validate` | ≤ 50 ms | 7,61 ms | 7,58 ms | 8,44 ms | — | 5 | đạt |
| Soạn đề: mỗi lần gõ vào câu | `authoring.typing` | ≤ 8 ms | 0,05 ms | 0,05 ms | 0,06 ms | 0,23 ms | 5 | đạt |
| Soạn đề: gõ vào ô tìm (đổi chữ tìm, chỉ mục đã có) | `authoring.searchQuery` | ≤ 8 ms | 1,62 ms | 0,94 ms | 1,91 ms | — | 5 | đạt |
| Soạn đề: mỗi lần gõ khi ô tìm có chữ (gõ vào câu, lọc lại cây đề) | `authoring.searchTyping` | ≤ 8 ms | 1,02 ms | 1,01 ms | 1,02 ms | 1,19 ms | 5 | đạt |
| Soạn đề: lưu đề chuẩn có ảnh | `authoring.save` | ≤ 3.000 ms | 877 ms | 876 ms | 879 ms | — | 3 | đạt |
| PDF đề chuẩn có đáp án (Admin) (1167 trang, PDF 105 MB) | `report.exam.withAnswers` | ≤ 30.000 ms | 11.387 ms | 11.372 ms | 11.493 ms | — | 3 | đạt |
| PDF đề chuẩn có đáp án: main actor chặn dài nhất | `report.exam.withAnswers.mainActor` | ≤ 100 ms | 38,40 ms | 38,40 ms | 38,40 ms | — | 1 | đạt |
| PDF đề chuẩn chỉ đề (Admin) (1077 trang, PDF 100 MB) | `report.exam.questionsOnly` | ≤ 30.000 ms | 9.490 ms | 9.490 ms | 9.490 ms | — | 1 | đạt |

Ghi chú (bước 9 của plan giai đoạn 5): cùng máy, trước bước 9 (4d7448a, 2026-10-18) `authoring.firstSearch` trung vị
42,95 ms (**vượt** 5,4×; lần gõ đầu dựng chỉ mục tìm trên main actor); các mục khác trong khoảng ±5% số trên. Mục mới
của bước 9: `session.submit.mainActor`, `report.print.prepare`, `report.print.run`, `report.exam.questionsOnly`. Debug
(`swift test`, cùng máy): `authoring.firstSearch` 0,56 ms (trước 44–48 ms), `session.submit` ~604 ms, PDF Xem lại tất
cả 13,3 s, main actor chặn 64 ms. Cỡ file PDF với ảnh thật và các phương án nén: large-exams.md, mục Việc mở.

## 2026-10-16 · commit a92aed4

Máy: Apple M4 Pro, 24 GB RAM, macOS 26.6.2, Xcode 27.0. Lệnh: `scripts/measure_large.sh` (`swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter Timing`).

| Thao tác (đề chuẩn) | Mã | Ngân sách Release | Trung vị | Nhanh nhất | Chậm nhất | Sự kiện chậm nhất | Số lần | So ngân sách |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tạo đề + phiên, lõi ExamKit (thành phần của Bắt đầu) | `session.compose` | ≤ 1.500 ms | 1,51 ms | 1,49 ms | 1,74 ms | — | 5 | đạt |
| Ghi gói đề chuẩn có ảnh (thành phần của Lưu đề) | `examfile.write` | ≤ 3.000 ms | 885 ms | 881 ms | 887 ms | — | 3 | đạt |
| Đọc nghiêm gói đề chuẩn (thành phần của Thêm đề, Bắt đầu) | `examfile.read` | ≤ 1.500 ms | 224 ms | 219 ms | 228 ms | — | 3 | đạt |
| Làm mới trạng thái 50 đề (5 đề chuẩn, mọi file đã đổi) | `library.refresh` | ≤ 5.000 ms | 555 ms | 552 ms | 578 ms | — | 3 | đạt |
| Làm mới 50 đề: main actor chặn dài nhất | `library.refresh.mainActor` | ≤ 50 ms | 15,01 ms | 11,76 ms | 16,17 ms | — | 3 | đạt |
| Mở Kết quả + Xem lại của lần thi cũ (payload, đọc đề; kho 50 đề, 200 lần thi) | `history.open` | ≤ 1.500 ms | 315 ms | 314 ms | 318 ms | — | 3 | đạt |
| Bắt đầu (đọc lại nghiêm + tạo đề + model phiên) tới khi có câu 1 | `session.start` | ≤ 1.500 ms | 217 ms | 216 ms | 236 ms | — | 3 | đạt |
| Bắt đầu: main actor chặn dài nhất | `session.start.mainActor` | ≤ 100 ms | 10,27 ms | 6,97 ms | 10,28 ms | — | 3 | đạt |
| Đổi câu (model câu + lựa chọn + bảng câu hỏi 2.000 ô) | `session.navigate` | ≤ 16 ms | 0,45 ms | 0,45 ms | 0,45 ms | 0,58 ms | 3 | đạt |
| Nộp bài: chấm + lưu lần thi + Kết quả | `session.submit` | ≤ 500 ms | 84,39 ms | 81,74 ms | 84,49 ms | — | 3 | đạt |
| Đổi bộ lọc Xem lại | `review.filter` | ≤ 50 ms | 5,89 ms | 5,76 ms | 6,20 ms | — | 5 | đạt |
| Thêm một đề chuẩn (đọc nghiêm, nền) tới khi Sẵn sàng | `library.import` | ≤ 1.500 ms | 220 ms | 218 ms | 221 ms | — | 3 | đạt |
| Thêm một đề chuẩn: main actor chặn dài nhất | `library.import.mainActor` | ≤ 50 ms | 7,11 ms | 6,36 ms | 8,44 ms | — | 3 | đạt |
| Soạn đề: mở cửa sổ (dựng cây đề) | `authoring.open` | ≤ 100 ms | 20,21 ms | 19,83 ms | 24,27 ms | — | 5 | đạt |
| Soạn đề: lần gõ đầu vào ô tìm (dựng chỉ mục tìm) | `authoring.firstSearch` | ≤ 8 ms | 43,13 ms | 42,69 ms | 46,02 ms | — | 5 | **vượt** (5,4×) |
| Soạn đề: kiểm đề (nền) | `authoring.validate` | ≤ 50 ms | 7,53 ms | 7,48 ms | 8,45 ms | — | 5 | đạt |
| Soạn đề: mỗi lần gõ vào câu | `authoring.typing` | ≤ 8 ms | 0,06 ms | 0,05 ms | 0,06 ms | 0,57 ms | 5 | đạt |
| Soạn đề: gõ vào ô tìm (đổi chữ tìm, chỉ mục đã có) | `authoring.searchQuery` | ≤ 8 ms | 1,60 ms | 0,95 ms | 1,94 ms | — | 5 | đạt |
| Soạn đề: mỗi lần gõ khi ô tìm có chữ (gõ vào câu, lọc lại cây đề) | `authoring.searchTyping` | ≤ 8 ms | 1,01 ms | 1 ms | 1,04 ms | 1,20 ms | 5 | đạt |
| Soạn đề: lưu đề chuẩn có ảnh | `authoring.save` | ≤ 3.000 ms | 887 ms | 880 ms | 892 ms | — | 3 | đạt |

## 2026-10-16 · commit fab0eaa

Máy: Apple M4 Pro, 24 GB RAM, macOS 26.6.2, Xcode 27.0. Lệnh: `scripts/measure_large.sh` (`swift test -c release -Xswiftc -enable-testing -Xswiftc -DDEBUG --filter Timing`).

| Thao tác (đề chuẩn) | Mã | Ngân sách Release | Trung vị | Nhanh nhất | Số lần | So ngân sách |
| --- | --- | --- | --- | --- | --- | --- |
| Tạo đề + phiên, lõi ExamKit (thành phần của Bắt đầu) | `session.compose` | ≤ 1.500 ms | 1,50 ms | 1,49 ms | 5 | đạt |
| Ghi gói đề chuẩn có ảnh (thành phần của Lưu đề) | `examfile.write` | ≤ 3.000 ms | 901 ms | 887 ms | 3 | đạt |
| Đọc nghiêm gói đề chuẩn (thành phần của Thêm đề, Bắt đầu) | `examfile.read` | ≤ 1.500 ms | 221 ms | 220 ms | 3 | đạt |
| Bắt đầu (đọc lại nghiêm + tạo đề + model phiên) tới khi có câu 1 | `session.start` | ≤ 1.500 ms | 221 ms | 212 ms | 3 | đạt |
| Bắt đầu: main actor chặn dài nhất | `session.start.mainActor` | ≤ 100 ms | 11,38 ms | 11,18 ms | 3 | đạt |
| Đổi câu (model câu + lựa chọn + bảng câu hỏi 2.000 ô) | `session.navigate` | ≤ 16 ms | 0,43 ms | 0,43 ms | 3 | đạt |
| Nộp bài: chấm + lưu lần thi + Kết quả | `session.submit` | ≤ 500 ms | 81,55 ms | 80,43 ms | 3 | đạt |
| Mở Kết quả + Xem lại của lần thi cũ (payload, đọc đề) | `history.open` | ≤ 1.500 ms | 309 ms | 305 ms | 3 | đạt |
| Đổi bộ lọc Xem lại | `review.filter` | ≤ 50 ms | 5,94 ms | 5,90 ms | 5 | đạt |
| Thêm một đề chuẩn (đọc nghiêm, nền) tới khi Sẵn sàng | `library.import` | ≤ 1.500 ms | 217 ms | 216 ms | 3 | đạt |
| Thêm một đề chuẩn: main actor chặn dài nhất | `library.import.mainActor` | ≤ 50 ms | 7,58 ms | 7,58 ms | 3 | đạt |
| Soạn đề: mở cửa sổ (dựng cây đề) | `authoring.open` | ≤ 100 ms | 19,37 ms | 19,30 ms | 5 | đạt |
| Soạn đề: lần gõ đầu vào ô tìm (dựng chỉ mục tìm) | `authoring.firstSearch` | ≤ 8 ms | 42,50 ms | 41,62 ms | 5 | **vượt** (5,3×) |
| Soạn đề: kiểm đề (nền) | `authoring.validate` | ≤ 50 ms | 7,26 ms | 7,22 ms | 5 | đạt |
| Soạn đề: mỗi lần gõ vào câu | `authoring.typing` | ≤ 8 ms | 0,06 ms | 0,05 ms | 5 | đạt |
| Soạn đề: gõ vào ô tìm (đổi chữ tìm, chỉ mục đã có) | `authoring.searchQuery` | ≤ 8 ms | 1,58 ms | 0,93 ms | 5 | đạt |
| Soạn đề: mỗi lần gõ khi ô tìm có chữ (gõ vào câu, lọc lại cây đề) | `authoring.searchTyping` | ≤ 8 ms | 0,98 ms | 0,96 ms | 5 | đạt |
| Soạn đề: lưu đề chuẩn có ảnh | `authoring.save` | ≤ 3.000 ms | 862 ms | 859 ms | 3 | đạt |
