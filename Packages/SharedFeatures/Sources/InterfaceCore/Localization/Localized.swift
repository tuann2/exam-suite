import Foundation

/// Chữ giao diện của InterfaceCore: tra `Resources/Localizable.xcstrings` của target này (bundle của module), không tra
/// bundle chính của app. Dùng cho API chỉ nhận chuỗi (`Button`, `Label`, `.help`, `NSAlert`…) và chuỗi của model
/// trình bày; `Text` viết `Text("…", bundle: .module)`. Trình biên dịch vẫn trích literal (kể cả nội suy `%lld`, `%@`)
/// vào catalog qua tham số `String.LocalizationValue`. Quy ước: AGENTS.md, mục "Chuỗi giao diện".
func localized(_ key: String.LocalizationValue) -> String {
    InterfaceStrings.resolve(key, bundle: ModuleStrings.bundle)
}

/// Bundle tài nguyên của InterfaceCore (catalog đã biên dịch). Test tra khoá theo ngôn ngữ cố định qua
/// `InterfaceCore.ModuleStrings.bundle` (tên module đi trước vì mỗi target có một kiểu cùng tên).
enum ModuleStrings {
    static let bundle = Bundle.module
}
