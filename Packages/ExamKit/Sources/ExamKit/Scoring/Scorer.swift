import Foundation

/// Chấm điểm theo docs/product/scoring.md (thẩm quyền). Hàm thuần, không trạng thái.
public enum Scorer {
    /// Chấm một câu.
    /// - `selected` nil hoặc rỗng → `unanswered`.
    /// - Đáp án chứa id không có trong `options` → `incorrect`.
    /// - `single`: đúng khi chọn đúng một lựa chọn và đó là phần tử duy nhất của `correct`.
    /// - `multiple`: đúng khi tập chọn bằng đúng tập `correct` (không thiếu, không thừa, không xét thứ tự).
    public static func outcome(of question: Question, selected: Set<OptionID>?) -> QuestionOutcome {
        guard let selected, !selected.isEmpty else { return .unanswered }
        let optionIDs = Set(question.options.map(\.id))
        guard selected.isSubset(of: optionIDs) else { return .incorrect }
        let isCorrect: Bool
        switch question.type {
        case .single:
            isCorrect = selected.count == 1 && selected == question.correctSet
        case .multiple:
            isCorrect = selected == question.correctSet
        }
        return isCorrect ? .correct : .incorrect
    }

    /// `total <= 0 ? 0 : correct * 1000 / total`, chia lấy phần nguyên.
    /// `total` âm coi như 0 (giống bản gốc).
    public static func score1000(correct: Int, total: Int) -> Int {
        total <= 0 ? 0 : (correct * 1000) / total
    }

    /// `total <= 0 ? 0 : correct * 100 / total`, chia lấy phần nguyên; chỉ để hiển thị.
    public static func percent(correct: Int, total: Int) -> Int {
        total <= 0 ? 0 : (correct * 100) / total
    }

    /// Đậu khi `score1000 >= passPercent * 10`.
    public static func isPassed(score1000: Int, passPercent: Int) -> Bool {
        score1000 >= passPercent * 10
    }

    /// Chấm cả phiên thi.
    /// - Parameters:
    ///   - questionIDs: các câu có trong phiên, theo thứ tự phiên.
    ///   - answers: đáp án theo id câu; câu không thuộc `questionIDs` bị bỏ qua.
    /// - Throws: `ScoringError.duplicateQuestion` nếu một id lặp lại,
    ///   `ScoringError.unknownQuestion` nếu id không có trong đề. Kiểm theo thứ tự phiên,
    ///   ném lỗi gặp đầu tiên.
    public static func score(exam: Exam, questionIDs: [UUID], answers: AnswerSheet) throws -> ScoreResult {
        // Chỉ mục id câu → (câu, vị trí section). Nếu đề có id trùng (đề sai, việc của
        // ExamValidator) thì lấy lần xuất hiện đầu, khớp với `Exam.question(id:)`.
        var index: [UUID: (question: Question, section: Int)] = [:]
        for (s, section) in exam.sections.enumerated() {
            for q in section.questions where index[q.id] == nil {
                index[q.id] = (q, s)
            }
        }

        var seen = Set<UUID>()
        var outcomes: [UUID: QuestionOutcome] = [:]
        var sectionTotals = Array(repeating: 0, count: exam.sections.count)
        var sectionCorrect = Array(repeating: 0, count: exam.sections.count)
        var correct = 0

        for id in questionIDs {
            guard seen.insert(id).inserted else { throw ScoringError.duplicateQuestion(id) }
            guard let entry = index[id] else { throw ScoringError.unknownQuestion(id) }
            let result = outcome(of: entry.question, selected: answers[id])
            outcomes[id] = result
            sectionTotals[entry.section] += 1
            if result == .correct {
                correct += 1
                sectionCorrect[entry.section] += 1
            }
        }

        let sections = exam.sections.enumerated().map { s, section in
            SectionScore(
                sectionID: section.id,
                title: section.title,
                total: sectionTotals[s],
                correct: sectionCorrect[s]
            )
        }
        let total = questionIDs.count
        let s1000 = score1000(correct: correct, total: total)
        return ScoreResult(
            total: total,
            correct: correct,
            score1000: s1000,
            percent: percent(correct: correct, total: total),
            passPercent: exam.passPercent,
            passed: isPassed(score1000: s1000, passPercent: exam.passPercent),
            sections: sections,
            outcomes: outcomes,
            questionIDs: questionIDs
        )
    }
}
