import Foundation

/// Kiểm những điều schema cấm mà `JSONSerialization` và model không thấy được.
/// Chỉ dùng ở chế độ `strict` (bản Học viên). Đường dẫn cùng kiểu với
/// `ExamSchemaKeys.unknownFieldPaths`, ví dụ `sections[0].questions[1].text`.
enum StrictJSON {
    // MARK: - Quét token: khoá trùng, dấu phẩy thừa

    /// Kết quả quét `exam.json` thô.
    struct ScanReport: Equatable {
        /// Đường dẫn mọi khoá xuất hiện từ hai lần trở lên trong cùng một object, theo thứ
        /// tự lần lặp đầu tiên trong file; mỗi khoá của một object chỉ báo một lần.
        var duplicateKeys: [String] = []
        /// Đường dẫn object/mảng có dấu phẩy ngay trước dấu đóng (`{"a": 1,}`, `["B",]`),
        /// theo thứ tự dấu đóng trong file; gốc là `<gốc>`.
        var trailingCommas: [String] = []
    }

    /// Quét token trên dữ liệu thô, tìm những điều `JSONSerialization` (macOS và Linux)
    /// chấp nhận mà JSON chuẩn, schema và Python từ chối hoặc hiểu khác:
    ///
    /// - Khoá trùng: Foundation gộp (trên macOS giữ giá trị đầu), Python giữ giá trị cuối,
    ///   nên hai bên có thể đọc ra hai đề khác nhau. Khoá được so sau khi giải mã escape:
    ///   `"a"` và `"\u0061"` là trùng.
    /// - Dấu phẩy thừa trước `}` hoặc `]`: Foundation (cả `JSONDecoder`) nhận, JSON chuẩn
    ///   không cho.
    ///
    /// Giả định `data` đã qua `JSONSerialization`. Gặp dữ liệu sai cấu trúc thì dừng và
    /// trả những gì đã thấy, không crash.
    static func scan(_ data: Data) -> ScanReport {
        var scanner = Scanner(bytes: [UInt8](data))
        return scanner.run()
    }

    /// `scan(data).duplicateKeys`.
    static func duplicateKeyPaths(in data: Data) -> [String] { scan(data).duplicateKeys }

    /// Tên hiển thị của gốc trong đường dẫn (cùng cách `ExamPackageReader.describe`).
    static let rootName = JSONProblem.rootPath

    private struct Scanner {
        let bytes: [UInt8]
        var position = 0
        var report = ScanReport()
        /// Byte có nghĩa cuối cùng ngoài chuỗi (chuỗi tính là `"`), bỏ qua khoảng trắng.
        var lastSignificant: UInt8?

        enum Frame {
            case object(path: String, keys: Set<String>, reported: Set<String>, currentKey: String?, expectingKey: Bool)
            case array(path: String, index: Int)

            var path: String {
                switch self {
                case let .object(path, _, _, _, _), let .array(path, _): path
                }
            }
        }

        var stack: [Frame] = []

        init(bytes: [UInt8]) { self.bytes = bytes }

        mutating func run() -> ScanReport {
            while position < bytes.count {
                let byte = bytes[position]
                switch byte {
                case UInt8(ascii: "{"):
                    stack.append(.object(path: childPath(), keys: [], reported: [], currentKey: nil, expectingKey: true))
                case UInt8(ascii: "["):
                    stack.append(.array(path: childPath(), index: 0))
                case UInt8(ascii: "}"), UInt8(ascii: "]"):
                    if let closed = stack.popLast(), lastSignificant == UInt8(ascii: ",") {
                        report.trailingCommas.append(closed.path.isEmpty ? StrictJSON.rootName : closed.path)
                    }
                case UInt8(ascii: ","):
                    if let top = stack.popLast() {
                        switch top {
                        case let .object(path, keys, reported, _, _):
                            stack.append(.object(path: path, keys: keys, reported: reported, currentKey: nil, expectingKey: true))
                        case let .array(path, index):
                            stack.append(.array(path: path, index: index + 1))
                        }
                    }
                case UInt8(ascii: "\""):
                    position += 1
                    guard let string = readString() else { return report }
                    lastSignificant = byte
                    if case .object(let path, var keys, var reported, _, true)? = stack.last {
                        stack.removeLast()
                        if !keys.insert(string).inserted, reported.insert(string).inserted {
                            report.duplicateKeys.append(StrictJSON.join(path, key: string))
                        }
                        stack.append(.object(path: path, keys: keys, reported: reported, currentKey: string, expectingKey: false))
                    }
                    continue
                default:
                    // ':', số, true/false/null: không ảnh hưởng tới khoá hay dấu phẩy.
                    break
                }
                // Khoảng trắng JSON: space, tab, LF, CR.
                if ![0x20, 0x09, 0x0A, 0x0D].contains(byte) { lastSignificant = byte }
                position += 1
            }
            return report
        }

