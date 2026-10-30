import Foundation
import Testing
@testable import ExamKit

// Tình huống theo docs/product/exam-session.md (mục "Bằng chứng cần có"); danh sách ý
// tham khảo SimulatorSessionTests của Open Exam Suite (chỉ tên tình huống, không chép code).

// MARK: - Hỗ trợ

/// Đồng hồ giả: thời gian chỉ đổi khi test gọi. Giờ hệ thống (`now`) và đồng hồ đơn điệu
/// (`uptime`) điều khiển độc lập được. Dùng chung giữa các bản sao của phiên (struct) nên
/// là class, có khoá để an toàn khi chạy song song.
final class FakeClock: SessionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var wall: Date
    private var monotonic: TimeInterval = 1000

    init(_ start: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        wall = start
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return wall
    }

    func uptime() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return monotonic
    }

    /// Thời gian trôi bình thường: cả hai nguồn cùng tiến.
    func advance(seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        wall += seconds
        monotonic += seconds
    }

    func advance(minutes: Double) { advance(seconds: minutes * 60) }

    /// Chỉ giờ hệ thống đổi (người dùng chỉnh giờ máy, hoặc máy ngủ: uptime không chạy).
    func shiftWall(minutes: Double) {
        lock.lock()
        defer { lock.unlock() }
        wall += minutes * 60
    }
}

private func ids(_ letters: String) -> Set<OptionID> {
    Set(letters.map { OptionID($0)! })
}

private func opt(_ letter: Character) -> OptionID { OptionID(letter)! }

private func sampleExam() throws -> Exam {
    try ExamJSON.decode(Fixtures.data(Fixtures.exam("kien-thuc-chung")))
}

// Id câu trong fixture kien-thuc-chung (passPercent 70, timeLimitMinutes 30).
private enum KTC {
    static let q1 = UUID(uuidString: "a91c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e")! // Vật lý, single ABCD, đúng B
    static let q2 = UUID(uuidString: "b12d3e4f-5a6b-4c7d-9e8f-0a1b2c3d4e5f")! // Vật lý, multiple ABCD, đúng A C
    static let q3 = UUID(uuidString: "c23e4f5a-6b7c-4d8e-8f9a-1b2c3d4e5f6a")! // Vật lý, single ABC, đúng A
    static let q4 = UUID(uuidString: "d34f5a6b-7c8d-4e9f-9a0b-2c3d4e5f6a7b")! // Toán, single ABC, đúng B
    static let q5 = UUID(uuidString: "e45a6b7c-8d9e-4f0a-8b1c-3d4e5f6a7b8c")! // Toán, multiple ABCDE, đúng A C E
    static let all = [q1, q2, q3, q4, q5]
}

private func makeSession(
    _ mode: SessionMode = .exam,
    minutes: Int? = nil,
    exam: Exam? = nil,
    options: CompositionOptions = CompositionOptions(seed: 1),
    clock: FakeClock
) throws -> ExamSession {
    let exam = try exam ?? sampleExam()
    let paper = try ExamComposer.compose(exam, options: options)
    return try ExamSession(
        exam: exam, paper: paper, mode: mode, timeLimitMinutes: minutes, candidateName: "Thí sinh", clock: clock
    )
}

/// Chọn các lựa chọn cho câu hiện tại (multiple: bật từng cái).
private func answer(_ session: inout ExamSession, _ letters: String) throws {
    for letter in letters {
        try session.select(option: opt(letter))
    }
}

/// Chạy lệnh trên bản sao; kỳ vọng ném đúng lỗi và phiên không đổi gì.
private func expectRejected(
    _ session: ExamSession,
    _ expected: SessionError,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ command: (inout ExamSession) throws -> Void
) {
    var copy = session
    do {
        try command(&copy)
        Issue.record("Lệnh lẽ ra bị từ chối với \(expected)", sourceLocation: sourceLocation)
    } catch let error as SessionError {
        #expect(error == expected, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Lỗi không mong đợi: \(error)", sourceLocation: sourceLocation)
    }
    #expect(copy == session, "Phiên phải giữ nguyên khi lệnh bị từ chối", sourceLocation: sourceLocation)
}

// MARK: - Tạo phiên

@Suite("ExamSession: tạo phiên")
struct ExamSessionCreationTests {
    @Test("Exam bắt đầu ngay: inProgress, câu đầu, đồng hồ chạy, thời hạn mặc định của đề")
    func startsExam() throws {
        let clock = FakeClock()
        let s = try makeSession(.exam, clock: clock)
        #expect(s.phase == .inProgress)
        #expect(s.currentIndex == 0)
        #expect(s.currentItem.questionID == KTC.q1)
        #expect(s.currentQuestion.id == KTC.q1)
        #expect(s.answers.isEmpty)
        #expect(s.flagged.isEmpty)
        #expect(s.unansweredCount == 5)
        #expect(s.flaggedCount == 0)
        #expect(s.questionCount == 5)
        #expect(s.mode == .exam)
        #expect(s.timeLimitMinutes == 30)
        #expect(s.elapsed == 0)
        #expect(s.remaining == 1800)
        #expect(s.isClockRunning)
        #expect(s.result == nil)
        #expect(s.candidateName == "Thí sinh")
        #expect(s.startedAt == clock.now())
    }

