import AppKit
import ExamKit
import LibraryData
import LibraryFeature
import SwiftUI

/// Phần AppKit của phiên thi cho một bản app, giữ ở app delegate (một đối tượng cho cả app): tạo
/// `SessionCoordinator` trên thư viện của app, nối Thư viện với phiên thi, hỏi khi đóng cửa sổ làm bài hoặc
/// thoát app lúc chưa nộp, tạm dừng khi máy sắp ngủ (docs/product/exam-taking.md).
///
/// - Đóng cửa sổ làm bài (nút đóng, ⌘W): `windowShouldClose` của cửa sổ hỏi "Bài chưa nộp sẽ mất. Bỏ bài?"
///   bằng sheet trên cửa sổ đó (**Tiếp tục làm** mặc định, **Bỏ bài**); đồng hồ vẫn chạy trong lúc hỏi.
/// - Thoát app (⌘Q, ⌥⌘Q, Thoát từ Dock, đăng xuất/khởi động lại/tắt máy, AppleScript): mục Thoát và Apple event thoát
///   là của AppKit, không thay; app delegate chuyển `applicationShouldTerminate` vào đây; hỏi như trên rồi trả lời
///   AppKit (`terminateLater`). AppKit đã hỏi lưu các tài liệu soạn đề (`DocumentGroup` của bản Admin) **trước** khi
///   gọi delegate, nên lời nhắc lưu của cửa sổ soạn đề giữ nguyên. Huỷ (Tiếp tục làm) thì AppKit trả `userCanceledErr`
///   cho Apple event thoát: đăng xuất bị huỷ gọn. Mọi sheet SwiftUI của app gắn `presentationAllowsAppTermination()`
///   (LibraryFeature) nên không chặn các đường thoát này (`scripts/check_quit_sheets.py`).
/// - Bản Học viên: đóng cửa sổ Thư viện là thoát app (library.md), nên `windowShouldClose` của Thư viện gọi
///   `NSApp.terminate` (đi qua đúng lời hỏi trên) và chỉ đóng khi app thoát thật.
/// - Mỗi lúc chỉ một lời hỏi: đang hỏi mà lại đóng/thoát (ví dụ đóng Thư viện bản Học viên lần nữa) thì không
///   hiện hộp thứ hai.
/// - Máy sắp ngủ (`NSWorkspace.willSleepNotification`): `systemWillSleep()`.
@MainActor
public final class SessionAppController {
    /// Hiện lời hỏi Bỏ bài trên cửa sổ (nil: hộp riêng) rồi gọi `completion(discard)`, ngay hoặc sau.
    typealias ConfirmationPresenter = @MainActor (
        _ confirmation: SessionCloseConfirmation,
        _ window: NSWindow?,
        _ completion: @escaping @MainActor (_ discard: Bool) -> Void
    ) -> Void

    public let coordinator: SessionCoordinator
    public let library: LibraryModel

    let sessionWindowGuard = WindowCloseGuard()
    let libraryWindowGuard = WindowCloseGuard()
    private(set) weak var sessionWindow: NSWindow?
    /// Đang hiện lời hỏi Bỏ bài (đóng cửa sổ hoặc thoát app).
    private(set) var isAskingToDiscard = false
    private let presentConfirmation: ConfirmationPresenter
    private let terminateApp: @MainActor () -> Void
    private var sleepObserver: (any NSObjectProtocol)?

    /// - Parameters:
    ///   - defaults: tên thí sinh và chế độ lần trước (app: `UserDefaults.standard`; UI test: suite trong thư mục
    ///   tạm, xem `AppLaunchStorage`).
    ///   - timeScale: hệ số thời gian của đồng hồ phiên thi; khác 1 chỉ ở chế độ cô lập của UI test (Debug).
    public convenience init(library: LibraryModel, defaults: UserDefaults = .standard, timeScale: Double = 1) {
        self.init(
            library: library,
            coordinator: SessionCoordinator(environment: .live(store: library.store, defaults: defaults, timeScale: timeScale)),
            presentConfirmation: Self.presentAlert,
            terminateApp: { NSApp.terminate(nil) }
        )
        // Xuất PDF… / In…: hộp lưu, hộp In, hộp báo lỗi làm sheet trên cửa sổ làm bài.
        coordinator.reportServices = .live(window: { [weak self] in self?.sessionWindow })
    }

