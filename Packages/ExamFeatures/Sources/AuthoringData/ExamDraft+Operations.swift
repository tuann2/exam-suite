import ExamFile
import ExamKit
import Foundation

/// Tên mặc định app ghi vào **nội dung đề**: tên đề mới ("Đề mới") và tên phần ("Phần 1" của đề mới, "Phần N" khi thêm
/// phần). Nt0 chốt 2026-10-17 (plan giai đoạn 5, Decisions; accessibility-localization.md, ghi chú bước 7b và 7c): theo
/// **ngôn ngữ giao diện lúc tạo** (giao diện tiếng Anh: "New Exam", "Section 1"); sau khi tạo là nội dung đề, không dịch
/// lại. AuthoringData không có catalog nên tầng giao diện (AuthoringFeature) truyền tên đã tra catalog của nó;
/// `vietnamese` (ngôn ngữ nguồn) là mặc định cho test và cho nơi gọi không có giao diện.
public struct DefaultContentNames: Sendable {
    /// Tên của đề mới.
    public var examTitle: String
    /// Tên của phần thứ `n` (đánh số từ 1).
    public var sectionTitle: @Sendable (Int) -> String

    public init(examTitle: String, sectionTitle: @escaping @Sendable (Int) -> String) {
        self.examTitle = examTitle
        self.sectionTitle = sectionTitle
    }

    /// Tên tiếng Việt (ngôn ngữ nguồn): "Đề mới", "Phần N".
    public static let vietnamese = DefaultContentNames(examTitle: "Đề mới", sectionTitle: { "Phần \($0)" })
}

/// Giá trị mặc định khi tạo mới (docs/product/authoring.md, mục Mở cửa sổ soạn đề và phương án 2).
public enum AuthoringDefaults {
    public static let passPercent = 70
    public static let timeLimitMinutes = 60

    /// Đề mới: `id` mới, tên đề mới của `names` ("Đề mới"), 70%, 60 phút, `hideAnswers` tắt, một phần chưa có câu tên là
    /// phần thứ nhất của `names` ("Phần 1") (có lỗi "phần không có câu" cho tới khi thêm câu; vẫn lưu được).
    public static func newExam(
        id: UUID = UUID(), sectionID: UUID = UUID(), names: DefaultContentNames = .vietnamese
    ) -> Exam {
        Exam(
            id: id,
            title: names.examTitle,
            passPercent: passPercent,
            timeLimitMinutes: timeLimitMinutes,
            hideAnswers: false,
            sections: [ExamSection(id: sectionID, title: names.sectionTitle(1), questions: [])]
        )
    }

    /// Số lựa chọn của câu mới (authoring.md, phương án 7, Nt0 chốt 2026-10-16).
    public static let blankQuestionOptionCount = 4

    /// Câu trống cho "Thêm câu": một đáp án, chưa có nội dung, bốn lựa chọn trống A–D, chưa có đáp
    /// án đúng (authoring.md, phương án 7). `optionCount` khác chỉ để test dựng câu ngắn hơn.
    public static func blankQuestion(id: UUID = UUID(), optionCount: Int = blankQuestionOptionCount) -> Question {
        Question(
            id: id, type: .single, text: "",
            options: (0 ..< optionCount).map { Option(id: OptionID(index: $0)!, text: "") },
            correct: []
        )
    }
}

// MARK: - Địa chỉ câu và phần

/// Cách chỉ tới một câu: theo id (`UUID`, lần xuất hiện đầu nếu id trùng) hoặc theo vị trí
/// (`QuestionPath`, luôn đúng một câu). Đề đọc dễ có thể có id trùng (exam-format.md, ràng buộc 1):
/// cây đề và thanh lỗi (bước 4) nên định danh dòng câu theo vị trí (`IssueTarget.TreeRow`).
public protocol QuestionAddress: Sendable {
    func resolve(in exam: Exam) throws(ExamEditError) -> QuestionPath
}

