#if canImport(CommonCrypto)
    import CommonCrypto
#endif
import ExamFile
import ExamKit
import Foundation

/// Ảnh PNG của đề chuẩn: 1600×1000 xám, nhiễu giả ngẫu nhiên (không nén được, như ảnh chụp), xen kẽ 1 bit và 2 bit
/// mỗi điểm ảnh (~196 KB / ~392 KB, trung bình ~300 KB). Zlib chỉ dùng khối "stored" để byte giống hệt
/// `png_image` của scripts/gen_large_exam.py trên mọi nền tảng (không phụ thuộc phiên bản zlib).
enum NoisePNG {
    static let width = 1_600
    static let height = 1_000
    static let poolBytes = 1 << 20
    /// Số lẻ: điểm bắt đầu trong khối nhiễu của các ảnh khác nhau (mod 2^20).
    static let stride = 104_729
    static let salt: UInt64 = 0x4C41_5247_4550_4E47 // "LARGEPNG"

    /// Khối nhiễu 1 MiB: SplitMix64(seed ^ salt), mỗi số 8 byte little-endian.
    static func pool(seed: UInt64) -> [UInt8] {
        var rng = SeededGenerator(seed: seed ^ salt)
        var bytes = [UInt8](repeating: 0, count: poolBytes)
        bytes.withUnsafeMutableBytes { buffer in
            for index in 0 ..< poolBytes / 8 {
                buffer.storeBytes(of: rng.next().littleEndian, toByteOffset: index * 8, as: UInt64.self)
            }
        }
        return bytes
    }

    /// Ảnh thứ `ordinal` (0, 1, 2… theo thứ tự câu có ảnh).
    static func image(pool: [UInt8], ordinal: Int) -> Data {
        let depth = ordinal % 2 == 0 ? 1 : 2
        let rowBytes = width * depth / 8
        var raw = [UInt8]()
        raw.reserveCapacity((rowBytes + 1) * height)
        var offset = (ordinal * stride) % poolBytes
        for _ in 0 ..< height {
            raw.append(0) // bộ lọc 0 (None)
            let end = offset + rowBytes
            if end <= poolBytes {
                raw.append(contentsOf: pool[offset ..< end])
            } else {
                raw.append(contentsOf: pool[offset...])
                raw.append(contentsOf: pool[..<(end - poolBytes)])
            }
            offset = end % poolBytes
        }

        var stream: [UInt8] = [0x78, 0x01]
        stream.reserveCapacity(raw.count + raw.count / 65_535 * 5 + 16)
        var position = 0
        while true {
            let count = min(65_535, raw.count - position)
            position += count
            let final = position >= raw.count
            stream.append(final ? 1 : 0)
            stream.append(contentsOf: littleEndian16(UInt16(count)) + littleEndian16(UInt16(count) ^ 0xFFFF))
            stream.append(contentsOf: raw[(position - count) ..< position])
            if final { break }
        }
        stream.append(contentsOf: bigEndian32(adler32(raw)))

        var header = bigEndian32(UInt32(width)) + bigEndian32(UInt32(height))
        header += [UInt8(depth), 0, 0, 0, 0]
        var png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        png += chunk("IHDR", header)
        png += chunk("IDAT", stream)
        png += chunk("IEND", [])
        return Data(png)
    }

    /// "media/<16 hex đầu SHA-256>.png", đúng như `MediaNaming.path(for:fileExtension:)`. Trên macOS băm bằng
    /// CommonCrypto: SHA-256 thuần Swift của ExamFile ở bản Debug chỉ khoảng 4 MB/s (~14 s cho 60 MB ảnh, mỗi tiến
    /// trình test). Linux (không có CommonCrypto) dùng MediaNaming. `StandardExamTests` đối chiếu hai cách.
    static func mediaPath(for data: Data) -> String {
        #if canImport(CommonCrypto)
            var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes { buffer in
                _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
            }
            let hex = digest.prefix(MediaNaming.hashPrefixLength / 2).map { String(format: "%02x", $0) }.joined()
            return "media/\(hex).png"
        #else
            // Đuôi "png" luôn hợp lệ nên không ném lỗi.
            return try! MediaNaming.path(for: data, fileExtension: "png")
        #endif
    }

    private static func chunk(_ kind: String, _ data: [UInt8]) -> [UInt8] {
        let typed = Array(kind.utf8) + data
        return bigEndian32(UInt32(data.count)) + typed + bigEndian32(crc32(typed))
    }

    private static func bigEndian32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private static func littleEndian16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8)]
    }

    /// Adler-32 (RFC 1950), cộng dồn theo khối 5552 byte rồi mới lấy dư.
    static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        bytes.withUnsafeBufferPointer { buffer in
            var index = 0
            while index < buffer.count {
                let end = Swift.min(index + 5_552, buffer.count)
                while index < end {
                    a &+= UInt32(buffer[index])
                    b &+= a
                    index += 1
                }
                a %= 65_521
                b %= 65_521
            }
        }
        return b << 16 | a
    }

    private static let crcTable: [UInt32] = (0 ..< 256).map { n in
        var c = UInt32(n)
        for _ in 0 ..< 8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    /// CRC-32 (ISO 3309, như zlib.crc32).
    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        crcTable.withUnsafeBufferPointer { table in
            bytes.withUnsafeBufferPointer { buffer in
                for byte in buffer {
                    crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
                }
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
