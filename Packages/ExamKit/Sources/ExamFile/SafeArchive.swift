import Foundation
import ZIPFoundation

/// Mở zip để đọc theo cách không làm crash tiến trình với dữ liệu hỏng.
///
/// Không dùng `Archive(data:)`: ở ZIPFoundation 0.9.20, archive trong bộ nhớ
/// crash ("Range requires lowerBound <= upperBound" trong `MemoryFile.readData`)
/// khi zip hỏng có offset trỏ quá cuối dữ liệu. Archive dạng file chỉ đọc được
/// 0 byte và ném lỗi bình thường, nên dữ liệu trong bộ nhớ được ghi ra file tạm trước.
enum SafeArchive {
    /// Ghi `data` ra file tạm trong `temporaryDirectory`, gọi `body`, rồi xoá file tạm.
    static func withTemporaryFile<T>(_ data: Data, _ body: (URL) throws -> T) throws -> T {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("examfile-read-\(UUID().uuidString).zip")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try body(url)
    }

    /// Archive chỉ đọc của file ở `url`; nil nếu file không phải zip.
    /// Lỗi "không có file / không có quyền" của Foundation được ném nguyên vẹn.
    static func open(_ url: URL) throws -> Archive? {
        if !FileManager.default.isReadableFile(atPath: url.path) {
            _ = try Data(contentsOf: url)
        }
        do {
            // Chú thích kiểu không optional để chọn init ném lỗi, không phải init failable đã deprecated.
            let archive: Archive = try Archive(url: url, accessMode: .read)
            return archive
        } catch {
            return nil
        }
    }
}
