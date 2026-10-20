import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
import LibraryData
@testable import SessionFeature
import Testing

/// Thư viện chuẩn của large-exams.md (mục "Đề chuẩn để đo", dòng Thư viện): 50 đề, trong đó 5 đề chuẩn (2.000 câu,
/// 200 ảnh), và 200 lần thi trong Lịch sử thi, 20 lần của một đề chuẩn. Đo làm mới trạng thái 50 đề (mọi file đã đổi,
/// đọc nghiêm lại ở nền; main actor không bị chặn) và mở lần thi cũ khi kho có 200 lần thi. Kho SwiftData trong bộ
/// nhớ, file trong thư mục tạm.
///
/// Cùng suite `.serialized` với các test đo khác của SessionFeatureTests: các test đo này chạy việc nặng đồng bộ trên
/// main actor (nộp, tạo lần thi), chạy song song thì làm sai số đo main actor chặn của nhau (đã gặp: ~0,9 s).
extension SessionTimingTests {
    struct LibraryClock: SessionClock {
        func now() -> Date { Date(timeIntervalSince1970: 1_792_000_000) }
        func uptime() -> TimeInterval { 1_000 }
    }

    @Test("Làm mới 50 đề; mở lần thi cũ của đề chuẩn với 200 lần thi trong kho", .timeLimit(.minutes(5)))
    func standardLibrary() async throws {
        let workspace = try SessionWorkspace()
        let root = workspace.root

        // 5 đề chuẩn (cùng nội dung, khác id và tên) + 45 đề nhỏ (20 câu, 2 ảnh), ghi song song ngoài main actor.
        let packages: [ExamPackage] = (0 ..< 50).map { index in
            if index < 5 {
                var package = StandardExam.standard
                package.exam.id = UUID(uuidString: String(format: "5ad0e000-0000-4000-8000-%012d", index))!
                package.exam.title += " (bản \(index + 1))"
                return package
            }
            return StandardExam.make(seed: UInt64(1_000 + index), questions: 20, sections: 2)
        }
        let urls = (0 ..< 50).map { root.appendingPathComponent("Thư viện/de-\($0).exam") }
        try FileManager.default.createDirectory(at: urls[0].deletingLastPathComponent(), withIntermediateDirectories: true)
        try await Task.detached {
            let failures = ErrorBox()
            DispatchQueue.concurrentPerform(iterations: packages.count) { index in
                do { try ExamPackageWriter.write(packages[index], to: urls[index]) } catch { failures.record(error) }
            }
            if let error = failures.first { throw error }
        }.value

        let store = LibraryStore.inMemory(configuration: workspace.configuration(), defaults: workspace.defaults)
        store.load()
        let report = await store.importFiles(urls)
        #expect(report.addedExamIDs.count == 50)

        // 200 lần thi: 20 của đề chuẩn thứ nhất (trả lời nửa đề), 4 của mỗi đề nhỏ. Payload như app ghi khi nộp.
        let standardID = packages[0].exam.id
        var attemptCount = 0
        for (index, package) in packages.enumerated() where index == 0 || index >= 5 {
            let fingerprints = QuestionFingerprint.fingerprints(of: package.exam)
            for round in 0 ..< (index == 0 ? 20 : 4) {
                try Self.addAttempt(of: package.exam, seed: UInt64(round + 1), fingerprints: fingerprints, to: store)
                attemptCount += 1
            }
        }
        #expect(attemptCount == 200)
        #expect(store.attempts(examID: nil).count == 200)

        // Làm mới: mọi file đổi giờ sửa nên cả 50 đề được đọc nghiêm lại.
        var refreshGaps: [Duration] = []
        var bump: TimeInterval = 0
        let refresh = await Timing.measure(.libraryRefresh, runs: 3) {
            bump += 60
            for url in urls {
                try? FileManager.default.setAttributes(
                    [.modificationDate: Date(timeIntervalSince1970: 1_790_000_000 + bump)], ofItemAtPath: url.path)
            }
            let probe = MainActorGapProbe()
            await probe.start()
            await store.refreshAll()
            await probe.stop()
            refreshGaps.append(probe.longestGap)
        }
        #expect(store.entries.count == 50)
        #expect(store.entries.allSatisfy { $0.status == .ready })
        let refreshBlocking = Timing.record(TimingSample(budget: .libraryRefreshMainActor, runs: refreshGaps))

        // Mở lần thi cũ của đề chuẩn từ Lịch sử thi: giải mã payload, đối chiếu tóm tắt, đọc nghiêm file đề, Xem lại.
        let environment = SessionEnvironment(
            library: LibraryStoreSessionLibrary(store: store),
            preferences: UserDefaultsSessionPreferences(defaults: workspace.defaults),
            makeSeed: { 1 },
            makeClock: { LibraryClock() }
        )
        let history = store.attempts(examID: standardID)
        #expect(history.count == 20)
        var index = 0
        var opened = 0
        let open = await Timing.measure(.historyOpen, runs: 3) {
            let results = ResultsModel.history(history[index], environment: environment)
            index += 1
            _ = (results.scoreText, results.sectionRows, results.comparison)
            if let review = await results.makeAnswerReview(filter: .all) {
                _ = review.rows
                for filter in AnswerReviewFilter.allCases { _ = review.count(for: filter) }
                if let selected = review.selectedIndex { _ = review.detail(at: selected) }
                opened += 1
            }
        }
        #expect(opened == 3)

        #expect(refresh.isWithinLimit, "\(refresh.line)")
        #expect(refreshBlocking.isWithinLimit, "\(refreshBlocking.line)")
        #expect(open.isWithinLimit, "\(open.line)")
    }

    /// Một lần thi Thi của `exam`: tạo đề (xáo), trả lời nửa số câu, nộp, lưu lần thi + payload vào kho.
    private static func addAttempt(
        of exam: Exam, seed: UInt64, fingerprints: [UUID: String], to store: LibraryStore
    ) throws {
        let paper = try ExamComposer.compose(
            exam, options: CompositionOptions(selection: .all, shuffleQuestions: true, shuffleOptions: true, seed: seed))
        var session = try ExamSession(
            exam: exam, paper: paper, mode: .exam, timeLimitMinutes: nil, candidateName: "Nguyễn Văn An",
            clock: LibraryClock())
        for index in stride(from: 0, to: session.questionCount, by: 2) {
            try session.goTo(index: index)
            try session.select(option: session.currentItem.optionOrder[(index / 2 + Int(seed)) % session.currentItem.optionOrder.count])
        }
        try session.openReview()
        try session.submit()
        let result = try #require(session.result)
        let record = try AttemptRecord(session: session, fingerprints: fingerprints)
        let attempt = Attempt(
            examID: exam.id, examTitle: exam.title, candidateName: session.candidateName, mode: .exam,
            startedAt: session.startedAt, submittedAt: session.submittedAt ?? session.startedAt,
            elapsedSeconds: session.elapsed, correct: result.correct, total: result.total,
            score1000: result.score1000, percent: result.percent, passed: result.passed
        )
        try store.addAttempt(attempt, payload: record.encoded())
    }
}

/// Gom lỗi từ các luồng của `concurrentPerform`.
private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [any Error] = []

    func record(_ error: any Error) { lock.withLock { errors.append(error) } }
    var first: (any Error)? { lock.withLock { errors.first } }
}
