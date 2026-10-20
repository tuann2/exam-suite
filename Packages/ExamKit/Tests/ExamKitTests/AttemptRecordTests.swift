import Foundation
import Testing
@testable import ExamKit

// Dữ liệu chi tiết một lần thi (docs/product/exam-taking.md, "Dữ liệu một lần thi"; exec-plan giai
// đoạn 3 bước 1): tạo từ phiên đã nộp, vòng mã hoá–giải mã, JSON mẫu cố định để phát hiện đổi
// khoá, payload hỏng, phiên bản mới hơn, dữ liệu mâu thuẫn.

private typealias S = AttemptSamples

/// `body` phải ném đúng loại `AttemptRecordError` mà `matches` nhận.
private func expectRecordError(
    _ description: String,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ matches: (AttemptRecordError) -> Bool,
    _ body: () throws -> Void
) {
    do {
        try body()
        Issue.record("Lẽ ra bị từ chối: \(description)", sourceLocation: sourceLocation)
    } catch let error as AttemptRecordError {
        #expect(matches(error), "\(description): \(error)", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Lỗi không phải AttemptRecordError: \(error)", sourceLocation: sourceLocation)
    }
}

private func isMalformed(_ e: AttemptRecordError) -> Bool {
    if case .malformedPayload = e { return true }
    return false
}

private func isInconsistent(_ e: AttemptRecordError) -> Bool {
    if case .inconsistentPayload = e { return true }
    return false
}

// MARK: - JSON mẫu cố định

