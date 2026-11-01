import ExamKit
import Foundation
@testable import LibraryData
import SwiftData
import Testing

@MainActor
@Suite("Kho SwiftData")
struct PersistenceTests {
    /// CoreData in ra log "isn't in the correct format" khi mở file rác: đó là lỗi được test cố ý gây ra.
    @Test("Kho hỏng (file rác): đổi tên thành Library.store.broken-<thời điểm> kèm -shm/-wal, tạo kho mới, báo người dùng")
    func brokenStoreIsMovedAsideAndReplaced() async throws {
        let workspace = try TestWorkspace()
        let config = workspace.configuration(mode: .strict)
        let directory = config.storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let junk = Data("đây không phải cơ sở dữ liệu SQLite".utf8)
        try junk.write(to: config.storeURL)
        try Data("wal cũ".utf8).write(to: URL(fileURLWithPath: config.storeURL.path + "-wal"))
        try Data("shm cũ".utf8).write(to: URL(fileURLWithPath: config.storeURL.path + "-shm"))

        let store = LibraryStore.persistent(configuration: config, defaults: workspace.defaults)

        guard case let .recoveredFromBrokenStore(broken) = store.storeIssue else {
            Issue.record("Phải báo đã thay kho hỏng, nhận được \(String(describing: store.storeIssue))")
            return
        }
        #expect(broken.deletingLastPathComponent().path == directory.path)
        #expect(broken.lastPathComponent.wholeMatch(of: #/Library\.store\.broken-\d{8}T\d{6}Z/#) != nil)
        #expect(try Data(contentsOf: broken) == junk)
        #expect(try Data(contentsOf: URL(fileURLWithPath: broken.path + "-wal")) == Data("wal cũ".utf8))
        #expect(try Data(contentsOf: URL(fileURLWithPath: broken.path + "-shm")) == Data("shm cũ".utf8))
        #expect(store.storeIssue?.logMessage.contains(broken.lastPathComponent) == true)
        #expect(workspace.exists(config.storeURL))

        // Kho mới dùng được và bền qua lần mở sau.
        store.load()
        let exam = makeExam(title: "Sau khi cứu kho")
        let report = await store.importFiles([try workspace.write(exam, to: "de.exam")])
        #expect(report.addedExamIDs == [exam.id])
        #expect(store.lastStorageError == nil)
        let reopened = LibraryStore.persistent(configuration: config, defaults: workspace.defaults)
        #expect(reopened.storeIssue == nil)
        reopened.load()
        #expect(reopened.entries.map(\.examID) == [exam.id])

        store.dismissStoreIssue()
        #expect(store.storeIssue == nil)
    }

    @Test("Đổi tên kho hỏng không đè kho hỏng trước đó cùng thời điểm")
    func brokenNamesDoNotCollide() throws {
        let workspace = try TestWorkspace()
        let url = workspace.url("Library.store")
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        try Data("1".utf8).write(to: url)
        let first = try LibraryPersistence.moveAsideBrokenStore(at: url, now: now)
        try Data("2".utf8).write(to: url)
        try Data("2-wal".utf8).write(to: URL(fileURLWithPath: url.path + "-wal"))

        let second = try LibraryPersistence.moveAsideBrokenStore(at: url, now: now)

        #expect(first.lastPathComponent == "Library.store.broken-20260921T141320Z")
        #expect(second.lastPathComponent == "Library.store.broken-20260921T141320Z-2")
        #expect(try Data(contentsOf: first) == Data("1".utf8))
        #expect(try Data(contentsOf: second) == Data("2".utf8))
        #expect(try Data(contentsOf: URL(fileURLWithPath: second.path + "-wal")) == Data("2-wal".utf8))
        #expect(!workspace.exists(url))
    }

