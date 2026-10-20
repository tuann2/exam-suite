import AuthoringData
import ExamFile
import ExamKit
import Foundation
import UniformTypeIdentifiers

/// Lỗi đọc file ảnh trước khi đưa vào đề.
public enum ImageFileError: Error, Equatable, Sendable, LocalizedError {
    /// URL không phải file trên máy (ví dụ ảnh kéo từ trình duyệt).
    case notAFile
    /// Không đọc được file hay kích thước của nó. Tham số: tên file.
    case unreadable(String)
    /// Câu đã bị xoá trong lúc đọc file ảnh.
    case questionRemoved

    public var errorDescription: String? {
        switch self {
        case .notAFile:
            localized("Chỉ thêm được ảnh từ file trên máy. Lưu ảnh về máy rồi kéo file vào, hoặc dùng Thêm ảnh….")
        case let .unreadable(name):
            localized("Không đọc được file ảnh “\(name)”.")
        case .questionRemoved:
            localized("Câu đã bị xoá trong lúc đọc file ảnh; ảnh không được thêm.")
        }
    }
}

/// Đọc file ảnh người dùng chọn hoặc kéo vào trình soạn câu (docs/product/authoring.md, mục Ảnh): giữ nguyên
/// byte gốc. Chỉ nhận file trên máy; kiểm loại và kích thước **trước khi** đọc cả file, để ảnh vượt giới hạn bị từ
/// chối ngay với lý do mà không phải nạp hàng trăm MB vào bộ nhớ. Giới hạn của cả gói (tổng dung lượng, số ảnh) do
/// `ExamDraft.setImage` kiểm.
public enum ImageFileLoader {
    /// Loại file mở được trong hộp chọn ảnh.
    public static let contentTypes: [UTType] = [.png, .jpeg, .gif, .webP, .heic]

    public struct Loaded: Sendable {
        public let data: Data
        /// Đuôi file gốc, không có dấu chấm.
        public let fileExtension: String
    }

    /// Đọc ảnh ở `url`. Chạy ngoài main actor (file có thể lớn).
    public static func load(_ url: URL, limits: ExamPackageLimits = .default) throws -> Loaded {
        guard url.isFileURL else { throw ImageFileError.notAFile }
        let ext = url.pathExtension
        guard MediaNaming.allowedExtensions.contains(ext.lowercased()) else {
            throw ExamEditError.unsupportedImageType(ext.isEmpty ? url.lastPathComponent : ext)
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw ImageFileError.unreadable(url.lastPathComponent)
        }
        guard size <= limits.mediaEntryBytes else {
            throw ExamEditError.imageTooLarge(bytes: size, limit: limits.mediaEntryBytes)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ImageFileError.unreadable(url.lastPathComponent)
        }
        // File có thể lớn lên giữa lúc đo và lúc đọc.
        guard data.count <= limits.mediaEntryBytes else {
            throw ExamEditError.imageTooLarge(bytes: data.count, limit: limits.mediaEntryBytes)
        }
        return Loaded(data: data, fileExtension: ext)
    }
}

extension AuthoringEditor {
    /// Đọc file ảnh ở nền rồi thêm/thay ảnh của câu `path`; lỗi thì báo, đề không đổi.
    ///
    /// Đọc file mất thời gian, trong lúc đó cây đề có thể đổi (xoá câu, Hoàn tác, kéo thả): ảnh áp vào **đúng câu**
    /// đã thả (theo `id`, tìm lại vị trí nếu câu đã dời chỗ); câu đã bị xoá thì bỏ và báo.
    public func importImage(from url: URL, to path: QuestionPath) async {
        await importImage(from: url, to: path) { try ImageFileLoader.load($0) }
    }

    func importImage(
        from url: URL, to path: QuestionPath,
        load: @escaping @Sendable (URL) async throws -> ImageFileLoader.Loaded
    ) async {
        guard let question = question(at: path) else { return }
        let questionID = question.id
        let replacing = question.image != nil
        do {
            let loaded = try await Task.detached(priority: .userInitiated) { try await load(url) }.value
            guard let target = currentPath(of: questionID, near: path) else { throw ImageFileError.questionRemoved }
            setImage(of: target, data: loaded.data, fileExtension: loaded.fileExtension)
        } catch {
            reportImageError(error, replacing: replacing)
        }
    }

    /// Vị trí hiện tại của câu `id`: `path` nếu câu vẫn ở đó; không thì câu cùng `id` gần `path` nhất (đề đọc dễ có
    /// thể có id trùng: không lấy đại lần xuất hiện đầu); `nil` nếu không còn câu nào có `id` đó.
    func currentPath(of id: UUID, near path: QuestionPath) -> QuestionPath? {
        if question(at: path)?.id == id { return path }
        var candidates: [QuestionPath] = []
        for (si, section) in draft.exam.sections.enumerated() {
            for (qi, question) in section.questions.enumerated() where question.id == id {
                candidates.append(QuestionPath(section: si, question: qi))
            }
        }
        let origin = (section: path.section, question: path.question)
        return candidates.min { a, b in
            TreeSelection.distance(origin, (a.section, a.question)) < TreeSelection.distance(origin, (b.section, b.question))
        }
    }
}
