import AppKit
import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import PDFKit
import ReportFeature
import SessionFeature
import Testing

/// Xuất PDF… / In… đề từ cửa sổ soạn đề (docs/product/export-print.md, mục Bản Admin, Tên file và hộp lưu, In, Đề lớn):
/// mở được khi nào, hộp chọn (dòng lỗi, dòng nhắc `hideAnswers`), nội dung đang soạn kể cả chưa lưu, hộp lưu với tên gợi
/// ý, ghi file tạm rồi thay, huỷ không để lại file, lỗi ghi có lý do, In với tên việc in. Hộp của macOS là bản giả;
/// bộ soạn đề, bộ dựng trang, file và PDF là thật.
@MainActor
@Suite("Xuất PDF và In đề", .serialized, .timeLimit(.minutes(2)))
struct ExamReportFlowTests {
    // MARK: - Đồ giả

    /// Hộp lưu, hộp In, hộp báo lỗi, VoiceOver giả: ghi lại lời gọi.
    @MainActor
    final class FakePanels {
        /// File hộp lưu trả về; nil = người dùng Huỷ hộp lưu.
        var destination: URL?
        var suggestedNames: [String] = []
        var printed: [(pdf: ReportPDF, jobTitle: String)] = []
        var printSucceeds = true
        var failures: [(title: String, message: String)] = []
        var announcements: [String] = []
        var progressDelay: Duration = .seconds(3600)

        var services: ReportServices {
            ReportServices(
                chooseDestination: { [self] name in
                    suggestedNames.append(name)
                    return destination
                },
                print: { [self] pdf, title in
                    printed.append((pdf, title))
                    return printSucceeds
                },
                presentFailure: { [self] title, message in failures.append((title, message)) },
                announce: { [self] text in announcements.append(text) },
                appVersion: "9.9",
                progressDelay: progressDelay
            )
        }
    }

    struct Setup {
        let harness: EditorHarness
        let controller: ExamReportController
        let panels: FakePanels
        let folder: URL
    }

    func setUp(_ draft: ExamDraft = sampleDraft()) throws -> Setup {
        let harness = EditorHarness(draft)
        let controller = ExamReportController()
        let panels = FakePanels()
        controller.makeServices = { _ in panels.services }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExamReportFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return Setup(harness: harness, controller: controller, panels: panels, folder: folder)
    }

    /// Mở hộp chọn, chọn kiểu, bấm Xuất/In, chờ luồng dừng.
    @discardableResult
    func run(_ setup: Setup, _ action: ReportAction, kind: ExamReportKind) async throws -> ExamReportFlow {
        #expect(setup.controller.request(action, editor: setup.harness.editor))
        let flow = try #require(setup.controller.flow)
        flow.kind = kind
        flow.confirm()
        await flow.waitUntilIdle()
        return flow
    }

    func pdfText(of url: URL) throws -> String {
        let reader = try #require(PDFDocument(url: url))
        return try #require(reader.string)
    }