    @Test("Practice không có đồng hồ đếm ngược; thời hạn truyền vào bị bỏ qua")
    func practiceHasNoTimer() throws {
        let s = try makeSession(.practice, minutes: 45, clock: FakeClock())
        #expect(s.timeLimitMinutes == nil)
        #expect(s.remaining == nil)
        #expect(s.phase == .inProgress)
    }

    @Test("Exam đổi thời hạn khi tạo phiên")
    func examOverridesTimeLimit() throws {
        let s = try makeSession(.exam, minutes: 10, clock: FakeClock())
        #expect(s.timeLimitMinutes == 10)
        #expect(s.remaining == 600)
    }

    @Test("Thời hạn Exam phải trong 1–600 phút", arguments: [
        (-5, false), (0, false), (1, true), (600, true), (601, false),
    ])
    func timeLimitRange(minutes: Int, valid: Bool) throws {
        let clock = FakeClock()
        if valid {
            #expect(try makeSession(.exam, minutes: minutes, clock: clock).timeLimitMinutes == minutes)
        } else {
            #expect(throws: SessionError.invalidTimeLimit(minutes: minutes)) {
                try makeSession(.exam, minutes: minutes, clock: clock)
            }
        }
    }

    @Test("Thời hạn mặc định của đề ngoài khoảng cũng bị từ chối ở Exam, không ảnh hưởng Practice")
    func examDefaultTimeLimitValidated() throws {
        var exam = try sampleExam()
        exam.timeLimitMinutes = 0
        #expect(throws: SessionError.invalidTimeLimit(minutes: 0)) {
            try makeSession(.exam, exam: exam, clock: FakeClock())
        }
        #expect(try makeSession(.exam, minutes: 20, exam: exam, clock: FakeClock()).timeLimitMinutes == 20)
        #expect(try makeSession(.practice, exam: exam, clock: FakeClock()).mode == .practice)
    }

    @Test("hideAnswers khoá Practice nhưng vẫn thi Exam được")
    func hideAnswersBlocksPractice() throws {
        var exam = try sampleExam()
        exam.hideAnswers = true
        #expect(throws: SessionError.practiceNotAllowed) {
            try makeSession(.practice, exam: exam, clock: FakeClock())
        }
        #expect(try makeSession(.exam, exam: exam, clock: FakeClock()).phase == .inProgress)
    }

    @Test("Đề đã tạo cho đề khác bị từ chối")
    func paperExamMismatch() throws {
        let exam = try sampleExam()
        var other = exam
        other.id = UUID()
        let paper = try ExamComposer.compose(other, options: CompositionOptions(seed: 1))
        #expect(throws: SessionError.paperExamMismatch(paperExamID: other.id, examID: exam.id)) {
            try ExamSession(exam: exam, paper: paper, mode: .exam, timeLimitMinutes: nil, candidateName: "", clock: FakeClock())
        }
    }

    @Test("Đề đã tạo rỗng, có câu lạ hoặc câu trùng bị từ chối")
    func invalidPapers() throws {
        let exam = try sampleExam()
        let options = CompositionOptions(seed: 1)
        let section = exam.sections[0].id
        let empty = ExamPaper(examID: exam.id, options: options, items: [])
        #expect(throws: SessionError.emptyPaper) {
            try ExamSession(exam: exam, paper: empty, mode: .exam, timeLimitMinutes: nil, candidateName: "", clock: FakeClock())
        }
        let stray = UUID()
        let unknown = ExamPaper(examID: exam.id, options: options, items: [
            PaperItem(questionID: KTC.q1, sectionID: section, optionOrder: ids("ABCD").sorted()),
            PaperItem(questionID: stray, sectionID: section, optionOrder: []),
        ])
        #expect(throws: SessionError.unknownQuestion(stray)) {
            try ExamSession(exam: exam, paper: unknown, mode: .exam, timeLimitMinutes: nil, candidateName: "", clock: FakeClock())
        }
        let item = PaperItem(questionID: KTC.q1, sectionID: section, optionOrder: ids("ABCD").sorted())
        let duplicate = ExamPaper(examID: exam.id, options: options, items: [item, item])
        #expect(throws: SessionError.duplicateQuestion(KTC.q1)) {
            try ExamSession(exam: exam, paper: duplicate, mode: .exam, timeLimitMinutes: nil, candidateName: "", clock: FakeClock())
        }
    }

    @Test("Equatable so sánh trạng thái, không so sánh đồng hồ")
    func equatableIgnoresClock() throws {
        var a = try makeSession(clock: FakeClock())
        let b = try makeSession(clock: FakeClock())
        #expect(a == b)
        try a.select(option: opt("A"))
        #expect(a != b)
    }

    // `==` của ExamSession viết tay. Danh sách này phải khớp thuộc tính lưu trữ thật; khi test
    // này đỏ vì thêm thuộc tính, hãy thêm thuộc tính đó vào `==` (trừ `clock`) rồi vào đây.
    @Test("== bao mọi thuộc tính lưu trữ (trừ clock)")
    func equatableCoversAllStoredProperties() throws {
        let s = try makeSession(clock: FakeClock())
        let labels = Set(Mirror(reflecting: s).children.compactMap(\.label))
        #expect(labels == [
            "exam", "paper", "mode", "timeLimitMinutes", "candidateName", "startedAt",
            "phase", "currentIndex", "answers", "flagged", "checkedQuestionIDs", "pauseReason",
            "result", "submittedAt", "clock", "questionsByID", "accumulated", "runningSince",
            "phaseBeforePause", "issuedWarnings", "pendingEvents",
        ])
    }
}

