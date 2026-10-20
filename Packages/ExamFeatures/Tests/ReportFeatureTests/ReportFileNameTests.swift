import Foundation
@testable import ReportFeature
import Testing

/// Tên file gợi ý (docs/product/export-print.md, mục Tên file và hộp lưu, phương án 10).
@Suite("Tên file PDF gợi ý")
struct ReportFileNameTests {
    let utc = TimeZone(identifier: "UTC")!
    // 2026-10-16 14:05:00 UTC
    let submittedAt = Date(timeIntervalSince1970: 1_792_159_500)

    @Test("Kết quả: <Tên đề> - <Thí sinh> - <yyyy-MM-dd HHmm>.pdf theo múi giờ")
    func resultsName() {
        #expect(ReportFileName.results(examTitle: "Kiến thức chung", candidateName: "Nguyễn Văn Đức", submittedAt: submittedAt, timeZone: utc)
            == "Kiến thức chung - Nguyễn Văn Đức - 2026-10-16 1405.pdf")
        let hanoi = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        #expect(ReportFileName.results(examTitle: "Đề", candidateName: "An", submittedAt: submittedAt, timeZone: hanoi)
            == "Đề - An - 2026-10-16 2105.pdf")
    }

    @Test("Bỏ / và :, gộp khoảng trắng và ký tự điều khiển, bỏ khoảng trắng hai đầu")
    func forbiddenCharacters() {
        #expect(ReportFileName.results(examTitle: "  Mạng: TCP/IP\t\ncơ   bản ", candidateName: "An\u{0007}", submittedAt: submittedAt, timeZone: utc)
            == "Mạng TCPIP cơ bản - An - 2026-10-16 1405.pdf")
        #expect(ReportFileName.clean("a\u{00A0}\u{2003}b") == "a b")
    }

    @Test("Chuẩn hoá NFC: chữ tổ hợp (NFD) thành chữ dựng sẵn")
    func nfc() {
        let decomposed = "Đe\u{0302}\u{0300} thi"  // "Đề thi" dạng NFD
        let name = ReportFileName.exam(title: decomposed, withAnswers: false)
        #expect(name == "Đề thi (đề).pdf")
        #expect(name.unicodeScalars.count == "Đề thi (đề).pdf".unicodeScalars.count)
    }

    @Test("Tên đề dài bị cắt trước: thí sinh và thời điểm nộp giữ nguyên; ≤ 120 ký tự, NFC, không tách dấu")
    func truncatesTitleFirst() {
        let title = String(repeating: "Định ", count: 40)  // 200 ký tự
        let name = ReportFileName.results(examTitle: title, candidateName: "Nguyễn Văn Đức", submittedAt: submittedAt, timeZone: utc)
        #expect(name.hasSuffix(" - Nguyễn Văn Đức - 2026-10-16 1405.pdf"))
        #expect(name.hasPrefix("Định Định"))
        let base = String(name.dropLast(4))
        #expect(base.count <= ReportFileName.maxLength)
        #expect(base.count >= ReportFileName.maxLength - 5)
        #expect(base == base.precomposedStringWithCanonicalMapping)
        #expect(!base.contains("  "))
        // Ký tự nào cũng là chữ dựng sẵn trọn vẹn: không có dấu rời.
        #expect(!base.unicodeScalars.contains { $0.properties.generalCategory == .nonspacingMark })
        // Hai lần thi khác giờ của cùng đề dài: tên khác nhau.
        let later = ReportFileName.results(examTitle: title, candidateName: "Nguyễn Văn Đức", submittedAt: submittedAt + 60, timeZone: utc)
        #expect(later != name)
    }

    @Test("Tên thí sinh quá dài thì bị cắt (≤ 40 ký tự), ngày giờ vẫn còn; tên đề vẫn có phần đầu")
    func hugeCandidate() {
        let candidate = String(repeating: "Trần ", count: 60)  // 300 ký tự
        let name = ReportFileName.results(examTitle: "Kiến thức chung", candidateName: candidate, submittedAt: submittedAt, timeZone: utc)
        #expect(name.hasPrefix("Kiến thức chung - Trần Trần"))
        #expect(name.hasSuffix(" - 2026-10-16 1405.pdf"))
        let candidatePart = name.components(separatedBy: " - ")[1]
        #expect(candidatePart.count <= 40)
        #expect(String(name.dropLast(4)).count <= ReportFileName.maxLength)
    }

    @Test("≤ 255 byte UTF-8 cả với chữ nhiều byte (emoji, chữ Hán): cắt tên đề theo byte")
    func utf8ByteLimit() {
        for unit in ["😀", "漢字", "Ệ"] {
            let title = String(repeating: unit, count: 200)
            let name = ReportFileName.results(examTitle: title, candidateName: "An", submittedAt: submittedAt, timeZone: utc)
            #expect(name.utf8.count <= ReportFileName.maxBytes, "\(unit): \(name.utf8.count) byte")
            #expect(String(name.dropLast(4)).count <= ReportFileName.maxLength)
            #expect(name.hasSuffix(" - An - 2026-10-16 1405.pdf"))
            #expect(name.hasPrefix(unit))
            let exam = ReportFileName.exam(title: title, withAnswers: true)
            #expect(exam.utf8.count <= ReportFileName.maxBytes)
            #expect(exam.hasSuffix(" (có đáp án).pdf"))
        }
    }

    @Test("PDF đề: (có đáp án) / (đề); tên rỗng dùng “Exam Suite”")
    func examNames() {
        #expect(ReportFileName.exam(title: "Kiến thức chung", withAnswers: true) == "Kiến thức chung (có đáp án).pdf")
        #expect(ReportFileName.exam(title: "Kiến thức chung", withAnswers: false) == "Kiến thức chung (đề).pdf")
        #expect(ReportFileName.exam(title: " / : ", withAnswers: false) == "(đề).pdf")
        #expect(ReportFileName.fileName(title: " / : ") { $0 } == "Exam Suite.pdf")
        // Tên đề dài: phần "(có đáp án)" giữ nguyên.
        let long = ReportFileName.exam(title: String(repeating: "Đề rất dài ", count: 20), withAnswers: true)
        #expect(long.hasSuffix(" (có đáp án).pdf"))
        #expect(String(long.dropLast(4)).count <= ReportFileName.maxLength)
    }
}
