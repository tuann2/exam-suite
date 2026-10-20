import AppKit
import XCTest

/// Các bước chung của luồng làm bài (docs/product/overview.md, luồng 1–3), chỉ bằng bàn phím trừ các bước ghi
/// rõ "cần Điều hướng bàn phím".
///
/// **Điều hướng bàn phím (Full Keyboard Access) của macOS:** khi tắt (mặc định), Tab chỉ đi qua ô nhập chữ và
/// danh sách; nút, ô chọn, nút trong hộp thoại chỉ tới được bằng Tab khi người dùng bật cài đặt này. Cài đặt nằm ở
/// miền chung của người dùng, app không bật riêng được (đã thử `-AppleKeyboardUIMode 2` và defaults riêng của app:
/// AppKit không đọc), và UI test không được đổi cài đặt của máy. Vì vậy các bước sau dùng `click()` và có đánh
/// dấu `needsFullKeyboardAccess` trong log: chọn chế độ **Thi** và **N câu ngẫu nhiên** trong Trước khi thi,
/// **Nộp bài** trong hộp "Còn N câu chưa làm", **Xem câu sai**, **Kết quả** và **Làm lại**, **Bỏ bài**.
@MainActor
struct StudentFlow {
    let app: XCUIApplication
    /// Ngôn ngữ giao diện của lần chạy (`IsolatedApp(language:)`): vài bước so chữ của app (đầu câu, giá trị trợ năng
    /// của lựa chọn, nhãn của ô chọn).
    var language: UITestLanguage = .vietnamese

    // MARK: - Thư viện → Trước khi thi

