import ExamFile
import ExamKit
import Foundation
import LargeExamSupport
import Testing

/// Gói `.exam` do `scripts/gen_large_exam.py` ghi (đóng gói bằng pack_exam.py) mở được bằng bộ đọc nghiêm của app và
/// đúng bằng đề `StandardExam` cùng tham số (cả byte ảnh). Đề nhỏ để nhanh; bỏ qua khi máy không có python3.
@Suite("Gói do gen_large_exam.py ghi: đọc nghiêm được, trùng StandardExam")
struct GeneratedPackageTests {
    /// Đường dẫn python3 trên PATH, nếu có.
    static let python: URL? = {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        return path.split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("python3") }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }()

    @Test("seed 7, 40 câu, 4 phần", .enabled(if: python != nil, "cần python3 trên PATH"))
    func pythonPackageReadsStrictly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedPackageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let process = Process()
        process.executableURL = try #require(Self.python)
        process.arguments = [
            RepoPaths.root.appendingPathComponent("scripts/gen_large_exam.py").path,
            "--seed", "7", "--questions", "40", "--sections", "4", "--out", directory.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let packed = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "exam" }
        let file = try #require(packed.first)
        #expect(packed.count == 1)
        let read = try ExamPackageReader.read(contentsOf: file, mode: .strict)
        let expected = StandardExam.make(seed: 7, questions: 40, sections: 4)
        #expect(read == expected)
        #expect(read.media.count == 4)
    }
}
