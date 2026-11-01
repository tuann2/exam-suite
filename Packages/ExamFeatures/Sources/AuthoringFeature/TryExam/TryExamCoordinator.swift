import ExamFile
import ExamKit
import Foundation
import InterfaceCore
import LibraryData
import Observation
import OSLog

/// Kết quả lưu document trước khi thử.
public enum TryExamSaveOutcome: Equatable, Sendable {
    /// Đã lưu (hoặc không có gì phải lưu); đường dẫn file `.exam`.
    case saved(URL)
    /// Người dùng huỷ hộp Lưu, hoặc lưu không được (macOS đã báo lỗi lưu): không thử.
    case cancelled
}

/// Kết quả đọc nghiêm file vừa lưu (như điều kiện "Sẵn sàng" của Thư viện, exam-taking.md phương án 5).
public enum TryExamStrictRead: Equatable, Sendable {
    case ready
    /// Đề còn lỗi kiểm đề: `errorCount` là số lỗi mức `error` của `ExamValidator` trên file vừa lưu (kể cả ảnh thiếu),
    /// cùng nguồn với số trên thanh lỗi (đọc nghiêm dừng ở lỗi đầu tiên nên không dùng để đếm).
    case validationErrors(errorCount: Int)
    /// File đọc được nhưng bản Học viên vẫn từ chối vì lý do khác lỗi kiểm đề (trường lạ, khoá trùng…).
    case fileRejected(reason: String)
    /// Không đọc được file vừa lưu (đã bị chuyển/xoá, không có quyền, zip hỏng…).
    case unreadable(reason: String)
}

/// Kết quả đưa file vào Thư viện của bản Admin (như **Thêm đề**).
public enum TryExamLibraryOutcome: Equatable, Sendable {
    /// Đề có trong Thư viện (vừa thêm hoặc đã có, cùng file).
    case inLibrary(examID: UUID)
    /// Cùng id đề với một mục đã có nhưng khác file: Thư viện đang hỏi **Dùng file mới** / **Huỷ**. Chọn Dùng file mới
    /// thì Thư viện gọi `onReplaced` (mở Trước khi thi); Huỷ thì thôi (authoring.md, phương án 12).
    case awaitingReplacementDecision
    /// File không thêm được: Thư viện đã báo lý do trên cửa sổ Thư viện, không mở Trước khi thi.
    case needsAttention
}

/// Những gì Thử đề này cần ngoài document: đọc file, Thư viện, phiên thi. App dùng `live(library:)`; test thay
/// bằng bản giả.
public struct TryExamEnvironment {
    public var readStrict: @Sendable (URL) async -> TryExamStrictRead
    /// Thêm file vào Thư viện. `onReplaced` được gọi (với id đề) nếu Thư viện hỏi Dùng file mới và người dùng chọn.
    public var addToLibrary: @MainActor (_ url: URL, _ onReplaced: @escaping @MainActor (UUID) -> Void) async
        -> TryExamLibraryOutcome
    /// Mở **Trước khi thi** của đề (trên cửa sổ Thư viện). `false` nếu đề chưa Sẵn sàng trong Thư viện.
    public var openPreExam: @MainActor (UUID) -> Bool

    public init(
        readStrict: @escaping @Sendable (URL) async -> TryExamStrictRead,
        addToLibrary: @escaping @MainActor (URL, @escaping @MainActor (UUID) -> Void) async -> TryExamLibraryOutcome,
        openPreExam: @escaping @MainActor (UUID) -> Bool
    ) {
        self.readStrict = readStrict
        self.addToLibrary = addToLibrary
        self.openPreExam = openPreExam
    }

    /// Đọc nghiêm file thật; thêm vào Thư viện bằng đúng luồng **Thêm đề** (`LibraryModel.addExamFile`), mở Trước khi
    /// thi bằng đúng lệnh **Luyện tập/Thi** của thẻ đề (`LibraryModel.startSession`, chế độ dùng lần trước).
    @MainActor
    public static func live(library: LibraryModel) -> TryExamEnvironment {
        TryExamEnvironment(
            readStrict: { url in await readStrictly(url) },
            addToLibrary: { [weak library] url, onReplaced in
                guard let library else { return .needsAttention }
                switch await library.addExamFile(url, afterReplacing: onReplaced) {
                case let .added(examID), let .alreadyInLibrary(examID):
                    return .inLibrary(examID: examID)
                case .needsReplaceConfirmation:
                    library.presentWindow?()
                    return .awaitingReplacementDecision
                case .rejected, .skippedNotExam, nil:
                    library.presentWindow?()
                    return .needsAttention
                }
            },
            openPreExam: { [weak library] examID in
                library?.startSession(examID, mode: nil) ?? false
            }
        )
    }

