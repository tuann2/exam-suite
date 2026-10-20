import ExamKit
import Foundation
import LibraryFeature

/// Chuỗi hiển thị tiếng Việt của phiên thi (docs/product/exam-taking.md). Số, phần trăm và ngày giờ (lịch Gregorian)
/// theo locale của ngôn ngữ giao diện (`InterfaceLocale.current`, không theo Region của macOS); `dateTime` nhận
/// `locale`/`timeZone` truyền vào để test cố định được (múi giờ mặc định theo máy).
///
/// "Luyện tập"/"Thi" và "Đậu"/"Trượt" trùng chữ với Lịch sử thi (`LibraryFormat` của LibraryFeature);
/// viết lại ở đây để model trình bày của phiên thi (có test riêng) không dựa vào phần giao diện Thư viện.
public enum SessionFormat {
    public static func mode(_ mode: SessionMode) -> String {
        switch mode {
        case .practice: localized("Luyện tập")
        case .exam: localized("Thi")
        }
    }

    /// Kết quả bằng chữ, luôn đi kèm `resultSymbol` (không chỉ dựa vào màu).
    public static func result(passed: Bool) -> String {
        passed ? localized("Đậu") : localized("Trượt")
    }

    public static func resultSymbol(passed: Bool) -> String {
        passed ? "checkmark.seal.fill" : "xmark.seal.fill"
    }

    /// Phần trăm: "72%", theo ngôn ngữ giao diện (`FormatStyle`, không ghép dấu `%` tay).
    public static func percent(_ value: Int) -> String {
        InterfaceLocale.percent(value)
    }

    /// Số nguyên có ngăn nghìn theo ngôn ngữ giao diện ("1.234" ở giao diện tiếng Việt), cho số đứng một mình hay ghép
    /// với ký hiệu ("1.234/2.000") mà không cần khoá trong catalog.
    public static func number(_ value: Int) -> String {
        InterfaceLocale.number(value)
    }

    /// Đồng hồ: `mm:ss`, từ 60 phút trở lên `h:mm:ss`.
    public static func clock(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let rest = total % 60
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        if hours > 0 { return "\(hours):\(two(minutes)):\(two(rest))" }
        return "\(two(minutes)):\(two(rest))"
    }

    /// Thời lượng bằng chữ: "1 giờ 5 phút", "12 phút 5 giây", "45 giây" (làm tròn tới giây).
    public static func duration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let rest = total % 60
        if hours > 0 {
            return minutes > 0
                ? localized("\(hours) giờ \(minutes) phút")
                : localized("\(hours) giờ")
        }
        if minutes > 0 {
            return rest > 0
                ? localized("\(minutes) phút \(rest) giây")
                : localized("\(minutes) phút")
        }
        return localized("\(rest) giây")
    }

    public static func minutes(_ count: Int) -> String {
        localized("\(count) phút")
    }

    /// Ngày giờ dạng số: "14:05 15/10/2026" (giao diện tiếng Việt), "10/15/2026, 2:05 PM" (tiếng Anh).
    public static func dateTime(
        _ date: Date,
        locale: Locale = InterfaceLocale.current,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        date.formatted(Date.FormatStyle(
            date: .numeric, time: .shortened, locale: locale, calendar: InterfaceLocale.calendar, timeZone: timeZone
        ))
    }

    /// Chênh lệch điểm % so với lần trước: "+8%", "−5%" (dấu trừ U+2212), "bằng".
    public static func percentDelta(_ delta: Int) -> String {
        if delta > 0 { return localized("+\(percent(delta))") }
        if delta < 0 { return localized("−\(percent(-delta))") }
        return localized("bằng")
    }

    /// Nhãn lựa chọn theo vị trí hiển thị: 0 → "A", 1 → "B"…
    public static func optionLabel(position: Int) -> String {
        OptionID(index: position)?.description ?? "\(position + 1)"
    }
}
