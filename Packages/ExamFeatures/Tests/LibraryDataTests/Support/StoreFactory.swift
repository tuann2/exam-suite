import ExamFile
import Foundation
@testable import LibraryData
import Testing

/// Repository dùng cho test: chạy cùng kịch bản trên cả bản trong bộ nhớ và bản SwiftData.
enum RepositoryKind: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case memory
    case swiftData

    var testDescription: String { rawValue }

    @MainActor
    func make() -> any LibraryRepository {
        switch self {
        case .memory: InMemoryLibraryRepository()
        case .swiftData: LibraryPersistence.inMemoryRepository()
        }
    }
}

/// Đồng hồ giả, chỉnh được từ test.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_790_000_000)) {
        current = start
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }

    var function: @Sendable () -> Date {
        { [self] in now }
    }
}

/// Bộ đọc gói đề ghi lại số lần đọc, có lần nào chạy trên main thread không, và số lần đọc cùng lúc
/// nhiều nhất. `delay`: mỗi lần đọc chờ thêm chừng ấy giây (để các lần đọc chồng lên nhau).
final class ReadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let delay: TimeInterval
    private var reads: [String: Int] = [:]
    private var onMainThread = 0
    private var inFlight = 0
    private var peak = 0

    init(delay: TimeInterval = 0) {
        self.delay = delay
    }

    var reader: ExamFileInspector.Reader {
        { [self] url, mode in
            let isMain = Thread.isMainThread
            lock.withLock {
                reads[url.lastPathComponent, default: 0] += 1
                if isMain { onMainThread += 1 }
                inFlight += 1
                peak = max(peak, inFlight)
            }
            defer { lock.withLock { inFlight -= 1 } }
            if delay > 0 { Thread.sleep(forTimeInterval: delay) }
            return try ExamPackageReader.read(contentsOf: url, mode: mode)
        }
    }

    var totalReads: Int { lock.withLock { reads.values.reduce(0, +) } }
    var mainThreadReads: Int { lock.withLock { onMainThread } }
    /// Số lần đọc chạy cùng lúc nhiều nhất từ lần `resetPeak()` trước.
    var peakConcurrentReads: Int { lock.withLock { peak } }

    func resetPeak() {
        lock.withLock { peak = inFlight }
    }

    func reads(of fileName: String) -> Int {
        lock.withLock { reads[fileName, default: 0] }
    }
}

extension TestWorkspace {
    func configuration(
        mode: ReadMode,
        samples: URL? = nil,
        maxConcurrentReads: Int = 4,
        fingerprint: String = "test-v1"
    ) -> LibraryConfiguration {
        LibraryConfiguration(
            readMode: mode,
            isAdmin: mode == .lenient,
            storeURL: url("AppSupport/Library.store"),
            samplesDirectoryURL: root.appendingPathComponent("AppSupport/Samples", isDirectory: true),
            samplesSourceURL: samples,
            maxConcurrentReads: maxConcurrentReads,
            checkFingerprint: fingerprint
        )
    }

    /// Store test: kho trong bộ nhớ (hoặc repository truyền vào), đường dẫn trong thư mục tạm.
    @MainActor
    func makeStore(
        mode: ReadMode = .strict,
        repository: (any LibraryRepository)? = nil,
        kind: RepositoryKind = .swiftData,
        samples: URL? = nil,
        recorder: ReadRecorder? = nil,
        reader: ExamFileInspector.Reader? = nil,
        clock: TestClock? = nil,
        maxConcurrentReads: Int = 4,
        fingerprint: String = "test-v1",
        refreshReadTimeout: Duration = LibraryStore.defaultRefreshReadTimeout,
        refreshDeadline: (@Sendable (UUID) -> FileWorkDeadline)? = nil
    ) -> LibraryStore {
        let config = configuration(
            mode: mode,
            samples: samples,
            maxConcurrentReads: maxConcurrentReads,
            fingerprint: fingerprint
        )
        let reader: ExamFileInspector.Reader = reader ?? recorder?.reader ?? ExamFileInspector.defaultReader
        let now: @Sendable () -> Date
        if let clock {
            now = clock.function
        } else {
            now = { Date() }
        }
        return LibraryStore(
            configuration: config,
            repository: repository ?? kind.make(),
            defaults: defaults,
            inspector: ExamFileInspector(reader: reader),
            now: now,
            refreshReadTimeout: refreshReadTimeout,
            refreshDeadline: refreshDeadline
        )
    }
}

