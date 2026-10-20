import Accessibility
import AppKit
import SwiftUI

/// Câu VoiceOver của cửa sổ soạn đề (accessibility-localization.md, Mục tiêu phủ theo màn: Soạn đề "Lưu xong, kiểm đề
/// có lỗi mới"): thông báo không chặn, tiêu điểm không đổi.
@MainActor
enum AuthoringAnnouncer {
    static func post(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}

/// "Lưu xong" của cửa sổ soạn đề: lưu là của macOS (`DocumentGroup`, `NSDocument`), app không có lời gọi lại khi lưu xong.
/// Cách làm: khi người dùng chọn **Lưu** (⌘S) hoặc **Lưu thành…** của cửa sổ này (`NSMenu.didSendActionNotification` với
/// `saveDocument:`/`saveDocumentAs:` khi cửa sổ đang là cửa sổ chính), ghi lại file và ngày sửa file của document lúc đó,
/// rồi theo dõi tới khi document hết "Đã sửa" **và** file thật sự được ghi (ngày sửa file đổi, hoặc đường dẫn đổi với Lưu
/// thành…) và đọc "Đã lưu “tên file”" (hộp Lưu có thể mở lâu). Huỷ hộp Lưu (kể cả Lưu thành… của đề đã lưu, không sửa gì:
/// review độc lập #54 S3) hay lưu lỗi (macOS đã báo) thì hết thời gian chờ, không đọc. Tự lưu (không qua menu) không đọc.
@MainActor
final class SaveAnnouncementObserver {
    /// Thời gian chờ tối đa sau lệnh Lưu (kể cả lúc hộp Lưu đang mở).
    static let timeout: Duration = .seconds(120)
    static let pollInterval: Duration = .milliseconds(250)

    private weak var window: NSWindow?
    private let document: @MainActor () -> NSDocument?
    private let announce: @MainActor (String) -> Void
    /// `nonisolated(unsafe)`: chỉ ghi trên main actor; `deinit` (không cách ly) gỡ observer.
    nonisolated(unsafe) private var observer: (any NSObjectProtocol)?
    private var task: Task<Void, Never>?

    init(window: NSWindow, document: @escaping @MainActor () -> NSDocument?, announce: @escaping @MainActor (String) -> Void) {
        self.window = window
        self.document = document
        self.announce = announce
        observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didSendActionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let action = (notification.userInfo?["MenuItem"] as? NSMenuItem)?.action
            MainActor.assumeIsolated { self?.menuSent(action) }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// Thôi theo dõi (cửa sổ đóng, bộ soạn đề đổi).
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        task?.cancel()
        task = nil
    }

    /// Lệnh menu là **Lưu** (`saveDocument:`) hoặc **Lưu thành…** (`saveDocumentAs:`).
    static func isSaveCommand(_ action: Selector?) -> Bool {
        guard let action else { return false }
        return saveActions.contains(NSStringFromSelector(action))
    }

    static let saveActions: Set<String> = ["saveDocument:", "saveDocumentAs:"]

    /// Trạng thái file của document lúc gửi lệnh Lưu và lúc kiểm.
    struct FileState: Equatable {
        var fileURL: URL?
        var modificationDate: Date?
        var isEdited: Bool
    }

    /// Lưu xong: document có file, không còn thay đổi chưa lưu, và file đã thật sự được ghi sau lệnh (ngày sửa file mới hơn,
    /// hoặc file khác với Lưu thành…). Hết "Đã sửa" mà file không đổi (Lưu thành… bị huỷ, hay ⌘S khi chưa sửa gì) không tính.
    static func didSave(before: FileState, now: FileState) -> Bool {
        guard now.fileURL != nil, !now.isEdited else { return false }
        if now.fileURL != before.fileURL { return true }
        guard let date = now.modificationDate else { return false }
        return before.modificationDate.map { date > $0 } ?? true
    }

    static func state(of document: NSDocument) -> FileState {
        FileState(fileURL: document.fileURL, modificationDate: document.fileModificationDate, isEdited: document.isDocumentEdited)
    }

    private func menuSent(_ action: Selector?) {
        guard Self.isSaveCommand(action), let window, NSApp.mainWindow === window, let document = document() else { return }
        let before = Self.state(of: document)
        task?.cancel()
        task = Task { [weak self] in
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: Self.timeout)
            while clock.now < deadline {
                do { try await Task.sleep(for: Self.pollInterval) } catch { return }
                guard let self, self.window != nil, let document = self.document() else { return }
                if Self.didSave(before: before, now: Self.state(of: document)), let url = document.fileURL {
                    self.announce(AuthoringPresentation.savedAnnouncement(fileName: url.lastPathComponent))
                    return
                }
            }
        }
    }
}
