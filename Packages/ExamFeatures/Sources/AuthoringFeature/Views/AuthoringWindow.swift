import AppKit
import AuthoringData
import ExamKit
import LibraryFeature
import OSLog
import SessionFeature
import SwiftUI

/// Cửa sổ soạn đề (docs/product/authoring.md, mục Cửa sổ): `NavigationSplitView` với cây đề (trái) và trình soạn
/// (giữa), xem trước ở `.inspector` (phải, ⌃⌘I), thanh lỗi ở đáy cột giữa. Màu nhấn burgundy; tối thiểu 960×640.
/// Thanh tiêu đề (tên file, "Đã sửa"/"Đã lưu") là của macOS.
///
/// View chỉ hiển thị trạng thái của `AuthoringEditor` và gửi lệnh; mọi thay đổi đi qua bộ soạn đề (Hoàn tác).
public struct AuthoringWindow: View {
    @Bindable private var editor: AuthoringEditor

    @Environment(\.undoManager) private var undoManager
    @Environment(\.authoringHooks) private var hooks
    @FocusState private var focus: AuthoringFocus?
    @FocusState private var isSearchFocused: Bool
    /// **Xuất PDF…** / **In…** đề của cửa sổ này (docs/product/export-print.md, mục Bản Admin).
    @State private var reports = ExamReportController()

    /// Cỡ mặc định của cửa sổ soạn đề mới (`DocumentGroup.defaultSize` ở AdminShell).
    public static let defaultWindowSize = AuthoringStyle.defaultWindowSize

    public init(document: ExamAuthoringDocument) {
        editor = document.editor
    }

