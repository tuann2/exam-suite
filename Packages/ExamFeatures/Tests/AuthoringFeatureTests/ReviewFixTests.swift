import AuthoringData
@testable import AuthoringFeature
import ExamFile
import ExamKit
import Foundation
import Testing

/// Các phát hiện của review độc lập PR #34 (bb6dfab): mỗi test chứng minh một chỗ sửa.
@MainActor
@Suite("Review PR #34: UndoManager thiếu, ảnh sai tên, ảnh chạy nền, thanh lỗi cũ, đọc ảnh, xoá báo sau khi lưu")
struct ReviewFixTests {
    private func path(_ s: Int, _ q: Int) -> QuestionPath { QuestionPath(section: s, question: q) }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g44a-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: 1. Bộ soạn đề của document không có UndoManager

    @Test("Phát hiện 1: sửa khi bộ soạn đề của document chưa có UndoManager thì báo lỗi lập trình (fault + assert ở Debug)")
    func missingUndoManagerIsReported() {
        let document = ExamAuthoringDocument(draft: sampleDraft())
        let editor = document.editor
        var reported: [String] = []
        editor.reportMissingUndoManager = { reported.append($0) }
        editor.setTitle("Tên mới")
        #expect(reported == ["Sửa tên đề"])
        #expect(document.draft.exam.title == "Tên mới")

        // Có UndoManager thì không báo.
        let h = EditorHarness()
        h.editor.reportMissingUndoManager = { reported.append($0) }
        h.step { h.editor.setTitle("Khác") }
        #expect(reported == ["Sửa tên đề"])

        // Đã có rồi mất (cửa sổ đang đóng, ô số commit lúc rời ô): chỉ ghi log, không báo lỗi lập trình.
        h.editor.undoManager = nil
        h.editor.setPassPercent(80)
        #expect(reported == ["Sửa tên đề"])
    }

    // MARK: Re-review A: id trùng

    /// Q1 (0,0) và Q3 (0,2) cùng id 11, cả hai trống lựa chọn B.
    private func duplicateIDDraft() throws -> ExamDraft {
        var draft = sampleDraft()
        try draft.updateQuestion(QuestionPath(section: 0, question: 2)) { $0.id = fixedID(11) }
        try draft.setOptionText(of: QuestionPath(section: 0, question: 0), at: 1, "")
        try draft.setOptionText(of: QuestionPath(section: 0, question: 2), at: 1, "")
        return draft
    }

