import XCTest

/// Cửa sổ Thư viện mở với khung đã lưu của một máy thật: macOS 26 ghi kèm trạng thái xếp lát (`tilingState`) khi
/// cửa sổ từng được kéo lấp màn hình. Lần mở đầu sau khi cài bản mới, nội dung Thư viện từng bị dựng cao hơn cửa sổ
/// và lệch lên trên (thanh bên và danh sách trống). Khung truyền bằng tham số dòng lệnh (miền tham số), không ghi
/// `defaults` (`TiledWindow`).
///
/// Mở đầu (giai đoạn 5 bước 10, T3 của notes/g5-ui-test-trung-lap.md; trước là lần mở app riêng `LaunchIsolationUITests`):
/// app mở ở chế độ cô lập, Thư viện có hai đề mẫu, kho và cài đặt nằm trong thư mục tạm của test. Khung xếp lát đã lưu
/// chỉ đổi cỡ cửa sổ Thư viện, không đổi chỗ lưu kho hay cài đặt.
final class LibraryWindowRestoreUITests: XCTestCase {
    @MainActor
    func testIsolatedLaunchThenTiledLibraryWindowShowsSidebarAndExamsInsideWindow() throws {
        continueAfterFailure = false
        let isolated = try IsolatedApp(for: self)
        let app = isolated.app
        app.launchArguments += TiledWindow.launchArguments(autosaveName: "library")
        app.launch()

        let card = app.descendants(matching: .any)[Samples.lamQuen.cardID]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Thư viện không có thẻ đề mẫu")
        XCTContext.runActivity(named: "Chế độ cô lập: hai đề mẫu, kho và cài đặt trong thư mục tạm (trước là LaunchIsolationUITests)") { _ in
            XCTAssertTrue(app.descendants(matching: .any)[Samples.attt.cardID].waitForExistence(timeout: 5))
            let store = isolated.directory
                .appendingPathComponent("Application Support/vn.io.nt0.examsuite/Library.store")
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.path), "kho phải nằm trong thư mục tạm")
            // Cài đặt (cờ đề mẫu) ghi vào suite trong thư mục tạm, không vào UserDefaults.standard.
            XCTAssertTrue(
                isolated.waitForIsolatedDefault(IsolatedApp.samplesSeededKey),
                "cờ đề mẫu phải nằm trong \(isolated.defaultsFileURL.path)"
            )
        }
        let window = app.windows["library"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        TiledWindow.logRestoredFrame(of: window, name: "library")
        assertInside(card, window, "thẻ đề mẫu (lưới)")
        // Lần mở đầu có dải chào mừng: đoạn chữ dài của nó từng làm cột đề cao ~2.250 pt khi cửa sổ xếp lát.
        // Tiêu đề của dải là đề mục (`.isHeader`, bước 8b) nên không còn là `staticText`: tìm mọi loại phần tử theo đúng chữ.
        let welcome = window.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "Chào mừng bạn đến với Exam Suite", "Chào mừng bạn đến với Exam Suite"))
            .firstMatch
        XCTAssertTrue(welcome.exists, "Lần mở đầu phải có dải chào mừng (test cần dải này)")
        assertInside(welcome, window, "dải chào mừng")
        let allExams = window.staticTexts["Tất cả đề"].firstMatch
        XCTAssertTrue(allExams.exists, "Thanh bên thiếu mục Tất cả đề")
        assertInside(allExams, window, "mục Tất cả đề của thanh bên")

        // Chế độ danh sách: dòng đề phải nằm trong cửa sổ.
        window.radioButtons["list.bullet"].firstMatch.click()
        // Ô Mã đề chỉ là một chữ riêng ở chế độ danh sách (ở lưới, mã nằm trong nhãn gộp của thẻ).
        let row = window.staticTexts["LAMQUEN"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Danh sách thiếu ô Mã đề của đề mẫu")
        assertInside(row, window, "dòng đề mẫu (danh sách)")
    }

    @MainActor
    private func assertInside(
        _ element: XCUIElement, _ window: XCUIElement, _ what: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        TiledWindow.assertInside(element, window, what, file: file, line: line)
    }
}
