# Đề lớn: ngân sách hiệu năng

Thẩm quyền: tài liệu này (giai đoạn 5), cụ thể hoá tiêu chí v1 "Đề 2.000 câu có ảnh vẫn mở và cuộn mượt" của
[overview.md](overview.md) và [plan-macos-v1.md](plan-macos-v1.md). Quy mô đề chuẩn, bảng ngân sách và cách dùng
giới hạn chặn: Nt0 chốt 2026-10-16 (mục cuối).

## Đề chuẩn để đo

Sinh ra khi chạy test (không commit), cùng một bộ sinh có seed cố định:

| Thuộc tính | Giá trị |
| --- | --- |
| Số câu / số phần | 2.000 câu / 20 phần × 100 câu |
| Loại câu | 80% một đáp án, 20% nhiều đáp án; 4 lựa chọn, 5% câu có 8–12 lựa chọn |
| Chữ | Câu 200–600 ký tự tiếng Việt có dấu, có Markdown đậm/nghiêng; giải thích 50% câu |
| Ảnh | 10% câu (200 ảnh) PNG 1600×1000, khoảng 300 KB mỗi ảnh, không trùng (gói khoảng 60 MB) |
| Thư viện | 50 đề, trong đó 5 đề chuẩn; 200 lần thi trong Lịch sử thi, 20 lần của đề chuẩn với 2.000 câu |

`scripts/gen_large_exam.py` (công cụ dev, không thư viện ngoài) ghi cùng đề ra `dist/` thành `.exam` để mở tay. Bộ
sinh phía test là `StandardExam` (`Packages/ExamKit/Sources/LargeExamSupport`); hai bên cùng thuật toán và so cùng một
dấu vân tay cố định (`gen_large_exam.py --check`, `StandardExamTests`), nên là **cùng một đề** (seed mặc định 20261016).
Ảnh là nhiễu xám không nén được, xen kẽ 1 bit (~196 KB) và 2 bit (~392 KB), trung bình ~300 KB.

