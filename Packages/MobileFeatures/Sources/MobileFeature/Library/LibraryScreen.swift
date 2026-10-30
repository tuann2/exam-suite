import InterfaceCore
import LibraryData
import SessionModel
import SwiftUI
import UniformTypeIdentifiers

/// Thư viện của bản iOS (docs/product/library.md; khác macOS ở mục Bản iOS của mobile.md): danh sách đề (v1 chỉ danh
/// sách; lưới, Thông tin đề, lọc, Khôi phục đề mẫu ở v1.1), **Gần đây**, **Lịch sử thi**; tìm, sắp xếp, trạng thái file
/// (biểu tượng + chữ), **Tìm file…**, kéo xuống để làm mới, vuốt để **Xoá khỏi thư viện** kèm **Hoàn tác**, dải chào
/// mừng, **Thêm đề** bằng hộp chọn file. Mọi luật ở `LibraryModel` (dùng chung với bản macOS); màn này chỉ hiện và gửi
/// lệnh.
struct LibraryScreen: View {
    @Bindable var library: LibraryModel
    let sessions: MobileSessionCoordinator
    let storage: AppLaunchStorage

    @AppStorage(LibraryPreferenceKey.sortOrder) private var sortOrder: LibrarySortOrder = .recent
    @AppStorage(LibraryPreferenceKey.welcomeBanner) private var welcomeBanner: WelcomeBannerState = .notShown
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if welcomeBanner == .visible, library.section != .history {
                    WelcomeBannerRow { welcomeBanner = .dismissed }
                }
                switch library.section {
                case .all, .recent:
                    ForEach(entries) { entry in
                        ExamRow(entry: entry, library: library)
                    }
                case .history:
                    ForEach(library.visibleAttempts()) { attempt in
                        HistoryRow(attempt: attempt) { library.openAttempt(attempt) }
                    }
                }
            }
            // Đề vừa thêm, vừa dùng file mới hay vừa Hoàn tác xoá (`LibraryModel.reveal` chọn đề): cuộn tới dòng của
            // nó (bản macOS chọn thẻ; danh sách iOS không có trạng thái chọn).
            .onChange(of: library.selection) { _, examID in
                guard let examID else { return }
                withAnimation { proxy.scrollTo(examID, anchor: .center) }
            }
        }
        .listStyle(.insetGrouped)
        .overlay { emptyState }
        .navigationTitle(library.section.title)
        .searchable(text: $library.searchText, prompt: Text(searchPrompt))
        .refreshable { await library.store.refreshAll() }
        .toolbar { toolbar }
        .fileImporter(
            isPresented: Binding(
                get: { library.fileImportRequest != nil && !sessions.isSessionPresented },
                set: { presented in if !presented { library.fileImporterDismissed() } }
            ),
            allowedContentTypes: [.examPackage],
            allowsMultipleSelection: library.fileImportRequest?.allowsMultipleSelection ?? true,
            onCompletion: { result in _ = library.completeFileImport(result) },
            onCancellation: { library.cancelFileImport() }
        )
        // Đang có phiên (màn của phiên che Thư viện) hay sheet Trước khi thi đang mở (iOS không hiện hộp thứ hai chồng
        // lên sheet): hộp hỏi của Thư viện (đề nhận từ app khác) chờ tới khi về Thư viện (QI12b).
        .modifier(LibraryPromptAlerts(
            library: library,
            isActive: !sessions.isSessionPresented && sessions.preExam == nil
        ))
        .safeAreaInset(edge: .bottom) {
            NoticeBar(library: library, sessions: sessions)
        }
        .onAppear {
            library.undoManager = undoManager
            welcomeBanner = welcomeBanner.after(start: library.startReport)
        }
        .onChange(of: library.startReport) { _, report in
            welcomeBanner = welcomeBanner.after(start: report)
        }
    }

    private var entries: [LibraryEntry] {
        library.section == .recent ? library.recentEntries() : library.visibleEntries(order: sortOrder)
    }

    private var searchPrompt: String {
        library.section == .history
            ? localized("Tìm theo tên đề hoặc thí sinh")
            : localized("Tìm theo tên hoặc mã đề")
    }

    @ViewBuilder
    private var emptyState: some View {
        switch library.section {
        case .all where library.store.entries.isEmpty:
            ContentUnavailableView {
                Label(localized("Chưa có đề nào"), systemImage: "books.vertical")
            } description: {
                Text("Thêm file đề .exam bằng nút Thêm đề, hoặc mở file .exam từ app khác.", bundle: .module)
            }
        case .recent where library.recentEntries().isEmpty:
            ContentUnavailableView {
                Label(localized("Chưa có đề gần đây"), systemImage: "clock")
            } description: {
                Text("Đề có lần thi hoặc được thêm trong 30 ngày qua sẽ hiện ở đây.", bundle: .module)
            }
        case .history where library.visibleAttempts().isEmpty && library.searchText.isEmpty:
            ContentUnavailableView {
                Label(localized("Chưa có lần thi nào"), systemImage: "list.bullet.rectangle")
            } description: {
                Text("Mỗi lần bạn nộp bài Luyện tập hoặc Thi sẽ được ghi ở đây, mới nhất trước.", bundle: .module)
            }
        case .all, .recent, .history:
            if !library.searchText.isEmpty, isSearchEmpty {
                ContentUnavailableView.search(text: library.searchText)
            }
        }
    }

    private var isSearchEmpty: Bool {
        library.section == .history ? library.visibleAttempts().isEmpty : entries.isEmpty
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker(localized("Mục"), selection: Binding(
                    get: { library.section },
                    set: { library.selectSection($0) }
                )) {
                    ForEach(LibrarySection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage).tag(section)
                    }
                }
                if library.section == .all {
                    Picker(localized("Sắp xếp"), selection: $sortOrder) {
                        ForEach(LibrarySortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                }
            } label: {
                Label(localized("Mục và sắp xếp"), systemImage: "line.3.horizontal.decrease.circle")
            }
            .accessibilityIdentifier("library.sections")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                addExams()
            } label: {
                Label(localized("Thêm đề"), systemImage: "plus")
            }
            .accessibilityIdentifier("library.add")
        }
    }

    /// **Thêm đề**: hộp chọn file `.exam` của iOS. UI test (build Debug, chế độ cô lập) thay hộp chọn file bằng file
    /// truyền vào (`-ExamSuiteUITestChosenFile`, như bản Admin macOS), vì XCUITest không lái được hộp chọn file.
    private func addExams() {
        #if DEBUG
        if let chosen = storage.revalidatedUITestChosenFile() {
            library.importFiles([chosen])
            return
        }
        #endif
        library.requestAddExams()
    }
}

