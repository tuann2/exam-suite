import AppKit
import LibraryData
import LibraryFeature
import SessionFeature
import SwiftUI

// Bản Học viên. Không import AuthoringFeature, trực tiếp hay gián tiếp (ADR 0003,
// kiểm bằng scripts/check_boundaries.py và scripts/check_bundle_boundary.sh).

/// App delegate của bản Học viên: giữ thư viện và phiên thi của app, nhận file `.exam` mở từ Finder, hỏi
/// trước khi thoát khi có bài chưa nộp.
///
/// Vì sao `application(_:open:)` thay vì `WindowGroup` + `onOpenURL`: AppKit giao cả ba đường mở file
/// (nhấp đúp, Open With, kéo vào biểu tượng Dock) cho đúng hàm này, kể cả khi file làm app khởi động (hàm
/// được gọi trước khi cửa sổ hiện, file được xếp hàng tới khi kho đã tải). Khi delegate xử lý sự kiện mở
/// file, SwiftUI không tự tạo cửa sổ cho nó; còn `onOpenURL` trên `WindowGroup` có thể sinh thêm một cửa sổ
/// Thư viện cho mỗi lần mở file. Cửa sổ Thư viện là `Window` (một bản duy nhất): `openFromFinder` chỉ mở lại
/// hoặc đưa nó lên trước rồi chạy đúng luồng Thêm đề (báo lỗi, hộp thoại trùng id, chọn đề vừa thêm).
@MainActor
public final class StudentAppDelegate: NSObject, NSApplicationDelegate {
    /// Nơi lưu kho, đề mẫu và cài đặt: kho riêng theo bundle ID và `UserDefaults.standard`; build Debug chạy với
    /// `-ExamSuiteUITest <thư mục>` thì mọi thứ trong thư mục tạm của UI test (`AppLaunchStorage`).
    public let storage: AppLaunchStorage = StudentAppDelegate.resolveStorage()
    /// Thư viện của bản Học viên: đọc nghiêm, kho riêng theo bundle ID. Tạo một lần, lúc app cần lần đầu.
    public private(set) lazy var library: LibraryModel = .persistent(
        configuration: storage.configuration,
        defaults: storage.defaults
    )
    /// Phiên thi (mỗi lúc một phiên), nối với thư viện.
    public private(set) lazy var sessions = SessionAppController(
        library: library,
        defaults: storage.defaults,
        timeScale: storage.sessionTimeScale
    )

    /// Tham số cô lập sai (chỉ build Debug): dừng app ngay, trước khi có cửa sổ, để không bao giờ rơi về kho
    /// và cài đặt thật.
    nonisolated private static func resolveStorage() -> AppLaunchStorage {
        do {
            return try AppLaunchStorage.resolve(.student)
        } catch {
            FileHandle.standardError.write(Data("Exam Suite: không bật được chế độ cô lập của UI test: \(error)\n".utf8)) // l10n-ignore: log
            exit(EX_USAGE)
        }
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        library.openFromFinder(urls)
    }

    /// ⌘Q, Thoát từ Dock, đăng xuất/khởi động lại/tắt máy, đóng cửa sổ Thư viện: có bài chưa nộp thì hỏi
    /// (docs/product/exam-taking.md). Mục Thoát và Apple event thoát là của AppKit (`SessionAppController`).
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        sessions.applicationShouldTerminate(sender)
    }
}

/// Các scene của bản Học viên: cửa sổ Thư viện, cửa sổ làm bài và lệnh menu của chúng.
///
/// Đóng cửa sổ Thư viện thì app thoát (library.md, phương án 10), kể cả khi cửa sổ làm bài đang mở:
/// `SessionLibraryDecoration` chuyển việc đóng thành `NSApp.terminate`, nên có bài chưa nộp thì hỏi trước.
/// Mở `.exam` từ Finder khi app đã thoát thì khởi động lại app vào Thư viện.
public struct StudentScenes: Scene {
    private let library: LibraryModel
    private let sessions: SessionAppController
    private let defaults: UserDefaults

    public init(delegate: StudentAppDelegate) {
        library = delegate.library
        sessions = delegate.sessions
        defaults = delegate.storage.defaults
    }

    public var body: some Scene {
        // `@AppStorage` của mọi view đọc/ghi `defaults` của app (UI test: suite trong thư mục tạm). Số, phần trăm, ngày
        // giờ theo ngôn ngữ giao diện, không theo Region (`.interfaceLocale()`, accessibility-localization.md): scene mới
        // cũng phải gắn cả hai.
        LibraryWindow(model: library, decoration: SessionLibraryDecoration(sessions: sessions, closingQuitsApp: true))
            .commands {
                SidebarCommands()
                LibraryCommands(model: library)
            }
            .defaultAppStorage(defaults)
            .interfaceLocale()
        SessionWindowScene(sessions: sessions)
            .defaultAppStorage(defaults)
            .interfaceLocale()
    }
}
