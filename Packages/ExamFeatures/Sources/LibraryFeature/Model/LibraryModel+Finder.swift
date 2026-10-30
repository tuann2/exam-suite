import AppKit
import InterfaceCore
import LibraryData

extension LibraryModel {
    /// Thư viện của một bản app macOS (`.student` hoặc `.admin`), lưu trong kho riêng theo bundle ID; **Hiện trong
    /// Finder** qua `NSWorkspace`. `LibraryModel` ở InterfaceCore (dùng chung với iOS) không import AppKit, nên lệnh
    /// này truyền vào từ đây.
    /// - Parameter defaults: nơi lưu cờ "đã tạo đề mẫu" (app: `UserDefaults.standard`; UI test: suite trong thư
    ///   mục tạm, xem `AppLaunchStorage`).
    public static func persistent(configuration: LibraryConfiguration, defaults: UserDefaults = .standard) -> LibraryModel {
        LibraryModel(
            store: .persistent(configuration: configuration, defaults: defaults),
            revealFiles: { NSWorkspace.shared.activateFileViewerSelecting($0) }
        )
    }
}
