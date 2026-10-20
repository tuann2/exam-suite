import ExamKit
import Foundation

/// Vị trí một câu trong đề: chỉ số phần và chỉ số câu trong phần, từ 0, theo thứ tự trong file.
public struct QuestionPath: Hashable, Sendable, CustomStringConvertible {
    public var section: Int
    public var question: Int

    public init(section: Int, question: Int) {
        self.section = section
        self.question = question
    }

    public var description: String { "phần \(section + 1), câu \(question + 1)" }
}

/// Thuộc tính cấp đề sửa được trong trình soạn (docs/product/authoring.md, mục Thuộc tính đề).
/// `id` và `formatVersion` không sửa ở đây: `id` của đề ổn định, `formatVersion` do bộ ghi đặt.
public struct ExamProperties: Hashable, Sendable {
    public var title: String
    public var code: String?
    public var passPercent: Int
    public var timeLimitMinutes: Int
    public var hideAnswers: Bool
    public var instructions: String?

    public init(
        title: String,
        code: String? = nil,
        passPercent: Int,
        timeLimitMinutes: Int,
        hideAnswers: Bool = false,
        instructions: String? = nil
    ) {
        self.title = title
        self.code = code
        self.passPercent = passPercent
        self.timeLimitMinutes = timeLimitMinutes
        self.hideAnswers = hideAnswers
        self.instructions = instructions
    }

    public init(_ exam: Exam) {
        self.init(
            title: exam.title, code: exam.code, passPercent: exam.passPercent,
            timeLimitMinutes: exam.timeLimitMinutes, hideAnswers: exam.hideAnswers,
            instructions: exam.instructions
        )
    }
}

/// Một thay đổi nguyên thuỷ trên đề đang soạn. `ExamDraft.apply(_:)` thực hiện nó và trả về
/// thay đổi ngược; áp thay đổi ngược đưa đề về đúng trạng thái trước (Hoàn tác), áp lại thay
/// đổi ngược của thay đổi ngược là Làm lại. `UndoManager` của giao diện (bước 4) chỉ cần lưu
/// giá trị này, không cần chụp cả đề.
///
/// Địa chỉ theo **chỉ số** (không theo id) để luôn rõ ràng kể cả với đề đọc dễ có id trùng;
/// Hoàn tác/Làm lại khôi phục đúng trạng thái nên chỉ số luôn còn đúng. Các thao tác tiện dụng
/// của `ExamDraft` nhận id rồi đổi ra chỉ số.
///
/// Thay đổi trong một câu (nội dung, lựa chọn, đáp án đúng, loại, ảnh, giải thích) đều là
/// `replaceQuestion`: thay đổi ngược là bản chụp gọn của đúng câu đó.
public indirect enum ExamEdit: Hashable, Sendable {
    case setProperties(ExamProperties)
    case insertSection(ExamSection, at: Int)
    case removeSection(at: Int)
    case setSectionTitle(String, at: Int)
    /// Phần mới ở vị trí `i` là phần cũ ở vị trí `order[i]`; `order` là một hoán vị của các chỉ số.
    case permuteSections(order: [Int])
    case insertQuestion(Question, at: QuestionPath)
    case removeQuestion(at: QuestionPath)
    /// Chuyển một câu (giữ id). `to` là vị trí cuối cùng của câu, tính trên phần đích sau khi đã
    /// gỡ câu khỏi chỗ cũ.
    case moveQuestion(from: QuestionPath, to: QuestionPath)
    /// Câu mới ở vị trí `i` của phần là câu cũ ở vị trí `order[i]`.
    case permuteQuestions(section: Int, order: [Int])
    case replaceQuestion(Question, at: QuestionPath)
    /// Thêm byte ảnh vào gói dưới đường dẫn `media/<tên>`. Đã có cùng đường dẫn cùng byte thì
    /// không làm gì; khác byte thì báo lỗi (không bao giờ ghi đè ảnh đã có).
    case insertMedia(path: String, data: Data)
    case removeMedia(path: String)
    /// Áp lần lượt; lỗi giữa chừng thì đề giữ nguyên như trước cả nhóm.
    case group([ExamEdit])

    /// Thay đổi không làm gì (thay đổi ngược của thao tác không đổi đề).
    public static let none = ExamEdit.group([])

    /// `true` nếu thay đổi chắc chắn không đổi đề (nhóm rỗng, hoặc chỉ gồm nhóm rỗng).
    public var isEmpty: Bool {
        if case let .group(edits) = self { return edits.allSatisfy(\.isEmpty) }
        return false
    }
}

