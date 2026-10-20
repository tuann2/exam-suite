import ExamFile
import ExamKit
import Foundation
import LibraryData
import LibraryFeature
import Observation

/// Cửa sổ làm bài khi chưa nộp: câu hỏi, bảng câu hỏi, đồng hồ, tạm dừng, Kiểm tra đáp án, Rà soát & nộp
/// (docs/product/exam-taking.md; quy tắc phiên ở exam-session.md).
///
/// Bọc `ExamSession` (state machine của ExamKit). Không tự tạo Timer: giao diện gọi `tick()` định kỳ
/// (ví dụ mỗi nửa giây) để vẽ lại đồng hồ và nhận cảnh báo; thời gian hiển thị luôn lấy từ phiên (mốc
/// `uptime` của `SessionClock` tiêm vào), tick chỉ để vẽ lại.
///
/// Sau mọi lệnh (kể cả lệnh bị từ chối) và mọi tick, model lấy sự kiện đồng hồ của phiên: cảnh báo → dải
/// thông báo + VoiceOver; hết giờ → chuyển **ngay** sang Rà soát khoá (gọi `openReview()`), kể cả khi hết
/// giờ được phát hiện trong một lệnh bị từ chối với phase `.timeUp`.
@Observable
@MainActor
public final class AttemptModel {
    public private(set) var session: ExamSession
    /// Ảnh của đề (đường dẫn trong gói → dữ liệu).
    public let media: [String: Data]
    public private(set) var clockDisplay: ClockDisplay
    /// Dải thông báo đang hiện (cảnh báo giờ, hết giờ).
    public private(set) var banner: SessionBanner?
    /// Câu VoiceOver chờ đọc, theo thứ tự.
    public private(set) var announcements: [SessionAnnouncement] = []
    /// Bảng câu hỏi đang hiện (⌃⌘I).
    public var isNavigatorVisible = true
    /// Đang hỏi "Còn N câu chưa làm. Vẫn nộp?".
    public private(set) var isConfirmingSubmit = false
    /// Có sau khi nộp.
    public private(set) var submission: SessionSubmission?

    @ObservationIgnored private let environment: SessionEnvironment
    @ObservationIgnored private var nextNoticeID = 0

    init(session: ExamSession, media: [String: Data], environment: SessionEnvironment) {
        self.session = session
        self.media = media
        self.environment = environment
        clockDisplay = Self.clockDisplay(for: session)
    }

    // MARK: - Thông tin chung

    public var exam: Exam { session.exam }
    public var mode: SessionMode { session.mode }
    public var phase: SessionPhase { session.phase }
    public var isSubmitted: Bool { session.phase == .submitted }

    /// Tiêu đề cửa sổ: tên đề, chế độ.
    public var windowTitle: String {
        "\(exam.title) — \(SessionFormat.mode(mode))"
    }

    // MARK: - Câu hiện tại

    public var currentIndex: Int { session.currentIndex }
    public var questionCount: Int { session.questionCount }
    public var currentQuestion: Question { session.currentQuestion }

    /// "Câu 3/60".
    public var questionPositionText: String {
        localized("Câu \(currentIndex + 1)/\(questionCount)")
    }

    /// Tên phần của câu hiện tại.
    public var currentSectionTitle: String {
        sectionTitle(session.currentItem.sectionID)
    }

    public var isCurrentFlagged: Bool { session.flagged.contains(session.currentItem.questionID) }

    /// Đáp án câu hiện tại đã khoá sau Kiểm tra đáp án.
    public var isCurrentLocked: Bool { session.checkedQuestionIDs.contains(session.currentItem.questionID) }

    /// "Chọn N đáp án" cho câu `multiple` (N = số đáp án đúng); nil với `single`.
    public var selectionHint: String? {
        let question = currentQuestion
        guard question.type == .multiple else { return nil }
        return localized("Chọn \(question.correctSet.count) đáp án")
    }

    /// Ảnh của câu hiện tại, nếu có.
    public var currentImage: Data? {
        currentQuestion.image.flatMap { media[$0] }
    }

