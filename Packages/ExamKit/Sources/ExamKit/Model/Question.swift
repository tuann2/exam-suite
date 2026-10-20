import Foundation

/// Loại câu hỏi. `single`: đúng một đáp án; `multiple`: phải chọn đúng toàn bộ tập đáp án.
/// Là `String` raw value để `exam.json` đọc được bằng mắt; loại mới thêm ở v2.
public enum QuestionType: String, Codable, Sendable, CaseIterable {
    case single
    case multiple
}

/// Một lựa chọn của câu hỏi.
public struct Option: Codable, Hashable, Sendable, Identifiable {
    public var id: OptionID
    /// Markdown cơ bản.
    public var text: String

    public init(id: OptionID, text: String) {
        self.id = id
        self.text = text
    }
}

/// Câu hỏi trắc nghiệm. Thứ tự `options` trong file là thứ tự gốc; xáo đáp án
/// là việc của phiên thi và không đổi dữ liệu này.
public struct Question: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var type: QuestionType
    /// Markdown cơ bản.
    public var text: String
    /// Đường dẫn tương đối trong gói, dạng `media/<hash>.<ext>`; nil nếu không có ảnh.
    public var image: String?
    public var options: [Option]
    /// Tập đáp án đúng; `single` có đúng một phần tử. Luôn là mảng (ADR 0002).
    public var correct: [OptionID]
    /// Markdown cơ bản; hiện sau Check answer hoặc khi xem lại.
    public var explanation: String?

    public init(
        id: UUID = UUID(),
        type: QuestionType,
        text: String,
        image: String? = nil,
        options: [Option],
        correct: [OptionID],
        explanation: String? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.image = image
        self.options = options
        self.correct = correct
        self.explanation = explanation
    }

    /// Tập đáp án đúng để so sánh không phụ thuộc thứ tự.
    public var correctSet: Set<OptionID> { Set(correct) }
}

extension Question: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, text, image, options, correct, explanation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        type = try c.decode(QuestionType.self, forKey: .type)
        text = try c.decode(String.self, forKey: .text)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        options = try c.decode([Option].self, forKey: .options)
        correct = try c.decode([OptionID].self, forKey: .correct)
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLowercased(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encode(options, forKey: .options)
        try c.encode(correct, forKey: .correct)
        try c.encodeIfPresent(explanation, forKey: .explanation)
    }
}
