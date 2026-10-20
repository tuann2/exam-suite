import CoreData
import ExamKit
import Foundation
@testable import LibraryData
import SQLite3
import SwiftData
import Testing

/// Dữ liệu trong `Fixtures/Library-v1.store`: kho SwiftData thật tạo bằng `LibrarySchemaV1` (xem
/// `Fixtures/README.md`). Bookmark là byte giả có độ dài như bookmark thật: test kiểm schema đọc lại đúng
/// từng byte, không cần file thật.
enum LibraryV1Fixture {
    static let sampleExamID = UUID(uuidString: "0f5c2a6e-1b3d-4c5e-8f70-a1b2c3d4e501")!
    static let userExamID = UUID(uuidString: "0f5c2a6e-1b3d-4c5e-8f70-a1b2c3d4e502")!
    static let newerExamID = UUID(uuidString: "0f5c2a6e-1b3d-4c5e-8f70-a1b2c3d4e503")!
    /// Đề đã bị xoá khỏi thư viện nhưng còn lần thi.
    static let removedExamID = UUID(uuidString: "0f5c2a6e-1b3d-4c5e-8f70-a1b2c3d4e504")!

    /// File fixture trong mã nguồn (generator ghi vào đây).
    static let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Library-v1.store", isDirectory: false)

    /// Bản chép trong bundle test (resource `Fixtures`).
    static var bundledURL: URL? {
        Bundle.module.url(forResource: "Library-v1", withExtension: "store", subdirectory: "Fixtures")
    }

    static func bookmark(seed: Int, count: Int) -> Data {
        Data((0 ..< count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ seed) })
    }

    static let records: [LibraryRecord] = [
        LibraryRecord(
            examID: sampleExamID,
            location: StoredLocation(
                bookmark: bookmark(seed: 1, count: 812),
                // Đường dẫn đã ghi trong `Library-v1.store` (test so từng byte đã lưu). Fixture tạo lại một lần
                // 2026-10-20 cho bản public với bundle ID hiện hành (Nt0 duyệt; Fixtures/README.md); ngoài lần đó
                // fixture không được tạo lại (AGENTS.md, kho v1 của người dùng mở được).
                path: "/Users/hocvien/Library/Application Support/vn.io.nt0.examsuite/Samples/Làm quen với Exam Suite.exam"
            ),
            summary: ExamSummary(
                title: "Làm quen với Exam Suite",
                code: "MAU-01",
                questionCount: 12,
                sectionCount: 3,
                imageCount: 2,
                timeLimitMinutes: 15,
                passPercent: 60,
                hideAnswers: false,
                formatVersion: 1
            ),
            facts: FileFacts(size: 48_213, modificationDate: Date(timeIntervalSinceReferenceDate: 812_345_678.123_456)),
            isSample: true,
            addedAt: Date(timeIntervalSinceReferenceDate: 812_345_700.5),
            lastOpenedAt: nil,
            verdict: .ready,
            checkFingerprint: "format v1; app 0.1.0 (1)",
            checkedAt: Date(timeIntervalSinceReferenceDate: 812_345_701.25)
        ),
        LibraryRecord(
            examID: userExamID,
            location: StoredLocation(
                bookmark: bookmark(seed: 2, count: 1_024),
                path: "/Users/hocvien/Downloads/An toàn thông tin cơ bản.exam"
            ),
            summary: ExamSummary(
                title: "An toàn thông tin cơ bản",
                code: nil,
                questionCount: 40,
                sectionCount: 4,
                imageCount: 0,
                timeLimitMinutes: 45,
                passPercent: 70,
                hideAnswers: true,
                formatVersion: 1
            ),
            facts: FileFacts(size: 120_004, modificationDate: Date(timeIntervalSinceReferenceDate: 812_400_000)),
            isSample: false,
            addedAt: Date(timeIntervalSinceReferenceDate: 812_400_100.75),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 812_500_000.125),
            // Kho chỉ lưu chữ của lý do; đọc lại là `.stored` (bước 7b), cùng chữ đã lưu.
            verdict: .failsStrict(reason: .stored("Đề có trường không được hỗ trợ: ghiChu.")),
            checkFingerprint: "format v1; app 0.1.0 (1)",
            checkedAt: Date(timeIntervalSinceReferenceDate: 812_500_001)
        ),
        LibraryRecord(
            examID: newerExamID,
            location: StoredLocation(
                bookmark: bookmark(seed: 3, count: 640),
                path: "/Volumes/Chia sẻ/Đề thi/Đề mới hơn.exam"
            ),
            summary: ExamSummary(
                title: "Đề mới hơn",
                code: "MOI.2",
                questionCount: 5,
                sectionCount: 1,
                imageCount: 1,
                timeLimitMinutes: 10,
                passPercent: 50,
                hideAnswers: false,
                formatVersion: 1
            ),
            facts: FileFacts(size: 1_024, modificationDate: nil),
            isSample: false,
            addedAt: Date(timeIntervalSinceReferenceDate: 812_600_000),
            lastOpenedAt: nil,
            verdict: .needsNewerApp(found: 2, supported: 1),
            checkFingerprint: "format v1; app 0.0.9 (1)",
            checkedAt: nil
        ),
    ]

    static let attempts: [(attempt: Attempt, payload: Data)] = [
        (
            Attempt(
                id: UUID(uuidString: "a7e3d9c1-5b2f-4e6a-9d8c-7b6a5f4e3d01")!,
                examID: sampleExamID,
                examTitle: "Làm quen với Exam Suite",
                candidateName: "Nguyễn Thị Lan",
                mode: .practice,
                startedAt: Date(timeIntervalSinceReferenceDate: 812_350_000),
                submittedAt: Date(timeIntervalSinceReferenceDate: 812_350_600.5),
                elapsedSeconds: 588.25,
                correct: 10,
                total: 12,
                score1000: 833,
                percent: 83,
                passed: true
            ),
            Data(#"{"version":1,"answers":{"q1":["A"],"q2":["B","C"]}}"#.utf8)
        ),
        (
            Attempt(
                id: UUID(uuidString: "a7e3d9c1-5b2f-4e6a-9d8c-7b6a5f4e3d02")!,
                examID: userExamID,
                examTitle: "An toàn thông tin cơ bản",
                candidateName: "Trần Văn Bình",
                mode: .exam,
                startedAt: Date(timeIntervalSinceReferenceDate: 812_510_000),
                submittedAt: Date(timeIntervalSinceReferenceDate: 812_512_700),
                elapsedSeconds: 2_700,
                correct: 25,
                total: 40,
                score1000: 625,
                percent: 62,
                passed: false
            ),
            Data((0 ..< 20_000).map { UInt8(truncatingIfNeeded: $0 &* 7) })
        ),
        (
            Attempt(
                id: UUID(uuidString: "a7e3d9c1-5b2f-4e6a-9d8c-7b6a5f4e3d03")!,
                examID: removedExamID,
                examTitle: "Đề đã xoá khỏi thư viện",
                candidateName: "Lê Chi",
                mode: .exam,
                startedAt: Date(timeIntervalSinceReferenceDate: 812_200_000),
                submittedAt: Date(timeIntervalSinceReferenceDate: 812_200_900),
                elapsedSeconds: 900,
                correct: 8,
                total: 10,
                score1000: 800,
                percent: 80,
                passed: true
            ),
            Data()
        ),
    ]
}

