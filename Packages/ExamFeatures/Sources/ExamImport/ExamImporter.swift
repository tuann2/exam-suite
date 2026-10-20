import ExamFile
import ExamKit
import Foundation

/// Import đề từ `.txt`, `.docx` và `.vce` (docs/product/import.md; `.vce` theo ADR 0009). Không giao diện, chỉ bản Admin link (ADR 0003).
///
/// Chạy nền (task tách rời, không chiếm actor của người gọi), báo tiến độ qua `progress` và huỷ được: huỷ task gọi
/// thì bộ chuyển đổi dừng ở lần kiểm kế tiếp và ném `CancellationError`. Không ghi file nào.
///
/// ```swift
/// let result = try await ExamImporter.importFile(at: url) { progress in … }
/// // hộp thoại xác nhận: result.suggestions, result.report, result.questionCount
/// let package = result.makePackage(ImportConfirmation(title: …, code: …, passPercent: …, timeLimitMinutes: …))
/// ```
public enum ExamImporter {
    /// Đuôi file được hỗ trợ (chữ thường).
    public static let supportedExtensions: [String] = ImportSourceFormat.allCases.map(\.rawValue)

    /// Import file theo đuôi (`txt`, `docx`, `vce`, không phân biệt hoa thường). `sharedSectionTitle`: tên phần cho câu
    /// không thuộc phần nào (`ImportDefaults.sharedSectionTitle`); giao diện truyền tên theo ngôn ngữ giao diện lúc import.
    public static func importFile(
        at url: URL,
        limits: ImportLimits = .default,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle,
        progress: @escaping @Sendable (ImportProgress) -> Void = { _ in }
    ) async throws -> ImportResult {
        guard let format = ImportSourceFormat(fileExtension: url.pathExtension) else {
            throw ImportError.unsupportedFileType(url.pathExtension)
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return try await runDetached {
            let reporter = ProgressReporter(progress)
            reporter.report(.reading, fraction: 0)
            let result: ImportResult
            switch format {
            case .txt:
                result = try TextImporter.convert(readFile(url, limit: limits.textBytes, what: .textFile),
                                                  fileStem: stem, limits: limits, sharedSectionTitle: sharedSectionTitle,
                                                  progress: reporter)
            case .docx:
                result = try DocxImporter.convert(contentsOf: url, fileStem: stem, limits: limits,
                                                  sharedSectionTitle: sharedSectionTitle, progress: reporter)
            case .vce:
                result = try VceImporter.convert(readFile(url, limit: limits.vceBytes, what: .vceFile),
                                                 fileStem: stem, limits: limits, sharedSectionTitle: sharedSectionTitle,
                                                 progress: reporter)
            }
            reporter.report(.finished, fraction: 1)
            return result
        }
    }

    /// Import dữ liệu đã đọc sẵn. `fileName` (có đuôi) cho định dạng, tên phần (txt) và tiêu đề gợi ý;
    /// `sharedSectionTitle` như `importFile`.
    public static func importData(
        _ data: Data,
        fileName: String,
        limits: ImportLimits = .default,
        sharedSectionTitle: String = ImportDefaults.sharedSectionTitle,
        progress: @escaping @Sendable (ImportProgress) -> Void = { _ in }
    ) async throws -> ImportResult {
        let url = URL(fileURLWithPath: fileName)
        guard let format = ImportSourceFormat(fileExtension: url.pathExtension) else {
            throw ImportError.unsupportedFileType(url.pathExtension)
        }
        let stem = url.deletingPathExtension().lastPathComponent
        return try await runDetached {
            let reporter = ProgressReporter(progress)
            reporter.report(.reading, fraction: 0)
            let result: ImportResult
            switch format {
            case .txt:
                result = try TextImporter.convert(data, fileStem: stem, limits: limits,
                                                  sharedSectionTitle: sharedSectionTitle, progress: reporter)
            case .docx:
                result = try DocxImporter.convert(data, fileStem: stem, limits: limits,
                                                  sharedSectionTitle: sharedSectionTitle, progress: reporter)
            case .vce:
                result = try VceImporter.convert(data, fileStem: stem, limits: limits,
                                                 sharedSectionTitle: sharedSectionTitle, progress: reporter)
            }
            reporter.report(.finished, fraction: 1)
            return result
        }
    }

    /// Chạy `work` trên task tách rời (luồng nền) và chuyển lệnh huỷ của task gọi sang task đó.
    private static func runDetached(
        _ work: @escaping @Sendable () throws -> ImportResult
    ) async throws -> ImportResult {
        let task = Task.detached(priority: .userInitiated) { try work() }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func readFile(_ url: URL, limit: Int, what: ImportSizeLimit) throws -> Data {
        let size: Int
        do {
            size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        } catch {
            throw ImportError.unreadableFile(.system(error.localizedDescription))
        }
        guard size <= limit else { throw ImportError.tooLarge(what: what, limit: limit) }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadableFile(.system(error.localizedDescription))
        }
    }
}

/// Tiến độ import cho giao diện.
public struct ImportProgress: Equatable, Sendable {
    public enum Phase: Sendable {
        case reading
        case converting
        case finished
    }

