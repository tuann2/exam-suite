@testable import ExamImport
import Foundation
import Testing

/// Quy tắc mojibake (import.md, phương án 10, thu hẹp sau review PR #32) trên chuỗi tự soạn.
@Suite("Lỗi mã hoá (mojibake)")
struct MojibakeRepairTests {
    @Test("Tự sửa dãy chắc chắn: â + (€ | U+0081 | ‚) + một ký tự, ra U+2000–U+20CF", arguments: [
        ("â€™", "’"), ("â€˜", "‘"), ("â€œ", "“"), ("â€\u{9D}", "”"), ("â€“", "–"), ("â€”", "—"), ("â€¦", "…"),
        ("â‚¬", "€"), ("â‚«", "₫"), ("â\u{81}°", "⁰"),
    ])
    func repairs(input: String, expected: String) {
        let result = MojibakeRepair.repair(input)
        #expect(result.text == expected)
        #expect(result.findings.fixed == [MojibakeRepair.Fix(before: input, after: expected)])
        #expect(result.findings.suspected.isEmpty)
    }

    @Test("Dãy khác chỉ cảnh báo, giữ nguyên chữ (gồm các ví dụ của review PR #32)", arguments: [
        ("Trả lời “CÓ” nếu đúng", "Ó”"), ("“LÊ”", "Ê”"), ("KHÔ\u{A0}RÁO", "Ô\u{A0}"), ("NESCAFÉ®", "É®"),
        ("CAFÉ™", "É™"), ("5×\u{A0}3", "×\u{A0}"), ("“ĐÃ”", "Ã”"), ("cafÃ©", "Ã©"), ("Â\u{A0}", "Â\u{A0}"),
        ("Â©", "Â©"), ("Æ°", "Æ°"), ("áº¿", "áº¿"), ("â„¢", "â„¢"), ("ðŸ˜€", "ðŸ˜€"),
    ])
    func suspectedOnly(input: String, sequence: String) {
        let result = MojibakeRepair.repair(input)
        #expect(result.text == input)
        #expect(result.findings.fixed.isEmpty)
        #expect(result.findings.suspected.map(\.before) == [sequence])
    }

    @Test("Dãy chắc chắn nhưng ra ký tự vô hình (U+200B, U+2028, U+202E…) chỉ cảnh báo, giữ nguyên", arguments: [
        ("â€‹", "\u{200B}"), ("â€Ž", "\u{200E}"), ("â€¨", "\u{2028}"), ("â€®", "\u{202E}"), ("â\u{81}\u{A0}", "\u{2060}"),
        ("â\u{81}¯", "\u{206F}"),
    ])
    func invisibleNotFixed(input: String, decoded: String) {
        let result = MojibakeRepair.repair("a" + input + "b")
        #expect(result.text == "a" + input + "b")
        #expect(result.findings.fixed.isEmpty)
        #expect(result.findings.suspected == [MojibakeRepair.Fix(before: input, after: decoded)])
        // Ký tự hiện được ngay cạnh vùng vô hình vẫn được sửa.
        #expect(MojibakeRepair.repair("â€™" + input).text == "’" + input)
    }

    @Test("Chữ hợp lệ không bị sửa, không bị cảnh báo", arguments: [
        "â", "Ã", "Tiếng Việt có dấu: ầ ẩ ẫ ậ, Ă, Đ, ơ, ư", "â là chữ, Ã cũng vậy", "Ã đứng trước dấu cách",
        "café, naïve, Œuvre", "Giá 100€ — “trích dẫn”", "plain ASCII text", "",
        "â€", "â€x", // dãy chưa trọn (thiếu byte nối)
        "À€", // C0 80: byte đầu C0 không hợp lệ trong UTF-8
        "í\u{A0}\u{80}", // ED A0 80 là surrogate, không phải ký tự hợp lệ
        "à€€", // E0 80 80 là dạng quá dài
    ])
    func noFalsePositive(input: String) {
        let result = MojibakeRepair.repair(input)
        #expect(result.text == input)
        #expect(result.findings.isEmpty)
    }

    @Test("Nhiều chỗ trong câu: sửa dãy chắc chắn, giữ dãy chỉ nghi")
    func multiple() {
        let result = MojibakeRepair.repair("Itâ€™s Ã\u{A0} cafÃ© â€œokâ€\u{9D} â nhé")
        #expect(result.text == "It’s Ã\u{A0} cafÃ© “ok” â nhé")
        #expect(result.findings.fixed.count == 3)
        #expect(result.findings.suspected.map(\.before) == ["Ã\u{A0}", "Ã©"])
        #expect(ImportIssueDetail.mojibakeFixed(MojibakeRepair.summary(result.findings.fixed)).logMessage.contains("3 chỗ"))
        #expect(ImportIssueDetail.mojibakeSuspected(MojibakeRepair.summary(result.findings.suspected)).logMessage
            .contains("\"Ã©\" (có thể là \"é\")"))
    }

    @Test("Bảng Windows-1252: 0x80–0x9F và năm byte chưa định nghĩa")
    func table() {
        #expect(MojibakeRepair.byte(for: "€") == 0x80)
        #expect(MojibakeRepair.byte(for: "Ÿ") == 0x9F)
        for value: UInt32 in [0x81, 0x8D, 0x8F, 0x90, 0x9D] {
            #expect(MojibakeRepair.byte(for: Unicode.Scalar(value)!) == UInt8(value))
        }
        #expect(MojibakeRepair.byte(for: "\u{80}") == nil)
        #expect(MojibakeRepair.byte(for: "ă") == nil)
    }
}