// MARK: - Trả lời, đánh dấu, điều hướng

@Suite("ExamSession: trả lời, đánh dấu, điều hướng")
struct ExamSessionAnsweringTests {
    @Test("Câu single: chọn lựa chọn khác thì thay, chọn lại cùng lựa chọn thì giữ")
    func singleReplaces() throws {
        var s = try makeSession(clock: FakeClock())
        try s.select(option: opt("A"))
        #expect(s.answers[KTC.q1] == ids("A"))
        try s.select(option: opt("B"))
        #expect(s.answers[KTC.q1] == ids("B"))
        try s.select(option: opt("B"))
        #expect(s.answers[KTC.q1] == ids("B"))
        #expect(s.unansweredCount == 4)
        #expect(s.isAnswered(KTC.q1))
    }

    @Test("Câu multiple: chọn là bật/tắt; tắt hết = chưa trả lời")
    func multipleToggles() throws {
        var s = try makeSession(clock: FakeClock())
        try s.goTo(index: 1)
        #expect(s.currentQuestion.type == .multiple)
        try s.select(option: opt("A"))
        try s.select(option: opt("C"))
        #expect(s.answers[KTC.q2] == ids("AC"))
        try s.select(option: opt("A"))
        #expect(s.answers[KTC.q2] == ids("C"))
        try s.select(option: opt("C"))
        #expect(s.answers[KTC.q2] == nil)
        #expect(!s.isAnswered(KTC.q2))
        #expect(s.unansweredCount == 5)
    }

    @Test("Lựa chọn không thuộc câu bị từ chối")
    func unknownOptionRejected() throws {
        var s = try makeSession(clock: FakeClock())
        try s.goTo(index: 2) // q3 chỉ có A B C
        expectRejected(s, .unknownOption(opt("D"))) { try $0.select(option: opt("D")) }
    }

    @Test("Xoá đáp án")
    func clearAnswer() throws {
        var s = try makeSession(clock: FakeClock())
        try s.select(option: opt("C"))
        try s.clearAnswer()
        #expect(s.answers[KTC.q1] == nil)
        #expect(s.unansweredCount == 5)
        try s.clearAnswer() // xoá câu chưa trả lời: không lỗi
        #expect(s.answers.isEmpty)
    }

    @Test("Đáp án lưu theo id câu và id lựa chọn gốc, không theo vị trí hiển thị")
    func answersUseOriginalIDs() throws {
        let clock = FakeClock()
        let exam = try sampleExam()
        var s = try makeSession(
            options: CompositionOptions(shuffleQuestions: true, shuffleOptions: true, seed: 2024), clock: clock
        )
        // Chọn đúng đáp án của từng câu theo id gốc, bất kể thứ tự hiển thị.
        for index in 0 ..< s.questionCount {
            try s.goTo(index: index)
            let q = exam.question(id: s.currentItem.questionID)!
            #expect(Set(s.currentItem.optionOrder) == Set(q.options.map(\.id)))
            for id in q.correct {
                try s.select(option: id)
            }
            #expect(s.answers[q.id] == q.correctSet)
        }
        try s.openReview()
        try s.submit()
        #expect(s.result?.correct == 5)
    }

    @Test("Đánh dấu bật/tắt theo id câu")
    func toggleFlag() throws {
        var s = try makeSession(options: CompositionOptions(shuffleQuestions: true, seed: 5), clock: FakeClock())
        let first = s.currentItem.questionID
        try s.toggleFlag()
        #expect(s.flagged == [first])
        try s.next()
        let second = s.currentItem.questionID
        try s.toggleFlag()
        #expect(s.flagged == [first, second])
        #expect(s.flaggedCount == 2)
        try s.toggleFlag()
        #expect(s.flagged == [first])
        #expect(s.flaggedCount == 1)
    }

    @Test("Điều hướng ở biên: câu trước ở câu đầu và câu sau ở câu cuối thì đứng yên")
    func navigationBounds() throws {
        var s = try makeSession(clock: FakeClock())
        try s.previous()
        #expect(s.currentIndex == 0)
        for _ in 0 ..< 10 {
            try s.next()
        }
        #expect(s.currentIndex == 4)
        #expect(s.currentItem.questionID == KTC.q5)
        try s.previous()
        #expect(s.currentIndex == 3)
        try s.goTo(index: 0)
        #expect(s.currentIndex == 0)
        try s.goTo(index: 4)
        #expect(s.currentIndex == 4)
        expectRejected(s, .indexOutOfRange(index: 5, count: 5)) { try $0.goTo(index: 5) }
        expectRejected(s, .indexOutOfRange(index: -1, count: 5)) { try $0.goTo(index: -1) }
    }
}

// MARK: - Chuyển trạng thái

/// Đưa một phiên Exam 10 phút vào trạng thái cần thử.
private func examSession(in phase: SessionPhase, clock: FakeClock) throws -> ExamSession {
    var s = try makeSession(.exam, minutes: 10, clock: clock)
    switch phase {
    case .inProgress:
        break
    case .paused:
        try s.pause(reason: .user)
    case .timeUp:
        clock.advance(minutes: 10)
        _ = s.tick()
    case .reviewing(locked: false):
        try s.openReview()
    case .reviewing(locked: true):
        clock.advance(minutes: 10)
        _ = s.tick()
        try s.openReview()
    case .submitted:
        try s.openReview()
        try s.submit()
    }
    #expect(s.phase == phase)
    return s
}

