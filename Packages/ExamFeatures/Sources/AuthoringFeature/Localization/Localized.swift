import Foundation
import LibraryFeature

/// Chữ giao diện của AuthoringFeature: tra `Resources/Localizable.xcstrings` của target này (bundle của module), không tra
/// bundle chính của app. Dùng cho API chỉ nhận chuỗi (`Button`, `Label`, `.help`, `NSAlert`…) và chuỗi của model
/// trình bày; `Text` viết `Text("…", bundle: .module)`. Trình biên dịch vẫn trích literal (kể cả nội suy `%lld`, `%@`)
/// vào catalog qua tham số `String.LocalizationValue`. Quy ước: AGENTS.md, mục "Chuỗi giao diện".
func localized(_ key: String.LocalizationValue) -> String {
    InterfaceStrings.resolve(key, bundle: ModuleStrings.bundle)
}

/// Bundle tài nguyên của AuthoringFeature (catalog đã biên dịch). Test tra khoá theo ngôn ngữ cố định qua
/// `AuthoringFeature.ModuleStrings.bundle` (tên module đi trước vì mỗi target có một kiểu cùng tên).
enum ModuleStrings {
    static let bundle = Bundle.module
}

/// Như `localized(_:)`, nhưng tra theo ngôn ngữ cố định `locale` khi có (`nil`: theo ngôn ngữ giao diện, như
/// `localized(_:)`). Dùng cho chữ app tạo ra mà test cần kiểm ở một ngôn ngữ biết trước (tên mặc định ghi vào đề,
/// `DefaultContentNames.interface(locale:)`).
func localized(_ key: String.LocalizationValue, locale: Locale?) -> String {
    guard let locale else { return localized(key) }
    return InterfaceStrings.resolve(key, bundle: ModuleStrings.bundle, locale: locale)
}
