import Foundation

/// Lỗi mã hoá trong file gốc (mojibake), docs/product/import.md mục Luồng và phương án 10 (Nt0 chốt 2026-10-16, thu
/// hẹp cùng ngày sau review PR #32): văn bản UTF-8 từng bị đọc nhầm thành Windows-1252, ví dụ `’` (E2 80 99) hiện
/// thành `â€™`.
///
/// Cách đọc: coi mỗi ký tự là một byte Windows-1252 (các byte chưa định nghĩa 0x81, 0x8D, 0x8F, 0x90, 0x9D ứng với
/// U+0081, U+008D, U+008F, U+0090, U+009D); một dãy ký tự khớp trọn vẹn thành **đúng một ký tự UTF-8 nhiều byte hợp
/// lệ** là dãy nghi lỗi.
/// - **Tự sửa** chỉ dãy chắc chắn là lỗi: 3 ký tự, bắt đầu bằng `â` (0xE2), ký tự thứ hai là `€`, U+0081 hoặc `‚`
///   (byte 0x80–0x82), giải ra một ký tự trong U+2000–U+20CF (dấu câu chung, tiền tệ: ‘ ’ “ ” – — … € ₫), **trừ** ký
///   tự định dạng/phân cách vô hình U+200B–U+200F, U+2028–U+202E, U+2060–U+206F (chỉ cảnh báo).
/// - Mọi dãy nghi lỗi khác (`Ã©`, `Â` + NBSP, `Ó` + `”`…) **chỉ cảnh báo**, giữ nguyên chữ: chữ hoa tiếng Việt đứng sát
///   `”`, `®`, NBSP… cũng khớp cách đọc trên (review PR #32).
///
/// Dùng chung cho mọi định dạng import (txt, docx, và bộ đọc vce ở bước 6).
enum MojibakeRepair {
    /// Một dãy: chuỗi gốc và ký tự giải ra.
    struct Fix: Equatable, Hashable, Sendable {
        var before: String
        var after: String
    }

    /// Các dãy đã sửa và các dãy chỉ cảnh báo.
    struct Findings: Equatable, Sendable {
        var fixed: [Fix] = []
        var suspected: [Fix] = []

        var isEmpty: Bool { fixed.isEmpty && suspected.isEmpty }

        static func += (lhs: inout Findings, rhs: Findings) {
            lhs.fixed += rhs.fixed
            lhs.suspected += rhs.suspected
        }
    }

    /// Chuỗi sau khi sửa các dãy chắc chắn là lỗi, cùng các dãy đã sửa và dãy chỉ cảnh báo (theo thứ tự).
    static func repair(_ text: String) -> (text: String, findings: Findings) {
        let scalars = Array(text.unicodeScalars)
        // Không có ký tự nào có thể là byte đầu của UTF-8 nhiều byte (0xC2–0xF4) thì không cần quét.
        guard scalars.contains(where: { (0xC2 ... 0xF4).contains($0.value) }) else { return (text, Findings()) }

        var out = String.UnicodeScalarView()
        var findings = Findings()
        var index = 0
        while index < scalars.count {
            guard let (scalar, length) = decode(scalars, at: index) else {
                out.append(scalars[index])
                index += 1
                continue
            }
            let source = scalars[index ..< index + length]
            let fix = Fix(before: String(String.UnicodeScalarView(source)), after: String(Character(scalar)))
            if isCertain(source, decoded: scalar) {
                findings.fixed.append(fix)
                out.append(scalar)
            } else {
                findings.suspected.append(fix)
                out.append(contentsOf: source)
            }
            index += length
        }
        return findings.fixed.isEmpty ? (text, findings) : (String(out), findings)
    }

    /// `â` + (`€` | U+0081 | `‚`) + một ký tự, giải ra U+2000–U+20CF, trừ ký tự định dạng/phân cách vô hình.
    private static func isCertain(_ source: ArraySlice<Unicode.Scalar>, decoded: Unicode.Scalar) -> Bool {
        guard source.count == 3, let second = byte(for: source[source.startIndex + 1]) else { return false }
        return source.first?.value == 0xE2 && (0x80 ... 0x82).contains(second)
            && (0x2000 ... 0x20CF).contains(decoded.value)
            && !invisibleFormatCharacters.contains(where: { $0.contains(decoded.value) })
    }

