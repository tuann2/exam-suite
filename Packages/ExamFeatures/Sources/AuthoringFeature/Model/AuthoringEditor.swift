import AuthoringData
import ExamFile
import ExamKit
import Foundation
import InterfaceCore
import Observation
import OSLog

/// Nơi giữ bản sao mới nhất của đề để lưu (document). Bộ soạn đề ghi vào sau mỗi thay đổi.
protocol AuthoringDraftStorage: AnyObject, Sendable {
    func store(_ draft: ExamDraft)
    /// Tăng mỗi lần macOS chụp đề để lưu.
    var saveGeneration: Int { get }
}

/// Trạng thái và lệnh của một cửa sổ soạn đề (docs/product/authoring.md): đề đang soạn, dòng chọn trên cây
/// đề, kết quả kiểm lỗi, xem trước, tiêu điểm, hộp thoại.
///
/// **Mọi** thay đổi nội dung đi qua `ExamDraft` (AuthoringData) trong `perform`, rồi đăng ký thay đổi ngược
/// với `UndoManager` của cửa sổ (Hoàn tác/Làm lại, và để macOS đánh dấu document "Đã sửa"):
/// - Thay đổi không đổi gì (`ExamEdit.isEmpty`) không tạo bước Hoàn tác.
/// - Gõ chữ gộp theo trường (`TypingField`): chỉ lần gõ đầu của một đoạn gõ đăng ký thay đổi ngược. Thay đổi
///   ngược của trường chữ là bản chụp cả câu / cả thuộc tính đề / tên phần, nên Hoàn tác nó đưa trường về
///   trước cả đoạn gõ. Thao tác khác (nhất là thêm/xoá/sắp xếp: thay đổi ngược địa chỉ theo vị trí), đổi dòng
///   chọn, Hoàn tác/Làm lại và lưu đều đóng đoạn gõ trước.
/// - Đang Hoàn tác/Làm lại (trình soạn chữ của macOS có thể gửi lại chữ cũ qua binding) thì áp mà không đăng
///   ký thêm.
///
/// Không giao diện: test bằng `UndoManager` thật và document không có cửa sổ (AuthoringFeatureTests).
@MainActor
@Observable
public final class AuthoringEditor {
    public private(set) var draft: ExamDraft
    /// Dòng đang chọn trên cây đề (theo vị trí; đề đọc dễ có thể có id trùng).
    public var selection: TreeRow? = .exam {
        didSet { if selection != oldValue { endTyping() } }
    }
    public private(set) var outline: TreeOutline
    /// Kết quả kiểm đề gần nhất (có thể trễ một nhịp so với `draft` khi `isValidating`).
    public private(set) var issues: IssueIndex
    public private(set) var isValidating = false
    /// Lý do bản Học viên từ chối **file đang lưu** ngoài lỗi kiểm đề (trường lạ, khoá trùng…). Chỉ hết khi đọc lại
    /// file trên đĩa sau khi lưu thấy file đã sạch (`recheckFile(at:)`), không hết chỉ vì đã gửi byte đi ghi.
    public private(set) var fileRejection: String?
    /// Ảnh câu tham chiếu có trong file nhưng sai tên (không theo SHA-256, exam-format.md): bộ đọc bỏ qua nên không
    /// dùng được, và mất khi lưu (authoring.md, mục Ảnh). Tính từ tên entry của file đang lưu.
    public private(set) var misnamedImages: Set<String>

