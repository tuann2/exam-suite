import AppKit
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import ImageIO
import PDFKit
import ReportFeature
import Testing
import UniformTypeIdentifiers

/// Model của PDF đề (docs/product/export-print.md, mục Bản Admin: PDF và In đề) và PDF thật đọc lại bằng PDFKit: hai
/// kiểu (Có đáp án và giải thích / Chỉ đề), thứ tự file, đánh số liên tục toàn đề, nhãn theo vị trí, ảnh, đề đang soạn
/// còn lỗi (in đúng như đang soạn), chân trang, tên file gợi ý, chữ tiếng Việt đọc lại nguyên văn.
@MainActor
@Suite("PDF đề (Admin)", .serialized)
struct ExamReportTests {
    // MARK: - Đề thử

    static func option(_ index: Int, _ text: String) -> Option {
        Option(id: OptionID(index: index)!, text: text)
    }

    /// Đề hai phần; mỗi câu có giải thích riêng để kiểm ẩn/hiện; câu 3 nhiều đáp án; câu 2 có ảnh.
    static func exam(hideAnswers: Bool = false, code: String? = "DL-01", instructions: String? = "Đọc **kỹ** đề.") -> Exam {
        Exam(
            id: fixedID(1),
            title: "Địa lý Đông Nam Á",
            code: code,
            passPercent: 70,
            timeLimitMinutes: 45,
            hideAnswers: hideAnswers,
            instructions: instructions,
            sections: [
                ExamSection(id: fixedID(2), title: "Địa hình", questions: [
                    Question(
                        id: fixedID(11), type: .single, text: "Đỉnh núi cao nhất Đông Dương?",
                        options: [option(0, "Phan Xi Păng"), option(1, "Ngọc Linh"), option(2, "Bạch Mã")],
                        correct: [OptionID(index: 0)!], explanation: "Lời giải một: Phan Xi Păng cao 3.143 m."
                    ),
                    Question(
                        id: fixedID(12), type: .single, text: "Đồng bằng nào lớn nhất?", image: "media/anh.png",
                        options: [option(0, "Sông Hồng"), option(1, "Sông Cửu Long")],
                        correct: [OptionID(index: 1)!], explanation: "Lời giải hai."
                    ),
                ]),
                ExamSection(id: fixedID(3), title: "Dân cư", questions: [
                    Question(
                        id: fixedID(13), type: .multiple, text: "Đô thị nào thuộc vùng Đông Nam Bộ?",
                        options: [option(0, "Biên Hoà"), option(1, "Đà Lạt"), option(2, "Thủ Dầu Một"), option(3, "Huế")],
                        correct: [OptionID(index: 0)!, OptionID(index: 2)!], explanation: "Lời giải ba."
                    ),
                ]),
            ]
        )
    }

    static func report(_ exam: Exam = exam(), media: [String: Data] = [:], kind: ExamReportKind) -> ExamReport {
        ExamReport(package: ExamPackage(exam: exam, media: media), kind: kind, appVersion: "9.9")
    }

    static func questions(_ document: ReportDocument) -> [ReportQuestion] {
        document.blocks.compactMap { if case let .question(question) = $0 { question } else { nil } }
    }

    static func headings(_ document: ReportDocument) -> [ReportHeading] {
        document.blocks.compactMap { if case let .heading(heading) = $0 { heading } else { nil } }
    }

    /// Khối đầu (đầu trang đầu); nil nếu khối đầu không phải đầu trang.
    static func title(_ document: ReportDocument) -> ReportTitle? {
        if case let .title(title) = document.blocks.first { title } else { nil }
    }

    static func png(width: Int = 400, height: Int = 200) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.5, green: 0.1, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func render(_ report: ExamReport) async throws -> PDFDocument {
        let pdf = try await ReportRenderer().render(report.document())
        let reader = try #require(PDFDocument(data: pdf.data))
        #expect(reader.pageCount == pdf.pageCount)
        #expect(pdf.pageCount > 0)
        return reader
    }

    // MARK: - Model

