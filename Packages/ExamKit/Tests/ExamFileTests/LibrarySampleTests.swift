import ExamKit
import Foundation
import Testing
@testable import ExamFile

/// Đề mẫu bản app ghi ra lần đầu mở (docs/product/library.md, mục "Đề mẫu và lần đầu mở app"),
/// nằm ở `RepoPaths.samples/<tên>/` (exam.json + media/). Kỳ vọng chặt hơn nhãn `valid` của
/// fixtures/expected-verdicts.json: bản Học viên đọc nghiêm được và không có cả warning.
/// Phía script: `scripts/validate_exam.py --all` (hàm `check_sample`) kiểm cùng các quy tắc và
/// thêm NFC; ở đây không kiểm NFC vì `String` của Swift so theo tương đương chính tắc.
@Suite("Đề mẫu của Thư viện: đọc nghiêm được, không error lẫn warning")
struct LibrarySampleTests {
    /// Mọi thư mục con không ẩn, theo tên. Thư mục thiếu `exam.json` vẫn có mặt để test đỏ,
    /// không bị bỏ qua (như `check_sample` của script).
    static let names: [String] = {
        let fileManager = FileManager.default
        let all = (try? fileManager.contentsOfDirectory(atPath: RepoPaths.samples.path)) ?? []
        return all.sorted().filter { name in
            var isDirectory: ObjCBool = false
            let path = RepoPaths.samples.appendingPathComponent(name).path
            return !name.hasPrefix(".") && fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    }()

    static func directory(_ name: String) -> URL {
        RepoPaths.samples.appendingPathComponent(name, isDirectory: true)
    }

    @Test("Tìm thấy đề mẫu (đổi chỗ thư mục thì sửa RepoPaths.samples và SAMPLES của validate_exam.py)")
    func samplesFound() {
        #expect(!Self.names.isEmpty, "Không có đề mẫu trong \(RepoPaths.samples.path)")
    }

    @Test("Mỗi thư mục đề mẫu có exam.json", arguments: names)
    func manifestPresent(name: String) {
        let manifest = Self.directory(name).appendingPathComponent("exam.json")
        #expect(FileManager.default.fileExists(atPath: manifest.path), "\(name): thư mục đề mẫu thiếu exam.json")
    }

    @Test("Đóng gói như pack_exam.py, đọc strict: không vấn đề nào; ghi lại rồi đọc ra đúng gói",
          arguments: names)
    func strictReadWithoutIssues(name: String) throws {
        let package = try ExamPackageReader.read(Zip.make(Zip.directoryEntries(Self.directory(name))), mode: .strict)
        #expect(package.validationIssues.isEmpty, "\(name): \(package.validationIssues.map(\.message))")
        #expect(try ExamPackageReader.read(ExamPackageWriter.write(package), mode: .strict) == package)
    }

    @Test("media/: mỗi ảnh được một câu dùng và đặt tên theo SHA-256 nội dung", arguments: names)
    func mediaNamedByContent(name: String) throws {
        let package = try ExamPackageReader.read(Zip.make(Zip.directoryEntries(Self.directory(name))), mode: .strict)
        let mediaDir = Self.directory(name).appendingPathComponent("media", isDirectory: true)
        // Bỏ qua file ẩn (.DS_Store do Finder tạo, đã có trong .gitignore), như script.
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: mediaDir.path)) ?? [])
            .filter { !$0.hasPrefix(".") }
        #expect(Set(files.map { "media/\($0)" }) == Set(package.exam.allQuestions.compactMap(\.image)), "\(name)")
        for file in files {
            let url = mediaDir.appendingPathComponent(file)
            let data = try Data(contentsOf: url)
            #expect(try MediaNaming.path(for: data, fileExtension: url.pathExtension) == "media/\(file)", "\(name)")
        }
    }
}
