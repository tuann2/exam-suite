import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
import LibraryData
@testable import SessionFeature
import Testing

/// Làm bài trên đề chuẩn (2.000 câu, 200 ảnh; docs/product/large-exams.md) qua model thật: Thư viện SwiftData trong
/// bộ nhớ, file đề trong thư mục tạm, `SessionCoordinator` như app. Mỗi thao tác đo cả phần model mà màn hình đọc
/// ngay sau đó (câu hiện tại, lựa chọn, bảng câu hỏi; Kết quả; danh sách Xem lại).
@MainActor
@Suite("Timing: làm bài với đề chuẩn, thư viện chuẩn 50 đề (chạy tuần tự)", .serialized)
struct SessionTimingTests {
    @Test("Bắt đầu → đổi câu → nộp; đổi bộ lọc Xem lại", .timeLimit(.minutes(3)))
    func standardExamSession() async throws {
        let workspace = try SessionWorkspace()
        let package = StandardExam.standard
        let examID = package.exam.id
        let file = try workspace.write(package, to: "Đề/Đề chuẩn.exam")
        let store = LibraryStore.inMemory(configuration: workspace.configuration(), defaults: workspace.defaults)
        store.load()
        #expect(await store.importFiles([file]).addedExamIDs == [examID])
        let clock = FakeClock()
        var seed: UInt64 = 1
        let environment = SessionEnvironment(
            library: LibraryStoreSessionLibrary(store: store),
            preferences: UserDefaultsSessionPreferences(defaults: workspace.defaults),
            makeSeed: {
                seed += 1
                return seed
            },
            makeClock: { [clock] in clock }
        )

        let runs = 3
        var starts: [Duration] = []
        var startGaps: [Duration] = []
        var navigations: [Duration] = []
        var worstNavigation: Duration = .zero
        var submits: [Duration] = []
        var submitGaps: [Duration] = []
        let timer = ContinuousClock()
        for _ in 0 ..< runs {
            let coordinator = SessionCoordinator(environment: environment)
            #expect(await coordinator.openPreExam(examID: examID, mode: .exam) == .opened)
            let preExam = try #require(coordinator.preExam)
            preExam.candidateName = "Nguyễn Văn An"
            preExam.shuffleQuestions = true
            preExam.shuffleOptions = true

            // Bắt đầu: đọc lại nghiêm (nền) + tạo đề + model phiên, tới khi màn làm bài có đủ dữ liệu cho câu 1.
            let probe = MainActorGapProbe()
            await probe.start()
            let startBegan = timer.now
            #expect(await coordinator.startPreExam())
            let attempt = try #require(coordinator.window?.attempt)
            Self.readAttemptScreen(attempt)
            starts.append(timer.now - startBegan)
            await probe.stop()
            startGaps.append(probe.longestGap)
            #expect(attempt.questionCount == 2_000)

            // Đổi câu: 200 sự kiện xen kẽ chọn đáp án (phím chữ cái), câu sau (→), nhảy tới ô bất kỳ của bảng câu hỏi.
            // Mỗi lần đo là trung bình một sự kiện của đợt 200 sự kiện; kèm sự kiện chậm nhất.
            let events = 200
            var navigation: Duration = .zero
            for event in 0 ..< events {
                let elapsed = timer.measure {
                    switch event % 3 {
                    case 0: attempt.selectOption(atPosition: 0)
                    case 1: attempt.nextQuestion()
                    default: attempt.goTo(index: (event * 37) % attempt.questionCount)
                    }
                    Self.readAttemptScreen(attempt)
                }
                navigation += elapsed
                worstNavigation = max(worstNavigation, elapsed)
            }
            navigations.append(navigation / events)

            // Nộp: chấm + lưu lần thi (payload vào kho) + Kết quả. Còn câu chưa làm nên có hộp xác nhận. Nộp chạy đồng bộ
            // trên main actor nên khoảng chặn dài nhất ≈ cả thao tác (bước 9: ghi số, cột main actor của bảng ngân sách).
            let submitProbe = MainActorGapProbe()
            await submitProbe.start()
            let submitBegan = timer.now
            attempt.openReview()
            coordinator.window?.requestSubmit()
            coordinator.window?.confirmSubmit()
            let results = try #require(coordinator.window?.results)
            _ = (results.scoreText, results.sectionRows, results.comparison, results.incorrectCount)
            submits.append(timer.now - submitBegan)
            await submitProbe.stop()
            submitGaps.append(submitProbe.longestGap)
            #expect(results.reviewUnavailableReason == nil)
            coordinator.returnToLibrary()
        }
        let start = Timing.record(TimingSample(budget: .sessionStart, runs: starts))
        Timing.record(TimingSample(budget: .sessionStartMainActor, runs: startGaps))
        let navigate = Timing.record(TimingSample(budget: .sessionNavigate, runs: navigations, worstEvent: worstNavigation))
        let submit = Timing.record(TimingSample(budget: .sessionSubmit, runs: submits))
        Timing.record(TimingSample(budget: .sessionSubmitMainActor, runs: submitGaps))

        // Xem lại của một lần thi cũ (đo mở lần thi cũ với kho 200 lần thi ở LibraryScaleTimingTests).
        let saved = store.attempts(examID: examID)
        #expect(saved.count == runs)
        let review = await ResultsModel.history(saved[0], environment: environment).makeAnswerReview(filter: .all)
        let answerReview = try #require(review)
        #expect(answerReview.rows.count == 2_000)

        // Đổi bộ lọc Xem lại: danh sách, số câu từng bộ lọc, câu đang chọn.
        let filters: [AnswerReviewFilter] = [.incorrect, .unanswered, .correct, .flagged, .all]
        var filterRuns: [Duration] = []
        for _ in 0 ..< 5 {
            filterRuns.append(timer.measure {
                for filter in filters {
                    answerReview.setFilter(filter)
                    Self.readReviewScreen(answerReview)
                }
            } / filters.count)
        }
        let filter = Timing.record(TimingSample(budget: .reviewFilter, runs: filterRuns))

        #expect(start.isWithinLimit, "\(start.line)")
        #expect(navigate.isWithinLimit, "\(navigate.line)")
        #expect(submit.isWithinLimit, "\(submit.line)")
        #expect(filter.isWithinLimit, "\(filter.line)")
    }

    /// Những gì màn làm bài đọc sau mỗi thao tác.
    private static func readAttemptScreen(_ attempt: AttemptModel) {
        _ = (attempt.currentQuestion, attempt.displayedOptions, attempt.navigatorSections, attempt.currentImage)
        _ = (attempt.questionPositionText, attempt.progressText, attempt.currentSectionTitle, attempt.selectionHint)
    }

    /// Những gì màn Xem lại đọc: danh sách theo bộ lọc, số câu mỗi bộ lọc, chi tiết câu đang chọn.
    private static func readReviewScreen(_ review: AnswerReviewModel) {
        _ = review.rows
        for filter in AnswerReviewFilter.allCases { _ = review.count(for: filter) }
        if let index = review.selectedIndex { _ = review.detail(at: index) }
    }
}
