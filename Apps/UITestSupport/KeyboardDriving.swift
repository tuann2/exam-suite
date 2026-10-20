import XCTest

/// Lái app chỉ bằng bàn phím (`typeKey`/`typeText`), đọc trạng thái qua `accessibilityIdentifier`.
extension XCUIApplication {
    /// Phần tử đầu tiên có `accessibilityIdentifier` này, bất kể loại. SwiftUI ghép identifier khi gộp phần tử
    /// trợ năng (ví dụ `results.verdict-results.score`), nên khớp cả dạng ghép.
    func element(_ identifier: String) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier BEGINSWITH %@ OR identifier ENDSWITH %@",
            identifier, "\(identifier)-", "-\(identifier)"
        )
        return descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Bấm một phím (kèm phím bổ trợ) vào cửa sổ đang dùng.
    func press(_ key: XCUIKeyboardKey, _ modifiers: XCUIElement.KeyModifierFlags = []) {
        typeKey(key, modifierFlags: modifiers)
    }

    /// Bấm một phím chữ (kèm phím bổ trợ) vào cửa sổ đang dùng.
    func press(_ character: String, _ modifiers: XCUIElement.KeyModifierFlags = []) {
        typeKey(character, modifierFlags: modifiers)
    }
}

extension XCUIApplication {
    /// Bấm Tab (hoặc ⇧Tab) tới khi `element` có tiêu điểm bàn phím, tối đa `maxPresses` lần.
    @discardableResult
    func tab(to element: XCUIElement, backwards: Bool = false, maxPresses: Int = 12) -> Bool {
        for _ in 0 ..< maxPresses {
            if element.hasKeyboardFocus { return true }
            press(.tab, backwards ? .shift : [])
        }
        return element.hasKeyboardFocus
    }
}

extension XCUIElement {
    /// Giá trị trợ năng dạng chuỗi ("" nếu không có).
    var stringValue: String { (value as? String) ?? "" }

    /// Chữ hiển thị của phần tử: nhãn và giá trị (chữ tĩnh của SwiftUI nằm ở giá trị).
    var text: String { [label, stringValue].filter { !$0.isEmpty }.joined(separator: " ") }

    /// Phần tử đang có tiêu điểm bàn phím (thuộc tính trợ năng của macOS).
    var hasKeyboardFocus: Bool { (value(forKey: "hasKeyboardFocus") as? Bool) ?? false }

    /// Chờ tới khi phần tử biến mất.
    @discardableResult
    func waitForNonExistence(within timeout: TimeInterval) -> Bool {
        waitUntil(timeout) { !self.exists }
    }

    /// Chờ tới khi nhãn hoặc giá trị chứa `text`.
    @discardableResult
    func waitForText(_ text: String, within timeout: TimeInterval) -> Bool {
        waitUntil(timeout) { self.exists && self.text.contains(text) }
    }
}

/// Hỏi lại `condition` mỗi 0,2 giây tới khi đúng hoặc hết `timeout` giây.
@MainActor
@discardableResult
func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }
    return condition()
}
