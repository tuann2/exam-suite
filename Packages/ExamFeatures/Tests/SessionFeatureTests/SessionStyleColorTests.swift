import AppKit
import InterfaceCore
import LibraryFeature
@testable import SessionFeature
import SwiftUI
import Testing

/// Màu của cửa sổ làm bài dựng đúng từ `LibraryPalette` (độ tương phản của bảng màu có test ở `PaletteContrastTests`),
/// nền nhạt của hàng lựa chọn đã chọn và khung giải thích là nền của bảng màu (plan giai đoạn 5 bước 8b).
@MainActor
@Suite("Màu của cửa sổ làm bài theo bảng màu")
struct SessionStyleColorTests {
    @Test("SessionStyle dựng đúng màu sRGB của LibraryPalette ở từng giao diện", arguments: [false, true])
    func styleColorsMatchPalette(dark: Bool) throws {
        let cases: [(name: String, color: Color, pair: LibraryPalette.Pair)] = [
            ("accentFill", SessionStyle.accentFill, LibraryPalette.accentFill),
            ("accentForeground", SessionStyle.accentForeground, LibraryPalette.accentForeground),
            ("positive", SessionStyle.positive, LibraryPalette.positive),
            ("warning", SessionStyle.warning, LibraryPalette.warning),
            ("critical", SessionStyle.critical, LibraryPalette.critical),
        ]
        for item in cases {
            let resolved = LibraryPalette.systemColor(NSColor(item.color), dark: dark)
            #expect(resolved.rgb == item.pair.rgb(dark: dark), "\(item.name)")
            #expect(resolved.alpha == 1, "\(item.name)")
        }
    }

    @Test("Nền của hàng lựa chọn đã chọn và khung giải thích là nền của bảng màu")
    func backgroundsComeFromPalette() {
        #expect(SessionStyle.selectedOptionBackground
            == .tint(LibraryPalette.accentForeground, opacity: LibraryPalette.tintedBackgroundOpacity))
        #expect(SessionStyle.explanationBackground == .neutral(opacity: LibraryPalette.explanationFillOpacity))
    }
}
