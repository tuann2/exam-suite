import Foundation

/// Cách chọn câu cho một phiên (màn Trước khi thi, docs/product/scoring.md).
public enum QuestionSelection: Equatable, Hashable, Sendable {
    /// Mọi câu, theo thứ tự trong file.
    case all
    /// Chỉ các section này, giữ thứ tự section và thứ tự câu trong file.
    case sections(Set<UUID>)
    /// N câu ngẫu nhiên trên toàn đề (Fisher–Yates toàn bộ câu, lấy N câu đầu).
    case random(count: Int)
    /// "Luyện lại câu sai": đúng các câu này, theo thứ tự truyền vào; trùng id thì giữ lần đầu.
    case questions([UUID])
}

/// Tuỳ chọn tạo đề cho một phiên. Cùng đề + cùng tuỳ chọn (kể cả `seed`) ⇒ cùng `ExamPaper`.
public struct CompositionOptions: Equatable, Hashable, Sendable {
    public var selection: QuestionSelection
    /// Xáo thứ tự câu sau khi chọn.
    public var shuffleQuestions: Bool
    /// Xáo thứ tự hiển thị lựa chọn của từng câu; chấm vẫn theo `OptionID` gốc.
    public var shuffleOptions: Bool
    /// Seed của `SeededGenerator`; lưu cùng Attempt để "Làm lại" tái hiện đúng đề.
    public var seed: UInt64

    public init(
        selection: QuestionSelection = .all,
        shuffleQuestions: Bool = false,
        shuffleOptions: Bool = false,
        seed: UInt64
    ) {
        self.selection = selection
        self.shuffleQuestions = shuffleQuestions
        self.shuffleOptions = shuffleOptions
        self.seed = seed
    }
}
