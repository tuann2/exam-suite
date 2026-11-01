import Foundation

/// Phiên thi: state machine thuần theo docs/product/exam-session.md (thẩm quyền).
///
/// Là giá trị (struct): mỗi lệnh là `mutating`, lệnh không hợp lệ ném `SessionError`.
/// Lệnh bị từ chối không đổi phiên, trừ phần ghi nhận đồng hồ (xem "Phát hiện hết giờ
/// và cảnh báo" bên dưới). Giao diện (giai đoạn 3) bọc phiên trong view model `@Observable`
/// và gọi `tick()` định kỳ (ví dụ mỗi giây) để nhận cảnh báo và hết giờ.
///
/// ## Đồng hồ
///
/// - Thời gian lấy từ `SessionClock` tiêm vào; không có Timer hay luồng nền.
/// - Thời gian đã làm (`elapsed`) = tổng các khoảng đồng hồ chạy, tính bằng mốc
///   `clock.uptime()` (đơn điệu, không chạy khi máy ngủ) lúc chạy/dừng, không cộng dồn
///   tick. Chỉnh giờ hệ thống không ảnh hưởng. `clock.now()` chỉ dùng cho `startedAt`,
///   `submittedAt`.
/// - Đồng hồ chạy ở `inProgress` và `reviewing(locked: false)` (rà soát vẫn tính giờ,
///   như bản gốc), dừng ở `paused`, `timeUp`, `reviewing(locked: true)`, `submitted`.
///   Practice cũng đo `elapsed` (để lưu thời gian làm) nhưng không có thời hạn.
/// - Exam: khi `elapsed` chạm thời hạn, phase chuyển sang `timeUp`, `elapsed` dừng
///   đúng bằng thời hạn (kể cả khi phát hiện muộn).
///
/// ## Phát hiện hết giờ và cảnh báo
///
/// Mọi lệnh và `tick()` đều đối chiếu đồng hồ trước khi làm việc, kể cả lệnh rồi bị từ
/// chối. Lần đối chiếu có thể ghi nhận cảnh báo đã tới mốc và hết giờ: nếu đã quá giờ,
/// phiên chuyển sang `timeUp` trước, nên lệnh ra sau thời hạn bị từ chối
/// (`invalidCommand(_, phase: .timeUp)`) dù `tick()` chưa kịp chạy; cả `openReview` cũng
/// bị từ chối lần đó, để giao diện thấy màn Hết giờ trước. Sự kiện ghi nhận trong lúc chạy
/// lệnh được giữ lại và trả ở lần `tick()` kế tiếp, nên không mất cảnh báo hay `timeUp`.
/// Sau khi nộp không còn sự kiện nào.
public struct ExamSession: Sendable {
    /// Khoảng thời hạn Exam hợp lệ, phút.
    public static let timeLimitRange = 1 ... 600
    /// Các mốc cảnh báo (phút còn lại), theo thứ tự phát.
    public static let warningMinutes = [5, 1]

    // MARK: Dữ liệu cố định của phiên

    public let exam: Exam
    public let paper: ExamPaper
    public let mode: SessionMode
    /// Thời hạn (phút) của phiên Exam; nil ở Practice.
    public let timeLimitMinutes: Int?
    public let candidateName: String
    /// `clock.now()` (giờ hệ thống) lúc tạo phiên; chỉ để ghi lại, không dùng đo thời gian.
    public let startedAt: Date

    // MARK: Trạng thái

    public private(set) var phase: SessionPhase
    /// Vị trí câu hiện tại trong `paper.items`.
    public private(set) var currentIndex: Int
    /// Đáp án theo id câu và id lựa chọn gốc. Không có khoá = chưa trả lời (không lưu tập rỗng).
    public private(set) var answers: AnswerSheet
    /// Id các câu đang được đánh dấu.
    public private(set) var flagged: Set<UUID>
    /// Id các câu đã Check answer (Practice); đáp án các câu này bị khoá.
    public private(set) var checkedQuestionIDs: Set<UUID>
    /// Lý do tạm dừng khi `phase == .paused`; nil ở trạng thái khác.
    public private(set) var pauseReason: PauseReason?
    /// Kết quả chấm, có sau `submit`.
    public private(set) var result: ScoreResult?
    /// `clock.now()` (giờ hệ thống) lúc nộp; chỉ để ghi lại.
    public private(set) var submittedAt: Date?

    // MARK: Nội bộ

