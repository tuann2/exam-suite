import AppKit
import Foundation
@testable import LibraryFeature
import SwiftUI
import Testing

/// Độ tương phản của **mọi** màu app tự định nghĩa và nền nhạt pha màu, tính trên nền thật ở cả hai giao diện
/// (docs/product/accessibility-localization.md, mục Dark Mode và tương phản; library.md phương án 8; plan giai đoạn 5 bước
/// 8b). Màu ngữ nghĩa của hệ thống (`.secondary`, `.separator`…) không thuộc quy tắc (Nt0 chốt 2026-10-18); chữ `.primary`
/// (`labelColor`, độ mờ 0,85) đặt trên nền nhạt của app thì có kiểm, vì nền đó là của app.
///
/// Nền cửa sổ thật (`NSColor.windowBackgroundColor`) đọc lúc chạy (`LibraryPalette.windowBackground`): máy chạy test phải tắt
/// Increase Contrast (AGENTS.md, như snapshot test).
@MainActor
@Suite("Tương phản của bảng màu và nền nhạt trên nền thật")
struct PaletteContrastTests {
    static let smallText = 4.5
    static let largeTextOrIcon = 3.0

    /// Màu của bảng dùng cho **chữ nhỏ** (và biểu tượng): teal trên nền (gợi ý "Chọn N đáp án", "Bạn chọn", nhãn Đề mẫu),
    /// xanh/cam/đỏ của trạng thái ("Đúng", "Sai", "Đã đánh dấu", "Phần yếu nhất", lỗi của hộp xác nhận import…).
    static let textColors: [(name: String, pair: LibraryPalette.Pair)] = [
        ("accentForeground", LibraryPalette.accentForeground),
        ("positive", LibraryPalette.positive),
        ("warning", LibraryPalette.warning),
        ("critical", LibraryPalette.critical),
    ]

    /// Nền nhạt pha màu của app, mỗi cái với màu của nó: chữ đặt lên là `.primary` (dải thông báo), hoặc chính màu đó
    /// (nhãn Đề mẫu), hoặc màu của bảng (hàng lựa chọn đã chọn: "Đúng"/"Sai" sau Kiểm tra đáp án).
    static let tints: [(name: String, background: AdaptiveBackground, tone: LibraryPalette.Pair)] = [
        ("dải cảnh báo", .tint(LibraryPalette.warning, opacity: LibraryPalette.tintedBackgroundOpacity), LibraryPalette.warning),
        ("dải lỗi", .tint(LibraryPalette.critical, opacity: LibraryPalette.tintedBackgroundOpacity), LibraryPalette.critical),
        ("dải chào mừng, nhãn Đề mẫu, hàng lựa chọn đã chọn",
         .tint(LibraryPalette.accentForeground, opacity: LibraryPalette.tintedBackgroundOpacity), LibraryPalette.accentForeground),
        ("lớp phủ kéo thả", .tint(LibraryPalette.accentForeground, opacity: LibraryPalette.dropTargetOpacity),
         LibraryPalette.accentForeground),
    ]

    /// Chữ `.primary` của hệ thống trên nền `background`: `labelColor` (có độ mờ) trộn lên nền.
    static func primaryText(on background: LibraryPalette.RGB, dark: Bool) -> LibraryPalette.RGB {
        let label = LibraryPalette.systemColor(.labelColor, dark: dark)
        return LibraryPalette.flatten(label.rgb, alpha: label.alpha, over: background)
    }

    static func blend(_ background: AdaptiveBackground, over base: LibraryPalette.RGB, dark: Bool) -> LibraryPalette.RGB {
        switch background {
        case let .tint(pair, opacity):
            return LibraryPalette.flatten(pair.rgb(dark: dark), alpha: opacity, over: base)
        case let .neutral(opacity):
            let quaternary = LibraryPalette.systemColor(.quaternaryLabelColor, dark: dark)
            return LibraryPalette.flatten(quaternary.rgb, alpha: quaternary.alpha * opacity, over: base)
        case .bar, .material:
            return base
        }
    }

    // MARK: - Nền thật

