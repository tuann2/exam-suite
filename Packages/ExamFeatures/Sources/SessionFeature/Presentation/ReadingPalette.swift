import AppKit
import InterfaceCore
import LibraryFeature

/// **Nền đọc** của vùng nội dung câu (docs/product/accessibility-localization.md, mục Dark Mode và tương phản; plan giai đoạn
/// 6, bước 1): năm nền có sẵn, một lựa chọn cho cả app, nhớ trong `defaults` của app như cỡ chữ nội dung.
///
/// - **Theo hệ thống** (mặc định): vùng nội dung câu vẽ như trước, theo sáng/tối của macOS (màu ngữ nghĩa của hệ thống và
///   màu sáng/tối của `LibraryPalette`).
/// - **Trắng**, **Giấy ngà**, **Xám dịu**, **Tối**: bộ màu cố định (`ReadingPalette`), **giữ nguyên khi macOS đổi sáng/tối**
///   (như app Sách); mọi màu của vùng nội dung câu lấy từ bộ màu của nền, không dùng màu ngữ nghĩa của hệ thống.
public enum ReadingBackground: String, CaseIterable, Identifiable, Sendable {
    case system
    case white
    case sepia
    case softGray
    case dark

    /// Khoá `@AppStorage` (một lựa chọn cho cả app; `defaults` của bản app, UI test: suite trong thư mục tạm,
    /// `AppLaunchStorage`), cạnh `content.zoomPercent` của cỡ chữ nội dung.
    public static let storageKey = "content.readingBackground"

    /// Giá trị lưu không hợp lệ (sửa tay, bản sau đổi nền) thì về **Theo hệ thống**.
    public init(storedValue: String) {
        self = ReadingBackground(rawValue: storedValue) ?? .system
    }

    public var id: String { rawValue }

    /// Bộ màu cố định của nền; `nil` với **Theo hệ thống** (màu theo sáng/tối của macOS).
    public var fixedPalette: ReadingPalette? {
        switch self {
        case .system: nil
        case .white: .white
        case .sepia: .sepia
        case .softGray: .softGray
        case .dark: .dark
        }
    }

    /// Bộ màu mà vùng nội dung câu thật sự dùng khi macOS ở giao diện sáng (`systemDark == false`) hoặc tối. Nền cố định
    /// cho cùng một bộ ở cả hai giao diện; **Theo hệ thống** cho bộ màu dựng từ màu của macOS lúc chạy (nền cửa sổ, chữ
    /// `.primary`/`.secondary`, viền) và màu sáng/tối của `LibraryPalette`, đúng như cửa sổ làm bài vẽ (test tương phản, mẫu
    /// màu của ô chọn).
    public func palette(systemDark: Bool) -> ReadingPalette {
        fixedPalette ?? ReadingPalette.system(dark: systemDark)
    }
}

/// Bộ màu của một nền đọc ở dạng số (độ tương phản có test: `ReadingBackgroundTests`): nền, chữ, chữ phụ, viền, màu nhấn
/// teal (viền và dấu của lựa chọn đang chọn, gợi ý "Chọn N đáp án", "Bạn chọn"), màu Đúng/Sai/đánh dấu đặt trên nền đó, nền
/// khung giải thích. Nền của lựa chọn đang chọn và của dòng báo (Xem lại bài) là màu đó pha lên nền với độ mờ
/// `LibraryPalette.tintedBackgroundOpacity`, trộn sẵn thành màu đặc (không có độ trong, nên Reduce Transparency không đổi gì).
///
/// Quy tắc (phương án 8 của library.md): chữ nhỏ ≥ 4,5:1, biểu tượng và chữ lớn ≥ 3:1 trên mọi nền mà chữ đặt lên (nền,
/// lựa chọn đang chọn, khung giải thích, dòng báo); màu Đúng/Sai/đánh dấu và teal làm chữ nhỏ nên phải đạt 4,5:1.
public struct ReadingPalette: Hashable, Sendable {
    public typealias RGB = LibraryPalette.RGB

    public let background: RGB
    public let text: RGB
    public let secondaryText: RGB
    /// Viền của lựa chọn chưa chọn và của ảnh (trang trí, như `.separator`; dấu của lựa chọn mang màu chữ phụ).
    public let border: RGB
    public let accent: RGB
    public let positive: RGB
    public let critical: RGB
    public let warning: RGB
    public let explanationBackground: RGB
    /// Nền tối (chữ sáng): thanh cuộn và chữ được chọn của vùng nội dung vẽ theo giao diện tối.
    public let isDark: Bool

    public init(
        background: RGB, text: RGB, secondaryText: RGB, border: RGB, accent: RGB,
        positive: RGB, critical: RGB, warning: RGB, explanationBackground: RGB, isDark: Bool
    ) {
        self.background = background
        self.text = text
        self.secondaryText = secondaryText
        self.border = border
        self.accent = accent
        self.positive = positive
        self.critical = critical
        self.warning = warning
        self.explanationBackground = explanationBackground
        self.isDark = isDark
    }

