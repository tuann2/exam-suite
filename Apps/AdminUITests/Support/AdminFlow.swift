import AppKit
import XCTest

/// Các bước chung của luồng Soạn đề bản Admin (docs/product/overview.md, luồng 4, 5; import.md): lái app ở chế độ cô
/// lập, đọc trạng thái qua `accessibilityIdentifier` (AuthoringFeature).
///
/// **Bàn phím:** ô chữ tới bằng Tab (có trong vòng Tab cả khi tắt Điều hướng bàn phím); lệnh có phím tắt dùng phím
/// (⌘N, ⌥⌘N, ⌘S, ⌘Z, ⇧⌘Z, ⌘W, ⌘R, ⌘Q, ⌫). Nút, ô đánh dấu, nút chọn kiểu câu, dòng của thanh lỗi/báo cáo import, nút
/// Thêm phần chỉ tới được bằng Tab khi bật Điều hướng bàn phím (Full Keyboard Access) của macOS, nên dùng `click()` và
/// ghi `needsFullKeyboardAccess` trong log, như bản Học viên (Apps/StudentUITests/Support/StudentFlow.swift). Kéo thả
/// trên cây đề là thao tác chuột theo đúng luồng 5.
///
/// **Tự lưu của macOS:** đề chưa từng lưu được macOS tự lưu vào `~/Library/Autosave Information/`, thư mục không theo
/// bundle ID. Mỗi test phải kết thúc bằng lưu vào thư mục tạm hoặc đóng không lưu, rồi ⌘Q thấy app thoát; khi test
/// hỏng giữa chừng, `registerCleanup` thoát app và bỏ thay đổi trước khi `IsolatedApp` buộc dừng app.
/// `scripts/verify_local.sh --uitest` so `~/Library/Autosave Information/` trước và sau.
@MainActor
struct AdminFlow {
    let app: XCUIApplication
    let isolated: IsolatedApp

    init(_ isolated: IsolatedApp) {
        self.isolated = isolated
        app = isolated.app
    }

    // MARK: - Dọn dẹp

    /// Đăng ký bước dọn khi test xong (chạy **trước** khi `IsolatedApp` buộc dừng app và xoá thư mục tạm, vì khối dọn
    /// dẹp chạy theo thứ tự ngược với lúc đăng ký): ghi vào log những gì macOS tự lưu trong thư mục nhà tạm, rồi thoát
    /// app, bỏ mọi thay đổi chưa lưu, để không để lại bản tự lưu của đề chưa lưu.
    func registerCleanup(_ testCase: XCTestCase) {
        let app = app
        let isolated = isolated
        testCase.addTeardownBlock { @MainActor in
            AdminFlow.logTemporaryAutosaves(isolated)
            AdminFlow.quitDiscardingChanges(app)
        }
    }

    /// Thoát app; hộp hỏi lưu (một hay nhiều đề) thì chọn bỏ thay đổi; hộp Lưu thì Huỷ.
    static func quitDiscardingChanges(_ app: XCUIApplication) {
        for _ in 0 ..< 6 {
            if app.state == .notRunning { return }
            let sheet = app.sheets.firstMatch
            let dialog = app.dialogs.firstMatch
            if sheet.exists {
                discard(in: sheet, app: app)
            } else if dialog.exists {
                discard(in: dialog, app: app)
            } else {
                app.press("q", .command)
            }
            waitUntil(4) { app.state == .notRunning || app.sheets.firstMatch.exists || app.dialogs.firstMatch.exists }
        }
    }

    /// Nút "bỏ thay đổi" của hộp hỏi lưu: ⌘⌫ ("Xoá" với đề chưa từng lưu, "Không lưu"); không đóng được thì bấm nút
    /// theo tên (tiếng Việt hoặc tiếng Anh, tuỳ ngôn ngữ AppKit chọn cho app), cuối cùng Esc (Huỷ hộp Lưu).
    private static func discard(in alert: XCUIElement, app: XCUIApplication) {
        app.press(.delete, .command)
        if alert.waitForNonExistence(within: 2) { return }
        for title in discardTitles where alert.buttons[title].exists {
            alert.buttons[title].click()
            if alert.waitForNonExistence(within: 2) { return }
        }
        app.press(.escape)
    }

