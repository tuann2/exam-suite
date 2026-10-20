import ExamKit
import Foundation
import LibraryData

/// Mức của đồng hồ Thi; mỗi mức có biểu tượng riêng kèm màu (không chỉ dựa vào màu).
public enum ClockLevel: Hashable, Sendable {
    /// Còn hơn 5 phút (và mọi lúc ở Luyện tập).
    case normal
    /// Sắp hết: còn ≤ 5 phút.
    case warning
    /// Gấp: còn ≤ 1 phút.
    case urgent

    public var systemImage: String {
        switch self {
        case .normal: "clock"
        case .warning: "clock.badge.exclamationmark"
        case .urgent: "exclamationmark.triangle.fill"
        }
    }

    /// Ngưỡng (giây còn lại) của mức sắp hết và gấp.
    static let warningSeconds: TimeInterval = 5 * 60
    static let urgentSeconds: TimeInterval = 60
}

/// Đồng hồ trên thanh công cụ.
public struct ClockDisplay: Hashable, Sendable {
    /// `mm:ss` hoặc `h:mm:ss`.
    public let text: String
    public let level: ClockLevel
    /// Thi: đếm ngược thời gian còn lại; Luyện tập: thời gian đã làm.
    public let isCountdown: Bool
    /// Câu đọc VoiceOver: "Còn 4 phút 59 giây" / "Đã làm 12 phút".
    public let accessibilityLabel: String
}

/// Dải thông báo không chặn trên đầu câu.
public struct SessionBanner: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Còn 5 / 1 phút; tự ẩn sau vài giây.
        case timeWarning(minutesLeft: Int)
        /// Đã hết giờ; ở lại trên Rà soát khoá.
        case timeUp
    }

    public let id: Int
    public let kind: Kind
    public let message: String

    /// Giao diện tự ẩn dải này sau vài giây (`AttemptModel.dismissBanner(id:)`).
    public var autoDismisses: Bool {
        if case .timeWarning = kind { return true }
        return false
    }

    public var systemImage: String {
        switch kind {
        case .timeWarning: "clock.badge.exclamationmark"
        case .timeUp: "alarm.fill"
        }
    }
}

/// Một câu VoiceOver cần đọc. Giao diện lấy bằng `AttemptModel.takeAnnouncements()` rồi đọc theo thứ tự.
public struct SessionAnnouncement: Identifiable, Hashable, Sendable {
    public enum Priority: Hashable, Sendable {
        case normal
        /// Cảnh báo giờ, hết giờ: đọc ngay.
        case high
    }

    public let id: Int
    public let text: String
    public let priority: Priority
}

/// Đánh dấu Đúng/Sai của một lựa chọn sau **Kiểm tra đáp án**.
public enum OptionCheckMark: Hashable, Sendable {
    /// Lựa chọn đúng.
    case correct
    /// Lựa chọn đã chọn nhưng sai.
    case incorrect

    public var title: String {
        switch self {
        case .correct: localized("Đúng")
        case .incorrect: localized("Sai")
        }
    }

    public var systemImage: String {
        switch self {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        }
    }
}

/// Một lựa chọn của câu hiện tại, theo thứ tự hiển thị của phiên.
public struct DisplayedOption: Identifiable, Hashable, Sendable {
    public var id: OptionID { optionID }
    /// Vị trí hiển thị (0-based); phím chữ ở vị trí này chọn lựa chọn này.
    public let position: Int
    /// Nhãn theo vị trí hiển thị: A, B, C…
    public let label: String
    /// Id lựa chọn gốc trong file.
    public let optionID: OptionID
    public let text: String
    public let isSelected: Bool
    /// Có sau Kiểm tra đáp án: Đúng (lựa chọn đúng) hoặc Sai (đã chọn nhưng sai); nil với lựa chọn khác.
    public let checkMark: OptionCheckMark?
}

/// Kết quả Kiểm tra đáp án của câu hiện tại.
public struct AnswerCheckPresentation: Hashable, Sendable {
    public let isCorrect: Bool
    /// "Đúng" / "Chưa đúng".
    public let resultText: String
    public let explanation: String?
}