    @Test("Đầu trang đầu: tên đề, mã đề, số câu, số phần, thời gian Thi, ngưỡng đậu (% và thang 1000), hướng dẫn")
    func header() throws {
        let document = Self.report(kind: .questionsOnly).document()
        let title = try #require(Self.title(document))
        #expect(title.title == "Địa lý Đông Nam Á")
        #expect(title.subtitle == nil)
        #expect(title.fields.map(\.label) == ["Mã đề", "Số câu", "Số phần", "Thời gian Thi", "Ngưỡng đậu"])
        #expect(title.fields.map(\.value) == ["DL-01", "3", "2", "45 phút", "70% · 700/1000"])
        #expect(title.instructions == "Đọc **kỹ** đề.")

        // Không mã đề, không hướng dẫn (hay hướng dẫn chỉ khoảng trắng): không có dòng đó.
        let bare = try #require(Self.title(Self.report(Self.exam(code: nil, instructions: "  \n"), kind: .withAnswers).document()))
        #expect(bare.fields.map(\.label) == ["Số câu", "Số phần", "Thời gian Thi", "Ngưỡng đậu"])
        #expect(bare.instructions == nil)
    }

    /// accessibility-localization.md, mục Ngôn ngữ (bước 7a): số theo ngôn ngữ giao diện (vi khoá trong test), không theo
    /// Region; thang 1000 giữ số trơn (chờ Nt0 chốt).
    @Test("Số từ 1.000 có ngăn nghìn theo ngôn ngữ giao diện: Số câu, đề mục phần, vị trí câu")
    func largeCountsUseInterfaceGrouping() throws {
        let questions = (0 ..< 1234).map { index in
            Question(
                id: fixedID(1000 + index), type: .single, text: "Câu hỏi \(index + 1)",
                options: [Self.option(0, "Có"), Self.option(1, "Không")], correct: [OptionID(index: 0)!]
            )
        }
        var exam = Self.exam()
        exam.passPercent = 100
        exam.sections = [ExamSection(id: fixedID(2), title: "Một phần", questions: questions)]
        let document = Self.report(exam, kind: .questionsOnly).document()
        let fields = try #require(Self.title(document)).fields
        #expect(fields.first { $0.label == "Số câu" }?.value == "1.234")
        #expect(fields.first { $0.label == "Ngưỡng đậu" }?.value == "100% · 1000/1000")
        #expect(Self.headings(document).map(\.detail) == ["1.234 câu"])
        #expect(Self.questions(document).last?.positionText == "Câu 1.234/1.234")
    }

    @Test("Đề hideAnswers: đầu trang có “Ẩn đáp án”, ở cả hai kiểu; kiểu Có đáp án vẫn có đáp án (admin có file đề)")
    func hideAnswersHeader() throws {
        for kind in ExamReportKind.allCases {
            let document = Self.report(Self.exam(hideAnswers: true), kind: kind).document()
            let fields = try #require(Self.title(document)).fields
            #expect(fields.last == ReportField(label: "Ẩn đáp án", value: "Có"), "\(kind)")
            let marks = Self.questions(document).flatMap(\.options).flatMap(\.marks)
            #expect(marks.isEmpty == (kind == .questionsOnly), "\(kind)")
        }
    }

