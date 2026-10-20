import ExamKit
import LibraryFeature
import ReportFeature
import SwiftUI

/// Scene cửa sổ làm bài, dùng ở cả hai bản app (docs/product/exam-taking.md, mục Cửa sổ làm bài).
///
/// `Window` (một bản duy nhất) vì mỗi lúc chỉ một phiên: `openWindow(id:)` mở cửa sổ hoặc đưa nó lên trước.
/// Không mở khi khởi động app và không khôi phục khi mở lại app (không lưu phiên dở, phương án 2). Tối thiểu
/// 960×640, cho phép toàn màn hình. Menu **Bài thi**, mục **Xuất PDF…** / **In…** của menu Tệp (`SessionCommands`) và
/// **Phóng to** / **Thu nhỏ** / **Cỡ thật** và **Nền đọc** của menu Xem (`ContentZoomCommands`) đi kèm scene này.
public struct SessionWindowScene: Scene {
    /// Id của scene (`openWindow(id:)`).
    public static let windowID = "session"

    private let sessions: SessionAppController

    public init(sessions: SessionAppController) {
        self.sessions = sessions
    }

    public var body: some Scene {
        Window(localized("Làm bài"), id: Self.windowID) {
            SessionWindowRoot(sessions: sessions)
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands {
            SessionCommands()
            // Phóng to / Thu nhỏ / Cỡ thật, Nền đọc (menu Xem) của cửa sổ làm bài và (bản Admin) xem trước của Soạn đề.
            ContentZoomCommands()
        }
    }
}

/// Nội dung cửa sổ làm bài: màn của `SessionCoordinator.window`. Không còn phiên (Bỏ bài, Về thư viện) thì
/// đóng cửa sổ. Hỏi khi đóng lúc chưa nộp qua `SessionAppController` (AppKit).
struct SessionWindowRoot: View {
    let sessions: SessionAppController

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let coordinator = sessions.coordinator
        Group {
            if let window = coordinator.window {
                SessionWindowContent(window: window, coordinator: coordinator)
                    .id(window.id)
            } else {
                Color.clear
            }
        }
        .frame(minWidth: SessionStyle.minWindowSize.width, minHeight: SessionStyle.minWindowSize.height)
        .tint(SessionStyle.accentForeground)
        .background(WindowAccessor { sessions.attachSessionWindow($0) })
        .onAppear {
            coordinator.presentSessionWindow = { openWindow(id: SessionWindowScene.windowID) }
        }
        .onChange(of: coordinator.window?.id, initial: true) { _, id in
            // Bỏ bài, Về thư viện, hoặc cửa sổ mở lại khi không có phiên: đóng cửa sổ.
            if id == nil { sessions.closeSessionWindow() }
        }
    }
}

/// Màn đang hiện của một cửa sổ làm bài: làm bài / Kết quả / Xem lại bài.
private struct SessionWindowContent: View {
    let window: SessionWindowModel
    let coordinator: SessionCoordinator

    var body: some View {
        Group {
            switch window.screen {
            case .attempt:
                if let attempt = window.attempt {
                    AttemptScreen(window: window, attempt: attempt)
                }
            case .results:
                if let results = window.results {
                    ResultsScreen(
                        window: window,
                        results: results,
                        onRetake: { Task { await coordinator.retake() } },
                        onReturnToLibrary: { coordinator.returnToLibrary() }
                    )
                }
            case .answerReview:
                if let review = window.answerReview {
                    AnswerReviewScreen(
                        window: window,
                        review: review,
                        onPracticeIncorrect: { Task { await coordinator.practiceIncorrect() } }
                    )
                }
            }
        }
        .navigationTitle(window.title)
        // Xuất PDF… / In…: hộp chọn và tiến độ (docs/product/export-print.md); hộp lưu, hộp In, hộp báo lỗi là sheet
        // của AppKit (`ReportServices.live`).
        .sheet(isPresented: Binding(
            get: { window.reportFlow?.presentsSheet == true },
            set: { presented in if !presented { window.reportFlow?.sheetDismissed() } }
        )) {
            ResultsReportSheet(window: window)
                .presentationAllowsAppTermination()
        }
        // Sheet ảnh phóng to báo cho cửa sổ (`SessionWindowModel.setModal`).
        .environment(window)
        .focusedSceneValue(\.sessionWindowModel, window)
        .focusedSceneValue(\.sessionMenuState, SessionMenuState(window: window))
        // Câu VoiceOver của bài (đổi câu, Kiểm tra đáp án, cảnh báo giờ, nộp bài). Đọc ở đây chứ không ở màn
        // làm bài, vì nộp bài chuyển ngay sang Kết quả.
        .onChange(of: window.attempt?.announcements ?? [], initial: true) {
            if let attempt = window.attempt { SessionAnnouncer.post(attempt.takeAnnouncements()) }
        }
    }
}

