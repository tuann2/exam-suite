import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Tên phần chung (câu không thuộc phần nào) là nội dung đề, theo ngôn ngữ giao diện lúc import: giao diện truyền vào
/// `sharedSectionTitle:` (Nt0 chốt 2026-10-17, plan giai đoạn 5 bước 7c); không truyền thì tiếng Việt "Phần chung".
@Suite("Tên phần chung khi import theo ngôn ngữ giao diện")
struct SharedSectionTitleTests {
    @Test("Mặc định tiếng Việt: \"Phần chung\"")
    func defaultIsVietnamese() {
        #expect(ImportDefaults.sharedSectionTitle == "Phần chung")
    }

    @Test(".txt: tên file rỗng thì phần lấy tên phần chung được truyền vào")
    func text() async throws {
        let data = Data(TextImportTests.basic.utf8)
        let english = try await ExamImporter.importData(data, fileName: " .txt", sharedSectionTitle: "General Section")
        #expect(english.sections.map(\.title) == ["General Section"])
        let vietnamese = try await ExamImporter.importData(data, fileName: " .txt")
        #expect(vietnamese.sections.map(\.title) == ["Phần chung"])
        // Có tên file thì vẫn là tên file (import.md phương án 8), không theo ngôn ngữ.
        let named = try await ExamImporter.importData(data, fileName: "Mạng.txt", sharedSectionTitle: "General Section")
        #expect(named.sections.map(\.title) == ["Mạng"])
    }

    @Test(".docx: câu không có Section: và không có nhóm vào phần chung được truyền vào")
    func docx() async throws {
        var doc = DocxBuilder()
        doc.paragraph("Tiêu đề")
        DocxImportTests.listQuestion(&doc, 1, labels: [])
        let english = try await ExamImporter.importData(doc.data(), fileName: "a.docx", sharedSectionTitle: "General Section")
        #expect(english.sections.map(\.title) == ["General Section"])
        let vietnamese = try await importDocx(doc)
        #expect(vietnamese.sections.map(\.title) == ["Phần chung"])
    }

    @Test(".vce: câu phần −1 khi file không có nhóm có tên vào phần chung được truyền vào, cả trong câu cảnh báo")
    func vce() async throws {
        var writer = VceImportTests.basic()
        writer.sections = []
        writer.questions[0].sectionID = -1
        writer.questions[1].sectionID = -1
        let english = try await ExamImporter.importData(writer.data(), fileName: "a.vce",
                                                        sharedSectionTitle: "General Section")
        #expect(english.sections.map(\.title) == ["General Section"])
        #expect(try await importVce(writer).sections.map(\.title) == ["Phần chung"])

        writer.groups = ["Exam A", "Exam B"]
        let groups = try await ExamImporter.importData(writer.data(), fileName: "a.vce",
                                                       sharedSectionTitle: "General Section")
        #expect(groups.sections.map(\.title) == ["General Section"])
        #expect(groups.entries(.multipleGroups).map(\.detail) == [.multipleGroups(count: 2, fallbackSection: "General Section")])
    }
}
