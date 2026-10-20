import AppKit
import AuthoringFeature
import LibraryData
import LibraryFeature
import SessionFeature
import SwiftUI

/// App delegate của bản Admin: giữ thư viện, phiên thi và danh sách đề mở gần đây, tạo đúng một lần cùng app.
///
/// Không xử lý `application(_:open:)`: file `.exam` mở từ Finder đi vào `DocumentGroup` (cửa sổ soạn đề)
/// như kết luận spike giai đoạn 0.
@MainActor
public final class AdminAppDelegate: NSObject, NSApplicationDelegate {
    /// Nơi lưu kho, đề mẫu và cài đặt: kho riêng theo bundle ID và `UserDefaults.standard`; build Debug chạy với
    /// `-ExamSuiteUITest <thư mục>` thì mọi thứ trong thư mục tạm của UI test (`AppLaunchStorage`), như bản Học viên.
    public let storage: AppLaunchStorage = AdminAppDelegate.resolveStorage()
    /// Thư viện của bản Admin: đọc dễ, kho riêng theo bundle ID.
    public private(set) lazy var library: LibraryModel = .persistent(
        configuration: storage.configuration,
        defaults: storage.defaults
    )
    /// Phiên thi (mỗi lúc một phiên), nối với thư viện. Làm bài chỉ với đề Sẵn sàng (đọc nghiêm được).
    public private(set) lazy var sessions = SessionAppController(
        library: library,
        defaults: storage.defaults,
        timeScale: storage.sessionTimeScale
    )
    lazy var recentDocuments = RecentDocuments()
    /// **Import đề…** (docs/product/import.md): mỗi lúc một lần import; lỗi hiện bằng hộp thông báo.
    public private(set) lazy var importFlow: ImportFlowModel = {
        let model = ImportFlowModel()
        model.onFailure = { failure in
            // Hiện sau khi cửa sổ Import đề (nếu có) đã đóng.
            DispatchQueue.main.async { ImportFilePanel.present(failure) }
        }
        return model
    }()
    /// **Thử đề này** (docs/product/authoring.md): lưu → đọc nghiêm → thêm vào Thư viện → Trước khi thi.
    public private(set) lazy var tryExam = TryExamCoordinator(environment: .live(library: library))

    /// Tham số cô lập sai, chạy chế độ cô lập dưới bundle ID thật, hay bản build cho UI test
    /// (`vn.io.nt0.examsuite.admin.uitest`) thiếu tham số (chỉ build Debug): dừng app ngay, trước khi có cửa sổ, để
    /// không bao giờ rơi về kho và cài đặt thật.
    nonisolated private static func resolveStorage() -> AppLaunchStorage {
        do {
            return try AppLaunchStorage.resolve(.admin)
        } catch {
            FileHandle.standardError.write(Data("Exam Suite Admin: không bật được chế độ cô lập của UI test: \(error)\n".utf8)) // l10n-ignore: log
            exit(EX_USAGE)
        }
    }

    /// ⌘Q, Thoát từ Dock, đăng xuất/khởi động lại/tắt máy: có bài chưa nộp thì hỏi. AppKit hỏi lưu các cửa sổ soạn đề
    /// trước khi gọi hàm này. Mục Thoát và Apple event thoát là của AppKit (`SessionAppController`).
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        sessions.applicationShouldTerminate(sender)
    }
}

/// Các scene của bản Admin: cửa sổ Thư viện (scene đầu, mở khi khởi động), cửa sổ làm bài, và
/// `DocumentGroup` + `ExamAuthoringDocument` cho cửa sổ soạn đề (docs/product/authoring.md): **Đề mới** (⌘N, nút trên
/// thanh công cụ Thư viện), mở `.exam` từ Finder, **Sửa** (⌘E) trên Thư viện, **Mở để sửa…** (⇧⌘O). Mỗi file một
/// cửa sổ; mở lại file đang mở thì macOS đưa cửa sổ đó lên trước.
public struct AdminScenes: Scene {
    private let delegate: AdminAppDelegate

    public init(delegate: AdminAppDelegate) {
        self.delegate = delegate
    }

