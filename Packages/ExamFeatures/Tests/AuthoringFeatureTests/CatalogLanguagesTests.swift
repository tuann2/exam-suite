@testable import AuthoringFeature
import Foundation
@testable import LibraryFeature
@testable import ReportFeature
@testable import SessionFeature
import Testing

/// Mọi module có chữ giao diện mang cùng các ngôn ngữ đã biên dịch (review độc lập #50 N2; plan giai đoạn 5 bước 7c):
/// `InterfaceLocale` chọn ngôn ngữ định dạng theo catalog của LibraryFeature, nên module nào thiếu `en` sẽ ra chữ tiếng
/// Việt cạnh số/ngày dạng tiếng Anh. Kiểm trên bundle đã biên dịch của `swift test`; hai app đã build kiểm bằng
/// `scripts/check_localization.py --built-apps` (cùng luật, có đối chứng âm).
@Suite("Ngôn ngữ của catalog ở mọi module")
struct CatalogLanguagesTests {
    private static let en = Locale(identifier: "en")

    /// Bundle catalog của AdminShell: không test target nào phụ thuộc AdminShell, nên lấy bản `swift test` dựng cạnh
    /// bundle test.
    private static var adminShellBundle: Bundle? {
        let products = Bundle(for: BundleToken.self).bundleURL.deletingLastPathComponent()
        return Bundle(url: products.appendingPathComponent("ExamFeatures_AdminShell.bundle"))
    }

    private static func moduleBundles() throws -> [(name: String, bundle: Bundle)] {
        [
            ("LibraryFeature", LibraryFeature.ModuleStrings.bundle),
            ("SessionFeature", SessionFeature.ModuleStrings.bundle),
            ("ReportFeature", ReportFeature.ModuleStrings.bundle),
            ("AuthoringFeature", AuthoringFeature.ModuleStrings.bundle),
            ("AdminShell", try #require(adminShellBundle, "Không thấy ExamFeatures_AdminShell.bundle cạnh bundle test")),
        ]
    }

    @Test("Mọi module có cùng ngôn ngữ (vi nguồn, en đã biên dịch)")
    func everyModuleHasTheSameLanguages() throws {
        let bundles = try Self.moduleBundles()
        let reference = Set(InterfaceLocale.catalogLanguages(of: bundles[0].bundle))
        #expect(reference == ["vi", "en"])
        for (name, bundle) in bundles {
            #expect(Set(InterfaceLocale.catalogLanguages(of: bundle)) == reference, "\(name)")
            #expect(bundle.developmentLocalization == "vi", "\(name)")
        }
    }

    /// Ưu tiên tiếng Anh (kể cả có vùng) ra `en` cho định dạng, và mọi module ra chữ tiếng Anh với số dạng tiếng Anh.
    @Test("Ưu tiên tiếng Anh: định dạng và chữ của mọi module là tiếng Anh")
    func englishPreferenceGivesEnglishEverywhere() throws {
        let available = InterfaceLocale.catalogLanguages(of: LibraryFeature.ModuleStrings.bundle)
        let locale = InterfaceLocale.resolve(preferences: ["en-VN", "vi"], available: available, pinned: nil)
        #expect(locale.identifier == "en")
        #expect(InterfaceLocale.number(1234, locale: locale) == "1,234")
        // Ngôn ngữ không có trong app vẫn ra tiếng Việt (phương án 1).
        #expect(InterfaceLocale.resolve(preferences: ["fr"], available: available, pinned: nil).identifier == "vi")

        let samples: [(String, Bundle, String.LocalizationValue, String)] = [
            ("LibraryFeature", LibraryFeature.ModuleStrings.bundle, "Đã thêm \(1234) đề.", "Added 1,234 exams."),
            ("SessionFeature", SessionFeature.ModuleStrings.bundle, "Câu \(1234)/\(2000)", "Question 1,234 of 2,000"),
            ("ReportFeature", ReportFeature.ModuleStrings.bundle, "Trang \(1)/\(1175)", "Page 1 of 1,175"),
            ("AuthoringFeature", AuthoringFeature.ModuleStrings.bundle, "\(1) cảnh báo", "1 warning"),
            ("AdminShell", try #require(Self.adminShellBundle), "Mở gần đây", "Open Recent"),
        ]
        for (name, bundle, key, english) in samples {
            #expect(InterfaceStrings.resolve(key, bundle: bundle, locale: locale) == english, "\(name)")
        }
    }
}

private final class BundleToken {}