    /// Lựa chọn của câu hiện tại theo thứ tự hiển thị (đã xáo nếu bật), nhãn theo vị trí.
    public var displayedOptions: [DisplayedOption] {
        let question = currentQuestion
        let selected = session.answers[question.id] ?? []
        let checked = isCurrentLocked
        let texts = Dictionary(question.options.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
        return session.currentItem.optionOrder.enumerated().map { position, optionID in
            var mark: OptionCheckMark?
            if checked {
                if question.correctSet.contains(optionID) {
                    mark = .correct
                } else if selected.contains(optionID) {
                    mark = .incorrect
                }
            }
            return DisplayedOption(
                position: position,
                label: SessionFormat.optionLabel(position: position),
                optionID: optionID,
                text: texts[optionID] ?? "",
                isSelected: selected.contains(optionID),
                checkMark: mark
            )
        }
    }

    /// Kết quả Kiểm tra đáp án của câu hiện tại; nil nếu chưa kiểm tra.
    public var currentCheck: AnswerCheckPresentation? {
        guard isCurrentLocked else { return nil }
        let question = currentQuestion
        let correct = Scorer.outcome(of: question, selected: session.answers[question.id]) == .correct
        return AnswerCheckPresentation(
            isCorrect: correct,
            resultText: Self.checkResultText(correct),
            explanation: question.explanation
        )
    }

    // MARK: - Tạm dừng

    /// Nội dung câu và lựa chọn được hiện (tạm dừng thì che toàn bộ; bảng câu hỏi chỉ hiện số ô).
    public var isContentVisible: Bool { session.phase != .paused }

    /// Chữ trên lớp phủ tạm dừng; nil khi không tạm dừng.
    public var pauseMessage: String? {
        guard session.phase == .paused else { return nil }
        return session.pauseReason == .systemSleep
            ? localized("Đã tạm dừng vì máy ngủ")
            : localized("Đã tạm dừng")
    }

    // MARK: - Bảng câu hỏi, tiến độ

    public var answeredCount: Int { questionCount - session.unansweredCount }

    /// "Đã làm 12/60" (chỉ đếm câu có đáp án).
    public var progressText: String {
        localized("Đã làm \(answeredCount)/\(questionCount)")
    }

    /// Ô của bảng câu hỏi nhóm theo phần (thứ tự phần trong đề), số thứ tự theo phiên. Tạm dừng thì ô chỉ
    /// có số, không có trạng thái.
    public var navigatorSections: [NavigatorSection] {
        let hidden = !isContentVisible
        var cellsBySection: [UUID: [NavigatorCell]] = [:]
        for (index, item) in session.paper.items.enumerated() {
            cellsBySection[item.sectionID, default: []].append(
                NavigatorCell(
                    index: index,
                    number: index + 1,
                    isAnswered: !hidden && session.isAnswered(item.questionID),
                    isFlagged: !hidden && session.flagged.contains(item.questionID),
                    isCurrent: !hidden && index == session.currentIndex,
                    isStateHidden: hidden
                )
            )
        }
        return exam.sections.compactMap { section in
            guard let cells = cellsBySection[section.id] else { return nil }
            return NavigatorSection(id: section.id, title: section.title, cells: cells)
        }
    }

    // MARK: - Rà soát

    /// Bảng Rà soát & nộp; nil khi không ở rà soát.
    public var reviewSummary: ReviewSummary? {
        guard case let .reviewing(locked) = session.phase else { return nil }
        var unanswered: [Int] = []
        var flagged: [Int] = []
        for (index, item) in session.paper.items.enumerated() {
            if !session.isAnswered(item.questionID) { unanswered.append(index) }
            if session.flagged.contains(item.questionID) { flagged.append(index) }
        }
        return ReviewSummary(
            answeredCount: questionCount - unanswered.count,
            unansweredCount: unanswered.count,
            flaggedCount: session.flaggedCount,
            unansweredIndices: unanswered,
            flaggedIndices: flagged,
            isLocked: locked
        )
    }

    // MARK: - Lệnh menu

    /// Lệnh có hợp lệ ở trạng thái hiện tại không (menu **Bài thi** tắt lệnh không hợp lệ).
    public func isEnabled(_ command: AttemptCommand) -> Bool {
        let phase = session.phase
        let inProgress = phase == .inProgress
        switch command {
        case .previousQuestion:
            return inProgress && currentIndex > 0
        case .nextQuestion, .advance:
            return inProgress && currentIndex < questionCount - 1
        case .toggleFlag:
            return inProgress
        case .togglePause:
            return inProgress || phase == .reviewing(locked: false) || phase == .paused
        case .checkAnswer:
            let id = session.currentItem.questionID
            return mode == .practice && inProgress && session.isAnswered(id) && !isCurrentLocked
        case .openReview:
            return inProgress
        case .returnToAttempt:
            return phase == .reviewing(locked: false)
        case .submit:
            if case .reviewing = phase { return true }
            return false
        case .toggleNavigator:
            return !isSubmitted
        }
    }

    /// Chạy lệnh menu; lệnh đang tắt thì bỏ qua. Nộp bài đi qua `requestSubmit()`.
    public func perform(_ command: AttemptCommand) {
        guard isEnabled(command) else { return }
        switch command {
        case .previousQuestion: previousQuestion()
        case .nextQuestion, .advance: nextQuestion()
        case .toggleFlag: toggleFlag()
        case .togglePause: togglePause()
        case .checkAnswer: checkAnswer()
        case .openReview: openReview()
        case .returnToAttempt: returnToAttempt()
        case .submit: requestSubmit()
        case .toggleNavigator: isNavigatorVisible.toggle()
        }
    }

    /// Tiêu đề lệnh tạm dừng theo trạng thái: "Tạm dừng" / "Tiếp tục".
    public var pauseCommandTitle: String {
        session.phase == .paused ? localized("Tiếp tục") : localized("Tạm dừng")
    }

    // MARK: - Lệnh: trả lời

    /// Chọn/bỏ chọn lựa chọn ở vị trí hiển thị `position` (0-based). Ngoài số lựa chọn thì bỏ qua.
    @discardableResult
    public func selectOption(atPosition position: Int) -> Bool {
        let order = session.currentItem.optionOrder
        guard order.indices.contains(position) else { return false }
        return run { try $0.select(option: order[position]) }
    }

    /// Phím chữ A–Z (không phân biệt hoa thường): chọn theo **vị trí hiển thị**. Chữ vượt số lựa chọn
    /// hoặc không phải đúng một ký tự ASCII A–Z/a–z (chữ có dấu, ß, ﬁ, emoji, chuỗi rỗng hay nhiều ký tự)
    /// thì bỏ qua (`false`).
    @discardableResult
    public func handleLetterKey(_ key: String) -> Bool {
        guard let position = Self.letterPosition(key) else { return false }
        return selectOption(atPosition: position)
    }

    @discardableResult
    public func handleLetterKey(_ key: Character) -> Bool {
        handleLetterKey(String(key))
    }

    /// Vị trí 0-based của phím chữ ASCII A–Z/a–z; nil với mọi phím khác. Không dùng `uppercased()` vì
    /// một số ký tự viết hoa thành nhiều ký tự ("ß" → "SS").
    static func letterPosition(_ key: String) -> Int? {
        let scalars = key.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first, scalar.isASCII else { return nil }
        switch scalar.value {
        case 0x41 ... 0x5A: return Int(scalar.value - 0x41)
        case 0x61 ... 0x7A: return Int(scalar.value - 0x61)
        default: return nil
        }
    }

    /// Chọn theo id lựa chọn gốc (bấm vào hàng lựa chọn).
    @discardableResult
    public func selectOption(_ optionID: OptionID) -> Bool {
        run { try $0.select(option: optionID) }
    }

    @discardableResult
    public func clearAnswer() -> Bool {
        run { try $0.clearAnswer() }
    }

    // MARK: - Lệnh: điều hướng, đánh dấu

    @discardableResult
    public func nextQuestion() -> Bool { run { try $0.next() } }

    @discardableResult
    public func previousQuestion() -> Bool { run { try $0.previous() } }

    /// Tới câu ở vị trí `index` (bấm ô bảng câu hỏi).
    @discardableResult
    public func goTo(index: Int) -> Bool { run { try $0.goTo(index: index) } }

    @discardableResult
    public func toggleFlag() -> Bool { run { try $0.toggleFlag() } }

    /// **Kiểm tra đáp án** (chỉ Luyện tập): khoá đáp án câu này, VoiceOver đọc kết quả.
    @discardableResult
    public func checkAnswer() -> Bool {
        var check: AnswerCheck?
        let ok = run { check = try $0.checkAnswer() }
        if let check {
            announce(Self.checkResultText(check.outcome == .correct), priority: .normal)
        }
        return ok
    }

    // MARK: - Lệnh: tạm dừng

    /// ⌘. : tạm dừng hoặc tiếp tục.
    @discardableResult
    public func togglePause() -> Bool {
        session.phase == .paused ? run { try $0.resume() } : run { try $0.pause(reason: .user) }
    }

    @discardableResult
    public func pause() -> Bool { run { try $0.pause(reason: .user) } }

    @discardableResult
    public func resume() -> Bool { run { try $0.resume() } }

    /// Máy sắp ngủ: tự tạm dừng (`systemSleep`). Không ở trạng thái tạm dừng được thì bỏ qua. Thức dậy
    /// vẫn ở tạm dừng tới khi người dùng tiếp tục.
    public func systemWillSleep() {
        guard session.phase == .inProgress || session.phase == .reviewing(locked: false) else {
            processClock()
            return
        }
        run { try $0.pause(reason: .systemSleep) }
    }

    // MARK: - Lệnh: rà soát và nộp

    /// ⌘Return: mở Rà soát & nộp.
    @discardableResult
    public func openReview() -> Bool { run { try $0.openReview() } }

    /// Từ Rà soát chưa khoá quay lại làm bài, tuỳ chọn tới thẳng câu `index`.
    @discardableResult
    public func returnToAttempt(at index: Int? = nil) -> Bool {
        run { try $0.returnToAttempt(at: index) }
    }

    /// **Nộp bài** trên Rà soát: còn câu chưa làm thì hỏi xác nhận (`isConfirmingSubmit`), không thì nộp
    /// luôn. Trả về kết quả nộp nếu đã nộp.
    @discardableResult
    public func requestSubmit() -> SessionSubmission? {
        processClock()
        guard case .reviewing = session.phase else { return nil }
        if session.unansweredCount > 0 {
            isConfirmingSubmit = true
            return nil
        }
        return submit()
    }

    /// **Quay lại** trên hộp xác nhận nộp.
    public func cancelSubmit() {
        isConfirmingSubmit = false
    }

    /// Nộp bài (đã xác nhận): chấm, tạo lần thi + bản ghi chi tiết (dấu vân tay từ đề lúc thi), lưu vào
    /// Lịch sử thi. Lưu lỗi thì `submission.saveError` có lý do; Kết quả vẫn hiện.
    @discardableResult
    public func submit() -> SessionSubmission? {
        isConfirmingSubmit = false
        if let submission { return submission }
        guard run({ try $0.submit() }), let result = session.result, let submittedAt = session.submittedAt else {
            return nil
        }
        let attempt = Attempt(
            id: environment.makeAttemptID(),
            examID: exam.id,
            examTitle: exam.title,
            candidateName: session.candidateName,
            mode: mode,
            startedAt: session.startedAt,
            submittedAt: submittedAt,
            elapsedSeconds: session.elapsed,
            correct: result.correct,
            total: result.total,
            score1000: result.score1000,
            percent: result.percent,
            passed: result.passed
        )
        var record: AttemptRecord?
        var saveError: String?
        do {
            let made = try AttemptRecord(session: session, fingerprints: QuestionFingerprint.fingerprints(of: session.exam))
            record = made
            try environment.library.saveAttempt(attempt, payload: try made.encoded())
        } catch {
            saveError = Self.saveErrorMessage(error)
        }
        let submission = SessionSubmission(attempt: attempt, record: record, saveError: saveError)
        self.submission = submission
        banner = nil
        let verdict = SessionFormat.result(passed: result.passed)
        announce(
            localized("Đã nộp bài. \(verdict), \(SessionFormat.percent(result.percent))."),
            priority: .normal
        )
        if let saveError { announce(saveError, priority: .normal) }
        return submission
    }

    // MARK: - Đồng hồ

    /// Gọi định kỳ từ giao diện: vẽ lại đồng hồ, nhận cảnh báo và hết giờ.
    public func tick() {
        processClock()
    }

    /// Ẩn dải thông báo `id` (giao diện gọi sau vài giây với dải `autoDismisses`).
    public func dismissBanner(id: Int) {
        if banner?.id == id { banner = nil }
    }

    /// Lấy và xoá các câu VoiceOver đang chờ.
    public func takeAnnouncements() -> [SessionAnnouncement] {
        defer { announcements = [] }
        return announcements
    }

    // MARK: - Nội bộ

    /// Chạy một lệnh của phiên rồi xử lý đồng hồ (kể cả khi lệnh bị từ chối); đổi câu thì VoiceOver đọc.
    @discardableResult
    private func run(_ command: (inout ExamSession) throws -> Void) -> Bool {
        let before = session.currentIndex
        let ok: Bool
        do {
            try command(&session)
            ok = true
        } catch {
            ok = false
        }
        processClock()
        if session.currentIndex != before, session.phase == .inProgress {
            announce(questionChangeAnnouncement, priority: .normal)
        }
        return ok
    }

    /// Lấy sự kiện đồng hồ của phiên và áp; hết giờ thì chuyển ngay sang Rà soát khoá.
    private func processClock() {
        // Tick thường không đổi gì: chỉ ghi lại phiên khi có thay đổi, để giao diện (bảng câu hỏi 2.000 ô)
        // không vẽ lại mỗi lần tick.
        var updated = session
        let events = updated.tick()
        if updated != session { session = updated }
        for event in events {
            switch event {
            case let .warning(minutes):
                let message = localized("Còn \(minutes) phút")
                showBanner(.timeWarning(minutesLeft: minutes), message: message)
                announce(message, priority: .high)
            case .timeUp:
                let message = localized("Đã hết giờ. Xem lại rồi bấm Nộp bài")
                showBanner(.timeUp, message: message)
                announce(message, priority: .high)
            }
        }
        if session.phase == .timeUp {
            // Không có màn Hết giờ riêng (phương án 10): sang Rà soát khoá ngay.
            try? session.openReview()
        }
        let display = Self.clockDisplay(for: session)
        if display != clockDisplay { clockDisplay = display }
    }

    private func showBanner(_ kind: SessionBanner.Kind, message: String) {
        nextNoticeID += 1
        banner = SessionBanner(id: nextNoticeID, kind: kind, message: message)
    }

    private func announce(_ text: String, priority: SessionAnnouncement.Priority) {
        nextNoticeID += 1
        announcements.append(SessionAnnouncement(id: nextNoticeID, text: text, priority: priority))
    }

    /// "Câu 3 trên 60, Phần Mạng". Tên phần đã có dạng "Phần <số>…" (ví dụ "Phần 1") hoặc "Section <số>…" (tên mặc định
    /// của đề tạo khi giao diện tiếng Anh, bước 7c) thì không thêm "Phần" lần nữa; tên như "Phần mềm" vẫn đọc "Phần Phần
    /// mềm".
    var questionChangeAnnouncement: String {
        let title = currentSectionTitle
        let section = Self.hasNumberedSectionPrefix(title) ? title : localized("Phần \(title)")
        return localized("Câu \(currentIndex + 1) trên \(questionCount), \(section)")
    }

    /// Tên phần bắt đầu bằng "Phần " hoặc "Section " (không phân biệt hoa thường) rồi tới chữ số: hai dạng tên mặc định
    /// app ghi vào đề (`DefaultContentNames`, theo ngôn ngữ giao diện lúc tạo), bất kể giao diện đang dùng ngôn ngữ nào.
    static func hasNumberedSectionPrefix(_ title: String) -> Bool {
        let prefixes = ["phần ", "section "] // l10n-ignore: so với tên phần trong nội dung đề
        let normalized = title.precomposedStringWithCanonicalMapping
        let lowered = normalized.lowercased()
        guard let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) else { return false }
        let rest = normalized.dropFirst(prefix.count)
        return rest.first?.isNumber == true
    }