    public var body: some View {
        NavigationSplitView {
            AuthoringTree(editor: editor)
                .navigationSplitViewColumnWidth(
                    min: AuthoringStyle.treeColumnWidth.min,
                    ideal: AuthoringStyle.treeColumnWidth.ideal,
                    max: AuthoringStyle.treeColumnWidth.max
                )
        } detail: {
            // Báo cáo import và thanh lỗi nằm DƯỚI trình soạn (VStack), không phủ lên nó (`safeAreaInset`): khi danh sách
            // lỗi hay báo cáo mở, phần cuối của Form (ví dụ các lựa chọn của câu) nằm dưới lớp phủ mà vẫn được tính là
            // đang hiện, nên bấm vào đó trúng danh sách phía trên (UI test PR #42: ô "Đúng" của lựa chọn A, C không đổi;
            // dòng báo cáo không tìm được điểm bấm). WindowLayoutTests kiểm không có vùng chồng nhau.
            VStack(spacing: 0) {
                EditorColumn(editor: editor, focus: $focus)
                    .frame(maxHeight: .infinity)
                if let report = editor.importReport, editor.showsImportReport {
                    ImportReportPanel(editor: editor, report: report)
                }
                IssueBar(editor: editor)
            }
                // Không khai báo độ rộng tối thiểu, độ rộng lý tưởng cố định; xem trước gắn vào cột giữa (không vào cả
                // NavigationSplitView): để ba cột vừa cửa sổ 960 pt (AuthoringStyle, WindowLayoutTests).
                .frame(idealWidth: AuthoringStyle.editorIdealWidth, maxWidth: .infinity, maxHeight: .infinity)
                .inspector(isPresented: $editor.showsPreview) {
                    PreviewPane(editor: editor)
                        .inspectorColumnWidth(
                            min: AuthoringStyle.previewColumnWidth.min,
                            ideal: AuthoringStyle.previewColumnWidth.ideal,
                            max: AuthoringStyle.previewColumnWidth.max
                        )
                }
        }
        .searchable(text: $editor.searchText, placement: .sidebar, prompt: Text("Tìm nội dung câu", bundle: .module))
        .searchFocused($isSearchFocused)
        .toolbar {
            if let tryExam = hooks.tryExam {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        tryExam(editor)
                    } label: {
                        Label(localized("Thử đề này"), systemImage: "play.circle")
                    }
                    .help(Text("Lưu rồi thử đề này (⌘R)", bundle: .module))
                    .accessibilityIdentifier("authoring.tryExam")
                }
            }
            if editor.importReport != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editor.showsImportReport.toggle()
                    } label: {
                        Label(
                            editor.showsImportReport
                                ? localized("Ẩn báo cáo import") : localized("Hiện báo cáo import"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                    .help(Text("Ẩn/hiện báo cáo import", bundle: .module))
                    .accessibilityIdentifier("authoring.importReport.toggle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor.showsPreview.toggle()
                } label: {
                    Label(
                        editor.showsPreview ? localized("Ẩn xem trước") : localized("Hiện xem trước"),
                        systemImage: "sidebar.trailing"
                    )
                }
                .help(Text("Ẩn/hiện xem trước (⌃⌘I)", bundle: .module))
                .accessibilityIdentifier("authoring.togglePreview")
            }
        }
        .tint(AuthoringStyle.accentForeground)
        // Phóng to / Thu nhỏ / Cỡ thật và Nền đọc (menu Xem) cho xem trước (`QuestionPreview`); xem trước đang ẩn thì các
        // mục tắt. Mức và nền nhớ bằng `@AppStorage` chung với cửa sổ làm bài.
        .contentZoomScope(isAvailable: editor.showsPreview)
        .readingBackgroundScope(isAvailable: editor.showsPreview)
        // Trong lúc Xuất PDF/In chạy mà chưa có sheet nào (0,3 s đầu khi dựng, chuyển giữa các hộp), chuột không tác dụng
        // trên nội dung cửa sổ: bấm không mở thêm sheet (ảnh phóng to, hộp chọn ảnh), để sheet tiến độ trình bày được.
        // Chỉ chặn chuột: lệnh menu và phím (⌥⌘N, ⌘R, Xoá phần…) vẫn chạy trong khoảng đó (giới hạn đã biết, plan giai đoạn
        // 5, Decisions bước 6); PDF dùng ảnh chụp đề lúc mở hộp chọn nên không mất hay lẫn dữ liệu.
        .allowsHitTesting(reports.flow == nil)
        .frame(minWidth: AuthoringStyle.minWindowSize.width, minHeight: AuthoringStyle.minWindowSize.height)
        .focusedSceneValue(\.authoringEditor, editor)
        .focusedSceneValue(\.authoringMenuState, AuthoringMenuState(editor))
        // Menu Tệp › Xuất PDF… / In… (⌘P): nhóm in chung của cả app (`SessionCommands`), không thêm nhóm thứ hai.
        .focusedSceneValue(\.reportCommandTarget, reports.commandTarget(for: editor))
        // Hộp chọn và tiến độ của Xuất PDF/In đề; hộp lưu, hộp In, hộp báo lỗi là sheet của AppKit (`ReportPanels`).
        .sheet(isPresented: Binding(
            get: { reports.flow?.presentsSheet == true },
            set: { presented in if !presented { reports.flow?.sheetDismissed() } }
        )) {
            ExamReportSheet(controller: reports)
                .presentationAllowsAppTermination()
        }
        .background(ExamReportWindowReader(controller: reports))
        .onDisappear { reports.cancelAll() }
        .alert(
            editor.alert?.title ?? "",
            isPresented: Binding(get: { editor.alert != nil }, set: { if !$0 { editor.alert = nil } }),
            presenting: editor.alert
        ) { _ in
            Button(localized("OK")) { editor.alert = nil }
        } message: { alert in
            Text(alert.message)
        }
        .confirmationDialog(
            removalTitle,
            isPresented: Binding(
                get: { editor.sectionPendingRemoval != nil },
                set: { if !$0 { editor.sectionPendingRemoval = nil } }
            ),
            presenting: editor.sectionPendingRemoval
        ) { request in
            Button(localized("Xoá phần"), role: .destructive) { editor.removeSection(at: request.index) }
            Button(localized("Huỷ"), role: .cancel) { editor.sectionPendingRemoval = nil }
        } message: { request in
            Text(
                "Phần này có \(request.questionCount) câu. Xoá phần thì xoá luôn các câu đó; có thể Hoàn tác (⌘Z).",
                bundle: .module
            )
        }
        // Gán theo định danh của bộ soạn đề, không chỉ lúc cửa sổ hiện: Hoàn lại > Bản đã lưu, Duyệt các phiên bản hay
        // file bị app khác sửa làm SwiftUI dựng document (và bộ soạn đề) mới trong cùng cửa sổ; thiếu `UndoManager`
        // thì sửa không đánh dấu "Đã sửa" và đóng cửa sổ là mất thay đổi.
        .onChange(of: ObjectIdentifier(editor), initial: true) { _, _ in
            editor.undoManager = undoManager
        }
        .onChange(of: undoManager) { _, manager in
            // Cửa sổ đang đóng thì môi trường về `nil`: giữ tham chiếu yếu cũ (tự về `nil` khi UndoManager mất).
            if let manager { editor.undoManager = manager }
        }
        .background(DocumentURLReader(editor: editor))
        .background(AuthoringDocumentBridge(editor: editor))
        .onChange(of: editor.focusRequest) { _, request in
            guard let request else { return }
            // Trình soạn của dòng vừa chọn được dựng ở lượt cập nhật này; đặt tiêu điểm ở lượt sau.
            Task { @MainActor in focus = request.focus }
        }
        .onChange(of: focus) { _, _ in editor.endTyping() }
        .onChange(of: editor.searchFocusRequest) { _, _ in isSearchFocused = true }
    }

    private var removalTitle: String {
        guard let request = editor.sectionPendingRemoval else { return "" }
        return localized("Xoá phần “\(AuthoringPresentation.sectionTitle(request.title))”?")
    }
}

