import ExamFile
import ExamKit
import Foundation
import InterfaceCore
import LibraryData
import Observation
import SessionModel

/// Màn của một phiên trên iPhone: làm bài (gồm tạm dừng, Rà soát & nộp) → Kết quả → Xem lại bài.
public enum MobileSessionScreen: Hashable, Sendable {
    case attempt
    case results
    case answerReview
}

/// Một phiên trên iPhone, như cửa sổ làm bài của bản macOS (`SessionWindowModel` của SessionFeature, không có phần
/// Xuất PDF/In của v1.1): làm bài → Kết quả → Xem lại bài trên cùng một màn đẩy vào `NavigationStack`. Mở từ Lịch sử
/// thi thì bắt đầu ở Kết quả, không có phần làm bài.
@Observable
@MainActor
public final class MobileSession: Identifiable {
    public let id = UUID()
    /// Bài đang làm hoặc vừa nộp; nil khi mở từ Lịch sử thi.
    public let attempt: AttemptModel?
    public private(set) var results: ResultsModel?
    public private(set) var answerReview: AnswerReviewModel?
    public private(set) var screen: MobileSessionScreen
    /// Đang đọc file đề để Xem lại bài (lần cũ).
    public private(set) var isLoadingReview = false

    @ObservationIgnored private let environment: SessionEnvironment

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

    /// Tiêu đề màn: tên đề.
    public var title: String {
        attempt?.exam.title ?? results?.attempt.examTitle ?? ""
    }

    /// Có bài chưa nộp: nút Quay lại phải hỏi "Bỏ bài?".
    public var hasUnsubmittedWork: Bool {
        guard let attempt else { return false }
        return !attempt.isSubmitted
    }

    // MARK: - Nộp

    /// **Nộp bài** trên Rà soát: còn câu chưa làm thì hỏi (`attempt.isConfirmingSubmit`), không thì nộp và chuyển
    /// sang Kết quả.
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

    /// **Xem lại bài** (bộ lọc Tất cả) hoặc **Xem câu sai** (bộ lọc Sai). Trả `false` nếu không mở được (lý do ở
    /// `results.reviewUnavailableReason` / `results.reviewFailure`).
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
}

/// Điều phối phiên thi của bản iOS (một đối tượng cho cả app), cùng luật với `SessionCoordinator` của bản macOS
/// (docs/product/exam-taking.md): **mỗi lúc một phiên**, Trước khi thi là sheet trên Thư viện, đọc lại file đề (đọc
/// nghiêm) khi mở và khi bắt đầu, kiểm lại sau mỗi lần chờ, Làm lại / Luyện lại câu sai, mở lần thi từ Lịch sử thi, hỏi
/// "Bỏ bài?" khi rời bài chưa nộp. Khác macOS (mobile.md, mục Bản iOS): phiên là một màn đẩy vào `NavigationStack`
/// thay vì cửa sổ, app xuống nền thì tự tạm dừng (`background`).
@Observable
@MainActor
public final class MobileSessionCoordinator {
    /// Phiên hiện tại (một phiên); nil khi không có.
    public private(set) var session: MobileSession?
    /// Sheet Trước khi thi.
    public private(set) var preExam: PreExamModel?
    /// Thông báo không chặn cho Thư viện ("Đang có bài chưa nộp", lỗi mở đề).
    public private(set) var notice: SessionNotice?
    /// Đang đọc file đề để mở Trước khi thi.
    public private(set) var isOpeningPreExam = false

    @ObservationIgnored public let environment: SessionEnvironment

    public init(environment: SessionEnvironment) {
        self.environment = environment
    }

    /// Màn phiên đang được đẩy vào `NavigationStack`.
    public var isSessionPresented: Bool { session != nil }

    /// Có bài chưa nộp.
    public var hasUnsubmittedSession: Bool { session?.hasUnsubmittedWork ?? false }

    // MARK: - Trước khi thi

