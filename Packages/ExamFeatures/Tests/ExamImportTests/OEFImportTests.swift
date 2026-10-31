import ExamFile
@testable import ExamImport
import ExamKit
import Foundation
import Testing

/// Import `.oef` (docs/product/import.md mục `.oef`): cùng bộ chuyển với bản Học viên (`OEFReader`), ghi chú của bộ
/// đọc thành mục báo cáo. File thử là oracle chung `fixtures/oef/` (kết luận của bộ đọc ở `OEFReaderTests`).
@Suite("Import .oef")
struct OEFImportTests {
    static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ExamImportTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ExamFeatures
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // gốc repo
        .appendingPathComponent("fixtures/oef", isDirectory: true)

    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: fixtures.appendingPathComponent("\(name).oef"))
    }

    func importOEF(_ name: String, limits: ImportLimits = .default,
                   sharedSectionTitle: String = ImportDefaults.sharedSectionTitle) async throws -> ImportResult
    {
        try await ExamImporter.importData(Self.fixture(name), fileName: "\(name).oef", limits: limits,
                                          sharedSectionTitle: sharedSectionTitle)
    }

    @Test(".oef là đuôi được hỗ trợ")
    func supported() {
        #expect(ExamImporter.supportedExtensions.contains("oef"))
        #expect(ImportSourceFormat(fileExtension: "OEF") == .oef)
    }

    @Test("Đề hợp lệ: xác nhận bằng giá trị điền sẵn ra đúng đề bản Học viên đọc (id, chữ, ảnh, hướng dẫn)")
    func sameExamAsStudent() async throws {
        let result = try await importOEF("co-ban")
        let student = try OEFReader.convert(Self.fixture("co-ban"), mode: .strict).package
        #expect(result.sourceFormat == .oef)
        #expect(result.report.entries.isEmpty)
        #expect(result.suggestions == ImportSuggestions(title: "Đề thử OEF cơ bản", code: "OEF-01", passPercent: 70,
                                                        timeLimitMinutes: 45))
        let package = result.makePackage(ImportConfirmation(title: "Đề thử OEF cơ bản", code: "OEF-01",
                                                            passPercent: 70, timeLimitMinutes: 45))
        #expect(package == student)
        let (written, reread) = try result.roundTrip(mode: .strict)
        #expect(reread == written)
    }

    @Test("Ẩn đáp án theo file; mã sai mẫu và phần không có câu thành cảnh báo")
    func hideAnswersAndWarnings() async throws {
        let result = try await importOEF("goi-dap-an-packed")
        #expect(result.hideAnswers)
        #expect(result.suggestions.code == nil && result.suggestions.passPercent == 73)
        #expect(result.report.entries.map(\.code) == [.invalidCode, .emptySection])
        #expect(result.report.entries.map(\.detail) == [.invalidOefCode("MÃ CÓ DẤU"), .oefEmptySection(section: 1)])
        #expect(result.report.warningCount == 2 && result.report.droppedCount == 0)
    }

    @Test("Trường lạ: bỏ qua, mỗi trường một cảnh báo không thuộc câu nào")
    func unknownFields() async throws {
        let result = try await importOEF("truong-la")
        #expect(result.report.entries.map(\.detail) == [
            .oefUnknownField("properties.#8"), .oefUnknownField("sections[0].questions[0].#9"),
            .oefUnknownField("sections[0].questions[0].options[0].#4"), .oefUnknownField("#3"),
        ])
        #expect(result.report.entries.allSatisfy { $0.questionID == nil && $0.location == ImportLocation() })
    }

    @Test("Đáp án lệch, chữ trùng: cảnh báo trỏ tới câu theo thứ tự trong file")
    func answerProblemsPointToQuestions() async throws {
        let result = try await importOEF("dap-an-khong-khop")
        let ids = result.questions.map(\.id)
        #expect(result.report.entries.map(\.code) == [.answerNotInOptions, .duplicateOptionLetter])
        #expect(result.report.entries.map(\.location.questionNumber) == [1, 2])
        #expect(result.report.entries.map(\.questionID) == [ids[0], ids[1]])
        #expect(result.report.entries[0].detail == .oefAnswerNotInOptions(["D"]))
    }

    @Test("Câu không có lựa chọn: bị bỏ, mục báo cáo không trỏ tới câu")
    func droppedQuestion() async throws {
        let result = try await importOEF("cau-khong-lua-chon")
        #expect(result.questionCount == 1)
        #expect(result.report.droppedCount == 1)
        let entry = try #require(result.entries(.noOptions).first)
        #expect(entry.location.questionNumber == 2 && entry.questionID == nil)
    }

    @Test("Ngưỡng ngoài thang, thời gian 0: để trống trong hộp xác nhận, kèm cảnh báo")
    func emptySuggestions() async throws {
        let result = try await importOEF("nguong-ngoai-thang")
        #expect(result.suggestions.passPercent == nil && result.suggestions.timeLimitMinutes == nil)
        #expect(result.report.entries.map(\.detail) == [.oefPassmarkOutOfRange, .invalidOefTimeLimit(0)])
    }

    @Test("Ảnh không hỗ trợ, quá 26 lựa chọn: như import docx (bỏ ảnh; nối vào Z)")
    func imageAndOptions() async throws {
        let image = try await importOEF("anh-bmp")
        #expect(image.media.isEmpty && image.questions[0].image == nil)
        #expect(image.report.entries.map(\.detail) == [.unsupportedImageFormat(fileExtension: nil)])
        let options = try await importOEF("qua-26-lua-chon")
        #expect(options.questions[0].options.count == 26 && options.questions[0].correct == [OptionID("Z")!])
        #expect(options.report.entries.map(\.detail) == [.tooManyOptions(count: 28)])
    }

    @Test("Phần không tên: lấy tên phần chung được truyền vào, kèm cảnh báo")
    func untitledSection() async throws {
        // Properties {Title "Đề", Passmark 500, TimeLimit 10}; Section {Question {Text "Câu?", Answer A, A "x", B "y"}}.
        let option = { (letter: UInt8, text: String) -> [UInt8] in
            Self.field(7, [0x08, letter] + Self.field(2, Array(text.utf8)))
        }
        let question = Self.field(2, Array("Câu?".utf8)) + [0x20, 0x41] + option(0x41, "x") + option(0x42, "y")
        let properties = Self.field(1, Array("Đề".utf8)) + [0x21] + withUnsafeBytes(of: Double(500).bitPattern.littleEndian, Array.init)
            + [0x28, 0x0A]
        let data = Data(Self.field(1, properties) + Self.field(2, Self.field(2, question)))
        let result = try await ExamImporter.importData(data, fileName: "khong-ten.oef", sharedSectionTitle: "General Section")
        #expect(result.sections.map(\.title) == ["General Section"])
        #expect(result.report.entries.map(\.detail)
            == [.oefUntitledSection(section: 1, fallbackSection: "General Section")])
    }

    @Test("File không đọc được: lỗi có mã, không có đề")
    func unreadable() async throws {
        await expectImportError(.unreadableOEF(.legacyFormat)) { _ = try await importOEF("ban-cu-nrbf") }
        await expectImportError(.unreadableOEF(.noQuestions)) { _ = try await importOEF("khong-cau-hoi") }
        await expectImportError(.unreadableOEF(.malformed(offset: 0))) { _ = try await importOEF("van-ban-wims") }
        await expectImportError(.tooLarge(what: .oefFile, limit: 100)) {
            _ = try await importOEF("co-ban", limits: ImportLimits(oefBytes: 100))
        }
    }

    /// Trường độ dài của Protobuf (độ dài < 128).
    static func field(_ number: UInt8, _ payload: [UInt8]) -> [UInt8] {
        [number << 3 | 2, UInt8(payload.count)] + payload
    }
}