/// Cách chỉ tới một phần: theo id (`UUID`, lần xuất hiện đầu nếu id trùng) hoặc theo chỉ số (`Int`, từ 0).
public protocol SectionAddress: Sendable {
    func resolveSection(in exam: Exam) throws(ExamEditError) -> Int
}

extension UUID: QuestionAddress {
    public func resolve(in exam: Exam) throws(ExamEditError) -> QuestionPath {
        for (si, section) in exam.sections.enumerated() {
            if let qi = section.questions.firstIndex(where: { $0.id == self }) {
                return QuestionPath(section: si, question: qi)
            }
        }
        throw .questionNotFound(self)
    }
}

extension QuestionPath: QuestionAddress {
    public func resolve(in exam: Exam) throws(ExamEditError) -> QuestionPath {
        guard exam.sections.indices.contains(section), exam.sections[section].questions.indices.contains(question) else {
            throw .invalidQuestionPath(self)
        }
        return self
    }
}

extension UUID: SectionAddress {
    public func resolveSection(in exam: Exam) throws(ExamEditError) -> Int {
        guard let index = exam.sections.firstIndex(where: { $0.id == self }) else { throw .sectionNotFound(self) }
        return index
    }
}

extension Int: SectionAddress {
    public func resolveSection(in exam: Exam) throws(ExamEditError) -> Int {
        guard exam.sections.indices.contains(self) else { throw .invalidSectionIndex(self) }
        return self
    }
}

extension ExamDraft {
    /// Đề mới mặc định (`AuthoringDefaults.newExam`), chưa có ảnh. `names`: tên mặc định theo ngôn ngữ giao diện lúc tạo
    /// (tầng giao diện truyền vào).
    public static func newExam(
        id: UUID = UUID(), sectionID: UUID = UUID(), names: DefaultContentNames = .vietnamese
    ) -> ExamDraft {
        ExamDraft(exam: AuthoringDefaults.newExam(id: id, sectionID: sectionID, names: names))
    }

    // MARK: - Tìm

    /// Chỉ số của phần có `id` (lần xuất hiện đầu nếu id trùng).
    public func sectionIndex(of id: UUID) -> Int? { try? id.resolveSection(in: exam) }

    /// Vị trí của câu có `id` (lần xuất hiện đầu nếu id trùng, như `Exam.question(id:)`).
    public func path(of questionID: UUID) -> QuestionPath? { try? questionID.resolve(in: exam) }

    public func question(at path: QuestionPath) -> Question? {
        guard let path = try? path.resolve(in: exam) else { return nil }
        return exam.sections[path.section].questions[path.question]
    }

    // MARK: - Thuộc tính đề

    /// Đặt thuộc tính đề. Giá trị như cũ thì không đổi gì và trả `.none` (không tạo bước Hoàn tác).
    @discardableResult
    public mutating func setProperties(_ properties: ExamProperties) -> ExamEdit {
        guard properties != ExamProperties(exam) else { return .none }
        // `setProperties` không bao giờ lỗi.
        return (try? apply(.setProperties(properties))) ?? .none
    }

    @discardableResult
    public mutating func updateProperties(_ change: (inout ExamProperties) -> Void) -> ExamEdit {
        var properties = ExamProperties(exam)
        change(&properties)
        return setProperties(properties)
    }

    @discardableResult
    public mutating func setTitle(_ title: String) -> ExamEdit { updateProperties { $0.title = title } }

    /// Chuỗi rỗng nghĩa là không có mã đề (bỏ trường `code`).
    @discardableResult
    public mutating func setCode(_ code: String?) -> ExamEdit { updateProperties { $0.code = Self.nilIfEmpty(code) } }

    @discardableResult
    public mutating func setPassPercent(_ value: Int) -> ExamEdit { updateProperties { $0.passPercent = value } }

    @discardableResult
    public mutating func setTimeLimitMinutes(_ value: Int) -> ExamEdit { updateProperties { $0.timeLimitMinutes = value } }

    @discardableResult
    public mutating func setHideAnswers(_ value: Bool) -> ExamEdit { updateProperties { $0.hideAnswers = value } }

