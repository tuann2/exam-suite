# Execution Plan: Giai đoạn 1 · Lõi và định dạng file (cổng G1)

Date: 2026-10-15

## Status

Completed (2026-10-15, qua cổng G1)

## Outcome

`ExamKit` và `ExamFile` hoàn chỉnh và được test: model, kiểm tra lỗi đề, chấm
điểm, chọn câu có seed, phiên thi (state machine với Clock), đọc/ghi gói `.exam`
round-trip kể cả ảnh. Qua cổng G1: đề mẫu khớp schema, ghi rồi đọc lại không
mất dữ liệu, test chấm điểm xanh trên Linux và macOS.

## Context

- Thẩm quyền: docs/product/exam-format.md, scoring.md, exam-session.md; ADR 0002, 0006, 0008.
- Danh sách tình huống tham khảo (chỉ tên tình huống, không chép code): `ScorerTests`,
  `GraderTests`, `ExamComposerRandomTests`, `SimulatorSessionTests`, `ExamFormatFixtureTests`
  trong `src/Tests/` của Open Exam Suite.
- Mọi PR ở giai đoạn này là **rủi ro cao** → review độc lập (docs/process/review-and-merge.md).

## Scope

In scope: mọi thứ trong `Packages/ExamKit`. Out of scope: SwiftUI, SwiftData, PDF.

## Approach

Mỗi bước = một PR trên nhánh `feature/g1-<bước>`, nhỏ, có test đi kèm:

1. `ExamKit` model: `Exam`, `ExamSection`, `Question`, `Option`, `QuestionType`, `Codable`
   khớp schema (tên trường, `correct` mảng, `image` optional). Test decode 2 fixture.
2. `ExamValidator`: 4 ràng buộc liên trường trong exam-format.md + lỗi soạn đề
   (câu < 2 lựa chọn, thiếu đáp án, tiêu đề trống, trùng tên section). Test bằng `fixtures/invalid`.
3. `Scoring`: `score1000`, `percent`, `passed`, kết quả theo section. Test theo scoring.md.
4. `ExamComposer`: tất cả / theo section / N ngẫu nhiên, xáo câu, xáo đáp án, Fisher–Yates
   với seed UInt64, "luyện lại câu sai". Test lặp lại được với seed.
5. `ExamSession`: trạng thái và lệnh theo exam-session.md, `Clock` tiêm từ ngoài,
   cảnh báo 5/1 phút, tạm dừng, hết giờ. Test với clock giả.
6. `ExamFile`: đọc/ghi gói (ZIPFoundation), hash ảnh, bỏ qua entry lạ, từ chối
   `formatVersion` lớn hơn, khung chuyển đổi phiên bản. Test round-trip với ảnh, file hỏng, zip không có exam.json.
   Đọc có hai chế độ: **nghiêm** (bản Học viên) báo lỗi nêu tên và vị trí trường lạ ở mọi cấp;
   **dễ** (bản Admin) bỏ qua trường lạ. Test với `fixtures/invalid/unknown-top-level-field.json`
   và thêm fixture trường lạ ở cấp câu hỏi.
7. Đồng bộ `scripts/validate_exam.py` với `ExamValidator` (cùng fixture phải cùng kết luận).

## Risks And Recovery

- Quy tắc chấm điểm mơ hồ ở biên → dừng và hỏi, không tự quyết (scoring.md là thẩm quyền).
- ZIPFoundation trên Linux cần zlib: image `swift:6.1` đã có.
- Rollback: revert PR; không có dữ liệu người dùng.

## Progress

Bước 2, 3, 4, 6 làm song song bởi agent riêng trong worktree riêng; bước 5 xếp chồng
trên 3 và 4. Mỗi PR qua review độc lập bằng phiên agent mới (kết quả dán trong PR).

