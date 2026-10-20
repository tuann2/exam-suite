import ExamKit
import Foundation
import LibraryData

/// Chuỗi hiển thị tiếng Việt dùng chung cho thẻ, bảng, Thông tin, Lịch sử thi và câu đọc của VoiceOver.
/// Số, phần trăm, ngày giờ (lịch Gregorian) và dung lượng theo locale của ngôn ngữ giao diện (`InterfaceLocale.current`,
/// không theo Region của macOS). Tham số `locale`/`timeZone` (để test cố định được; múi giờ mặc định theo máy) chỉ áp cho
/// ngày giờ, phần trăm và dung lượng; số trong chữ qua catalog (`questions`, `duration`…) luôn theo
/// `InterfaceLocale.current`, cùng ngôn ngữ với chữ.
public enum LibraryFormat {
    public static func questions(_ count: Int) -> String {
        localized("\(count) câu")
    }

    public static func sections(_ count: Int) -> String {
        localized("\(count) phần")
    }

    public static func images(_ count: Int) -> String {
        localized("\(count) ảnh")
    }

    public static func minutes(_ count: Int) -> String {
        localized("\(count) phút")
    }

    /// Ngưỡng đậu, ví dụ "Đậu từ 70%".
    public static func passThreshold(_ percent: Int) -> String {
        localized("Đậu từ \(Self.percent(percent))")
    }

    /// Phần trăm (điểm, ngưỡng đậu): "80%", theo ngôn ngữ giao diện (`FormatStyle`, không ghép dấu `%` tay).
    public static func percent(_ value: Int, locale: Locale = InterfaceLocale.current) -> String {
        InterfaceLocale.percent(value, locale: locale)
    }

    /// Số câu · số phần · thời gian · ngưỡng đậu, một dòng trên thẻ.
    public static func facts(_ summary: ExamSummary) -> String {
        [
            questions(summary.questionCount),
            sections(summary.sectionCount),
            minutes(summary.timeLimitMinutes),
            passThreshold(summary.passPercent),
        ].joined(separator: " · ")
    }

    /// Chế độ của lần thi: "Luyện tập" hoặc "Thi".
    public static func mode(_ mode: SessionMode) -> String {
        switch mode {
        case .practice: localized("Luyện tập")
        case .exam: localized("Thi")
        }
    }

    /// Kết quả bằng chữ (luôn đi kèm `resultSymbol`, không chỉ dựa vào màu).
    public static func result(passed: Bool) -> String {
        passed ? localized("Đậu") : localized("Trượt")
    }

    public static func resultSymbol(passed: Bool) -> String {
        passed ? "checkmark.seal.fill" : "xmark.seal.fill"
    }

    /// Thời gian làm bài: "1 giờ 5 phút", "12 phút 5 giây", "45 giây" (làm tròn tới giây).
    public static func duration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let remainder = total % 60
        if hours > 0 {
            return minutes > 0
                ? localized("\(hours) giờ \(minutes) phút")
                : localized("\(hours) giờ")
        }
        if minutes > 0 {
            return remainder > 0
                ? localized("\(minutes) phút \(remainder) giây")
                : localized("\(minutes) phút")
        }
        return localized("\(remainder) giây")
    }

    /// Ngày dạng số, ví dụ 15/10/2026 (giao diện tiếng Việt), 10/15/2026 (tiếng Anh).
    public static func date(
        _ date: Date,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        date.formatted(Date.FormatStyle(
            date: .numeric, time: .omitted, locale: locale, calendar: InterfaceLocale.calendar, timeZone: timeZone
        ))
    }

    /// Ngày giờ dạng số, ví dụ 14:05 15/10/2026 (giao diện tiếng Việt), 10/15/2026, 2:05 PM (tiếng Anh).
    public static func dateTime(
        _ date: Date,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        date.formatted(Date.FormatStyle(
            date: .numeric, time: .shortened, locale: locale, calendar: InterfaceLocale.calendar, timeZone: timeZone
        ))
    }

    /// Dung lượng file kiểu Finder ("13 KB"); không biết thì "Chưa rõ".
    public static func fileSize(_ bytes: Int64?, locale: Locale = InterfaceLocale.current) -> String {
        guard let bytes else { return localized("Chưa rõ") }
        return bytes.formatted(ByteCountFormatStyle(style: .file, locale: locale))
    }

    /// Lần thi gần nhất trên thẻ: "80% · 15/10/2026 · Đậu", hoặc "Chưa thi lần nào".
    public static func lastAttempt(
        _ attempt: Attempt?,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        guard let attempt else { return localized("Chưa thi lần nào") }
        return [
            percent(attempt.percent, locale: locale),
            date(attempt.submittedAt, locale: locale, timeZone: timeZone),
            result(passed: attempt.passed),
        ].joined(separator: " · ")
    }
}
