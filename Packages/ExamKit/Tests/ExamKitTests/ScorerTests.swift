import Foundation
import Testing
@testable import ExamKit

// Tình huống theo docs/product/scoring.md, mục "Bằng chứng cần có"; danh sách ý
// tham khảo ScorerTests/GraderTests của Open Exam Suite (chỉ tên tình huống).

private func ids(_ letters: String) -> Set<OptionID> {
    Set(letters.map { OptionID($0)! })
}

private func options(_ letters: String) -> [Option] {
    letters.map { Option(id: OptionID($0)!, text: "Lựa chọn \($0)") }
}

private func question(_ type: QuestionType, options letters: String = "ABCD", correct: String) -> Question {
    Question(type: type, text: "Câu hỏi", options: options(letters), correct: correct.map { OptionID($0)! })
}

/// Đề một section gồm `count` câu `single`, đáp án đúng là A.
private func singleSectionExam(count: Int, passPercent: Int) -> Exam {
    Exam(
        title: "Đề thử",
        passPercent: passPercent,
        timeLimitMinutes: 10,
        sections: [ExamSection(title: "Chung", questions: (0 ..< count).map { _ in question(.single, correct: "A") })]
    )
}

/// Trả lời đúng `correct` câu đầu (chọn A), các câu sau sai (chọn B).
private func answers(for exam: Exam, correct: Int) -> AnswerSheet {
    var sheet: AnswerSheet = [:]
    for (i, q) in exam.allQuestions.enumerated() {
        sheet[q.id] = i < correct ? ids("A") : ids("B")
    }
    return sheet
}

private func sampleExam() throws -> Exam {
    try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
}

// Id câu trong fixture kien-thuc-chung.
private enum KTC {
    static let q1 = UUID(uuidString: "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e")! // Vật lý, single B
    static let q2 = UUID(uuidString: "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f")! // Vật lý, multiple A C
    static let q3 = UUID(uuidString: "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a")! // Vật lý, single A
    static let q4 = UUID(uuidString: "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b")! // Toán, single B
    static let q5 = UUID(uuidString: "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c")! // Toán, multiple A C E
    static let all = [q1, q2, q3, q4, q5]
    static let correctSheet: AnswerSheet = [q1: ids("B"), q2: ids("AC"), q3: ids("A"), q4: ids("B"), q5: ids("ACE")]
    static let wrongSheet: AnswerSheet = [q1: ids("A"), q2: ids("A"), q3: ids("B"), q4: ids("C"), q5: ids("ACEB")]
}

@Suite("Scorer: công thức điểm và ngưỡng đậu")
struct ScorerFormulaTests {
    @Test("score1000 và percent chia lấy phần nguyên; total ≤ 0 → 0", arguments: [
        (0, 0, 0, 0),
        (5, 0, 0, 0),
        (5, -1, 0, 0),
        (0, 10, 0, 0),
        (7, 10, 700, 70),
        (10, 10, 1000, 100),
        (2, 3, 666, 66),
        (1, 3, 333, 33),
        (1, 7, 142, 14),
        (6, 7, 857, 85),
        (199, 200, 995, 99),
    ])
    func formula(correct: Int, total: Int, expected1000: Int, expectedPercent: Int) {
        #expect(Scorer.score1000(correct: correct, total: total) == expected1000)
        #expect(Scorer.percent(correct: correct, total: total) == expectedPercent)
    }

    @Test("Đậu khi score1000 ≥ passPercent × 10, biên đúng ngưỡng", arguments: [
        (700, 70, true),
        (699, 70, false),
        (666, 67, false),
        (666, 66, true),
        (650, 65, true),
        (649, 65, false),
        (1000, 100, true),
        (999, 100, false),
        (0, 0, true),
        (0, 1, false),
    ])
    func passThreshold(score1000: Int, passPercent: Int, passed: Bool) {
        #expect(Scorer.isPassed(score1000: score1000, passPercent: passPercent) == passed)
    }