/// Mọi lệnh (trừ checkAnswer, chỉ có ở Practice), mỗi lệnh một lời gọi đại diện.
private let examCommands: [(SessionCommand, @Sendable (inout ExamSession) throws -> Void)] = [
    (.select, { try $0.select(option: OptionID("A")!) }),
    (.clearAnswer, { try $0.clearAnswer() }),
    (.toggleFlag, { try $0.toggleFlag() }),
    (.goTo, { try $0.goTo(index: 1) }),
    (.next, { try $0.next() }),
    (.previous, { try $0.previous() }),
    (.pause, { try $0.pause(reason: .user) }),
    (.resume, { try $0.resume() }),
    (.openReview, { try $0.openReview() }),
    (.returnToAttempt, { try $0.returnToAttempt() }),
    (.submit, { try $0.submit() }),
]

/// Sơ đồ trạng thái (docs/product/exam-session.md): lệnh hợp lệ ở mỗi phase.
private func allowedCommands(in phase: SessionPhase) -> Set<SessionCommand> {
    switch phase {
    case .inProgress: [.select, .clearAnswer, .toggleFlag, .goTo, .next, .previous, .pause, .openReview]
    case .paused: [.resume]
    case .timeUp: [.openReview]
    case .reviewing(locked: false): [.pause, .returnToAttempt, .submit]
    case .reviewing(locked: true): [.submit]
    case .submitted: []
    }
}

@Suite("ExamSession: chuyển trạng thái")
struct ExamSessionTransitionTests {
    @Test("Lệnh hợp lệ chạy được; lệnh sai trạng thái ném invalidCommand và giữ nguyên phiên", arguments: [
        SessionPhase.inProgress, .paused, .timeUp, .reviewing(locked: false), .reviewing(locked: true), .submitted,
    ])
    func commandMatrix(phase: SessionPhase) throws {
        let clock = FakeClock()
        let s = try examSession(in: phase, clock: clock)
        let allowed = allowedCommands(in: phase)
        for (command, run) in examCommands {
            if allowed.contains(command) {
                var copy = s
                #expect(throws: Never.self, "\(command) ở \(phase)") { try run(&copy) }
            } else {
                expectRejected(s, .invalidCommand(command, phase: phase)) { try run(&$0) }
            }
        }
    }

    @Test("Practice: lệnh hợp lệ chạy được; lệnh sai trạng thái ném invalidCommand và giữ nguyên phiên", arguments: [
        SessionPhase.inProgress, .paused, .reviewing(locked: false), .submitted,
    ])
    func practiceCommandMatrix(phase: SessionPhase) throws {
        var s = try makeSession(.practice, clock: FakeClock())
        try s.select(option: opt("B")) // để checkAnswer có đáp án
        switch phase {
        case .inProgress: break
        case .paused: try s.pause(reason: .user)
        case .reviewing(locked: false): try s.openReview()
        default:
            try s.openReview()
            try s.submit()
        }
        #expect(s.phase == phase)
        var allowed = allowedCommands(in: phase)
        if phase == .inProgress { allowed.insert(.checkAnswer) }
        let check: @Sendable (inout ExamSession) throws -> Void = { _ = try $0.checkAnswer() }
        let commands = examCommands + [(SessionCommand.checkAnswer, check)]
        for (command, run) in commands {
            if allowed.contains(command) {
                var copy = s
                #expect(throws: Never.self, "\(command) ở \(phase)") { try run(&copy) }
            } else {
                expectRejected(s, .invalidCommand(command, phase: phase)) { try run(&$0) }
            }
        }
    }

    @Test("Đích của các chuyển trạng thái hợp lệ")
    func validTargets() throws {
        let clock = FakeClock()
        var s = try examSession(in: .inProgress, clock: clock)
        try s.pause(reason: .user)
        #expect(s.phase == .paused)
        #expect(s.pauseReason == .user)
        try s.resume()
        #expect(s.phase == .inProgress)
        #expect(s.pauseReason == nil)
        try s.openReview()
        #expect(s.phase == .reviewing(locked: false))
        try s.pause(reason: .user)
        try s.resume()
        #expect(s.phase == .reviewing(locked: false), "Tiếp tục quay về đúng bảng rà soát")
        try s.returnToAttempt()
        #expect(s.phase == .inProgress)
        try s.openReview()
        try s.submit()
        #expect(s.phase == .submitted)
        #expect(s.result != nil)
        #expect(!s.isClockRunning)
    }

    @Test("Quay lại làm bài từ rà soát có thể tới thẳng một câu")
    func returnToAttemptAtIndex() throws {
        var s = try examSession(in: .reviewing(locked: false), clock: FakeClock())
        expectRejected(s, .indexOutOfRange(index: 9, count: 5)) { try $0.returnToAttempt(at: 9) }
        try s.returnToAttempt(at: 3)
        #expect(s.phase == .inProgress)
        #expect(s.currentIndex == 3)
    }

    @Test("Check answer không có ở Exam")
    func checkAnswerUnavailableInExam() throws {
        var s = try makeSession(.exam, clock: FakeClock())
        try s.select(option: opt("A"))
        expectRejected(s, .unavailableInMode(.checkAnswer, mode: .exam)) { _ = try $0.checkAnswer() }
    }
}