    private static let discardTitles = [
        "Xoá", "Xóa", "Delete", "Không lưu", "Don’t Save", "Don't Save", "Huỷ thay đổi", "Hủy thay đổi",
        "Discard Changes", "Hoàn nguyên thay đổi", "Revert Changes",
    ]

    /// Ghi vào log nội dung `Library/Autosave Information` trong thư mục nhà tạm (`CFFIXED_USER_HOME`): cho biết macOS tự
    /// lưu đề chưa lưu vào thư mục nhà tạm hay không (thư mục thật do verify_local.sh so).
    static func logTemporaryAutosaves(_ isolated: IsolatedApp) {
        let folder = isolated.directory.appendingPathComponent("Home/Library/Autosave Information", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        XCTContext.runActivity(named: "Autosave Information trong thư mục nhà tạm: \(names.isEmpty ? "trống" : names.sorted().joined(separator: ", "))") { _ in }
    }

    // MARK: - Thư viện

    /// Thư viện đã tải đề mẫu.
    func waitForLibrary(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.element(Samples.lamQuen.cardID).waitForExistence(timeout: 30),
            "Thư viện không hiện đề mẫu", file: file, line: line
        )
    }

    /// ⌘F, gõ mã đề, Tab sang lưới, → chọn thẻ (như StudentFlow.openPreExam, không mở).
    func selectCard(_ exam: Samples.Exam, file: StaticString = #filePath, line: UInt = #line) {
        app.press("f", .command)
        // Ô tìm có thể còn chữ của lần tìm trước: chọn hết rồi gõ đè.
        app.press("a", .command)
        app.typeText(exam.code)
        let card = app.element(exam.cardID)
        let other = app.element((exam.code == Samples.lamQuen.code ? Samples.attt : Samples.lamQuen).cardID)
        XCTAssertTrue(other.waitForNonExistence(within: 5), "Tìm theo mã không lọc thẻ", file: file, line: line)
        app.press(.tab)
        app.press(.rightArrow)
        XCTAssertTrue(waitUntil(5) { card.isSelected }, "Phím → không chọn thẻ \(exam.code)", file: file, line: line)
    }

    // MARK: - Cửa sổ soạn đề

    /// Cây đề của cửa sổ soạn đề đang mở.
    var tree: XCUIElement { app.element("authoring.tree") }

    /// Chờ cửa sổ soạn đề.
    func waitForAuthoringWindow(file: StaticString = #filePath, line: UInt = #line) {
        let found = tree.waitForExistence(timeout: 15)
        if !found { dumpTree() }
        XCTAssertTrue(found, "Không mở cửa sổ soạn đề", file: file, line: line)
    }

    /// Dòng trên cây đề: `exam`, `section.<i>`, `question.<s>.<q>`.
    func row(_ suffix: String) -> XCUIElement {
        app.element("authoring.tree.\(suffix)")
    }

    /// Chọn một dòng của cây đề (bấm vào dòng; danh sách có trong vòng Tab, nhưng dòng cụ thể chọn bằng chuột cho
    /// chắc chắn, không phụ thuộc thứ tự dòng).
    func select(_ suffix: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = row(suffix)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Cây đề không có dòng \(suffix)", file: file, line: line)
        element.click()
    }

    /// Đưa tiêu điểm vào ô chữ `identifier`: Tab (ô chữ có trong vòng Tab cả khi tắt Điều hướng bàn phím); không tới
    /// thì bấm vào ô (ghi log).
    func focus(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Không có ô \(identifier)", file: file, line: line)
        if field.hasKeyboardFocus { return }
        if !app.tab(to: field, maxPresses: 24) {
            XCTContext.runActivity(named: "Tab không tới \(identifier): bấm vào ô") { _ in }
            field.click()
        }
    }

    /// Chọn hết chữ trong ô `identifier`, gõ `text`; `commit` thì Tab để ghi nhận (ô số chỉ nhận giá trị khi rời ô).
    func fill(_ identifier: String, _ text: String, commit: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
        focus(identifier, file: file, line: line)
        app.press("a", .command)
        app.typeText(text)
        if commit { app.press(.tab) }
    }