    @Test("Không tạo được thư mục kho: dùng kho tạm trong bộ nhớ và báo, không crash")
    func unusableLocationFallsBackToMemory() async throws {
        let workspace = try TestWorkspace()
        let blocker = workspace.url("blocker")
        try Data("file nằm đúng chỗ thư mục kho".utf8).write(to: blocker)
        var config = workspace.configuration(mode: .strict)
        config.storeURL = blocker.appendingPathComponent("Library.store")

        let store = LibraryStore.persistent(configuration: config, defaults: workspace.defaults)

        guard case .temporaryStore = store.storeIssue else {
            Issue.record("Phải báo đang dùng kho tạm, nhận được \(String(describing: store.storeIssue))")
            return
        }
        store.load()
        let exam = makeExam()
        let report = await store.importFiles([try workspace.write(exam, to: "de.exam")])
        #expect(report.addedExamIDs == [exam.id])
    }

    @Test("Kho trên đĩa bền qua các lần mở: mục, bookmark, lần mở, lần thi, payload")
    func storeSurvivesReopen() async throws {
        let workspace = try TestWorkspace()
        let config = workspace.configuration(mode: .lenient)
        let file = try workspace.writeFixture("kien-thuc-chung", to: "de.exam")
        let id = RepoFixtures.kienThucChungID
        let attempt = Attempt(
            examID: id, examTitle: "Kiến thức chung", candidateName: "Bình", mode: .practice,
            startedAt: Date(timeIntervalSince1970: 1_790_000_000), submittedAt: Date(timeIntervalSince1970: 1_790_000_600),
            elapsedSeconds: 600, correct: 3, total: 4, score1000: 750, percent: 75, passed: true
        )
        let before: LibraryEntry
        do {
            let store = LibraryStore.persistent(configuration: config, defaults: workspace.defaults)
            #expect(store.storeIssue == nil)
            store.load()
            _ = await store.importFiles([file])
            store.markOpened(id)
            try store.addAttempt(attempt, payload: Data([1, 2, 3]))
            before = try #require(store.entry(id))
        }

        let reopened = LibraryStore.persistent(configuration: config, defaults: workspace.defaults)
        reopened.load()

        var entry = try #require(reopened.entry(id))
        entry.status = before.status
        #expect(entry == before)
        #expect(reopened.attempts == [attempt])
        #expect(try reopened.attemptPayload(id: attempt.id) == Data([1, 2, 3]))
        await reopened.refreshAll()
        #expect(reopened.entry(id)?.status == .ready)
    }

