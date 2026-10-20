@testable import AuthoringData
import ExamFile
import ExamKit
import Foundation
import Testing

/// Chữ cái lựa chọn luôn theo vị trí, đáp án đúng đi theo nội dung (authoring.md, mục Phần và câu).
@Suite("Lựa chọn và đáp án đúng")
struct OptionEditingTests {
    private let q = fixedID(1)

    private func draft(with question: Question) -> ExamDraft {
        var draft = ExamDraft.newExam()
        try! draft.addQuestion(question, to: draft.exam.sections[0].id)
        return draft
    }

    @Test("Xoá lựa chọn trước đáp án đúng: chữ cái lùi, đáp án đúng đi theo nội dung")
    func removeBeforeCorrect() throws {
        var d = draft(with: makeQuestion(id: q, options: ["p", "q", "r", "s"], correct: "C"))
        try checkUndoRedo(&d) { try $0.removeOption(of: q, at: 0) }
        #expect(d.question(q).optionLetters == "ABC")
        #expect(d.question(q).optionTexts == ["q", "r", "s"])
        #expect(d.question(q).correctLetters == "B")
        #expect(d.validationIssues.isEmpty)
    }

    @Test("Xoá lựa chọn đúng duy nhất: câu không còn đáp án đúng (lỗi), không tự chọn lựa chọn khác")
    func removeOnlyCorrect() throws {
        var d = draft(with: makeQuestion(id: q, options: ["p", "q", "r"], correct: "B"))
        try checkUndoRedo(&d) { try $0.removeOption(of: q, at: 1) }
        #expect(d.question(q).optionTexts == ["p", "r"])
        #expect(d.question(q).correct.isEmpty)
        #expect(d.validationIssues.map(\.code) == [.noCorrectAnswer])
        try checkRoundTrip(d, strict: false)
    }

    @Test("Hai lựa chọn: xoá còn một, rồi không còn lựa chọn nào (lỗi, không chặn); thêm lại về A, B")
    func twoOptionsEdge() throws {
        var d = draft(with: makeQuestion(id: q, options: ["Đúng", "Sai"], correct: "A"))
        try checkUndoRedo(&d) { try $0.removeOption(of: q, at: 0) }
        #expect(d.question(q).optionLetters == "A" && d.question(q).optionTexts == ["Sai"])
        #expect(Set(d.validationIssues.map(\.code)) == [.tooFewOptions, .noCorrectAnswer])
        try checkUndoRedo(&d) { try $0.removeOption(of: q, at: 0) }
        #expect(d.question(q).options.isEmpty)
        try checkRoundTrip(d, strict: false)
        try checkUndoRedo(&d) { try $0.addOption(to: q, text: "x") }
        try checkUndoRedo(&d) { try $0.addOption(to: q, text: "w", at: 0) }
        #expect(d.question(q).optionLetters == "AB" && d.question(q).optionTexts == ["w", "x"])
    }

    @Test("26 lựa chọn: thêm lựa chọn 27 bị từ chối, đề không đổi; xoá đầu vẫn liên tiếp A…Y")
    func twentySixOptions() throws {
        let texts = (0 ..< 26).map { "Lựa chọn \($0 + 1)" }
        var d = draft(with: makeQuestion(id: q, type: .multiple, options: texts, correct: "AZ"))
        #expect(d.question(q).optionLetters == "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        #expect(d.validationIssues.isEmpty)
        let before = d
        #expect(throws: ExamEditError.tooManyOptions) { try d.addOption(to: q) }
        #expect(throws: ExamEditError.tooManyOptions) { try d.addOption(to: q, at: 0) }
        #expect(d == before)
        try checkRoundTrip(d, strict: true)

        try checkUndoRedo(&d) { try $0.removeOption(of: q, at: 0) }
        #expect(d.question(q).optionLetters == "ABCDEFGHIJKLMNOPQRSTUVWXY")
        #expect(d.question(q).optionTexts.first == "Lựa chọn 2")
        // "Lựa chọn 26" (đúng) giờ là Y; "Lựa chọn 1" (đúng) đã xoá.
        #expect(d.question(q).correctLetters == "Y")
        try checkUndoRedo(&d) { try $0.addOption(to: q, text: "Mới", at: 3) }
        #expect(d.question(q).optionLetters.count == 26)
        #expect(d.question(q).optionTexts[3] == "Mới")
        #expect(d.question(q).correctLetters == "Z")
    }

    @Test("Thêm lựa chọn ở giữa: các lựa chọn sau đổi chữ, đáp án đúng đi theo nội dung")
    func insertInMiddle() throws {
        var d = draft(with: makeQuestion(id: q, type: .multiple, options: ["p", "q", "r"], correct: "BC"))
        try checkUndoRedo(&d) { try $0.addOption(to: q, text: "mới", at: 1) }
        #expect(d.question(q).optionTexts == ["p", "mới", "q", "r"])
        #expect(d.question(q).optionLetters == "ABCD")
        #expect(d.question(q).correctLetters == "CD")
    }

