import ExamKit
import Foundation
@testable import SessionFeature
import Testing

/// Đồng hồ chạy nhanh cho UI test (chỉ build Debug): nhân thời gian đo, giữ mốc giờ thật; hệ số 1 là đồng hồ
/// thật của app.
@Suite("Đồng hồ phiên thi của UI test")
struct UITestClockTests {
    @Test("Hệ số nhân thời gian đo, giữ giờ hệ thống")
    func scaledClockMultipliesUptime() {
        let base = FakeClock()
        let clock = ScaledSessionClock(base: base, factor: 6)
        let start = clock.uptime()
        let wall = clock.now()
        base.advance(10)
        #expect(clock.uptime() - start == 60)
        #expect(clock.now() == wall.addingTimeInterval(10))
    }

    @Test("Hệ số 1 dùng SystemSessionClock; khác 1 dùng đồng hồ nhanh")
    func clockFactoryByScale() {
        #expect(SessionEnvironment.clockFactory(timeScale: 1)() is SystemSessionClock)
        let scaled = SessionEnvironment.clockFactory(timeScale: 30)()
        #expect((scaled as? ScaledSessionClock)?.factor == 30)
    }

    @Test("Thi 6 phút với hệ số 6: cảnh báo 5 phút sau 10 giây đo thật, hết giờ sau 60 giây")
    @MainActor
    func examTimelineWithScaledClock() throws {
        let base = FakeClock()
        let clock = ScaledSessionClock(base: base, factor: 6)
        let exam = makeExam(counts: [3])
        var session = try ExamSession(
            exam: exam,
            paper: ExamComposer.compose(exam, options: CompositionOptions(seed: 1)),
            mode: .exam,
            timeLimitMinutes: 6,
            candidateName: "Học viên",
            clock: clock
        )
        base.advance(9)
        #expect(session.tick().isEmpty)
        base.advance(1)
        #expect(session.tick() == [.warning(minutesLeft: 5)])
        base.advance(40)
        #expect(session.tick() == [.warning(minutesLeft: 1)])
        base.advance(10)
        #expect(session.tick() == [.timeUp])
    }
}