/// Bảo vệ dữ liệu người dùng qua các phiên bản app: kho do bản app dùng `LibrarySchemaV1` tạo ra phải mở
/// được bằng code hiện tại, đủ dữ liệu, không bị coi là kho hỏng (bị dời sang `.broken-…` thì người dùng mất
/// thư viện và lịch sử thi).
@MainActor
@Suite("Kho v1 thật")
struct LibraryV1FixtureTests {
    @Test("Kho v1 đã commit mở được bằng code hiện tại: đủ mục, lần thi, payload; không bị dời đi")
    func opensCommittedV1Store() throws {
        let workspace = try TestWorkspace()
        let directory = try workspace.makeDirectory("AppSupport")
        let storeURL = directory.appendingPathComponent("Library.store")
        try FileManager.default.copyItem(at: try #require(LibraryV1Fixture.bundledURL), to: storeURL)

        let opened = LibraryPersistence.openPersistent(at: storeURL, now: Date())

        #expect(opened.issue == nil)
        #expect(opened.repository is SwiftDataLibraryRepository)
        let expectedRecords = LibraryV1Fixture.records.sorted { $0.addedAt < $1.addedAt }
        #expect(try opened.repository.fetchEntries() == expectedRecords)
        let expectedAttempts = LibraryV1Fixture.attempts.map(\.attempt).sorted(by: Attempt.newestFirst)
        #expect(try opened.repository.fetchAttempts() == expectedAttempts)
        for (attempt, payload) in LibraryV1Fixture.attempts {
            #expect(try opened.repository.attemptPayload(id: attempt.id) == payload)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(!names.contains { $0.contains(".broken") })
    }

    @Test("Hash phiên bản model của kho v1 đã commit trùng với kho vừa tạo bằng LibrarySchemaV1 hiện tại")
    func v1ModelHashesUnchanged() throws {
        let workspace = try TestWorkspace()
        let fresh = workspace.url("fresh/Library.store")
        try FileManager.default.createDirectory(at: fresh.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try LibraryPersistence.makeContainer(storeURL: fresh)
        let committed = workspace.url("committed/Library.store")
        try FileManager.default.createDirectory(at: committed.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: try #require(LibraryV1Fixture.bundledURL), to: committed)

        let expected = try Self.modelVersionHashes(of: committed)
        let current = try Self.modelVersionHashes(of: fresh)

        // Bất kỳ thay đổi nào ở LibrarySchemaV1 (thêm, bỏ, đổi tên, đổi kiểu thuộc tính) đổi hash của thực thể,
        // kể cả thay đổi mà CoreData tự chuyển đổi được (thêm thuộc tính tuỳ chọn) nên test mở kho không bắt được.
        #expect(Set(expected.keys) == ["LibraryItem", "AttemptItem"])
        #expect(current == expected)
    }

    /// `NSStoreModelVersionHashes` trong metadata của kho SQLite: hash của từng thực thể theo id.
    static func modelVersionHashes(of url: URL) throws -> [String: Data] {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: url)
        return try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
    }

    @Test("Thư viện mở từ kho v1: hiện đủ mục và lịch sử thi; file không có trên máy thì Không tìm thấy file")
    func libraryLoadsV1Store() async throws {
        let workspace = try TestWorkspace()
        let config = workspace.configuration(mode: .strict)
        try FileManager.default.createDirectory(
            at: config.storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: try #require(LibraryV1Fixture.bundledURL), to: config.storeURL)

        let store = LibraryStore.persistent(configuration: config, defaults: workspace.defaults)
        store.load()

        #expect(store.storeIssue == nil)
        #expect(store.lastStorageError == nil)
        #expect(store.entries.map(\.examID) == [
            LibraryV1Fixture.sampleExamID, LibraryV1Fixture.userExamID, LibraryV1Fixture.newerExamID,
        ])
        #expect(store.entry(LibraryV1Fixture.sampleExamID)?.isSample == true)
        #expect(store.entry(LibraryV1Fixture.userExamID)?.lastOpenedAt != nil)
        #expect(store.entries.allSatisfy { $0.status == .checking })
        #expect(store.attempts.count == 3)
        #expect(store.latestAttempt(examID: LibraryV1Fixture.removedExamID)?.examTitle == "Đề đã xoá khỏi thư viện")

        await store.refreshAll()

        #expect(store.entries.allSatisfy { $0.status == .missing })
        #expect(!store.isRefreshing)
    }

    /// Tạo lại `Fixtures/Library-v1.store`. Chỉ chạy khi được yêu cầu, và chỉ khi V1 còn là schema mới nhất:
    ///
    ///     REGENERATE_LIBRARY_V1_FIXTURE=1 swift test --package-path Packages/ExamFeatures \
    ///         --filter LibraryV1FixtureTests/regenerateV1Fixture
    ///
    /// Khi đã có V2, fixture V1 là bằng chứng của kho người dùng đang có: không tạo lại, thêm generator V2.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["REGENERATE_LIBRARY_V1_FIXTURE"] == "1"))
    func regenerateV1Fixture() throws {
        try #require(
            LibraryMigrationPlan.schemas.count == 1,
            "V1 không còn là schema mới nhất: giữ nguyên fixture V1, tạo fixture mới cho schema mới."
        )
        let output = LibraryV1Fixture.sourceURL
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? fileManager.removeItem(atPath: output.path + suffix)
        }
        try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Ghi bằng đường ghi thật của app (container + repository) vào thư mục tạm.
        let workspace = try TestWorkspace()
        let staging = workspace.url("staging/Library.store")
        try fileManager.createDirectory(at: staging.deletingLastPathComponent(), withIntermediateDirectories: true)
        let repository = SwiftDataLibraryRepository(container: try LibraryPersistence.makeContainer(storeURL: staging))
        try repository.saveEntries(LibraryV1Fixture.records)
        for (attempt, payload) in LibraryV1Fixture.attempts {
            try repository.insertAttempt(attempt, payload: payload)
        }
        // CoreData còn giữ kết nối tới file trong thư mục tạm: chép file chính và WAL (không chép -shm, SQLite
        // tự dựng lại từ WAL) sang chỗ đích rồi gộp WAL ở đó.
        for suffix in ["", "-wal"] where fileManager.fileExists(atPath: staging.path + suffix) {
            try fileManager.copyItem(atPath: staging.path + suffix, toPath: output.path + suffix)
        }
        try SQLiteFile.checkpointIntoSingleFile(output)
        #expect(!fileManager.fileExists(atPath: output.path + "-wal"))
        #expect(!fileManager.fileExists(atPath: output.path + "-shm"))
    }
}

/// Gộp nhật ký WAL vào file SQLite chính và chuyển sang chế độ nhật ký thường, để kho nằm trọn trong một file.
enum SQLiteFile {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func checkpointIntoSingleFile(_ url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(database)
            throw Failure(description: "Không mở được \(url.path) bằng SQLite.")
        }
        var message: UnsafeMutablePointer<CChar>?
        let sql = "PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE;"
        let status = sqlite3_exec(database, sql, nil, nil, &message)
        sqlite3_close(database)
        guard status == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "lỗi không rõ"
            sqlite3_free(message)
            throw Failure(description: "Không gộp được WAL: \(text)")
        }
        // Không còn ở chế độ WAL: file bộ nhớ chia sẻ còn sót lại không dùng nữa.
        try? FileManager.default.removeItem(atPath: url.path + "-shm")
    }
}
