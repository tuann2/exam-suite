import Foundation
import LibraryData

/// File `.exam` mở từ app khác (docs/product/mobile.md, mục Bản iOS, QI12).
///
/// - Hộp chia sẻ, "Mở bằng" (Zalo, Mail, AirDrop…): iOS chép file vào thư mục `Inbox` của app (`Documents/Inbox`) rồi
///   giao URL đó. `Inbox` không phải chỗ lưu lâu dài (app không được tạo file ở đó, iOS có thể dọn), nên app dời file
///   sang `Application Support/<bundle ID>/Received/` rồi thêm như mọi file: bookmark tới bản đã dời. Nhận lại cùng đề
///   là file khác nên hỏi Dùng file mới / Huỷ như macOS; Xoá khỏi thư viện không xoá bản đã dời.
/// - App Tệp mở file tại chỗ (`LSSupportsOpeningDocumentsInPlace`): không dời, thêm bằng bookmark trong lúc mở quyền
///   security scope như file chọn bằng hộp chọn file (`SecurityScopedAccess`).
public struct ReceivedFiles: Sendable {
    /// Thư mục giữ file đã dời khỏi `Inbox`.
    public let directory: URL
    /// `Documents/Inbox` của app.
    public let inboxDirectory: URL

    public init(directory: URL, inboxDirectory: URL) {
        self.directory = directory
        self.inboxDirectory = inboxDirectory
    }

    /// Thư mục của bản app: `Received/` cạnh kho thư viện (UI test: trong thư mục cô lập), `Inbox` trong `Documents`
    /// của container.
    public init(configuration: LibraryConfiguration) {
        self.init(
            directory: configuration.storeURL.deletingLastPathComponent()
                .appendingPathComponent("Received", isDirectory: true),
            inboxDirectory: URL.documentsDirectory.appendingPathComponent("Inbox", isDirectory: true)
        )
    }

    /// File nằm trong `Inbox` của app (đường dẫn thật, đã giải symlink).
    public func isInInbox(_ url: URL) -> Bool {
        let inbox = inboxDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let file = url.resolvingSymlinksInPath().standardizedFileURL.path
        return file.hasPrefix(inbox + "/")
    }

    /// URL để thêm vào Thư viện: file trong `Inbox` được dời sang `directory` (tên đã có thì thêm số: "Đề 2.exam");
    /// file khác giữ nguyên. Chạy ngoài main actor (thao tác file).
    public func adopt(_ url: URL) throws -> URL {
        guard isInInbox(url) else { return url }
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = Self.freeName(for: url.lastPathComponent, in: directory)
        try manager.moveItem(at: url, to: destination)
        return destination
    }

    /// Tên chưa có trong `directory`: giữ tên gốc, trùng thì thêm " 2", " 3"… trước đuôi.
    static func freeName(for fileName: String, in directory: URL) -> URL {
        let manager = FileManager.default
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(fileName, isDirectory: false)
        var number = 2
        while manager.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
            candidate = directory.appendingPathComponent(name, isDirectory: false)
            number += 1
        }
        return candidate
    }
}