    private func sectionTitle(_ sectionID: UUID) -> String {
        exam.sections.first { $0.id == sectionID }?.title ?? ""
    }

    static func checkResultText(_ correct: Bool) -> String {
        correct ? localized("Đúng") : localized("Chưa đúng")
    }

    static func saveErrorMessage(_ error: any Error) -> String {
        // Lỗi của kho (`LibraryError`) theo mã; lỗi khác có mô tả thì dùng câu của hệ thống (`ErrorMessages`).
        if error is LibraryError || error is any LocalizedError {
            return localized("Không lưu được lần thi vào Lịch sử thi: \(ErrorMessages.message(for: error))")
        }
        if error is AttemptRecordError {
            return localized("Không lưu được lần thi vào Lịch sử thi: không tạo được dữ liệu chi tiết của bài.")
        }
        return localized("Không lưu được lần thi vào Lịch sử thi.")
    }

    /// Đồng hồ theo phiên: Thi đếm ngược thời gian còn lại (làm tròn lên giây để chạm 00:00 đúng lúc hết
    /// giờ); Luyện tập hiện thời gian đã làm.
    static func clockDisplay(for session: ExamSession) -> ClockDisplay {
        if let remaining = session.remaining {
            let seconds = Int(remaining.rounded(.up))
            let level: ClockLevel
            if remaining <= ClockLevel.urgentSeconds {
                level = .urgent
            } else if remaining <= ClockLevel.warningSeconds {
                level = .warning
            } else {
                level = .normal
            }
            return ClockDisplay(
                text: SessionFormat.clock(seconds: seconds),
                level: level,
                isCountdown: true,
                accessibilityLabel: localized("Còn \(SessionFormat.duration(seconds: TimeInterval(seconds)))")
            )
        }
        let seconds = Int(session.elapsed.rounded(.down))
        return ClockDisplay(
            text: SessionFormat.clock(seconds: seconds),
            level: .normal,
            isCountdown: false,
            accessibilityLabel: localized("Đã làm \(SessionFormat.duration(seconds: TimeInterval(seconds)))")
        )
    }
}