/// Lỗi khi sửa đề. Thao tác lỗi không đổi đề. Dạng mã và đối số: giao diện dựng câu báo bằng chữ của String Catalog
/// (AuthoringFeature, `AuthoringMessages`; docs/product/accessibility-localization.md, phương án 2); `logMessage` là câu
/// tiếng Việt cho nhật ký và test. Không theo `LocalizedError`, để câu đó không tự lọt ra giao diện.
public enum ExamEditError: Error, Equatable, Sendable {
    case sectionNotFound(UUID)
    case questionNotFound(UUID)
    case invalidSectionIndex(Int)
    case invalidQuestionPath(QuestionPath)
    case invalidOptionIndex(Int)
    case invalidPermutation
    /// Đã có 26 lựa chọn (A–Z): không còn chữ cái cho lựa chọn mới.
    case tooManyOptions
    /// Đuôi ảnh không thuộc png, jpg, jpeg, gif, webp, heic.
    case unsupportedImageType(String)
    /// Ảnh lớn hơn giới hạn mỗi ảnh của `ExamPackageLimits` (byte).
    case imageTooLarge(bytes: Int, limit: Int)
    /// Thêm ảnh này làm tổng dung lượng ảnh của đề vượt giới hạn đọc gói (byte).
    case packageTooLarge(limit: Int)
    /// Thêm ảnh này làm số entry của gói vượt giới hạn đọc gói.
    case tooManyImages(limit: Int)
    /// Đường dẫn ảnh đã có trong gói với nội dung khác (trùng tiền tố SHA-256): không ghi đè.
    case mediaNameCollision(String)
}

extension ExamEditError {
    /// Câu tiếng Việt cho nhật ký và test (giao diện không dùng).
    public var logMessage: String {
        switch self {
        case let .sectionNotFound(id):
            return "Không tìm thấy phần \(id.uuidString.lowercased()) trong đề."
        case let .questionNotFound(id):
            return "Không tìm thấy câu \(id.uuidString.lowercased()) trong đề."
        case let .invalidSectionIndex(index):
            return "Không có phần thứ \(index + 1) trong đề."
        case let .invalidQuestionPath(path):
            return "Không có \(path) trong đề."
        case let .invalidOptionIndex(index):
            return "Không có lựa chọn thứ \(index + 1) trong câu."
        case .invalidPermutation:
            return "Thứ tự mới không hợp lệ."
        case .tooManyOptions:
            return "Câu đã có đủ 26 lựa chọn (A–Z), không thêm được nữa."
        case let .unsupportedImageType(ext):
            return "Loại ảnh \"\(ext)\" không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic)."
        case let .imageTooLarge(bytes, limit):
            return "Ảnh nặng \(Self.megabytes(bytes)), vượt giới hạn \(Self.megabytes(limit)) mỗi ảnh."
        case let .packageTooLarge(limit):
            return "Thêm ảnh này làm tổng dung lượng ảnh của đề vượt \(Self.megabytes(limit))."
        case let .tooManyImages(limit):
            return "Đề đã có quá nhiều ảnh (gói tối đa \(limit) mục)."
        case let .mediaNameCollision(path):
            return "Trong đề đã có ảnh khác cùng tên \(path); không thay ảnh đã có."
        }
    }

    /// "12,5 MiB". Câu ở đây là chuỗi trơn tiếng Việt cho nhật ký (AuthoringData không có catalog), nên số định dạng theo
    /// tiếng Việt cho khớp câu, không theo Region của macOS. Giao diện định dạng theo ngôn ngữ giao diện
    /// (`AuthoringMessages`, bước 7b).
    private static func megabytes(_ bytes: Int) -> String {
        let value = Double(bytes) / Double(1 << 20)
        return value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(Locale(identifier: "vi"))) + " MiB"
    }
}
