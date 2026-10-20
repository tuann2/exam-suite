import Foundation

/// Đáp án của thí sinh theo id câu → tập id lựa chọn GỐC (không theo vị trí hiển thị
/// sau khi xáo). Thiếu khoá hoặc tập rỗng = chưa trả lời.
public typealias AnswerSheet = [UUID: Set<OptionID>]

/// Kết quả chấm một câu. Chỉ đúng hoặc sai, không có điểm từng phần;
/// `unanswered` tính là sai nhưng tách riêng để màn kết quả và "Luyện lại câu sai" dùng.
public enum QuestionOutcome: String, Sendable, Equatable {
    case correct
    case incorrect
    case unanswered
}

/// Kết quả theo một section của đề (docs/product/scoring.md, mục Kết quả theo section).
public struct SectionScore: Equatable, Sendable {
    public let sectionID: UUID
    public let title: String
    /// Số câu của section có mặt trong phiên thi.
    public let total: Int
    /// Số câu đúng trong số đó.
    public let correct: Int

    public init(sectionID: UUID, title: String, total: Int, correct: Int) {
        self.sectionID = sectionID
        self.title = title
        self.total = total
        self.correct = correct
    }
}

/// Kết quả chấm cả phiên thi. Chỉ tạo bằng `Scorer.score(exam:questionIDs:answers:)`.
public struct ScoreResult: Equatable, Sendable {
    /// Số câu trong phiên thi (sau khi chọn câu).
    public let total: Int
    public let correct: Int
    /// Thang 1000, chia lấy phần nguyên.
    public let score1000: Int
    /// Phần trăm để hiển thị, chia lấy phần nguyên.
    public let percent: Int
    /// Ngưỡng đậu lấy từ đề lúc chấm.
    public let passPercent: Int
    public let passed: Bool
    /// Mọi section của đề theo thứ tự file, kể cả section 0/0.
    public let sections: [SectionScore]
    /// Kết quả của mọi câu trong phiên.
    public let outcomes: [UUID: QuestionOutcome]
    /// Các câu trong phiên theo thứ tự phiên (đúng thứ tự `questionIDs` đã truyền vào).
    public let questionIDs: [UUID]

    init(
        total: Int,
        correct: Int,
        score1000: Int,
        percent: Int,
        passPercent: Int,
        passed: Bool,
        sections: [SectionScore],
        outcomes: [UUID: QuestionOutcome],
        questionIDs: [UUID]
    ) {
        self.total = total
        self.correct = correct
        self.score1000 = score1000
        self.percent = percent
        self.passPercent = passPercent
        self.passed = passed
        self.sections = sections
        self.outcomes = outcomes
        self.questionIDs = questionIDs
    }

    /// Câu sai hoặc chưa làm, theo thứ tự phiên; dùng cho "Luyện lại câu sai".
    public var incorrectOrUnansweredIDs: [UUID] {
        questionIDs.filter { outcomes[$0] != .correct }
    }
}

/// Lỗi khi danh sách câu của phiên không khớp với đề.
public enum ScoringError: Error, Equatable {
    /// Id câu không có trong đề.
    case unknownQuestion(UUID)
    /// Id câu xuất hiện hơn một lần trong phiên.
    case duplicateQuestion(UUID)
}