    public var searchText = ""
    public var showsPreview = true
    public var previewMode: PreviewMode = .practice
    public var isIssueListExpanded = false
    public private(set) var focusRequest: FocusRequest?
    public private(set) var searchFocusRequest = 0
    public var alert: AuthoringAlert?
    public var sectionPendingRemoval: SectionRemovalRequest?
    /// Báo cáo import (cửa sổ mở từ **Import đề…**; import.md, Luồng bước 5); `nil` với đề mới hoặc mở từ file.
    public let importReport: ImportReportState?
    /// Bảng báo cáo import đang hiện (mở sẵn khi có báo cáo; ẩn/hiện được).
    public var showsImportReport: Bool
    /// Tên mặc định ghi vào đề khi **Thêm phần** hay thêm câu vào đề chưa có phần ("Phần N"), theo ngôn ngữ giao diện lúc
    /// mở cửa sổ (`DefaultContentNames.interface`; test đặt ngôn ngữ cố định).
    @ObservationIgnored var contentNames: DefaultContentNames = .interface()
    /// Lưu document của chính cửa sổ này cho **Thử đề này** (cửa sổ gán, `AuthoringDocumentBridge`).
    @ObservationIgnored public var saveForTrial: (@MainActor () async -> TryExamSaveOutcome)?
    /// Đề import chưa được đánh dấu "Đã sửa" trên document của cửa sổ.
    @ObservationIgnored private var pendingImportChange: Bool

    /// `UndoManager` của cửa sổ (document). Cửa sổ gán khi xuất hiện và khi document được dựng lại.
    @ObservationIgnored public weak var undoManager: UndoManager? {
        didSet { if undoManager != nil { hadUndoManager = true } }
    }
    @ObservationIgnored private weak var storage: (any AuthoringDraftStorage)?
    @ObservationIgnored private var typingRun: (field: TypingField, saveGeneration: Int)?
    @ObservationIgnored private let validation: ValidationScheduler
    @ObservationIgnored private var focusToken = 0
    /// Tăng sau mỗi thay đổi nội dung; `issues` gắn với phiên bản đã kiểm (`issuesRevision`).
    @ObservationIgnored public private(set) var revision = 0
    @ObservationIgnored private var issuesRevision = -1
    /// Chữ đã chuẩn hoá để tìm, theo câu; `nil` khi chưa dựng xong hoặc phải dựng lại (thêm/xoá/sắp xếp).
    @ObservationIgnored private var searchIndex: TreeSearchIndex?
    /// Lần dựng chỉ mục tìm đang chạy nền (khi mở cửa sổ, sau thêm/xoá/sắp xếp), để lần gõ đầu vào ô tìm không phải dựng
    /// chỉ mục của cả đề trên main actor (large-exams.md: "mỗi lần gõ, kể cả khi ô tìm có chữ" ≤ 8 ms).
    @ObservationIgnored private var searchIndexTask: Task<Void, Never>?
    /// Thay đổi đã áp kể từ khi lần dựng nền bắt đầu (lần dựng chụp đề lúc bắt đầu): áp lại khi chỉ mục về.
    @ObservationIgnored private var editsDuringIndexBuild: [ExamEdit] = []
    @ObservationIgnored private var rowsMemo: (revision: Int, query: String, rows: [TreeRow])?
    /// Đường dẫn file của document (cửa sổ gán), để đọc lại file trên đĩa sau khi lưu.
    @ObservationIgnored public var documentURL: (@MainActor () -> URL?)?
    @ObservationIgnored private var recheckTask: Task<Void, Never>?
    /// Bộ soạn đề của document trong cửa sổ phải có `UndoManager`: thiếu thì thay đổi không đánh dấu "Đã sửa" và
    /// đóng cửa sổ là mất. Tắt chỉ ở test không cần Hoàn tác.
    @ObservationIgnored let requiresUndoManager: Bool
    /// Đã từng có `UndoManager` (cửa sổ đã gắn). Sau đó mà mất (cửa sổ đang đóng, ô số commit lúc rời ô) thì chỉ ghi
    /// log, không assert: thay đổi lúc đóng cửa sổ không còn gì để đánh dấu.
    @ObservationIgnored private var hadUndoManager = false
    /// Báo lỗi lập trình khi đăng ký Hoàn tác mà chưa có `UndoManager` (test thay để ghi lại).
    @ObservationIgnored var reportMissingUndoManager: (String) -> Void = { actionName in
        AuthoringEditor.log.fault("Edit \(actionName, privacy: .public) has no UndoManager: document will not be marked edited")
        assertionFailure("AuthoringEditor: thay đổi \(actionName) không có UndoManager") // l10n-ignore: lỗi lập trình
    }
    /// Chỉ cho test: gọi ngay trước mỗi lần đăng ký Hoàn tác (test không có vòng lặp sự kiện để `UndoManager` tự mở
    /// nhóm theo sự kiện, nên tự mở nhóm ở đây).
    @ObservationIgnored var willRegisterUndo: ((UndoManager) -> Void)?

