import Foundation
import SwiftUI

/// Locale của **ngôn ngữ giao diện**, dùng để định dạng số (ngăn nghìn), phần trăm và ngày giờ ở mọi màn và PDF/In
/// (docs/product/accessibility-localization.md, mục Ngôn ngữ: "theo locale của ngôn ngữ giao diện (`FormatStyle`), không
/// ghép chuỗi tay"; Nt0 giữ quy tắc 2026-10-17: không theo Region của macOS).
///
/// Chỉ có ngôn ngữ, không có vùng: giao diện tiếng Việt thì "1.234", "85,5%", "14:05 15/10/2026"; tiếng Anh thì
/// "1,234", "85.5%", "10/15/2026, 2:05 PM", dù Region của máy là gì. Ngôn ngữ là ngôn ngữ mà **chữ của catalog** thật sự
/// ra (cùng ngôn ngữ với chữ tra qua `InterfaceStrings` và `Text(_:bundle:)`), không chỉ ngôn ngữ của bundle chính: bundle
/// chính có `vi.lproj` và `en.lproj` (chuỗi Info.plist) từ bước 4, nhưng catalog của các module chưa có `en` tới bước 7c,
/// nên máy ưu tiên tiếng Anh vẫn thấy chữ tiếng Việt, và số/ngày cũng phải dạng tiếng Việt. Lịch luôn Gregorian
/// (`calendar`), không theo lịch của Region. Trong tiến trình không phải app (`swift test`) là ngôn ngữ đã khoá của
/// `InterfaceStrings.pinnedLocale` (vi), nên test không phụ thuộc máy chạy.
///
/// Cách dùng (AGENTS.md, mục "Chuỗi giao diện"):
/// - Chữ có số qua `localized("…\(n)…")` hay `InterfaceStrings.resolve`: số tự định dạng theo locale này.
/// - View SwiftUI: gốc của mọi scene gắn `.interfaceLocale()` (môi trường `\.locale`), nên nội suy trong
///   `Text("…", bundle: .module)` và `Text(n, format: .number)` theo locale này; `ImageRenderer` của PDF cũng gắn.
/// - Ngoài view (model trình bày, AppKit, PDF): `number(_:)`, `percent(_:)` hoặc `FormatStyle` có
///   `.locale(InterfaceLocale.current)` (ngày: thêm `calendar: InterfaceLocale.calendar`). Không dùng
///   `Locale.current`/`.autoupdatingCurrent` (theo Region), kiểm bằng `scripts/check_localization.py` (luật
///   `region-locale`).
public enum InterfaceLocale {
    /// Ngôn ngữ nguồn của mọi catalog (khoá là chữ tiếng Việt): luôn tra được, kể cả khi bundle của module không có
    /// `vi.lproj`; dùng khi không ngôn ngữ ưu tiên nào có trong catalog (phương án 1: không khớp thì tiếng Việt).
    static let sourceLanguage = "vi"

    /// Lịch của mọi ngày giờ hiển thị: Gregorian, không theo lịch chọn ở Region (Phật lịch, lịch Nhật…).
    public static let calendar = Calendar(identifier: .gregorian)

    /// Locale định dạng của giao diện app (tính một lần: ngôn ngữ của app không đổi khi đang chạy). Trong test, ngôn ngữ
    /// test đang ép (`InterfaceStrings.testLanguage`) thắng, để số và ngày cùng ngôn ngữ với chữ.
    public static var current: Locale { InterfaceStrings.testLanguage ?? resolvedCurrent }

    private static let resolvedCurrent: Locale = resolve(
        preferences: appPreferences,
        available: catalogLanguages(of: ModuleStrings.bundle),
        pinned: InterfaceStrings.pinnedLocale
    )

    /// Thứ tự ngôn ngữ của app: ngôn ngữ bundle chính đã chọn (theo ngôn ngữ ưu tiên của macOS hoặc ngôn ngữ riêng cho
    /// app), nếu không có thì ngôn ngữ ưu tiên của hệ thống.
    private static var appPreferences: [String] {
        let chosen = Bundle.main.preferredLocalizations.filter { $0 != "Base" }
        return chosen.isEmpty ? Locale.preferredLanguages : chosen
    }