    init(
        background: UInt32, text: UInt32, secondaryText: UInt32, border: UInt32, accent: UInt32,
        positive: UInt32, critical: UInt32, warning: UInt32, explanationBackground: UInt32, isDark: Bool
    ) {
        self.init(
            background: RGB(hex: background), text: RGB(hex: text), secondaryText: RGB(hex: secondaryText),
            border: RGB(hex: border), accent: RGB(hex: accent), positive: RGB(hex: positive), critical: RGB(hex: critical),
            warning: RGB(hex: warning), explanationBackground: RGB(hex: explanationBackground), isDark: isDark
        )
    }

    /// Nền của lựa chọn đang chọn: teal pha lên nền (như hàng đã chọn của giao diện theo hệ thống).
    public var selectedOptionBackground: RGB {
        tinted(accent)
    }

    /// Nền của dòng báo (Xem lại bài: "đã sửa sau lần thi") có màu `tone` pha lên nền.
    public func tinted(_ tone: RGB) -> RGB {
        LibraryPalette.flatten(tone, alpha: LibraryPalette.tintedBackgroundOpacity, over: background)
    }

    /// Màu của nền đọc thay cho màu sáng/tối `pair` của bảng màu (teal, xanh, cam, đỏ); màu khác thì `nil`.
    public func color(replacing pair: LibraryPalette.Pair) -> RGB? {
        switch pair {
        case LibraryPalette.accentForeground: accent
        case LibraryPalette.positive: positive
        case LibraryPalette.critical: critical
        case LibraryPalette.warning: warning
        default: nil
        }
    }

    // MARK: - Bốn nền cố định

    /// **Trắng**: nền trắng, chữ gần đen; màu Đúng/Sai/đánh dấu và teal như giao diện sáng của `LibraryPalette`.
    public static let white = ReadingPalette(
        background: 0xFFFFFF, text: 0x1D1D1F, secondaryText: 0x5C5C61, border: 0xC7C7CC, accent: 0x006666,
        positive: 0x196B2D, critical: 0xB22719, warning: 0x934A00, explanationBackground: 0xF0F0F2, isDark: false
    )

    /// **Giấy ngà**: nền ngà tông ấm, chữ nâu đậm; teal, xanh, đỏ, cam đậm hơn một chút cho nền ấm.
    public static let sepia = ReadingPalette(
        background: 0xF7F0E1, text: 0x3A2E22, secondaryText: 0x67563F, border: 0xD3C5A8, accent: 0x005A5A,
        positive: 0x17602A, critical: 0x9E2418, warning: 0x7F4000, explanationBackground: 0xEDE3CC, isDark: false
    )

    /// **Xám dịu**: nền xám trung tính tối hơn Trắng (bớt chói), chữ gần đen; màu đậm hơn cho nền xám.
    public static let softGray = ReadingPalette(
        background: 0xD8D8D6, text: 0x1F1F1F, secondaryText: 0x464646, border: 0xA9A9A6, accent: 0x004D4D,
        positive: 0x135524, critical: 0x8A1D13, warning: 0x6B3600, explanationBackground: 0xCACAC7, isDark: false
    )

    /// **Tối**: nền tối như cửa sổ tối của macOS 26, chữ sáng; teal, xanh, đỏ, cam như giao diện tối của `LibraryPalette`.
    public static let dark = ReadingPalette(
        background: 0x1E1E1E, text: 0xE6E6E6, secondaryText: 0xA6A6AB, border: 0x4A4A4D, accent: 0x4FC9C9,
        positive: 0x30D158, critical: 0xFF918A, warning: 0xFF9F0A, explanationBackground: 0x2C2C2E, isDark: true
    )

    // MARK: - Theo hệ thống

    /// Bộ màu của **Theo hệ thống** ở giao diện sáng hoặc tối, dựng từ màu của macOS đọc lúc chạy: nền cửa sổ thật, chữ
    /// `.primary` (`labelColor`), chữ phụ `.secondary`, viền `.separator` (trộn lên nền), nền trung tính của khung giải thích
    /// (`SessionStyle.explanationBackground`), và màu sáng/tối của `LibraryPalette`. Chữ phụ và viền là màu ngữ nghĩa của
    /// hệ thống, được miễn quy tắc 4,5:1 của app (Nt0 chốt 2026-10-18); vùng nội dung câu vẫn vẽ bằng màu ngữ nghĩa (theo
    /// Increase Contrast).
    public static func system(dark: Bool) -> ReadingPalette {
        let window = LibraryPalette.windowBackground(dark: dark)
        func flattened(_ color: NSColor) -> RGB {
            let system = LibraryPalette.systemColor(color, dark: dark)
            return LibraryPalette.flatten(system.rgb, alpha: system.alpha, over: window)
        }
        let quaternary = LibraryPalette.systemColor(.quaternaryLabelColor, dark: dark)
        return ReadingPalette(
            background: window,
            text: flattened(.labelColor),
            secondaryText: flattened(.secondaryLabelColor),
            border: flattened(.separatorColor),
            accent: LibraryPalette.accentForeground.rgb(dark: dark),
            positive: LibraryPalette.positive.rgb(dark: dark),
            critical: LibraryPalette.critical.rgb(dark: dark),
            warning: LibraryPalette.warning.rgb(dark: dark),
            explanationBackground: LibraryPalette.flatten(
                quaternary.rgb, alpha: quaternary.alpha * LibraryPalette.explanationFillOpacity, over: window
            ),
            isDark: dark
        )
    }
}
