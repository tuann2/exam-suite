import ExamFile
import ExamKit
import Foundation
import Observation

/// Bộ lọc của Xem lại bài. Đúng, Sai (đã trả lời nhưng sai) và Chưa làm chia hết các câu; Đã đánh dấu
/// cắt ngang.
public enum AnswerReviewFilter: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all
    case incorrect
    case unanswered
    case flagged
    case correct

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: localized("Tất cả")
        case .incorrect: localized("Sai")
        case .unanswered: localized("Chưa làm")
        case .flagged: localized("Đã đánh dấu")
        case .correct: localized("Đúng")
        }
    }
}

/// Câu trong file đề hiện tại so với lúc thi (theo dấu vân tay).
public enum ReviewQuestionChange: Hashable, Sendable {
    case unchanged
    /// Câu đã sửa sau lần thi; đúng/sai vẫn là kết quả lúc thi.
    case edited
    /// Câu không còn trong đề.
    case deleted
}

/// Trạng thái kết quả của một câu (biểu tượng + chữ).
public struct ReviewOutcomeLabel: Hashable, Sendable {
    public let outcome: QuestionOutcome

    public var title: String {
        switch outcome {
        case .correct: localized("Đúng")
        case .incorrect: localized("Sai")
        case .unanswered: localized("Chưa làm")
        }
    }

    public var systemImage: String {
        switch outcome {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .unanswered: "circle.dashed"
        }
    }
}

/// Một dòng của danh sách câu bên trái.
public struct AnswerReviewRow: Identifiable, Hashable, Sendable {
    public var id: Int { index }
    /// Vị trí trong phiên (0-based).
    public let index: Int
    public let number: Int
    public let status: ReviewOutcomeLabel
    public let isFlagged: Bool
    public let change: ReviewQuestionChange
    /// Đoạn đầu nội dung câu, hoặc "Câu này đã bị xoá khỏi đề".
    public let preview: String

    /// Câu VoiceOver của dòng (accessibility-localization.md: "mỗi dòng câu đọc số + trạng thái"): "Câu 2, Sai, Đánh dấu,
    /// Câu này đã được sửa sau lần thi, <đoạn đầu không ký hiệu Markdown>".
    public var accessibilityLabel: String {
        var parts = [localized("Câu \(number)"), status.title]
        if isFlagged { parts.append(localized("Đánh dấu")) }
        switch change {
        case .unchanged: break
        case .edited: parts.append(localized("Câu này đã được sửa sau lần thi"))
        case .deleted: parts.append(localized("Câu này đã bị xoá khỏi đề"))
        }
        parts.append(PlainMarkdown.text(preview))
        return parts.joined(separator: ", ")
    }
}

/// Một lựa chọn ở chi tiết câu, theo thứ tự đã hiện lúc làm.
public struct ReviewOption: Identifiable, Hashable, Sendable {
    public var id: OptionID { optionID }
    public let label: String
    public let optionID: OptionID
    public let text: String
    /// **Bạn chọn**; luôn `false` với câu đã sửa sau lần thi.
    public let isSelected: Bool
    /// **Đáp án đúng**; nil khi đề ẩn đáp án (`hideAnswers`) hoặc câu đã sửa sau lần thi.
    public let isCorrectAnswer: Bool?

    /// Chữ đi kèm biểu tượng: "Bạn chọn", "Đáp án đúng".
    public var marks: [String] {
        var marks: [String] = []
        if isSelected { marks.append(localized("Bạn chọn")) }
        if isCorrectAnswer == true { marks.append(localized("Đáp án đúng")) }
        return marks
    }

    /// Câu VoiceOver của lựa chọn (accessibility-localization.md: lựa chọn đọc "Bạn chọn", "Đáp án đúng"): "B. <nội dung
    /// không ký hiệu Markdown>, Bạn chọn, Đáp án đúng".
    public var accessibilityLabel: String {
        ([localized("\(label). \(PlainMarkdown.text(text))")] + marks).joined(separator: ", ")
    }
}

/// Chi tiết câu đang xem (bên phải).
public struct AnswerReviewDetail: Hashable, Sendable {
    public let index: Int
    public let number: Int
    public let total: Int
    public let sectionTitle: String
    public let status: ReviewOutcomeLabel
    public let isFlagged: Bool
    public let change: ReviewQuestionChange
    /// Nội dung câu (file đề hiện tại); nil khi câu đã bị xoá.
    public let text: String?
    /// Đường dẫn ảnh trong gói, nếu có.
    public let imagePath: String?
    public let options: [ReviewOption]
    /// Giải thích; nil khi đề không có hoặc đề ẩn đáp án.
    public let explanation: String?
    /// Dòng báo/cảnh báo trên câu: đã xoá; đã sửa (kèm "Không hiện lựa chọn của bạn…").
    public let notices: [String]
}

