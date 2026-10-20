import AuthoringData
@testable import AuthoringFeature
import ExamImport
import ExamKit
import Foundation
import Testing

/// Tên mặc định app ghi vào nội dung đề theo ngôn ngữ giao diện lúc tạo (Nt0 chốt 2026-10-17; plan giai đoạn 5,
/// Decisions; accessibility-localization.md, ghi chú bước 7c): đề mới, phần mới, phần chung khi import. Sau khi tạo là
/// nội dung đề, không dịch lại.
@MainActor
@Suite("Tên mặc định ghi vào đề theo ngôn ngữ giao diện")
struct DefaultContentNamesTests {
    private static let en = Locale(identifier: "en")
    private static let vi = Locale(identifier: "vi")

    @Test("Giao diện tiếng Anh: New Exam, Section N, General Section; tiếng Việt: Đề mới, Phần N, Phần chung")
    func namesFollowInterfaceLanguage() {
        let english = DefaultContentNames.interface(locale: Self.en)
        #expect(english.examTitle == "New Exam")
        #expect(english.sectionTitle(1) == "Section 1")
        #expect(english.sectionTitle(1234) == "Section 1234")
        #expect(ImportContentNames.sharedSectionTitle(locale: Self.en) == "General Section")

        let vietnamese = DefaultContentNames.interface(locale: Self.vi)
        #expect(vietnamese.examTitle == "Đề mới")
        #expect(vietnamese.sectionTitle(2) == "Phần 2")
        #expect(ImportContentNames.sharedSectionTitle(locale: Self.vi) == "Phần chung")
        // Tiến trình test khoá tiếng Việt (InterfaceStrings.pinnedLocale): như dữ liệu mặc định của AuthoringData/ExamImport.
        #expect(DefaultContentNames.interface().examTitle == DefaultContentNames.vietnamese.examTitle)
        #expect(DefaultContentNames.interface().sectionTitle(1234) == DefaultContentNames.vietnamese.sectionTitle(1234))
        #expect(ImportContentNames.sharedSectionTitle() == ImportDefaults.sharedSectionTitle)
    }

    @Test("Đề mới (⌘N) và Thêm phần dùng tên theo ngôn ngữ giao diện; tên đã ghi không đổi theo ngôn ngữ")
    func newDocumentAndAddSection() {
        let document = ExamAuthoringDocument(names: .interface(locale: Self.en))
        #expect(document.draft.exam.title == "New Exam")
        #expect(document.draft.exam.sections.map(\.title) == ["Section 1"])

        let h = EditorHarness(document.draft)
        h.editor.contentNames = .interface(locale: Self.en)
        h.step { h.editor.addSection() }
        #expect(h.exam.sections.map(\.title) == ["Section 1", "Section 2"])
        // Đổi ngôn ngữ (mở lại cửa sổ ở giao diện tiếng Việt): phần mới theo tiếng Việt, phần cũ giữ nguyên.
        h.editor.contentNames = .interface(locale: Self.vi)
        h.step { h.editor.addSection() }
        #expect(h.exam.sections.map(\.title) == ["Section 1", "Section 2", "Phần 3"])

        // Đề mới mặc định (tiến trình test: tiếng Việt) và câu đầu của đề chưa có phần.
        let vietnamese = ExamAuthoringDocument()
        #expect(vietnamese.draft.exam.title == "Đề mới")
        #expect(vietnamese.draft.exam.sections.map(\.title) == ["Phần 1"])
        let empty = EditorHarness(ExamDraft(exam: Exam(title: "Rỗng", passPercent: 70, timeLimitMinutes: 60, sections: [])))
        empty.editor.contentNames = .interface(locale: Self.en)
        empty.step { empty.editor.addQuestion() }
        #expect(empty.exam.sections.map(\.title) == ["Section 1"])
    }

    @Test("Import đề…: bộ chạy thật đặt tên phần chung theo ngôn ngữ giao diện")
    func importRunnerUsesInterfaceName() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared-section-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        // Tên file rỗng (chỉ có đuôi): phần của .txt lấy tên phần chung (import.md phương án 8).
        let file = folder.appendingPathComponent(" .txt")
        try Data("Q1:\nHai cộng hai?\nA. 3\nB. 4\nCorrect Answer: B\n".utf8).write(to: file)

        let english = try await ImportFlowModel.runner(locale: Self.en)(file) { _ in }
        #expect(english.sections.map(\.title) == ["General Section"])
        let live = try await ImportFlowModel.liveRunner(file) { _ in }
        #expect(live.sections.map(\.title) == ["Phần chung"])
    }
}