// MARK: - Menu Bài thi

struct SessionWindowModelKey: FocusedValueKey {
    typealias Value = SessionWindowModel
}

struct SessionMenuStateKey: FocusedValueKey {
    typealias Value = SessionMenuState
}

extension FocusedValues {
    /// Cửa sổ làm bài đang là cửa sổ chính (`focusedSceneValue`).
    var sessionWindowModel: SessionWindowModel? {
        get { self[SessionWindowModelKey.self] }
        set { self[SessionWindowModelKey.self] = newValue }
    }

    /// Trạng thái bật/tắt và tên lệnh của menu **Bài thi**, tính lại mỗi khi bài đổi trạng thái.
    var sessionMenuState: SessionMenuState? {
        get { self[SessionMenuStateKey.self] }
        set { self[SessionMenuStateKey.self] = newValue }
    }

    /// **Xuất PDF…** / **In…** của cửa sổ đang dùng khi đó không phải cửa sổ làm bài (`ReportCommandTarget`).
    public var reportCommandTarget: ReportCommandTarget? {
        get { self[ReportCommandTargetKey.self] }
        set { self[ReportCommandTargetKey.self] = newValue }
    }
}

// MARK: - Xuất PDF, In của cửa sổ khác

/// **Xuất PDF…** / **In…** (menu Tệp) của một cửa sổ khác cửa sổ làm bài: cửa sổ soạn đề của bản Admin (PDF đề,
/// docs/product/export-print.md, mục Bản Admin) gửi giá trị này qua `focusedSceneValue(\.reportCommandTarget, …)`. Nhóm
/// in của menu Tệp là của cả app (`SessionCommands`), nên cửa sổ khác dùng chung hai mục và ⌘P thay vì thêm nhóm thứ
/// hai. SessionFeature không biết gì về cửa sổ đó (ADR 0003: bản Học viên không có code soạn đề).
///
/// So sánh theo `id` (đối tượng giữ lệnh của cửa sổ) và `isEnabled`, không theo closure, để menu chỉ dựng lại khi trạng
/// thái bật/tắt đổi.
public struct ReportCommandTarget: Equatable {
    /// Định danh của đối tượng giữ lệnh (mỗi cửa sổ một đối tượng).
    public let id: ObjectIdentifier
    /// Hai mục bật (cửa sổ không có sheet/hộp thoại, không có lần xuất nào đang chạy).
    public let isEnabled: Bool
    /// Mở hộp chọn của Xuất PDF… / In….
    public let perform: @MainActor (ReportAction) -> Void

    public init(id: ObjectIdentifier, isEnabled: Bool, perform: @escaping @MainActor (ReportAction) -> Void) {
        self.id = id
        self.isEnabled = isEnabled
        self.perform = perform
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled
    }
}

struct ReportCommandTargetKey: FocusedValueKey {
    typealias Value = ReportCommandTarget
}

