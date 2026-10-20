import Foundation
@testable import LibraryFeature

/// Chữ của `key` trong catalog của LibraryFeature, khoá ngôn ngữ `language` bằng `LocalizedStringResource.locale`
/// (spike giai đoạn 5: tham số `locale` của `String(localized:bundle:locale:)` không chọn ngôn ngữ, và `swift test`
/// chọn `en` khi catalog có `en`).
func catalogText(_ key: String.LocalizationValue, language: String) -> String {
    InterfaceStrings.resolve(key, bundle: LibraryFeature.ModuleStrings.bundle, locale: Locale(identifier: language))
}
