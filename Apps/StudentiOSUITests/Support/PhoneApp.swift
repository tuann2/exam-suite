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
            // Nút giảm của Stepper (nút đầu) tới khi nhãn ghi đúng số phút.
            let stepper = element("preExam.time")
            XCTAssertTrue(reveal(stepper), "Không thấy ô thời gian")
            var taps = 0
            while !stepper.label.contains("\(minutes) phút"), taps < 700 {
                stepper.buttons.element(boundBy: 0).tap()
                taps += 1
            }
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
    /// Ngoại lệ đã xem xét: vấn đề của phần tử khớp `matches` không làm test thất bại, vì `reason`.
    struct Exception {
        let type: XCUIAccessibilityAuditType
        let reason: String
        let matches: (XCUIAccessibilityAuditIssue) -> Bool
    }

    /// (a) Nút đang tắt (Bắt đầu khi chưa có tên thí sinh): WCAG 1.4.3 miễn tương phản cho thành phần không dùng được,
    /// iOS vẽ nút tắt mờ đi. (b) Nút của thanh điều hướng (Huỷ, Bắt đầu, Thư viện, Tạm dừng): thanh của iOS giữ cỡ chữ
    /// cố định và hiện Large Content Viewer khi nhấn giữ ở cỡ chữ trợ năng, app không đổi được. (c) Báo nhầm có bằng
    /// chứng: "Dynamic Type partially unsupported" với ba dòng chữ dùng text style (`.headline`, `.body`) trong `List`:
    /// ảnh chụp ở Accessibility L (bước I2, 2026-10-31) cho thấy cả ba phóng to và xuống dòng như mọi dòng khác.
    static func exceptions(in app: XCUIApplication) -> [Exception] {
        let bar = app.navigationBars.firstMatch
        return [
            Exception(type: .contrast, reason: "nút đang tắt (WCAG 1.4.3)") { issue in
                issue.element.map { $0.exists && !$0.isEnabled } ?? false
            },
            Exception(type: .dynamicType, reason: "nút của thanh điều hướng iOS") { issue in
                guard let element = issue.element, element.exists, bar.exists else { return false }
                return bar.frame.contains(element.frame)
            },
            Exception(type: .textClipped, reason: "nút của thanh điều hướng iOS") { issue in
                guard let element = issue.element, element.exists, bar.exists else { return false }
                return bar.frame.contains(element.frame)
            },
            Exception(type: .dynamicType, reason: "báo nhầm: chữ có text style, ảnh chụp ở Accessibility L") { issue in
                guard let label = issue.element?.label else { return false }
                return ["Theo phần", "Không còn câu chưa làm.", "Không có câu đánh dấu."].contains(label)
            },
        ]
    }

    static func audit(_ app: XCUIApplication, screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let exceptions = exceptions(in: app)
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                if exceptions.contains(where: { $0.type == issue.auditType && $0.matches(issue) }) { return true }
                let element = issue.element
                XCTFail(
                    "Trợ năng (\(screen)): \(issue.compactDescription) — \(issue.detailedDescription) "
                        + "[\(element?.identifier ?? "")|\(element?.label ?? "")|\(element.map { "\($0.elementType.rawValue)" } ?? "")]",
                    file: file,
                    line: line
                )
                return true
            }
        } catch {
            XCTFail("Không chạy được kiểm trợ năng (\(screen)): \(error)", file: file, line: line)
        }
    }
}
