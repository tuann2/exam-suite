@testable import AuthoringData
import ExamFile
import ExamKit
import Foundation
import Testing

@Suite("Ghi rồi đọc lại, dấu vân tay câu, chuỗi Hoàn tác/Làm lại")
struct RoundTripAndUndoTests {
    /// Soạn một đề hoàn chỉnh từ Đề mới chỉ bằng thao tác của `ExamDraft`.
    private func authoredExam() throws -> ExamDraft {
        var d = ExamDraft.newExam(id: fixedID(1), sectionID: fixedID(2))
        d.setTitle("Đề soạn thử")
        d.setCode("DST-01")
        d.setPassPercent(80)
        d.setTimeLimitMinutes(45)
        d.setInstructions("Làm **cẩn thận**.")
        let s1 = fixedID(2)
        let s2 = try d.addSection(title: "Phần hai", id: fixedID(3)).id

        try d.addQuestion(AuthoringDefaults.blankQuestion(id: fixedID(10), optionCount: 2), to: s1)
        try d.setQuestionText(fixedID(10), "Thủ đô của Việt Nam?")
        try d.setOptionText(of: fixedID(10), at: 0, "Hà Nội")
        try d.setOptionText(of: fixedID(10), at: 1, "Huế")
        try d.addOption(to: fixedID(10), text: "Đà Nẵng")
        try d.setCorrect(of: fixedID(10), at: 0, true)
        try d.setImage(of: fixedID(10), data: imageBytes(1), fileExtension: "png")
        try d.setExplanation(fixedID(10), "Từ năm 1010.")

        try d.addQuestion(AuthoringDefaults.blankQuestion(id: fixedID(11), optionCount: 2), to: s2)
        try d.setQuestionText(fixedID(11), "Số nguyên tố?")
        try d.setQuestionType(fixedID(11), .multiple)
        for (i, text) in ["2", "3", "4"].enumerated() where i >= 2 { try d.addOption(to: fixedID(11), text: text) }
        try d.setOptionText(of: fixedID(11), at: 0, "2")
        try d.setOptionText(of: fixedID(11), at: 1, "3")
        try d.setCorrect(of: fixedID(11), at: 0, true)
        try d.setCorrect(of: fixedID(11), at: 1, true)
        try d.setImage(of: fixedID(11), data: imageBytes(2), fileExtension: "JPG")

        try d.duplicateQuestion(fixedID(10), newID: fixedID(12))
        try d.setQuestionText(fixedID(12), "Thủ đô cũ của Việt Nam (1802–1945)?")
        try d.setCorrect(of: fixedID(12), at: 1, true)
        // Ảnh bị thay: ảnh cũ không còn ai dùng thì không được ghi.
        try d.setImage(of: fixedID(12), data: imageBytes(3), fileExtension: "gif")
        try d.setImage(of: fixedID(12), data: imageBytes(4), fileExtension: "heic")
        return d
    }

