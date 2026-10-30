import XCTest

/// Bản iOS chạy trên simulator ở chế độ cô lập của UI test (chỉ build Debug; LibraryData/AppLaunchStorage.swift, như
/// hai bản macOS): kho, đề mẫu và cài đặt nằm trong một thư mục tạm riêng của từng test, xoá khi test xong. App build
/// với đuôi `.uitest` (`EXAMSUITE_BUNDLE_ID_SUFFIX`); simulator tách dữ liệu khỏi máy Mac.
///
/// - `-ExamSuiteUITest <thư mục>`: thư mục có file đánh dấu `.examsuite-uitest`.
/// - `-ExamSuiteUITestTimeScale <hệ số>`: đồng hồ phiên thi nhanh gấp <hệ số> lần (luồng 2).
/// - `-ExamSuiteUITestChosenFile <file>`: file dùng thay hộp chọn file khi bấm Thêm đề (XCUITest không lái được hộp
///   chọn file của iOS); phải nằm trong thư mục tạm của test.
/// - `-AppleLanguages (vi)`: giao diện tiếng Việt (test tìm phần tử theo định danh, vài chữ tiếng Việt).
@MainActor
final class PhoneApp {
    let app: XCUIApplication
    let directory: URL

    init(for testCase: XCTestCase, timeScale: Double? = nil) throws {
        let base = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("ExamSuiteiOSUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data().write(to: base.appendingPathComponent(".examsuite-uitest"))
        directory = base
        app = XCUIApplication()
        var arguments = ["-ExamSuiteUITest", base.path, "-AppleLanguages", "(vi)"]
        if let timeScale {
            arguments += ["-ExamSuiteUITestTimeScale", String(timeScale)]
        }
        app.launchArguments = arguments
        testCase.addTeardownBlock { @MainActor [self] in
            app.terminate()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// Chép `source` vào `<thư mục tạm>/Files/<name>` và dùng nó thay hộp chọn file. Gọi trước `app.launch()`.
    func useChosenFile(copying source: URL, as name: String) throws {
        let files = directory.appendingPathComponent("Files", isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let url = files.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: url)
        app.launchArguments += ["-ExamSuiteUITestChosenFile", url.path]
    }

    /// File đề mẫu mà app đã ghi vào thư mục cô lập lần đầu mở (`Application Support/<bundle ID>/Samples`).
    func sampleFile(named name: String) -> URL {
        directory.appendingPathComponent("Application Support/vn.io.nt0.examsuite/Samples/\(name)")
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Chờ phần tử có định danh `identifier` xuất hiện rồi chạm. Dòng của `List` ngoài màn chưa có trong cây trợ năng:
    /// không thấy thì cuộn lên tối đa vài lần.
    func tap(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let element = element(identifier)
        XCTAssertTrue(reveal(element, timeout: timeout), "Không thấy \(identifier)", file: file, line: line)
        element.tap()
    }

    /// Chờ `element` xuất hiện; chưa có thì cuộn màn lên (tối đa 6 lần) tới khi chạm được.
    @discardableResult
    func reveal(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        if element.waitForExistence(timeout: timeout), element.isHittable { return true }
        for _ in 0 ..< 6 {
            app.swipeUp()
            if element.waitForExistence(timeout: 1), element.isHittable { return true }
        }
        return element.exists
    }

    /// Dòng của đề trong Thư viện.
    func row(_ exam: Samples.Exam) -> XCUIElement {
        element("library.row.\(exam.id.uppercased())")
    }

    /// Mở Trước khi thi của đề, đặt tên thí sinh, chế độ, rồi Bắt đầu.
    func start(
        _ exam: Samples.Exam,
        mode: String,
        name: String = "Nguyễn Văn An",
        minutes: Int? = nil,
        auditPreExam: Bool = false
    ) {
        let row = row(exam)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "Không thấy đề \(exam.code) trong Thư viện")
        row.tap()
        let nameField = element("preExam.name")
        XCTAssertTrue(element("preExam.start").waitForExistence(timeout: 10), "Không mở được Trước khi thi")
        if auditPreExam { PhoneAccessibilityAudit.audit(app, screen: "Trước khi thi") }
        XCTAssertTrue(reveal(nameField), "Không thấy ô tên thí sinh")
        nameField.tap()
        if let current = nameField.value as? String, !current.isEmpty, current != nameField.placeholderValue {
            nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        nameField.typeText(name)
        let modeControl = app.segmentedControls["preExam.mode"]
        XCTAssertTrue(reveal(modeControl), "Không thấy ô chọn chế độ")
        modeControl.buttons[mode].tap()
        if let minutes {
            // Gõ số phút vào ô số: chạm ô (cuộn tới và chọn ô), chạm mép phải để con trỏ ở cuối số, xoá rồi gõ; rồi Xong
            // trên thanh bàn phím.
            let field = element("preExam.timeLimit")
            XCTAssertTrue(reveal(field), "Không thấy ô thời gian")
            field.tap()
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            let current = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "\(minutes)")
            tap("keyboard.done")
            // Bàn phím là tiến trình khác: cây trợ năng của app không cho biết nó còn đang thu lại, kiểm trợ năng lúc đó báo
            // nhầm phần tử của bàn phím. Chờ bàn phím biến mất.
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Bàn phím chưa đóng")
            XCTAssertEqual(field.value as? String, "\(minutes)", "Ô thời gian phải ghi \(minutes) phút")
            if auditPreExam { PhoneAccessibilityAudit.audit(app, screen: "Trước khi thi (Thi, ô thời gian)") }
        }
        tap("preExam.start")
        XCTAssertTrue(element("attempt.clock").waitForExistence(timeout: 15), "Chưa vào màn làm bài")
    }

    /// Chọn các lựa chọn (chữ cái theo vị trí) của câu đang xem rồi sang câu sau.
    func answer(_ letters: String, next: Bool = true) {
        for letter in letters {
            tap("option.\(letter)")
        }
        if next { tap("attempt.next") }
    }
}

/// Kiểm trợ năng tự động của iOS (`XCUIApplication.performAccessibilityAudit`;
/// docs/product/accessibility-localization.md,
/// phương án 7): một lần ở mỗi màn mà luồng đi qua, mọi loại kiểm có trên iOS. Vấn đề nào cũng làm test thất bại, trừ
/// ngoại lệ ghi ở `exceptions` (loại kiểm, phần tử, lý do).
@MainActor
enum PhoneAccessibilityAudit {
    /// Chờ màn đứng yên: ít nhất 1 giây (hoạt cảnh mờ dần, như Rà soát khoá hiện ra cùng dải "Đã hết giờ", không đổi
    /// khung nên cây trợ năng không cho biết), rồi tới khi cây trợ năng (kể cả khung) không đổi giữa hai lần đọc cách 0,5
    /// giây, tối đa thêm 5 giây. Kiểm lúc màn đang chuyển đo chữ đang mờ hay khung đang di chuyển và báo nhầm (tương phản,
    /// "Dynamic Type partially unsupported"; bước I2a, 2026-10-31).
    static func waitUntilStill(_ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1)
        var previous = app.debugDescription
        for _ in 0 ..< 10 {
            Thread.sleep(forTimeInterval: 0.5)
            let current = app.debugDescription
            if current == previous { return }
            previous = current
        }
    }

    /// Ngoại lệ đã xem xét: vấn đề của phần tử khớp `matches` không làm test thất bại, vì `reason`.
    struct Exception {
        let type: XCUIAccessibilityAuditType
        let reason: String
        let matches: (XCUIAccessibilityAuditIssue) -> Bool
    }

    /// (a) Nút đang tắt (Bắt đầu khi chưa có tên thí sinh): WCAG 1.4.3 miễn tương phản cho thành phần không dùng được,
    /// iOS vẽ nút tắt mờ đi. (b) Nút của thanh điều hướng (Huỷ, Bắt đầu, Thư viện, Tạm dừng, Xong của sheet): thanh của
    /// iOS giữ cỡ chữ cố định và hiện Large Content Viewer khi nhấn giữ ở cỡ chữ trợ năng, app không đổi được; tương
    /// phản của chúng phụ thuộc nền kính lấy từ nội dung cuộn bên dưới. Xét mọi
    /// thanh điều hướng đang có (màn bên dưới và sheet), không chỉ thanh đầu tiên. (c) Báo nhầm có bằng chứng: "Dynamic
    /// Type partially unsupported" với chữ trong dòng của `List` (lúc thì "Theo phần", "Không còn câu chưa làm.", lúc thì
    /// "Đánh dấu", "0" của Rà soát khoá: đổi theo lần chạy). Chữ của MobileFeature chỉ dùng text style (cỡ cố định chỉ
    /// ở biểu tượng trang trí), và ảnh chụp ở Accessibility L (bước I2a, 2026-10-31: Kết quả, Rà soát, Rà soát khoá)
    /// cho thấy các dòng đó phóng to và xuống dòng như mọi dòng khác. Chỉ miễn báo "partially unsupported" (không miễn
    /// "unsupported": cỡ chữ cố định thật), chỉ chữ tĩnh của `List`/`Form` (cùng nhãn và cùng khung).
    static func exceptions(in app: XCUIApplication) -> [Exception] {
        let bars = app.navigationBars
        func inNavigationBar(_ element: XCUIElement) -> Bool {
            bars.allElementsBoundByIndex.contains { $0.exists && $0.frame.contains(element.frame) }
        }
        return [
            Exception(type: .contrast, reason: "nút đang tắt (WCAG 1.4.3)") { issue in
                issue.element.map { $0.exists && !$0.isEnabled } ?? false
            },
            Exception(type: .dynamicType, reason: "nút của thanh điều hướng iOS") { issue in
                guard let element = issue.element, element.exists else { return false }
                return inNavigationBar(element)
            },
            // Nút của thanh là kính Liquid Glass của hệ thống, lấy màu từ nội dung cuộn bên dưới: "Huỷ" của Trước khi
            // thi đạt khi form chưa cuộn (luồng 1) và bị báo khi form đã cuộn tới ô thời gian (luồng 2). Màu chữ là màu
            // nhấn #006666 (≈7:1 trên nền trắng, `PaletteContrastTests`); nền kính app không đặt được.
            Exception(type: .contrast, reason: "nút của thanh điều hướng iOS trên kính Liquid Glass") { issue in
                guard let element = issue.element, element.exists else { return false }
                return inNavigationBar(element)
            },
            Exception(type: .textClipped, reason: "nút của thanh điều hướng iOS") { issue in
                guard let element = issue.element, element.exists else { return false }
                return inNavigationBar(element)
            },
            Exception(type: .dynamicType, reason: "báo nhầm: chữ có text style trong List, ảnh ở Accessibility L") { issue in
                // Chữ tĩnh thuộc một `List` (kể cả dòng đã cuộn khỏi khung, nằm dưới thanh nút): cùng nhãn và cùng khung.
                guard issue.compactDescription.contains("partially"), let element = issue.element, element.exists,
                      element.elementType == .staticText, !element.label.isEmpty else { return false }
                let frame = element.frame
                return app.collectionViews.staticTexts.matching(NSPredicate(format: "label == %@", element.label))
                    .allElementsBoundByIndex.contains { $0.frame == frame }
            },
        ]
    }

    /// Kiểm tương phản trước, trên màn chưa bị đổi gì, rồi mới các loại còn lại: kiểm Dynamic Type đổi cỡ chữ, `List`
    /// dựng lại dòng có hoạt cảnh, và tương phản đo trong lúc đó báo nhầm chập chờn ở chữ chính trên nền trắng (tiêu đề
    /// nhóm của Rà soát khoá; bước I2a, 2026-10-31).
    static func audit(_ app: XCUIApplication, screen: String, file: StaticString = #filePath, line: UInt = #line) {
        waitUntilStill(app)
        let exceptions = exceptions(in: app)
        let handler: (XCUIAccessibilityAuditIssue) throws -> Bool = { issue in
            if exceptions.contains(where: { $0.type == issue.auditType && $0.matches(issue) }) { return true }
            let element = issue.element
            let frame = element.flatMap { $0.exists ? "\($0.frame)" : nil } ?? "-"
            let lists = app.collectionViews.allElementsBoundByIndex.map { "\($0.frame)" }.joined(separator: ",")
            XCTFail(
                "Trợ năng (\(screen)): \(issue.compactDescription) — \(issue.detailedDescription) "
                    + "[\(element?.identifier ?? "")|\(element?.label ?? "")|\(element.map { "\($0.elementType.rawValue)" } ?? "")"
                    + "|khung \(frame)|List \(lists)]",
                file: file,
                line: line
            )
            return true
        }
        do {
            try app.performAccessibilityAudit(for: .contrast, handler)
            try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(.contrast), handler)
        } catch {
            XCTFail("Không chạy được kiểm trợ năng (\(screen)): \(error)", file: file, line: line)
        }
    }
}
