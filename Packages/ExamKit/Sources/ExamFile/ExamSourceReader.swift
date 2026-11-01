import Foundation

/// Đọc file đề theo đuôi: `.oef` (Open Exam Suite) qua `OEFReader`, mọi đuôi khác như gói `.exam` qua
/// `ExamPackageReader` (docs/product/exam-format.md). Thư viện và phiên thi của bản Học viên đọc file qua đây.
public enum ExamSourceReader {
    /// Đuôi file đọc được (chữ thường).
    public static let fileExtensions: Set<String> = [ExamFileFormat.fileExtension, ExamFileFormat.oefFileExtension]

    public static func isOEF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == ExamFileFormat.oefFileExtension
    }

    public static func read(contentsOf url: URL, mode: ReadMode) throws -> ExamPackage {
        if isOEF(url) { return try OEFReader.read(contentsOf: url, mode: mode) }
        return try ExamPackageReader.read(contentsOf: url, mode: mode)
    }
}
