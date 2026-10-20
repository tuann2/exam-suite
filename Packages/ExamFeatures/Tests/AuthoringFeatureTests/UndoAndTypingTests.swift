import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import Testing

@MainActor
@Suite("Hoàn tác/Làm lại qua document, gộp gõ chữ, ranh giới thao tác cấu trúc")
struct UndoAndTypingTests {
    @Test("Chuỗi thao tác: Hoàn tác hết về đúng đề ban đầu, Làm lại hết về đúng đề sau; document luôn giữ bản mới nhất")
    func undoRedoThroughDocument() throws {
        let h = EditorHarness()
        let original = h.editor.draft
        let q1 = QuestionPath(section: 0, question: 0)
        h.editor.selection = .question(q1)
        h.step { h.editor.addQuestion() }
        let added = try #require(h.editor.selectedQuestionPath)
        h.step { h.editor.setQuestionText(at: added, "Câu mới") }
        h.step { h.editor.addOption(to: added) }
        h.step { h.editor.setOptionText(of: added, at: 2, "C") }
        h.step { h.editor.setCorrect(of: added, at: 2, true) }
        h.step { h.editor.setImage(of: added, data: imageBytes(1), fileExtension: "png") }
        h.step { h.editor.setQuestionType(at: q1, .multiple) }
        h.step { h.editor.setTitle("Tên mới") }
        h.step { h.editor.setPassPercent(80) }
        h.step { h.editor.moveQuestion(at: QuestionPath(section: 0, question: 2), toSection: 1) }
        h.step { h.editor.addSection() }
        h.step { h.editor.removeSection(at: 0) }
        let final = h.editor.draft
        #expect(h.document.draft == final)
        #expect(h.undoCount == 12)

        while h.undo.canUndo { h.undo.undo() }
        #expect(h.editor.draft == original)
        #expect(h.document.draft == original)
        while h.undo.canRedo { h.undo.redo() }
        #expect(h.editor.draft == final)
        #expect(h.document.draft == final)
    }

    @Test("Thay đổi không đổi gì (ExamEdit.isEmpty) không tạo bước Hoàn tác")
    func emptyEditsAreNotRegistered() {
        let h = EditorHarness()
        h.step { h.editor.setTitle("Đề thử") }
        h.step { h.editor.setPassPercent(70) }
        h.step { h.editor.setQuestionText(at: QuestionPath(section: 0, question: 0), "Q1") }
        h.step { h.editor.moveQuestion(at: QuestionPath(section: 0, question: 0), toSection: 0) }
        #expect(!h.undo.canUndo)
    }

    @Test("Thao tác lỗi (thêm lựa chọn thứ 27) không đổi đề, không tạo bước Hoàn tác, báo lý do")
    func failingEditReportsAndKeepsDraft() {
        let letters = (0 ..< 26).map { "Lựa chọn \($0)" }
        var draft = sampleDraft()
        try? draft.updateQuestion(QuestionPath(section: 0, question: 0)) {
            $0 = makeQuestion(11, "Q1", options: letters)
        }
        let h = EditorHarness(draft)
        let before = h.editor.draft
        h.step { h.editor.addOption(to: QuestionPath(section: 0, question: 0)) }
        #expect(h.editor.draft == before)
        #expect(!h.undo.canUndo)
        #expect(h.editor.alert?.message.contains("26") == true)
    }

    @Test("Gõ liên tiếp vào một trường gộp thành một bước; Hoàn tác về trước đoạn gõ, Làm lại ra đủ chữ")
    func typingCoalescesPerField() {
        let h = EditorHarness()
        let p = QuestionPath(section: 0, question: 1)
        h.type("Thủ đô?") { h.editor.setQuestionText(at: p, $0) }
        #expect(h.editor.question(at: p)?.text == "Thủ đô?")
        #expect(h.undoCount == 1)
        h.undo.undo()
        #expect(h.editor.question(at: p)?.text == "Q2")
        h.undo.redo()
        #expect(h.editor.question(at: p)?.text == "Thủ đô?")
        #expect(h.document.draft.question(at: p)?.text == "Thủ đô?")
    }

    @Test("Trường khác, đổi dòng chọn, rời ô (endTyping), Hoàn tác thì mở đoạn gõ mới")
    func typingRunBoundaries() {
        let h = EditorHarness()
        let p = QuestionPath(section: 0, question: 0)
        h.type("ab") { h.editor.setQuestionText(at: p, $0) }
        h.type("x") { h.editor.setOptionText(of: p, at: 0, $0) }
        h.type("xy") { h.editor.setOptionText(of: p, at: 1, $0) }
        #expect(h.undoCount == 3)

        // Đổi dòng chọn rồi quay lại gõ cùng trường: đoạn gõ mới.
        h.editor.selection = .question(QuestionPath(section: 1, question: 0))
        h.editor.selection = .question(p)
        h.type("abc") { h.editor.setQuestionText(at: p, $0) }
        #expect(h.undoCount == 4)

        // Rời ô (tiêu điểm đổi) rồi gõ tiếp: đoạn gõ mới.
        h.editor.endTyping()
        h.type("abcd") { h.editor.setQuestionText(at: p, $0) }
        #expect(h.undoCount == 5)

        // Hoàn tác giữa chừng rồi gõ: không gộp vào bước đã hoàn tác.
        h.undo.undo()
        #expect(h.editor.question(at: p)?.text == "abc")
        h.type("abcX") { h.editor.setQuestionText(at: p, $0) }
        h.undo.undo()
        #expect(h.editor.question(at: p)?.text == "abc")
    }

