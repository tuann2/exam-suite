import PDFKit
import XCTest

/// Luồng 1 (docs/product/overview.md): lần đầu mở → đề mẫu "Làm quen" → Luyện tập → Kiểm tra đáp án → Rà soát
/// (hộp "Còn N câu chưa làm": Return = Quay lại) → nộp → Kết quả → Xem lại bài (←/→). Chỉ bằng bàn phím.
///
/// Nối ở đuôi (giai đoạn 5 bước 10, T3 của notes/g5-ui-test-trung-lap.md; trước là `ExportResultsUITests`, một lần mở
/// app riêng diễn lại Trước khi thi → Bắt đầu → nộp): **Xuất PDF và In kết quả** (docs/product/export-print.md, mục Bản
/// Học viên; plan giai đoạn 5 bước 5). Từ Xem lại bài về Kết quả: ⌘P mở hộp chọn của In (Esc huỷ, không mở hộp In thật);
/// **Xuất PDF…** mở hộp chọn (mức xem lại mặc định "Câu sai và chưa làm"), Return mở hộp Lưu của macOS với tên gợi ý,
/// lưu vào thư mục tạm của chế độ cô lập, file PDF có thật và đọc được.
///
/// Hai tham số riêng của đoạn xuất PDF đặt cho cả lần chạy, cả hai chỉ ở miền tham số (không ghi `defaults`):
/// - `-NSNavLastRootDirectory` (`SavePanelDriver.prepareFolder`): chỗ lưu mặc định của hộp Lưu là thư mục tạm; chỉ hộp
///   Lưu/Mở của macOS đọc, luồng 1 không mở hộp nào.
/// - `-AppleLocale en_US` (Region Mỹ) với giao diện tiếng Việt: ngày giờ nộp trên PDF phải theo ngôn ngữ giao diện ("14:05
///   15/10/2026"), không theo Region ("10/15/2026, 2:05 PM") (accessibility-localization.md, mục Ngôn ngữ; plan giai đoạn 5
///   bước 7a). Luồng 1 không bị ảnh hưởng: mọi chữ, số và phần trăm nó kiểm ("12 câu · không giới hạn giờ", "Câu 3/12",
///   "91%", menu Cỡ thật/Phóng to) theo ngôn ngữ giao diện, không theo Region.
///
/// Kiểm trợ năng tự động (`AccessibilityAuditor`, phương án 7 của accessibility-localization.md) một lần ở mỗi màn: Thư
/// viện, Trước khi thi, làm bài, Rà soát & nộp, Kết quả, Xem lại bài, hộp chọn Xuất PDF/In. Mỗi đoạn là một activity
/// (`XCTContext.runActivity`) để log và ảnh chụp khi lỗi chỉ đúng bước.
final class PracticeFlowUITests: XCTestCase {
    @MainActor
    func testFirstLaunchPracticeCheckAnswerSubmitReviewThenExportResultsPDF() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self)
        let saveFolder = try SavePanelDriver.prepareFolder("XuatPDFUITest", in: isolated)
        let app = isolated.app
        let flow = StudentFlow(app: app)
        let exam = Samples.lamQuen
        let auditor = AccessibilityAuditor(app: app, testCase: self)
        app.launchArguments += ["-AppleLocale", "en_US"]
        app.launch()
        flow.waitForLibrary()
        auditor.audit("Thư viện")

        // Thư viện → Trước khi thi (lần đầu: Luyện tập, tất cả câu) → Bắt đầu.
        flow.openPreExam(exam)
        XCTAssertTrue(app.element("preExam.summary").text.contains("\(exam.questionCount) câu · không giới hạn giờ"))
        auditor.audit("Trước khi thi")
        flow.typeCandidateName()
        flow.start()
        flow.expectQuestion(1, of: exam.questionCount)
        auditor.audit("Làm bài")

        // Cỡ chữ nội dung (menu Xem): Cỡ thật tắt ở 100%; ⌘= (như Safari, không cần ⇧) phóng to; ⌘0 về cỡ thật.
        // "Thu nhỏ" còn là Cửa sổ › Thu nhỏ (Minimize) của macOS tiếng Việt, nên kiểm theo "Cỡ thật" và "Phóng to" (duy nhất).
        let actualSize = app.menuBars.menuItems["Cỡ thật"].firstMatch
        let zoomIn = app.menuBars.menuItems["Phóng to"].firstMatch
        XCTAssertTrue(actualSize.exists, "Menu Xem thiếu Cỡ thật")
        XCTAssertFalse(actualSize.isEnabled, "Cỡ thật phải tắt ở 100%")
        XCTAssertTrue(zoomIn.isEnabled, "Phóng to phải bật ở cửa sổ làm bài")
        app.press("=", .command)
        XCTAssertTrue(waitUntil(3) { actualSize.isEnabled }, "⌘= không phóng to")
        app.press("0", .command)
        XCTAssertTrue(waitUntil(3) { !actualSize.isEnabled }, "⌘0 không về cỡ thật")

        // Nền đọc (menu Xem › Nền đọc, plan giai đoạn 6 bước 1): lần đầu chưa có giá trị lưu (Theo hệ thống, vùng câu hỏi
        // nền trắng của macOS); chọn Giấy ngà qua menu khi đang làm bài: lựa chọn ghi vào defaults của thư mục cô lập và vùng
        // câu hỏi đổi sang nền Giấy ngà `#F7F0E1` (ảnh chụp màn hình chứa cửa sổ, kể cả màn hình phụ; sai số màu ±8 do hồ sơ
        // màu của màn hình). Giữ Giấy ngà cho hết luồng: các lần kiểm trợ năng sau (làm bài sau Kiểm tra đáp án, Xem lại bài)
        // đo tương phản trên nền Giấy ngà.
        let readingKey = "content.readingBackground"
        XCTAssertNil(NSDictionary(contentsOf: isolated.defaultsFileURL)?[readingKey], "Nền đọc phải mặc định Theo hệ thống")
        flow.chooseReadingBackground("Giấy ngà")
        XCTAssertTrue(waitUntil(15) { NSDictionary(contentsOf: isolated.defaultsFileURL)?[readingKey] as? String == "sepia" },
                      "Nền đọc Giấy ngà không ghi vào defaults cô lập")
        let sepia = (red: 0xF7, green: 0xF0, blue: 0xE1)
        var paper: (red: Int, green: Int, blue: Int)?
        let repainted = waitUntil(5) {
            paper = flow.backgroundColor(leftOf: "question.text")
            guard let paper else { return false }
            return abs(paper.red - sepia.red) <= 8 && abs(paper.green - sepia.green) <= 8 && abs(paper.blue - sepia.blue) <= 8
        }
        XCTAssertTrue(repainted, "Vùng câu hỏi chưa đổi sang nền Giấy ngà: \(String(describing: paper))"
            + (ScreenPixels.lastProblem.map { " (\($0))" } ?? ""))
        flow.expectQuestion(1, of: exam.questionCount)

        // Câu 1: phím chữ chọn đáp án, ⌘K kiểm tra → Đúng; Return sang câu sau.
        app.press("a")
        XCTAssertTrue(waitUntil(3) { flow.isSelected("A") }, "Phím A không chọn lựa chọn A")
        app.press("k", .command)
        XCTAssertTrue(app.element("check.result").waitForText("Đúng", within: 3))
        app.press(.return)
        flow.expectQuestion(2, of: exam.questionCount)

        // Câu 2 (nhiều đáp án A, B): hai phím chữ → Đúng.
        app.press("a")
        app.press("b")
        app.press("k", .command)
        XCTAssertTrue(app.element("check.result").waitForText("Đúng", within: 3))
        app.press(.return)

        // Câu 3: chọn sai → Chưa đúng; đáp án bị khoá (phím chữ không đổi được).
        flow.expectQuestion(3, of: exam.questionCount)
        app.press("a")
        app.press("k", .command)
        XCTAssertTrue(app.element("check.result").waitForText("Chưa đúng", within: 3))
        // Sau Kiểm tra đáp án: nhãn Đúng/Sai của lựa chọn không bị làm mờ (review độc lập #54 S1).
        auditor.audit("Làm bài sau Kiểm tra đáp án")
        app.press("d")
        XCTAssertTrue(flow.isSelected("A") && !flow.isSelected("D"), "Câu đã kiểm tra phải khoá đáp án")

        // → sang câu 4, ← về câu 3.
        app.press(.rightArrow)
        flow.expectQuestion(4, of: exam.questionCount)
        app.press(.leftArrow)
        flow.expectQuestion(3, of: exam.questionCount)
        app.press(.rightArrow)

        // ⌘Return: Rà soát với 9 câu chưa làm; Return (Nộp bài) → hỏi; Return = Quay lại (mặc định).
        app.press(.return, .command)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5))
        XCTAssertEqual(flow.reviewNumber("review.unanswered"), 9, flow.reviewCount("review.unanswered"))
        auditor.audit("Rà soát & nộp")
        app.press(.return)
        XCTAssertTrue(flow.submitConfirmation.waitForExistence(timeout: 5), "Nộp khi còn câu chưa làm phải hỏi")
        app.press(.return)
        XCTAssertTrue(flow.submitConfirmation.waitForNonExistence(within: 5), "Return phải là Quay lại")
        XCTAssertTrue(app.element("review.submit").exists, "Quay lại phải ở lại Rà soát")
        XCTAssertFalse(app.element("results.verdict").exists)

        // Esc: quay lại làm bài, làm nốt câu 4–12 bằng phím chữ + Return.
        app.press(.escape)
        flow.expectQuestion(4, of: exam.questionCount)
        for number in 4 ... exam.questionCount {
            flow.expectQuestion(number, of: exam.questionCount)
            for letter in exam.answers[number - 1] {
                app.press(String(letter).lowercased())
            }
            app.press(.return)
        }

        // Không còn câu chưa làm: Return trên Rà soát nộp luôn, không hỏi.
        app.press(.return, .command)
        XCTAssertTrue(app.element("review.submit").waitForExistence(timeout: 5))
        XCTAssertEqual(flow.reviewNumber("review.unanswered"), 0, flow.reviewCount("review.unanswered"))
        app.press(.return)
        flow.expectResults()
        XCTAssertFalse(flow.submitConfirmation.exists)
        // 11/12 đúng (câu 3 sai): 91% ≥ 60% → Đậu.
        XCTAssertTrue(app.element("results.verdict").text.contains("Đậu"), app.element("results.verdict").text)
        XCTAssertTrue(app.element("results.score").text.contains("91%"), app.element("results.score").text)
        auditor.audit("Kết quả")

        // Return = Xem lại bài; ←/→ đi trong bộ lọc Tất cả.
        app.press(.return)
        let position = app.element("answerReview.position")
        XCTAssertTrue(position.waitForText("Câu 1/\(exam.questionCount)", within: 10), position.text)
        auditor.audit("Xem lại bài")
        app.press(.rightArrow)
        XCTAssertTrue(position.waitForText("Câu 2/\(exam.questionCount)", within: 3), position.text)
        app.press(.rightArrow)
        XCTAssertTrue(position.waitForText("Câu 3/\(exam.questionCount)", within: 3), position.text)
        app.press(.leftArrow)
        XCTAssertTrue(position.waitForText("Câu 2/\(exam.questionCount)", within: 3), position.text)

        try XCTContext.runActivity(named: "Xuất PDF và In kết quả (trước là ExportResultsUITests)") { _ in
            try exportResults(app: app, flow: flow, auditor: auditor, isolated: isolated, saveFolder: saveFolder)
        }
    }

    /// Từ Xem lại bài về Kết quả, ⌘P → hộp chọn của In → Esc (không có hộp In); Xuất PDF… → Return → hộp Lưu với tên gợi
    /// ý → lưu vào `saveFolder` → đọc lại PDF. Lần thi của luồng 1: 11/12 đúng, câu 3 sai, nên phần xem lại mặc định ("Câu
    /// sai và chưa làm") có câu 3 và PDF có mục "Xem lại bài".
    @MainActor
    private func exportResults(
        app: XCUIApplication, flow: StudentFlow, auditor: AccessibilityAuditor, isolated: IsolatedApp, saveFolder: URL
    ) throws {
        // Về Kết quả (nút Kết quả trên thanh công cụ Xem lại bài).
        flow.needsFullKeyboardAccess("Kết quả (thanh công cụ Xem lại bài)")
        app.element("answerReview.results").click()
        flow.expectResults()
        XCTAssertTrue(app.element("results.exportPDF").exists, "Kết quả thiếu nút Xuất PDF…")
        XCTAssertTrue(app.element("results.print").exists, "Kết quả thiếu nút In…")

        // ⌘P: hộp chọn của In; mức xem lại mặc định "Câu sai và chưa làm"; Esc = Huỷ, không có hộp In.
        app.press("p", .command)
        let confirm = app.element("report.confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "⌘P không mở hộp chọn")
        XCTAssertTrue(confirm.text.contains("In…"), confirm.text)
        let level = app.element("report.reviewLevel")
        XCTAssertTrue(level.exists, "Hộp chọn thiếu Phần xem lại bài")
        let selected = level.radioButtons.matching(NSPredicate(format: "value == 1")).firstMatch
        XCTAssertTrue(selected.text.contains("Câu sai và chưa làm"), selected.text)
        // Kiểm trợ năng tự động của hộp chọn Xuất PDF/In (phương án 7).
        auditor.audit("Hộp chọn của In…")
        app.press(.escape)
        XCTAssertTrue(confirm.waitForNonExistence(within: 5), "Esc phải Huỷ hộp chọn")
        // Chờ có giới hạn (2 giây) xem có hộp In nào hiện (sheet hay hộp riêng); hết hạn mà không có là đạt.
        let printPanelAppeared = waitUntil(2) { app.sheets.firstMatch.exists || app.dialogs.firstMatch.exists }
        if printPanelAppeared { flow.dumpTree() }
        XCTAssertFalse(printPanelAppeared, "Huỷ hộp chọn không được mở hộp In")
        flow.expectResults()

        // Xuất PDF…: hộp chọn → Return → hộp Lưu với tên gợi ý (tên đề - thí sinh - thời điểm nộp).
        flow.needsFullKeyboardAccess("Xuất PDF… (nút trên thanh dưới của Kết quả)")
        app.element("results.exportPDF").click()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Xuất PDF… không mở hộp chọn")
        XCTAssertTrue(confirm.text.contains("Xuất PDF…"), confirm.text)
        app.press(.return)
        XCTAssertTrue(confirm.waitForNonExistence(within: 5), "Return không xác nhận hộp chọn")
        let panel = app.sheets.firstMatch
        let opened = panel.waitForExistence(timeout: 10)
        if !opened { flow.dumpTree() }
        XCTAssertTrue(opened, "Xuất PDF… không mở hộp Lưu")
        // Ô tên (Lưu thành) có tên gợi ý chứa tên thí sinh (tìm theo giá trị: hộp Lưu còn ô Thẻ, ô tìm).
        let suggested = panel.textFields.matching(NSPredicate(format: "value CONTAINS %@", "Hoc vien UI test")).firstMatch
        if !suggested.waitForExistence(timeout: 5) { flow.dumpTree() }
        XCTAssertTrue(suggested.exists, "Ô tên của hộp Lưu không có tên gợi ý chứa tên thí sinh")

        let driver = SavePanelDriver(
            app: app,
            isolatedDirectory: isolated.directory,
            defaultsDomain: "vn.io.nt0.examsuite.uitest",
            dumpTree: { flow.dumpTree() }
        )
        let saved = driver.save(panel, named: "ket-qua-uitest", fileExtension: "pdf", in: saveFolder)

        // File PDF thật, đọc được, đúng kết quả vừa nộp; không còn file tạm trong thư mục (bỏ qua .DS_Store nếu macOS ghi).
        let listing = {
            ((try? FileManager.default.contentsOfDirectory(atPath: saveFolder.path)) ?? []).filter { $0 != ".DS_Store" }.sorted()
        }
        XCTAssertTrue(waitUntil(10) { listing() == ["ket-qua-uitest.pdf"] }, "Thư mục lưu phải chỉ có file PDF: \(listing())")
        let pdf = try XCTUnwrap(PDFDocument(url: saved), "Không đọc được PDF đã xuất")
        XCTAssertGreaterThan(pdf.pageCount, 0)
        let text = pdf.string ?? ""
        for expected in ["Làm quen với Exam Suite", "Hoc vien UI test", "Xem lại bài",
                         "Kết quả luyện tập, không có giá trị xác nhận", "Nộp lúc"] {
            XCTAssertTrue(text.contains(expected), "PDF thiếu \(expected)")
        }
        // Ngày giờ nộp theo ngôn ngữ giao diện (tiếng Việt: giờ trước, ngày/tháng/năm), không theo Region en_US.
        let range = NSRange(text.startIndex..., in: text)
        let vietnameseDateTime = try NSRegularExpression(pattern: #"\b\d{1,2}:\d{2} \d{1,2}/\d{1,2}/\d{4}\b"#)
        XCTAssertNotNil(vietnameseDateTime.firstMatch(in: text, range: range), "PDF thiếu ngày giờ nộp dạng tiếng Việt")
        let regionTime = try NSRegularExpression(pattern: #"\d{1,2}:\d{2}[ \x{00A0}\x{202F}]?[AP]M\b"#)
        XCTAssertNil(regionTime.firstMatch(in: text, range: range), "Giờ trên PDF theo Region en_US (AM/PM)")
        // Lưu xong không tự mở PDF; cửa sổ làm bài vẫn ở Kết quả.
        flow.expectResults()
    }
}
