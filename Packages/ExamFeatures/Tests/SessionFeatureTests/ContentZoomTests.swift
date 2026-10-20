import AppKit
@testable import SessionFeature
import SwiftUI
import Testing

/// Cỡ chữ nội dung câu (docs/product/accessibility-localization.md, mục Cỡ chữ, phương án 5; plan giai đoạn 5 bước 8b):
/// bốn mức, Phóng to / Thu nhỏ / Cỡ thật tắt ở giới hạn, giá trị lưu không hợp lệ về cỡ thật, phông nhân hệ số.
@MainActor
@Suite("Cỡ chữ nội dung câu: Phóng to, Thu nhỏ, Cỡ thật")
struct ContentZoomTests {
    @Test("Bốn mức 100/115/130/150%; Phóng to/Thu nhỏ đi từng mức và dừng ở hai đầu")
    func levels() {
        #expect(ContentZoomLevel.allCases.map(\.rawValue) == [100, 115, 130, 150])
        #expect(ContentZoomLevel.allCases.map(\.scale) == [1, 1.15, 1.3, 1.5])
        #expect(ContentZoomLevel.actual.zoomedIn == .large)
        #expect(ContentZoomLevel.larger.zoomedIn == .largest)
        #expect(ContentZoomLevel.largest.zoomedIn == nil)
        #expect(ContentZoomLevel.large.zoomedOut == .actual)
        #expect(ContentZoomLevel.actual.zoomedOut == nil)
        // Giá trị lưu (`@AppStorage`) không hợp lệ thì về cỡ thật; khoá không đổi giữa các bản.
        #expect(ContentZoomLevel(storedPercent: 130) == .larger)
        #expect(ContentZoomLevel(storedPercent: 0) == .actual)
        #expect(ContentZoomLevel(storedPercent: 200) == .actual)
        #expect(ContentZoomLevel.storageKey == "content.zoomPercent")
    }

    @Test("Lệnh menu: bật/tắt ở giới hạn, mỗi lệnh đổi đúng một mức; Cỡ thật về 100%")
    func commands() {
        var stored = ContentZoomLevel.actual
        func control() -> ContentZoomControl { ContentZoomControl(level: stored) { stored = $0 } }

        #expect(control().canZoomIn && !control().canZoomOut && !control().canResetZoom)
        control().zoomOut()
        #expect(stored == .actual)
        for expected in [ContentZoomLevel.large, .larger, .largest, .largest] {
            control().zoomIn()
            #expect(stored == expected)
        }
        #expect(!control().canZoomIn && control().canZoomOut && control().canResetZoom)
        control().zoomOut()
        #expect(stored == .larger)
        control().resetZoom()
        #expect(stored == .actual)
        // So sánh theo mức (menu chỉ dựng lại khi mức đổi).
        #expect(ContentZoomControl(level: .large) { _ in } == ContentZoomControl(level: .large) { _ in })
    }

    @Test("⌘= cũng là Phóng to (chỉ ⌘, không ⇧/⌥/⌃); ⌘+ đi qua menu")
    func zoomInEqualsKey() {
        #expect(ZoomInEqualsKey.isZoomInEquals(characters: "=", modifiers: .command))
        #expect(ZoomInEqualsKey.isZoomInEquals(characters: "=", modifiers: [.command, .numericPad]) == false)
        #expect(!ZoomInEqualsKey.isZoomInEquals(characters: "=", modifiers: [.command, .shift]))
        #expect(!ZoomInEqualsKey.isZoomInEquals(characters: "=", modifiers: [.command, .option]))
        #expect(!ZoomInEqualsKey.isZoomInEquals(characters: "=", modifiers: []))
        #expect(!ZoomInEqualsKey.isZoomInEquals(characters: "-", modifiers: .command))
    }

    @Test("Phông của vùng nội dung: cỡ thật giữ phông kiểu chữ; phóng to nhân cỡ của kiểu chữ macOS")
    func fonts() {
        #expect(ContentFontModifier.font(.title3, weight: nil, design: nil, scale: 1) == .title3)
        #expect(ContentFontModifier.font(.callout, weight: .semibold, design: nil, scale: 1) == Font.callout.weight(.semibold))
        #expect(ContentFontModifier.font(.body, weight: .semibold, design: .monospaced, scale: 1)
            == Font.body.weight(.semibold).monospaced())
        let title3 = NSFont.preferredFont(forTextStyle: .title3).pointSize
        #expect(ContentFontModifier.pointSize(.title3) == title3)
        #expect(ContentFontModifier.font(.title3, weight: nil, design: nil, scale: 1.5)
            == Font.system(size: title3 * 1.5, weight: .regular, design: .default))
        let headline = NSFont.preferredFont(forTextStyle: .headline).pointSize
        #expect(ContentFontModifier.font(.headline, weight: nil, design: nil, scale: 1.3)
            == Font.system(size: headline * 1.3, weight: .bold, design: .default))
    }
}
