import AuthoringData
@testable import AuthoringFeature
import ExamKit
import Foundation
import Testing

@MainActor
@Suite("Dòng chọn sau thao tác, kéo thả trên cây đề, thanh lỗi → dòng/trường, tìm")
struct TreeAndNavigationTests {
    private func path(_ s: Int, _ q: Int) -> QuestionPath { QuestionPath(section: s, question: q) }
    private func ids(_ h: EditorHarness, section: Int) -> [UUID] { h.exam.sections[section].questions.map(\.id) }

    // MARK: - Chọn sau khi xoá

    @Test("Xoá câu giữa phần: chọn câu đứng vào chỗ đó; xoá câu cuối: câu trước; xoá câu duy nhất: dòng phần")
    func selectionAfterDeletingQuestions() {
        let h = EditorHarness()
        h.step { h.editor.removeQuestion(at: path(0, 1)) }
        #expect(h.editor.selection == .question(path(0, 1)))
        #expect(h.editor.question(at: path(0, 1))?.id == fixedID(13))
        h.step { h.editor.removeQuestion(at: path(0, 1)) }
        #expect(h.editor.selection == .question(path(0, 0)))
        h.step { h.editor.removeQuestion(at: path(1, 0)) }
        #expect(h.editor.selection == .section(index: 1))
    }

    @Test("Xoá phần: chọn phần đứng vào chỗ đó, không có thì phần trước, hết phần thì dòng Đề")
    func selectionAfterDeletingSections() {
        let h = EditorHarness()
        h.step { h.editor.removeSection(at: 0) }
        #expect(h.editor.selection == .section(index: 0))
        #expect(h.exam.sections[0].id == fixedID(3))
        h.step { h.editor.removeSection(at: 0) }
        #expect(h.editor.selection == .exam)
    }

    @Test("Hoàn tác xoá câu chọn lại câu vừa khôi phục; Làm lại chọn câu đứng vào chỗ đó")
    func selectionAfterUndoRedoOfDelete() {
        let h = EditorHarness()
        h.editor.selection = .question(path(0, 2))
        h.step { h.editor.removeQuestion(at: path(0, 0)) }
        h.editor.selection = .exam
        h.undo.undo()
        #expect(h.editor.selection == .question(path(0, 0)))
        #expect(h.editor.question(at: path(0, 0))?.id == fixedID(11))
        h.undo.redo()
        #expect(h.editor.selection == .question(path(0, 0)))
        #expect(h.editor.question(at: path(0, 0))?.id == fixedID(12))
    }

    @Test("Xoá phần còn câu thì hỏi lại; phần rỗng xoá luôn; ⌫ trên dòng câu xoá không hỏi")
    func removeSectionAsksWhenNotEmpty() {
        let h = EditorHarness()
        h.editor.requestRemoveSection(at: 1)
        #expect(h.editor.sectionPendingRemoval?.questionCount == 1)
        #expect(h.exam.sections.count == 2)
        h.step { h.editor.removeSection(at: 1) }
        #expect(h.editor.sectionPendingRemoval == nil)
        #expect(h.exam.sections.count == 1)
        h.step { h.editor.addSection() }
        h.editor.selection = .section(index: 1)
        h.step { h.editor.removeSelection() }
        #expect(h.exam.sections.count == 1)
        h.editor.selection = .question(path(0, 0))
        h.step { h.editor.removeSelection() }
        #expect(h.exam.sections[0].questions.count == 2)
    }

