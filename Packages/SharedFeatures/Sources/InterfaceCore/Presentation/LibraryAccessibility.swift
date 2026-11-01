import Foundation
import LibraryData

/// Chuỗi cho VoiceOver (docs/product/library.md, mục Bàn phím và trợ năng).
public enum LibraryAccessibility {
    /// Câu VoiceOver đọc cho một thẻ đề: tiêu đề, nhãn đề mẫu, mã, số câu, trạng thái kèm lý do (nếu có),
    /// lần thi gần nhất. Ví dụ: "Kiến thức chung, đề mẫu, mã KTC01, 12 câu, File hỏng: File không phải gói
    /// zip hợp lệ. Lần thi gần nhất: 80%, Đậu, ngày 15/10/2026." `locale`/`timeZone` (để test cố định được) chỉ áp
    /// cho phần trăm và ngày; số câu theo `InterfaceLocale.current`.
    public static func cardSummary(
        entry: LibraryEntry,
        latestAttempt: Attempt?,
        isAdmin: Bool,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var parts = [entry.title]
        if entry.isSample {
            parts.append(localized("đề mẫu"))
        }
        if let code = entry.code, !code.isEmpty {
            parts.append(localized("mã \(code)"))
        }
        parts.append(LibraryFormat.questions(entry.summary.questionCount))
        let status = EntryStatusPresentation(status: entry.status, isAdmin: isAdmin)
        parts.append(status.title)
        var head = parts.joined(separator: ", ")
        if let detail = status.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            head += ": " + (detail.hasSuffix(".") ? String(detail.dropLast()) : detail)
        }
        head += "."
        guard let attempt = latestAttempt else {
            return head + " " + localized("Chưa thi lần nào.")
        }
        let percent = LibraryFormat.percent(attempt.percent, locale: locale)
        let result = LibraryFormat.result(passed: attempt.passed)
        let date = LibraryFormat.date(attempt.submittedAt, locale: locale, timeZone: timeZone)
        return head + " " + localized("Lần thi gần nhất: \(percent), \(result), ngày \(date).")
    }

    /// Chữ VoiceOver của từng ô một dòng **Lịch sử thi**, theo thứ tự cột (VoiceOver đọc dòng của bảng bằng chữ các ô;
    /// accessibility-localization.md, Mục tiêu phủ theo màn: ngày giờ, đề, thí sinh, chế độ, điểm, đậu/trượt): ngày giờ, tên
    /// đề, thí sinh, chế độ, điểm %, thang 1000 ("850/1000": ô chỉ hiện "850"), Đậu/Trượt (chữ, không chỉ biểu tượng), thời
    /// gian làm bằng chữ. `locale`/`timeZone` (để test cố định được) chỉ áp cho ngày giờ và phần trăm.
    public static func historyRowCells(
        _ attempt: Attempt,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> [String] {
        [
            LibraryFormat.dateTime(attempt.submittedAt, locale: locale, timeZone: timeZone),
            attempt.examTitle,
            attempt.candidateName,
            LibraryFormat.mode(attempt.mode),
            LibraryFormat.percent(attempt.percent, locale: locale),
            scale1000Label(attempt.score1000),
            LibraryFormat.result(passed: attempt.passed),
            LibraryFormat.duration(seconds: attempt.elapsedSeconds),
        ]
    }

    /// Ô **Thang 1000** đọc kèm thang: "850/1000" (số trơn ở mọi ngôn ngữ, `InterfaceLocale.scale1000`).
    public static func scale1000Label(_ value: Int) -> String {
        localized("\(InterfaceLocale.scale1000(value))/1000")
    }
}
