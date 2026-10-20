import ExamKit
import Foundation
import ReportFeature
@testable import SessionFeature
import Testing

/// Nhóm in của menu Tệp là của cả app (`SessionCommands`): **Xuất PDF…** / **In…** (⌘P) đi tới cửa sổ làm bài khi nó đang
/// dùng, không thì tới cửa sổ gửi `ReportCommandTarget` (cửa sổ soạn đề của bản Admin, PDF đề; docs/product/export-print.md
/// phương án 9), không thêm nhóm in thứ hai.
extension ResultsReportFlowTests {
    @Test("Menu Tệp › Xuất PDF…/In…: cửa sổ làm bài đang dùng thì theo nó; không thì theo cửa sổ khác (PDF đề); không có gì thì tắt")
    func reportMenuRoute() async throws {
        // Không có cửa sổ nào: tắt, bấm không làm gì.
        let none = ReportMenuRoute(sessionWindow: nil, sessionState: nil, target: nil)
        #expect(!none.isEnabled)
        none.perform(.print)

        // Cửa sổ khác (soạn đề): bật/tắt theo nó, bấm gọi đúng lệnh; đang tắt thì bấm không gọi.
        let owner = NSObject()
        var calls: [ReportAction] = []
        let enabled = ReportCommandTarget(id: ObjectIdentifier(owner), isEnabled: true) { calls.append($0) }
        let route = ReportMenuRoute(sessionWindow: nil, sessionState: nil, target: enabled)
        #expect(route.isEnabled)
        route.perform(.exportPDF)
        route.perform(.print)
        #expect(calls == [.exportPDF, .print])
        let disabled = ReportCommandTarget(id: ObjectIdentifier(owner), isEnabled: false) { calls.append($0) }
        let off = ReportMenuRoute(sessionWindow: nil, sessionState: nil, target: disabled)
        #expect(!off.isEnabled)
        off.perform(.print)
        #expect(calls == [.exportPDF, .print])
        // Menu dựng lại khi bật/tắt đổi, không vì closure mới.
        #expect(enabled == ReportCommandTarget(id: ObjectIdentifier(owner), isEnabled: true) { _ in })
        #expect(enabled != disabled)

        // Cửa sổ làm bài đang dùng: theo trạng thái của nó (đang làm bài thì tắt), không gọi cửa sổ khác.
        let setup = try setUp()
        let sample = exam()
        setup.harness.library.add(sample)
        await setup.coordinator.openPreExam(examID: sample.id, mode: .exam)
        #expect(await setup.coordinator.startPreExam())
        let window = try #require(setup.coordinator.window)
        let attempting = ReportMenuRoute(sessionWindow: window, sessionState: SessionMenuState(window: window), target: enabled)
        #expect(!attempting.isEnabled)
        attempting.perform(.print)
        #expect(window.reportFlow == nil)
        #expect(calls == [.exportPDF, .print])

        let attempt = try #require(window.attempt)
        attempt.answerCorrectly()
        attempt.openReview()
        window.requestSubmit()
        if attempt.isConfirmingSubmit { window.confirmSubmit() }
        #expect(window.screen == .results)
        let results = ReportMenuRoute(sessionWindow: window, sessionState: SessionMenuState(window: window), target: disabled)
        #expect(results.isEnabled)
        results.perform(.print)
        #expect(window.reportFlow?.action == .print)
        #expect(calls == [.exportPDF, .print])
        window.reportFlow?.cancel()
    }
}
