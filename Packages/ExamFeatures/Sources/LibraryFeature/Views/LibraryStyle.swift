import AppKit
import SwiftUI

/// Màu và kích thước dùng chung của Thư viện (docs/product/library.md, mục Cửa sổ).
enum LibraryStyle {
    /// Màu nhấn teal `#017777` làm nền nút có chữ trắng (nút mặc định của sheet), cả hai giao diện.
    static let accent = LibraryPalette.accentFill.color(name: "LibraryAccentFill")
    /// Teal cho chữ, biểu tượng, viền trên nền; cũng là `tint` của cửa sổ Thư viện (nút viền, viền chọn).
    static let accentForeground = LibraryPalette.accentForeground.color(name: "LibraryAccentForeground")
    static let positive = LibraryPalette.positive.color(name: "LibraryPositive")
    static let warning = LibraryPalette.warning.color(name: "LibraryWarning")
    static let critical = LibraryPalette.critical.color(name: "LibraryCritical")

    /// Bề rộng tối thiểu của một thẻ trong lưới.
    static let cardMinWidth: CGFloat = 270
    static let gridSpacing: CGFloat = 16
    static let gridPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 10
    /// Kích thước tối thiểu của cửa sổ Thư viện.
    static let minWindowSize = CGSize(width: 960, height: 640)
    /// Độ rộng tối thiểu của chữ trong dải thông báo (`BannerView`): chặn cỡ nhỏ nhất của dải cao vô lý.
    static let bannerTextMinWidth: CGFloat = 320
}

extension EntryStatusPresentation.Tone {
    var color: Color {
        switch self {
        case .positive: LibraryStyle.positive
        case .neutral: .secondary
        case .warning: LibraryStyle.warning
        case .critical: LibraryStyle.critical
        }
    }
}

/// Trạng thái của đề: biểu tượng + chữ (không chỉ dựa vào màu).
struct StatusLabel: View {
    let presentation: EntryStatusPresentation

    var body: some View {
        Label {
            Text(presentation.title)
        } icon: {
            Image(systemName: presentation.systemImage)
                .paletteForeground(presentation.tone.color)
        }
    }
}

/// Kết quả đậu/trượt: biểu tượng + chữ.
struct ResultLabel: View {
    let passed: Bool

    var body: some View {
        Label {
            Text(LibraryFormat.result(passed: passed))
        } icon: {
            Image(systemName: LibraryFormat.resultSymbol(passed: passed))
                .paletteForeground(passed ? LibraryStyle.positive : LibraryStyle.critical)
        }
    }
}

/// Nhãn "Đề mẫu".
struct SampleBadge: View {
    var body: some View {
        Text("Đề mẫu", bundle: .module)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .paletteForeground(LibraryStyle.accentForeground)
            .adaptiveBackground(.tint(LibraryPalette.accentForeground, opacity: LibraryPalette.tintedBackgroundOpacity), in: Capsule())
            .accessibilityLabel(Text("Đề mẫu", bundle: .module))
    }
}
