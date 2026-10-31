import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Import một file `.vce` tự dựng.
func importVce(_ writer: VceTestWriter, fileName: String = "De tu soan.vce", limits: ImportLimits = .default)
    async throws -> ImportResult
{
    try await ExamImporter.importData(writer.data(), fileName: fileName, limits: limits)
}

/// `.vce` không đọc được, lý do chứa `fragment`.
func expectUnreadableVCE(
    _ data: Data,
    containing fragment: String,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    do {
        _ = try await ExamImporter.importData(data, fileName: "a.vce")
        Issue.record("Mong đợi .vce không đọc được, nhưng import thành công", sourceLocation: sourceLocation)
    } catch let ImportError.unreadableVCE(problem) {
        #expect(problem.logMessage.contains(fragment), "\(problem.logMessage)", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Mong đợi unreadableVCE, nhận \(error)", sourceLocation: sourceLocation)
    }
}

/// Quy tắc `.vce` của docs/product/import.md trên file tự dựng (`VceTestWriter`, theo bố cục ghi ở `VceImporter`).
@Suite("Import .vce")
struct VceImportTests {
    static func basic() -> VceTestWriter {
        var writer = VceTestWriter()
        writer.questions = [
            .init("Giao thức nào dùng cổng 53?", options: ["HTTP", "DNS", "FTP"], answer: "B"),
            .init("Cổng mặc định của HTTPS?", options: ["80", "443"], answer: "B"),
        ]
        return writer
    }

    // MARK: Khối nhị phân

    @Test("CRC-32 khớp vector chuẩn; phép che tự đảo và quay vòng sau 256 byte")
    func primitives() {
        #expect(VceCRC32.checksum(Array("123456789".utf8)[...]) == 0xCBF4_3926)
        #expect(VceCRC32.checksum([][...]) == 0)
        let raw = (0 ..< 600).map { UInt8(truncatingIfNeeded: $0 * 7) }
        let masked = VceMask.unmask(raw)
        #expect(masked[0] == raw[0] && masked[1] == raw[1] ^ 1 && masked[256] == raw[256])
        #expect(VceMask.unmask(masked) == raw)
    }

    @Test("Kiểm độc lập: file .vce tí hon dựng tay bằng Python (zlib.crc32), không qua VceTestWriter")
    func independentTinyFile() async throws {
        // Sinh một lần bằng script Python riêng theo bố cục của `VceImporter` (struct + zlib, không dùng code Swift):
        // mã "C1", tiêu đề "T", điểm đậu 700, 60 phút, phần (1, "S"), một nhóm không tên, một câu "Q?" với lựa chọn
        // x, y, đáp án B, giải thích là khối rỗng. CRC-32 của mọi byte trước 8 byte cuối theo zlib: 0xA5FB2CDC.
        let hex = "85a802010004000000ffff433003000000ffff54bc0200003c00000005000000ffff312f32000000000000000000000000000000"
            + "000000000000000000000000000000000000000000000008000000000102030405060700000000010000000100000003000000ff"
            + "ff53010000000000000000010000008400000000010000000500000000000000630000001d010203293d2636283a2a3a01073e2f"
            + "213122332c3526372814104a1c221e36003a222324081e071909190b1d20241f10001203140d160718093731443d171f5b414243"
            + "697d6676687a6a7a41477e6f617162736c756677685450225c747e5f606162010000004202000000010000000000000b01000000"
            + "000000dc2cfba5"
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(try #require(UInt8(hex[index ..< next], radix: 16)))
            index = next
        }
        #expect(bytes.count == 267)
        #expect(VceCRC32.checksum(bytes[0 ..< bytes.count - 8]) == 0xA5FB_2CDC)
        // Một mảng nhỏ khác, CRC theo zlib.crc32(b"VCE\x00\xff\x80").
        #expect(VceCRC32.checksum([0x56, 0x43, 0x45, 0x00, 0xFF, 0x80][...]) == 0xA610_BE8D)

        let result = try await ExamImporter.importData(Data(bytes), fileName: "tiny.vce")
        #expect(result.suggestions == ImportSuggestions(title: "T", code: "C1", passPercent: 70, timeLimitMinutes: 60))
        #expect(result.sections.map(\.title) == ["S"])
        let q = try #require(result.questions.first)
        #expect(result.questionCount == 1)
        #expect(q.text == "Q?")
        #expect(q.options.map(\.text) == ["x", "y"])
        #expect(q.correct == [OptionID("B")!])
        #expect(q.explanation == nil)
        #expect(result.report.entries.isEmpty)
    }

    @Test("Windows-1252: 0x80–0x9F giải đúng bảng (byte chưa định nghĩa thành mã C1); 256 byte đi về được")
    func windows1252Decoding() {
        let decoded = Windows1252.decode(Array(0x80 ... 0x9F) as [UInt8])
        #expect(decoded.usedNonASCII)
        let expected = "€\u{81}‚ƒ„…†‡ˆ‰Š‹Œ\u{8D}Ž\u{8F}\u{90}‘’“”•–—˜™š›œ\u{9D}žŸ"
        #expect(Array(decoded.text.unicodeScalars) == Array(expected.unicodeScalars))
        for byte in UInt8.min ... UInt8.max {
            #expect(MojibakeRepair.byte(for: MojibakeRepair.scalar(forWindows1252: byte)) == byte)
        }
        #expect(!Windows1252.decode(Array("ASCII".utf8)).usedNonASCII)
    }

    @Test("xstr không có tiền tố FF FF → không đọc được")
    func xstrWithoutPrefix() async throws {
        var bytes = Self.basic().bytes()
        // Tiêu đề: sau magic, 1 byte, xstr mã đề; rồi i32 độ dài + FF FF.
        let title = 4 + 1 + VceTestWriter.xstr(Self.basic().code).count + 4
        #expect(bytes[title] == 0xFF && bytes[title + 1] == 0xFF)
        bytes[title] = 0
        bytes[title + 1] = 0
        await expectUnreadableVCE(Data(VceTestWriter.sealed(bytes)), containing: "chuỗi tiêu đề không đúng dạng")
    }