    @Test("Thêm câu: ngay sau câu đang chọn, chọn câu mới và đưa tiêu điểm vào nội dung; đề chưa có phần thì thêm phần")
    func addQuestionPlacement() {
        let h = EditorHarness()
        h.editor.selection = .question(path(0, 0))
        h.step { h.editor.addQuestion() }
        #expect(h.editor.selection == .question(path(0, 1)))
        #expect(h.editor.question(at: path(0, 1))?.text == "")
        #expect(h.editor.question(at: path(0, 1))?.options.map(\.id.description) == ["A", "B", "C", "D"])
        #expect(h.editor.question(at: path(0, 1))?.correct.isEmpty == true)
        #expect(h.editor.focusRequest?.focus == .questionText)
        h.editor.selection = .section(index: 1)
        h.step { h.editor.addQuestion() }
        #expect(h.editor.selection == .question(path(1, 1)))

        let empty = EditorHarness(ExamDraft(exam: Exam(id: fixedID(1), title: "Rỗng", passPercent: 70, timeLimitMinutes: 10, sections: [])))
        empty.step { empty.editor.addQuestion() }
        #expect(empty.exam.sections.count == 1)
        #expect(empty.exam.sections[0].title == "Phần 1")
        #expect(empty.editor.selection == .question(path(0, 0)))
        empty.undo.undo()
        #expect(empty.exam.sections.isEmpty)
    }

    @Test("Thêm phần sau phần đang chọn, tên gợi ý \"Phần N\"; nhân bản chọn bản sao; chuyển câu chọn câu ở chỗ mới")
    func addSectionDuplicateMove() {
        let h = EditorHarness()
        h.editor.selection = .question(path(0, 1))
        h.step { h.editor.addSection() }
        #expect(h.editor.selection == .section(index: 1))
        #expect(h.exam.sections[1].title == "Phần 3")
        #expect(h.editor.focusRequest?.focus == .sectionTitle)

        h.step { h.editor.duplicateQuestion(at: path(0, 0)) }
        #expect(h.editor.selection == .question(path(0, 1)))
        #expect(h.editor.question(at: path(0, 1))?.text == "Q1")
        #expect(h.editor.question(at: path(0, 1))?.id != fixedID(11))

        h.step { h.editor.moveQuestion(at: path(0, 0), toSection: 2) }
        #expect(h.editor.selection == .question(path(2, 1)))
        #expect(h.editor.question(at: path(2, 1))?.id == fixedID(11))
    }

    // MARK: - Kéo thả

