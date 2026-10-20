import ExamFile
import ExamKit
import Foundation

/// Đề đang soạn trong bản Admin (docs/product/authoring.md): `Exam` + byte ảnh, cùng các thao tác
/// sửa. Kiểu giá trị, không giao diện; cửa sổ soạn đề (bước 4) giữ một `ExamDraft`, gọi thao
/// tác, đăng ký thay đổi ngược trả về với `UndoManager`.
///
/// Bất biến:
/// - Chữ cái lựa chọn theo vị trí (A, B, C… liên tiếp); mọi thao tác trên lựa chọn đặt lại chữ
///   cái và đáp án đúng đi theo nội dung (`OptionEditing`).
/// - Không bao giờ đổi tên hay ghi đè ảnh đã có trong gói (dấu vân tay câu băm theo đường dẫn
///   ảnh: đổi tên làm mọi lần thi cũ báo "đã sửa").
/// - Ảnh không còn câu nào dùng vẫn giữ trong `package.media` (để Hoàn tác không mất ảnh) và
///   bị bỏ khi xuất gói (`packageForSaving`).
/// - Không chặn trạng thái sai (phần rỗng, thiếu đáp án…): `validationIssues` báo, không chặn
///   lưu (exam-format.md).
public struct ExamDraft: Sendable {
    public private(set) var package: ExamPackage

    /// Đang trong `batch`: thay đổi ngược của mỗi `apply` được ghi lại để gộp thành một bước.
    private var recorder: [ExamEdit]?

    public init(package: ExamPackage) {
        self.package = package
    }

    public init(exam: Exam, media: [String: Data] = [:]) {
        self.init(package: ExamPackage(exam: exam, media: media))
    }

    public var exam: Exam { package.exam }

    /// Kết quả `ExamValidator` trên đề hiện tại với ảnh có trong gói (cùng quy tắc với bản Học viên).
    public var validationIssues: [ValidationIssue] { package.validationIssues }

    // MARK: - Áp thay đổi nguyên thuỷ

    /// Áp `edit` và trả về thay đổi ngược. Lỗi thì đề không đổi.
    @discardableResult
    public mutating func apply(_ edit: ExamEdit) throws(ExamEditError) -> ExamEdit {
        let inverse = try applyPrimitive(edit)
        recorder?.append(inverse)
        return inverse
    }

    /// Gộp nhiều thao tác thành một bước Hoàn tác: chạy `body`, trả về một thay đổi ngược cho
    /// tất cả. `body` lỗi thì đề trở về như trước khi gọi.
    @discardableResult
    public mutating func batch(_ body: (inout ExamDraft) throws -> Void) throws -> ExamEdit {
        let backup = package
        let outer = recorder
        recorder = []
        do {
            try body(&self)
        } catch {
            package = backup
            recorder = outer
            throw error
        }
        let inverse = ExamEdit.group((recorder ?? []).reversed())
        recorder = outer
        recorder?.append(inverse)
        return inverse
    }

