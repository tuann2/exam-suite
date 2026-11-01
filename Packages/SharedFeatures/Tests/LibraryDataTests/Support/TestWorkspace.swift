import ExamFile
import ExamKit
import Foundation
@testable import LibraryData

/// Đường dẫn tới `fixtures/` ở gốc repo, tính từ vị trí file này (cùng cách với
/// Packages/ExamKit/Tests/ExamKitTests/Support/Fixtures.swift).
enum RepoFixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // LibraryDataTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // SharedFeatures
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("fixtures", isDirectory: true)

    static func examDirectory(_ name: String) -> URL {
        root.appendingPathComponent("exams/\(name)", isDirectory: true)
    }

    static func invalidJSON(_ name: String) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent("invalid/\(name).json"))
    }

    /// Đề trong `fixtures/exams/<name>` (exam.json + media/), dựng thành `ExamPackage`.
    static func package(_ name: String) throws -> ExamPackage {
        let directory = examDirectory(name)
        let exam = try ExamJSON.decode(Data(contentsOf: directory.appendingPathComponent("exam.json")))
        var media: [String: Data] = [:]
        let mediaDirectory = directory.appendingPathComponent("media", isDirectory: true)
        if FileManager.default.fileExists(atPath: mediaDirectory.path) {
            for file in try FileManager.default.contentsOfDirectory(atPath: mediaDirectory.path) where !file.hasPrefix(".") {
                media["media/\(file)"] = try Data(contentsOf: mediaDirectory.appendingPathComponent(file))
            }
        }
        return ExamPackage(exam: exam, media: media)
    }

    /// Id của đề `fixtures/exams/kien-thuc-chung`.
    static let kienThucChungID = UUID(uuidString: "0b6c1f8e-4d2a-4c1b-9f3e-2a7d5e8c1b40")!
}

/// Thư mục tạm riêng của một test (đường dẫn thật, đã giải `/var` → `/private/var` để khớp đường dẫn
/// bookmark trả về); bị xoá khi test xong. Không test nào ghi vào ~/Library thật.
final class TestWorkspace {
    let root: URL
    /// UserDefaults lưu ở file plist trong thư mục tạm (suite là đường dẫn tuyệt đối).
    let defaults: UserDefaults

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryDataTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = ExamFileInspector.canonical(base)
        defaults = UserDefaults(suiteName: root.appendingPathComponent("defaults.plist").path)!
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath, isDirectory: false)
    }

    @discardableResult
    func makeDirectory(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Ghi gói `.exam` bằng `ExamPackageWriter` (ghi nguyên tử, như app).
    @discardableResult
    func write(_ package: ExamPackage, to relativePath: String) throws -> URL {
        let url = url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ExamPackageWriter.write(package, to: url)
        return url
    }

    @discardableResult
    func write(_ exam: Exam, to relativePath: String) throws -> URL {
        try write(ExamPackage(exam: exam), to: relativePath)
    }

    /// Đóng gói một fixture hợp lệ `fixtures/exams/<name>`, có thể sửa đề trước khi ghi.
    @discardableResult
    func writeFixture(_ name: String, to relativePath: String, change: (inout Exam) -> Void = { _ in }) throws -> URL {
        var package = try RepoFixtures.package(name)
        change(&package.exam)
        return try write(package, to: relativePath)
    }

    /// Gói zip chứa `exam.json` thô (để có trường lạ, phiên bản mới hơn… mà `ExamPackageWriter` không ghi ra).
    @discardableResult
    func writeRawPackage(json: Data, to relativePath: String) throws -> URL {
        let url = url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try StoredZip.make([("exam.json", json)]).write(to: url)
        return url
    }

    /// `fixtures/invalid/<name>.json` đóng gói thành `.exam`.
    @discardableResult
    func writeInvalidFixture(_ name: String, to relativePath: String) throws -> URL {
        try writeRawPackage(json: RepoFixtures.invalidJSON(name), to: relativePath)
    }

    /// File không phải zip.
    @discardableResult
    func writeGarbage(to relativePath: String) throws -> URL {
        let url = url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("đây không phải gói đề".utf8).write(to: url)
        return url
    }

    /// Đổi ngày sửa đổi của file (để lần làm mới thấy file đã đổi mà không đổi nội dung).
    func touch(_ url: URL, offset: TimeInterval = 60) throws {
        let current = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date ?? Date()
        try FileManager.default.setAttributes([.modificationDate: current.addingTimeInterval(offset)], ofItemAtPath: url.path)
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

/// Đề hợp lệ dựng bằng code: `questions` câu một đáp án, chia mỗi phần tối đa 100 câu.
func makeExam(
    id: UUID = UUID(),
    title: String = "Đề thử",
    code: String? = nil,
    questions: Int = 2,
    passPercent: Int = 60,
    timeLimitMinutes: Int = 20
) -> Exam {
    let sections = stride(from: 0, to: questions, by: 100).map { start in
        ExamSection(
            title: "Phần \(start / 100 + 1)",
            questions: (start ..< min(start + 100, questions)).map { index in
                Question(
                    type: .single,
                    text: "Câu \(index + 1): chọn đáp án đúng cho phép tính \(index) + 1 = ?",
                    options: (0 ..< 4).map { option in
                        Option(id: OptionID(index: option)!, text: "Phương án \(option + 1): \(index + option)")
                    },
                    correct: [OptionID(index: 1)!],
                    explanation: "Vì \(index) + 1 = \(index + 1)."
                )
            }
        )
    }
    return Exam(
        id: id,
        title: title,
        code: code,
        passPercent: passPercent,
        timeLimitMinutes: timeLimitMinutes,
        sections: sections
    )
}

/// JSON thô của một đề (để sửa thành có trường lạ, phiên bản lạ…).
func rawJSON(of exam: Exam, change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try JSONSerialization.jsonObject(with: ExamJSON.encode(exam)) as! [String: Any]
    change(&object)
    return try JSONSerialization.data(withJSONObject: object)
}

/// Lý do của file không phải zip (`ExamFileError.notAZipArchive`).
let notZipReason = FileProblemReason.package(.notAZipArchive)

/// Lý do "Đề có trường không được hỗ trợ: …" (`ExamFileError.unknownFields`).
func unknownFieldsReason(_ paths: String...) -> FileProblemReason {
    .package(.unknownFields(paths))
}

/// Lỗi đọc nghiêm/dễ của file theo `ExamPackageReader`, để so lý do hiển thị đúng từng chữ.
func readError(_ url: URL, mode: ReadMode) -> ExamFileError? {
    do {
        _ = try ExamPackageReader.read(contentsOf: url, mode: mode)
        return nil
    } catch {
        return error as? ExamFileError
    }
}
