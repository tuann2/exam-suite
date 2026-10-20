import Foundation

// Chi tiết có mã của ba lỗi `ExamFileError` trước đây chỉ mang câu tiếng Việt (`invalidJSON`, `migrationFailed`,
// `writeFailed`), để tầng giao diện dựng câu báo bằng chữ của String Catalog (docs/product/accessibility-localization.md,
// phương án 2). `logMessage` của mỗi kiểu là đúng câu tiếng Việt trước đây, chỉ cho nhật ký, script, test (giao diện không
// dùng; luật `core-text` của scripts/check_localization.py); kết luận đọc/ghi không đổi.

/// Vì sao `exam.json` không hợp lệ (`ExamFileError.invalidJSON`).
public enum JSONProblem: Equatable, Hashable, Sendable {
    /// `exam.json` không phải UTF-8.
    case notUTF8
    /// `JSONSerialization` không phân tích được. Tham số: mô tả lỗi của hệ thống (`localizedDescription`, macOS đã dịch
    /// theo ngôn ngữ của app).
    case unparsable(systemDescription: String)
    /// Gốc không phải object.
    case rootNotObject
    /// Thiếu `formatVersion`.
    case missingFormatVersion
    /// `formatVersion` không phải số nguyên.
    case formatVersionNotInteger
    /// Chỉ ở chế độ `strict`: dấu phẩy thừa trước `}`/`]`. Tham số: đường dẫn object/mảng (gốc là `rootPath`).
    case trailingCommas([String])
    /// Model thiếu khoá bắt buộc. `path` dạng `sections[0].questions[2]` (gốc là `rootPath`).
    case missingKey(path: String, key: String)
    /// Sai kiểu dữ liệu. `expectedType`: tên kiểu Swift (chữ kỹ thuật, không dịch).
    case typeMismatch(path: String, expectedType: String)
    /// Giá trị `null` ở chỗ cần giá trị. `expectedType`: tên kiểu Swift.
    case valueMissing(path: String, expectedType: String)
    /// Giá trị không hợp lệ. `detail`: mô tả của bộ giải mã (chữ kỹ thuật, không dịch).
    case invalidValue(path: String, detail: String)
    /// Lỗi giải mã khác. Tham số: mô tả kỹ thuật của lỗi.
    case other(String)

    /// Tên của gốc trong đường dẫn (`path`, `trailingCommas`).
    public static let rootPath = "<gốc>"

    /// Câu tiếng Việt (nhật ký, test), phần sau "exam.json không hợp lệ: ".
    public var logMessage: String {
        switch self {
        case .notUTF8:
            "exam.json phải mã hoá UTF-8."
        case let .unparsable(description):
            "không phân tích được JSON (\(description))."
        case .rootNotObject:
            "gốc của exam.json phải là một object."
        case .missingFormatVersion:
            "thiếu khoá bắt buộc \"formatVersion\"."
        case .formatVersionNotInteger:
            "formatVersion phải là số nguyên."
        case let .trailingCommas(paths):
            "dấu phẩy thừa trước dấu đóng } hoặc ] ở \(paths.joined(separator: ", ")). Xoá dấu phẩy sau phần tử cuối."
        case let .missingKey(path, key):
            "\(path): thiếu khoá bắt buộc \"\(key)\"."
        case let .typeMismatch(path, type):
            "\(path): sai kiểu dữ liệu, cần \(type)."
        case let .valueMissing(path, type):
            "\(path): thiếu giá trị (null), cần \(type)."
        case let .invalidValue(path, detail):
            "\(path): giá trị không hợp lệ (\(detail))."
        case let .other(description):
            description
        }
    }
}

/// Vì sao không chuyển được đề lên phiên bản kế tiếp (`ExamFileError.migrationFailed`).
public enum MigrationProblem: Equatable, Hashable, Sendable {
    /// Chưa có bộ chuyển đổi từ phiên bản nguồn lên phiên bản kế tiếp.
    case missingStep
    /// Kết quả chuyển đổi không ghi lại được thành JSON.
    case invalidResult
    /// Bộ chuyển đổi ném lỗi. Tham số: mô tả kỹ thuật của lỗi.
    case stepFailed(String)

    /// Câu tiếng Việt (nhật ký, test) cho lần chuyển từ `version` lên `version + 1`.
    public func logMessage(from version: Int) -> String {
        switch self {
        case .missingStep:
            "chưa có bộ chuyển đổi v\(version) → v\(version + 1)."
        case .invalidResult:
            "kết quả chuyển đổi không phải JSON hợp lệ."
        case let .stepFailed(description):
            description
        }
    }
}

/// Vì sao không ghi được gói đề (`ExamFileError.writeFailed`).
public enum WriteProblem: Equatable, Hashable, Sendable {
    /// Không mã hoá được `exam.json`. Tham số: mô tả kỹ thuật của lỗi.
    case encodingFailed(String)
    /// Không lấy được dữ liệu zip trong bộ nhớ.
    case archiveUnavailable
    /// Lỗi tạo zip. Tham số: mô tả kỹ thuật của lỗi.
    case archiveFailed(String)
    /// Không thay được file đích bằng file tạm (`rename(2)`). `systemReason`: mô tả lỗi POSIX của hệ thống.
    case replaceFailed(fileName: String, systemReason: String)

    /// Câu tiếng Việt (nhật ký, test), phần sau "Không ghi được gói đề: ".
    public var logMessage: String {
        switch self {
        case let .encodingFailed(description):
            "không mã hoá được exam.json (\(description))."
        case .archiveUnavailable:
            "không lấy được dữ liệu zip trong bộ nhớ."
        case let .archiveFailed(description):
            "lỗi tạo zip (\(description))."
        case let .replaceFailed(fileName, reason):
            "không thay được file \(fileName) (\(reason))."
        }
    }
}
