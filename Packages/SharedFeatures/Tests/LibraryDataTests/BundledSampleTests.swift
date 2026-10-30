import ExamFile
import ExamKit
import Foundation
@testable import LibraryData
import Testing

/// Đề mẫu thật trong bundle của LibraryData (docs/product/library.md, mục "Đề mẫu và lần đầu mở app"):
/// bundle chép đủ thư mục đề mẫu của repo, mỗi đề đọc nghiêm được không vấn đề nào, ghi ra thư mục
/// tạm thì thêm đủ mục đề mẫu, xoá rồi khôi phục thì thêm lại đúng mục đã xoá.
@MainActor
@Suite("Đề mẫu thật trong bundle")
struct BundledSampleTests {
    /// Thư mục đề mẫu trong repo (`Sources/LibraryData/Resources/Samples`), tính từ vị trí file này.
    static let sourceSamples: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // LibraryDataTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // SharedFeatures
        .appendingPathComponent("Sources/LibraryData/Resources/Samples", isDirectory: true)

    /// Tên các mục không ẩn trong một thư mục, theo tên.
    static func visibleNames(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    static func bundledSamples() throws -> URL {
        try #require(LibraryConfiguration.bundledSamplesURL)
    }

    /// Id đề và tên file `.exam` mà app ghi ra cho mỗi đề mẫu trong bundle, theo tên thư mục.
    static func expectedSamples() throws -> [(id: UUID, fileName: String)] {
        var used = Set<String>()
        return try SampleSource.sampleDirectories(in: bundledSamples()).map { directory in
            let package = try SampleSource.loadPackage(from: directory)
            return (package.exam.id, SampleSource.uniqueFileName(forTitle: package.exam.title, used: &used))
        }
    }

    static func sortedIDs(_ ids: [UUID]) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }

    @Test("Bundle chứa đúng các thư mục đề mẫu của repo (không tính file ẩn), đủ 2 đề như library.md")
    func bundleMatchesRepository() throws {
        let bundled = try Self.bundledSamples()
        let names = try Self.visibleNames(in: bundled)

        #expect(names == (try Self.visibleNames(in: Self.sourceSamples)))
        #expect(names.count == 2)
        // Mỗi mục là một thư mục đề mẫu (có exam.json), không có file lẻ.
        #expect(SampleSource.sampleDirectories(in: bundled).map(\.lastPathComponent) == names)
    }

    @Test("Mỗi đề mẫu trong bundle đọc nghiêm được, không lỗi, không cảnh báo, không thiếu ảnh")
    func bundledSamplesReadStrictlyWithoutIssues() throws {
        let directories = SampleSource.sampleDirectories(in: try Self.bundledSamples())
        #expect(!directories.isEmpty)
        for directory in directories {
            let name = directory.lastPathComponent
            let written = try ExamPackageWriter.write(SampleSource.loadPackage(from: directory))
            let package = try ExamPackageReader.read(written, mode: .strict)
            #expect(package.validationIssues.isEmpty, "\(name): \(package.validationIssues.map(\.message))")
            #expect(package.missingMedia.isEmpty, "\(name)")
            #expect(!package.media.isEmpty, "\(name): đề mẫu có ảnh tự tạo")
        }
    }

    @Test("Ghi đề mẫu thật vào thư mục tạm: thêm đủ mục đề mẫu, Sẵn sàng, tên file theo tiêu đề",
          arguments: [ReadMode.strict, .lenient])
    func seedsAllBundledSamples(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: mode, samples: try Self.bundledSamples())
        let expected = try Self.expectedSamples()

        let report = await store.seedSamplesIfNeeded()