    @Test("Đề soạn bằng thao tác: ghi bằng ExamPackageWriter rồi đọc lại (dễ và nghiêm) ra đúng dữ liệu, kể cả ảnh")
    func authoredRoundTrip() throws {
        let draft = try authoredExam()
        #expect(draft.validationIssues.isEmpty)
        #expect(draft.package.media.count == 4)
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.exam == draft.exam)
        #expect(saved.media.count == 3)
        #expect(saved.media[try MediaNaming.path(for: imageBytes(3), fileExtension: "gif")] == nil)
        for question in draft.exam.allQuestions {
            let path = try #require(question.image)
            #expect(saved.media[path] == draft.package.media[path])
        }
        let q11 = try #require(saved.exam.question(id: fixedID(11)))
        #expect(q11.type == .multiple && q11.correctLetters == "AB" && q11.optionTexts == ["2", "3", "4"])
        let q12 = try #require(saved.exam.question(id: fixedID(12)))
        #expect(q12.correctLetters == "B" && q12.explanation == "Từ năm 1010.")
        #expect(saved.exam.sections.map(\.id) == [fixedID(2), fixedID(3)])
        #expect(saved.exam.sections[0].questions.map(\.id) == [fixedID(10), fixedID(12)])
    }

    @Test("Mở đề có sẵn, sửa, ghi rồi đọc lại ra đúng dữ liệu, kể cả ảnh", arguments: ["kien-thuc-chung", "toi-thieu", "bien-khoang-trang"])
    func fixtureRoundTrip(name: String) throws {
        var draft = ExamDraft(package: try RepoFixtures.package(name))
        let original = draft
        try checkRoundTrip(draft, strict: true)
        let section = draft.exam.sections[0].id
        try draft.addQuestion(makeQuestion(id: fixedID(40), options: ["x", "y"], correct: "B"), to: section, at: 0)
        try draft.moveSections(fromOffsets: [0], toOffset: draft.exam.sections.count)
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.exam.question(id: fixedID(40)) != nil)
        #expect(Set(saved.media.keys) == Set(original.package.media.keys))
    }

    @Test("Dấu vân tay câu không đổi khi chỉ đổi thứ tự câu/phần hay chuyển phần; đổi khi sửa nội dung")
    func fingerprints() throws {
        var draft = try RepoFixtures.kienThucChung()
        let original = QuestionFingerprint.fingerprints(of: draft.exam)
        let physics = draft.exam.sections[0].id
        let maths = draft.exam.sections[1].id
        let p = draft.exam.sections[0].questions.map(\.id)

        try draft.moveSections(fromOffsets: [1], toOffset: 0)
        try draft.moveQuestions(inSection: physics, fromOffsets: [0, 1], toOffset: 3)
        try draft.moveQuestion(p[2], toSection: maths, at: 1)
        try draft.duplicateQuestion(p[0], newID: fixedID(50))
        try draft.removeQuestion(fixedID(50))
        try draft.renameSection(maths, to: "Toán học")
        draft.setTitle("Đề khác")
        #expect(QuestionFingerprint.fingerprints(of: draft.exam) == original)
        // Sau khi ghi rồi đọc lại cũng vậy.
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(QuestionFingerprint.fingerprints(of: saved.exam) == original)

        // Sửa nội dung: chỉ câu đó đổi dấu vân tay.
        func changed(_ edit: (inout ExamDraft) throws -> Void) throws -> Set<UUID> {
            var copy = draft
            try edit(&copy)
            let now = QuestionFingerprint.fingerprints(of: copy.exam)
            return Set(original.keys.filter { now[$0] != original[$0] })
        }
        #expect(try changed { try $0.setQuestionText(p[1], "Khác") } == [p[1]])
        #expect(try changed { try $0.setOptionText(of: p[1], at: 0, "Khác") } == [p[1]])
        #expect(try changed { try $0.setCorrect(of: p[1], at: 3, true) } == [p[1]])
        #expect(try changed { try $0.moveOptions(of: p[1], fromOffsets: [0], toOffset: 2) } == [p[1]])
        #expect(try changed { try $0.addOption(to: p[1], text: "Mới") } == [p[1]])
        #expect(try changed { try $0.removeOption(of: p[1], at: 3) } == [p[1]])
        #expect(try changed { try $0.setQuestionType(p[1], .single) } == [p[1]])
        #expect(try changed { try $0.setExplanation(p[1], "Giải thích") } == [p[1]])
        #expect(try changed { try $0.removeImage(of: p[0]) } == [p[0]])
        #expect(try changed { try $0.setImage(of: p[1], data: imageBytes(9), fileExtension: "png") } == [p[1]])
    }

    @Test("Chuỗi thao tác: Hoàn tác hết về đúng đề ban đầu, Làm lại hết về đúng đề cuối")
    func undoRedoSequence() throws {
        var draft = try RepoFixtures.kienThucChung()
        let start = draft
        let physics = draft.exam.sections[0].id
        let maths = draft.exam.sections[1].id
        let p = draft.exam.sections[0].questions.map(\.id)
        let m = draft.exam.sections[1].questions.map(\.id)

        let operations: [(inout ExamDraft) throws -> ExamEdit] = [
            { $0.setTitle("Mới") },
            { try $0.addSection(title: "Phần 3", id: fixedID(60)).inverse },
            { try $0.moveQuestion(p[0], toSection: fixedID(60)) },
            { try $0.setImage(of: m[0], data: imageBytes(1), fileExtension: "png").inverse },
            { try $0.duplicateQuestion(m[0], newID: fixedID(61)).inverse },
            { try $0.moveOptions(of: fixedID(61), fromOffsets: [2], toOffset: 0) },
            { try $0.removeOption(of: m[1], at: 0) },
            { try $0.setQuestionType(m[1], .single) },
            { try $0.moveSections(fromOffsets: [2], toOffset: 0) },
            { try $0.removeSection(physics) },
            { try $0.moveQuestions(inSection: maths, fromOffsets: [0], toOffset: 3) },
            { try $0.removeImage(of: p[0]) },
            { try $0.addOption(to: p[0], text: "E", at: 0) },
            { try $0.setCorrect(of: p[0], at: 0, true) },
            { try $0.renameSection(maths, to: "Đại số") },
        ]
        var states: [ExamDraft] = [draft]
        var undoStack: [ExamEdit] = []
        for operation in operations {
            undoStack.append(try operation(&draft))
            states.append(draft)
        }
        let end = draft
        // Hoàn tác từng bước, kiểm mỗi trạng thái trung gian.
        var redoStack: [ExamEdit] = []
        for step in stride(from: operations.count - 1, through: 0, by: -1) {
            redoStack.append(try draft.apply(undoStack.removeLast()))
            #expect(draft == states[step], "Hoàn tác bước \(step + 1)")
        }
        #expect(draft == start)
        for step in 1 ... operations.count {
            undoStack.append(try draft.apply(redoStack.removeLast()))
            #expect(draft == states[step], "Làm lại bước \(step)")
        }
        #expect(draft == end)
        try checkRoundTrip(end, strict: false)
    }

    @Test("Thay đổi ngược của nhóm và của thao tác không đổi đề")
    func groupInverses() throws {
        var draft = try RepoFixtures.kienThucChung()
        let before = draft
        #expect(ExamEdit.none.isEmpty)
        #expect(try draft.apply(.none).isEmpty)
        #expect(try draft.apply(.removeMedia(path: "media/0000000000000000.png")).isEmpty)
        let path = try #require(draft.package.media.keys.first)
        #expect(try draft.apply(.insertMedia(path: path, data: draft.package.media[path]!)).isEmpty)
        #expect(draft == before)
        try checkUndoRedo(&draft) {
            try $0.apply(.group([
                .permuteSections(order: [1, 0]),
                .permuteQuestions(section: 1, order: [2, 0, 1]),
                .moveQuestion(from: QuestionPath(section: 1, question: 0), to: QuestionPath(section: 0, question: 2)),
                .setSectionTitle("X", at: 0),
                .removeMedia(path: path),
            ]))
        }
    }
}
