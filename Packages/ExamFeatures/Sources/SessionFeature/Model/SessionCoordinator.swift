import ExamFile
import ExamKit
import Foundation
import LibraryData
import Observation
import ReportFeature
import SessionModel

/// Màn đang hiện trong cửa sổ làm bài.
public enum SessionScreen: Hashable, Sendable {
    /// Làm bài, tạm dừng, Rà soát & nộp.
    case attempt
    case results
    case answerReview
}

/// Hộp thoại hoặc sheet do giao diện mở trên cửa sổ làm bài (ngoài hộp xác nhận nộp của `AttemptModel`).
public enum SessionModal: Hashable, Sendable {
    /// Ảnh của câu phóng to.
    case imageZoom
    /// "Bài chưa nộp sẽ mất. Bỏ bài?" khi đóng cửa sổ hoặc thoát app.
    case closeConfirmation
}

/// Một cửa sổ làm bài: làm bài → Kết quả → Xem lại bài trong cùng cửa sổ (docs/product/exam-taking.md).
/// Mở từ Lịch sử thi thì bắt đầu ở Kết quả, không có phần làm bài.
@Observable
@MainActor
public final class SessionWindowModel: Identifiable {
    public let id = UUID()
    /// Bài đang làm hoặc vừa nộp; nil khi mở từ Lịch sử thi.
    public let attempt: AttemptModel?
    public private(set) var results: ResultsModel?
    public private(set) var answerReview: AnswerReviewModel?
    public private(set) var screen: SessionScreen
    /// Đang đọc file đề để Xem lại bài (lần cũ).
    public private(set) var isLoadingReview = false
    /// Sheet/hộp thoại giao diện đang mở trên cửa sổ.
    public private(set) var presentedModals: Set<SessionModal> = []
    /// Lần **Xuất PDF…** / **In…** đang chạy (hộp chọn, hộp lưu, tiến độ, hộp In, hộp báo lỗi).
    public private(set) var reportFlow: ResultsReportFlow?

    @ObservationIgnored private let environment: SessionEnvironment
    /// Hộp của macOS cho Xuất PDF/In (`SessionCoordinator.reportServices`); nil thì không xuất được.
    @ObservationIgnored var reportServices: ReportServices?
    /// Phần xem lại dùng lần trước của Xuất PDF/In (`SessionCoordinator.reportPreferences`); nil thì không xuất được.
    @ObservationIgnored var reportPreferences: (any ReportPreferences)?

    init(attempt: AttemptModel, environment: SessionEnvironment) {
        self.attempt = attempt
        self.environment = environment
        screen = .attempt
    }

    init(results: ResultsModel, environment: SessionEnvironment) {
        attempt = nil
        self.results = results
        self.environment = environment
        screen = .results
    }

    /// Tiêu đề cửa sổ: tên đề, chế độ.
    public var title: String {
        if let attempt { return attempt.windowTitle }
        guard let results else { return "" }
        return "\(results.attempt.examTitle) — \(SessionFormat.mode(results.attempt.mode))"
    }

    /// Đang có sheet hoặc hộp thoại trên cửa sổ (ảnh phóng to, hỏi Bỏ bài, xác nhận nộp, Xuất PDF/In): phím và lệnh
    /// của menu **Bài thi** không tác dụng lên bài phía sau.
    public var hasModal: Bool {
        !presentedModals.isEmpty || attempt?.isConfirmingSubmit == true || reportFlow != nil
    }

    /// Mở thêm sheet trên cửa sổ được không (ảnh phóng to): không khi đã có sheet/hộp thoại, kể cả khi một lần Xuất PDF/In
    /// đang chạy mà sheet tiến độ chưa hiện (0,3 s đầu), để sheet tiến độ luôn trình bày được.
    public var canPresentSheet: Bool { !hasModal }

    public func setModal(_ modal: SessionModal, presented: Bool) {
        if presented { presentedModals.insert(modal) } else { presentedModals.remove(modal) }
    }

    /// Có bài chưa nộp (đóng cửa sổ hay thoát app phải hỏi).
    public var hasUnsubmittedWork: Bool {
        guard let attempt else { return false }
        return !attempt.isSubmitted
    }

    // MARK: - Nộp

