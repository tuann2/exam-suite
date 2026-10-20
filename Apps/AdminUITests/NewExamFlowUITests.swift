import PDFKit
import XCTest

/// Luồng 4 của docs/product/overview.md (Soạn đề, bản Admin; authoring.md): Đề mới (⌘N) → thuộc tính đề → thêm phần →
/// câu nhiều đáp án có ảnh → thanh lỗi bắt câu chưa có đáp án đúng → sửa → xem trước → lưu vào thư mục tạm của test →
/// Thử đề này (⌘R) mở Trước khi thi.
///
/// Kiểm trợ năng tự động (`AccessibilityAuditor`, phương án 7 của accessibility-localization.md) ở cửa sổ soạn đề (câu có
/// ảnh, xem trước đang mở) và Trước khi thi của Thử đề này.
///
/// Ảnh lấy từ file test đưa vào bằng `-ExamSuiteUITestChosenFile` (chỉ build Debug, chỉ chế độ cô lập), không lái hộp
/// chọn file của macOS. Hộp Lưu của macOS: chỗ lưu mặc định là thư mục tạm (`-NSNavLastRootDirectory`), lái bằng bàn phím
/// (tên; ⇧⌘G nếu cần), chỉ bấm Lưu khi ô vị trí là thư mục tạm. Test kết thúc khi đề
/// đã lưu vào thư mục tạm và ⌘Q thoát app, nên macOS không giữ bản tự lưu của đề chưa lưu.
///
/// Nối vào trước bước lưu (giai đoạn 5 bước 10, T3 của notes/g5-ui-test-trung-lap.md; trước là lần mở app riêng
/// `ExportExamUITests` diễn lại ⌘N → gõ câu): **PDF và In đề** (docs/product/export-print.md, mục Bản Admin; plan giai
/// đoạn 5 bước 6) với đề đang soạn, chưa lưu. ⌘P mở hộp chọn của In, Kiểu chọn sẵn **Chỉ đề**; chọn Có đáp án rồi Esc huỷ
/// (không mở hộp In thật) → **Tệp › Xuất PDF…** → Kiểu lại là Chỉ đề (không nhớ lần trước, phương án 18) → Return → hộp
/// Lưu với tên gợi ý `<Tên đề> (đề).pdf` → lưu vào thư mục tạm → file PDF có thật, có câu vừa soạn, không có "Đáp án
/// đúng"; lưu PDF không lưu đề (⌘W vẫn hỏi; Huỷ giữ cửa sổ). Mỗi đoạn nối là một activity (`XCTContext.runActivity`).
final class NewExamFlowUITests: XCTestCase {
    @MainActor
    func testNewExamWithImageQuestionValidatePreviewExportPDFSaveAndTry() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self)
        let image = try isolated.writeFile("hinh-cau-hoi.png", AdminFixtures.png())
        isolated.useChosenFile(image)
        let app = isolated.app
        let flow = AdminFlow(isolated)
        // Chỗ lưu mặc định của hộp Lưu là thư mục tạm (-NSNavLastRootDirectory, miền tham số).
        let saveFolder = try flow.prepareSaveFolder()
        flow.registerCleanup(self)
        let auditor = AccessibilityAuditor(app: app, testCase: self)
        app.launch()
        flow.waitForLibrary()

        // ⌘N: cửa sổ soạn đề với đề trống chưa lưu, có sẵn "Phần 1".
        app.press("n", .command)
        flow.waitForAuthoringWindow()
        XCTAssertTrue(flow.row("section.0").waitForExistence(timeout: 5), "Đề mới phải có Phần 1")
        XCTAssertFalse(flow.row("section.1").exists)

        // Thuộc tính đề.
        flow.select("exam")
        flow.fill("authoring.exam.title", "De thu luong 4")
        flow.fill("authoring.exam.code", "LUONG4")
        flow.fill("authoring.exam.passPercent", "75")
        flow.fill("authoring.exam.timeLimit", "45")
        XCTAssertEqual(app.element("authoring.exam.title").stringValue, "De thu luong 4")
        XCTAssertEqual(app.element("authoring.exam.code").stringValue, "LUONG4")
        XCTAssertEqual(app.element("authoring.exam.passPercent").stringValue, "75")
        XCTAssertEqual(app.element("authoring.exam.timeLimit").stringValue, "45")
        XCTAssertTrue(flow.row("exam").waitForText("De thu luong 4", within: 5), flow.row("exam").text)

        // Thêm phần: "Phần 2" ở cuối đề, được chọn, tiêu điểm ở ô tên phần.
        flow.click("authoring.addSection", step: "Thêm phần (nút dưới cây đề)")
        XCTAssertTrue(flow.row("section.1").waitForExistence(timeout: 5), "Thêm phần không thêm dòng phần")
        flow.fill("authoring.section.title", "Mang may tinh")
        XCTAssertTrue(flow.row("section.1").waitForText("Mang may tinh", within: 5), flow.row("section.1").text)

        // ⌥⌘N: câu mới cuối phần đang chọn (một đáp án, bốn lựa chọn trống, chưa có đáp án đúng).
        flow.select("section.1")
        app.press("n", [.command, .option])
        XCTAssertTrue(flow.row("question.1.0").waitForExistence(timeout: 5), "⌥⌘N không thêm câu vào phần đang chọn")
        XCTAssertTrue(app.element("authoring.option.3.text").waitForExistence(timeout: 5), "Câu mới phải có bốn lựa chọn")
        XCTAssertFalse(app.element("authoring.option.4.text").exists)

        // Câu nhiều đáp án: loại, nội dung, bốn lựa chọn, ảnh.
        flow.choose("Nhiều đáp án", in: "authoring.question.type")
        flow.fill("authoring.question.text", "Giao thuc nao dung cho thu dien tu (email)?")
        for (index, text) in ["SMTP", "HTTP", "IMAP", "FTP"].enumerated() {
            flow.fill("authoring.option.\(index).text", text)
        }
        flow.click("authoring.question.image.choose", step: "Thêm ảnh… (file của test thay hộp chọn file)")
        XCTAssertTrue(
            app.element("authoring.question.image.remove").waitForExistence(timeout: 10),
            "Câu chưa có ảnh sau Thêm ảnh…"
        )
        let question = flow.row("question.1.0")
        XCTAssertTrue(question.waitForText("có ảnh", within: 5), question.text)
        XCTAssertTrue(question.text.contains("nhiều đáp án"), question.text)

        // Kiểm lỗi: câu chưa có đáp án đúng là lỗi trên thanh lỗi (không chặn gì).
        XCTAssertTrue(waitUntil(10) { flow.hasErrors }, "Thanh lỗi không báo lỗi: \(flow.issueSummary.text)")
        flow.expandIssueList()
        XCTAssertTrue(
            waitUntil(10) { flow.issueListContains("chưa có đáp án đúng") },
            "Thanh lỗi không bắt câu chưa có đáp án đúng"
        )

        // Sửa: A và C đúng. Chờ trạng thái cuối (danh sách lỗi đang hiện, chỉ còn lỗi "Phần 1" chưa có câu) rồi mới
        // kiểm vắng lỗi thiếu đáp án, để danh sách đang vẽ lại không làm phép kiểm "không có" đạt sớm.
        flow.click("authoring.option.0.correct", step: "Đánh dấu A đúng (ô đánh dấu)")
        flow.click("authoring.option.2.correct", step: "Đánh dấu C đúng (ô đánh dấu)")
        XCTAssertTrue(
            waitUntil(10) {
                app.element("authoring.issues.list").exists && flow.issueSummaryIs("1 lỗi")
                    && flow.issueListContains("chưa có câu hỏi nào")
            },
            "Thanh lỗi phải chỉ còn lỗi phần trống: \(flow.issueSummary.text)"
        )
        XCTAssertFalse(flow.issueListContains("chưa có đáp án đúng"), "Đã đánh dấu đáp án đúng nhưng thanh lỗi vẫn báo")

        // "Phần 1" còn trống (lỗi phần không có câu): chọn dòng phần, ⌫ xoá luôn (phần rỗng không hỏi lại).
        flow.select("section.0")
        app.press(.delete)
        XCTAssertTrue(flow.row("section.1").waitForNonExistence(within: 5), "⌫ không xoá phần rỗng")
        XCTAssertTrue(flow.row("section.0").waitForText("Mang may tinh", within: 5), flow.row("section.0").text)
        XCTAssertTrue(
            waitUntil(10) { flow.issueSummaryIs("Không có lỗi hay cảnh báo") },
            "Đề còn lỗi hoặc cảnh báo: \(flow.issueSummary.text)"
        )

        // Xem trước: câu đang chọn như cửa sổ làm bài; ⌃⌘I ẩn/hiện; đổi kiểu Thi rồi Luyện tập.
        flow.select("question.0.0")
        let preview = app.element("authoring.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Xem trước phải mở sẵn")
        XCTAssertTrue(waitUntil(5) { Self.contains(preview, "email") }, "Xem trước không hiện nội dung câu")
        XCTAssertTrue(Self.contains(preview, "SMTP"), "Xem trước không hiện lựa chọn")
        app.press("i", [.command, .control])
        XCTAssertTrue(preview.waitForNonExistence(within: 5), "⌃⌘I không ẩn xem trước")
        app.press("i", [.command, .control])
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "⌃⌘I không hiện lại xem trước")
        flow.choose("Thi", in: "authoring.preview.mode")
        XCTAssertTrue(waitUntil(5) { Self.contains(preview, "email") })
        flow.choose("Luyện tập", in: "authoring.preview.mode")
        XCTAssertTrue(waitUntil(5) { Self.contains(preview, "email") })
        auditor.audit("Cửa sổ soạn đề")

        try XCTContext.runActivity(named: "PDF và In đề chưa lưu (trước là ExportExamUITests)") { _ in
            try exportQuestionsOnlyPDF(app: app, flow: flow, isolated: isolated, saveFolder: saveFolder)
        }

        // Lưu vào thư mục tạm của test (hộp Lưu của macOS).
        let saved = flow.saveNewDocument(named: "luong-4", in: saveFolder)
        let data = try Data(contentsOf: saved)
        XCTAssertTrue(data.zipContainsEntry(named: "exam.json"), "File đã lưu thiếu exam.json")
        XCTAssertTrue(data.zipContainsEntry(named: "media/"), "File đã lưu thiếu ảnh của câu")

        // ⌘R Thử đề này: đề đã lưu, không đổi → đọc nghiêm → thêm vào Thư viện → Trước khi thi.
        app.press("r", .command)
        let start = app.element("preExam.start")
        let opened = start.waitForExistence(timeout: 20)
        if !opened { flow.dumpTree() }
        XCTAssertTrue(opened, "Thử đề này không mở Trước khi thi")
        // Cửa sổ soạn đề ở sau (Trước khi thi là sheet trên Thư viện): nội dung câu ở xem trước (chữ .primary của đề vừa
        // soạn) bị macOS vẽ mờ theo cửa sổ không hoạt động; cùng chữ đó đã kiểm khi cửa sổ soạn đề ở trước (màn "Cửa sổ soạn đề").
        // Gợi ý "Chọn N đáp án" của xem trước (màu nhấn của nền đọc) cũng thuộc cửa sổ soạn đề phía sau: cổng trên repo
        // public 2026-10-20 bắt nó ở cả hai lần chạy; nó đã đạt ở màn "Cửa sổ soạn đề" khi cửa sổ đó ở trước.
        let previewTexts = ["Giao thuc nao dung cho thu dien tu (email)?", "Chọn 2 đáp án"]
            + ["SMTP", "HTTP", "IMAP", "FTP"].enumerated()
            .map { "\(["A", "B", "C", "D"][$0.offset]). \($0.element)" }
        auditor.audit("Trước khi thi của Thử đề này", exceptions: [
            AccessibilityAuditor.Exception(
                type: .contrast, element: "nội dung câu và lựa chọn ở xem trước của cửa sổ soạn đề phía sau",
                reason: "chữ .primary (màu hệ thống) ở cửa sổ không hoạt động; đạt khi cửa sổ soạn đề ở trước"
            ) { info, context in
                AccessibilityAuditor.isOutsideActiveWindow(info, context)
                    && previewTexts.contains { info.value.hasPrefix($0) }
            },
        ])

        flow.quit()
    }

    /// Đề "De thu luong 4" đang soạn (chưa lưu, không lỗi): ⌘P → hộp chọn của In (Chỉ đề; chọn Có đáp án; Esc, không có
    /// hộp In) → Tệp › Xuất PDF… (lại Chỉ đề) → Return → hộp Lưu → `saveFolder/de-uitest.pdf` → đọc lại PDF; ⌘W vẫn hỏi
    /// lưu đề (xuất PDF không lưu đề), Esc = Huỷ giữ cửa sổ soạn đề.
    @MainActor
    private func exportQuestionsOnlyPDF(app: XCUIApplication, flow: AdminFlow, isolated: IsolatedApp, saveFolder: URL) throws {
        // ⌘P: hộp chọn của In đề; Esc = Huỷ, không có hộp In.
        app.press("p", .command)
        let confirm = app.element("report.confirm")
        let opened = confirm.waitForExistence(timeout: 5)
        if !opened { flow.dumpTree() }
        XCTAssertTrue(opened, "⌘P không mở hộp chọn của In đề")
        XCTAssertTrue(confirm.text.contains("In…"), confirm.text)
        let kind = app.element("report.examKind")
        XCTAssertTrue(kind.exists, "Hộp chọn thiếu Kiểu")
        XCTAssertTrue(
            Self.selectedKind(kind).contains("Chỉ đề"),
            "Kiểu chọn sẵn phải là Chỉ đề: \(Self.selectedKind(kind))"
        )
        XCTAssertFalse(app.element("report.errorNotice").exists, "Đề không có lỗi thì không có dòng “Đề còn N lỗi”")
        // Chọn Có đáp án rồi Huỷ: lần mở sau vẫn là Chỉ đề (không nhớ).
        flow.choose("Có đáp án và giải thích", in: "report.examKind")
        XCTAssertTrue(waitUntil(5) { Self.selectedKind(kind).contains("Có đáp án") }, Self.selectedKind(kind))
        app.press(.escape)
        XCTAssertTrue(confirm.waitForNonExistence(within: 5), "Esc phải Huỷ hộp chọn")
        let printPanelAppeared = waitUntil(2) { app.sheets.firstMatch.exists || app.dialogs.firstMatch.exists }
        if printPanelAppeared { flow.dumpTree() }
        XCTAssertFalse(printPanelAppeared, "Huỷ hộp chọn không được mở hộp In")

        // Tệp › Xuất PDF… (không phím tắt): hộp chọn, chọn Chỉ đề, Return → hộp Lưu với tên gợi ý.
        flow.clickMenuItem("Xuất PDF…")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Tệp › Xuất PDF… không mở hộp chọn")
        XCTAssertTrue(confirm.text.contains("Xuất PDF…"), confirm.text)
        XCTAssertTrue(
            Self.selectedKind(kind).contains("Chỉ đề"),
            "Mở lại hộp chọn phải về Chỉ đề (không nhớ Có đáp án): \(Self.selectedKind(kind))"
        )
        XCTAssertTrue(confirm.isEnabled, "Nút Xuất PDF… phải bấm được ngay (Return)")
        app.press(.return)
        XCTAssertTrue(confirm.waitForNonExistence(within: 5), "Return không xác nhận hộp chọn")
        let panel = app.sheets.firstMatch
        let panelOpened = panel.waitForExistence(timeout: 10)
        if !panelOpened { flow.dumpTree() }
        XCTAssertTrue(panelOpened, "Xuất PDF… không mở hộp Lưu")
        let suggested = panel.textFields.matching(NSPredicate(format: "value CONTAINS %@", "De thu luong 4 (đề)")).firstMatch
        if !suggested.waitForExistence(timeout: 5) { flow.dumpTree() }
        XCTAssertTrue(suggested.exists, "Ô tên của hộp Lưu không có tên gợi ý “De thu luong 4 (đề)”")

        let driver = SavePanelDriver(
            app: app,
            isolatedDirectory: isolated.directory,
            defaultsDomain: "vn.io.nt0.examsuite.admin.uitest",
            dumpTree: { flow.dumpTree() }
        )
        let saved = driver.save(panel, named: "de-uitest", fileExtension: "pdf", in: saveFolder)

        // File PDF thật, đọc được, đúng nội dung đang soạn (chưa lưu), không có đáp án; không còn file tạm.
        let listing = {
            ((try? FileManager.default.contentsOfDirectory(atPath: saveFolder.path)) ?? []).filter { $0 != ".DS_Store" }.sorted()
        }
        XCTAssertTrue(waitUntil(10) { listing() == ["de-uitest.pdf"] }, "Thư mục lưu phải chỉ có file PDF: \(listing())")
        let pdf = try XCTUnwrap(PDFDocument(url: saved), "Không đọc được PDF đã xuất")
        XCTAssertGreaterThan(pdf.pageCount, 0)
        let text = pdf.string ?? ""
        for expected in ["De thu luong 4", "Giao thuc nao dung cho thu dien tu (email)?", "SMTP", "FTP"] {
            XCTAssertTrue(text.contains(expected), "PDF thiếu \(expected)")
        }
        XCTAssertFalse(text.contains("Đáp án đúng"), "PDF Chỉ đề không được có “Đáp án đúng”")

        // Lưu PDF không lưu đề: đóng cửa sổ vẫn hỏi lưu (đề chưa từng lưu); Esc = Huỷ giữ cửa sổ và thay đổi.
        app.press("w", .command)
        let sheet = flow.expectCloseSheet()
        app.press(.escape)
        XCTAssertTrue(sheet.waitForNonExistence(within: 5), "Esc không đóng hộp hỏi")
        XCTAssertTrue(flow.tree.exists, "Huỷ phải giữ cửa sổ soạn đề")
        XCTAssertTrue(flow.row("exam").text.contains("De thu luong 4"), "Huỷ phải giữ thay đổi: \(flow.row("exam").text)")
    }

    /// Chữ của lựa chọn đang chọn trong nhóm Kiểu (nút chọn có giá trị 1).
    @MainActor
    private static func selectedKind(_ group: XCUIElement) -> String {
        group.radioButtons.matching(NSPredicate(format: "value == 1")).firstMatch.text
    }

    /// Có phần tử con của `element` mà nhãn hoặc giá trị chứa `text`.
    @MainActor
    private static func contains(_ element: XCUIElement, _ text: String) -> Bool {
        element.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch.exists
    }
}