    @Test("Kho tạo bằng schema v1 mở được qua kế hoạch chuyển đổi hiện tại, không mất dữ liệu")
    func versionOneStoreOpens() throws {
        let workspace = try TestWorkspace()
        let url = workspace.url("v1/Library.store")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let record = LibraryRecord(
            examID: UUID(),
            location: StoredLocation(bookmark: Data([9, 9]), path: "/tmp/de.exam"),
            summary: ExamSummary(title: "Đề v1", code: "V1", questionCount: 3, sectionCount: 1, timeLimitMinutes: 5, passPercent: 50),
            facts: FileFacts(size: 1234, modificationDate: Date(timeIntervalSince1970: 1_790_000_000.123456)),
            isSample: true,
            addedAt: Date(timeIntervalSince1970: 1_780_000_000),
            lastOpenedAt: nil,
            verdict: .needsNewerApp(found: 3, supported: 1),
            checkFingerprint: "cũ",
            checkedAt: Date(timeIntervalSince1970: 1_780_000_001)
        )
        do {
            let schema = Schema(versionedSchema: LibrarySchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            container.mainContext.insert(LibraryItem(record: record))
            try container.mainContext.save()
        }

        let opened = LibraryPersistence.openPersistent(at: url, now: Date())

        #expect(opened.issue == nil)
        #expect(try opened.repository.fetchEntries() == [record])
        #expect(LibrarySchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(LibraryMigrationPlan.schemas.count == 1)
        #expect(LibraryMigrationPlan.stages.isEmpty)
    }

    @Test("preview giữ đúng mục, trạng thái, lần thi truyền vào; inMemory dùng được ngay")
    func previewAndInMemoryFactories() async throws {
        let entry = LibraryEntry(
            examID: UUID(),
            summary: ExamSummary(title: "Đề hỏng", code: "H1", questionCount: 5, sectionCount: 1, timeLimitMinutes: 10, passPercent: 50),
            fileURL: URL(fileURLWithPath: "/tmp/de-hong.exam"),
            fileSize: 2048,
            addedAt: Date(timeIntervalSince1970: 1_790_000_000),
            status: .corrupt(reason: .package(.missingManifest))
        )
        let attempt = Attempt(
            examID: entry.examID, examTitle: entry.title, candidateName: "Chi", mode: .exam,
            startedAt: Date(timeIntervalSince1970: 1_790_000_000), submittedAt: Date(timeIntervalSince1970: 1_790_000_900),
            elapsedSeconds: 900, correct: 2, total: 5, score1000: 400, percent: 40, passed: false
        )

        let preview = LibraryStore.preview(entries: [entry], attempts: [attempt])

        #expect(preview.entries == [entry])
        #expect(preview.attempts == [attempt])
        #expect(preview.latestAttempt(examID: entry.examID) == attempt)
        #expect(preview.configuration == .student)

        let workspace = try TestWorkspace()
        let memory = LibraryStore.inMemory(configuration: workspace.configuration(mode: .lenient), defaults: workspace.defaults)
        memory.load()
        let exam = makeExam()
        let report = await memory.importFiles([try workspace.write(exam, to: "de.exam")])
        #expect(report.addedExamIDs == [exam.id])
        #expect(memory.storeIssue == nil)
        #expect(!workspace.exists(workspace.configuration(mode: .lenient).storeURL))
    }

    /// Kho chỉ lưu chữ của lý do (`LibrarySchemaV1` không đổi): lý do có mã lưu thành đúng câu tiếng Việt trước bước 7b, đọc
    /// lại thành `.stored(câu đó)`, và kết luận đó không được dùng lại (lần làm mới sau đọc lại file).
    @Test("Mỗi kết luận đọc file lưu và đọc lại qua SwiftData; lý do lưu thành câu tiếng Việt, đọc lại không dùng lại", arguments: [
        FileVerdict.ready,
        .failsStrict(reason: unknownFieldsReason("x")),
        .corrupt(reason: .package(.missingManifest)),
        .needsNewerApp(found: 2, supported: 1),
    ])
    func verdictRoundTrip(verdict: FileVerdict) throws {
        let repository = LibraryPersistence.inMemoryRepository()
        let record = LibraryRecord(
            examID: UUID(),
            location: StoredLocation(bookmark: Data([1]), path: "/tmp/x.exam"),
            summary: ExamSummary(title: "X", questionCount: 1, sectionCount: 1, timeLimitMinutes: 1, passPercent: 1),
            facts: nil,
            isSample: false,
            addedAt: Date(timeIntervalSince1970: 1_790_000_000),
            lastOpenedAt: nil,
            verdict: verdict,
            checkFingerprint: "f",
            checkedAt: nil
        )
        try repository.saveEntries([record])
        var stored = record
        switch verdict {
        case let .failsStrict(reason): stored.verdict = .failsStrict(reason: .stored(reason.logMessage))
        case let .corrupt(reason): stored.verdict = .corrupt(reason: .stored(reason.logMessage))
        case .ready, .needsNewerApp: break
        }
        #expect(try repository.fetchEntries() == [stored])
        #expect(stored.verdict?.isReusable == (verdict == .ready || verdict == .needsNewerApp(found: 2, supported: 1)))
        #expect(repository is SwiftDataLibraryRepository)
    }

    @Test("Lý do lưu trong kho là đúng câu tiếng Việt trước bước 7b")
    func storedReasonTextUnchanged() {
        #expect(unknownFieldsReason("x").logMessage == "Đề có trường không được hỗ trợ: x.")
        #expect(FileProblemReason.package(.missingManifest).logMessage == "Gói đề thiếu file exam.json ở gốc.")
    }
}