    @Test("Nền cửa sổ thật đọc được ở hai giao diện và có trong danh sách nền phải kiểm")
    func windowBackgroundIsResolved() {
        let light = LibraryPalette.windowBackground(dark: false)
        let dark = LibraryPalette.windowBackground(dark: true)
        #expect(light.luminance > 0.8, "nền sáng \(light)")
        #expect(dark.luminance < 0.05, "nền tối \(dark)")
        #expect(LibraryPalette.backgrounds(dark: false).contains(light))
        #expect(LibraryPalette.backgrounds(dark: true).contains(dark))
    }

    // MARK: - Màu của bảng làm chữ

    @Test("Màu của bảng làm chữ nhỏ đạt 4,5:1 trên mọi nền (nền đo được và nền cửa sổ thật)", arguments: [false, true])
    func paletteTextOnEveryBackground(dark: Bool) {
        for (name, pair) in Self.textColors {
            for background in LibraryPalette.backgrounds(dark: dark) {
                let ratio = LibraryPalette.contrast(pair.rgb(dark: dark), background)
                #expect(ratio >= Self.smallText, "\(name) \(pair.rgb(dark: dark)) trên \(background): \(ratio)")
            }
        }
    }

    @Test("Chữ màu của bảng trên hàng lựa chọn đã chọn (nền nhạt teal trên nền cửa sổ của macOS 26, macOS 15 và máy chạy test) đạt 4,5:1",
          arguments: [false, true])
    func paletteTextOnSelectedOption(dark: Bool) {
        for window in LibraryPalette.windowBackgrounds(dark: dark) {
            let row = Self.blend(.tint(LibraryPalette.accentForeground, opacity: LibraryPalette.tintedBackgroundOpacity), over: window, dark: dark)
            for (name, pair) in Self.textColors {
                let ratio = LibraryPalette.contrast(pair.rgb(dark: dark), row)
                #expect(ratio >= Self.smallText, "\(name) trên hàng đã chọn \(row) (nền cửa sổ \(window)): \(ratio)")
            }
        }
    }

    // MARK: - Nền nhạt của app

    @Test("Chữ .primary đạt 4,5:1 và biểu tượng màu của dải đạt 3:1 trên mọi nền nhạt pha màu, trên mọi nền",
          arguments: [false, true])
    func tintedBackgroundsKeepTextReadable(dark: Bool) {
        for (name, background, tone) in Self.tints {
            for base in LibraryPalette.backgrounds(dark: dark) {
                let blended = Self.blend(background, over: base, dark: dark)
                let text = Self.primaryText(on: blended, dark: dark)
                #expect(LibraryPalette.contrast(text, blended) >= Self.smallText, "chữ trên \(name) / \(base)")
                #expect(LibraryPalette.contrast(tone.rgb(dark: dark), blended) >= Self.largeTextOrIcon, "biểu tượng trên \(name) / \(base)")
            }
        }
    }

    @Test("Nhãn Đề mẫu: chữ teal trên nền nhạt teal của chính nó đạt 4,5:1 trên mọi nền", arguments: [false, true])
    func sampleBadgeOnItsTint(dark: Bool) {
        let badge = AdaptiveBackground.tint(LibraryPalette.accentForeground, opacity: LibraryPalette.tintedBackgroundOpacity)
        for base in LibraryPalette.backgrounds(dark: dark) {
            let blended = Self.blend(badge, over: base, dark: dark)
            let ratio = LibraryPalette.contrast(LibraryPalette.accentForeground.rgb(dark: dark), blended)
            #expect(ratio >= Self.smallText, "\(base): \(ratio)")
        }
    }

    @Test("Chữ .primary đạt 4,5:1 trên nền trung tính của app (khung giải thích, ô số Rà soát)", arguments: [false, true])
    func neutralFillsKeepTextReadable(dark: Bool) {
        for opacity in [LibraryPalette.explanationFillOpacity, LibraryPalette.statFillOpacity, 1] {
            for base in LibraryPalette.backgrounds(dark: dark) {
                let blended = Self.blend(.neutral(opacity: opacity), over: base, dark: dark)
                let ratio = LibraryPalette.contrast(Self.primaryText(on: blended, dark: dark), blended)
                #expect(ratio >= Self.smallText, "độ mờ \(opacity) trên \(base): \(ratio)")
            }
        }
    }

