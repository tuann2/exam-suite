import AppKit
import Foundation
import ImageIO
import PDFKit
@testable import ReportFeature
import Testing
import UniformTypeIdentifiers

/// Bộ dựng trang PDF (cách A của docs/product/export-print.md), đọc lại bằng PDFKit trên tài liệu nhỏ (đọc lại ~1.000
/// trang mất ~29 s, docs/notes/g5-spike-pdf-l10n.md).
@MainActor
@Suite("Bộ dựng trang PDF", .serialized)
struct ReportRendererTests {
    static let footer = ReportFooter(
        title: "Đề Địa lý Đông Nam Á",
        lines: ["Kết quả luyện tập, không có giá trị xác nhận"]
    )

    static func document(_ blocks: [ReportBlock], title: String = "Đề Địa lý Đông Nam Á – Kết quả") -> ReportDocument {
        ReportDocument(metadata: ReportMetadata(title: title, creator: "Exam Suite 1.0"), footer: footer, blocks: blocks)
    }

    static func question(
        _ number: Int,
        text: String,
        options: [String] = ["Hà Nội", "Đà Nẵng", "Huế", "Cần Thơ"],
        explanation: String? = nil,
        image: ReportImageSource? = nil
    ) -> ReportBlock {
        .question(ReportQuestion(
            number: number,
            sectionTitle: "Phần 1",
            positionText: "Câu \(number)/60",
            status: ReportBadge(title: "Sai", systemImage: "xmark.circle.fill"),
            text: text,
            image: image,
            options: options.enumerated().map { offset, text in
                ReportOption(
                    label: "\(offset + 1).",
                    text: text,
                    marks: offset == 1 ? [ReportBadge(title: "Đáp án đúng", systemImage: "checkmark.circle.fill")] : []
                )
            },
            explanation: explanation
        ))
    }

    func render(_ document: ReportDocument) async throws -> (ReportPDF, PDFDocument) {
        let clock = ContinuousClock()
        let start = clock.now
        let pdf = try await ReportRenderer().render(document)
        print("Timing: PDF \(document.blocks.count) khối → \(pdf.pageCount) trang \(clock.now - start)")
        let reader = try #require(PDFDocument(data: pdf.data))
        #expect(reader.pageCount == pdf.pageCount)
        return (pdf, reader)
    }

    func pageText(_ reader: PDFDocument, _ index: Int) -> String {
        reader.page(at: index)?.string ?? ""
    }

    // MARK: - Chữ

    @Test("Chữ thật, tiếng Việt đọc lại nguyên văn: Đ (U+0110) không thành Ð (U+00D0)")
    func vietnameseReadBack() async throws {
        let (_, reader) = try await render(Self.document([
            .title(ReportTitle(
                title: "Đề Địa lý Đông Nam Á",
                subtitle: "Kết quả",
                fields: [ReportField(label: "Thí sinh", value: "Nguyễn Văn Đức"), ReportField(label: "Mã đề", value: "ĐL-01")]
            )),
            Self.question(1, text: "Đâu là thủ đô của Việt Nam? Ước lượng độ ẩm, giữ ưu thế, nghĩa vụ."),
        ]))
        let text = try #require(reader.string)
        for expected in ["Đề Địa lý Đông Nam Á", "Nguyễn Văn Đức", "ĐL-01", "Đâu là thủ đô của Việt Nam?", "Đáp án đúng",
                         "Đà Nẵng", "Ước lượng độ ẩm, giữ ưu thế, nghĩa vụ."] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        #expect(!text.contains("\u{00D0}"), "Ð (U+00D0) xuất hiện: phông vẽ chữ Đ sai (SF Pro?)")
        #expect(text == text.precomposedStringWithCanonicalMapping)
        #expect(reader.findString("Đáp án đúng", withOptions: []).count == 1)
    }

    @Test("Markdown cơ bản: đậm, nghiêng, mã inline, liên kết hiện chữ; không còn ký hiệu Markdown")
    func markdown() async throws {
        let (_, reader) = try await render(Self.document([
            Self.question(1, text: "Chọn **đáp án đậm**, *nghiêng*, mã `ipconfig` và [liên kết](https://example.com)."),
        ]))
        let text = try #require(reader.string)
        #expect(text.contains("Chọn đáp án đậm, nghiêng, mã ipconfig và liên kết."), "\(text)")
        #expect(!text.contains("**"))
        #expect(!text.contains("`"))
        #expect(!text.contains("https://example.com"))
        // Chuỗi không phân tích được thì in nguyên văn.
        let (_, raw) = try await render(Self.document([Self.question(2, text: "a ** b ` c")]))
        #expect(raw.string?.contains("a ** b ` c") == true)
    }

