import ExamKit
import Foundation

/// Nội dung đã giải mã của một gói `.exam` (docs/product/exam-format.md, mục Gói).
public struct ExamPackage: Equatable, Sendable {
    public var exam: Exam
    /// Ảnh trong gói, khoá là đường dẫn đầy đủ trong zip, dạng `media/<tên>`.
    public var media: [String: Data]

    public init(exam: Exam, media: [String: Data] = [:]) {
        self.exam = exam
        self.media = media
    }

    /// Ảnh được câu hỏi tham chiếu mà không có trong `media` (hoặc tên sai mẫu
    /// `media/<hash>.<ext>`), theo thứ tự xuất hiện, không lặp. Tính từ `exam` và
    /// `media`, không lưu ra file. Bản Admin dùng để báo lỗi sau khi đọc `lenient`;
    /// đọc `strict` thì gói thiếu ảnh đã bị từ chối.
    public var missingMedia: [String] {
        var seen = Set<String>()
        var missing: [String] = []
        for image in exam.allQuestions.compactMap(\.image) where seen.insert(image).inserted {
            if !MediaNaming.isValidPath(image) || media[image] == nil { missing.append(image) }
        }
        return missing
    }

    /// Kết quả `ExamValidator` cho đề này, với tập ảnh có trong gói (`media.keys`).
    /// Tính mỗi lần gọi, không tham gia `==`. Bản Admin đọc `lenient` rồi hiện danh sách
    /// này nhưng không chặn lưu; đọc `strict` thì đề có lỗi mức `error` đã bị từ chối
    /// (`ExamFileError.validationFailed`). Ảnh thiếu xuất hiện ở đây dưới dạng
    /// `imageNotFound`/`imagePathInvalid`, đồng thời trong `missingMedia`.
    public var validationIssues: [ValidationIssue] {
        ExamValidator.validate(exam, availableMedia: Set(media.keys))
    }
}

/// Trần kích thước khi đọc gói, chống zip bomb và gói bất thường. Giá trị mặc
/// định rộng rãi so với đề thật; vượt trần → `ExamFileError.tooLarge`.
public struct ExamPackageLimits: Equatable, Sendable {
    /// Kích thước giải nén tối đa của `exam.json`, byte.
    public var manifestBytes: Int
    /// Kích thước giải nén tối đa của mỗi ảnh, byte.
    public var mediaEntryBytes: Int
    /// Tổng kích thước giải nén tối đa của các entry được nạp, byte.
    public var totalUncompressedBytes: Int
    /// Số entry tối đa trong zip (tính mọi entry, kể cả entry bị bỏ qua).
    public var entryCount: Int
    /// Số cấp object/mảng lồng nhau tối đa trong `exam.json` (gốc là cấp 1). Đề hợp lệ
    /// sâu 7 cấp (gốc → sections → section → questions → câu → options → lựa chọn); trần chặn JSON lồng sâu làm tràn stack của `JSONSerialization`.
    public var maxJSONDepth: Int

    public init(
        manifestBytes: Int = 32 << 20,
        mediaEntryBytes: Int = 50 << 20,
        totalUncompressedBytes: Int = 1 << 30,
        entryCount: Int = 20_000,
        maxJSONDepth: Int = 32
    ) {
        self.manifestBytes = manifestBytes
        self.mediaEntryBytes = mediaEntryBytes
        self.totalUncompressedBytes = totalUncompressedBytes
        self.entryCount = entryCount
        self.maxJSONDepth = maxJSONDepth
    }

    /// exam.json 32 MiB, mỗi ảnh 50 MiB, tổng giải nén 1 GiB, 20.000 entry, lồng tối đa 32 cấp.
    public static let `default` = ExamPackageLimits()

    /// Tên dùng trong `tooLarge(entry:limit:)` khi vượt trần số entry hoặc tổng dung lượng.
    public static let entryCountName = "<số entry>"
    public static let totalSizeName = "<tổng giải nén>"
}

/// Cách xử lý trường lạ khi đọc (docs/product/exam-format.md, mục Trường lạ).
public enum ReadMode: Sendable {
    /// Bản Học viên: từ chối đề có trường lạ ở bất kỳ cấp nào.
    case strict
    /// Bản Admin: bỏ qua trường lạ; khi lưu lại, file không còn trường đó.
    case lenient
}

