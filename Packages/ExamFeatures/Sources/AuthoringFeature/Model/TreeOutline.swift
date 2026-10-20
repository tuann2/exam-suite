import AuthoringData
import ExamKit
import Foundation

/// Tóm tắt một câu cho dòng trên cây đề (docs/product/authoring.md, mục Cửa sổ): số thứ tự, dòng đầu nội
/// dung, có ảnh, nhiều đáp án. Dấu lỗi/cảnh báo lấy từ `IssueIndex` theo `TreeRow`.
public struct QuestionSummary: Hashable, Sendable {
    public var path: QuestionPath
    /// Số thứ tự trong cả đề, từ 1 (như "Câu 3 trên 60" của cửa sổ làm bài).
    public var number: Int
    /// Dòng đầu không rỗng của nội dung, bỏ khoảng trắng hai đầu; rỗng nếu câu chưa có nội dung.
    public var firstLine: String
    public var hasImage: Bool
    public var isMultiple: Bool

    init(_ question: Question, path: QuestionPath, number: Int) {
        self.path = path
        self.number = number
        firstLine = Self.firstLine(of: question.text)
        hasImage = question.image != nil
        isMultiple = question.type == .multiple
    }

    /// Dòng đầu không rỗng, tối đa 160 ký tự.
    static func firstLine(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return line.count > 160 ? String(line.prefix(160)) + "…" : line
    }
}

public struct SectionSummary: Hashable, Sendable {
    public var index: Int
    public var title: String
    public var questions: [QuestionSummary]
}

/// Cây đề dựng từ `Exam`: phần và câu theo thứ tự file, định danh theo vị trí (`TreeRow`).
///
/// Sửa trong một câu hay đổi tên phần chỉ cập nhật đúng dòng đó (gõ chữ không dựng lại cả cây đề 2.000 câu);
/// thêm/xoá/sắp xếp thì dựng lại.
public struct TreeOutline: Hashable, Sendable {
    public private(set) var sections: [SectionSummary]

    public init(_ exam: Exam) {
        var number = 0
        sections = exam.sections.enumerated().map { si, section in
            SectionSummary(index: si, title: section.title, questions: section.questions.enumerated().map { qi, question in
                number += 1
                return QuestionSummary(question, path: QuestionPath(section: si, question: qi), number: number)
            })
        }
    }

    public var questionCount: Int { sections.reduce(0) { $0 + $1.questions.count } }

    public func question(_ path: QuestionPath) -> QuestionSummary? {
        guard sections.indices.contains(path.section),
              sections[path.section].questions.indices.contains(path.question) else { return nil }
        return sections[path.section].questions[path.question]
    }

    /// Cập nhật cây sau thay đổi `edit` (thay đổi tiến hay thay đổi ngược đều được: chỉ dùng vị trí).
    mutating func update(after edit: ExamEdit, in exam: Exam) {
        if !updateInPlace(edit, exam) { self = TreeOutline(exam) }
    }

    /// Cập nhật tại chỗ nếu `edit` không đổi cấu trúc; `false` nếu cần dựng lại.
    private mutating func updateInPlace(_ edit: ExamEdit, _ exam: Exam) -> Bool {
        switch edit {
        case .setProperties, .insertMedia, .removeMedia:
            return true
        case let .setSectionTitle(_, index):
            guard sections.indices.contains(index), exam.sections.indices.contains(index) else { return false }
            sections[index].title = exam.sections[index].title
            return true
        case let .replaceQuestion(_, path):
            guard let old = question(path), exam.sections.indices.contains(path.section),
                  exam.sections[path.section].questions.indices.contains(path.question) else { return false }
            let question = exam.sections[path.section].questions[path.question]
            sections[path.section].questions[path.question] = QuestionSummary(question, path: path, number: old.number)
            return true
        case let .group(edits):
            for edit in edits where !updateInPlace(edit, exam) { return false }
            return true
        case .insertSection, .removeSection, .permuteSections, .insertQuestion, .removeQuestion, .moveQuestion,
             .permuteQuestions:
            return false
        }
    }

    // MARK: - Dòng phẳng của danh sách

    /// Dòng phần và dòng câu theo thứ tự hiển thị (dòng Đề nằm riêng, không kéo thả được).
    public var rows: [TreeRow] {
        var rows: [TreeRow] = []
        rows.reserveCapacity(sections.count + questionCount)
        for section in sections {
            rows.append(.section(index: section.index))
            rows.append(contentsOf: section.questions.map { .question($0.path) })
        }
        return rows
    }
}

/// Chữ đã chuẩn hoá (`TreeSearch.fold`) của nội dung từng câu, để lọc cây đề khi tìm (⌘F) mà không chuẩn hoá lại cả
/// đề mỗi lần vẽ. Sửa trong một câu chỉ cập nhật câu đó; thêm/xoá/sắp xếp thì dựng lại. Bộ soạn đề dựng nó ngoài main
/// actor khi mở cửa sổ và sau thêm/xoá/sắp xếp (`AuthoringEditor`).
///
/// `@unchecked Sendable`: chỉ giữ `NSString` bất biến (tạo từ `String`, không bao giờ là `NSMutableString`), và là kiểu
/// giá trị (cập nhật thay phần tử của mảng, không sửa `NSString` nào), nên chuyển từ luồng dựng sang main actor an toàn.
struct TreeSearchIndex: @unchecked Sendable {
    /// `NSString` để tìm bằng `range(of:options: .literal)` (so byte UTF-16, không xử lý lại Unicode mỗi lần).
    private var folded: [[NSString]]

