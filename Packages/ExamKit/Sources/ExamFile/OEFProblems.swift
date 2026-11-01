import Foundation

// Lỗi và ghi chú có mã của bộ đọc `.oef` (docs/product/exam-format.md, mục File `.oef`). Như các lỗi khác của
// ExamFile: `logMessage` là câu tiếng Việt cho nhật ký, script, test; giao diện dựng câu từ case và tham số
// (`ErrorMessages`, `AuthoringMessages`).

/// Vị trí của một câu trong file `.oef`: thứ tự phần và thứ tự câu trong phần, đếm từ 0 theo file (kể cả phần và
/// câu bị bỏ khi chuyển).
public struct OEFPlace: Equatable, Hashable, Sendable {
    public let section: Int
    public let question: Int

    public init(section: Int, question: Int) {
        self.section = section
        self.question = question
    }

    /// "phần 2, câu 3": đếm từ 1, tiếng Việt cho nhật ký và test.
    public var logDescription: String { "phần \(section + 1), câu \(question + 1)" }
}

/// Giới hạn khi đọc `.oef`, chống file dựng có chủ đích. Mặc định theo trần của gói `.exam` (`ExamPackageLimits`).
public struct OEFLimits: Equatable, Sendable {
    /// Kích thước file tối đa, byte (bằng tổng giải nén của gói `.exam`).
    public var fileBytes: Int
    /// Kích thước tối đa của mỗi ảnh, byte.
    public var imageBytes: Int
    /// Tổng độ dài (byte UTF-8) của mọi chuỗi tối đa (bằng trần `exam.json`); kiểm trước khi kiểm UTF-8.
    public var textBytes: Int
    /// Tổng số phần, câu, lựa chọn và đáp án (phần tử của Answers) tối đa.
    public var elementCount: Int
    /// Số mục giữ lại trong danh sách của câu báo (đường dẫn trường lạ, chữ đáp án không khớp): các mục khác nhau đầu
    /// tiên; ít nhất 1.
    public var listedItems: Int

    public init(
        fileBytes: Int = ExamPackageLimits.default.totalUncompressedBytes,
        imageBytes: Int = ExamPackageLimits.default.mediaEntryBytes,
        textBytes: Int = ExamPackageLimits.default.manifestBytes,
        elementCount: Int = 500_000,
        listedItems: Int = 20
    ) {
        self.fileBytes = fileBytes
        self.imageBytes = imageBytes
        self.textBytes = textBytes
        self.elementCount = elementCount
        self.listedItems = max(1, listedItems)
    }

    public static let `default` = OEFLimits()
}

/// Giới hạn nào của `OEFLimits` bị vượt.
public enum OEFLimit: String, Equatable, Hashable, Sendable {
    case file
    case text
    case elements
}

/// Vì sao file `.oef` không đọc được (`ExamFileError.oef`).
public enum OEFProblem: Equatable, Hashable, Sendable {
    /// `.oef` bản cũ của Open Exam Suite (zip + XML, hoặc BinaryFormatter của .NET): mở bằng Open Exam Suite rồi lưu lại.
    case legacyFormat
    /// Dây Protobuf hỏng hoặc file không phải `.oef` của Open Exam Suite. `offset`: vị trí byte (từ 0) nơi phát hiện.
    case malformed(offset: Int)
    /// File không có câu hỏi nào (sau khi bỏ phần không có câu).
    case noQuestions
    /// Vượt giới hạn của `OEFLimits`. `limit`: byte hoặc số phần tử.
    case tooLarge(OEFLimit, limit: Int)
    /// Chỉ ở chế độ `strict`: ảnh của câu vượt `OEFLimits.imageBytes`.
    case imageTooLarge(OEFPlace, limit: Int)
    /// Chỉ ở chế độ `strict`: trường không có trong định dạng đã biết, dạng `sections[0].questions[2].#9` (tối đa
    /// `OEFLimits.listedItems` đường dẫn đầu).
    case unknownFields([String])
    /// Chỉ ở chế độ `strict`: ngưỡng đậu không phải số trong thang 0–1000.
    case passmarkOutOfRange
    /// Chỉ ở chế độ `strict`: ảnh không thuộc png, jpg, gif, webp, heic (nhận theo byte đầu).
    case unsupportedImage(OEFPlace)
    /// Chỉ ở chế độ `strict`: câu có quá 26 lựa chọn. `count`: số lựa chọn trong file.
    case tooManyOptions(OEFPlace, count: Int)
    /// Chỉ ở chế độ `strict`: hai lựa chọn của một câu cùng chữ cái. `letter`: chữ cái (hoặc `U+XXXX`).
    case duplicateOptionLetter(OEFPlace, letter: String)
    /// Chỉ ở chế độ `strict`: đáp án không khớp chữ cái của lựa chọn nào trong câu (tối đa `OEFLimits.listedItems`
    /// chữ đầu).
    case answerNotInOptions(OEFPlace, letters: [String])

