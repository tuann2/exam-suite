import CoreText
import SwiftUI
import Synchronization

/// Phông và màu của PDF (docs/product/export-print.md, Trình bày chung, phương án 13): **Helvetica Neue** cho chữ
/// thân và đề mục, **SF Mono** cho mã inline. Không dùng SF Pro: chữ Đ (U+0110) vẽ bằng SF Pro đọc lại từ PDF thành
/// Ð (U+00D0) (docs/notes/g5-spike-pdf-l10n.md). Luôn nền trắng chữ đen, không theo Dark Mode.
///
/// **Không chữ ghép** (giai đoạn 5 bước 8a, review độc lập #52): Helvetica Neue mặc định ghép "fi", "fl", "ffi"… thành
/// một glyph (U+FB01, U+FB02, U+FB03…), và lớp chữ của PDF ghi đúng ký tự ghép đó: chép ra "oﬃcial", tìm "official"
/// trong Preview không thấy, VoiceOver đọc sai, kể cả nội dung đề tiếng Anh. Chữ Helvetica Neue tắt chữ ghép thường
/// (`kLigaturesType`/`kCommonLigaturesOffSelector` và OpenType `liga` = 0) qua `CTFont` → `Font(_:)`.
enum ReportTypography {
    static let bodySize: CGFloat = 11
    static let smallSize: CGFloat = 9.5
    static let footerSize: CGFloat = 7.5
    static let headingSize: CGFloat = 14
    static let titleSize: CGFloat = 18
    static let verdictSize: CGFloat = 22

    static func body(size: CGFloat = bodySize, bold: Bool = false, italic: Bool = false) -> Font {
        let name = switch (bold, italic) {
        case (false, false): "HelveticaNeue"
        case (true, false): "HelveticaNeue-Bold"
        case (false, true): "HelveticaNeue-Italic"
        case (true, true): "HelveticaNeue-BoldItalic"
        }
        let key = FontKey(name: name, size: size)
        if let font = fontCache.withLock({ $0[key] }) { return font }
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute: name] as CFDictionary)
        let font = Font(withoutLigatures(CTFontCreateWithFontDescriptor(descriptor, size, nil)))
        fontCache.withLock { $0[key] = font }
        return font
    }

    /// Một `Font` cho mỗi phông và cỡ: dùng lại cùng một `CTFont` để SwiftUI dùng lại kết quả đo chữ giữa các khối (tạo
    /// `CTFont` mới mỗi lần làm PDF đề chuẩn 2.000 câu chậm hơn ~11 %). Khối của PDF đề dựng ngoài main actor nên có khoá.
    private struct FontKey: Hashable {
        let name: String
        let size: CGFloat
    }

    private static let fontCache = Mutex<[FontKey: Font]>([:])

    /// SF Mono (phông đơn cách của hệ thống). Không có chữ ghép thường nên giữ nguyên (đã kiểm: "`official`" đọc lại
    /// nguyên văn, `ReportRendererTests.noLigatures`).
    static func code(size: CGFloat = bodySize, bold: Bool = false) -> Font {
        Font.system(size: size * 0.93, weight: bold ? .semibold : .regular, design: .monospaced)
    }

    /// Bản sao của `font` tắt chữ ghép thường (AAT và OpenType `liga`); chữ ghép bắt buộc của chữ viết (nếu có) giữ.
    static func withoutLigatures(_ font: CTFont) -> CTFont {
        let features: [[CFString: Any]] = [
            [
                kCTFontFeatureTypeIdentifierKey: kLigaturesType,
                kCTFontFeatureSelectorIdentifierKey: kCommonLigaturesOffSelector,
            ],
            [kCTFontOpenTypeFeatureTag: "liga", kCTFontOpenTypeFeatureValue: 0],
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontFeatureSettingsAttribute: features] as CFDictionary
        )
        return CTFontCreateCopyWithAttributes(font, CTFontGetSize(font), nil, descriptor)
    }

    /// Độ xám (sRGB, 0 đen … 1 trắng) của các màu PDF: bảng màu dạng số của PDF (luôn sáng, export-print.md), để test
    /// tương phản (`ReportPaletteTests`: chữ ≥ 4,5:1 trên trang trắng và nền nhạt).
    enum Gray {
        static let primary = 0.0
        static let secondary = 0.3
        static let rule = 0.6
        static let tint = 0.93
        static let fill = 0.35
    }

    /// Chữ chính: đen.
    static let primary = Color(white: Gray.primary)
    /// Chữ phụ (tên phần, nhãn): xám đậm, tương phản ≥ 7:1 trên nền trắng.
    static let secondary = Color(white: Gray.secondary)
    /// Viền, vạch phân cách.
    static let rule = Color(white: Gray.rule)
    /// Nền nhạt (khung giải thích, dòng báo, thanh điểm).
    static let tint = Color(white: Gray.tint)
    /// Phần đã đạt của thanh điểm.
    static let fill = Color(white: Gray.fill)

    /// Markdown cơ bản như màn hình (exam-format.md: đậm, nghiêng, mã inline, liên kết; `MarkdownText` của
    /// SessionFeature): chuỗi chuẩn hoá NFC trước khi vẽ; đậm/nghiêng gán phông Helvetica Neue tương ứng, mã gán SF
    /// Mono; liên kết hiện chữ gạch chân, không bấm được. Chuỗi không phân tích được thì in nguyên văn.
    static func markdown(_ source: String, size: CGFloat = bodySize, bold: Bool = false) -> AttributedString {
        let nfc = source.precomposedStringWithCanonicalMapping
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        var text = (try? AttributedString(markdown: nfc, options: options)) ?? AttributedString(nfc)
        for run in text.runs {
            let intent = run.inlinePresentationIntent ?? []
            let strong = bold || intent.contains(.stronglyEmphasized)
            let range = run.range
            if intent.contains(.code) {
                text[range].font = code(size: size, bold: strong)
            } else {
                text[range].font = body(size: size, bold: strong, italic: intent.contains(.emphasized))
            }
            if intent.contains(.strikethrough) {
                text[range].strikethroughStyle = .single
            }
            if run.link != nil {
                text[range].link = nil
                text[range].underlineStyle = .single
            }
            text[range].inlinePresentationIntent = nil
            text[range].foregroundColor = primary
        }
        return text
    }

    /// Chữ trơn một kiểu (không Markdown), NFC.
    static func plain(_ source: String, font: Font, color: Color = primary) -> AttributedString {
        var text = AttributedString(source.precomposedStringWithCanonicalMapping)
        text.font = font
        text.foregroundColor = color
        return text
    }
}