    /// Đọc nghiêm như bản Học viên, ngoài main actor. Thất bại thì đọc dễ để phân loại: còn lỗi kiểm đề (đếm như
    /// thanh lỗi: `ExamValidator` với ảnh có trong gói), bị từ chối vì lý do khác, hay không đọc được file.
    public static func readStrictly(_ url: URL) async -> TryExamStrictRead {
        await Task.detached(priority: .userInitiated) {
            let strictError: any Error
            do {
                _ = try ExamPackageReader.read(contentsOf: url, mode: .strict)
                return .ready
            } catch {
                strictError = error
            }
            let package: ExamPackage
            do {
                package = try ExamPackageReader.read(contentsOf: url, mode: .lenient)
            } catch {
                return .unreadable(reason: describe(error))
            }
            let errors = package.validationIssues.count { $0.severity == .error }
            return errors > 0 ? .validationErrors(errorCount: errors) : .fileRejected(reason: describe(strictError))
        }.value
    }

    private static func describe(_ error: any Error) -> String {
        AuthoringMessages.message(for: error)
    }
}

/// Kết quả một lần Thử đề này (test và nhật ký).
public enum TryExamOutcome: Equatable, Sendable {
    /// Đã mở Trước khi thi của đề.
    case openedPreExam(examID: UUID)
    /// Huỷ lưu: không thử.
    case saveCancelled
    /// Đề còn lỗi kiểm đề: báo "Đề còn N lỗi, sửa trước khi thử" trên cửa sổ soạn đề, mở thanh lỗi.
    case notReady(errorCount: Int)
    /// Bản Học viên sẽ từ chối file vì lý do khác lỗi kiểm đề, hoặc không đọc được file vừa lưu: báo lý do thật.
    case fileProblem
    /// Thư viện đang hỏi **Dùng file mới**: chọn thì mở Trước khi thi, Huỷ thì thôi.
    case awaitingReplacementDecision
    /// Thư viện báo file không thêm được trên cửa sổ Thư viện.
    case libraryNeedsAttention
    /// Đề có trong Thư viện nhưng chưa Sẵn sàng ở đó (không mở được Trước khi thi).
    case libraryNotReady
    /// Đang có một lần Thử đề chưa xong.
    case busy
}

/// **Thử đề này** (⌘R, menu Đề; nút trên thanh công cụ soạn đề), docs/product/authoring.md mục Thử đề này, Nt0 chốt
/// "lưu rồi thử, có lịch sử":
///
/// 1. Lưu document (chưa từng lưu thì macOS hỏi chỗ lưu như Lưu thành); huỷ lưu thì không thử.
/// 2. Đọc nghiêm file vừa lưu (điều kiện "Sẵn sàng", exam-taking.md phương án 5); không được thì báo
///    "Đề còn N lỗi, sửa trước khi thử" trên cửa sổ soạn đề và mở thanh lỗi.
/// 3. Thêm file vào Thư viện nếu chưa có (như **Thêm đề**), rồi mở **Trước khi thi** của đề đó với chế độ dùng lần
///    trước; người dùng chọn Luyện tập hoặc Thi. Lần thử là một lần thi thường của SessionFeature, vào Lịch sử thi.
///    Cùng id đề nhưng khác file với mục đã có: Thư viện hỏi **Dùng file mới** / **Huỷ**; chọn Dùng file mới thì mở
///    Trước khi thi luôn, Huỷ thì thôi (authoring.md, phương án 12).
///
/// Không giao diện: lưu (AppKit) do shell truyền vào, Thư viện và đọc file qua `TryExamEnvironment`.
@MainActor
@Observable
public final class TryExamCoordinator {
    /// Đang thử (đang lưu, đọc hoặc thêm vào Thư viện): lần bấm ⌘R tiếp theo bị bỏ qua.
    public private(set) var isRunning = false
    /// Việc làm tiếp sau **Dùng file mới** đang chạy (test chờ).
    @ObservationIgnored private(set) var followUp: Task<TryExamOutcome, Never>?

    @ObservationIgnored private let environment: TryExamEnvironment