    private mutating func applyPrimitive(_ edit: ExamEdit) throws(ExamEditError) -> ExamEdit {
        switch edit {
        case let .setProperties(properties):
            let old = ExamProperties(package.exam)
            package.exam.title = properties.title
            package.exam.code = properties.code
            package.exam.passPercent = properties.passPercent
            package.exam.timeLimitMinutes = properties.timeLimitMinutes
            package.exam.hideAnswers = properties.hideAnswers
            package.exam.instructions = properties.instructions
            return .setProperties(old)

        case let .insertSection(section, index):
            guard (0 ... package.exam.sections.count).contains(index) else { throw .invalidSectionIndex(index) }
            package.exam.sections.insert(section, at: index)
            return .removeSection(at: index)

        case let .removeSection(index):
            try checkSection(index)
            let removed = package.exam.sections.remove(at: index)
            return .insertSection(removed, at: index)

        case let .setSectionTitle(title, index):
            try checkSection(index)
            let old = package.exam.sections[index].title
            package.exam.sections[index].title = title
            return .setSectionTitle(old, at: index)

        case let .permuteSections(order):
            let inverse = try Self.inversePermutation(order, count: package.exam.sections.count)
            let old = package.exam.sections
            package.exam.sections = order.map { old[$0] }
            return .permuteSections(order: inverse)

        case let .insertQuestion(question, path):
            try checkSection(path.section)
            guard (0 ... package.exam.sections[path.section].questions.count).contains(path.question) else {
                throw .invalidQuestionPath(path)
            }
            package.exam.sections[path.section].questions.insert(question, at: path.question)
            return .removeQuestion(at: path)

        case let .removeQuestion(path):
            try checkQuestion(path)
            let removed = package.exam.sections[path.section].questions.remove(at: path.question)
            return .insertQuestion(removed, at: path)

        case let .moveQuestion(from, to):
            try checkQuestion(from)
            try checkSection(to.section)
            // Số câu của phần đích sau khi gỡ câu khỏi chỗ cũ.
            let destinationCount = package.exam.sections[to.section].questions.count
                - (from.section == to.section ? 1 : 0)
            guard (0 ... destinationCount).contains(to.question) else { throw .invalidQuestionPath(to) }
            let moved = package.exam.sections[from.section].questions.remove(at: from.question)
            package.exam.sections[to.section].questions.insert(moved, at: to.question)
            return .moveQuestion(from: to, to: from)

        case let .permuteQuestions(sectionIndex, order):
            try checkSection(sectionIndex)
            let old = package.exam.sections[sectionIndex].questions
            let inverse = try Self.inversePermutation(order, count: old.count)
            package.exam.sections[sectionIndex].questions = order.map { old[$0] }
            return .permuteQuestions(section: sectionIndex, order: inverse)

        case let .replaceQuestion(question, path):
            try checkQuestion(path)
            let old = package.exam.sections[path.section].questions[path.question]
            package.exam.sections[path.section].questions[path.question] = question
            return .replaceQuestion(old, at: path)

        case let .insertMedia(path, data):
            if let existing = package.media[path] {
                guard existing == data else { throw .mediaNameCollision(path) }
                return .none
            }
            package.media[path] = data
            return .removeMedia(path: path)

        case let .removeMedia(path):
            guard let old = package.media.removeValue(forKey: path) else { return .none }
            return .insertMedia(path: path, data: old)

        case let .group(edits):
            let backup = package
            var inverses: [ExamEdit] = []
            inverses.reserveCapacity(edits.count)
            do throws(ExamEditError) {
                for edit in edits { inverses.append(try applyPrimitive(edit)) }
            } catch {
                package = backup
                throw error
            }
            return .group(inverses.reversed())
        }
    }

    private func checkSection(_ index: Int) throws(ExamEditError) {
        guard package.exam.sections.indices.contains(index) else { throw .invalidSectionIndex(index) }
    }

    private func checkQuestion(_ path: QuestionPath) throws(ExamEditError) {
        guard package.exam.sections.indices.contains(path.section),
              package.exam.sections[path.section].questions.indices.contains(path.question)
        else { throw .invalidQuestionPath(path) }
    }

    /// Hoán vị ngược của `order`; lỗi nếu `order` không phải hoán vị của `0..<count`.
    static func inversePermutation(_ order: [Int], count: Int) throws(ExamEditError) -> [Int] {
        guard order.count == count else { throw .invalidPermutation }
        var inverse = [Int](repeating: -1, count: count)
        for (newIndex, oldIndex) in order.enumerated() {
            guard (0 ..< count).contains(oldIndex), inverse[oldIndex] == -1 else { throw .invalidPermutation }
            inverse[oldIndex] = newIndex
        }
        return inverse
    }
}

extension ExamDraft: Equatable {
    /// So theo nội dung (đề + ảnh); trạng thái `batch` đang chạy không tính.
    public static func == (lhs: ExamDraft, rhs: ExamDraft) -> Bool { lhs.package == rhs.package }
}
