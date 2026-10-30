import Foundation
import InterfaceCore
@testable import ReportFeature
import Testing

/// Catalog của ReportFeature được đóng gói đúng bundle của module và tra theo ngôn ngữ cố định; nhãn vẽ vào PDF đi qua
/// catalog (docs/product/accessibility-localization.md, mục Kiểm; export-print.md, Ngôn ngữ nhãn).
@Suite("String Catalog của ReportFeature")
struct ReportLocalizationTests {
    private func catalogText(_ key: String.LocalizationValue, language: String) -> String {
        InterfaceStrings.resolve(key, bundle: ReportFeature.ModuleStrings.bundle, locale: Locale(identifier: language))
    }

    @Test func moduleBundleDeclaresVietnameseSource() {
        #expect(ReportFeature.ModuleStrings.bundle.developmentLocalization == "vi")
        #expect(ReportFeature.ModuleStrings.bundle.bundleURL.lastPathComponent.contains("ReportFeature"))
    }

    @Test func vietnameseResolvesWithArguments() {
        #expect(catalogText("Trang \(2)/\(5)", language: "vi") == "Trang 2/5")
        #expect(ReportStrings.page(2, of: 5) == "Trang 2/5")
        #expect(ReportStrings.questionContinued(12) == "Câu 12 (tiếp)")
        #expect(ReportStrings.creator(version: "1.0") == "Exam Suite 1.0")
        #expect(ReportStrings.resultsDisclaimer == "Kết quả luyện tập, không có giá trị xác nhận")
        #expect(ResultsReviewLevel.default.title == "Câu sai và chưa làm")
    }

    /// Số trong chữ giao diện định dạng theo locale của ngôn ngữ giao diện (accessibility-localization.md mục Ngôn ngữ;
    /// Nt0 giữ quy tắc 2026-10-17): giao diện tiếng Việt thì dấu chấm ngăn nghìn, tiếng Anh dấu phẩy. Khoá ngôn ngữ tường
    /// minh nên không phụ thuộc Region của máy chạy test. Trong app, `InterfaceStrings.resolve` định dạng theo
    /// `InterfaceLocale.current` (bước 7a), không theo Region.
    @Test func numbersFollowInterfaceLanguage() {
        #expect(catalogText("Trang \(1175)/\(1175)", language: "vi") == "Trang 1.175/1.175")
        #expect(catalogText("Câu \(1234)/\(2000)", language: "vi") == "Câu 1.234/2.000")
        #expect(catalogText("Trang \(1175)/\(1175)", language: "en") == "Page 1,175 of 1,175")
        // `swift test` khoá ngôn ngữ nguồn vi (InterfaceStrings.pinnedLocale), nên hàm của ReportStrings cũng ra dạng vi.
        #expect(ReportStrings.page(1175, of: 1175) == "Trang 1.175/1.175")
        #expect(ReportStrings.questionPosition(1234, of: 2000) == "Câu 1.234/2.000")
        #expect(ReportStrings.questionContinued(1234) == "Câu 1.234 (tiếp)")
        #expect(ReportStrings.questionCount(2000) == "2.000 câu")
        #expect(ReportStrings.drawingPage(1001) == "Đang dựng trang 1.001…")
    }

    /// Bộ dựng trang đặt môi trường SwiftUI theo ngôn ngữ giao diện (mặc định), như gốc mọi scene của app.
    @MainActor
    @Test func rendererUsesInterfaceLocale() {
        #expect(ReportRenderer().locale == InterfaceLocale.current)
        #expect(ReportRenderer(locale: Locale(identifier: "en")).locale.identifier == "en")
    }

    /// Bản `en` (bước 7c): nhãn PDF, câu có đối số, plural ("1 question" / "2 questions").
    @Test func englishResolves() {
        #expect(catalogText("Đáp án đúng", language: "en") == "Correct answer")
        #expect(catalogText("Bạn chọn", language: "en") == "Your answer")
        #expect(catalogText("Kết quả luyện tập, không có giá trị xác nhận", language: "en")
            == "Practice result, not an official certification")
        #expect(catalogText("Câu \(12) (tiếp)", language: "en") == "Question 12 (continued)")
        #expect(catalogText("\(1) câu", language: "en") == "1 question")
        #expect(catalogText("\(2) câu", language: "en") == "2 questions")
        #expect(catalogText("\(2000) câu", language: "en") == "2,000 questions")
        #expect(catalogText("\("Địa lý") (có đáp án)", language: "en") == "Địa lý (with answers)")
    }
}
