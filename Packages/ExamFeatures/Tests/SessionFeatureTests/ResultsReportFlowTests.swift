import ExamFile
import ExamKit
import Foundation
import LibraryData
import PDFKit
import ReportFeature
@testable import SessionFeature
@testable import SessionModel
import Testing

/// Xuất PDF… / In… kết quả từ cửa sổ làm bài (docs/product/export-print.md, mục Bản Học viên, Tên file và hộp lưu, In,
/// Đề lớn): bật/tắt theo màn, hộp chọn (mức xem lại nhớ lần trước, tắt kèm lý do), hộp lưu với tên gợi ý, ghi file tạm
/// rồi thay, huỷ không để lại file, lỗi ghi có lý do, In, và PDF ghi ra (đọc lại bằng PDFKit) không lộ đáp án. Hộp của
/// macOS là bản giả (`FakeReportPanels`); bộ dựng trang, file và PDF là thật.
@MainActor
@Suite("Xuất PDF và In kết quả", .serialized, .timeLimit(.minutes(2)))
struct ResultsReportFlowTests {
    // MARK: - Đồ giả

    /// Hộp lưu, hộp In, hộp báo lỗi, VoiceOver giả: ghi lại lời gọi.
    @MainActor
    final class FakeReportPanels {
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
        let harness: Harness
        let coordinator: SessionCoordinator
        let panels: FakeReportPanels
        let workspace: SessionWorkspace
    }

    func setUp(candidateName: String = "Nguyễn Văn Đức") throws -> Setup {
        let harness = Harness(candidateName: candidateName)
        let coordinator = SessionCoordinator(environment: harness.environment)
        let panels = FakeReportPanels()
        coordinator.reportServices = panels.services
        coordinator.reportPreferences = harness.preferences
        return Setup(harness: harness, coordinator: coordinator, panels: panels, workspace: try SessionWorkspace())
    }

    /// Đề hai phần; mỗi câu có lời giải riêng để kiểm ẩn/hiện.
    func exam(hideAnswers: Bool = false, title: String = "Địa lý Đông Nam Á") -> Exam {
        makeExam(
            title: title,
            code: "DL-01",
            hideAnswers: hideAnswers,
            sections: [
                SectionSpec(title: "Địa hình", questions: [
                    singleQuestion("Đỉnh núi cao nhất?", explanation: "Lời giải 1"),
                    singleQuestion("Đồng bằng nào lớn nhất?", explanation: "Lời giải 2"),
                ]),
                SectionSpec(title: "Dân cư", questions: [
                    singleQuestion("Đô thị đông dân nhất?", explanation: "Lời giải 3"),
                ]),
            ]
        )
    }

    /// Thi đề `exam` trong cửa sổ làm bài theo `plan` ("c" đúng, "w" sai, "-" bỏ trống) rồi nộp: cửa sổ ở Kết quả.
    func submit(_ setup: Setup, _ exam: Exam, plan: String) async throws -> SessionWindowModel {
        if setup.harness.library.entries[exam.id] == nil { setup.harness.library.add(exam) }
        await setup.coordinator.openPreExam(examID: exam.id, mode: .exam)
        #expect(await setup.coordinator.startPreExam())
        let window = try #require(setup.coordinator.window)
        let attempt = try #require(window.attempt)
        for (index, step) in plan.enumerated() {
            attempt.goTo(index: index)
            switch step {
            case "c": attempt.answerCorrectly()
            case "w": attempt.answerWrongly()
            default: break
            }
        }
        attempt.openReview()
        window.requestSubmit()
        if attempt.isConfirmingSubmit { window.confirmSubmit() }
        #expect(window.screen == .results)
        return window
    }

