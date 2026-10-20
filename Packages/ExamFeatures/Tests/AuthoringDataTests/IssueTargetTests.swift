@testable import AuthoringData
import ExamFile
import ExamKit
import Foundation
import Testing

/// Ánh xạ vấn đề của `ExamValidator` → dòng trên cây đề và trường trong trình soạn (thanh lỗi).
@Suite("Vị trí của lỗi kiểm đề")
struct IssueTargetTests {
    @Test("Mỗi mã vấn đề có một trường")
    func everyCodeHasField() {
        let expected: [IssueCode: IssueTarget.Field] = [
            .titleEmpty: .title, .titleTooLong: .title, .codeInvalid: .code,
            .passPercentOutOfRange: .passPercent, .timeLimitOutOfRange: .timeLimitMinutes,
            .instructionsTooLong: .instructions, .noSections: .sections, .duplicateID: .id,
            .sectionHasNoQuestions: .questions, .duplicateSectionTitle: .title,
            .questionTextEmpty: .text, .questionTextTooLong: .text, .explanationTooLong: .explanation,
            .imagePathInvalid: .image, .imageNotFound: .image, .tooFewOptions: .options, .tooManyOptions: .options,
            .noCorrectAnswer: .correct, .duplicateCorrectAnswer: .correct, .correctAnswerNotInOptions: .correct,
            .singleHasMultipleCorrect: .correct, .multipleHasSingleCorrect: .correct,
            .optionIDOutOfOrder: .optionID, .optionTextEmpty: .text, .optionTextTooLong: .text,
        ]
        #expect(Set(expected.keys) == Set(IssueCode.allCases))
        for code in IssueCode.allCases {
            #expect(IssueTarget.field(for: code) == expected[code], "\(code)")
        }
    }

    @Test("Lỗi trỏ đúng đề/phần/câu/lựa chọn và trường; gom theo dòng cây đề")
    func targetsOfIssues() throws {
        var draft = try RepoFixtures.kienThucChung()
        let maths = draft.exam.sections[1].id
        let q = draft.exam.sections[1].questions[1].id
        draft.setPassPercent(101)
        try draft.renameSection(maths, to: " vật LÝ ")
        let empty = try draft.addSection(title: "Rỗng", id: fixedID(70)).id
        try draft.setQuestionText(q, "   ")
        try draft.setOptionText(of: q, at: 2, "")
        try draft.setCorrect(of: q, at: 0, false)
        try draft.setCorrect(of: q, at: 2, false)

        let issues = draft.validationIssues
        let targets = issues.map { IssueTarget($0) }
        let path = QuestionPath(section: 1, question: 1)
        #expect(targets == [
            IssueTarget(node: .exam, field: .passPercent),
            IssueTarget(node: .section(id: maths, index: 1), field: .title),
            IssueTarget(node: .question(id: q, path: path), field: .text),
            IssueTarget(node: .question(id: q, path: path), field: .correct),
            IssueTarget(node: .option(questionID: q, path: path, optionIndex: 2), field: .text),
            IssueTarget(node: .section(id: empty, index: 2), field: .questions),
        ])
        #expect(issues.map(\.code) == [.passPercentOutOfRange, .duplicateSectionTitle, .questionTextEmpty,
                                       .multipleHasSingleCorrect, .optionTextEmpty, .sectionHasNoQuestions])
        #expect(targets.map(\.node.treeRow) == [.exam, .section(index: 1), .question(path), .question(path),
                                                 .question(path), .section(index: 2)])

        let index = IssueIndex(issues)
        #expect(index.errorCount == 4 && index.warningCount == 2)
        #expect(index.examIssues.map(\.code) == [.passPercentOutOfRange])
        #expect(index.issues(for: .section(index: 1)).map(\.code) == [.duplicateSectionTitle])
        #expect(index.issues(for: .section(index: 2)).map(\.code) == [.sectionHasNoQuestions])
        #expect(index.issues(for: .section(index: 0)).isEmpty)
        #expect(index.issues(for: .question(path)).map(\.code) == [.questionTextEmpty, .multipleHasSingleCorrect, .optionTextEmpty])
        #expect(IssueIndex.worstSeverity(index.issues(for: .question(path))) == .error)
        #expect(IssueIndex.worstSeverity(index.issues(for: .section(index: 1))) == .warning)
        #expect(IssueIndex.worstSeverity([]) == nil)
    }

    @Test("Đề mới: lỗi phần rỗng trỏ tới phần \"Phần 1\", danh sách câu")
    func newExamIssue() {
        let draft = ExamDraft.newExam(sectionID: fixedID(80))
        #expect(draft.validationIssues.map { IssueTarget($0) } == [
            IssueTarget(node: .section(id: fixedID(80), index: 0), field: .questions),
        ])
    }
}