    /// Câu tiếng Việt (nhật ký, test), phần sau "File .oef không đọc được: ".
    public var logMessage: String {
        switch self {
        case .legacyFormat:
            "file .oef bản cũ (trước Open Exam Suite 4). Mở file bằng Open Exam Suite rồi lưu lại để có bản mới."
        case let .malformed(offset):
            "dữ liệu hỏng ở byte \(offset), hoặc file không phải đề của Open Exam Suite."
        case .noQuestions:
            "file không có câu hỏi nào."
        case let .tooLarge(limit, value):
            switch limit {
            case .file: "file vượt giới hạn \(value) byte."
            case .text: "phần chữ của file vượt giới hạn \(value) byte."
            case .elements: "file có quá \(value) phần, câu, lựa chọn và đáp án."
            }
        case let .imageTooLarge(place, limit):
            "ảnh của \(place.logDescription) vượt giới hạn \(limit) byte."
        case let .unknownFields(paths):
            "file có trường không được hỗ trợ: \(paths.joined(separator: ", "))."
        case .passmarkOutOfRange:
            "ngưỡng đậu không nằm trong thang 0–1000."
        case let .unsupportedImage(place):
            "ảnh của \(place.logDescription) không thuộc loại được hỗ trợ (png, jpg, gif, webp, heic)."
        case let .tooManyOptions(place, count):
            "\(place.logDescription) có \(count) lựa chọn (tối đa 26)."
        case let .duplicateOptionLetter(place, letter):
            "\(place.logDescription) có hai lựa chọn cùng chữ \(letter)."
        case let .answerNotInOptions(place, letters):
            "đáp án \(letters.joined(separator: ", ")) của \(place.logDescription) không khớp lựa chọn nào."
        }
    }
}

/// Chỗ bộ đọc `.oef` đã sửa hoặc bỏ khi đọc ở chế độ `lenient` (bản Admin: báo cáo import). Ở chế độ `strict`, các
/// chỗ tương ứng là lỗi (`OEFProblem`) hoặc được chuẩn hoá không báo (mã sai mẫu, phần không có câu).
public enum OEFNote: Equatable, Hashable, Sendable {
    /// Trường lạ, bị bỏ qua. Tham số: đường dẫn như `OEFProblem.unknownFields`.
    case unknownField(String)
    /// Mã đề không khớp mẫu `[A-Za-z0-9._-]{1,32}`, bị bỏ.
    case invalidCode(String)
    /// Ngưỡng đậu không phải số trong thang 0–1000: không điền sẵn.
    case passmarkOutOfRange
    /// Thời gian ngoài 1–600 phút: không điền sẵn. Tham số: giá trị trong file.
    case timeLimitOutOfRange(Int)
    /// Phần thứ `section` (từ 0) không có câu nào, bị bỏ.
    case emptySection(section: Int)
    /// Phần thứ `section` (từ 0) không có tên.
    case untitledSection(section: Int)
    /// Câu không có lựa chọn nào, bị bỏ.
    case noOptions(OEFPlace)
    /// Câu có quá 26 lựa chọn: từ lựa chọn thứ 27 nối vào Z (như import docx).
    case tooManyOptions(OEFPlace, count: Int)
    /// Hai lựa chọn cùng chữ cái; đáp án theo lựa chọn đầu tiên mang chữ đó.
    case duplicateOptionLetter(OEFPlace, letter: String)
    /// Đáp án không khớp lựa chọn nào, bị bỏ.
    case answerNotInOptions(OEFPlace, letters: [String])
    /// Ảnh không thuộc loại được hỗ trợ, bị bỏ.
    case unsupportedImage(OEFPlace)
    /// Ảnh vượt `OEFLimits.imageBytes`, bị bỏ.
    case imageTooLarge(OEFPlace, limit: Int)
}
