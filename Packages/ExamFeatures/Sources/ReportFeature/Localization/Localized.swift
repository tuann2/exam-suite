import Foundation
import LibraryFeature

/// Chữ giao diện của ReportFeature (nhãn của PDF/In, tiến độ, tên file gợi ý): tra `Resources/Localizable.xcstrings`
/// của target này (bundle của module), không tra bundle chính của app. Chữ vẽ vào PDF cũng đi qua đây, nên PDF theo
/// ngôn ngữ giao diện của app (export-print.md, Ngôn ngữ nhãn). Trình biên dịch vẫn trích literal (kể cả nội suy
/// `%lld`, `%@`) vào catalog qua tham số `String.LocalizationValue`. Quy ước: AGENTS.md, mục "Chuỗi giao diện".
func localized(_ key: String.LocalizationValue) -> String {
    InterfaceStrings.resolve(key, bundle: ModuleStrings.bundle)
}

/// Bundle tài nguyên của ReportFeature (catalog đã biên dịch). Test tra khoá theo ngôn ngữ cố định qua
/// `ReportFeature.ModuleStrings.bundle` (tên module đi trước vì mỗi target có một kiểu cùng tên).
enum ModuleStrings {
    static let bundle = Bundle.module
}