// MARK: - Lệnh menu

/// Trạng thái bật/tắt của lệnh menu, gửi qua `focusedSceneValue` khi cửa sổ soạn đề đang dùng.
public struct AuthoringMenuState: Hashable, Sendable {
    public let hasQuestionSelection: Bool
    public let hasSectionSelection: Bool
    public let canAddOption: Bool
    public let showsPreview: Bool

    @MainActor init(_ editor: AuthoringEditor) {
        hasQuestionSelection = editor.selectedQuestionPath != nil
        if case .section = editor.selection { hasSectionSelection = true } else { hasSectionSelection = false }
        canAddOption = editor.canAddOption
        showsPreview = editor.showsPreview
    }
}

struct AuthoringEditorKey: FocusedValueKey {
    typealias Value = AuthoringEditor
}

struct AuthoringMenuStateKey: FocusedValueKey {
    typealias Value = AuthoringMenuState
}

extension FocusedValues {
    var authoringEditor: AuthoringEditor? {
        get { self[AuthoringEditorKey.self] }
        set { self[AuthoringEditorKey.self] = newValue }
    }

    var authoringMenuState: AuthoringMenuState? {
        get { self[AuthoringMenuStateKey.self] }
        set { self[AuthoringMenuStateKey.self] = newValue }
    }
}

/// Lệnh của shell bản Admin cho cửa sổ soạn đề: mục menu (và nút **Thử đề này** trên thanh công cụ, qua
/// `.environment(\.authoringHooks, …)`) chỉ hiện khi shell gán.
public struct AuthoringHooks: Sendable {
    /// **File > Import đề…**: shell mở hộp chọn file và cửa sổ Import đề (`ImportFlowModel`, `ImportExamWindow`).
    public var importExam: (@MainActor @Sendable () -> Void)?
    /// **Đề > Thử đề này** (⌘R) và nút trên thanh công cụ: lưu rồi thử (authoring.md, mục Thử đề này;
    /// `TryExamCoordinator`).
    public var tryExam: (@MainActor @Sendable (AuthoringEditor) -> Void)?
    #if DEBUG
    /// Chỉ build Debug, chỉ chế độ cô lập của UI test (`-ExamSuiteUITestChosenFile`, `AppLaunchStorage`): **Thêm/Thay
    /// ảnh…** gọi hàm này thay hộp chọn file của macOS; hàm kiểm lại file ngay lúc gọi, `nil` thì không làm gì (không
    /// mở hộp chọn file). Bản thân móc là `nil` khi chạy bình thường.
    public var uiTestChooseImageFile: (@MainActor @Sendable () -> URL?)?
    #endif

