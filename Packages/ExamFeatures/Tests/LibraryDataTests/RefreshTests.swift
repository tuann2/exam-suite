import ExamFile
import ExamKit
import Foundation
@testable import LibraryData
import Testing

@MainActor
@Suite("Làm mới trạng thái file")
struct RefreshTests {
    @Test("Mở app: thông tin thẻ đã lưu hiện ngay với Đang kiểm tra, rồi Sẵn sàng sau khi kiểm")
    func loadShowsSavedInfoWhileChecking() async throws {
        let workspace = try TestWorkspace()
        let repository = RepositoryKind.swiftData.make()
        let first = workspace.makeStore(repository: repository)
        let file = try workspace.writeFixture("kien-thuc-chung", to: "de.exam")
        _ = await first.importFiles([file])

        let reopened = workspace.makeStore(repository: repository)
        reopened.load()

        let entry = try #require(reopened.entry(RepoFixtures.kienThucChungID))
        #expect(entry.status == .checking)
        #expect(entry.title == "Kiến thức chung")
        #expect(entry.summary.questionCount == first.entry(RepoFixtures.kienThucChungID)?.summary.questionCount)

        await reopened.refreshAll()

        #expect(reopened.entry(RepoFixtures.kienThucChungID)?.status == .ready)
        #expect(!reopened.isRefreshing)
    }

    @Test("File bị xoá → Không tìm thấy file; file trở lại đúng chỗ → Sẵn sàng")
    func deletedFileIsMissing() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let file = try workspace.writeFixture("toi-thieu", to: "de.exam")
        let id = try RepoFixtures.package("toi-thieu").exam.id
        _ = await store.importFiles([file])

        try FileManager.default.removeItem(at: file)
        await store.refreshAll()
        #expect(store.entry(id)?.status == .missing)
        #expect(store.entries.count == 1)

