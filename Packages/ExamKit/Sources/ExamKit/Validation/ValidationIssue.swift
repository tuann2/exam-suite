import Foundation

/// Mức độ của một vấn đề trong đề.
/// - `error`: vi phạm schema hoặc ràng buộc liên trường; bản Học viên từ chối mở đề,
///   bản Admin hiện thanh lỗi nhưng không chặn lưu (docs/product/exam-format.md).
/// - `warning`: file vẫn hợp lệ, chỉ nhắc người soạn đề.
public enum IssueSeverity: String, Sendable {
    case error
    case warning
}

/// Vị trí của vấn đề trong đề. Chỉ số bắt đầu từ 0, theo thứ tự trong file.
public enum IssueLocation: Equatable, Hashable, Sendable {
    case exam
    case section(index: Int, id: UUID)
    case question(sectionIndex: Int, questionIndex: Int, id: UUID)
    /// `questionID` để thanh lỗi bản Admin nhảy tới câu theo id.
    case option(sectionIndex: Int, questionIndex: Int, optionIndex: Int, questionID: UUID)
}

/// Mã vấn đề ổn định (raw value không đổi giữa các phiên bản) để test và giao diện
/// nhận diện mà không phụ thuộc câu chữ của `message`.
public enum IssueCode: String, Sendable, CaseIterable {
    // Cấp đề
    case titleEmpty
    case titleTooLong
    case codeInvalid
    case passPercentOutOfRange
    case timeLimitOutOfRange
    case instructionsTooLong
    case noSections
    /// id của đề, section hoặc câu trùng với một id xuất hiện trước đó.
    case duplicateID

    // Cấp section (`titleEmpty`, `titleTooLong` dùng chung, phân biệt bằng `IssueLocation`)
    case sectionHasNoQuestions
    case duplicateSectionTitle

    // Cấp câu hỏi
    case questionTextEmpty
    case questionTextTooLong
    case explanationTooLong
    case imagePathInvalid
    case imageNotFound
    case tooFewOptions
    case tooManyOptions
    case noCorrectAnswer
    case duplicateCorrectAnswer
    case correctAnswerNotInOptions
    case singleHasMultipleCorrect
    case multipleHasSingleCorrect

    // Cấp lựa chọn
    case optionIDOutOfOrder
    case optionTextEmpty
    case optionTextTooLong

    /// Mỗi mã có đúng một mức độ cố định.
    public var severity: IssueSeverity {
        switch self {
        case .duplicateSectionTitle, .multipleHasSingleCorrect: .warning
        default: .error
        }
    }
}

/// Giá trị cụ thể của một vấn đề, để tầng giao diện dựng câu báo bằng chữ của String Catalog từ `code` + `location`
/// + `arguments` (docs/product/accessibility-localization.md, phương án 2) thay vì hiện `message` tiếng Việt. Mỗi mã
/// chỉ điền các trường ghi ở dưới; trường khác để trống. Câu `message` dựng từ đúng các giá trị này.
public struct IssueArguments: Equatable, Hashable, Sendable {
    /// Chuỗi trong câu báo: mã đề sai (`codeInvalid`), id trùng viết thường (`duplicateID`), tiêu đề phần đã bỏ khoảng
    /// trắng hai đầu (`duplicateSectionTitle`), đường dẫn ảnh (`imagePathInvalid`, `imageNotFound`).
    public var text: String?
    /// Giá trị đo được: ngưỡng đậu (`passPercentOutOfRange`), số phút (`timeLimitOutOfRange`), độ dài theo code point
    /// (`titleTooLong`, `instructionsTooLong`, `questionTextTooLong`, `explanationTooLong`, `optionTextTooLong`), số lựa
    /// chọn (`tooFewOptions`, `tooManyOptions`), số đáp án đúng (`singleHasMultipleCorrect`).
    public var value: Int?
    /// Giới hạn trong câu báo: độ dài tối đa (`titleEmpty` và các mã `…TooLong`), số lựa chọn tối thiểu
    /// (`tooFewOptions`) hoặc tối đa (`tooManyOptions`).
    public var limit: Int?
    /// Mã lựa chọn ghi trong file (`optionIDOutOfOrder`, `optionTextEmpty`, `optionTextTooLong`).
    public var optionID: OptionID?
    /// Mã lựa chọn đúng theo vị trí (`optionIDOutOfOrder`).
    public var expectedOptionID: OptionID?
    /// Các mã lựa chọn, theo thứ tự trong câu báo: đáp án bị lặp (`duplicateCorrectAnswer`), đáp án không có trong lựa
    /// chọn (`correctAnswerNotInOptions`), mọi đáp án đúng như ghi trong file (`singleHasMultipleCorrect`).
    public var optionIDs: [OptionID]
    /// Nơi xuất hiện trước: đề, phần hoặc câu có cùng id (`duplicateID`); phần có cùng tiêu đề
    /// (`duplicateSectionTitle`).
    public var firstLocation: IssueLocation?

    public init(
        text: String? = nil,
        value: Int? = nil,
        limit: Int? = nil,
        optionID: OptionID? = nil,
        expectedOptionID: OptionID? = nil,
        optionIDs: [OptionID] = [],
        firstLocation: IssueLocation? = nil
    ) {
        self.text = text
        self.value = value
        self.limit = limit
        self.optionID = optionID
        self.expectedOptionID = expectedOptionID
        self.optionIDs = optionIDs
        self.firstLocation = firstLocation
    }
}

/// Một vấn đề tìm thấy khi kiểm tra đề.
public struct ValidationIssue: Equatable, Hashable, Sendable {
    public let severity: IssueSeverity
    public let code: IssueCode
    public let location: IssueLocation
    /// Tiếng Việt, nêu vị trí và cần sửa gì: cho nhật ký, script và test. Giao diện không hiện chữ này mà dựng câu
    /// của catalog từ `code`, `location`, `arguments` (phương án 2 của accessibility-localization.md).
    public let message: String
    /// Giá trị cụ thể trong `message` (vị trí đã có ở `location`).
    public let arguments: IssueArguments

    /// Mức độ lấy từ `code.severity` để hai thứ không bao giờ lệch nhau.
    public init(code: IssueCode, location: IssueLocation, message: String, arguments: IssueArguments = IssueArguments()) {
        self.severity = code.severity
        self.code = code
        self.location = location
        self.message = message
        self.arguments = arguments
    }
}

extension Array where Element == ValidationIssue {
    /// Có ít nhất một vấn đề mức `error` (bản Học viên từ chối mở đề).
    public var hasErrors: Bool { contains { $0.severity == .error } }
}
