import Foundation
@testable import ExamKit

/// Lần thi dựng tất định từ fixture `kien-thuc-chung` (đồng hồ giả, seed cố định), dùng cho
/// AttemptRecordTests và JSON mẫu cố định.
enum AttemptSamples {
    // Id trong fixture kien-thuc-chung (passPercent 70, timeLimitMinutes 30).
    static let q1 = UUID(uuidString: "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e")! // Vật lý, single ABCD, đúng B
    static let q2 = UUID(uuidString: "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f")! // Vật lý, multiple ABCD, đúng A C
    static let q3 = UUID(uuidString: "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a")! // Vật lý, single ABC, đúng A
    static let q4 = UUID(uuidString: "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b")! // Toán, single ABC, đúng B
    static let q5 = UUID(uuidString: "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c")! // Toán, multiple ABCDE, đúng A C E
    static let physics = UUID(uuidString: "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b")!
    static let math = UUID(uuidString: "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c")!

    /// 2^53 + 1: số nguyên nhỏ nhất mà Double (số JSON ở nhiều bộ đọc) không biểu diễn đúng.
    static let bigSeed: UInt64 = 9_007_199_254_740_993

    static func exam() throws -> Exam {
        try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
    }

    /// Dấu vân tay giả (ExamKit không tính SHA-256): 64 ký tự hex, khác nhau theo câu.
    static func fingerprints(for exam: Exam) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for (i, q) in exam.allQuestions.enumerated() {
            result[q.id] = String(repeating: String(Array("0123456789abcdef")[(i + 1) % 16]), count: 64)
        }
        return result
    }

    /// Chọn đáp án cho câu `id` (đi tới câu đó trước).
    static func answer(_ session: inout ExamSession, _ id: UUID, _ letters: String) throws {
        let index = session.paper.items.firstIndex { $0.questionID == id }!
        try session.goTo(index: index)
        for letter in letters {
            try session.select(option: OptionID(letter)!)
        }
    }

    static func flag(_ session: inout ExamSession, _ id: UUID) throws {
        let index = session.paper.items.firstIndex { $0.questionID == id }!
        try session.goTo(index: index)
        try session.toggleFlag()
    }

    /// Thi 20 phút, mọi câu, xáo câu và đáp án với seed lớn. Đúng q1, q4, q5; sai q2; bỏ q3;
    /// đánh dấu q2, q3. Kết quả 3/5 = 600, 60%, chưa đạt (ngưỡng 70).
    static func submittedExamSession() throws -> ExamSession {
        let exam = try exam()
        let options = CompositionOptions(selection: .all, shuffleQuestions: true, shuffleOptions: true, seed: bigSeed)
        let paper = try ExamComposer.compose(exam, options: options)
        let clock = FakeClock()
        var s = try ExamSession(
            exam: exam, paper: paper, mode: .exam, timeLimitMinutes: 20, candidateName: "Thí sinh", clock: clock
        )
        try answer(&s, q1, "B")
        try answer(&s, q2, "A")
        try answer(&s, q4, "B")
        try answer(&s, q5, "ACE")
        try flag(&s, q2)
        try flag(&s, q3)
        clock.advance(minutes: 7)
        try s.openReview()
        try s.submit()
        return s
    }

    /// Luyện tập phần Toán, không xáo, seed 0. q4 chọn A (sai) rồi Kiểm tra đáp án; q5 đúng,
    /// không kiểm tra. Kết quả 1/2 = 500, 50%.
    static func submittedPracticeSession() throws -> ExamSession {
        let exam = try exam()
        let options = CompositionOptions(selection: .sections([math]), seed: 0)
        let paper = try ExamComposer.compose(exam, options: options)
        var s = try ExamSession(
            exam: exam, paper: paper, mode: .practice, timeLimitMinutes: nil, candidateName: "Thí sinh", clock: FakeClock()
        )
        try answer(&s, q4, "A")
        _ = try s.checkAnswer()
        try answer(&s, q5, "ACE")
        try s.openReview()
        try s.submit()
        return s
    }

    static func examRecord() throws -> AttemptRecord {
        let s = try submittedExamSession()
        return try AttemptRecord(session: s, fingerprints: fingerprints(for: s.exam))
    }

    static func practiceRecord() throws -> AttemptRecord {
        let s = try submittedPracticeSession()
        return try AttemptRecord(session: s, fingerprints: fingerprints(for: s.exam))
    }
}
