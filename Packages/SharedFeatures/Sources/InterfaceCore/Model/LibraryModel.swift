import ExamKit
import Foundation
import LibraryData
import Observation
import OSLog

/// Trạng thái giao diện của cửa sổ Thư viện và các lệnh người dùng gửi (docs/product/library.md).
///
/// Mỗi bản app có đúng một cửa sổ Thư viện nên có đúng một `LibraryModel`, sống suốt đời app (giữ ở
/// app delegate). Logic thư viện (nhập file, trạng thái file, xoá, đề mẫu, lần thi) nằm ở
/// `LibraryStore` của LibraryData; model này chỉ giữ điều hướng, hộp thoại, thông báo và nối lệnh với
/// store. Lệnh menu (`LibraryCommands`) và app delegate dùng chung model này, không qua biến toàn cục.
@Observable
@MainActor
public final class LibraryModel {
    /// Id của scene `Window` Thư viện (`openWindow(id:)`).
    public static let windowID = "library"

    public let store: LibraryStore

    // MARK: - Điều hướng

    public private(set) var section: LibrarySection = .all
    /// Đề đang chọn trong lưới hoặc danh sách.
    public var selection: UUID?
    /// **Xem lịch sử thi** từ một đề: Lịch sử thi chỉ hiện đề này.
    public private(set) var historyExamID: UUID?
    public var searchText = ""
    public var filter: LibraryFilter = .all

    // MARK: - Trình bày

    /// Đề đang mở sheet **Thông tin**.
    public var infoExamID: UUID?
    /// Hộp thoại chọn file đang được yêu cầu.
    public private(set) var fileImportRequest: FileImportRequest?
    /// Hộp thoại chờ người dùng trả lời, hiện lần lượt.
    public private(set) var prompts: [LibraryPrompt] = []
    /// Thông báo không chặn đang hiện.
    public private(set) var notice: LibraryNotice?
    /// Kết quả `LibraryStore.start()` (có sau khi mở app xong): giao diện dùng để hiện dải chào mừng.
    public private(set) var startReport: SampleReport?
    /// **Sửa** đang chờ cửa sổ Thư viện mở bằng `openDocument(at:)` (bản Admin).
    public private(set) var editRequest: EditRequest?
    /// Tăng mỗi lần cần đưa tiêu điểm vào ô tìm kiếm (⌘F).
    public private(set) var searchFocusRequest = 0
    /// Số việc nhập/tìm file/khôi phục đề mẫu đang chờ hoặc đang chạy.
    public private(set) var pendingOperations = 0