/// Trạng thái một ô của bảng câu hỏi; có thể vừa Đã làm vừa Đánh dấu vừa Đang xem.
public struct NavigatorCell: Identifiable, Hashable, Sendable {
    public var id: Int { index }
    /// Vị trí trong phiên (0-based).
    public let index: Int
    /// Số thứ tự hiển thị (1-based).
    public let number: Int
    public let isAnswered: Bool
    public let isFlagged: Bool
    public let isCurrent: Bool
    /// Đang tạm dừng: bảng câu hỏi chỉ hiện số ô, không hiện trạng thái (các cờ trên đều `false`).
    public let isStateHidden: Bool

    /// Biểu tượng theo trạng thái (hình dạng khác nhau, không chỉ màu).
    public var systemImage: String {
        if isStateHidden { return "square" }
        if isFlagged { return "flag.fill" }
        return isAnswered ? "circle.fill" : "circle"
    }

    /// "Câu 3, Đã làm, Đánh dấu, Đang xem"; tạm dừng thì chỉ "Câu 3".
    public var accessibilityLabel: String {
        var parts = [localized("Câu \(number)")]
        if isStateHidden { return parts[0] }
        parts.append(isAnswered ? localized("Đã làm") : localized("Chưa làm"))
        if isFlagged { parts.append(localized("Đánh dấu")) }
        if isCurrent { parts.append(localized("Đang xem")) }
        return parts.joined(separator: ", ")
    }
}

/// Một nhóm của bảng câu hỏi (một phần của đề).
public struct NavigatorSection: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let cells: [NavigatorCell]
}

/// Bảng **Rà soát & nộp**.
public struct ReviewSummary: Hashable, Sendable {
    public let answeredCount: Int
    public let unansweredCount: Int
    public let flaggedCount: Int
    /// Câu chưa làm (vị trí trong phiên, 0-based).
    public let unansweredIndices: [Int]
    /// Câu đã đánh dấu (vị trí trong phiên, 0-based).
    public let flaggedIndices: [Int]
    /// Rà soát khoá (hết giờ): không quay lại làm bài.
    public let isLocked: Bool

    /// Bấm số câu để quay lại làm bài, nút **Quay lại làm bài** (Esc): không có khi khoá.
    public var canReturnToAttempt: Bool { !isLocked }

    /// "Còn 6 câu chưa làm. Vẫn nộp?"; nil khi không còn câu chưa làm (nộp luôn, không hỏi).
    public var submitConfirmationMessage: String? {
        unansweredCount > 0 ? localized("Còn \(unansweredCount) câu chưa làm. Vẫn nộp?") : nil
    }
}

/// Lệnh của menu **Bài thi** (kèm phím tắt của bảng phím exam-taking.md). Mỗi lệnh có trạng thái
/// bật/tắt (`AttemptModel.isEnabled(_:)`) theo trạng thái hiện tại của phiên.
public enum AttemptCommand: String, CaseIterable, Hashable, Sendable {
    /// Câu trước (←)
    case previousQuestion
    /// Câu sau (→)
    case nextQuestion
    /// Câu tiếp theo (Return)
    case advance
    /// Đánh dấu (⌘D)
    case toggleFlag
    /// Tạm dừng / tiếp tục (⌘.)
    case togglePause
    /// Kiểm tra đáp án, chỉ Luyện tập (⌘K)
    case checkAnswer
    /// Rà soát & nộp (⌘Return)
    case openReview
    /// Quay lại làm bài, Rà soát chưa khoá (Esc)
    case returnToAttempt
    /// Nộp bài (trên Rà soát)
    case submit
    /// Ẩn/hiện bảng câu hỏi (⌃⌘I)
    case toggleNavigator
}

/// Kết quả nộp bài: lần thi (tóm tắt), bản ghi chi tiết và lỗi lưu nếu có.
public struct SessionSubmission: Equatable, Sendable {
    public let attempt: Attempt
    /// Nil chỉ khi không tạo được bản ghi (khi đó lần thi cũng không được lưu).
    public let record: AttemptRecord?
    /// Lỗi lưu vào Lịch sử thi; Kết quả vẫn hiện tới khi đóng cửa sổ.
    public let saveError: String?
}
