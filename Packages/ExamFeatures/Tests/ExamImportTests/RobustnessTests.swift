import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// File hỏng, zip bomb nhỏ, XML bất thường, giới hạn, chạy nền có tiến độ và huỷ.
@Suite("Import: file hỏng, giới hạn, tiến độ, huỷ")
struct RobustnessTests {
    static func minimalDocx() -> DocxBuilder {
        var doc = DocxBuilder()
        doc.paragraph("QUESTION 1")
        doc.paragraph("Câu hỏi")
        doc.listItem("Có", numID: 1)
        doc.listItem("Không", numID: 1)
        doc.paragraph("Correct Answer: A")
        return doc
    }

    @Test("Không phải zip, zip thiếu document.xml: báo không phải .docx")
    func notADocx() async throws {
        await expectImportError(.notADocx) {
            _ = try await ExamImporter.importData(Data("không phải zip".utf8), fileName: "a.docx")
        }
        await expectImportError(.notADocx) {
            _ = try await ExamImporter.importData(Data(), fileName: "a.docx")
        }
        let zip = try DocxBuilder.zip([("word/khac.xml", Data("<a/>".utf8))])
        await expectImportError(.notADocx) {
            _ = try await ExamImporter.importData(zip, fileName: "a.docx")
        }
    }

    @Test("Zip cắt cụt: báo lỗi, không crash")
    func truncatedZip() async throws {
        let data = try Self.minimalDocx().data()
        for length in [10, data.count / 2, data.count - 10] {
            do {
                _ = try await ExamImporter.importData(data.prefix(length), fileName: "a.docx")
                Issue.record("Zip cắt cụt \(length) byte vẫn import được")
            } catch is ImportError {
            } catch {
                Issue.record("Lỗi không phải ImportError: \(error)")
            }
        }
    }

    @Test("Sai CRC: phần bị hỏng")
    func corruptedCRC() async throws {
        var doc = Self.minimalDocx()
        doc.storeUncompressed = true
        let data = ZipPatcher.corruptStoredContent(of: "word/document.xml", in: try doc.data())
        await expectImportError(.corruptedPart("word/document.xml")) {
            _ = try await ExamImporter.importData(data, fileName: "a.docx")
        }
    }

    @Test("Zip bomb nói dối kích thước (không nén và deflate): dừng giải nén khi vượt kích thước khai báo")
    func lyingSize() async throws {
        for stored in [true, false] {
            var doc = Self.minimalDocx()
            doc.storeUncompressed = stored
            // Đủ dài để dữ liệu giải nén vượt xa 100 byte khai báo.
            doc.paragraph(String(repeating: "Nội dung dài. ", count: 500))
            let data = ZipPatcher.setUncompressedSize(of: "word/document.xml", to: 100, in: try doc.data())
            await expectImportError(.corruptedPart("word/document.xml")) {
                _ = try await ExamImporter.importData(data, fileName: "a.docx")
            }
        }
    }

    @Test("Zip bomb nhỏ: document.xml nén rất nhỏ nhưng giải nén vượt giới hạn → từ chối trước khi giải nén")
    func zipBomb() async throws {
        var doc = Self.minimalDocx()
        // ~2 MiB chữ lặp, nén còn vài KiB.
        doc.paragraph(String(repeating: "A", count: 2 << 20))
        let data = try doc.data()
        #expect(data.count < 64 << 10)
        var limits = ImportLimits.default
        limits.xmlPartBytes = 1 << 20
        await expectImportError(.tooLarge(what: .docxPart("word/document.xml"), limit: 1 << 20)) {
            _ = try await ExamImporter.importData(data, fileName: "a.docx", limits: limits)
        }
        limits = .default
        limits.totalUncompressedBytes = 1 << 20
        await expectImportError(.tooLarge(what: .docxTotalSize, limit: 1 << 20)) {
            _ = try await ExamImporter.importData(data, fileName: "a.docx", limits: limits)
        }
    }

    @Test("Đường dẫn quan hệ: tương đối, tuyệt đối, %2F; ../ vượt gốc gói bị từ chối")
    func packagePaths() {
        #expect(PackagePath.resolve("media/a.png", relativeTo: "word/document.xml") == "word/media/a.png")
        #expect(PackagePath.resolve("/word/media/a.png", relativeTo: "word/document.xml") == "word/media/a.png")
        #expect(PackagePath.resolve("..%2Fa.png", relativeTo: "word/document.xml") == "a.png")
        #expect(PackagePath.resolve("../../a.png", relativeTo: "word/document.xml") == nil)
        #expect(PackagePath.resolve("../../../etc/passwd", relativeTo: "word/document.xml") == nil)
        #expect(PackagePath.resolve("word/document.xml", relativeTo: "") == "word/document.xml")
        #expect(PackagePath.relationships(of: "word/document.xml") == "word/_rels/document.xml.rels")
    }

    @Test("_rels/.rels trỏ văn bản chính ra ngoài gốc gói: dùng word/document.xml mặc định")
    func mainPartAboveRoot() async throws {
        var doc = Self.minimalDocx()
        doc.mainDocumentTarget = "../../document.xml"
        let result = try await importDocx(doc)
        #expect(result.questionCount == 1)
    }

    @Test("Quá số entry trong zip")
    func entryCount() async throws {
        var doc = Self.minimalDocx()
        for i in 0 ..< 30 { doc.files["extra/\(i).txt"] = Data([UInt8(i)]) }
        var limits = ImportLimits.default
        limits.entryCount = 20
        await expectImportError(.tooLarge(what: .docxEntryCount, limit: 20)) {
            _ = try await importDocx(doc, limits: limits)
        }
    }

