import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import LibraryData
import LibraryFeature
import Testing

/// Thư mục tạm riêng của một test (tên `g44b-…`), xoá khi xong.
private final class TempDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("g44b-try-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func file(_ name: String) -> URL { url.appendingPathComponent(name) }
}

/// Môi trường giả ghi lại thứ tự các bước.
@MainActor
private final class FakeTryEnvironment {
    var steps: [String] = []
    var strictRead: TryExamStrictRead = .ready
    var libraryOutcome: TryExamLibraryOutcome = .inLibrary(examID: fixedID(1))
    var preExamOpens = true
    var openedExamIDs: [UUID] = []
    /// Việc Thư viện làm sau **Dùng file mới** (môi trường giả giữ lại để test gọi).
    var onReplaced: (@MainActor (UUID) -> Void)?

    var environment: TryExamEnvironment {
        TryExamEnvironment(
            readStrict: { url in
                await MainActor.run {
                    self.steps.append("read \(url.lastPathComponent)")
                    return self.strictRead
                }
            },
            addToLibrary: { url, onReplaced in
                self.steps.append("add \(url.lastPathComponent)")
                self.onReplaced = onReplaced
                return self.libraryOutcome
            },
            openPreExam: { examID in
                self.steps.append("open")
                self.openedExamIDs.append(examID)
                return self.preExamOpens
            }
        )
    }
}

private let savedURL = URL(fileURLWithPath: "/tmp/g44b-khong-ton-tai/Đề thử.exam")

@MainActor
@Suite("Thử đề này: lưu → đọc nghiêm → thêm vào Thư viện → Trước khi thi (authoring.md, mục Thử đề này)")
struct TryExamCoordinatorTests {
    @Test("Đủ các bước theo thứ tự: lưu, đọc nghiêm file vừa lưu, thêm vào Thư viện, mở Trước khi thi của đề đó")
    func happyPath() async {
        let fake = FakeTryEnvironment()
        let editor = EditorHarness().editor
        let coordinator = TryExamCoordinator(environment: fake.environment)
        let outcome = await coordinator.run(editor: editor) {
            fake.steps.append("save")
            return .saved(savedURL)
        }
        #expect(outcome == .openedPreExam(examID: fixedID(1)))
        #expect(fake.steps == ["save", "read Đề thử.exam", "add Đề thử.exam", "open"])
        #expect(fake.openedExamIDs == [fixedID(1)])
        #expect(editor.alert == nil)
        #expect(!coordinator.isRunning)
    }

    @Test("Huỷ hộp Lưu (đề chưa từng lưu): không thử, không đọc, không đụng Thư viện, không báo gì")
    func saveCancelled() async {
        let fake = FakeTryEnvironment()
        let editor = EditorHarness().editor
        let outcome = await TryExamCoordinator(environment: fake.environment).run(editor: editor) { .cancelled }
        #expect(outcome == .saveCancelled)
        #expect(fake.steps.isEmpty)
        #expect(editor.alert == nil)
        #expect(!editor.isIssueListExpanded)
    }

    @Test("Đề còn lỗi kiểm đề: báo “Đề còn N lỗi, sửa trước khi thử”, mở thanh lỗi, không thêm vào Thư viện")
    func strictReadFails() async {
        let fake = FakeTryEnvironment()
        fake.strictRead = .validationErrors(errorCount: 3)
        let editor = EditorHarness().editor
        let outcome = await TryExamCoordinator(environment: fake.environment).run(editor: editor) { .saved(savedURL) }
        #expect(outcome == .notReady(errorCount: 3))
        #expect(fake.steps == ["read Đề thử.exam"])
        #expect(editor.isIssueListExpanded)
        #expect(editor.alert?.title == "Đề còn 3 lỗi, sửa trước khi thử")
        #expect(editor.alert?.message == "Bản Học viên sẽ từ chối đề này. Danh sách lỗi ở thanh lỗi phía dưới.")
    }