    /// Ký tự chữ ghép Latin (U+FB00–FB06: ff, fi, fl, ffi, ffl, ſt, st) trong `text`.
    static func ligatures(in text: String) -> [String] {
        text.unicodeScalars.filter { (0xFB00 ... 0xFB06).contains($0.value) }.map { String(format: "U+%04X", $0.value) }
    }

    @Test("Không chữ ghép: \"official\", \"ffi\", \"fl\" đọc lại nguyên văn ở mọi phông của PDF (thân, đậm, nghiêng, mã)")
    func noLigatures() async throws {
        let words = "official office affix efficient fluffy flight shuffle"
        let (_, reader) = try await render(Self.document([
            .title(ReportTitle(
                title: "Official Traffic Rules", subtitle: "Final results",
                fields: [ReportField(label: "Affiliation", value: "Office of Fluid Affairs")]
            )),
            .heading(ReportHeading(title: "Fluffy official section", detail: "fifty efficient affixes")),
            Self.question(
                1,
                text: "\(words). **\(words)** *\(words)* `\(words)`",
                options: ["ffi fl fi ff ffl", "official", "*afflict*", "`office`"],
                explanation: "The official flight shuffle."
            ),
        ]))
        let text = try #require(reader.string)
        #expect(Self.ligatures(in: text).isEmpty, "PDF có chữ ghép: \(Self.ligatures(in: text))")
        for expected in [words, "Official Traffic Rules", "Office of Fluid Affairs", "Fluffy official section",
                         "fifty efficient affixes", "ffi fl fi ff ffl", "afflict", "The official flight shuffle."] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        // Tìm trong PDF (như Preview) thấy đúng chữ.
        #expect(reader.findString("official", withOptions: [.caseInsensitive]).count >= 5)
    }