    /// Thư viện đã tải đề mẫu.
    func waitForLibrary(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.element(Samples.lamQuen.cardID).waitForExistence(timeout: 30),
            "Thư viện không hiện đề mẫu", file: file, line: line
        )
    }

    /// ⌘F, gõ mã đề để lọc còn một thẻ, Tab sang lưới, → chọn thẻ, Return mở **Trước khi thi** với chế độ dùng lần
    /// trước (lần đầu là Luyện tập). ⌘A trước khi gõ: ô tìm có thể còn mã đề của lần mở trước trong cùng test.
    func openPreExam(_ exam: Samples.Exam, file: StaticString = #filePath, line: UInt = #line) {
        app.press("f", .command)
        app.press("a", .command)
        app.typeText(exam.code)
        let card = app.element(exam.cardID)
        let other = app.element((exam.code == Samples.lamQuen.code ? Samples.attt : Samples.lamQuen).cardID)
        XCTAssertTrue(other.waitForNonExistence(within: 5), "Tìm theo mã không lọc thẻ", file: file, line: line)
        // Ô tìm kiếm → lưới đề.
        app.press(.tab)
        app.press(.rightArrow)
        XCTAssertTrue(waitUntil(5) { card.isSelected }, "Phím → không chọn thẻ \(exam.code)", file: file, line: line)
        app.press(.return)
        XCTAssertTrue(
            app.element("preExam.start").waitForExistence(timeout: 10),
            "Return trên thẻ không mở Trước khi thi", file: file, line: line
        )
    }

    /// Gõ tên thí sinh vào ô tên (đang có tiêu điểm vì tên trống).
    func typeCandidateName(_ name: String = "Hoc vien UI test", file: StaticString = #filePath, line: UInt = #line) {
        let field = app.element("preExam.candidateName")
        XCTAssertTrue(field.hasKeyboardFocus, "Ô tên thí sinh chưa có tiêu điểm", file: file, line: line)
        app.typeText(name)
        XCTAssertEqual(field.stringValue, name, file: file, line: line)
    }

    /// Chọn chế độ **Thi** trong Trước khi thi. Cần Điều hướng bàn phím (xem đầu file).
    func chooseExamMode(file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess("Chọn chế độ Thi (segmented)")
        let mode = app.element("preExam.mode")
        mode.radioButtons[language == .english ? "Exam" : "Thi"].firstMatch.click()
        XCTAssertTrue(app.element("preExam.timeLimit").waitForExistence(timeout: 5), "Chưa sang chế độ Thi", file: file, line: line)
    }

    /// Chọn **N câu ngẫu nhiên**. Cần Điều hướng bàn phím (xem đầu file).
    func chooseRandomSelection(file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess("Chọn N câu ngẫu nhiên (radio)")
        let prefix = language == .english ? "N Random" : "N câu"
        app.element("preExam.selection").radioButtons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch.click()
        XCTAssertTrue(app.element("preExam.randomCount").waitForExistence(timeout: 5), "Chưa có ô số câu", file: file, line: line)
    }

    /// Tab tới ô số `identifier` (ô nhập chữ, có trong vòng Tab cả khi tắt Điều hướng bàn phím), chọn hết và gõ
    /// `value`, Tab để ghi nhận.
    func typeNumber(_ value: Int, into identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.element(identifier)
        XCTAssertTrue(app.tab(to: field), "Tab không tới \(identifier)", file: file, line: line)
        app.press("a", .command)
        app.typeText(String(value))
        app.press(.tab)
        XCTAssertEqual(field.stringValue, String(value), "\(identifier)", file: file, line: line)
    }

    /// Return = **Bắt đầu**; chờ cửa sổ làm bài.
    func start(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.element("preExam.start").isEnabled, "Bắt đầu đang khoá", file: file, line: line)
        app.press(.return)
        XCTAssertTrue(
            app.element("question.header").waitForExistence(timeout: 15),
            "Không mở cửa sổ làm bài", file: file, line: line
        )
    }

    // MARK: - Làm bài

    /// Nhãn đầu câu ("Phần …, Câu 3/12…").
    var header: XCUIElement { app.element("question.header") }

    /// Đầu câu cho biết đang ở câu `number` trên `total`.
    func expectQuestion(_ number: Int, of total: Int, file: StaticString = #filePath, line: UInt = #line) {
        let position = questionPosition(number, of: total)
        XCTAssertTrue(
            header.waitForText(position, within: 5),
            "Đang ở '\(header.text)', cần \(position)", file: file, line: line
        )
    }

    /// Chữ vị trí câu ở đầu câu và ở Xem lại bài: "Câu 3/12" / "Question 3 of 12".
    func questionPosition(_ number: Int, of total: Int) -> String {
        language == .english ? "Question \(number) of \(total)" : "Câu \(number)/\(total)"
    }

    /// Chữ cái của lựa chọn đầu tiên ở câu đang xem có nội dung **không** thuộc `correctTexts` (nhãn trợ năng của lựa
    /// chọn là "A. <nội dung>"), tức một lựa chọn sai; `nil` nếu không có.
    func wrongOptionLetter(correctTexts: Set<String>) -> String? {
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init) {
            let option = app.element("option.\(letter)")
            guard option.exists else { break }
            let label = option.label
            let prefix = "\(letter). "
            let text = label.hasPrefix(prefix) ? String(label.dropFirst(prefix.count)) : label
            if !correctTexts.contains(text) { return letter }
        }
        return nil
    }

    /// Lựa chọn ở vị trí `letter` đang được chọn (giá trị trợ năng "Đã chọn…" / "Selected…").
    func isSelected(_ letter: String) -> Bool {
        app.element("option.\(letter)").stringValue.hasPrefix(language == .english ? "Selected" : "Đã chọn")
    }

    /// Dải thông báo trên đầu câu có chữ `text` (chờ tối đa `timeout` giây).
    ///
    /// Dải tự ẩn sau 6 giây, nên không đọc thuộc tính của phần tử (nó có thể biến mất giữa hai lần đọc và XCTest
    /// báo lỗi cứng "No matches found"). Thay vào đó chờ một truy vấn khớp cả định danh lẫn chữ: chính dải có
    /// nhãn/giá trị chứa chữ, hoặc một phần tử con của dải chứa chữ. `exists` của truy vấn không khớp chỉ trả false.
    func expectBanner(_ text: String, within timeout: TimeInterval, file: StaticString = #filePath, line: UInt = #line) {
        let id = "attempt.banner"
        let idPredicate = "(identifier == %@ OR identifier BEGINSWITH %@ OR identifier ENDSWITH %@)"
        let banners = app.descendants(matching: .any)
        let selfMatch = banners.matching(NSPredicate(
            format: "\(idPredicate) AND (label CONTAINS %@ OR value CONTAINS %@)",
            id, "\(id)-", "-\(id)", text, text
        )).firstMatch
        let childMatch = banners.matching(NSPredicate(format: idPredicate, id, "\(id)-", "-\(id)"))
            .descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        var found = false
        while Date() < deadline {
            if selfMatch.exists || childMatch.exists { found = true; break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(found, "Không thấy dải '\(text)'", file: file, line: line)
    }

    /// Ô `number` của bảng câu hỏi.
    func navigatorCell(_ number: Int) -> XCUIElement {
        app.element("navigator.cell.\(number)")
    }

    // MARK: - Rà soát & nộp

    /// Chữ của ô Đã làm / Chưa làm / Đánh dấu của Rà soát (nhãn và số gộp một phần tử).
    func reviewCount(_ identifier: String) -> String {
        app.element(identifier).text
    }

    /// Số trong ô `identifier` của Rà soát: số nguyên duy nhất trong chữ của ô; nil nếu không có hay có nhiều số. So
    /// bằng giá trị đúng (`XCTAssertEqual`), không so chuỗi con ("12" chứa "2").
    func reviewNumber(_ identifier: String) -> Int? {
        let text = reviewCount(identifier)
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return numbers.count == 1 ? numbers[0] : nil
    }

    /// Hộp "Còn N câu chưa làm. Vẫn nộp?".
    var submitConfirmation: XCUIElement {
        app.element("submit.confirm")
    }

    /// **Nộp bài** trong hộp xác nhận. Cần Điều hướng bàn phím (xem đầu file): Return và Esc là Quay lại.
    func confirmSubmitInDialog(file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess("Nộp bài trong hộp Còn N câu chưa làm")
        XCTAssertTrue(submitConfirmation.waitForExistence(timeout: 5), "Không có hộp xác nhận", file: file, line: line)
        submitConfirmation.click()
        expectResults(file: file, line: line)
    }

    /// Màn Kết quả.
    func expectResults(file: StaticString = #filePath, line: UInt = #line) {
        let found = app.element("results.verdict").waitForExistence(timeout: 10)
        if !found { dumpTree() }
        XCTAssertTrue(found, "Không tới Kết quả", file: file, line: line)
    }

    // MARK: - Menu Xem › Nền đọc

    /// Tên năm nền theo thứ tự của menu con **Nền đọc** (plan giai đoạn 6 bước 1).
    static let readingBackgrounds = ["Theo hệ thống", "Trắng", "Giấy ngà", "Xám dịu", "Tối"]

    /// Chọn nền `title` qua menu Xem (View) › Nền đọc: menu con bật ở cửa sổ làm bài và có đủ năm nền. Cần chuột (mở menu
    /// bằng bàn phím cần Điều hướng bàn phím).
    ///
    /// Dấu ✓ của mục đang chọn (`AXMenuItemMarkChar`) XCUITest không đọc được (`value` rỗng, `isSelected` là mục đang trỏ
    /// chuột): ảnh màn hình lúc menu con mở được đính vào kết quả test khi test hỏng; trạng thái kiểm bằng giá trị lưu và màu
    /// nền thật của vùng câu hỏi (`PracticeFlowUITests`).
    func chooseReadingBackground(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess("Menu Xem › Nền đọc › \(title)")
        let bar = app.menuBars.menuBarItems.containing(NSPredicate(format: "title == %@", "Nền đọc")).firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "Không thấy menu chứa “Nền đọc”", file: file, line: line)
        bar.click()
        let submenu = bar.menuItems["Nền đọc"].firstMatch
        XCTAssertTrue(submenu.waitForExistence(timeout: 5), "Menu Xem không có “Nền đọc”", file: file, line: line)
        XCTAssertTrue(submenu.isEnabled, "Nền đọc phải bật ở cửa sổ làm bài", file: file, line: line)
        submenu.click()
        for name in Self.readingBackgrounds {
            XCTAssertTrue(submenu.menuItems[name].firstMatch.waitForExistence(timeout: 5),
                          "Nền đọc không có “\(name)”", file: file, line: line)
        }
        // Ảnh màn hình chứa menu con (có thể là màn hình phụ; `ScreenPixels`).
        let menuFrame = submenu.menuItems[title].firstMatch.frame
        if let screenshot = ScreenPixels.screenshot(containing: CGPoint(x: menuFrame.midX, y: menuFrame.midY)) {
            let shot = XCTAttachment(screenshot: screenshot)
            shot.name = "Menu Nền đọc trước khi chọn \(title)"
            XCTContext.runActivity(named: "Ảnh menu Nền đọc") { $0.add(shot) }
        }
        submenu.menuItems[title].firstMatch.click()
    }

    /// Màu sRGB (0–255) của điểm ảnh cách mép trái phần tử `identifier` `inset` điểm về bên trái, giữa chiều cao (nền của
    /// vùng câu hỏi ở lề trái 24 pt của nội dung câu), đọc trên ảnh chụp màn hình chứa điểm đó (`ScreenPixels`: không dùng
    /// `window.screenshot()`, hỏng khi cửa sổ nằm trên màn hình phụ). `nil` khi chưa có phần tử hay điểm nằm ngoài cửa sổ;
    /// lý do khi không đọc được màn hình ở `ScreenPixels.lastProblem`.
    func backgroundColor(leftOf identifier: String, inset: CGFloat = 12) -> (red: Int, green: Int, blue: Int)? {
        let element = app.element(identifier)
        let window = app.windows.containing(.any, identifier: identifier).firstMatch
        guard element.exists, window.exists else { return nil }
        let point = CGPoint(x: element.frame.minX - inset, y: element.frame.midY)
        guard window.frame.contains(point) else {
            ScreenPixels.lastProblem = "điểm \(point) nằm ngoài cửa sổ \(window.frame)"
            return nil
        }
        return ScreenPixels.color(at: point)
    }

    // MARK: - Ghi chú

    /// In cây trợ năng của các cửa sổ (không gồm menu) vào log, để chẩn đoán khi test hỏng.
    func dumpTree() {
        for window in app.windows.allElementsBoundByIndex {
            print("=== CÂY CỬA SỔ \(window.identifier) ===\n\(window.debugDescription)")
        }
    }

    /// Ghi vào log bước dùng chuột thay cho Tab/Space. Luôn click, không kiểm máy có bật Điều hướng bàn phím hay
    /// không; chuyển sang Tab/Space khi máy test bật Điều hướng bàn phím là việc sau (exam-taking.md phương án 19).
    func needsFullKeyboardAccess(_ step: String) {
        XCTContext.runActivity(named: "needsFullKeyboardAccess: \(step) (click thay cho Tab/Space; cần Điều hướng bàn phím của macOS)") { _ in }
    }
}
