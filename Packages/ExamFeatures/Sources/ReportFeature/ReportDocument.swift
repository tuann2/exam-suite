import Foundation

/// Tài liệu báo cáo thuần (không SwiftUI): siêu dữ liệu, chân trang và danh sách khối theo thứ tự đọc
/// (docs/product/export-print.md, mục "Cách làm"). Mọi quy tắc ẩn/hiện đã áp dụng **trước** khi dựng tài liệu
/// (PDF kết quả: `ResultsReport`, dựng từ Kết quả/Xem lại của SessionFeature; PDF đề: giai đoạn 5 bước 6). Bộ dựng
/// trang (`ReportRenderer`) chỉ vẽ đúng những gì có ở đây.
public struct ReportDocument: Sendable, Hashable {
    public var metadata: ReportMetadata
    public var footer: ReportFooter
    public var blocks: [ReportBlock]

    public init(metadata: ReportMetadata, footer: ReportFooter, blocks: [ReportBlock]) {
        self.metadata = metadata
        self.footer = footer
        self.blocks = blocks
    }
}

/// Siêu dữ liệu PDF: Title, Creator. Không ghi tên máy hay đường dẫn file.
public struct ReportMetadata: Sendable, Hashable {
    /// Ví dụ "Kiến thức chung – Kết quả".
    public var title: String
    /// "Exam Suite <phiên bản>".
    public var creator: String

    public init(title: String, creator: String) {
        self.title = title
        self.creator = creator
    }
}

/// Chân trang mỗi trang: dòng đầu là `title` (cắt nếu dài) và "Trang N/M" (bộ dựng trang điền), rồi các dòng
/// `lines` (ví dụ dòng lưu ý "Kết quả luyện tập, không có giá trị xác nhận").
public struct ReportFooter: Sendable, Hashable {
    public var title: String
    public var lines: [String]

    public init(title: String, lines: [String]) {
        self.title = title
        self.lines = lines
    }
}

/// Một cặp nhãn – giá trị (Thí sinh, Mã đề…).
public struct ReportField: Sendable, Hashable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

/// Biểu tượng (SF Symbol) đi kèm chữ: đúng/sai/đánh dấu luôn có ký hiệu + chữ để in đen trắng vẫn đọc được.
public struct ReportBadge: Sendable, Hashable {
    public var title: String
    public var systemImage: String

    public init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }
}

/// Khối của tài liệu. Mỗi khối ưu tiên nằm trọn một trang; khối cao hơn một trang được tách giữa các phần (đoạn,
/// ảnh, lựa chọn, giải thích, dòng bảng), phần sang trang mới mở bằng dòng "(tiếp)".
public enum ReportBlock: Sendable, Hashable {
    /// Đầu trang đầu: tiêu đề lớn, dòng phụ, các cặp nhãn – giá trị, hướng dẫn (Markdown).
    case title(ReportTitle)
    /// Kết quả: Đậu/Trượt, điểm, thanh điểm có vạch ngưỡng đậu, so với lần trước.
    case resultSummary(ReportResultSummary)
    /// Bảng Theo phần.
    case sectionScores(ReportSectionScores)
    /// Đề mục (không đứng một mình cuối trang: luôn đi cùng phần đầu của khối sau).
    case heading(ReportHeading)
    /// Một dòng báo (biểu tượng + chữ).
    case notice(ReportNotice)
    /// Một câu hỏi (xem lại bài hoặc đề).
    case question(ReportQuestion)
}

public struct ReportTitle: Sendable, Hashable {
    public var title: String
    public var subtitle: String?
    public var fields: [ReportField]
    /// Markdown cơ bản.
    public var instructions: String?

    public init(title: String, subtitle: String? = nil, fields: [ReportField] = [], instructions: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.fields = fields
        self.instructions = instructions
    }
}

public struct ReportResultSummary: Sendable, Hashable {
    /// "Đậu" / "Trượt" kèm biểu tượng.
    public var verdict: ReportBadge
    /// "72% · 720/1000".
    public var scoreText: String
    /// Thanh điểm 0…1.
    public var scoreFraction: Double
    /// Vạch ngưỡng đậu 0…1; nil khi không có chi tiết lần thi.
    public var passThresholdFraction: Double?
    /// Các dòng dưới điểm: số câu đúng, ngưỡng đậu…
    public var fields: [ReportField]
    /// "So với lần trước: +8%" kèm biểu tượng; nil thì không có dòng này.
    public var comparison: ReportBadge?
    /// Dòng báo (ví dụ "Không đọc được chi tiết lần thi này").
    public var notices: [ReportNotice]

