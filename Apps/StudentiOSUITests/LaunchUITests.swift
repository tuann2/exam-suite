import XCTest

/// Mở bản iOS trên simulator (bước I0 của docs/product/plan-ios-v1.md): app chạy tới màn gốc. Ba luồng của plan (Phần 5)
/// thay test này ở bước I2, cùng chế độ cô lập của UI test.
final class LaunchUITests: XCTestCase {
    @MainActor
    func testLaunchShowsRoot() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["root.list"].waitForExistence(timeout: 20), "Không thấy màn gốc")
        app.terminate()
    }
}
