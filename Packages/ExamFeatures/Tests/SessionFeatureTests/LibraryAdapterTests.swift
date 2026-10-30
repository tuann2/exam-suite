import ExamFile
import ExamKit
import Foundation
import LibraryData
@testable import SessionFeature
@testable import SessionModel
import Testing

/// `LibraryStoreSessionLibrary` trên kho thật trong bộ nhớ và file đề thật (fixture
/// `fixtures/exams/kien-thuc-chung`, ghi bằng `ExamPackageWriter`) trong thư mục tạm.
@MainActor
@Suite("Thư viện thật: đọc nghiêm file đề, lưu và mở lại lần thi")
struct LibraryAdapterTests {
    struct Setup {
        let workspace: SessionWorkspace
        let store: LibraryStore
        let library: LibraryStoreSessionLibrary
        let file: URL
        let package: ExamPackage
        let clock = FakeClock()

        @MainActor
        var environment: SessionEnvironment {
            SessionEnvironment(
                library: library,
                preferences: UserDefaultsSessionPreferences(defaults: workspace.defaults),
                makeSeed: { 99 },
                makeClock: { [clock] in clock }
            )
        }
    }

    func setUp() async throws -> Setup {
        let workspace = try SessionWorkspace()
        let package = try RepoFixtures.package("kien-thuc-chung")
        let file = try workspace.write(package, to: "Đề/Kiến thức chung.exam")
        let store = LibraryStore.inMemory(configuration: workspace.configuration(), defaults: workspace.defaults)
        store.load()
        let report = await store.importFiles([file])
        #expect(report.addedExamIDs == [package.exam.id])
        return Setup(
            workspace: workspace,
            store: store,
            library: LibraryStoreSessionLibrary(store: store),
            file: file,
            package: package
        )
    }

    @Test("Đọc nghiêm file đề của mục thư viện (kèm ảnh); đề không có trong thư viện thì báo")
    func readsExamFile() async throws {
        let setup = try await setUp()
        let read = try await setup.library.readExam(setup.package.exam.id).get()
        #expect(read == setup.package)
        #expect(!read.media.isEmpty)
        #expect(await setup.library.readExam(UUID()) == .failure(.notInLibrary))
    }

    @Test("File bị xoá: không bắt đầu được, “Không tìm thấy file đề.”, thẻ thành Không tìm thấy file")
    func missingFile() async throws {
        let setup = try await setUp()
        let examID = setup.package.exam.id
        let preExam = PreExamModel(package: setup.package, environment: setup.environment)
        preExam.candidateName = "An"
        try FileManager.default.removeItem(at: setup.file)

        #expect(await preExam.start() == nil)
        #expect(preExam.startFailure == "Không tìm thấy file đề.")
        await setup.store.refreshAll()
        #expect(setup.store.entry(examID)?.status == .missing)
    }

    @Test("File hỏng sau khi thêm: không bắt đầu được, lý do của bộ đọc, thẻ thành File hỏng")
    func corruptFile() async throws {
        let setup = try await setUp()
        let examID = setup.package.exam.id
        let preExam = PreExamModel(package: setup.package, environment: setup.environment)
        preExam.candidateName = "An"
        try Data("không phải zip".utf8).write(to: setup.file)

        #expect(await preExam.start() == nil)
        let reason = try #require(preExam.startFailure)
        #expect(reason == ExamFileError.notAZipArchive.errorDescription)
        await setup.store.refreshAll()
        guard case .corrupt = setup.store.entry(examID)?.status else {
            Issue.record("Thẻ phải là File hỏng, có \(String(describing: setup.store.entry(examID)?.status))")
            return
        }
    }

    @Test("Lỗi đọc file của hệ thống: câu tiếng Việt của app, không dùng localizedDescription")
    func systemReadErrorsInVietnamese() async throws {
        let setup = try await setUp()
        let examID = setup.package.exam.id
        func read(throwing error: any Error) async -> Result<ExamPackage, ExamLoadFailure> {
            let library = LibraryStoreSessionLibrary(store: setup.store, reader: { _ in throw error })
            return await library.readExam(examID)
        }
        #expect(await read(throwing: CocoaError(.fileReadNoPermission))
            == .failure(.unreadable(reason: "Không có quyền đọc file đề.")))
        #expect(await read(throwing: CocoaError(.fileReadNoSuchFile)) == .failure(.fileMissing))
        #expect(await read(throwing: NSError(domain: NSPOSIXErrorDomain, code: Int(EIO)))
            == .failure(.unreadable(reason: "Không đọc được file đề.")))
    }

    @Test("File giờ là đề khác: không bắt đầu được")
    func differentExamAtPath() async throws {
        let setup = try await setUp()
        let other = makeExam(counts: [1])
        try ExamPackageWriter.write(ExamPackage(exam: other), to: setup.file)
        #expect(await setup.library.readExam(setup.package.exam.id) == .failure(.differentExam))
    }

    @Test("Luồng đầy đủ: mở, Bắt đầu, làm, nộp → lần thi trong kho; mở lại từ Lịch sử thi và Xem lại bằng file đề")
    func fullFlowWithRealStore() async throws {
        let setup = try await setUp()
        let examID = setup.package.exam.id
        let coordinator = SessionCoordinator(environment: setup.environment)
        #expect(await coordinator.openPreExam(examID: examID) == .opened)
        coordinator.preExam?.candidateName = "Nguyễn Văn An"
        coordinator.preExam?.mode = .exam
        #expect(await coordinator.startPreExam())
        let window = try #require(coordinator.window)
        let attempt = try #require(window.attempt)
        attempt.answerCorrectly()
        attempt.nextQuestion()
        attempt.answerWrongly()
        setup.clock.advance(200)
        attempt.openReview()
        window.requestSubmit()
        window.confirmSubmit()
        #expect(window.screen == .results)
        #expect(window.results?.saveError == nil)

        let saved = try #require(setup.store.attempts(examID: examID).first)
        #expect(saved.candidateName == "Nguyễn Văn An")
        #expect(saved.correct == 1)
        #expect(saved.total == 5)
        #expect(saved.elapsedSeconds == 200)
        let payload = try #require(try setup.store.attemptPayload(id: saved.id))
        let record = try AttemptRecord.decode(payload)
        #expect(record.fingerprints == QuestionFingerprint.fingerprints(of: setup.package.exam))
        #expect(record.paper.options.seed == 99)
        #expect(setup.workspace.defaults.string(forKey: UserDefaultsSessionPreferences.candidateNameKey) == "Nguyễn Văn An")

        coordinator.returnToLibrary()
        #expect(coordinator.openHistoryAttempt(saved) == .opened)
        let history = try #require(coordinator.window?.results)
        #expect(history.record == record)
        #expect(history.sectionRows.map(\.title) == ["Vật lý", "Toán"])
        #expect(await coordinator.window?.openAnswerReview() == true)
        let review = try #require(coordinator.window?.answerReview)
        #expect(review.rows.allSatisfy { $0.change == .unchanged })
        #expect(review.detail(at: 0).imagePath.map { review.media[$0] != nil } ?? true)

        // Đề bị xoá khỏi thư viện: kết quả vẫn mở được, không Làm lại, Xem lại tắt.
        _ = try setup.store.remove(examID)
        let orphan = ResultsModel.history(saved, environment: setup.environment)
        #expect(orphan.record == record)
        #expect(orphan.retakePreset == nil)
        #expect(!orphan.canReview)
    }
}
