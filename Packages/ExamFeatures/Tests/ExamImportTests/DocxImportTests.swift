import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Quy tắc `.docx` của docs/product/import.md trên tài liệu Word tự dựng (`DocxBuilder`).
@Suite("Import .docx")
struct DocxImportTests {
    /// Đầu đề + nhóm "Exam A" như bố cục xuất từ VCE.
    static func header(_ doc: inout DocxBuilder, number: String = "ON-042", passing: String = "800",
                       time: String = "Time Limit: 120 min File Version: 1.0")
    {
        doc.paragraphs("Đề ôn tập mạng máy tính", "Number: \(number)", "Passing Score: \(passing)", time,
                       "Sections", "1. Phần mạng", "Exam A")
    }

    /// Một câu dùng danh sách upperLetter cho lựa chọn.
    static func listQuestion(_ doc: inout DocxBuilder, _ number: Int, numID: Int = 1, answer: String = "B",
                             labels: [String] = ["Section: Phần mạng", "Explanation", "Explanation/Reference:"])
    {
        doc.paragraph("QUESTION \(number)")
        doc.paragraph("Giao thức nào dùng cổng 53?")
        doc.listItem("HTTP", numID: numID)
        doc.listItem("DNS", numID: numID)
        doc.listItem("FTP", numID: numID)
        doc.paragraph("Correct Answer: \(answer)")
        for label in labels { doc.paragraph(label) }
    }