    /// Ở suite này (tuần tự), không ở "Ghi PDF ra file": chỉ các test dựng PDF vào bộ nhớ (`render(_:)`) tạo file
    /// `ExamSuiteReport-*` trong thư mục tạm của hệ thống, nên hai suite chạy song song từng làm test này bắt nhầm file tạm
    /// của test khác còn đang dựng (đỏ chập chờn khi chạy cả `swift test`, giai đoạn 5 bước 8a).
    ///
    /// File của chính lần dựng này là phần **chênh** của `ReportTemporaryFiles.pending` giữa ngay trước khi gọi `render(_:)`
    /// và lần báo tiến độ đầu tiên (re-review #53): `render(_:)` ghi nhớ file rồi báo tiến độ đầu tiên trên main actor, không
    /// có điểm chờ nào ở giữa, nên suite khác (song song) không chen file của nó vào phần chênh được. Sau khi dựng, chỉ file
    /// đó phải hết trong danh sách và trên đĩa; file của suite khác (nếu có) không làm test đỏ.
    @Test("In: PDF tạm trong thư mục tạm của hệ thống cũng được ghi nhớ khi đang dựng và xoá khi xong")
    func printTemporaryFileTracked() async throws {
        let systemTemporary = FileManager.default.temporaryDirectory.standardizedFileURL.path
        let isPrintTemporary: (URL) -> Bool = {
            $0.deletingLastPathComponent().standardizedFileURL.path == systemTemporary
                && $0.lastPathComponent.hasPrefix("ExamSuiteReport-")
        }
        var ownFiles: Set<URL>?
        var stillTrackedWhileDrawing = false
        let blocks = (1 ... 3).map { Self.question($0, text: "Câu ghi file \($0) " + String(repeating: "nội dung ", count: 40)) }
        let before = ReportTemporaryFiles.pending
        let pdf = try await ReportRenderer().render(Self.document(blocks)) { event in
            if ownFiles == nil {
                ownFiles = ReportTemporaryFiles.pending.subtracting(before)
            }
            if event.phase == .drawing, let ownFiles, !ownFiles.isEmpty {
                stillTrackedWhileDrawing = ownFiles.isSubset(of: ReportTemporaryFiles.pending)
            }
        }
        #expect(pdf.pageCount > 0)
        let own = try #require(ownFiles)
        #expect(own.count == 1, "phần chênh của danh sách file tạm: \(own)")
        #expect(own.allSatisfy(isPrintTemporary), "\(own)")
        #expect(stillTrackedWhileDrawing)
        for url in own {
            #expect(!ReportTemporaryFiles.pending.contains(url))
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("A4 dọc 595 × 842 pt; siêu dữ liệu Title, Creator")
    func a4AndMetadata() async throws {
        let (_, reader) = try await render(Self.document([Self.question(1, text: "Câu ngắn")]))
        let bounds = try #require(reader.page(at: 0)).bounds(for: .mediaBox)
        #expect(bounds.width == 595)
        #expect(bounds.height == 842)
        let attributes = reader.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == "Đề Địa lý Đông Nam Á – Kết quả")
        #expect(attributes[PDFDocumentAttribute.creatorAttribute] as? String == "Exam Suite 1.0")
    }

    // MARK: - Phân trang

    @Test("Chân trang có trên mọi trang: “Trang N/M”, tên đề, dòng lưu ý")
    func footerOnEveryPage() async throws {
        let blocks = (1 ... 12).map { Self.question($0, text: "Câu hỏi số \($0): " + String(repeating: "Nội dung dài để đầy trang. ", count: 12)) }
        let (pdf, reader) = try await render(Self.document(blocks))
        #expect(pdf.pageCount >= 3)
        for index in 0 ..< reader.pageCount {
            let text = pageText(reader, index)
            #expect(text.contains("Trang \(index + 1)/\(pdf.pageCount)"), "trang \(index + 1)")
            #expect(text.contains("Đề Địa lý Đông Nam Á"), "trang \(index + 1)")
            #expect(text.contains("Kết quả luyện tập, không có giá trị xác nhận"), "trang \(index + 1)")
        }
        // Khối vừa một trang không bị cắt: mỗi câu nằm trọn trên một trang.
        for number in 1 ... 12 {
            let pages = (0 ..< reader.pageCount).filter { pageText(reader, $0).contains("Câu \(number)/60") }
            #expect(pages.count == 1, "câu \(number) ở các trang \(pages)")
            let page = try #require(pages.first)
            #expect(pageText(reader, page).contains("Câu hỏi số \(number):"))
        }
        #expect(!(reader.string ?? "").contains("(tiếp)"))
    }

    @Test("Khối cao hơn một trang tách giữa các lựa chọn, phần sau mở bằng “Câu N (tiếp)”; không mất chữ")
    func longBlockSplits() async throws {
        let options = (1 ... 60).map { "Lựa chọn thứ \($0) để chiếm chỗ trên trang giấy." }
        let (pdf, reader) = try await render(Self.document([
            Self.question(1, text: "Câu ngắn đứng trước."),
            Self.question(7, text: "Câu có rất nhiều lựa chọn.", options: options, explanation: "Giải thích cuối khối."),
        ]))
        #expect(pdf.pageCount >= 2)
        let text = try #require(reader.string)
        for option in options { #expect(text.contains(option), "mất: \(option)") }
        #expect(text.contains("Giải thích cuối khối."))
        let continued = (0 ..< reader.pageCount).filter { pageText(reader, $0).contains("Câu 7 (tiếp)") }
        #expect(continued == Array(1 ..< pdf.pageCount), "dòng tiếp ở các trang \(continued)")
        // Mỗi lựa chọn nằm trọn một trang (không cắt giữa dòng).
        for option in options {
            let pages = (0 ..< reader.pageCount).filter { pageText(reader, $0).contains(option) }
            #expect(pages.count == 1, "\(option) ở các trang \(pages)")
        }
    }

    @Test("Một đoạn dài hơn cả trang: tách theo từ, đủ mọi từ theo thứ tự, có “(tiếp)”")
    func longParagraphSplits() async throws {
        let words = (1 ... 900).map { "từ\($0)" }
        let (pdf, reader) = try await render(Self.document([Self.question(3, text: words.joined(separator: " "))]))
        #expect(pdf.pageCount >= 2)
        let text = try #require(reader.string)
        let found = text.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { $0.hasPrefix("từ") }
        #expect(found == words)
        #expect(pageText(reader, 1).contains("Câu 3 (tiếp)"))

        // Một "từ" không khoảng trắng dài hơn cả trang: ngắt giữa ký tự, không mất ký tự nào.
        let word = String(repeating: "Kỹỹ", count: 1200)
        let (wordPDF, wordReader) = try await render(Self.document([Self.question(4, text: word)]))
        #expect(wordPDF.pageCount >= 2)
        let wordText = try #require(wordReader.string)
        #expect(wordText.filter { $0 == "ỹ" }.count == 2400)
    }

    @Test("Đề mục không đứng một mình cuối trang")
    func headingKeptWithNext() async throws {
        // Lấp trang đầu gần đầy rồi thêm đề mục + câu: đề mục phải sang trang sau cùng câu.
        var blocks = (1 ... 5).map { Self.question($0, text: String(repeating: "Lấp chỗ trống của trang đầu. ", count: 10)) }
        blocks.append(.heading(ReportHeading(title: "Phần cuối", detail: "Chi tiết đề mục")))
        blocks.append(Self.question(6, text: "Câu sau đề mục.", options: (1 ... 8).map { "Lựa chọn \($0)" }))
        let (_, reader) = try await render(Self.document(blocks))
        let headingPage = (0 ..< reader.pageCount).first { pageText(reader, $0).contains("Phần cuối") }
        let questionPage = (0 ..< reader.pageCount).first { pageText(reader, $0).contains("Câu sau đề mục.") }
        #expect(headingPage != nil)
        #expect(headingPage == questionPage)
    }

    @Test("Xếp trang: khối vừa trang không bị tách; khối quá cao tách thành mảnh không vượt trang")
    func paginationArithmetic() async throws {
        typealias Block = ReportRenderer.MeasuredBlock
        let segment = ReportSegment.hint("x")
        func block(_ height: CGFloat, segments: [CGFloat]? = nil, keep: Bool = false) -> Block {
            Block(
                segments: Array(repeating: segment, count: segments?.count ?? 1),
                height: height,
                segmentHeights: segments,
                continuation: .continuation("tiếp"),
                continuationHeight: 10,
                keepWithNext: keep
            )
        }
        let pages = try await ReportRenderer.paginate([block(300), block(300), block(300)], pageHeight: 700)
        #expect(pages.map(\.count) == [2, 1])
        #expect(pages[0].map(\.y) == [0, 300 + ReportRenderer.blockSpacing])

        let tall = block(1500, segments: Array(repeating: 100, count: 15))
        let split = try await ReportRenderer.paginate([block(100), tall], pageHeight: 700)
        #expect(split.count >= 3)
        for page in split {
            let bottom = page.map { $0.y + $0.height }.max() ?? 0
            #expect(bottom <= 700)
        }
        // Mảnh sau mở bằng dòng tiếp.
        for page in split.dropFirst() {
            #expect(page.first?.segments.first == .continuation("tiếp"))
        }

        // Đề mục trước khối quá cao: không đứng một mình cuối trang (đi cùng hai phần đầu của khối sau).
        var heading = block(40, keep: true)
        heading.segments = [.heading("Đề mục", detail: nil)]
        let tallAfterHeading = block(1500, segments: [200] + Array(repeating: 100, count: 13))
        let headingPages = try await ReportRenderer.paginate([block(380), heading, tallAfterHeading], pageHeight: 700)
        let headingPage = try #require(headingPages.firstIndex { $0.contains { $0.segments.first == .heading("Đề mục", detail: nil) } })
        let tallStart = try #require(headingPages.firstIndex { $0.contains { $0.segments.count > 1 && $0.segments.first == segment } })
        #expect(headingPage == tallStart)

        // Đề mục + khối vừa một trang nhưng không vừa cùng trang với đề mục: khối (đã cho tách được) bắt đầu ngay sau
        // đề mục thay vì để đề mục một mình cuối trang.
        var heading2 = block(40, keep: true)
        heading2.segments = [.heading("Đề mục 2", detail: nil)]
        let fitsAlone = block(572, segments: Array(repeating: 50, count: 10))
        let pages2 = try await ReportRenderer.paginate([block(500), heading2, fitsAlone], pageHeight: 700)
        #expect(pages2[0].count == 3)
        #expect(pages2[0].last?.segments.first == segment)
        #expect(pages2.count == 2)
        #expect(pages2[1].first?.segments.first == .continuation("tiếp"))
        // Khối vừa một trang không đi sau đề mục thì không tách, kể cả khi có chiều cao từng phần.
        let pages3 = try await ReportRenderer.paginate([block(500), fitsAlone], pageHeight: 700)
        #expect(pages3.map(\.count) == [1, 1])
    }

    // MARK: - Ảnh

    static func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("Ảnh vừa bề rộng, cao ≤ 1/3 trang, giữ tỉ lệ, không phóng to; ảnh hỏng hoặc thiếu có dòng báo")
    func images() async throws {
        let geometry = ReportPageGeometry.a4
        let wide = try Self.png(width: 1600, height: 1000)
        let wideSize = try #require(ReportImages.displaySize(of: wide, maxWidth: geometry.contentWidth, maxHeight: geometry.maxImageHeight))
        #expect(wideSize.width <= geometry.contentWidth)
        #expect(wideSize.height <= 842 / 3)
        #expect(abs(wideSize.width / wideSize.height - 1.6) < 0.01)
        let tall = try Self.png(width: 400, height: 2000)
        let tallSize = try #require(ReportImages.displaySize(of: tall, maxWidth: geometry.contentWidth, maxHeight: geometry.maxImageHeight))
        #expect(tallSize.height == geometry.maxImageHeight)
        let small = try Self.png(width: 80, height: 40)
        #expect(ReportImages.displaySize(of: small, maxWidth: geometry.contentWidth, maxHeight: geometry.maxImageHeight) == CGSize(width: 80, height: 40))
        let decoded = try #require(ReportImages.decode(wide, displaySize: wideSize))
        #expect(max(decoded.width, decoded.height) <= Int((max(wideSize.width, wideSize.height) * 2).rounded(.up)))
        #expect(ReportImages.displaySize(of: Data("không phải ảnh".utf8), maxWidth: 100, maxHeight: 100) == nil)

        let (pdf, reader) = try await render(Self.document([
            Self.question(1, text: "Câu có ảnh.", image: .data(wide)),
            Self.question(2, text: "Câu ảnh hỏng.", image: .data(Data("hỏng".utf8))),
            Self.question(3, text: "Câu thiếu ảnh.", image: .missing),
        ]))
        #expect(pdf.pageCount >= 1)
        let text = try #require(reader.string)
        #expect(text.components(separatedBy: "Không hiện được ảnh của câu này").count - 1 == 2)
        #expect(text.contains("Câu có ảnh."))
    }

    // MARK: - Tiến độ, huỷ

    @Test("Tiến độ: xếp trang (khối) rồi từng trang, tăng dần, kết thúc 100%")
    func progress() async throws {
        let blocks = (1 ... 20).map { Self.question($0, text: "Câu \($0)") }
        var events: [ReportProgress] = []
        let pdf = try await ReportRenderer().render(Self.document(blocks)) { events.append($0) }
        let layout = events.filter { $0.phase == .layout }
        let drawing = events.filter { $0.phase == .drawing }
        #expect(layout.first?.completed == 0)
        #expect(layout.last?.completed == 20)
        #expect(layout.map(\.completed) == layout.map(\.completed).sorted())
        #expect(drawing.map(\.completed) == Array(0 ... pdf.pageCount))
        #expect(drawing.first?.message == "Đang dựng trang 1…")
        #expect(events.map(\.fractionCompleted) == events.map(\.fractionCompleted).sorted())
        #expect(events.last?.fractionCompleted == 1)
    }

    @Test("Huỷ khi đang xếp trang hoặc đang vẽ: ném CancellationError, không để lại file dở")
    func cancellation() async throws {
        let blocks = (1 ... 30).map { Self.question($0, text: "Câu \($0) " + String(repeating: "chữ ", count: 40)) }
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for phase in [ReportProgress.Phase.layout, .drawing] {
            let url = directory.appendingPathComponent("huy-\(phase).pdf")
            let task = Task { @MainActor () -> ReportPDFFile in
                try await ReportRenderer().render(Self.document(blocks), to: url) { event in
                    if event.phase == phase, event.completed >= 1 {
                        withUnsafeCurrentTask { $0?.cancel() }
                    }
                }
            }
            await #expect(throws: CancellationError.self) { try await task.value }
            #expect(!FileManager.default.fileExists(atPath: url.path), "file dở còn lại sau khi huỷ ở \(phase)")
        }
    }

    @Test("Ghi thẳng ra file: đúng số trang; file đích có sẵn bị ghi đè")
    func renderToFile() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ket-qua.pdf")
        try Data("cũ".utf8).write(to: url)
        let blocks = (1 ... 6).map { Self.question($0, text: "Câu \($0) " + String(repeating: "chữ ", count: 60)) }
        let file = try await ReportRenderer().render(Self.document(blocks), to: url)
        #expect(file.url == url)
        let reader = try #require(PDFDocument(url: url))
        #expect(reader.pageCount == file.pageCount)
        #expect(reader.string?.contains("Câu 6/60") == true)
    }

    @Test("Main actor không bị chặn quá 100 ms: ảnh lớn giải mã ngoài main actor, khối dài nhường lượt theo thời gian")
    func mainActorStaysResponsive() async throws {
        let big = try Self.png(width: 5000, height: 3600)
        let long = String(repeating: "Đoạn văn rất dài để buộc tách khối qua nhiều trang. ", count: 200)
        var blocks: [ReportBlock] = (1 ... 4).map { Self.question($0, text: "Câu có ảnh lớn \($0)", image: .data(big)) }
        blocks += (5 ... 12).map { Self.question($0, text: long) }
        let beat = MainActorHeartbeat()
        beat.start()
        let clock = ContinuousClock()
        let start = clock.now
        let pdf = try await ReportRenderer().render(Self.document(blocks))
        await beat.stop()
        print("Timing: PDF ảnh 5000×3600 + 8 khối dài → \(pdf.pageCount) trang \(clock.now - start), main actor chặn lâu nhất \(beat.longestGap)")
        #expect(beat.beats > 10)
        #expect(beat.longestGap < .milliseconds(100))
    }

    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReportFeatureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - Lựa chọn quá dài

    @Test("Lựa chọn 4.000 ký tự có hai dấu: tách sang trang sau với nhãn “(tiếp)”, không vẽ xuống chân trang, không mất từ")
    func longOptionSplits() async throws {
        // 4.000 ký tự (giới hạn của schema cho options[].text): "Zebra1 Zebra2 …".
        var words: [String] = []
        while (words.joined(separator: " ") + " Zebra\(words.count + 1)").count <= 4000 { words.append("Zebra\(words.count + 1)") }
        let text = words.joined(separator: " ")
        #expect(text.count > 3990)
        let marks = [ReportBadge(title: "Bạn chọn", systemImage: "hand.point.up.left.fill"),
                     ReportBadge(title: "Đáp án đúng", systemImage: "checkmark.circle.fill")]
        let document = Self.document([
            .question(ReportQuestion(
                number: 9, sectionTitle: "Phần 1", positionText: "Câu 9/60", text: "Câu có lựa chọn rất dài.",
                options: [ReportOption(label: "A", text: text, marks: marks), ReportOption(label: "B", text: "Ngắn")]
            )),
        ])
        let renderer = ReportRenderer()
        let metrics = renderer.layoutMetrics(for: document.footer)
        let (pdf, reader) = try await render(document)
        #expect(pdf.pageCount >= 2)
        let contentBottom = 842 - 51 - metrics.contentHeight
        for index in 0 ..< reader.pageCount {
            let page = try #require(reader.page(at: index))
            // Vùng từ mép dưới trang tới đáy vùng nội dung: chỉ có chân trang.
            let below = page.selection(for: CGRect(x: 0, y: 0, width: 595, height: contentBottom - 0.5))?.string ?? ""
            #expect(!below.contains("Zebra"), "trang \(index + 1): chữ của lựa chọn nằm dưới vùng nội dung")
            #expect(below.contains("Trang \(index + 1)/\(pdf.pageCount)"))
        }
        let all = try #require(reader.string)
        let found = Set(all.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.hasPrefix("Zebra") })
        #expect(found == Set(words))
        #expect(reader.findString("Bạn chọn", withOptions: []).count == 1)
        #expect(reader.findString("Đáp án đúng", withOptions: []).count == 1)
        #expect(pageText(reader, 1).contains("Câu 9 (tiếp)"))
        #expect(pageText(reader, 1).contains("(tiếp)"))
    }

    // MARK: - In

    @Test("In ra file (không hộp thoại, khổ Letter): co vừa trang, đủ số trang và chữ")
    func printToFile() async throws {
        let blocks = (1 ... 6).map { Self.question($0, text: "Câu in số \($0) " + String(repeating: "nội dung ", count: 30)) }
        let pdf = try await ReportRenderer().render(Self.document(blocks))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReportFeatureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("in.pdf")

        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 612, height: 792)
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = output
        let operation = try #require(ReportPrinting.printOperation(for: pdf, jobTitle: "Đề Địa lý", printInfo: info))
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        #expect(operation.jobTitle == "Đề Địa lý")
        #expect(operation.run())

        let printed = try #require(PDFDocument(url: output))
        #expect(printed.pageCount == pdf.pageCount)
        let bounds = try #require(printed.page(at: 0)).bounds(for: .mediaBox)
        #expect(bounds.size == CGSize(width: 612, height: 792))
        #expect(printed.string?.contains("Câu in số 6") == true)
    }
}
