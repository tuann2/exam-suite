import AppKit
import AuthoringData
import ExamImport
@testable import AuthoringFeature
import Foundation
import Testing

/// `NSDocument` không cửa sổ cho test bước lưu của Thử đề này: ghi byte cố định (hoặc lỗi), hộp Lưu giả (chọn file hoặc
/// Huỷ), lỗi lưu được ghi lại thay vì hiện hộp thoại.
@MainActor
private final class FakeDocument: NSDocument {
    /// Hộp Lưu giả: file người dùng chọn; `nil` = Huỷ.
    var savePanelChoice: URL?
    var failWrite = false
    private(set) var writes = 0
    private(set) var savePanels = 0
    private(set) var presentedErrors: [any Error] = []

    override nonisolated class var autosavesInPlace: Bool { false }

    override func data(ofType typeName: String) throws -> Data {
        writes += 1
        if failWrite { throw CocoaError(.fileWriteNoPermission) }
        return Data("đề thử".utf8)
    }

    override func runModalSavePanel(
        for saveOperation: NSDocument.SaveOperationType,
        delegate: Any?,
        didSave didSaveSelector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        savePanels += 1
        guard let url = savePanelChoice else {
            Self.call(didSaveSelector, on: delegate, document: self, flag: false, contextInfo: contextInfo)
            return
        }
        save(to: url, ofType: fileType ?? "vn.io.nt0.exam", for: .saveAsOperation, delegate: delegate,
             didSave: didSaveSelector, contextInfo: contextInfo)
    }

    override func presentError(_ error: any Error) -> Bool {
        presentedErrors.append(error)
        return false
    }

    override func presentError(
        _ error: any Error,
        modalFor window: NSWindow,
        delegate: Any?,
        didPresent didPresentSelector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        presentedErrors.append(error)
        Self.callDidPresent(didPresentSelector, on: delegate, recovered: false, contextInfo: contextInfo)
    }

    /// Gọi `document:didSave:contextInfo:` như AppKit.
    static func call(
        _ selector: Selector?, on delegate: Any?, document: NSDocument, flag: Bool, contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let selector, let target = delegate as? NSObject, let imp = target.method(for: selector) else { return }
        typealias Function = @convention(c) (NSObject, Selector, NSDocument, ObjCBool, UnsafeMutableRawPointer?) -> Void
        unsafeBitCast(imp, to: Function.self)(target, selector, document, ObjCBool(flag), contextInfo)
    }

    static func callDidPresent(
        _ selector: Selector?, on delegate: Any?, recovered: Bool, contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let selector, let target = delegate as? NSObject, let imp = target.method(for: selector) else { return }
        typealias Function = @convention(c) (NSObject, Selector, ObjCBool, UnsafeMutableRawPointer?) -> Void
        unsafeBitCast(imp, to: Function.self)(target, selector, ObjCBool(recovered), contextInfo)
    }
}

/// Thư mục tạm riêng (tên `g44b-…`), xoá khi xong.
private final class SaverDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("g44b-saver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    /// File đã lưu trước đó, gắn vào document như mở từ đĩa.
    @MainActor
    func savedDocument(named name: String) throws -> FakeDocument {
        let file = url.appendingPathComponent(name)
        try Data("bản cũ".utf8).write(to: file)
        let document = FakeDocument()
        document.fileType = "vn.io.nt0.exam"
        document.fileURL = file
        document.fileModificationDate = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        return document
    }
}

@MainActor
@Suite("Thử đề này: lưu đúng document của cửa sổ (không đổi, đã sửa, chưa từng lưu, huỷ hộp Lưu, lưu lỗi)", .timeLimit(.minutes(1)))
struct TryExamDocumentSaverTests {
    @Test("Đã có file và không có thay đổi: không ghi lại, thử luôn file đó")
    func unchangedIsNotRewritten() async throws {
        let directory = try SaverDirectory()
        let document = try directory.savedDocument(named: "de.exam")
        #expect(await TryExamDocumentSaver.save(document) == .saved(try #require(document.fileURL)))
        #expect(document.writes == 0)
        #expect(document.savePanels == 0)
    }

    @Test("Có thay đổi chưa lưu: lưu vào file đang có (như ⌘S), hết “Đã sửa”")
    func editedIsSavedInPlace() async throws {
        let directory = try SaverDirectory()
        let document = try directory.savedDocument(named: "de.exam")
        document.updateChangeCount(.changeDone)
        let url = try #require(document.fileURL)
        #expect(await TryExamDocumentSaver.save(document) == .saved(url))
        #expect(document.writes == 1)
        #expect(document.savePanels == 0)
        #expect(!document.isDocumentEdited)
        #expect(try Data(contentsOf: url) == Data("đề thử".utf8))
    }

