import ExamFile
import ExamKit
import Foundation

/// Thông tin thẻ đề (docs/product/library.md, mục Thẻ đề), lấy từ lần gần nhất đọc được file.
/// Được lưu trong kho để thư viện hiện ngay khi mở app, trước khi kiểm xong file.
public struct ExamSummary: Hashable, Sendable {
    public var title: String
    public var code: String?
    public var questionCount: Int
    public var sectionCount: Int
    /// Số ảnh trong gói (`ExamPackage.media`).
    public var imageCount: Int
    public var timeLimitMinutes: Int
    /// Ngưỡng đậu, % (docs/product/scoring.md).
    public var passPercent: Int
    public var hideAnswers: Bool
    /// `formatVersion` của đề sau khi đọc. Đề cũ được chuyển lên phiên bản app hiểu nên khi có
    /// chuyển đổi, giá trị là phiên bản hiện tại; ở v1 bằng đúng giá trị trong file.
    public var formatVersion: Int

    public init(
        title: String,
        code: String? = nil,
        questionCount: Int,
        sectionCount: Int,
        imageCount: Int = 0,
        timeLimitMinutes: Int,
        passPercent: Int,
        hideAnswers: Bool = false,
        formatVersion: Int = ExamFileFormat.currentVersion
    ) {
        self.title = title
        self.code = code
        self.questionCount = questionCount
        self.sectionCount = sectionCount
        self.imageCount = imageCount
        self.timeLimitMinutes = timeLimitMinutes
        self.passPercent = passPercent
        self.hideAnswers = hideAnswers
        self.formatVersion = formatVersion
    }

    public init(package: ExamPackage) {
        let exam = package.exam
        self.init(
            title: exam.title,
            code: exam.code,
            questionCount: exam.questionCount,
            sectionCount: exam.sections.count,
            imageCount: package.media.count,
            timeLimitMinutes: exam.timeLimitMinutes,
            passPercent: exam.passPercent,
            hideAnswers: exam.hideAnswers,
            formatVersion: exam.formatVersion
        )
    }
}

/// Vì sao một file đề không dùng được như bình thường. Lý do dạng mã (`FileProblemReason`); giao diện dựng câu báo
/// bằng chữ của catalog (LibraryFeature).
public enum LibraryFileProblem: Hashable, Sendable {
    /// Không đọc được gói kể cả ở chế độ dễ: zip hỏng, thiếu `exam.json`, JSON sai, quá lớn…
    case corrupt(reason: FileProblemReason)
    /// `formatVersion` lớn hơn phiên bản app hiểu.
    case needsNewerApp(found: Int, supported: Int)
    /// Đọc dễ được nhưng đọc nghiêm thất bại (lỗi kiểm tra, trường lạ, thiếu ảnh…): bản Học viên
    /// từ chối đề này.
    case invalid(reason: FileProblemReason)

    /// Câu tiếng Việt cho nhật ký và test (giao diện không dùng).
    public var logMessage: String {
        switch self {
        case let .corrupt(reason), let .invalid(reason):
            reason.logMessage
        case let .needsNewerApp(found, supported):
            FileProblemReason.package(.unsupportedVersion(found: found, supported: supported)).logMessage
        }
    }
}

/// Trạng thái của một mục thư viện (bảng trạng thái trong docs/product/library.md).
public enum LibraryEntryStatus: Hashable, Sendable {
    /// Sẵn sàng: file đọc được theo chế độ của bản app.
    case ready
    /// Đang kiểm tra: chưa có kết quả đọc file trong lần chạy app này.
    case checking
    /// Không tìm thấy file: bookmark không phân giải được, file đã xoá (kể cả nằm trong Thùng rác),
    /// ở ổ chưa gắn, hoặc vị trí cũ giờ chứa một đề khác. Bước tiếp: **Tìm file…** (`relocate`).
    case missing
    /// File hỏng: không đọc được gói.
    case corrupt(reason: FileProblemReason)
    /// Cần app mới hơn: `formatVersion` lớn hơn app hiểu.
    case needsNewerApp(found: Int, supported: Int)
    /// Đề có lỗi (bản Học viên): đọc nghiêm thất bại.
    case invalid(reason: FileProblemReason)
    /// Có lỗi (bản Admin): đọc dễ được nhưng bản Học viên sẽ từ chối; `reason` là lý do bản Học viên từ chối.
    case readableWithIssues(reason: FileProblemReason)

    /// Thuộc bộ lọc **Sẵn sàng**.
    public var isReady: Bool { self == .ready }

    /// Thuộc bộ lọc **Có vấn đề**: mọi trạng thái trừ Sẵn sàng và Đang kiểm tra.
    public var hasProblem: Bool {
        switch self {
        case .ready, .checking: false
        case .missing, .corrupt, .needsNewerApp, .invalid, .readableWithIssues: true
        }
    }

    /// Lý do kèm trạng thái, dạng mã; `nil` với Sẵn sàng, Đang kiểm tra, Không tìm thấy file. Cần app mới hơn là lỗi
    /// phiên bản của ExamFile.
    public var reason: FileProblemReason? {
        switch self {
        case .ready, .checking, .missing:
            nil
        case let .corrupt(reason), let .invalid(reason), let .readableWithIssues(reason):
            reason
        case let .needsNewerApp(found, supported):
            .package(.unsupportedVersion(found: found, supported: supported))
        }
    }
}

/// Một mục thư viện ở dạng giá trị cho giao diện (không lộ model SwiftData).
public struct LibraryEntry: Identifiable, Hashable, Sendable {
    /// Mỗi id đề chỉ có một mục trong thư viện, nên id của mục chính là id đề.
    public var id: UUID { examID }
    public let examID: UUID
    public var summary: ExamSummary
    /// Đường dẫn file theo lần phân giải bookmark gần nhất (Thông tin, Hiện trong Finder, Sửa).
    public var fileURL: URL
    /// Dung lượng file (byte) ở lần đọc gần nhất.
    public var fileSize: Int64?
    /// Ngày sửa đổi file ở lần đọc gần nhất.
    public var fileModificationDate: Date?
    /// Đề mẫu do app tạo (docs/product/library.md, mục Đề mẫu).
    public var isSample: Bool
    public var addedAt: Date
    public var lastOpenedAt: Date?
    public var status: LibraryEntryStatus

    public init(
        examID: UUID,
        summary: ExamSummary,
        fileURL: URL,
        fileSize: Int64? = nil,
        fileModificationDate: Date? = nil,
        isSample: Bool = false,
        addedAt: Date,
        lastOpenedAt: Date? = nil,
        status: LibraryEntryStatus
    ) {
        self.examID = examID
        self.summary = summary
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.fileModificationDate = fileModificationDate
        self.isSample = isSample
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.status = status
    }

    public var title: String { summary.title }
    public var code: String? { summary.code }
}