/// Một đề trong danh sách: tên, mã, số câu, trạng thái (biểu tượng + chữ, màu chỉ để nhấn thêm), lần thi gần nhất. Chạm
/// để mở Trước khi thi (đề Sẵn sàng); vuốt để Xoá khỏi thư viện; giữ lâu để Luyện tập, Thi, Xem lịch sử thi, Tìm file….
struct ExamRow: View {
    let entry: LibraryEntry
    let library: LibraryModel

    var body: some View {
        let status = EntryStatusPresentation(status: entry.status, isAdmin: false)
        let latest = library.store.latestAttempt(examID: entry.examID)
        Button {
            library.startSession(entry.examID)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if entry.isSample {
                        Text("Đề mẫu", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(MobilePalette.secondaryText)
                    }
                }
                Text(LibraryFormat.facts(entry.summary))
                    .font(.subheadline)
                    .foregroundStyle(MobilePalette.secondaryText)
                Label {
                    Text(status.title)
                } icon: {
                    Image(systemName: status.systemImage)
                        .foregroundStyle(MobilePalette.color(status.tone))
                }
                .font(.subheadline)
                if let detail = status.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(MobilePalette.secondaryText)
                }
                if status.nextSteps.contains(.locateFile) {
                    Button(localized("Tìm file…")) { library.requestLocate(entry.examID) }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                }
                Text(LibraryFormat.lastAttempt(latest))
                    .font(.footnote)
                    .foregroundStyle(MobilePalette.secondaryText)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(!library.canStartSession(entry) && !status.nextSteps.contains(.locateFile))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LibraryAccessibility.cardSummary(entry: entry, latestAttempt: latest, isAdmin: false))
        .accessibilityIdentifier("library.row.\(entry.examID.uuidString)")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                library.remove(entry.examID)
            } label: {
                Label(localized("Xoá khỏi thư viện"), systemImage: "trash")
            }
        }
        .contextMenu {
            if library.canStartSession(entry) {
                Button(localized("Luyện tập"), systemImage: "pencil.and.list.clipboard") {
                    library.startSession(entry.examID, mode: .practice)
                }
                Button(localized("Thi"), systemImage: "timer") {
                    library.startSession(entry.examID, mode: .exam)
                }
            }
            Button(localized("Xem lịch sử thi"), systemImage: "list.bullet.rectangle") {
                library.showHistory(for: entry.examID)
            }
            if status.nextSteps.contains(.locateFile) {
                Button(localized("Tìm file…"), systemImage: "magnifyingglass") {
                    library.requestLocate(entry.examID)
                }
            }
            Button(localized("Xoá khỏi thư viện"), systemImage: "trash", role: .destructive) {
                library.remove(entry.examID)
            }
        }
    }
}