    public var body: some Scene {
        // `@AppStorage` của mọi view đọc/ghi `defaults` của app (UI test: suite trong thư mục tạm). Scene mới có
        // view dùng `@AppStorage` cũng phải gắn `.defaultAppStorage(delegate.storage.defaults)`. Mọi scene gắn
        // `.interfaceLocale()`: số, phần trăm, ngày giờ theo ngôn ngữ giao diện, không theo Region
        // (accessibility-localization.md, mục Ngôn ngữ).
        LibraryWindow(
            model: delegate.library,
            decoration: SessionLibraryDecoration(sessions: delegate.sessions, closingQuitsApp: false)
                .concat(AdminLibraryToolbar())
        )
        .commands {
            SidebarCommands()
            LibraryCommands(model: delegate.library) {
                AdminDocumentMenuItems(recents: delegate.recentDocuments)
            }
        }
        .defaultAppStorage(delegate.storage.defaults)
        .interfaceLocale()

        SessionWindowScene(sessions: delegate.sessions)
            .defaultAppStorage(delegate.storage.defaults)
            .interfaceLocale()

        // Cửa sổ soạn đề dùng `@AppStorage` cho cỡ chữ của xem trước (`contentZoomScope`): UI test ghi vào suite trong thư
        // mục tạm, không vào defaults thật.
        DocumentGroup(newDocument: { ExamAuthoringDocument() }) { file in
            AuthoringWindow(document: file.document)
                .environment(\.authoringHooks, AdminAuthoringCommands.hooks(delegate: delegate, openWindow: nil))
        }
        .defaultAppStorage(delegate.storage.defaults)
        .interfaceLocale()
        // Cỡ mặc định của cửa sổ soạn đề mới: ba cột ở độ rộng lý tưởng, trình soạn rộng hơn (AuthoringStyle).
        .defaultSize(AuthoringWindow.defaultWindowSize)
        .commands {
            AdminAuthoringCommands(delegate: delegate)
        }

        // Tiến độ và hộp thoại xác nhận của Import đề… (không dùng `@AppStorage`; gắn như mọi scene của bản Admin).
        ImportExamWindow(model: delegate.importFlow)
            .defaultAppStorage(delegate.storage.defaults)
            .interfaceLocale()
    }
}

/// Lệnh menu của cửa sổ soạn đề, với **File > Import đề…** và **Đề > Thử đề này** (⌘R) nối vào app delegate.
/// `Commands` để dùng được `openWindow` (mở cửa sổ Import đề).
struct AdminAuthoringCommands: Commands {
    let delegate: AdminAppDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        AuthoringCommands(hooks: Self.hooks(delegate: delegate, openWindow: openWindow))
    }

    /// - Parameter openWindow: `nil` khi chỉ cần Thử đề này (nút trên thanh công cụ của cửa sổ soạn đề).
    @MainActor
    static func hooks(delegate: AdminAppDelegate, openWindow: OpenWindowAction?) -> AuthoringHooks {
        var importExam: (@MainActor @Sendable () -> Void)?
        if let openWindow {
            importExam = { [weak delegate] in
                guard let delegate else { return }
                startImport(flow: delegate.importFlow, storage: delegate.storage, openWindow: openWindow)
            }
        }
        let tryExam: @MainActor @Sendable (AuthoringEditor) -> Void = { [weak delegate] editor in
            guard let coordinator = delegate?.tryExam else { return }
            Task { await coordinator.run(editor: editor) { await TryExamDocumentSaver.save(for: editor) } }
        }
        var hooks = AuthoringHooks(importExam: importExam, tryExam: tryExam)
        #if DEBUG
        // UI test (chế độ cô lập): ảnh của câu lấy từ file test đưa vào, không mở hộp chọn file.
        if let file = delegate.storage.uiTestChosenFile, let directory = delegate.storage.uiTestDirectory {
            hooks.uiTestChooseImageFile = { UITestLaunchOptions.revalidatedChosenFile(file, in: directory) }
        }
        #endif
        return hooks
    }

    /// **Import đề…**: chọn file rồi mở cửa sổ Import đề (tiến độ, hộp thoại xác nhận). Đang có một lần import thì
    /// đưa cửa sổ đó lên trước. `.vce` và lỗi: hộp thông báo, không mở cửa sổ nào.
    @MainActor
    private static func startImport(flow: ImportFlowModel, storage: AppLaunchStorage, openWindow: OpenWindowAction) {
        if flow.phase != .idle {
            openWindow(id: ImportExamWindow.windowID)
            return
        }
        guard let url = chooseImportFile(storage: storage) else { return }
        if flow.start(url) != .rejected {
            openWindow(id: ImportExamWindow.windowID)
        }
    }

    /// Hộp chọn file của Import đề…; riêng UI test (build Debug, chế độ cô lập, `-ExamSuiteUITestChosenFile`) dùng file
    /// test đưa vào, như khi người dùng chọn đúng file đó.
    @MainActor
    private static func chooseImportFile(storage: AppLaunchStorage) -> URL? {
        #if DEBUG
        // Có móc thì không bao giờ mở hộp chọn file; file kiểm lại ngay lúc dùng, không còn hợp lệ thì không import.
        if storage.uiTestChosenFile != nil { return storage.revalidatedUITestChosenFile() }
        #endif
        return ImportFilePanel.chooseFile()
    }
}

