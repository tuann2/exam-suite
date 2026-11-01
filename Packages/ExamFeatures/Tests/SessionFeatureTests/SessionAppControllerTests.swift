import AppKit
import ExamKit
import Foundation
import InterfaceCore
import LibraryData
@testable import SessionFeature
import SwiftUI
import Testing

/// Phần AppKit của phiên thi, không chạy app: delegate chen trước (`WindowCloseGuard`) trên `NSWindow` không
/// hiện với delegate giả, lời hỏi khi đóng cửa sổ/thoát app (`SessionAppController`, lời hỏi giả), trạng thái
/// menu **Bài thi** (`SessionMenuState`), kể cả khi cửa sổ có sheet/hộp thoại.
@MainActor
@Suite("Đóng cửa sổ, thoát app, menu Bài thi", .timeLimit(.minutes(1)))
struct SessionAppControllerTests {
    let exam = makeExam(counts: [2, 1])

    // MARK: - Đồ giả

    /// Delegate giả: ghi lại thông điệp nhận được.
    @MainActor
    final class FakeWindowDelegate: NSObject, NSWindowDelegate {
        var shouldCloseCalls = 0
        var willCloseCalls = 0
        var resizeCalls = 0
        var answer = true

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            shouldCloseCalls += 1
            return answer
        }