        try workspace.writeFixture("toi-thieu", to: "de.exam")
        await store.refreshAll()
        #expect(store.entry(id)?.status == .ready)
    }

    @Test("File đổi tên hoặc di chuyển trên cùng ổ: bookmark vẫn tìm được, đường dẫn và bookmark được cập nhật", arguments: RepositoryKind.allCases)
    func renamedOrMovedFileIsFound(kind: RepositoryKind) async throws {
        let workspace = try TestWorkspace()
        let repository = kind.make()
        let recorder = ReadRecorder()
        let store = workspace.makeStore(repository: repository, recorder: recorder)
        let original = try workspace.writeFixture("kien-thuc-chung", to: "Tải về/de.exam")
        let id = RepoFixtures.kienThucChungID
        _ = await store.importFiles([original])
        let bookmarkBefore = try #require(store.records[id]).location.bookmark
        let readsAfterImport = recorder.totalReads

        let renamed = workspace.url("Tải về/Kiến thức chung (bản cuối).exam")
        try FileManager.default.moveItem(at: original, to: renamed)
        await store.refreshAll()

        var entry = try #require(store.entry(id))
        #expect(entry.status == .ready)
        #expect(entry.fileURL.path == renamed.path)
        let bookmarkAfterRename = try #require(store.records[id]).location.bookmark
        #expect(bookmarkAfterRename != bookmarkBefore)

        try workspace.makeDirectory("Lưu trữ/2026")
        let moved = workspace.url("Lưu trữ/2026/de.exam")
        try FileManager.default.moveItem(at: renamed, to: moved)
        await store.refreshAll()

        entry = try #require(store.entry(id))
        #expect(entry.status == .ready)
        #expect(entry.fileURL.path == moved.path)
        // Đổi tên/di chuyển không đổi nội dung: không phải đọc lại.
        #expect(recorder.totalReads == readsAfterImport)
        // Đường dẫn và bookmark mới đã được lưu vào kho.
        let saved = try #require(try repository.fetchEntries().first)
        #expect(saved.location.path == moved.path)
        let located = try #require(ExamFileInspector.locate(saved.location))
        #expect(sameFile(located.url, moved))
    }

    @Test("Ghi đè nguyên tử ở cùng chỗ (cách app lưu đề) vẫn tìm được file")
    func atomicSaveAtSamePath() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let file = try workspace.writeFixture("toi-thieu", to: "de.exam")
        let id = try RepoFixtures.package("toi-thieu").exam.id
        _ = await store.importFiles([file])

        try workspace.writeFixture("toi-thieu", to: "de.exam") { $0.title = "Đã lưu lại" }
        await store.refreshAll()

        #expect(store.entry(id)?.status == .ready)
        #expect(store.entry(id)?.title == "Đã lưu lại")
    }

    @Test("File bị sửa (dung lượng/ngày sửa đổi khác) → đọc lại và cập nhật thông tin thẻ; file không đổi → không đọc lại")
    func modifiedFileIsReread() async throws {
        let workspace = try TestWorkspace()
        let recorder = ReadRecorder()
        let repository = RepositoryKind.swiftData.make()
        let store = workspace.makeStore(repository: repository, recorder: recorder)
        let exam = makeExam(title: "Đề gốc", code: "G1", questions: 3)
        let file = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([file])
        let readsAfterImport = recorder.totalReads

        await store.refreshAll()
        #expect(recorder.totalReads == readsAfterImport)
        #expect(store.entry(exam.id)?.status == .ready)

        var edited = makeExam(id: exam.id, title: "Đề đã sửa", code: "G2", questions: 12, passPercent: 80, timeLimitMinutes: 45)
        edited.hideAnswers = true
        try workspace.write(edited, to: "de.exam")
        await store.refreshAll()

        let entry = try #require(store.entry(exam.id))
        #expect(recorder.totalReads == readsAfterImport + 1)
        #expect(entry.summary.title == "Đề đã sửa")
        #expect(entry.summary.code == "G2")
        #expect(entry.summary.questionCount == 12)
        #expect(entry.summary.passPercent == 80)
        #expect(entry.summary.timeLimitMinutes == 45)
        #expect(entry.summary.hideAnswers)
        #expect(entry.fileSize == Int64(try Data(contentsOf: file).count))
        #expect(try repository.fetchEntries().first?.summary.title == "Đề đã sửa")

        // Chỉ đổi ngày sửa đổi cũng đọc lại.
        try workspace.touch(file)
        await store.refreshAll()
        #expect(recorder.totalReads == readsAfterImport + 2)
    }

    @Test("Mở lại app: file không đổi thì dùng kết luận đã lưu; app đổi phiên bản (dấu bộ kiểm khác) thì đọc lại")
    func savedVerdictIsReusedUntilFingerprintChanges() async throws {
        let workspace = try TestWorkspace()
        let repository = RepositoryKind.swiftData.make()
        let file = try workspace.writeInvalidFixture("future-version", to: "moi-hon.exam")
        let good = try workspace.writeFixture("kien-thuc-chung", to: "tot.exam")
        let admin = workspace.makeStore(mode: .lenient, repository: repository)
        // Bản Admin không thêm được file cần app mới hơn; thêm file tốt rồi biến nó thành "cần app mới hơn".
        _ = await admin.importFiles([good, file])
        try FileManager.default.removeItem(at: good)
        try FileManager.default.copyItem(at: file, to: good)
        await admin.refreshAll()
        #expect(admin.entry(RepoFixtures.kienThucChungID)?.status == .needsNewerApp(found: 2, supported: 1))

        let sameVersionRecorder = ReadRecorder()
        let sameVersion = workspace.makeStore(mode: .lenient, repository: repository, recorder: sameVersionRecorder)
        sameVersion.load()
        await sameVersion.refreshAll()
        #expect(sameVersionRecorder.totalReads == 0)
        #expect(sameVersion.entry(RepoFixtures.kienThucChungID)?.status == .needsNewerApp(found: 2, supported: 1))

        let updatedRecorder = ReadRecorder()
        let updatedApp = workspace.makeStore(mode: .lenient, repository: repository, recorder: updatedRecorder, fingerprint: "test-v2")
        updatedApp.load()
        await updatedApp.refreshAll()
        #expect(updatedRecorder.reads(of: "tot.exam") >= 1)
    }

    /// Bước 7b: kho chỉ lưu chữ tiếng Việt của lý do, giao diện cần lý do có mã. Mở lại app: file có vấn đề (lý do đọc
    /// từ kho) được đọc lại một lần dù không đổi; file Sẵn sàng và Cần app mới hơn vẫn dùng kết luận đã lưu.
    @Test("Mở lại app: lý do lưu dạng chữ không được dùng lại, file có vấn đề đọc lại một lần và có lý do có mã")
    func storedReasonIsReadAgain() async throws {
        let workspace = try TestWorkspace()
        let repository = RepositoryKind.swiftData.make()
        let exam = makeExam(title: "Có trường lạ")
        let withIssues = try workspace.writeRawPackage(json: rawJSON(of: exam) { $0["ghiChu"] = 1 }, to: "co-loi.exam")
        let good = try workspace.writeFixture("kien-thuc-chung", to: "tot.exam")
        let admin = workspace.makeStore(mode: .lenient, repository: repository)
        _ = await admin.importFiles([withIssues, good])
        #expect(admin.entry(exam.id)?.status == .readableWithIssues(reason: unknownFieldsReason("ghiChu")))

        let recorder = ReadRecorder()
        let reopened = workspace.makeStore(mode: .lenient, repository: repository, recorder: recorder)
        reopened.load()
        #expect(reopened.records[exam.id]?.verdict == .failsStrict(reason: .stored("Đề có trường không được hỗ trợ: ghiChu.")))
        await reopened.refreshAll()
        #expect(recorder.reads(of: "co-loi.exam") >= 1)
        #expect(recorder.reads(of: "tot.exam") == 0)
        #expect(reopened.entry(exam.id)?.status == .readableWithIssues(reason: unknownFieldsReason("ghiChu")))

        // Trong cùng lần chạy, lý do có mã dùng lại được: lần làm mới sau không đọc lại.
        let readsAfterFirstRefresh = recorder.totalReads
        await reopened.refreshAll()
        #expect(recorder.totalReads == readsAfterFirstRefresh)
    }

    @Test("File thành có lỗi: bản Học viên Đề có lỗi, bản Admin Có lỗi (cùng lý do)", arguments: [ReadMode.strict, .lenient])
    func fileBecomesInvalid(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: mode)
        let exam = makeExam(title: "Sẽ hỏng")
        let file = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([file])

        try workspace.writeRawPackage(json: rawJSON(of: exam) { $0["passPercent"] = 70; $0["mauSac"] = "đỏ" }, to: "de.exam")
        await store.refreshAll()

        let reason = unknownFieldsReason("mauSac")
        let expected: LibraryEntryStatus = mode == .strict ? .invalid(reason: reason) : .readableWithIssues(reason: reason)
        #expect(store.entry(exam.id)?.status == expected)
        // Đọc dễ được nên thông tin thẻ vẫn cập nhật.
        #expect(store.entry(exam.id)?.summary.passPercent == 70)
    }

    @Test("File thành hỏng hoặc cần app mới hơn", arguments: [ReadMode.strict, .lenient])
    func fileBecomesCorruptOrNewer(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: mode)
        let broken = makeExam(title: "Sẽ hỏng")
        let newer = makeExam(title: "Sẽ mới hơn")
        let brokenFile = try workspace.write(broken, to: "hong.exam")
        let newerFile = try workspace.write(newer, to: "moi.exam")
        _ = await store.importFiles([brokenFile, newerFile])

        try workspace.writeGarbage(to: "hong.exam")
        try workspace.writeRawPackage(json: rawJSON(of: newer) { $0["formatVersion"] = 7 }, to: "moi.exam")
        await store.refreshAll()

        #expect(store.entry(broken.id)?.status == .corrupt(reason: notZipReason))
        #expect(store.entry(newer.id)?.status == .needsNewerApp(found: 7, supported: 1))
        #expect(store.entry(broken.id)?.title == "Sẽ hỏng")
        #expect(store.entry(newer.id)?.status.reason?.logMessage == "Đề cần phiên bản app mới hơn (định dạng v7, app này hiểu tới v1).")
    }

    @Test("Chỗ của file giờ là một đề khác → Không tìm thấy file của đề này")
    func fileReplacedByAnotherExam() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let exam = makeExam(title: "Đề A")
        let file = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([file])

        try workspace.write(makeExam(title: "Đề B"), to: "de.exam")
        await store.refreshAll()

        #expect(store.entry(exam.id)?.status == .missing)
        #expect(store.entry(exam.id)?.title == "Đề A")
    }

    @Test("File bị chuyển vào Thùng rác → Không tìm thấy file")
    func trashedFileIsMissing() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let exam = makeExam()
        let file = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([file])

        try workspace.makeDirectory(".Trash")
        try FileManager.default.moveItem(at: file, to: workspace.url(".Trash/de.exam"))
        await store.refreshAll()

        #expect(store.entry(exam.id)?.status == .missing)
    }

    @Test("Gọi làm mới chồng nhau: cả hai chờ xong, không đọc trùng không cần thiết")
    func overlappingRefreshes() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        var exams: [Exam] = []
        for index in 0 ..< 6 {
            let exam = makeExam(title: "Đề \(index)", questions: 50)
            exams.append(exam)
            try workspace.write(exam, to: "de-\(index).exam")
        }
        _ = await store.importFiles((0 ..< 6).map { workspace.url("de-\($0).exam") })
        for index in 0 ..< 6 { try workspace.touch(workspace.url("de-\(index).exam")) }

        async let first: Void = store.refreshAll()
        async let second: Void = store.refreshAll()
        _ = await (first, second)

        #expect(!store.isRefreshing)
        #expect(store.entries.allSatisfy { $0.status == .ready })
    }
}