    private static let log = Logger(subsystem: "vn.io.nt0.examsuite.admin", category: "authoring.editor")

    /// Đọc câu VoiceOver (app: `AuthoringAnnouncer.post`; test thay để bắt câu đọc).
    @ObservationIgnored var announce: @MainActor (String) -> Void = { AuthoringAnnouncer.post($0) }
    /// Số lỗi của lần kiểm đề trước (`nil`: chưa kiểm lần nào, lần kiểm đầu khi mở cửa sổ không đọc).
    @ObservationIgnored private var lastValidatedErrorCount: Int?

    init(
        draft: ExamDraft,
        fileRejection: String? = nil,
        misnamedImages: Set<String> = [],
        importReport: ImportReportState? = nil,
        storage: (any AuthoringDraftStorage)?,
        validation: ValidationScheduler = ValidationScheduler(),
        requiresUndoManager: Bool = true
    ) {
        self.draft = draft
        self.fileRejection = fileRejection
        self.misnamedImages = misnamedImages
        self.requiresUndoManager = requiresUndoManager
        self.importReport = importReport
        showsImportReport = importReport != nil
        pendingImportChange = importReport != nil
        self.storage = storage
        self.validation = validation
        outline = TreeOutline(draft.exam)
        issues = IssueIndex([])
        scheduleValidation(immediately: true)
        buildSearchIndexInBackground()
    }

    public var exam: Exam { draft.exam }

    // MARK: - Áp thay đổi

    /// Áp một thao tác của `ExamDraft` và đăng ký Hoàn tác.
    ///
    /// - Parameters:
    ///   - action: thao tác (tên bước trong menu Sửa "Hoàn tác <tên>", tiêu đề hộp báo khi lỗi).
    ///   - typing: trường gõ chữ, để gộp các lần gõ liên tiếp; `nil` với thao tác rời.
    ///   - body: thao tác trên đề, trả về thay đổi ngược. Lỗi thì đề không đổi và hiện thông báo.
    /// - Returns: `true` nếu thao tác chạy được (kể cả khi không đổi gì).
    @discardableResult
    func perform(
        _ action: EditAction,
        typing: TypingField? = nil,
        _ body: (inout ExamDraft) throws -> ExamEdit
    ) -> Bool {
        let restoring = undoManager.map { $0.isUndoing || $0.isRedoing } ?? false
        let generation = storage?.saveGeneration ?? 0
        let continuesTyping = typing != nil && !restoring
            && typingRun?.field == typing && typingRun?.saveGeneration == generation
        if !continuesTyping { typingRun = nil }

        let inverse: ExamEdit
        do {
            inverse = try body(&draft)
        } catch {
            report(error, action: action)
            return false
        }
        guard !inverse.isEmpty else { return true }
        didChange(touching: inverse)
        guard !restoring, !continuesTyping else { return true }
        if let typing { typingRun = (typing, generation) }
        registerUndo(inverse, action: action)
        return true
    }

    /// Kết thúc đoạn gõ đang mở: lần gõ sau là một bước Hoàn tác mới.
    public func endTyping() {
        typingRun = nil
    }

