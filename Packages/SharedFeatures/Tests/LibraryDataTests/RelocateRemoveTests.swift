import ExamFile
import ExamKit
import Foundation
@testable import LibraryData
import Testing

@MainActor
@Suite("Tìm file, xoá khỏi thư viện, hoàn tác")
struct RelocateRemoveTests {
    @Test("Tìm file… với file cùng id đề: mục trỏ sang file mới, Sẵn sàng, lưu vào kho", arguments: RepositoryKind.allCases)
    func relocateToSameExam(kind: RepositoryKind) async throws {
        let workspace = try TestWorkspace()
        let repository = kind.make()
        let store = workspace.makeStore(repository: repository)
        let exam = makeExam(title: "Đề mất file")
        let original = try workspace.write(exam, to: "Ổ cũ/de.exam")
        _ = await store.importFiles([original])
        let addedAt = try #require(store.entry(exam.id)).addedAt
        try FileManager.default.removeItem(at: original)
        await store.refreshAll()
        #expect(store.entry(exam.id)?.status == .missing)

        var renamed = exam
        renamed.title = "Đề tìm lại"
        let found = try workspace.write(renamed, to: "Ổ mới/bản sao.exam")
        try await store.relocate(exam.id, to: found)

        let entry = try #require(store.entry(exam.id))
        #expect(entry.status == .ready)
        #expect(sameFile(entry.fileURL, found))
        #expect(entry.title == "Đề tìm lại")
        #expect(entry.addedAt == addedAt)
        let saved = try #require(try repository.fetchEntries().first)
        #expect(sameFile(saved.fileURL, found))

        await store.refreshAll()
        #expect(store.entry(exam.id)?.status == .ready)
    }

    @Test("Tìm file… cho đề mẫu mất file: mục trỏ sang file người dùng chọn và không còn là đề mẫu")
    func relocateClearsSampleFlag() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(samples: try SampleTests.makeSource(workspace, fixtures: ["toi-thieu"]))
        await store.seedSamplesIfNeeded()
        let id = try RepoFixtures.package("toi-thieu").exam.id
        #expect(store.entry(id)?.isSample == true)
        try FileManager.default.removeItem(at: store.configuration.samplesDirectoryURL)
        await store.refreshAll()
        let copy = try workspace.writeFixture("toi-thieu", to: "Tài liệu/ban-sao.exam")

        try await store.relocate(id, to: copy)