    /// Test tiêm điều phối, cách hiện lời hỏi và cách thoát app.
    init(
        library: LibraryModel,
        coordinator: SessionCoordinator,
        presentConfirmation: @escaping ConfirmationPresenter,
        terminateApp: @escaping @MainActor () -> Void
    ) {
        self.library = library
        self.coordinator = coordinator
        self.presentConfirmation = presentConfirmation
        self.terminateApp = terminateApp
        library.sessionActions = LibrarySessionActions(
            openPreExam: { [weak coordinator] examID, mode in
                Task { await coordinator?.openPreExam(examID: examID, mode: mode) }
            },
            openAttempt: { [weak coordinator] attempt in
                coordinator?.openHistoryAttempt(attempt)
            }
        )
        coordinator.presentLibrary = { [weak library] in library?.presentWindow?() }

        sessionWindowGuard.shouldClose = { [weak self] window in
            self?.sessionWindowShouldClose(window) ?? true
        }
        sessionWindowGuard.willClose = { [weak self] _ in
            self?.coordinator.sessionWindowDidClose()
        }
        libraryWindowGuard.shouldClose = { [weak self] _ in
            self?.libraryWindowShouldClose() ?? true
        }

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.systemWillSleep() }
        }
    }

    // MARK: - Cửa sổ

    /// Cửa sổ làm bài vừa có `NSWindow` (scene `SessionWindowScene`), hoặc được cập nhật.
    func attachSessionWindow(_ window: NSWindow) {
        let isNew = sessionWindow !== window
        sessionWindow = window
        sessionWindowGuard.install(on: window)
        // Cửa sổ mở khi không có phiên (ví dụ từ menu Window): đóng ngay.
        if isNew, coordinator.window == nil {
            DispatchQueue.main.async { [weak self] in
                if self?.coordinator.window == nil { self?.closeSessionWindow() }
            }
        }
    }

    /// Đóng cửa sổ làm bài khi không còn phiên (Bỏ bài, Về thư viện). Đóng bằng AppKit (`close()` không hỏi
    /// lại `windowShouldClose`), vì cửa sổ có delegate chen trước (`WindowCloseGuard`).
    func closeSessionWindow() {
        guard let window = sessionWindow, window.isVisible || window.isMiniaturized else { return }
        if window.attachedSheet != nil {
            // Hộp thoại đang kết thúc: đóng ở lượt sau.
            DispatchQueue.main.async { [weak self] in self?.closeSessionWindow() }
            return
        }
        window.close()
    }

    /// Cửa sổ Thư viện của bản Học viên: đóng là thoát app.
    func attachQuittingLibraryWindow(_ window: NSWindow) {
        libraryWindowGuard.install(on: window)
    }

    /// Đóng cửa sổ làm bài: chưa nộp thì hỏi (sheet trên cửa sổ) và giữ cửa sổ; Bỏ bài thì bỏ phiên, cửa sổ
    /// tự đóng theo.
    func sessionWindowShouldClose(_ window: NSWindow) -> Bool {
        guard case let .confirm(confirmation) = coordinator.closeDecision else { return true }
        guard !isAskingToDiscard, window.attachedSheet == nil else {
            // Đang có hộp thoại trên cửa sổ (đang hỏi, xác nhận nộp, ảnh phóng to): xử lý nó trước.
            NSSound.beep()
            return false
        }
        ask(confirmation, on: window) { [weak self] discard in
            if discard { self?.coordinator.discardSession() }
        }
        return false
    }

    /// Bản Học viên đóng Thư viện: thoát app (hỏi ở `applicationShouldTerminate`). Đang hỏi thì thôi. Cửa sổ còn sheet
    /// thì AppKit không cho đóng.
    func libraryWindowShouldClose() -> Bool {
        if !isAskingToDiscard { terminateApp() }
        return false
    }

    // MARK: - Thoát app

    /// Gọi từ `applicationShouldTerminate(_:)` của app delegate. Không có bài chưa nộp thì thoát luôn.
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard case let .confirm(confirmation) = coordinator.closeDecision else { return .terminateNow }
        // Đang hỏi rồi (ví dụ đóng Thư viện lần nữa): không hiện hộp thứ hai, giữ app.
        guard !isAskingToDiscard else { return .terminateCancel }
        let window = sessionWindow.flatMap { $0.attachedSheet == nil ? $0 : nil }
        let reply = TerminateReplyBox()
        ask(confirmation, on: window) { [weak self] discard in
            if discard { self?.coordinator.discardSession() }
            if reply.returned {
                sender.reply(toApplicationShouldTerminate: discard)
            } else {
                reply.immediate = discard
            }
        }
        reply.returned = true
        if let immediate = reply.immediate { return immediate ? .terminateNow : .terminateCancel }
        return .terminateLater
    }

    // MARK: - Lời hỏi

    /// Hiện lời hỏi, đánh dấu cửa sổ làm bài đang có hộp thoại (menu Bài thi tắt) tới khi trả lời.
    private func ask(
        _ confirmation: SessionCloseConfirmation,
        on window: NSWindow?,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        isAskingToDiscard = true
        let windowModel = coordinator.window
        windowModel?.setModal(.closeConfirmation, presented: true)
        presentConfirmation(confirmation, window) { [weak self] discard in
            self?.isAskingToDiscard = false
            windowModel?.setModal(.closeConfirmation, presented: false)
            completion(discard)
        }
    }

    /// Lời hỏi bằng `NSAlert`: sheet trên cửa sổ nếu có, không thì hộp riêng.
    private static func presentAlert(
        _ confirmation: SessionCloseConfirmation,
        _ window: NSWindow?,
        _ completion: @escaping @MainActor (Bool) -> Void
    ) {
        let alert = makeAlert(confirmation)
        NSApp.activate()
        guard let window else {
            completion(alert.runModal() == .alertSecondButtonReturn)
            return
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        alert.beginSheetModal(for: window) { response in
            MainActor.assumeIsolated { completion(response == .alertSecondButtonReturn) }
        }
    }

    /// "Bài chưa nộp sẽ mất. Bỏ bài?": **Tiếp tục làm** (nút đầu, mặc định, Return) / **Bỏ bài**; dòng phụ theo
    /// exam-taking.md (phương án 16).
    private static func makeAlert(_ confirmation: SessionCloseConfirmation) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = confirmation.message
        alert.informativeText = localized("Bỏ bài thì không lưu gì và lần này không có trong Lịch sử thi.")
        alert.addButton(withTitle: confirmation.continueTitle)
        let discard = alert.addButton(withTitle: confirmation.discardTitle)
        discard.hasDestructiveAction = true
        return alert
    }
}

