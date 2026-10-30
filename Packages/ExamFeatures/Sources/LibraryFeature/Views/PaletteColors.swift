import AppKit
import InterfaceCore
import SwiftUI

// Màu của bảng màu (`LibraryPalette`, `AuthoringPalette`) thành màu SwiftUI theo giao diện sáng/tối, nền có độ trong của app
// theo Reduce Transparency, và màu của bảng trên dòng đang chọn (docs/product/accessibility-localization.md, mục Dark Mode
// và tương phản). Dùng chung cho Thư viện, cửa sổ làm bài và soạn đề.

extension LibraryPalette.RGB {
    /// Màu sRGB của AppKit.
    public var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}

extension LibraryPalette.Pair {
    /// Màu SwiftUI theo giao diện sáng/tối của view, dựng từ giá trị số (độ tương phản có test). `name` chỉ để gỡ lỗi.
    public func color(name: String) -> Color {
        let pair = self
        return Color(nsColor: NSColor(name: name) { appearance in
            pair.rgb(dark: LibraryPalette.isDark(appearance)).nsColor
        })
    }
}

extension LibraryPalette {
    /// Giao diện tối (`darkAqua` và các biến thể của nó, kể cả độ tương phản cao).
    public static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// Màu của hệ thống ở giao diện sáng hoặc tối, trong sRGB: giá trị và độ mờ (chữ `.primary` là `labelColor` với độ mờ
    /// 0,85).
    public static func systemColor(_ color: NSColor, dark: Bool) -> (rgb: RGB, alpha: Double) {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
        return systemColor(color, in: appearance)
    }

    static func systemColor(_ color: NSColor, in appearance: NSAppearance) -> (rgb: RGB, alpha: Double) {
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB)
        }
        guard let resolved else { return (RGB(hex: 0), 1) }
        func channel(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
        let hex = channel(resolved.redComponent) << 16 | channel(resolved.greenComponent) << 8 | channel(resolved.blueComponent)
        return (RGB(hex: hex), Double(resolved.alphaComponent))
    }

    /// Nền cửa sổ thật của macOS (`windowBackgroundColor`, đặc) ở giao diện sáng hoặc tối, đọc lúc chạy: nền của vùng câu
    /// hỏi, Kết quả, Xem lại, vùng nội dung Thư viện. Test tương phản tính nền nhạt pha màu trên nền này.
    public static func windowBackground(dark: Bool) -> RGB {
        systemColor(.windowBackgroundColor, dark: dark).rgb
    }

    /// Nền cửa sổ của macOS 26 và macOS 15 cộng nền cửa sổ thật đọc lúc chạy.
    public static func windowBackgrounds(dark: Bool) -> [RGB] {
        let listed = dark ? darkWindowBackgrounds : lightWindowBackgrounds
        let window = windowBackground(dark: dark)
        return listed.contains(window) ? listed : listed + [window]
    }

    /// Mọi nền mà màu của bảng phải đọc được ở một giao diện: các nền đo được (`lightBackgrounds`/`darkBackgrounds`) cộng
    /// nền cửa sổ thật.
    public static func backgrounds(dark: Bool) -> [RGB] {
        let listed = dark ? darkBackgrounds : lightBackgrounds
        let window = windowBackground(dark: dark)
        return listed.contains(window) ? listed : listed + [window]
    }

    /// Màu đặc bằng `top` (độ mờ `alpha`) phủ lên `background`.
    public static func flatten(_ top: RGB, alpha: Double, over background: RGB) -> RGB {
        top.blended(over: background, opacity: min(max(alpha, 0), 1))
    }
}

// MARK: - Nền có độ trong và Reduce Transparency

/// Nền có độ trong mà app tự đặt (docs/product/accessibility-localization.md: "Reduce Transparency (nền mờ thay bằng nền
/// đặc)"). Bình thường giữ kiểu nền cũ; khi bật Reduce Transparency của macOS (`accessibilityReduceTransparency`) thì
/// thay bằng **màu đặc** cùng sắc: nền nhạt pha màu và nền trung tính thành màu đã trộn sẵn trên nền cửa sổ thật (chính màu
/// test tương phản tính), `.bar` và vật liệu thành nền cửa sổ.
public enum AdaptiveBackground: Hashable, Sendable {
    /// Màu của bảng với độ mờ `opacity` (dải thông báo, nhãn Đề mẫu, hàng lựa chọn đã chọn, lớp phủ kéo thả).
    case tint(LibraryPalette.Pair, opacity: Double)
    /// `.quaternary` của hệ thống với độ mờ `opacity` (khung giải thích, ô số của Rà soát, rãnh thanh điểm).
    case neutral(opacity: Double)
    /// Vật liệu `.bar` (thanh dưới cây đề, thanh lỗi, báo cáo import, tiêu đề phần của bảng câu hỏi).
    case bar
    /// Vật liệu `.regularMaterial` (thông báo ở chân Thư viện, nhãn của lớp phủ kéo thả).
    case material

