import AuthoringData
import ExamFile
import ExamKit
import Foundation

/// Lệnh sửa đề của cửa sổ soạn đề (docs/product/authoring.md). Mỗi lệnh là một bước Hoàn tác, trừ gõ chữ (gộp
/// theo đoạn gõ).
extension AuthoringEditor {
    // MARK: - Thuộc tính đề

    public func setTitle(_ title: String) {
        perform(.editTitle, typing: .examTitle) { $0.setTitle(title) }
    }

    public func setCode(_ code: String) {
        perform(.editCode, typing: .examCode) { $0.setCode(code) }
    }

    public func setPassPercent(_ value: Int) {
        perform(.editPassPercent) { $0.setPassPercent(value) }
    }

    public func setTimeLimitMinutes(_ value: Int) {
        perform(.editTimeLimit) { $0.setTimeLimitMinutes(value) }
    }

    public func setHideAnswers(_ value: Bool) {
        perform(.changeHideAnswers) { $0.setHideAnswers(value) }
    }

    public func setInstructions(_ text: String) {
        perform(.editInstructions, typing: .instructions) { $0.setInstructions(text) }
    }

    // MARK: - Phần

    /// **Thêm phần**: phần rỗng "Phần N" (theo ngôn ngữ giao diện, `contentNames`) ngay sau phần đang chọn (hoặc cuối
    /// đề), chọn nó và đưa tiêu điểm vào ô tên.
    public func addSection() {
        let index = selectedSectionIndex.map { $0 + 1 } ?? draft.exam.sections.count
        let names = contentNames
        guard perform(.addSection, { try $0.addSection(at: index, names: names).inverse }) else { return }
        selection = .section(index: index)
        requestFocus(.sectionTitle)
    }

    public func renameSection(at index: Int, to title: String) {
        perform(.renameSection, typing: .sectionTitle(index)) { try $0.renameSection(index, to: title) }
    }

    /// **Xoá phần**: phần còn câu thì hỏi lại (`sectionPendingRemoval`); phần rỗng xoá luôn. Có Hoàn tác.
    public func requestRemoveSection(at index: Int) {
        guard let section = section(at: index) else { return }
        if section.questions.isEmpty {
            removeSection(at: index)
        } else {
            sectionPendingRemoval = SectionRemovalRequest(
                index: index, title: section.title, questionCount: section.questions.count
            )
        }
    }

    public func removeSection(at index: Int) {
        sectionPendingRemoval = nil
        guard perform(.removeSection, { try $0.removeSection(index) }) else { return }
        selection = TreeSelection.afterRemovingSection(at: index, in: draft.exam)
    }

    /// **Đổi tên** (menu chuột phải của phần): chọn phần và đưa tiêu điểm vào ô tên trong trình soạn.
    public func beginRenamingSection(at index: Int) {
        guard section(at: index) != nil else { return }
        selection = .section(index: index)
        requestFocus(.sectionTitle)
    }

    // MARK: - Câu

    /// **Thêm câu** (⌥⌘N): câu trống (`AuthoringDefaults.blankQuestion`) ngay sau câu đang chọn, hoặc cuối phần
    /// đang chọn, hoặc cuối phần cuối; đề chưa có phần thì thêm "Phần 1" trước. Chọn câu mới, tiêu điểm vào nội dung.
    public func addQuestion() {
        let target: QuestionPath
        let sections = draft.exam.sections
        if let path = selectedQuestionPath {
            target = QuestionPath(section: path.section, question: path.question + 1)
        } else if let index = selectedSectionIndex {
            target = QuestionPath(section: index, question: sections[index].questions.count)
        } else if let last = sections.indices.last {
            target = QuestionPath(section: last, question: sections[last].questions.count)
        } else {
            target = QuestionPath(section: 0, question: 0)
        }
        let names = contentNames
        let ok = perform(.addQuestion) { draft in
            try draft.batch { draft in
                if draft.exam.sections.isEmpty { try draft.addSection(names: names) }
                try draft.addQuestion(to: target.section, at: target.question)
            }
        }
        guard ok else { return }
        selection = .question(target)
        requestFocus(.questionText)
    }

    /// **Nhân bản**: bản sao có `id` mới, ngay sau câu gốc; chọn bản sao.
    public func duplicateQuestion(at path: QuestionPath) {
        guard perform(.duplicateQuestion, { try $0.duplicateQuestion(path).inverse }) else { return }
        selection = .question(QuestionPath(section: path.section, question: path.question + 1))
    }

    /// **Xoá** câu: không hỏi lại (có Hoàn tác, authoring.md phương án 5); chọn câu đứng vào chỗ đó, không có thì
    /// câu trước, không có thì dòng phần.
    public func removeQuestion(at path: QuestionPath) {
        guard perform(.removeQuestion, { try $0.removeQuestion(path) }) else { return }
        selection = TreeSelection.afterRemovingQuestion(at: path, in: draft.exam)
    }

    /// **Chuyển tới phần ▸**: chuyển câu (giữ `id`) xuống cuối phần đích; chọn câu ở chỗ mới.
    public func moveQuestion(at path: QuestionPath, toSection section: Int) {
        guard section != path.section, self.section(at: section) != nil else { return }
        let destination = QuestionPath(section: section, question: draft.exam.sections[section].questions.count)
        guard perform(.moveQuestion, { try $0.moveQuestion(path, toSection: section) }) else { return }
        selection = .question(destination)
    }

