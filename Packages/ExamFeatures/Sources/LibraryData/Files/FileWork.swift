import Foundation

/// Nơi chạy việc chặn luồng với file: đọc gói đề, phân giải bookmark, ghi đề mẫu.
///
/// Không chạy thẳng trong task của Swift concurrency: thread pool hợp tác chỉ có số luồng bằng số nhân
/// CPU, việc chặn luồng ở đó làm đói mọi task khác, kể cả task trên main actor đang chờ được đánh thức
/// (đo được: 16 lần đọc đề 2.000 câu cùng lúc trên máy 12 nhân làm main actor trễ 1,7 giây; CI 3 nhân
/// trễ 1,2 giây với 4 lần đọc). Hàng đợi GCD này có luồng riêng; task chỉ chờ kết quả qua continuation,
/// không giữ luồng của pool. Số việc cùng lúc do người gọi giới hạn (`maxConcurrentReads`).
enum FileWork {
    static let queue = DispatchQueue(
        label: "vn.io.nt0.examsuite.library.files",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Hàng đợi riêng cho đồng hồ hết hạn, để hết hạn vẫn báo đúng giờ khi mọi luồng của `queue` đang bận.
    private static let deadlineQueue = DispatchQueue(
        label: "vn.io.nt0.examsuite.library.files.deadline",
        qos: .userInitiated
    )

    /// Chạy `work` trên `queue` và chờ kết quả, không chiếm luồng của Swift concurrency.
    static func run<Output: Sendable>(_ work: @escaping @Sendable () -> Output) async -> Output {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }

    /// Như `run(_:)` nhưng chỉ chờ tối đa `timeout`; quá hạn thì trả `nil`.
    ///
    /// Việc đang chặn luồng (ví dụ đọc file trên ổ mạng không phản hồi) không dừng được nên vẫn chạy tới
    /// khi xong; kết quả về muộn bị bỏ. Continuation được resume đúng một lần dù việc xong và hết hạn
    /// xảy ra cùng lúc (`ResumeOnce`).
    static func run<Output: Sendable>(
        timeout: Duration,
        _ work: @escaping @Sendable () -> Output
    ) async -> Output? {
        await run(deadline: deadline(after: timeout), work)
    }

    /// Như `run(timeout:_:)` nhưng thời điểm hết hạn do `deadline` quyết định. Bản app luôn dùng
    /// `deadline(after:)`; test truyền hạn do test tự kích hoạt để kết quả không lệ thuộc tốc độ máy.
    /// `deadline` được hẹn trước khi việc được đưa vào `queue`.
    static func run<Output: Sendable>(
        deadline: FileWorkDeadline,
        _ work: @escaping @Sendable () -> Output
    ) async -> Output? {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            deadline { once.resume(nil) }
            queue.async { once.resume(work()) }
        }
    }

    /// Hết hạn theo đồng hồ sau `timeout`, tính từ lúc hẹn (trên hàng đợi riêng `deadlineQueue`).
    static func deadline(after timeout: Duration) -> FileWorkDeadline {
        { expire in
            deadlineQueue.asyncAfter(deadline: .now() + timeout.timeInterval, execute: expire)
        }
    }
}

/// Hẹn giờ hết hạn cho một việc của `FileWork.run(deadline:_:)`: gọi `expire` khi hết hạn (từ luồng bất
/// kỳ, nhiều nhất một lần có tác dụng). Bản app: `FileWork.deadline(after:)`.
typealias FileWorkDeadline = @Sendable (_ expire: @escaping @Sendable () -> Void) -> Void

/// Các mục đang có lần kiểm file chạy trên hàng đợi file, kể cả lần đã quá hạn mà vẫn còn treo.
/// Lần làm mới sau bỏ qua những mục này thay vì mở thêm lần đọc nữa cho đúng file đang treo (mỗi lần đọc
/// treo giữ một luồng GCD). Việc đọc tự đánh dấu khi bắt đầu và bỏ đánh dấu khi xong, kể cả khi xong muộn.
final class InFlightReads: @unchecked Sendable {
    private let lock = NSLock()
    private var running: Set<UUID> = []

    func contains(_ id: UUID) -> Bool {
        lock.withLock { running.contains(id) }
    }

    /// Chạy `work` trong lúc `id` được đánh dấu là đang đọc.
    func track<Output>(_ id: UUID, _ work: () -> Output) -> Output {
        lock.withLock { _ = running.insert(id) }
        defer { lock.withLock { _ = running.remove(id) } }
        return work()
    }
}

/// Resume một continuation đúng một lần, dù nhiều bên gọi cùng lúc; các lần gọi sau bị bỏ qua.
final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value?, Never>?

    init(_ continuation: CheckedContinuation<Value?, Never>) {
        self.continuation = continuation
    }

    /// - Returns: `true` nếu lần gọi này là lần resume (lần đầu).
    @discardableResult
    func resume(_ value: Value?) -> Bool {
        let pending: CheckedContinuation<Value?, Never>? = lock.withLock {
            defer { continuation = nil }
            return continuation
        }
        guard let pending else { return false }
        pending.resume(returning: value)
        return true
    }
}

extension Duration {
    /// Số giây, cho các API của Dispatch.
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
