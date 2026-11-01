import ExamFile
import ExamKit
import Foundation
import InterfaceCore
import LibraryData
@testable import MobileFeature
import SessionModel
import Testing

/// Phần chỉ của bản iOS (docs/product/mobile.md, mục Bản iOS): điều phối phiên thi trên iPhone, file nhận từ app khác,
/// tự tạm dừng khi xuống nền. Luật dùng chung (chấm điểm, Trước khi thi, Kết quả, Thư viện) đã có test ở bản macOS;
/// ở đây chỉ kiểm chỗ iOS khác hay nối khác.
@Suite("Bản iOS: phiên thi, file nhận, xuống nền")
@MainActor
struct MobileSessionTests {
    // MARK: - Xuống nền

    @Test("Xuống nền khi đang làm: tạm dừng lý do background, “Đã tạm dừng vì bạn rời app”, lên lại vẫn tạm dừng")
    func backgroundPausesAttempt() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        let attempt = try await workspace.startAttempt(app)
        app.didEnterBackground()
        #expect(attempt.phase == .paused)
        #expect(attempt.session.pauseReason == .background)
        #expect(attempt.pauseMessage == "Đã tạm dừng vì bạn rời app")
        app.didBecomeActive()
        #expect(attempt.phase == .paused)
        attempt.resume()
        #expect(attempt.phase == .inProgress)
    }

    @Test("Xuống nền khi không có bài đang làm (đã nộp, đang tạm dừng): không đổi gì")
    func backgroundIgnoredWhenNotRunning() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        let attempt = try await workspace.startAttempt(app)
        attempt.pause()
        app.didEnterBackground()
        #expect(attempt.session.pauseReason == .user)
        attempt.resume()
        let session = try #require(app.sessions.session)
        attempt.openReview()
        session.requestSubmit()
        session.confirmSubmit()
        #expect(session.screen == .results)
        app.didEnterBackground()
        #expect(attempt.isSubmitted)
    }

    // MARK: - Quay lại, Bỏ bài

    @Test("Quay lại khi bài chưa nộp: không tự rời (phải hỏi); Bỏ bài thì bỏ phiên, không lưu lần thi")
    func discardUnsubmitted() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        _ = try await workspace.startAttempt(app)
        let sessions = app.sessions
        #expect(sessions.hasUnsubmittedSession)
        #expect(sessions.discardMessage == "Bài chưa nộp sẽ mất. Bỏ bài?")
        sessions.returnToLibrary()
        #expect(sessions.isSessionPresented)
        sessions.discardSession()
        #expect(!sessions.isSessionPresented)
        #expect(app.library.store.attempts.isEmpty)
    }

    @Test("Nộp xong: Về thư viện đóng màn phiên; lần thi có trong Lịch sử thi, mở lại được Kết quả")
    func submitThenReturn() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        let attempt = try await workspace.startAttempt(app)
        let session = try #require(app.sessions.session)
        _ = attempt.selectOption(atPosition: 0)
        attempt.openReview()
        session.requestSubmit()
        session.confirmSubmit()
        #expect(session.screen == .results)
        app.sessions.returnToLibrary()
        #expect(!app.sessions.isSessionPresented)
        let saved = try #require(app.library.store.attempts.first)
        #expect(app.sessions.openHistoryAttempt(saved) == .opened)
        #expect(app.sessions.session?.screen == .results)
        #expect(app.sessions.session?.attempt == nil)
    }

    @Test("Mỗi lúc một phiên: đang có bài chưa nộp thì không mở Trước khi thi hay lần thi cũ, báo “Đang có bài chưa nộp”")
    func oneSessionAtATime() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        _ = try await workspace.startAttempt(app)
        let sample = try #require(app.library.store.entries.filter(\.isSample).first)
        let outcome = await app.sessions.openPreExam(examID: sample.examID)
        #expect(outcome == .blockedByUnsubmittedSession)
        #expect(app.sessions.preExam == nil)
        #expect(app.sessions.notice?.message == "Đang có bài chưa nộp")
    }

    @Test("Huỷ Trước khi thi trong lúc đang đọc file: không bắt đầu, không nhớ tên thí sinh")
    func cancelWhileStarting() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        let sample = try #require(app.library.store.entries.filter(\.isSample).first)
        await app.sessions.openPreExam(examID: sample.examID, mode: .practice)
        let preExam = try #require(app.sessions.preExam)
        preExam.candidateName = "Người thử"
        async let started = app.sessions.startPreExam()
        app.sessions.cancelPreExam()
        #expect(await started == false)
        #expect(!app.sessions.isSessionPresented)
        #expect(UserDefaultsSessionPreferences(defaults: workspace.defaults).candidateName != "Người thử")
    }

    // MARK: - File nhận từ app khác

    @Test("File trong Inbox được dời sang Received rồi thêm vào Thư viện; Inbox không còn file")
    func inboxFileIsMovedAndAdded() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        let file = try workspace.writeExam(named: "Đề nhận.exam", in: workspace.inbox)
        await app.open(file).value
        #expect(!FileManager.default.fileExists(atPath: file.path))
        let moved = workspace.received.appendingPathComponent("Đề nhận.exam")
        #expect(FileManager.default.fileExists(atPath: moved.path))
        let added = try #require(app.library.store.entries.first { !$0.isSample })
        #expect(added.fileURL.resolvingSymlinksInPath().path == moved.resolvingSymlinksInPath().path)
        #expect(added.status == .ready)
    }

    @Test("Nhận lại cùng tên: bản dời mới thêm số, không ghi đè bản cũ")
    func receivedNameCollision() throws {
        let workspace = try MobileWorkspace()
        let first = try workspace.writeExam(named: "Đề.exam", in: workspace.inbox)
        let firstMoved = try workspace.receivedFiles.adopt(first)
        let second = try workspace.writeExam(named: "Đề.exam", in: workspace.inbox)
        let secondMoved = try workspace.receivedFiles.adopt(second)
        #expect(firstMoved.lastPathComponent == "Đề.exam")
        #expect(secondMoved.lastPathComponent == "Đề 2.exam")
        #expect(FileManager.default.fileExists(atPath: firstMoved.path))
    }

    @Test("File ngoài Inbox (app Tệp mở tại chỗ) không bị dời")
    func fileOutsideInboxStays() throws {
        let workspace = try MobileWorkspace()
        let file = try workspace.writeExam(named: "Tại chỗ.exam", in: workspace.root.appendingPathComponent("Tệp"))
        #expect(!workspace.receivedFiles.isInInbox(file))
        #expect(try workspace.receivedFiles.adopt(file) == file)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Nhận file lúc đang làm bài: màn làm bài vẫn còn, đề vẫn được thêm; hộp hỏi trùng id chờ tới khi về Thư viện")
    func receiveWhileAttempting() async throws {
        let workspace = try MobileWorkspace()
        let app = await workspace.startedApp()
        let attempt = try await workspace.startAttempt(app)
        app.didEnterBackground()
        // Cùng đề với một đề mẫu nhưng là file khác: Thư viện hỏi Dùng file mới / Huỷ.
        let sample = try #require(app.library.store.entries.filter(\.isSample).first)
        let copy = try workspace.copyFile(sample.fileURL, named: "Bản chép.exam", into: workspace.inbox)
        await app.open(copy).value
        #expect(app.sessions.isSessionPresented)
        #expect(app.sessions.session?.attempt === attempt)
        #expect(attempt.phase == .paused)
        let prompt = try #require(app.library.prompts.first)
        guard case .replace = prompt.kind else {
            Issue.record("cần hộp hỏi Dùng file mới / Huỷ, được \(prompt.kind)")
            return
        }
    }

    // MARK: - Quyền đọc file

    @Test("URL đọc được của mục: phân giải lại bookmark (file đã đổi chỗ vẫn tìm được); không có bookmark thì giữ URL")
    func readableURLResolvesBookmark() throws {
        let workspace = try MobileWorkspace()
        let file = try workspace.writeExam(named: "Đề.exam", in: workspace.root.appendingPathComponent("A"))
        let bookmark = try file.bookmarkData()
        let moved = workspace.root.appendingPathComponent("B", isDirectory: true)
        try FileManager.default.moveItem(at: file.deletingLastPathComponent(), to: moved)
        let resolved = SecurityScopedAccess.readableURL(file, bookmark: bookmark)
        #expect(resolved.resolvingSymlinksInPath().path
            == moved.appendingPathComponent("Đề.exam").resolvingSymlinksInPath().path)
        #expect(SecurityScopedAccess.readableURL(file, bookmark: nil) == file)
        #expect(SecurityScopedAccess.with(resolved) { FileManager.default.fileExists(atPath: resolved.path) })
    }
}

