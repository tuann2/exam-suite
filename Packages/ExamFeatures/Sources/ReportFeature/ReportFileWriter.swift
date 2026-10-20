import CoreGraphics
import Foundation

/// Vì sao không ghi được PDF ra chỗ người dùng chọn (docs/product/export-print.md, mục Tên file và hộp lưu: "lỗi ghi
/// thì báo lý do, không để file dở"). Câu báo là chữ của app (catalog), không dùng `localizedDescription` của hệ thống,
/// như lỗi đọc file đề của Xem lại.
public enum ReportWriteError: Error, Hashable, Sendable {
    /// Không có quyền ghi vào thư mục (hoặc thay file) đã chọn.
    case noPermission
    /// Ổ đĩa đầy (hoặc hết hạn mức).
    case outOfSpace
    /// Ổ đĩa chỉ đọc.
    case readOnlyVolume
    /// Thư mục đã chọn không còn.
    case folderMissing
    /// File PDF vừa ghi không đọc lại được (ví dụ ổ đĩa đầy giữa chừng: Core Graphics không báo lỗi ghi).
    case unreadableOutput
    /// Lỗi khác của hệ thống tệp.
    case failed

    /// Lý do hiện trong hộp báo lỗi.
    public var message: String {
        switch self {
        case .noPermission: ReportStrings.writeNoPermission
        case .outOfSpace: ReportStrings.writeOutOfSpace
        case .readOnlyVolume: ReportStrings.writeReadOnlyVolume
        case .folderMissing: ReportStrings.writeFolderMissing
        case .unreadableOutput: ReportStrings.writeUnreadableOutput
        case .failed: ReportStrings.writeFailed
        }
    }

    /// Lỗi `errno` của `open(2)`/`rename(2)`.
    init(errno code: Int32) {
        switch code {
        case EACCES, EPERM: self = .noPermission
        case ENOSPC, EDQUOT: self = .outOfSpace
        case EROFS: self = .readOnlyVolume
        case ENOENT, ENOTDIR: self = .folderMissing
        default: self = .failed
        }
    }

    /// Lý do cho mọi lỗi của lần xuất (không gồm huỷ): lỗi ghi có lý do riêng, còn lại là câu chung.
    public static func message(for error: any Error) -> String {
        (error as? ReportWriteError)?.message ?? ReportWriteError.failed.message
    }
}

/// **Xuất PDF…**: dựng PDF vào một file tạm ẩn **cùng thư mục** với file đích rồi `rename(2)` đè lên file đích (nguyên tử
/// trên cùng ổ đĩa), như `ExamPackageWriter` (docs/product/export-print.md: "Ghi file tạm rồi thay"). Lỗi hay huỷ ở bất
/// kỳ bước nào thì xoá file tạm; file đích (nếu đã có) giữ nguyên tới khi PDF mới đã ghi xong và đọc lại được. App thoát
/// **bình thường** giữa chừng (⌘Q, Thoát từ Dock, đăng xuất: sheet tiến độ không chặn thoát) thì file tạm được xoá lúc
/// `NSApplication.willTerminateNotification` (`ReportTemporaryFiles`); crash hay buộc thoát thì file tạm ẩn còn lại cạnh
/// file đích, như file tạm của `ExamPackageWriter`.
@MainActor
public enum ReportFileWriter {
    /// Ghi PDF của `document` ra `destination`.
    ///
    /// - Throws: `CancellationError` khi task bị huỷ (không để lại file nào), `ReportWriteError` khi không ghi được.
    public static func write(
        _ document: ReportDocument,
        to destination: URL,
        renderer: ReportRenderer = ReportRenderer(),
        progress: (ReportProgress) -> Void = { _ in }
    ) async throws -> ReportPDFFile {
        // Tạo file tạm trước khi dựng: thư mục không ghi được thì báo ngay, không chờ dựng xong cả nghìn trang.
        let temporary = try createTemporaryFile(for: destination)
        ReportTemporaryFiles.track(temporary)
        defer { ReportTemporaryFiles.untrack(temporary) }
        do {
            let file = try await renderer.render(document, to: temporary, progress: progress)
            // Đọc lại bảng tham chiếu ngoài main actor (PDF có thể ~100 MB, hàng nghìn trang).
            let pageCount = file.pageCount
            try await Task.detached(priority: .userInitiated) { try verify(temporary, pageCount: pageCount) }.value
            // Huỷ ngay trước khi thay: file đích cũ giữ nguyên.
            try Task.checkCancellation()
            try replace(destination, with: temporary)
            return ReportPDFFile(url: destination, pageCount: file.pageCount)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            if error is ReportRenderError { throw ReportWriteError.failed }
            throw error
        }
    }

    /// Tiền tố của file tạm (ẩn trong Finder).
    nonisolated static let temporaryPrefix = ".ExamSuite-"

    /// `.ExamSuite-<8 ký tự>.pdf.tmp` cạnh file đích: độ dài cố định (27 byte), nên tên file đích dài tới giới hạn 255 byte
    /// của APFS vẫn có file tạm hợp lệ (tên tạm không dựa trên tên đích).
    nonisolated static func temporaryURL(for destination: URL) -> URL {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
        return destination.deletingLastPathComponent()
            .appendingPathComponent("\(temporaryPrefix)\(token).pdf.tmp", isDirectory: false)
    }

    /// Tạo file tạm rỗng (`O_EXCL`: không bao giờ dùng lại file có sẵn; trùng tên thì thử tên khác) để biết sớm thư mục có
    /// ghi được không.
    nonisolated static func createTemporaryFile(for destination: URL) throws -> URL {
        for _ in 0 ..< 5 {
            let url = temporaryURL(for: destination)
            let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
                guard let path else { return -1 }
                return open(path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
            }
            if descriptor >= 0 {
                close(descriptor)
                return url
            }
            let code = errno
            if code != EEXIST { throw ReportWriteError(errno: code) }
        }
        throw ReportWriteError.failed
    }

    /// PDF vừa ghi đọc lại được và đủ số trang (Core Graphics không báo lỗi ghi, ví dụ ổ đĩa đầy giữa chừng). Chỉ đọc
    /// bảng tham chiếu, không đọc nội dung trang.
    nonisolated static func verify(_ url: URL, pageCount: Int) throws {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages == pageCount else {
            throw ReportWriteError.unreadableOutput
        }
    }

    /// `rename(2)` file tạm đè lên file đích.
    nonisolated static func replace(_ destination: URL, with temporary: URL) throws {
        let status = temporary.withUnsafeFileSystemRepresentation { source in
            destination.withUnsafeFileSystemRepresentation { target in
                guard let source, let target else { return Int32(-1) }
                return rename(source, target)
            }
        }
        if status != 0 { throw ReportWriteError(errno: errno) }
    }
}
