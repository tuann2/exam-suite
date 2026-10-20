import Foundation
import ZIPFoundation

/// Đọc các phần của file `.docx` (zip) có giới hạn (`ImportLimits`), theo cùng cách né lỗi ZIPFoundation 0.9.20
/// như `ExamPackageReader` (ADR 0006, Follow-Up): luôn mở qua file (không `Archive(data:)`), tự so CRC và kích
/// thước, dừng giải nén ngay khi dữ liệu dài hơn kích thước khai báo (zip bomb nói dối kích thước).
final class DocxArchive {
    private let archive: Archive
    private let limits: ImportLimits
    /// Entry kiểu file theo đường dẫn; đường dẫn xuất hiện hơn một lần nằm ở `duplicates`.
    private var entries: [String: Entry] = [:]
    private var duplicates = Set<String>()
    private var usedBytes = 0

    /// - Throws: `ImportError.notADocx` nếu không phải zip; `.tooLarge` nếu quá số entry.
    init(url: URL, limits: ImportLimits) throws {
        if !FileManager.default.isReadableFile(atPath: url.path) {
            throw ImportError.unreadableFile(.cannotOpen(fileName: url.lastPathComponent))
        }
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw ImportError.notADocx
        }
        self.archive = archive
        self.limits = limits
        var count = 0
        for entry in archive {
            count += 1
            if count > limits.entryCount {
                throw ImportError.tooLarge(what: .docxEntryCount, limit: limits.entryCount)
            }
            guard entry.type == .file else { continue }
            if entries[entry.path] != nil {
                duplicates.insert(entry.path)
            } else {
                entries[entry.path] = entry
            }
        }
    }

    func contains(_ path: String) -> Bool { entries[path] != nil }

    /// Dữ liệu giải nén của phần `path`; `nil` nếu không có.
    /// - Throws: `.corruptedPart` (hỏng, trùng tên), `.tooLarge` (vượt `limit` hoặc tổng giải nén).
    func data(_ path: String, limit: Int) throws -> Data? {
        guard let entry = entries[path] else { return nil }
        // Hai entry cùng tên: không biết bản nào đúng (Word chỉ ghi một), coi như file hỏng.
        guard !duplicates.contains(path) else { throw ImportError.corruptedPart(path) }
        let declared = entry.uncompressedSize
        guard declared <= UInt64(limit) else { throw ImportError.tooLarge(what: .docxPart(path), limit: limit) }
        let total = limits.totalUncompressedBytes
        guard UInt64(usedBytes) + declared <= UInt64(total) else {
            throw ImportError.tooLarge(what: .docxTotalSize, limit: total)
        }
        let expected = Int(declared)
        var out = Data()
        out.reserveCapacity(expected)
        let checksum: CRC32
        do {
            checksum = try archive.extract(entry, skipCRC32: false) { chunk in
                guard out.count + chunk.count <= expected else { throw ImportError.corruptedPart(path) }
                out.append(chunk)
            }
        } catch {
            throw ImportError.corruptedPart(path)
        }
        guard checksum == entry.checksum, out.count == expected else { throw ImportError.corruptedPart(path) }
        usedBytes += out.count
        return out
    }

    /// Ghi dữ liệu trong bộ nhớ ra file tạm, gọi `body`, rồi xoá (như `SafeArchive` của ExamFile).
    static func withTemporaryFile<T>(_ data: Data, _ body: (URL) throws -> T) throws -> T {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("examimport-\(UUID().uuidString).docx")
        do {
            try data.write(to: url)
        } catch {
            throw ImportError.unreadableFile(.system(error.localizedDescription))
        }
        defer { try? FileManager.default.removeItem(at: url) }
        return try body(url)
    }
}

/// Đường dẫn trong gói OPC (docx).
enum PackagePath {
    /// Phân giải `target` của một quan hệ so với thư mục của phần nguồn (`word/document.xml` → `word/`).
    /// Target tuyệt đối (`/word/media/a.png`) tính từ gốc. `nil` nếu ra ngoài gốc gói.
    static func resolve(_ target: String, relativeTo sourcePart: String) -> String? {
        let decoded = target.removingPercentEncoding ?? target
        var components: [Substring]
        if decoded.hasPrefix("/") {
            components = []
        } else {
            components = sourcePart.split(separator: "/", omittingEmptySubsequences: true).dropLast()
        }
        for part in decoded.split(separator: "/", omittingEmptySubsequences: true) {
            switch part {
            case ".": continue
            case "..":
                guard !components.isEmpty else { return nil }
                components.removeLast()
            default: components.append(part)
            }
        }
        return components.isEmpty ? nil : components.joined(separator: "/")
    }

    /// File quan hệ của một phần: `word/document.xml` → `word/_rels/document.xml.rels`.
    static func relationships(of part: String) -> String {
        var components = part.split(separator: "/").map(String.init)
        let name = components.popLast() ?? part
        return (components + ["_rels", name + ".rels"]).joined(separator: "/")
    }
}