/// Một lần thi trong **Lịch sử thi**: ngày giờ, đề, thí sinh, chế độ, điểm, Đậu/Trượt. Chạm để mở Kết quả.
struct HistoryRow: View {
    let attempt: Attempt
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 3) {
                Text(attempt.examTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(LibraryFormat.dateTime(attempt.submittedAt))
                    .font(.subheadline)
                    .foregroundStyle(MobilePalette.secondaryText)
                HStack(spacing: 8) {
                    Text(attempt.candidateName)
                    Text(LibraryFormat.mode(attempt.mode))
                    Text(LibraryFormat.percent(attempt.percent))
                    Label {
                        Text(LibraryFormat.result(passed: attempt.passed))
                    } icon: {
                        Image(systemName: LibraryFormat.resultSymbol(passed: attempt.passed))
                            .foregroundStyle(attempt.passed ? MobilePalette.positive : MobilePalette.critical)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(MobilePalette.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LibraryAccessibility.historyRowCells(attempt).joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

/// Dải chào mừng sau lần đầu tạo đề mẫu; đóng thì không hiện lại.
struct WelcomeBannerRow: View {
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.wave")
                .foregroundStyle(MobilePalette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Chào mừng bạn đến với Exam Suite", bundle: .module)
                    .font(.headline)
                Text("Thư viện có sẵn đề mẫu để bạn làm quen. Thêm đề của bạn bằng nút Thêm đề, hoặc mở file .exam từ app khác.", bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(MobilePalette.secondaryText)
            }
            Spacer(minLength: 0)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(localized("Đóng"))
        }
        .accessibilityElement(children: .contain)
    }
}

/// Thông báo không chặn của Thư viện (đã thêm đề, đã xoá kèm Hoàn tác…) và của phiên thi ("Đang có bài chưa nộp", lỗi
/// mở đề), ở cuối màn; tự ẩn sau một lúc như bản macOS.
struct NoticeBar: View {
    let library: LibraryModel
    let sessions: MobileSessionCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if let notice = sessions.notice {
                bar(message: notice.message, undo: nil) { sessions.dismissNotice() }
                    .task(id: notice.id) {
                        AccessibilityNotification.Announcement(notice.message).post()
                        try? await Task.sleep(for: LibraryNotice.displayDuration)
                        if sessions.notice?.id == notice.id { sessions.dismissNotice() }
                    }
            }
            if let notice = library.notice {
                bar(message: notice.message, undo: notice.undoRemovalID) { library.dismissNotice() }
                    .task(id: notice.id) {
                        AccessibilityNotification.Announcement(notice.message).post()
                        try? await Task.sleep(for: LibraryNotice.displayDuration)
                        library.expireNotice(notice.id)
                    }
            }
        }
        .padding(.horizontal)
        .animation(reduceMotion ? nil : .snappy, value: library.notice)
        .animation(reduceMotion ? nil : .snappy, value: sessions.notice)
    }

    private func bar(message: String, undo: UUID?, close: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let undo {
                Button(localized("Hoàn tác")) { library.undoRemoval(undo) }
                    .buttonStyle(.bordered)
            }
            Button(action: close) {
                Image(systemName: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(localized("Đóng thông báo"))
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("library.notice")
    }
}

/// Hộp hỏi của Thư viện (trùng id: Dùng file mới / Huỷ; thông báo lỗi) lần lượt từng cái, và danh sách "file không thêm
/// được" kèm lý do và bước tiếp theo. Chữ dùng chung với bản macOS (`LibraryPrompt.alertTitle`, `alertMessage`).
struct LibraryPromptAlerts: ViewModifier {
    let library: LibraryModel
    let isActive: Bool

    func body(content: Content) -> some View {
        let prompt = isActive ? library.prompts.first : nil
        let alertPrompt = prompt.flatMap { $0.isAlert ? $0 : nil }
        content
            .alert(
                Text(alertPrompt?.alertTitle ?? ""),
                isPresented: Binding(get: { alertPrompt != nil }, set: { _ in }),
                presenting: alertPrompt
            ) { prompt in
                switch prompt.kind {
                case .replace:
                    Button(localized("Dùng file mới")) { library.confirmReplacement(promptID: prompt.id) }
                    Button(localized("Huỷ"), role: .cancel) { library.dismissPrompt(prompt.id) }
                case .message, .importProblems:
                    Button(localized("OK")) { library.dismissPrompt(prompt.id) }
                }
            } message: { prompt in
                Text(prompt.alertMessage)
            }
            .sheet(item: Binding(
                get: { ImportProblemsTarget(prompt) },
                set: { newValue in if newValue == nil, let prompt { library.dismissPrompt(prompt.id) } }
            )) { target in
                ImportProblemsSheet(problems: target.problems) { library.dismissPrompt(target.id) }
            }
    }
}

struct ImportProblemsTarget: Identifiable {
    let id: UUID
    let problems: [ImportProblem]

    init?(_ prompt: LibraryPrompt?) {
        guard let prompt, case .importProblems(let problems) = prompt.kind else { return nil }
        id = prompt.id
        self.problems = problems
    }
}

/// Báo gọn những file không thêm được kèm lý do và bước tiếp theo, sau mỗi lần thêm.
struct ImportProblemsSheet: View {
    let problems: [ImportProblem]
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List(problems) { problem in
                VStack(alignment: .leading, spacing: 3) {
                    Text(problem.fileName)
                        .font(.headline)
                    Text(problem.reason)
                    Text(problem.nextStep)
                        .foregroundStyle(MobilePalette.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
            .navigationTitle(localized("Không thêm được \(problems.count) file"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Đóng"), action: onClose)
                }
            }
        }
    }
}