    private let clock: any SessionClock
    private let questionsByID: [UUID: Question]
    /// Tổng thời gian đồng hồ đã chạy trước `runningSince`, giây.
    private var accumulated: TimeInterval
    /// `clock.uptime()` lúc đồng hồ bắt đầu chạy lần gần nhất; nil khi đồng hồ dừng.
    private var runningSince: TimeInterval?
    /// Phase để `resume` quay về (`inProgress` hoặc `reviewing(locked: false)`).
    private var phaseBeforePause: SessionPhase?
    /// Các mốc cảnh báo đã phát (phút).
    private var issuedWarnings: Set<Int>
    /// Sự kiện phát hiện trong lúc chạy lệnh, chờ trả ở `tick()` kế tiếp.
    private var pendingEvents: [SessionEvent]

    /// Tạo phiên và bắt đầu làm ngay: phase `inProgress`, câu đầu tiên, đồng hồ chạy.
    ///
    /// - Parameters:
    ///   - paper: đề đã tạo bằng `ExamComposer.compose` cho chính `exam`.
    ///   - timeLimitMinutes: thời hạn Exam do người dùng đổi; nil → `exam.timeLimitMinutes`.
    ///     Bỏ qua ở Practice.
    /// - Throws: `SessionError.paperExamMismatch`, `.emptyPaper`, `.practiceNotAllowed`,
    ///   `.unknownQuestion`, `.duplicateQuestion`, `.invalidTimeLimit` (kiểm theo thứ tự này).
    public init(
        exam: Exam,
        paper: ExamPaper,
        mode: SessionMode,
        timeLimitMinutes: Int?,
        candidateName: String,
        clock: some SessionClock
    ) throws {
        guard paper.examID == exam.id else {
            throw SessionError.paperExamMismatch(paperExamID: paper.examID, examID: exam.id)
        }
        guard !paper.items.isEmpty else { throw SessionError.emptyPaper }
        if mode == .practice, exam.hideAnswers { throw SessionError.practiceNotAllowed }

        // Chỉ mục câu của đề; id trùng trong đề là lỗi soạn đề, lấy lần đầu như Scorer.
        var lookup: [UUID: Question] = [:]
        for q in exam.allQuestions where lookup[q.id] == nil {
            lookup[q.id] = q
        }
        var seen = Set<UUID>()
        var used: [UUID: Question] = [:]
        for item in paper.items {
            guard let q = lookup[item.questionID] else { throw SessionError.unknownQuestion(item.questionID) }
            guard seen.insert(item.questionID).inserted else { throw SessionError.duplicateQuestion(item.questionID) }
            used[q.id] = q
        }

        switch mode {
        case .practice:
            self.timeLimitMinutes = nil
        case .exam:
            let minutes = timeLimitMinutes ?? exam.timeLimitMinutes
            guard Self.timeLimitRange.contains(minutes) else { throw SessionError.invalidTimeLimit(minutes: minutes) }
            self.timeLimitMinutes = minutes
        }

        let now = clock.now()
        let t = clock.uptime()
        self.exam = exam
        self.paper = paper
        self.mode = mode
        self.candidateName = candidateName
        self.clock = clock
        self.questionsByID = used
        startedAt = now
        phase = .inProgress
        currentIndex = 0
        answers = [:]
        flagged = []
        checkedQuestionIDs = []
        pauseReason = nil
        result = nil
        submittedAt = nil
        accumulated = 0
        runningSince = t
        phaseBeforePause = nil
        issuedWarnings = []
        pendingEvents = []
    }

    // MARK: - Truy vấn

    /// Câu hiện tại trong đề đã tạo (id câu, section gốc, thứ tự hiển thị lựa chọn).
    public var currentItem: PaperItem { paper.items[currentIndex] }

    /// Nội dung câu hiện tại.
    public var currentQuestion: Question { question(for: currentItem) }

    /// Nội dung câu của một mục trong `paper.items`.
    public func question(for item: PaperItem) -> Question {
        // init đã bảo đảm mọi câu của paper có trong đề.
        questionsByID[item.questionID]!
    }

    /// Số câu trong phiên.
    public var questionCount: Int { paper.items.count }

    /// Câu đã có đáp án (ít nhất một lựa chọn).
    public func isAnswered(_ questionID: UUID) -> Bool {
        !(answers[questionID] ?? []).isEmpty
    }

    public var unansweredCount: Int {
        paper.items.reduce(0) { $0 + (isAnswered($1.questionID) ? 0 : 1) }
    }

