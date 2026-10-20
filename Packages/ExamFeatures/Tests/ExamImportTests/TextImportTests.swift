import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Quy tắc `.txt` của docs/product/import.md trên file tự soạn.
@Suite("Import .txt")
struct TextImportTests {
    static let basic = """
    Q1:
    Thủ đô của Việt Nam
    là thành phố nào?
    A. Hà Nội
    B. Đà Nẵng
    C. Huế
    D. Cần Thơ
    Correct Answer: A
    Explanation: Hà Nội là thủ đô
    từ năm 1976.

    Q2:
    Chọn hai số chẵn.
    A. 1
    B. 2
    C. 3
    D. 4
    Correct Answer: B,D
    """

    @Test("Câu, lựa chọn, đáp án, giải thích; một phần tên là tên file; tiêu đề gợi ý là tên file")
    func basicStructure() async throws {
        let result = try await importText(Self.basic, fileName: "Kiến thức chung.txt")
        #expect(result.sourceFormat == .txt)
        #expect(result.sections.count == 1)
        #expect(result.sections[0].title == "Kiến thức chung")
        #expect(result.suggestions == ImportSuggestions(title: "Kiến thức chung"))
        #expect(result.report.entries.isEmpty)

        let q = result.questions
        #expect(q.count == 2)
        #expect(q[0].text == "Thủ đô của Việt Nam là thành phố nào?")
        #expect(q[0].options.map(\.id.description) == ["A", "B", "C", "D"])
        #expect(q[0].options.map(\.text) == ["Hà Nội", "Đà Nẵng", "Huế", "Cần Thơ"])
        #expect(q[0].correct == [OptionID("A")!])
        #expect(q[0].type == .single)
        #expect(q[0].explanation == "Hà Nội là thủ đô từ năm 1976.")
        #expect(q[1].type == .multiple)
        #expect(q[1].correct.map(\.description) == ["B", "D"])
        #expect(q[1].explanation == nil)
    }

