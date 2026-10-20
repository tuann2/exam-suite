@testable import AuthoringData
import ExamFile
import ExamKit
import Foundation
import Testing

@Suite("Đề mới, thuộc tính đề, phần, câu")
struct ExamStructureTests {
    // MARK: Đề mới

    @Test("Đề mới: id mới, \"Đề mới\", 70%, 60 phút, Ẩn đáp án tắt, một phần \"Phần 1\" chưa có câu")
    func newExamDefaults() throws {
        let a = ExamDraft.newExam()
        let b = ExamDraft.newExam()
        let exam = a.exam
        #expect(exam.title == "Đề mới")
        #expect(exam.passPercent == 70)
        #expect(exam.timeLimitMinutes == 60)
        #expect(exam.hideAnswers == false)
        #expect(exam.code == nil && exam.instructions == nil)
        #expect(exam.formatVersion == ExamFileFormat.currentVersion)
        #expect(exam.sections.count == 1)
        #expect(exam.sections[0].title == "Phần 1")
        #expect(exam.sections[0].questions.isEmpty)
        #expect(exam.id != exam.sections[0].id)
        #expect(a.exam.id != b.exam.id && a.exam.sections[0].id != b.exam.sections[0].id)
        #expect(a.package.media.isEmpty)
        // Chỉ một lỗi: phần chưa có câu. Vẫn lưu được (đọc dễ), bản Học viên từ chối.
        #expect(a.validationIssues.map(\.code) == [.sectionHasNoQuestions])
        try checkRoundTrip(a, strict: false)
        #expect(throws: ExamFileError.self) { try ExamPackageReader.read(a.fileData(), mode: .strict) }
    }

    @Test("Đề mới thêm một câu đủ nội dung thì bản Học viên đọc nghiêm được")
    func newExamBecomesValid() throws {
        var draft = ExamDraft.newExam()
        let section = draft.exam.sections[0].id
        let q = fixedID(1)
        try draft.addQuestion(AuthoringDefaults.blankQuestion(id: q), to: section)
        // Câu mới: một đáp án, bốn lựa chọn trống A–D, chưa có đáp án đúng (authoring.md, phương án 7).
        #expect(draft.question(q).optionLetters == "ABCD")
        #expect(draft.question(q).optionTexts == ["", "", "", ""])
        #expect(draft.question(q).type == .single && draft.question(q).correct.isEmpty)
        try draft.setQuestionText(q, "1 + 1 = ?")
        for (i, text) in ["2", "3", "4", "5"].enumerated() { try draft.setOptionText(of: q, at: i, text) }
        try draft.setCorrect(of: q, at: 0, true)
        #expect(draft.validationIssues.isEmpty)
        try checkRoundTrip(draft, strict: true)
    }

    // MARK: Thuộc tính đề