/// Trả lời `applicationShouldTerminate` ngay (lời hỏi xong đồng bộ) hay sau (`terminateLater`).
@MainActor
private final class TerminateReplyBox {
    var returned = false
    var immediate: Bool?
}

// MARK: - Bắc cầu với Thư viện

/// Phần phiên thi gắn vào cửa sổ Thư viện (`LibraryWindow(model:decoration:)`): sheet **Trước khi thi**, thông
/// báo của phiên thi ("Đang có bài chưa nộp", lỗi mở đề) ở chân Thư viện, và (bản Học viên) đóng Thư viện là
/// thoát app.
public struct SessionLibraryDecoration: ViewModifier {
    private let sessions: SessionAppController
    private let closingQuitsApp: Bool

    @Environment(\.openWindow) private var openWindow

    /// - Parameter closingQuitsApp: bản Học viên (đóng cửa sổ Thư viện thì app thoát, library.md).
    public init(sessions: SessionAppController, closingQuitsApp: Bool) {
        self.sessions = sessions
        self.closingQuitsApp = closingQuitsApp
    }

    public func body(content: Content) -> some View {
        let coordinator = sessions.coordinator
        content
            .sheet(item: Binding(
                get: { coordinator.preExam },
                set: { if $0 == nil { coordinator.cancelPreExam() } }
            )) { preExam in
                PreExamView(
                    model: preExam,
                    onStart: { Task { await coordinator.startPreExam() } },
                    onCancel: { coordinator.cancelPreExam() }
                )
                .tint(SessionStyle.accentForeground)
                // ⌘Q, Thoát từ Dock, đăng xuất khi Trước khi thi đang mở: thoát như thường (SwiftUI đóng sheet, binding
                // gọi cancelPreExam()).
                .presentationAllowsAppTermination()
            }
            .background(WindowAccessor { window in
                if closingQuitsApp { sessions.attachQuittingLibraryWindow(window) }
            })
            .onAppear {
                coordinator.presentSessionWindow = { openWindow(id: SessionWindowScene.windowID) }
            }
            .onChange(of: coordinator.preExam?.id) { _, id in
                // Một sheet mỗi lúc: Trước khi thi (cả khi mở từ Làm lại) thay sheet Thông tin.
                if id != nil { sessions.library.infoExamID = nil }
            }
            .onChange(of: coordinator.notice, initial: true) { _, notice in
                guard let notice else { return }
                sessions.library.show(LibraryNotice(message: notice.message))
                coordinator.dismissNotice()
            }
    }
}