    @Test("Chưa từng lưu: hỏi chỗ lưu; chọn file thì lưu ở đó và thử file đó")
    func untitledAsksWhereToSave() async throws {
        let directory = try SaverDirectory()
        let document = FakeDocument()
        document.fileType = "vn.io.nt0.exam"
        document.updateChangeCount(.changeDone)
        let chosen = directory.url.appendingPathComponent("Đề mới.exam")
        document.savePanelChoice = chosen
        let outcome = await TryExamDocumentSaver.save(document)
        guard case let .saved(url) = outcome else {
            Issue.record("phải lưu được: \(outcome)")
            return
        }
        #expect(url.lastPathComponent == "Đề mới.exam")
        #expect(document.savePanels == 1)
        #expect(document.writes == 1)
        #expect(FileManager.default.fileExists(atPath: chosen.path))
    }

    @Test("Huỷ hộp Lưu: không thử, không ghi gì")
    func cancelledSavePanel() async {
        let document = FakeDocument()
        document.fileType = "vn.io.nt0.exam"
        document.updateChangeCount(.changeDone)
        #expect(await TryExamDocumentSaver.save(document) == .cancelled)
        #expect(document.savePanels == 1)
        #expect(document.writes == 0)
        #expect(document.fileURL == nil)
    }

    @Test("Lưu lỗi (macOS báo lỗi): không thử, document vẫn “Đã sửa”")
    func saveErrorCancels() async throws {
        let directory = try SaverDirectory()
        let document = try directory.savedDocument(named: "de.exam")
        document.updateChangeCount(.changeDone)
        document.failWrite = true
        #expect(await TryExamDocumentSaver.save(document) == .cancelled)
        #expect(document.writes == 1)
        #expect(document.isDocumentEdited)
    }

    @Test("Bộ soạn đề chưa gắn với document của cửa sổ nào: không lưu, không thử")
    func editorWithoutDocument() async {
        let editor = ExamAuthoringDocument().editor
        #expect(await TryExamDocumentSaver.save(for: editor) == .cancelled)
    }

    @Test("Bộ soạn đề gắn với document của chính cửa sổ: Thử đề lưu đúng document đó")
    func editorSavesItsOwnDocument() async throws {
        let directory = try SaverDirectory()
        let mine = try directory.savedDocument(named: "cua-toi.exam")
        let other = try directory.savedDocument(named: "cua-so-khac.exam")
        mine.updateChangeCount(.changeDone)
        other.updateChangeCount(.changeDone)
        let editor = ExamAuthoringDocument().editor
        AuthoringDocumentBridge.attach(editor) { mine }
        #expect(await TryExamDocumentSaver.save(for: editor) == .saved(try #require(mine.fileURL)))
        #expect(mine.writes == 1)
        #expect(other.writes == 0)
        #expect(other.isDocumentEdited)
    }
}

@MainActor
@Suite("Đề import là document “Đã sửa”: đóng cửa sổ (⌘W, ⌘Q) thì macOS hỏi lưu")
struct ImportedDocumentChangeTests {
    private func importedEditor() -> AuthoringEditor {
        let imported = ImportedExam(
            draft: sampleDraft(),
            report: ImportReportState(fileName: "de.txt", report: .init(entries: []))
        )
        return ExamAuthoringDocument(imported: imported).editor
    }

    @Test("Gắn document của cửa sổ: đề import được đánh dấu “Đã sửa” đúng một lần")
    func importedIsMarkedEdited() {
        let editor = importedEditor()
        let document = FakeDocument()
        #expect(!document.isDocumentEdited)
        AuthoringDocumentBridge.attach(editor) { document }
        #expect(document.isDocumentEdited)
        // Gắn lại (SwiftUI cập nhật view) không đánh dấu thêm: lưu một lần là hết "Đã sửa".
        document.updateChangeCount(.changeCleared)
        AuthoringDocumentBridge.attach(editor) { document }
        #expect(!document.isDocumentEdited)
    }

    @Test("Đề mới và đề mở từ file không bị đánh dấu khi gắn cửa sổ")
    func othersAreNotMarked() throws {
        let document = FakeDocument()
        AuthoringDocumentBridge.attach(ExamAuthoringDocument().editor) { document }
        #expect(!document.isDocumentEdited)
    }

    @Test("Cửa sổ chưa có document ở lần gắn đầu: lần gắn sau (có document) vẫn đánh dấu")
    func markedWhenDocumentArrivesLater() {
        let editor = importedEditor()
        AuthoringDocumentBridge.attach(editor) { nil }
        let document = FakeDocument()
        AuthoringDocumentBridge.attach(editor) { document }
        #expect(document.isDocumentEdited)
    }
}
