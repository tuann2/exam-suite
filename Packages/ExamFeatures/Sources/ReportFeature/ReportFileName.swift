import Foundation

/// Tên file gợi ý cho hộp lưu PDF (docs/product/export-print.md, mục Tên file và hộp lưu, phương án 10).
///
/// Tên dài thì **cắt tên đề trước**: thí sinh và thời điểm nộp giữ nguyên để hai lần thi của cùng đề không trùng tên;
/// tên thí sinh chỉ bị cắt khi riêng nó đã quá dài. Cả tên (trước `.pdf`) không quá 120 ký tự và cả tên file không quá
/// 255 byte UTF-8 (giới hạn của APFS).
public enum ReportFileName {
    /// Số ký tự tối đa của tên (trước đuôi `.pdf`).
    public static let maxLength = 120
    /// Số byte UTF-8 tối đa của cả tên file, kể cả `.pdf`.
    public static let maxBytes = 255
    /// Số ký tự tối đa của tên thí sinh trong tên file (chỉ cắt khi riêng tên thí sinh đã dài hơn).
    static let maxCandidateLength = 40
    static let fileExtension = ".pdf"

    /// Kết quả: `<Tên đề> - <Thí sinh> - <yyyy-MM-dd HHmm>.pdf` (thời điểm nộp, theo múi giờ của máy).
    public static func results(
        examTitle: String,
        candidateName: String,
        submittedAt: Date,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter() // l10n-ignore: tên file dạng cố định yyyy-MM-dd HHmm, en_US_POSIX
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        let candidate = truncated(clean(candidateName), maxLength: maxCandidateLength, maxBytes: 4 * maxCandidateLength)
        let date = formatter.string(from: submittedAt)
        return fileName(title: examTitle) { title in
            ([title, candidate].filter { !$0.isEmpty } + [date]).joined(separator: " - ")
        }
    }

    /// Đề: `<Tên đề> (có đáp án).pdf` hoặc `<Tên đề> (đề).pdf` (chữ theo catalog).
    public static func exam(title: String, withAnswers: Bool) -> String {
        fileName(title: title) { title in
            withAnswers ? ReportStrings.examFileWithAnswers(title) : ReportStrings.examFileQuestionsOnly(title)
        }
    }

    /// Chuẩn hoá NFC, bỏ `/` và `:`, đổi ký tự điều khiển và khoảng trắng liên tiếp thành một khoảng trắng, bỏ khoảng
    /// trắng hai đầu.
    public static func clean(_ text: String) -> String {
        let nfc = text.precomposedStringWithCanonicalMapping
        var result = ""
        var pendingSpace = false
        for character in nfc {
            if character == "/" || character == ":" { continue }
            let isBlank = character.unicodeScalars.allSatisfy {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
            }
            if isBlank {
                pendingSpace = !result.isEmpty
                continue
            }
            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(character)
        }
        return result
    }

    /// Tên file từ `compose(tên đề)`: tên đề được cắt (ở ranh giới ký tự, không tách dấu khỏi chữ) tới khi cả tên vừa
    /// giới hạn; tên đề rỗng hoặc phần còn lại vẫn quá dài thì cắt cả chuỗi. Rỗng thì dùng "Exam Suite".
    static func fileName(title rawTitle: String, compose: (String) -> String) -> String {
        var title = clean(rawTitle)
        func fits(_ base: String) -> Bool {
            base.count <= maxLength && base.utf8.count + fileExtension.utf8.count <= maxBytes
        }
        var base = clean(compose(title))
        while !fits(base), !title.isEmpty {
            title = String(title.dropLast()).trimmingCharacters(in: .whitespaces)
            base = clean(compose(title))
        }
        base = truncated(base, maxLength: maxLength, maxBytes: maxBytes - fileExtension.utf8.count)
        if base.isEmpty { base = "Exam Suite" }
        return base + fileExtension
    }

    /// Cắt ở ranh giới ký tự cho tới khi không quá `maxLength` ký tự và `maxBytes` byte UTF-8; bỏ khoảng trắng cuối.
    static func truncated(_ text: String, maxLength: Int, maxBytes: Int) -> String {
        var result = String(text.prefix(maxLength))
        while result.utf8.count > maxBytes { result.removeLast() }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