    public var flaggedCount: Int { flagged.count }

    /// Đồng hồ có đang chạy không.
    public var isClockRunning: Bool { runningSince != nil }

    /// Thời gian đã làm. Exam: không vượt thời hạn.
    public var elapsed: TimeInterval { elapsed(at: clock.uptime()) }

    /// Thời gian còn lại, không âm; nil ở Practice.
    public var remaining: TimeInterval? {
        guard let limit = timeLimit else { return nil }
        return max(0, limit - elapsed)
    }

    /// Tuỳ chọn cho "Luyện lại câu sai" (chạy ở Practice): đúng các câu sai hoặc chưa làm,
    /// theo thứ tự phiên, không xáo. nil nếu chưa nộp, không còn câu sai, hoặc đề có
    /// `hideAnswers` (Practice bị khoá).
    public func practiceIncorrectOptions(seed: UInt64) -> CompositionOptions? {
        guard let result, !exam.hideAnswers else { return nil }
        let ids = result.incorrectOrUnansweredIDs
        guard !ids.isEmpty else { return nil }
        return CompositionOptions(selection: .questions(ids), shuffleQuestions: false, shuffleOptions: false, seed: seed)
    }

    /// Tuỳ chọn cho "Làm lại": giữ nguyên cách chọn câu và xáo của phiên này, thay seed.
    /// Truyền `paper.options.seed` để tái hiện đúng đề cũ.
    public func retakeOptions(seed: UInt64) -> CompositionOptions {
        var options = paper.options
        options.seed = seed
        return options
    }

    // MARK: - Lệnh: trả lời, đánh dấu, điều hướng (chỉ khi inProgress)

    /// Chọn một lựa chọn (id gốc) cho câu hiện tại. `single`: thay đáp án cũ;
    /// `multiple`: bật/tắt lựa chọn đó (tắt hết = chưa trả lời).
    public mutating func select(option: OptionID) throws {
        syncClock(at: clock.uptime())
        try require(.select, phase == .inProgress)
        let q = currentQuestion
        guard !checkedQuestionIDs.contains(q.id) else { throw SessionError.answerLocked(questionID: q.id) }
        guard q.options.contains(where: { $0.id == option }) else { throw SessionError.unknownOption(option) }
        switch q.type {
        case .single:
            answers[q.id] = [option]
        case .multiple:
            var set = answers[q.id] ?? []
            if set.contains(option) { set.remove(option) } else { set.insert(option) }
            answers[q.id] = set.isEmpty ? nil : set
        }
    }

    /// Xoá đáp án câu hiện tại.
    public mutating func clearAnswer() throws {
        syncClock(at: clock.uptime())
        try require(.clearAnswer, phase == .inProgress)
        let id = currentItem.questionID
        guard !checkedQuestionIDs.contains(id) else { throw SessionError.answerLocked(questionID: id) }
        answers[id] = nil
    }

    /// Bật/tắt đánh dấu câu hiện tại. Được cả khi đáp án đã khoá sau Check answer.
    public mutating func toggleFlag() throws {
        syncClock(at: clock.uptime())
        try require(.toggleFlag, phase == .inProgress)
        let id = currentItem.questionID
        if flagged.contains(id) { flagged.remove(id) } else { flagged.insert(id) }
    }

    /// Tới câu ở vị trí `index` (0-based).
    public mutating func goTo(index: Int) throws {
        syncClock(at: clock.uptime())
        try require(.goTo, phase == .inProgress)
        guard paper.items.indices.contains(index) else {
            throw SessionError.indexOutOfRange(index: index, count: paper.items.count)
        }
        currentIndex = index
    }

    /// Câu sau; ở câu cuối thì đứng yên (không lỗi).
    public mutating func next() throws {
        syncClock(at: clock.uptime())
        try require(.next, phase == .inProgress)
        currentIndex = min(currentIndex + 1, paper.items.count - 1)
    }

    /// Câu trước; ở câu đầu thì đứng yên (không lỗi).
    public mutating func previous() throws {
        syncClock(at: clock.uptime())
        try require(.previous, phase == .inProgress)
        currentIndex = max(currentIndex - 1, 0)
    }