    @Test("Danh sách phẳng của cây đề")
    func flatRows() {
        let outline = TreeOutline(sampleDraft().exam)
        #expect(outline.rows == [
            .section(index: 0), .question(path(0, 0)), .question(path(0, 1)), .question(path(0, 2)),
            .section(index: 1), .question(path(1, 0)),
        ])
        #expect(outline.question(path(1, 0))?.number == 4)
    }

    @Test("Kéo câu: trong phần, sang phần khác (sau dòng phần = đầu phần), thả tại chỗ = không đổi")
    func resolveQuestionMoves() {
        let rows = TreeOutline(sampleDraft().exam).rows
        // Q1 (dòng 1) thả trước Q3 (dòng 3) → sau Q2.
        #expect(TreeMove.resolve(rows: rows, source: [1], destination: 3) == .question(from: path(0, 0), toSection: 0, at: 1))
        // Q1 thả sau dòng "Phần 2" → đầu Phần 2.
        #expect(TreeMove.resolve(rows: rows, source: [1], destination: 5) == .question(from: path(0, 0), toSection: 1, at: 0))
        // Q4 thả cuối danh sách: không đổi; thả trước dòng "Phần 2" → cuối Phần 1.
        #expect(TreeMove.resolve(rows: rows, source: [5], destination: 6) == nil)
        #expect(TreeMove.resolve(rows: rows, source: [5], destination: 4) == .question(from: path(1, 0), toSection: 0, at: 3))
        // Thả ngay trước/sau chính nó; thả lên đầu (chưa có phần nào phía trên).
        #expect(TreeMove.resolve(rows: rows, source: [2], destination: 2) == nil)
        #expect(TreeMove.resolve(rows: rows, source: [2], destination: 3) == nil)
        #expect(TreeMove.resolve(rows: rows, source: [2], destination: 0) == nil)
        // Kéo nhiều dòng một lúc: không hỗ trợ.
        #expect(TreeMove.resolve(rows: rows, source: [1, 2], destination: 5) == nil)
    }

    @Test("Kéo phần (cả phần cùng câu): thả giữa các câu của phần khác = sau phần đó")
    func resolveSectionMoves() {
        let rows = TreeOutline(sampleDraft().exam).rows
        #expect(TreeMove.resolve(rows: rows, source: [4], destination: 0) == .section(from: 1, toOffset: 0))
        #expect(TreeMove.resolve(rows: rows, source: [0], destination: 6) == .section(from: 0, toOffset: 2))
        #expect(TreeMove.resolve(rows: rows, source: [4], destination: 2) == nil)
        #expect(TreeMove.resolve(rows: rows, source: [0], destination: 4) == nil)
        #expect(TreeMove.resolve(rows: rows, source: [0], destination: 1) == nil)
    }

    @Test("Kéo thả trên cây đề sửa đề (giữ id), chọn dòng ở chỗ mới, Hoàn tác được")
    func treeMovesApplyAndUndo() {
        let h = EditorHarness()
        let original = h.editor.draft
        let rows = h.editor.visibleRows
        h.step { h.editor.moveTreeRows(rows, fromOffsets: [1], toOffset: 6) }
        #expect(ids(h, section: 1) == [fixedID(14), fixedID(11)])
        #expect(h.editor.selection == .question(path(1, 1)))
        h.step { h.editor.moveTreeRows(h.editor.visibleRows, fromOffsets: [3], toOffset: 0) }
        #expect(h.exam.sections.map(\.id) == [fixedID(3), fixedID(2)])
        #expect(h.editor.selection == .section(index: 0))
        h.step { h.editor.moveTreeRows(h.editor.visibleRows, fromOffsets: [0], toOffset: 6) }
        #expect(h.exam.sections.map(\.id) == [fixedID(2), fixedID(3)])
        #expect(h.editor.selection == .section(index: 1))
        h.undo.undo()
        h.undo.undo()
        h.undo.undo()
        #expect(h.editor.draft == original)
    }

    // MARK: - Thanh lỗi

    @Test("Bấm vấn đề trên thanh lỗi: chọn đúng dòng và đưa tiêu điểm tới đúng trường")
    func issueNavigation() async throws {
        var draft = sampleDraft()
        draft.setTitle("")
        try draft.setOptionText(of: QuestionPath(section: 0, question: 1), at: 1, "")
        try draft.setCorrect(of: QuestionPath(section: 0, question: 2), at: 0, false)
        _ = try draft.addSection(title: "Rỗng")
        let h = EditorHarness(draft)
        await h.editor.waitForValidation()
        let issues = h.editor.issues.issues

        func navigate(_ code: IssueCode) throws -> (TreeRow?, AuthoringFocus?) {
            let issue = try #require(issues.first { $0.code == code })
            h.editor.navigate(to: issue)
            return (h.editor.selection, h.editor.focusRequest?.focus)
        }
        #expect(try navigate(.titleEmpty) == (.exam, .examTitle))
        #expect(try navigate(.optionTextEmpty) == (.question(path(0, 1)), .optionText(1)))
        #expect(try navigate(.noCorrectAnswer) == (.question(path(0, 2)), .optionCorrect(0)))
        #expect(try navigate(.sectionHasNoQuestions) == (.section(index: 2), .addQuestion))
        #expect(h.editor.studentRejection == "đề còn \(h.editor.issues.errorCount) lỗi.")

        // Đang tìm và dòng bị lọc khỏi cây: bỏ tìm để thấy dòng.
        h.editor.searchText = "Q1"
        _ = try navigate(.optionTextEmpty)
        #expect(h.editor.searchText.isEmpty)

        // Vấn đề cũ (dòng không còn, kiểm lỗi chưa chạy lại): không đổi gì.
        h.step { h.editor.removeSection(at: 2) }
        h.editor.selection = .exam
        let stale = try #require(issues.first { $0.code == .sectionHasNoQuestions })
        h.editor.navigate(to: stale)
        #expect(h.editor.selection == .exam)
    }

    @Test("Mỗi trường của IssueTarget có chỗ nhận tiêu điểm")
    func focusMapping() {
        let q = QuestionPath(section: 0, question: 0)
        let cases: [(IssueTarget, AuthoringFocus)] = [
            (IssueTarget(node: .exam, field: .code), .examCode),
            (IssueTarget(node: .exam, field: .passPercent), .passPercent),
            (IssueTarget(node: .exam, field: .timeLimitMinutes), .timeLimit),
            (IssueTarget(node: .exam, field: .instructions), .instructions),
            (IssueTarget(node: .exam, field: .sections), .addSection),
            (IssueTarget(node: .section(id: fixedID(2), index: 0), field: .title), .sectionTitle),
            (IssueTarget(node: .section(id: fixedID(2), index: 0), field: .id), .newID),
            (IssueTarget(node: .question(id: fixedID(11), path: q), field: .text), .questionText),
            (IssueTarget(node: .question(id: fixedID(11), path: q), field: .image), .image),
            (IssueTarget(node: .question(id: fixedID(11), path: q), field: .explanation), .explanation),
            (IssueTarget(node: .question(id: fixedID(11), path: q), field: .options), .addOption),
            (IssueTarget(node: .question(id: fixedID(11), path: q), field: .id), .newID),
            (IssueTarget(node: .option(questionID: fixedID(11), path: q, optionIndex: 3), field: .optionID), .optionText(3)),
        ]
        for (target, focus) in cases {
            #expect(AuthoringFocus(target) == focus, "\(target)")
        }
    }

    @Test("Vấn đề hiện dưới đúng ô: lọc theo dòng, trường và lựa chọn")
    func fieldIssues() async throws {
        var draft = sampleDraft()
        try draft.setOptionText(of: QuestionPath(section: 0, question: 0), at: 1, "")
        try draft.setQuestionText(QuestionPath(section: 0, question: 0), "")
        let h = EditorHarness(draft)
        await h.editor.waitForValidation()
        let row = TreeRow.question(path(0, 0))
        #expect(h.editor.issues(for: row, field: .text).map(\.code) == [.questionTextEmpty])
        #expect(h.editor.issues(for: row, option: 1).map(\.code) == [.optionTextEmpty])
        #expect(h.editor.issues(for: row, option: 0).isEmpty)
    }

    @Test("Tìm trong cây đề: không phân biệt hoa thường và dấu, giữ dòng phần của câu khớp")
    func search() throws {
        var draft = sampleDraft()
        try draft.setQuestionText(QuestionPath(section: 1, question: 0), "Thủ đô Hà Nội")
        let h = EditorHarness(draft)
        h.editor.searchText = "ha noi"
        #expect(h.editor.visibleRows == [.section(index: 1), .question(path(1, 0))])
        h.editor.searchText = "  "
        #expect(h.editor.visibleRows.count == 6)
        #expect(TreeSearch.fold("Đề ĐÀO") == "de dao")
    }

    // MARK: - Chỉ mục tìm dựng nền (giai đoạn 5, bước 9)

    @Test("Chỉ mục tìm dựng nền khi mở cửa sổ: lần gõ đầu vào ô tìm chỉ lọc")
    func searchIndexBuiltInBackgroundOnOpen() async throws {
        var draft = sampleDraft()
        try draft.setQuestionText(path(1, 0), "Thủ đô Hà Nội")
        let h = EditorHarness(draft)
        await h.editor.waitForSearchIndex()
        #expect(h.editor.hasSearchIndex)
        h.editor.searchText = "ha noi"
        #expect(h.editor.visibleRows == [.section(index: 1), .question(path(1, 0))])
    }

    @Test("Sửa câu trong lúc chỉ mục đang dựng nền: chỉ mục về có chữ mới, không có chữ cũ")
    func searchIndexReplaysTypingDuringBuild() async {
        let h = EditorHarness()
        // Lần dựng nền chỉ áp kết quả trên main actor, tức là sau các thay đổi đồng bộ này.
        h.step { h.editor.setQuestionText(at: path(0, 1), "Sông Mê Kông") }
        h.step { h.editor.setQuestionText(at: path(0, 2), "Vịnh Hạ Long") }
        await h.editor.waitForSearchIndex()
        #expect(h.editor.hasSearchIndex)
        h.editor.searchText = "me kong"
        #expect(h.editor.visibleRows == [.section(index: 0), .question(path(0, 1))])
        h.editor.searchText = "q2"
        #expect(h.editor.visibleRows.isEmpty)
        h.editor.searchText = "ha long"
        #expect(h.editor.visibleRows == [.section(index: 0), .question(path(0, 2))])
    }

    @Test("Thêm/xoá câu trong lúc dựng hay sau khi đã có chỉ mục: dựng lại nền, kết quả tìm đúng vị trí mới")
    func searchIndexRebuildsAfterStructuralEdits() async {
        let h = EditorHarness()
        // Trong lúc dựng: xoá Q1 (Q2, Q3 lùi lên), rồi sửa câu mới ở vị trí đầu.
        h.step { h.editor.removeQuestion(at: path(0, 0)) }
        h.step { h.editor.setQuestionText(at: path(0, 0), "Cao nguyên Mộc Châu") }
        await h.editor.waitForSearchIndex()
        #expect(h.editor.hasSearchIndex)
        h.editor.searchText = "moc chau"
        #expect(h.editor.visibleRows == [.section(index: 0), .question(path(0, 0))])

        // Sau khi đã có chỉ mục: xoá phần 1, chỉ mục bỏ và dựng lại nền; Q4 giờ ở phần 0.
        h.step { h.editor.removeSection(at: 0) }
        #expect(!h.editor.hasSearchIndex)
        await h.editor.waitForSearchIndex()
        #expect(h.editor.hasSearchIndex)
        h.editor.searchText = "q4"
        #expect(h.editor.visibleRows == [.section(index: 0), .question(path(0, 0))])

        // Hoàn tác (thay đổi ngược cũng đi qua chỉ mục): phần 1 trở lại, Q4 về phần 1.
        h.undo.undo()
        await h.editor.waitForSearchIndex()
        #expect(h.editor.visibleRows == [.section(index: 1), .question(path(1, 0))])
    }

    @Test("Gõ vào ô tìm trước khi lần dựng nền xong: dựng ngay trên main actor, bỏ lần dựng nền")
    func searchBeforeBackgroundIndexIsReady() async {
        let h = EditorHarness()
        h.editor.searchText = "q3"
        #expect(h.editor.visibleRows == [.section(index: 0), .question(path(0, 2))])
        #expect(h.editor.hasSearchIndex)
        await h.editor.waitForSearchIndex()
        h.step { h.editor.setQuestionText(at: path(0, 2), "Đổi") }
        #expect(h.editor.visibleRows.isEmpty)
    }

    @Test("Dựng chỉ mục nền dừng khi bị huỷ; bộ soạn đề đã đóng thì lần dựng nền không giữ nó lại")
    func searchIndexBuildStopsWhenCancelled() async {
        let exam = sampleDraft().exam
        #expect(TreeSearchIndex(exam, isCancelled: { true }) == nil)
        #expect(TreeSearchIndex(exam, isCancelled: { false })?.rows(matching: "q4") == [.section(index: 1), .question(path(1, 0))])
        // Đóng cửa sổ ngay sau khi mở: bộ soạn đề được giải phóng dù lần dựng nền chưa xong.
        weak var closed: AuthoringEditor?
        do {
            let h = EditorHarness(largeDraft(questions: 2_000))
            closed = h.editor
        }
        for _ in 0 ..< 100 where closed != nil { await Task.yield() }
        #expect(closed == nil)
    }
}
