import Foundation
import LibraryData

/// Bước tiếp theo hiện trên thẻ theo trạng thái (bảng trạng thái của docs/product/library.md).
public enum EntryNextStep: Hashable, Sendable {
    /// **Tìm file…**: chọn lại file của đề (`LibraryStore.relocate`).
    case locateFile
    /// **Xoá khỏi thư viện**.
    case removeFromLibrary
    /// "Cập nhật Exam Suite": lời nhắc, chưa có nút tự cập nhật.
    case updateApp
    /// **Sửa** (chỉ bản Admin): mở đề trong cửa sổ soạn đề.
    case edit
}

/// Cách hiện một trạng thái của đề: luôn có biểu tượng **và** chữ, màu chỉ để nhấn thêm
/// (docs/product/library.md: "Trạng thái của đề, luôn bằng biểu tượng + chữ, không chỉ dựa vào màu").
public struct EntryStatusPresentation: Hashable, Sendable {
    /// Mức độ, giao diện đổi thành màu (xanh, xám, cam, đỏ).
    public enum Tone: Hashable, Sendable {
        case positive
        case neutral
        case warning
        case critical
    }

    /// Tên trạng thái, ví dụ "Sẵn sàng", "File hỏng".
    public let title: String
    /// Tên SF Symbol, khác nhau giữa các trạng thái của cùng một bản app.
    public let systemImage: String
    public let tone: Tone
    /// Lý do hoặc giải thích ngắn; `nil` với Sẵn sàng và Đang kiểm tra.
    public let detail: String?
    /// Bước tiếp theo trên thẻ, theo thứ tự hiện.
    public let nextSteps: [EntryNextStep]
    /// Thứ tự khi sắp theo cột Trạng thái: Sẵn sàng trước, rồi tới các vấn đề.
    public let sortRank: Int

    public init(status: LibraryEntryStatus, isAdmin: Bool) {
        switch status {
        case .ready:
            title = localized("Sẵn sàng")
            systemImage = "checkmark.circle.fill"
            tone = .positive
            detail = nil
            nextSteps = []
            sortRank = 0
        case .checking:
            title = localized("Đang kiểm tra")
            systemImage = "clock.arrow.circlepath"
            tone = .neutral
            detail = nil
            nextSteps = []
            sortRank = 1
        case .readableWithIssues(let reason):
            // Bản Admin: đọc dễ được nhưng bản Học viên sẽ từ chối.
            title = localized("Có lỗi")
            systemImage = "exclamationmark.triangle.fill"
            tone = .warning
            detail = localized("Bản Học viên sẽ không mở được đề này: \(ErrorMessages.message(for: reason))")
            nextSteps = isAdmin ? [.edit] : [.removeFromLibrary]
            sortRank = 2
        case .invalid(let reason):
            title = localized("Đề có lỗi")
            systemImage = "exclamationmark.triangle.fill"
            tone = .critical
            detail = ErrorMessages.message(for: reason)
            nextSteps = [.removeFromLibrary]
            sortRank = 3
        case .needsNewerApp:
            title = localized("Cần app mới hơn")
            systemImage = "arrow.up.circle.fill"
            tone = .warning
            detail = status.reason.map { ErrorMessages.message(for: $0) }
            nextSteps = [.updateApp, .removeFromLibrary]
            sortRank = 4
        case .missing:
            title = localized("Không tìm thấy file")
            systemImage = "questionmark.folder.fill"
            tone = .warning
            detail = localized("File không còn ở chỗ cũ: đã bị xoá, chuyển sang nơi khác hoặc nằm trên ổ chưa gắn.")
            nextSteps = [.locateFile, .removeFromLibrary]
            sortRank = 5
        case .corrupt(let reason):
            title = localized("File hỏng")
            systemImage = "xmark.octagon.fill"
            tone = .critical
            detail = ErrorMessages.message(for: reason)
            nextSteps = [.removeFromLibrary]
            sortRank = 6
        }
    }

    /// Lời nhắc cho bước "Cập nhật Exam Suite" (chưa có nút tự cập nhật).
    public static var updateAppHint: String {
        localized("Cập nhật Exam Suite lên bản mới hơn để mở đề này.")
    }
}
