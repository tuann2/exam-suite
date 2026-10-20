import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Import một file txt tự soạn.
func importText(_ text: String, fileName: String = "Đề tự soạn.txt", limits: ImportLimits = .default) async throws
    -> ImportResult
{
    try await ExamImporter.importData(Data(text.utf8), fileName: fileName, limits: limits)
}

/// Import một file docx tự soạn.
func importDocx(_ builder: DocxBuilder, fileName: String = "De tu soan.docx", limits: ImportLimits = .default)
    async throws -> ImportResult
{
    try await ExamImporter.importData(builder.data(), fileName: fileName, limits: limits)
}

extension ImportResult {
    var questions: [Question] { sections.flatMap(\.questions) }

    func entries(_ code: ImportIssueCode) -> [ImportReportEntry] {
        report.entries.filter { $0.code == code }
    }

    /// Xác nhận với giá trị hợp lệ rồi ghi bằng `ExamPackageWriter` và đọc lại.
    func roundTrip(mode: ReadMode = .lenient) throws -> (written: ExamPackage, reread: ExamPackage) {
        let package = makePackage(ImportConfirmation(title: suggestions.title, code: suggestions.code,
                                                     passPercent: suggestions.passPercent ?? 70,
                                                     timeLimitMinutes: suggestions.timeLimitMinutes ?? 60))
        let data = try ExamPackageWriter.write(package)
        return (package, try ExamPackageReader.read(data, mode: mode))
    }
}

/// Lỗi import mong đợi (so bằng `==`).
func expectImportError(
    _ expected: ImportError,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
        Issue.record("Mong đợi lỗi \(expected), nhưng import thành công", sourceLocation: sourceLocation)
    } catch let error as ImportError {
        #expect(error == expected, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Mong đợi \(expected), nhận \(error)", sourceLocation: sourceLocation)
    }
}

/// PNG 1×1 tự tạo (byte cố định), và biến thể khác nội dung.
func tinyPNG(_ variant: UInt8 = 0) -> Data {
    var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    bytes += [UInt8](repeating: variant, count: 16)
    return Data(bytes)
}
