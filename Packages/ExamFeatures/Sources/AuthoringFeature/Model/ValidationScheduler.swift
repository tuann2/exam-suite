import AuthoringData
import ExamKit
import Foundation

/// Kiểm đề chạy nền, gộp thay đổi (docs/product/authoring.md, mục Kiểm lỗi: "chạy nền, không làm chậm gõ
/// với đề 2.000 câu").
///
/// Mỗi thay đổi hẹn một lần kiểm sau `debounce`; thay đổi mới trong lúc chờ huỷ lần hẹn cũ, nên gõ liên tục
/// chỉ kiểm một lần khi ngừng gõ. `ExamValidator` và việc gom vấn đề theo dòng (`IssueIndex`) chạy ngoài main
/// actor; kết quả của lần kiểm đã bị thay thế thì bỏ.
@MainActor
final class ValidationScheduler {
    typealias Validate = @Sendable (Exam, Set<String>) -> [ValidationIssue]

    static let defaultDebounce: Duration = .milliseconds(250)
    static let defaultValidate: Validate = { exam, media in ExamValidator.validate(exam, availableMedia: media) }

    private let debounce: Duration
    private let validate: Validate
    private var task: Task<Void, Never>?

    init(debounce: Duration = defaultDebounce, validate: @escaping Validate = defaultValidate) {
        self.debounce = debounce
        self.validate = validate
    }

    var isPending: Bool { task != nil }

    /// Hẹn kiểm `exam` với tập ảnh `media`; `deliver` nhận kết quả trên main actor nếu không bị thay thế.
    func schedule(
        exam: Exam, media: Set<String>, immediately: Bool = false,
        deliver: @escaping @MainActor (IssueIndex) -> Void
    ) {
        task?.cancel()
        let debounce = immediately ? nil : debounce
        let validate = validate
        task = Task { [weak self] in
            if let debounce {
                do { try await Task.sleep(for: debounce) } catch { return }
            }
            let index = await Task.detached(priority: .userInitiated) {
                IssueIndex(validate(exam, media))
            }.value
            guard !Task.isCancelled else { return }
            self?.task = nil
            deliver(index)
        }
    }

    /// Huỷ lần đang hẹn và kiểm ngay trên luồng gọi (đề 2.000 câu khoảng 15 ms ở bản Debug).
    func validateNow(exam: Exam, media: Set<String>) -> IssueIndex {
        task?.cancel()
        task = nil
        return IssueIndex(validate(exam, media))
    }

    /// Chờ tới khi không còn lần kiểm nào đang hẹn hay đang chạy (test).
    func waitUntilIdle() async {
        while let current = task {
            await current.value
            if task == current { break }
        }
    }
}