        let entry = try #require(store.entry(id))
        #expect(!entry.isSample)
        #expect(entry.status == .ready)
        #expect(sameFile(entry.fileURL, copy))
        #expect(store.records[id]?.isSample == false)
    }

    @Test("Tìm file… với file trong Thùng rác: báo lỗi, không đổi gì")
    func relocateRejectsTrashedFile() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let exam = makeExam(title: "Đề gốc")
        _ = await store.importFiles([try workspace.write(exam, to: "de.exam")])
        let before = try #require(store.entry(exam.id))
        let trashed = try workspace.write(exam, to: ".Trash/de.exam")

        await #expect(throws: LibraryError.unusableFile(.corrupt(reason: .inTrash(fileName: "de.exam")))) {
            try await store.relocate(exam.id, to: trashed)
        }
        #expect(store.entry(exam.id) == before)
    }

    @Test("Tìm file… với đề khác id: báo lỗi rõ ràng, không đổi gì")
    func relocateToDifferentExam() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let exam = makeExam(title: "Đề gốc")
        let original = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([original])
        let before = try #require(store.entry(exam.id))
        let recordBefore = try #require(store.records[exam.id])
        let other = try workspace.write(makeExam(title: "Đề khác"), to: "khac.exam")

        await #expect(throws: LibraryError.differentExam(expectedTitle: "Đề gốc", foundTitle: "Đề khác")) {
            try await store.relocate(exam.id, to: other)
        }
        #expect(store.entry(exam.id) == before)
        #expect(store.records[exam.id] == recordBefore)
        #expect(LibraryError.differentExam(expectedTitle: "Đề gốc", foundTitle: "Đề khác").logMessage
            == "File chọn là đề \"Đề khác\", không phải đề \"Đề gốc\". Hãy chọn đúng file của đề này.")
    }

    @Test("Tìm file… với file không dùng được: báo lỗi, không đổi gì")
    func relocateToUnusableFile() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: .strict)
        let exam = makeExam(title: "Đề gốc")
        let original = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([original])
        let before = try #require(store.entry(exam.id))

        let garbage = try workspace.writeGarbage(to: "hong.exam")
        await #expect(throws: LibraryError.unusableFile(.corrupt(reason: notZipReason))) {
            try await store.relocate(exam.id, to: garbage)
        }
        let invalid = try workspace.writeRawPackage(json: rawJSON(of: exam) { $0["la"] = 1 }, to: "co-loi.exam")
        await #expect(throws: LibraryError.unusableFile(.invalid(reason: unknownFieldsReason("la")))) {
            try await store.relocate(exam.id, to: invalid)
        }
        let text = workspace.url("ghi-chu.txt")
        try Data("x".utf8).write(to: text)
        await #expect(throws: LibraryError.notAnExamFile(text)) {
            try await store.relocate(exam.id, to: text)
        }
        let unknownID = UUID()
        await #expect(throws: LibraryError.entryNotFound(examID: unknownID)) {
            try await store.relocate(unknownID, to: original)
        }
        #expect(store.entry(exam.id) == before)
    }

    @Test("Bản Admin tìm lại được file có lỗi (Có lỗi)")
    func adminRelocatesToFileWithIssues() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: .lenient)
        let exam = makeExam(title: "Đề gốc")
        let original = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([original])
        let withIssues = try workspace.writeRawPackage(json: rawJSON(of: exam) { $0["la"] = 1 }, to: "co-loi.exam")

        try await store.relocate(exam.id, to: withIssues)

        #expect(store.entry(exam.id)?.status == .readableWithIssues(reason: unknownFieldsReason("la")))
        let relocated = try #require(store.entry(exam.id))
        #expect(sameFile(relocated.fileURL, withIssues))
    }

    @Test("Xoá khỏi thư viện không xoá file; Hoàn tác khôi phục y nguyên", arguments: RepositoryKind.allCases)
    func removeAndUndo(kind: RepositoryKind) async throws {
        let workspace = try TestWorkspace()
        let repository = kind.make()
        let clock = TestClock()
        let store = workspace.makeStore(repository: repository, clock: clock)
        let keep = makeExam(title: "Giữ lại")
        let target = makeExam(title: "Sẽ xoá")
        let keepFile = try workspace.write(keep, to: "giu.exam")
        clock.advance(by: 10)
        let file = try workspace.write(target, to: "xoa.exam")
        _ = await store.importFiles([keepFile])
        clock.advance(by: 60)
        _ = await store.importFiles([file])
        clock.advance(by: 60)
        store.markOpened(target.id)
        let before = try #require(store.entry(target.id))
        let recordBefore = try #require(store.records[target.id])

        let removed = try store.remove(target.id)

        #expect(removed.entry == before)
        #expect(store.entry(target.id) == nil)
        #expect(store.entries.map(\.examID) == [keep.id])
        #expect(workspace.exists(file))
        #expect(try repository.fetchEntries().map(\.examID) == [keep.id])

        clock.advance(by: 3600)
        try store.undoRemove(removed)

        #expect(store.entry(target.id) == before)
        #expect(store.records[target.id] == recordBefore)
        #expect(store.entries.map(\.examID) == [keep.id, target.id])
        let saved = try #require(try repository.fetchEntries().first { $0.examID == target.id })
        #expect(saved == recordBefore)
        #expect(saved.location.bookmark == recordBefore.location.bookmark)
        #expect(saved.addedAt == before.addedAt)
        #expect(saved.lastOpenedAt == before.lastOpenedAt)
    }

    @Test("Hoàn tác sau khi đề đã được thêm lại: báo lỗi, không tạo mục trùng")
    func undoAfterReAdd() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let exam = makeExam()
        let file = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([file])
        let removed = try store.remove(exam.id)
        _ = await store.importFiles([file])

        #expect(throws: LibraryError.alreadyInLibrary(examID: exam.id)) {
            try store.undoRemove(removed)
        }
        #expect(store.entries.count == 1)
        #expect(throws: LibraryError.entryNotFound(examID: UUID(uuidString: "00000000-0000-4000-8000-000000000000")!)) {
            try store.remove(UUID(uuidString: "00000000-0000-4000-8000-000000000000")!)
        }
    }

    @Test("Đánh dấu đã mở: cập nhật lần mở gần nhất và lưu vào kho")
    func markOpened() async throws {
        let workspace = try TestWorkspace()
        let repository = RepositoryKind.swiftData.make()
        let clock = TestClock()
        let store = workspace.makeStore(repository: repository, clock: clock)
        let exam = makeExam()
        _ = await store.importFiles([try workspace.write(exam, to: "de.exam")])
        clock.advance(by: 120)

        store.markOpened(exam.id)

        #expect(store.entry(exam.id)?.lastOpenedAt == clock.now)
        #expect(try repository.fetchEntries().first?.lastOpenedAt == clock.now)
        store.markOpened(UUID())
        #expect(store.lastStorageError == nil)
    }
}
