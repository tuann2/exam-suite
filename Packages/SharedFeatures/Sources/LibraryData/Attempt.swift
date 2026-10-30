import ExamKit
import Foundation

/// Tóm tắt một lần thi (docs/product/library.md, mục Lịch sử thi): đủ để liệt kê, lọc theo đề và
/// sắp xếp. Nội dung chi tiết (câu trả lời, kết quả theo section) nằm trong `payload` riêng do
/// giai đoạn 3 quyết định định dạng; lấy bằng `LibraryStore.attemptPayload(id:)`.
///
/// Lần thi gắn với id đề và còn lại khi đề bị xoá khỏi thư viện.
public struct Attempt: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let examID: UUID
    /// Tên đề lúc thi (đề có thể đổi tên hoặc bị xoá sau đó).
    public var examTitle: String
    public var candidateName: String
    /// Luyện tập (`practice`) hay Thi (`exam`).
    public var mode: SessionMode
    public var startedAt: Date
    public var submittedAt: Date
    /// Thời gian làm bài, giây (`ExamSession.elapsed`).
    public var elapsedSeconds: TimeInterval
    public var correct: Int
    public var total: Int
    /// Điểm thang 1000 (docs/product/scoring.md).
    public var score1000: Int
    /// Điểm %, chia lấy phần nguyên.
    public var percent: Int
    public var passed: Bool

    public init(
        id: UUID = UUID(),
        examID: UUID,
        examTitle: String,
        candidateName: String,
        mode: SessionMode,
        startedAt: Date,
        submittedAt: Date,
        elapsedSeconds: TimeInterval,
        correct: Int,
        total: Int,
        score1000: Int,
        percent: Int,
        passed: Bool
    ) {
        self.id = id
        self.examID = examID
        self.examTitle = examTitle
        self.candidateName = candidateName
        self.mode = mode
        self.startedAt = startedAt
        self.submittedAt = submittedAt
        self.elapsedSeconds = elapsedSeconds
        self.correct = correct
        self.total = total
        self.score1000 = score1000
        self.percent = percent
        self.passed = passed
    }

    /// Thứ tự "mới nhất trước": nộp sau trước; bằng nhau thì bắt đầu sau trước, rồi theo id để ổn định.
    public static func newestFirst(_ lhs: Attempt, _ rhs: Attempt) -> Bool {
        if lhs.submittedAt != rhs.submittedAt { return lhs.submittedAt > rhs.submittedAt }
        if lhs.startedAt != rhs.startedAt { return lhs.startedAt > rhs.startedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