    /// **Nộp bài** trên Rà soát: còn câu chưa làm thì hỏi (`attempt.isConfirmingSubmit`), không thì nộp
    /// và chuyển sang Kết quả.
    public func requestSubmit() {
        guard let attempt else { return }
        if let submission = attempt.requestSubmit() { showResults(of: submission, attempt: attempt) }
    }

    /// **Nộp bài** trên hộp xác nhận.
    public func confirmSubmit() {
        guard let attempt else { return }
        if let submission = attempt.submit() { showResults(of: submission, attempt: attempt) }
    }

    private func showResults(of submission: SessionSubmission, attempt: AttemptModel) {
        results = ResultsModel(
            submission: submission,
            content: ExamPackage(exam: attempt.session.exam, media: attempt.media),
            environment: environment
        )
        screen = .results
    }

    // MARK: - Kết quả, Xem lại bài

    /// **Xem lại bài** (bộ lọc Tất cả) hoặc **Xem câu sai** (bộ lọc Sai). Trả `false` nếu không mở được
    /// (lý do ở `results.reviewUnavailableReason` / `results.reviewFailure`).
    @discardableResult
    public func openAnswerReview(filter: AnswerReviewFilter = .all) async -> Bool {
        guard let results, !isLoadingReview else { return false }
        isLoadingReview = true
        defer { isLoadingReview = false }
        guard let review = await results.makeAnswerReview(filter: filter) else { return false }
        answerReview = review
        screen = .answerReview
        return true
    }

    /// Từ Xem lại bài về Kết quả.
    public func showResults() {
        guard results != nil else { return }
        screen = .results
    }

    // MARK: - Xuất PDF, In

    /// **Xuất PDF…** / **In…** bật: cửa sổ ở Kết quả hoặc Xem lại bài, không có sheet/hộp thoại (kể cả một lần xuất
    /// đang chạy). Tắt khi đang làm bài hay Rà soát (docs/product/export-print.md, mục Mở từ đâu).
    public var canRequestReport: Bool {
        guard results != nil, screen == .results || screen == .answerReview else { return false }
        return !hasModal
    }

    /// Mở hộp chọn của **Xuất PDF…** / **In…**. Trả `false` khi không được (`canRequestReport`).
    @discardableResult
    public func requestReport(_ action: ReportAction) -> Bool {
        guard canRequestReport, let results, let reportServices, let reportPreferences else { return false }
        let flow = ResultsReportFlow(
            action: action,
            results: results,
            openedReview: answerReview,
            preferences: reportPreferences,
            services: reportServices
        )
        flow.onFinish = { [weak self, weak flow] in
            guard let self, let flow, self.reportFlow === flow else { return }
            self.reportFlow = nil
        }
        reportFlow = flow
        return true
    }

    /// Huỷ lần xuất đang chạy (cửa sổ đóng, đổi phiên, thoát app): không để lại file.
    public func cancelReport() {
        reportFlow?.cancelAll()
    }
}

/// Hộp thoại hỏi trước khi đóng cửa sổ làm bài hoặc thoát app khi chưa nộp.
public struct SessionCloseConfirmation: Hashable, Sendable {
    /// "Bài chưa nộp sẽ mất. Bỏ bài?"
    public let message: String
    /// **Tiếp tục làm** (mặc định).
    public let continueTitle: String
    /// **Bỏ bài** (không lưu gì).
    public let discardTitle: String
}

/// Chính sách khi đóng cửa sổ làm bài hoặc thoát app (shell thực hiện qua AppKit).
public enum SessionCloseDecision: Hashable, Sendable {
    /// Không có bài chưa nộp: đóng/thoát luôn, không hỏi.
    case closeImmediately
    /// Hỏi; **Tiếp tục làm** là mặc định. Ở Thi đồng hồ vẫn chạy trong lúc hỏi.
    case confirm(SessionCloseConfirmation)
}

/// Điều phối phiên thi của cả app (một đối tượng, giữ ở app delegate): **mỗi lúc một phiên**, màn Trước khi
/// thi trên cửa sổ Thư viện, cửa sổ làm bài, Làm lại / Luyện lại câu sai, mở lần thi từ Lịch sử thi,
/// chính sách hỏi khi đóng cửa sổ hoặc thoát app.
@Observable
@MainActor
public final class SessionCoordinator {
    /// Tính mỗi lần đọc (không `static let`): theo ngôn ngữ đang tra.
    static var unsubmittedMessage: String { localized("Đang có bài chưa nộp") }