    private static let log = Logger(subsystem: "vn.io.nt0.examsuite.admin", category: "authoring.tryExam")

    public init(environment: TryExamEnvironment) {
        self.environment = environment
    }

    /// Chạy Thử đề này cho cửa sổ của `editor`.
    /// - Parameter save: lưu document của cửa sổ đó (hỏi chỗ lưu nếu chưa từng lưu).
    @discardableResult
    public func run(editor: AuthoringEditor, save: @MainActor () async -> TryExamSaveOutcome) async -> TryExamOutcome {
        guard !isRunning else { return .busy }
        isRunning = true
        defer { isRunning = false }
        // Đoạn gõ đang mở kết thúc trước khi lưu (lần gõ sau là bước Hoàn tác mới).
        editor.endTyping()

        guard case let .saved(url) = await save() else {
            Self.log.info("Try exam: save cancelled")
            return .saveCancelled
        }
        if let problem = Self.report(await environment.readStrict(url), on: editor) {
            return problem
        }
        let environment = environment
        let onReplaced: @MainActor (UUID) -> Void = { [weak self, weak editor] examID in
            Self.log.info("Try exam: library now uses the saved file")
            // Kết luận đọc file của hộp hỏi lấy lúc hỏi; file có thể đã được lưu lại (có lỗi) trong lúc chờ trả lời,
            // nên đọc nghiêm lại trước khi mở. Cửa sổ soạn đề có thể đã đóng: vẫn mở Trước khi thi.
            let task = Task { @MainActor in
                if let problem = Self.report(await environment.readStrict(url), on: editor) { return problem }
                return Self.openPreExam(examID, environment: environment, editor: editor)
            }
            self?.followUp = task
        }
        switch await environment.addToLibrary(url, onReplaced) {
        case let .inLibrary(examID):
            return Self.openPreExam(examID, environment: environment, editor: editor)
        case .awaitingReplacementDecision:
            Self.log.info("Try exam: waiting for the library's replace decision")
            return .awaitingReplacementDecision
        case .needsAttention:
            Self.log.info("Try exam: library needs attention")
            return .libraryNeedsAttention
        }
    }

    /// Báo kết quả đọc nghiêm không Sẵn sàng trên cửa sổ soạn đề (nếu còn); `nil` nếu Sẵn sàng.
    private static func report(_ read: TryExamStrictRead, on editor: AuthoringEditor?) -> TryExamOutcome? {
        switch read {
        case .ready:
            return nil
        case let .validationErrors(errorCount):
            log.info("Try exam: saved file has \(errorCount) validation errors")
            editor?.isIssueListExpanded = true
            editor?.alert = AuthoringAlert(
                title: localized("Đề còn \(errorCount) lỗi, sửa trước khi thử"),
                message: localized("Bản Học viên sẽ từ chối đề này. Danh sách lỗi ở thanh lỗi phía dưới.")
            )
            return .notReady(errorCount: errorCount)
        case let .fileRejected(reason):
            log.info("Try exam: saved file rejected for a non-validation reason")
            editor?.isIssueListExpanded = true
            editor?.alert = AuthoringAlert(
                title: localized("Bản Học viên sẽ từ chối đề này"),
                message: localized("File vừa lưu chưa đọc nghiêm được: \(reason)")
            )
            return .fileProblem
        case let .unreadable(reason):
            log.error("Try exam: saved file unreadable")
            editor?.alert = AuthoringAlert(
                title: localized("Không đọc được file vừa lưu"),
                message: reason
            )
            return .fileProblem
        }
    }

    /// Mở Trước khi thi của đề (đề đã có trong Thư viện); chưa Sẵn sàng thì báo trên cửa sổ soạn đề (nếu còn).
    private static func openPreExam(
        _ examID: UUID,
        environment: TryExamEnvironment,
        editor: AuthoringEditor?
    ) -> TryExamOutcome {
        guard environment.openPreExam(examID) else {
            Self.log.error("Try exam: exam in library but not ready")
            editor?.alert = AuthoringAlert(
                title: localized("Chưa mở được Trước khi thi"),
                message: localized("""
                    Đề đã có trong Thư viện nhưng chưa ở trạng thái Sẵn sàng. Mở Thư viện để xem trạng thái của đề, \
                    rồi thử lại.
                    """)
            )
            return .libraryNotReady
        }
        Self.log.info("Try exam: opened pre-exam")
        return .openedPreExam(examID: examID)
    }
}