// MARK: - Đồng hồ: tạm dừng, ngủ–thức

@Suite("ExamSession: tạm dừng và ngủ–thức")
struct ExamSessionPauseTests {
    @Test("Tạm dừng không trừ giờ")
    func pauseDoesNotConsumeTime() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 2)
        try s.pause(reason: .user)
        #expect(!s.isClockRunning)
        clock.advance(minutes: 3)
        #expect(s.elapsed == 120)
        #expect(s.remaining == 480)
        try s.resume()
        #expect(s.remaining == 480)
        clock.advance(seconds: 30)
        #expect(s.elapsed == 150)
        #expect(s.remaining == 450)
    }

    @Test("Tạm dừng lâu hơn thời hạn không gây hết giờ và không phát cảnh báo")
    func longPauseNoEvents() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        try s.pause(reason: .user)
        clock.advance(minutes: 120)
        #expect(s.tick() == [])
        #expect(s.phase == .paused)
        try s.resume()
        #expect(s.tick() == [])
        #expect(s.remaining == 600)
    }

    /// `.background`: app xuống nền ở bản iOS, cùng luật với máy ngủ (mobile.md, mục Bản iOS).
    @Test("Máy ngủ, app xuống nền: phiên tạm dừng, thời gian ngủ không bị trừ, thức dậy vẫn tạm dừng tới khi tiếp tục",
          arguments: [PauseReason.systemSleep, .background])
    func systemSleep(reason: PauseReason) throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 2)
        try s.pause(reason: reason)
        clock.advance(minutes: 60) // ngủ một giờ
        #expect(s.phase == .paused)
        #expect(s.pauseReason == reason)
        #expect(s.tick() == [])
        #expect(s.remaining == 480)
        try s.resume()
        clock.advance(seconds: 1)
        #expect(s.remaining == 479)
        #expect(s.phase == .inProgress)
    }

    @Test("Máy ngủ, app xuống nền khi đang rà soát: thức dậy quay về rà soát, không trừ giờ",
          arguments: [PauseReason.systemSleep, .background])
    func systemSleepWhileReviewing(reason: PauseReason) throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        try s.openReview()
        clock.advance(minutes: 1)
        try s.pause(reason: reason)
        clock.advance(minutes: 30)
        try s.resume()
        #expect(s.phase == .reviewing(locked: false))
        #expect(s.elapsed == 60)
    }

    @Test("Đồng hồ vẫn chạy khi rà soát (không khoá)")
    func clockRunsWhileReviewing() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        try s.openReview()
        clock.advance(minutes: 3)
        try s.returnToAttempt()
        #expect(s.elapsed == 180)
    }

    @Test("Practice cũng dừng đo thời gian khi tạm dừng")
    func practicePause() throws {
        let clock = FakeClock()
        var s = try makeSession(.practice, clock: clock)
        clock.advance(minutes: 4)
        try s.pause(reason: .systemSleep)
        clock.advance(minutes: 60)
        try s.resume()
        clock.advance(minutes: 1)
        #expect(s.elapsed == 300)
        #expect(s.remaining == nil)
    }
}

// MARK: - Đồng hồ: cảnh báo và hết giờ

