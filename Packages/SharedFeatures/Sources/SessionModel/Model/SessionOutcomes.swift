import Foundation

/// Phản hồi khi yêu cầu mở Trước khi thi hoặc một lần thi.
public enum SessionOpenOutcome: Hashable, Sendable {
    case opened
    /// Đang có bài chưa nộp: bản macOS đưa cửa sổ làm bài lên trước; `notice` là "Đang có bài chưa nộp".
    case blockedByUnsubmittedSession
    /// Không mở được; lý do tiếng Việt (cũng ở `notice`).
    case failed(String)
}

/// Thông báo không chặn cho Thư viện (điều phối phiên thi của bản macOS và bản iOS).
public struct SessionNotice: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let message: String

    public init(message: String, id: UUID = UUID()) {
        self.id = id
        self.message = message
    }
}