        func windowWillClose(_ notification: Notification) { willCloseCalls += 1 }
        func windowDidResize(_ notification: Notification) { resizeCalls += 1 }
    }

    /// Lời hỏi giả: ghi lại, trả lời ngay (`answer`) hoặc giữ lại tới khi test trả lời.
    @MainActor
    final class ConfirmRecorder {
        var confirmations: [SessionCloseConfirmation] = []
        var windows: [NSWindow?] = []
        var answer: Bool?
        var pending: (@MainActor (Bool) -> Void)?

        func present(_ confirmation: SessionCloseConfirmation, _ window: NSWindow?, _ completion: @escaping @MainActor (Bool) -> Void) {
            confirmations.append(confirmation)
            windows.append(window)
            if let answer { completion(answer) } else { pending = completion }
        }
    }

    struct Setup {
        let harness: Harness
        let coordinator: SessionCoordinator
        let controller: SessionAppController
        let recorder: ConfirmRecorder
        let terminations: Counter
        let workspace: SessionWorkspace
    }

    @MainActor
    final class Counter { var value = 0 }

    func makeWindow(delegate: (any NSWindowDelegate)?) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        return window
    }

    func setUp() throws -> Setup {
        let harness = Harness()
        harness.library.add(exam)
        let coordinator = SessionCoordinator(environment: harness.environment)
        let workspace = try SessionWorkspace()
        let library = LibraryModel(
            store: .inMemory(configuration: workspace.configuration(), defaults: workspace.defaults),
            startsAutomatically: false,
            revealFiles: { _ in }
        )
        let recorder = ConfirmRecorder()
        let terminations = Counter()
        let controller = SessionAppController(
            library: library,
            coordinator: coordinator,
            presentConfirmation: { recorder.present($0, $1, $2) },
            terminateApp: { terminations.value += 1 }
        )
        return Setup(
            harness: harness,
            coordinator: coordinator,
            controller: controller,
            recorder: recorder,
            terminations: terminations,
            workspace: workspace
        )
    }

    /// Bản app (`init(library:defaults:timeScale:)`) gắn đủ hai thứ Xuất PDF…/In… cần: hộp của macOS và phần xem lại dùng
    /// lần trước, lưu ở `defaults` của app với khoá như trước bước I1 của plan iOS. Thiếu một trong hai thì hai lệnh bật
    /// mà không làm gì.
    @Test func appControllerWiresReportFlow() throws {
        let workspace = try SessionWorkspace()
        let library = LibraryModel(
            store: .inMemory(configuration: workspace.configuration(), defaults: workspace.defaults),
            startsAutomatically: false
        )
        let controller = SessionAppController(library: library, defaults: workspace.defaults)
        #expect(controller.coordinator.reportServices != nil)
        let preferences = try #require(controller.coordinator.reportPreferences)
        preferences.reportReviewLevel = .all
        #expect(workspace.defaults.string(forKey: "report.resultsReviewLevel") == "all")
    }

    /// Bắt đầu một bài Luyện tập chưa nộp.
    func start(_ setup: Setup) async throws -> SessionWindowModel {
        await setup.coordinator.openPreExam(examID: exam.id, mode: .practice)
        #expect(await setup.coordinator.startPreExam())
        return try #require(setup.coordinator.window)
    }

    func notification(_ name: Notification.Name, _ window: NSWindow) -> Notification {
        Notification(name: name, object: window)
    }

    // MARK: - WindowCloseGuard

    @Test("Guard chen trước delegate: chuyển tiếp mọi thông điệp khác; hỏi trước khi đóng rồi mới hỏi delegate cũ")
    func guardForwardsToOriginalDelegate() {
        let fake = FakeWindowDelegate()
        let window = makeWindow(delegate: fake)
        let guardDelegate = WindowCloseGuard()
        var willClose = 0
        guardDelegate.willClose = { _ in willClose += 1 }
        guardDelegate.install(on: window)

        #expect(window.delegate === guardDelegate)
        #expect(guardDelegate.original === fake)
        // Thông điệp guard không tự xử lý đi thẳng tới delegate cũ.
        #expect((window.delegate as? NSObject)?.responds(to: #selector(NSWindowDelegate.windowDidResize(_:))) == true)
        window.delegate?.windowDidResize?(notification(NSWindow.didResizeNotification, window))
        #expect(fake.resizeCalls == 1)

        // Không có chính sách: hỏi delegate cũ.
        fake.answer = false
        #expect(window.delegate?.windowShouldClose?(window) == false)
        #expect(fake.shouldCloseCalls == 1)
        // Chính sách giữ cửa sổ: delegate cũ không được hỏi.
        guardDelegate.shouldClose = { _ in false }
        #expect(window.delegate?.windowShouldClose?(window) == false)
        #expect(fake.shouldCloseCalls == 1)
        // Chính sách cho đóng: delegate cũ quyết định tiếp.
        guardDelegate.shouldClose = { _ in true }
        fake.answer = true
        #expect(window.delegate?.windowShouldClose?(window) == true)
        #expect(fake.shouldCloseCalls == 2)

        window.delegate?.windowWillClose?(notification(NSWindow.willCloseNotification, window))
        #expect(willClose == 1)
        #expect(fake.willCloseCalls == 1)
    }

    @Test("Cửa sổ mới không có delegate: không chuyển tiếp nhầm sang delegate của cửa sổ trước; cửa sổ trước lấy lại delegate")
    func guardOnWindowWithoutDelegate() {
        let fake = FakeWindowDelegate()
        let first = makeWindow(delegate: fake)
        let second = makeWindow(delegate: nil)
        let guardDelegate = WindowCloseGuard()
        guardDelegate.install(on: first)
        guardDelegate.install(on: second)

        #expect(second.delegate === guardDelegate)
        #expect(guardDelegate.original == nil)
        #expect(first.delegate === fake)
        #expect((second.delegate as? NSObject)?.responds(to: #selector(NSWindowDelegate.windowDidResize(_:))) == false)
        second.delegate?.windowDidResize?(notification(NSWindow.didResizeNotification, second))
        #expect(fake.resizeCalls == 0)
        #expect(second.delegate?.windowShouldClose?(second) == true)
        #expect(fake.shouldCloseCalls == 0)
    }

    @Test("SwiftUI đặt lại delegate: guard chen trước lần nữa khi cửa sổ cập nhật/thành key, lấy delegate mới làm delegate cũ")
    func guardReinstallsWhenDelegateReplaced() {
        let first = FakeWindowDelegate()
        let replacement = FakeWindowDelegate()
        let window = makeWindow(delegate: first)
        let guardDelegate = WindowCloseGuard()
        guardDelegate.shouldClose = { _ in false }
        guardDelegate.install(on: window)

        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didUpdateNotification, NSWindow.didBecomeMainNotification] {
            window.delegate = replacement
            NotificationCenter.default.post(name: name, object: window)
            #expect(window.delegate === guardDelegate)
            #expect(guardDelegate.original === replacement)
        }
        window.delegate?.windowDidResize?(notification(NSWindow.didResizeNotification, window))
        #expect(replacement.resizeCalls == 1)
        #expect(first.resizeCalls == 0)
        // Vẫn hỏi trước khi đóng.
        #expect(window.delegate?.windowShouldClose?(window) == false)
        #expect(replacement.shouldCloseCalls == 0)

        // Cài lại trực tiếp (mỗi lần SwiftUI cập nhật view) cũng vậy, kể cả khi delegate bị bỏ hẳn.
        window.delegate = nil
        guardDelegate.install(on: window)
        #expect(window.delegate === guardDelegate)
        #expect(guardDelegate.original == nil)
    }

    // MARK: - Đóng cửa sổ làm bài

    @Test("Đóng cửa sổ làm bài khi chưa nộp: hỏi “Bài chưa nộp sẽ mất. Bỏ bài?”, giữ cửa sổ; Tiếp tục làm giữ bài, Bỏ bài bỏ phiên")
    func closeUnsubmittedAsks() async throws {
        let setup = try setUp()
        let windowModel = try await start(setup)
        let fake = FakeWindowDelegate()
        let window = makeWindow(delegate: fake)
        setup.controller.attachSessionWindow(window)
        #expect(window.delegate === setup.controller.sessionWindowGuard)

        // Đóng qua delegate của cửa sổ (nút đóng, ⌘W).
        #expect(window.delegate?.windowShouldClose?(window) == false)
        #expect(setup.recorder.confirmations.map(\.message) == ["Bài chưa nộp sẽ mất. Bỏ bài?"])
        #expect(setup.recorder.confirmations.first?.continueTitle == "Tiếp tục làm")
        #expect(setup.recorder.windows.first.flatMap { $0 } === window)
        #expect(fake.shouldCloseCalls == 0)
        // Trong lúc hỏi: cửa sổ có hộp thoại, menu Bài thi tắt; đóng lần nữa không hiện hộp thứ hai.
        #expect(windowModel.hasModal)
        #expect(SessionMenuState(window: windowModel).enabled.isEmpty)
        #expect(setup.controller.sessionWindowShouldClose(window) == false)
        #expect(setup.recorder.confirmations.count == 1)

        // Tiếp tục làm.
        setup.recorder.pending?(false)
        #expect(!windowModel.hasModal)
        #expect(setup.coordinator.window === windowModel)
        #expect(setup.coordinator.hasUnsubmittedSession)

        // Hỏi lại, Bỏ bài: không lưu gì.
        setup.recorder.answer = true
        #expect(setup.controller.sessionWindowShouldClose(window) == false)
        #expect(setup.coordinator.window == nil)
        #expect(setup.harness.library.storedAttempts.isEmpty)
    }

    @Test("Đóng cửa sổ làm bài khi đã nộp hoặc không có phiên: không hỏi")
    func closeSubmittedDoesNotAsk() async throws {
        let setup = try setUp()
        let window = makeWindow(delegate: nil)
        #expect(setup.controller.sessionWindowShouldClose(window))
        let windowModel = try await start(setup)
        setup.controller.attachSessionWindow(window)
        let attempt = try #require(windowModel.attempt)
        attempt.answer("B")
        attempt.nextQuestion()
        attempt.answer("B")
        attempt.nextQuestion()
        attempt.answer("B")
        attempt.openReview()
        windowModel.requestSubmit()
        #expect(windowModel.screen == .results)

        #expect(window.delegate?.windowShouldClose?(window) == true)
        #expect(setup.recorder.confirmations.isEmpty)
    }

    // MARK: - Thoát app

    @Test("Thoát app: không có bài thì thoát ngay; chưa nộp thì hỏi; Tiếp tục làm huỷ thoát, Bỏ bài thoát và không lưu")
    func terminatePolicy() async throws {
        let setup = try setUp()
        let app = NSApplication.shared
        #expect(setup.controller.applicationShouldTerminate(app) == .terminateNow)
        #expect(setup.recorder.confirmations.isEmpty)

        _ = try await start(setup)
        setup.recorder.answer = false
        #expect(setup.controller.applicationShouldTerminate(app) == .terminateCancel)
        #expect(setup.coordinator.hasUnsubmittedSession)
        #expect(setup.recorder.confirmations.count == 1)
        #expect(setup.recorder.windows.first.flatMap { $0 } == nil)

        setup.recorder.answer = true
        #expect(setup.controller.applicationShouldTerminate(app) == .terminateNow)
        #expect(setup.coordinator.window == nil)
        #expect(setup.harness.library.storedAttempts.isEmpty)
    }

    /// Sheet Trước khi thi thật (`SessionLibraryDecoration`) trên một cửa sổ: sheet SwiftUI mặc định chặn app thoát (⌘Q
    /// không hỏi app delegate, UI test PR #42; Thoát từ Dock và đăng xuất bị từ chối), nên sheet gắn
    /// `presentationAllowsAppTermination()`: cờ `preventsApplicationTerminationWhenModal` của cửa sổ sheet là NO, AppKit chạy
    /// quy trình thoát chuẩn (hỏi Bỏ bài ở `applicationShouldTerminate`). Đối chứng sheet mặc định: LibraryFeatureTests
    /// (`PresentationTerminationTests`).
    @Test("Sheet Trước khi thi thật trên cửa sổ không chặn thoát app (⌘Q, Thoát từ Dock, đăng xuất)")
    func preExamSheetAllowsTermination() async throws {
        let setup = try setUp()
        let window = makeWindow(delegate: nil)
        window.contentView = NSHostingView(rootView: Color.clear
            .frame(width: 480, height: 360)
            .modifier(SessionLibraryDecoration(sessions: setup.controller, closingQuitsApp: false)))
        window.setContentSize(NSSize(width: 480, height: 360))
        window.orderFrontRegardless()
        defer { window.close() }
        await setup.coordinator.openPreExam(examID: exam.id, mode: .practice)
        #expect(await waitFor { window.attachedSheet != nil }, "sheet Trước khi thi phải hiện")
        let sheet = try #require(window.attachedSheet)
        #expect(!(sheet is NSPanel))
        #expect(sheet.preventsApplicationTerminationWhenModal == false)
        // AppKit kết thúc sheet khi thoát: binding đặt nil thì Trước khi thi đóng (cancelPreExam), không để lại trạng thái.
        setup.coordinator.cancelPreExam()
        #expect(await waitFor { window.attachedSheet == nil })
        #expect(setup.coordinator.preExam == nil)
        // Không có bài: thoát ngay, không hỏi.
        #expect(setup.controller.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
        #expect(setup.recorder.confirmations.isEmpty)
    }

    /// Chờ điều kiện (tối đa 3 giây) trên main actor.
    private func waitFor(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 150 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    @Test("Đang hỏi Bỏ bài: thoát lần nữa hay đóng Thư viện (bản Học viên) không hiện hộp thứ hai")
    func noNestedConfirmations() async throws {
        let setup = try setUp()
        let app = NSApplication.shared
        // Không có bài: đóng Thư viện là thoát app.
        #expect(setup.controller.libraryWindowShouldClose() == false)
        #expect(setup.terminations.value == 1)

        _ = try await start(setup)
        let window = makeWindow(delegate: nil)
        setup.controller.attachSessionWindow(window)
        // Lời hỏi chưa trả lời (sheet trên cửa sổ làm bài).
        #expect(setup.controller.applicationShouldTerminate(app) == .terminateLater)
        #expect(setup.controller.isAskingToDiscard)
        #expect(setup.recorder.windows.first.flatMap { $0 } === window)

        #expect(setup.controller.libraryWindowShouldClose() == false)
        #expect(setup.terminations.value == 1)
        #expect(setup.controller.applicationShouldTerminate(app) == .terminateCancel)
        #expect(setup.controller.sessionWindowShouldClose(window) == false)
        #expect(setup.recorder.confirmations.count == 1)
    }

    // MARK: - Menu Bài thi

    @Test("Menu Bài thi theo trạng thái bài: câu đầu, đã trả lời, rà soát, tạm dừng, đã nộp")
    func menuStateFollowsAttempt() async throws {
        let setup = try setUp()
        let windowModel = try await start(setup)
        let attempt = try #require(windowModel.attempt)

        var state = SessionMenuState(window: windowModel)
        #expect(state.enabled == [.nextQuestion, .advance, .toggleFlag, .togglePause, .openReview, .toggleNavigator])
        #expect(state.isPractice)
        #expect(!state.isFlagged)

        attempt.answer("B")
        attempt.toggleFlag()
        state = SessionMenuState(window: windowModel)
        #expect(state.enabled.contains(.checkAnswer))
        #expect(state.isFlagged)

        attempt.togglePause()
        state = SessionMenuState(window: windowModel)
        #expect(state.isPaused)
        #expect(state.enabled == [.togglePause, .toggleNavigator])
        attempt.togglePause()

        attempt.openReview()
        state = SessionMenuState(window: windowModel)
        #expect(state.enabled == [.togglePause, .returnToAttempt, .submit, .toggleNavigator])

        windowModel.requestSubmit()
        #expect(attempt.isConfirmingSubmit)
        windowModel.confirmSubmit()
        #expect(SessionMenuState(window: windowModel).enabled.isEmpty)
    }

    @Test("Cửa sổ có sheet/hộp thoại (ảnh phóng to, hỏi Bỏ bài, xác nhận nộp): mọi lệnh và phím của menu Bài thi tắt")
    func menuDisabledWhileModalPresented() async throws {
        let setup = try setUp()
        let windowModel = try await start(setup)
        let attempt = try #require(windowModel.attempt)
        let normal = SessionMenuState(window: windowModel).enabled
        #expect(normal.contains(.advance))

        windowModel.setModal(.imageZoom, presented: true)
        #expect(windowModel.hasModal)
        #expect(SessionMenuState(window: windowModel).enabled.isEmpty)
        windowModel.setModal(.imageZoom, presented: false)
        #expect(SessionMenuState(window: windowModel).enabled == normal)

        windowModel.setModal(.closeConfirmation, presented: true)
        #expect(SessionMenuState(window: windowModel).enabled.isEmpty)
        windowModel.setModal(.closeConfirmation, presented: false)

        // Hộp "Còn N câu chưa làm. Vẫn nộp?".
        attempt.openReview()
        windowModel.requestSubmit()
        #expect(attempt.isConfirmingSubmit)
        #expect(windowModel.hasModal)
        #expect(SessionMenuState(window: windowModel).enabled.isEmpty)
        attempt.cancelSubmit()
        #expect(!windowModel.hasModal)
        #expect(SessionMenuState(window: windowModel).enabled.contains(.returnToAttempt))
    }
}
