import Foundation

/// Tập khoá hợp lệ ở từng cấp của `exam.json` v1, khai báo một chỗ duy nhất.
/// Phải trùng với `properties` trong schema/exam-v1.schema.json; test
/// `ExamSchemaKeysTests` đọc schema và so sánh để hai bên không lệch nhau.
enum ExamSchemaKeys {
    static let exam: Set<String> = [
        "formatVersion", "id", "title", "code", "passPercent", "timeLimitMinutes",
        "hideAnswers", "instructions", "sections",
    ]
    static let section: Set<String> = ["id", "title", "questions"]
    static let question: Set<String> = ["id", "type", "text", "image", "options", "correct", "explanation"]
    static let option: Set<String> = ["id", "text"]

    /// Đường dẫn mọi trường lạ trong JSON thô của đề, theo thứ tự cấu trúc
    /// (đề → section → câu → lựa chọn); trong cùng một object xếp theo tên khoá.
    /// Giá trị sai kiểu (ví dụ `sections` không phải mảng) được bỏ qua ở đây;
    /// bước giải mã sẽ báo lỗi.
    static func unknownFieldPaths(in exam: [String: Any]) -> [String] {
        var paths = unknown(in: exam, allowed: Self.exam, prefix: "")
        for (si, section) in objects(exam["sections"]).enumerated() {
            let sp = "sections[\(si)]"
            paths += unknown(in: section, allowed: Self.section, prefix: sp)
            for (qi, question) in objects(section["questions"]).enumerated() {
                let qp = "\(sp).questions[\(qi)]"
                paths += unknown(in: question, allowed: Self.question, prefix: qp)
                for (oi, option) in objects(question["options"]).enumerated() {
                    paths += unknown(in: option, allowed: Self.option, prefix: "\(qp).options[\(oi)]")
                }
            }
        }
        return paths
    }

    private static func unknown(in object: [String: Any], allowed: Set<String>, prefix: String) -> [String] {
        object.keys.filter { !allowed.contains($0) }.sorted().map { prefix.isEmpty ? $0 : "\(prefix).\($0)" }
    }

    /// Các phần tử của một mảng JSON dưới dạng object; phần tử không phải object
    /// được thay bằng object rỗng để chỉ số trong đường dẫn vẫn đúng vị trí gốc.
    private static func objects(_ value: Any?) -> [[String: Any]] {
        guard let array = value as? [Any] else { return [] }
        return array.map { $0 as? [String: Any] ?? [:] }
    }
}
