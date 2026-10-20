import Foundation
@testable import LibraryFeature
import Testing

/// Hạ tầng String Catalog (docs/product/accessibility-localization.md, mục Ngôn ngữ; plan giai đoạn 5 bước 4): chữ giao
/// diện tra catalog của module, tiếng Việt là ngôn ngữ nguồn, test so chữ tiếng Việt không đổi kết quả khi catalog có
/// bản tiếng Anh.
@Suite("String Catalog: tiếng Việt nguồn, khoá ngôn ngữ trong test")
struct LocalizationTests {
    /// Trình chạy `swift test` không khai báo `vi` ở bundle chính, nên macOS sẽ chọn `en` khi catalog có `en` (spike).
    /// `InterfaceStrings` khoá ngôn ngữ nguồn `vi` ở tiến trình như vậy; trong app (bundle chính có vi.lproj, en.lproj,
    /// `scripts/check_localization.py --built-apps` kiểm) thì theo ngôn ngữ bundle chính chọn.
    @Test func testProcessPinsVietnamese() {
        #expect(!Bundle.main.localizations.contains("vi"))
        #expect(InterfaceStrings.pinnedLocale?.identifier == "vi")
    }

    @Test func moduleBundleDeclaresVietnameseSource() {
        #expect(LibraryFeature.ModuleStrings.bundle.developmentLocalization == "vi")
    }

    /// Khoá là chữ tiếng Việt: tra `vi` ra đúng khoá, nội suy số và chuỗi điền đúng chỗ (phần trăm qua `FormatStyle`,
    /// bước 7a).
    @Test func vietnameseResolvesToSourceText() {
        #expect(catalogText("Thư viện", language: "vi") == "Thư viện")
        #expect(catalogText("\(12) câu", language: "vi") == "12 câu")
        #expect(catalogText("Đậu từ \(LibraryFormat.percent(70))", language: "vi") == "Đậu từ 70%")
        #expect(localized("Đậu từ \(LibraryFormat.percent(70))") == "Đậu từ 70%")
        #expect(LibraryFormat.passThreshold(70) == "Đậu từ 70%")
    }

    /// Bản `en` (bước 7c): tra `en` ra chữ tiếng Anh, plural và substitution đúng. Tra theo bundle chính (đường của app,
    /// `locale: nil`) trong trình chạy `swift test` (bundle chính không khai báo ngôn ngữ; spike giai đoạn 5: macOS chọn
    /// `en`) ra chữ của một trong hai ngôn ngữ của catalog, không ra chữ rỗng hay khoá lạ.
    @Test func englishResolves() {
        #expect(catalogText("Thư viện", language: "en") == "Library")
        #expect(catalogText("\("850")/1000", language: "en") == "850/1000")
        #expect(catalogText("\(1) câu", language: "en") == "1 question")
        #expect(catalogText("\(12) câu", language: "en") == "12 questions")
        #expect(catalogText("\(1500) câu", language: "en") == "1,500 questions")
        #expect(catalogText("Đậu từ \(LibraryFormat.percent(70, locale: Locale(identifier: "en")))", language: "en")
            == "Passing score 70%")
        #expect(catalogText("\(2) giờ \(1) phút", language: "en") == "2 hours 1 minute")
        #expect(catalogText("\(1) phút \(30) giây", language: "en") == "1 minute 30 seconds")
        let bundle = LibraryFeature.ModuleStrings.bundle
        #expect(["12 câu", "12 questions"].contains(InterfaceStrings.resolve("\(12) câu", bundle: bundle, locale: nil)))
    }
}