    private func registerUndo(_ inverse: ExamEdit, action: EditAction) {
        let actionName = action.undoName
        guard let undoManager else {
            if hadUndoManager {
                Self.log.info("Edit \(actionName, privacy: .public) after the window's UndoManager went away")
            } else if requiresUndoManager {
                reportMissingUndoManager(actionName)
            }
            return
        }
        willRegisterUndo?(undoManager)
        undoManager.registerUndo(withTarget: self) { editor in
            editor.applyFromUndoManager(inverse, action: action)
        }
        undoManager.setActionName(actionName)
    }

    /// Hoàn tác/Làm lại: áp thay đổi ngược, chọn chỗ vừa đổi, đăng ký thay đổi ngược của nó (UndoManager tự
    /// đưa vào ngăn Làm lại khi đang Hoàn tác và ngược lại).
    private func applyFromUndoManager(_ edit: ExamEdit, action: EditAction) {
        typingRun = nil
        let inverse: ExamEdit
        do {
            inverse = try draft.apply(edit)
        } catch {
            // Không xảy ra nếu mọi thay đổi đều qua `perform`: thay đổi ngược luôn áp được lên đúng trạng thái sau.
            Self.log.fault("Undo step failed: \(String(describing: error), privacy: .public)")
            report(error, action: action)
            return
        }
        selection = TreeSelection.after(applying: edit, current: selection, in: draft.exam)
        didChange(touching: edit)
        registerUndo(inverse, action: action)
    }

    private func didChange(touching edit: ExamEdit) {
        revision += 1
        outline.update(after: edit, in: draft.exam)
        if searchIndexTask != nil {
            editsDuringIndexBuild.append(edit)
        } else if searchIndex?.update(after: edit, in: draft.exam) == false {
            searchIndex = nil
            buildSearchIndexInBackground()
        }
        storage?.store(draft)
        scheduleValidation()
    }

    private func report(_ error: any Error, action: EditAction) {
        alert = AuthoringAlert(title: action.failureTitle, message: AuthoringMessages.message(for: error))
    }

    // MARK: - Kiểm lỗi

    private func scheduleValidation(immediately: Bool = false) {
        isValidating = true
        let validated = revision
        validation.schedule(exam: draft.exam, media: Set(draft.package.media.keys), immediately: immediately) { [weak self] index in
            self?.issues = index
            self?.issuesRevision = validated
            self?.isValidating = false
            self?.announceNewErrors(in: index)
        }
    }

    /// VoiceOver đọc khi lần kiểm đề có **thêm** lỗi so với lần kiểm trước (accessibility-localization.md, Mục tiêu phủ
    /// theo màn: Soạn đề "kiểm đề có lỗi mới (không đọc mỗi lần gõ)"): lần kiểm chỉ chạy sau khi ngừng gõ 250 ms
    /// (`ValidationScheduler`), lỗi giảm hay giữ nguyên thì không đọc, lần kiểm đầu khi mở cửa sổ không đọc.
    private func announceNewErrors(in index: IssueIndex) {
        defer { lastValidatedErrorCount = index.errorCount }
        guard let previous = lastValidatedErrorCount, index.errorCount > previous else { return }
        announce(AuthoringPresentation.newErrorsAnnouncement(index.errorCount - previous))
    }

    /// `issues` là kết quả kiểm của đúng đề hiện tại (không còn lần kiểm nào đang hẹn).
    public var issuesAreCurrent: Bool { issuesRevision == revision }

    /// Kiểm đề ngay trên main actor (huỷ lần đang hẹn), dùng khi cần kết quả đúng ngay (bấm thanh lỗi lúc vừa sửa).
    func validateNow() {
        issues = validation.validateNow(exam: draft.exam, media: Set(draft.package.media.keys))
        issuesRevision = revision
        isValidating = false
    }

    /// Chờ lần kiểm đề đang hẹn (test).
    func waitForValidation() async {
        await validation.waitUntilIdle()
    }

    /// Bản Học viên có từ chối đề này không, và vì sao (dòng "Bản Học viên sẽ từ chối đề này" của thanh lỗi):
    /// đề còn lỗi kiểm đề, hoặc file đang lưu có lỗi mà bản Học viên đọc nghiêm không chấp nhận.
    public var studentRejection: String? {
        let errors = issues.errorCount
        if errors > 0 { return localized("đề còn \(errors) lỗi.") }
        return fileRejection
    }

