import Foundation

/// Chế độ làm bài (docs/product/exam-session.md, mục Chế độ).
public enum SessionMode: String, Sendable, Codable, CaseIterable {
    /// Không đồng hồ đếm ngược, có Check answer. Bị khoá khi đề có `hideAnswers == true`.
    case practice
    /// Có thời hạn, không có Check answer.
    case exam
}

/// Trạng thái của phiên thi. Thư viện, Trước khi thi, Kết quả và Xem lại bài là
/// điều hướng của giao diện, không thuộc `ExamSession`.
///
/// ```text
/// inProgress ⇄ paused                            (pause / resume)
/// reviewing(locked: false) ⇄ paused              (pause / resume, quay về đúng chỗ cũ)
/// inProgress → reviewing(locked: false)          (openReview)
/// reviewing(locked: false) → inProgress          (returnToAttempt)
/// inProgress, reviewing(locked: false) → timeUp  (hết giờ, chỉ Exam)
/// timeUp → reviewing(locked: true)               (openReview)
/// reviewing(_) → submitted                       (submit)
/// ```
public enum SessionPhase: Equatable, Sendable {
    /// Đang làm bài (Attempt). Chỉ ở đây mới sửa đáp án, đánh dấu, chuyển câu.
    case inProgress
    /// Tạm dừng: giao diện che câu hỏi, đồng hồ dừng.
    case paused
    /// Hết giờ (chỉ Exam): đồng hồ dừng, không sửa được đáp án.
    case timeUp
    /// Bảng rà soát trước khi nộp. `locked == true` khi vào từ hết giờ: không quay lại làm bài.
    case reviewing(locked: Bool)
    /// Đã nộp; `ExamSession.result` có kết quả.
    case submitted
}

/// Lý do tạm dừng; giao diện dùng để hiện thông báo phù hợp.
public enum PauseReason: String, Sendable, Codable {
    /// Người dùng bấm Tạm dừng (phím P).
    case user
    /// Máy sắp ngủ. Thời gian ngủ không bị trừ; thức dậy phiên vẫn ở `paused` tới khi `resume`.
    case systemSleep
    /// App xuống nền (bản iOS: chuyển app, về màn hình chính, khoá màn hình; docs/product/mobile.md, mục Bản iOS).
    /// Như máy ngủ: thời gian ở nền không bị trừ, mở lại phiên vẫn ở `paused` tới khi `resume`.
    case background
}

/// Sự kiện đồng hồ, trả về từ `ExamSession.tick()`.
public enum SessionEvent: Equatable, Sendable {
    /// Còn `minutesLeft` phút (5 hoặc 1). Mỗi mốc phát nhiều nhất một lần mỗi phiên.
    case warning(minutesLeft: Int)
    /// Vừa hết giờ; phase đã là `timeUp`. Phát đúng một lần.
    case timeUp
}

/// Tên lệnh, dùng trong lỗi để mô tả lệnh bị từ chối.
public enum SessionCommand: String, Sendable, CaseIterable {
    case select
    case clearAnswer
    case toggleFlag
    case goTo
    case next
    case previous
    case pause
    case resume
    case openReview
    case returnToAttempt
    case submit
    case checkAnswer
}

/// Kết quả Check answer ở chế độ Practice.
public struct AnswerCheck: Equatable, Sendable {
    public let questionID: UUID
    /// Đúng/sai theo `Scorer.outcome(of:selected:)`; không bao giờ là `unanswered`
    /// vì không check được câu chưa trả lời.
    public let outcome: QuestionOutcome
    /// Tập đáp án đúng (id lựa chọn gốc) để giao diện tô đúng/sai.
    public let correctOptions: Set<OptionID>
    /// Giải thích của câu, nếu có.
    public let explanation: String?

    public init(questionID: UUID, outcome: QuestionOutcome, correctOptions: Set<OptionID>, explanation: String?) {
        self.questionID = questionID
        self.outcome = outcome
        self.correctOptions = correctOptions
        self.explanation = explanation
    }
}

/// Lỗi của `ExamSession`. Lệnh bị từ chối không đổi đáp án, đánh dấu, câu hiện tại hay
/// trạng thái do lệnh đó gây ra. Ngoại lệ duy nhất là phần ghi nhận đồng hồ: mọi lệnh đều
/// đối chiếu đồng hồ trước, nên cảnh báo đã tới mốc và hết giờ (phase → `timeUp`) vẫn được
/// ghi nhận, và trả ở `tick()` kế tiếp (xem `ExamSession`).
public enum SessionError: Error, Equatable {
    // Lỗi khi tạo phiên.

    /// Practice bị khoá vì đề có `hideAnswers == true`.
    case practiceNotAllowed
    /// `paper.examID` không phải id của đề.
    case paperExamMismatch(paperExamID: UUID, examID: UUID)
    /// Đề đã tạo không có câu nào.
    case emptyPaper
    /// Đề đã tạo có câu không thuộc đề.
    case unknownQuestion(UUID)
    /// Đề đã tạo có một câu hai lần.
    case duplicateQuestion(UUID)
    /// Thời hạn Exam (phút) ngoài khoảng `ExamSession.timeLimitRange`.
    case invalidTimeLimit(minutes: Int)

    // Lỗi khi ra lệnh.

    /// Lệnh không hợp lệ ở trạng thái hiện tại.
    case invalidCommand(SessionCommand, phase: SessionPhase)
    /// Lệnh không có ở chế độ này (Check answer ở Exam).
    case unavailableInMode(SessionCommand, mode: SessionMode)
    /// Vị trí câu ngoài `0..<count`.
    case indexOutOfRange(index: Int, count: Int)
    /// Lựa chọn không thuộc câu hiện tại.
    case unknownOption(OptionID)
    /// Đáp án câu này đã khoá sau Check answer.
    case answerLocked(questionID: UUID)
    /// Check answer khi câu hiện tại chưa có đáp án.
    case noAnswerToCheck(questionID: UUID)
}