@Suite("ExamSession: cảnh báo 5/1 phút và hết giờ")
struct ExamSessionTimerTests {
    @Test("Tick mỗi giây: cảnh báo 5 phút, 1 phút, hết giờ, mỗi cái đúng một lần, đúng thời điểm")
    func denseTicks() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        var log: [(second: Int, event: SessionEvent)] = []
        for second in 1 ... 700 {
            clock.advance(seconds: 1)
            for e in s.tick() {
                log.append((second, e))
            }
        }
        #expect(log.map(\.event) == [.warning(minutesLeft: 5), .warning(minutesLeft: 1), .timeUp])
        #expect(log.map(\.second) == [300, 540, 600])
        #expect(s.phase == .timeUp)
    }

    @Test("Tick thưa nhảy qua mốc vẫn phát đủ, theo thứ tự 5 rồi 1; đã hết giờ thì chỉ phát timeUp", arguments: [
        (299.0, [SessionEvent]()),
        (300.0, [.warning(minutesLeft: 5)]),
        (420.0, [.warning(minutesLeft: 5)]),
        (540.0, [.warning(minutesLeft: 5), .warning(minutesLeft: 1)]),
        (599.0, [.warning(minutesLeft: 5), .warning(minutesLeft: 1)]),
        (600.0, [.timeUp]),
        (7200.0, [.timeUp]),
    ])
    func sparseFirstTick(after seconds: TimeInterval, expected: [SessionEvent]) throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(seconds: seconds)
        #expect(s.tick() == expected)
        #expect(s.tick() == [], "Không phát lại")
    }

    @Test("Chuỗi tick thưa: mỗi mốc một lần")
    func sparseSequence() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 6)
        #expect(s.tick() == [.warning(minutesLeft: 5)])
        clock.advance(minutes: 3.5)
        #expect(s.tick() == [.warning(minutesLeft: 1)])
        clock.advance(minutes: 5)
        #expect(s.tick() == [.timeUp])
        clock.advance(minutes: 5)
        #expect(s.tick() == [])
    }

    @Test("Thời hạn ngắn: chỉ cảnh báo các mốc nhỏ hơn thời hạn", arguments: [
        (1, [SessionEvent.timeUp]),
        (3, [.warning(minutesLeft: 1), .timeUp]),
        (5, [.warning(minutesLeft: 1), .timeUp]),
        (6, [.warning(minutesLeft: 5), .warning(minutesLeft: 1), .timeUp]),
    ])
    func shortLimits(minutes: Int, expected: [SessionEvent]) throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: minutes, clock: clock)
        var events: [SessionEvent] = []
        for _ in 0 ..< minutes * 60 + 5 {
            clock.advance(seconds: 1)
            events += s.tick()
        }
        #expect(events == expected)
    }

    @Test("Tạm dừng không làm mất hay lặp cảnh báo")
    func warningsAcrossPause() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 5.5)
        #expect(s.tick() == [.warning(minutesLeft: 5)])
        try s.pause(reason: .user)
        clock.advance(minutes: 30)
        try s.resume()
        #expect(s.tick() == [])
        clock.advance(minutes: 4)
        #expect(s.tick() == [.warning(minutesLeft: 1)])
    }

    @Test("Hết giờ → timeUp → rà soát khoá → không sửa được đáp án, không quay lại → nộp")
    func timeUpFlow() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        try answer(&s, "B") // q1 đúng
        try s.next()
        try answer(&s, "A") // q2 thiếu C → sai
        let answersBefore = s.answers

        clock.advance(minutes: 11) // tick trễ một phút
        #expect(s.tick() == [.timeUp])
        #expect(s.phase == .timeUp)
        #expect(s.elapsed == 600, "Dừng đúng ở thời hạn dù phát hiện muộn")
        #expect(s.remaining == 0)
        #expect(!s.isClockRunning)
        expectRejected(s, .invalidCommand(.select, phase: .timeUp)) { try $0.select(option: opt("C")) }
        expectRejected(s, .invalidCommand(.submit, phase: .timeUp)) { try $0.submit() }

        try s.openReview()
        #expect(s.phase == .reviewing(locked: true))
        let locked = SessionPhase.reviewing(locked: true)
        expectRejected(s, .invalidCommand(.returnToAttempt, phase: locked)) { try $0.returnToAttempt() }
        expectRejected(s, .invalidCommand(.select, phase: locked)) { try $0.select(option: opt("C")) }
        expectRejected(s, .invalidCommand(.clearAnswer, phase: locked)) { try $0.clearAnswer() }
        expectRejected(s, .invalidCommand(.pause, phase: locked)) { try $0.pause(reason: .systemSleep) }

        clock.advance(minutes: 2)
        try s.submit()
        #expect(s.phase == .submitted)
        #expect(s.answers == answersBefore)
        #expect(s.result?.correct == 1)
        #expect(s.result?.total == 5)
        #expect(s.elapsed == 600)
    }

    @Test("Hết giờ khi đang rà soát (không khoá) cũng chuyển timeUp")
    func timeUpWhileReviewing() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        try s.openReview()
        clock.advance(minutes: 10)
        #expect(s.tick() == [.timeUp])
        #expect(s.phase == .timeUp)
        try s.openReview()
        #expect(s.phase == .reviewing(locked: true))
    }

    @Test("Lệnh sau thời hạn mà tick chưa chạy: phiên ghi nhận hết giờ, lệnh bị từ chối, tick sau phát timeUp")
    func commandAfterDeadlineBeforeTick() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 10)
        #expect(throws: SessionError.invalidCommand(.select, phase: .timeUp)) {
            try s.select(option: opt("A"))
        }
        #expect(s.phase == .timeUp)
        #expect(s.answers.isEmpty)
        #expect(s.tick() == [.timeUp])
        #expect(s.tick() == [])
    }

    @Test("Cảnh báo phát hiện trong lúc chạy lệnh được giữ tới tick kế tiếp")
    func pendingWarningDelivered() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 6)
        try s.next()
        clock.advance(minutes: 0.5)
        #expect(s.tick() == [.warning(minutesLeft: 5)])
        #expect(s.tick() == [])
    }

    @Test("Practice không hết giờ và tick không phát sự kiện")
    func practiceNoTimeUp() throws {
        let clock = FakeClock()
        var s = try makeSession(.practice, clock: clock)
        clock.advance(minutes: 6000)
        #expect(s.tick() == [])
        #expect(s.phase == .inProgress)
        #expect(s.remaining == nil)
        #expect(s.elapsed == 6000 * 60)
    }
}

// MARK: - Đồng hồ: lệnh ra đúng lúc đồng hồ đổi, đồng hồ đơn điệu

