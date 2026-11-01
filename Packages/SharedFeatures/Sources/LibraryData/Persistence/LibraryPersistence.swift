import Foundation
import SwiftData

/// Mở kho SwiftData của Thư viện (docs/product/library.md, mục Lưu trữ).
///
/// Kho không mở được (file rác, hỏng, schema lạ): app không crash; kho cũ được đổi tên thành
/// `Library.store.broken-<thời điểm UTC>` (file `-shm`/`-wal` đi kèm đổi tên theo, để vẫn mở được
/// bằng sqlite3 khi cần cứu dữ liệu), rồi tạo kho mới và báo qua `LibraryStoreIssue`. Nếu cả kho mới
/// cũng không tạo được thì dùng kho tạm trong bộ nhớ và báo.
@MainActor
enum LibraryPersistence {
    struct Opened {
        let repository: any LibraryRepository
        let issue: LibraryStoreIssue?
    }

    /// File đi kèm kho SQLite: nhật ký WAL và bộ nhớ chia sẻ.
    static let companionSuffixes = ["-shm", "-wal"]

    static func makeContainer(storeURL: URL?) throws -> ModelContainer {
        let schema = Schema(versionedSchema: LibrarySchemaV1.self)
        let configuration: ModelConfiguration
        if let storeURL {
            // Đường dẫn tường minh: không dùng kho mặc định (hai bản app không sandbox sẽ dùng chung).
            // Không đồng bộ CloudKit.
            configuration = ModelConfiguration(
                "Library",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        } else {
            // Tên riêng cho mỗi kho trong bộ nhớ để hai kho không bao giờ dùng chung dữ liệu.
            configuration = ModelConfiguration(
                UUID().uuidString,
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: LibraryMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Kho trên đĩa ở `storeURL`, có cứu kho hỏng.
    static func openPersistent(at storeURL: URL, now: Date, fileManager: FileManager = .default) -> Opened {
        do {
            try fileManager.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            LibraryLog.store.error("Cannot create library directory: \(String(describing: error), privacy: .public)")
            return temporary(reason: error.localizedDescription)
        }

        let firstError: any Error
        do {
            let container = try makeContainer(storeURL: storeURL)
            return Opened(repository: SwiftDataLibraryRepository(container: container), issue: nil)
        } catch {
            firstError = error
        }
        LibraryLog.store.error("Cannot open library store: \(String(describing: firstError), privacy: .public)")
        guard fileManager.fileExists(atPath: storeURL.path) else {
            // Không có kho cũ để dời đi: lỗi nằm ở chỗ khác (quyền, ổ đĩa…).
            return temporary(reason: firstError.localizedDescription)
        }
        do {
            let broken = try moveAsideBrokenStore(at: storeURL, now: now, fileManager: fileManager)
            let container = try makeContainer(storeURL: storeURL)
            LibraryLog.store.notice("Broken library store moved to \(broken.lastPathComponent, privacy: .public)")
            return Opened(
                repository: SwiftDataLibraryRepository(container: container),
                issue: .recoveredFromBrokenStore(brokenStoreURL: broken)
            )
        } catch {
            LibraryLog.store.error("Cannot recover library store: \(String(describing: error), privacy: .public)")
            return temporary(reason: error.localizedDescription)
        }
    }

    /// Kho trong bộ nhớ (test, preview, hoặc khi kho trên đĩa không dùng được).
    static func inMemoryRepository() -> any LibraryRepository {
        if let container = try? makeContainer(storeURL: nil) {
            return SwiftDataLibraryRepository(container: container)
        }
        return InMemoryLibraryRepository()
    }

    /// Đổi tên kho hỏng (và file đi kèm) thành `<tên kho>.broken-<thời điểm>[-n]<đuôi đi kèm>`.
    /// - Returns: đường dẫn mới của file kho chính.
    static func moveAsideBrokenStore(at storeURL: URL, now: Date, fileManager: FileManager = .default) throws -> URL {
        // Ví dụ Library.store.broken-20261015T081530Z (UTC, không có ":" để tên file dùng được ở mọi nơi).
        let style = Date.ISO8601FormatStyle(
            dateSeparator: .omitted,
            dateTimeSeparator: .standard,
            timeSeparator: .omitted,
            timeZone: .gmt
        )
        let stamp = now.formatted(style)
        let base = storeURL.path
        var suffix = ".broken-\(stamp)"
        var counter = 1
        while ([""] + companionSuffixes).contains(where: { fileManager.fileExists(atPath: base + suffix + $0) }) {
            counter += 1
            suffix = ".broken-\(stamp)-\(counter)"
        }
        for companion in [""] + companionSuffixes where fileManager.fileExists(atPath: base + companion) {
            try fileManager.moveItem(
                at: URL(fileURLWithPath: base + companion),
                to: URL(fileURLWithPath: base + suffix + companion)
            )
        }
        return URL(fileURLWithPath: base + suffix)
    }

    private static func temporary(reason: String) -> Opened {
        Opened(repository: inMemoryRepository(), issue: .temporaryStore(reason: reason))
    }
}