/// Lỗi đọc/ghi gói `.exam`. `errorDescription` là câu tiếng Việt cho nhật ký, script và test; giao diện dựng câu báo
/// bằng chữ của String Catalog từ case và tham số (docs/product/accessibility-localization.md, phương án 2).
public enum ExamFileError: Error, Equatable, Hashable, Sendable {
    /// Dữ liệu không phải file zip, hoặc zip hỏng tới mức không mở được.
    case notAZipArchive
    /// Gói không có `exam.json` ở gốc.
    case missingManifest
    /// Một entry trong zip không giải nén được (sai CRC, dữ liệu nén hỏng). Tham số: đường dẫn entry.
    case corruptedEntry(String)
    /// `exam.json` không phải JSON hợp lệ hoặc không khớp cấu trúc đề. Chi tiết nêu đường dẫn khoá nếu có.
    case invalidJSON(JSONProblem)
    /// File được ghi bởi phiên bản app mới hơn.
    case unsupportedVersion(found: Int, supported: Int)
    /// `formatVersion` nhỏ hơn 1.
    case invalidVersion(Int)
    /// Chỉ ở chế độ `strict`: các trường lạ, dạng `sections[0].questions[2].hint`.
    case unknownFields([String])
    /// Chỉ ở chế độ `strict`: một object JSON có khoá lặp lại (so sau khi giải mã escape).
    /// Tham số: đường dẫn khoá trùng trong file gốc, dạng `sections[0].questions[1].text`.
    case duplicateJSONKeys([String])
    /// Chỉ ở chế độ `strict`: giá trị `null` (schema không cho `null` ở đâu cả).
    /// Tham số: đường dẫn, dạng `sections[0].questions[1].image`.
    case nullValues([String])
    /// Chỉ ở chế độ `strict`: ảnh được câu hỏi tham chiếu nhưng không có trong `media/` của gói.
    case missingMedia([String])
    /// Chỉ ở chế độ `strict`: giá trị `image` không khớp `media/<16–64 hex>.<png|jpg|jpeg|gif|webp|heic>`.
    case invalidMediaPath([String])
    /// Chỉ ở chế độ `strict`: đề vi phạm ràng buộc của `ExamValidator`. Tham số: các vấn đề
    /// mức `error`, theo thứ tự validator trả về (không gồm `warning`).
    case validationFailed([ValidationIssue])
    /// Gói có hai entry cùng tên (`exam.json` hoặc ảnh trong `media/`).
    case duplicateEntry(String)
    /// Entry (hoặc số entry / tổng dung lượng, xem `ExamPackageLimits`) vượt trần `limit`.
    case tooLarge(entry: String, limit: Int)
    /// `exam.json` lồng object/mảng sâu hơn `ExamPackageLimits.maxJSONDepth` cấp (cả hai chế độ).
    case tooDeep(limit: Int)
    /// Không chuyển được đề từ phiên bản `from` lên phiên bản kế tiếp.
    case migrationFailed(from: Int, reason: MigrationProblem)
    /// Đuôi ảnh không thuộc png, jpg, jpeg, gif, webp, heic.
    case unsupportedImageType(String)
    /// Không tạo được gói zip khi ghi.
    case writeFailed(WriteProblem)
    /// File `.oef` của Open Exam Suite không đọc được (docs/product/exam-format.md, mục File `.oef`).
    case oef(OEFProblem)
}

extension ExamFileError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAZipArchive:
            return "File không phải gói đề .exam hợp lệ (không đọc được dạng zip)."
        case .missingManifest:
            return "Gói đề thiếu file exam.json ở gốc."
        case let .corruptedEntry(path):
            return "Gói đề bị hỏng: không giải nén được \(path)."
        case let .invalidJSON(problem):
            return "exam.json không hợp lệ: \(problem.logMessage)"
        case let .unsupportedVersion(found, supported):
            return "Đề cần phiên bản app mới hơn (định dạng v\(found), app này hiểu tới v\(supported))."
        case let .invalidVersion(version):
            return "formatVersion không hợp lệ: \(version) (phải từ 1 trở lên)."
        case let .unknownFields(paths):
            return "Đề có trường không được hỗ trợ: \(paths.joined(separator: ", "))."
        case let .duplicateJSONKeys(paths):
            return "exam.json có khoá bị lặp lại trong cùng một object: \(paths.joined(separator: ", ")). Mỗi khoá chỉ được ghi một lần."
        case let .nullValues(paths):
            return "exam.json có giá trị null (không được phép): \(paths.joined(separator: ", ")). Bỏ hẳn trường tuỳ chọn thay vì ghi null."
        case let .missingMedia(paths):
            return "Gói đề thiếu ảnh: \(paths.joined(separator: ", "))."
        case let .invalidMediaPath(paths):
            return "Đường dẫn ảnh không hợp lệ: \(paths.joined(separator: ", "))."
        case let .validationFailed(issues):
            guard let first = issues.first else { return "Đề có lỗi, không mở được." }
            if issues.count == 1 {
                return "Đề có 1 lỗi, không mở được: \(first.message)"
            }
            return "Đề có \(issues.count) lỗi, không mở được. Lỗi đầu tiên: \(first.message)"
        case let .duplicateEntry(path):
            return "Gói đề bị hỏng: có nhiều entry cùng tên \(path)."
        case let .tooLarge(entry, limit):
            return "Gói đề vượt giới hạn ở \(entry) (tối đa \(limit))."
        case let .tooDeep(limit):
            return "exam.json lồng object/mảng quá sâu (tối đa \(limit) cấp). File có thể bị hỏng hoặc không phải đề thi."
        case let .migrationFailed(from, reason):
            return "Không chuyển được đề từ định dạng v\(from) lên v\(from + 1): \(reason.logMessage(from: from))"
        case let .unsupportedImageType(ext):
            return "Loại ảnh \"\(ext)\" không được hỗ trợ (chỉ png, jpg, jpeg, gif, webp, heic)."
        case let .writeFailed(problem):
            return "Không ghi được gói đề: \(problem.logMessage)"
        case let .oef(problem):
            return "File .oef không đọc được: \(problem.logMessage)"
        }
    }
}
