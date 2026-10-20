import XCTest

/// Import đề… (docs/product/import.md, Luồng): file `.txt` tự soạn (`Fixtures/nhap-thu.txt`: 3 câu, câu 3 không có lựa
/// chọn nên bị bỏ, văn bản trước câu 1 và văn bản lạc ở câu 2 là cảnh báo) → hộp xác nhận (điền sẵn tiêu đề theo tên
/// file, ngưỡng đậu và thời gian bắt buộc) → cửa sổ soạn đề chưa lưu kèm báo cáo import → bấm dòng báo cáo nhảy tới câu
/// → ⌘W hỏi lưu (sửa của PR #35: đề import được đánh dấu "Đã sửa") → bỏ, không lưu → ⌘Q.
///
/// File chọn bằng `-ExamSuiteUITestChosenFile` (chỉ build Debug, chỉ chế độ cô lập), không lái hộp chọn file.
///
/// Kiểm trợ năng tự động (`AccessibilityAuditor`, phương án 7 của accessibility-localization.md) ở hộp xác nhận Import đề
/// và cửa sổ soạn đề có báo cáo import.
///
/// Bố cục thật của hộp xác nhận (lỗi beta G6.2): bốn ô, dòng báo lỗi, dòng ghi chú và hai nút nằm trong cửa sổ và trong
/// vùng cuộn chứa chúng (`WindowLayout.assertVisible`), đúng thứ tự từ trên xuống; cửa sổ thu lại khi hết dòng báo lỗi và
/// lớn lên khi có dòng báo lỗi mới (mã đề sai mẫu). Trước khi sửa, `Form` của hộp xác nhận cao 0 (cửa sổ 480×198) mà
/// test vẫn đạt: ô được điền bằng Tab (tiêu điểm bàn phím, không cần thấy ô), test chỉ kiểm `exists`, giá trị và nút Import
/// bật; khung của ô vẫn nằm trong khung cửa sổ (đè lên tóm tắt và ghi chú) và `isHittable` vẫn đúng. Nay test đỏ trên bố
/// cục cũ ("ô Tiêu đề bị vùng cuộn cắt … vùng cuộn (486.0, 448.5, 440.0, 0.0)").
final class ImportExamUITests: XCTestCase {
    @MainActor
    func testImportTextConfirmReportNavigateAndCloseAsks() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self)
        let source = try isolated.writeFile("nhap-thu.txt", AdminFixtures.importText())
        isolated.useChosenFile(source)
        let app = isolated.app
        let flow = AdminFlow(isolated)
        flow.registerCleanup(self)
        let auditor = AccessibilityAuditor(app: app, testCase: self)
        app.launch()
        flow.waitForLibrary()

        // File > Import đề… → cửa sổ Import đề: đọc xong thì hộp xác nhận.
        flow.clickMenuItem("Import đề…")
        let summary = app.element("import.confirm.summary")
        let confirming = summary.waitForExistence(timeout: 20)
        if !confirming { flow.dumpTree() }
        XCTAssertTrue(confirming, "Không có hộp xác nhận import")
        XCTAssertTrue(summary.text.contains("1 phần · 2 câu · 1 câu bị bỏ · 2 cảnh báo"), summary.text)

        // Điền sẵn: tiêu đề theo tên file (txt không có thông tin đề); ngưỡng đậu và thời gian bắt buộc, chưa có.
        XCTAssertEqual(app.element("import.confirm.title").stringValue, "nhap-thu")
        XCTAssertTrue(app.element("import.confirm.passPercent.problem").exists, "Ngưỡng đậu trống phải báo")
        XCTAssertTrue(app.element("import.confirm.timeLimit.problem").exists, "Thời gian trống phải báo")
        let importButton = app.element("import.confirm.import")
        XCTAssertFalse(importButton.isEnabled, "Import phải khoá khi còn ô bắt buộc trống")
        // Lỗi beta G6.2: bốn ô co về cao 0 trong cửa sổ cỡ theo nội dung, chỉ còn đầu đề, tóm tắt, một dòng ghi chú bị cắt
        // và hai nút. `exists`, giá trị và gõ bằng Tab vẫn đúng với ô bị co, nên đo khung: ô và ghi chú phải thấy được.
        let window = app.windows.containing(.any, identifier: "import.confirm.summary").firstMatch
        XCTAssertTrue(window.exists, "Không thấy cửa sổ Import đề")
        assertConfirmLayout(in: window, app: app, problems: ["import.confirm.passPercent", "import.confirm.timeLimit"])
        let heightWithProblems = window.frame.height

        flow.fill("import.confirm.passPercent", "70")
        XCTAssertFalse(importButton.isEnabled, "Import phải khoá khi thời gian còn trống")
        flow.fill("import.confirm.timeLimit", "30")
        XCTAssertTrue(waitUntil(5) { importButton.isEnabled }, "Đủ ô bắt buộc nhưng Import vẫn khoá")
        XCTAssertFalse(app.element("import.confirm.passPercent.problem").exists)
        // Hết hai dòng báo lỗi: cửa sổ thu lại theo nội dung (cỡ cửa sổ = cỡ lý tưởng), ô vẫn thấy được.
        XCTAssertTrue(
            waitUntil(5) { window.frame.height < heightWithProblems - 10 },
            "Cửa sổ không thu lại khi hết dòng báo lỗi: \(heightWithProblems) → \(window.frame.height)"
        )
        assertConfirmLayout(in: window, app: app, problems: [])
        let heightWithoutProblems = window.frame.height

        // Cửa sổ lớn lên: mã đề sai mẫu thì có dòng báo lỗi của Mã đề, Import khoá; xoá mã đề (tuỳ chọn) thì hết.
        flow.fill("import.confirm.code", "ABC 123!")
        XCTAssertTrue(app.element("import.confirm.code.problem").waitForExistence(timeout: 5), "Mã đề sai mẫu phải báo")
        XCTAssertFalse(importButton.isEnabled, "Import phải khoá khi mã đề sai mẫu")
        XCTAssertTrue(
            waitUntil(5) { window.frame.height > heightWithoutProblems + 10 },
            "Cửa sổ không lớn lên khi có dòng báo lỗi: \(heightWithoutProblems) → \(window.frame.height)"
        )
        assertConfirmLayout(in: window, app: app, problems: ["import.confirm.code"])
        flow.focus("import.confirm.code")
        app.press("a", .command)
        app.press(.delete)
        app.press(.tab)
        XCTAssertTrue(waitUntil(5) { importButton.isEnabled }, "Xoá mã đề sai nhưng Import vẫn khoá")
        XCTAssertTrue(
            waitUntil(5) { abs(window.frame.height - heightWithoutProblems) < 1 },
            "Cửa sổ không về cỡ cũ: \(heightWithoutProblems) → \(window.frame.height)"
        )
        auditor.audit("Hộp xác nhận Import đề")

        // Return = Import: cửa sổ soạn đề chưa lưu, một phần (tên file), hai câu, báo cáo import mở sẵn.
        app.press(.return)
        flow.waitForAuthoringWindow()
        XCTAssertTrue(summary.waitForNonExistence(within: 5), "Cửa sổ Import đề phải đóng sau Import")
        XCTAssertTrue(flow.row("section.0").waitForText("nhap-thu", within: 5), flow.row("section.0").text)
        XCTAssertTrue(flow.row("question.0.1").exists)
        XCTAssertFalse(flow.row("question.0.2").exists, "Câu không có lựa chọn phải bị bỏ")
        let report = app.element("authoring.importReport")
        XCTAssertTrue(report.waitForExistence(timeout: 5), "Không có báo cáo import")
        XCTAssertTrue(Self.contains(report, "1 câu bị bỏ · 2 cảnh báo"), "Tóm tắt báo cáo import sai")
        auditor.audit("Báo cáo import")

        // Ẩn/hiện báo cáo bằng nút trên thanh công cụ.
        flow.click("authoring.importReport.toggle", step: "Ẩn báo cáo import (thanh công cụ)")
        XCTAssertTrue(report.waitForNonExistence(within: 5), "Không ẩn được báo cáo import")
        flow.click("authoring.importReport.toggle", step: "Hiện báo cáo import (thanh công cụ)")
        XCTAssertTrue(report.waitForExistence(timeout: 5), "Không hiện lại được báo cáo import")

        // Bấm dòng cảnh báo của câu 2: chọn câu 2 (trình soạn câu hiện nội dung câu 2).
        let entry = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "authoring.importReport.entry.", "Câu 2"
        )).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Báo cáo không có dòng của câu 2")
        flow.needsFullKeyboardAccess("Bấm dòng báo cáo import")
        entry.click()
        XCTAssertTrue(
            waitUntil(5) { app.element("authoring.question.text").stringValue.contains("email") },
            "Bấm dòng báo cáo không chọn câu 2: \(app.element("authoring.question.text").stringValue)"
        )

        // ⌘W: đề import chưa lưu phải hỏi (không đóng mất đề); bỏ, không lưu → cửa sổ đóng.
        app.press("w", .command)
        let sheet = flow.expectCloseSheet()
        flow.discardChanges(in: sheet)
        XCTAssertTrue(flow.tree.waitForNonExistence(within: 5), "Bỏ thay đổi phải đóng cửa sổ soạn đề")
        flow.quit()
    }

    /// Bốn ô, dòng báo lỗi của các ô `problems`, dòng ghi chú và hai nút của hộp xác nhận nằm trọn trong cửa sổ Import đề
    /// và có chiều cao; bốn ô bấm được (`isHittable`); thứ tự từ trên xuống: tóm tắt, ô và dòng báo lỗi, ghi chú, nút.
    @MainActor
    private func assertConfirmLayout(
        in window: XCUIElement, app: XCUIApplication, problems: [String],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let fields = [
            ("import.confirm.title", "ô Tiêu đề"),
            ("import.confirm.code", "ô Mã đề"),
            ("import.confirm.passPercent", "ô Ngưỡng đậu"),
            ("import.confirm.timeLimit", "ô Thời gian Thi"),
        ]
        for (identifier, what) in fields {
            let field = app.element(identifier)
            WindowLayout.assertVisible(field, in: window, what, file: file, line: line)
            XCTAssertTrue(field.isHittable, "\(what) không bấm được (khung \(field.frame))", file: file, line: line)
        }
        for identifier in problems {
            WindowLayout.assertVisible(app.element("\(identifier).problem"), in: window, "dòng báo lỗi của \(identifier)",
                                       file: file, line: line)
        }
        let note = app.element("import.confirm.note")
        let cancel = app.element("import.confirm.cancel")
        WindowLayout.assertVisible(note, in: window, "dòng ghi chú", file: file, line: line)
        WindowLayout.assertVisible(cancel, in: window, "nút Huỷ", file: file, line: line)
        WindowLayout.assertVisible(app.element("import.confirm.import"), in: window, "nút Import", file: file, line: line)

        // Thứ tự từ trên xuống, không chồng nhau (không dựa vào việc `Form` có là vùng cuộn trong cây trợ năng hay không):
        // tóm tắt, rồi bốn ô và dòng báo lỗi, rồi ghi chú, rồi hai nút. Toạ độ của XCUITest: y tăng xuống dưới.
        let summary = app.element("import.confirm.summary").frame
        let firstField = app.element(fields[0].0).frame
        let lastRow = (fields.map { app.element($0.0).frame } + problems.map { app.element("\($0).problem").frame })
            .map(\.maxY).max() ?? 0
        XCTAssertLessThanOrEqual(
            summary.maxY, firstField.minY + 1, "Tóm tắt \(summary) chồng lên ô đầu \(firstField)", file: file, line: line
        )
        XCTAssertLessThanOrEqual(
            lastRow, note.frame.minY + 1, "Ô hoặc dòng báo lỗi (đáy \(lastRow)) chồng lên ghi chú \(note.frame)",
            file: file, line: line
        )
        XCTAssertLessThanOrEqual(
            note.frame.maxY, cancel.frame.minY + 1, "Ghi chú \(note.frame) chồng lên nút \(cancel.frame)",
            file: file, line: line
        )
    }

    @MainActor
    private static func contains(_ element: XCUIElement, _ text: String) -> Bool {
        element.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch.exists
    }
}
