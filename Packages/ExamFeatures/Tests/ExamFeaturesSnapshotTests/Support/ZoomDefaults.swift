import Foundation
@testable import SessionFeature

/// Cài đặt `@AppStorage` của một snapshot test với cỡ chữ nội dung `level` (Phóng to, phương án 5) và nền đọc `reading`
/// (plan giai đoạn 6 bước 1): file tạm riêng (như `LibraryFixture`), không đụng `defaults` của app hay của tiến trình test.
/// Gắn bằng `.defaultAppStorage(defaults)`.
@MainActor
final class ZoomDefaults {
    let defaults: UserDefaults
    private let directory: URL

    init(_ level: ContentZoomLevel = .actual, reading: ReadingBackground = .system) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExamFeaturesSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: directory.appendingPathComponent("defaults.plist").path)!
        defaults.set(level.rawValue, forKey: ContentZoomLevel.storageKey)
        defaults.set(reading.rawValue, forKey: ReadingBackground.storageKey)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
