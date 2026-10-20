import Foundation

/// Tên các entry của một file zip, đọc từ thư mục trung tâm (central directory), không giải nén gì. Chỉ để cửa sổ soạn
/// đề biết ảnh câu tham chiếu có trong file nhưng sai tên (bộ đọc của ExamFile bỏ qua chúng, exam-format.md). Không
/// dùng ZIPFoundation (ADR 0006: chỉ ExamFile, ExamImport) và không đổi ExamFile.
///
/// Trả `nil` với zip không đọc được theo cách đơn giản này (ZIP64, thư mục trung tâm hỏng): khi đó coi như không biết.
enum ZipEntryNames {
    static func names(in data: Data) -> Set<String>? {
        let bytes = [UInt8](data)
        let endSize = 22
        guard bytes.count >= endSize else { return nil }
        // End of central directory: tìm từ cuối (sau nó có thể có chú thích tối đa 65.535 byte).
        let lowest = max(0, bytes.count - endSize - 0xFFFF)
        var end: Int?
        var position = bytes.count - endSize
        while position >= lowest {
            if uint32(bytes, position) == 0x0605_4B50 { end = position; break }
            position -= 1
        }
        guard let end else { return nil }
        let count = Int(uint16(bytes, end + 10))
        let size = Int(uint32(bytes, end + 12))
        let offset = Int(uint32(bytes, end + 16))
        // ZIP64 (các trường đầy 0xFF…) hoặc vượt khỏi file: không đọc.
        guard count != 0xFFFF, offset != 0xFFFF_FFFF, offset + size <= end else { return nil }
        var names = Set<String>()
        var cursor = offset
        for _ in 0 ..< count {
            guard cursor + 46 <= end, uint32(bytes, cursor) == 0x0201_4B50 else { return nil }
            let nameLength = Int(uint16(bytes, cursor + 28))
            let extraLength = Int(uint16(bytes, cursor + 30))
            let commentLength = Int(uint16(bytes, cursor + 32))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= end else { return nil }
            names.insert(String(decoding: bytes[nameStart ..< nameStart + nameLength], as: UTF8.self))
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return names
    }

    private static func uint16(_ bytes: [UInt8], _ at: Int) -> UInt16 {
        UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8
    }

    private static func uint32(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        UInt32(bytes[at]) | UInt32(bytes[at + 1]) << 8 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 3]) << 24
    }
}