Số đo đã có (Debug, Mac của người điều phối): đọc nghiêm đề 2.000 câu không ảnh khoảng 400 ms (giai đoạn 2); kiểm đề
khoảng 13–15 ms, dựng cây đề khoảng 25 ms, gõ khoảng 0,01 ms (PR #34). Lọc cây đề khi đang tìm: trước sửa khoảng 32 ms
mỗi lần gõ (review độc lập #34); sau sửa (`TreeSearchIndex`, PR #34) khoảng 1,2–1,3 ms mỗi lần gõ, lần tìm đầu
khoảng 28–35 ms (dựng chỉ mục; bước 9 chuyển ra nền khi mở cửa sổ, xem dưới bảng Ngân sách).

## Ngân sách

"Main actor" = luồng giao diện; khoảng chặn dài nhất đo bằng nhịp main actor như `MainActorHeartbeat` của
LibraryDataTests. Ngân sách tính cho **build Release** trên Mac Apple silicon của người điều phối; test trong
`swift test` (Debug) dùng **giới hạn chặn** rộng hơn (cột cuối) để bắt hồi quy mà không chập chờn.

| Thao tác (đề chuẩn) | Ngân sách Release | Main actor chặn tối đa | Giới hạn chặn trong test (Debug) |
| --- | --- | --- | --- |
| Mở app với thư viện 50 đề tới khi Thư viện hiện | ≤ 1 s | ≤ 50 ms | — (đo tay) |
| Thêm một đề chuẩn (đọc nghiêm, nền) tới khi thẻ Sẵn sàng | ≤ 1,5 s | ≤ 50 ms | ≤ 6 s; chặn ≤ 200 ms (như test hiện có) |
| Làm mới trạng thái 50 đề | ≤ 5 s | ≤ 50 ms | chặn ≤ 200 ms |
| Bắt đầu (đọc lại nghiêm + tạo đề + model phiên) tới khi câu 1 hiện | ≤ 1,5 s | ≤ 100 ms | ≤ 6 s |
| Đổi câu (←/→, chữ cái, bấm ô bảng câu hỏi) | ≤ 16 ms (một khung hình) | ≤ 16 ms | ≤ 50 ms |
| Cuộn bảng câu hỏi 2.000 ô, cuộn danh sách Xem lại | không giật thấy được | ≤ 16 ms mỗi khung hình | — (đo tay, Instruments nếu cần) |
| Nộp bài: chấm + lưu lần thi + Kết quả | ≤ 500 ms | ≤ 100 ms | ≤ 2 s |
| Mở Kết quả/Xem lại của lần thi cũ (giải mã payload, dấu vân tay, đọc đề) | ≤ 1,5 s | ≤ 100 ms | ≤ 6 s |
| Đổi bộ lọc Xem lại | ≤ 50 ms | ≤ 50 ms | ≤ 200 ms |
| Soạn đề: mở cửa sổ (dựng cây đề) | ≤ 100 ms | ≤ 100 ms | ≤ 300 ms |
| Soạn đề: mỗi lần gõ, kể cả khi ô tìm có chữ | ≤ 8 ms | ≤ 8 ms | ≤ 16 ms |
| Soạn đề: kiểm đề (nền, sau khi ngừng gõ) | ≤ 50 ms | 0 (chạy nền) | ≤ 200 ms |
| Soạn đề: lưu đề chuẩn có ảnh | ≤ 3 s | ≤ 100 ms | ≤ 10 s |
| PDF kết quả không có phần xem lại | ≤ 1 s | ≤ 100 ms | ≤ 3 s |
| PDF kết quả có Xem lại tất cả 2.000 câu | ≤ 30 s, có tiến độ và Huỷ | ≤ 100 ms | ≤ 120 s |
| PDF đề chuẩn có đáp án (Admin) | ≤ 30 s, có tiến độ và Huỷ | ≤ 100 ms | ≤ 120 s |
| Bộ nhớ khi làm bài đề chuẩn (ảnh giải mã khi cần) | ≤ 400 MB | — | — (đo tay, Activity Monitor) |
| Bộ nhớ đỉnh khi xuất PDF 2.000 câu | ≤ 1 GB | — | — (đo tay) |

**Bước 9 (2026-10-18): mọi mục đo được đạt ngân sách Release** (số ở
[large-exam-measurements.md](../notes/large-exam-measurements.md), commit 328b956). Mục từng vượt: lần gõ đầu vào ô tìm
của Soạn đề dựng chỉ mục tìm của cả đề trên main actor (~43 ms Release, ~44–48 ms Debug); nay bộ soạn đề dựng chỉ mục
**ngoài main actor khi mở cửa sổ** (và sau thêm/xoá/sắp xếp; thay đổi trong lúc dựng được áp lại), lần gõ đầu chỉ lọc:
**0,23 ms Release, 0,56 ms Debug**; test so giới hạn chặn 16 ms (không còn lỗi đã biết). Gõ vào ô tìm trước khi dựng
xong (trong ~40 ms đầu sau khi mở cửa sổ) thì dựng ngay như trước. Đo thêm ở bước 9 (chỉ ghi số): main actor chặn khi
nộp bài **~84 ms Release / ~610 ms Debug** (nộp chạy đồng bộ trên main actor, sát ngân sách 100 ms ở Release; giữ
nguyên, xem dưới); đường In: mở PDF + tạo thao tác In trên main actor ~1,4 ms;
in PDF "Xem lại tất cả" 1.168 trang ra file (`NSPrintOperation.run`, chạy trên main actor; chỉ đo trong
`measure_large.sh`) ~4,8 s Release (trong app
AppKit chạy nó trong vòng lặp của bảng tiến độ In, test tay).

**Cỡ file PDF (Nt0 chốt 2026-10-18: giữ ảnh 2× không mất dữ liệu, đặt ngân sách cỡ file).** Ảnh nhúng ở 2× cỡ hiển thị (ảnh đề chuẩn 1600×1000 hiện
448×280 pt, nhúng 896×560 px, ~144 ppi trên giấy), nén không mất (Flate) như Core Graphics mặc định. Đo bước 9
(2026-10-18, cùng đề 2.000 câu, 200 ảnh; "ảnh thật" là hai ảnh minh hoạ của đề mẫu Thư viện, 1600×900 và 1600×1212,
mỗi bản sửa một điểm ảnh để Core Graphics không gộp; thử nghiệm không commit):

| PDF | Ảnh nhiễu (đề chuẩn) | Ảnh thật |
| --- | --- | --- |
| Kết quả, Xem lại tất cả (1.168 trang), hiện tại | 108 MB | — |
| Đề có đáp án (1.167 trang), hiện tại 2× | 105 MB | 27,2 MB |
| Đề chỉ đề (1.077 trang), hiện tại 2× | 101 MB | 22,8 MB |
| Đề có đáp án, ảnh 1× (~72 ppi) | 29,9 MB (−72%) | 15,9 MB (−42%) |
| Đề có đáp án, 2× + JPEG chất lượng 0,8 | 86,8 MB (−17%) | 22,7 MB (−16%) |
| Đề có đáp án, 1× + JPEG 0,8 | 24,5 MB (−77%) | 13,6 MB (−50%) |

Phần chữ (không ảnh) ước ~12 MB với đề có đáp án, ~8 MB chỉ đề. Ảnh nhiễu của đề chuẩn không nén được nên là trường hợp
xấu nhất; ảnh thật (sơ đồ, ảnh chụp màn hình) nhỏ hơn ~4 lần. Phương án cho Nt0: (A) giữ 2× không mất (nét nhất khi
in; đề thật cỡ ~25 MB); (B) 1,5× (~108 ppi; ước ~20 MB với ảnh thật, −25%, chưa đo); (C) 1× (72 ppi, mờ thấy được khi in ảnh có chữ nhỏ);
(D) JPEG khi nhúng (lợi ít với sơ đồ, ảnh chữ bị nhoè quanh nét); (E) đặt ngân sách cỡ file (ví dụ ≤ 50 MB với đề thật)
mà không đổi gì bây giờ. **Nt0 chọn (A) + (E).** Ngân sách cỡ file với đề chuẩn (số đo bước 9 + ~20%;
`PDFSizeBudget` của LargeExamSupport; test so ở mọi lần chạy vì cỡ file không phụ thuộc máy):

| PDF (đề chuẩn) | Đo bước 9 | Ngân sách |
| --- | --- | --- |
| Kết quả, Xem lại tất cả 2.000 câu | 108 MB | ≤ 130 MB |
| Đề có đáp án | 105 MB | ≤ 126 MB |
| Đề chỉ đề (chỉ đo trong `measure_large.sh`) | 100 MB | ≤ 121 MB |

Nộp bài (~84 ms main actor Release, sát ngân sách chặn 100 ms): Nt0 chốt 2026-10-18 giữ nguyên, chỉ theo dõi số
`session.submit.mainActor`.

## Cách đo

- **Swift Testing + `ContinuousClock`** như `ValidationPerformanceTests` và `BackgroundReadingTests` hiện có (Swift
  Testing không có `measure`): helper `Timing` (LargeExamSupport) lặp 3 lần (thao tác nặng: đọc/ghi gói, thêm đề, Bắt
  đầu, nộp, mở lần thi cũ, lưu) hoặc 5 lần, in dòng `Timing: <mã> | <thao tác> | min | median | runs | budget | limit |
  <Debug|Release>`; `#expect` so **lần nhanh nhất** với cột "Giới hạn chặn" (phương án đã chốt 4), trung vị là số báo
  cáo; mẫu gồm nhiều biến thể (các chữ tìm) so biến thể chậm nhất. Thao tác lặp lại (đổi câu, gõ) đo trung bình một sự
  kiện trong một đợt và in thêm sự kiện chậm nhất. Phần dựng kho, đề, lần thi nằm ngoài vùng đo. Bảng ngân sách nằm ở
  một chỗ (`TimingBudget`). Chạy trong `scripts/check.sh` (Debug) như mọi test; test nặng có `.timeLimit`; test đo
  chạy việc nặng trên main actor thì chung một suite `.serialized`.
- **Thư viện chuẩn** (dòng Thư viện của bảng đề chuẩn): 5 đề chuẩn (khác id) + 45 đề nhỏ (20 câu, 2 ảnh) và 200 lần
  thi (20 của một đề chuẩn), dựng trong test (`LibraryScaleTimingTests`) để đo làm mới 50 đề và mở lần thi cũ.
- **Release**: `scripts/measure_large.sh` chạy cùng các test đo với `EXAMSUITE_MEASURE_RECORD=1 swift test -c release -Xswiftc -enable-testing
  -Xswiftc -DDEBUG --filter Timing` (`-DDEBUG` chỉ để vài test dùng code riêng của Debug biên dịch được; code đó không
  nằm trên đường đo, bản đo vẫn tối ưu) và ghi bảng số (trung vị so với ngân sách) vào
  [large-exam-measurements.md](../notes/large-exam-measurements.md); chạy ở bước đo, bước tối ưu và cuối giai đoạn
  (không chặn merge). `EXAMSUITE_MEASURE_RECORD=1` bật thêm các mục chỉ ghi số mà `swift test` thường bỏ qua (in thật
  ra file, PDF đề chỉ đề; review độc lập #55).
- Phần không đo được bằng `swift test` (khung hình thật, cuộn, mở app, bộ nhớ): test tay trên bản Release với đề chuẩn,
  ghi số vào plan. XCUITest chỉ build Debug (chế độ cô lập chỉ có ở Debug) nên không dùng để đo ngân sách Release; có
  thể thêm một test `XCTClockMetric` cho Bắt đầu → câu 1 ở Debug để theo dõi xu hướng.
- Main actor chặn: đo bằng nhịp main actor trong lúc thao tác (như `MainActorHeartbeat`).

## Phương án đã chốt (Nt0 duyệt 2026-10-16)

1. **Quy mô đề chuẩn:** 2.000 câu, 10% câu có ảnh (mục Đề chuẩn để đo). Người dùng có đề lớn hơn thì nâng đề chuẩn trước khi
   tối ưu.
2. **Bảng ngân sách** như mục Ngân sách.
3. **Chặn merge:** giới hạn chặn (Debug, rộng) làm test thất bại; ngân sách Release chỉ đo và ghi số vào plan ở bước tối
   ưu và cuối giai đoạn, không chặn merge.
4. **Cách so giới hạn chặn** (Nt0 duyệt 2026-10-16, review #39): test so **lần nhanh nhất** của N lần (3 với thao tác
   nặng, 5 với thao tác nhẹ) với giới hạn chặn Debug, để tải máy (các suite song song, Docker của `verify_local.sh`)
   không làm test chập chờn; trung vị vẫn in và là số so với ngân sách trong báo cáo Release.