    @Test("Bị từ chối vì lý do khác lỗi kiểm đề, hoặc không đọc được file vừa lưu: báo lý do thật, không “Đề còn 1 lỗi”")
    func nonValidationProblemsShowRealReason() async {
        let fake = FakeTryEnvironment()
        fake.strictRead = .fileRejected(reason: "Có trường lạ: hint.")
        let editor = EditorHarness().editor
        #expect(await TryExamCoordinator(environment: fake.environment).run(editor: editor) { .saved(savedURL) } == .fileProblem)
        #expect(editor.alert?.title == "Bản Học viên sẽ từ chối đề này")
        #expect(editor.alert?.message == "File vừa lưu chưa đọc nghiêm được: Có trường lạ: hint.")

        let unreadable = FakeTryEnvironment()
        unreadable.strictRead = .unreadable(reason: "Không tìm thấy file.")
        let other = EditorHarness().editor
        #expect(await TryExamCoordinator(environment: unreadable.environment).run(editor: other) { .saved(savedURL) }
            == .fileProblem)
        #expect(other.alert?.title == "Không đọc được file vừa lưu")
        #expect(other.alert?.message == "Không tìm thấy file.")
        #expect(!other.isIssueListExpanded)
        #expect(unreadable.steps == ["read Đề thử.exam"])
    }

    @Test("Thư viện hỏi Dùng file mới: chưa mở Trước khi thi; chọn Dùng file mới thì mở luôn, không cần ⌘R lần nữa")
    func replacementConfirmedContinues() async {
        let fake = FakeTryEnvironment()
        fake.libraryOutcome = .awaitingReplacementDecision
        let editor = EditorHarness().editor
        let coordinator = TryExamCoordinator(environment: fake.environment)
        let outcome = await coordinator.run(editor: editor) { .saved(savedURL) }
        #expect(outcome == .awaitingReplacementDecision)
        #expect(fake.steps == ["read Đề thử.exam", "add Đề thử.exam"])
        #expect(!coordinator.isRunning, "chờ người dùng trả lời không chặn ⌘R")

        fake.onReplaced?(fixedID(7))
        #expect(await coordinator.followUp?.value == .openedPreExam(examID: fixedID(7)))
        // Đọc nghiêm lại file trước khi mở (kết luận của hộp hỏi lấy lúc hỏi).
        #expect(fake.steps == ["read Đề thử.exam", "add Đề thử.exam", "read Đề thử.exam", "open"])
        #expect(fake.openedExamIDs == [fixedID(7)])
        #expect(editor.alert == nil)
    }

    @Test("Dùng file mới nhưng file đã được lưu lại có lỗi trong lúc chờ: không mở Trước khi thi, báo lỗi")
    func replacementConfirmedButFileNowInvalid() async {
        let fake = FakeTryEnvironment()
        fake.libraryOutcome = .awaitingReplacementDecision
        let editor = EditorHarness().editor
        let coordinator = TryExamCoordinator(environment: fake.environment)
        _ = await coordinator.run(editor: editor) { .saved(savedURL) }
        fake.strictRead = .validationErrors(errorCount: 2)
        fake.onReplaced?(fixedID(7))
        #expect(await coordinator.followUp?.value == .notReady(errorCount: 2))
        #expect(fake.openedExamIDs.isEmpty)
        #expect(editor.alert?.title == "Đề còn 2 lỗi, sửa trước khi thử")
    }

    @Test("Thư viện báo file không thêm được: không mở Trước khi thi")
    func libraryNeedsAttention() async {
        let fake = FakeTryEnvironment()
        fake.libraryOutcome = .needsAttention
        let editor = EditorHarness().editor
        let outcome = await TryExamCoordinator(environment: fake.environment).run(editor: editor) { .saved(savedURL) }
        #expect(outcome == .libraryNeedsAttention)
        #expect(fake.steps == ["read Đề thử.exam", "add Đề thử.exam"])
        #expect(editor.alert == nil)
    }

    @Test("Đề có trong Thư viện nhưng chưa Sẵn sàng ở đó: báo trên cửa sổ soạn đề")
    func libraryNotReady() async {
        let fake = FakeTryEnvironment()
        fake.preExamOpens = false
        let editor = EditorHarness().editor
        let outcome = await TryExamCoordinator(environment: fake.environment).run(editor: editor) { .saved(savedURL) }
        #expect(outcome == .libraryNotReady)
        #expect(editor.alert?.title == "Chưa mở được Trước khi thi")
    }

    @Test("Bấm ⌘R lần nữa khi lần trước chưa xong (đang hỏi chỗ lưu): bỏ qua")
    func secondRunWhileBusy() async {
        let fake = FakeTryEnvironment()
        let editor = EditorHarness().editor
        let coordinator = TryExamCoordinator(environment: fake.environment)
        let (gate, open) = AsyncStream<Void>.makeStream()
        let first = Task {
            await coordinator.run(editor: editor) {
                for await _ in gate { break }
                return .saved(savedURL)
            }
        }
        for _ in 0 ..< 100 where !coordinator.isRunning { await Task.yield() }
        #expect(coordinator.isRunning)
        #expect(await coordinator.run(editor: editor) { .saved(savedURL) } == .busy)
        open.yield()
        #expect(await first.value == .openedPreExam(examID: fixedID(1)))
        #expect(fake.steps.filter { $0 == "open" }.count == 1)
    }
}

