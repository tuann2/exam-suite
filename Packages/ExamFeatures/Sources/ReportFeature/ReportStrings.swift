import Foundation

/// Chữ giao diện của báo cáo PDF, qua `localized(_:)` (String Catalog của ReportFeature). Nhãn theo ngôn ngữ giao
/// diện của app; nội dung đề giữ nguyên (docs/product/export-print.md, mục Trình bày chung).
public enum ReportStrings {
    /// "Trang 2/5".
    public static func page(_ number: Int, of count: Int) -> String {
        localized("Trang \(number)/\(count)")
    }

    /// "Câu 12/60".
    public static func questionPosition(_ number: Int, of total: Int) -> String {
        localized("Câu \(number)/\(total)")
    }

    /// "Câu 12 (tiếp)": đầu phần của khối câu bị tách sang trang sau.
    public static func questionContinued(_ number: Int) -> String {
        localized("Câu \(number) (tiếp)")
    }

    /// Dưới nhãn của mảnh sau khi một lựa chọn quá dài bị tách sang trang sau.
    public static var optionContinued: String {
        localized("(tiếp)")
    }

    /// "Theo phần (tiếp)" và mọi khối khác bị tách.
    public static func continued(_ title: String) -> String {
        localized("\(title) (tiếp)")
    }

    /// "Exam Suite 1.0" (Creator của PDF).
    public static func creator(version: String) -> String {
        localized("Exam Suite \(version)")
    }

    /// Dòng lưu ý ở chân trang PDF kết quả (export-print.md phương án 5).
    public static var resultsDisclaimer: String {
        localized("Kết quả luyện tập, không có giá trị xác nhận")
    }

    /// Tiêu đề PDF kết quả: "Kiến thức chung – Kết quả".
    public static func resultsDocumentTitle(_ examTitle: String) -> String {
        localized("\(examTitle) – Kết quả")
    }

    public static var resultsSubtitle: String {
        localized("Kết quả")
    }

    public static var passThreshold: String {
        localized("Ngưỡng đậu")
    }

    public static var sectionsTitle: String {
        localized("Theo phần")
    }

    public static var weakestSection: String {
        localized("Phần yếu nhất")
    }

    public static var reviewTitle: String {
        localized("Xem lại bài")
    }

    public static var selected: String {
        localized("Bạn chọn")
    }

    public static var correctAnswer: String {
        localized("Đáp án đúng")
    }

    public static var flagged: String {
        localized("Đã đánh dấu")
    }

    public static var explanation: String {
        localized("Giải thích")
    }

    public static var answersHiddenNote: String {
        localized("Đề này ẩn đáp án: chỉ hiện lựa chọn của bạn và kết quả đúng/sai.")
    }

    public static var imageUnavailable: String {
        localized("Không hiện được ảnh của câu này")
    }

    public static var noQuestions: String {
        localized("Không có câu nào.")
    }

    public static var noIncorrectOrUnanswered: String {
        localized("Không có câu sai hoặc chưa làm.")
    }

    /// "5 câu".
    public static func questionCount(_ count: Int) -> String {
        localized("\(count) câu")
    }

    /// Tiến độ khi đo và xếp khối.
    public static var preparing: String {
        localized("Đang chuẩn bị trang…")
    }

    /// "Đang dựng trang 3…".
    public static func drawingPage(_ number: Int) -> String {
        localized("Đang dựng trang \(number)…")
    }

    // MARK: - Mức xem lại (export-print.md phương án 3)

    public static var reviewLevelNone: String {
        localized("Không")
    }

    public static var reviewLevelIncorrectAndUnanswered: String {
        localized("Câu sai và chưa làm")
    }

    public static var reviewLevelAll: String {
        localized("Tất cả câu")
    }

    // MARK: - Lỗi ghi, lỗi in (export-print.md: "lỗi ghi thì báo lý do")

    public static var writeNoPermission: String {
        localized("Không có quyền ghi vào thư mục đã chọn.")
    }

    public static var writeOutOfSpace: String {
        localized("Ổ đĩa không còn đủ chỗ trống.")
    }

    public static var writeReadOnlyVolume: String {
        localized("Ổ đĩa đã chọn chỉ đọc.")
    }

    public static var writeFolderMissing: String {
        localized("Không tìm thấy thư mục đã chọn.")
    }

    public static var writeUnreadableOutput: String {
        localized("File PDF vừa ghi bị lỗi, có thể do ổ đĩa đầy.")
    }

    public static var writeFailed: String {
        localized("Không ghi được file PDF.")
    }

    /// Không tạo được thao tác In từ PDF đã dựng.
    public static var printUnavailable: String {
        localized("Không chuẩn bị được bản in.")
    }

    // MARK: - Tên file (export-print.md phương án 10)

    /// Hậu tố tên file PDF đề có đáp án: "Kiến thức chung (có đáp án)".
    public static func examFileWithAnswers(_ title: String) -> String {
        localized("\(title) (có đáp án)")
    }

    /// "Kiến thức chung (đề)".
    public static func examFileQuestionsOnly(_ title: String) -> String {
        localized("\(title) (đề)")
    }
}
