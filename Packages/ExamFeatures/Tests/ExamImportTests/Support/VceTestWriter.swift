@testable import ExamImport
import Foundation

/// Dựng file `.vce` tự tạo trong test (ADR 0009 điều kiện 4: không dùng file thật), theo bố cục ghi ở `VceImporter`:
/// đầu đề, bảng phần, nhóm, bản ghi câu, phép che (`VceMask`), khối RVF (đặc tả RVF công khai, biến thể UTF-16LE +
/// U+2029), kích thước file và CRC-32.
struct VceTestWriter {
    /// Một khối nội dung (đề bài, lựa chọn, giải thích).
    enum Block {
        /// Văn bản Unicode thường: `-8`, `-9`, một mục văn bản kiểu chữ 0 với mỗi đoạn kết thúc U+2029.
        case paragraphs([String])
        /// Byte RVF tự dựng (ảnh, ANSI, kiểu chữ khác…).
        case raw([UInt8])
    }

    struct Question {
        var text: Block
        var options: [Block]
        var explanation: Block = .paragraphs([""])
        var answer: String
        var sectionID: Int32 = 1
        var type: Int32 = 5
        /// `nil` = theo số chữ của đáp án (như các file mẫu: 1 khi có ≥ 2 chữ).
        var multiFlag: UInt8?
        /// `nil` = số khối lựa chọn.
        var optionCount: Int32?
        /// Byte thêm vào cuối bản ghi câu (bố cục lạ).
        var extraBytes: [UInt8] = []

        init(_ text: String, options: [String], answer: String, explanation: [String] = [""], sectionID: Int32 = 1) {
            self.text = .paragraphs([text])
            self.options = options.map { .paragraphs([$0]) }
            self.answer = answer
            self.explanation = .paragraphs(explanation)
            self.sectionID = sectionID
        }

        init(text: Block, options: [Block], explanation: Block = .paragraphs([""]), answer: String) {
            self.text = text
            self.options = options
            self.explanation = explanation
            self.answer = answer
        }
    }

    var code = "ON-VCE"
    var title = "De on tap VCE"
    var passingScore: Int32 = 800
    var timeLimit: Int32 = 120
    var sections: [(id: Int32, name: String)] = [(1, "Part 1")]
    /// `nil` = không có nhóm nào (số nhóm 0); các file mẫu có đúng một nhóm.
    var groups: [String] = [""]
    var questions: [Question] = []
    /// Byte đầu file (mặc định magic của file mẫu).
    var magic: [UInt8] = [0x85, 0xA8, 0x02, 0x01]

    // MARK: Ghi

    func bytes() -> [UInt8] {
        var out = magic
        out.append(0)
        out += Self.xstr(code)
        out += Self.xstr(title)
        out += Self.i32(passingScore)
        out += Self.i32(timeLimit)
        out += Self.xstr("1.0")
        out += [UInt8](repeating: 0, count: 32)
        out += [UInt8](repeating: 0, count: 6)
        out += Self.blob(VceMask.unmask([UInt8](repeating: 0, count: 8)))
        out += Self.blob(VceMask.unmask(Self.rvf([""])))
        out += Self.i32(Int32(sections.count))
        for section in sections {
            out += Self.i32(section.id)
            out += Self.xstr(section.name)
        }
        out += Self.i32(Int32(groups.count))
        for group in groups {
            out.append(0)
            out += Self.xstr(group)
        }
        out += Self.i32(Int32(questions.count))
        for question in questions {
            let record = Self.record(question)
            out += Self.i32(Int32(record.count))
            out += record
        }
        return Self.sealed(out + [UInt8](repeating: 0, count: 12))
    }

    func data() -> Data { Data(bytes()) }

    /// Ghi lại kích thước file và CRC-32 (8 byte cuối được tính lại; 12 byte cuối là phần đuôi).
    static func sealed(_ bytes: [UInt8]) -> [UInt8] {
        var out = bytes
        let n = out.count
        out.replaceSubrange(n - 12 ..< n - 8, with: i32(Int32(n)))
        let crc = VceCRC32.checksum(out[0 ..< n - 8])
        out.replaceSubrange(n - 4 ..< n, with: u32(crc))
        return out
    }

