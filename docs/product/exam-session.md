# Phiên thi

Thẩm quyền: tài liệu này + sơ đồ trạng thái trong [plan-macos-v1.md](plan-macos-v1.md).
Code: `ExamSession` trong `ExamKit/Session` (struct giá trị, state machine thuần,
nhận `SessionClock` từ ngoài; không Timer, không luồng nền). UI: `SessionFeature`
bọc phiên trong view model `@Observable` và gọi `tick()` định kỳ.

## Chế độ

| | Practice | Exam |
| --- | --- | --- |
| Đồng hồ | Không đếm ngược (vẫn đo thời gian làm) | Có, đếm ngược từ `timeLimitMinutes` của đề; người dùng đổi được khi tạo phiên, 1–600 phút |
| Check answer | Có, hiện đúng/sai + giải thích ngay; sau đó đáp án câu đó bị khoá | Không |
| Kết quả | Cuối bài | Cuối bài |
| `hideAnswers = true` | Chế độ bị khoá (tạo phiên bị từ chối) | Vẫn thi được; xem lại không hiện đáp án |

## Trạng thái và chuyển đổi

Thư viện, Trước khi thi, Kết quả và Xem lại bài là điều hướng của giao diện.
`ExamSession` chỉ có các trạng thái (`SessionPhase`) từ lúc bắt đầu làm tới lúc nộp:

| Trong sơ đồ kế hoạch | `SessionPhase` |
| --- | --- |
| Attempt (Đang làm bài) | `inProgress` |
| Paused (Tạm dừng) | `paused` |
| TimeUp (Hết giờ) | `timeUp` |
| Review (Rà soát, nộp) | `reviewing(locked: false)`; vào từ hết giờ là `reviewing(locked: true)` |
| Results (Kết quả) | `submitted` (có `result`) |

```text
Library → PreExam → (tạo ExamSession) inProgress
inProgress ⇄ paused                              pause / resume
reviewing(locked: false) ⇄ paused                pause / resume (quay về đúng chỗ cũ)
inProgress → reviewing(locked: false)            openReview (⌘Return)
reviewing(locked: false) → inProgress            returnToAttempt (có thể tới thẳng một câu)
inProgress, reviewing(locked: false) → timeUp    hết giờ, chỉ Exam
timeUp → reviewing(locked: true)                 openReview (UI gọi ngay, "tự chuyển")
reviewing(_) → submitted                         submit (Nộp; hỏi xác nhận nếu còn câu chưa làm là việc của UI)
submitted → AnswerReview | PreExam (Làm lại) | Library      điều hướng của UI
AnswerReview → PreExam (Luyện lại câu sai, Practice)        điều hướng của UI
```

- Tạo phiên là bắt đầu làm: `inProgress`, câu đầu tiên, đồng hồ chạy.
- Mọi đường tới `submitted` đều qua rà soát: `submit` chỉ hợp lệ ở `reviewing`.
- Chỉ ở `inProgress` mới chọn/xoá đáp án, đánh dấu, chuyển câu, Check answer.
- Từ `timeUp` và `reviewing(locked: true)` không sửa được đáp án, không quay lại làm bài, không tạm dừng.
- `paused` che nội dung câu hỏi (UI); đồng hồ dừng. Tiếp tục mới hiện lại.
- Máy ngủ: UI gọi `pause(reason: .systemSleep)` khi máy sắp ngủ; thời gian ngủ không bị trừ; thức dậy phiên vẫn ở `paused` tới khi người dùng tiếp tục. Bản iOS: app xuống nền thì `pause(reason: .background)`, cùng luật (mobile.md, mục Bản iOS).
- Lệnh sai trạng thái ném `SessionError.invalidCommand(lệnh, phase:)`. Lệnh bị từ chối không đổi đáp án, đánh dấu, câu hiện tại hay trạng thái do lệnh gây ra; riêng phần đồng hồ (cảnh báo tới mốc, hết giờ) vẫn được ghi nhận, xem mục Đồng hồ.

### Lệnh

| Lệnh | Hợp lệ khi | Tác dụng |
| --- | --- | --- |
| `select(option:)` | `inProgress`, câu chưa khoá | Theo id lựa chọn gốc. `single`: thay đáp án; `multiple`: bật/tắt (tắt hết = chưa trả lời) |
| `clearAnswer()` | `inProgress`, câu chưa khoá | Xoá đáp án câu hiện tại |
| `toggleFlag()` | `inProgress` | Bật/tắt đánh dấu (được cả khi câu đã khoá) |
| `goTo(index:)`, `next()`, `previous()` | `inProgress` | Chuyển câu; `next` ở câu cuối và `previous` ở câu đầu đứng yên, không lỗi |
| `checkAnswer()` | Practice, `inProgress`, câu đã có đáp án | Trả đúng/sai, tập đáp án đúng, giải thích; khoá đáp án câu đó; gọi lại trả cùng kết quả |
| `pause(reason:)` | `inProgress`, `reviewing(locked: false)` | Lý do `user`, `systemSleep` hoặc `background` (bản iOS: app xuống nền) |
| `resume()` | `paused` | Về trạng thái trước khi tạm dừng |
| `openReview()` | `inProgress`, `timeUp` | Mở rà soát (khoá nếu từ `timeUp`) |
| `returnToAttempt(at:)` | `reviewing(locked: false)` | Quay lại làm bài |
| `submit()` | `reviewing(_)` | Chấm bằng `Scorer.score`, dừng đồng hồ |
| `tick()` | luôn | Trả sự kiện đồng hồ mới; không bao giờ lỗi; sau khi nộp luôn rỗng |