    /// Ngôn ngữ chữ của catalog tra được trong `bundle`: các `*.lproj` đã biên dịch (Xcode chỉ ghi `en.lproj` khi catalog
    /// có bản `en`; ngôn ngữ nguồn không có thư mục riêng vì khoá chính là chữ) cộng ngôn ngữ nguồn của bundle.
    static func catalogLanguages(of bundle: Bundle) -> [String] {
        bundle.localizations + [bundle.developmentLocalization ?? sourceLanguage]
    }

    /// Locale chỉ gồm mã ngôn ngữ: ngôn ngữ đầu tiên trong `preferences` mà catalog có (`available`, luôn kể cả tiếng
    /// Việt nguồn), so theo mã ngôn ngữ nên vùng bị bỏ ("en-VN" → "en"); không ngôn ngữ nào khớp thì tiếng Việt.
    /// `pinned` (tiến trình test) thắng. Cùng cách Foundation chọn ngôn ngữ cho chữ của module (spike giai đoạn 5:
    /// `fr` → `vi`, `fr, en` → `en`; catalog chưa có `en` → `vi`).
    static func resolve(preferences: [String], available: [String], pinned: Locale?) -> Locale {
        if let pinned {
            return language(of: pinned.identifier) ?? Locale(identifier: sourceLanguage)
        }
        let codes = Set((available + [sourceLanguage]).compactMap { language(of: $0)?.identifier })
        for preference in preferences {
            if let locale = language(of: preference), codes.contains(locale.identifier) {
                return locale
            }
        }
        return Locale(identifier: sourceLanguage)
    }

    private static func language(of identifier: String) -> Locale? {
        guard let code = Locale(identifier: identifier).language.languageCode?.identifier,
              !code.isEmpty, code != "base", code != "und"
        else { return nil }
        return Locale(identifier: code)
    }

    /// Số nguyên có ngăn nghìn theo ngôn ngữ giao diện: "1.234" (vi), "1,234" (en).
    public static func number(_ value: Int, locale: Locale = current) -> String {
        value.formatted(.number.locale(locale))
    }

    /// Phần trăm (số nguyên điểm phần trăm, ví dụ điểm 85 → "85%") theo ngôn ngữ giao diện.
    public static func percent(_ value: Int, locale: Locale = current) -> String {
        value.formatted(.percent.locale(locale))
    }

    /// Điểm hay ngưỡng theo **thang 1000**: luôn chữ số trơn, không ngăn nghìn, ở mọi ngôn ngữ ("850", "1000"; đi cùng
    /// "/1000": "850/1000", "1000/1000"). **Ngoại lệ có chủ ý** của quy tắc số theo ngôn ngữ giao diện (Nt0 chốt
    /// 2026-10-17, accessibility-localization.md mục Ngôn ngữ; scoring.md): "1000" là tên của thang, và Kết quả ghi số trơn
    /// từ G3.3. Mọi chỗ hiện giá trị thang 1000 (Kết quả, PDF kết quả, PDF đề, Lịch sử thi, Soạn đề) đi qua hàm này.
    public static func scale1000(_ value: Int) -> String {
        String(value)
    }
}

extension View {
    /// Đặt `\.locale` của môi trường theo ngôn ngữ giao diện (`InterfaceLocale.current`) và `\.calendar` theo lịch
    /// Gregorian (`InterfaceLocale.calendar`): số, phần trăm, ngày giờ trong `Text` (và lịch của `DatePicker`) theo ngôn
    /// ngữ giao diện, không theo Region. Gắn ở gốc của view không nằm trong scene (`ImageRenderer`).
    public func interfaceLocale(_ locale: Locale = InterfaceLocale.current) -> some View {
        environment(\.locale, locale).environment(\.calendar, InterfaceLocale.calendar)
    }
}

extension Scene {
    /// Như `View.interfaceLocale()`, cho cả scene (mọi cửa sổ, sheet, hộp thoại của scene). Mỗi scene của hai shell phải
    /// gắn (như `.defaultAppStorage`).
    public func interfaceLocale(_ locale: Locale = InterfaceLocale.current) -> some Scene {
        environment(\.locale, locale).environment(\.calendar, InterfaceLocale.calendar)
    }
}