    static func record(_ q: Question) -> [UInt8] {
        let letters = q.answer.filter(\.isLetter).count
        var out: [UInt8] = [q.multiFlag ?? (letters >= 2 ? 1 : 0)]
        out += i32(q.sectionID)
        out += i32(q.type)
        out += i32(0)
        var content: [UInt8] = []
        for block in [q.text] + q.options + [q.explanation] {
            let rvf = rvf(block)
            content += i32(Int32(rvf.count))
            content += rvf
        }
        out += blob(VceMask.unmask(content))
        out += blob(VceMask.unmask(Array(q.answer.utf8)))
        out += i32(q.optionCount ?? Int32(q.options.count))
        out += [1, 0, 0]
        out += xstr("Tinh huong")
        out += q.extraBytes
        return out
    }

    // MARK: RVF

    static func rvf(_ block: Block) -> [UInt8] {
        switch block {
        case let .paragraphs(paragraphs): rvf(paragraphs)
        case let .raw(bytes): bytes
        }
    }

    static let version = Array("-8 1 3 1\r\n".utf8)
    static let docParameters = Array("-9 0 0 0 0 0 7\r\n".utf8)

    /// Khối như file mẫu: phiên bản, thuộc tính tài liệu, một mục văn bản Unicode `N` đoạn.
    static func rvf(_ paragraphs: [String]) -> [UInt8] {
        version + docParameters + unicodeText(paragraphs)
    }

    /// Mục văn bản Unicode: `<kiểu chữ> N <đoạn> <tuỳ chọn> <query> 0` + mỗi đoạn UTF-16LE kết thúc U+2029.
    static func unicodeText(_ paragraphs: [String], style: Int = 0, paragraph: Int = 0, options: Int = 8,
                            query: Int = 0) -> [UInt8]
    {
        var out = Array("\(style) \(paragraphs.count) \(paragraph) \(options) \(query) 0\r\n".utf8)
        for p in paragraphs {
            for unit in p.utf16 {
                out += [UInt8(unit & 0xFF), UInt8(unit >> 8)]
            }
            out += [0x29, 0x20]
        }
        return out
    }

    /// Mục văn bản ANSI (tuỳ chọn không có bit 3): mỗi dòng Windows-1252 kết thúc CR LF (đặc tả RVF).
    static func ansiText(_ lines: [[UInt8]]) -> [UInt8] {
        var out = Array("0 \(lines.count) 0 0 0 0\r\n".utf8)
        for line in lines { out += line + [0x0D, 0x0A] }
        return out
    }

    /// Ảnh lưu dạng hex (query 0): tên, lớp, dữ liệu hex mỗi thứ một dòng (đặc tả RVF).
    static func hexPicture() -> [UInt8] {
        Array("-3 3 0 0 0 0 0\r\nanh\r\nTPNGImage\r\n89504E470D0A1A0A\r\n".utf8)
    }

    /// Ảnh lưu nhị phân (query 2): tên, lớp, rồi `i32` độ dài + byte (đặc tả RVF).
    static func binaryPicture(_ payload: [UInt8]) -> [UInt8] {
        Array("-3 3 0 0 2 0 0\r\nanh\r\nTJPEGImage\r\n".utf8) + i32(Int32(payload.count)) + payload
    }

    // MARK: Nguyên tố

    static func i32(_ value: Int32) -> [UInt8] {
        u32(UInt32(bitPattern: value))
    }

    static func u32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)]
    }

    static func blob(_ bytes: [UInt8]) -> [UInt8] {
        i32(Int32(bytes.count)) + bytes
    }

    /// `xstr`: rỗng → độ dài 0 (như tên nhóm của file mẫu); không thì `FF FF` + chuỗi Windows-1252 đã che.
    static func xstr(_ s: String) -> [UInt8] {
        guard !s.isEmpty else { return i32(0) }
        let raw = s.unicodeScalars.map { MojibakeRepair.byte(for: $0) ?? 0x3F }
        return blob([0xFF, 0xFF] + VceMask.unmask(raw))
    }
}

/// Bộ sinh số giả ngẫu nhiên cố định hạt giống (SplitMix64), để test đột biến lặp lại được.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
