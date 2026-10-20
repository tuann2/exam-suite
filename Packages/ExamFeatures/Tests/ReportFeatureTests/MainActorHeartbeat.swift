import Foundation

/// Đo main actor có bị chặn không (như `MainActorHeartbeat` của LibraryDataTests): một task trên main actor ngủ 5 ms rồi
/// ghi lại khoảng cách giữa hai lần thức. Main actor bị chặn X ms thì sẽ có khoảng cách ≥ X ms.
@MainActor
final class MainActorHeartbeat {
    private(set) var longestGap: Duration = .zero
    private(set) var beats = 0
    private var task: Task<Void, Never>?

    func start() {
        task = Task { @MainActor in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
                let now = clock.now
                longestGap = max(longestGap, now - last)
                beats += 1
                last = now
            }
        }
    }

    func stop() async {
        task?.cancel()
        await task?.value
    }
}