// MARK: - AppKit

/// Lấy `NSWindow` chứa một view SwiftUI.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> AccessorView {
        let view = AccessorView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: AccessorView, context: Context) {
        view.onWindow = onWindow
        if let window = view.window { onWindow(window) }
    }

    final class AccessorView: NSView {
        var onWindow: (@MainActor (NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}

/// Delegate chen trước delegate SwiftUI của một cửa sổ để hỏi trước khi đóng. Mọi thông điệp khác chuyển
/// nguyên cho delegate cũ (`forwardingTarget`), và `windowShouldClose`/`windowWillClose` cũng gọi tiếp
/// delegate cũ, nên hành vi cửa sổ của SwiftUI giữ nguyên.
///
/// SwiftUI có thể đặt lại delegate của cửa sổ về sau: mỗi khi cửa sổ cập nhật hoặc thành cửa sổ chính/key
/// (và mỗi lần `install`), guard kiểm lại và chen trước lần nữa, lấy delegate mới làm delegate cũ.
@MainActor
final class WindowCloseGuard: NSObject, NSWindowDelegate {
    /// Trả `false` để giữ cửa sổ.
    var shouldClose: ((NSWindow) -> Bool)?
    var willClose: ((NSWindow) -> Void)?

    /// Delegate gốc (của SwiftUI) của cửa sổ đang gắn; nil nếu cửa sổ không có delegate.
    /// `NSWindow.delegate` là tham chiếu yếu nên giữ mạnh ở đây.
    nonisolated(unsafe) private(set) var original: (any NSWindowDelegate)?
    private(set) weak var window: NSWindow?
    private var observers: [any NSObjectProtocol] = []

    /// Gắn vào cửa sổ (đổi cửa sổ thì trả delegate cho cửa sổ cũ) và chen trước delegate hiện tại.
    func install(on window: NSWindow) {
        if self.window !== window {
            stopObserving()
            if let old = self.window, old.delegate === self { old.delegate = original }
            self.window = window
            original = nil
            observe(window)
        }
        ensureInstalled()
    }

    /// Delegate của cửa sổ không còn là guard (SwiftUI đặt lại): lấy delegate hiện tại (kể cả nil) làm delegate
    /// cũ rồi chen trước lần nữa.
    func ensureInstalled() {
        guard let window, window.delegate !== self else { return }
        original = window.delegate
        window.delegate = self
    }

    private func observe(_ window: NSWindow) {
        let center = NotificationCenter.default
        let names = [NSWindow.didUpdateNotification, NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification]
        for name in names {
            // queue nil: chạy ngay trên luồng gửi (main), để kiểm lại trước khi người dùng kịp đóng.
            observers.append(center.addObserver(forName: name, object: window, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.ensureInstalled() }
            })
        }
    }

    private func stopObserving() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let shouldClose, !shouldClose(sender) { return false }
        return original?.windowShouldClose?(sender) ?? true
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow { willClose?(window) }
        original?.windowWillClose?(notification)
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return original?.responds(to: aSelector) ?? false
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) { return original }
        return super.forwardingTarget(for: aSelector)
    }
}
