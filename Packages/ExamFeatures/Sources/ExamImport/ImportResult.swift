import ExamFile
import ExamKit
import Foundation

/// Kết quả chuyển đổi một file `.txt`/`.docx`/`.vce` thành đề (docs/product/import.md).
///
/// Chưa phải `Exam` hoàn chỉnh: tiêu đề, mã đề, ngưỡng đậu và thời gian do người dùng xác nhận trong hộp thoại
/// (import.md, Luồng bước 3), nên đề chỉ được dựng bằng `makePackage(_:)` sau khi có `ImportConfirmation`.
/// Không có giá trị giả cho ngưỡng/thời gian trong kết quả.
public struct ImportResult: Equatable, Sendable {
    /// `id` của đề, sinh ngẫu nhiên mỗi lần import (import.md, phương án 4); riêng `.oef` là id dẫn xuất từ mã và tiêu
    /// đề trong file, như khi bản Học viên mở thẳng file đó (exam-format.md, mục File `.oef`).
    public var examID: UUID
    /// Các phần theo thứ tự xuất hiện; mọi `id` ngẫu nhiên (`.oef`: dẫn xuất như `examID`), chuỗi đã chuẩn hoá NFC và
    /// bỏ khoảng trắng hai đầu.
    public var sections: [ExamSection]
    /// Ảnh được câu hỏi tham chiếu, khoá `media/<sha256>.<ext>` (như `ExamPackage.media`).
    public var media: [String: Data]
    /// Câu bị bỏ và cảnh báo, theo thứ tự trong file gốc.
    public var report: ImportReport
    /// Giá trị điền sẵn cho hộp thoại xác nhận.
    public var suggestions: ImportSuggestions
    /// Định dạng file gốc.
    public var sourceFormat: ImportSourceFormat
    /// Hướng dẫn và cờ ẩn đáp án đọc từ file (chỉ `.oef` có); hộp xác nhận không hỏi hai giá trị này.
    public var instructions: String?
    public var hideAnswers: Bool

    public init(
        examID: UUID,
        sections: [ExamSection],
        media: [String: Data],
        report: ImportReport,
        suggestions: ImportSuggestions,
        sourceFormat: ImportSourceFormat,
        instructions: String? = nil,
        hideAnswers: Bool = false
    ) {
        self.examID = examID
        self.sections = sections
        self.media = media
        self.report = report
        self.suggestions = suggestions
        self.sourceFormat = sourceFormat
        self.instructions = instructions
        self.hideAnswers = hideAnswers
    }

    /// Số câu giữ lại (không gồm câu bị bỏ).
    public var questionCount: Int { sections.reduce(0) { $0 + $1.questions.count } }

    /// Dựng gói đề với giá trị người dùng đã xác nhận. Tiêu đề và mã được chuẩn hoá NFC, bỏ khoảng trắng hai đầu;
    /// mã rỗng thành `nil`. Không kiểm khoảng giá trị: lỗi (nếu có) hiện trên thanh lỗi như mọi đề.
    public func makePackage(_ confirmation: ImportConfirmation) -> ExamPackage {
        let code = confirmation.code.map(TextNormalizer.clean).flatMap { $0.isEmpty ? nil : $0 }
        let exam = Exam(
            id: examID,
            title: TextNormalizer.clean(confirmation.title),
            code: code,
            passPercent: confirmation.passPercent,
            timeLimitMinutes: confirmation.timeLimitMinutes,
            hideAnswers: hideAnswers,
            instructions: instructions,
            sections: sections
        )
        return ExamPackage(exam: exam, media: media)
    }
}

/// Giá trị người dùng xác nhận trong hộp thoại import (bước 4 của giai đoạn 4 dựng hộp thoại).
public struct ImportConfirmation: Equatable, Sendable {
    public var title: String
    public var code: String?
    public var passPercent: Int
    public var timeLimitMinutes: Int

    public init(title: String, code: String?, passPercent: Int, timeLimitMinutes: Int) {
        self.title = title
        self.code = code
        self.passPercent = passPercent
        self.timeLimitMinutes = timeLimitMinutes
    }
}

/// Giá trị gợi ý lấy từ file (import.md, Luồng bước 3). `nil` = file không có, hộp thoại để trống và bắt nhập.
public struct ImportSuggestions: Equatable, Sendable {
    /// txt: tên file bỏ đuôi; docx: đoạn đầu tiên của đầu đề; vce: trường tiêu đề (không có thì tên file bỏ đuôi).
    public var title: String
    /// docx `Number:`, vce trường mã đề, khi khớp mẫu mã của schema.
    public var code: String?
    /// docx `Passing Score: N`, vce trường điểm đậu: N > 100 thì N/10 làm tròn gần nhất (nửa lên), ngược lại N.
    public var passPercent: Int?
    /// docx `Time Limit: N min`, vce trường thời gian (phút).
    public var timeLimitMinutes: Int?