    /// Kéo thả trên cây đề (`List.onMove` trên danh sách phẳng `rows`): sắp xếp câu trong phần, chuyển câu sang
    /// phần khác, sắp xếp phần. Chọn dòng vừa kéo ở chỗ mới.
    public func moveTreeRows(_ rows: [TreeRow], fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let move = TreeMove.resolve(rows: rows, source: source, destination: destination) else { return }
        apply(move)
    }

    func apply(_ move: TreeMove) {
        switch move {
        case let .question(from, section, index):
            let ok = perform(.moveQuestion) { try $0.moveQuestion(from, toSection: section, at: index) }
            if ok { selection = .question(QuestionPath(section: section, question: index)) }
        case let .section(from, offset):
            let ok = perform(.reorderSections) {
                try $0.moveSections(fromOffsets: IndexSet(integer: from), toOffset: offset)
            }
            if ok { selection = .section(index: offset > from ? offset - 1 : offset) }
        }
    }

    public func setQuestionText(at path: QuestionPath, _ text: String) {
        perform(.editQuestionText, typing: .questionText(path)) { try $0.setQuestionText(path, text) }
    }

    public func setExplanation(at path: QuestionPath, _ text: String) {
        perform(.editExplanation, typing: .explanation(path)) { try $0.setExplanation(path, text) }
    }

    /// **Một đáp án** / **Nhiều đáp án**. Nhiều → Một khi có hơn một đáp án đúng: giữ đáp án đúng đầu tiên.
    public func setQuestionType(at path: QuestionPath, _ type: QuestionType) {
        perform(.changeQuestionType) { try $0.setQuestionType(path, type) }
    }

    /// Cấp `id` mới cho phần hoặc câu có id trùng (đề đọc dễ). Id câu gắn với lịch sử thi: câu đổi id không còn
    /// nối với các lần thi cũ, nên chỉ hiện nút này khi dòng có lỗi id trùng.
    public func assignNewID(to row: TreeRow) {
        switch row {
        case let .section(index):
            perform(.assignNewID) { try $0.assignNewID(toSection: index) }
        case let .question(path):
            perform(.assignNewID) { try $0.assignNewID(toQuestion: path) }
        case .exam:
            break
        }
    }

    // MARK: - Lựa chọn

    /// **Thêm lựa chọn** (⌥⌘↩): lựa chọn trống ở cuối; tiêu điểm vào ô chữ của nó. Tối đa 26 (A–Z).
    public func addOption(to path: QuestionPath) {
        guard let count = question(at: path)?.options.count else { return }
        guard perform(.addOption, { try $0.addOption(to: path) }) else { return }
        requestFocus(.optionText(count))
    }

    public func removeOption(of path: QuestionPath, at index: Int) {
        guard perform(.removeOption, { try $0.removeOption(of: path, at: index) }) else { return }
        if let count = question(at: path)?.options.count {
            requestFocus(count == 0 ? .addOption : .optionText(min(index, count - 1)))
        }
    }

    /// Sắp xếp lựa chọn kiểu `List.onMove`: chữ cái theo vị trí mới, đáp án đúng đi theo nội dung.
    public func moveOptions(of path: QuestionPath, fromOffsets source: IndexSet, toOffset destination: Int) {
        perform(.reorderOptions) {
            try $0.moveOptions(of: path, fromOffsets: source, toOffset: destination)
        }
    }

    /// Đưa lựa chọn `index` lên (`offset` = -1) hoặc xuống (+1) một bậc (menu, hành động trợ năng).
    public func moveOption(of path: QuestionPath, at index: Int, by offset: Int) {
        guard let count = question(at: path)?.options.count else { return }
        let target = index + offset
        guard (0 ..< count).contains(index), (0 ..< count).contains(target), offset != 0 else { return }
        moveOptions(of: path, fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
        requestFocus(.optionText(target))
    }

    public func setOptionText(of path: QuestionPath, at index: Int, _ text: String) {
        perform(.editOption, typing: .optionText(path, index)) {
            try $0.setOptionText(of: path, at: index, text)
        }
    }

    public func setCorrect(of path: QuestionPath, at index: Int, _ isCorrect: Bool) {
        perform(.changeCorrectAnswer) { try $0.setCorrect(of: path, at: index, isCorrect) }
    }

    // MARK: - Ảnh

    /// **Thêm/Thay ảnh**: byte gốc của file ảnh (đã đọc bằng `ImageFileLoader`). Từ chối kèm lý do khi vượt
    /// giới hạn hay sai loại.
    public func setImage(of path: QuestionPath, data: Data, fileExtension: String, limits: ExamPackageLimits = .default) {
        let action: EditAction = question(at: path)?.image == nil ? .addImage : .replaceImage
        perform(action) { try $0.setImage(of: path, data: data, fileExtension: fileExtension, limits: limits).inverse }
    }

    public func removeImage(of path: QuestionPath) {
        perform(.removeImage) { try $0.removeImage(of: path) }
    }

    /// Báo lỗi đọc file ảnh (trước khi đổi đề).
    public func reportImageError(_ error: any Error, replacing: Bool) {
        alert = AuthoringAlert(
            title: replacing ? EditAction.replaceImage.failureTitle : EditAction.addImage.failureTitle,
            message: AuthoringMessages.message(for: error)
        )
    }

    // MARK: - Trạng thái lệnh menu

    public var canAddOption: Bool {
        guard let path = selectedQuestionPath, let question = question(at: path) else { return false }
        return question.options.count < ExamValidator.Limits.optionCount.upperBound
    }

    /// Xoá dòng đang chọn (⌫ trên cây đề, menu Đề).
    public func removeSelection() {
        switch selection {
        case let .question(path): removeQuestion(at: path)
        case let .section(index): requestRemoveSection(at: index)
        case .exam, nil: break
        }
    }
}