        #expect(report.failures.isEmpty)
        #expect(report.sampleCount == expected.count)
        #expect(Set(report.addedExamIDs) == Set(expected.map(\.id)))
        #expect(store.entries.count == expected.count)
        #expect(store.entries.allSatisfy { $0.isSample && $0.status == .ready })
        #expect(store.hasSeededSamples)
        let directory = store.configuration.samplesDirectoryURL
        #expect(try Self.visibleNames(in: directory) == expected.map(\.fileName).sorted())
        for sample in expected {
            let entry = try #require(store.entry(sample.id))
            #expect(sameFile(entry.fileURL, directory.appendingPathComponent(sample.fileName)))
        }
        // Chỉ ghi trong thư mục tạm của test, không đụng Application Support thật.
        #expect(directory.path.hasPrefix(workspace.root.path))
    }

    @Test("Xoá đề mẫu thật rồi Khôi phục đề mẫu: thêm lại đúng các mục đã xoá, giữ nguyên mục còn lại")
    func restoreReaddsRemovedSamples() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(samples: try Self.bundledSamples())
        await store.seedSamplesIfNeeded()
        let ids = try Self.expectedSamples().map(\.id)
        let removedID = try #require(ids.first)
        let keptID = try #require(ids.last)
        #expect(removedID != keptID)
        let kept = try #require(store.entry(keptID))
        try store.remove(removedID)
        #expect(store.entry(removedID) == nil)

        let report = await store.restoreSamples()

        #expect(report.failures.isEmpty)
        #expect(report.addedExamIDs == [removedID])
        #expect(report.keptExamIDs == [keptID])
        #expect(store.entries.count == ids.count)
        let restored = try #require(store.entry(removedID))
        #expect(restored.isSample)
        #expect(restored.status == .ready)
        #expect(store.entry(keptID) == kept)

        // Xoá hết rồi khôi phục: đủ lại mọi đề mẫu, không mục trùng.
        for id in ids { try store.remove(id) }
        let all = await store.restoreSamples()
        #expect(Self.sortedIDs(all.addedExamIDs) == Self.sortedIDs(ids))
        #expect(Self.sortedIDs(store.entries.map(\.examID)) == Self.sortedIDs(ids))
        #expect(store.entries.allSatisfy { $0.isSample && $0.status == .ready })
    }

    /// UI test luồng 2 (Apps/StudentUITests/ExamFlowUITests.swift) chọn một lựa chọn SAI ở câu 1 để Kết quả luôn có câu
    /// sai (nút Xem câu sai): nó đọc nội dung lựa chọn và tránh các nội dung trong
    /// Apps/UITestSupport/Fixtures/attt-correct-options.json. File đó phải đúng là tập nội dung lựa chọn đúng của đề mẫu
    /// "An toàn thông tin cơ bản", không trùng nội dung lựa chọn sai nào, và câu nào cũng có ít nhất một lựa chọn sai.
    @Test("File nội dung lựa chọn đúng của UI test khớp đề mẫu An toàn thông tin cơ bản")
    func uiTestCorrectOptionTextsMatchSample() throws {
        let fixture = RepoFixtures.root.deletingLastPathComponent() // gốc repo
            .appendingPathComponent("Apps/UITestSupport/Fixtures/attt-correct-options.json")
        let listed = try JSONDecoder().decode([String].self, from: Data(contentsOf: fixture))
        let package = try SampleSource.loadPackage(
            from: Self.sourceSamples.appendingPathComponent("an-toan-thong-tin-co-ban", isDirectory: true)
        )
        var correct = Set<String>()
        var wrong = Set<String>()
        for question in package.exam.sections.flatMap(\.questions) {
            let correctIDs = Set(question.correct)
            let wrongOptions = question.options.filter { !correctIDs.contains($0.id) }
            #expect(!wrongOptions.isEmpty, "câu \(question.id) không có lựa chọn sai")
            for option in question.options {
                if correctIDs.contains(option.id) { correct.insert(option.text) } else { wrong.insert(option.text) }
            }
        }
        #expect(Set(listed) == correct)
        // StudentFlow so với nhãn trợ năng của lựa chọn, là chữ đã bỏ định dạng Markdown: nội dung lựa chọn đúng có ký
        // tự Markdown thì nhãn khác nội dung trong file, lựa chọn đúng bị coi là sai. Cấm ký tự Markdown ở đây.
        let markdown = Set("*_`[]#\\<>~|!&")
        for text in listed {
            #expect(!text.contains(where: markdown.contains), "nội dung lựa chọn đúng có ký tự Markdown: \(text)")
        }
        #expect(listed.count == correct.count, "file có nội dung lặp")
        #expect(correct.isDisjoint(with: wrong), "nội dung vừa đúng ở câu này vừa sai ở câu khác: \(correct.intersection(wrong))")
    }
}
