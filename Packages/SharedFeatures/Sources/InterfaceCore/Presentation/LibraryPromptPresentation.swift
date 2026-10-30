import Foundation
import LibraryData

/// Chữ của hộp hỏi Thư viện (trùng id: Dùng file mới / Huỷ; thông báo), dùng chung bản macOS và bản iOS. "File không
/// thêm được" (`importProblems`) là danh sách riêng, không phải hộp hỏi.
extension LibraryPrompt {
    public var isAlert: Bool {
        if case .importProblems = kind { return false }
        return true
    }

    public var alertTitle: String {
        switch kind {
        case .replace:
            localized("Đề này đã có trong thư viện từ file khác")
        case .message(let title, _):
            title
        case .importProblems:
            ""
        }
    }

    public var alertMessage: String {
        switch kind {
        case .replace(let pending):
            localized("“\(pending.title)” đang dùng file:\n\(pending.existingFileURL.path)\n\nDùng file mới?\n\(pending.newFileURL.path)")
        case .message(_, let message):
            message
        case .importProblems:
            ""
        }
    }
}