    public var phase: Phase
    /// 0…1.
    public var fractionCompleted: Double

    public init(phase: Phase, fractionCompleted: Double) {
        self.phase = phase
        self.fractionCompleted = fractionCompleted
    }
}

/// Gửi tiến độ, không bao giờ lùi.
final class ProgressReporter: @unchecked Sendable {
    private let handler: @Sendable (ImportProgress) -> Void
    private var last = -1.0

    init(_ handler: @escaping @Sendable (ImportProgress) -> Void) {
        self.handler = handler
    }

    /// Chỉ gọi từ một luồng (luồng chuyển đổi).
    func report(_ phase: ImportProgress.Phase, fraction: Double) {
        let value = min(max(fraction, last), 1)
        last = value
        handler(ImportProgress(phase: phase, fractionCompleted: value))
    }
}

/// Giới hạn khi import, chống file bất thường và zip bomb. Theo `ExamPackageLimits` của gói đề.
public struct ImportLimits: Equatable, Sendable {
    /// Kích thước tối đa của file `.txt`, byte. Mặc định bằng trần `exam.json` (32 MiB): đề sinh ra không lớn hơn.
    public var textBytes: Int
    /// Kích thước giải nén tối đa của mỗi phần XML trong `.docx` (`document.xml`, `numbering.xml`, rels), byte.
    /// Mặc định 4 lần trần `exam.json` (128 MiB) vì XML của Word dài hơn nhiều so với nội dung.
    public var xmlPartBytes: Int
    /// Kích thước giải nén tối đa của mỗi ảnh, byte (như gói đề: 50 MiB).
    public var mediaEntryBytes: Int
    /// Tổng giải nén tối đa của các phần được đọc, byte (như gói đề: 1 GiB).
    public var totalUncompressedBytes: Int
    /// Số entry tối đa trong zip `.docx` (như gói đề: 20.000).
    public var entryCount: Int
    /// Số cấp phần tử XML lồng nhau tối đa. Văn bản Word thường sâu dưới 30 cấp (bảng lồng, ảnh).
    public var maxXMLDepth: Int
    /// Kích thước tối đa của file `.vce`, byte (đọc cả file vào bộ nhớ, rồi chép một lần thành mảng byte). Mặc định
    /// 64 MiB, gấp đôi trần `exam.json`: file mẫu 0,35–1,35 MB (600 câu ~1,35 MB); còn chỗ cho ảnh (chưa đọc nhưng
    /// vẫn nằm trong file). Hạ từ 256 MiB sau review độc lập PR #38.
    public var vceBytes: Int

    public init(
        textBytes: Int = ExamPackageLimits.default.manifestBytes,
        xmlPartBytes: Int = ExamPackageLimits.default.manifestBytes * 4,
        mediaEntryBytes: Int = ExamPackageLimits.default.mediaEntryBytes,
        totalUncompressedBytes: Int = ExamPackageLimits.default.totalUncompressedBytes,
        entryCount: Int = ExamPackageLimits.default.entryCount,
        maxXMLDepth: Int = 128,
        vceBytes: Int = 64 << 20
    ) {
        self.textBytes = textBytes
        self.xmlPartBytes = xmlPartBytes
        self.mediaEntryBytes = mediaEntryBytes
        self.totalUncompressedBytes = totalUncompressedBytes
        self.entryCount = entryCount
        self.maxXMLDepth = maxXMLDepth
        self.vceBytes = vceBytes
    }

