import ExamFile
import ExamKit
import Foundation
@testable import LibraryData
import Testing

@MainActor
@Suite("Đề mẫu")
struct SampleTests {
    /// Nguồn đề mẫu giả trong thư mục tạm, dựng từ fixture (nội dung đề mẫu thật do bước 2 soạn).
    static func makeSource(_ workspace: TestWorkspace, fixtures: [String] = ["kien-thuc-chung", "toi-thieu"]) throws -> URL {
        let source = try workspace.makeDirectory("Bundle/Samples")
        try Data().write(to: source.appendingPathComponent(".gitkeep"))
        for name in fixtures {
            try FileManager.default.copyItem(
                at: RepoFixtures.examDirectory(name),
                to: source.appendingPathComponent(name, isDirectory: true)
            )
        }
        return source
    }

    @Test("Lần đầu: ghi đề mẫu ra thư mục Samples (tên theo tiêu đề), thêm với cờ đề mẫu; chỉ một lần", arguments: RepositoryKind.allCases)
    func seedsOnce(kind: RepositoryKind) async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(kind: kind, samples: try Self.makeSource(workspace))
        let samples = store.configuration.samplesDirectoryURL
        #expect(!store.hasSeededSamples)

        let report = await store.seedSamplesIfNeeded()

        let tinyID = try RepoFixtures.package("toi-thieu").exam.id
        #expect(report.sampleCount == 2)
        #expect(report.failures.isEmpty)
        #expect(report.didAddSamples)
        #expect(Set(report.addedExamIDs) == [RepoFixtures.kienThucChungID, tinyID])
        #expect(store.entries.count == 2)
        #expect(store.entries.allSatisfy { $0.isSample && $0.status == .ready })
        #expect(store.hasSeededSamples)
        #expect(workspace.defaults.bool(forKey: LibraryStore.samplesSeededKey))
        let files = try FileManager.default.contentsOfDirectory(atPath: samples.path).sorted()
        #expect(files == ["Kiến thức chung.exam", "Đề tối thiểu.exam"].sorted())
        let entry = try #require(store.entry(RepoFixtures.kienThucChungID))
        #expect(sameFile(entry.fileURL, samples.appendingPathComponent("Kiến thức chung.exam")))
        // Ghi bằng ExamPackageWriter: đọc nghiêm lại được, kèm ảnh.
        let written = try ExamPackageReader.read(contentsOf: entry.fileURL, mode: .strict)
        #expect(written == (try RepoFixtures.package("kien-thuc-chung")))