    // MARK: - Dòng đang chọn

    @Test("Dòng đang chọn: chữ trắng trên nền chọn teal đạt 4,5:1; màu của bảng trên nền chọn đậm thành chữ của hệ thống")
    func selectedRows() {
        for dark in [false, true] {
            #expect(LibraryPalette.contrast(LibraryPalette.white, LibraryPalette.accentFill.rgb(dark: dark)) >= Self.smallText)
        }
        #expect(PaletteForeground.resolve(prominence: .increased) == .system)
        #expect(PaletteForeground.resolve(prominence: .standard) == .palette)
        // Lý do: màu của bảng trên nền chọn teal gần như không thấy.
        for (name, pair) in Self.textColors where name != "accentForeground" {
            #expect(LibraryPalette.contrast(pair.light, LibraryPalette.accentFill.light) < Self.largeTextOrIcon, "\(name)")
        }
    }

    // MARK: - Reduce Transparency

    static let adaptiveBackgrounds: [AdaptiveBackground] = Self.tints.map(\.background) + [
        .neutral(opacity: LibraryPalette.explanationFillOpacity), .neutral(opacity: LibraryPalette.statFillOpacity),
        .neutral(opacity: 1), .bar, .material,
    ]

    @Test("Reduce Transparency: nền đặc (độ mờ 1) đúng bằng màu đã trộn trên nền cửa sổ thật mà test tương phản tính",
          arguments: [false, true])
    func reduceTransparencySolidColors(dark: Bool) throws {
        let window = LibraryPalette.windowBackground(dark: dark)
        for background in Self.adaptiveBackgrounds {
            let resolved = LibraryPalette.systemColor(background.solidColor, dark: dark)
            #expect(resolved.alpha == 1, "\(background)")
            #expect(resolved.rgb == background.solidRGB(dark: dark), "\(background)")
            #expect(background.solidRGB(dark: dark) == Self.blend(background, over: window, dark: dark), "\(background)")
        }
        #expect(AdaptiveBackground.bar.solidRGB(dark: dark) == window)
    }

    // MARK: - Đối chứng âm

    @Test("Đối chứng âm: màu cũ (bước 8a, bản đầu của 8b) không đạt ở đúng chỗ test bắt, kể cả nền của macOS 15")
    func previousColorsFail() {
        let white = LibraryPalette.white
        let selectedRow = LibraryPalette.flatten(LibraryPalette.accentForeground.light, alpha: LibraryPalette.tintedBackgroundOpacity, over: white)
        #expect(LibraryPalette.contrast(LibraryPalette.RGB(hex: 0x1E7B34), selectedRow) < Self.smallText)
        #expect(LibraryPalette.contrast(LibraryPalette.RGB(hex: 0xFF6961), LibraryPalette.RGB(hex: 0x3A3A3A)) < Self.smallText)
        // Bản đầu của 8b chỉ tính nền cửa sổ của macOS 26: trên nền macOS 15 (#ECECEC, #323232) không đạt.
        let mac15Light = LibraryPalette.flatten(LibraryPalette.accentForeground.light, alpha: LibraryPalette.tintedBackgroundOpacity,
                                                over: LibraryPalette.RGB(hex: 0xECECEC))
        let mac15Dark = LibraryPalette.flatten(LibraryPalette.accentForeground.dark, alpha: LibraryPalette.tintedBackgroundOpacity,
                                               over: LibraryPalette.RGB(hex: 0x323232))
        for old in [0x1C7631, 0xA35200, 0xC42B1C] as [UInt32] {
            #expect(LibraryPalette.contrast(LibraryPalette.RGB(hex: old), mac15Light) < Self.smallText, "\(String(old, radix: 16))")
        }
        #expect(LibraryPalette.contrast(LibraryPalette.RGB(hex: 0xFF8077), mac15Dark) < Self.smallText)
        #expect(LibraryPalette.windowBackgrounds(dark: false).contains(LibraryPalette.RGB(hex: 0xECECEC)))
        #expect(LibraryPalette.windowBackgrounds(dark: true).contains(LibraryPalette.RGB(hex: 0x323232)))
    }
}
