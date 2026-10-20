import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import Testing

@MainActor
@Suite("Document: đề mới, ghi rồi mở lại (kể cả ảnh), đọc dễ, dòng Bản Học viên sẽ từ chối, đọc ảnh")
struct DocumentTests {
    /// Ghi như macOS lưu (chụp đề → byte file) rồi mở lại như mở từ Finder.
    private func saveAndReopen(_ document: ExamAuthoringDocument) throws -> ExamAuthoringDocument {
        let snapshot = try document.snapshot(contentType: .examPackage)
        return try ExamAuthoringDocument(fileData: try ExamAuthoringDocument.fileData(for: snapshot))
    }

    @Test("Đề mới: \"Đề mới\", 70%, 60 phút, một phần \"Phần 1\" chưa có câu; có lỗi phần rỗng nhưng vẫn lưu được")
    func newDocument() async throws {
        let document = ExamAuthoringDocument()
        let exam = document.editor.exam
        #expect(exam.title == "Đề mới")
        #expect(exam.passPercent == 70)
        #expect(exam.timeLimitMinutes == 60)
        #expect(exam.sections.map(\.title) == ["Phần 1"])
        #expect(exam.sections[0].questions.isEmpty)
        await document.editor.waitForValidation()
        #expect(document.editor.issues.issues.map(\.code) == [.sectionHasNoQuestions])
        let reopened = try saveAndReopen(document)
        #expect(reopened.draft.exam == exam)
    }

    @Test("Soạn qua bộ soạn đề, lưu, mở lại: đúng đề và đúng byte ảnh; ảnh bị thay hoặc của câu đã xoá không được ghi")
    func roundTripWithImages() throws {
        let h = EditorHarness()
        let q1 = QuestionPath(section: 0, question: 0)
        let q2 = QuestionPath(section: 0, question: 1)
        h.step { h.editor.setImage(of: q1, data: imageBytes(1), fileExtension: "png") }
        h.step { h.editor.setImage(of: q1, data: imageBytes(2), fileExtension: "JPG") }
        h.step { h.editor.setImage(of: q2, data: imageBytes(3), fileExtension: "gif") }
        h.step { h.editor.setImage(of: QuestionPath(section: 0, question: 2), data: imageBytes(2), fileExtension: "jpg") }
        h.step { h.editor.removeQuestion(at: q2) }
        h.step { h.editor.setQuestionText(at: q1, "Ảnh **mới**") }
        h.step { h.editor.setExplanation(at: q1, "Vì vậy.") }
        // Còn trong bộ nhớ (cho Hoàn tác): ảnh 1 (đã bị thay), ảnh 3 (câu đã xoá).
        #expect(h.editor.draft.package.media.count == 3)

        let reopened = try saveAndReopen(h.document)
        #expect(reopened.draft.exam == h.exam)
        let image = try #require(h.exam.sections[0].questions[0].image)
        #expect(image.hasSuffix(".jpg"))
        #expect(reopened.draft.package.media == [image: imageBytes(2)])
        #expect(h.exam.sections[0].questions[1].image == image)

        // Hoàn tác vẫn khôi phục được ảnh đã bị thay và câu đã xoá, rồi lưu lại có đủ ảnh.
        while h.undo.canUndo { h.undo.undo() }
        h.undo.redo()
        h.undo.redo()
        h.undo.redo()
        let restored = try saveAndReopen(h.document)
        #expect(restored.draft.package.media.count == 2)
        #expect(Set(restored.draft.package.media.values) == [imageBytes(2), imageBytes(3)])
    }

    @Test("Mở file có lỗi kiểm đề ở chế độ dễ; lưu không chặn; mở lại ra đúng đề")
    func lenientOpenAndSaveWithErrors() async throws {
        var draft = sampleDraft()
        draft.setTitle("")
        try draft.setCorrect(of: QuestionPath(section: 0, question: 0), at: 0, false)
        let data = try ExamAuthoringDocument.fileData(for: draft.packageForSaving)
        #expect(throws: (any Error).self) { try ExamPackageReader.read(data, mode: .strict) }
        let document = try ExamAuthoringDocument(fileData: data)
        #expect(document.draft == draft)
        let editor = document.editor
        await editor.waitForValidation()
        #expect(editor.issues.errorCount == 2)
        #expect(editor.fileRejection == nil)
        #expect(editor.studentRejection == "đề còn 2 lỗi.")
        let reopened = try saveAndReopen(document)
        #expect(reopened.draft == draft)
    }

