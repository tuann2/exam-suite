import Foundation

// Codable của kết quả chấm, để lưu trong dữ liệu lần thi (docs/product/exam-taking.md,
// "Dữ liệu một lần thi"). Khoá JSON cố định bằng CodingKeys tường minh; đổi khoá phải tăng
// `AttemptRecord.currentPayloadVersion` (xem ComposerCodable.swift).

extension QuestionOutcome: Codable {}

extension SectionScore: Codable {
    private enum CodingKeys: String, CodingKey {
        case sectionID, title, total, correct
    }

    /// Từ chối `correct` âm hoặc lớn hơn `total`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let total = try c.decode(Int.self, forKey: .total)
        let correct = try c.decode(Int.self, forKey: .correct)
        guard correct >= 0, correct <= total else {
            throw inconsistency("Phần có \(correct) câu đúng trên \(total) câu", codingPath: c.codingPath)
        }
        self.init(
            sectionID: try c.decode(UUID.self, forKey: .sectionID),
            title: try c.decode(String.self, forKey: .title),
            total: total,
            correct: correct
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeLowercased(sectionID, forKey: .sectionID)
        try c.encode(title, forKey: .title)
        try c.encode(total, forKey: .total)
        try c.encode(correct, forKey: .correct)
    }
}

/// `ScoreResult` vẫn chỉ tạo bằng `Scorer.score` trong code; ngoại lệ duy nhất là giải mã,
/// và giải mã kiểm lại mọi ràng buộc mà `Scorer` bảo đảm (docs/product/scoring.md):
///
/// - `questionIDs` không trùng, `total == questionIDs.count`;
/// - `outcomes` có đúng các id trong `questionIDs`, `correct` bằng số kết quả `.correct`;
/// - section không trùng id, tổng `total`/`correct` theo section bằng tổng chung;
/// - `passPercent` trong 0–100; `score1000`, `percent`, `passed` khớp công thức với `correct`, `total`,
///   `passPercent`.
///
/// Sai một điều là ném `DecodingError.dataCorrupted` kèm `PayloadConsistencyError`.
/// Số liệu lấy từ JSON có thể rất lớn nên mọi phép tính ở đây không được tràn số.
extension ScoreResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case total, correct, score1000, percent, passPercent, passed, sections, outcomes, questionIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let total = try c.decode(Int.self, forKey: .total)
        let correct = try c.decode(Int.self, forKey: .correct)
        let score1000 = try c.decode(Int.self, forKey: .score1000)
        let percent = try c.decode(Int.self, forKey: .percent)
        let passPercent = try c.decode(Int.self, forKey: .passPercent)
        let passed = try c.decode(Bool.self, forKey: .passed)
        let sections = try c.decode([SectionScore].self, forKey: .sections)
        let outcomes = try c.decodeByID(QuestionOutcome.self, forKey: .outcomes)
        let questionIDs = try c.decode([UUID].self, forKey: .questionIDs)

        func fail(_ reason: String) -> DecodingError { inconsistency(reason, codingPath: c.codingPath) }

        let idSet = Set(questionIDs)
        guard idSet.count == questionIDs.count else { throw fail("Danh sách câu có id trùng") }
        guard total == questionIDs.count else {
            throw fail("total = \(total) nhưng có \(questionIDs.count) câu")
        }
        guard Set(outcomes.keys) == idSet else { throw fail("Kết quả từng câu không khớp danh sách câu") }
        let countedCorrect = outcomes.values.reduce(0) { $0 + ($1 == .correct ? 1 : 0) }
        guard correct == countedCorrect else {
            throw fail("correct = \(correct) nhưng có \(countedCorrect) câu đúng")
        }

        guard Set(sections.map(\.sectionID)).count == sections.count else { throw fail("Section có id trùng") }
        var sectionTotal = 0
        var sectionCorrect = 0
        for s in sections {
            // SectionScore đã kiểm 0 ≤ correct ≤ total; cộng có kiểm tràn.
            let (t, o1) = sectionTotal.addingReportingOverflow(s.total)
            let (k, o2) = sectionCorrect.addingReportingOverflow(s.correct)
            guard !o1, !o2 else { throw fail("Tổng theo section tràn số") }
            sectionTotal = t
            sectionCorrect = k
        }
        guard sectionTotal == total, sectionCorrect == correct else {
            throw fail("Tổng theo section \(sectionCorrect)/\(sectionTotal) khác tổng chung \(correct)/\(total)")
        }

        // 0 ≤ correct ≤ total ≤ số phần tử mảng: nhân 1000 không tràn.
        guard score1000 == Scorer.score1000(correct: correct, total: total) else {
            throw fail("score1000 = \(score1000) không khớp \(correct)/\(total)")
        }
        guard percent == Scorer.percent(correct: correct, total: total) else {
            throw fail("percent = \(percent) không khớp \(correct)/\(total)")
        }
        // passPercent là số nguyên 0–100 (scoring.md); kiểm trước khi dùng công thức của Scorer
        // nên `passPercent * 10` không tràn.
        guard (0 ... 100).contains(passPercent) else {
            throw fail("passPercent = \(passPercent) ngoài 0–100")
        }
        guard passed == Scorer.isPassed(score1000: score1000, passPercent: passPercent) else {
            throw fail("passed = \(passed) không khớp score1000 \(score1000) và passPercent \(passPercent)")
        }

        self.init(
            total: total,
            correct: correct,
            score1000: score1000,
            percent: percent,
            passPercent: passPercent,
            passed: passed,
            sections: sections,
            outcomes: outcomes,
            questionIDs: questionIDs
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(total, forKey: .total)
        try c.encode(correct, forKey: .correct)
        try c.encode(score1000, forKey: .score1000)
        try c.encode(percent, forKey: .percent)
        try c.encode(passPercent, forKey: .passPercent)
        try c.encode(passed, forKey: .passed)
        try c.encode(sections, forKey: .sections)
        try c.encodeByID(outcomes, forKey: .outcomes)
        try c.encodeLowercased(questionIDs, forKey: .questionIDs)
    }
}
