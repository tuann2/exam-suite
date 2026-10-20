import XCTest

/// Khung cửa sổ đã lưu kèm trạng thái xếp lát của macOS 26 (`tilingState`) và phép kiểm phần tử nằm trong cửa sổ, dùng
/// cho các UI test mở cửa sổ với khung đó (plan giai đoạn 5, Decisions 2026-10-17 "Thư viện trống"; bước 8a). Khung
/// truyền bằng tham số dòng lệnh `-NSWindow Frame <tên autosave>` (miền tham số), không ghi `defaults`.
enum TiledWindow {
    /// Giá trị "NSWindow Frame library" lấy từ một Mac thật (2026-10-17): cửa sổ 1352×783 lấp màn hình 1352×848.
    static let frame =
        #"0 65 1352 783 0 0 1352 848 {"tilingState":{"tilingPosition":6,"normalizedSize":2,"untiledFrame":"{{0, 30}, {1352, 783}}"}}"#

    /// Cỡ cửa sổ trong `frame`.
    static let size = CGSize(width: 1352, height: 783)

    /// Tham số dòng lệnh đặt khung đã lưu của cửa sổ có tên autosave `name` (định danh của scene `Window`).
    static func launchArguments(autosaveName name: String) -> [String] {
        ["-NSWindow Frame \(name)", frame]
    }

    /// Cửa sổ có mở đúng cỡ của khung đã lưu không (macOS có thể dời khung cho vừa màn hình của máy chạy test; cỡ khác hẳn
    /// nghĩa là cửa sổ không dùng khung đã lưu). Ghi kết quả vào log.
    @MainActor
    @discardableResult
    static func logRestoredFrame(of window: XCUIElement, name: String) -> Bool {
        let frame = window.frame
        let restored = abs(frame.width - size.width) < 2 && abs(frame.height - size.height) < 40
        XCTContext.runActivity(named: "Cửa sổ \(name): khung \(frame), \(restored ? "đã" : "KHÔNG") dùng khung xếp lát đã lưu") { _ in }
        return restored
    }

    /// `element` nằm trọn trong `window` (sai số 1 pt); không thì in cây phần tử của cửa sổ để chẩn đoán. Phép kiểm dùng
    /// chung với bản Admin: `WindowLayout` (Apps/UITestSupport).
    @MainActor
    static func assertInside(
        _ element: XCUIElement, _ window: XCUIElement, _ what: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        WindowLayout.assertInside(element, window, what, file: file, line: line)
    }
}