    /// Check answer (chỉ Practice, khi đang làm): chấm câu hiện tại và khoá đáp án câu đó.
    /// Gọi lại trên câu đã khoá trả cùng kết quả.
    public mutating func checkAnswer() throws -> AnswerCheck {
        syncClock(at: clock.uptime())
        guard mode == .practice else { throw SessionError.unavailableInMode(.checkAnswer, mode: mode) }
        try require(.checkAnswer, phase == .inProgress)
        let q = currentQuestion
        guard let selected = answers[q.id], !selected.isEmpty else {
            throw SessionError.noAnswerToCheck(questionID: q.id)
        }
        checkedQuestionIDs.insert(q.id)
        return AnswerCheck(
            questionID: q.id,
            outcome: Scorer.outcome(of: q, selected: selected),
            correctOptions: q.correctSet,
            explanation: q.explanation
        )
    }

    // MARK: - Lệnh: tạm dừng

    /// Tạm dừng từ `inProgress` hoặc `reviewing(locked: false)`; đồng hồ dừng.
    /// Gọi với `.systemSleep` khi máy sắp ngủ, `.background` khi app xuống nền (bản iOS).
    public mutating func pause(reason: PauseReason) throws {
        let t = clock.uptime()
        syncClock(at: t)
        try require(.pause, phase == .inProgress || phase == .reviewing(locked: false))
        phaseBeforePause = phase
        pauseReason = reason
        setPhase(.paused, at: t)
    }

    /// Tiếp tục: về đúng trạng thái trước khi tạm dừng; đồng hồ chạy lại.
    public mutating func resume() throws {
        let t = clock.uptime()
        syncClock(at: t)
        try require(.resume, phase == .paused)
        let target = phaseBeforePause ?? .inProgress
        phaseBeforePause = nil
        pauseReason = nil
        setPhase(target, at: t)
    }

    // MARK: - Lệnh: rà soát và nộp

    /// Mở bảng rà soát. Từ `inProgress` → `reviewing(locked: false)`;
    /// từ `timeUp` → `reviewing(locked: true)` (giao diện gọi ngay sau khi hiện Hết giờ).
    public mutating func openReview() throws {
        let t = clock.uptime()
        // Vừa phát hiện hết giờ trong chính lệnh này: từ chối, để giao diện thấy `timeUp`
        // (màn Hết giờ) rồi mới mở rà soát khoá, nhất quán với các lệnh khác.
        if syncClock(at: t) {
            throw SessionError.invalidCommand(.openReview, phase: phase)
        }
        switch phase {
        case .inProgress:
            setPhase(.reviewing(locked: false), at: t)
        case .timeUp:
            setPhase(.reviewing(locked: true), at: t)
        default:
            throw SessionError.invalidCommand(.openReview, phase: phase)
        }
    }

    /// Từ rà soát (không khoá) quay lại làm bài, tuỳ chọn tới thẳng câu `index`.
    public mutating func returnToAttempt(at index: Int? = nil) throws {
        let t = clock.uptime()
        syncClock(at: t)
        try require(.returnToAttempt, phase == .reviewing(locked: false))
        if let index {
            guard paper.items.indices.contains(index) else {
                throw SessionError.indexOutOfRange(index: index, count: paper.items.count)
            }
            currentIndex = index
        }
        setPhase(.inProgress, at: t)
    }

    /// Nộp bài (chỉ từ rà soát): chấm bằng `Scorer`, dừng đồng hồ. Hỏi xác nhận khi còn
    /// câu chưa làm là việc của giao diện.
    public mutating func submit() throws {
        let t = clock.uptime()
        syncClock(at: t)
        guard case .reviewing = phase else { throw SessionError.invalidCommand(.submit, phase: phase) }
        // init đã kiểm câu thuộc đề và không trùng nên Scorer không ném ở đây.
        let scored = try Scorer.score(exam: exam, questionIDs: paper.questionIDs, answers: answers)
        setPhase(.submitted, at: t)
        result = scored
        submittedAt = clock.now()
        // Sau khi nộp, cảnh báo/hết giờ chưa kịp lấy không còn ý nghĩa.
        pendingEvents = []
    }

    // MARK: - Đồng hồ

    /// Đối chiếu đồng hồ và trả các sự kiện mới (cảnh báo 5/1 phút, hết giờ) theo thứ tự.
    /// Không bao giờ ném; Practice và lúc đồng hồ dừng trả mảng rỗng (trừ sự kiện đang chờ).
    ///
    /// Tick thưa nhảy qua nhiều mốc vẫn phát đủ, theo thứ tự 5 rồi 1. Nếu lúc đối chiếu đã
    /// hết giờ thì chỉ phát `timeUp`, bỏ các cảnh báo chưa kịp phát.
    public mutating func tick() -> [SessionEvent] {
        syncClock(at: clock.uptime())
        let events = pendingEvents
        pendingEvents = []
        return events
    }

