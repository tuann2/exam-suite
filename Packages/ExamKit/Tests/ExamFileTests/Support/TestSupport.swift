import ExamKit
import Foundation
import ZIPFoundation

/// Đường dẫn tới `fixtures/`, `schema/` và đề mẫu của Thư viện ở gốc repo, tính từ vị trí
/// file này (cùng cách với Tests/ExamKitTests/Support/Fixtures.swift).
enum RepoPaths {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // ExamFileTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ExamKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root

    static let fixtures = root.appendingPathComponent("fixtures", isDirectory: true)
    static let schema = root.appendingPathComponent("schema/exam-v1.schema.json")
    /// Đề mẫu bản app ghi ra lần đầu mở (docs/product/library.md); mỗi thư mục con là một gói
    /// đã giải nén như `fixtures/exams/<tên>`. Cùng đường dẫn với `SAMPLES` trong scripts/validate_exam.py.
    static let samples = root.appendingPathComponent(
        "Packages/ExamFeatures/Sources/LibraryData/Resources/Samples", isDirectory: true)

    static func examDirectory(_ name: String) -> URL {
        fixtures.appendingPathComponent("exams/\(name)", isDirectory: true)
    }

    static func examJSON(_ name: String) throws -> Data {
        try Data(contentsOf: examDirectory(name).appendingPathComponent("exam.json"))
    }

    static func invalidJSON(_ name: String) throws -> Data {
        try Data(contentsOf: fixtures.appendingPathComponent("invalid/\(name).json"))
    }
}

enum Zip {
    /// Tạo zip trong bộ nhớ, giữ đúng thứ tự entry. Tên kết thúc bằng "/" là thư mục.
    static func make(_ entries: [(String, Data)], compression: CompressionMethod = .deflate) throws -> Data {
        let archive = try Archive(data: Data(), accessMode: .create)
        for (name, payload) in entries {
            let isDirectory = name.hasSuffix("/")
            try archive.addEntry(
                with: name,
                type: isDirectory ? .directory : .file,
                uncompressedSize: Int64(payload.count),
                compressionMethod: isDirectory ? .none : compression,
                provider: { pos, size in payload.subdata(in: Int(pos) ..< Int(pos) + size) }
            )
        }
        guard let data = archive.data else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    /// Đóng gói một thư mục fixture (exam.json + media/) như scripts/pack_exam.py.
    static func packFixture(_ name: String) throws -> Data {
        try make(fixtureEntries(name))
    }

    static func fixtureEntries(_ name: String) throws -> [(String, Data)] {
        try directoryEntries(RepoPaths.examDirectory(name))
    }

    /// `exam.json` rồi mọi file trong `media/` (theo tên) của một thư mục gói đã giải nén.
    static func directoryEntries(_ dir: URL) throws -> [(String, Data)] {
        var entries: [(String, Data)] = [("exam.json", try Data(contentsOf: dir.appendingPathComponent("exam.json")))]
        let mediaDir = dir.appendingPathComponent("media", isDirectory: true)
        if FileManager.default.fileExists(atPath: mediaDir.path) {
            for file in try FileManager.default.contentsOfDirectory(atPath: mediaDir.path).sorted() {
                entries.append(("media/\(file)", try Data(contentsOf: mediaDir.appendingPathComponent(file))))
            }
        }
        return entries
    }

    /// Tên entry theo thứ tự lưu trong zip.
    static func entryNames(_ data: Data) throws -> [String] {
        try Archive(data: data, accessMode: .read).map(\.path)
    }
}

enum JSONEdit {
    /// Sửa JSON thô của một fixture rồi trả lại dạng Data.
    static func modify(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// Thêm khoá vào object lồng theo đường đi qua các mảng `sections`/`questions`/`options`.
    static func setting(_ value: Any, key: String, section: Int, question: Int? = nil, option: Int? = nil,
                        in exam: inout [String: Any]) {
        var sections = exam["sections"] as! [[String: Any]]
        var s = sections[section]
        if let question {
            var questions = s["questions"] as! [[String: Any]]
            var q = questions[question]
            if let option {
                var options = q["options"] as! [[String: Any]]
                options[option][key] = value
                q["options"] = options
            } else {
                q[key] = value
            }
            questions[question] = q
            s["questions"] = questions
        } else {
            s[key] = value
        }
        sections[section] = s
        exam["sections"] = sections
    }
}
