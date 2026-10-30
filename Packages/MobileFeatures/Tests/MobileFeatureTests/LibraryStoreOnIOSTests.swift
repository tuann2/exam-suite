import ExamFile
import ExamKit
import Foundation
import LibraryData
import Testing

/// Kho thư viện của LibraryData chạy được trên iOS (docs/product/plan-ios-v1.md bước I1; đã thử ở spike I0). Logic đã
/// có test ở LibraryDataTests trên macOS; test này chỉ kiểm phần phụ thuộc nền tảng: kho SwiftData mở được, đề mẫu đọc
/// từ bundle của LibraryData trong app iOS, bookmark tìm lại file khi thư mục chứa nó đổi chỗ (như container của app
/// đổi đường dẫn sau khi cập nhật app).
@Suite("Kho thư viện trên iOS")
@MainActor
struct LibraryStoreOnIOSTests {
    @Test("Kho mở, đề mẫu được tạo, bookmark tìm lại file khi thư mục đổi chỗ")
    func storeSamplesAndMovedFolder() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileFeatureTests-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = try #require(UserDefaults(suiteName: "MobileFeatureTests-\(UUID().uuidString)"))
        let configuration = LibraryConfiguration.forApp(
            bundleIdentifier: LibraryConfiguration.iosBundleIdentifier,
            isAdmin: false,
            applicationSupportDirectory: root.appendingPathComponent("Application Support", isDirectory: true)
        )

        // Kho mở, đề mẫu chép từ bundle của LibraryData và đọc nghiêm được.
        let samples = try #require(LibraryConfiguration.bundledSamplesURL)
        let sampleCount = try FileManager.default.contentsOfDirectory(atPath: samples.path)
            .filter { !$0.hasPrefix(".") }.count
        let store = LibraryStore.persistent(configuration: configuration, defaults: defaults)
        #expect(store.storeIssue == nil)
        _ = await store.start()
        let sampleEntries = store.entries.filter(\.isSample)
        #expect(sampleCount > 0)
        #expect(sampleEntries.count == sampleCount)
        #expect(sampleEntries.allSatisfy { $0.status == .ready })

        // Đề thêm từ một thư mục; thư mục đổi chỗ thì làm mới vẫn tìm được file.
        let sample = try #require(sampleEntries.first)
        var package = try ExamPackageReader.read(contentsOf: sample.fileURL, mode: .strict)
        package.exam.id = UUID()
        let folder = root.appendingPathComponent("Documents/Đề tải về", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("Đề thử.exam")
        try ExamPackageWriter.write(package, to: file)
        let report = await store.importFiles([file])
        #expect(report.addedExamIDs == [package.exam.id])

        let movedFolder = root.appendingPathComponent("Documents 2/Đề tải về", isDirectory: true)
        try FileManager.default.createDirectory(at: movedFolder.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: folder, to: movedFolder)
        await store.refreshAll()
        let entry = try #require(store.entry(package.exam.id))
        #expect(entry.status == .ready)
        #expect(entry.fileURL.resolvingSymlinksInPath().path
            == movedFolder.appendingPathComponent("Đề thử.exam").resolvingSymlinksInPath().path)
    }
}
