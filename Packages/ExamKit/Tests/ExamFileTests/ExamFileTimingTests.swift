import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
import Testing

/// Đọc/ghi gói đề chuẩn (2.000 câu, 200 ảnh ~60 MB; docs/product/large-exams.md). In dòng `Timing:`; test thất bại
/// khi lần nhanh nhất vượt giới hạn chặn (Debug). `scripts/measure_large.sh` chạy lại ở Release để ghi số.
@Suite("Timing: đọc/ghi gói đề chuẩn", .serialized)
struct ExamFileTimingTests {
    @Test("Ghi rồi đọc nghiêm gói đề chuẩn có ảnh", .timeLimit(.minutes(3)))
    func writeAndReadStandardPackage() throws {
        let package = StandardExam.standard
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExamFileTimingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("de-chuan.exam")

        let write = try Timing.measure(.examFileWrite, runs: 3) {
            try ExamPackageWriter.write(package, to: url)
        }
        var read: ExamPackage?
        let reading = try Timing.measure(.examFileRead, runs: 3) {
            read = try ExamPackageReader.read(contentsOf: url, mode: .strict)
        }
        #expect(read == package)
        #expect(write.isWithinLimit, "\(write.line)")
        #expect(reading.isWithinLimit, "\(reading.line)")
    }
}