    @Test("Sửa thuộc tính đề, mỗi thao tác Hoàn tác/Làm lại đúng; chuỗi rỗng bỏ trường tuỳ chọn")
    func properties() throws {
        var draft = try RepoFixtures.kienThucChung()
        let id = draft.exam.id
        try checkUndoRedo(&draft) { $0.setTitle("Đề sửa") }
        try checkUndoRedo(&draft) { $0.setCode("ABC-1") }
        try checkUndoRedo(&draft) { $0.setPassPercent(85) }
        try checkUndoRedo(&draft) { $0.setTimeLimitMinutes(90) }
        try checkUndoRedo(&draft) { $0.setHideAnswers(true) }
        try checkUndoRedo(&draft) { $0.setInstructions("**Đọc kỹ**") }
        #expect(ExamProperties(draft.exam) == ExamProperties(
            title: "Đề sửa", code: "ABC-1", passPercent: 85, timeLimitMinutes: 90,
            hideAnswers: true, instructions: "**Đọc kỹ**"
        ))
        #expect(draft.exam.id == id)
        try checkUndoRedo(&draft) { $0.setCode("") }
        try checkUndoRedo(&draft) { $0.setInstructions("") }
        #expect(draft.exam.code == nil && draft.exam.instructions == nil)
        // Giá trị ngoài ràng buộc vẫn nhập được nhưng hiện lỗi.
        draft.setPassPercent(150)
        draft.setTimeLimitMinutes(0)
        #expect(Set(draft.validationIssues.map(\.code)) == [.passPercentOutOfRange, .timeLimitOutOfRange])
        try checkRoundTrip(draft, strict: false)
    }

    // MARK: Phần

    @Test("Thêm, đổi tên, sắp xếp, xoá phần; phần giữ id; Hoàn tác/Làm lại")
    func sections() throws {
        var draft = try RepoFixtures.kienThucChung()
        let physics = draft.exam.sections[0].id
        let maths = draft.exam.sections[1].id
        #expect(draft.suggestedSectionTitle() == "Phần 3")

        var added = UUID()
        try checkUndoRedo(&draft) {
            let result = try $0.addSection(id: fixedID(10))
            added = result.id
            return result.inverse
        }
        #expect(added == fixedID(10))
        #expect(draft.exam.sections.map(\.title) == ["Vật lý", "Toán", "Phần 3"])
        #expect(draft.exam.sections[2].questions.isEmpty)
        #expect(draft.validationIssues.map(\.code) == [.sectionHasNoQuestions])

        try checkUndoRedo(&draft) { try $0.addSection(title: "Hoá", at: 0, id: fixedID(11)).inverse }
        #expect(draft.exam.sections.map(\.title) == ["Hoá", "Vật lý", "Toán", "Phần 3"])
        try checkUndoRedo(&draft) { try $0.renameSection(fixedID(11), to: "Hoá học") }
        #expect(draft.exam.sections[0].title == "Hoá học")

        // Kéo "Toán" (2) lên đầu, rồi kéo hai phần đầu xuống cuối.
        try checkUndoRedo(&draft) { try $0.moveSections(fromOffsets: [2], toOffset: 0) }
        #expect(draft.exam.sections.map(\.id) == [maths, fixedID(11), physics, fixedID(10)])
        try checkUndoRedo(&draft) { try $0.moveSections(fromOffsets: [0, 1], toOffset: 4) }
        #expect(draft.exam.sections.map(\.id) == [physics, fixedID(10), maths, fixedID(11)])
        // Kéo về đúng chỗ cũ: không đổi, không tạo bước Hoàn tác.
        #expect(try draft.moveSections(fromOffsets: [1], toOffset: 1).isEmpty)
        #expect(try draft.moveSections(fromOffsets: [1], toOffset: 2).isEmpty)

        // Xoá phần còn câu: xoá cả câu; Hoàn tác trả lại đúng chỗ.
        try checkUndoRedo(&draft) { try $0.removeSection(maths) }
        #expect(draft.exam.sections.map(\.id) == [physics, fixedID(10), fixedID(11)])
        #expect(draft.exam.questionCount == 3)
        try checkUndoRedo(&draft) { try $0.removeSection(fixedID(10)) }
        try checkUndoRedo(&draft) { try $0.removeSection(fixedID(11)) }
        try checkUndoRedo(&draft) { try $0.removeSection(physics) }
        // Đề không còn phần: lỗi, vẫn lưu được.
        #expect(draft.exam.sections.isEmpty)
        #expect(draft.validationIssues.map(\.code) == [.noSections])
        try checkRoundTrip(draft, strict: false)
    }

    @Test("Tên gợi ý cho phần mới bỏ qua tên đã có")
    func suggestedSectionTitle() throws {
        var draft = ExamDraft.newExam()
        #expect(draft.suggestedSectionTitle() == "Phần 2")
        try draft.addSection(title: "phần 2 ")
        try draft.addSection(title: "Phần 3")
        #expect(draft.suggestedSectionTitle() == "Phần 4")
        try draft.renameSection(draft.exam.sections[0].id, to: "Phần 4")
        #expect(draft.suggestedSectionTitle() == "Phần 5")
    }

    /// Tên mặc định theo ngôn ngữ giao diện lúc tạo (bước 7c): tầng giao diện truyền `DefaultContentNames`; mặc định
    /// tiếng Việt.
    @Test("Tên mặc định ghi vào đề theo tên được truyền vào (giao diện tiếng Anh: New Exam, Section N)")
    func defaultNamesFollowGivenNames() throws {
        let english = DefaultContentNames(examTitle: "New Exam", sectionTitle: { "Section \($0)" })
        var draft = ExamDraft.newExam(names: english)
        #expect(draft.exam.title == "New Exam")
        #expect(draft.exam.sections.map(\.title) == ["Section 1"])
        #expect(draft.suggestedSectionTitle(names: english) == "Section 2")
        try draft.addSection(title: "section 2 ")
        try draft.addSection(names: english)
        #expect(draft.exam.sections.map(\.title) == ["Section 1", "section 2 ", "Section 3"])
        // Đề đã có tên tiếng Anh, thêm phần khi giao diện tiếng Việt: tên mới theo tiếng Việt, không đổi tên cũ.
        try draft.addSection()
        #expect(draft.exam.sections.map(\.title) == ["Section 1", "section 2 ", "Section 3", "Phần 4"])
        #expect(DefaultContentNames.vietnamese.examTitle == "Đề mới")
        #expect(DefaultContentNames.vietnamese.sectionTitle(12) == "Phần 12")
    }

    @Test("Thao tác lỗi (id không có, vị trí sai) không đổi đề")
    func errorsLeaveDraftUnchanged() throws {
        var draft = try RepoFixtures.kienThucChung()
        let before = draft
        let missing = fixedID(999)
        let q = draft.exam.sections[0].questions[0].id
        let section = draft.exam.sections[0].id
        #expect(throws: ExamEditError.sectionNotFound(missing)) { try draft.removeSection(missing) }
        #expect(throws: ExamEditError.questionNotFound(missing)) { try draft.removeQuestion(missing) }
        #expect(throws: ExamEditError.sectionNotFound(missing)) { try draft.moveQuestion(q, toSection: missing) }
        #expect(throws: ExamEditError.invalidQuestionPath(QuestionPath(section: 0, question: 5))) {
            try draft.moveQuestion(q, toSection: section, at: 5)
        }
        #expect(throws: ExamEditError.invalidPermutation) { try draft.moveSections(fromOffsets: [3], toOffset: 0) }
        #expect(throws: ExamEditError.invalidPermutation) { try draft.moveSections(fromOffsets: [0], toOffset: 3) }
        #expect(throws: ExamEditError.invalidOptionIndex(4)) { try draft.removeOption(of: q, at: 4) }
        #expect(throws: ExamEditError.invalidOptionIndex(9)) { try draft.addOption(to: q, at: 9) }
        #expect(throws: ExamEditError.invalidPermutation) { try draft.apply(.permuteSections(order: [0, 0])) }
        #expect(throws: ExamEditError.invalidPermutation) { try draft.apply(.permuteQuestions(section: 0, order: [2, 1])) }
        #expect(throws: ExamEditError.invalidSectionIndex(5)) { try draft.apply(.insertSection(ExamSection(title: "x", questions: []), at: 5)) }
        #expect(throws: ExamEditError.invalidQuestionPath(QuestionPath(section: 1, question: 2))) {
            try draft.apply(.removeQuestion(at: QuestionPath(section: 1, question: 2)))
        }
        // Nhóm lỗi ở bước cuối: các bước trước bị huỷ.
        #expect(throws: ExamEditError.invalidSectionIndex(7)) {
            try draft.apply(.group([.setProperties(ExamProperties(title: "x", passPercent: 1, timeLimitMinutes: 1)),
                                    .removeQuestion(at: QuestionPath(section: 0, question: 0)),
                                    .removeSection(at: 7)]))
        }
        // batch lỗi giữa chừng: đề về như trước.
        struct Stop: Error {}
        #expect(throws: Stop.self) {
            try draft.batch { d in
                d.setTitle("x")
                try d.removeQuestion(q)
                throw Stop()
            }
        }
        #expect(draft == before)
    }

    // MARK: Câu

    @Test("Thêm, xoá câu; Hoàn tác trả câu về đúng chỗ")
    func addRemoveQuestion() throws {
        var draft = try RepoFixtures.kienThucChung()
        let maths = draft.exam.sections[1].id
        let first = draft.exam.sections[1].questions[0].id
        let second = draft.exam.sections[1].questions[1].id
        try checkUndoRedo(&draft) { try $0.addQuestion(AuthoringDefaults.blankQuestion(id: fixedID(1)), to: maths, at: 0) }
        try checkUndoRedo(&draft) { try $0.addQuestion(AuthoringDefaults.blankQuestion(id: fixedID(2)), to: maths) }
        #expect(draft.exam.sections[1].questions.map(\.id).first == fixedID(1))
        #expect(draft.exam.sections[1].questions.map(\.id).last == fixedID(2))
        #expect(draft.exam.sections[1].questions[1].id == first)
        try checkUndoRedo(&draft) { try $0.removeQuestion(first) }
        #expect(draft.exam.sections[1].questions.map(\.id) == [fixedID(1), second, fixedID(2)])
        #expect(draft.exam.question(id: first) == nil)
    }

    @Test("Nhân bản câu: id mới, cùng nội dung (kể cả ảnh), ngay sau câu gốc; dấu vân tay như câu gốc")
    func duplicateQuestion() throws {
        var draft = try RepoFixtures.kienThucChung()
        let original = draft.exam.sections[0].questions[0]
        #expect(original.image != nil)
        var newID = UUID()
        try checkUndoRedo(&draft) {
            let result = try $0.duplicateQuestion(original.id, newID: fixedID(5))
            newID = result.id
            return result.inverse
        }
        #expect(newID == fixedID(5))
        let questions = draft.exam.sections[0].questions
        #expect(questions.map(\.id).prefix(2) == [original.id, fixedID(5)])
        var expected = original
        expected.id = fixedID(5)
        #expect(questions[1] == expected)
        #expect(QuestionFingerprint.fingerprint(of: questions[1]) == QuestionFingerprint.fingerprint(of: original))
        #expect(draft.validationIssues.isEmpty)
        // Ảnh dùng chung chỉ lưu một lần.
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.media.count == 1)
        // Nhân bản mặc định tạo id ngẫu nhiên khác mọi id có sẵn.
        let random = try draft.duplicateQuestion(original.id).id
        #expect(![original.id, fixedID(5)].contains(random))
    }

    @Test("Chuyển câu sang phần khác giữ id; chuyển câu cuối làm phần rỗng (lỗi, vẫn lưu được)")
    func moveQuestionAcrossSections() throws {
        var draft = try RepoFixtures.kienThucChung()
        let physics = draft.exam.sections[0].id
        let maths = draft.exam.sections[1].id
        let p = draft.exam.sections[0].questions.map(\.id)
        let m = draft.exam.sections[1].questions.map(\.id)
        let before = draft.exam.sections[0].questions[1]

        try checkUndoRedo(&draft) { try $0.moveQuestion(p[1], toSection: maths, at: 1) }
        #expect(draft.exam.sections[0].questions.map(\.id) == [p[0], p[2]])
        #expect(draft.exam.sections[1].questions.map(\.id) == [m[0], p[1], m[1]])
        #expect(draft.question(p[1]) == before)

        // Mặc định: cuối phần đích.
        try checkUndoRedo(&draft) { try $0.moveQuestion(p[0], toSection: maths) }
        #expect(draft.exam.sections[1].questions.map(\.id) == [m[0], p[1], m[1], p[0]])

        // Câu cuối của phần Vật lý.
        try checkUndoRedo(&draft) { try $0.moveQuestion(p[2], toSection: maths, at: 0) }
        #expect(draft.exam.sections[0].questions.isEmpty)
        #expect(draft.exam.sections[1].questions.map(\.id) == [p[2], m[0], p[1], m[1], p[0]])
        #expect(draft.validationIssues.map(\.code) == [.sectionHasNoQuestions])
        try checkRoundTrip(draft, strict: false)

        // Chuyển vào phần rỗng.
        try checkUndoRedo(&draft) { try $0.moveQuestion(m[1], toSection: physics) }
        #expect(draft.exam.sections[0].questions.map(\.id) == [m[1]])
    }

    @Test("Sắp xếp câu trong phần (kéo thả), và chuyển trong cùng phần")
    func reorderQuestions() throws {
        var draft = try RepoFixtures.kienThucChung()
        let physics = draft.exam.sections[0].id
        let p = draft.exam.sections[0].questions.map(\.id)
        try checkUndoRedo(&draft) { try $0.moveQuestions(inSection: physics, fromOffsets: [0], toOffset: 3) }
        #expect(draft.exam.sections[0].questions.map(\.id) == [p[1], p[2], p[0]])
        try checkUndoRedo(&draft) { try $0.moveQuestions(inSection: physics, fromOffsets: [1, 2], toOffset: 0) }
        #expect(draft.exam.sections[0].questions.map(\.id) == [p[2], p[0], p[1]])
        try checkUndoRedo(&draft) { try $0.moveQuestion(p[2], toSection: physics, at: 2) }
        #expect(draft.exam.sections[0].questions.map(\.id) == [p[0], p[1], p[2]])
        #expect(try draft.moveQuestion(p[2], toSection: physics).isEmpty)
        #expect(try draft.moveQuestions(inSection: physics, fromOffsets: [0], toOffset: 1).isEmpty)
    }

    @Test("Sửa nội dung, giải thích của câu giữ id; sửa không đổi gì thì không tạo bước Hoàn tác")
    func editQuestionText() throws {
        var draft = try RepoFixtures.kienThucChung()
        let q = draft.exam.sections[1].questions[0].id
        try checkUndoRedo(&draft) { try $0.setQuestionText(q, "Nội dung mới") }
        try checkUndoRedo(&draft) { try $0.setExplanation(q, "Vì *vậy*") }
        #expect(draft.question(q).text == "Nội dung mới")
        #expect(draft.question(q).explanation == "Vì *vậy*")
        try checkUndoRedo(&draft) { try $0.setExplanation(q, "") }
        #expect(draft.question(q).explanation == nil)
        #expect(try draft.setQuestionText(q, "Nội dung mới").isEmpty)
        try checkRoundTrip(draft, strict: true)
    }

    @Test("batch gộp nhiều thao tác thành một bước Hoàn tác")
    func batchIsOneUndoStep() throws {
        var draft = try RepoFixtures.kienThucChung()
        let maths = draft.exam.sections[1].id
        try checkUndoRedo(&draft) {
            try $0.batch { d in
                d.setTitle("Gộp")
                let section = try d.addSection(title: "Mới", id: fixedID(20)).id
                try d.moveQuestion(d.exam.sections[1].questions[0].id, toSection: section)
                // batch lồng nhau.
                try d.batch { inner in try inner.renameSection(maths, to: "Đại số") }
            }
        }
        #expect(draft.exam.title == "Gộp")
        #expect(draft.exam.sections.map(\.title) == ["Vật lý", "Đại số", "Mới"])
        #expect(draft.exam.sections[2].questions.count == 1)
    }

    @Test("Id câu trùng giữa hai phần: lỗi trỏ theo vị trí; xoá, nhân bản, sửa, cấp id mới theo vị trí đúng câu thứ hai")
    func duplicateQuestionIDsAcrossSections() throws {
        var package = try RepoFixtures.package("kien-thuc-chung")
        let duplicated = package.exam.sections[0].questions[0].id
        package.exam.sections[1].questions[1].id = duplicated
        let start = ExamDraft(package: package)
        let first = try #require(start.question(at: QuestionPath(section: 0, question: 0)))
        let second = try #require(start.question(at: QuestionPath(section: 1, question: 1)))
        #expect(first.id == second.id && first != second)

        // Lỗi id trùng trỏ tới câu thứ hai theo vị trí, không theo id.
        let issue = try #require(start.validationIssues.first { $0.code == .duplicateID })
        let target = IssueTarget(issue)
        #expect(target.field == .id)
        #expect(target.node.treeRow == .question(QuestionPath(section: 1, question: 1)))
        guard case let .question(path) = target.node.treeRow else { Issue.record("không phải dòng câu"); return }
        #expect(IssueIndex(start.validationIssues).issues(for: .question(path)).map(\.code) == [.duplicateID])
        #expect(IssueIndex(start.validationIssues).issues(for: .question(QuestionPath(section: 0, question: 0))).isEmpty)

        // Xoá theo vị trí: câu thứ hai biến mất, câu đầu còn nguyên.
        var draft = start
        try checkUndoRedo(&draft) { try $0.removeQuestion(path) }
        #expect(draft.exam.sections[0].questions[0] == first)
        #expect(!draft.exam.sections[1].questions.contains(second))
        #expect(!draft.validationIssues.contains { $0.code == .duplicateID })
        // Xoá theo id: tác động lần xuất hiện đầu (đã ghi trong API), nên giao diện dùng vị trí.
        draft = start
        try draft.removeQuestion(duplicated)
        #expect(draft.exam.sections[1].questions.contains(second))
        #expect(!draft.exam.sections[0].questions.contains(first))

        // Nhân bản theo vị trí: bản sao của câu thứ hai, ngay sau nó.
        draft = start
        try checkUndoRedo(&draft) { try $0.duplicateQuestion(path, newID: fixedID(31)).inverse }
        var copy = second
        copy.id = fixedID(31)
        #expect(draft.exam.sections[1].questions[2] == copy)

        // Sửa theo vị trí: nội dung, lựa chọn, đáp án, ảnh của câu thứ hai; câu đầu không đổi.
        draft = start
        try checkUndoRedo(&draft) { try $0.setQuestionText(path, "Câu thứ hai") }
        try checkUndoRedo(&draft) { try $0.addOption(to: path, text: "Mới") }
        try checkUndoRedo(&draft) { try $0.setCorrect(of: path, at: 1, true) }
        try checkUndoRedo(&draft) { try $0.setImage(of: path, data: imageBytes(31), fileExtension: "png").inverse }
        #expect(draft.exam.sections[0].questions[0] == first)
        let edited = try #require(draft.question(at: path))
        #expect(edited.text == "Câu thứ hai" && edited.optionTexts.last == "Mới" && edited.image != nil)

        // Cấp id mới theo vị trí: hết lỗi, câu đầu giữ id (lịch sử thi theo id không đổi).
        draft = start
        try checkUndoRedo(&draft) { try $0.assignNewID(toQuestion: path, newID: fixedID(32)) }
        #expect(draft.question(at: path)?.id == fixedID(32))
        #expect(draft.exam.sections[0].questions[0].id == duplicated)
        #expect(!draft.validationIssues.contains { $0.code == .duplicateID })
        try checkRoundTrip(draft, strict: true)

        // Vị trí không có câu: lỗi, đề không đổi.
        #expect(throws: ExamEditError.invalidQuestionPath(QuestionPath(section: 1, question: 9))) {
            try draft.removeQuestion(QuestionPath(section: 1, question: 9))
        }
    }

    @Test("Id phần trùng: lỗi trỏ theo chỉ số phần; đổi tên, cấp id mới, xoá theo chỉ số đúng phần thứ hai")
    func duplicateSectionIDs() throws {
        var package = try RepoFixtures.package("kien-thuc-chung")
        package.exam.sections[1].id = package.exam.sections[0].id
        let start = ExamDraft(package: package)
        let issue = try #require(start.validationIssues.first { $0.code == .duplicateID })
        #expect(IssueTarget(issue).node.treeRow == .section(index: 1))

        var draft = start
        try checkUndoRedo(&draft) { try $0.renameSection(1, to: "Đại số") }
        #expect(draft.exam.sections.map(\.title) == ["Vật lý", "Đại số"])
        try checkUndoRedo(&draft) { try $0.assignNewID(toSection: 1, newID: fixedID(33)) }
        #expect(draft.exam.sections.map(\.id) == [start.exam.sections[0].id, fixedID(33)])
        #expect(draft.exam.sections[1].questions == start.exam.sections[1].questions)
        #expect(!draft.validationIssues.contains { $0.code == .duplicateID })
        try checkUndoRedo(&draft) { try $0.addQuestion(makeQuestion(id: fixedID(34), options: ["a", "b"], correct: "A"), to: 1, at: 0) }
        try checkUndoRedo(&draft) { try $0.moveQuestion(fixedID(34), toSection: 0) }
        #expect(draft.exam.sections[0].questions.last?.id == fixedID(34))

        draft = start
        try checkUndoRedo(&draft) { try $0.removeSection(1) }
        #expect(draft.exam.sections == [start.exam.sections[0]])
        #expect(throws: ExamEditError.invalidSectionIndex(5)) { try draft.renameSection(5, to: "x") }
    }

    @Test("Thao tác không đổi gì trả thay đổi rỗng (giao diện bỏ qua, không đánh dấu Đã sửa)")
    func noOpOperationsReturnEmptyEdit() throws {
        var draft = try RepoFixtures.kienThucChung()
        let before = draft
        let exam = draft.exam
        let q = exam.sections[0].questions[0]
        #expect(draft.setTitle(exam.title).isEmpty)
        #expect(draft.setCode(exam.code).isEmpty)
        #expect(draft.setPassPercent(exam.passPercent).isEmpty)
        #expect(draft.setTimeLimitMinutes(exam.timeLimitMinutes).isEmpty)
        #expect(draft.setHideAnswers(exam.hideAnswers).isEmpty)
        #expect(draft.setInstructions(exam.instructions).isEmpty)
        #expect(draft.setProperties(ExamProperties(exam)).isEmpty)
        #expect(try draft.renameSection(exam.sections[0].id, to: exam.sections[0].title).isEmpty)
        #expect(try draft.setQuestionText(q.id, q.text).isEmpty)
        #expect(try draft.setExplanation(q.id, q.explanation).isEmpty)
        #expect(try draft.setQuestionType(q.id, q.type).isEmpty)
        #expect(try draft.setOptionText(of: q.id, at: 0, q.options[0].text).isEmpty)
        #expect(try draft.setCorrect(of: q.id, at: 1, true).isEmpty) // B đã là đáp án đúng duy nhất
        let image = try #require(q.image)
        let bytes = try #require(draft.package.media[image])
        let same = try draft.setImage(of: q.id, data: bytes, fileExtension: "png")
        #expect(same.path == image && same.inverse.isEmpty)
        #expect(try draft.removeImage(of: exam.sections[1].questions[0].id).isEmpty)
        #expect(try draft.moveQuestion(q.id, toSection: exam.sections[0].id, at: 0).isEmpty)
        #expect(draft == before)
        // Đổi thật vẫn tạo bước Hoàn tác.
        #expect(!draft.setTitle(exam.title + " ").isEmpty)
    }
}
