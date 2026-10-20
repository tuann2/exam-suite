import ExamKit
import Foundation

/// Dấu vân tay của câu hỏi: SHA-256 (hex chữ thường) của **dạng chuẩn** của câu. Lưu trong
/// lần thi (`AttemptRecord.fingerprints`) để Xem lại bài biết câu nào đã sửa sau lần thi
/// (docs/product/exam-taking.md, mục "Lịch sử thi" và "Dữ liệu một lần thi").
///
/// ## Dạng chuẩn (phiên bản 1)
///
/// Một object JSON viết liền, không khoảng trắng, mã hoá UTF-8, khoá sắp xếp:
///
/// ```text
/// {"correct":["A","C"],"explanation":"…"|null,"image":"media/….png"|null,
///  "options":[{"id":"A","text":"…"},…],"text":"…","type":"single"|"multiple"}
/// ```
///
/// - `correct`: tập đáp án đúng, đã sắp xếp, bỏ trùng (thứ tự trong file không đổi nghĩa câu).
/// - `options`: theo thứ tự trong file (thứ tự gốc là một phần của câu).
/// - `explanation`, `image`: `null` khi không có (khác chuỗi rỗng).
/// - Không gồm id câu (dấu vân tay đã gắn với id) và section.
/// - Mọi chuỗi chuẩn hoá Unicode NFC trước khi ghi.
/// - Chuỗi JSON chỉ escape `"`, `\`, và ký tự điều khiển U+0000–U+001F (`\b \f \n \r \t`
///   dạng ngắn, còn lại `\u00xx` hex chữ thường); mọi ký tự khác ghi nguyên UTF-8.
///
/// Dạng này trùng với `json.dumps(obj, ensure_ascii=False, separators=(",", ":"), sort_keys=True)`
/// của Python trên các chuỗi đã NFC, nên đối chiếu được ngoài app. Tự tuần tự hoá thay vì dùng
/// `JSONEncoder` vì cách in (thứ tự khoá, escape `/`, số) của `JSONEncoder` không được cam kết
/// giống nhau giữa macOS và Linux hay giữa các phiên bản Foundation.
///
/// Đổi dạng chuẩn làm mọi lần thi cũ báo "đã sửa": phải coi là thay đổi rủi ro cao, tăng
/// `AttemptRecord.currentPayloadVersion` và giữ cách tính cũ cho payload cũ. Test khoá giá trị
/// cố định ở `QuestionFingerprintTests`.
public enum QuestionFingerprint {
    /// SHA-256 hex (64 ký tự chữ thường) của dạng chuẩn của câu.
    public static func fingerprint(of question: Question) -> String {
        SHA256.hexDigest(Data(canonicalJSON(of: question).utf8))
    }

    /// Dấu vân tay của mọi câu trong đề theo id câu. Id câu trùng (đề sai) thì lấy lần xuất hiện
    /// đầu, như `Exam.question(id:)` và `Scorer`.
    public static func fingerprints(of exam: Exam) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for question in exam.allQuestions where result[question.id] == nil {
            result[question.id] = fingerprint(of: question)
        }
        return result
    }

    /// Dạng chuẩn (xem tài liệu của kiểu). Khoá viết sẵn theo thứ tự đã sắp xếp.
    static func canonicalJSON(of question: Question) -> String {
        var out = "{"
        out += "\"correct\":["
        out += Set(question.correct).sorted().map { string($0.description) }.joined(separator: ",")
        out += "],\"explanation\":" + (question.explanation.map(string) ?? "null")
        out += ",\"image\":" + (question.image.map(string) ?? "null")
        out += ",\"options\":["
        out += question.options.map { "{\"id\":" + string($0.id.description) + ",\"text\":" + string($0.text) + "}" }
            .joined(separator: ",")
        out += "],\"text\":" + string(question.text)
        out += ",\"type\":" + string(question.type.rawValue)
        out += "}"
        return out
    }

    /// Chuỗi JSON của `value` sau khi chuẩn hoá NFC.
    private static func string(_ value: String) -> String {
        let hex = Array("0123456789abcdef")
        var out = "\""
        for scalar in value.precomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{00}" ... "\u{1F}":
                let v = Int(scalar.value)
                out += "\\u00" + String(hex[v >> 4]) + String(hex[v & 0xF])
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }
}
