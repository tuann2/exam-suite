import Foundation

/// Markdown cơ bản của nội dung đề (exam-format.md: đậm, nghiêng, mã, liên kết) thành chữ trơn cho câu VoiceOver: VoiceOver
/// không đọc ký hiệu (`**`, `*`, `` ` ``), chỉ đọc chữ (docs/product/accessibility-localization.md, mục VoiceOver). Dùng ở
/// cửa sổ làm bài, Xem lại bài, xem trước và cây đề của Soạn đề.
public enum PlainMarkdown {
    /// Chuỗi đã bỏ ký hiệu Markdown; chuỗi không phân tích được thì giữ nguyên văn.
    public static func text(_ source: String) -> String {
        String(attributed(source).characters)
    }

    /// Như `MarkdownText` vẽ: chỉ cú pháp trong dòng, giữ xuống dòng.
    public static func attributed(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}
