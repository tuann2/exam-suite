import Foundation
import LargeExamSupport
import Testing

/// Đối chứng cho thước đo main actor của test `Timing`: bắt được main actor bị chặn (kể cả khi chặn ngay sau
/// `start()`, trước lần `await` đầu tiên), không báo chặn khi main actor rảnh.
@MainActor
@Suite("MainActorGapProbe: đối chứng âm và dương", .serialized)
struct MainActorGapProbeTests {
    @Test("Chặn main actor 150 ms ngay sau start(): khoảng chặn dài nhất ≥ 120 ms")
    func detectsBlocking() async {
        let probe = MainActorGapProbe()
        await probe.start()
        usleep(150_000) // chặn main actor, không await
        await probe.stop()
        #expect(probe.longestGap >= .milliseconds(120))
    }

    @Test("Main actor rảnh 60 ms: có nhịp, khoảng chặn dài nhất < 100 ms (rộng vì các suite chạy song song)")
    func quietWhenIdle() async throws {
        let probe = MainActorGapProbe()
        await probe.start()
        try await Task.sleep(for: .milliseconds(60))
        await probe.stop()
        #expect(probe.beats >= 3)
        #expect(probe.longestGap < .milliseconds(100))
    }
}
