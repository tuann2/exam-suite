import AuthoringData
import Foundation

/// Điều khiển nhận tiêu điểm trong trình soạn (cột giữa). Trình soạn chỉ hiện một đề/phần/câu tại một lúc
/// (theo dòng đang chọn trên cây đề), nên tiêu điểm không cần mang vị trí câu.
public enum AuthoringFocus: Hashable, Sendable {
    // Thuộc tính đề
    case examTitle
    case examCode
    case passPercent
    case timeLimit
    case hideAnswers
    case instructions
    case addSection
    // Phần
    case sectionTitle
    case addQuestion
    /// Nút **Cấp id mới** (chỉ hiện khi dòng có lỗi id trùng).
    case newID
    // Câu
    case questionText
    case questionType
    case image
    case explanation
    case addOption
    case optionText(Int)
    case optionCorrect(Int)

    /// Tiêu điểm cho một vấn đề của thanh lỗi (docs/product/authoring.md, mục Cửa sổ: "bấm một dòng thì chọn
    /// đúng đề/phần/câu và trường đó").
    public init(_ target: IssueTarget) {
        switch target.node {
        case .exam:
            switch target.field {
            case .code: self = .examCode
            case .passPercent: self = .passPercent
            case .timeLimitMinutes: self = .timeLimit
            case .instructions: self = .instructions
            case .sections: self = .addSection
            default: self = .examTitle
            }
        case .section:
            switch target.field {
            case .questions: self = .addQuestion
            case .id: self = .newID
            default: self = .sectionTitle
            }
        case .question:
            switch target.field {
            case .image: self = .image
            case .explanation: self = .explanation
            case .options: self = .addOption
            // Thiếu/thừa đáp án đúng: nút đánh dấu đúng của lựa chọn đầu.
            case .correct: self = .optionCorrect(0)
            case .id: self = .newID
            default: self = .questionText
            }
        case let .option(_, _, optionIndex):
            self = .optionText(optionIndex)
        }
    }
}

/// Yêu cầu đưa tiêu điểm tới một điều khiển; `token` đổi mỗi lần để yêu cầu lặp lại vẫn có tác dụng.
public struct FocusRequest: Hashable, Sendable {
    public let focus: AuthoringFocus
    public let token: Int
}

/// Thông báo lỗi khi một thao tác không làm được (ảnh quá lớn, đủ 26 lựa chọn…).
public struct AuthoringAlert: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String
}

/// Hỏi lại trước khi xoá phần còn câu (authoring.md, phương án 5).
public struct SectionRemovalRequest: Identifiable, Hashable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let title: String
    public let questionCount: Int
}

/// Kiểu xem trước: như cửa sổ làm bài ở chế độ Luyện tập (hiện đáp án đúng và giải thích như sau Kiểm tra
/// đáp án) hoặc Thi (chỉ câu hỏi và lựa chọn).
public enum PreviewMode: String, Hashable, Sendable, CaseIterable {
    case practice
    case exam
}

/// Trường gõ chữ. Các lần gõ liên tiếp vào cùng một trường gộp thành một bước Hoàn tác ("gõ chữ gộp theo
/// từng đoạn gõ", authoring.md); trường khác, thao tác khác, đổi dòng chọn, Hoàn tác/Làm lại hay lưu thì
/// kết thúc đoạn gõ.
public enum TypingField: Hashable, Sendable {
    case examTitle
    case examCode
    case instructions
    case sectionTitle(Int)
    case questionText(QuestionPath)
    case explanation(QuestionPath)
    case optionText(QuestionPath, Int)
}