// MARK: - Hỗ trợ

/// Thư mục tạm riêng của một test: kho, đề mẫu, `Inbox` và `Received` giả, `UserDefaults` riêng. Xoá khi test xong.
@MainActor
final class MobileWorkspace {
    let root: URL
    let defaults: UserDefaults
    let configuration: LibraryConfiguration
    let inbox: URL
    let received: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MobileFeatureTests-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = base
        defaults = UserDefaults(suiteName: base.appendingPathComponent("defaults.plist").path)!
        configuration = LibraryConfiguration.forApp(
            bundleIdentifier: LibraryConfiguration.iosBundleIdentifier,
            isAdmin: false,
            applicationSupportDirectory: base.appendingPathComponent("Application Support", isDirectory: true)
        )
        inbox = base.appendingPathComponent("Documents/Inbox", isDirectory: true)
        received = configuration.storeURL.deletingLastPathComponent().appendingPathComponent("Received", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    var receivedFiles: ReceivedFiles { ReceivedFiles(directory: received, inboxDirectory: inbox) }

    /// App với kho thật trong thư mục tạm, đã tải kho và tạo đề mẫu.
    func startedApp() async -> MobileAppModel {
        let storage = AppLaunchStorage(configuration: configuration, defaults: defaults)
        let library = LibraryModel(
            store: .persistent(configuration: configuration, defaults: defaults),
            startsAutomatically: true
        )
        let sessions = MobileSessionCoordinator(environment: .live(store: library.store, defaults: defaults))
        let app = MobileAppModel(library: library, sessions: sessions, storage: storage, received: receivedFiles)
        await library.waitUntilStarted()
        return app
    }

    /// Mở Trước khi thi cho đề mẫu đầu tiên và bắt đầu Luyện tập.
    func startAttempt(_ app: MobileAppModel) async throws -> AttemptModel {
        let sample = try #require(app.library.store.entries.filter(\.isSample).first)
        #expect(await app.sessions.openPreExam(examID: sample.examID, mode: .practice) == .opened)
        let preExam = try #require(app.sessions.preExam)
        preExam.candidateName = "Nguyễn Văn An"
        #expect(await app.sessions.startPreExam())
        return try #require(app.sessions.session?.attempt)
    }

    /// Ghi một gói đề hợp lệ (đề mẫu đầu tiên của bundle, id mới) vào `directory`.
    @discardableResult
    func writeExam(named name: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let samples = try #require(LibraryConfiguration.bundledSamplesURL)
        let first = try #require(try FileManager.default.contentsOfDirectory(atPath: samples.path)
            .filter { !$0.hasPrefix(".") }.sorted().first)
        let folder = samples.appendingPathComponent(first, isDirectory: true)
        var exam = try ExamJSON.decode(Data(contentsOf: folder.appendingPathComponent("exam.json")))
        exam.id = UUID()
        var media: [String: Data] = [:]
        let mediaFolder = folder.appendingPathComponent("media", isDirectory: true)
        for file in (try? FileManager.default.contentsOfDirectory(atPath: mediaFolder.path)) ?? [] where !file.hasPrefix(".") {
            media["media/\(file)"] = try Data(contentsOf: mediaFolder.appendingPathComponent(file))
        }
        let url = directory.appendingPathComponent(name, isDirectory: false)
        try ExamPackageWriter.write(ExamPackage(exam: exam, media: media), to: url)
        return url
    }

    func copyFile(_ source: URL, named name: String, into directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name, isDirectory: false)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }
}