    /// Chuỗi rỗng nghĩa là không có hướng dẫn (bỏ trường `instructions`).
    @discardableResult
    public mutating func setInstructions(_ text: String?) -> ExamEdit {
        updateProperties { $0.instructions = Self.nilIfEmpty(text) }
    }

    // MARK: - Phần

    /// Tên gợi ý cho phần mới: tên phần thứ N của `names` ("Phần N") với N = số phần + 1, tăng tiếp nếu trùng tên phần
    /// đã có (không phân biệt hoa thường, bỏ khoảng trắng hai đầu).
    public func suggestedSectionTitle(names: DefaultContentNames = .vietnamese) -> String {
        let existing = Set(exam.sections.map(\.title).map(Self.titleKey))
        var n = exam.sections.count + 1
        while existing.contains(Self.titleKey(names.sectionTitle(n))) { n += 1 }
        return names.sectionTitle(n)
    }

    private static func titleKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Thêm phần rỗng ở vị trí `index` (mặc định cuối đề). Không có `title` thì dùng tên gợi ý theo `names`. Trả về id
    /// phần mới và thay đổi ngược.
    @discardableResult
    public mutating func addSection(
        title: String? = nil, at index: Int? = nil, id: UUID = UUID(), names: DefaultContentNames = .vietnamese
    ) throws(ExamEditError) -> (id: UUID, inverse: ExamEdit) {
        let section = ExamSection(id: id, title: title ?? suggestedSectionTitle(names: names), questions: [])
        let inverse = try apply(.insertSection(section, at: index ?? exam.sections.count))
        return (id, inverse)
    }

    /// Xoá phần cùng mọi câu trong đó (giao diện hỏi lại nếu phần còn câu; có Hoàn tác).
    @discardableResult
    public mutating func removeSection(_ section: some SectionAddress) throws(ExamEditError) -> ExamEdit {
        try apply(.removeSection(at: section.resolveSection(in: exam)))
    }

    /// Đổi tên phần. Tên như cũ thì trả `.none`.
    @discardableResult
    public mutating func renameSection(_ section: some SectionAddress, to title: String) throws(ExamEditError) -> ExamEdit {
        let index = try section.resolveSection(in: exam)
        guard exam.sections[index].title != title else { return .none }
        return try apply(.setSectionTitle(title, at: index))
    }

    /// Cấp `id` mới cho phần (giữ tên và câu). Dùng để sửa lỗi id trùng của đề đọc dễ; id phần
    /// không gắn với lịch sử thi.
    @discardableResult
    public mutating func assignNewID(toSection section: some SectionAddress, newID: UUID = UUID()) throws(ExamEditError) -> ExamEdit {
        let index = try section.resolveSection(in: exam)
        var updated = exam.sections[index]
        updated.id = newID
        return try apply(.group([.removeSection(at: index), .insertSection(updated, at: index)]))
    }

    /// Sắp xếp phần kiểu kéo thả (`fromOffsets`/`toOffset` như `List.onMove`). Phần giữ id.
    @discardableResult
    public mutating func moveSections(fromOffsets source: IndexSet, toOffset destination: Int) throws(ExamEditError) -> ExamEdit {
        guard let order = Array<ExamSection>.moveOrder(count: exam.sections.count, fromOffsets: source, toOffset: destination) else {
            throw .invalidPermutation
        }
        if order == Array(order.indices) { return .none }
        return try apply(.permuteSections(order: order))
    }

    // MARK: - Câu

    /// Thêm câu vào phần ở vị trí `index` (mặc định cuối phần). Mặc định là câu trống
    /// `AuthoringDefaults.blankQuestion`.
    @discardableResult
    public mutating func addQuestion(
        _ question: Question = AuthoringDefaults.blankQuestion(), to section: some SectionAddress, at index: Int? = nil
    ) throws(ExamEditError) -> ExamEdit {
        let si = try section.resolveSection(in: exam)
        let qi = index ?? exam.sections[si].questions.count
        return try apply(.insertQuestion(question, at: QuestionPath(section: si, question: qi)))
    }

