import InterfaceCore
import LibraryData
import SwiftUI
import UniformTypeIdentifiers

/// Cửa sổ Thư viện (docs/product/library.md, mục Cửa sổ): `NavigationSplitView` với sidebar **Tất cả đề**,
/// **Gần đây**, **Lịch sử thi**; thanh công cụ Thêm đề, tìm, sắp xếp, lọc, lưới/danh sách; kéo thả file;
/// thông báo không chặn; hộp thoại trùng id và báo file không thêm được.
///
/// Giao diện chỉ hiển thị trạng thái của `LibraryModel`/`LibraryStore` và gửi lệnh.
public struct LibraryRootView: View {
    @Bindable private var model: LibraryModel

    @AppStorage(LibraryPreferenceKey.viewMode) private var viewMode: LibraryViewMode = .grid
    @AppStorage(LibraryPreferenceKey.sortOrder) private var sortOrder: LibrarySortOrder = .recent
    @AppStorage(LibraryPreferenceKey.welcomeBanner) private var welcomeBanner: WelcomeBannerState = .notShown

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openDocument) private var openDocument
    @Environment(\.undoManager) private var undoManager
    @Environment(\.appearsActive) private var appearsActive

    @FocusState private var isSearchFocused: Bool
    @State private var isDropTargeted = false

    public init(model: LibraryModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 300)
        } detail: {
            LibraryDetailView(model: model, viewMode: viewMode, sortOrder: sortOrder, welcomeBanner: $welcomeBanner)
        }
        .navigationTitle(model.section.title)
        .navigationSubtitle(Text(subtitle))
        .searchable(text: $model.searchText, placement: .toolbar, prompt: Text(searchPrompt))
        .searchFocused($isSearchFocused)
        .toolbar { toolbar }
        .frame(minWidth: LibraryStyle.minWindowSize.width, minHeight: LibraryStyle.minWindowSize.height)
        .tint(LibraryStyle.accentForeground)
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            model.importFiles(urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted { DropTargetOverlay() }
        }
        .overlay(alignment: .bottom) {
            NoticeOverlay(model: model)
        }
        .fileImporter(
            isPresented: Binding(
                get: { model.fileImportRequest != nil && model.infoExamID == nil },
                set: { presented in if !presented { model.fileImporterDismissed() } }
            ),
            allowedContentTypes: [.examPackage],
            allowsMultipleSelection: model.fileImportRequest?.allowsMultipleSelection ?? true,
            onCompletion: { result in _ = model.completeFileImport(result) },
            onCancellation: { model.cancelFileImport() }
        )
        .modifier(LibraryPromptPresenter(model: model))
        .focusedSceneValue(\.libraryCommandContext, model.commandContext)
        .onAppear {
            // Cửa sổ Thư viện là `Window` (một bản duy nhất): mở lại hoặc đưa lên trước bằng `openWindow`.
            model.presentWindow = { openWindow(id: LibraryModel.windowID) }
            model.undoManager = undoManager
            welcomeBanner = welcomeBanner.after(start: model.startReport)
        }
        .onChange(of: model.startReport) { _, report in
            welcomeBanner = welcomeBanner.after(start: report)
        }
        .onChange(of: appearsActive) { _, isActive in
            // Làm mới trạng thái file mỗi khi cửa sổ được kích hoạt lại (chạy nền, không chặn giao diện).
            model.undoManager = undoManager
            if isActive { model.windowBecameActive() }
        }
        .onChange(of: model.searchFocusRequest) {
            isSearchFocused = true
        }
        .task(id: model.editRequest) {
            guard let request = model.editRequest else { return }
            do {
                try await openDocument(at: request.fileURL)
                model.finishEdit(request, error: nil)
            } catch {
                model.finishEdit(request, error: error)
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        switch model.section {
        case .all:
            parts.append(localized("\(model.store.entries.count) đề"))
        case .recent:
            parts.append(localized("\(model.recentEntries().count) đề"))
        case .history:
            parts.append(localized("\(model.store.attempts.count) lần thi"))
        }
        // Chỉ báo lần kiểm đầu tiên sau khi mở app (thẻ còn "Đang kiểm tra"); các lần làm mới khi cửa sổ
        // được kích hoạt lại chạy rất nhanh, báo ra sẽ làm tiêu đề nhấp nháy.
        if model.store.isRefreshing, model.store.entries.contains(where: { $0.status == .checking }) {
            parts.append(localized("Đang kiểm tra file…"))
        }
        if model.pendingOperations > 0 {
            parts.append(localized("Đang đọc file đề…"))
        }
        return parts.joined(separator: " · ")
    }

    private var searchPrompt: String {
        model.section == .history
            ? localized("Tìm theo tên đề hoặc thí sinh")
            : localized("Tìm theo tên hoặc mã đề")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                model.requestAddExams()
            } label: {
                Label(localized("Thêm đề"), systemImage: "plus")
            }
            .help(Text("Thêm đề (⌘O)", bundle: .module))
        }
        if model.section != .history {
            ToolbarItem {
                Menu {
                    Picker(localized("Sắp xếp"), selection: $sortOrder) {
                        ForEach(LibrarySortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(localized("Sắp xếp: \(sortOrder.title)"), systemImage: "arrow.up.arrow.down")
                }
                // Nút menu trên thanh công cụ chỉ hiện biểu tượng: nhãn trợ năng tường minh (kiểm trợ năng, bước 8b).
                .accessibilityLabel(Text("Sắp xếp: \(sortOrder.title)", bundle: .module))
                .disabled(model.section == .recent)
                .help(model.section == .recent
                    ? Text("Gần đây luôn xếp mới nhất trước", bundle: .module)
                    : Text("Sắp xếp: \(sortOrder.title)", bundle: .module))
            }
            ToolbarItem {
                Menu {
                    Picker(localized("Lọc"), selection: $model.filter) {
                        ForEach(LibraryFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(
                        localized("Lọc: \(model.filter.title)"),
                        systemImage: model.filter == .all
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                }
                .help(Text("Lọc: \(model.filter.title)", bundle: .module))
                .accessibilityLabel(Text("Lọc: \(model.filter.title)", bundle: .module))
            }
            ToolbarItem {
                Picker(localized("Chế độ xem"), selection: $viewMode) {
                    Label(localized("Lưới"), systemImage: "square.grid.2x2").tag(LibraryViewMode.grid)
                    Label(localized("Danh sách"), systemImage: "list.bullet").tag(LibraryViewMode.list)
                }
                .pickerStyle(.segmented)
                // Ô đang chọn có thể lấy tint làm nền dưới chữ/biểu tượng trắng: dùng #017777 (5,38:1).
                .tint(LibraryStyle.accent)
                .help(Text("Xem dạng lưới hoặc danh sách", bundle: .module))
            }
        }
    }
}

/// Sidebar: **Tất cả đề**, **Gần đây**, **Lịch sử thi**, kèm số lượng.
struct LibrarySidebar: View {
    let model: LibraryModel

    var body: some View {
        List(selection: Binding(
            get: { model.section },
            set: { section in if let section { model.selectSection(section) } }
        )) {
            row(.all, count: model.store.entries.count)
            row(.recent, count: model.recentEntries().count)
            row(.history, count: model.store.attempts.count)
        }
        .listStyle(.sidebar)
        // Dòng đang chọn có chữ trắng trên nền màu nhấn (nếu theo tint): dùng #017777 (5,38:1).
        .tint(LibraryStyle.accent)
    }

    private func row(_ section: LibrarySection, count: Int) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .badge(count)
            .tag(section)
    }
}

/// Vùng nội dung: dải thông báo, rồi lưới/danh sách đề hoặc Lịch sử thi; sheet **Thông tin**.
struct LibraryDetailView: View {
    @Bindable var model: LibraryModel
    let viewMode: LibraryViewMode
    let sortOrder: LibrarySortOrder
    @Binding var welcomeBanner: WelcomeBannerState

    var body: some View {
        VStack(spacing: 0) {
            LibraryBanners(model: model, welcomeBanner: $welcomeBanner)
            switch model.section {
            case .all, .recent:
                exams
            case .history:
                HistoryView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: Binding(
            get: { model.infoExamID.map(InfoTarget.init(id:)) },
            set: { target in model.infoExamID = target?.id }
        )) { target in
            ExamInfoSheet(model: model, examID: target.id)
                .presentationAllowsAppTermination()
        }
    }

    @ViewBuilder
    private var exams: some View {
        let entries = model.visibleEntries(order: sortOrder)
        Group {
            if entries.isEmpty {
                emptyState
            } else if viewMode == .grid {
                ExamGridView(model: model, entries: entries)
            } else {
                ExamTableView(model: model, entries: entries, sortOrder: sortOrder)
            }
        }
        .onChange(of: entries.map(\.examID)) { _, visible in
            model.keepSelection(within: visible)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.store.entries.isEmpty {
            ContentUnavailableView {
                Label(localized("Chưa có đề nào"), systemImage: "books.vertical")
            } description: {
                Text("Thêm file đề .exam bằng nút Thêm đề (⌘O) hoặc kéo file vào cửa sổ này.", bundle: .module)
            } actions: {
                Button(localized("Thêm đề…")) { model.requestAddExams() }
            }
        } else if !model.searchText.isEmpty {
            ContentUnavailableView.search(text: model.searchText)
        } else if let emptyTitle = model.filter.emptyTitle {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: "line.3.horizontal.decrease.circle")
            } actions: {
                Button(localized("Xem tất cả")) { model.filter = .all }
            }
        } else {
            ContentUnavailableView {
                Label(localized("Chưa có đề gần đây"), systemImage: "clock")
            } description: {
                Text("Đề có lần thi hoặc được thêm trong 30 ngày qua sẽ hiện ở đây.", bundle: .module)
            }
        }
    }
}

/// Hộp thoại chờ người dùng trả lời (`LibraryModel.prompts`), lần lượt từng cái: "Đề này đã có trong thư
/// viện từ file khác" (**Dùng file mới** / **Huỷ**), báo lỗi, và sheet báo những file không thêm được.
struct LibraryPromptPresenter: ViewModifier {
    let model: LibraryModel

    func body(content: Content) -> some View {
        let prompt = model.prompts.first
        let alertPrompt = prompt.flatMap { $0.isAlert ? $0 : nil }
        let problems = Self.problemsTarget(prompt)
        content
            .alert(
                Text(alertPrompt?.alertTitle ?? ""),
                isPresented: Binding(get: { alertPrompt != nil }, set: { _ in }),
                presenting: alertPrompt
            ) { prompt in
                switch prompt.kind {
                case .replace:
                    Button(localized("Dùng file mới")) { model.confirmReplacement(promptID: prompt.id) }
                        .keyboardShortcut(.defaultAction)
                    Button(localized("Huỷ"), role: .cancel) { model.dismissPrompt(prompt.id) }
                case .message, .importProblems:
                    Button(localized("OK")) { model.dismissPrompt(prompt.id) }
                        .keyboardShortcut(.defaultAction)
                }
            } message: { prompt in
                Text(prompt.alertMessage)
            }
            .sheet(item: Self.problemsBinding(problems, model: model)) { target in
                ImportProblemsSheet(problems: target.problems) {
                    model.dismissPrompt(target.id)
                }
                .presentationAllowsAppTermination()
            }
    }

    /// Sheet "file không thêm được" của lời nhắc `prompt` (nil nếu lời nhắc là hộp hỏi khác hoặc không có).
    static func problemsTarget(_ prompt: LibraryPrompt?) -> ImportProblemsTarget? {
        guard let prompt, case .importProblems(let problems) = prompt.kind else { return nil }
        return ImportProblemsTarget(id: prompt.id, problems: problems)
    }

    /// Binding của sheet "file không thêm được": SwiftUI đóng sheet (khi app thoát, kể cả lúc thoát bị huỷ sau đó) thì
    /// bỏ đúng lời nhắc đang hiện (`target`, không phải lời nhắc đứng đầu lúc đó), như mọi sheet khác của app; danh sách
    /// chỉ để đọc nên không cần mở lại (review độc lập PR #45, L1).
    static func problemsBinding(_ target: ImportProblemsTarget?, model: LibraryModel) -> Binding<ImportProblemsTarget?> {
        Binding(
            get: { target },
            set: { newValue in
                if newValue == nil, let target { model.dismissPrompt(target.id) }
            }
        )
    }
}

extension LibraryPrompt {
    var isAlert: Bool {
        if case .importProblems = kind { return false }
        return true
    }

    var alertTitle: String {
        switch kind {
        case .replace:
            localized("Đề này đã có trong thư viện từ file khác")
        case .message(let title, _):
            title
        case .importProblems:
            ""
        }
    }

    var alertMessage: String {
        switch kind {
        case .replace(let pending):
            localized("“\(pending.title)” đang dùng file:\n\(pending.existingFileURL.path)\n\nDùng file mới?\n\(pending.newFileURL.path)")
        case .message(_, let message):
            message
        case .importProblems:
            ""
        }
    }
}

struct ImportProblemsTarget: Identifiable {
    let id: UUID
    let problems: [ImportProblem]
}

/// Báo gọn những file không thêm được kèm lý do và bước tiếp theo, sau mỗi lần thêm.
struct ImportProblemsSheet: View {
    let problems: [ImportProblem]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Không thêm được \(problems.count) file", bundle: .module)
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LibraryStyle.warning)
            }
            .accessibilityAddTraits(.isHeader)
            List(problems) { problem in
                VStack(alignment: .leading, spacing: 3) {
                    Text(problem.fileName)
                        .font(.headline)
                    Text(problem.reason)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(problem.nextStep)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .textSelection(.enabled)
            }
            // Dòng đang chọn có chữ trắng trên nền màu nhấn (nếu theo tint): dùng #017777 (5,38:1).
            .tint(LibraryStyle.accent)
            .frame(minHeight: 120, idealHeight: min(CGFloat(problems.count) * 76 + 16, 360))
            HStack {
                Spacer()
                Button(localized("Đóng"), action: onClose)
                    .keyboardShortcut(.defaultAction)
                    // Nút mặc định có nền màu nhấn và chữ trắng: dùng #017777 (5,38:1) ở cả hai giao diện.
                    .tint(LibraryStyle.accent)
            }
        }
        .padding(20)
        .frame(minWidth: 480, idealWidth: 540)
        .onExitCommand(perform: onClose)
    }
}