    @Test("Re-review A: id trùng, kết quả kiểm đã cũ: bấm vấn đề của Q3 chọn Q3 (đúng chỗ cũ, hoặc gần chỗ cũ nhất)")
    func staleIssueWithDuplicateIDs() async throws {
        let h = EditorHarness(try duplicateIDDraft())
        await h.editor.waitForValidation()
        let q3Issue = try #require(h.editor.issues.issues.first {
            $0.code == .optionTextEmpty && IssueTarget($0).node.treeRow == .question(path(0, 2))
        })

        // Sửa chữ Q2: kết quả cũ nhưng vị trí không đổi → đúng chỗ cũ.
        h.step { h.editor.setQuestionText(at: path(0, 1), "Q2 sửa") }
        #expect(!h.editor.issuesAreCurrent)
        h.editor.navigate(to: q3Issue)
        #expect(h.editor.selection == .question(path(0, 2)))

        // Xoá Q2: Q3 lùi về (0,1); ứng viên gần chỗ cũ (0,2) nhất là Q3, không phải Q1 ở (0,0).
        h.editor.selection = .exam
        let current = try #require(h.editor.issues.issues.first {
            $0.code == .optionTextEmpty && IssueTarget($0).node.treeRow == .question(path(0, 2))
        })
        h.step { h.editor.removeQuestion(at: path(0, 1)) }
        h.editor.navigate(to: current)
        #expect(h.editor.selection == .question(path(0, 1)))
        #expect(h.editor.question(at: path(0, 1))?.text == "Q3")
    }

    @Test("Re-review A: id trùng, ảnh đọc nền theo câu đã dời chỗ: chọn câu cùng id gần chỗ cũ nhất")
    func asyncImageWithDuplicateIDs() async throws {
        let h = EditorHarness(try duplicateIDDraft())
        await h.editor.importImage(from: URL(fileURLWithPath: "/tmp/anh.png"), to: path(0, 2)) { _ in
            await MainActor.run { h.step { h.editor.removeQuestion(at: QuestionPath(section: 0, question: 1)) } }
            return ImageFileLoader.Loaded(data: imageBytes(6), fileExtension: "png")
        }
        h.endEvent()
        #expect(h.editor.question(at: path(0, 1))?.text == "Q3")
        #expect(h.editor.question(at: path(0, 1))?.image != nil)
        #expect(h.editor.question(at: path(0, 0))?.image == nil)
        #expect(h.editor.currentPath(of: fixedID(11), near: path(0, 0)) == path(0, 0))
        #expect(h.editor.currentPath(of: fixedID(99), near: path(0, 0)) == nil)
    }

    // MARK: 2. Ảnh có trong file nhưng sai tên

    /// Gói làm tay: câu 1 trỏ `media/photo.png` (có entry, sai tên), câu 2 trỏ ảnh đúng mẫu nhưng không có trong gói.
    private func misnamedImagePackage() throws -> Data {
        var exam = sampleDraft().exam
        exam.sections[0].questions[0].image = "media/photo.png"
        exam.sections[0].questions[1].image = "media/0123456789abcdef.png"
        return StoredZip.make([
            ("exam.json", try ExamJSON.encode(exam)),
            ("media/photo.png", imageBytes(5, count: 2_000)),
        ])
    }

    @Test("Phát hiện 2: ảnh sai tên trong file được nêu rõ (sẽ bị bỏ khi lưu), khác với ảnh không có trong gói")
    func misnamedImageIsExplained() async throws {
        let data = try misnamedImagePackage()
        #expect(ZipEntryNames.names(in: data) == ["exam.json", "media/photo.png"])
        let document = try ExamAuthoringDocument(fileData: data)
        let editor = document.editor
        await editor.waitForValidation()
        #expect(editor.misnamedImages == ["media/photo.png"])

        let wrongName = try #require(editor.issues(for: .question(path(0, 0)), field: .image).first)
        #expect(editor.message(for: wrongName) == """
            Ảnh media/photo.png sai tên (phải theo SHA-256), không dùng được và sẽ bị bỏ khi lưu; \
            dùng Thêm/Thay ảnh… để thêm lại.
            """)
        #expect(editor.missingImageMessage(for: try #require(editor.question(at: path(0, 0)))) == editor.message(for: wrongName))

        let missing = try #require(editor.issues(for: .question(path(0, 1)), field: .image).first)
        #expect(editor.message(for: missing) == missing.message)
        #expect(editor.missingImageMessage(for: try #require(editor.question(at: path(0, 1))))
            == "Không có ảnh media/0123456789abcdef.png trong gói.")

        // Lưu: file mới không còn entry sai tên (như exam-format.md), nên đọc lại file thì hết nói "sai tên".
        let rewritten = try document.write(try document.snapshot(contentType: .examPackage))
        #expect(ZipEntryNames.names(in: rewritten) == ["exam.json"])
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("de.exam")
        try rewritten.write(to: file)
        await editor.recheckFile(at: file)
        #expect(editor.misnamedImages.isEmpty)
        #expect(editor.message(for: wrongName) == wrongName.message)
    }

    @Test("Phát hiện 2: đọc tên entry của zip do ExamPackageWriter ghi; dữ liệu không phải zip thì không biết")
    func zipEntryNames() throws {
        var draft = sampleDraft()
        try draft.setImage(of: path(0, 0), data: imageBytes(1), fileExtension: "png")
        let names = try #require(ZipEntryNames.names(in: draft.fileData()))
        #expect(names.count == 2)
        #expect(names.contains("exam.json"))
        #expect(names.contains(try #require(draft.exam.sections[0].questions[0].image)))
        #expect(ZipEntryNames.names(in: Data("không phải zip".utf8)) == nil)
        #expect(ZipEntryNames.names(in: Data()) == nil)
    }

    // MARK: 3. Ảnh đọc ở nền áp vào đúng câu

    @Test("Phát hiện 3: câu bị xoá trong lúc đọc ảnh thì bỏ ảnh và báo; không gắn nhầm câu đứng vào chỗ đó")
    func asyncImageForDeletedQuestionIsDropped() async {
        let h = EditorHarness()
        await h.editor.importImage(from: URL(fileURLWithPath: "/tmp/anh.png"), to: path(0, 0)) { _ in
            await MainActor.run { h.step { h.editor.removeQuestion(at: QuestionPath(section: 0, question: 0)) } }
            return ImageFileLoader.Loaded(data: imageBytes(3), fileExtension: "png")
        }
        h.endEvent()
        #expect(h.editor.question(at: path(0, 0))?.id == fixedID(12))
        #expect(h.exam.allQuestions.allSatisfy { $0.image == nil })
        #expect(h.editor.alert?.message == ImageFileError.questionRemoved.errorDescription)
    }

    @Test("Phát hiện 3: câu dời chỗ trong lúc đọc ảnh thì ảnh theo câu tới chỗ mới")
    func asyncImageFollowsMovedQuestion() async throws {
        let h = EditorHarness()
        await h.editor.importImage(from: URL(fileURLWithPath: "/tmp/anh.png"), to: path(0, 1)) { _ in
            await MainActor.run {
                h.editor.selection = .section(index: 0)
                h.step { h.editor.moveQuestion(at: QuestionPath(section: 0, question: 0), toSection: 1) }
            }
            return ImageFileLoader.Loaded(data: imageBytes(4), fileExtension: "png")
        }
        h.endEvent()
        let q2 = try #require(h.editor.question(at: path(0, 0)))
        #expect(q2.id == fixedID(12))
        #expect(q2.image != nil)
        #expect(h.editor.question(at: path(0, 1))?.image == nil)
        #expect(h.editor.alert == nil)
    }

    // MARK: 5. Bấm thanh lỗi khi kết quả kiểm đã cũ

    @Test("Phát hiện 5: bấm vấn đề cũ sau khi xoá câu phía trước: kiểm ngay, chọn đúng câu theo id")
    func staleIssueNavigatesToSameQuestion() async throws {
        var draft = sampleDraft()
        try draft.setOptionText(of: QuestionPath(section: 0, question: 1), at: 1, "")
        let h = EditorHarness(draft)
        await h.editor.waitForValidation()
        let issue = try #require(h.editor.issues.issues.first { $0.code == .optionTextEmpty })
        #expect(h.editor.issuesAreCurrent)

        h.step { h.editor.removeQuestion(at: path(0, 0)) }
        #expect(!h.editor.issuesAreCurrent)
        h.editor.navigate(to: issue)
        #expect(h.editor.selection == .question(path(0, 0)))
        #expect(h.editor.question(at: path(0, 0))?.id == fixedID(12))
        #expect(h.editor.focusRequest?.focus == .optionText(1))
        #expect(h.editor.issuesAreCurrent)

        // Câu của vấn đề đã bị xoá: không chọn câu nào khác.
        let stale = try #require(h.editor.issues.issues.first { $0.code == .optionTextEmpty })
        h.step { h.editor.removeQuestion(at: path(0, 0)) }
        h.editor.selection = .exam
        h.editor.navigate(to: stale)
        #expect(h.editor.selection == .exam)
    }

    // MARK: 6. Đọc file ảnh

    @Test("Phát hiện 6: chỉ nhận file trên máy; không đọc được kích thước thì báo lỗi, không đọc cả file")
    func imageLoaderRequiresReadableFile() throws {
        #expect(throws: ImageFileError.notAFile) {
            try ImageFileLoader.load(try #require(URL(string: "https://example.com/anh.png")))
        }
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: ImageFileError.unreadable("khong-co.png")) {
            try ImageFileLoader.load(directory.appendingPathComponent("khong-co.png"))
        }
    }
}