@MainActor
@Suite("Thử đề này với file thật và Thư viện bản Admin trong bộ nhớ")
struct TryExamLiveTests {
    /// Ghi document như macOS lưu (chụp đề → byte file của `ExamPackageWriter`).
    private func save(_ document: ExamAuthoringDocument, to url: URL) throws {
        let snapshot = try document.snapshot(contentType: .examPackage)
        try ExamAuthoringDocument.fileData(for: snapshot).write(to: url)
    }

    /// Thư viện bản Admin (đọc dễ) trong bộ nhớ; `opened` ghi lại lệnh mở Trước khi thi.
    private func adminLibrary(in directory: TempDirectory, opened: OpenRecorder) -> LibraryModel {
        let configuration = LibraryConfiguration(
            readMode: .lenient,
            isAdmin: true,
            storeURL: directory.file("Library.store"),
            samplesDirectoryURL: directory.file("Samples"),
            samplesSourceURL: nil,
            checkFingerprint: "g44b"
        )
        let defaults = UserDefaults(suiteName: directory.file("defaults.plist").path)!
        let library = LibraryModel(
            store: .inMemory(configuration: configuration, defaults: defaults),
            startsAutomatically: false,
            revealFiles: { _ in }
        )
        library.sessionActions = LibrarySessionActions(
            openPreExam: { examID, mode in opened.calls.append((examID, mode)) },
            openAttempt: { _ in }
        )
        return library
    }

    @Test("Đọc nghiêm file thật: đề hợp lệ Sẵn sàng; đề thiếu đáp án (vẫn lưu được) có đúng số lỗi; file không có thì không đọc được")
    func readStrictlyOnRealFiles() async throws {
        let directory = try TempDirectory()
        let good = directory.file("hop-le.exam")
        try save(ExamAuthoringDocument(draft: sampleDraft()), to: good)
        #expect(await TryExamEnvironment.readStrictly(good) == .ready)

        var broken = sampleDraft().exam
        broken.sections[0].questions[0].correct = []
        broken.sections[0].questions[1].correct = []
        let bad = directory.file("thieu-dap-an.exam")
        try save(ExamAuthoringDocument(draft: ExamDraft(exam: broken)), to: bad)
        #expect(await TryExamEnvironment.readStrictly(bad) == .validationErrors(errorCount: 2))

        guard case .unreadable = await TryExamEnvironment.readStrictly(directory.file("khong-co.exam")) else {
            Issue.record("file không có phải là không đọc được")
            return
        }
        let garbage = directory.file("rac.exam")
        try Data("không phải zip".utf8).write(to: garbage)
        guard case .unreadable = await TryExamEnvironment.readStrictly(garbage) else {
            Issue.record("file không phải zip phải là không đọc được")
            return
        }
    }