    /// macOS vừa lấy byte để ghi file. Ghi có thể thất bại (hết chỗ, không có quyền), nên chưa coi lỗi của file cũ
    /// là hết: đọc lại file trên đĩa sau 1 giây và 3 giây (`recheckFile(at:)`).
    func fileMayHaveBeenWritten() {
        guard fileRejection != nil || !misnamedImages.isEmpty else { return }
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            for delay in [Duration.seconds(1), .seconds(3)] {
                do { try await Task.sleep(for: delay) } catch { return }
                guard let self, let url = self.documentURL?() else { return }
                await self.recheckFile(at: url)
            }
        }
    }

    /// Đọc lại file đề trên đĩa: lý do bản Học viên từ chối file (ngoài lỗi kiểm đề) và ảnh sai tên còn trong file.
    /// File không đọc được thì giữ nguyên trạng thái cũ.
    func recheckFile(at url: URL) async {
        let referenced = Set(draft.exam.allQuestions.compactMap(\.image)).subtracting(draft.package.media.keys)
        let result = await Task.detached(priority: .utility) { () -> (String?, Set<String>)? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return (
                ExamAuthoringDocument.fileLevelRejection(for: data),
                ExamAuthoringDocument.misnamedImages(in: data, referenced: referenced)
            )
        }.value
        guard let (rejection, misnamed) = result else { return }
        fileRejection = rejection
        misnamedImages = misnamed
    }

    /// Thông điệp của một vấn đề cho thanh lỗi và dưới ô nhập: chữ của catalog theo mã (`ErrorMessages`). Ảnh có trong
    /// file nhưng sai tên thì nói rõ (thay cho "không có trong gói" của `ExamValidator`).
    public func message(for issue: ValidationIssue) -> String {
        guard issue.code == .imagePathInvalid || issue.code == .imageNotFound,
              case let .question(_, path) = IssueTarget(issue).node,
              let image = question(at: path)?.image, misnamedImages.contains(image)
        else { return ErrorMessages.message(for: issue) }
        return Self.misnamedImageMessage(image)
    }

    /// Ảnh của câu không hiện được: sai tên trong file, hoặc không có trong gói; `nil` nếu câu không có ảnh hay ảnh có.
    public func missingImageMessage(for question: Question) -> String? {
        guard let image = question.image, imageData(for: question) == nil else { return nil }
        if misnamedImages.contains(image) { return Self.misnamedImageMessage(image) }
        return localized("Không có ảnh \(image) trong gói.")
    }

    static func misnamedImageMessage(_ image: String) -> String {
        localized("Ảnh \(image) sai tên (phải theo SHA-256), không dùng được và sẽ bị bỏ khi lưu; dùng Thêm/Thay ảnh… để thêm lại.")
    }

    /// Vấn đề của một dòng, lọc theo trường (và lựa chọn, với lỗi của lựa chọn) để hiện ngay dưới ô nhập.
    public func issues(for row: TreeRow, field: IssueTarget.Field? = nil, option: Int? = nil) -> [ValidationIssue] {
        issues.issues(for: row).filter { issue in
            let target = IssueTarget(issue)
            if let field, target.field != field { return false }
            if case let .option(_, _, index) = target.node { return option == index }
            return option == nil
        }
    }

    // MARK: - Điều hướng, tiêu điểm

    /// Bấm một dòng của thanh lỗi: chọn đúng đề/phần/câu và đưa tiêu điểm tới trường đó.
    ///
    /// Vấn đề trỏ theo vị trí. Đề đã đổi sau lần kiểm cuối (đang chờ kiểm lại) thì kiểm ngay rồi tìm lại đúng vấn đề
    /// đó theo mã và id của đề/phần/câu (và vị trí lựa chọn); không còn thì không làm gì, để không chọn nhầm câu khác.
    public func navigate(to issue: ValidationIssue) {
        var issue = issue
        if !issuesAreCurrent {
            validateNow()
            guard let current = Self.matching(issue, in: issues.issues) else { return }
            issue = current
        }
        let target = IssueTarget(issue)
        guard let row = TreeSelection.valid(target.node.treeRow, in: draft.exam), row == target.node.treeRow else { return }
        if !visibleRows.contains(row) {
            searchText = ""
        }
        selection = row
        requestFocus(AuthoringFocus(target))
    }

    /// Đề import chưa lưu phải được đánh dấu "Đã sửa" một lần khi có cửa sổ (để đóng thì macOS hỏi lưu). Trả `true` đúng
    /// một lần với document mở từ **Import đề…**.
    public func takePendingImportChange() -> Bool {
        defer { pendingImportChange = false }
        return pendingImportChange
    }

    /// Câu có `id` còn trong đề (dòng báo cáo import bấm được).
    public func containsQuestion(_ id: UUID) -> Bool {
        draft.path(of: id) != nil
    }

    /// Bấm một dòng của báo cáo import: chọn câu có `id` đó (lần xuất hiện đầu) và đưa tiêu điểm vào nội dung câu.
    /// Báo cáo trỏ theo id câu (không theo vị trí), nên luôn tìm trên đề hiện tại, kể cả khi đề đã sửa sau lần kiểm
    /// cuối (không cần kiểm lại như `navigate(to:)`). Câu không còn trong đề (đã xoá sau khi import) thì không làm gì
    /// và trả `false`.
    @discardableResult
    public func navigate(toQuestion id: UUID) -> Bool {
        guard let path = draft.path(of: id) else { return false }
        let row = TreeRow.question(path)
        if !visibleRows.contains(row) {
            searchText = ""
        }
        selection = row
        requestFocus(.questionText)
        return true
    }

    public func requestFocus(_ focus: AuthoringFocus) {
        focusToken += 1
        focusRequest = FocusRequest(focus: focus, token: focusToken)
    }

    /// ⌘F: đưa tiêu điểm vào ô tìm của cây đề.
    public func requestSearchFocus() {
        searchFocusRequest += 1
    }

    /// Vấn đề trong `issues` ứng với `old` (của một lần kiểm trước): cùng mã, cùng id đề/phần/câu, cùng vị trí lựa chọn.
    /// Đề đọc dễ có thể có id trùng: ưu tiên ứng viên ở đúng vị trí cũ, rồi ứng viên gần vị trí cũ nhất (cùng phần
    /// trước, rồi khoảng cách chỉ số câu), không lấy đại lần xuất hiện đầu.
    static func matching(_ old: ValidationIssue, in issues: [ValidationIssue]) -> ValidationIssue? {
        let oldNode = IssueTarget(old).node
        let candidates = issues.filter { issue in
            guard issue.code == old.code else { return false }
            switch (oldNode, IssueTarget(issue).node) {
            case (.exam, .exam): return true
            case let (.section(a, _), .section(b, _)): return a == b
            case let (.question(a, _), .question(b, _)): return a == b
            case let (.option(a, _, i), .option(b, _, j)): return a == b && i == j
            default: return false
            }
        }
        if let same = candidates.first(where: { $0.location == old.location }) { return same }
        let origin = TreeSelection.position(of: oldNode.treeRow)
        return candidates.min { a, b in
            TreeSelection.distance(origin, TreeSelection.position(of: IssueTarget(a).node.treeRow))
                < TreeSelection.distance(origin, TreeSelection.position(of: IssueTarget(b).node.treeRow))
        }
    }

    /// Dòng hiện trên cây đề (đã lọc theo ô tìm). Ghi nhớ theo (phiên bản đề, chữ tìm); chữ đã chuẩn hoá của từng
    /// câu giữ trong `TreeSearchIndex` (dựng nền khi mở cửa sổ) và chỉ cập nhật câu vừa sửa, nên lần gõ đầu vào ô tìm và
    /// gõ trong đề 2.000 câu lúc đang tìm không phải chuẩn hoá lại cả đề.
    public var visibleRows: [TreeRow] {
        // Đọc hai thuộc tính được theo dõi để view vẽ lại khi cây đề hoặc chữ tìm đổi.
        let query = searchText
        let outline = outline
        if let memo = rowsMemo, memo.revision == revision, memo.query == query { return memo.rows }
        let needle = TreeSearch.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let rows: [TreeRow]
        if needle.isEmpty {
            rows = outline.rows
        } else {
            if searchIndex == nil {
                // Lần dựng nền chưa xong (gõ ngay khi vừa mở hay vừa thêm/xoá): dựng ngay, bỏ lần dựng nền.
                searchIndexTask?.cancel()
                searchIndexTask = nil
                editsDuringIndexBuild = []
                searchIndex = TreeSearchIndex(draft.exam)
            }
            rows = searchIndex?.rows(matching: needle) ?? []
        }
        rowsMemo = (revision, query, rows)
        return rows
    }

    // MARK: - Chỉ mục tìm

    /// Dựng chỉ mục tìm của đề hiện tại ngoài main actor (huỷ lần đang chạy). Thay đổi áp trong lúc dựng được ghi lại và
    /// áp lên chỉ mục khi nó về; thay đổi cấu trúc (thêm/xoá/sắp xếp) trong lúc đó thì dựng lại. Lần dựng nền dừng giữa
    /// chừng khi bị huỷ (lần dựng mới, gõ vào ô tìm trước khi xong) hoặc khi bộ soạn đề không còn (cửa sổ đã đóng).
    private func buildSearchIndexInBackground() {
        searchIndexTask?.cancel()
        editsDuringIndexBuild = []
        let exam = draft.exam
        searchIndexTask = Task { [weak self] in
            let build = Task.detached(priority: .userInitiated) { [weak self] in
                TreeSearchIndex(exam, isCancelled: { Task.isCancelled || self == nil })
            }
            let built = await withTaskCancellationHandler { await build.value } onCancel: { build.cancel() }
            guard !Task.isCancelled, let self, let built else { return }
            self.searchIndexTask = nil
            self.install(built)
        }
    }

    private func install(_ built: TreeSearchIndex) {
        var index = built
        for edit in editsDuringIndexBuild where !index.update(after: edit, in: draft.exam) {
            buildSearchIndexInBackground()
            return
        }
        editsDuringIndexBuild = []
        searchIndex = index
    }

    /// Chỉ mục tìm đã sẵn (lần gõ vào ô tìm chỉ lọc). Cho test.
    var hasSearchIndex: Bool { searchIndex != nil }

    /// Chờ lần dựng chỉ mục tìm nền (kể cả lần dựng lại do thay đổi trong lúc dựng). Cho test.
    func waitForSearchIndex() async {
        while let current = searchIndexTask {
            await current.value
            if searchIndexTask == current { break }
        }
    }

    // MARK: - Truy vấn cho giao diện

    public func question(at path: QuestionPath) -> Question? { draft.question(at: path) }

    public func section(at index: Int) -> ExamSection? {
        draft.exam.sections.indices.contains(index) ? draft.exam.sections[index] : nil
    }

    /// Byte ảnh của câu, nếu ảnh có trong gói.
    public func imageData(for question: Question) -> Data? {
        question.image.flatMap { draft.package.media[$0] }
    }

    /// Phần chứa dòng đang chọn (dòng phần, hoặc phần của câu).
    public var selectedSectionIndex: Int? {
        switch selection {
        case let .section(index): index
        case let .question(path): path.section
        case .exam, nil: nil
        }
    }

    public var selectedQuestionPath: QuestionPath? {
        if case let .question(path) = selection { return path }
        return nil
    }
}