    /// Mở hộp chọn, chọn mức (nếu có), bấm Xuất/In, chờ luồng dừng.
    @discardableResult
    func run(
        _ window: SessionWindowModel,
        _ action: ReportAction,
        level: ResultsReviewLevel? = nil
    ) async throws -> ResultsReportFlow {
        #expect(window.requestReport(action))
        let flow = try #require(window.reportFlow)
        if let level { flow.level = level }
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

    func folder(_ setup: Setup, _ name: String = "Xuat") throws -> URL {
        let url = setup.workspace.root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Bật/tắt

    @Test("Xuất PDF/In bật ở Kết quả và Xem lại bài; tắt khi làm bài, Rà soát, có sheet/hộp thoại hay đang xuất")
    func availability() async throws {
        let setup = try setUp()
        let exam = exam()
        setup.harness.library.add(exam)
        await setup.coordinator.openPreExam(examID: exam.id, mode: .exam)
        #expect(await setup.coordinator.startPreExam())
        let window = try #require(setup.coordinator.window)
        let attempt = try #require(window.attempt)
        #expect(!window.canRequestReport)
        #expect(!SessionMenuState(window: window).canReport)
        #expect(!window.requestReport(.exportPDF))
        attempt.answerCorrectly()
        attempt.openReview()
        #expect(!window.canRequestReport, "Rà soát")
        window.requestSubmit()
        #expect(attempt.isConfirmingSubmit)
        #expect(!window.canRequestReport, "hộp xác nhận nộp")
        window.confirmSubmit()

        #expect(window.screen == .results)
        #expect(window.canRequestReport)
        #expect(SessionMenuState(window: window).canReport)
        #expect(SessionMenuState(window: window).enabled.isEmpty, "menu Bài thi tắt sau khi nộp")
        window.setModal(.imageZoom, presented: true)
        #expect(!SessionMenuState(window: window).canReport)
        window.setModal(.imageZoom, presented: false)

        #expect(await window.openAnswerReview())
        #expect(SessionMenuState(window: window).canReport)

        // Hộp chọn đang mở: menu và nút tắt, không mở hộp thứ hai.
        #expect(window.requestReport(.print))
        #expect(window.hasModal)
        #expect(!SessionMenuState(window: window).canReport)
        #expect(!window.requestReport(.exportPDF))
        let flow = try #require(window.reportFlow)
        #expect(flow.action == .print)
        #expect(flow.presentsSheet)
        flow.cancel()
        #expect(window.reportFlow == nil)
        #expect(window.canRequestReport)
        #expect(setup.panels.suggestedNames.isEmpty)
        #expect(setup.panels.printed.isEmpty)

        // Không có dịch vụ hộp (không gắn shell): không mở gì.
        setup.coordinator.reportServices = nil
        #expect(!window.requestReport(.exportPDF))
    }

    // MARK: - Xuất PDF

    @Test("Xuất PDF: hộp lưu với tên gợi ý, ghi file, đọc lại đúng nội dung; không để lại file tạm; VoiceOver đọc xong")
    func exportWritesFile() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        let directory = try folder(setup)
        let destination = directory.appendingPathComponent("ket-qua.pdf")
        setup.panels.destination = destination

        let flow = try await run(window, .exportPDF)
        #expect(flow.step == .finished)
        #expect(window.reportFlow == nil)
        let results = try #require(window.results)
        #expect(setup.panels.suggestedNames == [ReportFileName.results(
            examTitle: "Địa lý Đông Nam Á",
            candidateName: "Nguyễn Văn Đức",
            submittedAt: results.attempt.submittedAt
        )])
        #expect(setup.panels.suggestedNames.first?.hasPrefix("Địa lý Đông Nam Á - Nguyễn Văn Đức - ") == true)
        #expect(setup.panels.announcements == ["Đã xuất PDF"])
        #expect(setup.panels.failures.isEmpty)
        #expect(try files(in: directory) == ["ket-qua.pdf"])

        let text = try pdfText(of: destination)
        for expected in ["Địa lý Đông Nam Á", "Nguyễn Văn Đức", "Trượt", "Theo phần",
                         "Kết quả luyện tập, không có giá trị xác nhận",
                         // Mức mặc định: Câu sai và chưa làm (câu 2 sai, câu 3 chưa làm).
                         "Câu sai và chưa làm · 2 câu", "Câu 2/3", "Câu 3/3", "Đáp án đúng", "Lời giải 2"] {
            #expect(text.contains(expected), "thiếu \(expected)")
        }
        #expect(!text.contains("Câu 1/3"))
        // Không ghi thời điểm xuất (export-print.md phương án 17); phiên bản chỉ ở Creator.
        #expect(!text.contains("Xuất bằng"))
        #expect(!text.contains("9.9"))
        let attributes = PDFDocument(url: destination)?.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.creatorAttribute] as? String == "Exam Suite 9.9")
    }

    @Test("Mức xem lại: nhớ lựa chọn lần trước (chung mọi đề); Không thì chỉ phần kết quả; Tất cả câu đủ mọi câu")
    func reviewLevelRemembered() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        let directory = try folder(setup)

        #expect(setup.harness.preferences.reportReviewLevel == .incorrectAndUnanswered)
        #expect(window.requestReport(.exportPDF))
        #expect(window.reportFlow?.level == .incorrectAndUnanswered, "mặc định: Câu sai và chưa làm")
        #expect(window.reportFlow?.isLevelSelectable == true)
        window.reportFlow?.cancel()

        setup.panels.destination = directory.appendingPathComponent("khong.pdf")
        try await run(window, .exportPDF, level: ResultsReviewLevel.none)
        #expect(setup.harness.preferences.reportReviewLevel == ResultsReviewLevel.none)
        let none = try pdfText(of: directory.appendingPathComponent("khong.pdf"))
        #expect(none.contains("Theo phần"))
        #expect(!none.contains("Xem lại bài"))
        #expect(!none.contains("Bạn chọn"))

        // Lần sau (kể cả đề khác) mở với lựa chọn lần trước.
        #expect(window.requestReport(.exportPDF))
        #expect(window.reportFlow?.level == ResultsReviewLevel.none)
        window.reportFlow?.cancel()
        let other = try await submit(setup, exam(title: "Lịch sử"), plan: "ccc")
        #expect(other.requestReport(.print))
        #expect(other.reportFlow?.level == ResultsReviewLevel.none)
        other.reportFlow?.cancel()

        setup.panels.destination = directory.appendingPathComponent("tat-ca.pdf")
        try await run(other, .exportPDF, level: .all)
        #expect(setup.harness.preferences.reportReviewLevel == .all)
        let all = try pdfText(of: directory.appendingPathComponent("tat-ca.pdf"))
        for number in 1 ... 3 { #expect(all.contains("Câu \(number)/3"), "thiếu câu \(number)") }
        #expect(all.contains("Tất cả câu · 3 câu"))
    }

    @Test("Cài đặt thật: mức xem lại ghi vào defaults của app, giá trị lạ thì về mặc định")
    func reviewLevelPreference() throws {
        let workspace = try SessionWorkspace()
        let preferences = UserDefaultsSessionPreferences(defaults: workspace.defaults)
        #expect(preferences.reportReviewLevel == .incorrectAndUnanswered)
        preferences.reportReviewLevel = .all
        #expect(workspace.defaults.string(forKey: UserDefaultsSessionPreferences.reportReviewLevelKey) == "all")
        #expect(UserDefaultsSessionPreferences(defaults: workspace.defaults).reportReviewLevel == .all)
        workspace.defaults.set("lạ", forKey: UserDefaultsSessionPreferences.reportReviewLevelKey)
        #expect(preferences.reportReviewLevel == .incorrectAndUnanswered)
    }

    @Test("hideAnswers, từ đầu tới file: PDF có lựa chọn của người làm, không có “Đáp án đúng” và giải thích")
    func hideAnswersEndToEnd() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(hideAnswers: true), plan: "cw-")
        let directory = try folder(setup)
        for level in [ResultsReviewLevel.all, .incorrectAndUnanswered] {
            let destination = directory.appendingPathComponent("an-dap-an-\(level.rawValue).pdf")
            setup.panels.destination = destination
            try await run(window, .exportPDF, level: level)
            let reader = try #require(PDFDocument(url: destination))
            let text = try #require(reader.string)
            #expect(!text.contains("Đáp án đúng"))
            #expect(reader.findString("Đáp án đúng", withOptions: .caseInsensitive).isEmpty)
            #expect(!text.contains("Lời giải"))
            #expect(!text.contains("Giải thích"))
            #expect(text.contains("Bạn chọn"))
            #expect(text.contains("Đề này ẩn đáp án: chỉ hiện lựa chọn của bạn và kết quả đúng/sai."))
        }
        // In cũng dùng đúng PDF đó.
        try await run(window, .print, level: .all)
        let printed = try #require(setup.panels.printed.last)
        let printedText = try #require(PDFDocument(data: printed.pdf.data)?.string)
        #expect(!printedText.contains("Đáp án đúng"))
        #expect(!printedText.contains("Lời giải"))
    }

    @Test("Lần thi cũ có câu đã sửa: PDF không có “Bạn chọn”/“Đáp án đúng” ở câu đó; đọc file đề lúc bấm Xuất")
    func historyEditedQuestion() async throws {
        let setup = try setUp()
        let original = exam()
        let submitted = try await submit(setup, original, plan: "cww")
        let attempt = try #require(submitted.results?.attempt)
        setup.coordinator.returnToLibrary()
        var edited = original
        edited.sections[0].questions[1].text = "Đồng bằng nào lớn nhất? (sửa)"
        setup.harness.library.packages[original.id] = .success(ExamPackage(exam: edited))

        #expect(setup.coordinator.openHistoryAttempt(attempt) == .opened)
        let window = try #require(setup.coordinator.window)
        let reads = setup.harness.library.readCount
        let destination = try folder(setup).appendingPathComponent("cu.pdf")
        setup.panels.destination = destination
        try await run(window, .exportPDF, level: .all)
        #expect(setup.harness.library.readCount == reads + 1, "đọc file đề hiện tại như Xem lại bài")
        let reader = try #require(PDFDocument(url: destination))
        #expect(reader.findString("Câu này đã được sửa sau lần thi", withOptions: []).count == 1)
        #expect(reader.findString("Không hiện lựa chọn của bạn vì câu đã sửa sau lần thi", withOptions: []).count == 1)
        // Câu 1 và 3 không đổi, đã trả lời: “Bạn chọn” đúng hai lần; câu 2 (sửa) không có.
        #expect(reader.findString("Bạn chọn", withOptions: []).count == 2)
        #expect(reader.string?.contains("Đồng bằng nào lớn nhất? (sửa)") == true)
    }

    @Test("Mở từ Xem lại bài: dùng đúng Xem lại đang mở, không đọc lại file đề")
    func reusesOpenedReview() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        #expect(await window.openAnswerReview())
        let reads = setup.harness.library.readCount
        setup.panels.destination = try folder(setup).appendingPathComponent("xem-lai.pdf")
        try await run(window, .exportPDF, level: .all)
        #expect(setup.harness.library.readCount == reads)
        #expect(try pdfText(of: try #require(setup.panels.destination)).contains("Tất cả câu · 3 câu"))
    }

    // MARK: - Xem lại không mở được

    @Test("Xem lại không mở được (đề không còn trong thư viện, chi tiết lần thi hỏng): lựa chọn tắt kèm lý do, chỉ xuất kết quả")
    func levelDisabledWhenReviewUnavailable() async throws {
        let setup = try setUp()
        let original = exam()
        let submitted = try await submit(setup, original, plan: "cw-")
        let attempt = try #require(submitted.results?.attempt)
        setup.coordinator.returnToLibrary()
        setup.harness.preferences.reportReviewLevel = .all
        let directory = try folder(setup)

        // Đề không còn trong thư viện: cùng lý do với nút Xem lại bài.
        setup.harness.library.remove(original.id)
        setup.coordinator.openHistoryAttempt(attempt)
        var window = try #require(setup.coordinator.window)
        #expect(window.requestReport(.exportPDF))
        var flow = try #require(window.reportFlow)
        #expect(!flow.isLevelSelectable)
        #expect(flow.levelUnavailableReason == window.results?.reviewUnavailableReason)
        #expect(flow.levelUnavailableReason == "Đề không còn trong thư viện nên không xem lại được.")
        #expect(flow.effectiveLevel == ResultsReviewLevel.none)
        #expect(flow.level == .all, "lựa chọn đã nhớ không bị ghi đè")
        setup.panels.destination = directory.appendingPathComponent("mat-de.pdf")
        flow.confirm()
        await flow.waitUntilIdle()
        #expect(setup.harness.preferences.reportReviewLevel == .all)
        var text = try pdfText(of: directory.appendingPathComponent("mat-de.pdf"))
        #expect(text.contains("Theo phần"))
        #expect(!text.contains("Xem lại bài"))

        // Chi tiết lần thi không đọc được: tóm tắt, không có Theo phần, không có Xem lại.
        setup.coordinator.returnToLibrary()
        setup.harness.library.payloads[attempt.id] = Data("hỏng".utf8)
        setup.coordinator.openHistoryAttempt(attempt)
        window = try #require(setup.coordinator.window)
        #expect(window.requestReport(.exportPDF))
        flow = try #require(window.reportFlow)
        #expect(flow.levelUnavailableReason == "Không đọc được chi tiết lần thi này")
        setup.panels.destination = directory.appendingPathComponent("hong.pdf")
        flow.confirm()
        await flow.waitUntilIdle()
        text = try pdfText(of: directory.appendingPathComponent("hong.pdf"))
        #expect(text.contains("Không đọc được chi tiết lần thi này"))
        #expect(!text.contains("Theo phần"))
        #expect(!text.contains("Xem lại bài"))
    }

    @Test("Đọc file đề lỗi lúc bấm Xuất/In với phần xem lại: đóng hộp chọn, báo lỗi kèm lý do, không xuất/in gì; mở lại chọn Không thì chỉ xuất kết quả")
    func reviewLoadFailureShowsErrorAndExportsNothing() async throws {
        let setup = try setUp()
        let original = exam()
        let submitted = try await submit(setup, original, plan: "cw-")
        let attempt = try #require(submitted.results?.attempt)
        setup.coordinator.returnToLibrary()
        // Thẻ còn Sẵn sàng nhưng file đã hỏng.
        setup.harness.library.packages[original.id] = .failure(.unreadable(reason: "File hỏng."))
        setup.coordinator.openHistoryAttempt(attempt)
        let window = try #require(setup.coordinator.window)
        let directory = try folder(setup)
        setup.panels.destination = directory.appendingPathComponent("khong-co.pdf")

        for action in [ReportAction.exportPDF, .print] {
            #expect(window.requestReport(action))
            let flow = try #require(window.reportFlow)
            #expect(flow.isLevelSelectable)
            flow.level = .incorrectAndUnanswered
            flow.confirm()
            await flow.waitUntilIdle()
            #expect(flow.step == .finished)
            #expect(!flow.presentsSheet)
            #expect(window.reportFlow == nil)
        }
        #expect(setup.panels.failures.map(\.title) == Array(repeating: "Không đọc được file đề để làm phần xem lại", count: 2))
        #expect(setup.panels.failures.map(\.message) == ["File hỏng.", "File hỏng."])
        #expect(setup.panels.suggestedNames.isEmpty, "không mở hộp lưu")
        #expect(setup.panels.printed.isEmpty, "không mở hộp In")
        #expect(setup.panels.announcements.isEmpty)
        #expect(try files(in: directory).isEmpty)
        #expect(setup.harness.library.refreshRequests == [original.id, original.id])

        // Mở lại, chọn Không: chỉ phần kết quả, không đọc file đề.
        let reads = setup.harness.library.readCount
        try await run(window, .exportPDF, level: ResultsReviewLevel.none)
        #expect(setup.harness.library.readCount == reads)
        let text = try pdfText(of: directory.appendingPathComponent("khong-co.pdf"))
        #expect(text.contains("Theo phần"))
        #expect(!text.contains("Xem lại bài"))
    }

    // MARK: - Huỷ

    @Test("Huỷ hộp chọn hoặc hộp lưu: không ghi gì, không báo gì")
    func cancelBeforeWriting() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        #expect(window.requestReport(.exportPDF))
        window.reportFlow?.cancel()
        #expect(window.reportFlow == nil)
        #expect(setup.panels.suggestedNames.isEmpty)

        // Return rồi Esc (hay đóng sheet khi thoát app) ngay, trước khi lần xuất đã xếp hàng kịp chạy (review #46, L1).
        let directory = try folder(setup)
        setup.panels.destination = directory.appendingPathComponent("race.pdf")
        let dismissals: [@MainActor (ResultsReportFlow) -> Void] = [{ $0.cancel() }, { $0.sheetDismissed() }]
        for dismiss in dismissals {
            #expect(window.requestReport(.exportPDF))
            let flow = try #require(window.reportFlow)
            flow.confirm()
            dismiss(flow)
            #expect(window.reportFlow == nil)
            await flow.waitUntilIdle()
            #expect(flow.step == .finished)
        }
        #expect(setup.panels.suggestedNames.isEmpty, "không mở hộp lưu sau khi đã Huỷ")
        #expect(try files(in: directory).isEmpty)
        #expect(setup.panels.announcements.isEmpty)
        #expect(window.canRequestReport)

        setup.panels.destination = nil
        let flow = try await run(window, .exportPDF)
        #expect(flow.step == .finished)
        #expect(setup.panels.suggestedNames.count == 1)
        #expect(setup.panels.announcements.isEmpty)
        #expect(setup.panels.failures.isEmpty)
        #expect(window.reportFlow == nil)
    }

    /// Đề 40 câu, câu dài: PDF nhiều trang để kịp huỷ giữa chừng.
    func longExam() -> Exam {
        let long = String(repeating: "Nội dung dài để kéo PDF qua nhiều trang. ", count: 12)
        return makeExam(
            title: "Đề dài",
            sections: [SectionSpec(title: "Phần 1", questions: (1 ... 40).map { singleQuestion("Câu \($0). \(long)") })]
        )
    }

    @Test("Huỷ khi đang dựng trang (sheet tiến độ): không để lại file dở, file đích có sẵn giữ nguyên")
    func cancelWhileRendering() async throws {
        let setup = try setUp()
        setup.panels.progressDelay = .zero
        setup.coordinator.reportServices = setup.panels.services
        let window = try await submit(setup, longExam(), plan: String(repeating: "w", count: 40))
        let directory = try folder(setup)
        let destination = directory.appendingPathComponent("da-co.pdf")
        try Data("bản cũ".utf8).write(to: destination)
        setup.panels.destination = destination

        #expect(window.requestReport(.exportPDF))
        let flow = try #require(window.reportFlow)
        flow.level = .all
        flow.confirm()
        // Chờ tới khi đang vẽ trang (sheet tiến độ hiện) rồi bấm Huỷ.
        var waited = 0
        while !(flow.step == .rendering && flow.isProgressVisible && flow.progress?.phase == .drawing), waited < 200_000 {
            waited += 1
            await Task.yield()
        }
        #expect(flow.step == .rendering)
        #expect(flow.isProgressVisible)
        #expect(flow.presentsSheet)
        #expect(flow.sheetContent == .progress)
        #expect(flow.progress?.message.hasPrefix("Đang dựng trang") == true)
        flow.cancel()
        await flow.waitUntilIdle()
        #expect(flow.step == .finished)
        #expect(window.reportFlow == nil)
        #expect(try files(in: directory) == ["da-co.pdf"], "không còn file tạm")
        #expect(try Data(contentsOf: destination) == Data("bản cũ".utf8))
        #expect(setup.panels.announcements.isEmpty)
        #expect(setup.panels.failures.isEmpty)
    }

    @Test("0,3 s đầu khi đang dựng (chưa có sheet tiến độ): không sheet nào, nhưng cửa sổ không mở thêm sheet (ảnh phóng to)")
    func noOtherSheetWhileRenderingBeforeProgress() async throws {
        let setup = try setUp()
        let window = try await submit(setup, longExam(), plan: String(repeating: "w", count: 40))
        #expect(await window.openAnswerReview())
        #expect(window.canPresentSheet)
        setup.panels.destination = try folder(setup).appendingPathComponent("anh.pdf")
        #expect(window.requestReport(.exportPDF))
        let flow = try #require(window.reportFlow)
        #expect(flow.sheetContent == .options)
        #expect(!window.canPresentSheet, "hộp chọn đang mở")
        flow.level = .all
        flow.confirm()
        var waited = 0
        while !(flow.step == .rendering && flow.progress != nil), waited < 200_000 {
            waited += 1
            await Task.yield()
        }
        #expect(flow.step == .rendering)
        #expect(!flow.isProgressVisible)
        #expect(flow.sheetContent == nil)
        #expect(!flow.presentsSheet)
        #expect(!window.canPresentSheet, "đang dựng: không mở ảnh phóng to")
        flow.cancel()
        await flow.waitUntilIdle()
        #expect(window.canPresentSheet)
    }

    @Test("Cửa sổ làm bài đóng hoặc về thư viện khi đang xuất: huỷ, không để lại file")
    func closingWindowCancels() async throws {
        let setup = try setUp()
        let window = try await submit(setup, longExam(), plan: String(repeating: "w", count: 40))
        let directory = try folder(setup)
        setup.panels.destination = directory.appendingPathComponent("dong.pdf")
        #expect(window.requestReport(.exportPDF))
        let flow = try #require(window.reportFlow)
        flow.level = .all
        flow.confirm()
        var waited = 0
        while flow.progress == nil, waited < 200_000 {
            waited += 1
            await Task.yield()
        }
        #expect(flow.step == .rendering)
        setup.coordinator.sessionWindowDidClose()
        await flow.waitUntilIdle()
        #expect(flow.step == .finished)
        #expect(try files(in: directory).isEmpty)

        // Hộp chọn đang mở khi cửa sổ đóng: luồng xong, không mở hộp lưu.
        let second = try await submit(setup, exam(), plan: "c--")
        #expect(second.requestReport(.exportPDF))
        let pending = try #require(second.reportFlow)
        setup.coordinator.returnToLibrary()
        #expect(pending.step == .finished)
    }

    @Test("Thoát app khi sheet đang mở (SwiftUI đóng sheet trước khi hỏi app delegate): hộp chọn như Huỷ; tiến độ đang hiện thì huỷ, không để lại file")
    func sheetDismissedByTermination() async throws {
        let setup = try setUp()
        setup.panels.progressDelay = .zero
        setup.coordinator.reportServices = setup.panels.services
        let window = try await submit(setup, longExam(), plan: String(repeating: "w", count: 40))
        #expect(window.requestReport(.exportPDF))
        window.reportFlow?.sheetDismissed()
        #expect(window.reportFlow == nil)
        #expect(setup.panels.suggestedNames.isEmpty)

        let directory = try folder(setup)
        setup.panels.destination = directory.appendingPathComponent("thoat.pdf")
        #expect(window.requestReport(.exportPDF))
        let flow = try #require(window.reportFlow)
        flow.level = .all
        flow.confirm()
        var waited = 0
        while !(flow.step == .rendering && flow.isProgressVisible && flow.progress?.phase == .drawing), waited < 200_000 {
            waited += 1
            await Task.yield()
        }
        #expect(flow.presentsSheet)
        flow.sheetDismissed()
        await flow.waitUntilIdle()
        #expect(flow.step == .finished)
        #expect(try files(in: directory).isEmpty)
        #expect(setup.panels.announcements.isEmpty)
    }

    // MARK: - Lỗi ghi

    @Test("Lỗi ghi có lý do, không để lại file: thư mục không ghi được, thư mục không còn, đích là thư mục")
    func writeErrors() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        let locked = try folder(setup, "Khoa")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        setup.panels.destination = locked.appendingPathComponent("khong-ghi.pdf")
        try await run(window, .exportPDF)
        #expect(setup.panels.failures.map(\.title) == ["Không xuất được PDF"])
        #expect(setup.panels.failures.map(\.message) == ["Không có quyền ghi vào thư mục đã chọn."])
        #expect(try files(in: locked).isEmpty)

        setup.panels.destination = setup.workspace.root.appendingPathComponent("Khong-co/ket-qua.pdf")
        try await run(window, .exportPDF)
        #expect(setup.panels.failures.last?.message == "Không tìm thấy thư mục đã chọn.")

        let directory = try folder(setup, "Dich")
        let occupied = directory.appendingPathComponent("trung-ten.pdf", isDirectory: true)
        try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: true)
        try Data().write(to: occupied.appendingPathComponent("giu.txt"))
        setup.panels.destination = occupied
        try await run(window, .exportPDF)
        #expect(setup.panels.failures.last?.message == "Không ghi được file PDF.")
        #expect(try files(in: directory) == ["trung-ten.pdf"], "không còn file tạm")
        #expect(try files(in: occupied) == ["giu.txt"])
        #expect(setup.panels.announcements.isEmpty)
        #expect(window.reportFlow == nil)
    }

    // MARK: - In

    @Test("In: dựng PDF rồi mở hộp In với tên việc in là tên file gợi ý; không tạo được thao tác In thì báo lỗi")
    func printFlow() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        try await run(window, .print, level: .all)
        let printed = try #require(setup.panels.printed.first)
        #expect(printed.pdf.pageCount > 0)
        let attempt = try #require(window.results).attempt
        let expected = ReportFileName.results(
            examTitle: "Địa lý Đông Nam Á",
            candidateName: "Nguyễn Văn Đức",
            submittedAt: attempt.submittedAt
        )
        #expect(printed.jobTitle + ".pdf" == expected)
        #expect(setup.panels.suggestedNames.isEmpty, "In không mở hộp lưu")
        let text = try #require(PDFDocument(data: printed.pdf.data)?.string)
        #expect(text.contains("Tất cả câu · 3 câu"))
        #expect(setup.panels.failures.isEmpty)

        setup.panels.printSucceeds = false
        try await run(window, .print)
        #expect(setup.panels.failures.map(\.title) == ["Không in được"])
        #expect(setup.panels.failures.map(\.message) == ["Không chuẩn bị được bản in."])
        #expect(window.reportFlow == nil)
    }

    @Test("In: cửa sổ đóng (huỷ) đúng lúc dựng vừa xong, sau lần kiểm huỷ cuối của bộ dựng trang: không mở hộp In, không báo lỗi")
    func cancelAfterRenderDoesNotPrint() async throws {
        let setup = try setUp()
        let window = try await submit(setup, exam(), plan: "cw-")
        #expect(window.requestReport(.print))
        let flow = try #require(window.reportFlow)
        var rendered = false
        flow.didRender = {
            rendered = true
            window.cancelReport()
        }
        flow.confirm()
        await flow.waitUntilIdle()
        #expect(rendered)
        #expect(setup.panels.printed.isEmpty, "huỷ sau khi dựng xong không được mở hộp In")
        #expect(setup.panels.failures.isEmpty)
        #expect(flow.step == .finished)
        #expect(window.reportFlow == nil)
    }
}