    @Test("score1000 ≥ passPercent×10 và percent ≥ passPercent cho cùng kết luận với mọi total ≤ 200")
    func bothComparisonsAgree() {
        var mismatches: [String] = []
        for total in 1 ... 200 {
            for correct in 0 ... total {
                let s = Scorer.score1000(correct: correct, total: total)
                let p = Scorer.percent(correct: correct, total: total)
                for passPercent in 0 ... 100
                where Scorer.isPassed(score1000: s, passPercent: passPercent) != (p >= passPercent) {
                    mismatches.append("\(correct)/\(total) @\(passPercent)")
                }
            }
        }
        #expect(mismatches.isEmpty)
    }
}

@Suite("Scorer: chấm từng câu")
struct ScorerOutcomeTests {
    @Test("single: chọn đúng đáp án duy nhất → đúng")
    func singleCorrect() {
        #expect(Scorer.outcome(of: question(.single, correct: "B"), selected: ids("B")) == .correct)
    }

    @Test("single: chọn sai → sai")
    func singleWrong() {
        #expect(Scorer.outcome(of: question(.single, correct: "B"), selected: ids("C")) == .incorrect)
    }

    @Test("single: chọn 2 lựa chọn (kể cả có đáp án đúng) → sai")
    func singleTwoSelected() {
        #expect(Scorer.outcome(of: question(.single, correct: "B"), selected: ids("BC")) == .incorrect)
    }

    @Test("multiple: đúng đủ tập → đúng")
    func multipleExact() {
        #expect(Scorer.outcome(of: question(.multiple, correct: "AC"), selected: ids("AC")) == .correct)
    }

    @Test("multiple: thứ tự không quan trọng (correct ghi C,A; chọn A rồi C)")
    func multipleOrderIrrelevant() {
        let q = question(.multiple, correct: "CA")
        var selected = Set<OptionID>()
        selected.insert(OptionID("A")!)
        selected.insert(OptionID("C")!)
        #expect(Scorer.outcome(of: q, selected: selected) == .correct)
    }

    @Test("multiple: thiếu một → sai, không điểm từng phần")
    func multipleMissingOne() {
        #expect(Scorer.outcome(of: question(.multiple, correct: "ACD"), selected: ids("AC")) == .incorrect)
    }

    @Test("multiple: thừa một → sai")
    func multipleExtraOne() {
        #expect(Scorer.outcome(of: question(.multiple, correct: "AC"), selected: ids("ACD")) == .incorrect)
    }

    @Test("Chưa trả lời: nil hoặc tập rỗng → unanswered", arguments: [QuestionType.single, .multiple])
    func unanswered(type: QuestionType) {
        let q = question(type, correct: type == .single ? "A" : "AB")
        #expect(Scorer.outcome(of: q, selected: nil) == .unanswered)
        #expect(Scorer.outcome(of: q, selected: []) == .unanswered)
    }

    @Test("Đáp án chứa id không có trong options → sai")
    func selectedOutsideOptions() {
        #expect(Scorer.outcome(of: question(.single, options: "ABC", correct: "A"), selected: ids("Z")) == .incorrect)
        #expect(Scorer.outcome(of: question(.multiple, options: "ABC", correct: "AB"), selected: ids("ABD")) == .incorrect)
        // Kể cả khi đề sai có `correct` ngoài options, chọn id đó vẫn không được tính đúng.
        #expect(Scorer.outcome(of: question(.single, options: "ABC", correct: "D"), selected: ids("D")) == .incorrect)
    }
}

@Suite("Scorer: chấm cả phiên")
struct ScorerSessionTests {
    @Test("Đề mẫu: tất cả đúng → 5/5, 1000, 100%, đậu")
    func allCorrect() throws {
        let exam = try sampleExam()
        let r = try Scorer.score(exam: exam, questionIDs: KTC.all, answers: KTC.correctSheet)
        #expect(r.total == 5)
        #expect(r.correct == 5)
        #expect(r.score1000 == 1000)
        #expect(r.percent == 100)
        #expect(r.passPercent == 70)
        #expect(r.passed)
        #expect(r.outcomes.count == 5)
        #expect(r.outcomes.values.allSatisfy { $0 == .correct })
        #expect(r.incorrectOrUnansweredIDs.isEmpty)
        #expect(r.questionIDs == KTC.all)
    }

