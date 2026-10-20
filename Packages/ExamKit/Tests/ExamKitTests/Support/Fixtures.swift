import Foundation

/// Đường dẫn tới `fixtures/` ở gốc repo, tính từ vị trí file test này.
enum Fixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // ExamKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ExamKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("fixtures", isDirectory: true)

    static func exam(_ name: String) -> URL {
        root.appendingPathComponent("exams/\(name)/exam.json")
    }

    static func invalid(_ name: String) -> URL {
        root.appendingPathComponent("invalid/\(name).json")
    }

    static func data(_ url: URL) throws -> Data { try Data(contentsOf: url) }
}
