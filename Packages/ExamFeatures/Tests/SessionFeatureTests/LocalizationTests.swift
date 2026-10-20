import Foundation
import LibraryFeature
@testable import SessionFeature
import Testing

/// Catalog của SessionFeature được đóng gói đúng bundle của module và tra theo ngôn ngữ cố định
/// (docs/product/accessibility-localization.md, mục Kiểm; plan giai đoạn 5 bước 4).
@Suite("String Catalog của SessionFeature")
struct SessionLocalizationTests {
    private func catalogText(_ key: String.LocalizationValue, language: String) -> String {
        InterfaceStrings.resolve(key, bundle: SessionFeature.ModuleStrings.bundle, locale: Locale(identifier: language))
    }

    @Test func moduleBundleDeclaresVietnameseSource() {
        #expect(SessionFeature.ModuleStrings.bundle.developmentLocalization == "vi")
        #expect(SessionFeature.ModuleStrings.bundle.bundleURL.lastPathComponent.contains("SessionFeature"))
    }

    @Test func vietnameseResolvesWithArguments() {
        #expect(catalogText("Câu \(3)/\(60)", language: "vi") == "Câu 3/60")
        #expect(localized("Câu \(3)/\(60)") == "Câu 3/60")
        #expect(SessionFormat.percent(85) == "85%")
    }

    /// Số, phần trăm, ngày giờ của phiên thi theo ngôn ngữ giao diện, không theo Region (accessibility-localization.md,
    /// mục Ngôn ngữ; bước 7a). Tiến trình test khoá vi; tiếng Anh tra bằng locale tường minh.
    @Test func numbersFollowInterfaceLanguage() {
        #expect(SessionFormat.number(2000) == "2.000")
        #expect(SessionFormat.percent(85) == "85%")
        #expect(SessionFormat.percentDelta(8) == "+8%")
        #expect(SessionFormat.percentDelta(-5) == "−5%")
        #expect(SessionFormat.percentDelta(0) == "bằng")
        let row = ResultSectionRow(id: UUID(), title: "Phần 1", correct: 1234, total: 2000, percent: 61, isWeakest: false)
        #expect(row.detailText == "1.234/2.000 · 61%")
        #expect(localized("Câu \(1234)/\(2000)") == "Câu 1.234/2.000")
        #expect(localized("Đã làm \(1500)/\(2000)") == "Đã làm 1.500/2.000")
        #expect(catalogText("Câu \(1234)/\(2000)", language: "en") == "Question 1,234 of 2,000")
    }

    @Test func dateTimeFollowsInterfaceLanguage() {
        let day = Date(timeIntervalSince1970: 1_792_073_100) // 15/10/2026 14:05 UTC
        let utc = TimeZone(identifier: "UTC")!
        #expect(SessionFormat.dateTime(day, timeZone: utc) == "14:05 15/10/2026")
        #expect(SessionFormat.dateTime(day, locale: Locale(identifier: "en"), timeZone: utc) == "10/15/2026, 2:05\u{202F}PM")
    }

    /// Bản `en` (bước 7c): thuật ngữ của bảng (accessibility-localization.md), câu có đối số, plural và substitution
    /// ("1 hour 5 minutes").
    @Test func englishResolves() {
        #expect(catalogText("Rà soát & nộp", language: "en") == "Review & Submit")
        #expect(catalogText("Kiểm tra đáp án", language: "en") == "Check Answer")
        #expect(catalogText("Luyện lại câu sai", language: "en") == "Practice Incorrect")
        #expect(catalogText("Đã làm \(12)/\(60)", language: "en") == "12 of 60 answered")
        #expect(catalogText("Còn \(1) câu chưa làm. Vẫn nộp?", language: "en") == "1 question is unanswered. Submit anyway?")
        #expect(catalogText("Còn \(2) câu chưa làm. Vẫn nộp?", language: "en") == "2 questions are unanswered. Submit anyway?")
        #expect(catalogText("\(1) giờ \(1) phút", language: "en") == "1 hour 1 minute")
        #expect(catalogText("\(2) giờ \(5) phút", language: "en") == "2 hours 5 minutes")
        #expect(catalogText("Câu \(3) trên \(60), \("Section Networking")", language: "en")
            == "Question 3 of 60, Section Networking")
        // Menu Xem/View (bước 8b): tên chuẩn của macOS.
        #expect(catalogText("Phóng to", language: "en") == "Zoom In")
        #expect(catalogText("Thu nhỏ", language: "en") == "Zoom Out")
        #expect(catalogText("Cỡ thật", language: "en") == "Actual Size")
        // Nền đọc (giai đoạn 6 bước 1): menu con của menu Xem và tên năm nền (thuật ngữ Nt0 duyệt 2026-10-18, accessibility-localization.md).
        #expect(catalogText("Nền đọc", language: "en") == "Reading Background")
        #expect(["Theo hệ thống", "Trắng", "Giấy ngà", "Xám dịu", "Tối"].map { catalogText(String.LocalizationValue($0), language: "en") }
            == ["Match System", "White", "Sepia", "Soft Gray", "Dark"])
        #expect(ReadingBackground.allCases.map(\.title) == ["Theo hệ thống", "Trắng", "Giấy ngà", "Xám dịu", "Tối"])
    }
}