    /// Cửa sổ làm bài hiện tại (một cửa sổ); nil khi không có.
    public private(set) var window: SessionWindowModel?
    /// Sheet Trước khi thi trên cửa sổ Thư viện.
    public private(set) var preExam: PreExamModel?
    /// Thông báo không chặn cho Thư viện ("Đang có bài chưa nộp", lỗi mở đề).
    public private(set) var notice: SessionNotice?
    /// Đang đọc file đề để mở Trước khi thi.
    public private(set) var isOpeningPreExam = false

    /// Mở cửa sổ làm bài hoặc đưa nó lên trước (shell gán bằng `openWindow`).
    @ObservationIgnored public var presentSessionWindow: (@MainActor () -> Void)?
    /// Đưa cửa sổ Thư viện lên trước.
    @ObservationIgnored public var presentLibrary: (@MainActor () -> Void)?
    /// Hộp của macOS cho **Xuất PDF…** / **In…** (app: `ReportServices.live(window:)` trên cửa sổ làm bài, do
    /// `SessionAppController` gán); nil thì hai lệnh không làm gì.
    @ObservationIgnored public var reportServices: ReportServices? {
        didSet { window?.reportServices = reportServices }
    }
    /// Phần xem lại dùng lần trước của **Xuất PDF…** / **In…** (app: `UserDefaultsSessionPreferences`, do
    /// `SessionAppController` gán); nil thì hai lệnh không làm gì.
    @ObservationIgnored public var reportPreferences: (any ReportPreferences)? {
        didSet { window?.reportPreferences = reportPreferences }
    }

    @ObservationIgnored public let environment: SessionEnvironment

    public init(environment: SessionEnvironment) {
        self.environment = environment
    }

    /// Có bài chưa nộp.
    public var hasUnsubmittedSession: Bool { window?.hasUnsubmittedWork ?? false }

    // MARK: - Trước khi thi

    /// Mở Trước khi thi cho đề (Luyện tập, Thi, nhấp đúp, Return trên thẻ; Làm lại; Luyện lại câu sai).
    /// Đang có bài chưa nộp thì đưa cửa sổ làm bài lên và báo "Đang có bài chưa nộp".
    /// - Parameter mode: nút **Luyện tập** / **Thi** chọn sẵn chế độ; nil (nhấp đúp, Return) dùng chế độ lần trước.
    @discardableResult
    public func openPreExam(
        examID: UUID,
        mode: SessionMode? = nil,
        preset: PreExamPreset = .fresh
    ) async -> SessionOpenOutcome {
        if let blocked = blockIfUnsubmitted() { return blocked }
        guard !isOpeningPreExam else {
            // Lần mở trước chưa xong (đang đọc file): báo, không mở chồng.
            let message = localized("Đang mở một đề, hãy chờ trong giây lát.")
            notice = SessionNotice(message: message)
            return .failed(message)
        }
        isOpeningPreExam = true
        defer { isOpeningPreExam = false }
        switch await environment.library.readExam(examID) {
        case let .success(package):
            // Kiểm lại sau khi chờ đọc file: một phiên có thể đã bắt đầu trong lúc đó.
            if let blocked = blockIfUnsubmitted() { return blocked }
            preExam = PreExamModel(package: package, preset: preset, mode: mode, environment: environment)
            presentLibrary?()
            return .opened
        case let .failure(failure):
            environment.library.examFileNeedsRefresh(examID)
            let message = localized("Không mở được đề: \(failure.message)")
            notice = SessionNotice(message: message)
            return .failed(message)
        }
    }

    /// **Huỷ** (Esc) trên Trước khi thi.
    public func cancelPreExam() {
        preExam = nil
    }

    /// **Bắt đầu**: tạo phiên, đóng sheet, mở cửa sổ làm bài (thay cửa sổ đã nộp nếu có). Lỗi thì sheet
    /// còn đó với lý do ở `preExam.startFailure`.
    @discardableResult
    public func startPreExam() async -> Bool {
        guard let preExam else { return false }
        if blockIfUnsubmitted() != nil { return false }
        // Bấm Bắt đầu lần hai trong lúc đang đọc file: `start()` trả nil (`isStarting`).
        guard let attempt = await preExam.start() else { return false }
        // Trong lúc đọc file, người dùng có thể đã Huỷ hoặc mở sheet khác: bỏ phiên vừa tạo
        // (chưa làm gì, không lưu gì).
        guard self.preExam === preExam else { return false }
        if blockIfUnsubmitted() != nil { return false }
        // Chỉ nhớ tên thí sinh và chế độ khi phiên chắc chắn được dùng (review #23, ghi chú a).
        preExam.rememberStartedChoices()
        replaceWindow(with: SessionWindowModel(attempt: attempt, environment: environment))
        self.preExam = nil
        presentSessionWindow?()
        return true
    }