    @Test("Mỗi phần là đề mục; câu đánh số liên tục toàn đề theo thứ tự file; lựa chọn theo thứ tự file, nhãn A, B, C…")
    func sectionsAndNumbering() {
        let document = Self.report(kind: .withAnswers).document()
        #expect(Self.headings(document).map(\.title) == ["Địa hình", "Dân cư"])
        #expect(Self.headings(document).map(\.detail) == ["2 câu", "1 câu"])
        // Khối theo đúng thứ tự: đầu trang, phần 1, câu 1, câu 2, phần 2, câu 3.
        let kinds = document.blocks.map { block -> String in
            switch block {
            case .title: "title"
            case let .heading(heading): "heading:\(heading.title)"
            case let .question(question): "question:\(question.number)"
            default: "other"
            }
        }
        #expect(kinds == ["title", "heading:Địa hình", "question:1", "question:2", "heading:Dân cư", "question:3"])
        let questions = Self.questions(document)
        #expect(questions.map(\.positionText) == ["Câu 1/3", "Câu 2/3", "Câu 3/3"])
        #expect(questions.map(\.sectionTitle) == ["Địa hình", "Địa hình", "Dân cư"])
        #expect(questions.map(\.text) == [
            "Đỉnh núi cao nhất Đông Dương?", "Đồng bằng nào lớn nhất?", "Đô thị nào thuộc vùng Đông Nam Bộ?",
        ])
        #expect(questions[2].options.map(\.label) == ["A", "B", "C", "D"])
        #expect(questions[2].options.map(\.text) == ["Biên Hoà", "Đà Lạt", "Thủ Dầu Một", "Huế"])
        // Không có trạng thái làm bài hay đánh dấu (chỉ PDF kết quả có).
        #expect(questions.allSatisfy { $0.status == nil && $0.flag == nil && $0.notices.isEmpty })
    }

    @Test("Có đáp án: “Đáp án đúng” đúng trên lựa chọn đúng và có Giải thích; Chỉ đề: không có cả hai")
    func answersByKind() {
        let withAnswers = Self.questions(Self.report(kind: .withAnswers).document())
        #expect(withAnswers.map { $0.options.map { !$0.marks.isEmpty } } == [
            [true, false, false], [false, true], [true, false, true, false],
        ])
        #expect(withAnswers.flatMap(\.options).flatMap(\.marks).allSatisfy { $0.title == "Đáp án đúng" })
        #expect(withAnswers.flatMap(\.options).allSatisfy { $0.isEmphasized == !$0.marks.isEmpty })
        #expect(withAnswers.map(\.explanation) == ["Lời giải một: Phan Xi Păng cao 3.143 m.", "Lời giải hai.", "Lời giải ba."])

        let questionsOnly = Self.questions(Self.report(kind: .questionsOnly).document())
        #expect(questionsOnly.flatMap(\.options).allSatisfy { $0.marks.isEmpty && !$0.isEmphasized })
        #expect(questionsOnly.allSatisfy { $0.explanation == nil })
        // Gợi ý "Chọn N đáp án" ở cả hai kiểu (như cửa sổ làm bài: học viên cũng thấy), chỉ câu nhiều đáp án.
        #expect(withAnswers.map(\.hint) == [nil, nil, "Chọn 2 đáp án"])
        #expect(questionsOnly.map(\.hint) == [nil, nil, "Chọn 2 đáp án"])
    }

    @Test("Ảnh: có trong gói thì byte ảnh; thiếu hoặc sai tên (không có trong gói) thì .missing; câu không ảnh thì nil")
    func images() throws {
        let data = try Self.png()
        let withImage = Self.questions(Self.report(media: ["media/anh.png": data], kind: .questionsOnly).document())
        #expect(withImage.map(\.image) == [nil, .data(data), nil])
        let missing = Self.questions(Self.report(kind: .questionsOnly).document())
        #expect(missing.map(\.image) == [nil, .missing, nil])
    }

    @Test("Đề đang soạn còn lỗi: in đúng như đang soạn (tên rỗng như cây đề, phần rỗng, câu chưa có đáp án đúng, id lệch vị trí)")
    func invalidDraftPrintsAsIs() throws {
        var exam = Self.exam()
        exam.title = "  "
        exam.sections[0].title = ""
        exam.sections.insert(ExamSection(id: fixedID(4), title: "Phần trống", questions: []), at: 1)
        // Câu nhiều đáp án chưa có đáp án đúng, nội dung rỗng, lựa chọn rỗng.
        exam.sections[2].questions.append(Question(
            id: fixedID(14), type: .multiple, text: "",
            options: [Self.option(0, ""), Self.option(1, "Có chữ")], correct: []
        ))
        // Id lựa chọn không theo vị trí (đề đọc dễ): nhãn theo vị trí, đáp án đúng theo id như xem trước.
        exam.sections[2].questions.append(Question(
            id: fixedID(15), type: .single, text: "Id lệch",
            options: [Self.option(1, "Mang id B"), Self.option(0, "Mang id A")], correct: [OptionID(index: 0)!]
        ))
        let document = Self.report(exam, kind: .withAnswers).document()
        #expect(try #require(Self.title(document)).title == "(Đề chưa có tên)")
        #expect(document.footer.title == "(Đề chưa có tên)")
        #expect(document.metadata.title == "(Đề chưa có tên) – Đề")
        #expect(Self.headings(document).map(\.title) == ["(Phần chưa có tên)", "Phần trống", "Dân cư"])
        #expect(Self.headings(document).map(\.detail) == ["2 câu", "0 câu", "3 câu"])
        let questions = Self.questions(document)
        #expect(questions.map(\.number) == [1, 2, 3, 4, 5])
        #expect(questions.map(\.positionText) == ["Câu 1/5", "Câu 2/5", "Câu 3/5", "Câu 4/5", "Câu 5/5"])
        #expect(questions[3].text == "")
        #expect(questions[3].hint == "Chọn 0 đáp án")
        #expect(questions[3].options.map(\.text) == ["", "Có chữ"])
        #expect(questions[3].options.allSatisfy { $0.marks.isEmpty })
        #expect(questions[4].options.map(\.label) == ["A", "B"])
        #expect(questions[4].options.map { !$0.marks.isEmpty } == [false, true])
        // Tên file vẫn từ tên đề thật (rỗng: ReportFileName tự xử lý).
        #expect(Self.report(exam, kind: .withAnswers).suggestedFileName.hasSuffix(".pdf"))
    }

    @Test("Chân trang: tên đề; mã đề và “Có đáp án” (kiểu Có đáp án); không có thời điểm xuất. Siêu dữ liệu: Title, Creator")
    func footerAndMetadata() {
        let withAnswers = Self.report(kind: .withAnswers).document()
        #expect(withAnswers.footer.title == "Địa lý Đông Nam Á")
        #expect(withAnswers.footer.lines == ["Mã đề: DL-01 · Có đáp án"])
        #expect(withAnswers.metadata == ReportMetadata(title: "Địa lý Đông Nam Á – Đề", creator: "Exam Suite 9.9"))

        #expect(Self.report(kind: .questionsOnly).document().footer.lines == ["Mã đề: DL-01"])
        #expect(Self.report(Self.exam(code: nil), kind: .withAnswers).document().footer.lines == ["Có đáp án"])
        #expect(Self.report(Self.exam(code: nil), kind: .questionsOnly).document().footer.lines.isEmpty)
    }

    @Test("Tên file gợi ý và tên việc in: “<Tên đề> (có đáp án).pdf” / “<Tên đề> (đề).pdf”; tên việc in bỏ .pdf")
    func fileNames() {
        let withAnswers = Self.report(kind: .withAnswers)
        #expect(withAnswers.suggestedFileName == "Địa lý Đông Nam Á (có đáp án).pdf")
        #expect(withAnswers.jobTitle == "Địa lý Đông Nam Á (có đáp án)")
        let questionsOnly = Self.report(kind: .questionsOnly)
        #expect(questionsOnly.suggestedFileName == "Địa lý Đông Nam Á (đề).pdf")
        #expect(questionsOnly.jobTitle == "Địa lý Đông Nam Á (đề)")
        // Ký tự cấm, NFC, 120 ký tự: giữ "(có đáp án)", cắt tên đề (ReportFileName).
        var long = Self.exam()
        long.title = "Tiê\u{0301}ng: Việt/" + String(repeating: "Đề dài ", count: 40)
        let name = Self.report(long, kind: .withAnswers).suggestedFileName
        #expect(name.hasSuffix(" (có đáp án).pdf"))
        #expect(!name.contains("/") && !name.contains(":"))
        #expect(name == name.precomposedStringWithCanonicalMapping)
        #expect((name as NSString).deletingPathExtension.count <= 120)
    }

    @Test("Kiểu: hai lựa chọn theo thứ tự của hộp chọn, chữ theo export-print.md")
    func kindTitles() {
        #expect(ExamReportKind.allCases.map(\.title) == ["Có đáp án và giải thích", "Chỉ đề (không đáp án)"])
    }

    // MARK: - PDF thật

    @Test("PDF Có đáp án đọc lại: tên đề, câu, “Đáp án đúng”, giải thích, chân trang mọi trang; Đ không thành Ð; A4")
    func withAnswersPDF() async throws {
        let reader = try await render(Self.report(media: ["media/anh.png": try Self.png()], kind: .withAnswers))
        let text = try #require(reader.string)
        for expected in [
            "Địa lý Đông Nam Á", "Mã đề", "DL-01", "45 phút", "70% · 700/1000", "Địa hình", "Dân cư",
            "Câu 1/3", "Đỉnh núi cao nhất Đông Dương?", "Phan Xi Păng", "Đáp án đúng", "Chọn 2 đáp án",
            "Giải thích", "Lời giải một: Phan Xi Păng cao 3.143 m.", "Lời giải ba.", "Có đáp án",
        ] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        #expect(!text.contains("\u{00D0}"), "Ð (U+00D0) xuất hiện: phông vẽ chữ Đ sai")
        #expect(!text.contains("Không hiện được ảnh"), "ảnh có trong gói phải vẽ được")
        #expect(!text.contains("Xuất bằng") && !text.contains("Exam Suite 9.9"), "PDF không ghi thời điểm/phiên bản xuất")
        for index in 0 ..< reader.pageCount {
            let page = try #require(reader.page(at: index))
            #expect(page.bounds(for: .mediaBox).size == CGSize(width: 595, height: 842))
            let pageText = page.string ?? ""
            #expect(pageText.contains("Trang \(index + 1)/\(reader.pageCount)"))
            #expect(pageText.contains("Mã đề: DL-01 · Có đáp án"))
        }
        let attributes = reader.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == "Địa lý Đông Nam Á – Đề")
        #expect(attributes[PDFDocumentAttribute.creatorAttribute] as? String == "Exam Suite 9.9")
    }

    @Test("Không có trang bìa riêng (phương án 19): trang 1 có cả thông tin đề, đề mục Phần 1 và câu 1, ở cả hai kiểu")
    func firstPageHasHeaderAndFirstQuestion() async throws {
        for kind in ExamReportKind.allCases {
            let reader = try await render(Self.report(kind: kind))
            let firstPage = try #require(reader.page(at: 0)?.string)
            for expected in ["Địa lý Đông Nam Á", "Số câu", "45 phút", "Đọc kỹ đề.", "Địa hình", "Câu 1/3",
                             "Đỉnh núi cao nhất Đông Dương?", "Phan Xi Păng"] {
                #expect(firstPage.contains(expected), "\(kind): trang 1 thiếu \(expected)")
            }
        }
    }

    @Test("PDF Chỉ đề đọc lại: có câu và lựa chọn, không có “Đáp án đúng”, giải thích, “Có đáp án”; đề hideAnswers cũng vậy")
    func questionsOnlyPDF() async throws {
        for hideAnswers in [false, true] {
            let reader = try await render(Self.report(Self.exam(hideAnswers: hideAnswers), kind: .questionsOnly))
            let text = try #require(reader.string)
            for expected in ["Địa lý Đông Nam Á", "Đỉnh núi cao nhất Đông Dương?", "Sông Cửu Long", "Chọn 2 đáp án",
                             "Không hiện được ảnh của câu này"] {
                #expect(text.contains(expected), "thiếu \(expected)")
            }
            for forbidden in ["Đáp án đúng", "Giải thích", "Lời giải", "Có đáp án"] {
                #expect(!text.contains(forbidden), "Chỉ đề không được có \(forbidden)")
            }
            #expect(text.contains("Ẩn đáp án") == hideAnswers)
        }
    }
}