        let second = await store.seedSamplesIfNeeded()
        #expect(second == SampleReport())
        #expect(store.entries.count == 2)
    }

    @Test("Xoá đề mẫu khỏi thư viện thì không tự tạo lại; Khôi phục đề mẫu thêm lại, không trùng")
    func removalAndRestore() async throws {
        let workspace = try TestWorkspace()
        let clock = TestClock()
        let store = workspace.makeStore(samples: try Self.makeSource(workspace), clock: clock)
        await store.seedSamplesIfNeeded()
        let tinyID = try RepoFixtures.package("toi-thieu").exam.id
        let keptBefore = try #require(store.entry(RepoFixtures.kienThucChungID))
        try store.remove(tinyID)

        await store.seedSamplesIfNeeded()
        #expect(store.entry(tinyID) == nil)

        // Người dùng sửa file đề mẫu đã xoá khỏi thư viện: khôi phục ghi lại bản gốc.
        let tinyFile = store.configuration.samplesDirectoryURL.appendingPathComponent("Đề tối thiểu.exam")
        try Data("file đã bị sửa hỏng".utf8).write(to: tinyFile)
        clock.advance(by: 600)
        let report = await store.restoreSamples()

        #expect(report.sampleCount == 2)
        #expect(report.addedExamIDs == [tinyID])
        #expect(report.keptExamIDs == [RepoFixtures.kienThucChungID])
        #expect(store.entries.count == 2)
        let restored = try #require(store.entry(tinyID))
        #expect(restored.isSample)
        #expect(restored.status == .ready)
        #expect(restored.addedAt == clock.now)
        #expect(try ExamPackageReader.read(contentsOf: tinyFile, mode: .strict).exam.id == tinyID)
        // Mục đề mẫu còn trong thư viện giữ nguyên.
        #expect(store.entry(RepoFixtures.kienThucChungID) == keptBefore)

        let again = await store.restoreSamples()
        #expect(again.addedExamIDs.isEmpty)
        #expect(store.entries.count == 2)
    }

    @Test("Khôi phục ghi lại file cho đề mẫu còn trong thư viện nhưng mất file")
    func restoreRewritesMissingFile() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(samples: try Self.makeSource(workspace))
        await store.seedSamplesIfNeeded()
        let addedAt = try #require(store.entry(RepoFixtures.kienThucChungID)).addedAt
        try FileManager.default.removeItem(at: store.configuration.samplesDirectoryURL)
        await store.refreshAll()
        #expect(store.entries.allSatisfy { $0.status == .missing })

        let report = await store.restoreSamples()

        #expect(report.addedExamIDs.count == 2)
        #expect(store.entries.count == 2)
        #expect(store.entries.allSatisfy { $0.status == .ready && $0.isSample })
        #expect(store.entry(RepoFixtures.kienThucChungID)?.addedAt == addedAt)
        await store.refreshAll()
        #expect(store.entries.allSatisfy { $0.status == .ready })
    }

    @Test("Nguồn đề mẫu rỗng hoặc không có: không làm gì, không lỗi, chưa bật cờ")
    func emptySource() async throws {
        let workspace = try TestWorkspace()
        let empty = workspace.makeStore(samples: try Self.makeSource(workspace, fixtures: []))
        let none = workspace.makeStore(samples: nil)

        #expect(await empty.seedSamplesIfNeeded() == SampleReport())
        #expect(await none.seedSamplesIfNeeded() == SampleReport())
        #expect(await empty.restoreSamples() == SampleReport())
        #expect(empty.entries.isEmpty)
        #expect(!empty.hasSeededSamples)
        #expect(!workspace.exists(empty.configuration.samplesDirectoryURL))
    }

    @Test("Đề mẫu lỗi: báo lỗi, các đề khác vẫn được thêm, chưa bật cờ để lần sau thử lại")
    func failingSample() async throws {
        let workspace = try TestWorkspace()
        let source = try Self.makeSource(workspace, fixtures: ["toi-thieu"])
        let broken = try workspace.makeDirectory("Bundle/Samples/hong")
        try Data("{ không phải JSON".utf8).write(to: broken.appendingPathComponent("exam.json"))
        let store = workspace.makeStore(samples: source)

        let report = await store.seedSamplesIfNeeded()

        #expect(report.sampleCount == 2)
        #expect(report.failures.map(\.sampleName) == ["hong"])
        #expect(report.addedExamIDs.count == 1)
        #expect(!store.hasSeededSamples)
    }

    @Test("Đề mẫu trong bundle (nếu có) thêm được ở cả hai bản app, không lỗi", arguments: [ReadMode.strict, .lenient])
    func bundledSamplesInstallCleanly(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let bundled = try #require(LibraryConfiguration.bundledSamplesURL)
        let store = workspace.makeStore(mode: mode, samples: bundled)

        let report = await store.seedSamplesIfNeeded()

        #expect(report.failures.isEmpty)
        #expect(report.addedExamIDs.count == report.sampleCount)
        #expect(store.entries.allSatisfy { $0.status == .ready && $0.isSample })
    }

    @Test("Tên file đề mẫu không quá 255 byte, cắt ở ranh giới ký tự, kể cả tiêu đề dài toàn chữ có dấu")
    func sampleFileNamesFitAPFS() throws {
        let workspace = try TestWorkspace()
        let directory = try workspace.makeDirectory("Samples")
        // 200 ký tự, mỗi ký tự 3 byte dựng sẵn, 5 byte khi tách dấu: vượt xa 255 byte.
        let title = String(repeating: "Đề kiểm tra kiến thức tổng hợp về an toàn thông tin ", count: 4)
        var used = Set<String>()
        let first = SampleSource.uniqueFileName(forTitle: title, used: &used)
        let second = SampleSource.uniqueFileName(forTitle: title, used: &used)

        for name in [first, second] {
            #expect(SampleSource.fileNameBytes(name) <= 255)
            #expect(name.utf8.count <= 255)
            #expect(name.hasSuffix(".exam"))
            // Ghi được thật trên ổ đĩa.
            try Data("x".utf8).write(to: directory.appendingPathComponent(name))
        }
        #expect(second.hasSuffix(" 2.exam"))
        #expect(first != second)
        // Cắt ở ranh giới ký tự: phần tên là phần đầu nguyên vẹn của tiêu đề, không có ký tự bị tách.
        let stem = String(first.dropLast(".exam".count))
        #expect(title.hasPrefix(stem))
        #expect(stem.unicodeScalars.last.map { !CharacterSet.nonBaseCharacters.contains($0) } == true)
        // Tên không cắt thì hệ thống file từ chối: giới hạn là thật.
        #expect(throws: (any Error).self) {
            try Data("x".utf8).write(to: directory.appendingPathComponent(title + ".exam"))
        }
        // Tên ngắn giữ nguyên.
        #expect(SampleSource.fileName(forTitle: "Làm quen với Exam Suite") == "Làm quen với Exam Suite.exam")
    }

    @Test("Đề mẫu có tiêu đề rất dài vẫn được ghi và thêm vào thư viện")
    func seedsSampleWithVeryLongTitle() async throws {
        let workspace = try TestWorkspace()
        let source = try workspace.makeDirectory("Bundle/Samples/dai")
        let title = String(repeating: "Ôn tập nghiệp vụ ngân hàng ", count: 7)
        try ExamJSON.encode(makeExam(title: String(title.prefix(200)))).write(to: source.appendingPathComponent("exam.json"))
        let store = workspace.makeStore(samples: source.deletingLastPathComponent())

        let report = await store.seedSamplesIfNeeded()

        #expect(report.failures.isEmpty)
        #expect(report.addedExamIDs.count == 1)
        #expect(store.entries.first?.status == .ready)
        let names = try FileManager.default.contentsOfDirectory(atPath: store.configuration.samplesDirectoryURL.path)
        #expect(names.count == 1)
        #expect(names.allSatisfy { SampleSource.fileNameBytes($0) <= 255 })
    }

    @Test("Tên file theo tiêu đề: bỏ ký tự cấm, không trùng")
    func sampleFileNames() {
        #expect(SampleSource.fileName(forTitle: "Toán: đại số/hình học") == "Toán- đại số-hình học.exam")
        #expect(SampleSource.fileName(forTitle: "..ẩn") == "ẩn.exam")
        #expect(SampleSource.fileName(forTitle: "  ") == "Đề mẫu.exam")
        var used = Set<String>()
        #expect(SampleSource.uniqueFileName(forTitle: "Đề", used: &used) == "Đề.exam")
        #expect(SampleSource.uniqueFileName(forTitle: "đề", used: &used) == "đề 2.exam")
        #expect(SampleSource.uniqueFileName(forTitle: "Đề", used: &used) == "Đề 3.exam")
    }
}