    public init(
        verdict: ReportBadge,
        scoreText: String,
        scoreFraction: Double,
        passThresholdFraction: Double?,
        fields: [ReportField],
        comparison: ReportBadge?,
        notices: [ReportNotice]
    ) {
        self.verdict = verdict
        self.scoreText = scoreText
        self.scoreFraction = scoreFraction
        self.passThresholdFraction = passThresholdFraction
        self.fields = fields
        self.comparison = comparison
        self.notices = notices
    }
}

public struct ReportSectionScores: Sendable, Hashable {
    public struct Row: Sendable, Hashable {
        public var title: String
        /// "4/5 · 80%" hoặc "Không có câu".
        public var detail: String
        /// Tỉ lệ cho thanh; nil với phần 0/0 (không có thanh).
        public var fraction: Double?
        /// Nhãn "Phần yếu nhất" (biểu tượng + chữ); nil nếu không phải.
        public var mark: ReportBadge?

        public init(title: String, detail: String, fraction: Double?, mark: ReportBadge?) {
            self.title = title
            self.detail = detail
            self.fraction = fraction
            self.mark = mark
        }
    }

    public var title: String
    public var rows: [Row]

    public init(title: String, rows: [Row]) {
        self.title = title
        self.rows = rows
    }
}

public struct ReportHeading: Sendable, Hashable {
    public var title: String
    public var detail: String?

    public init(title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }
}

public struct ReportNotice: Sendable, Hashable {
    public var text: String
    public var systemImage: String

    public init(text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }
}

/// Một câu hỏi. Mọi đánh dấu (Bạn chọn, Đáp án đúng, giải thích) đã được lọc theo quy tắc ẩn/hiện trước khi
/// tới đây; khối chỉ vẽ cái nó có.
public struct ReportQuestion: Sendable, Hashable {
    /// Số câu cho dòng "Câu 12 (tiếp)" khi khối bị tách sang trang sau.
    public var number: Int
    /// Tên phần (in nhạt trước số câu).
    public var sectionTitle: String
    /// "Câu 12/60".
    public var positionText: String
    /// Đúng / Sai / Chưa làm (xem lại bài); nil với PDF đề.
    public var status: ReportBadge?
    /// "Đã đánh dấu".
    public var flag: ReportBadge?
    /// Dòng báo trên câu (đã xoá, đã sửa sau lần thi, đề ẩn đáp án).
    public var notices: [ReportNotice]
    /// Nội dung (Markdown cơ bản); nil khi câu đã bị xoá khỏi đề.
    public var text: String?
    public var image: ReportImageSource?
    /// Gợi ý "Chọn N đáp án".
    public var hint: String?
    public var options: [ReportOption]
    /// Giải thích (Markdown cơ bản); nil khi không có hoặc bị ẩn.
    public var explanation: String?

    public init(
        number: Int,
        sectionTitle: String,
        positionText: String,
        status: ReportBadge? = nil,
        flag: ReportBadge? = nil,
        notices: [ReportNotice] = [],
        text: String?,
        image: ReportImageSource? = nil,
        hint: String? = nil,
        options: [ReportOption],
        explanation: String? = nil
    ) {
        self.number = number
        self.sectionTitle = sectionTitle
        self.positionText = positionText
        self.status = status
        self.flag = flag
        self.notices = notices
        self.text = text
        self.image = image
        self.hint = hint
        self.options = options
        self.explanation = explanation
    }
}

/// Ảnh của câu: byte trong gói đề, hoặc thiếu (câu có ảnh mà gói không có byte).
public enum ReportImageSource: Sendable, Hashable {
    case data(Data)
    case missing
}

/// Một lựa chọn, nhãn A, B, C… theo vị trí đã hiện. `marks`: "Bạn chọn", "Đáp án đúng" (ký hiệu + chữ).
public struct ReportOption: Sendable, Hashable {
    public var label: String
    /// Markdown cơ bản.
    public var text: String
    public var marks: [ReportBadge]
    /// Viền đậm (lựa chọn có đánh dấu).
    public var isEmphasized: Bool

    public init(label: String, text: String, marks: [ReportBadge] = []) {
        self.label = label
        self.text = text
        self.marks = marks
        isEmphasized = !marks.isEmpty
    }
}
