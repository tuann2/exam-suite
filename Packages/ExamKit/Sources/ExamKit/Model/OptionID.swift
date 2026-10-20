import Foundation

/// Mã lựa chọn: đúng một chữ cái in hoa A–Z, theo thứ tự xuất hiện trong `options`
/// (docs/product/exam-format.md). Chấm điểm so sánh theo mã này, không theo vị trí hiển thị.
public struct OptionID: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let letter: Character

    /// Trả về nil nếu không phải một chữ cái A–Z.
    public init?(_ letter: Character) {
        guard letter.isASCII, letter.isUppercase, letter.isLetter else { return nil }
        self.letter = letter
    }

    public init?(_ string: String) {
        guard string.count == 1, let c = string.first else { return nil }
        self.init(c)
    }

    /// Mã ở vị trí `index` (0 → A, 1 → B, …, 25 → Z); nil nếu ngoài khoảng.
    public init?(index: Int) {
        guard (0 ..< 26).contains(index) else { return nil }
        self.init(Character(Unicode.Scalar(UInt8(ascii: "A") + UInt8(index))))
    }

    /// Vị trí 0-based tương ứng (A → 0).
    public var index: Int { Int(letter.asciiValue! - UInt8(ascii: "A")) }

    public var description: String { String(letter) }

    public static func < (lhs: OptionID, rhs: OptionID) -> Bool { lhs.letter < rhs.letter }
}

extension OptionID: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let id = OptionID(raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Mã lựa chọn phải là một chữ cái A–Z, nhận được \"\(raw)\""
            ))
        }
        self = id
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