    @Test("Đề thiếu ảnh và thiếu đáp án: N trong “Đề còn N lỗi” bằng số lỗi trên thanh lỗi (đọc nghiêm dừng ở ảnh thiếu)")
    func errorCountMatchesIssueBar() async throws {
        let directory = try TempDirectory()
        var exam = sampleDraft().exam
        exam.sections[0].questions[0].image = "media/abababababababab.png"
        exam.sections[0].questions[1].correct = []
        exam.sections[0].questions[2].correct = []
        let document = ExamAuthoringDocument(draft: ExamDraft(exam: exam))
        let url = directory.file("thieu-anh.exam")
        try save(document, to: url)

        let editor = document.editor
        await editor.waitForValidation()
        #expect(editor.issues.errorCount == 3)
        #expect(await TryExamEnvironment.readStrictly(url) == .validationErrors(errorCount: editor.issues.errorCount))

        let outcome = await TryExamCoordinator(environment: TryExamEnvironment(
            readStrict: TryExamEnvironment.readStrictly,
            addToLibrary: { _, _ in .needsAttention },
            openPreExam: { _ in false }
        )).run(editor: editor) { .saved(url) }
        #expect(outcome == .notReady(errorCount: 3))
        #expect(editor.alert?.title == "Đề còn 3 lỗi, sửa trước khi thử")
    }

    @Test("Đề chưa có trong Thư viện: thêm (như Thêm đề), chọn, mở Trước khi thi với chế độ lần trước; thử lại không thêm mục trùng")
    func addsToLibraryThenOpensPreExam() async throws {
        let directory = try TempDirectory()
        let opened = OpenRecorder()
        let library = adminLibrary(in: directory, opened: opened)
        library.store.load()
        let document = ExamAuthoringDocument(draft: sampleDraft())
        let url = directory.file("Đề thử.exam")
        let coordinator = TryExamCoordinator(environment: .live(library: library))

        let outcome = await coordinator.run(editor: document.editor) {
            do {
                try save(document, to: url)
                return .saved(url)
            } catch {
                return .cancelled
            }
        }
        #expect(outcome == .openedPreExam(examID: fixedID(1)))
        #expect(library.store.entries.map(\.examID) == [fixedID(1)])
        #expect(library.store.entry(fixedID(1))?.status == .ready)
        #expect(library.selection == fixedID(1))
        #expect(opened.calls.count == 1)
        #expect(opened.calls.first?.0 == fixedID(1))
        #expect(opened.calls.first?.1 == nil)

        // Lần thử thứ hai (đã có trong Thư viện, cùng file): không thêm mục mới, vẫn mở Trước khi thi.
        let again = await coordinator.run(editor: document.editor) { .saved(url) }
        #expect(again == .openedPreExam(examID: fixedID(1)))
        #expect(library.store.entries.count == 1)
        #expect(opened.calls.count == 2)
    }

    /// Thử đề trên bản sao: đề đã có trong Thư viện từ `goc.exam`, bản sao `ban-sao.exam` cùng id đề.
    private struct CopyTrial {
        let library: LibraryModel
        let coordinator: TryExamCoordinator
        let document: ExamAuthoringDocument
        let copy: URL
        let outcome: TryExamOutcome

        /// Hộp hỏi Dùng file mới đang chờ.
        @MainActor var replacePrompts: [(prompt: LibraryPrompt, pending: PendingReplacement)] {
            library.prompts.compactMap { prompt in
                if case let .replace(pending) = prompt.kind { (prompt, pending) } else { nil }
            }
        }
    }

    private func runOnCopy(in directory: TempDirectory, opened: OpenRecorder) async throws -> CopyTrial {
        let library = adminLibrary(in: directory, opened: opened)
        library.store.load()
        let document = ExamAuthoringDocument(draft: sampleDraft())
        let original = directory.file("goc.exam")
        let copy = directory.file("ban-sao.exam")
        try save(document, to: original)
        try save(document, to: copy)
        await library.importFiles([original]).value
        let coordinator = TryExamCoordinator(environment: .live(library: library))
        let outcome = await coordinator.run(editor: document.editor) { .saved(copy) }
        return CopyTrial(library: library, coordinator: coordinator, document: document, copy: copy, outcome: outcome)
    }