    // MARK: - Từ Kết quả và Xem lại bài

    /// **Làm lại** trên Kết quả: Trước khi thi trên cửa sổ Thư viện với đúng lựa chọn của lần đó.
    @discardableResult
    public func retake() async -> SessionOpenOutcome {
        guard let results = window?.results, let preset = results.retakePreset else {
            return .failed(localized("Không làm lại được lần thi này."))
        }
        return await openPreExam(examID: results.attempt.examID, preset: preset)
    }

    /// **Luyện lại câu sai** trên Xem lại bài.
    @discardableResult
    public func practiceIncorrect() async -> SessionOpenOutcome {
        guard let window, let examID = window.results?.attempt.examID,
              let preset = window.answerReview?.practiceIncorrectPreset
        else {
            return .failed(localized("Không còn câu sai để luyện lại."))
        }
        return await openPreExam(examID: examID, preset: preset)
    }

    /// **Về thư viện**: đóng cửa sổ làm bài, đưa Thư viện lên trước. Chỉ khi không còn bài chưa nộp.
    public func returnToLibrary() {
        guard !hasUnsubmittedSession else { return }
        replaceWindow(with: nil)
        presentLibrary?()
    }

    // MARK: - Lịch sử thi

    /// Mở **Kết quả** của một lần thi trong Lịch sử thi (nhấp đúp hoặc Return), trong cửa sổ làm bài.
    @discardableResult
    public func openHistoryAttempt(_ attempt: Attempt) -> SessionOpenOutcome {
        if let blocked = blockIfUnsubmitted() { return blocked }
        replaceWindow(with: SessionWindowModel(results: .history(attempt, environment: environment), environment: environment))
        presentSessionWindow?()
        return .opened
    }

    // MARK: - Đóng cửa sổ, thoát app, máy ngủ

    /// Hỏi gì khi người dùng đóng cửa sổ làm bài hoặc thoát app (⌘Q, Dock).
    public var closeDecision: SessionCloseDecision {
        guard hasUnsubmittedSession else { return .closeImmediately }
        return .confirm(SessionCloseConfirmation(
            message: localized("Bài chưa nộp sẽ mất. Bỏ bài?"),
            continueTitle: localized("Tiếp tục làm"),
            discardTitle: localized("Bỏ bài")
        ))
    }

    /// **Bỏ bài**: bỏ phiên chưa nộp, không lưu gì (không có trong Lịch sử thi).
    public func discardSession() {
        replaceWindow(with: nil)
    }

    /// Cửa sổ làm bài đã đóng (sau khi chính sách cho phép).
    public func sessionWindowDidClose() {
        replaceWindow(with: nil)
    }

    /// Máy sắp ngủ: tạm dừng bài đang làm (`systemSleep`).
    public func systemWillSleep() {
        window?.attempt?.autoPause(reason: .systemSleep)
    }

    public func dismissNotice() {
        notice = nil
    }

    // MARK: - Nội bộ

    /// Đổi cửa sổ làm bài (mỗi lúc một cửa sổ): lần Xuất PDF/In của cửa sổ cũ bị huỷ (không để lại file).
    private func replaceWindow(with newWindow: SessionWindowModel?) {
        if let old = window, old !== newWindow { old.cancelReport() }
        newWindow?.reportServices = reportServices
        newWindow?.reportPreferences = reportPreferences
        window = newWindow
    }

    /// Đang có bài chưa nộp: đưa cửa sổ làm bài lên, báo "Đang có bài chưa nộp".
    private func blockIfUnsubmitted() -> SessionOpenOutcome? {
        guard hasUnsubmittedSession else { return nil }
        notice = SessionNotice(message: Self.unsubmittedMessage)
        presentSessionWindow?()
        return .blockedByUnsubmittedSession
    }
}
