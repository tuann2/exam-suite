import AuthoringData
import ExamKit
import Foundation

/// Dòng được chọn trên cây đề sau một thay đổi (theo vị trí, như `TreeRow`).
enum TreeSelection {
    /// Dòng nên chọn sau khi xoá câu ở `path`: câu đứng vào chỗ đó, không có thì câu trước, không có thì dòng
    /// phần. `exam` là đề sau khi xoá.
    static func afterRemovingQuestion(at path: QuestionPath, in exam: Exam) -> TreeRow {
        guard exam.sections.indices.contains(path.section) else { return afterRemovingSection(at: path.section, in: exam) }
        let count = exam.sections[path.section].questions.count
        if path.question < count { return .question(path) }
        if count > 0 { return .question(QuestionPath(section: path.section, question: count - 1)) }
        return .section(index: path.section)
    }

    /// Dòng nên chọn sau khi xoá phần `index`: phần đứng vào chỗ đó, không có thì phần trước, không có thì dòng Đề.
    static func afterRemovingSection(at index: Int, in exam: Exam) -> TreeRow {
        if exam.sections.indices.contains(index) { return .section(index: index) }
        if !exam.sections.isEmpty { return .section(index: exam.sections.count - 1) }
        return .exam
    }

    /// Dòng nên chọn sau khi áp `edit` (Hoàn tác/Làm lại): chỗ thay đổi diễn ra, để người dùng thấy cái vừa
    /// được hoàn tác. `current` là dòng đang chọn; `exam` là đề sau khi áp.
    static func after(applying edit: ExamEdit, current: TreeRow?, in exam: Exam) -> TreeRow? {
        let row: TreeRow?
        switch edit {
        case .setProperties:
            row = .exam
        case let .insertSection(_, index), let .setSectionTitle(_, index):
            row = .section(index: index)
        case let .removeSection(index):
            row = afterRemovingSection(at: index, in: exam)
        case let .permuteSections(order):
            row = current.map { remap($0, sectionOrder: order) }
        case let .insertQuestion(_, path), let .replaceQuestion(_, path):
            row = .question(path)
        case let .removeQuestion(path):
            row = afterRemovingQuestion(at: path, in: exam)
        case let .moveQuestion(_, to):
            row = .question(to)
        case let .permuteQuestions(section, order):
            if case let .question(path) = current, path.section == section, let new = order.firstIndex(of: path.question) {
                row = .question(QuestionPath(section: section, question: new))
            } else {
                row = .section(index: section)
            }
        case .insertMedia, .removeMedia:
            row = current
        case let .group(edits):
            var selection = current
            for edit in edits {
                selection = after(applying: edit, current: selection, in: exam)
            }
            row = selection
        }
        return valid(row, in: exam)
    }

    /// Vị trí mới của `row` khi các phần được sắp lại (phần mới thứ `i` là phần cũ `order[i]`).
    static func remap(_ row: TreeRow, sectionOrder order: [Int]) -> TreeRow {
        switch row {
        case .exam:
            return .exam
        case let .section(index):
            return order.firstIndex(of: index).map { .section(index: $0) } ?? row
        case let .question(path):
            return order.firstIndex(of: path.section).map { .question(QuestionPath(section: $0, question: path.question)) } ?? row
        }
    }

    /// Vị trí (phần, câu) của một dòng để so khoảng cách; dòng Đề là (-1, -1), dòng phần là (phần, -1).
    static func position(of row: TreeRow) -> (section: Int, question: Int) {
        switch row {
        case .exam: (-1, -1)
        case let .section(index): (index, -1)
        case let .question(path): (path.section, path.question)
        }
    }

    /// Khoảng cách giữa hai vị trí: khác phần thì xa hơn mọi câu cùng phần.
    static func distance(_ a: (section: Int, question: Int), _ b: (section: Int, question: Int)) -> Int {
        abs(a.section - b.section) * 1_000_000 + abs(a.question - b.question)
    }

    /// `row` nếu còn trỏ tới một dòng có thật; không thì dòng gần nhất (câu cuối của phần, phần cuối, dòng Đề).
    static func valid(_ row: TreeRow?, in exam: Exam) -> TreeRow? {
        guard let row else { return nil }
        switch row {
        case .exam:
            return .exam
        case let .section(index):
            return exam.sections.indices.contains(index) ? row : afterRemovingSection(at: index, in: exam)
        case let .question(path):
            guard exam.sections.indices.contains(path.section) else {
                return afterRemovingSection(at: path.section, in: exam)
            }
            return exam.sections[path.section].questions.indices.contains(path.question)
                ? row : afterRemovingQuestion(at: path, in: exam)
        }
    }
}