/// Đích của **Xuất PDF…** / **In…** theo cửa sổ đang dùng: cửa sổ làm bài (Kết quả, Xem lại bài) nếu nó đang dùng, không
/// thì cửa sổ gửi `ReportCommandTarget` (cửa sổ soạn đề); không có cửa sổ nào thì hai mục tắt.
@MainActor
struct ReportMenuRoute {
    let sessionWindow: SessionWindowModel?
    let sessionState: SessionMenuState?
    let target: ReportCommandTarget?

    var isEnabled: Bool {
        if sessionWindow != nil { return (sessionState ?? .inactive).canReport }
        return target?.isEnabled ?? false
    }

    func perform(_ action: ReportAction) {
        if let sessionWindow {
            sessionWindow.requestReport(action)
        } else if let target, target.isEnabled {
            target.perform(action)
        }
    }
}

/// Ảnh chụp trạng thái menu **Bài thi** (và **Xuất PDF…** / **In…** của menu Tệp) của cửa sổ làm bài (giá trị, để menu
/// cập nhật theo).
struct SessionMenuState: Hashable {
    var enabled: Set<AttemptCommand> = []
    var isFlagged = false
    var isPaused = false
    var isNavigatorVisible = true
    var isPractice = false
    /// **Xuất PDF…** / **In…** bật (Kết quả hoặc Xem lại bài, không có sheet/hộp thoại).
    var canReport = false

    static let inactive = SessionMenuState()

    init() {}

    /// Mọi lệnh tắt khi bài đã nộp (hoặc mở từ Lịch sử thi) và khi cửa sổ đang có sheet/hộp thoại (ảnh phóng
    /// to, hỏi Bỏ bài, xác nhận nộp, Xuất PDF/In): phím của menu không tác dụng lên bài phía sau hộp thoại.
    @MainActor
    init(window: SessionWindowModel) {
        canReport = window.canRequestReport
        guard let attempt = window.attempt, !attempt.isSubmitted else { return }
        isFlagged = attempt.isCurrentFlagged
        isPaused = attempt.phase == .paused
        isNavigatorVisible = attempt.isNavigatorVisible
        isPractice = attempt.mode == .practice
        guard !window.hasModal else { return }
        enabled = Set(AttemptCommand.allCases.filter { attempt.isEnabled($0) })
    }
}

/// Menu **Bài thi** (docs/product/exam-taking.md, mục Bàn phím và trợ năng): mọi lệnh của cửa sổ làm bài kèm
/// phím, tắt khi không hợp lệ ở trạng thái hiện tại (`AttemptModel.isEnabled`) hoặc khi cửa sổ làm bài không
/// phải cửa sổ đang dùng.
///
/// Phím không có ⌘/⌃ (←, →, Return, Esc) chỉ gắn vào mục menu khi lệnh đang bật, tức là khi cửa sổ làm bài
/// (không có ô nhập chữ) đang dùng; nhờ vậy menu không nuốt phím của ô nhập chữ ở cửa sổ khác (ô tìm kiếm, tên
/// thí sinh). Cửa sổ làm bài cũng tự nhận các phím này (`onKeyPress`) và A–Z. ⌃⌘I (Ẩn/hiện bảng câu hỏi) cũng chỉ
/// gắn khi đang bật, vì bản Admin dùng cùng phím cho Ẩn/hiện xem trước của cửa sổ soạn đề.
///
/// Menu **Tệp**: **Xuất PDF…** (không phím tắt) và **In…** (⌘P) thay nhóm in mặc định (không có Page Setup riêng ⇧⌘P),
/// bật khi cửa sổ làm bài ở Kết quả hoặc Xem lại bài và không có sheet/hộp thoại (docs/product/export-print.md, phương
/// án 6). Nhóm in là của cả app: cửa sổ soạn đề của bản Admin (PDF đề, phương án 9) dùng chung hai mục và ⌘P qua
/// `ReportCommandTarget` (`ReportMenuRoute`), không thêm nhóm thứ hai.
public struct SessionCommands: Commands {
    @FocusedValue(\.sessionWindowModel) private var window
    @FocusedValue(\.sessionMenuState) private var state
    @FocusedValue(\.reportCommandTarget) private var reportTarget