    @Test("Sắp xếp lựa chọn (kéo thả): chữ cái theo vị trí mới, đáp án đúng đi theo nội dung", arguments: [
        // (nguồn, đích, thứ tự nội dung mong đợi, đáp án mong đợi) với p, q, r, s và đáp án đúng q, s
        ([0], 4, ["q", "r", "s", "p"], "AC"),
        ([3], 0, ["s", "p", "q", "r"], "AC"),
        ([1, 3], 0, ["q", "s", "p", "r"], "AB"),
        ([0, 2], 4, ["q", "s", "p", "r"], "AB"),
        ([1], 3, ["p", "r", "q", "s"], "CD"),
    ])
    func reorderOptions(source: [Int], destination: Int, texts: [String], correct: String) throws {
        var d = draft(with: makeQuestion(id: q, type: .multiple, options: ["p", "q", "r", "s"], correct: "BD"))
        try checkUndoRedo(&d) { try $0.moveOptions(of: q, fromOffsets: IndexSet(source), toOffset: destination) }
        #expect(d.question(q).optionTexts == texts)
        #expect(d.question(q).optionLetters == "ABCD")
        #expect(d.question(q).correctLetters == correct)
        // Nội dung lựa chọn đúng không đổi.
        let correctTexts = d.question(q).options.filter { d.question(q).correctSet.contains($0.id) }.map(\.text)
        #expect(correctTexts.sorted() == ["q", "s"])
    }

    @Test("Sửa nội dung lựa chọn không đổi chữ cái hay đáp án đúng")
    func editOptionText() throws {
        var d = draft(with: makeQuestion(id: q, options: ["p", "q"], correct: "B"))
        try checkUndoRedo(&d) { try $0.setOptionText(of: q, at: 1, "Q mới") }
        #expect(d.question(q).optionTexts == ["p", "Q mới"])
        #expect(d.question(q).correctLetters == "B")
        #expect(throws: ExamEditError.invalidOptionIndex(2)) { try d.setOptionText(of: q, at: 2, "x") }
    }

    @Test("Đánh dấu đúng: câu một đáp án như radio, câu nhiều đáp án như ô đánh dấu")
    func markCorrect() throws {
        var single = draft(with: makeQuestion(id: q, options: ["p", "q", "r"], correct: "A"))
        try checkUndoRedo(&single) { try $0.setCorrect(of: q, at: 2, true) }
        #expect(single.question(q).correctLetters == "C")
        try checkUndoRedo(&single) { try $0.setCorrect(of: q, at: 2, false) }
        #expect(single.question(q).correct.isEmpty)
        #expect(try single.setCorrect(of: q, at: 1, false).isEmpty)

        var multiple = draft(with: makeQuestion(id: q, type: .multiple, options: ["p", "q", "r"], correct: "A"))
        try checkUndoRedo(&multiple) { try $0.setCorrect(of: q, at: 2, true) }
        #expect(multiple.question(q).correctLetters == "AC")
        try checkUndoRedo(&multiple) { try $0.setCorrect(of: q, at: 0, false) }
        #expect(multiple.question(q).correctLetters == "C")
        #expect(multiple.validationIssues.map(\.code) == [.multipleHasSingleCorrect])
        #expect(throws: ExamEditError.invalidOptionIndex(3)) { try multiple.setCorrect(of: q, at: 3, true) }
    }

    @Test("Đổi Nhiều → Một đáp án: giữ đáp án đúng đầu tiên theo thứ tự lựa chọn; Một → Nhiều giữ nguyên")
    func changeType() throws {
        // `correct` trong file không theo thứ tự: đáp án đầu tiên theo vị trí là B.
        var question = makeQuestion(id: q, type: .multiple, options: ["p", "q", "r", "s"], correct: "DB")
        var d = draft(with: question)
        try checkUndoRedo(&d) { try $0.setQuestionType(q, .single) }
        #expect(d.question(q).type == .single)
        #expect(d.question(q).correctLetters == "B")
        #expect(d.question(q).optionTexts == ["p", "q", "r", "s"])
        #expect(d.validationIssues.isEmpty)
        try checkUndoRedo(&d) { try $0.setQuestionType(q, .multiple) }
        #expect(d.question(q).type == .multiple && d.question(q).correctLetters == "B")
        #expect(try d.setQuestionType(q, .multiple).isEmpty)

        // Không có đáp án đúng: vẫn đổi được, vẫn chưa có đáp án.
        question.correct = []
        var empty = draft(with: question)
        try checkUndoRedo(&empty) { try $0.setQuestionType(q, .single) }
        #expect(empty.question(q).correct.isEmpty)
    }

    @Test("Đề đọc dễ có mã lựa chọn sai thứ tự: thao tác trên lựa chọn đặt lại A, B, C… và giữ đáp án theo nội dung")
    func normalizesOutOfOrderIDs() throws {
        // [A, C, B] với đáp án B (nội dung "ba"), và một mã đáp án không trỏ tới lựa chọn nào (Z).
        let question = Question(
            id: q, type: .single, text: "?",
            options: [Option(id: OptionID("A")!, text: "một"), Option(id: OptionID("C")!, text: "hai"),
                      Option(id: OptionID("B")!, text: "ba")],
            correct: [OptionID("B")!, OptionID("Z")!]
        )
        var d = draft(with: question)
        #expect(d.validationIssues.contains { $0.code == .optionIDOutOfOrder })
        try checkUndoRedo(&d) { try $0.addOption(to: q, text: "bốn") }
        #expect(d.question(q).optionLetters == "ABCD")
        #expect(d.question(q).optionTexts == ["một", "hai", "ba", "bốn"])
        // Đáp án đi theo nội dung "ba" (giờ là C); mã Z không trỏ tới đâu bị bỏ.
        #expect(d.question(q).correctLetters == "C")
        #expect(d.validationIssues.isEmpty)
    }
}