    @Test("Ảnh nhị phân có độ dài âm hoặc vượt khối: dừng khối, giữ chữ trước, cảnh báo")
    func binaryPictureBadLength() async throws {
        let before = VceTestWriter.version + VceTestWriter.unicodeText(["Trước"])
        let head = Array("-3 3 0 0 2 0 0\r\nanh\r\nTJPEGImage\r\n".utf8)
        for length: Int32 in [-5, .min, 1_000_000, 4] {
            let block = before + head + VceTestWriter.i32(length) + [0xFF, 0xD8] + VceTestWriter.unicodeText(["Sau"])
            var writer = VceTestWriter()
            writer.questions = [.init(text: .raw(block), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A")]
            let result = try await importVce(writer)
            // Độ dài 4 nằm trong khối nhưng nuốt 2 byte tiêu đề của mục sau: phần còn lại không đọc được, vẫn báo.
            #expect(result.questions[0].text == "Trước", "\(length)")
            let message = try #require(result.entries(.unsupportedContent).first?.logMessage, "\(length)")
            #expect(message.contains("ảnh") && message.contains("phần còn lại bị bỏ qua"), "\(length)")
        }
    }

    @Test("Cờ nhiều đáp án ≥ 2: cảnh báo, đáp án vẫn đọc theo chữ")
    func multiFlagOutOfRange() async throws {
        var writer = VceTestWriter()
        var single = VceTestWriter.Question("Một", options: ["1", "2"], answer: "A")
        single.multiFlag = 2
        var multi = VceTestWriter.Question("Hai", options: ["1", "2", "3"], answer: "AC")
        multi.multiFlag = 255
        writer.questions = [single, multi]
        let result = try await importVce(writer)
        #expect(result.questions.map(\.type) == [.single, .multiple])
        #expect(result.entries(.unexpectedAnswerFormat).map(\.location)
            == [ImportLocation(questionNumber: 1), ImportLocation(questionNumber: 2)])
        #expect(result.entries(.unexpectedAnswerFormat)[1].logMessage.contains("(255)"))
    }

    // MARK: Đầu đề

    @Test("Đầu đề: mã, tiêu đề, điểm đậu 800 → 80 %, thời gian 120; một phần; không có mục báo cáo")
    func header() async throws {
        let result = try await importVce(Self.basic())
        #expect(result.sourceFormat == .vce)
        #expect(result.suggestions == ImportSuggestions(title: "De on tap VCE", code: "ON-VCE", passPercent: 80,
                                                        timeLimitMinutes: 120))
        #expect(result.sections.map(\.title) == ["Part 1"])
        #expect(result.questionCount == 2)
        #expect(result.report.entries.isEmpty)
        let q = result.questions[0]
        #expect(q.type == .single)
        #expect(q.text == "Giao thức nào dùng cổng 53?")
        #expect(q.options.map(\.id.description) == ["A", "B", "C"])
        #expect(q.options.map(\.text) == ["HTTP", "DNS", "FTP"])
        #expect(q.correct == [OptionID("B")!])
        #expect(q.explanation == nil)
    }

    @Test("Điểm đậu: N > 100 → N/10 làm tròn nửa lên (như docx); ngoài khoảng → để trống, cảnh báo; thời gian âm → cảnh báo")
    func passingScoreAndTime() async throws {
        for (raw, expected) in [(725, 73), (724, 72), (805, 81), (75, 75), (1000, 100), (0, 0)] {
            var writer = Self.basic()
            writer.passingScore = Int32(raw)
            #expect(try await importVce(writer).suggestions.passPercent == expected, "\(raw)")
        }
        for raw: Int32 in [1005, 5000, -1, .max] {
            var writer = Self.basic()
            writer.passingScore = raw
            let result = try await importVce(writer)
            #expect(result.suggestions.passPercent == nil)
            #expect(result.entries(.invalidPassingScore).map(\.location) == [ImportLocation()])
        }
        var writer = Self.basic()
        writer.timeLimit = -5
        let result = try await importVce(writer)
        #expect(result.suggestions.timeLimitMinutes == nil)
        #expect(result.entries(.invalidTimeLimit).count == 1)
    }

    @Test("Mã đề sai mẫu bị bỏ (cảnh báo); tiêu đề rỗng → tên file")
    func codeAndTitle() async throws {
        var writer = Self.basic()
        writer.code = "MA DE SAI!"
        writer.title = ""
        let result = try await importVce(writer, fileName: "Ôn tập mạng.vce")
        #expect(result.suggestions.code == nil)
        #expect(result.entries(.invalidCode).count == 1)
        #expect(result.suggestions.title == "Ôn tập mạng")
    }

    // MARK: Phần

    @Test("Nhiều phần: câu theo id phần, phần theo thứ tự xuất hiện")
    func multipleSections() async throws {
        var writer = VceTestWriter()
        writer.sections = [(1, "Part 1"), (2, "Part 2")]
        writer.questions = [
            .init("Câu 1", options: ["Có", "Không"], answer: "A", sectionID: 2),
            .init("Câu 2", options: ["Có", "Không"], answer: "A", sectionID: 1),
            .init("Câu 3", options: ["Có", "Không"], answer: "B", sectionID: 2),
        ]
        let result = try await importVce(writer)
        #expect(result.sections.map(\.title) == ["Part 2", "Part 1"])
        #expect(result.sections.map { $0.questions.map(\.text) } == [["Câu 1", "Câu 3"], ["Câu 2"]])
        #expect(result.report.entries.isEmpty)
    }

    @Test("Phần −1: tên nhóm đề, nhóm không tên → \"Phần chung\"; id lạ → phần thay thế và cảnh báo")
    func sectionFallback() async throws {
        var writer = Self.basic()
        writer.sections = []
        writer.questions[0].sectionID = -1
        writer.questions[1].sectionID = -1
        var result = try await importVce(writer)
        #expect(result.sections.map(\.title) == ["Phần chung"])
        #expect(result.report.entries.isEmpty)

        writer.groups = ["Exam A"]
        writer.questions[1].sectionID = 7
        result = try await importVce(writer)
        #expect(result.sections.map(\.title) == ["Exam A"])
        #expect(result.sections[0].questions.count == 2)
        #expect(result.entries(.unknownSection).map(\.location) == [ImportLocation(questionNumber: 2)])
    }

    // MARK: Đáp án

    @Test("Nhiều đáp án viết liền (AC, như file mẫu) → Nhiều đáp án, không cảnh báo")
    func multipleAnswersConcatenated() async throws {
        var writer = VceTestWriter()
        writer.questions = [.init("Chọn hai", options: ["A1", "B1", "C1", "D1"], answer: "AC")]
        let result = try await importVce(writer)
        let q = result.questions[0]
        #expect(q.type == .multiple)
        #expect(q.correct == [OptionID("A")!, OptionID("C")!])
        #expect(result.report.entries.isEmpty)
    }

    @Test("Đáp án có phân cách (A,C / A C): vẫn đọc, cảnh báo khác mẫu; cờ nhiều đáp án không khớp → cảnh báo")
    func multipleAnswersSeparated() async throws {
        for raw in ["A,C", "A C", "A, C"] {
            var writer = VceTestWriter()
            writer.questions = [.init("Chọn hai", options: ["1", "2", "3"], answer: raw)]
            let result = try await importVce(writer)
            #expect(result.questions[0].correct == [OptionID("A")!, OptionID("C")!], "\(raw)")
            #expect(result.questions[0].type == .multiple)
            #expect(result.entries(.unexpectedAnswerFormat).count == 1, "\(raw)")
        }
        var writer = VceTestWriter()
        var question = VceTestWriter.Question("Chọn hai", options: ["1", "2", "3"], answer: "AB")
        question.multiFlag = 0
        writer.questions = [question]
        let result = try await importVce(writer)
        #expect(result.questions[0].type == .multiple)
        #expect(result.entries(.unexpectedAnswerFormat).count == 1)
    }

    @Test("Đáp án rỗng → giữ câu, cảnh báo thiếu đáp án; chữ thường/ký tự lạ → không đọc được")
    func answerProblems() async throws {
        var writer = VceTestWriter()
        writer.questions = [
            .init("Không đáp án", options: ["1", "2"], answer: ""),
            .init("Chữ thường", options: ["1", "2"], answer: "b"),
            .init("Ngoài lựa chọn", options: ["1", "2"], answer: "D"),
        ]
        let result = try await importVce(writer)
        #expect(result.questionCount == 3)
        #expect(result.questions[0].correct.isEmpty)
        #expect(result.entries(.missingAnswer).map(\.location) == [ImportLocation(questionNumber: 1)])
        #expect(result.entries(.answerUnreadable).map(\.location) == [ImportLocation(questionNumber: 2)])
        // Đáp án ngoài lựa chọn giữ nguyên để thanh lỗi chỉ ra (import.md phương án 7).
        #expect(result.questions[2].correct == [OptionID("D")!])
        let issues = try result.roundTrip().written.validationIssues.map(\.code)
        #expect(issues.contains(.correctAnswerNotInOptions))
    }

    // MARK: Lựa chọn và nội dung

    @Test("2 và 6 lựa chọn: theo thứ tự khối, đánh chữ A–F")
    func optionCounts() async throws {
        var writer = VceTestWriter()
        writer.questions = [
            .init("Hai", options: ["Đúng", "Sai"], answer: "A"),
            .init("Sáu", options: ["1", "2", "3", "4", "5", "6"], answer: "BDF"),
        ]
        let result = try await importVce(writer)
        #expect(result.questions[0].options.map(\.id.description) == ["A", "B"])
        #expect(result.questions[1].options.map(\.id.description) == ["A", "B", "C", "D", "E", "F"])
        #expect(result.questions[1].options.map(\.text) == ["1", "2", "3", "4", "5", "6"])
        #expect(result.questions[1].correct.map(\.description) == ["B", "D", "F"])
        #expect(result.questions[1].type == .multiple)
    }

    @Test("Đoạn U+2029: đề bài/giải thích → đoạn Markdown; lựa chọn → xuống dòng (như docx); đoạn trống bỏ")
    func paragraphs() async throws {
        var writer = VceTestWriter()
        writer.questions = [.init(
            text: .paragraphs(["  Đoạn một  ", "", "Đoạn hai"]),
            options: [.paragraphs(["Dòng đầu", "Dòng nối"]), .paragraphs(["Khác"])],
            explanation: .paragraphs(["Giải thích một", "", "Giải thích hai"]),
            answer: "A"
        )]
        let q = try await importVce(writer).questions[0]
        #expect(q.text == "Đoạn một\n\nĐoạn hai")
        #expect(q.options[0].text == "Dòng đầu\nDòng nối")
        #expect(q.explanation == "Giải thích một\n\nGiải thích hai")
    }

    @Test("Giải thích: bỏ các nhãn lặp ở đầu (Section:, Explanation, Explanation/Reference:), giữ chữ sau nhãn")
    func explanationLabels() async throws {
        var writer = VceTestWriter()
        writer.questions = [
            .init("Câu 1", options: ["1", "2"], answer: "A",
                  explanation: ["Section: Part 1", "Explanation", "Explanation/Reference:", "DNS dùng cổng 53.", "Đoạn hai"]),
            .init("Câu 2", options: ["1", "2"], answer: "A",
                  explanation: ["Section: Part 1 Explanation Explanation/Reference: Giải thích liền nhãn"]),
            .init("Câu 3", options: ["1", "2"], answer: "A", explanation: ["Section: (none)", "Explanation"]),
            .init("Câu 4", options: ["1", "2"], answer: "A",
                  explanation: ["Correct Answer: A là đúng vì…", "Explanation of terms"]),
        ]
        let questions = try await importVce(writer).questions
        #expect(questions[0].explanation == "DNS dùng cổng 53.\n\nĐoạn hai")
        #expect(questions[1].explanation == "Giải thích liền nhãn")
        #expect(questions[2].explanation == nil)
        #expect(questions[3].explanation == "Correct Answer: A là đúng vì…\n\nExplanation of terms")
    }

    @Test("Giải thích: \"Section: X\" chỉ bị bỏ khi X là (none) hoặc tên phần trong bảng; chữ thật được giữ")
    func explanationSectionText() async throws {
        var writer = VceTestWriter()
        writer.questions = [
            .init("Câu 1", options: ["1", "2"], answer: "A",
                  explanation: ["Section: 4.2 của tài liệu nói rõ điều này", "Đoạn hai"]),
            .init("Câu 2", options: ["1", "2"], answer: "A", explanation: ["Section: Part 9", "Explanation", "Chữ"]),
            .init("Câu 3", options: ["1", "2"], answer: "A", explanation: ["Section: Part 1", "Section: (NONE)", "Chữ"]),
        ]
        let q = try await importVce(writer).questions
        #expect(q[0].explanation == "Section: 4.2 của tài liệu nói rõ điều này\n\nĐoạn hai")
        #expect(q[1].explanation == "Section: Part 9\n\nExplanation\n\nChữ")
        #expect(q[2].explanation == "Chữ")
    }

    @Test("Phần có id trong bảng nhưng tên rỗng: phần thay thế, cảnh báo đúng lý do")
    func unnamedSection() async throws {
        var writer = Self.basic()
        writer.sections = [(1, "")]
        let result = try await importVce(writer)
        #expect(result.sections.map(\.title) == ["Phần chung"])
        let messages = result.entries(.unknownSection).map(\.logMessage)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.contains("Phần id 1 trong bảng phần không có tên") })
    }

    @Test("Byte Windows-1252 chưa định nghĩa trong tiêu đề/tên phần: cảnh báo nêu trường và ký tự điều khiển vô hình")
    func controlCharactersInHeader() async throws {
        var writer = Self.basic()
        writer.title = "De\u{0081}\u{009D}"
        writer.sections = [(1, "Ph\u{008D}n"), (2, "Caf\u{00E9}")]
        writer.questions[1].sectionID = 2
        let result = try await importVce(writer)
        #expect(result.suggestions.title == "De\u{0081}\u{009D}")
        let messages = result.entries(.assumedEncoding).map(\.logMessage)
        #expect(messages.count == 3)
        #expect(messages[0].hasPrefix("Tiêu đề") && messages[0].contains("ký tự điều khiển vô hình"))
        #expect(messages[1].hasPrefix("Tên phần id 1") && messages[1].contains("ký tự điều khiển vô hình"))
        #expect(messages[2].hasPrefix("Tên phần id 2") && !messages[2].contains("điều khiển"))
        #expect(result.entries(.assumedEncoding).allSatisfy { $0.location == ImportLocation() })
    }

    @Test("Tiếng Việt: giữ nguyên, chuẩn hoá NFC; ký tự Markdown chỉ thoát khi cần")
    func vietnameseAndMarkdown() async throws {
        let decomposed = "Thời gian làm bài".decomposedStringWithCanonicalMapping
        #expect(Array(decomposed.unicodeScalars) != Array("Thời gian làm bài".unicodeScalars))
        var writer = VceTestWriter()
        writer.questions = [.init(decomposed, options: ["*nghiêng*", "s3:* và snake_case"], answer: "A")]
        let q = try await importVce(writer).questions[0]
        #expect(Array(q.text.unicodeScalars) == Array("Thời gian làm bài".precomposedStringWithCanonicalMapping.unicodeScalars))
        #expect(q.options[0].text == "\\*nghiêng\\*")
        #expect(q.options[1].text == "s3:* và snake_case")
    }

    @Test("Mojibake: dãy chắc chắn tự sửa + cảnh báo theo câu; dãy nghi lỗi và ký tự vô hình chỉ cảnh báo")
    func mojibake() async throws {
        var writer = VceTestWriter()
        writer.questions = [
            .init("Itâ€™s DNS", options: ["Caf\u{00C3}\u{00A9}", "Không"], answer: "A",
                  explanation: ["Giá 100 â‚«"]),
            .init("Có\u{00E2}\u{20AC}\u{2039}vô hình", options: ["1", "2"], answer: "A"),
        ]
        let result = try await importVce(writer)
        let q = result.questions
        #expect(q[0].text == "It’s DNS")
        #expect(q[0].explanation == "Giá 100 ₫")
        #expect(q[0].options[0].text == "Caf\u{00C3}\u{00A9}")
        #expect(result.entries(.mojibakeFixed).map(\.location) == [ImportLocation(questionNumber: 1)])
        #expect(result.entries(.mojibakeFixed)[0].logMessage.contains("2 chỗ"))
        #expect(result.entries(.mojibakeSuspected).map(\.location)
            == [ImportLocation(questionNumber: 1), ImportLocation(questionNumber: 2)])
        #expect(q[1].text == "Có\u{00E2}\u{20AC}\u{2039}vô hình")
        #expect(result.entries(.mojibakeFixed).allSatisfy { $0.questionID == q[0].id })
    }

    @Test("Hơn 26 lựa chọn: không crash, từ lựa chọn 27 nối vào Z, cảnh báo")
    func tooManyOptions() async throws {
        var writer = VceTestWriter()
        writer.questions = [.init("Nhiều", options: (1 ... 28).map { "L\($0)" }, answer: "A")]
        let result = try await importVce(writer)
        let q = result.questions[0]
        #expect(q.options.count == 26)
        #expect(q.options[25].text == "L26\nL27\nL28")
        #expect(result.entries(.tooManyOptions).count == 1)
    }

    // MARK: RVF chưa hỗ trợ

    @Test("Ảnh (hex và nhị phân), đường kẻ: bỏ qua đúng bản ghi, giữ chữ trước/sau, cảnh báo kèm vị trí")
    func pictureRecords() async throws {
        let before = VceTestWriter.unicodeText(["Trước ảnh"])
        let after = VceTestWriter.unicodeText(["Sau ảnh"])
        let blocks: [[UInt8]] = [
            VceTestWriter.version + before + VceTestWriter.hexPicture() + after,
            VceTestWriter.version + before + VceTestWriter.binaryPicture([0xFF, 0xD8, 0x0D, 0x0A, 0x00, 0xFF]) + after,
            VceTestWriter.version + before + Array("-1 0 0 0 0 0\r\n".utf8) + after,
        ]
        for (index, block) in blocks.enumerated() {
            var writer = VceTestWriter()
            writer.questions = [
                .init("Câu đầu", options: ["1", "2"], answer: "A"),
                .init(text: .raw(block), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "B"),
            ]
            let result = try await importVce(writer)
            #expect(result.questions[1].text == "Trước ảnh\n\nSau ảnh", "\(index)")
            let warnings = result.entries(.unsupportedContent)
            #expect(warnings.map(\.location) == [ImportLocation(questionNumber: 2)], "\(index)")
            #expect(warnings.first?.logMessage.contains("đề bài") == true)
            #expect(warnings.first?.logMessage.contains(index == 2 ? "đường kẻ" : "ảnh") == true)
            #expect(warnings.first?.questionID == result.questions[1].id)
        }
    }

    @Test("Ảnh trong lựa chọn và giải thích: cảnh báo nêu đúng chỗ")
    func pictureInOptionAndExplanation() async throws {
        var writer = VceTestWriter()
        let picture = VceTestWriter.version + VceTestWriter.hexPicture()
        writer.questions = [.init(text: .paragraphs(["Câu"]),
                                  options: [.paragraphs(["1"]), .raw(picture + VceTestWriter.unicodeText(["2"]))],
                                  explanation: .raw(picture), answer: "A")]
        let result = try await importVce(writer)
        #expect(result.questions[0].options[1].text == "2")
        let messages = result.entries(.unsupportedContent).map(\.logMessage)
        #expect(messages.count == 2)
        #expect(messages[0].contains("lựa chọn B"))
        #expect(messages[1].contains("giải thích"))
    }

    @Test("Kiểu chữ khác 0: giữ chữ dạng thường, cảnh báo bỏ định dạng; Unicode dạng hex: bỏ, cảnh báo; ANSI đọc được, ngoài ASCII thì cảnh báo bảng mã")
    func textVariants() async throws {
        let styled = VceTestWriter.version + VceTestWriter.unicodeText(["Chữ "])
            + VceTestWriter.unicodeText(["đậm"], style: 2, paragraph: -1)
            + VceTestWriter.unicodeText([" tiếp"], paragraph: -1) + VceTestWriter.unicodeText(["Đoạn sau"])
        let hex = VceTestWriter.version + Array("0 1 0 8 3 0\r\n00410042\r\n".utf8) + VceTestWriter.unicodeText(["Sau"])
        let ascii = VceTestWriter.version + VceTestWriter.ansiText([Array("Dong ANSI".utf8), Array("Dong hai".utf8)])
        let latin = VceTestWriter.version + VceTestWriter.ansiText([[0x43, 0x61, 0x66, 0xE9]])
        var writer = VceTestWriter()
        writer.questions = [
            .init(text: .raw(styled), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw(hex), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw(ascii), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw(latin), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
        ]
        let result = try await importVce(writer)
        let q = result.questions
        #expect(q[0].text == "Chữ đậm tiếp\n\nĐoạn sau")
        #expect(q[1].text == "Sau")
        #expect(q[2].text == "Dong ANSI\n\nDong hai")
        #expect(q[3].text == "Café")
        #expect(result.entries(.formattingDropped).map(\.location) == [ImportLocation(questionNumber: 1)])
        #expect(result.entries(.unsupportedContent).map(\.location) == [ImportLocation(questionNumber: 2)])
        #expect(result.entries(.unsupportedContent)[0].logMessage.contains("hex"))
        #expect(result.entries(.assumedEncoding).map(\.location) == [ImportLocation(questionNumber: 4)])
    }

    @Test("Chữ định dạng (kiểu chữ khác 0) nhiều dòng, ở đề bài, lựa chọn và giải thích: không mất chữ, một cảnh báo mỗi câu")
    func formattingKeptAsPlainText() async throws {
        let styledText = VceTestWriter.version + VceTestWriter.docParameters
            + VceTestWriter.unicodeText(["Dòng đậm một", "Dòng đậm hai"], style: 1)
        let styledOption = VceTestWriter.version + VceTestWriter.unicodeText(["Lựa chọn "])
            + VceTestWriter.unicodeText(["nghiêng"], style: 3, paragraph: -1)
        let styledExplanation = VceTestWriter.version + VceTestWriter.unicodeText(["Explanation/Reference:"])
            + VceTestWriter.unicodeText(["Giải thích đậm"], style: 1)
        var writer = VceTestWriter()
        writer.questions = [
            .init(text: .raw(styledText), options: [.raw(styledOption), .paragraphs(["Khác"])],
                  explanation: .raw(styledExplanation), answer: "A"),
            .init("Câu thường", options: ["1", "2"], answer: "B"),
        ]
        let result = try await importVce(writer)
        let q = result.questions[0]
        #expect(q.text == "Dòng đậm một\n\nDòng đậm hai")
        #expect(q.options[0].text == "Lựa chọn nghiêng")
        #expect(q.explanation == "Giải thích đậm")
        let warnings = result.entries(.formattingDropped)
        #expect(warnings.map(\.location) == [ImportLocation(questionNumber: 1)])
        #expect(warnings.first?.questionID == q.id)
        #expect(warnings.first?.severity == .warning)
        let message = try #require(warnings.first?.logMessage)
        #expect(message.contains("đề bài") && message.contains("lựa chọn A") && message.contains("giải thích"))
        #expect(result.entries(.unsupportedContent).isEmpty)
    }

    @Test("Nhiều nhóm đề: đọc mọi bản ghi nhóm; câu không phần → \"Phần chung\" hoặc nhóm có tên duy nhất; cảnh báo mức file")
    func multipleGroups() async throws {
        var writer = Self.basic()
        writer.questions[1].sectionID = -1
        for (groups, expected, warns) in [(["Exam A", "Exam B"], "Phần chung", true),
                                          (["", "Exam B", ""], "Exam B", true),
                                          (["", ""], "Phần chung", true),
                                          ([], "Phần chung", false),
                                          (["Exam A"], "Exam A", false)]
        {
            writer.groups = groups
            let result = try await importVce(writer)
            // Câu có phần giữ phần của nó; câu −1 vào phần thay thế. Không đoán câu thuộc nhóm nào.
            #expect(result.sections.map(\.title) == ["Part 1", expected], "\(groups)")
            #expect(result.sections.map(\.questions.count) == [1, 1])
            let entries = result.entries(.multipleGroups)
            #expect(entries.map(\.location) == (warns ? [ImportLocation()] : []), "\(groups)")
            if warns {
                #expect(entries[0].logMessage.contains("\(groups.count) nhóm đề"))
                #expect(entries[0].logMessage.contains(expected))
            }
        }
    }

    @Test("Bản ghi nhóm không đọc được (số nhóm khai nhiều hơn bản ghi, tên nhóm sai dạng) → không đọc được")
    func brokenGroupRecords() async throws {
        var writer = Self.basic()
        writer.sections = []
        writer.groups = ["G"]
        let bytes = writer.bytes()
        let groupCount = 4 + VceTestWriter.headerLength(writer) + 4
        var claimsMore = bytes
        claimsMore.replaceSubrange(groupCount ..< groupCount + 4, with: VceTestWriter.i32(3))
        await expectUnreadableVCE(Data(VceTestWriter.sealed(claimsMore)), containing: "tên nhóm đề")
        var badName = bytes
        // Tên nhóm: u8, i32 độ dài, rồi FF FF: phá tiền tố FF FF.
        badName[groupCount + 4 + 1 + 4] = 0x00
        await expectUnreadableVCE(Data(VceTestWriter.sealed(badName)), containing: "tên nhóm đề")
    }

    @Test("CR LF sau U+2029 (RVF chuẩn) được bỏ qua, không thành ký tự rác U+0A0D")
    func crlfAfterParagraphSeparator() async throws {
        func utf16(_ s: String) -> [UInt8] { s.utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] } }
        let block = VceTestWriter.version + Array("0 2 0 8 0 0\r\n".utf8)
            + utf16("A") + [0x29, 0x20, 0x0D, 0x0A] + utf16("B") + [0x29, 0x20, 0x0D, 0x0A]
            + VceTestWriter.unicodeText(["C"])
        var writer = VceTestWriter()
        writer.questions = [.init(text: .raw(block), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A")]
        let result = try await importVce(writer)
        #expect(result.questions[0].text == "A\n\nB\n\nC")
        #expect(!result.questions[0].text.unicodeScalars.contains { $0.value == 0x0A0D })
        #expect(result.report.entries.isEmpty)
    }

    @Test("Bản ghi không phải chữ khai số dòng lấn sang mục sau hoặc ít hơn đặc tả: dừng khối và báo, không nuốt chữ lặng lẽ")
    func nonTextLineCountMismatch() async throws {
        let before = VceTestWriter.version + VceTestWriter.unicodeText(["Trước"])
        // Ảnh khai 5 dòng nhưng chỉ có 3 (tên, lớp, hex); dòng 4 là tiêu đề của mục chữ kế tiếp.
        let crossing = before + Array("-3 5 0 0 0 0 0\r\nanh\r\nTPNGImage\r\n89504E47\r\n".utf8)
            + VceTestWriter.ansiText([Array("Mat chu".utf8)]) + VceTestWriter.unicodeText(["Sau"])
        // Ảnh khai 1 dòng: ít hơn 3 dòng của đặc tả.
        let tooFew = before + Array("-3 1 0 0 0 0 0\r\nanh\r\n".utf8) + VceTestWriter.unicodeText(["Sau"])
        for block in [crossing, tooFew] {
            var writer = VceTestWriter()
            writer.questions = [.init(text: .raw(block), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A")]
            let result = try await importVce(writer)
            #expect(result.questions[0].text == "Trước")
            let message = try #require(result.entries(.unsupportedContent).first?.logMessage)
            #expect(message.contains("ảnh") && message.contains("phần còn lại bị bỏ qua"))
        }
    }

    @Test("Dòng dữ liệu toàn số (-9 có dữ liệu, ảnh tên \"1 2 3 4\") không bị coi là tiêu đề bản ghi kế tiếp")
    func numericDataLines() async throws {
        let docParams = VceTestWriter.version + Array("-9 3 0 0 0 0 7\r\n100 100 100 100\r\n1 2 3 4 5 6\r\n0 1 0 8 9 0\r\n".utf8)
            + VceTestWriter.unicodeText(["Sau tham số"])
        let picture = VceTestWriter.version + VceTestWriter.unicodeText(["Trước"])
            + Array("-3 3 0 0 0 0 0\r\n1 2 3 4\r\nTPNGImage\r\n0123456789\r\n".utf8) + VceTestWriter.unicodeText(["Sau"])
        var writer = VceTestWriter()
        writer.questions = [
            .init(text: .raw(docParams), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw(picture), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
        ]
        let result = try await importVce(writer)
        #expect(result.questions.map(\.text) == ["Sau tham số", "Trước\n\nSau"])
        let warnings = result.entries(.unsupportedContent)
        #expect(warnings.map(\.location) == [ImportLocation(questionNumber: 2)])
        #expect(warnings.first.map { $0.logMessage.contains("ảnh") && !$0.logMessage.contains("phần còn lại") } == true)
        #expect(RVFReader.Parser.isRecordHeader(Array("0 1 0 8 0 0".utf8)[...]))
        #expect(RVFReader.Parser.isRecordHeader(Array("-3 3 0 0 2 \"anh\" 0".utf8)[...]))
        #expect(!RVFReader.Parser.isRecordHeader(Array("-8 1 3 1".utf8)[...]))
        #expect(!RVFReader.Parser.isRecordHeader(Array("100 100 100 100".utf8)[...]))
    }

    @Test("Mục văn bản nối đoạn (đoạn −1) và xuống dòng (bit 2)")
    func continuation() async throws {
        let block = VceTestWriter.version + VceTestWriter.unicodeText(["Một"])
            + VceTestWriter.unicodeText([" nối"], paragraph: -1) + VceTestWriter.unicodeText(["Dòng mới"], options: 8 | 4)
        var writer = VceTestWriter()
        writer.questions = [.init(text: .raw(block), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A")]
        #expect(try await importVce(writer).questions[0].text == "Một nối\nDòng mới")
    }

    @Test("RVF không đúng dạng hoặc ngắn hơn khai báo: giữ phần đọc được, cảnh báo")
    func malformedRVF() async throws {
        let garbage = Array("không phải RVF".utf8)
        let short = VceTestWriter.version + Array("0 3 0 8 0 0\r\n".utf8) + [0x41, 0x00, 0x29, 0x20]
        let negative = VceTestWriter.version + Array("0 -2 0 8 0 0\r\n".utf8)
        var writer = VceTestWriter()
        writer.questions = [
            .init(text: .raw(garbage), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw(short), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw(negative), options: [.paragraphs(["1"]), .paragraphs(["2"])], answer: "A"),
            .init(text: .raw([]), options: [.raw([]), .paragraphs(["2"])], answer: "A"),
        ]
        let result = try await importVce(writer)
        #expect(result.questions.map(\.text) == ["", "A", "", ""])
        #expect(result.entries(.unsupportedContent).map(\.location)
            == (1 ... 3).map { ImportLocation(questionNumber: $0) })
        // Khối rỗng (có ở file mẫu: lựa chọn trống) là văn bản rỗng, không cảnh báo.
        #expect(result.questions[3].options[0].text == "")
    }

    // MARK: Câu bị bỏ

    @Test("Loại câu khác 5 → bỏ câu (unsupportedQuestionType), câu khác giữ")
    func unsupportedQuestionType() async throws {
        var writer = Self.basic()
        var other = VceTestWriter.Question("Kéo thả", options: ["1", "2"], answer: "A")
        other.type = 7
        writer.questions.insert(other, at: 1)
        let result = try await importVce(writer)
        #expect(result.questionCount == 2)
        #expect(result.report.droppedCount == 1)
        let entry = try #require(result.entries(.unsupportedQuestionType).first)
        #expect(entry.location == ImportLocation(questionNumber: 2))
        #expect(entry.severity == .dropped)
        #expect(entry.questionID == nil)
        #expect(entry.logMessage.contains("loại 7"))
    }

    @Test("Bố cục câu lạ (số khối khác số lựa chọn, byte thừa) → bỏ câu (unreadableQuestion)")
    func unreadableQuestion() async throws {
        var writer = Self.basic()
        writer.questions[0].optionCount = 5
        writer.questions[1].extraBytes = [1, 2, 3]
        writer.questions.append(.init("Còn lại", options: ["1", "2"], answer: "A"))
        let result = try await importVce(writer)
        #expect(result.questions.map(\.text) == ["Còn lại"])
        #expect(result.entries(.unreadableQuestion).map(\.location)
            == [ImportLocation(questionNumber: 1), ImportLocation(questionNumber: 2)])
        #expect(result.entries(.unreadableQuestion).allSatisfy { $0.severity == .dropped })
    }

    @Test("Câu không có lựa chọn → bỏ (noOptions); mọi câu bị bỏ → lỗi, không mở cửa sổ")
    func noUsableQuestions() async throws {
        var writer = Self.basic()
        writer.questions.append(.init("Không lựa chọn", options: [], answer: ""))
        let result = try await importVce(writer)
        #expect(result.entries(.noOptions).map(\.location) == [ImportLocation(questionNumber: 3)])

        var bad = VceTestWriter()
        var typed = VceTestWriter.Question("Loại lạ", options: ["1", "2"], answer: "A")
        typed.type = 9
        bad.questions = [typed, .init("Không lựa chọn", options: [], answer: "")]
        await expectUnreadableVCE(bad.data(), containing: "2 câu đều bị bỏ: 1 câu có loại chưa hỗ trợ, 1 câu không có lựa chọn")
        bad.questions = []
        await expectUnreadableVCE(bad.data(), containing: "không có câu hỏi nào")
    }

    // MARK: File hỏng

    @Test("Magic lạ, file rỗng, file quá ngắn → không đọc được")
    func wrongMagic() async throws {
        var writer = Self.basic()
        writer.magic = [0x85, 0xA8, 0x03, 0x01]
        await expectUnreadableVCE(writer.data(), containing: "mã nhận dạng")
        await expectUnreadableVCE(Data("PK\u{03}\u{04} không phải vce".utf8), containing: "mã nhận dạng")
        await expectUnreadableVCE(Data(), containing: "file rỗng")
        await expectUnreadableVCE(Data([0x85, 0xA8]), containing: "quá ngắn")
        await expectUnreadableVCE(Data([0x85, 0xA8, 0x02, 0x01, 0, 0]), containing: "cắt cụt")
    }

    @Test("Trường kích thước file sai, CRC-32 sai → không đọc được")
    func integrity() async throws {
        let good = Self.basic().bytes()
        var wrongSize = good
        let n = good.count
        wrongSize.replaceSubrange(n - 12 ..< n - 8, with: VceTestWriter.i32(Int32(n + 1)))
        wrongSize.replaceSubrange(n - 4 ..< n, with: VceTestWriter.u32(VceCRC32.checksum(wrongSize[0 ..< n - 8])))
        await expectUnreadableVCE(Data(wrongSize), containing: "kích thước ghi trong file")

        var flipped = good
        flipped[40] ^= 0x01
        await expectUnreadableVCE(Data(flipped), containing: "CRC-32")
        var badCRC = good
        badCRC[n - 1] ^= 0xFF
        await expectUnreadableVCE(Data(badCRC), containing: "CRC-32")
        // 4 byte chưa rõ trước CRC-32 nằm ngoài vùng CRC (mọi byte trước 8 byte cuối) và bị bỏ qua: sửa vẫn đọc được.
        var unknown = good
        unknown[n - 7] ^= 0xFF
        #expect(try await ExamImporter.importData(Data(unknown), fileName: "a.vce").questionCount == 2)
    }

    @Test("Độ dài và số lượng khổng lồ/âm (CRC đúng) → không đọc được, không cấp phát lớn")
    func hugeLengths() async throws {
        let good = Self.basic().bytes()
        // Độ dài mã đề nằm ngay sau magic + 1 byte.
        for value: Int32 in [.max, -1, Int32(good.count)] {
            var bytes = good
            bytes.replaceSubrange(5 ..< 9, with: VceTestWriter.i32(value))
            await expectUnreadableVCE(Data(VceTestWriter.sealed(bytes)), containing: "độ dài mã đề")
        }

        var writer = Self.basic()
        writer.sections = []
        writer.groups = ["G"]
        let bytes = writer.bytes()
        // Vị trí số phần: tìm bằng cách dựng lại tới trước bảng phần.
        let headerEnd = VceTestWriter.headerLength(writer)
        for (offset, value, fragment) in [(headerEnd, Int32.max, "số phần"), (headerEnd, -3, "số phần"),
                                          (headerEnd + 4, .max, "số nhóm đề"), (headerEnd + 4, -1, "số nhóm đề"),
                                          (headerEnd + 4 + 1 + 4 + 2 + 1 + 4, .max, "số câu"),
                                          (headerEnd + 4 + 1 + 4 + 2 + 1 + 4, -1, "số câu")]
        {
            var mutated = bytes
            mutated.replaceSubrange(4 + offset ..< 4 + offset + 4, with: VceTestWriter.i32(value))
            await expectUnreadableVCE(Data(VceTestWriter.sealed(mutated)), containing: fragment)
        }
        // Kích thước câu đầu tiên khổng lồ.
        let firstQuestion = 4 + headerEnd + 4 + 4 + 1 + 4 + 2 + 1 + 4
        var mutated = bytes
        mutated.replaceSubrange(firstQuestion ..< firstQuestion + 4, with: VceTestWriter.i32(.max))
        await expectUnreadableVCE(Data(VceTestWriter.sealed(mutated)), containing: "câu 1")
    }

    @Test("Byte thừa sau danh sách câu → không đọc được")
    func trailingBytes() async throws {
        var bytes = Self.basic().bytes()
        bytes.insert(contentsOf: [1, 2, 3], at: bytes.count - 12)
        await expectUnreadableVCE(Data(VceTestWriter.sealed(bytes)), containing: "byte lạ sau danh sách câu")
    }

    @Test("Cắt cụt ở mọi vị trí: lỗi, không crash; cắt rồi gắn đuôi mới (CRC đúng): lỗi ở bộ đọc tuần tự")
    func truncationAtEveryOffset() async throws {
        let bytes = Self.basic().bytes()
        for length in 0 ..< bytes.count {
            do {
                _ = try await ExamImporter.importData(Data(bytes.prefix(length)), fileName: "a.vce")
                Issue.record("Cắt còn \(length) byte vẫn import được")
            } catch ImportError.unreadableVCE {
            } catch {
                Issue.record("Cắt còn \(length) byte: lỗi lạ \(error)")
            }
        }
        let body = bytes.count - 12
        for length in 4 ..< body {
            let resealed = VceTestWriter.sealed(Array(bytes.prefix(length)) + [UInt8](repeating: 0, count: 12))
            do {
                _ = try await ExamImporter.importData(Data(resealed), fileName: "a.vce")
                Issue.record("Thân cắt còn \(length) byte vẫn import được")
            } catch ImportError.unreadableVCE {
            } catch {
                Issue.record("Thân cắt còn \(length) byte: lỗi lạ \(error)")
            }
        }
    }

    @Test("Đột biến ngẫu nhiên (CRC tính lại và không): không crash, không treo, chỉ ImportError",
          .timeLimit(.minutes(2)))
    func randomMutations() async throws {
        var writer = Self.basic()
        writer.sections = [(1, "Part 1"), (2, "Part 2")]
        writer.questions.append(.init(text: .raw(VceTestWriter.version + VceTestWriter.hexPicture()
                + VceTestWriter.unicodeText(["Sau"])), options: [.paragraphs(["1", "2"]), .paragraphs(["3"])],
            answer: "AB"))
        let original = writer.bytes()
        var generator = SeededGenerator(seed: 0x56_43_45)
        var succeeded = 0
        for iteration in 0 ..< 3000 {
            var bytes = original
            let count = Int.random(in: 1 ... 6, using: &generator)
            for _ in 0 ..< count {
                let index = Int.random(in: 4 ..< bytes.count - 12, using: &generator)
                bytes[index] = UInt8.random(in: 0 ... 255, using: &generator)
            }
            let data = Data(iteration % 5 == 0 ? bytes : VceTestWriter.sealed(bytes))
            do {
                let result = try await ExamImporter.importData(data, fileName: "a.vce")
                _ = try result.roundTrip()
                succeeded += 1
            } catch is ImportError {
            } catch {
                Issue.record("Đột biến \(iteration): lỗi không phải ImportError: \(error)")
            }
        }
        // Đa số đột biến rơi vào chữ của câu: vẫn đọc được (có thể kèm cảnh báo).
        #expect(succeeded > 0)
    }

    @Test("Báo cáo giữ 1.000 mục chi tiết mỗi mã; phần còn lại thành một mục tóm tắt; số câu bỏ và cảnh báo vẫn đúng")
    func reportCap() async throws {
        var odd = VceTestWriter.Question("Loại lạ", options: ["1", "2"], answer: "A")
        odd.type = 7
        var writer = VceTestWriter()
        writer.questions = Array(repeating: odd, count: 1_500)
            + Array(repeating: .init("Phân cách", options: ["1", "2"], answer: "A,B"), count: 300)
            + [.init("Thường", options: ["1", "2"], answer: "A")]
        let result = try await importVce(writer)
        #expect(result.questionCount == 301)
        // 1.000 mục bỏ câu chi tiết + tóm tắt 500; 300 cảnh báo (dưới trần của mã đó) đều chi tiết.
        #expect(result.report.entries.count == ReportBuilder.detailedEntryLimit + 300 + 1)
        #expect(result.report.droppedCount == 1_500)
        #expect(result.report.warningCount == 300)
        let summaries = result.report.entries.filter(\.isSummary)
        #expect(summaries.map(\.code) == [.unsupportedQuestionType])
        #expect(summaries.map(\.occurrences) == [500])
        #expect(summaries[0].logMessage.hasPrefix("… và 500 mục tương tự"))
        #expect(summaries.allSatisfy { $0.questionID == nil && $0.location == ImportLocation() })
        #expect(result.report.entries.filter { !$0.isSummary }.allSatisfy { $0.occurrences == 1 })

        // txt dùng cùng trần; số câu bị bỏ trong lỗi "không có câu" vẫn đếm đủ.
        let text = (1 ... 1_200).map { "Q\($0):\nKhông có lựa chọn\n" }.joined()
        await expectImportError(.noQuestions(dropped: 1_200)) {
            _ = try await importText(text)
        }
    }

    @Test("Trần theo mã: 1.200 tên phần ngoài ASCII không chiếm chỗ các mục bỏ câu")
    func perCodeCap() async throws {
        var odd = VceTestWriter.Question("Loại lạ", options: ["1", "2"], answer: "A")
        odd.type = 7
        var writer = VceTestWriter()
        writer.sections = (1 ... 1_200).map { (Int32($0), "Caf\u{00E9} \($0)") }
        writer.questions = Array(repeating: odd, count: 5) + [.init("Thường", options: ["1", "2"], answer: "A")]
        let result = try await importVce(writer)
        let dropped = result.entries(.unsupportedQuestionType)
        #expect(dropped.count == 5)
        #expect(dropped.allSatisfy { !$0.isSummary })
        #expect(dropped.map(\.location) == (1 ... 5).map { ImportLocation(questionNumber: $0) })
        let encoding = result.entries(.assumedEncoding)
        #expect(encoding.filter { !$0.isSummary }.count == ReportBuilder.detailedEntryLimit)
        #expect(encoding.filter(\.isSummary).map(\.occurrences) == [200])
        #expect(result.report.warningCount == 1_200)
    }

    @Test("Chỉ một mục vượt trần: giữ chi tiết, không có \"… và 1 mục tương tự\"")
    func singleOverflowKeptDetailed() async throws {
        var odd = VceTestWriter.Question("Loại lạ", options: ["1", "2"], answer: "A")
        odd.type = 7
        var writer = VceTestWriter()
        writer.questions = Array(repeating: odd, count: 1_001) + [.init("Thường", options: ["1", "2"], answer: "A")]
        let result = try await importVce(writer)
        let dropped = result.entries(.unsupportedQuestionType)
        #expect(dropped.count == 1_001)
        #expect(!dropped.contains { $0.isSummary })
        #expect(dropped.last?.location == ImportLocation(questionNumber: 1_001))
        #expect(!result.report.entries.contains { $0.logMessage.contains("… và 1 mục") })
        #expect(result.report.droppedCount == 1_001)
    }

    @Test("Trần mặc định của file .vce là 64 MiB")
    func defaultSizeLimit() {
        #expect(ImportLimits.default.vceBytes == 64 << 20)
    }

    @Test("Quá giới hạn kích thước file .vce")
    func sizeLimit() async throws {
        var limits = ImportLimits.default
        limits.vceBytes = 100
        await expectImportError(.tooLarge(what: .vceFile, limit: 100)) {
            _ = try await importVce(Self.basic(), limits: limits)
        }
    }

    @Test("Thông báo lỗi tiếng Việt (nhật ký) chỉ đường lui qua .docx")
    func errorDescription() {
        let error = ImportError.unreadableVCE(.checksumMismatch)
        #expect(error.logMessage == "File .vce không đọc được: sai mã kiểm tra CRC-32: file bị hỏng hoặc đã bị sửa. Nếu có bản .docx xuất từ VCE thì import file đó.")
        #expect(ImportError.unsupportedFileType("pdf").logMessage.contains(".txt, .docx, .vce và .oef"))
    }

    // MARK: Luồng

    /// Chạy `body` trong một task đã bị huỷ.
    static func inCancelledTask<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async -> Result<T, Error> {
        await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return Result { try body() }
        }.value
    }

    @Test("Huỷ khi đọc bảng phần/nhóm lớn (không có câu): bộ đọc khung và bộ ánh xạ kiểm huỷ trong vòng lặp")
    func cancellationInTables() async throws {
        var sections = VceTestWriter()
        sections.sections = (1 ... 20_000).map { (Int32($0), "P") }
        sections.questions = []
        var groups = VceTestWriter()
        groups.groups = Array(repeating: "", count: 20_000)
        groups.questions = []
        for writer in [sections, groups] {
            let bytes = writer.bytes()
            // Không có câu nào: chỉ vòng bảng phần/nhóm có thể nhận ra lệnh huỷ.
            let parsed = await Self.inCancelledTask { try VceFile.parse(bytes) }
            switch parsed {
            case .success:
                Issue.record("parsed: không nhận ra lệnh huỷ")
            case let .failure(error):
                #expect(error is CancellationError, "\(error)")
            }
            let file = try VceFile.parse(bytes)
            let converted = await Self.inCancelledTask { try VceConverter(file: file, fileStem: "a") }
            switch converted {
            case .success:
                Issue.record("converted: không nhận ra lệnh huỷ")
            case let .failure(error):
                #expect(error is CancellationError, "\(error)")
            }
        }
    }

    @Test("Huỷ ngay khi bắt đầu đọc file lớn (200.000 phần): ném CancellationError")
    func cancellationLargeFile() async throws {
        var writer = VceTestWriter()
        writer.sections = (1 ... 200_000).map { (Int32($0), "P") }
        writer.questions = [.init("Câu", options: ["1", "2"], answer: "A")]
        let data = writer.data()
        let box = CancelBox()
        let task = Task {
            try await ExamImporter.importData(data, fileName: "a.vce") { progress in
                if progress.phase == .reading { box.cancel() }
            }
        }
        box.set(task)
        do {
            _ = try await task.value
            Issue.record("Import không dừng khi bị huỷ")
        } catch is CancellationError {
        }
    }

    @Test("Huỷ task gọi: bộ đọc dừng và ném CancellationError")
    func cancellation() async throws {
        var writer = VceTestWriter()
        writer.questions = (1 ... 3000).map { .init("Câu \($0)", options: ["Có", "Không"], answer: "A") }
        let data = writer.data()
        let box = CancelBox()
        let task = Task {
            try await ExamImporter.importData(data, fileName: "a.vce") { progress in
                if progress.phase == .converting, progress.fractionCompleted > 0.1 { box.cancel() }
            }
        }
        box.set(task)
        do {
            _ = try await task.value
            Issue.record("Import không dừng khi bị huỷ")
        } catch is CancellationError {
        }
    }

    @Test("Import từ file trên đĩa (đuôi .VCE), .vce trong danh sách đuôi hỗ trợ; tiến độ kết thúc ở 1")
    func fromDisk() async throws {
        #expect(ExamImporter.supportedExtensions.contains("vce"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("examimport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Ôn tập.VCE")
        try Self.basic().data().write(to: url)
        let recorder = ProgressRecorder()
        let result = try await ExamImporter.importFile(at: url) { recorder.add($0) }
        #expect(result.questionCount == 2)
        #expect(recorder.values.last == ImportProgress(phase: .finished, fractionCompleted: 1))
        do {
            _ = try await ExamImporter.importFile(at: directory.appendingPathComponent("khong-co.vce"))
            Issue.record("File không có vẫn import được")
        } catch ImportError.unreadableFile {
        }
    }

    @Test("Ghi bằng ExamPackageWriter rồi đọc lại (nghiêm) ra đúng đề: nhiều phần, nhiều đáp án, tiếng Việt")
    func roundTrip() async throws {
        var writer = VceTestWriter()
        // Tên phần là `xstr` 1 byte/ký tự (ASCII ở file mẫu); chữ tiếng Việt nằm trong RVF (UTF-16).
        writer.sections = [(1, "Mang may tinh"), (2, "Bao mat")]
        writer.questions = [
            .init("Giao thức nào dùng cổng 53?", options: ["HTTP", "DNS"], answer: "B",
                  explanation: ["Explanation/Reference:", "DNS dùng cổng 53."]),
            .init("Chọn hai biện pháp", options: ["MFA", "Mật khẩu yếu", "Mã hoá", "Tắt log"], answer: "AC",
                  sectionID: 2),
        ]
        let result = try await importVce(writer)
        let (written, reread) = try result.roundTrip(mode: .strict)
        #expect(reread.exam == written.exam)
        #expect(written.validationIssues.isEmpty)
        #expect(reread.exam.sections.map(\.title) == ["Mang may tinh", "Bao mat"])
        #expect(reread.exam.sections[1].questions[0].type == .multiple)
        #expect(reread.exam.sections[0].questions[0].explanation == "DNS dùng cổng 53.")
    }
}

extension VceTestWriter {
    /// Số byte từ sau magic tới trước bảng phần (để test sửa đúng trường số phần/nhóm/câu).
    static func headerLength(_ writer: VceTestWriter) -> Int {
        1 + xstr(writer.code).count + xstr(writer.title).count + 8 + xstr("1.0").count + 32 + 6
            + blob([UInt8](repeating: 0, count: 8)).count + blob(rvf([""])).count
    }
}