    public init(title: String, code: String? = nil, passPercent: Int? = nil, timeLimitMinutes: Int? = nil) {
        self.title = title
        self.code = code
        self.passPercent = passPercent
        self.timeLimitMinutes = timeLimitMinutes
    }
}

public enum ImportSourceFormat: String, Sendable, CaseIterable {
    case txt
    case docx
    /// Avanset VCE (ADR 0009, docs/notes/vce-format.md).
    case vce
    /// Open Exam Suite, bản Protobuf (ADR 0014): đọc bằng `OEFReader` của ExamFile ở chế độ dễ.
    case oef

    /// Định dạng theo đuôi file (không phân biệt hoa thường); `nil` nếu không hỗ trợ.
    public init?(fileExtension: String) {
        self.init(rawValue: fileExtension.lowercased())
    }
}

/// Báo cáo import: từng câu bị bỏ hoặc có cảnh báo, kèm vị trí trong file gốc và lý do (import.md, Luồng bước 5). Mỗi
/// loại mục (mã) có chi tiết 1.000 mục đầu; phần còn lại của loại đó thành một mục tóm tắt (`isSummary`).
/// Lỗi kiểm tra của đề (exam-format.md) không nằm ở đây: thanh lỗi của cửa sổ soạn đề hiện chúng.
public struct ImportReport: Equatable, Sendable {
    public var entries: [ImportReportEntry]

    public init(entries: [ImportReportEntry] = []) {
        self.entries = entries
    }

    /// Số câu bị bỏ (kể cả các câu chỉ được đếm trong mục tóm tắt).
    public var droppedCount: Int { entries.reduce(0) { $0 + ($1.severity == .dropped ? $1.occurrences : 0) } }
    /// Số cảnh báo (kể cả các mục chỉ được đếm trong mục tóm tắt).
    public var warningCount: Int { entries.reduce(0) { $0 + ($1.severity == .warning ? $1.occurrences : 0) } }
}

public enum ImportSeverity: String, Sendable {
    /// Câu bị bỏ, không có trong đề.
    case dropped
    /// Nội dung được giữ (hoặc phần nhỏ bị bỏ qua), cần người soạn đề xem lại.
    case warning
}

/// Mã ổn định của từng loại mục báo cáo (giao diện và test nhận diện mà không phụ thuộc câu chữ).
public enum ImportIssueCode: String, Sendable, CaseIterable {
    /// Câu không có lựa chọn nào: bị bỏ (import.md, phương án 7).
    case noOptions
    /// txt: văn bản trước câu đầu tiên, bị bỏ qua.
    case textBeforeFirstQuestion
    /// Dòng/đoạn bắt đầu bằng chữ cái lựa chọn không đúng thứ tự, được coi là phần nối của phần trước.
    case optionLabelOutOfOrder
    /// Câu không có lựa chọn A: lựa chọn bắt đầu từ chữ khác được đánh lại A, B, C… theo vị trí, đáp án đổi theo.
    case optionLabelsShifted
    /// Câu có lựa chọn nhưng không có dòng `Correct Answer:`.
    case missingAnswer
    /// Dòng đáp án không đọc được thành chữ cái A–Z.
    case answerUnreadable
    /// Câu có nhiều dòng đáp án khác nhau; giữ dòng đầu.
    case conflictingAnswer
    /// Văn bản giữa đáp án và giải thích không thuộc phần nào, bị bỏ qua.
    case unrecognizedText
    /// docx `Number:` không khớp mẫu mã đề, bị bỏ.
    case invalidCode
    /// docx `Passing Score:` không đọc được (không phải số, quá 6 chữ số) hoặc ngoài 0–100 %.
    case invalidPassingScore
    /// docx `Time Limit:` không đọc được (không phải số, quá 6 chữ số).
    case invalidTimeLimit
    /// Ảnh thứ hai trở đi trong đề bài, bị bỏ (một ảnh mỗi câu).
    case extraImage
    /// Ảnh trong lựa chọn, giải thích hoặc đầu đề, bị bỏ.
    case imageOutsideQuestionText
    /// Ảnh có định dạng ngoài danh sách của exam-format.md (ví dụ `emf`), bị bỏ.
    case unsupportedImageFormat
    /// Ảnh liên kết ra ngoài hoặc không có trong file, bị bỏ.
    case imageNotFound
    /// Ảnh vượt giới hạn kích thước, bị bỏ.
    case imageTooLarge
    /// docx: `numbering.xml` có số bắt đầu danh sách ngoài 0–32767, bị bỏ qua.
    case invalidNumbering
    /// Bảng được chuyển thành văn bản (ô cách nhau bằng ` | `).
    case tableConverted
    /// docx: danh sách lựa chọn quá 26 mục; mục thứ 27 trở đi nối vào lựa chọn Z.
    case tooManyOptions
    /// Đã tự sửa dãy chắc chắn lỗi mã hoá (`â€™` → `’`) trong câu (import.md, phương án 10); một mục mỗi câu, kèm số
    /// chỗ và chuỗi trước/sau.
    case mojibakeFixed
    /// Có dãy nghi lỗi mã hoá nhưng không chắc (ví dụ `Ã©`, chữ hoa có dấu sát `”`): chữ giữ nguyên, chỉ cảnh báo
    /// kèm số chỗ và các dãy (import.md, phương án 10).
    case mojibakeSuspected
    /// vce: loại câu khác loại trắc nghiệm đã biết (5): câu bị bỏ (kéo thả, điền chỗ trống… chưa đọc được).
    case unsupportedQuestionType
    /// vce: bản ghi câu không khớp bố cục đã biết (số khối nội dung khác số lựa chọn, byte lạ): câu bị bỏ.
    case unreadableQuestion
    /// vce: nội dung RVF chưa hỗ trợ (ảnh, bảng, đường kẻ, chữ lưu dạng hex…) bị bỏ qua, phần còn lại giữ.
    case unsupportedContent
    /// vce: chữ có kiểu chữ khác 0 (đậm, nghiêng…) được giữ dạng chữ thường, chỉ bỏ định dạng; một mục mỗi câu.
    case formattingDropped
    /// vce: file có nhiều nhóm đề; câu không thuộc phần nào xếp vào "Phần chung" (hoặc nhóm có tên duy nhất), có thể
    /// khác cách nhóm của VCE.
    case multipleGroups
    /// vce: đáp án có dấu phân cách (khác mẫu viết liền) hoặc cờ nhiều đáp án không khớp số đáp án.
    case unexpectedAnswerFormat
    /// vce: câu trỏ tới id phần không có trong bảng phần, hoặc tới phần không tên; xếp vào phần thay thế.
    case unknownSection
    /// vce: chữ 1 byte/ký tự có byte ngoài ASCII, đã đọc theo Windows-1252 (giả thuyết chưa kiểm trên file mẫu).
    case assumedEncoding
    /// oef: trường không có trong định dạng đã biết, bị bỏ qua.
    case unknownField
    /// oef: phần không có câu nào, bị bỏ.
    case emptySection
    /// oef: phần không có tên, đặt tên phần chung.
    case untitledSection
    /// oef: hai lựa chọn của một câu cùng chữ cái.
    case duplicateOptionLetter
    /// oef: đáp án không khớp lựa chọn nào, bị bỏ.
    case answerNotInOptions

