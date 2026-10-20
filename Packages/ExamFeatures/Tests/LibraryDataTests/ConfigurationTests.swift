import ExamFile
import Foundation
@testable import LibraryData
import Testing
import UniformTypeIdentifiers

@Suite("Cấu hình theo bản app")
struct ConfigurationTests {
    @Test("Bản Học viên và bản Admin có kho và thư mục đề mẫu riêng theo bundle ID")
    func separateStorePerApp() {
        let student = LibraryConfiguration.student
        let admin = LibraryConfiguration.admin

        #expect(student.storeURL != admin.storeURL)
        #expect(student.samplesDirectoryURL != admin.samplesDirectoryURL)

        let support = URL.applicationSupportDirectory.standardizedFileURL.path
        #expect(student.storeURL.standardizedFileURL.path == "\(support)/vn.io.nt0.examsuite/Library.store")
        #expect(admin.storeURL.standardizedFileURL.path == "\(support)/vn.io.nt0.examsuite.admin/Library.store")
        #expect(student.samplesDirectoryURL.standardizedFileURL.path == "\(support)/vn.io.nt0.examsuite/Samples")
        #expect(admin.samplesDirectoryURL.standardizedFileURL.path == "\(support)/vn.io.nt0.examsuite.admin/Samples")
        // Không dùng kho mặc định của SwiftData (default.store dùng chung khi không sandbox).
        #expect(student.storeURL.lastPathComponent == "Library.store")
    }

    @Test("Học viên đọc nghiêm, Admin đọc dễ")
    func readModePerApp() {
        #expect(LibraryConfiguration.student.readMode == .strict)
        #expect(!LibraryConfiguration.student.isAdmin)
        #expect(LibraryConfiguration.admin.readMode == .lenient)
        #expect(LibraryConfiguration.admin.isAdmin)
    }

    @Test("forApp tính đường dẫn theo bundle ID dưới thư mục cho trước, không tạo gì trên đĩa")
    func forAppUsesBaseDirectory() throws {
        let workspace = try TestWorkspace()
        let base = workspace.root.appendingPathComponent("Application Support", isDirectory: true)
        let config = LibraryConfiguration.forApp(
            bundleIdentifier: "vn.io.nt0.test",
            isAdmin: true,
            applicationSupportDirectory: base
        )
        #expect(config.storeURL.path == base.path + "/vn.io.nt0.test/Library.store")
        #expect(config.samplesDirectoryURL.path == base.path + "/vn.io.nt0.test/Samples")
        #expect(config.readMode == .lenient)
        #expect(config.maxConcurrentReads == LibraryConfiguration.defaultMaxConcurrentReads)
        #expect(!workspace.exists(base))
    }

    @Test("Dấu bộ kiểm gồm phiên bản định dạng app hiểu")
    func fingerprintMentionsFormatVersion() {
        #expect(LibraryConfiguration.defaultCheckFingerprint.contains("format v\(ExamFileFormat.currentVersion)"))
    }

    @Test("Thư mục đề mẫu có trong bundle của LibraryData")
    func bundledSamplesDirectoryExists() throws {
        let url = try #require(LibraryConfiguration.bundledSamplesURL)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(LibraryConfiguration.student.samplesSourceURL == url)
    }

    @Test("UTType.examPackage là vn.io.nt0.exam")
    func examPackageType() {
        #expect(UTType.examPackage.identifier == ExamFileFormat.uniformTypeIdentifier)
        #expect(UTType.examPackage.identifier == "vn.io.nt0.exam")
    }
}