    @Test("id đề, phần, câu ngẫu nhiên mỗi lần import")
    func randomIDs() async throws {
        let a = try await importText(Self.basic)
        let b = try await importText(Self.basic)
        #expect(a.examID != b.examID)
        #expect(a.sections[0].id != b.sections[0].id)
        #expect(Set(a.questions.map(\.id)).isDisjoint(with: b.questions.map(\.id)))
        let ids = [a.examID, a.sections[0].id] + a.questions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Nối dòng bằng dấu cách, gạch nối cuối dòng nối liền, dòng trống tách đoạn")
    func lineJoining() async throws {
        let text = """
        Q1:
        Dịch vụ sao chép Cross-
        Region giúp
        sao lưu dữ liệu.

        Đoạn thứ hai -
        vẫn có dấu cách.
        A. Lựa chọn dài
        nối sang dòng sau
        B. Hai
        Correct Answer: A
        """
        let q = try await importText(text).questions[0]
        #expect(q.text == "Dịch vụ sao chép Cross-Region giúp sao lưu dữ liệu.\n\nĐoạn thứ hai - vẫn có dấu cách.")
        #expect(q.options[0].text == "Lựa chọn dài nối sang dòng sau")
    }

    @Test("Đầu câu: Q<số>: hoặc QUESTION <số>, không phân biệt hoa thường; dòng phải chỉ gồm đầu câu")
    func questionHeads() async throws {
        let text = """
        q7:
        Câu bảy
        A) Có
        B) Không
        Answer: A
        Question 12
        Câu mười hai
        A. X
        B. Y
        Correct Answer: B
        QUESTION 3 có chữ phía sau không phải đầu câu
        Explanation: hết
        """
        let result = try await importText(text)
        #expect(result.questions.count == 2)
        #expect(result.questions[0].options.map(\.text) == ["Có", "Không"])
        #expect(result.questions[0].correct == [OptionID("A")!])
        #expect(result.questions[1].text == "Câu mười hai")
        #expect(result.entries(.unrecognizedText).map(\.location) == [ImportLocation(questionNumber: 12, line: 11)])
    }

    @Test("Đáp án A,C / A C / AC / A, C đều thành Nhiều đáp án")
    func answerForms() async throws {
        for form in ["A,C", "A C", "AC", "A, C"] {
            let text = "Q1:\nCâu\nA. a\nB. b\nC. c\nCorrect Answer: \(form)\n"
            let q = try await importText(text).questions[0]
            #expect(q.correct.map(\.description) == ["A", "C"], "\(form)")
            #expect(q.type == .multiple)
        }
    }

    @Test("Lựa chọn sai thứ tự: dòng nối của lựa chọn trước, có cảnh báo; chữ trùng cũng vậy")
    func optionOrder() async throws {
        let text = """
        Q5:
        Câu hỏi
        A. Một
        C. Hai (thiếu B)
        B. Ba
        B. Bốn (trùng B)
        Correct Answer: A
        """
        let result = try await importText(text)
        let q = result.questions[0]
        #expect(q.options.map(\.text) == ["Một C. Hai (thiếu B)", "Ba B. Bốn (trùng B)"])
        let warnings = result.entries(.optionLabelOutOfOrder)
        #expect(warnings.map(\.location) == [ImportLocation(questionNumber: 5, line: 4), ImportLocation(questionNumber: 5, line: 6)])
        #expect(warnings.allSatisfy { $0.questionID == q.id && $0.severity == .warning })
    }

    @Test("Câu không có lựa chọn bị bỏ, báo cáo nêu vị trí")
    func droppedQuestion() async throws {
        let text = """
        Q1:
        Câu tốt
        A. Có
        B. Không
        Correct Answer: A
        Q2:
        Câu không có lựa chọn nào
        Correct Answer: A
        Q3:
        Nhãn lựa chọn nằm sau dòng đáp án
        Correct Answer: B
        B. Hai
        """
        let result = try await importText(text)
        #expect(result.questions.count == 1)
        #expect(result.report.droppedCount == 2)
        let dropped = result.entries(.noOptions)
        #expect(dropped.map(\.location) == [ImportLocation(questionNumber: 2, line: 6), ImportLocation(questionNumber: 3, line: 9)])
        #expect(dropped.allSatisfy { $0.questionID == nil && $0.severity == .dropped })
    }

    @Test("Không có dòng A.: lựa chọn bắt đầu từ nhãn đầu tiên, đánh lại A, B, C…; đáp án đổi theo vị trí; cảnh báo")
    func shiftedOptions() async throws {
        let text = """
        Q1:
        Câu thiếu lựa chọn A
        B. Hai
        C. Ba
        D. Bốn
        E. Năm
        Correct Answer: C
        Q2:
        Nhiều đáp án, bắt đầu từ C)
        C) một
        nối dòng
        D) hai
        E) ba
        F) bốn
        Correct Answer: D,F
        Q3:
        Đáp án không khớp lựa chọn nào
        B. x
        C. y
        D. z
        Correct Answer: A,E
        Q4:
        Phải liên tiếp từ chữ đầu
        B. một
        C. hai
        E. ba
        Correct Answer: B
        """
        let result = try await importText(text)
        #expect(result.report.droppedCount == 0)
        let q = result.questions
        #expect(q.count == 4)
        #expect(q[0].options.map(\.id.description) == ["A", "B", "C", "D"])
        #expect(q[0].options.map(\.text) == ["Hai", "Ba", "Bốn", "Năm"])
        #expect(q[0].correct == [OptionID("B")!])
        #expect(q[0].type == .single)
        #expect(q[1].options.map(\.text) == ["một nối dòng", "hai", "ba", "bốn"])
        #expect(q[1].correct.map(\.description) == ["B", "D"])
        #expect(q[1].type == .multiple)
        // A đứng trước lựa chọn đầu, E sau lựa chọn cuối: cả hai vẫn là vi phạm (không khớp lựa chọn A–C).
        #expect(q[2].options.count == 3)
        #expect(q[2].correct.map(\.description) == ["D", "E"])
        #expect(q[3].options.map(\.text) == ["một", "hai E. ba"])
        #expect(q[3].correct == [OptionID("A")!])

        let shifted = result.entries(.optionLabelsShifted)
        #expect(shifted.map(\.location) == [ImportLocation(questionNumber: 1, line: 3), ImportLocation(questionNumber: 2, line: 10),
                                            ImportLocation(questionNumber: 3, line: 18), ImportLocation(questionNumber: 4, line: 24)])
        #expect(shifted.allSatisfy { $0.severity == .warning })
        #expect(shifted[0].logMessage.contains("B–E (lựa chọn đầu tiên là dòng 3) được đánh lại A–D"))
        #expect(shifted[0].logMessage.contains("Đáp án C → B"))
        #expect(shifted[2].logMessage.contains("Đáp án A, E không khớp lựa chọn nào"))
        #expect(result.entries(.optionLabelOutOfOrder).map(\.location) == [ImportLocation(questionNumber: 4, line: 26)])
        let codes = try result.roundTrip().written.validationIssues.map(\.code)
        #expect(codes.contains(.correctAnswerNotInOptions))
    }

    @Test("Thiếu A, đề bài có dòng 'C. …': dòng đó là lựa chọn đầu tiên (nhãn đầu tiên), cảnh báo nêu đúng dòng")
    func shiftedStartsAtStemLabel() async throws {
        let text = """
        Q1:
        Câu hỏi
        C. dòng đề bài có nhãn C
        B. một
        C. hai
        D. ba
        Correct Answer: D
        """
        let result = try await importText(text)
        let q = result.questions[0]
        #expect(q.text == "Câu hỏi")
        #expect(q.options.map(\.text) == ["dòng đề bài có nhãn C B. một C. hai", "ba"])
        #expect(q.correct == [OptionID("B")!])
        let shifted = result.entries(.optionLabelsShifted)
        #expect(shifted.map(\.location) == [ImportLocation(questionNumber: 1, line: 3)])
        #expect(shifted.first?.logMessage.contains("lựa chọn đầu tiên là dòng 3") == true)
        #expect(result.entries(.optionLabelOutOfOrder).map(\.location.line) == [4, 5])
    }

    @Test("Có dòng A. thì giữ quy tắc cũ, kể cả khi dòng A. đứng sau nhãn khác")
    func optionAPresent() async throws {
        let text = """
        Q1:
        Các ý: C. không phải lựa chọn
        C. ý phụ trong đề bài
        A. Có
        B. Không
        Correct Answer: A
        """
        let result = try await importText(text)
        let q = result.questions[0]
        #expect(q.text == "Các ý: C. không phải lựa chọn C. ý phụ trong đề bài")
        #expect(q.options.map(\.text) == ["Có", "Không"])
        #expect(result.entries(.optionLabelsShifted).isEmpty)
    }

    @Test("Vi phạm khác được giữ: thiếu đáp án, đáp án không đọc được, đáp án ngoài lựa chọn, một lựa chọn")
    func violationsKept() async throws {
        let text = """
        Q1:
        Thiếu dòng đáp án
        A. a
        B. b
        Q2:
        Đáp án lạ
        A. a
        B. b
        Correct Answer: A và B
        Q3:
        Đáp án ngoài lựa chọn
        A. a
        B. b
        Correct Answer: E
        Q4:
        Một lựa chọn
        A. a
        Correct Answer: A
        """
        let result = try await importText(text)
        #expect(result.questions.count == 4)
        #expect(result.entries(.missingAnswer).map(\.location.questionNumber) == [1])
        #expect(result.entries(.answerUnreadable).map(\.location) == [ImportLocation(questionNumber: 2, line: 9)])
        #expect(result.questions[0].correct.isEmpty)
        #expect(result.questions[1].correct.isEmpty)
        #expect(result.questions[2].correct == [OptionID("E")!])
        #expect(result.questions[3].options.count == 1)
        let codes = Set(try result.roundTrip().written.validationIssues.map(\.code))
        #expect(codes.isSuperset(of: [.noCorrectAnswer, .correctAnswerNotInOptions, .tooFewOptions]))
    }

    @Test("Hai dòng đáp án khác nhau: giữ dòng đầu, cảnh báo; trùng thì không cảnh báo")
    func conflictingAnswers() async throws {
        let text = """
        Q1:
        Câu
        A. a
        B. b
        Correct Answer: A
        Correct Answer: A
        Correct Answer: B
        """
        let result = try await importText(text)
        #expect(result.questions[0].correct == [OptionID("A")!])
        #expect(result.entries(.conflictingAnswer).map(\.location) == [ImportLocation(questionNumber: 1, line: 7)])
    }

    @Test("Giải thích nhiều dòng tới câu kế; dòng 'Answer:' trong giải thích là nội dung khi đã có đáp án")
    func explanationLines() async throws {
        let text = """
        Q1:
        Câu
        A. a
        B. b
        Correct Answer: B
        Explanation:
        Answer: B vì lý do
        thứ nhất.

        Đoạn hai.
        Q2:
        Câu hai
        A. a
        B. b
        Explanation: Giải thích trước đáp án
        Correct Answer: A
        """
        let result = try await importText(text)
        #expect(result.questions[0].explanation == "Answer: B vì lý do thứ nhất.\n\nĐoạn hai.")
        #expect(result.questions[0].correct == [OptionID("B")!])
        #expect(result.questions[1].correct == [OptionID("A")!])
        #expect(result.questions[1].explanation == "Giải thích trước đáp án")
        #expect(result.entries(.conflictingAnswer).isEmpty)
    }

    @Test("Văn bản trước câu đầu tiên bị bỏ qua và ghi báo cáo")
    func preamble() async throws {
        let text = "Bộ câu hỏi ôn tập\nPhiên bản 1\n\nQ1:\nCâu\nA. a\nB. b\nCorrect Answer: A\n"
        let result = try await importText(text)
        #expect(result.entries(.textBeforeFirstQuestion).map(\.location) == [ImportLocation(line: 1)])
        #expect(result.questions[0].text == "Câu")
    }

    @Test("UTF-8 có BOM, xuống dòng CRLF; chuỗi chuẩn hoá NFC, bỏ khoảng trắng hai đầu")
    func encodingAndNormalization() async throws {
        let decomposed = "Tie\u{0302}\u{0301}ng Vie\u{0323}\u{0302}t" // "Tiếng Việt" dạng NFD
        let text = "Q1:\r\n  \(decomposed)  \r\nA.   Lựa chọn\u{00A0}\r\nB. b\r\nCorrect Answer: A\r\n"
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(text.utf8))
        let result = try await ExamImporter.importData(data, fileName: "De.txt")
        let q = result.questions[0]
        #expect(q.text == "Tiếng Việt")
        #expect(q.text.unicodeScalars.count == "Tiếng Việt".precomposedStringWithCanonicalMapping.unicodeScalars.count)
        #expect(q.options[0].text == "Lựa chọn")
    }

    @Test("Không phải UTF-8 thì báo lỗi: Windows-1258, UTF-16 có BOM, UTF-16 không BOM")
    func notUTF8() async {
        let latin = Data([0x51, 0x31, 0x3A, 0x0A, 0xC0, 0xE0, 0x0A]) // byte đơn lẻ ≥ 0x80
        let utf16 = "Q1:\nCâu\nA. a\n".data(using: .utf16)!
        let utf16NoBOM = "Q1:\nA. a\n".data(using: .utf16LittleEndian)!
        for data in [latin, utf16, utf16NoBOM] {
            await expectImportError(.notUTF8) {
                _ = try await ExamImporter.importData(data, fileName: "x.txt")
            }
        }
    }

    @Test("Ký tự Markdown trong văn bản trơn được thoát khi cần, để hiển thị đúng như file")
    func markdownEscaping() async throws {
        let text = """
        Q1:
        Tính 2 *3* và a_b_c
        A. Quyền s3:* trên arn:aws:s3:::bucket/*
        B. Thẻ <b> & &amp;
        Correct Answer: A
        """
        let q = try await importText(text).questions[0]
        #expect(q.text == "Tính 2 \\*3\\* và a\\_b\\_c")
        #expect(q.options[0].text == "Quyền s3:* trên arn:aws:s3:::bucket/*")
        #expect(q.options[1].text == "Thẻ \\<b\\> \\& \\&amp;")
        for source in [q.text, q.options[1].text] {
            let rendered = try AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            #expect(!String(rendered.characters).contains("\\"))
        }
    }

    @Test("Không có câu nào, hoặc mọi câu đều bị bỏ: báo lỗi, không có đề")
    func noQuestions() async {
        await expectImportError(.noQuestions(dropped: 0)) { _ = try await importText("Chỉ là ghi chú\nkhông có câu.\n") }
        await expectImportError(.noQuestions(dropped: 1)) { _ = try await importText("Q1:\nCâu\nCorrect Answer: A\n") }
        await expectImportError(.noQuestions(dropped: 0)) { _ = try await importText("") }
    }

    @Test("Đề sinh ra ghi bằng ExamPackageWriter và đọc lại (nghiêm và dễ) ra đúng dữ liệu")
    func roundTrip() async throws {
        let result = try await importText(Self.basic)
        let package = result.makePackage(ImportConfirmation(title: "  Đề ôn tập  ", code: "ON-01", passPercent: 70,
                                                            timeLimitMinutes: 45))
        #expect(package.exam.id == result.examID)
        #expect(package.exam.title == "Đề ôn tập")
        #expect(package.exam.code == "ON-01")
        #expect(package.exam.passPercent == 70)
        #expect(package.exam.timeLimitMinutes == 45)
        #expect(package.exam.sections == result.sections)
        #expect(package.validationIssues.isEmpty)
        let data = try ExamPackageWriter.write(package)
        #expect(try ExamPackageReader.read(data, mode: .strict) == package)
        #expect(try ExamPackageReader.read(data, mode: .lenient) == package)
        // Mã rỗng thành nil.
        let noCode = result.makePackage(ImportConfirmation(title: "Đề", code: "  ", passPercent: 50, timeLimitMinutes: 10))
        #expect(noCode.exam.code == nil)
    }

    @Test("Mojibake chắc chắn được tự sửa, dãy chỉ nghi được cảnh báo; mỗi loại một cảnh báo mỗi câu")
    func mojibake() async throws {
        let text = """
        Q1:
        Itâ€™s the companyâ€™s â€œbestâ€\u{9D} option
        A. cafÃ©
        B. Tiếng Việt: â, Ã đứng riêng
        Correct Answer: A
        Q2:
        Không có lỗi
        A. a
        B. b
        Correct Answer: A
        """
        let result = try await importText(text)
        let q = result.questions
        #expect(q[0].text == "It’s the company’s “best” option")
        #expect(q[0].options.map(\.text) == ["cafÃ©", "Tiếng Việt: â, Ã đứng riêng"])
        let fixed = result.entries(.mojibakeFixed)
        #expect(fixed.count == 1)
        #expect(fixed[0].location == ImportLocation(questionNumber: 1, line: 2))
        #expect(fixed[0].questionID == q[0].id)
        #expect(fixed[0].logMessage.contains("4 chỗ"))
        #expect(fixed[0].logMessage.contains("\"â€™\" → \"’\" (2 lần)"))
        let suspected = result.entries(.mojibakeSuspected)
        #expect(suspected.map(\.location) == [ImportLocation(questionNumber: 1, line: 3)])
        #expect(suspected[0].logMessage.contains("1 chỗ"))
        #expect(suspected[0].logMessage.contains("\"Ã©\""))
    }

    @Test("Chữ hoa có dấu sát dấu ngoặc, ®, NBSP không bị đổi; chỉ cảnh báo nghi lỗi")
    func mojibakeNoFalseRepair() async throws {
        let text = "Q1:\nTrả lời “CÓ” hoặc “LÊ” hoặc “ĐÃ”\nA. KHÔ\u{A0}RÁO\nB. NESCAFÉ® 5×\u{A0}3\nCorrect Answer: A\n"
        let result = try await importText(text)
        let q = result.questions[0]
        #expect(q.text == "Trả lời “CÓ” hoặc “LÊ” hoặc “ĐÃ”")
        #expect(q.options.map(\.text) == ["KHÔ\u{A0}RÁO", "NESCAFÉ® 5×\u{A0}3"])
        #expect(result.entries(.mojibakeFixed).isEmpty)
        let suspected = result.entries(.mojibakeSuspected)
        #expect(suspected.count == 1)
        #expect(suspected[0].logMessage.contains("6 chỗ"))
    }

    @Test("Giới hạn kích thước file .txt")
    func sizeLimit() async {
        var limits = ImportLimits.default
        limits.textBytes = 10
        await expectImportError(.tooLarge(what: .textFile, limit: 10)) {
            _ = try await importText(Self.basic, limits: limits)
        }
    }
}