    // MARK: - Nội bộ

    /// Thời hạn tính bằng giây; nil ở Practice.
    private var timeLimit: TimeInterval? {
        timeLimitMinutes.map { TimeInterval($0) * 60 }
    }

    /// Thời gian đã chạy tại mốc đơn điệu `t`, Exam không vượt thời hạn.
    private func elapsed(at t: TimeInterval) -> TimeInterval {
        let raw = rawElapsed(at: t)
        guard let limit = timeLimit else { return raw }
        return min(raw, limit)
    }

    /// `max(0, …)`: phòng đồng hồ tiêm vào không đơn điệu; khoảng đang chạy không bao giờ âm.
    private func rawElapsed(at t: TimeInterval) -> TimeInterval {
        guard let since = runningSince else { return accumulated }
        return accumulated + max(0, t - since)
    }

    private static func clockRuns(in phase: SessionPhase) -> Bool {
        phase == .inProgress || phase == .reviewing(locked: false)
    }

    /// Đổi phase và chạy/dừng đồng hồ cho khớp.
    private mutating func setPhase(_ newPhase: SessionPhase, at t: TimeInterval) {
        let shouldRun = Self.clockRuns(in: newPhase)
        if shouldRun, runningSince == nil {
            runningSince = t
        } else if !shouldRun, runningSince != nil {
            accumulated = elapsed(at: t)
            runningSince = nil
        }
        phase = newPhase
    }

    /// Exam, đồng hồ đang chạy: phát cảnh báo chưa phát và chuyển sang `timeUp` nếu hết giờ.
    /// Cảnh báo mốc `m` chỉ có khi thời hạn lớn hơn `m` phút (đề 5 phút không có cảnh báo 5 phút).
    /// - Returns: true nếu chính lần đối chiếu này chuyển phiên sang `timeUp`.
    @discardableResult
    private mutating func syncClock(at t: TimeInterval) -> Bool {
        guard let limit = timeLimit, runningSince != nil else { return false }
        let used = rawElapsed(at: t)
        if used >= limit {
            accumulated = limit
            runningSince = nil
            phase = .timeUp
            pendingEvents.append(.timeUp)
            return true
        }
        let left = limit - used
        for minutes in Self.warningMinutes where !issuedWarnings.contains(minutes) {
            let threshold = TimeInterval(minutes) * 60
            if limit > threshold, left <= threshold {
                issuedWarnings.insert(minutes)
                pendingEvents.append(.warning(minutesLeft: minutes))
            }
        }
        return false
    }

    private func require(_ command: SessionCommand, _ allowed: Bool) throws {
        guard allowed else { throw SessionError.invalidCommand(command, phase: phase) }
    }
}

// So sánh mọi trạng thái của phiên, trừ đồng hồ tiêm vào (không so sánh được).
// CẢNH BÁO: thêm thuộc tính lưu trữ mới thì PHẢI thêm vào đây. Thiếu một thuộc tính thì
// test "lệnh bị từ chối giữ nguyên phiên" (so sánh bằng ==) xanh giả. Test
// `equatableCoversAllStoredProperties` liệt kê tên thuộc tính lưu trữ (Mirror) để nhắc.
extension ExamSession: Equatable {
    public static func == (lhs: ExamSession, rhs: ExamSession) -> Bool {
        lhs.exam == rhs.exam
            && lhs.paper == rhs.paper
            && lhs.mode == rhs.mode
            && lhs.timeLimitMinutes == rhs.timeLimitMinutes
            && lhs.candidateName == rhs.candidateName
            && lhs.startedAt == rhs.startedAt
            && lhs.phase == rhs.phase
            && lhs.currentIndex == rhs.currentIndex
            && lhs.answers == rhs.answers
            && lhs.flagged == rhs.flagged
            && lhs.checkedQuestionIDs == rhs.checkedQuestionIDs
            && lhs.pauseReason == rhs.pauseReason
            && lhs.result == rhs.result
            && lhs.submittedAt == rhs.submittedAt
            && lhs.questionsByID == rhs.questionsByID
            && lhs.accumulated == rhs.accumulated
            && lhs.runningSince == rhs.runningSince
            && lhs.phaseBeforePause == rhs.phaseBeforePause
            && lhs.issuedWarnings == rhs.issuedWarnings
            && lhs.pendingEvents == rhs.pendingEvents
    }
}