    /// Kiểu nền: kiểu gốc (có độ trong), hoặc màu đặc khi `reduceTransparency`.
    public func style(reduceTransparency: Bool) -> AnyShapeStyle {
        if reduceTransparency { return AnyShapeStyle(Color(nsColor: solidColor)) }
        switch self {
        case let .tint(pair, opacity):
            return AnyShapeStyle(pair.color(name: "AdaptiveTint").opacity(opacity))
        case let .neutral(opacity):
            return AnyShapeStyle(HierarchicalShapeStyle.quaternary.opacity(opacity))
        case .bar:
            return AnyShapeStyle(Material.bar)
        case .material:
            return AnyShapeStyle(Material.regular)
        }
    }

    /// Màu đặc dùng khi bật Reduce Transparency, theo giao diện sáng/tối (độ mờ luôn 1).
    public var solidColor: NSColor {
        let background = self
        return NSColor(name: "AdaptiveBackgroundSolid") { appearance in
            background.solidRGB(dark: LibraryPalette.isDark(appearance)).nsColor
        }
    }

    /// Giá trị của `solidColor` ở giao diện sáng hoặc tối (test tương phản dùng đúng giá trị này).
    public func solidRGB(dark: Bool) -> LibraryPalette.RGB {
        let window = LibraryPalette.windowBackground(dark: dark)
        switch self {
        case let .tint(pair, opacity):
            return LibraryPalette.flatten(pair.rgb(dark: dark), alpha: opacity, over: window)
        case let .neutral(opacity):
            let quaternary = LibraryPalette.systemColor(.quaternaryLabelColor, dark: dark)
            return LibraryPalette.flatten(quaternary.rgb, alpha: quaternary.alpha * opacity, over: window)
        case .bar, .material:
            return window
        }
    }
}

private struct AdaptiveBackgroundModifier<S: Shape>: ViewModifier {
    let background: AdaptiveBackground
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background(background.style(reduceTransparency: reduceTransparency), in: shape)
    }
}

/// Hình được tô bằng nền có độ trong của app (ví dụ rãnh của thanh điểm), theo Reduce Transparency.
public struct AdaptiveFill<S: Shape>: View {
    private let background: AdaptiveBackground
    private let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(_ background: AdaptiveBackground, in shape: S) {
        self.background = background
        self.shape = shape
    }

    public var body: some View {
        shape.fill(background.style(reduceTransparency: reduceTransparency))
    }
}

extension View {
    /// Nền có độ trong của app trong `shape`; bật Reduce Transparency thì thành nền đặc (`AdaptiveBackground`).
    public func adaptiveBackground<S: Shape>(_ background: AdaptiveBackground, in shape: S) -> some View {
        modifier(AdaptiveBackgroundModifier(background: background, shape: shape))
    }

    /// Nền có độ trong của app phủ hết khung của view.
    public func adaptiveBackground(_ background: AdaptiveBackground) -> some View {
        modifier(AdaptiveBackgroundModifier(background: background, shape: Rectangle()))
    }
}

// MARK: - Màu của bảng trên dòng đang chọn

/// Chữ/biểu tượng mang màu của bảng trong dòng có thể chọn (danh sách, bảng): trên nền chọn đậm (dòng đang chọn khi danh
/// sách có tiêu điểm, `backgroundProminence == .increased`, nền teal/burgundy với chữ trắng) màu của bảng không đạt tương
/// phản (xanh `#1C7631` trên `#017777` ~1:1), nên dùng màu chữ của hệ thống (`.primary`, macOS vẽ trắng trên nền đó).
public enum PaletteForeground: Equatable, Sendable {
    /// Màu của bảng.
    case palette
    /// Màu chữ của hệ thống theo nền.
    case system

    public static func resolve(prominence: BackgroundProminence) -> PaletteForeground {
        prominence == .increased ? .system : .palette
    }
}

private struct PaletteForegroundModifier: ViewModifier {
    let color: Color

    @Environment(\.backgroundProminence) private var prominence

    func body(content: Content) -> some View {
        switch PaletteForeground.resolve(prominence: prominence) {
        case .palette: content.foregroundStyle(color)
        case .system: content.foregroundStyle(.primary)
        }
    }
}

extension View {
    /// `foregroundStyle(color)` cho màu của bảng, trừ trên nền chọn đậm (`PaletteForeground`).
    public func paletteForeground(_ color: Color) -> some View {
        modifier(PaletteForegroundModifier(color: color))
    }
}