    public var severity: ImportSeverity {
        switch self {
        case .noOptions, .unsupportedQuestionType, .unreadableQuestion: .dropped
        default: .warning
        }
    }
}

/// Vị trí trong file gốc.
public struct ImportLocation: Equatable, Hashable, Sendable {
    /// Số câu như ghi trong file (`Q12:` → 12, `QUESTION 3` → 3; vce: thứ tự câu trong file, từ 1); `nil` = ngoài câu
    /// hỏi (đầu file).
    public var questionNumber: Int?
    /// Số dòng (từ 1) với txt; `nil` với docx.
    public var line: Int?

    public init(questionNumber: Int? = nil, line: Int? = nil) {
        self.questionNumber = questionNumber
        self.line = line
    }

    /// "câu 12, dòng 345", "câu 3", "dòng 2", "đầu file": tiếng Việt cho nhật ký và test (giao diện dựng chữ của catalog
    /// từ `questionNumber`, `line`).
    public var logDescription: String {
        var parts: [String] = []
        if let questionNumber { parts.append("câu \(questionNumber)") }
        if let line { parts.append("dòng \(line)") }
        return parts.isEmpty ? "đầu file" : parts.joined(separator: ", ")
    }
}

/// Một mục của báo cáo import.
public struct ImportReportEntry: Equatable, Sendable {
    public let code: ImportIssueCode
    public var severity: ImportSeverity { code.severity }
    public let location: ImportLocation
    /// Câu tương ứng trong đề đã chuyển (để nhảy tới); `nil` nếu câu bị bỏ hoặc mục không thuộc câu nào.
    public var questionID: UUID?
    /// Lý do và đối số (không gồm vị trí): giao diện dựng câu bằng chữ của catalog (bước 7b).
    public let detail: ImportIssueDetail
    /// Số mục mà mục này đại diện: 1 với mục thường; N (≥ 2) với mục tóm tắt.
    public let occurrences: Int
    /// Mục tóm tắt "… và N mục tương tự" khi một loại mục vượt trần chi tiết: không có vị trí, không trỏ tới câu.
    public let isSummary: Bool

    public init(code: ImportIssueCode, location: ImportLocation, questionID: UUID?, detail: ImportIssueDetail,
                occurrences: Int = 1, isSummary: Bool = false)
    {
        self.code = code
        self.location = location
        self.questionID = questionID
        self.detail = detail
        self.occurrences = occurrences
        self.isSummary = isSummary
    }

    /// Lý do, tiếng Việt (nhật ký, test; giao diện không dùng).
    public var logMessage: String { detail.logMessage }
}
