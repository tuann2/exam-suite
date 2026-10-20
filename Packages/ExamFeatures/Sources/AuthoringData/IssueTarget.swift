import ExamKit
import Foundation

/// Một dòng trên cây đề, định danh **theo vị trí**: đề đọc dễ có thể có id phần/câu trùng
/// (exam-format.md, ràng buộc 1), nên id không đủ để chọn đúng dòng. Thao tác của `ExamDraft` nhận
/// thẳng `QuestionPath`/chỉ số phần (`QuestionAddress`, `SectionAddress`).
public enum TreeRow: Hashable, Sendable {
    /// Dòng Đề (thuộc tính đề).
    case exam
    case section(index: Int)
    case question(QuestionPath)
}

/// Chỗ trên cửa sổ soạn đề mà một vấn đề của `ExamValidator` trỏ tới: dòng trên cây đề và trường
/// trong trình soạn. Thanh lỗi (bước 4) bấm một dòng thì chọn `node.treeRow` và đưa tiêu điểm tới `field`
/// (docs/product/authoring.md, mục Kiểm lỗi và Cửa sổ).
public struct IssueTarget: Hashable, Sendable {
    public enum Node: Hashable, Sendable {
        /// Dòng Đề (thuộc tính đề).
        case exam
        case section(id: UUID, index: Int)
        case question(id: UUID, path: QuestionPath)
        /// Lựa chọn thứ `optionIndex` (từ 0) trong trình soạn câu.
        case option(questionID: UUID, path: QuestionPath, optionIndex: Int)

        /// Dòng trên cây đề (theo vị trí): phần, hoặc câu (lựa chọn thuộc dòng câu).
        public var treeRow: TreeRow {
            switch self {
            case .exam: .exam
            case let .section(_, index): .section(index: index)
            case let .question(_, path): .question(path)
            case let .option(_, path, _): .question(path)
            }
        }
    }

    /// Trường cần sửa.
    public enum Field: Hashable, Sendable {
        case title
        case code
        case passPercent
        case timeLimitMinutes
        case instructions
        /// Danh sách phần của đề (đề chưa có phần).
        case sections
        /// Danh sách câu của phần (phần chưa có câu).
        case questions
        /// Id trùng: trình soạn không có ô id; sửa bằng `assignNewID(toQuestion:)`/`assignNewID(toSection:)`
        /// hoặc xoá, **theo vị trí** (`node.treeRow`), vì thao tác theo id tác động lần xuất hiện đầu.
        case id
        /// Nội dung câu, hoặc nội dung lựa chọn khi `node` là `.option`.
        case text
        case image
        case explanation
        /// Danh sách lựa chọn (số lựa chọn ngoài 2–26).
        case options
        /// Đáp án đúng (nút đánh dấu đúng) và loại câu.
        case correct
        /// Mã lựa chọn sai thứ tự (đề đọc dễ): sửa bằng sắp xếp hoặc thêm/xoá lựa chọn.
        case optionID
    }

    public var node: Node
    public var field: Field

    public init(node: Node, field: Field) {
        self.node = node
        self.field = field
    }

    /// Chỗ của `issue`. Mỗi `IssueCode` ứng với đúng một trường; vị trí lấy từ `IssueLocation`.
    public init(_ issue: ValidationIssue) {
        switch issue.location {
        case .exam:
            node = .exam
        case let .section(index, id):
            node = .section(id: id, index: index)
        case let .question(si, qi, id):
            node = .question(id: id, path: QuestionPath(section: si, question: qi))
        case let .option(si, qi, oi, questionID):
            node = .option(questionID: questionID, path: QuestionPath(section: si, question: qi), optionIndex: oi)
        }
        field = Self.field(for: issue.code)
    }

    static func field(for code: IssueCode) -> Field {
        switch code {
        case .titleEmpty, .titleTooLong, .duplicateSectionTitle: .title
        case .codeInvalid: .code
        case .passPercentOutOfRange: .passPercent
        case .timeLimitOutOfRange: .timeLimitMinutes
        case .instructionsTooLong: .instructions
        case .noSections: .sections
        case .duplicateID: .id
        case .sectionHasNoQuestions: .questions
        case .questionTextEmpty, .questionTextTooLong, .optionTextEmpty, .optionTextTooLong: .text
        case .explanationTooLong: .explanation
        case .imagePathInvalid, .imageNotFound: .image
        case .tooFewOptions, .tooManyOptions: .options
        case .noCorrectAnswer, .duplicateCorrectAnswer, .correctAnswerNotInOptions,
             .singleHasMultipleCorrect, .multipleHasSingleCorrect: .correct
        case .optionIDOutOfOrder: .optionID
        }
    }
}

/// Vấn đề của đề gom theo dòng trên cây đề (theo vị trí, `TreeRow`), để vẽ dấu lỗi/cảnh báo cạnh
/// từng dòng (bước 4). Vấn đề của lựa chọn tính vào dòng câu chứa nó. Không tra theo id: id trùng
/// (đề đọc dễ) sẽ gộp nhầm hai dòng.
public struct IssueIndex: Sendable {
    public let issues: [ValidationIssue]
    private let byRow: [TreeRow: [ValidationIssue]]

    public init(_ issues: [ValidationIssue]) {
        self.issues = issues
        var rows: [TreeRow: [ValidationIssue]] = [:]
        for issue in issues {
            rows[IssueTarget(issue).node.treeRow, default: []].append(issue)
        }
        byRow = rows
    }

    /// Vấn đề của một dòng: dòng Đề (thuộc tính đề), dòng phần (tên, phần rỗng, id trùng; không gồm
    /// vấn đề của câu trong phần), dòng câu (câu và các lựa chọn của nó).
    public func issues(for row: TreeRow) -> [ValidationIssue] { byRow[row] ?? [] }
    public var examIssues: [ValidationIssue] { issues(for: .exam) }

    public var errorCount: Int { issues.count { $0.severity == .error } }
    public var warningCount: Int { issues.count { $0.severity == .warning } }


    /// Mức nặng nhất trong `issues` (lỗi hơn cảnh báo); `nil` nếu rỗng.
    public static func worstSeverity(_ issues: [ValidationIssue]) -> IssueSeverity? {
        if issues.contains(where: { $0.severity == .error }) { return .error }
        return issues.isEmpty ? nil : .warning
    }
}