    /// Mở cửa sổ Thư viện hoặc đưa nó lên trước; cửa sổ Thư viện gán khi xuất hiện (`openWindow`).
    @ObservationIgnored public var presentWindow: (@MainActor () -> Void)?
    /// Lệnh làm bài (Luyện tập, Thi, mở lần thi); shell gán khi tạo app. Nil thì các nút làm bài tắt.
    public var sessionActions: LibrarySessionActions?
    /// `UndoManager` của cửa sổ Thư viện, để ⌘Z hoàn tác **Xoá khỏi thư viện**.
    @ObservationIgnored public weak var undoManager: UndoManager?

    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var operationQueue: Task<Void, Never>?
    @ObservationIgnored private var removals: [UUID: RemovalUndo] = [:]
    @ObservationIgnored private var dismissedFileImport: FileImportRequest?
    /// Việc làm tiếp sau **Dùng file mới** của một hộp hỏi (theo id hộp hỏi), từ `addExamFile(_:afterReplacing:)`.
    @ObservationIgnored private var replacementFollowUps: [UUID: @MainActor (UUID) -> Void] = [:]
    @ObservationIgnored private let revealFiles: @MainActor ([URL]) -> Void
    @ObservationIgnored private let now: () -> Date

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? LibraryConfiguration.studentBundleIdentifier,
        category: "library.ui"
    )

    /// - Parameters:
    ///   - startsAutomatically: gọi `start()` ngay (app); test tắt để tự điều khiển.
    ///   - revealFiles: **Hiện trong Finder**: bản macOS truyền `NSWorkspace` (`LibraryModel.persistent` của
    ///     LibraryFeature); iOS không có lệnh này; test thay để ghi lại. Mặc định không làm gì, vì module này dùng
    ///     chung với iOS, không import AppKit.
    public init(
        store: LibraryStore,
        startsAutomatically: Bool = true,
        revealFiles: @escaping @MainActor ([URL]) -> Void = { _ in },
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.revealFiles = revealFiles
        self.now = now
        if startsAutomatically { start() }
    }

    public var isAdmin: Bool { store.configuration.isAdmin }

    // MARK: - Mở app, làm mới

    /// Mở app: tải kho ngay (thẻ hiện từ dữ liệu đã lưu, và file mở từ Finder lúc khởi động nhập được
    /// đúng vào kho đã tải), rồi chạy `LibraryStore.start()` ở nền: tạo đề mẫu lần đầu, làm mới trạng thái
    /// file. Gọi lại không làm gì.
    public func start() {
        guard startTask == nil else { return }
        store.load()
        startTask = Task { [weak self] in
            guard let store = self?.store else { return }
            let report = await store.start()
            self?.didStart(report)
        }
    }

    private func didStart(_ report: SampleReport) {
        startReport = report
        for failure in report.failures {
            let reason = failure.reason.logMessage // l10n-ignore: câu tiếng Việt chỉ cho nhật ký
            Self.log.error("Sample \(failure.sampleName, privacy: .public) not installed: \(reason, privacy: .public)")
        }
    }

    /// Chờ `start()` xong (test).
    public func waitUntilStarted() async {
        await startTask?.value
    }

    /// Cửa sổ Thư viện được kích hoạt lại: làm mới trạng thái file ở nền. Trước khi mở app xong thì bỏ
    /// qua, vì `start()` đang làm mới.
    public func windowBecameActive() {
        guard startReport != nil else { return }
        Task { await store.refreshAll() }
    }

    // MARK: - Điều hướng

    /// Đề hiện trong vùng nội dung theo mục sidebar, ô tìm kiếm, bộ lọc và cách sắp xếp.
    /// **Gần đây** luôn xếp mới nhất trước.
    public func visibleEntries(order: LibrarySortOrder) -> [LibraryEntry] {
        switch section {
        case .all:
            LibraryQuery.apply(
                store.entries,
                query: searchText,
                filter: filter,
                order: order,
                latestAttempts: store.latestAttempts
            )
        case .recent:
            LibraryQuery.filter(LibraryQuery.search(recentEntries(), query: searchText), by: filter)
        case .history:
            []
        }
    }

    /// Đề của mục **Gần đây** (chưa tìm, chưa lọc).
    public func recentEntries() -> [LibraryEntry] {
        LibraryQuery.recent(store.entries, latestAttempts: store.latestAttempts, now: now())
    }

    /// Lần thi hiện trong **Lịch sử thi**: mới nhất trước, lọc theo đề nếu đang **Xem lịch sử thi** của
    /// một đề, và theo ô tìm kiếm (tên đề lúc thi hoặc thí sinh, không phân biệt hoa thường và dấu).
    public func visibleAttempts() -> [Attempt] {
        let attempts = store.attempts(examID: historyExamID)
        let words = LibraryQuery.searchKey(searchText).split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return attempts }
        return attempts.filter { attempt in
            let haystack = LibraryQuery.searchKey(attempt.examTitle) + "\n"
                + LibraryQuery.searchKey(attempt.candidateName)
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    /// Tên đề đang lọc trong Lịch sử thi (đề có thể đã bị xoá khỏi thư viện: lấy tên lúc thi).
    public var historyExamTitle: String? {
        guard let historyExamID else { return nil }
        return store.entry(historyExamID)?.title ?? store.attempts(examID: historyExamID).first?.examTitle
    }

    public func selectSection(_ newSection: LibrarySection) {
        guard newSection != section else { return }
        if newSection != .history { historyExamID = nil }
        section = newSection
    }

    /// **Xem lịch sử thi** của một đề.
    public func showHistory(for examID: UUID) {
        historyExamID = examID
        section = .history
    }

    /// Bỏ lọc theo đề trong Lịch sử thi.
    public func showAllHistory() {
        historyExamID = nil
    }

    /// Chọn đề và bảo đảm nó hiện: về **Tất cả đề** nếu mục hiện tại không có đề này, bỏ tìm kiếm và bộ
    /// lọc nếu chúng đang ẩn đề này.
    public func reveal(_ examID: UUID) {
        guard let entry = store.entry(examID) else { return }
        if section == .history { selectSection(.all) }
        if section == .recent, !recentEntries().contains(where: { $0.examID == examID }) { selectSection(.all) }
        if !LibraryQuery.matches(entry, query: searchText) { searchText = "" }
        if LibraryQuery.filter([entry], by: filter).isEmpty { filter = .all }
        selection = examID
    }

    /// Bỏ chọn nếu đề đang chọn không còn hiện (bị tìm kiếm/lọc ẩn), để lệnh menu không tác động lên đề
    /// người dùng không thấy.
    public func keepSelection(within visible: [UUID]) {
        if let selection, !visible.contains(selection) { self.selection = nil }
    }

    /// Phím mũi tên trong lưới `columns` cột.
    public func moveSelection(_ direction: GridNavigation.Direction, in visible: [UUID], columns: Int) {
        let current = selection.flatMap { visible.firstIndex(of: $0) }
        guard let next = GridNavigation.move(
            from: current,
            direction: direction,
            count: visible.count,
            columns: columns
        ) else { return }
        selection = visible[next]
    }

    /// ⌘F: đưa tiêu điểm vào ô tìm kiếm.
    public func requestSearchFocus() {
        searchFocusRequest += 1
    }

    public var commandContext: LibraryCommandContext {
        guard section != .history, let selection, let entry = store.entry(selection) else {
            return LibraryCommandContext(selectedExamID: nil, canRevealSelection: false, canEditSelection: false)
        }
        return LibraryCommandContext(
            selectedExamID: selection,
            canRevealSelection: entry.status != .missing,
            canEditSelection: canEdit(entry)
        )
    }

    // MARK: - Thêm đề, tìm file

    /// **Thêm đề…** (nút, ⌘O, menu File).
    public func requestAddExams() {
        infoExamID = nil
        fileImportRequest = .addExams
    }

    /// **Tìm file…** cho đề mất file. Đóng sheet Thông tin (nếu đang mở) để hộp thoại chọn file hiện được.
    public func requestLocate(_ examID: UUID) {
        infoExamID = nil
        fileImportRequest = .locate(examID: examID)
    }

    /// Hộp thoại chọn file đã đóng. Giữ lại yêu cầu cho `completeFileImport` vì SwiftUI có thể báo đóng
    /// trước khi trả kết quả.
    public func fileImporterDismissed() {
        if let fileImportRequest { dismissedFileImport = fileImportRequest }
        fileImportRequest = nil
    }

    /// Người dùng huỷ hộp thoại chọn file.
    public func cancelFileImport() {
        fileImportRequest = nil
        dismissedFileImport = nil
    }

    /// Kết quả hộp thoại chọn file: thêm các file đã chọn, hoặc tìm lại file của đề.
    @discardableResult
    public func completeFileImport(_ result: Result<[URL], any Error>) -> Task<Void, Never>? {
        let request = fileImportRequest ?? dismissedFileImport
        cancelFileImport()
        guard let request else { return nil }
        switch result {
        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return nil }
            showError(title: localized("Không chọn được file"), error)
            return nil
        case .success(let urls):
            switch request {
            case .addExams:
                return importFiles(urls)
            case .locate(let examID):
                guard let url = urls.first else { return nil }
                return locate(examID, at: url)
            }
        }
    }

    /// Thêm file (hộp thoại Thêm đề, kéo thả). Các lần thêm chạy lần lượt để hai lần thêm cùng một file
    /// không thành hai mục; kết quả: chọn đề, thông báo, hỏi Dùng file mới, báo file không thêm được.
    @discardableResult
    public func importFiles(_ urls: [URL]) -> Task<Void, Never> {
        enqueue { model in await model.runImport(urls) }
    }

    /// Thêm **một** file như **Thêm đề** (cùng hàng đợi, cùng thông báo/hộp thoại trên cửa sổ Thư viện) và trả kết quả
    /// của file đó, để người gọi làm tiếp (bản Admin: **Thử đề này** mở Trước khi thi khi đề có trong Thư viện;
    /// docs/product/authoring.md). `nil` nếu không có kết quả.
    ///
    /// - Parameter afterReplacing: file cùng id đề với một mục đã có nhưng khác file (`needsReplaceConfirmation`):
    ///   gọi với id đề sau khi người dùng chọn **Dùng file mới** và file mới đã được dùng; **Huỷ** (hoặc dùng file mới
    ///   không được) thì không gọi.
    ///
    /// Hộp hỏi Dùng file mới **cũ** của cùng file (người dùng chưa trả lời mà lại thêm file đó lần nữa, ví dụ bấm Thử đề
    /// này lần hai) được bỏ trước khi thêm: chỉ còn một hộp hỏi, với kết luận đọc file mới nhất.
    public func addExamFile(
        _ url: URL,
        afterReplacing: (@MainActor (_ examID: UUID) -> Void)? = nil
    ) async -> ImportOutcome? {
        for prompt in prompts {
            if case let .replace(pending) = prompt.kind, Self.sameFile(pending.newFileURL, url) {
                dismissPrompt(prompt.id)
            }
        }
        let box = ImportOutcomeBox()
        await enqueue { model in
            box.outcome = await model.runImport([url])
        }.value
        if case let .needsReplaceConfirmation(pending)? = box.outcome, let afterReplacing,
           let prompt = prompts.last(where: { $0.kind == .replace(pending) }) {
            replacementFollowUps[prompt.id] = afterReplacing
        }
        return box.outcome
    }

    /// Hai đường dẫn chỉ cùng một file (so sau khi giải liên kết, như `/var` → `/private/var`).
    static func sameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath().path == rhs.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Bản Học viên: file `.exam` mở từ Finder (nhấp đúp, Open With, kéo vào biểu tượng Dock). Đi qua
    /// đúng luồng Thêm đề; mở cửa sổ Thư viện hoặc đưa nó lên trước.
    @discardableResult
    public func openFromFinder(_ urls: [URL]) -> Task<Void, Never> {
        // Đóng sheet Thông tin (nếu đang mở) để thấy đề vừa thêm và hộp thoại của lần thêm này.
        infoExamID = nil
        presentWindow?()
        return importFiles(urls)
    }

    /// **Tìm file…**: file chọn phải là cùng đề; không dùng được thì báo lý do, không đổi gì.
    @discardableResult
    public func locate(_ examID: UUID, at url: URL) -> Task<Void, Never> {
        enqueue { model in await model.runLocate(examID, url: url) }
    }

    /// Thêm các file, hiện kết quả trên Thư viện; trả kết quả của file đầu tiên.
    @discardableResult
    func runImport(_ urls: [URL]) async -> ImportOutcome? {
        guard !urls.isEmpty else { return nil }
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { for url in scoped { url.stopAccessingSecurityScopedResource() } }
        let report = await store.importFiles(urls)
        apply(ImportFeedback(report: report, titles: titlesByExamID()))
        return report.items.first?.outcome
    }

    func apply(_ feedback: ImportFeedback) {
        if let examID = feedback.examIDToSelect { reveal(examID) }
        if let message = feedback.notice { show(LibraryNotice(message: message)) }
        prompts.append(contentsOf: feedback.replacements.map { LibraryPrompt(.replace($0)) })
        if !feedback.problems.isEmpty {
            prompts.append(LibraryPrompt(.importProblems(feedback.problems)))
        }
    }

    func runLocate(_ examID: UUID, url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try await store.relocate(examID, to: url)
            reveal(examID)
            let title = store.entry(examID)?.title ?? url.lastPathComponent
            show(LibraryNotice(message: localized("Đã tìm thấy file của đề “\(title)”.")))
        } catch {
            showError(title: localized("Không dùng được file này"), error)
        }
    }

    private func titlesByExamID() -> [UUID: String] {
        Dictionary(store.entries.map { ($0.examID, $0.title) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Hộp thoại

    public func dismissPrompt(_ id: UUID) {
        prompts.removeAll { $0.id == id }
        replacementFollowUps[id] = nil
    }

    /// **Dùng file mới** cho hộp thoại "Đề này đã có trong thư viện từ file khác".
    public func confirmReplacement(promptID: UUID) {
        guard let prompt = prompts.first(where: { $0.id == promptID }),
              case .replace(let pending) = prompt.kind
        else { return }
        let followUp = replacementFollowUps[promptID]
        dismissPrompt(promptID)
        do {
            try store.confirmReplace(pending)
            reveal(pending.examID)
            show(LibraryNotice(message: localized("Đề “\(pending.title)” giờ dùng file mới.")))
            followUp?(pending.examID)
        } catch {
            showError(title: localized("Không dùng được file mới"), error)
        }
    }

    func showError(title: String, _ error: any Error) {
        prompts.append(LibraryPrompt(.message(title: title, message: ErrorMessages.message(for: error))))
    }

    // MARK: - Thông báo

    public func show(_ notice: LibraryNotice) {
        self.notice = notice
        // Nút Hoàn tác chỉ có trên thông báo đang hiện; lần xoá cũ vẫn hoàn tác được bằng ⌘Z.
        removals = removals.filter { $0.key == notice.undoRemovalID }
    }

    /// Thông báo hết giờ: chỉ ẩn nếu vẫn là thông báo đó (đồng hồ cũ không ẩn thông báo mới hơn).
    public func expireNotice(_ id: UUID) {
        if notice?.id == id { notice = nil }
    }

    public func dismissNotice() {
        notice = nil
    }

    // MARK: - Xoá khỏi thư viện, hoàn tác

    /// **Xoá khỏi thư viện**: chỉ xoá mục (không xoá file, không xoá lịch sử thi), không hỏi lại; hiện
    /// thông báo "Đã xoá khỏi thư viện" kèm **Hoàn tác**, và đăng ký với `undoManager` để ⌘Z hoàn tác.
    public func remove(_ examID: UUID) {
        do {
            let removed = try store.remove(examID)
            didRemove(RemovalUndo(removed: removed, undoManager: undoManager))
        } catch {
            showError(title: localized("Không xoá được đề khỏi thư viện"), error)
        }
    }

    /// Nút **Hoàn tác** trên thông báo: hoàn tác lần xoá đó và bỏ bước tương ứng khỏi ngăn ⌘Z.
    public func undoRemoval(_ removalID: UUID) {
        guard let undo = removals[removalID] else { return }
        undo.undoManager?.removeAllActions(withTarget: undo)
        restore(undo)
    }

    private func didRemove(_ undo: RemovalUndo) {
        let examID = undo.removed.examID
        if selection == examID { selection = nil }
        if infoExamID == examID { infoExamID = nil }
        removals[undo.id] = undo
        registerUndo(of: undo)
        show(LibraryNotice(
            message: localized("Đã xoá “\(undo.removed.entry.title)” khỏi thư viện."),
            undoRemovalID: undo.id
        ))
    }

    /// UndoManager chỉ giữ target bằng tham chiếu unowned: closure giữ `undo` mạnh để target sống đúng
    /// bằng bước hoàn tác trong ngăn (bỏ khỏi ngăn thì closure và `undo` được giải phóng theo).
    private func registerUndo(of undo: RemovalUndo) {
        guard let undoManager = undo.undoManager else { return }
        undoManager.registerUndo(withTarget: undo) { [weak self, undo] _ in
            // UndoManager của cửa sổ gọi trên main thread.
            MainActor.assumeIsolated { self?.restore(undo) }
        }
        undoManager.setActionName(localized("Xoá khỏi thư viện"))
    }

    /// Đưa đề trở lại thư viện y nguyên. Khi chạy trong ⌘Z thì đăng ký Làm lại (⇧⌘Z) xoá lại đề đó.
    private func restore(_ undo: RemovalUndo) {
        removals[undo.id] = nil
        do {
            try store.undoRemove(undo.removed)
        } catch {
            showError(title: localized("Không hoàn tác được"), error)
            return
        }
        if notice?.undoRemovalID == undo.id { notice = nil }
        reveal(undo.removed.examID)
        guard let undoManager = undo.undoManager, undoManager.isUndoing else { return }
        undoManager.registerUndo(withTarget: undo) { [weak self, undo] _ in
            MainActor.assumeIsolated { self?.removeAgain(undo) }
        }
        undoManager.setActionName(localized("Xoá khỏi thư viện"))
    }

    /// Làm lại (⇧⌘Z) sau khi hoàn tác: xoá lại đề, lại có thông báo và ⌘Z.
    private func removeAgain(_ undo: RemovalUndo) {
        do {
            undo.removed = try store.remove(undo.removed.examID)
        } catch {
            showError(title: localized("Không xoá được đề khỏi thư viện"), error)
            return
        }
        didRemove(undo)
    }

    // MARK: - Làm bài

    /// **Luyện tập** / **Thi** / nhấp đúp / Return làm bài được: chỉ khi đề **Sẵn sàng**, ở cả hai bản app
    /// (docs/product/exam-taking.md, phương án 5).
    public func canStartSession(_ entry: LibraryEntry) -> Bool {
        sessionActions != nil && entry.status == .ready
    }

    /// Mở **Trước khi thi** cho đề. `mode` nil (nhấp đúp, Return) dùng chế độ lần trước. Đề chưa Sẵn sàng thì
    /// không làm gì (hành động tắt).
    @discardableResult
    public func startSession(_ examID: UUID, mode: SessionMode? = nil) -> Bool {
        guard let entry = store.entry(examID), canStartSession(entry), let sessionActions else { return false }
        selection = examID
        infoExamID = nil
        sessionActions.openPreExam(examID, mode)
        return true
    }

    /// Mở **Kết quả** của một lần thi (Lịch sử thi: nhấp đúp hoặc Return).
    public func openAttempt(_ attempt: Attempt) {
        sessionActions?.openAttempt(attempt)
    }

    // MARK: - Thông tin, Finder, lịch sử, Sửa

    /// **Thông tin** (⌘I, menu chuột phải, nút "…", hành động trợ năng).
    public func showInfo(_ examID: UUID) {
        guard store.entry(examID) != nil else { return }
        selection = examID
        infoExamID = examID
    }

    /// **Hiện trong Finder**; file không còn thì báo, không mở Finder.
    public func revealInFinder(_ examID: UUID) {
        guard let entry = store.entry(examID) else { return }
        guard FileManager.default.fileExists(atPath: entry.fileURL.path) else {
            show(LibraryNotice(message: localized("Không tìm thấy file của đề “\(entry.title)”.")))
            return
        }
        revealFiles([entry.fileURL])
    }

    /// **Sửa** dùng được không: chỉ bản Admin, khi file đọc được ở chế độ dễ (hoặc chưa kiểm xong).
    public func canEdit(_ entry: LibraryEntry) -> Bool {
        guard isAdmin else { return false }
        switch entry.status {
        case .ready, .checking, .readableWithIssues:
            return true
        case .missing, .corrupt, .needsNewerApp, .invalid:
            return false
        }
    }

    /// **Sửa** (⌘E, bản Admin): cửa sổ Thư viện mở file bằng `openDocument(at:)`.
    public func requestEdit(_ examID: UUID) {
        guard let entry = store.entry(examID), canEdit(entry) else { return }
        infoExamID = nil
        editRequest = EditRequest(examID: examID, fileURL: entry.fileURL)
    }

    /// Cửa sổ Thư viện đã mở xong (hoặc không mở được) đề để sửa.
    public func finishEdit(_ request: EditRequest, error: (any Error)?) {
        guard editRequest?.id == request.id else { return }
        editRequest = nil
        if let error {
            showError(title: localized("Không mở được đề để sửa"), error)
        } else {
            store.markOpened(request.examID)
        }
    }

    // MARK: - Đề mẫu

    /// **Trợ giúp > Khôi phục đề mẫu**: thêm lại đề mẫu đã xoá, ghi lại file đề mẫu bị mất, rồi báo kết quả.
    @discardableResult
    public func restoreSamples() -> Task<Void, Never> {
        enqueue { model in await model.runRestoreSamples() }
    }

    func runRestoreSamples() async {
        let report = await store.restoreSamples()
        guard report.sampleCount > 0 else {
            prompts.append(LibraryPrompt(.message(
                title: localized("Không có đề mẫu"),
                message: localized("Bản app này không kèm đề mẫu.")
            )))
            return
        }
        if let first = report.addedExamIDs.first { reveal(first) }
        if report.didAddSamples {
            show(LibraryNotice(message: localized("Đã khôi phục \(report.addedExamIDs.count) đề mẫu.")))
        } else if report.failures.isEmpty {
            show(LibraryNotice(message: localized("Đề mẫu đã có đủ trong thư viện.")))
        }
        if !report.failures.isEmpty {
            let lines = report.failures.map { "\($0.sampleName): \(ErrorMessages.message(for: $0.reason))" }
            prompts.append(LibraryPrompt(.message(
                title: localized("Không khôi phục được \(report.failures.count) đề mẫu"),
                message: lines.joined(separator: "\n")
            )))
        }
    }

    // MARK: - Hàng đợi việc

    /// Chạy lần lượt các việc làm đổi thư viện từ giao diện (thêm, tìm file, khôi phục đề mẫu).
    @discardableResult
    private func enqueue(_ operation: @escaping @Sendable @MainActor (LibraryModel) async -> Void) -> Task<Void, Never> {
        let previous = operationQueue
        pendingOperations += 1
        let task = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await operation(self)
            pendingOperations -= 1
        }
        operationQueue = task
        return task
    }

    /// Chờ mọi việc đang xếp hàng xong (test).
    public func waitForPendingOperations() async {
        while let task = operationQueue {
            await task.value
            if operationQueue == task { return }
        }
    }
}

/// Kết quả của `addExamFile` chuyển ra khỏi việc trong hàng đợi.
@MainActor
private final class ImportOutcomeBox {
    var outcome: ImportOutcome?
}

/// Một lần **Xoá khỏi thư viện** còn hoàn tác được: đích của `UndoManager` và của nút Hoàn tác.
@MainActor
final class RemovalUndo {
    let id = UUID()
    var removed: RemovedEntry
    weak var undoManager: UndoManager?

    init(removed: RemovedEntry, undoManager: UndoManager?) {
        self.removed = removed
        self.undoManager = undoManager
    }
}
