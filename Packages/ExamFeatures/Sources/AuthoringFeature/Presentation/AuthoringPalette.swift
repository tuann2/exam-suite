import Foundation
import InterfaceCore

/// Màu nhấn burgundy của Soạn đề (`#801638`, docs/product/library.md mục Cửa sổ; authoring.md mục Cửa sổ), ở dạng
/// số để test kiểm độ tương phản như `LibraryPalette` (phương án 8 của library.md: chữ nhỏ ≥ 4,5:1, biểu tượng
/// ≥ 3:1, ở cả giao diện sáng và tối). Màu đỏ/cam của lỗi, cảnh báo dùng chung `LibraryPalette`.
///
/// - `accentFill`: nền nút có chữ trắng và nền dòng đang chọn của cây đề, `#801638` ở cả hai giao diện (chữ trắng
///   khoảng 10:1).
/// - `accentForeground`: chữ, biểu tượng, viền burgundy đặt trên nền. Giao diện sáng giữ `#801638`; giao diện tối
///   dùng `#F7A1B8` (cùng sắc, sáng hơn) vì `#801638` trên nền tối chỉ khoảng 1,7:1. Không dùng làm nền có chữ trắng
///   (`#F7A1B8` với chữ trắng chỉ ~1,9:1).
public enum AuthoringPalette {
    public typealias RGB = LibraryPalette.RGB

    public static let accentFill = LibraryPalette.Pair(light: 0x801638, dark: 0x801638)
    public static let accentForeground = LibraryPalette.Pair(light: 0x801638, dark: 0xF7A1B8)

    public static var accentFillLight: RGB { accentFill.light }
    public static var accentFillDark: RGB { accentFill.dark }
    public static var accentForegroundLight: RGB { accentForeground.light }
    public static var accentForegroundDark: RGB { accentForeground.dark }
}