@Suite("ExamSession: đối chiếu đồng hồ trong lệnh, đồng hồ đơn điệu")
struct ExamSessionClockSourceTests {
    @Test("Lệnh ra sau thời hạn khi tick chưa chạy bị từ chối với phase timeUp, kể cả openReview", arguments: [
        SessionCommand.openReview, .returnToAttempt, .pause, .submit, .select,
    ])
    func commandsAfterDeadline(command: SessionCommand) throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        if command == .returnToAttempt || command == .submit {
            try s.openReview()
        }
        clock.advance(minutes: 10)
        let run = examCommands.first { $0.0 == command }!.1
        #expect(throws: SessionError.invalidCommand(command, phase: .timeUp)) { try run(&s) }
        #expect(s.phase == .timeUp)
        #expect(s.tick() == [.timeUp])
        #expect(s.tick() == [])
        try s.openReview()
        #expect(s.phase == .reviewing(locked: true))
    }

    @Test("Lệnh bị từ chối đúng lúc vượt mốc cảnh báo vẫn ghi nhận cảnh báo cho tick sau")
    func rejectedCommandRecordsWarning() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 5.5)
        #expect(throws: SessionError.indexOutOfRange(index: 99, count: 5)) { try s.goTo(index: 99) }
        clock.advance(minutes: 4)
        #expect(throws: SessionError.invalidCommand(.resume, phase: .inProgress)) { try s.resume() }
        #expect(s.phase == .inProgress)
        #expect(s.currentIndex == 0)
        #expect(s.tick() == [.warning(minutesLeft: 5), .warning(minutesLeft: 1)])
    }

    @Test("Sau khi nộp, tick không trả sự kiện còn chờ")
    func noEventsAfterSubmit() throws {
        let clock = FakeClock()
        // Cảnh báo ghi nhận lúc nộp.
        var a = try makeSession(.exam, minutes: 10, clock: clock)
        try a.openReview()
        clock.advance(minutes: 5.5)
        try a.submit()
        #expect(a.tick() == [])
        // timeUp ghi nhận bởi lệnh, chưa tick, rồi rà soát khoá và nộp.
        var b = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 10)
        #expect(throws: SessionError.invalidCommand(.select, phase: .timeUp)) { try b.select(option: opt("A")) }
        try b.openReview()
        try b.submit()
        #expect(b.tick() == [])
        #expect(b.phase == .submitted)
    }

    @Test("Lùi giờ hệ thống không đổi thời gian đã làm; mốc ghi lại dùng giờ hệ thống")
    func wallClockChangeIgnored() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        let started = clock.now()
        clock.advance(minutes: 2)
        clock.shiftWall(minutes: -60) // người dùng lùi giờ máy một giờ
        clock.advance(minutes: 1)
        #expect(s.elapsed == 180)
        #expect(s.remaining == 420)
        clock.shiftWall(minutes: 120) // rồi đẩy tới hai giờ
        #expect(s.elapsed == 180)
        #expect(s.tick() == [])
        #expect(s.startedAt == started)
        try s.openReview()
        try s.submit()
        #expect(s.submittedAt == clock.now())
        #expect(s.elapsed == 180)
    }

    @Test("Máy ngủ mà app lỡ thông báo: uptime không chạy nên không trừ giờ")
    func missedSleepNotification() throws {
        let clock = FakeClock()
        var s = try makeSession(.exam, minutes: 10, clock: clock)
        clock.advance(minutes: 2)
        clock.shiftWall(minutes: 60) // ngủ một giờ, không gọi pause
        #expect(s.tick() == [])
        #expect(s.phase == .inProgress)
        #expect(s.elapsed == 120)
        clock.advance(minutes: 1)
        #expect(s.elapsed == 180)
    }

    @Test("SystemSessionClock: uptime đơn điệu, phiên thật bắt đầu với elapsed gần 0")
    func systemClock() throws {
        let clock = SystemSessionClock()
        let first = clock.uptime()
        let second = clock.uptime()
        #expect(first >= 0)
        #expect(second >= first)
        let exam = try sampleExam()
        let paper = try ExamComposer.compose(exam, options: CompositionOptions(seed: 1))
        var s = try ExamSession(exam: exam, paper: paper, mode: .exam, timeLimitMinutes: nil, candidateName: "", clock: clock)
        #expect(s.elapsed >= 0 && s.elapsed < 5)
        #expect((s.remaining ?? 0) > 1795)
        #expect(s.tick() == [])
        #expect(abs(s.startedAt.timeIntervalSinceNow) < 5)
    }
}

// MARK: - Practice: Check answer

@Suite("ExamSession: Practice và Check answer")
struct ExamSessionPracticeTests {
    @Test("Check answer hiện đúng/sai và giải thích, rồi khoá đáp án câu đó")
    func checkLocksAnswer() throws {
        let exam = try sampleExam()
        var s = try makeSession(.practice, clock: FakeClock())
        try s.select(option: opt("A")) // q1 đúng là B
        let check = try s.checkAnswer()
        #expect(check.questionID == KTC.q1)
        #expect(check.outcome == .incorrect)
        #expect(check.correctOptions == ids("B"))
        #expect(check.explanation == exam.question(id: KTC.q1)?.explanation)
        #expect(check.explanation != nil)
        #expect(s.checkedQuestionIDs == [KTC.q1])

        expectRejected(s, .answerLocked(questionID: KTC.q1)) { try $0.select(option: opt("B")) }
        expectRejected(s, .answerLocked(questionID: KTC.q1)) { try $0.clearAnswer() }
        #expect(s.answers[KTC.q1] == ids("A"))

        // Vẫn đánh dấu được; check lại trả cùng kết quả.
        try s.toggleFlag()
        #expect(s.flagged == [KTC.q1])
        #expect(try s.checkAnswer() == check)

        // Câu khác vẫn sửa được.
        try s.next()
        try answer(&s, "AC")
        let second = try s.checkAnswer()
        #expect(second.outcome == .correct)
        #expect(second.correctOptions == ids("AC"))
    }