    @Test("File có trường lạ: mở được, báo bản Học viên sẽ từ chối; lưu lại bỏ trường lạ và hết báo")
    func unknownFieldsAreReportedThenDroppedOnSave() async throws {
        let exam = sampleDraft().exam
        var json = try JSONSerialization.jsonObject(with: ExamJSON.encode(exam)) as! [String: Any]
        json["hint"] = "trường lạ"
        let manifest = try JSONSerialization.data(withJSONObject: json)
        let data = StoredZip.make([("exam.json", manifest)])

        let document = try ExamAuthoringDocument(fileData: data)
        #expect(document.draft.exam == exam)
        let editor = document.editor
        await editor.waitForValidation()
        let rejection = try #require(editor.studentRejection)
        #expect(rejection.contains("hint"))

        let snapshot = try document.snapshot(contentType: .examPackage)
        let rewritten = try document.write(snapshot)
        #expect(throws: Never.self) { try ExamPackageReader.read(rewritten, mode: .strict) }
        // Gửi byte đi ghi chưa phải đã ghi xong (phát hiện 7): chỉ hết báo khi file trên đĩa đã sạch.
        try await Task.sleep(for: .milliseconds(50))
        #expect(editor.fileRejection != nil)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44a-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("de.exam")
        try data.write(to: file)
        await editor.recheckFile(at: file)
        #expect(editor.fileRejection != nil, "Lưu thất bại: file trên đĩa vẫn là file cũ")
        try rewritten.write(to: file)
        await editor.recheckFile(at: file)
        #expect(editor.fileRejection == nil)
        #expect(editor.studentRejection == nil)
    }

    @Test("File không đọc được kể cả chế độ dễ: lỗi có lý do tiếng Việt")
    func corruptFile() {
        let error = #expect(throws: CocoaError.self) {
            try ExamAuthoringDocument(fileData: Data("không phải zip".utf8))
        }
        #expect((error?.userInfo[NSLocalizedFailureReasonErrorKey] as? String)?.contains("zip") == true)
    }

    @Test("Đọc file ảnh: đúng byte và đuôi; từ chối loại khác và ảnh vượt giới hạn trước khi đọc cả file")
    func imageFileLoader() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44a-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let png = directory.appendingPathComponent("anh.PNG")
        try imageBytes(7, count: 200).write(to: png)
        let loaded = try ImageFileLoader.load(png)
        #expect(loaded.data == imageBytes(7, count: 200))
        #expect(loaded.fileExtension == "PNG")

        let bmp = directory.appendingPathComponent("anh.bmp")
        try Data([1, 2, 3]).write(to: bmp)
        #expect(throws: ExamEditError.unsupportedImageType("bmp")) { try ImageFileLoader.load(bmp) }

        var limits = ExamPackageLimits.default
        limits.mediaEntryBytes = 100
        #expect(throws: ExamEditError.imageTooLarge(bytes: 204, limit: 100)) { try ImageFileLoader.load(png, limits: limits) }
    }

    @Test("Thêm ảnh từ file qua bộ soạn đề; lỗi thì báo, đề không đổi")
    func importImageThroughEditor() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44a-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("hinh.webp")
        try imageBytes(9).write(to: file)
        let h = EditorHarness()
        let p = QuestionPath(section: 0, question: 0)
        await h.editor.importImage(from: file, to: p)
        h.endEvent()
        let image = try #require(h.editor.question(at: p)?.image)
        #expect(image.hasSuffix(".webp"))
        #expect(h.editor.imageData(for: try #require(h.editor.question(at: p))) == imageBytes(9))

        let before = h.editor.draft
        await h.editor.importImage(from: directory.appendingPathComponent("khong-co.png"), to: p)
        #expect(h.editor.draft == before)
        #expect(h.editor.alert?.title == "Không thay ảnh được")
    }
}