- [x] 1 Model + Codable — PR #2, merge 2026-10-15.
- [x] 2 ExamValidator — PR #5, merge 2026-10-15. Review: APPROVE sau 3 vòng (vòng 2 bắt một test giả xanh).
- [x] 3 Scoring — PR #3, merge 2026-10-15. Review: APPROVE vòng 1.
- [x] 4 ExamComposer — PR #4, merge 2026-10-15. Review: APPROVE vòng 1.
- [x] 5 ExamSession — PR #6, merge 2026-10-15, phụ thuộc #3 và #4. Review: REQUEST CHANGES (3 lỗi, đồng hồ hệ thống lách được) → sửa, chuyển sang đồng hồ đơn điệu → APPROVE.
- [x] 6 ExamFile đọc/ghi — PR #7, merge 2026-10-15. Review: REQUEST CHANGES (writer chặn lưu khi thiếu ảnh, trái exam-format.md; zip bomb 1 GiB nạp hết vào RAM) → sửa, thêm giới hạn kích thước, từ chối entry trùng, chặn `media/../` → APPROVE.
- [x] 7 Đồng bộ và tích hợp — merge 2026-10-15.
  - 7a (PR #10): `validate_exam.py` cùng kết luận với ExamValidator; `fixtures/expected-verdicts.json` ràng buộc cả script (parity) lẫn test Swift. Review: REQUEST CHANGES (chỉ tài liệu) → APPROVE. Bộ thử 447 đề biên của reviewer không lệch kết luận.
  - 7b (PR #11): chế độ nghiêm gọi ExamValidator và từ chối khoá trùng, `null`, dấu phẩy thừa (StrictJSON); trần độ sâu JSON 32; ExamFileVerdictTests buộc ExamFile khớp mọi nhãn; Admin đọc bằng reader/writer mới và hiện "Bản Học viên sẽ từ chối đề này". Review: APPROVE, kèm 2 rủi ro (crash JSON lồng sâu, Admin báo sai "không lỗi") → sửa → APPROVE.
- [ ] (tuỳ chọn, chuyển sang giai đoạn sau) SwiftLint/SwiftFormat; thay đề mẫu bằng đề thật của người dùng thử
- [x] Cổng G1 — 2026-10-15: Nt0 chạy `scripts/check.sh` trên Mac, cài hai app Release vào /Applications, mở thử bản Admin với đề mẫu, đề sai đáp án và file hỏng, rồi duyệt.

Gộp thử cả 5 nhánh bước 2–6 (2026-10-15): không xung đột git; một xung đột ngữ nghĩa
(test phân loại fixture của #5 với fixture mới của #7) đã sửa trong #5. Cây gộp:
sau vòng sửa của #7, gộp cả 6 nhánh (kèm PR tài liệu này): 224 test xanh macOS (148 ExamKit + 76 ExamFile) và Linux, schema từ chối đủ 11 fixture sai.

Thứ tự merge đề xuất: #3, #4, #6 (sau khi #3 và #4 vào main, diff của #6 chỉ còn bước 5),
#5, #7. Mọi PR merge bằng merge commit (không squash) để PR xếp chồng giữ lịch sử.

## Decisions

- 2026-10-15 (bước 1): `OptionID` là struct riêng (một chữ A–Z) thay vì `String`, để chấm điểm và xáo đáp án không nhận nhầm chuỗi bất kỳ; giải mã mã sai ném `DecodingError`.
- 2026-10-15 (bước 1): model ghi UUID chữ thường và luôn ghi `hideAnswers` tường minh; `JSONEncoder` dùng `sortedKeys + prettyPrinted + withoutEscapingSlashes` để file ổn định khi diff. Model không kiểm `formatVersion` (việc của ExamFile, bước 6) và không kiểm ràng buộc liên trường (bước 2).
- 2026-10-15 (bước 1, sau review độc lập): đổi `Section` → `ExamSection` để không đụng `SwiftUI.Section` ở các view import cả ExamKit lẫn SwiftUI; `ExamFileFormat.currentVersion` tham chiếu `Exam.currentFormatVersion` (một nguồn sự thật); test so sánh JSON dùng `JSONCompare` viết tay vì `NSDictionary.isEqual` sai trên Linux.
- 2026-10-15 **Nt0 chốt trường lạ:** bản Học viên từ chối đề có trường lạ; bản Admin bỏ qua trường lạ (không giữ khi lưu). Đã ghi vào exam-format.md (mục Trường lạ) và ADR 0002. Hệ quả: mọi trường mới đều phải tăng `formatVersion`. Model `Codable` giữ hành vi bỏ qua (đúng cho Admin); việc phát hiện và từ chối thuộc ExamFile ở bước 6.
- 2026-10-15 (bước 1): test đọc fixture qua đường dẫn tính từ `#filePath` (không copy fixture vào resources) để một bộ fixture dùng chung cho Swift, Python và CI.

### Quyết định chờ Nt0 chốt (gom từ các PR; đang áp dụng vì đã merge)

Chi tiết và lý do nằm trong body của từng PR. Agent đã chọn phương án ghi ở đây và code theo đó.

| PR | Quyết định | Phương án đang dùng |
| --- | --- | --- |
| #4 | Thứ tự câu sau "N câu ngẫu nhiên" khi không bật xáo câu | Giữ thứ tự sau xáo (như bản gốc); công tắc "Xáo câu" vô tác dụng ở chế độ này, UI nên làm mờ. Khoá vĩnh viễn với seed đã lưu |
| #4 | N ngoài 1…tổng | Báo lỗi, không kẹp; UI giới hạn stepper |
| #5 | Đếm độ dài | Theo Unicode code point (khớp JSON Schema và Python) |
| #5 | Nội dung chỉ toàn khoảng trắng (theo Unicode White_Space) | Là error: bản Học viên từ chối |
| #5 | Mẫu `code`/`image` | Khớp tuyệt đối (script sẽ sửa ở bước 7) |
| #5 | Hai id chỉ khác hoa/thường | Coi là trùng |
| #6 | Màn rà soát | Vẫn tính giờ; tạm dừng được từ rà soát; hết giờ khi đang rà soát → Hết giờ |
| #6 | Practice | Có tạm dừng |
| #6 | Sau Check answer | Khoá đáp án câu đó |
| #6 | Hết giờ | Chuyển Hết giờ → Rà soát (khoá) → bấm Nộp; không tự nộp (plan-macos-v1.md đã sửa ở PR #10) |
| #7 | Giới hạn kích thước gói (`ExamPackageLimits`) | exam.json 32 MiB, mỗi ảnh 50 MiB, tổng giải nén 1 GiB, 20.000 entry; một ảnh mồ côi vượt trần làm hỏng việc mở cả gói |
| #7 | Entry trùng tên trong zip | Từ chối gói (Python lấy entry cuối, Swift lấy entry đầu, nên không cho tồn tại) |
| #7 | Gói thiếu ảnh | Bản Admin mở và lưu được, báo qua `missingMedia`; bản Học viên từ chối (đúng exam-format.md) |
| #11 | Trần độ sâu JSON | 32 cấp, cả hai bản app |
| #11 | So khoá trùng trong JSON | Theo tương đương chính tắc Unicode (vì Foundation gộp các khoá đó) |
| #11 | Bản Học viên gặp đề vừa thiếu ảnh vừa sai đáp án | Chỉ báo thiếu ảnh trước; bản Admin thấy đủ |
| #3 | Phiên 0 câu với passPercent 0 | Đậu theo công thức; Composer không cho tạo phiên 0 câu nên không xảy ra |

## Validation

- 2026-10-15 trên `main` sau khi merge #11 (af76807), cộng PR tài liệu này:
  - `scripts/check.sh` xanh: 153 test ExamKit, 106 test ExamFile, schema, parity script–app, ranh giới, build ExamFeatures.
  - Linux `swift:6.1` trên bản `git archive` sạch: 259 test xanh.
  - `xcodebuild` hai scheme BUILD SUCCEEDED; `check_bundle_boundary.sh`: Học viên 0 ký hiệu AuthoringFeature, Admin 262.
  - Mở thử bản Admin với đề có trường lạ ở cấp câu hỏi: cửa sổ hiện tóm tắt đề và dòng "Bản Học viên sẽ từ chối đề này: Đề có trường không được hỗ trợ: sections[0].questions[0].hint."; đóng app, shasum file không đổi.
- Focused proof: `swift test --package-path Packages/ExamKit` trên macOS và trong container `swift:6.1`.
- Integration: `scripts/check.sh`; đóng gói fixture bằng `scripts/pack_exam.py` rồi đọc lại bằng ExamFile.
- Repository-required checks: CI `core-linux` xanh trên SHA cuối của từng PR.

## Result

Hoàn thành 2026-10-15, qua cổng G1 (Nt0 duyệt).

- **Lõi `ExamKit`:** model đề, ExamValidator (mọi ràng buộc schema + liên trường, error/warning),
  chấm điểm (thang 1000 và %, theo section), chọn câu có seed (SplitMix64, tái lập trên mọi nền tảng),
  phiên thi (state machine, đồng hồ đơn điệu, cảnh báo 5/1 phút, hết giờ → rà soát khoá).
- **`ExamFile`:** đọc/ghi gói `.exam`; chế độ nghiêm (Học viên) và dễ (Admin); giới hạn kích thước,
  độ sâu, entry trùng; StrictJSON (khoá trùng, `null`, dấu phẩy thừa); SHA-256 đặt tên ảnh; khung chuyển phiên bản.
- **Đồng bộ công cụ:** `scripts/validate_exam.py` cùng kết luận với app, ràng buộc bằng `fixtures/expected-verdicts.json`.
- **Bản Admin** mở `.exam` từ Finder, hiện lỗi/cảnh báo và cho biết bản Học viên có mở được đề không.
- **Bằng chứng cuối** (main 9be491b): 153 test ExamKit + 106 test ExamFile xanh trên macOS, 259 trên Linux;
  hai app build Release và chạy từ /Applications.
- **Quy trình:** 11 PR code + 4 PR tài liệu/CI; mọi PR rủi ro cao có review độc lập. Review chặn được:
  test giả xanh, đồng hồ lách được bằng chỉnh giờ máy, nộp bài sau hạn, Admin bị chặn lưu trái tài liệu,
  zip bomb, crash do zip hỏng và JSON lồng sâu.

Giới hạn và việc chuyển tiếp:

- Các phương án trong bảng "Quyết định chờ Nt0 chốt" đang áp dụng; đổi được ở giai đoạn sau.
- ZIPFoundation 0.9.20 có thể treo trên Linux với luồng deflate hỏng (ADR 0006); CI có `timeout-minutes`.
- Chuỗi giao diện chưa đưa vào String Catalog (giai đoạn 5); chưa có XCUITest (giai đoạn 3 trở đi).
- `ScoreResult`, `ExamPaper`, `CompositionOptions` chưa `Codable`; cần khi lưu lần thi (giai đoạn 3).