    @Test("Đề mẫu: tất cả sai → 0/5, 0, trượt")
    func allWrong() throws {
        let exam = try sampleExam()
        let r = try Scorer.score(exam: exam, questionIDs: KTC.all, answers: KTC.wrongSheet)
        #expect(r.correct == 0)
        #expect(r.score1000 == 0)
        #expect(r.percent == 0)
        #expect(!r.passed)
        #expect(r.outcomes.values.allSatisfy { $0 == .incorrect })
        #expect(r.incorrectOrUnansweredIDs == KTC.all)
    }

    @Test("Đề mẫu: chưa trả lời (thiếu khoá và tập rỗng) tính sai, outcome unanswered")
    func unansweredInSession() throws {
        let exam = try sampleExam()
        let sheet: AnswerSheet = [KTC.q1: ids("B"), KTC.q2: [], KTC.q4: ids("A")]
        let r = try Scorer.score(exam: exam, questionIDs: KTC.all, answers: sheet)
        #expect(r.correct == 1)
        #expect(r.score1000 == 200)
        #expect(r.percent == 20)
        #expect(!r.passed)
        #expect(r.outcomes == [
            KTC.q1: .correct,
            KTC.q2: .unanswered,
            KTC.q3: .unanswered,
            KTC.q4: .incorrect,
            KTC.q5: .unanswered,
        ])
    }

    @Test("Không trả lời câu nào → mọi câu unanswered, không ném lỗi")
    func allUnanswered() throws {
        let exam = try sampleExam()
        let r = try Scorer.score(exam: exam, questionIDs: KTC.all, answers: [:])
        #expect(r.correct == 0)
        #expect(r.outcomes.values.allSatisfy { $0 == .unanswered })
        #expect(r.incorrectOrUnansweredIDs == KTC.all)
    }

    @Test("Đề mẫu: 4/5 → 800, 80%, đậu với 70; kết quả theo section đúng")
    func mixedWithSections() throws {
        let exam = try sampleExam()
        var sheet = KTC.correctSheet
        sheet[KTC.q2] = ids("A") // multiple thiếu một
        let r = try Scorer.score(exam: exam, questionIDs: KTC.all, answers: sheet)
        #expect(r.correct == 4)
        #expect(r.score1000 == 800)
        #expect(r.percent == 80)
        #expect(r.passed)
        #expect(r.sections == [
            SectionScore(sectionID: exam.sections[0].id, title: "Vật lý", total: 3, correct: 2),
            SectionScore(sectionID: exam.sections[1].id, title: "Toán", total: 2, correct: 2),
        ])
        #expect(r.incorrectOrUnansweredIDs == [KTC.q2])
    }

    @Test("Biên đậu/trượt qua score(): 7/10 đậu với 70, 6/10 trượt")
    func sevenOfTen() throws {
        let exam = singleSectionExam(count: 10, passPercent: 70)
        let ids = exam.allQuestions.map(\.id)
        let pass = try Scorer.score(exam: exam, questionIDs: ids, answers: answers(for: exam, correct: 7))
        #expect(pass.score1000 == 700)
        #expect(pass.percent == 70)
        #expect(pass.passed)
        let fail = try Scorer.score(exam: exam, questionIDs: ids, answers: answers(for: exam, correct: 6))
        #expect(fail.score1000 == 600)
        #expect(!fail.passed)
    }

    @Test("Chia lấy phần nguyên qua score(): 2/3 = 666, 66%; trượt với 67, đậu với 66", arguments: [(67, false), (66, true)])
    func twoOfThree(passPercent: Int, passed: Bool) throws {
        let exam = singleSectionExam(count: 3, passPercent: passPercent)
        let r = try Scorer.score(exam: exam, questionIDs: exam.allQuestions.map(\.id), answers: answers(for: exam, correct: 2))
        #expect(r.score1000 == 666)
        #expect(r.percent == 66)
        #expect(r.passed == passed)
    }

    @Test("Phiên 0 câu: 0 điểm; passPercent 70 trượt, passPercent 0 đậu; mọi section 0/0")
    func zeroQuestions() throws {
        var exam = try sampleExam()
        let r = try Scorer.score(exam: exam, questionIDs: [], answers: KTC.correctSheet)
        #expect(r.total == 0)
        #expect(r.correct == 0)
        #expect(r.score1000 == 0)
        #expect(r.percent == 0)
        #expect(!r.passed)
        #expect(r.outcomes.isEmpty)
        #expect(r.sections.map(\.total) == [0, 0])
        #expect(r.sections.map(\.correct) == [0, 0])

        exam.passPercent = 0
        let r0 = try Scorer.score(exam: exam, questionIDs: [], answers: [:])
        #expect(r0.passed)
    }

    @Test("Section không có câu nào trong phiên vẫn có mặt với 0/0; tổng section = tổng phiên")
    func sectionNotInSession() throws {
        let exam = try sampleExam()
        let session = [KTC.q5, KTC.q4]
        let r = try Scorer.score(exam: exam, questionIDs: session, answers: KTC.correctSheet)
        #expect(r.total == 2)
        #expect(r.correct == 2)
        #expect(r.sections.map(\.title) == ["Vật lý", "Toán"])
        #expect(r.sections[0].total == 0)
        #expect(r.sections[0].correct == 0)
        #expect(r.sections[1].total == 2)
        #expect(r.sections[1].correct == 2)
        #expect(r.sections.reduce(0) { $0 + $1.total } == r.total)
        #expect(r.sections.reduce(0) { $0 + $1.correct } == r.correct)
    }

    @Test("Đáp án của câu không thuộc phiên bị bỏ qua")
    func answersOutsideSessionIgnored() throws {
        let exam = try sampleExam()
        var sheet = KTC.correctSheet
        sheet[UUID()] = ids("A") // câu không có trong đề
        let r = try Scorer.score(exam: exam, questionIDs: [KTC.q1, KTC.q2], answers: sheet)
        #expect(r.total == 2)
        #expect(r.correct == 2)
        #expect(Set(r.outcomes.keys) == [KTC.q1, KTC.q2])
    }

    @Test("incorrectOrUnansweredIDs giữ thứ tự phiên (không theo thứ tự file)")
    func incorrectOrderFollowsSession() throws {
        let exam = try sampleExam()
        let session = [KTC.q5, KTC.q3, KTC.q1, KTC.q4, KTC.q2]
        let sheet: AnswerSheet = [KTC.q5: ids("AC"), KTC.q1: ids("B"), KTC.q4: ids("C")]
        let r = try Scorer.score(exam: exam, questionIDs: session, answers: sheet)
        #expect(r.incorrectOrUnansweredIDs == [KTC.q5, KTC.q3, KTC.q4, KTC.q2])
        #expect(r.questionIDs == session)
    }

    @Test("Id câu không có trong đề → unknownQuestion")
    func unknownQuestion() throws {
        let exam = try sampleExam()
        let stray = UUID()
        #expect(throws: ScoringError.unknownQuestion(stray)) {
            try Scorer.score(exam: exam, questionIDs: [KTC.q1, stray], answers: [:])
        }
    }

    @Test("Id câu lặp trong phiên → duplicateQuestion")
    func duplicateQuestion() throws {
        let exam = try sampleExam()
        #expect(throws: ScoringError.duplicateQuestion(KTC.q2)) {
            try Scorer.score(exam: exam, questionIDs: [KTC.q1, KTC.q2, KTC.q3, KTC.q2], answers: [:])
        }
    }
}