        /// Đường dẫn của giá trị sắp mở ở đỉnh ngăn xếp.
        func childPath() -> String {
            switch stack.last {
            case nil:
                return ""
            case let .object(path, _, _, currentKey, _)?:
                return StrictJSON.join(path, key: currentKey ?? "")
            case let .array(path, index)?:
                return "\(path)[\(index)]"
            }
        }

        /// Đọc một chuỗi JSON (đã qua dấu `"` mở), giải mã escape. `nil` nếu dữ liệu
        /// kết thúc giữa chừng hoặc escape sai.
        mutating func readString() -> String? {
            var units: [UInt16] = []
            var runStart = position
            func flushRun(_ end: Int) {
                if end > runStart {
                    units.append(contentsOf: String(decoding: bytes[runStart ..< end], as: UTF8.self).utf16)
                }
            }
            while position < bytes.count {
                let byte = bytes[position]
                if byte == UInt8(ascii: "\"") {
                    flushRun(position)
                    position += 1
                    return String(decoding: units, as: UTF16.self)
                }
                guard byte == UInt8(ascii: "\\") else {
                    position += 1
                    continue
                }
                flushRun(position)
                guard position + 1 < bytes.count else { return nil }
                let escaped = bytes[position + 1]
                position += 2
                switch escaped {
                case UInt8(ascii: "\""): units.append(0x22)
                case UInt8(ascii: "\\"): units.append(0x5C)
                case UInt8(ascii: "/"): units.append(0x2F)
                case UInt8(ascii: "b"): units.append(0x08)
                case UInt8(ascii: "f"): units.append(0x0C)
                case UInt8(ascii: "n"): units.append(0x0A)
                case UInt8(ascii: "r"): units.append(0x0D)
                case UInt8(ascii: "t"): units.append(0x09)
                case UInt8(ascii: "u"):
                    // Cặp surrogate là hai escape \uXXXX liền nhau; ghép mã UTF-16 rồi giải
                    // mã cả chuỗi một lần nên cặp được ghép đúng.
                    guard position + 4 <= bytes.count,
                          let hex = String(bytes: bytes[position ..< position + 4], encoding: .ascii),
                          let unit = UInt16(hex, radix: 16)
                    else { return nil }
                    units.append(unit)
                    position += 4
                default:
                    return nil
                }
                runStart = position
            }
            return nil
        }
    }

    // MARK: - null

    /// Đường dẫn mọi giá trị `null` trong JSON đã phân tích, theo thứ tự cấu trúc;
    /// trong cùng một object xếp theo tên khoá (như `unknownFieldPaths`).
    /// Schema không cho `null` ở đâu cả; model coi `null` ở trường tuỳ chọn như vắng mặt.
    static func nullValuePaths(in exam: [String: Any]) -> [String] {
        // Duyệt bằng ngăn xếp tường minh, không đệ quy: không phụ thuộc độ sâu của stack.
        var paths: [String] = []
        var pending: [(value: Any, path: String)] = [(exam, "")]
        while let (value, path) = pending.popLast() {
            // Thử object và mảng trước `is NSNull`: trên Linux, ép một mảng sang lớp NSNull
            // làm runtime bắc cầu cả cây sang NSArray, đệ quy theo độ sâu.
            if let object = value as? [String: Any] {
                // Đẩy ngược để lấy ra theo thứ tự tên khoá tăng dần.
                for key in object.keys.sorted().reversed() {
                    pending.append((object[key]!, join(path, key: key)))
                }
            } else if let array = value as? [Any] {
                for (index, element) in array.enumerated().reversed() {
                    pending.append((element, "\(path)[\(index)]"))
                }
            } else if value is NSNull {
                paths.append(path)
            }
        }
        return paths
    }

    // MARK: - Độ sâu

    /// `true` nếu `data` có chỗ lồng object/mảng sâu hơn `limit` cấp (gốc là cấp 1).
    /// Quét byte bằng vòng lặp, bỏ qua `{`/`[` nằm trong chuỗi (kể cả sau `\"`), dừng ngay
    /// khi vượt trần. Chạy trên dữ liệu chưa kiểm cú pháp; dữ liệu sai thì kết luận theo
    /// những gì đã thấy, việc báo lỗi cú pháp để `JSONSerialization` làm.
    static func depthExceeds(_ data: Data, limit: Int) -> Bool {
        var depth = 0
        var inString = false
        var escaped = false
        for byte in data {
            if inString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
                if depth > limit { return true }
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth = max(0, depth - 1)
            default:
                break
            }
        }
        return false
    }

    static func join(_ prefix: String, key: String) -> String {
        prefix.isEmpty ? key : "\(prefix).\(key)"
    }
}
