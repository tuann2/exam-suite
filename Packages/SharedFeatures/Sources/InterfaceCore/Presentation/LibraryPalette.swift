import Foundation

/// Bảng màu của Thư viện ở dạng số, để test kiểm độ tương phản (WCAG 2): chữ nhỏ ≥ 4,5:1, chữ lớn và
/// biểu tượng ≥ 3:1, ở cả giao diện sáng và tối (docs/product/library.md, mục Bàn phím và trợ năng; phương án 8).
/// Dùng chung cho cửa sổ làm bài (`SessionStyle`) và soạn đề (`AuthoringStyle`, cộng `AuthoringPalette`).
///
/// Mọi màu app tự định nghĩa (kể cả độ mờ của nền nhạt, viền) nằm ở đây hoặc `AuthoringPalette`, không viết số trong
/// view (docs/product/accessibility-localization.md, mục Dark Mode và tương phản; `scripts/check_colors.py`). Màu ngữ
/// nghĩa của hệ thống (`.primary`, `.secondary`, `.separator`, nền cửa sổ) không thuộc quy tắc 4,5:1 của app (Nt0 chốt
/// 2026-10-18): macOS tự chỉnh theo Dark Mode và Increase Contrast; chữ `.primary` đặt trên nền nhạt của app thì có test.
///
/// Màu nhấn teal `#017777` có hai vai:
/// - `accentFill`: nền nút có chữ trắng (nút mặc định của sheet). `#017777` ở cả hai giao diện: chữ trắng
///   5,38:1.
/// - `accentForeground`: chữ, biểu tượng, viền teal đặt trên nền (nhãn Đề mẫu, nút viền, viền chọn, dải chào
///   mừng). `#017777` trên nền sáng xám hoặc nền nhạt của nhãn chỉ 3,9–4,5:1, trên nền tối 2,3:1; nên giao
///   diện sáng dùng `#006666` (cùng màu, đậm hơn), giao diện tối dùng `#4FC9C9` (sáng hơn).
public enum LibraryPalette {
    public struct RGB: Hashable, Sendable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8

        public init(hex: UInt32) {
            red = UInt8((hex >> 16) & 0xFF)
            green = UInt8((hex >> 8) & 0xFF)
            blue = UInt8(hex & 0xFF)
        }