/// Bộ đọc chặn lại (như đọc file trên ổ mạng không phản hồi) với file có tên trong `blocked` cho tới khi
/// `release()`; đếm số lần đọc đã xong theo tên file.
final class ReadGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var blocked: Set<String> = []
    private var onBlocked: [String: @Sendable () -> Void] = [:]
    private var finished: [String: Int] = [:]
    private var started: [String: Int] = [:]

    /// Chặn các lần đọc `fileName` từ giờ. `onBlocked` chạy (trên luồng đọc, ngoài khoá) mỗi khi một lần
    /// đọc bắt đầu bị chặn, để test phản ứng đúng lúc lần đọc đã treo thay vì chờ theo đồng hồ.
    func block(_ fileName: String, onBlocked: (@Sendable () -> Void)? = nil) {
        condition.withLock {
            _ = blocked.insert(fileName)
            self.onBlocked[fileName] = onBlocked
        }
    }

    func release() {
        condition.withLock {
            blocked.removeAll()
            onBlocked.removeAll()
            condition.broadcast()
        }
    }

    func finishedReads(of fileName: String) -> Int {
        condition.withLock { finished[fileName, default: 0] }
    }

    /// Số lần đọc đã bắt đầu (kể cả lần đang bị chặn).
    func startedReads(of fileName: String) -> Int {
        condition.withLock { started[fileName, default: 0] }
    }

    var reader: ExamFileInspector.Reader {
        { [self] url, mode in
            let name = url.lastPathComponent
            let hook: (@Sendable () -> Void)? = condition.withLock {
                started[name, default: 0] += 1
                return blocked.contains(name) ? onBlocked[name] : nil
            }
            hook?()
            condition.withLock {
                while blocked.contains(name) { condition.wait() }
            }
            defer { condition.withLock { finished[name, default: 0] += 1 } }
            return try ExamPackageReader.read(contentsOf: url, mode: mode)
        }
    }
}

/// Hạn của lần kiểm file khi làm mới do test quyết định thay cho đồng hồ (`LibraryStore.refreshDeadline`):
/// lần kiểm chỉ hết hạn khi test gọi `expire(_:)`, nên máy bận đến đâu lần đọc bình thường cũng không bị
/// coi là treo. `useClock(_:forNextCheckOf:)` cho một lần kiểm đi đường của bản app (hết hạn theo đồng hồ).
final class TestDeadlines: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [UUID: [@Sendable () -> Void]] = [:]
    private var clockTimeouts: [UUID: Duration] = [:]

    var deadline: @Sendable (UUID) -> FileWorkDeadline {
        { [self] examID in { [self] expire in schedule(examID, expire) } }
    }

    private func schedule(_ examID: UUID, _ expire: @escaping @Sendable () -> Void) {
        let timeout = lock.withLock { () -> Duration? in
            if let timeout = clockTimeouts.removeValue(forKey: examID) { return timeout }
            pending[examID, default: []].append(expire)
            return nil
        }
        if let timeout { FileWork.deadline(after: timeout)(expire) }
    }

    /// Lần kiểm kế tiếp của `examID` hết hạn theo đồng hồ sau `timeout` (`FileWork.deadline(after:)`).
    func useClock(_ timeout: Duration, forNextCheckOf examID: UUID) {
        lock.withLock { clockTimeouts[examID] = timeout }
    }

    /// Cho hết hạn ngay mọi lần kiểm của `examID` đã hẹn mà chưa hết hạn.
    func expire(_ examID: UUID) {
        let callbacks = lock.withLock { pending.removeValue(forKey: examID) ?? [] }
        for callback in callbacks { callback() }
    }
}

/// Chờ tối đa `timeout` cho tới khi `condition` đúng (kiểm mỗi 10 ms).
func waitUntil(timeout: Duration = .seconds(5), _ condition: @Sendable () -> Bool) async throws -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline { return false }
        try await Task.sleep(for: .milliseconds(10))
    }
    return true
}

/// So hai đường dẫn file theo file thật (`stat`), không theo chuỗi.
func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
    guard let left = FileIdentity(url: lhs), let right = FileIdentity(url: rhs) else { return false }
    return left == right
}
