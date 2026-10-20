import Foundation

/// Một bước chuyển `exam.json` (JSON thô) từ phiên bản `sourceVersion` lên
/// `sourceVersion + 1` (docs/product/exam-format.md, mục Phiên bản định dạng).
/// Làm trên JSON thô vì model `Exam` chỉ mô tả phiên bản mới nhất.
struct FormatMigration: Sendable {
    let sourceVersion: Int
    let migrate: @Sendable ([String: Any]) throws -> [String: Any]
}

enum FormatMigrator {
    /// Các bước đã đăng ký. v1 là phiên bản đầu tiên nên chưa có bước nào;
    /// khi tăng lên v2, thêm bước `sourceVersion: 1` kèm fixture và test.
    static let registered: [FormatMigration] = []

    /// Chạy lần lượt các bước từ `version` lên `target`; sau mỗi bước đặt
    /// `formatVersion` thành phiên bản mới.
    static func migrate(
        _ json: [String: Any],
        from version: Int,
        to target: Int,
        using steps: [FormatMigration]
    ) throws -> [String: Any] {
        var current = json
        var v = version
        while v < target {
            guard let step = steps.first(where: { $0.sourceVersion == v }) else {
                throw ExamFileError.migrationFailed(from: v, reason: .missingStep)
            }
            do {
                current = try step.migrate(current)
            } catch let error as ExamFileError {
                throw error
            } catch {
                throw ExamFileError.migrationFailed(from: v, reason: .stepFailed(String(describing: error)))
            }
            v += 1
            current["formatVersion"] = v
        }
        return current
    }
}
