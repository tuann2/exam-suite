@testable import ExamImport
import Foundation

/// Bản rút gọn của `VceTestWriter` (ExamImportTests, không dùng chung được giữa hai target test): dựng file `.vce` tự
/// tạo theo bố cục ghi ở `VceImporter` với một phần, một nhóm và các câu chỉ có văn bản, để test luồng Import đề… với
/// `.vce` (ADR 0009: không dùng file thật).
struct MiniVceWriter {
    struct Question {
        var text: String
        var options: [String]
        var answer: String
    }

    var code = "MINI-VCE"
    var title = "De VCE tu soan"
    var passingScore: Int32 = 700
    var timeLimit: Int32 = 45
    var questions: [Question] = []

    func data() -> Data {
        var out: [UInt8] = [0x85, 0xA8, 0x02, 0x01, 0]
        out += Self.xstr(code)
        out += Self.xstr(title)
        out += Self.i32(passingScore)
        out += Self.i32(timeLimit)
        out += Self.xstr("1.0")
        out += [UInt8](repeating: 0, count: 38)
        out += Self.blob(VceMask.unmask([UInt8](repeating: 0, count: 8)))
        out += Self.blob(VceMask.unmask(Self.rvf([""])))
        out += Self.i32(1) + Self.i32(1) + Self.xstr("Part 1")
        out += Self.i32(1) + [0] + Self.i32(0)
        out += Self.i32(Int32(questions.count))
        for question in questions {
            let record = Self.record(question)
            out += Self.i32(Int32(record.count)) + record
        }
        out += [UInt8](repeating: 0, count: 12)
        let n = out.count
        out.replaceSubrange(n - 12 ..< n - 8, with: Self.i32(Int32(n)))
        out.replaceSubrange(n - 4 ..< n, with: Self.u32(VceCRC32.checksum(out[0 ..< n - 8])))
        return Data(out)
    }

    private static func record(_ q: Question) -> [UInt8] {
        var out: [UInt8] = [q.answer.count >= 2 ? 1 : 0]
        out += i32(1) + i32(5) + i32(0)
        var content: [UInt8] = []
        for block in [q.text] + q.options + [""] {
            let rvf = rvf([block])
            content += i32(Int32(rvf.count)) + rvf
        }
        out += blob(VceMask.unmask(content))
        out += blob(VceMask.unmask(Array(q.answer.utf8)))
        out += i32(Int32(q.options.count))
        out += [1, 0, 0]
        out += xstr("Tinh huong")
        return out
    }

    /// Khối RVF: phiên bản, thuộc tính tài liệu, một mục văn bản Unicode (UTF-16LE, mỗi đoạn kết thúc U+2029).
    private static func rvf(_ paragraphs: [String]) -> [UInt8] {
        var out = Array("-8 1 3 1\r\n-9 0 0 0 0 0 7\r\n0 \(paragraphs.count) 0 8 0 0\r\n".utf8)
        for p in paragraphs {
            for unit in p.utf16 { out += [UInt8(unit & 0xFF), UInt8(unit >> 8)] }
            out += [0x29, 0x20]
        }
        return out
    }

    private static func i32(_ value: Int32) -> [UInt8] { u32(UInt32(bitPattern: value)) }

    private static func u32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)]
    }

    private static func blob(_ bytes: [UInt8]) -> [UInt8] { i32(Int32(bytes.count)) + bytes }

    private static func xstr(_ s: String) -> [UInt8] {
        guard !s.isEmpty else { return i32(0) }
        let raw = s.unicodeScalars.map { MojibakeRepair.byte(for: $0) ?? 0x3F }
        return blob([0xFF, 0xFF] + VceMask.unmask(raw))
    }
}
