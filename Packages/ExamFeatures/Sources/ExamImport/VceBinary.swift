import Foundation

// Các khối nhị phân dùng chung cho bộ đọc `.vce` (docs/product/import.md mục `.vce`, ADR 0009).
// Nguồn hiểu biết về định dạng: phân tích file mẫu tại máy (docs/notes/vce-format.md), không từ code hay công cụ của bên
// thứ ba. Code viết mới, chỉ Foundation; bố cục file ghi ở `VceImporter`.

/// Lỗi cấu trúc khi đọc `.vce`. Ở mức file: thành `ImportError.unreadableVCE` (không mở cửa sổ); ở mức một câu
/// (bản ghi câu có kích thước riêng): câu bị bỏ và ghi báo cáo.
struct VceFormatError: Error, Equatable {
    /// Lý do có mã, không kèm vị trí byte (người dùng không cần).
    let problem: VceProblem

    init(_ problem: VceProblem) {
        self.problem = problem
    }

    static func truncated(_ field: VceField) -> VceFormatError {
        VceFormatError(.truncated(field))
    }

    static func badLength(_ field: VceField, _ length: Int) -> VceFormatError {
        VceFormatError(.badLength(field, length))
    }
}

/// Đọc tuần tự có kiểm biên trên một vùng byte. Mọi độ dài và số lượng đọc từ file được so với số byte còn lại trước
/// khi dùng, nên file sai không làm tràn chỉ số hay cấp phát lớn.
struct VceByteReader {
    let bytes: [UInt8]
    private(set) var position: Int
    let end: Int

    /// Vùng `range` của `bytes` (mặc định cả mảng).
    init(_ bytes: [UInt8], range: Range<Int>? = nil) {
        let range = range ?? bytes.startIndex ..< bytes.endIndex
        self.bytes = bytes
        position = range.lowerBound
        end = range.upperBound
    }

    var remaining: Int { end - position }
    var isAtEnd: Bool { position >= end }

    mutating func u8(_ what: VceField) throws -> UInt8 {
        guard remaining >= 1 else { throw VceFormatError.truncated(what) }
        defer { position += 1 }
        return bytes[position]
    }

    /// `i32` có dấu, little-endian.
    mutating func i32(_ what: VceField) throws -> Int {
        guard remaining >= 4 else { throw VceFormatError.truncated(what) }
        let value = Self.int32(bytes, at: position)
        position += 4
        return value
    }

    /// `count` byte kế tiếp (không chép).
    mutating func take(_ count: Int, _ what: VceField) throws -> ArraySlice<UInt8> {
        guard count >= 0, remaining >= count else { throw VceFormatError.truncated(what) }
        defer { position += count }
        return bytes[position ..< position + count]
    }

    mutating func skip(_ count: Int, _ what: VceField) throws {
        _ = try take(count, what)
    }

    /// `blob`: `i32` độ dài `n` + `n` byte. Độ dài âm hoặc lớn hơn phần còn lại → lỗi.
    mutating func blob(_ what: VceField) throws -> ArraySlice<UInt8> {
        let length = try i32(.lengthOf(what))
        guard length >= 0, length <= remaining else { throw VceFormatError.badLength(what, length) }
        return try take(length, what)
    }

    /// `xstr`: `blob` rỗng, hoặc `FF FF` + chuỗi 1 byte/ký tự đã che (`VceMask`). Trả byte đã bỏ che. Dạng khác (không
    /// có `FF FF`) là bố cục chưa biết → lỗi.
    mutating func xstr(_ what: VceField) throws -> [UInt8] {
        let raw = try blob(what)
        if raw.isEmpty { return [] }
        guard raw.count >= 2, raw[raw.startIndex] == 0xFF, raw[raw.startIndex + 1] == 0xFF else {
            throw VceFormatError(.badString(what))
        }
        return VceMask.unmask(raw.dropFirst(2))
    }

    static func int32(_ bytes: [UInt8], at index: Int) -> Int {
        let raw = UInt32(bytes[index]) | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2]) << 16
            | UInt32(bytes[index + 3]) << 24
        return Int(Int32(bitPattern: raw))
    }

    static func uint32(_ bytes: [UInt8], at index: Int) -> UInt32 {
        UInt32(bytes[index]) | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2]) << 16
            | UInt32(bytes[index + 3]) << 24
    }
}

/// Phép che đơn giản của nội dung `.vce`, tính lại từ đầu mỗi vùng. Không có khoá bí mật; phép này tự đảo (che và bỏ
/// che là một).
enum VceMask {
    static func unmask<C: Collection>(_ bytes: C) -> [UInt8] where C.Element == UInt8 {
        var out = [UInt8]()
        out.reserveCapacity(bytes.count)
        var index = 0
        for byte in bytes {
            out.append(byte ^ UInt8(truncatingIfNeeded: index))
            index += 1
        }
        return out
    }
}

/// CRC-32 chuẩn (đa thức đảo 0xEDB88320, giá trị đầu và XOR cuối 0xFFFFFFFF; cùng kết quả với zlib), cài đặt bảng
/// 256 mục viết mới theo định nghĩa công khai của thuật toán. Kiểm toàn vẹn file `.vce` (trường CRC-32
/// cuối file, `VceImporter`).
enum VceCRC32 {
    static let table: [UInt32] = (0 ..< 256).map { n in
        var c = UInt32(n)
        for _ in 0 ..< 8 {
            c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    static func checksum(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        table.withUnsafeBufferPointer { table in
            bytes.withUnsafeBufferPointer { buffer in
                for byte in buffer {
                    crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
                }
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

/// Giải chuỗi 1 byte/ký tự theo Windows-1252 (giả thuyết cho `xstr` và văn bản ANSI của RVF: các file mẫu chưa có ký tự
/// ngoài ASCII ở đó): 0x00–0x7F và 0xA0–0xFF giữ nguyên mã; 0x80–0x9F theo bảng Windows-1252 (năm byte chưa
/// định nghĩa ứng với mã C1 cùng giá trị, như `MojibakeRepair`).
enum Windows1252 {
    /// Chuỗi và `true` nếu có byte ngoài ASCII (tức đã dựa vào giả thuyết mã hoá).
    static func decode<C: Collection>(_ bytes: C) -> (text: String, usedNonASCII: Bool) where C.Element == UInt8 {
        var scalars = String.UnicodeScalarView()
        var nonASCII = false
        for byte in bytes {
            if byte >= 0x80 { nonASCII = true }
            scalars.append(MojibakeRepair.scalar(forWindows1252: byte))
        }
        return (String(scalars), nonASCII)
    }
}
