import InterfaceCore
import SwiftUI
import UIKit

// Màu của bảng màu số (`LibraryPalette`, cặp sáng/tối đã có test tương phản) thành màu SwiftUI của bản iOS, theo giao
// diện sáng/tối của hệ thống (docs/product/accessibility-localization.md, mục Dark Mode và tương phản). File bảng màu
// của bản iOS: màu tự định nghĩa chỉ dựng ở đây (scripts/check_colors.py).

extension LibraryPalette.Pair {
    /// Màu SwiftUI theo giao diện sáng/tối của view.
    var color: Color {
        let pair = self
        return Color(uiColor: UIColor { traits in
            let rgb = pair.rgb(dark: traits.userInterfaceStyle == .dark)
            return UIColor(
                red: CGFloat(rgb.red) / 255,
                green: CGFloat(rgb.green) / 255,
                blue: CGFloat(rgb.blue) / 255,
                alpha: 1
            )
        })
    }
}

/// Tiêu đề một nhóm của danh sách/form, đặt làm dòng đầu của nhóm: chữ chính, cỡ theo Dynamic Type (header của nhóm
/// trong `List` iOS bị ép chữ phụ của hệ thống, không đạt 4,5:1, và không phóng to hết cỡ).
struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Màu dùng trên màn iPhone.
enum MobilePalette {
    /// Màu nhấn (nút, lựa chọn đang chọn): teal của app.
    static var accent: Color { LibraryPalette.accentForeground.color }
    static var positive: Color { LibraryPalette.positive.color }
    static var warning: Color { LibraryPalette.warning.color }
    static var critical: Color { LibraryPalette.critical.color }

    /// Màu của một sắc thái trạng thái file (`EntryStatusPresentation.Tone`).
    static func color(_ tone: EntryStatusPresentation.Tone) -> Color {
        switch tone {
        case .positive: positive
        case .warning: warning
        case .critical: critical
        case .neutral: secondaryText
        }
    }

    /// Chữ phụ (mô tả, ngày, số liệu nhỏ): chữ chính của hệ thống mờ 75%, ≥ 4,5:1 trên nền sáng/tối và nền nhóm của
    /// iOS (màu `.secondary` của hệ thống chỉ khoảng 3,5:1 với chữ nhỏ; kiểm trợ năng của UI test đo trên màn thật).
    static var secondaryText: Color { Color.primary.opacity(0.75) }

    /// Nền đặc của thanh nút dưới màn và thông báo: không dùng vật liệu trong mờ (nội dung cuộn phía sau làm chữ trên
    /// thanh mất tương phản).
    static var barBackground: Color { Color(uiColor: .systemBackground) }

    /// Nền nhạt pha màu của dải thông báo (cùng độ mờ với bản macOS).
    static func tint(_ color: Color) -> Color {
        color.opacity(LibraryPalette.tintedBackgroundOpacity)
    }
}

extension View {
    /// Vùng cuộn nằm ngay trên thanh nút nền đặc (`MobilePalette.barBackground`): tắt hiệu ứng mờ dần ở mép dưới của
    /// iOS 26. Thanh đã tách khỏi nội dung bằng nền đặc và đường kẻ; hiệu ứng chỉ làm nhạt chữ sát thanh (kiểm tương
    /// phản của UI test báo ở tiêu đề nhóm của Rà soát khoá).
    @ViewBuilder
    func solidBottomEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            self
        }
    }
}
