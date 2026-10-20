import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import SessionFeature
import Testing

/// Điều phối phiên: mỗi lúc một phiên, cửa sổ làm bài, Làm lại / Luyện lại câu sai, Lịch sử thi,
/// đóng cửa sổ và thoát app (docs/product/exam-taking.md).
@MainActor
@Suite("Điều phối phiên", .timeLimit(.minutes(1)))
struct SessionCoordinatorTests {
    let exam = makeExam(counts: [2, 1])
    let other = makeExam(counts: [1])

    /// Ghi lại các lần shell được yêu cầu đưa cửa sổ lên trước.
    @MainActor
    final class Presenter {
        var sessionWindow = 0
        var library = 0
    }

    func makeCoordinator(_ harness: Harness, presenter: Presenter = Presenter()) -> SessionCoordinator {
        harness.library.add(exam)
        harness.library.add(other)
        let coordinator = SessionCoordinator(environment: harness.environment)
        coordinator.presentSessionWindow = { presenter.sessionWindow += 1 }
        coordinator.presentLibrary = { presenter.library += 1 }
        return coordinator
    }

    @Test("Mở Trước khi thi rồi Bắt đầu: sheet đóng, cửa sổ làm bài mở với phiên mới")
    func openAndStart() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)

        #expect(await coordinator.openPreExam(examID: exam.id) == .opened)
        let preExam = try #require(coordinator.preExam)
        #expect(preExam.examID == exam.id)
        #expect(coordinator.window == nil)

        #expect(await coordinator.startPreExam())
        #expect(coordinator.preExam == nil)
        let window = try #require(coordinator.window)
        #expect(window.screen == .attempt)
        #expect(window.title == "Kiến thức chung — Luyện tập")
        #expect(coordinator.hasUnsubmittedSession)
        #expect(presenter.sessionWindow == 1)
        // Đọc file lúc mở sheet và đọc lại lúc Bắt đầu.
        #expect(harness.library.readCount == 2)
    }

    @Test("Huỷ Trước khi thi")
    func cancelPreExam() async {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        await coordinator.openPreExam(examID: exam.id)
        coordinator.cancelPreExam()
        #expect(coordinator.preExam == nil)
    }

    @Test("Mở đề không đọc được: báo lý do, Thư viện làm mới, không có sheet")
    func openPreExamFailure() async {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        harness.library.packages[exam.id] = .failure(.unreadable(reason: "Đề có lỗi."))
        #expect(await coordinator.openPreExam(examID: exam.id) == .failed("Không mở được đề: Đề có lỗi."))
        #expect(coordinator.preExam == nil)
        #expect(coordinator.notice?.message == "Không mở được đề: Đề có lỗi.")
        #expect(harness.library.refreshRequests == [exam.id])
        coordinator.dismissNotice()
        #expect(coordinator.notice == nil)
    }

    @Test("Mỗi lúc một phiên: làm đề khác khi đang có bài chưa nộp → đưa cửa sổ lên, báo “Đang có bài chưa nộp”")
    func oneSessionAtATime() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)
        await coordinator.openPreExam(examID: exam.id)
        await coordinator.startPreExam()
        let window = try #require(coordinator.window)
        let reads = harness.library.readCount

        #expect(await coordinator.openPreExam(examID: other.id) == .blockedByUnsubmittedSession)
        #expect(coordinator.notice?.message == "Đang có bài chưa nộp")
        #expect(coordinator.preExam == nil)
        #expect(coordinator.window === window)
        #expect(presenter.sessionWindow == 2)
        #expect(harness.library.readCount == reads)

        // Cùng đề cũng vậy; mở lần thi từ Lịch sử thi cũng vậy.
        #expect(await coordinator.openPreExam(examID: exam.id) == .blockedByUnsubmittedSession)
        let old = makeAttempt(examID: exam.id)
        #expect(coordinator.openHistoryAttempt(old) == .blockedByUnsubmittedSession)
        #expect(coordinator.window === window)
    }

    @Test("Huỷ trong lúc Bắt đầu đang đọc file: không tạo phiên, không mở cửa sổ")
    func cancelWhileStarting() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)
        await coordinator.openPreExam(examID: exam.id)
        harness.library.holdsReads = true

        let start = Task { await coordinator.startPreExam() }
        await harness.library.waitForHeldReads(1)
        coordinator.cancelPreExam()
        harness.library.releaseReads()

        #expect(await start.value == false)
        #expect(coordinator.window == nil)
        #expect(coordinator.preExam == nil)
        #expect(!coordinator.hasUnsubmittedSession)
        #expect(presenter.sessionWindow == 0)
    }

    @Test("Tên thí sinh và chế độ chỉ được nhớ khi phiên được tạo; Huỷ trong lúc đọc file không đổi cài đặt")
    func preferencesOnlyAfterSessionCreated() async throws {
        let harness = Harness(candidateName: "An", lastMode: .practice)
        let coordinator = makeCoordinator(harness)
        await coordinator.openPreExam(examID: exam.id)
        let cancelled = try #require(coordinator.preExam)
        cancelled.candidateName = "Bình"
        cancelled.mode = .exam
        harness.library.holdsReads = true

        let start = Task { await coordinator.startPreExam() }
        await harness.library.waitForHeldReads(1)
        coordinator.cancelPreExam()
        harness.library.releaseReads()
        #expect(await start.value == false)
        #expect(harness.preferences.candidateName == "An")
        #expect(harness.preferences.lastMode == .practice)

        // Lần sau Bắt đầu thành công thì nhớ.
        harness.library.holdsReads = false
        await coordinator.openPreExam(examID: exam.id)
        let started = try #require(coordinator.preExam)
        #expect(started.candidateName == "An")
        started.candidateName = "  Cường "
        started.mode = .exam
        #expect(await coordinator.startPreExam())
        #expect(harness.preferences.candidateName == "Cường")
        #expect(harness.preferences.lastMode == .exam)
    }

    @Test("Huỷ rồi mở sheet khác trong lúc Bắt đầu đang đọc file: sheet mới giữ nguyên, không tạo phiên")
    func reopenWhileStarting() async throws {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        await coordinator.openPreExam(examID: exam.id)
        harness.library.holdsReads = true

        let start = Task { await coordinator.startPreExam() }
        await harness.library.waitForHeldReads(1)
        coordinator.cancelPreExam()
        let open = Task { await coordinator.openPreExam(examID: other.id) }
        await harness.library.waitForHeldReads(2)
        harness.library.releaseReads()

        #expect(await start.value == false)
        #expect(await open.value == .opened)
        #expect(coordinator.window == nil)
        #expect(coordinator.preExam?.examID == other.id)
    }

    @Test("Bấm Bắt đầu hai lần khi lần đầu đang đọc file: chỉ một phiên")
    func doubleStart() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)
        await coordinator.openPreExam(examID: exam.id)
        let preExam = try #require(coordinator.preExam)
        harness.library.holdsReads = true

        let first = Task { await coordinator.startPreExam() }
        await harness.library.waitForHeldReads(1)
        #expect(preExam.isStarting)
        #expect(!preExam.canStart)
        #expect(await coordinator.startPreExam() == false)
        harness.library.releaseReads()

        #expect(await first.value)
        #expect(coordinator.window != nil)
        #expect(presenter.sessionWindow == 1)
        #expect(harness.seeds.used.count == 1)
    }

    @Test("Mở Trước khi thi đề thứ hai khi lần mở đầu chưa đọc xong: báo chờ, giữ lần đầu")
    func openTwiceWhileReading() async throws {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        harness.library.holdsReads = true

        let first = Task { await coordinator.openPreExam(examID: exam.id) }
        await harness.library.waitForHeldReads(1)
        #expect(coordinator.isOpeningPreExam)
        let second = await coordinator.openPreExam(examID: other.id)
        #expect(second == .failed("Đang mở một đề, hãy chờ trong giây lát."))
        #expect(coordinator.notice?.message == "Đang mở một đề, hãy chờ trong giây lát.")
        harness.library.releaseReads()

        #expect(await first.value == .opened)
        #expect(coordinator.preExam?.examID == exam.id)
        #expect(!coordinator.isOpeningPreExam)
    }

    @Test("Đóng cửa sổ/thoát khi chưa nộp: hỏi “Bài chưa nộp sẽ mất. Bỏ bài?”; đồng hồ vẫn chạy; Bỏ bài không lưu gì")
    func closePolicyUnsubmitted() async throws {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        await coordinator.openPreExam(examID: exam.id)
        coordinator.preExam?.mode = .exam
        await coordinator.startPreExam()
        let attempt = try #require(coordinator.window?.attempt)
        attempt.answer("B")

        guard case let .confirm(confirmation) = coordinator.closeDecision else {
            Issue.record("Phải hỏi trước khi đóng")
            return
        }
        #expect(confirmation.message == "Bài chưa nộp sẽ mất. Bỏ bài?")
        #expect(confirmation.continueTitle == "Tiếp tục làm")
        #expect(confirmation.discardTitle == "Bỏ bài")

        // Hộp thoại hiện: Thi vẫn tính giờ.
        harness.clock.advance(90)
        attempt.tick()
        #expect(attempt.phase == .inProgress)
        #expect(attempt.clockDisplay.text == "28:30")

        coordinator.discardSession()
        #expect(coordinator.window == nil)
        #expect(!coordinator.hasUnsubmittedSession)
        #expect(coordinator.closeDecision == .closeImmediately)
        #expect(harness.library.storedAttempts.isEmpty)
        #expect(harness.library.payloads.isEmpty)
    }

    @Test("Đã nộp: đóng không hỏi; đề khác bắt đầu được và thay cửa sổ")
    func closePolicySubmitted() async throws {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        await coordinator.openPreExam(examID: exam.id)
        await coordinator.startPreExam()
        let window = try #require(coordinator.window)
        window.attempt?.openReview()
        window.requestSubmit()
        #expect(window.attempt?.isConfirmingSubmit == true)
        #expect(window.screen == .attempt)
        window.confirmSubmit()
        #expect(window.screen == .results)
        #expect(coordinator.closeDecision == .closeImmediately)
        #expect(harness.library.storedAttempts.count == 1)

        #expect(await coordinator.openPreExam(examID: other.id) == .opened)
        #expect(await coordinator.startPreExam())
        #expect(coordinator.window !== window)
        #expect(coordinator.window?.attempt?.exam.id == other.id)

        coordinator.sessionWindowDidClose()
        #expect(coordinator.window == nil)
    }

    @Test("Nộp không còn câu chưa làm thì sang Kết quả luôn")
    func submitWithoutConfirmation() async throws {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        await coordinator.openPreExam(examID: other.id)
        await coordinator.startPreExam()
        let window = try #require(coordinator.window)
        window.attempt?.answerCorrectly()
        window.attempt?.openReview()
        window.requestSubmit()
        #expect(window.screen == .results)
        #expect(window.results?.passed == true)
    }

    @Test("Kết quả → Xem lại bài / Xem câu sai → về Kết quả; Làm lại và Luyện lại câu sai mở Trước khi thi trên Thư viện")
    func resultsNavigation() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)
        await coordinator.openPreExam(examID: exam.id)
        coordinator.preExam?.mode = .exam
        coordinator.preExam?.shuffleQuestions = true
        await coordinator.startPreExam()
        let window = try #require(coordinator.window)
        let attempt = try #require(window.attempt)
        attempt.answerWrongly()
        attempt.openReview()
        window.confirmSubmit()

        #expect(await window.openAnswerReview(filter: .incorrect))
        #expect(window.screen == .answerReview)
        #expect(window.answerReview?.filter == .incorrect)
        window.showResults()
        #expect(window.screen == .results)
        #expect(await window.openAnswerReview())
        #expect(window.answerReview?.filter == .all)

        let libraryBefore = presenter.library
        #expect(await coordinator.practiceIncorrect() == .opened)
        let practice = try #require(coordinator.preExam)
        #expect(practice.isPracticeIncorrect)
        #expect(practice.questionCount == 3)
        #expect(presenter.library == libraryBefore + 1)
        coordinator.cancelPreExam()

        #expect(await coordinator.retake() == .opened)
        let retake = try #require(coordinator.preExam)
        #expect(retake.mode == .exam)
        #expect(retake.shuffleQuestions)
        #expect(!retake.isPracticeIncorrect)
    }

    @Test("Về thư viện: đóng cửa sổ làm bài, đưa Thư viện lên; không được khi chưa nộp")
    func returnToLibrary() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)
        await coordinator.openPreExam(examID: exam.id)
        await coordinator.startPreExam()
        let before = presenter.library
        coordinator.returnToLibrary()
        #expect(coordinator.window != nil)

        coordinator.window?.attempt?.submitNow()
        coordinator.returnToLibrary()
        #expect(coordinator.window == nil)
        #expect(presenter.library == before + 1)
    }

    @Test("Mở lần thi từ Lịch sử thi: cửa sổ ở Kết quả, không có phần làm bài, đóng không hỏi")
    func openHistory() async throws {
        let harness = Harness()
        let presenter = Presenter()
        let coordinator = makeCoordinator(harness, presenter: presenter)
        await coordinator.openPreExam(examID: exam.id)
        await coordinator.startPreExam()
        let submission = try #require(coordinator.window?.attempt?.submitNow())
        coordinator.returnToLibrary()

        #expect(coordinator.openHistoryAttempt(submission.attempt) == .opened)
        let window = try #require(coordinator.window)
        #expect(window.attempt == nil)
        #expect(window.screen == .results)
        #expect(window.results?.origin == .history)
        #expect(window.title == "Kiến thức chung — Luyện tập")
        #expect(!coordinator.hasUnsubmittedSession)
        #expect(coordinator.closeDecision == .closeImmediately)
        #expect(await window.openAnswerReview())
        #expect(window.screen == .answerReview)
    }

    @Test("Máy ngủ: tạm dừng bài đang làm")
    func sleepForwarded() async throws {
        let harness = Harness()
        let coordinator = makeCoordinator(harness)
        coordinator.systemWillSleep()
        await coordinator.openPreExam(examID: exam.id)
        await coordinator.startPreExam()
        coordinator.systemWillSleep()
        #expect(coordinator.window?.attempt?.pauseMessage == "Đã tạm dừng vì máy ngủ")
    }

    func makeAttempt(examID: UUID) -> Attempt {
        Attempt(
            examID: examID, examTitle: "Cũ", candidateName: "An", mode: .exam,
            startedAt: Date(timeIntervalSince1970: 0), submittedAt: Date(timeIntervalSince1970: 60),
            elapsedSeconds: 60, correct: 1, total: 3, score1000: 333, percent: 33, passed: false
        )
    }
}