    init(_ exam: Exam) {
        folded = exam.sections.map { $0.questions.map { TreeSearch.fold($0.text) as NSString } }
    }

    /// Dựng ở nền, dừng giữa chừng (nil) khi `isCancelled()` đúng; kiểm sau mỗi phần.
    init?(_ exam: Exam, isCancelled: () -> Bool) {
        var folded: [[NSString]] = []
        folded.reserveCapacity(exam.sections.count)
        for section in exam.sections {
            if isCancelled() { return nil }
            folded.append(section.questions.map { TreeSearch.fold($0.text) as NSString })
        }
        self.folded = folded
    }

    /// Cập nhật sau `edit`; `false` nếu cần dựng lại.
    mutating func update(after edit: ExamEdit, in exam: Exam) -> Bool {
        switch edit {
        case .setProperties, .insertMedia, .removeMedia, .setSectionTitle:
            return true
        case let .replaceQuestion(_, path):
            guard folded.indices.contains(path.section), folded[path.section].indices.contains(path.question),
                  let question = exam.sections[safe: path.section]?.questions[safe: path.question] else { return false }
            folded[path.section][path.question] = TreeSearch.fold(question.text) as NSString
            return true
        case let .group(edits):
            for edit in edits where !update(after: edit, in: exam) { return false }
            return true
        case .insertSection, .removeSection, .permuteSections, .insertQuestion, .removeQuestion, .moveQuestion,
             .permuteQuestions:
            return false
        }
    }

    /// Câu có nội dung chứa `needle` (đã chuẩn hoá), kèm dòng phần chứa chúng.
    func rows(matching needle: String) -> [TreeRow] {
        var rows: [TreeRow] = []
        for (si, section) in folded.enumerated() {
            let matches = section.indices.filter { section[$0].range(of: needle, options: .literal).location != NSNotFound }
            guard !matches.isEmpty else { continue }
            rows.append(.section(index: si))
            rows.append(contentsOf: matches.map { .question(QuestionPath(section: si, question: $0)) })
        }
        return rows
    }
}

enum TreeSearch {
    /// Chữ thường, bỏ dấu, "đ" → "d" (như tìm của Thư viện).
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "vi"))
            .replacingOccurrences(of: "đ", with: "d") // l10n-ignore: chuẩn hoá tìm
            .replacingOccurrences(of: "Đ", with: "d") // l10n-ignore: chuẩn hoá tìm
    }
}

/// Một lần kéo thả trên cây đề, đã đổi từ chỉ số dòng phẳng sang thao tác trên đề.
public enum TreeMove: Hashable, Sendable {
    /// Chuyển câu sang phần `toSection`, vị trí cuối cùng `at` (tính sau khi gỡ câu khỏi chỗ cũ), giữ `id`.
    case question(from: QuestionPath, toSection: Int, at: Int)
    /// Sắp xếp phần kiểu `List.onMove`: phần `from` đặt trước phần đang ở vị trí `toOffset` (= số phần là cuối).
    case section(from: Int, toOffset: Int)

    /// Đổi kéo thả trên danh sách phẳng `rows` (`List.onMove`: `source` là chỉ số dòng bị kéo, `destination` là
    /// chỗ chèn tính trên danh sách gốc) sang thao tác trên đề.
    ///
    /// - Câu: đặt sau dòng ngay trước chỗ chèn. Dòng đó là phần → đầu phần đó; là câu → ngay sau câu đó (cùng
    ///   phần). Chèn trước dòng đầu tiên (chưa có phần nào phía trên) thì không làm gì.
    /// - Phần (kéo cả phần cùng câu của nó): chỗ chèn nằm giữa các câu của phần khác thì đặt sau phần đó.
    /// - Chỉ kéo một dòng; trả `nil` nếu không đổi gì hoặc không hợp lệ.
    public static func resolve(rows: [TreeRow], source: IndexSet, destination: Int) -> TreeMove? {
        guard source.count == 1, let from = source.first, rows.indices.contains(from),
              (0 ... rows.count).contains(destination) else { return nil }
        switch rows[from] {
        case .exam:
            return nil
        case let .section(index):
            // Số dòng phần đứng trước chỗ chèn = vị trí mới theo kiểu onMove.
            let sectionsBefore = rows[..<destination].count { if case .section = $0 { true } else { false } }
            // Chỗ chèn ngay sau dòng phần của chính nó (giữa các câu của nó) → không đổi.
            if sectionsBefore == index + 1 || sectionsBefore == index { return nil }
            return .section(from: index, toOffset: sectionsBefore)
        case let .question(path):
            guard destination > 0 else { return nil }
            let target: (section: Int, index: Int)
            switch rows[destination - 1] {
            case .exam: return nil
            case let .section(index): target = (index, 0)
            case let .question(before): target = (before.section, before.question + 1)
            }
            let final = target.section == path.section && path.question < target.index ? target.index - 1 : target.index
            if target.section == path.section && final == path.question { return nil }
            return .question(from: path, toSection: target.section, at: final)
        }
    }
}
