import Foundation
import OSLog

/// Lỗi của các lệnh trên `LibraryStore`, dạng mã và đối số: giao diện dựng câu báo bằng chữ của String Catalog
/// (InterfaceCore, `ErrorMessages`; docs/product/accessibility-localization.md, phương án 2). `logMessage` là câu
/// tiếng Việt cho nhật ký và test. Không theo `LocalizedError`, để chữ tiếng Việt này không tự lọt ra giao diện qua
/// `localizedDescription`.
public enum LibraryError: Error, Hashable, Sendable {
    /// Không có mục nào với id đề này trong thư viện.
    case entryNotFound(examID: UUID)
    /// File chọn không phải file `.exam`.
    case notAnExamFile(URL)
    /// File chọn không dùng được (hỏng, cần app mới hơn, hoặc bản Học viên không mở được).
    case unusableFile(LibraryFileProblem)
    /// **Tìm file…**: file chọn là một đề khác (khác id đề) nên không thay được.
    case differentExam(expectedTitle: String, foundTitle: String)
    /// **Hoàn tác**: đề đã được thêm lại vào thư viện trong lúc chờ hoàn tác.
    case alreadyInLibrary(examID: UUID)
    /// Lần thi có id này đã được lưu.
    case duplicateAttempt(id: UUID)
    /// Kho không lưu/đọc được. Tham số: mô tả của lỗi gốc (của hệ thống).
    case storage(String)
}

extension LibraryError {
    /// Câu tiếng Việt cho nhật ký và test (giao diện không dùng).
    public var logMessage: String {
        switch self {
        case .entryNotFound:
            "Đề không còn trong thư viện."
        case let .notAnExamFile(url):
            "\"\(url.lastPathComponent)\" không phải file đề .exam."
        case let .unusableFile(problem):
            "Không dùng được file này: \(problem.logMessage)"
        case let .differentExam(expectedTitle, foundTitle):
            "File chọn là đề \"\(foundTitle)\", không phải đề \"\(expectedTitle)\". Hãy chọn đúng file của đề này."
        case .alreadyInLibrary:
            "Đề đã có lại trong thư viện nên không hoàn tác được."
        case .duplicateAttempt:
            "Lần thi này đã được lưu."
        case let .storage(detail):
            "Không lưu được thư viện: \(detail)"
        }
    }
}

/// Sự cố của kho cần báo người dùng bằng thông báo không chặn (docs/product/library.md, mục Lưu trữ).
public enum LibraryStoreIssue: Hashable, Sendable {
    /// Kho cũ không mở được, đã được đổi tên thành `brokenStoreURL`; thư viện bắt đầu lại từ kho mới trống.
    case recoveredFromBrokenStore(brokenStoreURL: URL)
    /// Không mở hay tạo được kho trên đĩa; thư viện đang dùng kho tạm, mất khi thoát app.
    case temporaryStore(reason: String)

    /// Câu tiếng Việt cho nhật ký và test (giao diện dựng câu của catalog, InterfaceCore).
    public var logMessage: String {
        switch self {
        case let .recoveredFromBrokenStore(url):
            "Không mở được dữ liệu thư viện cũ nên app đã tạo thư viện mới. "
                + "Dữ liệu cũ được giữ ở \"\(url.lastPathComponent)\" trong \(url.deletingLastPathComponent().path)."
        case let .temporaryStore(reason):
            "Không lưu được thư viện vào đĩa (\(reason)). Thay đổi trong lần mở app này sẽ mất khi thoát."
        }
    }
}

/// Nhật ký của LibraryData (Console.app, subsystem theo bundle ID của app).
enum LibraryLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? LibraryConfiguration.studentBundleIdentifier
    static let store = Logger(subsystem: subsystem, category: "library.store")
    static let files = Logger(subsystem: subsystem, category: "library.files")
}