    public static let `default` = ImportLimits()
}

/// File không đọc được: báo lý do, không mở cửa sổ (import.md, Luồng). Dạng mã và đối số: giao diện dựng câu báo bằng
/// chữ của String Catalog (AuthoringFeature, `AuthoringMessages`; accessibility-localization.md, phương án 2);
/// `logMessage` là câu tiếng Việt cho nhật ký và test. Không theo `LocalizedError`, để câu đó không tự lọt ra giao diện.
public enum ImportError: Error, Equatable, Sendable {
    /// Đuôi file không phải `.txt`/`.docx`/`.vce`. Tham số: đuôi.
    case unsupportedFileType(String)
    /// Không đọc được file (không có, không có quyền…).
    case unreadableFile(ImportReadProblem)
    /// `.txt` không phải UTF-8 (import.md, phương án 6).
    case notUTF8
    /// `.docx` không mở được dạng zip hoặc thiếu `word/document.xml`.
    case notADocx
    /// Một phần của `.docx` không giải nén được (zip hỏng, sai CRC, khai sai kích thước). Tham số: đường dẫn.
    case corruptedPart(String)
    /// Một phần XML của `.docx` sai cú pháp hoặc có DTD/thực thể. Tham số: đường dẫn, chi tiết.
    case invalidXML(part: String, detail: XMLProblem)
    /// Vượt giới hạn `ImportLimits`: byte, hoặc số entry với `docxEntryCount`.
    case tooLarge(what: ImportSizeLimit, limit: Int)
    /// XML lồng sâu hơn `ImportLimits.maxXMLDepth`. Tham số: đường dẫn, giới hạn.
    case tooDeep(part: String, limit: Int)
    /// Không tìm thấy câu hỏi nào (hoặc mọi câu đều bị bỏ). Tham số: số câu bị bỏ.
    case noQuestions(dropped: Int)
    /// `.vce` không đọc được (magic lạ, cắt cụt, sai kích thước, sai CRC-32, độ dài vượt dữ liệu, bố cục chưa biết,
    /// không có câu nào dùng được).
    case unreadableVCE(VceProblem)
}

extension ImportError {
    /// Câu tiếng Việt cho nhật ký và test (giao diện không dùng).
    public var logMessage: String {
        switch self {
        case let .unsupportedFileType(ext):
            return "Không import được file \".\(ext)\". Chỉ hỗ trợ .txt, .docx và .vce."
        case let .unreadableFile(problem):
            return "Không đọc được file: \(problem.logMessage)"
        case .notUTF8:
            return "File .txt phải mã hoá UTF-8. Mở file bằng trình soạn thảo, lưu lại với mã hoá UTF-8 rồi import lại."
        case .notADocx:
            return "File không phải tài liệu Word .docx hợp lệ (zip hỏng hoặc thiếu nội dung văn bản)."
        case let .corruptedPart(path):
            return "Tài liệu Word bị hỏng: không giải nén được \(path)."
        case let .invalidXML(part, detail):
            return "Tài liệu Word bị hỏng: \(part) không hợp lệ (\(detail.logMessage))."
        case let .tooLarge(.docxEntryCount, limit):
            // Giới hạn là số entry, không phải byte (review độc lập #51 N-b; import.md: "20.000 entry").
            return "File vượt giới hạn ở số entry trong file .docx (tối đa \(limit) entry)."
        case let .tooLarge(what, limit):
            return "File vượt giới hạn ở \(what.logName) (tối đa \(limit) byte)."
        case let .tooDeep(part, limit):
            return "Tài liệu Word bất thường: \(part) lồng quá \(limit) cấp."
        case let .noQuestions(dropped):
            if dropped > 0 {
                return "Không có câu hỏi nào dùng được: \(dropped) câu đều không có lựa chọn. Kiểm tra bố cục file (A. …, B. …)."
            }
            return "Không tìm thấy câu hỏi nào. Mỗi câu phải bắt đầu bằng dòng \"Q1:\" hoặc \"QUESTION 1\"."
        case let .unreadableVCE(problem):
            return "File .vce không đọc được: \(problem.logMessage). Nếu có bản .docx xuất từ VCE thì import file đó."
        }
    }
}
