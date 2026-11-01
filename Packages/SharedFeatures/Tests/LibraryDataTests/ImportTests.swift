import ExamFile
import ExamKit
import Foundation
@testable import LibraryData
import Testing

@MainActor
@Suite("Thêm đề")
struct ImportTests {
    @Test("Thêm file hợp lệ: thông tin thẻ, trạng thái Sẵn sàng, lưu vào kho", arguments: RepositoryKind.allCases)
    func addsValidExam(kind: RepositoryKind) async throws {
        let workspace = try TestWorkspace()
        let repository = kind.make()
        let clock = TestClock()
        let store = workspace.makeStore(repository: repository, clock: clock)
        let file = try workspace.writeFixture("kien-thuc-chung", to: "Downloads/Kiến thức chung.exam")

        let report = await store.importFiles([file])

        let id = RepoFixtures.kienThucChungID
        #expect(report.items.map(\.outcome) == [.added(examID: id)])
        #expect(report.examIDToSelect == id)
        let entry = try #require(store.entry(id))
        let package = try RepoFixtures.package("kien-thuc-chung")
        #expect(entry.status == .ready)
        #expect(entry.summary == ExamSummary(
            title: "Kiến thức chung",
            code: "KTC01",
            questionCount: package.exam.questionCount,
            sectionCount: package.exam.sections.count,
            imageCount: 1,
            timeLimitMinutes: 30,
            passPercent: 70,
            hideAnswers: false,
            formatVersion: 1
        ))
        #expect(sameFile(entry.fileURL, file))
        #expect(entry.fileSize == Int64(try Data(contentsOf: file).count))
        #expect(entry.fileModificationDate != nil)
        #expect(!entry.isSample)
        #expect(entry.addedAt == clock.now)
        #expect(entry.lastOpenedAt == nil)

        let saved = try repository.fetchEntries()
        #expect(saved.count == 1)
        #expect(saved.first?.summary == entry.summary)
        #expect(saved.first?.verdict == .ready)
        #expect(saved.first?.checkFingerprint == "test-v1")
        // Bookmark lưu trong kho phân giải về đúng file.
        let savedRecord = try #require(saved.first)
        let located = try #require(ExamFileInspector.locate(savedRecord.location))
        #expect(sameFile(located.url, file))
    }

    @Test("Cùng file hai lần: chọn mục đã có, không thêm mục mới; thông tin thẻ cập nhật theo file")
    func sameFileTwice() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let file = try workspace.writeFixture("toi-thieu", to: "a.exam")
        let id = try RepoFixtures.package("toi-thieu").exam.id
        _ = await store.importFiles([file])

        // Đổi nội dung file nhưng vẫn là đề đó; nhập lại qua một symlink.
        try workspace.writeFixture("toi-thieu", to: "a.exam") { $0.title = "Đề tối thiểu (sửa)" }
        let link = workspace.url("link.exam")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)

        let again = await store.importFiles([file])
        let viaLink = await store.importFiles([link])

        #expect(again.items.map(\.outcome) == [.alreadyInLibrary(examID: id)])
        #expect(viaLink.items.map(\.outcome) == [.alreadyInLibrary(examID: id)])
        #expect(viaLink.examIDToSelect == id)
        #expect(store.entries.count == 1)
        #expect(store.entry(id)?.title == "Đề tối thiểu (sửa)")
    }

    @Test("Bản Học viên nhập lại đúng file đã có nhưng file giờ có lỗi: chọn mục đó, thẻ hiện Đề có lỗi; file khác có lỗi thì không thay")
    func studentReimportsFileThatGainedErrors() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: .strict)
        let exam = makeExam(title: "Đề sẽ có lỗi")
        let file = try workspace.write(exam, to: "de.exam")
        _ = await store.importFiles([file])
        try workspace.writeRawPackage(json: rawJSON(of: exam) { $0["la"] = true }, to: "de.exam")
        let other = try workspace.writeRawPackage(json: rawJSON(of: exam) { $0["khac"] = true }, to: "ban-khac.exam")

        let same = await store.importFiles([file])
        let different = await store.importFiles([other])

        #expect(same.items.map(\.outcome) == [.alreadyInLibrary(examID: exam.id)])
        #expect(store.entry(exam.id)?.status == .invalid(reason: unknownFieldsReason("la")))
        #expect(different.items.map(\.outcome) == [.rejected(.invalid(reason: unknownFieldsReason("khac")))])
        let entry = try #require(store.entry(exam.id))
        #expect(sameFile(entry.fileURL, file))
    }

    @Test("Cùng id đề, khác file: cần xác nhận; Dùng file mới thì mục chuyển sang file mới", arguments: RepositoryKind.allCases)
    func sameExamDifferentFile(kind: RepositoryKind) async throws {
        let workspace = try TestWorkspace()
        let repository = kind.make()
        let clock = TestClock()
        let store = workspace.makeStore(repository: repository, clock: clock)
        let first = try workspace.writeFixture("toi-thieu", to: "Cũ/de.exam")
        let second = try workspace.writeFixture("toi-thieu", to: "Mới/de.exam") { $0.title = "Đề tối thiểu bản mới" }
        let id = try RepoFixtures.package("toi-thieu").exam.id
        _ = await store.importFiles([first])
        let addedAt = try #require(store.entry(id)).addedAt
        store.markOpened(id)
        clock.advance(by: 3600)

        let report = await store.importFiles([second])

        let pending = try #require(report.pendingReplacements.first)
        #expect(report.items.map(\.outcome) == [.needsReplaceConfirmation(pending)])
        #expect(pending.examID == id)
        #expect(pending.title == "Đề tối thiểu bản mới")
        #expect(sameFile(pending.newFileURL, second))
        #expect(sameFile(pending.existingFileURL, first))
        #expect(report.examIDToSelect == nil)
        // Chưa xác nhận (Huỷ): không đổi gì.
        let unconfirmed = try #require(store.entry(id))
        #expect(sameFile(unconfirmed.fileURL, first))
        #expect(unconfirmed.title == "Đề tối thiểu")

        try store.confirmReplace(pending)

        let entry = try #require(store.entry(id))
        #expect(store.entries.count == 1)
        #expect(sameFile(entry.fileURL, second))
        #expect(entry.title == "Đề tối thiểu bản mới")
        #expect(entry.addedAt == addedAt)
        #expect(entry.lastOpenedAt != nil)
        #expect(entry.status == .ready)
        let saved = try #require(try repository.fetchEntries().first)
        #expect(sameFile(saved.fileURL, second))
        #expect(saved.addedAt == addedAt)
    }

    @Test("Hai lần nhập chồng nhau cùng một file mới: một lần thêm, lần kia là đã có (không hỏi \"từ file khác\")")
    func overlappingImportsOfSameNewFile() async throws {
        let workspace = try TestWorkspace()
        // Đọc chậm để hai lần nhập cùng đang đọc trước khi lần nào áp kết quả.
        let store = workspace.makeStore(recorder: ReadRecorder(delay: 0.2))
        let exam = makeExam(title: "Kéo thả hai lần")
        let file = try workspace.write(exam, to: "de.exam")

        async let first = store.importFiles([file])
        async let second = store.importFiles([file])
        let reports = await [first, second]

        let outcomes = reports.flatMap { $0.items.map(\.outcome) }
        #expect(outcomes.filter { $0 == .added(examID: exam.id) }.count == 1)
        #expect(outcomes.filter { $0 == .alreadyInLibrary(examID: exam.id) }.count == 1)
        #expect(reports.allSatisfy { $0.pendingReplacements.isEmpty })
        #expect(reports.allSatisfy { $0.examIDToSelect == exam.id })
        #expect(store.entries.count == 1)
    }

    @Test("Hai file cùng id trong một lần nhập: file đầu được thêm, file sau cần xác nhận; cùng file hai lần thì chọn mục đã có")
    func duplicatesInOneBatch() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let id = try RepoFixtures.package("toi-thieu").exam.id
        let a = try workspace.writeFixture("toi-thieu", to: "a.exam")
        let b = try workspace.writeFixture("toi-thieu", to: "b.exam")

        let report = await store.importFiles([a, b, a])

        #expect(report.items.count == 3)
        #expect(report.items[0].outcome == .added(examID: id))
        guard case let .needsReplaceConfirmation(pending) = report.items[1].outcome else {
            Issue.record("File thứ hai phải cần xác nhận, nhận được \(report.items[1].outcome)")
            return
        }
        #expect(sameFile(pending.newFileURL, b))
        #expect(report.items[2].outcome == .alreadyInLibrary(examID: id))
        #expect(store.entries.count == 1)
    }

    @Test("Bản Học viên không thêm file hỏng, có lỗi, có trường lạ hoặc cần app mới hơn")
    func studentRejectsUnusableFiles() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: .strict)
        let garbage = try workspace.writeGarbage(to: "hong.exam")
        let invalid = try workspace.writeInvalidFixture("correct-not-in-options", to: "co-loi.exam")
        let unknown = try workspace.writeInvalidFixture("unknown-question-field", to: "truong-la.exam")
        let future = try workspace.writeInvalidFixture("future-version", to: "moi-hon.exam")
        var missingMedia = try RepoFixtures.package("kien-thuc-chung")
        missingMedia.media = [:]
        let noImage = try workspace.write(missingMedia, to: "thieu-anh.exam")

        let invalidReason = FileProblemReason(try #require(readError(invalid, mode: .strict)))
        let unknownReason = FileProblemReason(try #require(readError(unknown, mode: .strict)))
        let noImageReason = FileProblemReason(try #require(readError(noImage, mode: .strict)))

        let report = await store.importFiles([garbage, invalid, unknown, future, noImage])

        #expect(store.entries.isEmpty)
        #expect(report.addedExamIDs.isEmpty)
        let expected: [ImportOutcome] = [
            .rejected(.corrupt(reason: notZipReason)),
            .rejected(.invalid(reason: invalidReason)),
            .rejected(.invalid(reason: unknownReason)),
            .rejected(.needsNewerApp(found: 2, supported: ExamFileFormat.currentVersion)),
            .rejected(.invalid(reason: noImageReason)),
        ]
        #expect(report.items.map(\.outcome) == expected)
        #expect(noImageReason.logMessage == "Gói đề thiếu ảnh: media/9d5dc894e10f060d.png.")
        #expect(report.rejected.count == 5)
        // Lý do là lỗi có mã của ExamFile; câu tiếng Việt (nhật ký) là errorDescription của nó.
        #expect(report.items[2].outcome == .rejected(.invalid(reason: unknownFieldsReason("sections[0].questions[0].hint"))))
        #expect(unknownReason.logMessage == "Đề có trường không được hỗ trợ: sections[0].questions[0].hint.")
        #expect(LibraryFileProblem.needsNewerApp(found: 2, supported: 1).logMessage
            == "Đề cần phiên bản app mới hơn (định dạng v2, app này hiểu tới v1).")
    }

    @Test("Bản Admin thêm file đọc dễ được kể cả có lỗi (Có lỗi, kèm lý do bản Học viên từ chối)")
    func adminAddsFilesWithIssues() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: .lenient)
        let invalid = try workspace.writeInvalidFixture("correct-not-in-options", to: "co-loi.exam")
        let unknownExam = makeExam(title: "Có trường lạ")
        let unknown = try workspace.writeRawPackage(
            json: rawJSON(of: unknownExam) { $0["ghiChu"] = "trường lạ" },
            to: "truong-la.exam"
        )
        let garbage = try workspace.writeGarbage(to: "hong.exam")
        let future = try workspace.writeInvalidFixture("future-version", to: "moi-hon.exam")
        let good = try workspace.writeFixture("kien-thuc-chung", to: "tot.exam")
        let invalidID = try ExamPackageReader.read(contentsOf: invalid, mode: .lenient).exam.id
        let strictInvalid = FileProblemReason(try #require(readError(invalid, mode: .strict)))

        let report = await store.importFiles([invalid, unknown, garbage, future, good])

        let expected: [ImportOutcome] = [
            .added(examID: invalidID),
            .added(examID: unknownExam.id),
            .rejected(.corrupt(reason: notZipReason)),
            .rejected(.needsNewerApp(found: 2, supported: 1)),
            .added(examID: RepoFixtures.kienThucChungID),
        ]
        #expect(report.items.map(\.outcome) == expected)
        #expect(store.entry(invalidID)?.status == .readableWithIssues(reason: strictInvalid))
        #expect(store.entry(unknownExam.id)?.status == .readableWithIssues(reason: unknownFieldsReason("ghiChu")))
        #expect(store.entry(unknownExam.id)?.title == "Có trường lạ")
        #expect(store.entry(RepoFixtures.kienThucChungID)?.status == .ready)
        #expect(LibraryQuery.filter(store.entries, by: .problems).count == 2)
    }

    @Test("Dấu phẩy thừa: bản Học viên coi là Đề có lỗi (bản Admin đọc được); file không đọc được vì quyền: File hỏng kèm lý do hệ thống")
    func trailingCommaAndUnreadableFile() async throws {
        let workspace = try TestWorkspace()
        let exam = makeExam(title: "Dấu phẩy thừa")
        var json = String(decoding: try ExamJSON.encode(exam), as: UTF8.self)
        let lastBrace = try #require(json.lastIndex(of: "}"))
        json.insert(contentsOf: ",\n", at: lastBrace)
        let comma = try workspace.writeRawPackage(json: Data(json.utf8), to: "phay.exam")
        let commaReason = FileProblemReason(try #require(readError(comma, mode: .strict)))
        #expect(commaReason.logMessage.contains("dấu phẩy thừa"))
        let locked = try workspace.write(makeExam(title: "Khoá quyền"), to: "khoa.exam")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.path) }

        let student = workspace.makeStore(mode: .strict)
        let admin = workspace.makeStore(mode: .lenient)
        let studentReport = await student.importFiles([comma, locked])
        let adminReport = await admin.importFiles([comma])

        #expect(studentReport.items[0].outcome == .rejected(.invalid(reason: commaReason)))
        guard case let .rejected(.corrupt(reason)) = studentReport.items[1].outcome else {
            Issue.record("File không đọc được phải bị từ chối là File hỏng, nhận được \(studentReport.items[1].outcome)")
            return
        }
        guard case .unreadable = reason else {
            Issue.record("Lý do phải là lỗi hệ thống khi đọc file, nhận \(reason)")
            return
        }
        #expect(reason.logMessage.hasPrefix("Không đọc được file: "))
        #expect(adminReport.items.map(\.outcome) == [.added(examID: exam.id)])
        #expect(admin.entry(exam.id)?.status == .readableWithIssues(reason: commaReason))
    }

    @Test("Nhập lại đúng file đã có nhưng giờ không đọc được: báo không thêm được và thẻ hiện đúng trạng thái mới", arguments: [ReadMode.strict, .lenient])
    func reimportedFileThatBecameUnreadable(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let repository = RepositoryKind.swiftData.make()
        let store = workspace.makeStore(mode: mode, repository: repository)
        let broken = makeExam(title: "Sẽ hỏng")
        let newer = makeExam(title: "Sẽ cần app mới hơn")
        let other = makeExam(title: "Không liên quan")
        let brokenFile = try workspace.write(broken, to: "hong.exam")
        let newerFile = try workspace.write(newer, to: "moi.exam")
        _ = await store.importFiles([brokenFile, newerFile, try workspace.write(other, to: "khac.exam")])
        try workspace.writeGarbage(to: "hong.exam")
        try workspace.writeRawPackage(json: rawJSON(of: newer) { $0["formatVersion"] = 3 }, to: "moi.exam")
        #expect(store.entry(broken.id)?.status == .ready)

        let report = await store.importFiles([brokenFile, newerFile])

        #expect(report.items.map(\.outcome) == [
            .rejected(.corrupt(reason: notZipReason)),
            .rejected(.needsNewerApp(found: 3, supported: 1)),
        ])
        #expect(store.entry(broken.id)?.status == .corrupt(reason: notZipReason))
        #expect(store.entry(newer.id)?.status == .needsNewerApp(found: 3, supported: 1))
        #expect(store.entry(other.id)?.status == .ready)
        #expect(store.entries.count == 3)
        // Kết luận mới đã lưu: mở lại app vẫn hiện đúng. Cần app mới hơn không phải đọc lại; File hỏng đọc lại một lần
        // (kho chỉ lưu chữ của lý do, giao diện cần lý do có mã: bước 7b), rồi dùng lại trong lần chạy đó.
        let reopenedRecorder = ReadRecorder()
        let reopened = workspace.makeStore(mode: mode, repository: repository, recorder: reopenedRecorder)
        reopened.load()
        await reopened.refreshAll()
        #expect(reopened.entry(broken.id)?.status == .corrupt(reason: notZipReason))
        #expect(reopened.entry(newer.id)?.status == .needsNewerApp(found: 3, supported: 1))
        #expect(reopenedRecorder.reads(of: "hong.exam") == 1)
        #expect(reopenedRecorder.reads(of: "moi.exam") == 0)
        await reopened.refreshAll()
        #expect(reopenedRecorder.reads(of: "hong.exam") == 1)
    }

    @Test("File trong Thùng rác: không thêm, báo lý do tiếng Việt", arguments: [ReadMode.strict, .lenient])
    func rejectsFilesInTrash(mode: ReadMode) async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(mode: mode)
        let trashed = try workspace.write(makeExam(title: "Đã xoá"), to: ".Trash/da-xoa.exam")
        let volumeTrash = try workspace.write(makeExam(title: "Ổ ngoài"), to: "Volume/.Trashes/501/o-ngoai.exam")

        let report = await store.importFiles([trashed, volumeTrash])

        #expect(report.items.map(\.outcome) == [
            .rejected(.corrupt(reason: .inTrash(fileName: "da-xoa.exam"))),
            .rejected(.corrupt(reason: .inTrash(fileName: "o-ngoai.exam"))),
        ])
        #expect(FileProblemReason.inTrash(fileName: "da-xoa.exam").logMessage
            == "File \"da-xoa.exam\" đang nằm trong Thùng rác. Hãy chuyển file ra khỏi Thùng rác rồi thêm lại.")
        #expect(store.entries.isEmpty)
    }

    @Test("File không phải .exam (kể cả thư mục tên .exam) bị bỏ qua và được báo")
    func skipsNonExamFiles() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore()
        let text = workspace.url("ghi-chu.txt")
        try Data("xin chào".utf8).write(to: text)
        let zip = try workspace.writeFixture("toi-thieu", to: "de.zip")
        let folder = try workspace.makeDirectory("thu-muc.exam")
        let upper = try workspace.writeFixture("toi-thieu", to: "DE-HOA.EXAM")

        let report = await store.importFiles([text, zip, folder, upper])

        #expect(report.skippedURLs == [text, zip, folder])
        #expect(report.items[3].outcome == .added(examID: try RepoFixtures.package("toi-thieu").exam.id))
    }

    @Test("Báo cáo giữ đúng thứ tự file đưa vào khi đọc song song")
    func reportKeepsInputOrder() async throws {
        let workspace = try TestWorkspace()
        let store = workspace.makeStore(maxConcurrentReads: 3)
        let root = workspace.root
        // Ghi file ngoài main actor (đề 400 câu) để không làm chậm các test khác đang chạy trên main actor.
        let (urls, expected): ([URL], [ImportOutcome]) = try await Task.detached {
            var urls: [URL] = []
            var expected: [ImportOutcome] = []
            for index in 0 ..< 12 {
                if index % 4 == 3 {
                    let url = root.appendingPathComponent("hong-\(index).exam")
                    try Data("không phải zip".utf8).write(to: url)
                    urls.append(url)
                    expected.append(.rejected(.corrupt(reason: notZipReason)))
                } else {
                    // Đề lớn nhỏ xen kẽ để thứ tự đọc xong khác thứ tự đưa vào.
                    let exam = makeExam(title: "Đề \(index)", questions: index % 2 == 0 ? 400 : 1)
                    let url = root.appendingPathComponent("de-\(index).exam")
                    try ExamPackageWriter.write(ExamPackage(exam: exam), to: url)
                    urls.append(url)
                    expected.append(.added(examID: exam.id))
                }
            }
            return (urls, expected)
        }.value

        let report = await store.importFiles(urls)

        #expect(report.items.map(\.url) == urls)
        #expect(report.items.map(\.outcome) == expected)
        #expect(store.entries.count == 9)
    }
}
