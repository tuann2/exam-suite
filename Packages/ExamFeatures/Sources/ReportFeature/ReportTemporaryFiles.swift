import AppKit

/// File tạm của báo cáo đang dựng: file tạm cạnh file đích của Xuất PDF (`ReportFileWriter`) và PDF tạm của In
/// (`ReportRenderer.render(_:)`, trong thư mục tạm của hệ thống). App thoát **bình thường** giữa chừng (⌘Q, Thoát từ Dock,
/// đăng xuất: sheet tiến độ không chặn thoát) thì lần dựng không kịp tự dọn, nên các file còn trong danh sách được xoá lúc
/// `NSApplication.willTerminateNotification`. Crash hay buộc thoát thì không dọn được.
@MainActor
enum ReportTemporaryFiles {
    /// File tạm đang dựng.
    private(set) static var pending: Set<URL> = []
    private static var terminationObserver: (any NSObjectProtocol)?

    /// Ghi nhớ file tạm để xoá khi app thoát giữa chừng.
    static func track(_ url: URL) {
        pending.insert(url)
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { removeAll() }
        }
    }

    /// Lần dựng đã tự dọn (xong, lỗi, huỷ).
    static func untrack(_ url: URL) {
        pending.remove(url)
    }

    /// Xoá các file tạm đang dựng (app sắp thoát). `matching` chỉ để test giới hạn trong thư mục của nó.
    static func removeAll(matching include: (URL) -> Bool = { _ in true }) {
        for url in pending where include(url) {
            try? FileManager.default.removeItem(at: url)
            pending.remove(url)
        }
    }
}