/// **Xem lại bài** (docs/product/exam-taking.md): danh sách câu theo thứ tự phiên + bộ lọc kèm số lượng,
/// chi tiết câu, Câu trước/sau trong bộ lọc, Luyện lại câu sai.
///
/// Nội dung câu lấy từ `exam` truyền vào: đề lúc thi (vừa nộp) hoặc file đề hiện tại (lần cũ). Dấu vân tay
/// lúc thi cho biết câu đã sửa; đúng/sai luôn là kết quả lúc thi. Đề `hideAnswers`: có Đúng/Sai/Chưa làm
/// nhưng model **không** đưa ra đáp án đúng và giải thích.
@Observable
@MainActor
public final class AnswerReviewModel {
    // Tính mỗi lần đọc (không `static let`): chữ theo ngôn ngữ đang tra, kể cả khi test đổi ngôn ngữ trong tiến trình.
    static var deletedMessage: String { localized("Câu này đã bị xoá khỏi đề") }
    static var editedMessage: String { localized("Câu này đã được sửa sau lần thi") }
    static var marksHiddenMessage: String { localized("Không hiện lựa chọn của bạn vì câu đã sửa sau lần thi") }

    public private(set) var filter: AnswerReviewFilter
    /// Câu đang xem (vị trí trong phiên); nil khi bộ lọc không có câu nào.
    public private(set) var selectedIndex: Int?
    /// Đề ẩn đáp án: không có đáp án đúng, giải thích.
    public let answersHidden: Bool

    @ObservationIgnored private let record: AttemptRecord
    @ObservationIgnored private let questions: [UUID: Question]
    @ObservationIgnored private let changes: [ReviewQuestionChange]
    @ObservationIgnored private let sectionTitles: [UUID: String]
    public let media: [String: Data]

    public init(record: AttemptRecord, exam: Exam, media: [String: Data], filter: AnswerReviewFilter = .all) {
        self.record = record
        self.media = media
        answersHidden = exam.hideAnswers
        var questions: [UUID: Question] = [:]
        for question in exam.allQuestions where questions[question.id] == nil {
            questions[question.id] = question
        }
        self.questions = questions
        changes = record.paper.items.map { item in
            guard let question = questions[item.questionID] else { return .deleted }
            return QuestionFingerprint.fingerprint(of: question) == record.fingerprints[item.questionID]
                ? .unchanged : .edited
        }
        var titles: [UUID: String] = [:]
        for section in record.result.sections where titles[section.sectionID] == nil {
            titles[section.sectionID] = section.title
        }
        sectionTitles = titles
        self.filter = filter
        selectedIndex = nil
        selectedIndex = indices(for: filter).first
    }

    // MARK: - Bộ lọc, danh sách

    public var questionCount: Int { record.paper.items.count }

    private func outcome(at index: Int) -> QuestionOutcome {
        record.result.outcomes[record.paper.items[index].questionID] ?? .unanswered
    }

    private func matches(_ index: Int, _ filter: AnswerReviewFilter) -> Bool {
        switch filter {
        case .all: true
        case .incorrect: outcome(at: index) == .incorrect
        case .unanswered: outcome(at: index) == .unanswered
        case .correct: outcome(at: index) == .correct
        case .flagged: record.flagged.contains(record.paper.items[index].questionID)
        }
    }

    private func indices(for filter: AnswerReviewFilter) -> [Int] {
        record.paper.items.indices.filter { matches($0, filter) }
    }

    /// Vị trí trong phiên (0-based, theo thứ tự phiên) của các câu thuộc bộ lọc `filter`; PDF kết quả chọn câu cho
    /// phần xem lại bằng đúng các bộ lọc này (docs/product/export-print.md).
    public func questionIndices(for filter: AnswerReviewFilter) -> [Int] {
        indices(for: filter)
    }

    /// Số câu của bộ lọc, hiện kèm tên bộ lọc.
    public func count(for filter: AnswerReviewFilter) -> Int {
        indices(for: filter).count
    }

    /// "Sai (3)".
    public func filterTitle(_ filter: AnswerReviewFilter) -> String {
        localized("\(filter.title) (\(count(for: filter)))")
    }

