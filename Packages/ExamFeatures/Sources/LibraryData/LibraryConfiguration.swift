import ExamFile
import Foundation

/// Cấu hình Thư viện theo bản app (docs/product/library.md, mục Lưu trữ và Thêm đề).
///
/// Hai bản app không sandbox, nên kho mặc định của SwiftData sẽ bị hai bản dùng chung một file;
/// vì vậy mỗi bản có kho và thư mục đề mẫu riêng dưới
/// `~/Library/Application Support/<bundle ID>/`. Tạo cấu hình không đụng tới đĩa; thư mục chỉ
/// được tạo khi mở kho hoặc ghi đề mẫu.
public struct LibraryConfiguration: Sendable, Equatable {
    /// Bản Học viên `.strict`, bản Admin `.lenient` (docs/product/exam-format.md).
    public var readMode: ReadMode
    /// `true` ở bản Admin (vai Editor của kiểu `.exam`); giao diện dùng để hiện **Sửa**.
    public var isAdmin: Bool
    /// File kho SwiftData: `~/Library/Application Support/<bundle ID>/Library.store`.
    public var storeURL: URL
    /// Nơi ghi file đề mẫu: `~/Library/Application Support/<bundle ID>/Samples/`.
    public var samplesDirectoryURL: URL
    /// Thư mục nguồn đề mẫu, mỗi đề một thư mục con gồm `exam.json` và `media/` (mặc định:
    /// `Resources/Samples` trong bundle của LibraryData). `nil` hoặc thư mục rỗng: không có đề mẫu.
    public var samplesSourceURL: URL?
    /// Số file đề đọc cùng lúc khi làm mới, nhập file hoặc ghi đề mẫu. Nhỏ hơn 1 được coi là 1.
    public var maxConcurrentReads: Int
    /// Dấu của bộ kiểm file. Kết luận đọc file được lưu kèm dấu này; khi dấu đổi (app cập nhật,
    /// hiểu thêm phiên bản định dạng) thì lần làm mới sau đọc lại mọi file, kể cả file không đổi,
    /// để đề "Cần app mới hơn" không kẹt ở trạng thái cũ sau khi cập nhật app.
    public var checkFingerprint: String

    public init(
        readMode: ReadMode,
        isAdmin: Bool,
        storeURL: URL,
        samplesDirectoryURL: URL,
        samplesSourceURL: URL?,
        maxConcurrentReads: Int = LibraryConfiguration.defaultMaxConcurrentReads,
        checkFingerprint: String = LibraryConfiguration.defaultCheckFingerprint
    ) {
        self.readMode = readMode
        self.isAdmin = isAdmin
        self.storeURL = storeURL
        self.samplesDirectoryURL = samplesDirectoryURL
        self.samplesSourceURL = samplesSourceURL
        self.maxConcurrentReads = maxConcurrentReads
        self.checkFingerprint = checkFingerprint
    }

    // MARK: - Theo bản app

    /// Bundle ID của bản Học viên, khớp `project.yml` và ADR 0003.
    public static let studentBundleIdentifier = "vn.io.nt0.examsuite"
    /// Bundle ID của bản Admin, khớp `project.yml` và ADR 0003.
    public static let adminBundleIdentifier = "vn.io.nt0.examsuite.admin"

    /// Tên file kho trong thư mục của bản app.
    public static let storeFileName = "Library.store"
    /// Tên thư mục đề mẫu trong thư mục của bản app.
    public static let samplesDirectoryName = "Samples"

    /// Bản Học viên: đọc nghiêm, kho trong `Application Support/vn.io.nt0.examsuite/`.
    public static var student: LibraryConfiguration {
        forApp(bundleIdentifier: studentBundleIdentifier, isAdmin: false)
    }

    /// Bản Admin: đọc dễ, kho trong `Application Support/vn.io.nt0.examsuite.admin/`.
    public static var admin: LibraryConfiguration {
        forApp(bundleIdentifier: adminBundleIdentifier, isAdmin: true)
    }

    /// Cấu hình của một bản app theo bundle ID: `<applicationSupportDirectory>/<bundle ID>/Library.store`
    /// và `.../Samples/`; Admin đọc `.lenient`, Học viên `.strict`.
    /// - Parameter applicationSupportDirectory: mặc định `~/Library/Application Support` của người dùng
    ///   (app không sandbox); test truyền thư mục tạm.
    public static func forApp(
        bundleIdentifier: String,
        isAdmin: Bool,
        applicationSupportDirectory: URL = .applicationSupportDirectory
    ) -> LibraryConfiguration {
        let base = applicationSupportDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        return LibraryConfiguration(
            readMode: isAdmin ? .lenient : .strict,
            isAdmin: isAdmin,
            storeURL: base.appendingPathComponent(storeFileName, isDirectory: false),
            samplesDirectoryURL: base.appendingPathComponent(samplesDirectoryName, isDirectory: true),
            samplesSourceURL: bundledSamplesURL
        )
    }

    // MARK: - Mặc định

    /// Đọc nền tối đa 4 file một lúc: đủ nhanh cho thư viện vài trăm đề, và giới hạn bộ nhớ khi
    /// gặp đề lớn (mỗi lần đọc nạp cả ảnh của đề vào bộ nhớ).
    public static let defaultMaxConcurrentReads = 4

    /// Thư mục đề mẫu trong bundle của LibraryData (`Resources/Samples`, chép nguyên thư mục).
    public static var bundledSamplesURL: URL? {
        Bundle.module.url(forResource: samplesDirectoryName, withExtension: nil)
    }

    /// Phiên bản định dạng app hiểu + phiên bản app đang chạy.
    public static var defaultCheckFingerprint: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "format v\(ExamFileFormat.currentVersion); app \(version) (\(build))"
    }
}