    @Test("Không check được câu chưa trả lời")
    func checkRequiresAnswer() throws {
        let s = try makeSession(.practice, clock: FakeClock())
        expectRejected(s, .noAnswerToCheck(questionID: KTC.q1)) { _ = try $0.checkAnswer() }
    }

    @Test("Check answer chỉ khi đang làm bài", arguments: [
        SessionPhase.paused, .reviewing(locked: false), .submitted,
    ])
    func checkOnlyInProgress(phase: SessionPhase) throws {
        var s = try makeSession(.practice, clock: FakeClock())
        try s.select(option: opt("B"))
        switch phase {
        case .paused: try s.pause(reason: .user)
        case .reviewing: try s.openReview()
        default:
            try s.openReview()
            try s.submit()
        }
        #expect(s.phase == phase)
        expectRejected(s, .invalidCommand(.checkAnswer, phase: phase)) { _ = try $0.checkAnswer() }
    }
}

// MARK: - Nộp bài và tuỳ chọn làm tiếp

@Suite("ExamSession: nộp bài, làm lại, luyện lại câu sai")
struct ExamSessionSubmitTests {
    @Test("Nộp ra ScoreResult đúng như Scorer, dừng đồng hồ")
    func submitScores() throws {
        let clock = FakeClock()
        let exam = try sampleExam()
        var s = try makeSession(.exam, clock: clock)
        try answer(&s, "B") // q1 đúng
        try s.next()
        try answer(&s, "AC") // q2 đúng
        try s.next()
        try answer(&s, "B") // q3 sai
        try s.next() // q4 bỏ trống
        try s.next()
        try answer(&s, "ACE") // q5 đúng
        clock.advance(minutes: 7)
        try s.openReview()
        #expect(s.unansweredCount == 1)
        try s.submit()

        let result = try #require(s.result)
        #expect(result == (try Scorer.score(exam: exam, questionIDs: KTC.all, answers: s.answers)))
        #expect(result.total == 5)
        #expect(result.correct == 3)
        #expect(result.score1000 == 600)
        #expect(result.percent == 60)
        #expect(!result.passed)
        #expect(result.sections.map(\.total) == [3, 2])
        #expect(result.sections.map(\.correct) == [2, 1])
        #expect(result.outcomes[KTC.q4] == .unanswered)
        #expect(s.submittedAt == clock.now())
        #expect(s.elapsed == 420)
        clock.advance(minutes: 10)
        #expect(s.elapsed == 420, "Thời gian làm dừng sau khi nộp")
    }

    @Test("Luyện lại câu sai: câu sai/chưa làm theo thứ tự phiên, không xáo, seed truyền vào")
    func practiceIncorrect() throws {
        let exam = try sampleExam()
        var s = try makeSession(.exam, options: CompositionOptions(shuffleQuestions: true, shuffleOptions: true, seed: 77), clock: FakeClock())
        #expect(s.practiceIncorrectOptions(seed: 1) == nil, "Chưa nộp thì chưa có")
        // Chỉ trả lời đúng câu hiện ở vị trí 0.
        let firstQuestion = exam.question(id: s.currentItem.questionID)!
        for id in firstQuestion.correct {
            try s.select(option: id)
        }
        try s.openReview()
        try s.submit()

        let expectedIDs = Array(s.paper.questionIDs.dropFirst())
        let options = try #require(s.practiceIncorrectOptions(seed: 99))
        #expect(options == CompositionOptions(selection: .questions(expectedIDs), shuffleQuestions: false, shuffleOptions: false, seed: 99))
        // Dùng được để tạo phiên Practice mới gồm đúng các câu đó.
        let paper = try ExamComposer.compose(exam, options: options)
        #expect(paper.questionIDs == expectedIDs)
        let retry = try ExamSession(exam: exam, paper: paper, mode: .practice, timeLimitMinutes: nil, candidateName: "", clock: FakeClock())
        #expect(retry.questionCount == 4)
    }

    @Test("Luyện lại câu sai: nil khi đúng hết hoặc đề hideAnswers")
    func practiceIncorrectNil() throws {
        var s = try makeSession(.exam, clock: FakeClock())
        for letters in ["B", "AC", "A", "B", "ACE"] {
            try answer(&s, letters)
            try s.next()
        }
        try s.openReview()
        try s.submit()
        #expect(s.result?.passed == true)
        #expect(s.practiceIncorrectOptions(seed: 1) == nil)

        var hidden = try sampleExam()
        hidden.hideAnswers = true
        var h = try makeSession(.exam, exam: hidden, clock: FakeClock())
        try h.openReview()
        try h.submit()
        #expect(h.result?.correct == 0)
        #expect(h.practiceIncorrectOptions(seed: 1) == nil)
    }

    @Test("Làm lại: giữ cách chọn câu và xáo, thay seed; seed cũ tái hiện đúng đề")
    func retake() throws {
        let exam = try sampleExam()
        let original = CompositionOptions(selection: .random(count: 3), shuffleQuestions: true, shuffleOptions: true, seed: 9)
        let s = try makeSession(.exam, options: original, clock: FakeClock())
        #expect(s.retakeOptions(seed: 9) == original)
        #expect(try ExamComposer.compose(exam, options: s.retakeOptions(seed: 9)) == s.paper)
        let fresh = s.retakeOptions(seed: 10)
        #expect(fresh.seed == 10)
        #expect(fresh.selection == original.selection)
        #expect(fresh.shuffleQuestions && fresh.shuffleOptions)
    }
}
