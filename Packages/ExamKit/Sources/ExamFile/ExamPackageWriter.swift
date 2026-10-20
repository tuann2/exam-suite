import ExamKit
import Foundation
import ZIPFoundation

/// Ghi gói `.exam` (docs/product/exam-format.md, mục Gói).
///
/// - Luôn ghi `formatVersion` mới nhất (`ExamFileFormat.currentVersion`).
/// - Chỉ ghi `exam.json` và những ảnh được câu hỏi tham chiếu, có trong `media` và
///   đúng mẫu tên `media/<hash>.<ext>`; ảnh mồ côi bị bỏ.
/// - Không chặn lưu khi thiếu ảnh (bản Admin báo lỗi nhưng vẫn lưu,
///   docs/product/exam-format.md): tham chiếu thiếu được giữ nguyên trong `exam.json`,
///   xem `ExamPackage.missingMedia`.
/// - Thứ tự entry: `exam.json` rồi ảnh theo tên tăng dần; mọi entry nén deflate,
///   cùng ngày giờ cố định, nên cùng nội dung cho ra cùng byte trên cùng một nền tảng.
public enum ExamPackageWriter {
    /// Ngày giờ ghi vào mọi entry: 2026-01-01 00:00:00 UTC, giống `scripts/pack_exam.py`.
    static let entryModificationDate = Date(timeIntervalSince1970: 1_767_225_600)

    public static func write(_ package: ExamPackage) throws -> Data {
        var exam = package.exam
        exam.formatVersion = ExamFileFormat.currentVersion

        let manifest: Data
        do {
            manifest = try ExamJSON.encode(exam)
        } catch {
            throw ExamFileError.writeFailed(.encodingFailed("\(error)"))
        }

        let referenced = Set(exam.allQuestions.compactMap(\.image))
            .filter { MediaNaming.isValidPath($0) && package.media[$0] != nil }
            .sorted()
        do {
            let archive = try Archive(data: Data(), accessMode: .create)
            try add(manifest, at: ExamFileFormat.manifestName, to: archive)
            for path in referenced {
                if let data = package.media[path] { try add(data, at: path, to: archive) }
            }
            guard let data = archive.data else {
                throw ExamFileError.writeFailed(.archiveUnavailable)
            }
            return data
        } catch let error as ExamFileError {
            throw error
        } catch {
            throw ExamFileError.writeFailed(.archiveFailed("\(error)"))
        }
    }

    /// Ghi nguyên tử: ghi ra file tạm cùng thư mục rồi `rename(2)` đè lên file
    /// đích (nguyên tử trên cùng volume), để lỗi giữa chừng không làm hỏng file cũ.
    /// Không dùng `FileManager.replaceItemAt` vì trên Linux nó lỗi khi file đích đã có.
    public static func write(_ package: ExamPackage, to url: URL) throws {
        let data = try write(package)
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary)
            let status = temporary.withUnsafeFileSystemRepresentation { source in
                url.withUnsafeFileSystemRepresentation { destination in
                    guard let source, let destination else { return Int32(-1) }
                    return rename(source, destination)
                }
            }
            if status != 0 {
                let code = POSIXErrorCode(rawValue: errno) ?? .EIO
                throw ExamFileError.writeFailed(.replaceFailed(
                    fileName: url.lastPathComponent,
                    systemReason: POSIXError(code).localizedDescription
                ))
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func add(_ data: Data, at path: String, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            modificationDate: entryModificationDate,
            compressionMethod: .deflate,
            provider: { position, size in
                data.subdata(in: Int(position) ..< Int(position) + size)
            }
        )
    }
}
