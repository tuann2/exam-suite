import ExamFile
import ExamKit
import Foundation

/// Nguồn đề mẫu: mỗi đề một thư mục con chứa `exam.json` và (tuỳ chọn) `media/`, giống
/// `fixtures/exams/<tên>/` (docs/product/library.md, mục Đề mẫu).
enum SampleSource {
    /// Thư mục con có `exam.json`, theo tên tăng dần; bỏ file ẩn (như `.gitkeep`) và file lẻ.
    /// Nguồn không có hoặc rỗng: mảng rỗng.
    static func sampleDirectories(in root: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return children
            .filter { child in
                (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    && fileManager.fileExists(atPath: child.appendingPathComponent(ExamFileFormat.manifestName).path)
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Dựng gói từ thư mục nguồn: `exam.json` giải mã thành `Exam`, mọi file thường trong `media/`
    /// thành ảnh `media/<tên>`. Ghi bằng `ExamPackageWriter` sẽ chỉ giữ ảnh được câu hỏi tham chiếu.
    static func loadPackage(from directory: URL) throws -> ExamPackage {
        let manifest = try Data(contentsOf: directory.appendingPathComponent(ExamFileFormat.manifestName))
        let exam = try ExamJSON.decode(manifest)
        var media: [String: Data] = [:]
        let mediaDirectory = directory.appendingPathComponent(ExamFileFormat.mediaDirectory, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: mediaDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for file in files where (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            media["\(ExamFileFormat.mediaDirectory)/\(file.lastPathComponent)"] = try Data(contentsOf: file)
        }
        return ExamPackage(exam: exam, media: media)
    }

    /// Tên file dài tối đa 255 byte UTF-8 (giới hạn của APFS và HFS+).
    static let maxFileNameBytes = 255

    /// Tên file theo tiêu đề đề: bỏ ký tự không dùng được trong tên file, bỏ dấu chấm đầu (file ẩn),
    /// thêm `suffix` (ví dụ " 2") và đuôi `.exam`; cả tên không quá `maxFileNameBytes` byte, cắt tiêu đề
    /// ở ranh giới ký tự (không tách chữ với dấu của nó).
    static func fileName(forTitle title: String, suffix: String = "") -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\").union(.controlCharacters).union(.newlines)
        var name = String(String.UnicodeScalarView(title.unicodeScalars.map { forbidden.contains($0) ? "-" : $0 }))
        name = name.trimmingCharacters(in: .whitespaces)
        while name.hasPrefix(".") { name.removeFirst() }
        if name.isEmpty { name = "Đề mẫu" }
        let tail = "\(suffix).\(ExamFileFormat.fileExtension)"
        name = truncated(name, toBytes: maxFileNameBytes - fileNameBytes(tail))
            .trimmingCharacters(in: .whitespaces)
        if name.isEmpty { name = "Đề mẫu" }
        return name + tail
    }

    /// Như `fileName(forTitle:)`, thêm " 2", " 3"… nếu trùng (không phân biệt hoa thường, như ổ APFS
    /// mặc định) với tên đã dùng trong `used`.
    static func uniqueFileName(forTitle title: String, used: inout Set<String>) -> String {
        var candidate = fileName(forTitle: title)
        var counter = 1
        while !used.insert(candidate.lowercased()).inserted {
            counter += 1
            candidate = fileName(forTitle: title, suffix: " \(counter)")
        }
        return candidate
    }

    /// Số byte của tên khi nằm trên đĩa, tính theo dạng tách dấu (NFD): đây là dạng dài nhất mà tên có thể
    /// được lưu (chữ Việt dựng sẵn "ệ" 3 byte, tách dấu 5 byte), nên tên vừa giới hạn ở dạng này thì vừa ở
    /// mọi dạng.
    static func fileNameBytes(_ name: String) -> Int {
        name.decomposedStringWithCanonicalMapping.utf8.count
    }

    /// Phần đầu dài nhất của `text` không quá `limit` byte (theo `fileNameBytes`), cắt ở ranh giới ký tự.
    static func truncated(_ text: String, toBytes limit: Int) -> String {
        var result = ""
        var used = 0
        for character in text {
            let size = fileNameBytes(String(character))
            guard used + size <= limit else { break }
            result.append(character)
            used += size
        }
        return result
    }
}
