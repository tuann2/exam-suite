import Foundation

/// Chuẩn hoá chuỗi khi import (docs/product/import.md, Luồng): NFC, bỏ khoảng trắng hai đầu, nối dòng, chuyển văn
/// bản trơn sang Markdown cơ bản.
enum TextNormalizer {
    /// NFC rồi bỏ scalar Unicode `White_Space` ở hai đầu (cùng định nghĩa khoảng trắng với `ExamValidator`).
    static func clean(_ s: String) -> String {
        trimWhitespace(s.precomposedStringWithCanonicalMapping)
    }

    static func trimWhitespace(_ s: String) -> String {
        let scalars = s.unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(String.UnicodeScalarView(scalars[start ... end]))
    }

    static func isBlank(_ s: String) -> Bool {
        s.unicodeScalars.allSatisfy(\.properties.isWhitespace)
    }

    /// Nối các dòng (đã bỏ khoảng trắng hai đầu) theo quy tắc txt của import.md: dòng trống tách đoạn (giữ là
    /// `\n\n`), các dòng của một đoạn nối bằng một dấu cách, dòng kết thúc bằng `-` liền sau chữ (không phải
    /// khoảng trắng) nối liền không dấu cách (`Cross-` + `Region` → `Cross-Region`).
    static func joinLines(_ lines: [String]) -> String {
        var paragraphs: [String] = []
        var current = ""
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current) }
                current = ""
            } else if current.isEmpty {
                current = line
            } else if endsWithJoiningHyphen(current) {
                current += line
            } else {
                current += " " + line
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func endsWithJoiningHyphen(_ s: String) -> Bool {
        guard s.hasSuffix("-") else { return false }
        let beforeHyphen = s.dropLast().last
        return beforeHyphen.map { !$0.isWhitespace && $0 != "-" } ?? false
    }

    // MARK: - Markdown

    /// Cách app hiển thị Markdown cơ bản (`MarkdownText` của SessionFeature): chỉ cú pháp inline, giữ khoảng trắng.
    private static let markdownOptions = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace,
        failurePolicy: .returnPartiallyParsedIfPossible
    )

    /// Ký tự ASCII có thể mở cú pháp inline; thoát bằng `\` (CommonMark cho thoát mọi dấu câu ASCII).
    private static let markdownSpecials: Set<Character> = ["\\", "`", "*", "_", "[", "]", "<", ">", "~", "&"]

    /// `true` nếu văn bản trơn hiển thị khác đi khi đọc như Markdown (ví dụ `*a*` thành chữ nghiêng, `&amp;`
    /// thành `&`), tức cần thoát ký tự.
    static func needsMarkdownEscaping(_ plain: String) -> Bool {
        guard plain.contains(where: markdownSpecials.contains) else { return false }
        guard let rendered = try? AttributedString(markdown: plain, options: markdownOptions) else { return true }
        return String(rendered.characters) != plain
    }

    /// Thoát mọi ký tự đặc biệt của Markdown inline.
    static func escapeMarkdown(_ plain: String) -> String {
        var out = ""
        out.reserveCapacity(plain.count)
        for c in plain {
            if markdownSpecials.contains(c) { out.append("\\") }
            out.append(c)
        }
        return out
    }

    /// Văn bản trơn → Markdown hiển thị đúng như văn bản gốc. Chỉ thoát khi cần, để chuỗi trong trình soạn đề
    /// giữ nguyên dạng đọc được (`s3:*`, `snake_case` không bị chèn `\`).
    static func markdown(fromPlain plain: String) -> String {
        needsMarkdownEscaping(plain) ? escapeMarkdown(plain) : plain
    }
}