## Đồng hồ

- `SessionClock` có hai nguồn: `uptime()` đơn điệu để **đo** thời gian, `now()` (giờ hệ thống) chỉ để **ghi mốc** `startedAt`, `submittedAt`.
- Thời gian tính theo **mốc** `uptime()` lúc đồng hồ chạy/dừng, không cộng dồn tick. Chỉnh giờ máy (lùi hay tới) không đổi thời gian đã làm.
- App dùng `SystemSessionClock`: `uptime()` lấy từ `SuspendingClock` của thư viện chuẩn, không chạy khi máy ngủ, nên kể cả khi app lỡ thông báo máy ngủ thì thời gian ngủ cũng không bị trừ.
- Thời gian đã làm = tổng các khoảng ở `inProgress` và `reviewing(locked: false)` (rà soát vẫn tính giờ). Đồng hồ dừng ở `paused`, `timeUp`, `reviewing(locked: true)`, `submitted`.
- Cảnh báo còn **5 phút** và **1 phút** (`SessionEvent.warning`, có VoiceOver đọc): mỗi mốc đúng một lần, kể cả khi tick thưa nhảy qua mốc (nhảy qua cả hai thì phát 5 rồi 1). Chỉ có mốc nhỏ hơn thời hạn (thi 5 phút chỉ có cảnh báo 1 phút; thi 1 phút không có cảnh báo).
- Hết giờ → `timeUp` → rà soát khoá; không tự nộp ngay để người dùng thấy bảng rà soát; nộp khi bấm Nộp bài (DESIGN_BRIEF luồng 3).
  - Khi thời gian đã làm chạm thời hạn, `tick()` phát `SessionEvent.timeUp` đúng một lần và phase chuyển sang `timeUp`. Đã hết giờ thì không phát các cảnh báo chưa kịp phát.
  - Thời gian đã làm dừng đúng bằng thời hạn, kể cả khi phát hiện muộn.
  - Mọi lệnh đều đối chiếu đồng hồ trước, kể cả lệnh rồi bị từ chối: cảnh báo đã tới mốc được ghi nhận; nếu đã quá giờ thì phiên chuyển sang `timeUp` và chính lệnh đó bị từ chối với `phase: .timeUp` (kể cả `openReview`, để UI hiện màn Hết giờ trước). Sự kiện ghi nhận lúc đó được trả ở `tick()` kế tiếp; sau khi nộp thì bỏ.
  - UI hiện màn Hết giờ rồi gọi `openReview()` để sang `reviewing(locked: true)`.
- Practice: không có thời hạn, không có `timeUp`, `tick()` không phát sự kiện.

## Dữ liệu phiên

- Đáp án lưu theo `id` câu và `id` lựa chọn gốc (không theo vị trí hiển thị).
- Đánh dấu (flag) theo `id` câu.
- Khi nộp tạo `Attempt` (xem mục "Dữ liệu riêng của app" trong kế hoạch): điểm, đậu/trượt, theo section, câu trả lời, thời gian làm, seed và tuỳ chọn để làm lại. Nội dung `payload`: mục "Dữ liệu một lần thi" của [exam-taking.md](exam-taking.md).
- "Làm lại": `retakeOptions(seed:)` giữ cách chọn câu và xáo của phiên, thay seed (truyền seed cũ để tái hiện đúng đề).
- "Luyện lại câu sai": `practiceIncorrectOptions(seed:)` sau khi nộp cho tuỳ chọn gồm đúng các câu sai/chưa làm theo thứ tự phiên, không xáo; nil nếu không còn câu sai hoặc đề có `hideAnswers` (Practice bị khoá).

## Phím tắt

| Hành động | Phím |
| --- | --- |
| Chọn đáp án | A–Z |
| Câu trước / sau | ← / → |
| Đánh dấu | ⌘D |
| Tạm dừng / tiếp tục | ⌘. |
| Câu tiếp theo | Return |
| Rà soát & nộp | ⌘Return |

Đã chốt (Nt0 duyệt 2026-10-15): schema cho tới 26 đáp án nên phím chữ A–Z chỉ dùng để chọn đáp án;
**Đánh dấu** là ⌘D và **Tạm dừng** là ⌘. thay cho F và P của bản gốc. Đề mẫu "Làm quen" (câu 7, ảnh phím
tắt) sửa theo. Bảng phím đầy đủ của cửa sổ làm bài: [exam-taking.md](exam-taking.md).

## Bằng chứng cần có

Giai đoạn 1 (`ExamSessionTests`, đồng hồ giả `FakeClock`): mọi chuyển trạng thái
hợp lệ và không hợp lệ (ví dụ sửa đáp án sau `timeUp` bị từ chối), cảnh báo 5/1
phút đúng một lần (tick dày và tick thưa), tạm dừng không trừ giờ, ngủ–thức, hết
giờ chuyển rà soát khoá. Viết theo danh sách tình huống của `SimulatorSessionTests`
bản gốc. Giai đoạn 3: model trình bày của `SessionFeature` (test tự động), giao diện và VoiceOver
(XCUITest cho luồng bàn phím, người test tay cho phần còn lại).