    public init() {}

    public var body: some Commands {
        CommandMenu(localized("Bài thi")) {
            let state = state ?? .inactive
            let attempt = window?.attempt
            SessionMenuButton(
                title: localized("Câu trước"), command: .previousQuestion, state: state,
                shortcut: KeyboardShortcut(.leftArrow, modifiers: []), plainKey: true
            ) { attempt?.perform(.previousQuestion) }
            SessionMenuButton(
                title: localized("Câu sau"), command: .nextQuestion, state: state,
                shortcut: KeyboardShortcut(.rightArrow, modifiers: []), plainKey: true
            ) { attempt?.perform(.nextQuestion) }
            SessionMenuButton(
                title: localized("Câu tiếp theo"), command: .advance, state: state,
                shortcut: KeyboardShortcut(.return, modifiers: []), plainKey: true
            ) { attempt?.perform(.advance) }
            Divider()
            SessionMenuButton(
                title: state.isFlagged ? localized("Bỏ đánh dấu") : localized("Đánh dấu"),
                command: .toggleFlag, state: state,
                shortcut: KeyboardShortcut("d", modifiers: .command)
            ) { attempt?.perform(.toggleFlag) }
            SessionMenuButton(
                title: localized("Kiểm tra đáp án"), command: .checkAnswer, state: state,
                shortcut: KeyboardShortcut("k", modifiers: .command)
            ) { attempt?.perform(.checkAnswer) }
            Divider()
            SessionMenuButton(
                title: state.isPaused ? localized("Tiếp tục") : localized("Tạm dừng"),
                command: .togglePause, state: state,
                shortcut: KeyboardShortcut(".", modifiers: .command)
            ) { attempt?.perform(.togglePause) }
            SessionMenuButton(
                title: state.isNavigatorVisible ? localized("Ẩn bảng câu hỏi") : localized("Hiện bảng câu hỏi"),
                command: .toggleNavigator, state: state,
                // Chỉ giữ ⌃⌘I khi lệnh đang bật (cửa sổ làm bài đang dùng): bản Admin dùng cùng phím cho Ẩn/hiện xem
                // trước của cửa sổ soạn đề, và mục menu tắt vẫn có thể giữ phím.
                shortcut: KeyboardShortcut("i", modifiers: [.command, .control]), plainKey: true
            ) { attempt?.perform(.toggleNavigator) }
            Divider()
            SessionMenuButton(
                title: localized("Rà soát & nộp"), command: .openReview, state: state,
                shortcut: KeyboardShortcut(.return, modifiers: .command)
            ) { attempt?.perform(.openReview) }
            SessionMenuButton(
                title: localized("Quay lại làm bài"), command: .returnToAttempt, state: state,
                shortcut: KeyboardShortcut(.escape, modifiers: []), plainKey: true
            ) { attempt?.perform(.returnToAttempt) }
            SessionMenuButton(title: localized("Nộp bài…"), command: .submit, state: state, shortcut: nil) {
                window?.requestSubmit()
            }
        }
        CommandGroup(replacing: .printItem) {
            let route = ReportMenuRoute(sessionWindow: window, sessionState: state, target: reportTarget)
            Button(localized("Xuất PDF…")) { route.perform(.exportPDF) }
                .disabled(!route.isEnabled)
            Button(localized("In…")) { route.perform(.print) }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!route.isEnabled)
        }
    }
}

private struct SessionMenuButton: View {
    let title: String
    let command: AttemptCommand
    let state: SessionMenuState
    let shortcut: KeyboardShortcut?
    var plainKey = false
    let action: () -> Void

    var body: some View {
        let enabled = state.enabled.contains(command)
        Button(title, action: action)
            .keyboardShortcut(plainKey && !enabled ? nil : shortcut)
            .disabled(!enabled)
    }
}