    /// Các dòng của bộ lọc đang chọn, theo thứ tự phiên.
    public var rows: [AnswerReviewRow] {
        indices(for: filter).map { index in
            let item = record.paper.items[index]
            let preview: String
            if let question = questions[item.questionID] {
                preview = String(question.text.split(whereSeparator: \.isNewline).first ?? "")
            } else {
                preview = Self.deletedMessage
            }
            return AnswerReviewRow(
                index: index,
                number: index + 1,
                status: ReviewOutcomeLabel(outcome: outcome(at: index)),
                isFlagged: record.flagged.contains(item.questionID),
                change: changes[index],
                preview: preview
            )
        }
    }

    /// Đổi bộ lọc; câu đang xem không thuộc bộ lọc mới thì chọn câu đầu của bộ lọc.
    public func setFilter(_ newFilter: AnswerReviewFilter) {
        filter = newFilter
        if let selectedIndex, matches(selectedIndex, newFilter) { return }
        selectedIndex = indices(for: newFilter).first
    }

    /// Chọn câu ở vị trí `index` (phải thuộc bộ lọc đang chọn).
    public func select(index: Int) {
        guard record.paper.items.indices.contains(index), matches(index, filter) else { return }
        selectedIndex = index
    }

    public var canGoPrevious: Bool { neighbor(-1) != nil }
    public var canGoNext: Bool { neighbor(1) != nil }

    /// ← : câu trước trong bộ lọc.
    public func previous() {
        if let index = neighbor(-1) { selectedIndex = index }
    }

    /// → : câu sau trong bộ lọc.
    public func next() {
        if let index = neighbor(1) { selectedIndex = index }
    }

    private func neighbor(_ step: Int) -> Int? {
        let list = indices(for: filter)
        guard let selectedIndex, let position = list.firstIndex(of: selectedIndex) else { return nil }
        let target = position + step
        return list.indices.contains(target) ? list[target] : nil
    }

    // MARK: - Chi tiết

    public var detail: AnswerReviewDetail? {
        selectedIndex.map(detail(at:))
    }

    public func detail(at index: Int) -> AnswerReviewDetail {
        let item = record.paper.items[index]
        let selected = record.answers[item.questionID] ?? []
        let change = changes[index]
        var notices: [String] = []
        var options: [ReviewOption] = []
        var text: String?
        var imagePath: String?
        var explanation: String?

        if let question = questions[item.questionID] {
            text = question.text
            imagePath = question.image
            if !answersHidden { explanation = question.explanation }
            let texts = Dictionary(question.options.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
            if change == .edited {
                // Câu đã sửa (Nt0 quyết 2026-10-15): mã lựa chọn đi theo vị trí nên đáp án lúc thi có thể
                // trỏ nhầm sang lựa chọn khác. Hiện lựa chọn hiện tại theo thứ tự file, không đánh dấu
                // Bạn chọn / Đáp án đúng; đúng/sai vẫn là kết quả lúc thi.
                notices.append(Self.editedMessage)
                notices.append(Self.marksHiddenMessage)
                options = question.options.enumerated().map { position, option in
                    ReviewOption(
                        label: SessionFormat.optionLabel(position: position),
                        optionID: option.id,
                        text: option.text,
                        isSelected: false,
                        isCorrectAnswer: nil
                    )
                }
            } else {
                // Câu không đổi: đúng thứ tự đã hiện lúc làm.
                options = item.optionOrder.enumerated().map { position, optionID in
                    ReviewOption(
                        label: SessionFormat.optionLabel(position: position),
                        optionID: optionID,
                        text: texts[optionID] ?? "",
                        isSelected: selected.contains(optionID),
                        isCorrectAnswer: answersHidden ? nil : question.correctSet.contains(optionID)
                    )
                }
            }
        } else {
            notices.append(Self.deletedMessage)
        }

        return AnswerReviewDetail(
            index: index,
            number: index + 1,
            total: questionCount,
            sectionTitle: sectionTitles[item.sectionID] ?? "",
            status: ReviewOutcomeLabel(outcome: outcome(at: index)),
            isFlagged: record.flagged.contains(item.questionID),
            change: change,
            text: text,
            imagePath: imagePath,
            options: options,
            explanation: explanation,
            notices: notices
        )
    }

    // MARK: - Luyện lại câu sai

    /// **Luyện lại câu sai**: câu sai và chưa làm theo thứ tự phiên, chỉ câu còn trong đề. Nil (không có
    /// nút) khi không còn câu nào hoặc đề ẩn đáp án.
    public var practiceIncorrectPreset: PreExamPreset? {
        guard !answersHidden else { return nil }
        let ids = record.result.incorrectOrUnansweredIDs.filter { questions[$0] != nil }
        return ids.isEmpty ? nil : .practiceIncorrect(questionIDs: ids)
    }
}
