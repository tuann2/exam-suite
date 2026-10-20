import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import LibraryFeature
import Testing

/// Luồng của `LibraryModel` trên kho thật trong bộ nhớ và file thật trong thư mục tạm
/// (docs/product/library.md: Thêm đề, trùng id, Xoá + Hoàn tác, mở từ Finder, Tìm file…, Sửa, đề mẫu).
@MainActor
@Suite("LibraryModel: thêm đề, hộp thoại, thông báo, hoàn tác")
struct LibraryModelTests {
    // MARK: - Thêm đề

    @Test("Thêm file hợp lệ: đề được chọn, thông báo “Đã thêm đề…”, không hộp thoại")
    func importValidFile() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Kiến thức chung", code: "KTC01")
        let file = try workspace.write(exam, to: "Downloads/Kiến thức chung.exam")

        await model.importFiles([file]).value

        #expect(model.store.entry(exam.id)?.status == .ready)
        #expect(model.selection == exam.id)
        #expect(model.notice?.message == "Đã thêm đề “Kiến thức chung”.")
        #expect(model.notice?.undoRemovalID == nil)
        #expect(model.prompts.isEmpty)
        #expect(model.pendingOperations == 0)
    }

    @Test("Thêm một file và lấy kết quả (Thử đề này của bản Admin): cùng luồng Thêm đề, trả đúng kết quả của file")
    func addExamFileReturnsOutcome() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel(admin: true)
        let exam = makeExam(title: "Đề thử")
        let file = try workspace.write(exam, to: "Đề thử.exam")

        #expect(await model.addExamFile(file) == .added(examID: exam.id))
        #expect(model.selection == exam.id)
        #expect(model.notice?.message == "Đã thêm đề “Đề thử”.")
        #expect(await model.addExamFile(file) == .alreadyInLibrary(examID: exam.id))
        #expect(model.store.entries.count == 1)

        let garbage = try workspace.writeGarbage(to: "hong.exam")
        guard case .rejected = await model.addExamFile(garbage) else {
            Issue.record("file hỏng phải bị từ chối")
            return
        }
        guard case .importProblems = model.prompts.last?.kind else {
            Issue.record("Thư viện phải báo file không thêm được")
            return
        }
        #expect(model.pendingOperations == 0)
    }

    @Test("Thêm lại đúng file đã có: chọn đề đó, báo “Đề đã có trong thư viện”")
    func importSameFileAgain() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề A")
        let other = makeExam(title: "Đề B")
        let file = try workspace.write(exam, to: "a.exam")
        await model.importFiles([file, try workspace.write(other, to: "b.exam")]).value
        #expect(model.notice?.message == "Đã thêm 2 đề.")
        #expect(model.selection == other.id)

        await model.importFiles([file]).value

        #expect(model.store.entries.count == 2)
        #expect(model.selection == exam.id)
        #expect(model.notice?.message == "Đề đã có trong thư viện: “Đề A”.")
        #expect(model.prompts.isEmpty)
    }

    @Test("Trùng id khác file: hỏi “Đề này đã có trong thư viện từ file khác”; Dùng file mới thì chuyển sang file mới")
    func replaceWithNewFile() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề gốc")
        let original = try workspace.write(exam, to: "Cũ/de.exam")
        var renamed = exam
        renamed.title = "Đề gốc bản mới"
        let newer = try workspace.write(renamed, to: "Mới/de.exam")
        await model.importFiles([original]).value

        await model.importFiles([newer]).value

        let prompt = try #require(model.prompts.first)
        guard case .replace(let pending) = prompt.kind else {
            Issue.record("Cần hộp thoại Dùng file mới, có \(prompt.kind)")
            return
        }
        #expect(prompt.alertTitle == "Đề này đã có trong thư viện từ file khác")
        #expect(prompt.alertMessage.contains(pending.existingFileURL.path))
        #expect(prompt.alertMessage.contains(pending.newFileURL.path))
        #expect(model.store.entry(exam.id)?.title == "Đề gốc")

        model.confirmReplacement(promptID: prompt.id)

        #expect(model.prompts.isEmpty)
        let entry = try #require(model.store.entry(exam.id))
        #expect(entry.title == "Đề gốc bản mới")
        #expect(sameFile(entry.fileURL, newer))
        #expect(model.selection == exam.id)
        #expect(model.notice?.message == "Đề “Đề gốc bản mới” giờ dùng file mới.")
    }

    @Test("Trùng id khác file, Huỷ: không đổi gì")
    func cancelReplacement() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề gốc")
        let original = try workspace.write(exam, to: "Cũ/de.exam")
        await model.importFiles([original]).value
        await model.importFiles([try workspace.write(exam, to: "Mới/de.exam")]).value
        let prompt = try #require(model.prompts.first)

        model.dismissPrompt(prompt.id)

        #expect(model.prompts.isEmpty)
        #expect(sameFile(try #require(model.store.entry(exam.id)).fileURL, original))
    }

    @Test("File không thêm được và file không phải .exam: báo gọn một lần, theo thứ tự, kèm lý do và bước tiếp theo")
    func importProblemsAreReportedTogether() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let good = makeExam(title: "Đề tốt")
        let garbage = try workspace.writeGarbage(to: "hong.exam")
        let notes = try workspace.writeGarbage(to: "ghi-chu.txt")
        let goodFile = try workspace.write(good, to: "tot.exam")

        await model.importFiles([garbage, goodFile, notes]).value

        #expect(model.notice?.message == "Đã thêm đề “Đề tốt”.")
        #expect(model.selection == good.id)
        #expect(model.prompts.count == 1)
        let prompt = try #require(model.prompts.first)
        guard case .importProblems(let problems) = prompt.kind else {
            Issue.record("Cần báo file không thêm được, có \(prompt.kind)")
            return
        }
        #expect(!prompt.isAlert)
        #expect(problems.map(\.fileName) == ["hong.exam", "ghi-chu.txt"])
        #expect(problems[0].reason == ExamFileError.notAZipArchive.errorDescription)
        #expect(problems[0].nextStep == ImportProblem.nextStep(for: .corrupt(reason: .package(.notAZipArchive))))
        #expect(problems[1].reason == "Không phải file đề .exam.")
        #expect(problems[1].nextStep == "Chỉ thêm được file đề có đuôi .exam.")
        #expect(Set(problems.map(\.id)).count == 2)

        model.dismissPrompt(prompt.id)
        #expect(model.prompts.isEmpty)
    }

    @Test("Bước tiếp theo theo loại vấn đề của file")
    func nextStepsPerProblem() {
        #expect(ImportProblem.nextStep(for: .corrupt(reason: .stored("x"))) == "Kiểm tra lại file hoặc xin người soạn đề gửi lại file khác.")
        #expect(ImportProblem.nextStep(for: .needsNewerApp(found: 2, supported: 1)) == "Cập nhật Exam Suite lên bản mới hơn rồi thêm lại.")
        #expect(ImportProblem.nextStep(for: .invalid(reason: .stored("x"))) == "Báo người soạn đề sửa đề bằng bản Admin rồi gửi lại.")
    }

    @Test("Gộp thông báo: đếm đề không trùng, đề vừa thêm không tính là “đã có”")
    func noticeComposition() {
        let a = UUID()
        let b = UUID()
        let titles = [a: "A", b: "B"]
        #expect(ImportFeedback.notice(added: [], existing: [], titles: titles) == nil)
        #expect(ImportFeedback.notice(added: [a], existing: [], titles: titles) == "Đã thêm đề “A”.")
        #expect(ImportFeedback.notice(added: [a, b], existing: [], titles: titles) == "Đã thêm 2 đề.")
        #expect(ImportFeedback.notice(added: [], existing: [b], titles: titles) == "Đề đã có trong thư viện: “B”.")
        #expect(ImportFeedback.notice(added: [a], existing: [b], titles: titles) == "Đã thêm đề “A”. Đề đã có trong thư viện: “B”.")
        #expect(ImportFeedback.notice(added: [], existing: [a, b], titles: titles) == "2 đề đã có trong thư viện.")
        #expect(ImportFeedback.unique([a, b, a]) == [a, b])
    }

    @Test("Chọn đề sau khi thêm: về Tất cả đề, bỏ tìm kiếm và bộ lọc đang ẩn đề đó")
    func revealAfterImport() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Toán cao cấp")
        model.selectSection(.history)
        model.searchText = "lịch sử"
        model.filter = .problems

        await model.importFiles([try workspace.write(exam, to: "toan.exam")]).value

        #expect(model.section == .all)
        #expect(model.searchText.isEmpty)
        #expect(model.filter == .all)
        #expect(model.selection == exam.id)
        #expect(model.visibleEntries(order: .name).map(\.examID) == [exam.id])
    }

    @Test("Tìm kiếm và bộ lọc khớp thì giữ nguyên khi chọn đề vừa thêm")
    func revealKeepsMatchingQuery() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        model.searchText = "toan"
        model.filter = .ready

        let exam = makeExam(title: "Toán rời rạc")
        await model.importFiles([try workspace.write(exam, to: "toan.exam")]).value

        #expect(model.searchText == "toan")
        #expect(model.filter == .ready)
        #expect(model.selection == exam.id)
    }

    // MARK: - Mở từ Finder (bản Học viên)

    @Test("Mở .exam từ Finder: mở/đưa cửa sổ Thư viện lên, đi qua luồng Thêm đề, chọn đề đó")
    func openFromFinder() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        var presented = 0
        model.presentWindow = { presented += 1 }
        let exam = makeExam(title: "Đề từ Finder")
        let file = try workspace.write(exam, to: "Desktop/de.exam")

        await model.openFromFinder([file]).value

        #expect(presented == 1)
        #expect(model.selection == exam.id)
        #expect(model.notice?.message == "Đã thêm đề “Đề từ Finder”.")
    }

    @Test("Mở cùng một file hai lần liền nhau: các lần thêm chạy lần lượt, chỉ một mục, không hỏi Dùng file mới")
    func finderOpensAreSerialized() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề nhấp đúp hai lần", questions: 300)
        let file = try workspace.write(exam, to: "de.exam")

        let first = model.openFromFinder([file])
        let second = model.openFromFinder([file])
        #expect(model.pendingOperations == 2)
        await first.value
        await second.value

        #expect(model.store.entries.count == 1)
        #expect(model.prompts.isEmpty)
        #expect(model.notice?.message == "Đề đã có trong thư viện: “Đề nhấp đúp hai lần”.")
        #expect(model.pendingOperations == 0)
    }

    @Test("Mở từ Finder lúc app vừa khởi động: kho đã tải nên đề có sẵn được nhận ra, không thành mục trùng")
    func finderOpenDuringLaunchUsesLoadedStore() async throws {
        let workspace = try FeatureWorkspace()
        let exam = makeExam(title: "Đề có sẵn")
        let file = try workspace.write(exam, to: "de.exam")
        let first = workspace.makeModel()
        await first.importFiles([file]).value

        // Lần mở app sau, cùng kho: app delegate nhận file trước khi start() chạy xong.
        let relaunched = LibraryModel(store: first.store, startsAutomatically: true)
        let opening = relaunched.openFromFinder([file])
        await opening.value
        await relaunched.waitUntilStarted()

        #expect(relaunched.store.entries.count == 1)
        #expect(relaunched.prompts.isEmpty)
        #expect(relaunched.selection == exam.id)
    }

    // MARK: - Hộp thoại chọn file, Tìm file…

    @Test("Hộp thoại Thêm đề: kết quả đến sau khi hộp thoại báo đóng vẫn được thêm; huỷ thì không làm gì")
    func fileImporterFlow() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề chọn bằng hộp thoại")
        let file = try workspace.write(exam, to: "de.exam")

        model.requestAddExams()
        #expect(model.fileImportRequest == .addExams)
        #expect(model.fileImportRequest?.allowsMultipleSelection == true)
        model.fileImporterDismissed()
        #expect(model.fileImportRequest == nil)
        let task = try #require(model.completeFileImport(.success([file])))
        await task.value
        #expect(model.selection == exam.id)

        model.requestAddExams()
        model.cancelFileImport()
        #expect(model.completeFileImport(.success([file])) == nil)
        model.requestAddExams()
        #expect(model.completeFileImport(.failure(CocoaError(.userCancelled))) == nil)
        #expect(model.prompts.isEmpty)
    }

    @Test("Tìm file… cho đề mất file: chọn đúng file thì Sẵn sàng; chọn đề khác thì báo lý do, không đổi")
    func locateMissingFile() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề mất file")
        let original = try workspace.write(exam, to: "Ổ cũ/de.exam")
        await model.importFiles([original]).value
        try FileManager.default.removeItem(at: original)
        await model.store.refreshAll()
        #expect(model.store.entry(exam.id)?.status == .missing)
        model.infoExamID = exam.id

        model.requestLocate(exam.id)
        #expect(model.infoExamID == nil)
        #expect(model.fileImportRequest == .locate(examID: exam.id))
        #expect(model.fileImportRequest?.allowsMultipleSelection == false)
        let other = try workspace.write(makeExam(title: "Đề khác"), to: "khac.exam")
        await model.completeFileImport(.success([other]))?.value

        let prompt = try #require(model.prompts.first)
        #expect(prompt.alertTitle == "Không dùng được file này")
        #expect(prompt.alertMessage == LibraryError.differentExam(expectedTitle: "Đề mất file", foundTitle: "Đề khác").logMessage)
        #expect(model.store.entry(exam.id)?.status == .missing)
        model.dismissPrompt(prompt.id)

        let found = try workspace.write(exam, to: "Ổ mới/de.exam")
        model.requestLocate(exam.id)
        await model.completeFileImport(.success([found]))?.value

        #expect(model.prompts.isEmpty)
        let entry = try #require(model.store.entry(exam.id))
        #expect(entry.status == .ready)
        #expect(sameFile(entry.fileURL, found))
        #expect(model.notice?.message == "Đã tìm thấy file của đề “Đề mất file”.")
    }

    // MARK: - Xoá khỏi thư viện, hoàn tác

    @Test("Xoá khỏi thư viện: không hỏi lại, thông báo kèm Hoàn tác; nút Hoàn tác đưa đề trở lại y nguyên")
    func removeAndUndoFromNotice() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        model.undoManager = undoManager
        let exam = makeExam(title: "Đề sẽ xoá")
        let file = try workspace.write(exam, to: "de.exam")
        await model.importFiles([file]).value
        let before = try #require(model.store.entry(exam.id))
        model.infoExamID = exam.id

        undoManager.beginUndoGrouping()
        model.remove(exam.id)
        undoManager.endUndoGrouping()

        #expect(model.store.entry(exam.id) == nil)
        #expect(FileManager.default.fileExists(atPath: file.path), "Không xoá file")
        #expect(model.selection == nil)
        #expect(model.infoExamID == nil)
        let notice = try #require(model.notice)
        #expect(notice.message == "Đã xoá “Đề sẽ xoá” khỏi thư viện.")
        let removalID = try #require(notice.undoRemovalID)
        #expect(undoManager.canUndo)
        #expect(undoManager.undoActionName == "Xoá khỏi thư viện")

        model.undoRemoval(removalID)

        #expect(model.store.entry(exam.id) == before)
        #expect(model.selection == exam.id)
        #expect(model.notice == nil)
        // Đã hoàn tác bằng nút thì ⌘Z không còn bước xoá này nữa.
        #expect(!undoManager.canUndo)
        model.undoRemoval(removalID)
        #expect(model.store.entries.count == 1)
    }

    @Test("⌘Z hoàn tác Xoá khỏi thư viện qua UndoManager của cửa sổ; ⇧⌘Z xoá lại", arguments: [false, true])
    func undoAndRedoWithUndoManager(admin: Bool) async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel(admin: admin)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        model.undoManager = undoManager
        let exam = makeExam(title: "Đề hoàn tác")
        await model.importFiles([try workspace.write(exam, to: "de.exam")]).value
        let before = try #require(model.store.entry(exam.id))

        undoManager.beginUndoGrouping()
        model.remove(exam.id)
        undoManager.endUndoGrouping()
        undoManager.undo()

        #expect(model.store.entry(exam.id) == before)
        #expect(model.notice == nil)
        #expect(undoManager.canRedo)

        undoManager.redo()
        #expect(model.store.entry(exam.id) == nil)
        #expect(model.notice?.undoRemovalID != nil)
        #expect(undoManager.canUndo)

        undoManager.undo()
        #expect(model.store.entry(exam.id) == before)
    }

    @Test("Không có UndoManager: vẫn hoàn tác được bằng nút trên thông báo")
    func undoWithoutUndoManager() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề")
        await model.importFiles([try workspace.write(exam, to: "de.exam")]).value

        model.remove(exam.id)
        model.undoRemoval(try #require(model.notice?.undoRemovalID))

        #expect(model.store.entry(exam.id) != nil)
    }

    @Test("Hoàn tác khi đề đã được thêm lại: báo lỗi, không tạo mục trùng")
    func undoAfterReAdd() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let exam = makeExam(title: "Đề")
        let file = try workspace.write(exam, to: "de.exam")
        await model.importFiles([file]).value
        model.remove(exam.id)
        let removalID = try #require(model.notice?.undoRemovalID)
        let removed = try #require(model.notice)
        await model.importFiles([file]).value
        // Thông báo mới thay thông báo xoá; giữ lại id để thử hoàn tác muộn.
        #expect(model.notice != removed)

        model.undoRemoval(removalID)

        #expect(model.store.entries.count == 1)
    }

    @Test("Thông báo hết giờ chỉ ẩn đúng thông báo đó")
    func noticeExpiry() {
        let model = LibraryModel(store: .preview(entries: []), startsAutomatically: false)
        let first = LibraryNotice(message: "Một")
        let second = LibraryNotice(message: "Hai")
        model.show(first)
        model.show(second)

        model.expireNotice(first.id)
        #expect(model.notice == second)
        model.expireNotice(second.id)
        #expect(model.notice == nil)
        model.show(first)
        model.dismissNotice()
        #expect(model.notice == nil)
    }

    // MARK: - Thông tin, Finder, lịch sử, Sửa

    @Test("Thông tin, Hiện trong Finder, Xem lịch sử thi")
    func infoRevealHistory() async throws {
        let workspace = try FeatureWorkspace()
        let revealed = RevealRecorder()
        let model = workspace.makeModel(revealed: revealed)
        let exam = makeExam(title: "Đề")
        let file = try workspace.write(exam, to: "de.exam")
        await model.importFiles([file]).value
        model.selection = nil

        model.showInfo(exam.id)
        #expect(model.infoExamID == exam.id)
        #expect(model.selection == exam.id)

        model.revealInFinder(exam.id)
        #expect(revealed.urls.count == 1)
        #expect(sameFile(try #require(revealed.urls.first), file))

        model.showHistory(for: exam.id)
        #expect(model.section == .history)
        #expect(model.historyExamID == exam.id)
        #expect(model.historyExamTitle == "Đề")
        #expect(model.commandContext.selectedExamID == nil)
        model.showAllHistory()
        #expect(model.historyExamID == nil)
        model.showHistory(for: exam.id)
        model.selectSection(.all)
        #expect(model.historyExamID == nil)

        try FileManager.default.removeItem(at: file)
        model.revealInFinder(exam.id)
        #expect(revealed.urls.count == 1)
        #expect(model.notice?.message == "Không tìm thấy file của đề “Đề”.")
    }

    @Test("Sửa chỉ có ở bản Admin, khi file đọc được; mở xong thì ghi lần mở, lỗi thì báo")
    func editRequests() async throws {
        let workspace = try FeatureWorkspace()
        let student = workspace.makeModel()
        let admin = try FeatureWorkspace().makeModel(admin: true)
        let exam = makeExam(title: "Đề sửa")
        let file = try workspace.write(exam, to: "de.exam")
        await student.importFiles([file]).value
        await admin.importFiles([file]).value

        student.requestEdit(exam.id)
        #expect(student.editRequest == nil)
        #expect(!student.commandContext.canEditSelection)

        admin.infoExamID = exam.id
        admin.requestEdit(exam.id)
        let request = try #require(admin.editRequest)
        #expect(admin.infoExamID == nil)
        #expect(sameFile(request.fileURL, file))
        #expect(admin.commandContext.canEditSelection)
        admin.finishEdit(request, error: nil)
        #expect(admin.editRequest == nil)
        #expect(admin.store.entry(exam.id)?.lastOpenedAt != nil)

        admin.requestEdit(exam.id)
        admin.finishEdit(try #require(admin.editRequest), error: CocoaError(.fileReadCorruptFile))
        #expect(admin.prompts.first?.alertTitle == "Không mở được đề để sửa")
    }

    @Test("Sửa bật theo trạng thái file (bản Admin)")
    func canEditPerStatus() {
        let statuses: [(LibraryEntryStatus, Bool)] = [
            (.ready, true), (.checking, true), (.readableWithIssues(reason: .stored("x")), true),
            (.missing, false), (.corrupt(reason: .stored("x")), false), (.needsNewerApp(found: 2, supported: 1), false),
        ]
        let admin = LibraryModel(store: .preview(entries: [], configuration: .admin), startsAutomatically: false)
        let student = LibraryModel(store: .preview(entries: []), startsAutomatically: false)
        for (status, expected) in statuses {
            let entry = PresentationTests.entry(title: "Đề", code: nil, questions: 1, status: status)
            #expect(admin.canEdit(entry) == expected, "\(status)")
            #expect(!student.canEdit(entry))
        }
    }

    // MARK: - Danh sách, lịch sử, bàn phím

    @Test("Đề hiện theo mục sidebar, tìm, lọc, sắp xếp; bỏ chọn đề không còn hiện")
    func visibleEntries() throws {
        let now = Date(timeIntervalSince1970: 1_792_053_000)
        let day: TimeInterval = 86_400
        func entry(_ title: String, addedDaysAgo: Double, status: LibraryEntryStatus = .ready) -> LibraryEntry {
            LibraryEntry(
                examID: UUID(),
                summary: ExamSummary(title: title, questionCount: 5, sectionCount: 1, timeLimitMinutes: 10, passPercent: 50),
                fileURL: URL(fileURLWithPath: "/tmp/\(title).exam"),
                addedAt: now.addingTimeInterval(-addedDaysAgo * day),
                status: status
            )
        }
        let old = entry("Đề cũ", addedDaysAgo: 90)
        let fresh = entry("Toán mới", addedDaysAgo: 2)
        let broken = entry("Ăn uống", addedDaysAgo: 5, status: .missing)
        let attempt = makeAttempt(examID: old.examID, title: "Đề cũ (tên lúc thi)", submittedAt: now.addingTimeInterval(-day))
        let model = LibraryModel(
            store: .preview(entries: [old, fresh, broken], attempts: [attempt]),
            startsAutomatically: false,
            now: { now }
        )

        #expect(model.visibleEntries(order: .name).map(\.title) == ["Ăn uống", "Đề cũ", "Toán mới"])
        model.filter = .problems
        #expect(model.visibleEntries(order: .name).map(\.title) == ["Ăn uống"])
        model.filter = .ready
        model.searchText = "toan"
        #expect(model.visibleEntries(order: .name).map(\.title) == ["Toán mới"])
        model.searchText = ""
        model.filter = .all

        // Gần đây: lần thi hoặc lần thêm trong 30 ngày, mới nhất trước, bất kể cách sắp xếp.
        model.selectSection(.recent)
        #expect(model.visibleEntries(order: .name).map(\.title) == ["Đề cũ", "Toán mới", "Ăn uống"])
        #expect(model.recentEntries().count == 3)
        model.selectSection(.history)
        #expect(model.visibleEntries(order: .name).isEmpty)

        model.selectSection(.all)
        model.selection = fresh.examID
        model.keepSelection(within: [old.examID, fresh.examID])
        #expect(model.selection == fresh.examID)
        model.keepSelection(within: [old.examID])
        #expect(model.selection == nil)
    }

    @Test("Lịch sử thi: mới nhất trước, lọc theo đề, tìm theo tên đề lúc thi hoặc thí sinh")
    func visibleAttempts() {
        let now = Date(timeIntervalSince1970: 1_792_053_000)
        let examA = UUID()
        let examB = UUID()
        let a1 = makeAttempt(examID: examA, title: "Toán", candidate: "Lan", submittedAt: now.addingTimeInterval(-300))
        let b1 = makeAttempt(examID: examB, title: "Văn", candidate: "Đức", submittedAt: now.addingTimeInterval(-200))
        let a2 = makeAttempt(examID: examA, title: "Toán", candidate: "Minh", submittedAt: now.addingTimeInterval(-100))
        let model = LibraryModel(store: .preview(entries: [], attempts: [a1, b1, a2]), startsAutomatically: false)

        #expect(model.visibleAttempts() == [a2, b1, a1])
        model.showHistory(for: examA)
        #expect(model.visibleAttempts() == [a2, a1])
        // Đề đã xoá khỏi thư viện: tên lấy theo lần thi.
        #expect(model.historyExamTitle == "Toán")
        model.showAllHistory()
        model.searchText = "duc"
        #expect(model.visibleAttempts() == [b1])
        model.searchText = "toan minh"
        #expect(model.visibleAttempts() == [a2])
    }

    @Test("Phím mũi tên đổi đề đang chọn trong lưới")
    func arrowKeysMoveSelection() {
        let ids = (0 ..< 5).map { _ in UUID() }
        let model = LibraryModel(store: .preview(entries: []), startsAutomatically: false)

        model.moveSelection(.down, in: ids, columns: 3)
        #expect(model.selection == ids[0])
        model.moveSelection(.right, in: ids, columns: 3)
        #expect(model.selection == ids[1])
        model.moveSelection(.down, in: ids, columns: 3)
        #expect(model.selection == ids[4])
        model.moveSelection(.up, in: ids, columns: 3)
        #expect(model.selection == ids[1])
        model.moveSelection(.left, in: [], columns: 3)
        #expect(model.selection == ids[1])
    }

    @Test("Ngữ cảnh lệnh menu: đề đang chọn, Hiện trong Finder tắt khi mất file")
    func commandContext() {
        let ready = PresentationTests.entry(title: "A", code: nil, questions: 1, status: .ready)
        let missing = PresentationTests.entry(title: "B", code: nil, questions: 1, status: .missing)
        let model = LibraryModel(store: .preview(entries: [ready, missing]), startsAutomatically: false)

        #expect(model.commandContext.selectedExamID == nil)
        model.selection = ready.examID
        #expect(model.commandContext == LibraryCommandContext(
            selectedExamID: ready.examID,
            canRevealSelection: true,
            canEditSelection: false
        ))
        model.selection = missing.examID
        #expect(model.commandContext.selectedExamID == missing.examID)
        #expect(!model.commandContext.canRevealSelection)
        model.requestSearchFocus()
        #expect(model.searchFocusRequest == 1)
    }

    // MARK: - Mở app, đề mẫu

    @Test("Mở app lần đầu: tạo đề mẫu thật, báo để hiện dải chào mừng; Khôi phục đề mẫu báo kết quả")
    func startAndRestoreSamples() async throws {
        let workspace = try FeatureWorkspace()
        let samples: URL = try #require(LibraryConfiguration.bundledSamplesURL)
        let model = workspace.makeModel(samples: samples)

        model.start()
        model.start()
        await model.waitUntilStarted()

        let report = try #require(model.startReport)
        #expect(report.didAddSamples)
        #expect(WelcomeBannerState.notShown.after(start: report) == .visible)
        #expect(model.store.entries.count == report.sampleCount)
        #expect(model.store.entries.allSatisfy { $0.isSample && $0.status == .ready })
        model.windowBecameActive()

        let sampleID = try #require(report.addedExamIDs.first)
        model.remove(sampleID)
        await model.restoreSamples().value
        #expect(model.store.entry(sampleID)?.isSample == true)
        #expect(model.selection == sampleID)
        #expect(model.notice?.message == "Đã khôi phục 1 đề mẫu.")

        await model.restoreSamples().value
        #expect(model.notice?.message == "Đề mẫu đã có đủ trong thư viện.")
        #expect(model.prompts.isEmpty)
        await model.waitForPendingOperations()
    }

    @Test("Bản app không kèm đề mẫu: Khôi phục đề mẫu báo rõ")
    func restoreWithoutSamples() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()

        await model.restoreSamples().value

        #expect(model.prompts.first?.alertTitle == "Không có đề mẫu")
    }

    // MARK: - Làm bài

    @Test("Luyện tập / Thi / nhấp đúp / Return: chỉ đề Sẵn sàng mới mở Trước khi thi (phương án 5); lần thi mở Kết quả")
    func sessionActionsOnlyForReadyExams() async throws {
        let workspace = try FeatureWorkspace()
        let model = workspace.makeModel()
        let ready = makeExam(title: "Sẵn sàng")
        let gone = makeExam(title: "Mất file")
        let goneFile = try workspace.write(gone, to: "mat.exam")
        await model.importFiles([try workspace.write(ready, to: "san-sang.exam"), goneFile]).value
        try FileManager.default.removeItem(at: goneFile)
        await model.store.refreshAll()
        let readyEntry = try #require(model.store.entry(ready.id))
        let goneEntry = try #require(model.store.entry(gone.id))
        #expect(goneEntry.status == .missing)

        // Chưa nối phiên thi: mọi nút làm bài tắt.
        #expect(!model.canStartSession(readyEntry))
        #expect(!model.startSession(ready.id))

        var opened: [(UUID, SessionMode?)] = []
        var attempts: [UUID] = []
        model.sessionActions = LibrarySessionActions(
            openPreExam: { opened.append(($0, $1)) },
            openAttempt: { attempts.append($0.id) }
        )
        #expect(model.canStartSession(readyEntry))
        #expect(!model.canStartSession(goneEntry))

        model.infoExamID = ready.id
        #expect(model.startSession(ready.id, mode: .exam))
        #expect(model.startSession(ready.id))
        #expect(!model.startSession(gone.id, mode: .practice))
        #expect(opened.map(\.0) == [ready.id, ready.id])
        #expect(opened.map(\.1) == [.exam, nil])
        #expect(model.selection == ready.id)
        #expect(model.infoExamID == nil)

        let attempt = makeAttempt(examID: gone.id, title: "Mất file", submittedAt: Date())
        model.openAttempt(attempt)
        #expect(attempts == [attempt.id])
    }
}