/// JSON mẫu cố định (payloadVersion 1) của `AttemptSamples.examRecord()`. KHÔNG sửa cho khớp code:
/// test này đỏ nghĩa là lần thi đã lưu sẽ không đọc được. Muốn đổi định dạng thì tăng
/// `AttemptRecord.currentPayloadVersion`, giữ JSON này làm mẫu của bản 1 và thêm bước đọc bản cũ.
private let examGolden = #"""
{
  "payloadVersion": 1,
  "mode": "exam",
  "timeLimitMinutes": 20,
  "paper": {
    "examID": "0b6c1f8e-4d2a-4c1b-9f3e-2a7d5e8c1b40",
    "options": {
      "selection": {"kind": "all"},
      "shuffleQuestions": true,
      "shuffleOptions": true,
      "seed": "9007199254740993"
    },
    "items": [
      {"questionID": "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e", "sectionID": "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b", "optionOrder": ["D", "B", "C", "A"]},
      {"questionID": "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b", "sectionID": "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c", "optionOrder": ["A", "B", "C"]},
      {"questionID": "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c", "sectionID": "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c", "optionOrder": ["D", "C", "A", "E", "B"]},
      {"questionID": "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a", "sectionID": "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b", "optionOrder": ["B", "C", "A"]},
      {"questionID": "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f", "sectionID": "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b", "optionOrder": ["D", "C", "B", "A"]}
    ]
  },
  "answers": {
    "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e": ["B"],
    "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f": ["A"],
    "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b": ["B"],
    "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c": ["A", "C", "E"]
  },
  "flagged": ["b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f", "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a"],
  "checkedQuestionIDs": [],
  "result": {
    "total": 5,
    "correct": 3,
    "score1000": 600,
    "percent": 60,
    "passPercent": 70,
    "passed": false,
    "sections": [
      {"sectionID": "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b", "title": "Vật lý", "total": 3, "correct": 1},
      {"sectionID": "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c", "title": "Toán", "total": 2, "correct": 2}
    ],
    "outcomes": {
      "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e": "correct",
      "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f": "incorrect",
      "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a": "unanswered",
      "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b": "correct",
      "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c": "correct"
    },
    "questionIDs": [
      "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e",
      "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b",
      "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c",
      "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a",
      "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f"
    ]
  },
  "fingerprints": {
    "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e": "1111111111111111111111111111111111111111111111111111111111111111",
    "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f": "2222222222222222222222222222222222222222222222222222222222222222",
    "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a": "3333333333333333333333333333333333333333333333333333333333333333",
    "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b": "4444444444444444444444444444444444444444444444444444444444444444",
    "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c": "5555555555555555555555555555555555555555555555555555555555555555"
  }
}
"""#

/// JSON mẫu cố định của `AttemptSamples.practiceRecord()`: Luyện tập (không có `timeLimitMinutes`),
/// chọn theo section, có câu đã Kiểm tra đáp án, section 0/0.
private let practiceGolden = #"""
{
  "payloadVersion": 1,
  "mode": "practice",
  "paper": {
    "examID": "0b6c1f8e-4d2a-4c1b-9f3e-2a7d5e8c1b40",
    "options": {
      "selection": {"kind": "sections", "sectionIDs": ["6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c"]},
      "shuffleQuestions": false,
      "shuffleOptions": false,
      "seed": "0"
    },
    "items": [
      {"questionID": "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b", "sectionID": "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c", "optionOrder": ["A", "B", "C"]},
      {"questionID": "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c", "sectionID": "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c", "optionOrder": ["A", "B", "C", "D", "E"]}
    ]
  },
  "answers": {
    "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b": ["A"],
    "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c": ["A", "C", "E"]
  },
  "flagged": [],
  "checkedQuestionIDs": ["d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b"],
  "result": {
    "total": 2,
    "correct": 1,
    "score1000": 500,
    "percent": 50,
    "passPercent": 70,
    "passed": false,
    "sections": [
      {"sectionID": "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b", "title": "Vật lý", "total": 0, "correct": 0},
      {"sectionID": "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c", "title": "Toán", "total": 2, "correct": 1}
    ],
    "outcomes": {
      "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b": "incorrect",
      "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c": "correct"
    },
    "questionIDs": ["d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b", "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c"]
  },
  "fingerprints": {
    "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b": "4444444444444444444444444444444444444444444444444444444444444444",
    "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c": "5555555555555555555555555555555555555555555555555555555555555555"
  }
}
"""#

@Suite("AttemptRecord: JSON mẫu cố định (phát hiện đổi khoá)")
struct AttemptRecordGoldenTests {
    @Test("Đọc JSON mẫu ra đúng bản ghi; ghi bản ghi ra đúng JSON mẫu", arguments: [true, false])
    func golden(isExam: Bool) throws {
        let record = try isExam ? S.examRecord() : S.practiceRecord()
        let golden = Data((isExam ? examGolden : practiceGolden).utf8)

        // Bản app mới phải đọc được payload đã lưu.
        #expect(try AttemptRecord.decode(golden) == record)

        // Bản app mới phải ghi đúng định dạng đó (so ngữ nghĩa: cùng khoá, cùng giá trị).
        let encoded = try record.encoded()
        #expect(JSONCompare.equal(try JSONTree.parse(encoded), try JSONTree.parse(golden)),
                "\(String(decoding: encoded, as: UTF8.self))")
    }

    @Test("Ghi gọn, khoá sắp xếp, không escape '/', seed lớn nguyên vẹn")
    func encodedForm() throws {
        let data = try S.examRecord().encoded()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix(#"{"answers":{"#))
        #expect(!text.contains("\n"))
        #expect(!text.contains(#"\/"#))
        #expect(text.contains(#""seed":"9007199254740993""#))
        #expect(text.contains(#""payloadVersion":1"#))
        // Cùng bản ghi cho cùng byte (tập và từ điển ghi theo thứ tự cố định).
        #expect(try S.examRecord().encoded() == data)
    }
}

@Suite("AttemptRecord: tạo từ phiên đã nộp")
struct AttemptRecordCreationTests {
    @Test("Thi: chép đủ tuỳ chọn, thời gian cho phép, đề, đáp án, đánh dấu, kết quả, dấu vân tay")
    func fromExamSession() throws {
        let s = try S.submittedExamSession()
        let fps = S.fingerprints(for: s.exam)
        let r = try AttemptRecord(session: s, fingerprints: fps)
        #expect(r.mode == .exam)
        #expect(r.timeLimitMinutes == 20)
        #expect(r.paper == s.paper)
        #expect(r.options == s.paper.options)
        #expect(r.options.seed == S.bigSeed)
        #expect(r.examID == s.exam.id)
        #expect(r.answers == s.answers)
        #expect(r.flagged == [S.q2, S.q3])
        #expect(r.checkedQuestionIDs.isEmpty)
        #expect(r.result == s.result)
        #expect(r.result.correct == 3)
        #expect(r.fingerprints == fps)
    }

    @Test("Luyện tập có câu đã Kiểm tra đáp án: không có thời gian cho phép, giữ câu đã kiểm tra")
    func fromPracticeSession() throws {
        let s = try S.submittedPracticeSession()
        let r = try AttemptRecord(session: s, fingerprints: S.fingerprints(for: s.exam))
        #expect(r.mode == .practice)
        #expect(r.timeLimitMinutes == nil)
        #expect(r.checkedQuestionIDs == [S.q4])
        #expect(r.answers == [S.q4: [OptionID("A")!], S.q5: Set("ACE".map { OptionID($0)! })])
        // Chỉ giữ dấu vân tay của câu trong đề đã tạo.
        #expect(Set(r.fingerprints.keys) == [S.q4, S.q5])
        #expect(try AttemptRecord.decode(r.encoded()) == r)
    }

    @Test("Phiên chưa nộp bị từ chối, kèm trạng thái hiện tại")
    func rejectsUnsubmitted() throws {
        let exam = try S.exam()
        let clock = FakeClock()
        let paper = try ExamComposer.compose(exam, options: CompositionOptions(seed: 1))
        var s = try ExamSession(exam: exam, paper: paper, mode: .exam, timeLimitMinutes: 1, candidateName: "A", clock: clock)
        let fps = S.fingerprints(for: exam)

        #expect(throws: AttemptRecordError.sessionNotSubmitted(phase: .inProgress)) {
            try AttemptRecord(session: s, fingerprints: fps)
        }
        try s.pause(reason: .user)
        #expect(throws: AttemptRecordError.sessionNotSubmitted(phase: .paused)) {
            try AttemptRecord(session: s, fingerprints: fps)
        }
        try s.resume()
        try s.openReview()
        #expect(throws: AttemptRecordError.sessionNotSubmitted(phase: .reviewing(locked: false))) {
            try AttemptRecord(session: s, fingerprints: fps)
        }
        clock.advance(minutes: 2)
        _ = s.tick()
        #expect(s.phase == .timeUp)
        #expect(throws: AttemptRecordError.sessionNotSubmitted(phase: .timeUp)) {
            try AttemptRecord(session: s, fingerprints: fps)
        }
        try s.openReview()
        #expect(throws: AttemptRecordError.sessionNotSubmitted(phase: .reviewing(locked: true))) {
            try AttemptRecord(session: s, fingerprints: fps)
        }
        try s.submit()
        #expect(try AttemptRecord(session: s, fingerprints: fps).result.total == 5)
    }

    @Test("Thiếu dấu vân tay hoặc dấu vân tay sai dạng bị từ chối")
    func rejectsBadFingerprints() throws {
        let s = try S.submittedExamSession()
        var fps = S.fingerprints(for: s.exam)
        fps[S.q3] = nil
        #expect(throws: AttemptRecordError.missingFingerprint(questionID: S.q3)) {
            try AttemptRecord(session: s, fingerprints: fps)
        }
        for bad in [String(repeating: "A", count: 64), String(repeating: "a", count: 63), String(repeating: "g", count: 64), ""] {
            fps = S.fingerprints(for: s.exam)
            fps[S.q1] = bad
            #expect(throws: AttemptRecordError.invalidFingerprint(questionID: S.q1)) {
                try AttemptRecord(session: s, fingerprints: fps)
            }
        }
    }

    @Test("Dấu vân tay thừa (câu không trong đề đã tạo) bị bỏ")
    func dropsExtraFingerprints() throws {
        let s = try S.submittedPracticeSession()
        var fps = S.fingerprints(for: s.exam)
        fps[UUID()] = String(repeating: "f", count: 64)
        let r = try AttemptRecord(session: s, fingerprints: fps)
        #expect(Set(r.fingerprints.keys) == Set(s.paper.questionIDs))
    }

    @Test("Phiên chọn N câu ngẫu nhiên và Luyện lại câu sai: vòng mã hoá–giải mã")
    func otherSelections() throws {
        let exam = try S.exam()
        let clock = FakeClock()
        let options = CompositionOptions(selection: .random(count: 3), shuffleOptions: true, seed: .max)
        var s = try ExamSession(
            exam: exam, paper: try ExamComposer.compose(exam, options: options), mode: .practice,
            timeLimitMinutes: nil, candidateName: "A", clock: clock)
        try s.select(option: s.currentItem.optionOrder[0])
        _ = try s.checkAnswer()
        try s.openReview()
        try s.submit()
        let r = try AttemptRecord(session: s, fingerprints: S.fingerprints(for: exam))
        #expect(try AttemptRecord.decode(r.encoded()) == r)
        #expect(try AttemptRecord.decode(r.encoded()).options.seed == .max)

        let retry = try #require(s.practiceIncorrectOptions(seed: 5))
        var s2 = try ExamSession(
            exam: exam, paper: try ExamComposer.compose(exam, options: retry), mode: .practice,
            timeLimitMinutes: nil, candidateName: "A", clock: clock)
        try s2.openReview()
        try s2.submit()
        let r2 = try AttemptRecord(session: s2, fingerprints: S.fingerprints(for: exam))
        #expect(try AttemptRecord.decode(r2.encoded()) == r2)
    }
}

/// Tạo bản ghi từ phiên đã nộp, mã hoá, giải mã, so bằng nhau; trả bản ghi để kiểm thêm.
@discardableResult
private func expectRoundTrip(_ session: ExamSession, sourceLocation: SourceLocation = #_sourceLocation) throws -> AttemptRecord {
    let record = try AttemptRecord(session: session, fingerprints: S.fingerprints(for: session.exam))
    let decoded = try AttemptRecord.decode(record.encoded())
    #expect(decoded == record, sourceLocation: sourceLocation)
    #expect(decoded.result == session.result, sourceLocation: sourceLocation)
    return decoded
}

@Suite("AttemptRecord: vòng tạo → mã hoá → giải mã ở các tình huống biên")
struct AttemptRecordScenarioTests {
    @Test("Thi hết giờ còn câu chưa làm, nộp từ rà soát khoá")
    func timeUpWithUnanswered() throws {
        let exam = try S.exam()
        let clock = FakeClock()
        let paper = try ExamComposer.compose(exam, options: CompositionOptions(shuffleOptions: true, seed: 3))
        var s = try ExamSession(exam: exam, paper: paper, mode: .exam, timeLimitMinutes: 1, candidateName: "A", clock: clock)
        try S.answer(&s, S.q1, "B")
        try S.answer(&s, S.q2, "AC")
        try S.flag(&s, S.q5)
        clock.advance(minutes: 2)
        #expect(s.tick() == [.timeUp])
        try s.openReview()
        #expect(s.phase == .reviewing(locked: true))
        try s.submit()

        let r = try expectRoundTrip(s)
        #expect(r.timeLimitMinutes == 1)
        #expect(r.result.correct == 2)
        #expect(r.result.incorrectOrUnansweredIDs == [S.q3, S.q4, S.q5])
        #expect(r.result.outcomes[S.q3] == .unanswered)
        #expect(r.flagged == [S.q5])
    }

    @Test("Đề hideAnswers ở chế độ Thi")
    func hideAnswersExam() throws {
        var exam = try S.exam()
        exam.hideAnswers = true
        let paper = try ExamComposer.compose(exam, options: CompositionOptions(shuffleQuestions: true, seed: 11))
        var s = try ExamSession(exam: exam, paper: paper, mode: .exam, timeLimitMinutes: nil, candidateName: "A", clock: FakeClock())
        try S.answer(&s, S.q4, "B")
        try S.answer(&s, S.q5, "AC")
        try s.openReview()
        try s.submit()
        #expect(s.practiceIncorrectOptions(seed: 1) == nil)

        let r = try expectRoundTrip(s)
        #expect(r.mode == .exam)
        #expect(r.timeLimitMinutes == 30)
        #expect(r.result.correct == 1)
    }

    @Test("Đề có section rỗng nằm giữa trong file")
    func emptySectionInMiddle() throws {
        var exam = try S.exam()
        let empty = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        exam.sections.insert(ExamSection(id: empty, title: "Trống", questions: []), at: 1)
        let options = CompositionOptions(shuffleQuestions: true, shuffleOptions: true, seed: S.bigSeed)
        var s = try ExamSession(
            exam: exam, paper: try ExamComposer.compose(exam, options: options), mode: .practice,
            timeLimitMinutes: nil, candidateName: "A", clock: FakeClock())
        try S.answer(&s, S.q3, "A")
        _ = try s.checkAnswer()
        try s.openReview()
        try s.submit()

        let r = try expectRoundTrip(s)
        #expect(r.result.sections.map(\.sectionID) == [S.physics, empty, S.math])
        #expect(r.result.sections[1].total == 0)
        #expect(r.result.sections[1].correct == 0)
        #expect(r.checkedQuestionIDs == [S.q3])
    }

    @Test("Làm lại một lần Luyện lại câu sai, đổi sang Thi, bật xáo câu và đáp án")
    func retakeOfPracticeIncorrectAsExam() throws {
        let exam = try S.exam()
        let clock = FakeClock()

        // Lần đầu: Luyện tập mọi câu, đúng q1 và q4.
        var first = try ExamSession(
            exam: exam, paper: try ExamComposer.compose(exam, options: CompositionOptions(seed: 1)),
            mode: .practice, timeLimitMinutes: nil, candidateName: "A", clock: clock)
        try S.answer(&first, S.q1, "B")
        try S.answer(&first, S.q4, "B")
        try S.answer(&first, S.q2, "A")
        try first.openReview()
        try first.submit()
        try expectRoundTrip(first)

        // Luyện lại câu sai: q2, q3, q5 theo thứ tự phiên.
        let retry = try #require(first.practiceIncorrectOptions(seed: 2))
        #expect(retry.selection == .questions([S.q2, S.q3, S.q5]))
        var second = try ExamSession(
            exam: exam, paper: try ExamComposer.compose(exam, options: retry),
            mode: .practice, timeLimitMinutes: nil, candidateName: "A", clock: clock)
        try S.answer(&second, S.q2, "AC")
        _ = try second.checkAnswer()
        try second.openReview()
        try second.submit()
        try expectRoundTrip(second)

        // Làm lại lần Luyện lại câu sai, nhưng là Thi, xáo câu và đáp án, seed lớn.
        var retake = second.retakeOptions(seed: .max)
        retake.shuffleQuestions = true
        retake.shuffleOptions = true
        var third = try ExamSession(
            exam: exam, paper: try ExamComposer.compose(exam, options: retake),
            mode: .exam, timeLimitMinutes: 15, candidateName: "A", clock: clock)
        try S.answer(&third, S.q5, "ACE")
        try S.flag(&third, S.q3)
        try third.openReview()
        try third.submit()

        let r = try expectRoundTrip(third)
        #expect(r.options == retake)
        #expect(r.options.selection == .questions([S.q2, S.q3, S.q5]))
        #expect(Set(r.paper.questionIDs) == [S.q2, S.q3, S.q5])
        #expect(r.mode == .exam)
        #expect(r.timeLimitMinutes == 15)
        #expect(r.result.correct == 1)
        // Theo section chỉ đếm câu của phiên: Vật lý 2 câu (q2, q3), Toán 1 câu (q5).
        #expect(r.result.sections.map(\.total) == [2, 1])
    }
}

@Suite("AttemptRecord: payload hỏng và phiên bản mới hơn")
struct AttemptRecordMalformedTests {
    @Test("Không phải JSON object hợp lệ → malformedPayload", arguments: [
        "", "không phải json", "[]", "null", "1", "{", #"{"payloadVersion":1"#, "{}",
        #"{"payloadVersion":"1"}"#, #"{"payloadVersion":1.5}"#,
    ])
    func notAnObject(text: String) {
        expectRecordError(text, isMalformed) { _ = try AttemptRecord.decode(Data(text.utf8)) }
    }

    @Test("Byte không phải UTF-8 → malformedPayload")
    func invalidUTF8() {
        expectRecordError("byte rác", isMalformed) { _ = try AttemptRecord.decode(Data([0xFF, 0xFE, 0x00, 0x7B])) }
    }

    @Test("Thiếu một khoá bắt buộc → malformedPayload", arguments: [
        "mode", "paper", "answers", "flagged", "checkedQuestionIDs", "result", "fingerprints",
    ])
    func missingKey(key: String) throws {
        var tree = try JSONTree.parse(Data(examGolden.utf8))
        JSONTree.remove(&tree, [key])
        let data = try JSONTree.data(tree)
        expectRecordError(key, isMalformed) { _ = try AttemptRecord.decode(data) }
    }

    static let a1 = "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e"

    static let malformations: [(String, @Sendable (inout Any) -> Void)] = [
        ("mode lạ", { JSONTree.set(&$0, ["mode"], "quiz") }),
        ("khoá đáp án không phải UUID", { JSONTree.set(&$0, ["answers", "q1"], ["A"]) }),
        ("mã lựa chọn sai", { JSONTree.set(&$0, ["answers", a1], ["b"]) }),
        ("đáp án có lựa chọn trùng", { JSONTree.set(&$0, ["answers", a1], ["B", "B"]) }),
        ("đáp án sai kiểu", { JSONTree.set(&$0, ["answers", a1], "B") }),
        ("flagged trùng", { JSONTree.set(&$0, ["flagged"], [a1, a1]) }),
        ("flagged không phải UUID", { JSONTree.set(&$0, ["flagged"], ["x"]) }),
        ("seed là số JSON", { JSONTree.set(&$0, ["paper", "options", "seed"], 5) }),
        ("seed âm", { JSONTree.set(&$0, ["paper", "options", "seed"], "-5") }),
        ("dấu vân tay sai kiểu", { JSONTree.set(&$0, ["fingerprints", a1], 1) }),
        ("timeLimitMinutes sai kiểu", { JSONTree.set(&$0, ["timeLimitMinutes"], "20") }),
        ("result.passed sai kiểu", { JSONTree.set(&$0, ["result", "passed"], "false") }),
        ("payloadVersion 0", { JSONTree.set(&$0, ["payloadVersion"], 0) }),
        ("payloadVersion âm", { JSONTree.set(&$0, ["payloadVersion"], -1) }),
    ]

    @Test("Giá trị sai kiểu hoặc sai dạng → malformedPayload", arguments: 0 ..< malformations.count)
    func malformedValue(index: Int) throws {
        var tree = try JSONTree.parse(Data(examGolden.utf8))
        Self.malformations[index].1(&tree)
        let data = try JSONTree.data(tree)
        expectRecordError(Self.malformations[index].0, isMalformed) { _ = try AttemptRecord.decode(data) }
    }

    @Test("payloadVersion lớn hơn bản app hiểu → unsupportedPayloadVersion, kể cả khi phần còn lại khác hẳn",
          arguments: [2, 3, 999, Int.max])
    func newerVersion(version: Int) throws {
        let minimal = Data(#"{"payloadVersion":\#(version),"somethingNew":{"x":1}}"#.utf8)
        #expect(throws: AttemptRecordError.unsupportedPayloadVersion(found: version, supported: 1)) {
            try AttemptRecord.decode(minimal)
        }
        var tree = try JSONTree.parse(Data(examGolden.utf8))
        JSONTree.set(&tree, ["payloadVersion"], version)
        let full = try JSONTree.data(tree)
        #expect(throws: AttemptRecordError.unsupportedPayloadVersion(found: version, supported: 1)) {
            try AttemptRecord.decode(full)
        }
    }

    @Test("Khoá lạ thêm vào cùng phiên bản được bỏ qua")
    func ignoresUnknownKeys() throws {
        var tree = try JSONTree.parse(Data(examGolden.utf8))
        JSONTree.set(&tree, ["extra"], ["a": 1])
        #expect(try AttemptRecord.decode(JSONTree.data(tree)) == S.examRecord())
    }

    @Test("Đọc UUID chữ hoa như chữ thường")
    func uppercaseUUIDs() throws {
        var text = examGolden
        for id in [S.q1, S.q2, S.q3, S.q4, S.q5, S.physics, S.math] {
            text = text.replacingOccurrences(of: id.uuidString.lowercased(), with: id.uuidString)
        }
        #expect(text != examGolden)
        #expect(try AttemptRecord.decode(Data(text.utf8)) == S.examRecord())
    }
}

@Suite("AttemptRecord: dữ liệu mâu thuẫn bị từ chối")
struct AttemptRecordInconsistencyTests {
    static let q1 = "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e"
    static let q2 = "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f"
    static let q3 = "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a"
    static let q4 = "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b"
    static let q5 = "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c"
    static let physics = "5e1d3b2a-7c4f-4e8d-9a1b-3c5d7e9f1a2b"
    static let math = "6f2e4c3b-8d5a-4f9e-ab2c-4d6e8f0a2b3c"
    static let stranger = "99999999-9999-4999-8999-999999999999"

    /// Phép sửa trên JSON mẫu của lần Thi.
    static let examCases: [(String, @Sendable (inout Any) -> Void)] = [
        ("đáp án của câu không thuộc đề", { JSONTree.set(&$0, ["answers", stranger], ["A"]) }),
        ("đáp án có lựa chọn không thuộc câu", { JSONTree.set(&$0, ["answers", q1], ["E"]) }),
        ("đáp án rỗng", { JSONTree.set(&$0, ["answers", q3], [String]()) }),
        ("có đáp án nhưng kết quả là chưa làm", { JSONTree.set(&$0, ["answers", q3], ["A"]) }),
        ("chưa có đáp án nhưng kết quả là đúng", { JSONTree.remove(&$0, ["answers", q1]) }),
        ("câu đánh dấu không thuộc đề", { JSONTree.set(&$0, ["flagged"], [stranger]) }),
        ("Thi có câu đã Kiểm tra đáp án", { JSONTree.set(&$0, ["checkedQuestionIDs"], [q1]) }),
        ("Thi không có thời gian cho phép", { JSONTree.remove(&$0, ["timeLimitMinutes"]) }),
        ("Thi với thời gian cho phép ngoài 1–600", { JSONTree.set(&$0, ["timeLimitMinutes"], 601) }),
        ("thiếu dấu vân tay một câu", { JSONTree.remove(&$0, ["fingerprints", q3]) }),
        ("dấu vân tay của câu không thuộc đề", { JSONTree.set(&$0, ["fingerprints", stranger], String(repeating: "a", count: 64)) }),
        ("dấu vân tay không phải hex chữ thường", { JSONTree.set(&$0, ["fingerprints", q1], String(repeating: "A", count: 64)) }),
        ("dấu vân tay ngắn", { JSONTree.set(&$0, ["fingerprints", q1], "abc") }),
        ("thứ tự câu của kết quả khác đề", {
            JSONTree.set(&$0, ["result", "questionIDs"], [q1, q2, q3, q4, q5])
        }),
        ("đề thiếu một câu so với kết quả", { JSONTree.modify(&$0, ["paper", "items"]) { $0 = Array(($0 as! [Any]).dropLast()) } }),
        ("đề rỗng", { JSONTree.set(&$0, ["paper", "items"], [Any]()) }),
        ("đề có một câu hai lần", { JSONTree.modify(&$0, ["paper", "items"]) { $0 = ($0 as! [Any]) + [($0 as! [Any])[0]] } }),
        ("câu đổi section so với kết quả theo section", { JSONTree.set(&$0, ["paper", "items", "0", "sectionID"], math) }),
        ("section không có trong kết quả", { JSONTree.set(&$0, ["paper", "items", "0", "sectionID"], stranger) }),
        ("kết quả theo section hoán đổi (tổng vẫn khớp)", {
            JSONTree.set(&$0, ["result", "sections", "0", "correct"], 2)
            JSONTree.set(&$0, ["result", "sections", "1", "correct"], 1)
        }),
        ("chọn N câu ngẫu nhiên khác số câu", { JSONTree.set(&$0, ["paper", "options", "selection"], ["kind": "random", "count": 4]) }),
        ("danh sách câu đã chọn khác đề", {
            JSONTree.set(&$0, ["paper", "options", "selection"], ["kind": "questions", "questionIDs": [q1, q2, q3, q4]])
        }),
        ("section đã chọn không chứa câu của đề", {
            JSONTree.set(&$0, ["paper", "options", "selection"], ["kind": "sections", "sectionIDs": [math]])
        }),
        // Mâu thuẫn bên trong ScoreResult cũng thành inconsistentPayload.
        ("tổng điểm lệch", { JSONTree.set(&$0, ["result", "score1000"], 700) }),
        ("optionOrder trùng lựa chọn", { JSONTree.set(&$0, ["paper", "items", "1", "optionOrder"], ["A", "A", "C"]) }),
    ]

    @Test("Lần Thi mâu thuẫn → inconsistentPayload", arguments: 0 ..< examCases.count)
    func examInconsistent(index: Int) throws {
        var tree = try JSONTree.parse(Data(examGolden.utf8))
        Self.examCases[index].1(&tree)
        let data = try JSONTree.data(tree)
        expectRecordError(Self.examCases[index].0, isInconsistent) { _ = try AttemptRecord.decode(data) }
    }

    /// Phép sửa trên JSON mẫu của lần Luyện tập.
    static let practiceCases: [(String, @Sendable (inout Any) -> Void)] = [
        ("Luyện tập có thời gian cho phép", { JSONTree.set(&$0, ["timeLimitMinutes"], 30) }),
        ("câu đã Kiểm tra đáp án nhưng không có đáp án", {
            JSONTree.set(&$0, ["checkedQuestionIDs"], [q4, q5])
            JSONTree.remove(&$0, ["answers", q5])
        }),
        ("câu đã Kiểm tra đáp án (và đáp án) không thuộc đề", {
            JSONTree.set(&$0, ["checkedQuestionIDs"], [q1])
            JSONTree.set(&$0, ["answers", q1], ["B"])
        }),
        ("section 0/0 nhưng đề có câu của section đó", { JSONTree.set(&$0, ["paper", "items", "0", "sectionID"], physics) }),
    ]

    @Test("Lần Luyện tập mâu thuẫn → inconsistentPayload", arguments: 0 ..< practiceCases.count)
    func practiceInconsistent(index: Int) throws {
        var tree = try JSONTree.parse(Data(practiceGolden.utf8))
        Self.practiceCases[index].1(&tree)
        let data = try JSONTree.data(tree)
        expectRecordError(Self.practiceCases[index].0, isInconsistent) { _ = try AttemptRecord.decode(data) }
    }

    @Test("Hai JSON mẫu không sửa thì đọc được (đối chứng cho các test trên)")
    func controls() throws {
        _ = try AttemptRecord.decode(Data(examGolden.utf8))
        _ = try AttemptRecord.decode(Data(practiceGolden.utf8))
    }
}
