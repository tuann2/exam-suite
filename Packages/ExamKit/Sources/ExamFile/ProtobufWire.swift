import Foundation

/// Đọc dây Protobuf (https://protobuf.dev/programming-guides/encoding/) có kiểm biên, cho file `.oef`
/// (docs/product/exam-format.md, mục File `.oef`). Tự viết vì ADR 0006 không cho thêm thư viện; chỉ những kiểu dây
/// `.oef` dùng. Mọi độ dài được so với phần còn lại của thông điệp; sai lệch nào cũng là
/// `OEFProblem.malformed(offset:)` với vị trí byte tính từ đầu file.
struct ProtobufReader {
    enum WireType: UInt8 {
        case varint = 0
        case fixed64 = 1
        case lengthDelimited = 2
        case fixed32 = 5
    }

    struct Tag {
        let field: Int
        let wireType: WireType
        /// Vị trí byte đầu của khoá trong file.
        let offset: Int
    }

    private let bytes: [UInt8]
    private(set) var position: Int
    let end: Int

    init(_ bytes: [UInt8]) {
        self.init(bytes, range: 0 ..< bytes.count)
    }

    init(_ bytes: [UInt8], range: Range<Int>) {
        self.bytes = bytes
        position = range.lowerBound
        end = range.upperBound
    }

    var isAtEnd: Bool { position >= end }

    /// Khoá kế tiếp; `nil` khi hết thông điệp. Kiểu dây nhóm (3, 4) và số trường 0 là dây hỏng.
    mutating func nextTag() throws -> Tag? {
        guard !isAtEnd else { return nil }
        let offset = position
        let key = try readVarint()
        guard let wireType = WireType(rawValue: UInt8(key & 7)), key >> 3 != 0, key >> 3 <= 0x1FFF_FFFF else {
            throw ExamFileError.oef(.malformed(offset: offset))
        }
        return Tag(field: Int(key >> 3), wireType: wireType, offset: offset)
    }

    /// Varint tối đa 10 byte; byte thứ 10 chỉ được mang bit cuối của số 64 bit.
    mutating func readVarint() throws -> UInt64 {
        let start = position
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard position < end else { throw ExamFileError.oef(.malformed(offset: start)) }
            let byte = bytes[position]
            position += 1
            if shift == 63, byte > 1 { throw ExamFileError.oef(.malformed(offset: start)) }
            value |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
            if shift > 63 { throw ExamFileError.oef(.malformed(offset: start)) }
        }
    }

    mutating func readFixed64() throws -> UInt64 {
        guard end - position >= 8 else { throw ExamFileError.oef(.malformed(offset: position)) }
        var value: UInt64 = 0
        for index in 0 ..< 8 { value |= UInt64(bytes[position + index]) << (8 * UInt64(index)) }
        position += 8
        return value
    }

    /// Vùng byte của một trường độ dài; con trỏ nhảy qua vùng đó.
    mutating func readLengthDelimited() throws -> Range<Int> {
        let start = position
        let length = try readVarint()
        guard length <= UInt64(end - position) else { throw ExamFileError.oef(.malformed(offset: start)) }
        let range = position ..< position + Int(length)
        position = range.upperBound
        return range
    }

    /// Bỏ qua giá trị của trường (trường lạ).
    mutating func skip(_ wireType: WireType) throws {
        switch wireType {
        case .varint: _ = try readVarint()
        case .fixed64: _ = try readFixed64()
        case .lengthDelimited: _ = try readLengthDelimited()
        case .fixed32:
            guard end - position >= 4 else { throw ExamFileError.oef(.malformed(offset: position)) }
            position += 4
        }
    }

    /// Chuỗi UTF-8 hợp lệ trong vùng `range`; không hợp lệ là dây hỏng tại đầu vùng.
    func string(in range: Range<Int>) throws -> String {
        guard let text = String(validating: bytes[range], as: UTF8.self) else {
            throw ExamFileError.oef(.malformed(offset: range.lowerBound))
        }
        return text
    }

    func data(in range: Range<Int>) -> Data {
        Data(bytes[range])
    }

    /// Bộ đọc cho thông điệp con nằm trong `range`.
    func nested(_ range: Range<Int>) -> ProtobufReader {
        ProtobufReader(bytes, range: range)
    }
}