    /// Ký tự định dạng/phân cách vô hình (zero-width, LRM/RLM, U+2028/U+2029, điều khiển hướng chữ, U+2060–U+206F):
    /// không tự sửa thành chúng, chỉ cảnh báo, vì người soạn đề không nhìn thấy (Nt0 chốt 2026-10-16, re-review
    /// PR #32).
    static let invisibleFormatCharacters: [ClosedRange<UInt32>] = [0x200B ... 0x200F, 0x2028 ... 0x202E, 0x2060 ... 0x206F]

    /// Ký tự UTF-8 nhiều byte bắt đầu tại `index`, và số ký tự nguồn đã dùng; `nil` nếu không khớp trọn vẹn.
    private static func decode(_ scalars: [Unicode.Scalar], at index: Int) -> (Unicode.Scalar, Int)? {
        guard let lead = byte(for: scalars[index]) else { return nil }
        let length: Int
        switch lead {
        case 0xC2 ... 0xDF: length = 2
        case 0xE0 ... 0xEF: length = 3
        case 0xF0 ... 0xF4: length = 4
        default: return nil
        }
        guard index + length <= scalars.count else { return nil }
        var bytes = [lead]
        for offset in 1 ..< length {
            guard let next = byte(for: scalars[index + offset]), (0x80 ... 0xBF).contains(next) else { return nil }
            bytes.append(next)
        }
        // Bộ giải mã chuẩn loại dạng quá dài (E0 80 …), surrogate (ED A0 …), vượt U+10FFFF.
        guard let decoded = String(bytes: bytes, encoding: .utf8) else { return nil }
        let result = Array(decoded.unicodeScalars)
        guard result.count == 1 else { return nil }
        return (result[0], length)
    }

    /// Byte Windows-1252 của một ký tự; `nil` nếu ký tự không có trong bảng.
    static func byte(for scalar: Unicode.Scalar) -> UInt8? {
        let value = scalar.value
        if value < 0x80 || (0xA0 ... 0xFF).contains(value) { return UInt8(value) }
        return windows1252High[value]
    }

    /// Ký tự của một byte Windows-1252 (chiều ngược của `byte(for:)`), dùng giải chuỗi 1 byte/ký tự của `.vce`.
    static func scalar(forWindows1252 byte: UInt8) -> Unicode.Scalar {
        if byte < 0x80 || byte >= 0xA0 { return Unicode.Scalar(byte) }
        return windows1252Decode[Int(byte - 0x80)]
    }

    private static let windows1252Decode: [Unicode.Scalar] = (0x80 ... 0x9F).map { byte in
        let value = windows1252High.first { $0.value == UInt8(byte) }?.key ?? UInt32(byte)
        return Unicode.Scalar(value) ?? Unicode.Scalar(UInt8(byte))
    }

    /// 0x80–0x9F của Windows-1252, kể cả năm byte chưa định nghĩa (ứng với chính mã C1 cùng giá trị).
    private static let windows1252High: [UInt32: UInt8] = [
        0x20AC: 0x80, 0x0081: 0x81, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86,
        0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x008D: 0x8D,
        0x017D: 0x8E, 0x008F: 0x8F, 0x0090: 0x90, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94,
        0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
        0x0153: 0x9C, 0x009D: 0x9D, 0x017E: 0x9E, 0x0178: 0x9F,
    ]

    /// Tóm tắt cho cảnh báo `mojibakeFixed`/`mojibakeSuspected`: số chỗ, các cặp trước → sau đã gộp (tối đa 10).
    static func summary(_ fixes: [Fix]) -> MojibakeSummary {
        var order: [Fix] = []
        var counts: [Fix: Int] = [:]
        for fix in fixes {
            if counts[fix] == nil { order.append(fix) }
            counts[fix, default: 0] += 1
        }
        let pairs = order.prefix(10).map { fix in
            MojibakeSummary.Pair(before: fix.before, after: fix.after, count: counts[fix] ?? 1)
        }
        return MojibakeSummary(total: fixes.count, pairs: Array(pairs), moreKinds: max(order.count - 10, 0))
    }
}