    public init(
        importExam: (@MainActor @Sendable () -> Void)? = nil,
        tryExam: (@MainActor @Sendable (AuthoringEditor) -> Void)? = nil
    ) {
        self.importExam = importExam
        self.tryExam = tryExam
    }
}

extension EnvironmentValues {
    /// Lệnh của shell cho cửa sổ soạn đề (nút **Thử đề này** trên thanh công cụ).
    @Entry public var authoringHooks = AuthoringHooks()
}

/// Lệnh menu của cửa sổ soạn đề (authoring.md, mục Bàn phím và trợ năng):
///
/// - **Đề**: Thêm phần, Thêm câu (⌥⌘N), Thêm lựa chọn (⌥⌘↩), Nhân bản câu, Xoá; Thử đề này (⌘R).
/// - **Xem > Ẩn/hiện xem trước** (⌃⌘I), **Sửa > Tìm trong cây đề** (⌘F). Hai phím này trùng phím của
///   menu Bài thi (⌃⌘I) và Thư viện (⌘F), nên chỉ gắn vào mục menu khi cửa sổ soạn đề đang dùng; mục tắt
///   không giữ phím.
public struct AuthoringCommands: Commands {
    private let hooks: AuthoringHooks

    @FocusedValue(\.authoringEditor) private var editor
    @FocusedValue(\.authoringMenuState) private var state

    public init(hooks: AuthoringHooks = AuthoringHooks()) {
        self.hooks = hooks
    }

    public var body: some Commands {
        CommandMenu(localized("Đề")) {
            Button(localized("Thêm phần")) { editor?.addSection() }
                .disabled(state == nil)
            Button(localized("Thêm câu")) { editor?.addQuestion() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(state == nil)
            Button(localized("Thêm lựa chọn")) {
                if let editor, let path = editor.selectedQuestionPath { editor.addOption(to: path) }
            }
            .keyboardShortcut(.return, modifiers: [.command, .option])
            .disabled(state?.canAddOption != true)
            Divider()
            Button(localized("Nhân bản câu")) {
                if let editor, let path = editor.selectedQuestionPath { editor.duplicateQuestion(at: path) }
            }
            .disabled(state?.hasQuestionSelection != true)
            Button(state?.hasSectionSelection == true ? localized("Xoá phần…") : localized("Xoá câu")) {
                editor?.removeSelection()
            }
                .disabled(state?.hasQuestionSelection != true && state?.hasSectionSelection != true)
            if let tryExam = hooks.tryExam {
                Divider()
                Button(localized("Thử đề này")) { if let editor { tryExam(editor) } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(state == nil)
            }
        }
        if let importExam = hooks.importExam {
            CommandGroup(after: .newItem) {
                Button(localized("Import đề…")) { importExam() }
            }
        }
        CommandGroup(after: .sidebar) {
            Button(state?.showsPreview == false ? localized("Hiện xem trước") : localized("Ẩn xem trước")) {
                editor?.showsPreview.toggle()
            }
                .keyboardShortcut(state == nil ? nil : KeyboardShortcut("i", modifiers: [.command, .control]))
                .disabled(state == nil)
        }
        CommandGroup(after: .textEditing) {
            Button(localized("Tìm trong cây đề")) { editor?.requestSearchFocus() }
                .keyboardShortcut(state == nil ? nil : KeyboardShortcut("f", modifiers: .command))
                .disabled(state == nil)
        }
    }
}

/// Cho bộ soạn đề biết đường dẫn file của document (qua `NSWindow` → `NSDocument`), để đọc lại file trên đĩa sau
/// khi lưu (lý do bản Học viên từ chối file, ảnh sai tên).
private struct DocumentURLReader: NSViewRepresentable {
    let editor: AuthoringEditor

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        editor.documentURL = { [weak view] in
            guard let window = view?.window else { return nil }
            let document = (window.windowController?.document as? NSDocument)
                ?? NSDocumentController.shared.document(for: window)
            if document == nil {
                Self.log.error("Authoring window has no NSDocument: cannot re-read the saved file")
            }
            return document?.fileURL
        }
    }

    private static let log = Logger(subsystem: "vn.io.nt0.examsuite.admin", category: "authoring.window")
}
