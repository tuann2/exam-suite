import Foundation

/// Một section (phần) của đề; kết quả được tính theo từng section.
/// Tên `ExamSection` (không phải `Section`) để không đụng `SwiftUI.Section` ở tầng giao diện.
public struct ExamSection: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var questions: [Question]

    public init(id: UUID = UUID(), title: String, questions: [Question]) {
        self.id = id
        self.title = title
        self.questions = questions
    }
}

extension ExamSection: Codable {
    private enum CodingKeys: String, CodingKey { case id, title, questions }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        questions = try c.decode([Question].self, forKey: .questions)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLowercased(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(questions, forKey: .questions)
    }
}

/// Đề thi: nội dung của `exam.json` (schema/exam-v1.schema.json). Struct thuần,
/// tách khỏi SwiftData và khỏi cách lưu file (ADR 0008).
public struct Exam: Hashable, Sendable, Identifiable {
    /// Phiên bản định dạng mà đề này được ghi theo. Kiểm tra tương thích là việc của ExamFile.
    public var formatVersion: Int
    public var id: UUID
    public var title: String
    /// Mã đề ngắn, ví dụ `KTC01`.
    public var code: String?
    /// Ngưỡng đậu theo % câu đúng, số nguyên 0–100 (docs/product/scoring.md).
    public var passPercent: Int
    /// Thời gian mặc định cho chế độ Exam, phút.
    public var timeLimitMinutes: Int
    /// `true`: khoá chế độ Practice và ẩn đáp án khi xem lại. Mặc định `false`.
    public var hideAnswers: Bool
    /// Markdown cơ bản, hiện ở màn Trước khi thi.
    public var instructions: String?
    public var sections: [ExamSection]

    public init(
        formatVersion: Int = Exam.currentFormatVersion,
        id: UUID = UUID(),
        title: String,
        code: String? = nil,
        passPercent: Int,
        timeLimitMinutes: Int,
        hideAnswers: Bool = false,
        instructions: String? = nil,
        sections: [ExamSection]
    ) {
        self.formatVersion = formatVersion
        self.id = id
        self.title = title
        self.code = code
        self.passPercent = passPercent
        self.timeLimitMinutes = timeLimitMinutes
        self.hideAnswers = hideAnswers
        self.instructions = instructions
        self.sections = sections
    }

    /// `formatVersion` mới nhất mà model này mô tả; `ExamFileFormat.currentVersion` tham chiếu hằng này.
    public static let currentFormatVersion = 1

    /// Mọi câu theo thứ tự trong file, không phân biệt section.
    public var allQuestions: [Question] { sections.flatMap(\.questions) }

    public var questionCount: Int { sections.reduce(0) { $0 + $1.questions.count } }

    /// Tìm câu theo id; nil nếu không có.
    public func question(id: UUID) -> Question? {
        for s in sections {
            if let q = s.questions.first(where: { $0.id == id }) { return q }
        }
        return nil
    }

    /// Section chứa câu có id đã cho; nil nếu không có.
    public func section(containing questionID: UUID) -> ExamSection? {
        sections.first { $0.questions.contains { $0.id == questionID } }
    }
}

extension Exam: Codable {
    private enum CodingKeys: String, CodingKey {
        case formatVersion, id, title, code, passPercent, timeLimitMinutes, hideAnswers, instructions, sections
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        passPercent = try c.decode(Int.self, forKey: .passPercent)
        timeLimitMinutes = try c.decode(Int.self, forKey: .timeLimitMinutes)
        hideAnswers = try c.decodeIfPresent(Bool.self, forKey: .hideAnswers) ?? false
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        sections = try c.decode([ExamSection].self, forKey: .sections)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(formatVersion, forKey: .formatVersion)
        try c.encodeLowercased(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(code, forKey: .code)
        try c.encode(passPercent, forKey: .passPercent)
        try c.encode(timeLimitMinutes, forKey: .timeLimitMinutes)
        try c.encode(hideAnswers, forKey: .hideAnswers)
        try c.encodeIfPresent(instructions, forKey: .instructions)
        try c.encode(sections, forKey: .sections)
    }
}
