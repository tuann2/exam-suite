import Foundation

/// Dữ liệu lần thi đọc được (đúng cú pháp, đủ khoá, đúng kiểu) nhưng mâu thuẫn với chính nó,
/// ví dụ tổng theo phần lệch tổng chung hay đáp án của câu không thuộc đề.
///
/// Các kiểu `Codable` của lần thi (`ScoreResult`, `ExamPaper`, `AttemptRecord`…) ném
/// `DecodingError.dataCorrupted` với lỗi này ở `underlyingError`, để người gọi phân biệt
/// "mâu thuẫn" với "JSON hỏng". `AttemptRecord.decode(_:)` chuyển thành
/// `AttemptRecordError.inconsistentPayload`.
public struct PayloadConsistencyError: Error, Equatable, Sendable {
    /// Mô tả ngắn (tiếng Việt) điều mâu thuẫn đầu tiên tìm thấy.
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

/// `DecodingError` báo dữ liệu mâu thuẫn (xem `PayloadConsistencyError`).
func inconsistency(_ reason: String, codingPath: [CodingKey]) -> DecodingError {
    .dataCorrupted(.init(
        codingPath: codingPath,
        debugDescription: reason,
        underlyingError: PayloadConsistencyError(reason: reason)
    ))
}

// Quy ước mã hoá chung của dữ liệu lần thi (docs/product/exam-taking.md, "Dữ liệu một lần thi"):
// - UUID là chuỗi chữ thường (như `exam.json`); đọc nhận cả chữ hoa.
// - Tập (`Set`) ghi thành mảng đã sắp xếp để cùng dữ liệu cho cùng JSON; đọc thì từ chối phần tử trùng.
// - Từ điển theo id câu ghi thành object JSON, khoá là UUID chữ thường. `JSONEncoder` mặc định ghi
//   `[UUID: V]` thành mảng xen kẽ khoá/giá trị nên không dùng trực tiếp.
// - `UInt64` (seed) ghi thành chuỗi thập phân: số JSON lớn hơn 2^53 mất chính xác ở nhiều bộ đọc.

extension KeyedEncodingContainer {
    mutating func encodeLowercased(_ ids: [UUID], forKey key: Key) throws {
        try encode(ids.map { $0.uuidString.lowercased() }, forKey: key)
    }

    /// Tập id thành mảng chuỗi chữ thường đã sắp xếp.
    mutating func encodeSorted(_ ids: Set<UUID>, forKey key: Key) throws {
        try encode(ids.map { $0.uuidString.lowercased() }.sorted(), forKey: key)
    }

    /// Từ điển theo id thành object JSON, khoá là UUID chữ thường.
    mutating func encodeByID<Value: Encodable>(_ values: [UUID: Value], forKey key: Key) throws {
        var object: [String: Value] = [:]
        for (id, value) in values {
            object[id.uuidString.lowercased()] = value
        }
        try encode(object, forKey: key)
    }

    /// Seed `UInt64` thành chuỗi thập phân, không mất chính xác.
    mutating func encodeDecimalString(_ value: UInt64, forKey key: Key) throws {
        try encode(String(value), forKey: key)
    }
}

extension KeyedDecodingContainer {
    /// Mảng id thành tập; id trùng là dữ liệu hỏng.
    func decodeUniqueIDs(forKey key: Key) throws -> Set<UUID> {
        let ids = try decode([UUID].self, forKey: key)
        let set = Set(ids)
        guard set.count == ids.count else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Id bị trùng")
        }
        return set
    }

    /// Object JSON có khoá là UUID thành từ điển theo id. Khoá không phải UUID, hoặc hai khoá
    /// cùng một UUID (khác chữ hoa/thường), là dữ liệu hỏng.
    func decodeByID<Value: Decodable>(_ type: Value.Type, forKey key: Key) throws -> [UUID: Value] {
        let object = try decode([String: Value].self, forKey: key)
        var result: [UUID: Value] = [:]
        for (raw, value) in object {
            guard let id = UUID(uuidString: raw) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: self, debugDescription: "Khoá \"\(raw)\" không phải UUID")
            }
            guard result.updateValue(value, forKey: id) == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: key, in: self, debugDescription: "Khoá \(raw) bị trùng")
            }
        }
        return result
    }

    /// Chuỗi thập phân thành `UInt64`: chỉ chữ số 0–9, không dấu, không vượt `UInt64.max`.
    func decodeDecimalString(forKey key: Key) throws -> UInt64 {
        let raw = try decode(String.self, forKey: key)
        guard !raw.isEmpty, raw.utf8.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }),
              let value = UInt64(raw, radix: 10)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: self, debugDescription: "\"\(raw)\" không phải số nguyên không dấu 64 bit")
        }
        return value
    }
}