    @Test("XML sai cú pháp, có DTD/thực thể, lồng quá sâu: báo lỗi")
    func badXML() async throws {
        var doc = Self.minimalDocx()
        doc.documentOverride = "<w:document xmlns:w=\"\(DocxBuilder.wordNamespace)\"><w:body><w:p></w:body>"
        do {
            _ = try await importDocx(doc)
            Issue.record("XML hỏng vẫn import được")
        } catch let ImportError.invalidXML(part, _) {
            #expect(part == "word/document.xml")
        }

        doc.documentOverride = """
        <?xml version="1.0"?><!DOCTYPE d [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;">]>\
        <w:document xmlns:w="\(DocxBuilder.wordNamespace)"><w:body><w:p><w:r><w:t>&b;</w:t></w:r></w:p></w:body></w:document>
        """
        await expectImportError(.invalidXML(part: "word/document.xml", detail: .declaresDTD)) {
            _ = try await importDocx(doc)
        }

        // XML UTF-16: phép tìm byte "<!DOCTYPE" (UTF-8) không thấy, bộ phân tích phải chặn khai báo thực thể.
        let utf16 = """
        <?xml version="1.0" encoding="UTF-16"?><!DOCTYPE d [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;">]>\
        <w:document xmlns:w="\(DocxBuilder.wordNamespace)"><w:body><w:p><w:r><w:t>&b;</w:t></w:r></w:p></w:body></w:document>
        """
        var utf16Doc = Self.minimalDocx()
        utf16Doc.documentBytes = utf16.data(using: .utf16)
        #expect(utf16Doc.documentBytes?.range(of: Data("<!DOCTYPE".utf8)) == nil)
        await expectImportError(.invalidXML(part: "word/document.xml", detail: .declaresEntity)) {
            _ = try await importDocx(utf16Doc)
        }

        let deep = String(repeating: "<w:sdt>", count: 200) + String(repeating: "</w:sdt>", count: 200)
        doc.documentOverride = "<w:document xmlns:w=\"\(DocxBuilder.wordNamespace)\"><w:body>\(deep)</w:body></w:document>"
        await expectImportError(.tooDeep(part: "word/document.xml", limit: 128)) {
            _ = try await importDocx(doc)
        }
    }

    @Test("Đuôi file không hỗ trợ")
    func unsupportedExtension() async {
        await expectImportError(.unsupportedFileType("xls")) {
            _ = try await ExamImporter.importData(Data(), fileName: "de.xls")
        }
        await expectImportError(.unsupportedFileType("pdf")) {
            _ = try await ExamImporter.importFile(at: URL(fileURLWithPath: "/tmp/de.pdf"))
        }
    }

    @Test("Import từ file trên đĩa (txt, docx); file không có thì báo không đọc được")
    func importFromDisk() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("examimport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let txt = directory.appendingPathComponent("Ôn tập.TXT")
        try Data(TextImportTests.basic.utf8).write(to: txt)
        let docx = directory.appendingPathComponent("Ôn tập.docx")
        try Self.minimalDocx().data().write(to: docx)

        let fromText = try await ExamImporter.importFile(at: txt)
        #expect(fromText.questionCount == 2)
        #expect(fromText.sections[0].title == "Ôn tập")
        let fromDocx = try await ExamImporter.importFile(at: docx)
        #expect(fromDocx.questionCount == 1)
        #expect(fromDocx.suggestions.title == "Ôn tập")

        for missing in ["khong-co.txt", "khong-co.docx"] {
            do {
                _ = try await ExamImporter.importFile(at: directory.appendingPathComponent(missing))
                Issue.record("File không có vẫn import được")
            } catch ImportError.unreadableFile {
            }
        }
    }

    /// Đề txt dài: `count` câu.
    static func longText(_ count: Int) -> String {
        (1 ... count).map { "Q\($0):\nCâu số \($0)\nA. Có\nB. Không\nCorrect Answer: A\n" }.joined()
    }

    @Test("Tiến độ không lùi, kết thúc ở 1")
    func progress() async throws {
        let recorder = ProgressRecorder()
        _ = try await ExamImporter.importData(Data(Self.longText(400).utf8), fileName: "a.txt") { recorder.add($0) }
        let values = recorder.values
        #expect(values.count > 3)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0.fractionCompleted <= $1.fractionCompleted })
        #expect(values.last == ImportProgress(phase: .finished, fractionCompleted: 1))
    }

    @Test("Huỷ task gọi: bộ chuyển đổi dừng và ném CancellationError")
    func cancellation() async throws {
        let box = CancelBox()
        let data = Data(Self.longText(2000).utf8)
        let task = Task {
            try await ExamImporter.importData(data, fileName: "a.txt") { progress in
                if progress.phase == .converting, progress.fractionCompleted > 0 { box.cancel() }
            }
        }
        box.set(task)
        do {
            _ = try await task.value
            Issue.record("Import không dừng khi bị huỷ")
        } catch is CancellationError {
        }
    }
}

final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ImportProgress] = []

    func add(_ progress: ImportProgress) {
        lock.withLock { storage.append(progress) }
    }

    var values: [ImportProgress] { lock.withLock { storage } }
}

/// Huỷ task từ callback tiến độ (có thể gọi trước khi task được gán).
final class CancelBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<ImportResult, Error>?
    private var cancelRequested = false

    func set(_ task: Task<ImportResult, Error>) {
        lock.withLock {
            self.task = task
            if cancelRequested { task.cancel() }
        }
    }

    func cancel() {
        lock.withLock {
            cancelRequested = true
            task?.cancel()
        }
    }
}
