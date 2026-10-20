import Foundation

/// Một câu trong đề đã tạo cho phiên thi.
public struct PaperItem: Equatable, Hashable, Sendable {
    public let questionID: UUID
    /// Section gốc chứa câu, để chấm theo section.
    public let sectionID: UUID
    /// Thứ tự HIỂN THỊ của các id lựa chọn gốc. Không xáo đáp án thì là thứ tự
    /// trong file (A, B, C…). Đáp án người làm lưu và chấm theo id gốc, không theo vị trí.
    public let optionOrder: [OptionID]

    public init(questionID: UUID, sectionID: UUID, optionOrder: [OptionID]) {
        self.questionID = questionID
        self.sectionID = sectionID
        self.optionOrder = optionOrder
    }
}

/// Đề đã tạo cho một phiên: danh sách câu theo thứ tự hiển thị. Chỉ giữ id;
/// nội dung câu lấy từ `Exam` có `id == examID`.
public struct ExamPaper: Equatable, Hashable, Sendable {
    public let examID: UUID
    /// Tuỳ chọn đã dùng để tạo; cùng đề + cùng tuỳ chọn tạo lại đúng đề này.
    public let options: CompositionOptions
    public let items: [PaperItem]

    public init(examID: UUID, options: CompositionOptions, items: [PaperItem]) {
        self.examID = examID
        self.options = options
        self.items = items
    }

    /// Id câu theo thứ tự hiển thị.
    public var questionIDs: [UUID] { items.map(\.questionID) }
}