    /// Mở Trước khi thi cho đề (chạm vào đề, Luyện tập, Thi; Làm lại; Luyện lại câu sai). Đang có bài chưa nộp thì báo
    /// "Đang có bài chưa nộp".
    /// - Parameter mode: Luyện tập / Thi chọn sẵn chế độ; nil dùng chế độ lần trước.
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
            return .opened
        case let .failure(failure):
            environment.library.examFileNeedsRefresh(examID)
            let message = localized("Không mở được đề: \(failure.message)")
            notice = SessionNotice(message: message)
            return .failed(message)
        }
    }

    /// **Huỷ** trên Trước khi thi (hay vuốt sheet xuống).
    public func cancelPreExam() {
        preExam = nil
    }

    /// **Bắt đầu**: tạo phiên, đóng sheet, mở màn làm bài (thay phiên đã nộp nếu có). Lỗi thì sheet còn đó với lý do ở
    /// `preExam.startFailure`.
    @discardableResult
    public func startPreExam() async -> Bool {
        guard let preExam else { return false }
        if blockIfUnsubmitted() != nil { return false }
        // Bấm Bắt đầu lần hai trong lúc đang đọc file: `start()` trả nil (`isStarting`).
        guard let attempt = await preExam.start() else { return false }
        // Trong lúc đọc file, người dùng có thể đã Huỷ: bỏ phiên vừa tạo (chưa làm gì, không lưu gì).
        guard self.preExam === preExam else { return false }
        if blockIfUnsubmitted() != nil { return false }
        // Chỉ nhớ tên thí sinh và chế độ khi phiên chắc chắn được dùng (như bản macOS).
        preExam.rememberStartedChoices()
        session = MobileSession(attempt: attempt, environment: environment)
        self.preExam = nil
        return true
    }

    // MARK: - Từ Kết quả và Xem lại bài

    /// **Làm lại** trên Kết quả: Trước khi thi với đúng lựa chọn của lần đó.
    @discardableResult
    public func retake() async -> SessionOpenOutcome {
        guard let results = session?.results, let preset = results.retakePreset else {
            return .failed(localized("Không làm lại được lần thi này."))
        }
        return await openPreExam(examID: results.attempt.examID, preset: preset)
    }

    /// **Luyện lại câu sai** trên Xem lại bài.
    @discardableResult
    public func practiceIncorrect() async -> SessionOpenOutcome {
        guard let session, let examID = session.results?.attempt.examID,
              let preset = session.answerReview?.practiceIncorrectPreset
        else {
            return .failed(localized("Không còn câu sai để luyện lại."))
        }
        return await openPreExam(examID: examID, preset: preset)
    }

    /// **Về thư viện** (hay nút Quay lại khi không còn bài chưa nộp): đóng màn phiên.
    public func returnToLibrary() {
        guard !hasUnsubmittedSession else { return }
        session = nil
    }

    // MARK: - Lịch sử thi

    /// Mở **Kết quả** của một lần thi trong Lịch sử thi.
    @discardableResult
    public func openHistoryAttempt(_ attempt: Attempt) -> SessionOpenOutcome {
        if let blocked = blockIfUnsubmitted() { return blocked }
        session = MobileSession(results: .history(attempt, environment: environment), environment: environment)
        return .opened
    }

    // MARK: - Bỏ bài, xuống nền

    /// Câu hỏi khi rời bài chưa nộp bằng nút Quay lại (cùng câu với bản macOS khi đóng cửa sổ làm bài).
    public var discardMessage: String { localized("Bài chưa nộp sẽ mất. Bỏ bài?") }

    /// **Bỏ bài**: bỏ phiên chưa nộp, không lưu gì (không có trong Lịch sử thi).
    public func discardSession() {
        session = nil
    }

    /// App xuống nền (`scenePhase` sang `.background`: chuyển app, về màn hình chính, khoá màn hình): tạm dừng bài đang
    /// làm, lý do `background` (mobile.md, mục Bản iOS). Mở lại vẫn ở Tạm dừng tới khi bấm Tiếp tục.
    public func appDidEnterBackground() {
        session?.attempt?.autoPause(reason: .background)
    }

    public func dismissNotice() {
        notice = nil
    }

    // MARK: - Nội bộ

    /// Đang có bài chưa nộp: báo "Đang có bài chưa nộp" (màn làm bài che cả app, nên chỉ xảy ra khi lệnh đến từ ngoài
    /// giao diện, ví dụ đề nhận từ app khác).
    private func blockIfUnsubmitted() -> SessionOpenOutcome? {
        guard hasUnsubmittedSession else { return nil }
        notice = SessionNotice(message: localized("Đang có bài chưa nộp"))
        return .blockedByUnsubmittedSession
    }
}
