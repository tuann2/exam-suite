import Foundation

/// Nguồn thời gian của phiên thi, tiêm từ ngoài (docs/product/exam-session.md, mục Đồng hồ).
///
/// `ExamSession` không tự chạy đồng hồ (không Timer, không DispatchQueue, không async):
/// mỗi lệnh đọc đồng hồ một lần và tính thời gian theo mốc. Test dùng đồng hồ giả để
/// điều khiển thời gian; app dùng `SystemSessionClock`.
///
/// Có hai nguồn tách biệt:
/// - `now()`: giờ hệ thống, CHỈ để ghi mốc (`startedAt`, `submittedAt`). Người dùng chỉnh
///   được giờ hệ thống nên không dùng để đo thời gian làm bài.
/// - `uptime()`: đồng hồ đơn điệu (giây, gốc tuỳ ý nhưng cố định cho một đồng hồ), không lùi
///   khi chỉnh giờ máy và không chạy khi máy ngủ. Mọi phép đo thời gian đã làm, thời gian
///   còn lại, cảnh báo và hết giờ đều dùng nguồn này.
public protocol SessionClock: Sendable {
    /// Giờ hệ thống hiện tại, để ghi mốc.
    func now() -> Date
    /// Thời gian đơn điệu, giây; chỉ có nghĩa khi lấy hiệu hai lần đọc của cùng đồng hồ.
    func uptime() -> TimeInterval
}

/// Đồng hồ thật: `Date()` cho mốc, `SuspendingClock` của thư viện chuẩn cho phép đo.
///
/// `SuspendingClock` đơn điệu và không tăng khi máy ngủ (Darwin: `CLOCK_UPTIME_RAW`;
/// Linux: `CLOCK_MONOTONIC`), nên kể cả khi app lỡ thông báo máy ngủ, thời gian ngủ
/// cũng không bị trừ vào bài thi.
public struct SystemSessionClock: SessionClock {
    private let origin: SuspendingClock.Instant

    public init() {
        origin = SuspendingClock().now
    }

    public func now() -> Date { Date() }

    public func uptime() -> TimeInterval {
        let d = origin.duration(to: SuspendingClock().now)
        let (seconds, attoseconds) = d.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) * 1e-18
    }
}