    /// Xoá câu (không hỏi lại; có Hoàn tác). Ảnh của câu vẫn giữ trong `package.media` tới khi lưu.
    @discardableResult
    public mutating func removeQuestion(_ question: some QuestionAddress) throws(ExamEditError) -> ExamEdit {
        try apply(.removeQuestion(at: question.resolve(in: exam)))
    }

    /// Nhân bản câu: bản sao cùng nội dung (cả ảnh), `id` mới, đặt ngay sau câu gốc trong cùng phần.
    @discardableResult
    public mutating func duplicateQuestion(
        _ question: some QuestionAddress, newID: UUID = UUID()
    ) throws(ExamEditError) -> (id: UUID, inverse: ExamEdit) {
        let path = try question.resolve(in: exam)
        var copy = exam.sections[path.section].questions[path.question]
        copy.id = newID
        let inverse = try apply(.insertQuestion(copy, at: QuestionPath(section: path.section, question: path.question + 1)))
        return (newID, inverse)
    }

    /// Cấp `id` mới cho câu (giữ nội dung và chỗ). Chỉ dùng để sửa lỗi id trùng của đề đọc dễ: lịch
    /// sử thi theo id câu (exam-taking.md), nên câu đổi id không còn nối với các lần thi cũ.
    @discardableResult
    public mutating func assignNewID(toQuestion question: some QuestionAddress, newID: UUID = UUID()) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { $0.id = newID }
    }

    /// Chuyển câu sang phần đích (có thể là phần hiện tại), giữ `id`. `index` là vị trí cuối cùng trong
    /// phần đích (mặc định cuối phần).
    @discardableResult
    public mutating func moveQuestion(
        _ question: some QuestionAddress, toSection section: some SectionAddress, at index: Int? = nil
    ) throws(ExamEditError) -> ExamEdit {
        let from = try question.resolve(in: exam)
        let si = try section.resolveSection(in: exam)
        let count = exam.sections[si].questions.count - (si == from.section ? 1 : 0)
        let to = QuestionPath(section: si, question: index ?? count)
        if to == from { return .none }
        return try apply(.moveQuestion(from: from, to: to))
    }

    /// Sắp xếp câu trong một phần kiểu kéo thả (`fromOffsets`/`toOffset` như `List.onMove`).
    @discardableResult
    public mutating func moveQuestions(
        inSection section: some SectionAddress, fromOffsets source: IndexSet, toOffset destination: Int
    ) throws(ExamEditError) -> ExamEdit {
        let si = try section.resolveSection(in: exam)
        guard let order = Array<Question>.moveOrder(
            count: exam.sections[si].questions.count, fromOffsets: source, toOffset: destination
        ) else { throw .invalidPermutation }
        if order == Array(order.indices) { return .none }
        return try apply(.permuteQuestions(section: si, order: order))
    }

    /// Sửa một câu bằng hàm `change` (giữ chỗ trong đề). Câu không đổi thì trả `.none`.
    @discardableResult
    public mutating func updateQuestion(
        _ address: some QuestionAddress, _ change: (inout Question) throws(ExamEditError) -> Void
    ) throws(ExamEditError) -> ExamEdit {
        let path = try address.resolve(in: exam)
        var question = exam.sections[path.section].questions[path.question]
        try change(&question)
        if question == exam.sections[path.section].questions[path.question] { return .none }
        return try apply(.replaceQuestion(question, at: path))
    }

    @discardableResult
    public mutating func setQuestionText(_ question: some QuestionAddress, _ text: String) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { $0.text = text }
    }

    /// Chuỗi rỗng nghĩa là không có giải thích (bỏ trường `explanation`; dấu vân tay câu phân biệt
    /// "không có" với chuỗi rỗng).
    @discardableResult
    public mutating func setExplanation(_ question: some QuestionAddress, _ text: String?) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { $0.explanation = Self.nilIfEmpty(text) }
    }

    /// Đổi loại câu. Nhiều → Một đáp án khi đang có hơn một đáp án đúng: giữ đáp án đúng đầu tiên
    /// theo thứ tự lựa chọn (authoring.md, phương án 4).
    @discardableResult
    public mutating func setQuestionType(_ question: some QuestionAddress, _ type: QuestionType) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { (question: inout Question) throws(ExamEditError) in
            guard question.type != type else { return }
            question.type = type
            if type == .single {
                var entries = question.optionEntries
                if let first = entries.firstIndex(where: \.isCorrect) {
                    for i in entries.indices where i != first { entries[i].isCorrect = false }
                }
                question.setOptionEntries(entries)
            }
        }
    }

    // MARK: - Lựa chọn

    /// Thêm lựa chọn ở vị trí `index` (mặc định cuối). Tối đa 26 (A–Z).
    @discardableResult
    public mutating func addOption(
        to question: some QuestionAddress, text: String = "", at index: Int? = nil
    ) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { (question: inout Question) throws(ExamEditError) in
            var entries = question.optionEntries
            let position = index ?? entries.count
            guard (0 ... entries.count).contains(position) else { throw .invalidOptionIndex(position) }
            guard entries.count < ExamValidator.Limits.optionCount.upperBound else { throw .tooManyOptions }
            entries.insert(OptionEntry(text: text, isCorrect: false, originalID: OptionID(index: 0)!), at: position)
            question.setOptionEntries(entries)
        }
    }

    /// Xoá lựa chọn ở vị trí `index`; các lựa chọn sau lùi chữ cái, đáp án đúng đi theo nội dung.
    /// Xoá được cả khi còn dưới 2 lựa chọn (validator báo lỗi, không chặn).
    @discardableResult
    public mutating func removeOption(of question: some QuestionAddress, at index: Int) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { (question: inout Question) throws(ExamEditError) in
            var entries = question.optionEntries
            guard entries.indices.contains(index) else { throw .invalidOptionIndex(index) }
            entries.remove(at: index)
            question.setOptionEntries(entries)
        }
    }

    /// Sắp xếp lựa chọn kiểu kéo thả (`fromOffsets`/`toOffset` như `List.onMove`): chữ cái theo vị
    /// trí mới, đáp án đúng đi theo nội dung.
    @discardableResult
    public mutating func moveOptions(
        of question: some QuestionAddress, fromOffsets source: IndexSet, toOffset destination: Int
    ) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { (question: inout Question) throws(ExamEditError) in
            let entries = question.optionEntries
            guard let order = Array<OptionEntry>.moveOrder(count: entries.count, fromOffsets: source, toOffset: destination) else {
                throw .invalidPermutation
            }
            question.setOptionEntries(order.map { entries[$0] })
        }
    }

    /// Sửa nội dung lựa chọn ở vị trí `index` (không đổi chữ cái hay đáp án đúng).
    @discardableResult
    public mutating func setOptionText(
        of question: some QuestionAddress, at index: Int, _ text: String
    ) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { (question: inout Question) throws(ExamEditError) in
            guard question.options.indices.contains(index) else { throw .invalidOptionIndex(index) }
            question.options[index].text = text
        }
    }

    /// Đánh dấu lựa chọn ở vị trí `index` là đúng/sai. Câu một đáp án: đánh dấu đúng thì bỏ đánh
    /// dấu các lựa chọn khác (radio). Câu nhiều đáp án: chỉ đổi lựa chọn đó (ô đánh dấu).
    @discardableResult
    public mutating func setCorrect(
        of question: some QuestionAddress, at index: Int, _ isCorrect: Bool
    ) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { (question: inout Question) throws(ExamEditError) in
            var entries = question.optionEntries
            guard entries.indices.contains(index) else { throw .invalidOptionIndex(index) }
            if question.type == .single && isCorrect {
                for i in entries.indices { entries[i].isCorrect = (i == index) }
            } else {
                entries[index].isCorrect = isCorrect
            }
            question.setOptionEntries(entries)
        }
    }

    // MARK: - Tiện ích

    static func nilIfEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
