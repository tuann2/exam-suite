import Foundation

/// Bộ mã hoá/giải mã JSON chuẩn cho `exam.json`: khoá sắp xếp, thụt lề, không
/// escape `/` để file ổn định khi diff và đọc được bằng mắt.
public enum ExamJSON {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    public static func decoder() -> JSONDecoder { JSONDecoder() }

    public static func encode(_ exam: Exam) throws -> Data {
        try encoder().encode(exam)
    }

    public static func decode(_ data: Data) throws -> Exam {
        try decoder().decode(Exam.self, from: data)
    }
}

extension KeyedEncodingContainer {
    /// `UUID.uuidString` là chữ hoa; file đề dùng chữ thường cho đồng nhất với ví dụ trong schema.
    mutating func encodeLowercased(_ uuid: UUID, forKey key: Key) throws {
        try encode(uuid.uuidString.lowercased(), forKey: key)
    }
}
