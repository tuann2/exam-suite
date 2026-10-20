import Foundation

/// Thao tác sửa đề của cửa sổ soạn đề (`AuthoringEditor.perform`): tên bước Hoàn tác trong menu Sửa ("Hoàn tác Thêm
/// phần") và tiêu đề hộp báo khi thao tác không làm được ("Không thêm phần được"). Mỗi thao tác một khoá câu trọn vẹn
/// cho tiêu đề hộp báo (review độc lập #52 N1: trước đây ghép "Không" + tên bước viết thường + "được", tiếng Anh không
/// ghép được tự nhiên); chữ tiếng Việt không đổi.
enum EditAction: CaseIterable, Sendable {
    case editTitle
    case editCode
    case editPassPercent
    case editTimeLimit
    case changeHideAnswers
    case editInstructions
    case addSection
    case renameSection
    case removeSection
    case addQuestion
    case duplicateQuestion
    case removeQuestion
    case moveQuestion
    case reorderSections
    case editQuestionText
    case editExplanation
    case changeQuestionType
    case assignNewID
    case addOption
    case removeOption
    case reorderOptions
    case editOption
    case changeCorrectAnswer
    case addImage
    case replaceImage
    case removeImage

    /// Tên bước Hoàn tác/Làm lại.
    var undoName: String {
        switch self {
        case .editTitle: localized("Sửa tên đề")
        case .editCode: localized("Sửa mã đề")
        case .editPassPercent: localized("Sửa ngưỡng đậu")
        case .editTimeLimit: localized("Sửa thời gian làm bài")
        case .changeHideAnswers: localized("Đổi Ẩn đáp án")
        case .editInstructions: localized("Sửa hướng dẫn")
        case .addSection: localized("Thêm phần")
        case .renameSection: localized("Đổi tên phần")
        case .removeSection: localized("Xoá phần")
        case .addQuestion: localized("Thêm câu")
        case .duplicateQuestion: localized("Nhân bản câu")
        case .removeQuestion: localized("Xoá câu")
        case .moveQuestion: localized("Chuyển câu")
        case .reorderSections: localized("Sắp xếp phần")
        case .editQuestionText: localized("Sửa nội dung câu")
        case .editExplanation: localized("Sửa giải thích")
        case .changeQuestionType: localized("Đổi loại câu")
        case .assignNewID: localized("Cấp id mới")
        case .addOption: localized("Thêm lựa chọn")
        case .removeOption: localized("Xoá lựa chọn")
        case .reorderOptions: localized("Sắp xếp lựa chọn")
        case .editOption: localized("Sửa lựa chọn")
        case .changeCorrectAnswer: localized("Đổi đáp án đúng")
        case .addImage: localized("Thêm ảnh")
        case .replaceImage: localized("Thay ảnh")
        case .removeImage: localized("Xoá ảnh")
        }
    }

    /// Tiêu đề hộp báo khi thao tác lỗi (đề không đổi).
    var failureTitle: String {
        switch self {
        case .editTitle: localized("Không sửa tên đề được")
        case .editCode: localized("Không sửa mã đề được")
        case .editPassPercent: localized("Không sửa ngưỡng đậu được")
        case .editTimeLimit: localized("Không sửa thời gian làm bài được")
        case .changeHideAnswers: localized("Không đổi ẩn đáp án được")
        case .editInstructions: localized("Không sửa hướng dẫn được")
        case .addSection: localized("Không thêm phần được")
        case .renameSection: localized("Không đổi tên phần được")
        case .removeSection: localized("Không xoá phần được")
        case .addQuestion: localized("Không thêm câu được")
        case .duplicateQuestion: localized("Không nhân bản câu được")
        case .removeQuestion: localized("Không xoá câu được")
        case .moveQuestion: localized("Không chuyển câu được")
        case .reorderSections: localized("Không sắp xếp phần được")
        case .editQuestionText: localized("Không sửa nội dung câu được")
        case .editExplanation: localized("Không sửa giải thích được")
        case .changeQuestionType: localized("Không đổi loại câu được")
        case .assignNewID: localized("Không cấp id mới được")
        case .addOption: localized("Không thêm lựa chọn được")
        case .removeOption: localized("Không xoá lựa chọn được")
        case .reorderOptions: localized("Không sắp xếp lựa chọn được")
        case .editOption: localized("Không sửa lựa chọn được")
        case .changeCorrectAnswer: localized("Không đổi đáp án đúng được")
        case .addImage: localized("Không thêm ảnh được")
        case .replaceImage: localized("Không thay ảnh được")
        case .removeImage: localized("Không xoá ảnh được")
        }
    }
}
