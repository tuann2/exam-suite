import ExamFile
import ExamKit
import Foundation

/// Vì sao một file đề không dùng được, dạng mã và đối số: giao diện (InterfaceCore, `ErrorMessages`) dựng câu báo
/// bằng chữ của String Catalog theo ngôn ngữ giao diện (docs/product/accessibility-localization.md, phương án 2).
/// `logMessage` là câu tiếng Việt cho nhật ký, test, và là chữ lưu trong kho (`verdictReason` của `LibrarySchemaV1`,
/// giữ đúng chữ trước bước 7b).
public enum FileProblemReason: Hashable, Sendable {
    /// Lỗi đọc gói của ExamFile (không gồm lỗi kiểm đề: xem `validationFailed`).
    case package(ExamFileError)
    /// Đề vi phạm ràng buộc kiểm đề (đọc nghiêm): số lỗi mức error và lỗi đầu tiên. Chỉ giữ lỗi đầu, không giữ cả danh
    /// sách (đề 2.000 câu có thể có hàng nghìn lỗi).
    case validationFailed(errorCount: Int, first: ValidationIssue?)
    /// Lỗi của hệ thống khi đọc file (không có quyền, ổ lỗi…). Tham số: mô tả của macOS (đã theo ngôn ngữ của app).
    case unreadable(systemDescription: String)
    /// File chọn không có ở đường dẫn đó.
    case fileNotFound(fileName: String)
    /// File chọn nằm trong Thùng rác.
    case inTrash(fileName: String)
    /// Không tạo được bookmark tới file.
    case bookmarkFailed(fileName: String)
    /// Đọc file quá thời hạn.
    case readTimedOut(fileName: String)
    /// Đề mẫu trong bundle không đọc được. Tham số: mô tả kỹ thuật của lỗi.
    case sampleUnreadable(String)
    /// Không ghi được file đề mẫu.
    case sampleNotWritten(fileName: String)
    /// Lý do đọc từ kho, ghi ở lần chạy trước (chữ tiếng Việt). Kho chỉ lưu chữ (`LibrarySchemaV1` không đổi), nên kết
    /// luận mang lý do này không được dùng lại: lần làm mới kế tiếp đọc lại file (`FileVerdict.isReusable`), và trạng
    /// thái trên giao diện luôn đến từ lần đọc trong lần chạy này. Giao diện hiện nguyên chữ nếu gặp (preview, snapshot).
    case stored(String)

    /// Lý do cho một lỗi khi đọc file đề: `ExamFileError` (lỗi kiểm đề rút gọn còn số lỗi và lỗi đầu), hoặc mô tả của
    /// hệ thống.
    public init(_ error: any Error) {
        if let error = error as? ExamFileError {
            if case let .validationFailed(issues) = error {
                self = .validationFailed(errorCount: issues.count, first: issues.first)
            } else {
                self = .package(error)
            }
        } else {
            self = .unreadable(systemDescription: error.localizedDescription)
        }
    }

    /// Câu tiếng Việt (nhật ký, test, chữ lưu trong kho): đúng câu trước bước 7b.
    public var logMessage: String {
        switch self {
        case let .package(error):
            error.errorDescription ?? "\(error)"
        case let .validationFailed(count, first):
            Self.validationMessage(errorCount: count, first: first)
        case let .unreadable(description):
            "Không đọc được file: \(description)"
        case let .fileNotFound(fileName):
            "Không tìm thấy file \"\(fileName)\"."
        case let .inTrash(fileName):
            "File \"\(fileName)\" đang nằm trong Thùng rác. Hãy chuyển file ra khỏi Thùng rác rồi thêm lại."
        case let .bookmarkFailed(fileName):
            "Không tạo được liên kết tới file \"\(fileName)\"."
        case let .readTimedOut(fileName):
            "Đọc file \"\(fileName)\" quá lâu."
        case let .sampleUnreadable(detail):
            "Không đọc được đề mẫu: \(detail)"
        case let .sampleNotWritten(fileName):
            "Không ghi được file đề mẫu \(fileName)."
        case let .stored(text):
            text
        }
    }

    /// Như `ExamFileError.validationFailed(…).errorDescription` khi chỉ còn số lỗi và lỗi đầu.
    private static func validationMessage(errorCount: Int, first: ValidationIssue?) -> String {
        guard let first else { return "Đề có lỗi, không mở được." }
        if errorCount == 1 { return "Đề có 1 lỗi, không mở được: \(first.message)" }
        return "Đề có \(errorCount) lỗi, không mở được. Lỗi đầu tiên: \(first.message)"
    }
}