    @Test("Đầu đề: tiêu đề, Number → mã, Passing Score 800 → 80 %, Time Limit 120 min → 120")
    func headerSuggestions() async throws {
        var doc = DocxBuilder()
        Self.header(&doc)
        Self.listQuestion(&doc, 1)
        let result = try await importDocx(doc)
        #expect(result.sourceFormat == .docx)
        #expect(result.suggestions == ImportSuggestions(title: "Đề ôn tập mạng máy tính", code: "ON-042",
                                                        passPercent: 80, timeLimitMinutes: 120))
        #expect(result.report.entries.isEmpty)
    }

    @Test("Passing Score: N > 100 → N/10 làm tròn gần nhất, nửa lên; N ≤ 100 → N; ngoài khoảng hoặc lạ → để trống, cảnh báo")
    func passingScore() async throws {
        for (raw, expected) in [("725", 73), ("724", 72), ("805", 81), ("800", 80), ("75", 75), ("1000", 100), ("1004", 100), ("0", 0)] {
            var doc = DocxBuilder()
            Self.header(&doc, passing: raw)
            Self.listQuestion(&doc, 1)
            #expect(try await importDocx(doc).suggestions.passPercent == expected, "\(raw)")
        }
        for raw in ["1005", "1200", "tám trăm"] {
            var doc = DocxBuilder()
            Self.header(&doc, passing: raw)
            Self.listQuestion(&doc, 1)
            let result = try await importDocx(doc)
            #expect(result.suggestions.passPercent == nil)
            #expect(result.entries(.invalidPassingScore).map(\.location) == [ImportLocation()])
        }
    }

    @Test("Nhãn đầu đề đứng sau tiêu đề dài trong cùng đoạn vẫn được đọc (không cắt đoạn)")
    func headerFieldsAfterLongTitle() async throws {
        var doc = DocxBuilder()
        let title = "Đề ôn tập " + String(repeating: "rất dài ", count: 1000)
        doc.paragraph(title + "Number: ON-7 Passing Score: 724 Time Limit: 90 min File Version: 2")
        Self.listQuestion(&doc, 1)
        let result = try await importDocx(doc)
        #expect(result.suggestions.code == "ON-7")
        #expect(result.suggestions.passPercent == 72)
        #expect(result.suggestions.timeLimitMinutes == 90)
        #expect(result.suggestions.title.hasPrefix("Đề ôn tập rất dài"))
        #expect(result.report.entries.isEmpty)
    }

    @Test("Đoạn đầu đề dị dạng (nhãn lặp, dãy số/khoảng trắng dài) vẫn đọc nhanh")
    func headerPathological() async throws {
        var doc = DocxBuilder()
        doc.paragraph(String(repeating: "Number:", count: 20_000))
        doc.paragraph("Time Limit: " + String(repeating: "9", count: 20_000) + String(repeating: " ", count: 20_000) + "x")
        doc.paragraph(String(repeating: "Passing ", count: 20_000) + "Score: 800")
        Self.listQuestion(&doc, 1)
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await importDocx(doc)
        #expect(clock.now - start < .seconds(5))
        #expect(result.suggestions.passPercent == 80)
        #expect(result.suggestions.timeLimitMinutes == nil)
        #expect(result.entries(.invalidCode).count == 1)
        #expect(result.entries(.invalidTimeLimit).count == 1)
    }

    @Test("Số quá lớn ở đầu đề không làm tràn số: để trống và cảnh báo")
    func headerOverflow() async throws {
        for (passing, time) in [("9223372036854775807", "Time Limit: 9223372036854775807 min"),
                                ("99999999999999999999", "Time Limit: 1234567 min")]
        {
            var doc = DocxBuilder()
            Self.header(&doc, passing: passing, time: time)
            Self.listQuestion(&doc, 1)
            let result = try await importDocx(doc)
            #expect(result.suggestions.passPercent == nil)
            #expect(result.suggestions.timeLimitMinutes == nil)
            #expect(result.entries(.invalidPassingScore).count == 1)
            #expect(result.entries(.invalidTimeLimit).count == 1)
        }
    }

    /// numbering.xml tự soạn: numId 7 → abstract 20 (decimal) với `w:start` = `start`; numId 8 cùng abstract nhưng
    /// `lvlOverride` cấp 0 đổi thành upperLetter; numId 9 cùng abstract với `startOverride`.
    static func numbering(start: String, startOverride: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:numbering xmlns:w="\(DocxBuilder.wordNamespace)">
        <w:abstractNum w:abstractNumId="20"><w:lvl w:ilvl="0"><w:start w:val="\(start)"/><w:numFmt w:val="decimal"/></w:lvl></w:abstractNum>
        <w:num w:numId="7"><w:abstractNumId w:val="20"/></w:num>
        <w:num w:numId="8"><w:abstractNumId w:val="20"/><w:lvlOverride w:ilvl="0"><w:lvl w:ilvl="0"><w:numFmt w:val="upperLetter"/></w:lvl></w:lvlOverride></w:num>
        <w:num w:numId="9"><w:abstractNumId w:val="20"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="\(startOverride)"/></w:lvlOverride></w:num>
        </w:numbering>
        """
    }

    static func numberedQuestion(_ numbering: String) -> DocxBuilder {
        var doc = DocxBuilder()
        doc.numbering = numbering
        doc.paragraph("QUESTION 1")
        doc.listItem("bước một", numID: 7)
        doc.listItem("bước hai", numID: 7)
        doc.paragraph("Danh sách khác:")
        doc.listItem("ý một", numID: 9)
        doc.listItem("ý hai", numID: 9)
        doc.listItem("Có", numID: 8)
        doc.listItem("Không", numID: 8)
        doc.paragraph("Correct Answer: B")
        return doc
    }

    @Test("lvlOverride đổi kiểu đánh số thành upperLetter (lựa chọn); startOverride đổi số bắt đầu")
    func levelOverride() async throws {
        let result = try await importDocx(Self.numberedQuestion(Self.numbering(start: "3", startOverride: "5")))
        let q = result.questions[0]
        #expect(q.text == "3. bước một\n4. bước hai\n\nDanh sách khác:\n\n5. ý một\n6. ý hai")
        #expect(q.options.map(\.text) == ["Có", "Không"])
        #expect(q.correct == [OptionID("B")!])
        #expect(result.report.entries.isEmpty)
    }

    @Test("w:start / startOverride = Int.max: không tràn số, bỏ qua giá trị và cảnh báo")
    func numberingOverflow() async throws {
        let max = "9223372036854775807"
        let result = try await importDocx(Self.numberedQuestion(Self.numbering(start: max, startOverride: max)))
        #expect(result.questions[0].text == "1. bước một\n2. bước hai\n\nDanh sách khác:\n\n1. ý một\n2. ý hai")
        #expect(result.entries(.invalidNumbering).map(\.location) == [ImportLocation()])
        #expect(result.entries(.invalidNumbering).first?.logMessage.contains("2 số") == true)
    }

    @Test("Thiếu ngưỡng/thời gian thì để trống; mã sai mẫu bị bỏ và cảnh báo; không có tiêu đề thì dùng tên file")
    func headerFallbacks() async throws {
        var doc = DocxBuilder()
        doc.paragraphs("Number: mã có dấu", "Time Limit: không rõ")
        Self.listQuestion(&doc, 1)
        let result = try await importDocx(doc, fileName: "Bộ đề 3.docx")
        #expect(result.suggestions == ImportSuggestions(title: "Bộ đề 3"))
        #expect(result.entries(.invalidCode).count == 1)
        #expect(result.entries(.invalidTimeLimit).count == 1)
    }

    @Test("Lựa chọn từ danh sách upperLetter; đoạn không đánh số sau lựa chọn là phần nối; giải thích sau Explanation/Reference:")
    func listOptions() async throws {
        var doc = DocxBuilder()
        Self.header(&doc)
        doc.paragraph("QUESTION 1")
        doc.paragraph("Bạn là quản trị mạng.")
        doc.paragraph("Cần chọn giải pháp nào?")
        doc.listItem("Dùng VLAN", numID: 1)
        doc.paragraph("để tách mạng khách.")
        doc.listItem("Dùng NAT", numID: 1)
        doc.listItem("Dùng VPN", numID: 1)
        doc.paragraph("Correct Answer: A")
        doc.paragraph("Section: Phần mạng", style: "Heading1")
        doc.paragraphs("Explanation", "Explanation/Reference:", "Section: Phần mạng", "Explanation",
                       "Explanation/Reference:", "VLAN tách miền quảng bá.", "Tham khảo: tài liệu nội bộ.")
        let result = try await importDocx(doc)
        let q = result.questions[0]
        #expect(q.text == "Bạn là quản trị mạng.\n\nCần chọn giải pháp nào?")
        #expect(q.options.map(\.text) == ["Dùng VLAN\nđể tách mạng khách.", "Dùng NAT", "Dùng VPN"])
        #expect(q.correct == [OptionID("A")!])
        #expect(q.explanation == "VLAN tách miền quảng bá.\n\nTham khảo: tài liệu nội bộ.")
        #expect(result.sections.map(\.title) == ["Phần mạng"])
        #expect(result.report.entries.isEmpty)
    }

    @Test("Danh sách khác trong đề bài: gạch đầu dòng → '- ', đánh số → '1. '; upperLetter cấp 2 không là lựa chọn")
    func listsInQuestionText() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.paragraph("Xét các bước:")
        doc.listItem("Lập kế hoạch", numID: 3)
        doc.listItem("Triển khai", numID: 3)
        doc.listItem("Ý phụ", numID: 5, level: 1)
        doc.paragraph("Và các lưu ý:")
        doc.listItem("an toàn", numID: 2)
        doc.listItem("chi phí", numID: 2)
        doc.paragraph("Bước nào trước?")
        doc.listItem("Lập kế hoạch", numID: 4)
        doc.listItem("Triển khai", numID: 4)
        doc.paragraph("Correct Answer: A")
        let q = try await importDocx(doc).questions[0]
        #expect(q.text == "Xét các bước:\n\n1. Lập kế hoạch\n2. Triển khai\n  1. Ý phụ\n\nVà các lưu ý:\n\n- an toàn\n- chi phí\n\nBước nào trước?")
        #expect(q.options.map(\.text) == ["Lập kế hoạch", "Triển khai"])
    }

    @Test("Lựa chọn dạng 'A. …' khi không dùng danh sách; sai thứ tự thì nối và cảnh báo")
    func textLabelOptions() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 4")
        doc.paragraph("Which port does SSH use?")
        doc.paragraph("A. 21")
        doc.paragraph("B) 22")
        doc.paragraph("D. 25")
        doc.paragraph("C. 23")
        doc.paragraph("Correct Answer: B")
        let result = try await importDocx(doc)
        let q = result.questions[0]
        #expect(q.options.map(\.text) == ["21", "22\nD. 25", "23"])
        #expect(result.entries(.optionLabelOutOfOrder).map(\.location) == [ImportLocation(questionNumber: 4)])
    }

    @Test("Lựa chọn dạng chữ không có A.: bắt đầu từ nhãn đầu tiên, đánh lại theo vị trí, đáp án đổi theo; danh sách thì như cũ")
    func shiftedTextLabelOptions() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 5")
        doc.paragraph("Which port does HTTPS use?")
        doc.paragraphs("B. 80", "C. 443", "D. 8080")
        doc.paragraph("Correct Answer: C Section: Mạng Explanation")
        doc.paragraph("Explanation/Reference:")
        doc.paragraph("A. Giải thích có chữ A. không ảnh hưởng.")
        doc.paragraph("QUESTION 6")
        doc.paragraph("Đề bài có đoạn B. trước danh sách lựa chọn:")
        doc.paragraph("B. ý của đề bài")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: B")
        let result = try await importDocx(doc)
        let q = result.questions
        #expect(q[0].options.map(\.text) == ["80", "443", "8080"])
        #expect(q[0].correct == [OptionID("B")!])
        #expect(q[0].explanation == "A. Giải thích có chữ A. không ảnh hưởng.")
        #expect(q[1].text == "Đề bài có đoạn B. trước danh sách lựa chọn:\n\nB. ý của đề bài")
        #expect(q[1].options.map(\.text) == ["Có", "Không"])
        #expect(q[1].correct == [OptionID("B")!])
        let shifted = result.entries(.optionLabelsShifted)
        #expect(shifted.map(\.location) == [ImportLocation(questionNumber: 5)])
        #expect(shifted.first?.logMessage.contains("Đáp án C → B") == true)
    }

    @Test("Câu dùng danh sách upperLetter: đoạn 'A. …', 'B. …' trong đề bài là chữ của đề bài, không phải lựa chọn")
    func textLabelsIgnoredWithListOptions() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.paragraphs("Xét hai phát biểu:", "A. Phát biểu thứ nhất", "B. Phát biểu thứ hai", "Phát biểu nào đúng?")
        doc.listItem("Chỉ A", numID: 1)
        doc.listItem("Chỉ B", numID: 1)
        doc.paragraph("A. đoạn nối của lựa chọn B")
        doc.listItem("Cả hai", numID: 1)
        doc.paragraph("Correct Answer: C")
        let result = try await importDocx(doc)
        let q = result.questions[0]
        #expect(q.text == "Xét hai phát biểu:\n\nA. Phát biểu thứ nhất\n\nB. Phát biểu thứ hai\n\nPhát biểu nào đúng?")
        #expect(q.options.map(\.text) == ["Chỉ A", "Chỉ B\nA. đoạn nối của lựa chọn B", "Cả hai"])
        #expect(q.correct == [OptionID("C")!])
        #expect(result.report.entries.isEmpty)
    }

    @Test("Đổi chữ đáp án theo vị trí; chữ không khớp vẫn là vi phạm, không trùng lựa chọn khác")
    func remap() {
        func ids(_ s: String) -> [OptionID] { s.map { OptionID($0)! } }
        #expect(OptionRelettering.startOffset(labels: ids("BCDE")) == 1)
        #expect(OptionRelettering.startOffset(labels: ids("CAB")) == 0)
        #expect(OptionRelettering.startOffset(labels: []) == 0)
        #expect(OptionRelettering.remap(ids("C"), offset: 1, optionCount: 4).letters == ids("B"))
        #expect(OptionRelettering.remap(ids("DF"), offset: 2, optionCount: 4).letters == ids("BD"))
        let unmatched = OptionRelettering.remap(ids("AE"), offset: 1, optionCount: 3)
        #expect(unmatched.letters == ids("DE"))
        #expect(unmatched.unmatched == ids("AE"))
        // A, B (trước lựa chọn đầu C) không được thành lựa chọn mới; chữ thay thế không trùng nhau.
        let crowded = OptionRelettering.remap(ids("DAB"), offset: 2, optionCount: 2)
        #expect(crowded.letters.map(\.description) == ["B", "C", "D"])
        #expect(Set(crowded.letters).count == 3)
    }

    @Test("Nhãn dính cùng đoạn với đáp án được tách; nhãn lặp trong giải thích bị bỏ; nội dung sau nhãn được giữ")
    func gluedLabels() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 2")
        doc.paragraph("Chọn hai đáp án đúng.")
        doc.listItem("Một", numID: 1)
        doc.listItem("Hai", numID: 1)
        doc.listItem("Ba", numID: 1)
        doc.paragraph("Correct Answer: AC Section: Phần B Explanation")
        doc.paragraph("Explanation/Reference: Section: Phần B Explanation")
        doc.paragraph("Explanation/Reference: Giải thích ngay sau nhãn.")
        doc.paragraph("Correct Answer: AC")
        doc.paragraph("Đoạn hai của giải thích.")
        let result = try await importDocx(doc)
        let q = result.questions[0]
        #expect(q.correct.map(\.description) == ["A", "C"])
        #expect(q.type == .multiple)
        #expect(result.sections.map(\.title) == ["Phần B"])
        #expect(q.explanation == "Giải thích ngay sau nhãn.\n\nĐoạn hai của giải thích.")
        #expect(result.report.entries.isEmpty)
    }

    @Test("Đoạn nhãn có dãy khoảng trắng rất dài vẫn tách nhanh (quét tuyến tính)")
    func longWhitespaceLabels() async throws {
        let spaces = String(repeating: " ", count: 40_000)
        let tabs = String(repeating: "\t", count: 40_000)
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.paragraph("Câu hỏi")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: B\(spaces)Section: Phần\(tabs)x\(spaces)Explanation")
        doc.paragraph("Section: Khác\(spaces)B\(spaces)")
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await importDocx(doc)
        let elapsed = clock.now - start
        #expect(elapsed < .seconds(5), "\(elapsed)")
        #expect(result.questions[0].correct == [OptionID("B")!])
        #expect(result.sections.map(\.title) == ["Phần\(tabs)x"].map(TextNormalizer.clean))
    }

    @Test("Phần theo Section: (thứ tự xuất hiện); (none) hoặc thiếu → nhóm gần nhất; không có nhóm → Phần chung")
    func sections() async throws {
        var doc = DocxBuilder()
        doc.paragraph("Tiêu đề")
        Self.listQuestion(&doc, 1, labels: [])                         // không nhóm, không Section → Phần chung
        doc.paragraph("Exam A")
        Self.listQuestion(&doc, 2, labels: ["Section: Mạng"])
        Self.listQuestion(&doc, 3, labels: ["Section: (none) Explanation"])
        Self.listQuestion(&doc, 4, labels: ["Section: Bảo mật"])
        doc.paragraph("Exam B")
        Self.listQuestion(&doc, 5, labels: [])
        Self.listQuestion(&doc, 6, labels: ["Section: Mạng"])
        let result = try await importDocx(doc)
        #expect(result.sections.map(\.title) == ["Phần chung", "Mạng", "Exam A", "Bảo mật", "Exam B"])
        #expect(result.sections.map { $0.questions.count } == [1, 2, 1, 1, 1])
    }

    @Test("Đậm/nghiêng thành Markdown; khoảng trắng ra ngoài dấu; w:val=0 và định dạng của dấu đoạn bị bỏ qua")
    func formatting() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.raw("<w:p><w:pPr><w:rPr><w:b/></w:rPr></w:pPr>"
            + DocxBuilder.run("Chọn ") + DocxBuilder.run("đúng ", bold: true) + DocxBuilder.run("một", italic: true)
            + DocxBuilder.run(" đáp án ", bold: true, italic: true)
            + "<w:r><w:rPr><w:b w:val=\"0\"/></w:rPr><w:t>thường</w:t></w:r></w:p>")
        doc.listItem("Có", numID: 1)
        doc.raw(DocxBuilder.p(runs: [DocxBuilder.run("in đậm", bold: true)], numID: 1))
        doc.paragraph("Correct Answer: A")
        let q = try await importDocx(doc).questions[0]
        #expect(q.text == "Chọn **đúng** *một* ***đáp án*** thường")
        #expect(q.options[1].text == "**in đậm**")
    }

    @Test("Run đậm/nghiêng có dấu câu ở mép, liền chữ: vẫn hiện đậm/nghiêng (không lộ dấu sao)")
    func emphasisNextToPunctuation() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.raw(DocxBuilder.p(runs: [
            DocxBuilder.run("Xem "), DocxBuilder.run("(chú ý)", bold: true), DocxBuilder.run("tiếp và chữ"),
            DocxBuilder.run("(nghiêng)", italic: true), DocxBuilder.run(" cuối"),
        ]))
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: A")
        let text = try await importDocx(doc).questions[0].text
        #expect(text == "Xem **(chú ý**)tiếp và chữ(*nghiêng)* cuối")
        let rendered = try AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        #expect(String(rendered.characters) == "Xem (chú ý)tiếp và chữ(nghiêng) cuối")
        var strong = ""
        var emphasized = ""
        for run in rendered.runs {
            let piece = String(rendered[run.range].characters)
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true { strong += piece }
            if run.inlinePresentationIntent?.contains(.emphasized) == true { emphasized += piece }
        }
        #expect(strong == "(chú ý")
        #expect(emphasized == "nghiêng)")
    }

    @Test("Ngắt dòng trong đoạn thành xuống dòng; chữ đã xoá, mã trường, nhánh Fallback bị bỏ; tab thành dấu cách")
    func runContent() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.raw("<w:p><w:r><w:t>Dòng một</w:t><w:br/><w:t>dòng</w:t><w:tab/><w:t>hai</w:t></w:r>"
            + "<w:del><w:r><w:delText>đã xoá</w:delText></w:r></w:del>"
            + "<w:r><w:instrText> PAGE </w:instrText></w:r>"
            + "<mc:AlternateContent><mc:Choice Requires=\"wps\"><w:r><w:t> (chọn)</w:t></w:r></mc:Choice>"
            + "<mc:Fallback><w:r><w:t> (dự phòng)</w:t></w:r></mc:Fallback></mc:AlternateContent></w:p>")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: A")
        let q = try await importDocx(doc).questions[0]
        #expect(q.text == "Dòng một\ndòng hai (chọn)")
    }

    @Test("Bảng thành văn bản: mỗi hàng một dòng, ô cách nhau ' | ', có cảnh báo")
    func tables() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 7")
        doc.paragraph("Xem bảng:")
        doc.table([["Máy", "IP"], ["web", "10.0.0.1"]])
        doc.listItem("web", numID: 1)
        doc.listItem("db", numID: 1)
        doc.paragraph("Correct Answer: A")
        let result = try await importDocx(doc)
        #expect(result.questions[0].text == "Xem bảng:\n\nMáy | IP\nweb | 10.0.0.1")
        #expect(result.entries(.tableConverted).map(\.location) == [ImportLocation(questionNumber: 7)])
    }

    @Test("Ảnh: ảnh đầu tiên trong đề bài thành ảnh của câu (tên SHA-256); ảnh khác bị bỏ và ghi báo cáo")
    func images() async throws {
        var doc = DocxBuilder()
        doc.addImage("rIdA", name: "image1.png", data: tinyPNG(1))
        doc.addImage("rIdB", name: "image2.png", data: tinyPNG(2))
        doc.addImage("rIdC", name: "image3.emf", data: Data([1, 2, 3]))
        doc.addImage("rIdD", name: "image4.jpeg", data: tinyPNG(4))
        doc.relationships.append(("rIdE", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
                                  "https://example.com/a.png", true))
        doc.relationships.append(("rIdF", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
                                  "media/khong-co.png", false))
        doc.paragraph("Tiêu đề")
        doc.imageParagraph("rIdB")                                     // đầu đề → bỏ
        doc.paragraph("QUESTION 1")
        doc.imageParagraph("rIdC", text: "Sơ đồ:")                     // emf → bỏ, chưa có ảnh
        doc.imageParagraph("rIdE")                                     // liên kết ngoài → bỏ
        doc.imageParagraph("rIdF")                                     // không có trong file → bỏ
        doc.imageParagraph("rIdA")                                     // ảnh dùng được đầu tiên → giữ
        doc.imageParagraph("rIdB")                                     // ảnh thứ hai → bỏ
        doc.listItem("Có", numID: 1)
        doc.imageParagraph("rIdD")                                     // trong lựa chọn → bỏ
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: A")
        doc.paragraph("Explanation/Reference:")
        doc.imageParagraph("rIdD", text: "Hình giải thích")            // trong giải thích → bỏ
        let result = try await importDocx(doc)
        let q = result.questions[0]
        let expectedPath = try MediaNaming.path(for: tinyPNG(1), fileExtension: "png")
        #expect(q.image == expectedPath)
        #expect(result.media == [expectedPath: tinyPNG(1)])
        #expect(q.text == "Sơ đồ:")
        #expect(q.options.map(\.text) == ["Có", "Không"])
        #expect(q.explanation == "Hình giải thích")
        let codes = result.report.entries.map(\.code)
        #expect(codes == [.imageOutsideQuestionText, .unsupportedImageFormat, .imageNotFound, .imageNotFound,
                          .extraImage, .imageOutsideQuestionText, .imageOutsideQuestionText])
        #expect(result.report.entries[0].location == ImportLocation())
        #expect(result.report.entries.dropFirst().allSatisfy { $0.questionID == q.id })

        let (written, reread) = try result.roundTrip(mode: .strict)
        #expect(reread == written)
        #expect(reread.media[expectedPath] == tinyPNG(1))
    }

    @Test("Ảnh chỉ lấy trong word/media/: gốc zip, %2F, ../ vượt gốc bị bỏ và ghi báo cáo")
    func imagesOnlyFromWordMedia() async throws {
        let imageType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
        var doc = DocxBuilder()
        doc.files["secret.png"] = tinyPNG(9)
        doc.files["word/khac/b.png"] = tinyPNG(8)
        doc.files["word/media/ok.png"] = tinyPNG(7)
        doc.relationships += [
            ("rIdAbs", imageType, "/secret.png", false),
            ("rIdEnc", imageType, "..%2Fsecret.png", false),
            ("rIdUp", imageType, "../../secret.png", false),
            ("rIdOther", imageType, "khac/b.png", false),
            ("rIdOk", imageType, "media/../media/ok.png", false),
        ]
        doc.paragraph("QUESTION 1")
        for id in ["rIdAbs", "rIdEnc", "rIdUp", "rIdOther", "rIdOk"] { doc.imageParagraph(id) }
        doc.paragraph("Câu hỏi")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: A")
        let result = try await importDocx(doc)
        let expected = try MediaNaming.path(for: tinyPNG(7), fileExtension: "png")
        #expect(result.questions[0].image == expected)
        #expect(result.media.keys.sorted() == [expected])
        #expect(result.entries(.imageNotFound).count == 4)
    }

    @Test("Ảnh vượt giới hạn kích thước bị bỏ và ghi báo cáo")
    func imageTooLarge() async throws {
        var doc = DocxBuilder()
        doc.addImage("rIdA", name: "big.png", data: Data(repeating: 7, count: 4096))
        doc.paragraph("QUESTION 1")
        doc.imageParagraph("rIdA", text: "Ảnh lớn")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: A")
        var limits = ImportLimits.default
        limits.mediaEntryBytes = 1024
        let result = try await importDocx(doc, limits: limits)
        #expect(result.questions[0].image == nil)
        #expect(result.entries(.imageTooLarge).count == 1)
    }

    @Test("Câu không có lựa chọn bị bỏ; thiếu đáp án được giữ kèm cảnh báo; đáp án lạ cảnh báo")
    func droppedAndKept() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.paragraph("Câu không có lựa chọn")
        doc.paragraph("Correct Answer: A")
        doc.paragraph("QUESTION 2")
        doc.paragraph("Câu thiếu đáp án")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("QUESTION 3")
        doc.paragraph("Câu đáp án lạ")
        doc.listItem("Có", numID: 4)
        doc.listItem("Không", numID: 4)
        doc.paragraph("Correct Answer: ?")
        doc.paragraph("Ghi chú lạc chỗ")
        doc.paragraph("Explanation/Reference:")
        let result = try await importDocx(doc)
        #expect(result.questions.count == 2)
        #expect(result.entries(.noOptions).map(\.location) == [ImportLocation(questionNumber: 1)])
        #expect(result.entries(.missingAnswer).map(\.location) == [ImportLocation(questionNumber: 2)])
        #expect(result.entries(.answerUnreadable).map(\.location) == [ImportLocation(questionNumber: 3)])
        #expect(result.entries(.unrecognizedText).map(\.location) == [ImportLocation(questionNumber: 3)])
        #expect(result.questions[1].options.count == 2)
    }

    @Test("Mojibake chắc chắn trong đoạn (kể cả bị tách nhiều run) được sửa; dãy chỉ nghi thì cảnh báo, giữ chữ")
    func mojibake() async throws {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 9")
        doc.runs(DocxBuilder.run("Itâ€"), DocxBuilder.run("™s ok"))
        doc.listItem("cafÃ©", numID: 1)
        doc.listItem("Tiếng Việt: â và Ã", numID: 1)
        doc.paragraph("Correct Answer: A")
        let result = try await importDocx(doc)
        let q = result.questions[0]
        #expect(q.text == "It’s ok")
        #expect(q.options.map(\.text) == ["cafÃ©", "Tiếng Việt: â và Ã"])
        let fixed = result.entries(.mojibakeFixed)
        #expect(fixed.map(\.location) == [ImportLocation(questionNumber: 9)])
        #expect(fixed.first?.logMessage.contains("1 chỗ") == true)
        let suspected = result.entries(.mojibakeSuspected)
        #expect(suspected.map(\.location) == [ImportLocation(questionNumber: 9)])
        #expect(suspected.first?.logMessage.contains("\"Ã©\"") == true)
    }

    @Test("Không có QUESTION nào: báo lỗi")
    func noQuestions() async {
        var doc = DocxBuilder()
        doc.paragraphs("Chỉ có tiêu đề", "Number: X1")
        await expectImportError(.noQuestions(dropped: 0)) { _ = try await importDocx(doc) }
    }

    @Test("Không có numbering.xml: danh sách coi như gạch đầu dòng, lựa chọn dạng 'A.' vẫn đọc được")
    func withoutNumbering() async throws {
        var doc = DocxBuilder()
        doc.numbering = nil
        doc.paragraph("QUESTION 1")
        doc.listItem("mục", numID: 1)
        doc.paragraphs("A. Có", "B. Không", "Correct Answer: B")
        let q = try await importDocx(doc).questions[0]
        #expect(q.text == "- mục")
        #expect(q.options.map(\.text) == ["Có", "Không"])
    }

    @Test("Đề sinh ra ghi bằng ExamPackageWriter và đọc lại nghiêm ra đúng dữ liệu")
    func roundTrip() async throws {
        var doc = DocxBuilder()
        Self.header(&doc)
        Self.listQuestion(&doc, 1)
        Self.listQuestion(&doc, 2, numID: 4, answer: "A C")
        let result = try await importDocx(doc)
        let (written, reread) = try result.roundTrip(mode: .strict)
        #expect(reread == written)
        #expect(written.exam.code == "ON-042")
        #expect(written.exam.passPercent == 80)
        #expect(written.exam.timeLimitMinutes == 120)
        #expect(reread.exam.allQuestions.map(\.type) == [.single, .multiple])
    }
}
