import XCTest

/// Phần tử thấy được trong cửa sổ, đo bằng khung (UI test cửa sổ xếp lát của bước 8a giai đoạn 5; hộp xác nhận Import
/// đề, lỗi beta G6.2). `exists`, giá trị và tiêu điểm bàn phím đều đúng cả với phần tử không thấy được: UI test gõ vào ô
/// bằng Tab (tiêu điểm bàn phím) nên vẫn điền được ô người dùng không thấy. Phải đo khung để bắt lỗi bố cục.
///
/// Khung của phần tử trong vùng cuộn bị co (lỗi G6.2: `Form` cao 0) vẫn có thể nằm trong khung cửa sổ, đè lên phần tử
/// khác, và `isHittable` vẫn đúng (đã thử trên macOS 26): phải so cả với khung của mọi vùng cuộn chứa nó.
enum WindowLayout {
    /// `element` nằm trọn trong `window` (sai số 1 pt); không thì in cây phần tử của cửa sổ để chẩn đoán.
    @MainActor
    static func assertInside(
        _ element: XCUIElement, _ window: XCUIElement, _ what: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let frame = element.frame
        let bounds = window.frame
        let inside = bounds.insetBy(dx: -1, dy: -1).contains(frame)
        if !inside {
            print("=== CÂY CỬA SỔ ===\n\(window.debugDescription)")
        }
        XCTAssertTrue(inside, "\(what) nằm ngoài cửa sổ: \(frame) không trong \(bounds)", file: file, line: line)
    }

    /// `element` có mặt, cao và rộng ít nhất `minimumSize` pt, nằm trọn trong `window` và trong mọi vùng cuộn của cửa sổ
    /// chứa nó (tìm theo `accessibilityIdentifier` của `element`).
    @MainActor
    static func assertVisible(
        _ element: XCUIElement, in window: XCUIElement, _ what: String, minimumSize: CGFloat = 10,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Không có \(what)", file: file, line: line)
        let frame = element.frame
        let visible = frame.height >= minimumSize && frame.width >= minimumSize
        if !visible {
            print("=== CÂY CỬA SỔ ===\n\(window.debugDescription)")
        }
        XCTAssertTrue(
            visible, "\(what) bị co (khung \(frame), cần cao và rộng ≥ \(minimumSize) pt) trong cửa sổ \(window.frame)",
            file: file, line: line
        )
        assertInside(element, window, what, file: file, line: line)
        let identifier = element.identifier
        guard !identifier.isEmpty else { return }
        for scrollView in window.scrollViews.containing(.any, identifier: identifier).allElementsBoundByIndex {
            let clip = scrollView.frame
            let inside = clip.insetBy(dx: -1, dy: -1).contains(frame)
            if !inside {
                print("=== CÂY CỬA SỔ ===\n\(window.debugDescription)")
            }
            XCTAssertTrue(
                inside, "\(what) bị vùng cuộn cắt: \(frame) không trong vùng cuộn \(clip) (cửa sổ \(window.frame))",
                file: file, line: line
            )
        }
    }
}