    /// Các file trong thư mục (kể cả file ẩn): kiểm không còn file tạm.
    func files(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    /// Đề có một lỗi kiểm đề (câu nhiều đáp án chưa có đáp án đúng) và giải thích.
    func draftWithError(hideAnswers: Bool = false) -> ExamDraft {
        var exam = sampleDraft().exam
        exam.hideAnswers = hideAnswers
        exam.sections[0].questions[0].explanation = "Giải thích câu Q1 riêng."
        exam.sections[1].questions[0] = makeQuestion(14, "Câu Đ nhiều đáp án", options: ["Một", "Hai", "Ba"], correct: [],
                                                     type: .multiple)
        return ExamDraft(exam: exam)
    }

    // MARK: - Mở được khi nào

    @Test("Xuất PDF/In mở được khi cửa sổ không có hộp thoại và không có lần xuất nào đang chạy; mục menu theo đúng điều kiện")
    func availability() throws {
        let setup = try setUp()
        let editor = setup.harness.editor
        let controller = setup.controller
        #expect(controller.commandTarget(for: editor).isEnabled)

        editor.alert = AuthoringAlert(title: "Lỗi", message: "x")
        #expect(!controller.commandTarget(for: editor).isEnabled)
        #expect(!controller.request(.exportPDF, editor: editor))
        editor.alert = nil

        editor.requestRemoveSection(at: 0)
        #expect(editor.sectionPendingRemoval != nil)
        #expect(!controller.commandTarget(for: editor).isEnabled)
        #expect(!controller.request(.print, editor: editor))
        editor.sectionPendingRemoval = nil

        // Mục menu gọi đúng luồng; đang có hộp chọn thì tắt và bấm lại không mở thêm.
        controller.commandTarget(for: editor).perform(.print)
        let flow = try #require(controller.flow)
        #expect(flow.action == .print)
        #expect(!controller.commandTarget(for: editor).isEnabled)
        #expect(!controller.request(.exportPDF, editor: editor))
        #expect(controller.flow === flow)
        // Huỷ: hết lần xuất, mở lại được.
        flow.cancel()
        #expect(controller.flow == nil)
        #expect(controller.commandTarget(for: editor).isEnabled)
        // So sánh theo đối tượng và trạng thái bật/tắt (menu chỉ dựng lại khi đổi), không theo closure.
        #expect(controller.commandTarget(for: editor) == controller.commandTarget(for: editor))
    }

    @Test("Kiểu chọn sẵn luôn là Chỉ đề, không nhớ lần trước: chọn Có đáp án một lần thì lần mở sau vẫn là Chỉ đề; Return xuất ngay")
    func defaultKindIsQuestionsOnlyEveryTime() async throws {
        #expect(ExamReportKind.default == .questionsOnly)
        let setup = try setUp(draftWithError())
        let editor = setup.harness.editor
        for action in [ReportAction.exportPDF, .print] {
            #expect(setup.controller.request(action, editor: editor))
            let flow = try #require(setup.controller.flow)
            #expect(flow.kind == .questionsOnly, "\(action)")
            #expect(flow.canConfirm, "Return xác nhận ngay")
            flow.cancel()
        }

        // Xuất một lần với Có đáp án.
        let first = setup.folder.appendingPathComponent("co-dap-an.pdf")
        setup.panels.destination = first
        try await run(setup, .exportPDF, kind: .withAnswers)
        #expect(try pdfText(of: first).contains("Đáp án đúng"))

        // Lần mở sau (cả In): lại là Chỉ đề; bấm Xuất ngay (không chọn gì) ra bản không đáp án.
        #expect(setup.controller.request(.print, editor: editor))
        let reopened = try #require(setup.controller.flow)
        #expect(reopened.kind == .questionsOnly)
        reopened.cancel()
        let second = setup.folder.appendingPathComponent("chi-de.pdf")
        setup.panels.destination = second
        #expect(setup.controller.request(.exportPDF, editor: editor))
        let flow = try #require(setup.controller.flow)
        #expect(flow.kind == .questionsOnly)
        flow.confirm()
        await flow.waitUntilIdle()
        #expect(setup.panels.suggestedNames.last == "Đề thử (đề).pdf")
        let text = try pdfText(of: second)
        #expect(!text.contains("Đáp án đúng") && !text.contains("Giải thích câu Q1 riêng."))
        #expect(text.contains("Câu Đ nhiều đáp án"))
        // Xuất không đổi đề (không có bước Hoàn tác).
        #expect(setup.harness.undoCount == 0)
    }

    @Test("Hộp chọn: dòng lỗi khi đề còn lỗi; dòng nhắc khi đề hideAnswers chọn Có đáp án")
    func optionsSheet() async throws {
        let clean = try setUp()
        #expect(clean.controller.request(.exportPDF, editor: clean.harness.editor))
        let cleanFlow = try #require(clean.controller.flow)
        #expect(cleanFlow.title == "Xuất PDF đề")
        #expect(cleanFlow.confirmTitle == "Xuất PDF…")
        #expect(cleanFlow.errorCount == 0)
        #expect(cleanFlow.errorNotice == nil)
        #expect(cleanFlow.canConfirm)
        cleanFlow.kind = .withAnswers
        #expect(cleanFlow.hideAnswersNotice == nil, "đề không hideAnswers thì không nhắc")
        cleanFlow.cancel()

        // Đề còn lỗi (kể cả lúc bộ soạn đề chưa kiểm xong lần sửa vừa rồi): đếm đúng nội dung lúc mở hộp chọn.
        let broken = try setUp(draftWithError(hideAnswers: true))
        await broken.harness.editor.waitForValidation()
        #expect(broken.harness.editor.issuesAreCurrent)
        #expect(broken.controller.request(.print, editor: broken.harness.editor))
        let flow = try #require(broken.controller.flow)
        #expect(flow.title == "In đề")
        #expect(flow.confirmTitle == "In…")
        #expect(flow.errorCount == 1)
        #expect(flow.errorNotice == "Đề còn 1 lỗi; PDF in đúng như đang soạn")
        flow.kind = .withAnswers
        #expect(flow.hideAnswersNotice == "Đề này ẩn đáp án với học viên. Chỉ gửi bản có đáp án cho người được phép xem")
        flow.kind = .questionsOnly
        #expect(flow.hideAnswersNotice == nil)
        flow.cancel()

        // Sửa thêm một lỗi rồi mở ngay (kiểm đề chưa chạy): vẫn đếm đúng.
        let editor = broken.harness.editor
        broken.harness.step { editor.setCorrect(of: QuestionPath(section: 0, question: 0), at: 0, false) }
        #expect(!editor.issuesAreCurrent)
        #expect(broken.controller.request(.exportPDF, editor: editor))
        #expect(try #require(broken.controller.flow).errorCount == 2)
        broken.controller.flow?.cancel()
    }

    // MARK: - Xuất PDF

    @Test("Xuất PDF: nội dung đang soạn (chưa lưu, còn lỗi), hộp lưu với tên gợi ý, ghi file, VoiceOver đọc xong, không để lại file tạm")
    func exportWritesCurrentContent() async throws {
        let setup = try setUp(draftWithError())
        let editor = setup.harness.editor
        // Sửa chưa lưu: PDF có chữ mới.
        setup.harness.step { editor.setQuestionText(at: QuestionPath(section: 0, question: 1), "Câu Đã sửa chưa lưu") }
        setup.harness.step { editor.setTitle("Đề Địa lý") }
        let destination = setup.folder.appendingPathComponent("Đề Địa lý (đề).pdf")
        setup.panels.destination = destination

        let flow = try await run(setup, .exportPDF, kind: .questionsOnly)
        #expect(flow.step == .finished)
        #expect(setup.controller.flow == nil)
        #expect(setup.panels.suggestedNames == ["Đề Địa lý (đề).pdf"])
        #expect(setup.panels.announcements == ["Đã xuất PDF"])
        #expect(setup.panels.failures.isEmpty)
        #expect(try files(in: setup.folder) == ["Đề Địa lý (đề).pdf"])
        let text = try pdfText(of: destination)
        // Phương án 19: thông tin đề và Phần 1 cùng nằm ở trang 1 (không có trang bìa riêng).
        let firstPage = try #require(PDFDocument(url: destination)?.page(at: 0)?.string)
        for expected in ["Đề Địa lý", "Số câu", "Phần 1", "Câu 1/4", "Q1"] {
            #expect(firstPage.contains(expected), "trang 1 thiếu \(expected)")
        }
        for expected in ["Đề Địa lý", "Câu Đã sửa chưa lưu", "Câu Đ nhiều đáp án", "Chọn 0 đáp án", "Phần 2"] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        for forbidden in ["Đáp án đúng", "Giải thích câu Q1 riêng.", "Có đáp án"] {
            #expect(!text.contains(forbidden), "Chỉ đề không được có \(forbidden)")
        }
        // Xuất không đổi đề, không đánh dấu "Đã sửa" thêm (không có bước Hoàn tác mới).
        #expect(editor.exam.title == "Đề Địa lý")
        #expect(setup.harness.undoCount == 2)
    }

    @Test("Xuất PDF Có đáp án: “Đáp án đúng” và giải thích có trong file; tên gợi ý “(có đáp án)”; đè file có sẵn")
    func exportWithAnswersReplacesExisting() async throws {
        let setup = try setUp(draftWithError())
        let destination = setup.folder.appendingPathComponent("cu.pdf")
        try Data("cũ".utf8).write(to: destination)
        setup.panels.destination = destination
        try await run(setup, .exportPDF, kind: .withAnswers)
        #expect(setup.panels.suggestedNames == ["Đề thử (có đáp án).pdf"])
        let text = try pdfText(of: destination)
        for expected in ["Đáp án đúng", "Giải thích câu Q1 riêng.", "Có đáp án"] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        #expect(try files(in: setup.folder) == ["cu.pdf"])
    }

    @Test("Huỷ hộp chọn hoặc hộp lưu: không ghi gì, không báo gì")
    func cancelBeforeWriting() async throws {
        let setup = try setUp()
        #expect(setup.controller.request(.exportPDF, editor: setup.harness.editor))
        try #require(setup.controller.flow).cancel()
        #expect(setup.controller.flow == nil)
        #expect(setup.panels.suggestedNames.isEmpty)

        // Return rồi Esc ngay (lần xuất đã xếp hàng chưa chạy): không mở hộp lưu.
        #expect(setup.controller.request(.exportPDF, editor: setup.harness.editor))
        let quick = try #require(setup.controller.flow)
        quick.kind = .questionsOnly
        quick.confirm()
        quick.cancel()
        await quick.waitUntilIdle()
        #expect(setup.panels.suggestedNames.isEmpty)
        #expect(setup.controller.flow == nil)

        // Huỷ hộp lưu.
        setup.panels.destination = nil
        try await run(setup, .exportPDF, kind: .questionsOnly)
        #expect(setup.panels.suggestedNames.count == 1)
        #expect(setup.panels.failures.isEmpty && setup.panels.announcements.isEmpty)
        #expect(try files(in: setup.folder).isEmpty)
        #expect(setup.controller.flow == nil)
    }

    /// Đề đủ dài để còn đang dựng khi huỷ.
    func longDraft() -> ExamDraft {
        largeDraft(questions: 400)
    }

    @Test("Huỷ khi đang dựng (sheet tiến độ): không để lại file dở, file đích có sẵn giữ nguyên")
    func cancelWhileRendering() async throws {
        let setup = try setUp(longDraft())
        setup.panels.progressDelay = .zero
        let destination = setup.folder.appendingPathComponent("de.pdf")
        try Data("cũ".utf8).write(to: destination)
        setup.panels.destination = destination
        #expect(setup.controller.request(.exportPDF, editor: setup.harness.editor))
        let flow = try #require(setup.controller.flow)
        flow.kind = .withAnswers
        flow.confirm()
        // Chờ sheet tiến độ hiện (dựng lâu hơn progressDelay) rồi bấm Huỷ.
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(30)
        while flow.sheetContent != .progress, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(flow.sheetContent == .progress)
        #expect(flow.presentsSheet)
        flow.cancel()
        await flow.waitUntilIdle()
        #expect(flow.step == .finished)
        #expect(try files(in: setup.folder) == ["de.pdf"])
        #expect(try Data(contentsOf: destination) == Data("cũ".utf8))
        #expect(setup.panels.failures.isEmpty && setup.panels.announcements.isEmpty)
    }

    @Test("Thoát app hoặc đóng cửa sổ khi đang xuất: hộp chọn như Huỷ; tiến độ đang hiện thì huỷ; không để lại file")
    func dismissalCancels() async throws {
        let setup = try setUp(longDraft())
        // Hộp chọn bị đóng (SwiftUI đóng sheet khi thoát).
        #expect(setup.controller.request(.print, editor: setup.harness.editor))
        try #require(setup.controller.flow).sheetDismissed()
        #expect(setup.controller.flow == nil)

        // Sheet tiến độ bị đóng: huỷ lần dựng.
        setup.panels.progressDelay = .zero
        let destination = setup.folder.appendingPathComponent("de.pdf")
        setup.panels.destination = destination
        #expect(setup.controller.request(.exportPDF, editor: setup.harness.editor))
        let flow = try #require(setup.controller.flow)
        flow.kind = .questionsOnly
        flow.confirm()
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(30)
        while flow.sheetContent != .progress, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        flow.sheetDismissed()
        await flow.waitUntilIdle()
        #expect(try files(in: setup.folder).isEmpty)

        // Cửa sổ đóng giữa chừng (cancelAll).
        #expect(setup.controller.request(.exportPDF, editor: setup.harness.editor))
        let closing = try #require(setup.controller.flow)
        closing.kind = .questionsOnly
        closing.confirm()
        while closing.step != .rendering, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        setup.controller.cancelAll()
        await closing.waitUntilIdle()
        #expect(closing.step == .finished)
        #expect(try files(in: setup.folder).isEmpty)
        #expect(setup.panels.failures.isEmpty)
    }

    @Test("Lỗi ghi có lý do, không để lại file: thư mục không còn")
    func writeError() async throws {
        let setup = try setUp()
        setup.panels.destination = setup.folder.appendingPathComponent("khong-co/de.pdf")
        try await run(setup, .exportPDF, kind: .questionsOnly)
        #expect(setup.panels.failures.map(\.title) == ["Không xuất được PDF"])
        #expect(setup.panels.failures.map(\.message) == [ReportWriteError.folderMissing.message])
        #expect(setup.panels.announcements.isEmpty)
        #expect(try files(in: setup.folder).isEmpty)
    }

    // MARK: - In

    @Test("In: dựng PDF rồi mở hộp In với tên việc in là tên file gợi ý bỏ .pdf; không tạo được thao tác In thì báo lỗi")
    func printing() async throws {
        let setup = try setUp()
        try await run(setup, .print, kind: .withAnswers)
        let printed = try #require(setup.panels.printed.first)
        #expect(printed.jobTitle == "Đề thử (có đáp án)")
        #expect(printed.pdf.pageCount > 0)
        let reader = try #require(PDFDocument(data: printed.pdf.data))
        #expect(reader.string?.contains("Đáp án đúng") == true)
        #expect(setup.panels.failures.isEmpty)
        #expect(setup.controller.flow == nil)

        setup.panels.printSucceeds = false
        try await run(setup, .print, kind: .questionsOnly)
        #expect(setup.panels.printed.last?.jobTitle == "Đề thử (đề)")
        #expect(setup.panels.failures.map(\.title) == ["Không in được"])
        #expect(setup.panels.failures.map(\.message) == [ReportStrings.printUnavailable])
    }

    @Test("In: cửa sổ đóng (huỷ) đúng lúc dựng vừa xong, sau lần kiểm huỷ cuối của bộ dựng trang: không mở hộp In, không báo lỗi")
    func cancelAfterRenderDoesNotPrint() async throws {
        let setup = try setUp()
        #expect(setup.controller.request(.print, editor: setup.harness.editor))
        let flow = try #require(setup.controller.flow)
        var rendered = false
        flow.didRender = {
            rendered = true
            setup.controller.cancelAll()
        }
        flow.confirm()
        await flow.waitUntilIdle()
        #expect(rendered)
        #expect(setup.panels.printed.isEmpty, "huỷ sau khi dựng xong không được mở hộp In")
        #expect(setup.panels.failures.isEmpty)
        #expect(flow.step == .finished)
        #expect(setup.controller.flow == nil)
    }

    @Test("In ra file (không hộp thoại): bản PDF đề co vừa khổ giấy, chữ còn nguyên")
    func printToFile() async throws {
        let setup = try setUp(draftWithError())
        try await run(setup, .print, kind: .questionsOnly)
        let pdf = try #require(setup.panels.printed.first?.pdf)
        let output = setup.folder.appendingPathComponent("in.pdf")
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 612, height: 792)
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = output
        let operation = try #require(ReportPrinting.printOperation(for: pdf, jobTitle: "Đề thử (đề)", printInfo: info))
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        #expect(operation.run())
        let printed = try #require(PDFDocument(url: output))
        #expect(printed.pageCount == pdf.pageCount)
        #expect(printed.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792))
        #expect(printed.string?.contains("Câu Đ nhiều đáp án") == true)
    }
}