    @Test("Cùng id đề, khác file: Thư viện hỏi; Dùng file mới → mục dùng file vừa lưu và mở Trước khi thi luôn")
    func sameExamDifferentFileUseNewFile() async throws {
        let directory = try TempDirectory()
        let opened = OpenRecorder()
        let trial = try await runOnCopy(in: directory, opened: opened)
        let library = trial.library
        #expect(trial.outcome == .awaitingReplacementDecision)
        let (prompt, pending) = try #require(trial.replacePrompts.first)
        #expect(pending.newFileURL.lastPathComponent == trial.copy.lastPathComponent)
        #expect(opened.calls.isEmpty)

        library.confirmReplacement(promptID: prompt.id)
        #expect(await trial.coordinator.followUp?.value == .openedPreExam(examID: fixedID(1)))
        #expect(library.prompts.isEmpty)
        #expect(library.store.entries.count == 1)
        #expect(library.store.entry(fixedID(1))?.fileURL.lastPathComponent == trial.copy.lastPathComponent)
        #expect(opened.calls.count == 1)
        #expect(opened.calls.first?.0 == fixedID(1))
        #expect(opened.calls.first?.1 == nil)
    }

    @Test("Cùng id đề, khác file: Huỷ trên hộp hỏi thì không mở Trước khi thi, Thư viện giữ file cũ")
    func sameExamDifferentFileCancel() async throws {
        let directory = try TempDirectory()
        let opened = OpenRecorder()
        let trial = try await runOnCopy(in: directory, opened: opened)
        let library = trial.library
        #expect(trial.outcome == .awaitingReplacementDecision)
        let before = library.store.entry(fixedID(1))

        let (prompt, _) = try #require(trial.replacePrompts.first)
        library.dismissPrompt(prompt.id)
        #expect(library.prompts.isEmpty)
        #expect(trial.coordinator.followUp == nil)
        #expect(opened.calls.isEmpty)
        #expect(library.store.entry(fixedID(1)) == before)
        #expect(before?.fileURL.lastPathComponent == "goc.exam")
    }

    @Test("⌘R lần nữa khi hộp hỏi Dùng file mới còn chờ: vẫn chỉ một hộp hỏi; Dùng file mới thì mở Trước khi thi một lần")
    func secondTryWhileReplacePromptOpen() async throws {
        let directory = try TempDirectory()
        let opened = OpenRecorder()
        let trial = try await runOnCopy(in: directory, opened: opened)
        #expect(trial.replacePrompts.count == 1)
        let again = await trial.coordinator.run(editor: trial.document.editor) { .saved(trial.copy) }
        #expect(again == .awaitingReplacementDecision)
        #expect(trial.replacePrompts.count == 1)
        #expect(trial.library.prompts.count == 1)

        let (prompt, _) = try #require(trial.replacePrompts.first)
        trial.library.confirmReplacement(promptID: prompt.id)
        #expect(await trial.coordinator.followUp?.value == .openedPreExam(examID: fixedID(1)))
        #expect(opened.calls.count == 1)
        #expect(trial.library.prompts.isEmpty)
    }

    @Test("Hộp hỏi Dùng file mới từ Thêm đề thường (không phải Thử đề): không mở Trước khi thi")
    func plainReplacementDoesNotOpenPreExam() async throws {
        let directory = try TempDirectory()
        let opened = OpenRecorder()
        let library = adminLibrary(in: directory, opened: opened)
        library.store.load()
        let document = ExamAuthoringDocument(draft: sampleDraft())
        let original = directory.file("goc.exam")
        let copy = directory.file("ban-sao.exam")
        try save(document, to: original)
        try save(document, to: copy)
        await library.importFiles([original]).value
        await library.importFiles([copy]).value
        let prompt = try #require(library.prompts.last)
        library.confirmReplacement(promptID: prompt.id)
        #expect(opened.calls.isEmpty)
    }
}

@MainActor
private final class OpenRecorder {
    var calls: [(UUID, SessionMode?)] = []
}
