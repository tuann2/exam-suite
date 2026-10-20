import AppKit
import Foundation
import LibraryFeature
@testable import SessionFeature
import SwiftUI
import Testing

/// **Nền đọc** của vùng nội dung câu (docs/product/accessibility-localization.md, mục Dark Mode và tương phản; plan giai
/// đoạn 6 bước 1): năm nền, bộ màu đạt tương phản ở cả giao diện sáng và tối của macOS, nền cố định không đổi khi macOS đổi
/// sáng/tối, lựa chọn nhớ trong `defaults` của scene (không phải `UserDefaults.standard`), chỉ vùng nội dung câu đổi màu.
@MainActor
@Suite("Nền đọc: bộ màu, tương phản, nhớ lựa chọn, phạm vi")
struct ReadingBackgroundTests {
    static let smallText = 4.5
    static let largeTextOrIcon = 3.0
    static let fixed: [ReadingBackground] = [.white, .sepia, .softGray, .dark]

    typealias RGB = LibraryPalette.RGB

    // MARK: - Năm nền và giá trị lưu

    @Test("Năm nền theo thứ tự của menu; Theo hệ thống là mặc định; giá trị lưu không hợp lệ về Theo hệ thống")
    func presetsAndStoredValues() {
        #expect(ReadingBackground.allCases == [.system, .white, .sepia, .softGray, .dark])
        #expect(ReadingBackground.allCases.map(\.title) == ["Theo hệ thống", "Trắng", "Giấy ngà", "Xám dịu", "Tối"])
        // Khoá và giá trị lưu không đổi giữa các bản (đổi thì người dùng mất lựa chọn).
        #expect(ReadingBackground.storageKey == "content.readingBackground")
        #expect(ReadingBackground.allCases.map(\.rawValue) == ["system", "white", "sepia", "softGray", "dark"])
        #expect(ReadingBackground(storedValue: "sepia") == .sepia)
        #expect(ReadingBackground(storedValue: "") == .system)
        #expect(ReadingBackground(storedValue: "Sepia") == .system)
        #expect(ReadingBackground(storedValue: "night") == .system)
        #expect(ReadingBackground.system.fixedPalette == nil)
        #expect(Self.fixed.allSatisfy { $0.fixedPalette != nil })
    }

    @Test("Lệnh menu ghi đúng nền vào giá trị lưu; so sánh theo nền (menu chỉ dựng lại khi nền đổi)")
    func menuControlWritesChoice() {
        var stored = ReadingBackground.system
        let control = ReadingBackgroundControl(background: stored) { stored = $0 }
        control.choose(.sepia)
        #expect(stored == .sepia)
        control.choose(.dark)
        #expect(stored == .dark)
        #expect(ReadingBackgroundControl(background: .white) { _ in } == ReadingBackgroundControl(background: .white) { _ in })
        #expect(ReadingBackgroundControl(background: .white) { _ in } != ReadingBackgroundControl(background: .dark) { _ in })
    }

    // MARK: - Tương phản của năm bộ màu

    /// Nền mà chữ, biểu tượng của vùng nội dung câu đặt lên: nền, lựa chọn đang chọn, khung giải thích, dòng báo cảnh báo/lỗi
    /// (Xem lại bài).
    static func surfaces(_ palette: ReadingPalette) -> [(name: String, rgb: RGB)] {
        [
            ("nền", palette.background),
            ("lựa chọn đang chọn", palette.selectedOptionBackground),
            ("khung giải thích", palette.explanationBackground),
            ("dòng báo cảnh báo", palette.tinted(palette.warning)),
            ("dòng báo lỗi", palette.tinted(palette.critical)),
        ]
    }