    @Test("Thao tác cấu trúc đóng đoạn gõ: gõ ở cùng vị trí sau khi xoá câu phía trước là bước mới, Hoàn tác đúng câu")
    func structuralEditClosesTypingRun() {
        let h = EditorHarness()
        let first = QuestionPath(section: 0, question: 0)
        let original = h.editor.draft
        // Gõ vào Q1 (vị trí 0,0), xoá Q1 → Q2 đứng vào (0,0), gõ tiếp vào ô nội dung ở (0,0): cùng `TypingField`
        // nhưng là câu khác. Nếu gộp, Hoàn tác sẽ đặt bản chụp Q1 lên chỗ của Q2.
        h.type("Q1 sửa") { h.editor.setQuestionText(at: first, $0) }
        h.step { h.editor.removeQuestion(at: first) }
        #expect(h.editor.question(at: first)?.id == fixedID(12))
        h.type("Q2 sửa") { h.editor.setQuestionText(at: first, $0) }
        #expect(h.undoCount == 3)

        h.undo.undo()
        #expect(h.editor.question(at: first)?.id == fixedID(12))
        #expect(h.editor.question(at: first)?.text == "Q2")
        h.undo.undo()
        #expect(h.editor.question(at: first)?.id == fixedID(11))
        #expect(h.editor.question(at: first)?.text == "Q1 sửa")
        h.undo.undo()
        #expect(h.editor.draft == original)
    }

    @Test("Sắp xếp lựa chọn giữa hai đoạn gõ cùng lựa chọn: hai bước gõ riêng, Hoàn tác ra đúng chữ ở đúng chỗ")
    func optionReorderClosesTypingRun() {
        let h = EditorHarness()
        let p = QuestionPath(section: 0, question: 0)
        h.type("Một") { h.editor.setOptionText(of: p, at: 0, $0) }
        h.step { h.editor.moveOption(of: p, at: 0, by: 1) }
        // Lựa chọn "Sai" giờ ở vị trí 0.
        h.type("Hai") { h.editor.setOptionText(of: p, at: 0, $0) }
        #expect(h.editor.question(at: p)?.options.map(\.text) == ["Hai", "Một"])
        #expect(h.undoCount == 3)
        h.undo.undo()
        #expect(h.editor.question(at: p)?.options.map(\.text) == ["Sai", "Một"])
        h.undo.undo()
        #expect(h.editor.question(at: p)?.options.map(\.text) == ["Một", "Sai"])
        h.undo.undo()
        #expect(h.editor.question(at: p)?.options.map(\.text) == ["Đúng", "Sai"])
    }

    @Test("Lưu (macOS chụp đề) giữa đoạn gõ: lần gõ sau là bước mới, để document được đánh dấu Đã sửa lại")
    func saveClosesTypingRun() throws {
        let h = EditorHarness()
        let p = QuestionPath(section: 0, question: 0)
        h.type("ab") { h.editor.setQuestionText(at: p, $0) }
        let snapshot = try h.document.snapshot(contentType: .examPackage)
        #expect(snapshot.exam.sections[0].questions[0].text == "ab")
        h.type("abc") { h.editor.setQuestionText(at: p, $0) }
        #expect(h.undoCount == 2)
        h.undo.undo()
        #expect(h.editor.question(at: p)?.text == "ab")
    }

    @Test("Thay đổi đến trong lúc Hoàn tác (ô chữ gửi lại chữ cũ) được áp nhưng không đăng ký thêm")
    func changesDuringUndoAreNotRegistered() {
        let h = EditorHarness()
        let p = QuestionPath(section: 0, question: 0)
        h.type("abc") { h.editor.setQuestionText(at: p, $0) }
        // Một bước Hoàn tác khác của cùng nhóm (như trình soạn chữ của macOS) gửi chữ cũ qua binding.
        h.undo.beginUndoGrouping()
        h.undo.registerUndo(withTarget: h.editor) { editor in editor.setQuestionText(at: p, "Q1") }
        h.undo.endUndoGrouping()
        h.undo.undo()
        #expect(h.editor.question(at: p)?.text == "Q1")
        h.undo.undo()
        #expect(h.editor.question(at: p)?.text == "Q1")
        #expect(!h.undo.canUndo)
    }

    @Test("Tên bước Hoàn tác theo thao tác (menu Sửa)")
    func actionNames() {
        let h = EditorHarness()
        h.step { h.editor.removeQuestion(at: QuestionPath(section: 0, question: 0)) }
        #expect(h.undo.undoActionName == "Xoá câu")
        h.undo.undo()
        #expect(h.undo.redoActionName == "Xoá câu")
    }
}