/// Mục menu File riêng bản Admin, ngay sau **Thêm đề…** (⌘O): **Đề mới** (⌘N) và mở `.exam` vào cửa sổ soạn đề.
///
/// library.md quy định ⌘O = Thêm đề ở cả hai bản ("Phương án chờ Nt0 chốt", mục 7), nên mục Open… ⌘O có
/// sẵn của `DocumentGroup` bị thay (`LibraryCommands` thay cả nhóm `.newItem`) bằng "Mở để sửa…" ⇧⌘O gọi
/// `NSDocumentController.openDocument(_:)`, và "Mở gần đây" dựng lại từ danh sách của document controller. Mục
/// New ⌘N của `DocumentGroup` cũng bị thay theo, nên **Đề mới** (⌘N) đặt lại ở đây.
struct AdminDocumentMenuItems: View {
    let recents: RecentDocuments

    var body: some View {
        Button(localized("Đề mới")) {
            NSDocumentController.shared.newDocument(nil)
        }
        .keyboardShortcut("n", modifiers: .command)
        Button(localized("Mở để sửa…")) {
            NSDocumentController.shared.openDocument(nil)
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])
        Menu(localized("Mở gần đây")) {
            ForEach(recents.urls, id: \.self) { url in
                Button(FileManager.default.displayName(atPath: url.path)) {
                    recents.open(url)
                }
            }
            if !recents.urls.isEmpty {
                Divider()
            }
            Button(localized("Xoá danh sách")) { recents.clear() }
                .disabled(recents.urls.isEmpty)
        }
    }
}

/// Đề mở gần đây của `DocumentGroup` (`NSDocumentController.recentDocumentURLs`), đọc lại mỗi khi app hoặc
/// một cửa sổ được kích hoạt (mở đề xong thì cửa sổ soạn đề thành cửa sổ chính).
///
/// Không đụng `NSDocumentController.shared` trong lúc app khởi động: document controller tạo đầu tiên thành
/// bản dùng chung, và `DocumentGroup` cần bản của SwiftUI. Vì vậy không đọc trong `init` và chỉ đọc ở lượt
/// sau của main actor, sau khi app đã được kích hoạt hoặc một cửa sổ đã thành cửa sổ chính.
@Observable
@MainActor
final class RecentDocuments {
    private(set) var urls: [URL] = []
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reload() }
            })
        }
    }

    func reload() {
        let current = NSDocumentController.shared.recentDocumentURLs
        if current != urls { urls = current }
    }

    func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            guard let error else { return }
            Task { @MainActor in
                _ = NSApp.presentError(error)
            }
        }
    }

    func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        reload()
    }
}

/// Nút **Đề mới** trên thanh công cụ Thư viện của bản Admin (docs/product/authoring.md, mục Mở cửa sổ soạn đề;
/// library.md, mục Cửa sổ). Gắn vào cửa sổ Thư viện qua `decoration` để LibraryFeature không biết tới Soạn đề.
struct AdminLibraryToolbar: ViewModifier {
    @Environment(\.newDocument) private var newDocument

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newDocument { ExamAuthoringDocument() }
                } label: {
                    Label(localized("Đề mới"), systemImage: "square.and.pencil")
                }
                .help(Text("Đề mới (⌘N)", bundle: .module))
                .accessibilityIdentifier("library.newExam")
            }
        }
    }
}
