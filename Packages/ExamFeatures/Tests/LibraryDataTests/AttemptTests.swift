import ExamKit
import Foundation
@testable import LibraryData
import Testing

@MainActor
@Suite("Lần thi")
struct AttemptTests {
    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    static func attempt(
        examID: UUID,
        title: String = "Đề",
        minutesAfterStart: Double,
        mode: SessionMode = .exam,
        correct: Int = 7,
        total: Int = 10
    ) -> Attempt {
        let submitted = start.addingTimeInterval(minutesAfterStart * 60)
        return Attempt(
            examID: examID,
            examTitle: title,
            candidateName: "Nguyễn Văn An",
            mode: mode,
            startedAt: submitted.addingTimeInterval(-300),
            submittedAt: submitted,
            elapsedSeconds: 299.5,
            correct: correct,
            total: total,
            score1000: correct * 1000 / total,
            percent: correct * 100 / total,
            passed: correct * 1000 / total >= 700
        )
    }

    @Test("Thêm, liệt kê mới nhất trước, lọc theo đề, lần thi gần nhất theo đề, payload", arguments: RepositoryKind.allCases)
    func addAndList(kind: RepositoryKind) throws {
        let workspace = try TestWorkspace()
        let repository = kind.make()
        let store = workspace.makeStore(repository: repository)
        let examA = UUID()
        let examB = UUID()
        let a1 = Self.attempt(examID: examA, title: "A", minutesAfterStart: 10, mode: .practice, correct: 4)
        let b1 = Self.attempt(examID: examB, title: "B", minutesAfterStart: 20)
        let a2 = Self.attempt(examID: examA, title: "A (đổi tên)", minutesAfterStart: 30, correct: 9)
        let payload = Data("{\"answers\":{}}".utf8)

        try store.addAttempt(a1, payload: payload)
        try store.addAttempt(a2)
        try store.addAttempt(b1)

        #expect(store.attempts == [a2, b1, a1])
        #expect(store.attempts(examID: nil) == [a2, b1, a1])
        #expect(store.attempts(examID: examA) == [a2, a1])
        #expect(store.latestAttempt(examID: examA) == a2)
        #expect(store.latestAttempts == [examA: a2, examB: b1])
        #expect(try store.attemptPayload(id: a1.id) == payload)
        #expect(try store.attemptPayload(id: a2.id) == Data())
        #expect(try store.attemptPayload(id: UUID()) == nil)
        #expect(throws: LibraryError.duplicateAttempt(id: a1.id)) { try store.addAttempt(a1) }

        // Đọc lại từ kho: đủ trường, đúng thứ tự.
        let reopened = workspace.makeStore(repository: repository)
        reopened.load()
        #expect(reopened.attempts == [a2, b1, a1])
        #expect(reopened.attempts.last?.mode == .practice)
        #expect(reopened.attempts.last?.elapsedSeconds == 299.5)
        #expect(reopened.latestAttempts[examA] == a2)
    }

    @Test("Lần thi còn lại khi đề bị xoá khỏi thư viện")
    func attemptsSurviveRemoval() async throws {
        let workspace = try TestWorkspace()
        let repository = RepositoryKind.swiftData.make()
        let store = workspace.makeStore(repository: repository)
        let exam = makeExam(title: "Đề sẽ xoá")
        _ = await store.importFiles([try workspace.write(exam, to: "de.exam")])
        let attempt = Self.attempt(examID: exam.id, title: exam.title, minutesAfterStart: 5)
        try store.addAttempt(attempt)

        try store.remove(exam.id)

        #expect(store.entries.isEmpty)
        #expect(store.attempts(examID: exam.id) == [attempt])
        #expect(store.latestAttempt(examID: exam.id) == attempt)
        let reopened = workspace.makeStore(repository: repository)
        reopened.load()
        #expect(reopened.attempts == [attempt])
    }

    @Test("Lần thi gần nhất dùng cho sắp xếp Điểm lần trước và Gần đây")
    func latestAttemptFeedsQueries() async throws {
        let workspace = try TestWorkspace()
        let clock = TestClock(Self.start.addingTimeInterval(-86_400 * 60))
        let store = workspace.makeStore(clock: clock)
        let low = makeExam(title: "Điểm thấp")
        let high = makeExam(title: "Điểm cao")
        _ = await store.importFiles([try workspace.write(low, to: "a.exam"), try workspace.write(high, to: "b.exam")])
        try store.addAttempt(Self.attempt(examID: low.id, minutesAfterStart: 1, correct: 3))
        try store.addAttempt(Self.attempt(examID: high.id, minutesAfterStart: 2, correct: 9))

        let byScore = LibraryQuery.sorted(store.entries, by: .lastScore, latestAttempts: store.latestAttempts)
        #expect(byScore.map(\.examID) == [high.id, low.id])
        let recent = LibraryQuery.recent(store.entries, latestAttempts: store.latestAttempts, now: Self.start.addingTimeInterval(3600))
        #expect(recent.map(\.examID) == [high.id, low.id])
    }
}