    /// Bấm một điều khiển (nút, ô đánh dấu…) chỉ tới được bằng Tab khi bật Điều hướng bàn phím.
    func click(_ identifier: String, step: String, file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess(step)
        let element = app.element(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Không có \(identifier)", file: file, line: line)
        element.click()
    }

    /// Nút có nhãn `title` trong nhóm chọn `identifier` (ô chọn kiểu segmented).
    func choose(_ title: String, in identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess("Chọn “\(title)”")
        let group = app.element(identifier)
        XCTAssertTrue(group.waitForExistence(timeout: 5), "Không có \(identifier)", file: file, line: line)
        let button = group.radioButtons[title].firstMatch
        let target = button.exists ? button : group.buttons[title].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(identifier) không có “\(title)”", file: file, line: line)
        target.click()
    }

    /// Bấm mục menu theo tên (mở menu chứa nó trên thanh menu trước).
    func clickMenuItem(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        needsFullKeyboardAccess("Mục menu “\(title)” (không có phím tắt)")
        let barItem = app.menuBars.menuBarItems.containing(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssertTrue(barItem.waitForExistence(timeout: 5), "Không thấy menu chứa “\(title)”", file: file, line: line)
        barItem.click()
        let item = app.menuBars.menuItems[title].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Không thấy mục menu “\(title)”", file: file, line: line)
        item.click()
    }

    // MARK: - Thanh lỗi

    /// Dòng tóm tắt của thanh lỗi ("2 lỗi · 1 cảnh báo", "Không có lỗi hay cảnh báo").
    var issueSummary: XCUIElement { app.element("authoring.issues.summary") }

    /// Dòng tóm tắt đúng bằng `expected` (nhãn của nút, hoặc nhãn kèm giá trị).
    func issueSummaryIs(_ expected: String) -> Bool {
        issueSummary.exists && (issueSummary.label == expected || issueSummary.text == expected)
    }

    /// Thanh lỗi đang báo ít nhất một lỗi ("N lỗi").
    var hasErrors: Bool {
        issueSummary.text.range(of: #"\d+ lỗi"#, options: .regularExpression) != nil
    }

    /// Mở danh sách lỗi (bấm dòng tóm tắt) nếu chưa mở.
    func expandIssueList(file: StaticString = #filePath, line: UInt = #line) {
        if app.element("authoring.issues.list").exists { return }
        click("authoring.issues.summary", step: "Mở danh sách lỗi", file: file, line: line)
        XCTAssertTrue(
            app.element("authoring.issues.list").waitForExistence(timeout: 5),
            "Thanh lỗi không mở danh sách", file: file, line: line
        )
    }

    /// Danh sách lỗi có dòng chứa `text`.
    func issueListContains(_ text: String) -> Bool {
        app.element("authoring.issues.list").descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch.exists
    }

    // MARK: - Lưu, đóng

    /// Thư mục tạm cho hộp Lưu (tên riêng để nhận ra trên ô vị trí của hộp Lưu): chỗ lưu mặc định của hộp Lưu
    /// (`SavePanelDriver.prepareFolder`, `-NSNavLastRootDirectory`). Gọi trước `app.launch()`.
    func prepareSaveFolder() throws -> URL {
        try SavePanelDriver.prepareFolder(Self.saveFolderName, in: isolated)
    }

    static let saveFolderName = "LuuDeUITest"

    /// ⌘S với đề chưa từng lưu: hộp Lưu của macOS, lái bằng bàn phím (`SavePanelDriver`: gõ tên, ⇧⌘G nếu ô vị trí chưa
    /// là `folder`, chỉ bấm Lưu khi ô vị trí là `folder`, không thì Huỷ và báo lỗi). Trả file đã lưu
    /// (`<folder>/<name>.exam`), kiểm file nằm trong thư mục tạm.
    @discardableResult
    func saveNewDocument(named name: String, in folder: URL, file: StaticString = #filePath, line: UInt = #line) -> URL {
        app.press("s", .command)
        let panel = app.sheets.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "⌘S không mở hộp Lưu", file: file, line: line)
        let flow = self
        let driver = SavePanelDriver(
            app: app,
            isolatedDirectory: isolated.directory,
            defaultsDomain: "vn.io.nt0.examsuite.admin.uitest",
            dumpTree: { flow.dumpTree() }
        )
        return driver.save(panel, named: name, fileExtension: "exam", in: folder, file: file, line: line)
    }

    /// Có hộp hỏi (sheet hay hộp thoại) đang mở.
    var hasAlert: Bool {
        app.sheets.firstMatch.exists || app.dialogs.firstMatch.exists
    }

    /// Thư mục đề mẫu của bản Admin trong thư mục tạm (đề mẫu ghi ra khi app mở lần đầu).
    var samplesDirectory: URL {
        isolated.directory.appendingPathComponent("Application Support/vn.io.nt0.examsuite.admin/Samples", isDirectory: true)
    }

    /// Byte của các file đề mẫu (tên file → nội dung).
    func sampleFiles() -> [String: Data] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: samplesDirectory.path)) ?? []
        var result: [String: Data] = [:]
        for name in names where name.hasSuffix(".exam") {
            result[name] = try? Data(contentsOf: samplesDirectory.appendingPathComponent(name))
        }
        return result
    }

    /// Hộp hỏi khi đóng cửa sổ soạn đề có thay đổi chưa lưu (sheet của macOS trên cửa sổ đó).
    func expectCloseSheet(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let sheet = app.sheets.firstMatch
        let found = sheet.waitForExistence(timeout: 5)
        if !found { dumpTree() }
        XCTAssertTrue(found, "Đóng cửa sổ khi có thay đổi chưa lưu phải hỏi", file: file, line: line)
        return sheet
    }

    /// Bỏ thay đổi trong hộp hỏi lưu (đề chưa từng lưu: "Xoá"), chờ hộp đóng.
    func discardChanges(in sheet: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        Self.discard(in: sheet, app: app)
        XCTAssertTrue(sheet.waitForNonExistence(within: 5), "Hộp hỏi lưu chưa đóng", file: file, line: line)
    }

    /// ⌘Q: không còn đề chưa lưu, không có bài đang làm, nên app thoát ngay (không hỏi).
    func quit(file: StaticString = #filePath, line: UInt = #line) {
        app.press("q", .command)
        let quitted = waitUntil(10) { app.state == .notRunning }
        if !quitted { dumpTree() }
        XCTAssertTrue(quitted, "⌘Q không thoát app (còn đề chưa lưu hoặc hộp hỏi?)", file: file, line: line)
    }

    // MARK: - Ghi chú

    func dumpTree() {
        for window in app.windows.allElementsBoundByIndex {
            print("=== CÂY CỬA SỔ \(window.identifier) ===\n\(window.debugDescription)")
        }
    }

    func needsFullKeyboardAccess(_ step: String) {
        XCTContext.runActivity(named: "needsFullKeyboardAccess: \(step) (click thay cho Tab/Space; cần Điều hướng bàn phím của macOS)") { _ in }
    }
}

/// File tự tạo cho UI test bản Admin.
enum AdminFixtures {
    /// Ảnh PNG nhỏ (màu burgundy), dựng lúc chạy test.
    static func png(width: Int = 24, height: Int = 16) -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return Data() }
        let color = NSColor(deviceRed: 0.5, green: 0.09, blue: 0.22, alpha: 1)
        for x in 0 ..< width {
            for y in 0 ..< height { rep.setColor(color, atX: x, y: y) }
        }
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }

    /// File `.txt` tự soạn cho Import đề… (`Fixtures/nhap-thu.txt` trong bundle test; ExamImportTests kiểm cùng file).
    static func importText() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: AdminFixtureBundleToken.self).url(forResource: "nhap-thu", withExtension: "txt"),
            "Bundle test thiếu Fixtures/nhap-thu.txt"
        )
        return try Data(contentsOf: url)
    }
}

/// Lớp mốc để tìm bundle của target UI test.
private final class AdminFixtureBundleToken {}

extension Data {
    /// Gói zip có entry tên `name` (tên entry nằm nguyên trong thư mục trung tâm của zip).
    func zipContainsEntry(named name: String) -> Bool {
        range(of: Data(name.utf8)) != nil
    }
}
