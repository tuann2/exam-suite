import Foundation

/// Tạo zip không nén (stored) trong bộ nhớ, để test ghi được gói có `exam.json` thô mà
/// `ExamPackageWriter` không bao giờ ghi ra (trường lạ, phiên bản mới hơn…). Tự viết vì
/// ZIPFoundation chỉ được dùng trong module ExamFile (ADR 0006).
enum StoredZip {
    static func make(_ entries: [(name: String, data: Data)]) -> Data {
        var archive = Data()
        var directory = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(archive.count)
            // Local file header.
            archive.append(le32(0x0403_4B50))
            archive.append(le16(20)) // version needed
            archive.append(le16(0x0800)) // tên UTF-8
            archive.append(le16(0)) // stored
            archive.append(le16(0)) // giờ
            archive.append(le16(0x21)) // ngày 1980-01-01
            archive.append(le32(crc))
            archive.append(le32(size))
            archive.append(le32(size))
            archive.append(le16(UInt16(name.count)))
            archive.append(le16(0))
            archive.append(name)
            archive.append(entry.data)
            // Central directory header.
            directory.append(le32(0x0201_4B50))
            directory.append(le16(20)) // version made by (MS-DOS)
            directory.append(le16(20))
            directory.append(le16(0x0800))
            directory.append(le16(0))
            directory.append(le16(0))
            directory.append(le16(0x21))
            directory.append(le32(crc))
            directory.append(le32(size))
            directory.append(le32(size))
            directory.append(le16(UInt16(name.count)))
            directory.append(le16(0)) // extra
            directory.append(le16(0)) // comment
            directory.append(le16(0)) // disk
            directory.append(le16(0)) // internal attributes
            directory.append(le32(0)) // external attributes
            directory.append(le32(offset))
            directory.append(name)
        }
        let directoryOffset = UInt32(archive.count)
        archive.append(directory)
        // End of central directory.
        archive.append(le32(0x0605_4B50))
        archive.append(le16(0))
        archive.append(le16(0))
        archive.append(le16(UInt16(entries.count)))
        archive.append(le16(UInt16(entries.count)))
        archive.append(le32(UInt32(directory.count)))
        archive.append(le32(directoryOffset))
        archive.append(le16(0))
        return archive
    }

    private static func le16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static func le32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}

/// CRC-32 (IEEE 802.3) như zip dùng.
enum CRC32 {
    static let table: [UInt32] = (0 ..< 256).map { index in
        var value = UInt32(index)
        for _ in 0 ..< 8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
