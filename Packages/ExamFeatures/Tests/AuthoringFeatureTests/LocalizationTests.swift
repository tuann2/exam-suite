import Foundation
@testable import AuthoringFeature
import InterfaceCore
import Testing

/// Catalog của AuthoringFeature được đóng gói đúng bundle của module (docs/product/accessibility-localization.md,
/// mục Kiểm; plan giai đoạn 5 bước 4).
@Suite("String Catalog của AuthoringFeature")
struct AuthoringLocalizationTests {
    private func catalogText(_ key: String.LocalizationValue, language: String) -> String {
        InterfaceStrings.resolve(key, bundle: AuthoringFeature.ModuleStrings.bundle, locale: Locale(identifier: language))
    }

    @Test func moduleBundleDeclaresVietnameseSource() {
        #expect(AuthoringFeature.ModuleStrings.bundle.developmentLocalization == "vi")
    }

    /// Nhãn trước đây là `LocalizedStringKey` (không định dạng) nay qua `String.LocalizationValue`: khoá không nội suy
    /// có `%` phải ra nguyên văn ở cả hai đường tra (khoá ngôn ngữ trong test, theo bundle trong app) và ở cả hai ngôn
    /// ngữ. Đường theo bundle chính trong `swift test` ra tiếng Anh từ bước 7c (bundle chính của trình chạy không khai báo
    /// ngôn ngữ, spike giai đoạn 5).
    @Test func percentSignWithoutArgumentsIsKept() {
        let bundle = AuthoringFeature.ModuleStrings.bundle
        #expect(localized("Ngưỡng đậu (%)") == "Ngưỡng đậu (%)")
        #expect(["Ngưỡng đậu (%)", "Passing score (%)"]
            .contains(InterfaceStrings.resolve("Ngưỡng đậu (%)", bundle: bundle, locale: nil)))
        #expect(catalogText("Nhập ngưỡng đậu (%).", language: "vi") == "Nhập ngưỡng đậu (%).")
        #expect(catalogText("Nhập ngưỡng đậu (%).", language: "en") == "Enter the passing score (%).")
    }

    @Test func vietnameseResolvesWithArguments() {
        #expect(catalogText("Phần \(2), câu \(5)", language: "vi") == "Phần 2, câu 5")
        #expect(catalogText("Không import được “\("de.docx")”", language: "vi") == "Không import được “de.docx”")
    }

    /// Bản `en` (bước 7c): thuật ngữ của bảng, plural, substitution có đối số chen giữa.
    @Test func englishResolves() {
        #expect(catalogText("Không import được “\("de.docx")”", language: "en") == "Couldn’t import “de.docx”")
        #expect(catalogText("Thử đề này", language: "en") == "Try This Exam")
        #expect(catalogText("Import đề…", language: "en") == "Import Exam…")
        #expect(catalogText("\(1) lỗi", language: "en") == "1 error")
        #expect(catalogText("\(2) lỗi", language: "en") == "2 errors")
        #expect(catalogText("Báo cáo import “\("de.txt")”: \(1) câu bị bỏ · \(2) cảnh báo", language: "en")
            == "Import report for “de.txt”: 1 question skipped · 2 warnings")
        #expect(catalogText("Báo cáo import “\("de.txt")”: \(2) câu bị bỏ · \(1) cảnh báo", language: "en")
            == "Import report for “de.txt”: 2 questions skipped · 1 warning")
        #expect(catalogText("Ngưỡng đậu (%)", language: "en") == "Passing score (%)")
        #expect(catalogText("Điểm đậu trong file (\(250)) ngoài 0–100 % nên để trống; hãy nhập khi import.", language: "en")
            == "The passing score in the file (250) is outside 0–100 %, so it was left blank; enter it when importing.")
        // Câu VoiceOver của bước 8b.
        #expect(catalogText("Kiểm đề: \(1) lỗi mới", language: "en") == "Validation: 1 new error")
        #expect(catalogText("Kiểm đề: \(2) lỗi mới", language: "en") == "Validation: 2 new errors")
        #expect(catalogText("Đã lưu “\("de.exam")”", language: "en") == "Saved “de.exam”")
        #expect(catalogText("Đã import “\("de.txt")”: \("1 section")", language: "en") == "Imported “de.txt”: 1 section")
        #expect(catalogText("Ảnh của câu hỏi", language: "en") == "Question image")
    }
}