        /// Độ chói tương đối (WCAG 2).
        public var luminance: Double {
            func linear(_ channel: UInt8) -> Double {
                let value = Double(channel) / 255
                return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        /// Màu này phủ lên `background` với độ mờ `opacity` (nền nhạt của nhãn, của dải).
        public func blended(over background: RGB, opacity: Double) -> RGB {
            func mix(_ top: UInt8, _ bottom: UInt8) -> UInt32 {
                UInt32((Double(top) * opacity + Double(bottom) * (1 - opacity)).rounded())
            }
            return RGB(hex: mix(red, background.red) << 16 | mix(green, background.green) << 8 | mix(blue, background.blue))
        }
    }

    /// Một màu theo giao diện sáng/tối.
    public struct Pair: Hashable, Sendable {
        public let light: RGB
        public let dark: RGB

        public init(light: UInt32, dark: UInt32) {
            self.light = RGB(hex: light)
            self.dark = RGB(hex: dark)
        }

        public init(light: RGB, dark: RGB) {
            self.light = light
            self.dark = dark
        }

        /// Giá trị ở giao diện sáng (`dark == false`) hoặc tối.
        public func rgb(dark: Bool) -> RGB {
            dark ? self.dark : light
        }
    }

    /// Tỉ lệ tương phản WCAG 2 giữa hai màu.
    public static func contrast(_ lhs: RGB, _ rhs: RGB) -> Double {
        let (high, low) = lhs.luminance >= rhs.luminance ? (lhs.luminance, rhs.luminance) : (rhs.luminance, lhs.luminance)
        return (high + 0.05) / (low + 0.05)
    }

    public static let white = RGB(hex: 0xFFFFFF)

    /// Nền nút có chữ trắng: `#017777` ở cả hai giao diện.
    public static let accentFill = Pair(light: 0x017777, dark: 0x017777)
    /// Chữ, biểu tượng, viền teal trên nền.
    public static let accentForeground = Pair(light: 0x006666, dark: 0x4FC9C9)
    /// Trạng thái và kết quả, cho biểu tượng **và chữ** (luôn đi kèm chữ; chữ "Đúng", "Sai", "Đã đánh dấu", "Phần yếu
    /// nhất"… cũng mang màu này, nên phải đạt mức của chữ nhỏ 4,5:1). Màu hệ thống xanh/cam ở giao diện sáng chỉ khoảng
    /// 2,2:1 nên dùng sắc đậm hơn; giao diện tối dùng màu hệ thống, đỏ sáng hơn.
    ///
    /// Bước 8b (test tương phản trên nền của cả macOS 26 và macOS 15, review độc lập #54 S2): mức thấp nhất trên mọi nền và
    /// trên hàng lựa chọn đã chọn (nền nhạt teal trên nền cửa sổ `#FFFFFF`/`#ECECEC`, tối `#1E1E1E`/`#323232`):
    /// xanh sáng `#1E7B34` → `#196B2D` (3,80:1 → 4,70:1), cam sáng `#A35200` → `#934A00` (3,97:1 → 4,64:1), đỏ sáng
    /// `#C42B1C` → `#B22719` (4,03:1 → 4,68:1), đỏ tối `#FF6961` → `#FF918A` (3,50:1 → 4,69:1).
    public static let positive = Pair(light: 0x196B2D, dark: 0x30D158)
    public static let warning = Pair(light: 0x934A00, dark: 0xFF9F0A)
    public static let critical = Pair(light: 0xB22719, dark: 0xFF918A)

    /// Độ mờ của nền nhạt pha màu: nhãn Đề mẫu, dải thông báo (Thư viện, cửa sổ làm bài), hàng lựa chọn đã chọn.
    public static let tintedBackgroundOpacity = 0.12
    /// Độ mờ của nền nhạt khi kéo file vào cửa sổ Thư viện.
    public static let dropTargetOpacity = 0.08
    /// Độ mờ của viền dải thông báo của Thư viện (`BannerView`) và của cửa sổ làm bài (`SessionBannerView`).
    public static let libraryBannerBorderOpacity = 0.35
    public static let sessionBannerBorderOpacity = 0.4
    /// Độ mờ của viền tiêu điểm quanh vùng câu hỏi (cửa sổ làm bài).
    public static let focusRingOpacity = 0.6
    /// Nền nhạt trung tính (`.quaternary` của hệ thống với độ mờ này): khung giải thích, ô số của Rà soát.
    public static let explanationFillOpacity = 0.5
    public static let statFillOpacity = 0.4

    /// Nền mà các màu trên phải đọc được: nền cửa sổ, nền thẻ, nền nhóm của macOS (đo trên ảnh kết xuất và
    /// theo màu hệ thống), của macOS 26 và macOS 15 (`#323232`: nền cửa sổ tối của macOS 15).
    public static let lightBackgrounds = [0xFFFFFF, 0xF7F7F7, 0xECECEC].map(RGB.init(hex:))
    public static let darkBackgrounds = [0x1E1E1E, 0x282828, 0x323232, 0x343434, 0x3A3A3A].map(RGB.init(hex:))
    /// Nền cửa sổ (`windowBackgroundColor`) của các bản macOS app chạy: macOS 26 `#FFFFFF`/`#1E1E1E`, macOS 15 khoảng
    /// `#ECECEC`/`#323232`. Test tính nền nhạt trên các nền này cộng nền đọc lúc chạy, nên không phụ thuộc máy chạy test.
    public static let lightWindowBackgrounds = [0xFFFFFF, 0xECECEC].map(RGB.init(hex:))
    public static let darkWindowBackgrounds = [0x1E1E1E, 0x323232].map(RGB.init(hex:))
}
