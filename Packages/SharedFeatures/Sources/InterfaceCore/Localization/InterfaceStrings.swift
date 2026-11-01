import Foundation
import Synchronization

/// Tra chữ giao diện trong String Catalog của một module (docs/product/accessibility-localization.md, mục Ngôn ngữ).
///
/// Mỗi target có chữ giao diện có `Resources/Localizable.xcstrings` (tiếng Việt là ngôn ngữ nguồn: khoá chính là chữ
/// tiếng Việt) và một hàm `localized(_:)` nội bộ gọi `resolve(_:bundle: .module)`. Quy ước và cách kiểm ở AGENTS.md,
/// mục "Chuỗi giao diện"; `scripts/check_localization.py` bắt chỗ quên chỉ bundle (quên thì chữ tra bundle chính của
/// app, không có lỗi hay cảnh báo).
public enum InterfaceStrings {
    /// Ngôn ngữ khoá cứng khi tiến trình không phải app của Exam Suite.
    ///
    /// Trong app, bundle chính có `vi.lproj` và `en.lproj` (`InfoPlist.xcstrings`), nên giá trị là `nil`: chữ theo
    /// ngôn ngữ mà bundle chính chọn từ ngôn ngữ của macOS (phương án 1). Bundle chính không khai báo `vi` (trình chạy
    /// `swift test`, công cụ dòng lệnh) thì macOS luôn chọn `en` khi catalog có `en` (spike giai đoạn 5,
    /// docs/notes/g5-spike-pdf-l10n.md); ở đó dùng ngôn ngữ nguồn `vi`, như quy tắc "không có ngôn ngữ nào khớp thì
    /// tiếng Việt" của phương án 1, để test so chữ tiếng Việt không đổi kết quả khi catalog có bản tiếng Anh.
    public static let pinnedLocale: Locale? =
        Bundle.main.localizations.contains("vi") ? nil : Locale(identifier: "vi")

    /// **Chỉ cho test**: ngôn ngữ tra chữ của mọi `localized(_:)` (và `InterfaceLocale.current`) trong phạm vi một task
    /// (`InterfaceStrings.$languageOverride.withValue(Locale(identifier: "en")) { … }`), thắng `pinnedLocale`. Để kiểm cả
    /// một luồng (model trình bày → PDF) ở tiếng Anh trong `swift test`, nơi ngôn ngữ đã khoá `vi`. App không đặt: luôn
    /// `nil`. Số nội suy định dạng theo chính locale này (như mọi đường tra có `locale`). Chỉ đặt ở file này và ở test
    /// (`scripts/check_localization.py`, luật `test-hook`).
    @TaskLocal static var languageOverride: Locale?

    /// **Chỉ cho test, cả tiến trình**: như `languageOverride` nhưng không theo task, cho snapshot tiếng Anh (SwiftUI dựng
    /// lại view cả ngoài task của test, nơi task-local không còn). Chỉ đặt trong suite chạy tuần tự rồi trả về `nil`.
    /// App không đặt.
    ///
    /// Đọc/ghi qua khoá (`Mutex`, review độc lập #52): chữ có thể được tra trên luồng nền (khối của PDF đề dựng ngoài
    /// main actor, `Task.detached`) đúng lúc test đặt hoặc trả giá trị, nên không để biến dùng chung không khoá. Trong app
    /// khoá không bao giờ tranh chấp (không ai ghi): mỗi lần tra chữ thêm một lần khoá/mở `os_unfair_lock`, cỡ vài chục ns.
    static var processLanguageOverride: Locale? {
        get { processOverride.withLock { $0 } }
        set { processOverride.withLock { $0 = newValue } }
    }

    private static let processOverride = Mutex<Locale?>(nil)

    /// Ngôn ngữ test đang ép (`languageOverride`, rồi `processLanguageOverride`); `nil` trong app.
    static var testLanguage: Locale? { languageOverride ?? processLanguageOverride }

    /// Chữ của `key` trong catalog của `bundle` (bundle của module gọi, `.module`), theo ngôn ngữ giao diện.
    public static func resolve(_ key: String.LocalizationValue, bundle: Bundle) -> String {
        resolve(key, bundle: bundle, locale: testLanguage ?? pinnedLocale)
    }

    /// Như `resolve(_:bundle:)` nhưng chọn ngôn ngữ bằng `locale` (`nil`: theo bundle chính). Khoá ngôn ngữ bằng
    /// `LocalizedStringResource.locale`, vì tham số `locale` của `String(localized:bundle:locale:)` chỉ định dạng số
    /// và ngày, không chọn ngôn ngữ (spike giai đoạn 5). Số nội suy (`%lld`) có ngăn nghìn theo `locale` khi có, nếu
    /// không theo `InterfaceLocale.current` (ngôn ngữ giao diện, không theo Region của macOS).
    public static func resolve(_ key: String.LocalizationValue, bundle: Bundle, locale: Locale?) -> String {
        guard let locale else {
            return resolveFollowingMainBundle(key, bundle: bundle, formatLocale: InterfaceLocale.current)
        }
        var resource = LocalizedStringResource(key, bundle: .atURL(bundle.bundleURL)) // l10n-ignore: như dưới
        resource.locale = locale
        return String(localized: resource) // l10n-ignore: resource đã mang bundle của module
    }

    /// Đường của app: ngôn ngữ theo bundle chính, số và ngày nội suy định dạng theo `formatLocale` (mặc định của
    /// `String(localized:bundle:)` là `Locale.current`, tức Region của macOS). Tách riêng để test kiểm được đường này
    /// với locale cố định.
    static func resolveFollowingMainBundle(
        _ key: String.LocalizationValue,
        bundle: Bundle,
        formatLocale: Locale
    ) -> String {
        String(localized: key, bundle: bundle, locale: formatLocale) // l10n-ignore: bundle của module gọi
    }
}