    @Test("Chữ, chữ phụ, teal, Đúng/Sai/đánh dấu đạt 4,5:1 trên mọi nền của vùng nội dung (kể cả Đúng/Sai trên lựa chọn đang chọn)",
          arguments: ReadingBackground.allCases, [false, true])
    func paletteTextContrast(background: ReadingBackground, systemDark: Bool) {
        let palette = background.palette(systemDark: systemDark)
        var colors: [(name: String, rgb: RGB)] = [
            ("chữ", palette.text),
            ("teal", palette.accent),
            ("Đúng", palette.positive),
            ("Sai", palette.critical),
            ("đánh dấu", palette.warning),
        ]
        // Theo hệ thống: chữ phụ là `.secondary` của macOS, được miễn quy tắc của app (Nt0 chốt 2026-10-18); nền cố định thì
        // chữ phụ là màu của bộ màu, phải đạt.
        if background != .system { colors.append(("chữ phụ", palette.secondaryText)) }
        for (surface, base) in Self.surfaces(palette) {
            for (name, color) in colors {
                let ratio = LibraryPalette.contrast(color, base)
                #expect(ratio >= Self.smallText,
                        "\(background) (macOS \(systemDark ? "tối" : "sáng")): \(name) \(color) trên \(surface) \(base): \(ratio)")
            }
        }
    }

    @Test("Biểu tượng đạt 3:1: dấu của lựa chọn (đang chọn và chưa chọn), biểu tượng của dòng báo trên nền của nó",
          arguments: ReadingBackground.allCases, [false, true])
    func paletteIconContrast(background: ReadingBackground, systemDark: Bool) {
        let palette = background.palette(systemDark: systemDark)
        #expect(LibraryPalette.contrast(palette.accent, palette.selectedOptionBackground) >= Self.largeTextOrIcon)
        for tone in [palette.warning, palette.critical] {
            #expect(LibraryPalette.contrast(tone, palette.tinted(tone)) >= Self.largeTextOrIcon, "\(background) \(tone)")
        }
        if background != .system {
            #expect(LibraryPalette.contrast(palette.secondaryText, palette.background) >= Self.largeTextOrIcon)
        }
    }

    @Test("Nền cố định giữ nguyên khi macOS đổi sáng/tối; Theo hệ thống đổi theo")
    func fixedPalettesIgnoreSystemAppearance() throws {
        for background in Self.fixed {
            let palette = try #require(background.fixedPalette)
            #expect(background.palette(systemDark: false) == palette)
            #expect(background.palette(systemDark: true) == palette)
            // Màu SwiftUI dựng từ bộ màu ra cùng giá trị ở cả hai giao diện của cửa sổ.
            let style = ReadingStyle(background)
            for (name, color, expected) in [("teal", style.accent, palette.accent), ("Đúng", style.positive, palette.positive),
                                            ("Sai", style.critical, palette.critical), ("đánh dấu", style.warning, palette.warning)] {
                for dark in [false, true] {
                    let resolved = LibraryPalette.systemColor(NSColor(color), dark: dark)
                    #expect(resolved.rgb == expected && resolved.alpha == 1, "\(background) \(name) ở giao diện \(dark ? "tối" : "sáng")")
                }
            }
        }
        #expect(ReadingBackground.system.palette(systemDark: false) != ReadingBackground.system.palette(systemDark: true))
        #expect(ReadingPalette.dark.isDark && !ReadingPalette.sepia.isDark && !ReadingPalette.white.isDark
            && !ReadingPalette.softGray.isDark)
    }

    @Test("Theo hệ thống: vùng nội dung vẽ đúng như trước khi có nền đọc (màu và nền của SessionStyle)")
    func systemStyleKeepsSessionStyle() {
        let style = ReadingStyle.system
        #expect(style == ReadingStyle(.system))
        #expect(style.palette == nil)
        #expect(style.selectedOptionBackground == .adaptive(SessionStyle.selectedOptionBackground))
        #expect(style.explanationBackground == .adaptive(SessionStyle.explanationBackground))
        #expect(style.bannerBackground(tone: LibraryPalette.warning)
            == .adaptive(.tint(LibraryPalette.warning, opacity: LibraryPalette.tintedBackgroundOpacity)))
        for dark in [false, true] {
            for (color, pair) in [(style.accent, LibraryPalette.accentForeground), (style.positive, LibraryPalette.positive),
                                  (style.critical, LibraryPalette.critical), (style.warning, LibraryPalette.warning)] {
                #expect(LibraryPalette.systemColor(NSColor(color), dark: dark).rgb == pair.rgb(dark: dark))
            }
        }
        // Bộ màu của Theo hệ thống (test, mẫu màu) dựng từ cùng màu mà cửa sổ làm bài vẽ.
        for dark in [false, true] {
            let palette = ReadingBackground.system.palette(systemDark: dark)
            #expect(palette.background == LibraryPalette.windowBackground(dark: dark))
            #expect(palette.selectedOptionBackground == SessionStyle.selectedOptionBackground.solidRGB(dark: dark))
            #expect(palette.explanationBackground == SessionStyle.explanationBackground.solidRGB(dark: dark))
            #expect(palette.accent == LibraryPalette.accentForeground.rgb(dark: dark))
        }
    }

    @Test("Nền cố định: nền của lựa chọn đang chọn, khung giải thích, dòng báo là màu đặc của bộ màu (không độ trong)")
    func fixedStyleUsesSolidFills() throws {
        for background in Self.fixed {
            let palette = try #require(background.fixedPalette)
            let style = ReadingStyle(background)
            #expect(style.selectedOptionBackground == .solid(palette.selectedOptionBackground))
            #expect(style.explanationBackground == .solid(palette.explanationBackground))
            #expect(style.bannerBackground(tone: LibraryPalette.warning) == .solid(palette.tinted(palette.warning)))
            #expect(style.bannerBackground(tone: LibraryPalette.critical) == .solid(palette.tinted(palette.critical)))
            #expect(palette.color(replacing: LibraryPalette.accentForeground) == palette.accent)
            #expect(palette.color(replacing: LibraryPalette.positive) == palette.positive)
            #expect(palette.color(replacing: LibraryPalette.accentFill) == nil)
        }
    }

    @Test("Đối chứng âm: màu của giao diện theo hệ thống đặt lên nền đọc khác độ sáng thì không đạt (lý do mỗi nền có bộ màu riêng)")
    func systemColorsFailOnOtherBackgrounds() {
        // Chữ phụ `.secondary` của giao diện tối (macOS tối) trên nền Giấy ngà, và của giao diện sáng trên nền Tối.
        let darkSecondary = ReadingBackground.system.palette(systemDark: true).secondaryText
        let lightSecondary = ReadingBackground.system.palette(systemDark: false).secondaryText
        #expect(LibraryPalette.contrast(darkSecondary, ReadingPalette.sepia.background) < Self.smallText)
        #expect(LibraryPalette.contrast(lightSecondary, ReadingPalette.dark.background) < Self.smallText)
        // Đỏ, xanh của giao diện sáng trên nền Tối; đỏ của giao diện tối trên nền Trắng.
        #expect(LibraryPalette.contrast(LibraryPalette.critical.light, ReadingPalette.dark.background) < Self.smallText)
        #expect(LibraryPalette.contrast(LibraryPalette.positive.light, ReadingPalette.dark.background) < Self.smallText)
        #expect(LibraryPalette.contrast(LibraryPalette.critical.dark, ReadingPalette.white.background) < Self.smallText)
        // Cam sáng của bảng màu chung trên lựa chọn đang chọn của Xám dịu (nền tối hơn): không đạt, nên Xám dịu có màu riêng.
        #expect(LibraryPalette.contrast(LibraryPalette.warning.light, ReadingPalette.softGray.selectedOptionBackground) < Self.smallText)
    }

    // MARK: - Nhớ lựa chọn, phạm vi

    /// `defaults` riêng của test (file tạm), như suite của chế độ cô lập trong UI test; không đụng `defaults` của app.
    private func temporaryDefaults() throws -> (UserDefaults, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingBackgroundTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (UserDefaults(suiteName: directory.appendingPathComponent("defaults.plist").path)!, directory)
    }

    /// Đọc môi trường của một view trong cây.
    private final class Probe {
        var style: ReadingStyle?
        var colorScheme: ColorScheme?
    }

    private struct ProbeView: View {
        let probe: Probe
        @Environment(\.readingStyle) private var style
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Color.clear
                .frame(width: 10, height: 10)
                .onAppear { record() }
                .onChange(of: style) { record() }
        }

        private func record() {
            probe.style = style
            probe.colorScheme = colorScheme
        }
    }

    @Test("Nền đọc đọc từ defaults của scene (defaultAppStorage), đổi theo khi giá trị lưu đổi; chỉ vùng nội dung đổi màu, ép giao diện theo độ sáng của nền")
    func surfaceReadsSceneDefaultsAndStaysInScope() async throws {
        let (defaults, directory) = try temporaryDefaults()
        defer { try? FileManager.default.removeItem(at: directory) }
        defaults.set(ReadingBackground.dark.rawValue, forKey: ReadingBackground.storageKey)
        let inside = Probe()
        let outside = Probe()
        let root = HStack {
            ProbeView(probe: outside)
            ProbeView(probe: inside)
                .readingSurface(systemTint: SessionStyle.accentForeground)
        }
        .defaultAppStorage(defaults)
        .environment(\.colorScheme, .light)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 80, height: 40), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        defer {
            window.contentView = nil
            window.close()
        }
        #expect(await waitFor { inside.style != nil && outside.style != nil })
        // Trong vùng: bộ màu Tối và giao diện tối dù cửa sổ sáng; ngoài vùng (bảng câu hỏi, thanh dưới): như hệ thống.
        #expect(inside.style == ReadingStyle(.dark))
        #expect(inside.colorScheme == .dark)
        #expect(outside.style == .system)
        #expect(outside.colorScheme == .light)

        // Đổi giá trị lưu (menu hoặc ô chọn của Trước khi thi ghi cùng khoá): vùng nội dung đổi theo.
        defaults.set(ReadingBackground.sepia.rawValue, forKey: ReadingBackground.storageKey)
        #expect(await waitFor { inside.style == ReadingStyle(.sepia) })
        #expect(inside.colorScheme == .light)
        // Theo hệ thống: không ép gì.
        defaults.set(ReadingBackground.system.rawValue, forKey: ReadingBackground.storageKey)
        #expect(await waitFor { inside.style == .system })
        #expect(inside.colorScheme == .light)
        #expect(outside.style == .system)
    }

    @Test("Sheet mở từ vùng nội dung (ảnh phóng to) vẽ như cửa sổ, không theo nền đọc")
    func sheetLeavesReadingSurface() async throws {
        let (defaults, directory) = try temporaryDefaults()
        defer { try? FileManager.default.removeItem(at: directory) }
        defaults.set(ReadingBackground.dark.rawValue, forKey: ReadingBackground.storageKey)
        let probe = Probe()
        let root = ProbeView(probe: probe)
            .leavingReadingSurface()
            .readingSurface(systemTint: SessionStyle.accentForeground)
            .defaultAppStorage(defaults)
            .environment(\.colorScheme, .light)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        defer {
            window.contentView = nil
            window.close()
        }
        #expect(await waitFor { probe.style != nil })
        #expect(probe.style == .system)
        #expect(probe.colorScheme == .light)
    }

    /// Chờ điều kiện (tối đa 3 giây) trên main actor, cho SwiftUI dựng và cập nhật view.
    private func waitFor(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 150 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }
}
