import ExamKit
import Foundation
import LibraryData

/// Mục trên sidebar của cửa sổ Thư viện.
public enum LibrarySection: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// **Tất cả đề**
    case all
    /// **Gần đây**: đề có lần thi hoặc được thêm trong 30 ngày, mới nhất trước.
    case recent
    /// **Lịch sử thi**
    case history

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: localized("Tất cả đề")
        case .recent: localized("Gần đây")
        case .history: localized("Lịch sử thi")
        }
    }

    public var systemImage: String {
        switch self {
        case .all: "books.vertical"
        case .recent: "clock"
        case .history: "list.bullet.rectangle"
        }
    }
}

/// Hộp thoại chọn file đang được yêu cầu.
public enum FileImportRequest: Hashable, Sendable {
    /// **Thêm đề…**: chọn một hoặc nhiều file `.exam`.
    case addExams
    /// **Tìm file…** cho đề mất file: chọn một file.
    case locate(examID: UUID)

    public var allowsMultipleSelection: Bool {
        self == .addExams
    }
}

/// Yêu cầu mở đề trong cửa sổ soạn đề (bản Admin, **Sửa**). Cửa sổ Thư viện thực hiện bằng
/// `openDocument(at:)` của SwiftUI, nên LibraryFeature không cần AuthoringFeature (ADR 0003).
public struct EditRequest: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let examID: UUID
    public let fileURL: URL

    public init(examID: UUID, fileURL: URL, id: UUID = UUID()) {
        self.id = id
        self.examID = examID
        self.fileURL = fileURL
    }
}

/// Lệnh làm bài mà Thư viện gửi đi (docs/product/exam-taking.md, mục Bắt đầu và Lịch sử thi). Shell của mỗi
/// bản app gán bằng `SessionCoordinator` của SessionFeature, nên LibraryFeature không phụ thuộc giao diện
/// làm bài.
public struct LibrarySessionActions {
    /// Mở **Trước khi thi** cho đề: nút **Luyện tập** / **Thi** chọn sẵn chế độ; nil (nhấp đúp, Return) dùng
    /// chế độ lần trước.
    public var openPreExam: @MainActor (_ examID: UUID, _ mode: SessionMode?) -> Void
    /// Mở **Kết quả** của một lần thi trong Lịch sử thi (nhấp đúp hoặc Return).
    public var openAttempt: @MainActor (_ attempt: Attempt) -> Void

    public init(
        openPreExam: @escaping @MainActor (_ examID: UUID, _ mode: SessionMode?) -> Void,
        openAttempt: @escaping @MainActor (_ attempt: Attempt) -> Void
    ) {
        self.openPreExam = openPreExam
        self.openAttempt = openAttempt
    }
}

/// Hộp thoại chờ người dùng trả lời; giao diện hiện lần lượt từng cái, theo thứ tự.
public struct LibraryPrompt: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// "Đề này đã có trong thư viện từ file khác": **Dùng file mới** / **Huỷ**.
        case replace(PendingReplacement)
        /// Báo gọn những file không thêm được kèm lý do.
        case importProblems([ImportProblem])
        /// Thông báo cần người dùng đọc (lỗi, kết quả khôi phục đề mẫu…).
        case message(title: String, message: String)
    }

    public let id: UUID
    public let kind: Kind

    public init(_ kind: Kind, id: UUID = UUID()) {
        self.id = id
        self.kind = kind
    }
}

/// Thông báo không chặn ở chân cửa sổ, tự ẩn sau `displayDuration`.
public struct LibraryNotice: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let message: String
    /// Có giá trị thì thông báo có nút **Hoàn tác** cho lần xoá này (`LibraryModel.undoRemoval`).
    public let undoRemovalID: UUID?

    /// "Vài giây" của docs/product/library.md; ⌘Z vẫn hoàn tác được sau khi thông báo ẩn.
    public static let displayDuration: Duration = .seconds(8)

    public init(message: String, undoRemovalID: UUID? = nil, id: UUID = UUID()) {
        self.id = id
        self.message = message
        self.undoRemovalID = undoRemovalID
    }
}

/// Những gì lệnh menu cần biết về cửa sổ Thư viện đang được dùng (`focusedSceneValue`): có cửa sổ
/// Thư viện đang là cửa sổ chính không, đề nào đang chọn và làm được gì với đề đó.
public struct LibraryCommandContext: Hashable, Sendable {
    /// Đề đang chọn và đang hiện (không tính khi đang xem Lịch sử thi).
    public var selectedExamID: UUID?
    public var canRevealSelection: Bool
    public var canEditSelection: Bool

    public init(selectedExamID: UUID?, canRevealSelection: Bool, canEditSelection: Bool) {
        self.selectedExamID = selectedExamID
        self.canRevealSelection = canRevealSelection
        self.canEditSelection = canEditSelection
    }
}
