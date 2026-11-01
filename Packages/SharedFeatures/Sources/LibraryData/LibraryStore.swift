import ExamFile
import ExamKit
import Foundation
import Observation

/// Thư viện đề cho giao diện (docs/product/library.md): giao diện đọc trạng thái ở đây và gửi lệnh,
/// không đụng SwiftData hay file đề.
///
/// - Mọi trạng thái là giá trị (`LibraryEntry`, `Attempt`), không lộ model SwiftData.
/// - Đọc file đề luôn chạy ngoài main actor và ngoài thread pool của Swift concurrency (`FileWork`),
///   tối đa `configuration.maxConcurrentReads` file cùng lúc; kết quả được áp trên main actor.
/// - Mở app: `load()` → `seedSamplesIfNeeded()` → `refreshAll()` (hoặc `start()` làm cả ba);
///   gọi lại `refreshAll()` mỗi khi cửa sổ được kích hoạt.
@Observable
@MainActor
public final class LibraryStore {
    public let configuration: LibraryConfiguration

    /// Mọi mục, theo ngày thêm tăng dần. Tìm/lọc/sắp xếp bằng `LibraryQuery`.
    public private(set) var entries: [LibraryEntry] = []
    /// Mọi lần thi, mới nhất trước, kể cả lần thi của đề đã bị xoá khỏi thư viện.
    public private(set) var attempts: [Attempt] = []
    /// Lần thi gần nhất của từng đề, theo id đề.
    public private(set) var latestAttempts: [UUID: Attempt] = [:]
    /// Đang làm mới trạng thái file.
    public private(set) var isRefreshing = false
    /// Sự cố kho cần báo (kho hỏng đã được thay bằng kho mới, hoặc đang dùng kho tạm).
    public private(set) var storeIssue: LibraryStoreIssue?
    /// Lỗi kho gần nhất của các việc chạy ngầm (tải, làm mới, nhập, đề mẫu, đánh dấu đã mở).
    /// Các lệnh khác ném `LibraryError` trực tiếp.
    public private(set) var lastStorageError: LibraryError?

    /// Khoá UserDefaults "đã tạo đề mẫu" (docs/product/library.md: cài đặt nhỏ dùng `@AppStorage`).
    public static let samplesSeededKey = "library.samplesSeeded"

    @ObservationIgnored let repository: any LibraryRepository
    @ObservationIgnored let inspector: ExamFileInspector
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored let now: @Sendable () -> Date
    /// Thời hạn cho mỗi lần kiểm một file khi làm mới (phân giải bookmark, kiểm file, đọc).
    @ObservationIgnored let refreshReadTimeout: Duration
    /// Hạn của lần kiểm file của từng mục khi làm mới. Bản app: hết hạn sau `refreshReadTimeout` theo
    /// đồng hồ; chỉ test thay (`init(refreshDeadline:)`) để tự quyết lần kiểm nào hết hạn và lúc nào.
    @ObservationIgnored let refreshDeadline: @Sendable (UUID) -> FileWorkDeadline
    /// Mục có lần kiểm file còn chạy (kể cả lần đã quá hạn): làm mới bỏ qua cho tới khi lần đó xong.
    @ObservationIgnored let inFlightReads = InFlightReads()
    /// Dữ liệu lưu của từng mục (nguồn sự thật trong bộ nhớ, khớp với kho).
    @ObservationIgnored var records: [UUID: LibraryRecord] = [:]
    /// Tăng mỗi khi vị trí hoặc kết luận của mục đổi ngoài lần làm mới, để bỏ kết quả làm mới đã cũ.
    @ObservationIgnored private var revisions: [UUID: Int] = [:]
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshRequestedAgain = false

    init(
        configuration: LibraryConfiguration,
        repository: any LibraryRepository,
        defaults: UserDefaults,
        storeIssue: LibraryStoreIssue? = nil,
        inspector: ExamFileInspector = ExamFileInspector(),
        now: @escaping @Sendable () -> Date = { Date() },
        refreshReadTimeout: Duration = LibraryStore.defaultRefreshReadTimeout,
        refreshDeadline: (@Sendable (UUID) -> FileWorkDeadline)? = nil
    ) {
        self.configuration = configuration
        self.repository = repository
        self.defaults = defaults
        self.storeIssue = storeIssue
        self.inspector = inspector
        self.now = now
        self.refreshReadTimeout = refreshReadTimeout
        self.refreshDeadline = refreshDeadline ?? { _ in FileWork.deadline(after: refreshReadTimeout) }
    }

    /// Một lần kiểm file khi làm mới bị treo (ví dụ ổ mạng không phản hồi) thì thôi chờ sau 120 giây.
    static let defaultRefreshReadTimeout: Duration = .seconds(120)

    // MARK: - Tạo store

    /// Thư viện của app, lưu ở `configuration.storeURL`. Kho hỏng thì đổi tên, tạo kho mới và báo qua
    /// `storeIssue`; không crash. Chưa tải dữ liệu: gọi `load()` hoặc `start()`.
    /// - Parameter defaults: nơi lưu cờ "đã tạo đề mẫu" (mặc định `UserDefaults.standard` của bản app).
    public static func persistent(
        configuration: LibraryConfiguration,
        defaults: UserDefaults = .standard
    ) -> LibraryStore {
        let opened = LibraryPersistence.openPersistent(at: configuration.storeURL, now: Date())
        return LibraryStore(
            configuration: configuration,
            repository: opened.repository,
            defaults: defaults,
            storeIssue: opened.issue
        )
    }

    /// Thư viện trong bộ nhớ (SwiftData không ghi đĩa), cho test và preview.
    public static func inMemory(
        configuration: LibraryConfiguration,
        defaults: UserDefaults = .standard
    ) -> LibraryStore {
        LibraryStore(
            configuration: configuration,
            repository: LibraryPersistence.inMemoryRepository(),
            defaults: defaults
        )
    }

    /// Thư viện dựng sẵn cho SwiftUI preview: các mục và trạng thái đúng như truyền vào, không có file
    /// thật (đừng gọi `refreshAll()` trong preview: mọi mục sẽ thành Không tìm thấy file).
    public static func preview(
        entries: [LibraryEntry],
        attempts: [Attempt] = [],
        configuration: LibraryConfiguration = .student
    ) -> LibraryStore {
        let records = entries.map { entry in
            LibraryRecord(
                examID: entry.examID,
                location: StoredLocation(bookmark: Data(), path: entry.fileURL.path),
                summary: entry.summary,
                facts: FileFacts(size: entry.fileSize, modificationDate: entry.fileModificationDate),
                isSample: entry.isSample,
                addedAt: entry.addedAt,
                lastOpenedAt: entry.lastOpenedAt,
                verdict: nil,
                checkFingerprint: nil,
                checkedAt: nil
            )
        }
        let store = LibraryStore(
            configuration: configuration,
            repository: InMemoryLibraryRepository(entries: records, attempts: attempts),
            defaults: .standard
        )
        store.load()
        for entry in entries { store.setEntry(entry) }
        return store
    }

    // MARK: - Đọc trạng thái

    /// Bookmark của file đề của mục (để đọc file ngoài container của app trên iOS: `SecurityScopedAccess.readableURL`).
    public func fileBookmark(_ examID: UUID) -> Data? {
        records[examID]?.location.bookmark
    }

    public func entry(_ examID: UUID) -> LibraryEntry? {
        entries.first { $0.examID == examID }
    }

    /// Lần thi mới nhất trước; `examID == nil`: mọi lần thi (sidebar **Lịch sử thi**), có giá trị:
    /// chỉ đề đó (**Xem lịch sử thi**).
    public func attempts(examID: UUID?) -> [Attempt] {
        guard let examID else { return attempts }
        return attempts.filter { $0.examID == examID }
    }

    public func latestAttempt(examID: UUID) -> Attempt? {
        latestAttempts[examID]
    }

    /// Nội dung chi tiết của một lần thi (định dạng do giai đoạn 3 quyết định).
    public func attemptPayload(id: UUID) throws -> Data? {
        do {
            return try repository.attemptPayload(id: id)
        } catch {
            throw LibraryError.storage(error.localizedDescription)
        }
    }

    /// Đã từng tạo đề mẫu chưa (cờ trong `UserDefaults`, khoá `samplesSeededKey`).
    public var hasSeededSamples: Bool {
        defaults.bool(forKey: Self.samplesSeededKey)
    }

    // MARK: - Tải, mở app

    /// Đọc thư viện và lịch sử thi từ kho. Mục chưa được kiểm trong lần chạy này có trạng thái
    /// **Đang kiểm tra**; thông tin thẻ là thông tin đã lưu nên hiện được ngay.
    public func load() {
        let knownStatuses = Dictionary(entries.map { ($0.examID, $0.status) }, uniquingKeysWith: { first, _ in first })
        do {
            let loaded = try repository.fetchEntries()
            records = Dictionary(loaded.map { ($0.examID, $0) }, uniquingKeysWith: { first, _ in first })
            entries = records.values
                .map { makeEntry($0, status: knownStatuses[$0.examID] ?? .checking) }
                .sorted(by: Self.entryOrder)
        } catch {
            report(error, while: "load entries")
        }
        do {
            attempts = try repository.fetchAttempts()
            latestAttempts = Self.latestByExam(attempts)
        } catch {
            report(error, while: "load attempts")
        }
    }

    /// Mở app: tải, tạo đề mẫu lần đầu, rồi làm mới trạng thái file.
    /// - Returns: kết quả tạo đề mẫu (`didAddSamples` thì hiện dải chào mừng).
    @discardableResult
    public func start() async -> SampleReport {
        load()
        let samples = await seedSamplesIfNeeded()
        await refreshAll()
        return samples
    }

    /// Đã hiện thông báo sự cố kho cho người dùng.
    public func dismissStoreIssue() {
        storeIssue = nil
    }

    public func clearStorageError() {
        lastStorageError = nil
    }

    // MARK: - Làm mới trạng thái

    /// Kiểm mọi mục ở nền: phân giải bookmark (cập nhật bookmark cũ), kiểm file còn không, đọc lại
    /// file có dung lượng hoặc ngày sửa đổi khác lần trước (hoặc khi app đã đổi phiên bản), cập nhật
    /// thông tin thẻ và trạng thái. Kết quả hiện dần trên giao diện. Gọi khi đang làm mới thì chờ lần
    /// đang chạy xong rồi chạy thêm một lượt.
    ///
    /// Mỗi lần kiểm một file có thời hạn (120 giây): quá hạn thì thôi chờ, mục giữ nguyên trạng thái và
    /// thông tin cũ, kết quả về muộn bị bỏ. Chừng nào lần kiểm đó còn treo, các lần làm mới sau bỏ qua mục
    /// (giữ trạng thái) thay vì mở thêm lần đọc; khi nó xong, lần làm mới kế tiếp kiểm lại. Vì vậy làm mới
    /// luôn kết thúc và không cộng dồn luồng bị treo.
    public func refreshAll() async {
        if let running = refreshTask {
            refreshRequestedAgain = true
            await running.value
            return
        }
        let task = Task { await runRefreshLoop() }
        refreshTask = task
        await task.value
    }

    private func runRefreshLoop() async {
        isRefreshing = true
        repeat {
            refreshRequestedAgain = false
            await refreshPass()
        } while refreshRequestedAgain
        isRefreshing = false
        refreshTask = nil
    }

    private func refreshPass() async {
        let fingerprint = configuration.checkFingerprint
        let inFlight = inFlightReads
        let jobs = entries.compactMap { entry -> ExamFileInspector.RefreshJob? in
            guard let record = records[entry.examID] else { return nil }
            // Lần kiểm trước của mục này còn treo: không mở thêm lần đọc, giữ trạng thái.
            guard !inFlight.contains(record.examID) else {
                LibraryLog.files.notice(
                    "Skipping refresh of exam \(record.examID.uuidString, privacy: .public): previous check still running"
                )
                return nil
            }
            return ExamFileInspector.RefreshJob(
                examID: record.examID,
                revision: revisions[record.examID, default: 0],
                location: record.location,
                knownFacts: record.facts,
                cachedVerdict: record.checkFingerprint == fingerprint && record.verdict?.isReusable == true
                    ? record.verdict : nil
            )
        }
        let inspector = inspector
        let timeout = refreshReadTimeout
        let deadline = refreshDeadline
        var changed: [UUID] = []
        await forEachOffMain(
            jobs,
            inOrder: false,
            deadline: { job in deadline(job.examID) },
            work: { job in inFlight.track(job.examID) { inspector.refresh(job) } }
        ) { index, outcome in
            let job = jobs[index]
            guard let outcome else {
                // Quá hạn: giữ trạng thái và thông tin cũ; kết quả về muộn bị bỏ, lần làm mới sau kiểm lại.
                LibraryLog.files.error("""
                    Refresh check timed out after \(timeout, privacy: .public) \
                    for exam \(job.examID.uuidString, privacy: .public)
                    """)
                return
            }
            if applyRefresh(outcome, for: job) { changed.append(job.examID) }
        }
        persist(changed, while: "save refresh results")
    }

    /// Áp kết quả làm mới; `true` nếu dữ liệu lưu của mục đổi (cần ghi kho).
    private func applyRefresh(
        _ outcome: ExamFileInspector.RefreshOutcome,
        for job: ExamFileInspector.RefreshJob
    ) -> Bool {
        guard revisions[job.examID, default: 0] == job.revision, var record = records[job.examID] else {
            return false
        }
        switch outcome {
        case .missing:
            updateEntry(job.examID) { $0.status = .missing }
            return false
        case let .found(url, refreshedBookmark, facts, reading):
            let status: LibraryEntryStatus
            if let reading {
                if let readID = reading.examID, readID != job.examID {
                    // Vị trí của file giờ là một đề khác: file của đề này coi như không tìm thấy.
                    updateEntry(job.examID) { $0.status = .missing }
                    return false
                }
                record.verdict = reading.verdict
                record.facts = facts
                record.checkFingerprint = configuration.checkFingerprint
                record.checkedAt = now()
                if let summary = reading.summary { record.summary = summary }
                status = reading.verdict.status(for: configuration.readMode)
            } else if let verdict = record.verdict {
                status = verdict.status(for: configuration.readMode)
            } else {
                status = .checking
            }
            record.location.path = url.path
            if let refreshedBookmark { record.location.bookmark = refreshedBookmark }
            let changed = record != records[job.examID]
            records[job.examID] = record
            setEntry(makeEntry(record, status: status))
            return changed
        }
    }

    // MARK: - Thêm đề

    /// Thêm một hoặc nhiều file (nút Thêm đề, kéo thả, mở từ Finder). Đọc file ở nền theo chế độ của
    /// bản app; thêm những file được, báo cáo từng file theo đúng thứ tự đưa vào.
    ///
    /// - Bản Học viên: file hỏng, có lỗi hoặc cần app mới hơn → không thêm (`rejected`).
    /// - Bản Admin: file đọc dễ được thì thêm, kể cả có lỗi (trạng thái **Có lỗi**); hỏng hoặc cần app
    ///   mới hơn → không thêm.
    /// - Cùng id đề với mục đã có: cùng file → `alreadyInLibrary`; khác file → `needsReplaceConfirmation`.
    public func importFiles(_ urls: [URL]) async -> ImportReport {
        let snapshot = records.mapValues(\.location)
        let inspector = inspector
        var items: [ImportReport.Item] = []
        var addedThisBatch: [UUID: FileIdentity] = [:]
        var changed: [UUID] = []
        let probe: @Sendable (URL) -> ExamFileInspector.ImportProbe = { inspector.probeImport($0, existing: snapshot) }
        await forEachOffMain(urls, inOrder: true, work: probe) { index, probe in
            let outcome: ImportOutcome
            if let probe {
                outcome = applyImport(probe, snapshot: snapshot, addedThisBatch: &addedThisBatch, changed: &changed)
            } else {
                // Không xảy ra: nhập file không đặt thời hạn đọc.
                outcome = .rejected(.corrupt(reason: .readTimedOut(fileName: urls[index].lastPathComponent)))
            }
            items.append(ImportReport.Item(url: urls[index], outcome: outcome))
        }
        persist(changed, while: "save imported entries")
        return ImportReport(items: items)
    }

    private func applyImport(
        _ probe: ExamFileInspector.ImportProbe,
        snapshot: [UUID: StoredLocation],
        addedThisBatch: inout [UUID: FileIdentity],
        changed: inout [UUID]
    ) -> ImportOutcome {
        let file: ReadableFile
        switch probe.inspection {
        case .notExam:
            return .skippedNotExam
        case let .problem(problem, unreadable):
            // File đã có trong thư viện mà giờ không đọc được: thẻ phải hiện đúng trạng thái mới.
            if let unreadable, let examID = markUnreadable(unreadable) { changed.append(examID) }
            return .rejected(problem)
        case let .readable(readable):
            file = readable
        }
        let status = file.verdict.status(for: configuration.readMode)
        if var existing = records[file.examID],
           isSameFile(file, as: existing, probe: probe, snapshot: snapshot, addedThisBatch: addedThisBatch) {
            // Đúng file của mục đã có: chọn mục đó và cập nhật theo lần đọc vừa rồi, kể cả khi
            // file đã đổi thành có lỗi (trạng thái lỗi trên thẻ dành cho đề đã có mà file thay đổi).
            existing.adopt(file, fingerprint: configuration.checkFingerprint, checkedAt: now())
            replaceRecord(existing, status: status)
            changed.append(file.examID)
            return .alreadyInLibrary(examID: file.examID)
        }
        // Bản Học viên không thêm (và không đổi sang) file đọc nghiêm thất bại.
        if configuration.readMode == .strict, case let .failsStrict(reason) = file.verdict {
            return .rejected(.invalid(reason: reason))
        }
        if let existing = records[file.examID] {
            return .needsReplaceConfirmation(PendingReplacement(existingFileURL: existing.fileURL, file: file))
        }
        let record = newRecord(for: file)
        replaceRecord(record, status: status)
        addedThisBatch[file.examID] = file.identity
        changed.append(file.examID)
        return .added(examID: file.examID)
    }

    /// File vừa đọc có phải đúng file của mục `existing` không.
    ///
    /// Kết quả so lúc đọc (bookmark của mục được phân giải ở nền) chỉ còn đúng khi vị trí của mục chưa đổi
    /// từ lúc bắt đầu nhập. Nếu mục vừa được thêm hay đổi file bởi một lệnh chạy chồng (ví dụ hai lần nhập
    /// cùng một file mới), so đường dẫn thật (`realpath`) của file với vị trí hiện tại của mục, không đụng đĩa.
    private func isSameFile(
        _ file: ReadableFile,
        as existing: LibraryRecord,
        probe: ExamFileInspector.ImportProbe,
        snapshot: [UUID: StoredLocation],
        addedThisBatch: [UUID: FileIdentity]
    ) -> Bool {
        if let identity = file.identity, addedThisBatch[file.examID] == identity { return true }
        if snapshot[file.examID] == existing.location { return probe.matchesExistingFile }
        return existing.location.path == file.url.path
    }

    /// Mục đang trỏ tới đúng file không đọc được (so đường dẫn thật) nhận kết luận mới của file đó.
    /// - Returns: id đề của mục được cập nhật, nếu có.
    private func markUnreadable(_ file: ExamFileInspector.UnreadableFile) -> UUID? {
        guard var record = records.values.first(where: { $0.location.path == file.url.path }) else { return nil }
        record.verdict = file.verdict
        record.facts = file.facts
        record.checkFingerprint = configuration.checkFingerprint
        record.checkedAt = now()
        replaceRecord(record, status: file.verdict.status(for: configuration.readMode))
        return record.examID
    }

    /// **Dùng file mới**: mục cùng id đề chuyển sang file mới (giữ ngày thêm, lần mở, lần thi);
    /// mục không còn thì thêm mới. Mục trỏ sang file người dùng chọn nên không còn là đề mẫu.
    public func confirmReplace(_ pending: PendingReplacement) throws {
        let file = pending.file
        var record: LibraryRecord
        if var existing = records[file.examID] {
            existing.adopt(file, fingerprint: configuration.checkFingerprint, checkedAt: now())
            existing.isSample = false
            record = existing
        } else {
            record = newRecord(for: file)
        }
        try save(record)
        replaceRecord(record, status: file.verdict.status(for: configuration.readMode))
    }

    // MARK: - Tìm file

    /// **Tìm file…** cho đề mất file: file chọn phải là cùng đề (cùng id đề) và dùng được theo chế độ
    /// của bản app. Khác id đề, không đọc được, nằm trong Thùng rác, hoặc không phải `.exam` → ném lỗi,
    /// không đổi gì. Tìm được thì mục không còn là đề mẫu (như **Dùng file mới**).
    public func relocate(_ examID: UUID, to url: URL) async throws {
        guard let current = records[examID] else { throw LibraryError.entryNotFound(examID: examID) }
        let inspector = inspector
        let inspection = await Self.offMain { inspector.inspectNewFile(url) }
        let file: ReadableFile
        switch inspection {
        case .notExam:
            throw LibraryError.notAnExamFile(url)
        case let .problem(problem, _):
            throw LibraryError.unusableFile(problem)
        case let .readable(readable):
            file = readable
        }
        guard file.examID == examID else {
            throw LibraryError.differentExam(expectedTitle: current.summary.title, foundTitle: file.summary.title)
        }
        if configuration.readMode == .strict, case let .failsStrict(reason) = file.verdict {
            throw LibraryError.unusableFile(.invalid(reason: reason))
        }
        guard var record = records[examID] else { throw LibraryError.entryNotFound(examID: examID) }
        record.adopt(file, fingerprint: configuration.checkFingerprint, checkedAt: now())
        // Như Dùng file mới: mục giờ trỏ tới file người dùng chọn nên không còn là đề mẫu.
        record.isSample = false
        try save(record)
        replaceRecord(record, status: file.verdict.status(for: configuration.readMode))
    }

    // MARK: - Xoá, hoàn tác

    /// **Xoá khỏi thư viện**: chỉ xoá mục, không xoá file, không xoá lần thi.
    /// - Returns: giá trị để `undoRemove(_:)` khôi phục y nguyên.
    @discardableResult
    public func remove(_ examID: UUID) throws -> RemovedEntry {
        guard let record = records[examID], let entry = entry(examID) else {
            throw LibraryError.entryNotFound(examID: examID)
        }
        do {
            try repository.deleteEntry(examID: examID)
        } catch {
            throw LibraryError.storage(error.localizedDescription)
        }
        records[examID] = nil
        revisions[examID, default: 0] += 1
        entries.removeAll { $0.examID == examID }
        return RemovedEntry(entry: entry, record: record)
    }

    /// **Hoàn tác** xoá: khôi phục mục y nguyên (bookmark, ngày thêm, lần mở, cờ đề mẫu, trạng thái).
    /// Đề đã được thêm lại trong lúc đó → `LibraryError.alreadyInLibrary`, không đổi gì.
    public func undoRemove(_ removed: RemovedEntry) throws {
        guard records[removed.examID] == nil else {
            throw LibraryError.alreadyInLibrary(examID: removed.examID)
        }
        try save(removed.record)
        replaceRecord(removed.record, status: removed.entry.status)
    }

    // MARK: - Đánh dấu đã mở

    /// Ghi lại lúc mở đề (lần mở gần nhất).
    public func markOpened(_ examID: UUID) {
        guard var record = records[examID] else { return }
        record.lastOpenedAt = now()
        records[examID] = record
        updateEntry(examID) { $0.lastOpenedAt = record.lastOpenedAt }
        persist([examID], while: "save last opened date")
    }

    // MARK: - Lần thi

    /// Lưu một lần thi (giai đoạn 3 gọi khi nộp bài). Lần thi gắn với id đề, còn lại khi đề bị xoá.
    public func addAttempt(_ attempt: Attempt, payload: Data = Data()) throws {
        guard !attempts.contains(where: { $0.id == attempt.id }) else {
            throw LibraryError.duplicateAttempt(id: attempt.id)
        }
        do {
            try repository.insertAttempt(attempt, payload: payload)
        } catch {
            throw LibraryError.storage(error.localizedDescription)
        }
        let index = attempts.firstIndex { Attempt.newestFirst(attempt, $0) } ?? attempts.endIndex
        attempts.insert(attempt, at: index)
        if let latest = latestAttempts[attempt.examID], Attempt.newestFirst(latest, attempt) { return }
        latestAttempts[attempt.examID] = attempt
    }

    // MARK: - Nội bộ: mục

    static func entryOrder(_ lhs: LibraryEntry, _ rhs: LibraryEntry) -> Bool {
        (lhs.addedAt, lhs.examID.uuidString) < (rhs.addedAt, rhs.examID.uuidString)
    }

    static func latestByExam(_ attempts: [Attempt]) -> [UUID: Attempt] {
        var latest: [UUID: Attempt] = [:]
        for attempt in attempts where latest[attempt.examID].map({ Attempt.newestFirst(attempt, $0) }) ?? true {
            latest[attempt.examID] = attempt
        }
        return latest
    }

    /// Mục mới (không phải đề mẫu) cho file người dùng thêm.
    func newRecord(for file: ReadableFile) -> LibraryRecord {
        LibraryRecord(file: file, isSample: false, addedAt: now(), fingerprint: configuration.checkFingerprint)
    }

    func makeEntry(_ record: LibraryRecord, status: LibraryEntryStatus) -> LibraryEntry {
        LibraryEntry(
            examID: record.examID,
            summary: record.summary,
            fileURL: record.fileURL,
            fileSize: record.facts?.size,
            fileModificationDate: record.facts?.modificationDate,
            isSample: record.isSample,
            addedAt: record.addedAt,
            lastOpenedAt: record.lastOpenedAt,
            status: status
        )
    }

    /// Thay (hoặc thêm) mục trong bộ nhớ; kết quả làm mới đang chạy cho mục này bị bỏ.
    func replaceRecord(_ record: LibraryRecord, status: LibraryEntryStatus) {
        records[record.examID] = record
        revisions[record.examID, default: 0] += 1
        setEntry(makeEntry(record, status: status))
    }

    func setEntry(_ entry: LibraryEntry) {
        if let index = entries.firstIndex(where: { $0.examID == entry.examID }) {
            if entries[index].addedAt == entry.addedAt {
                entries[index] = entry
                return
            }
            entries.remove(at: index)
        }
        let index = entries.firstIndex { Self.entryOrder(entry, $0) } ?? entries.endIndex
        entries.insert(entry, at: index)
    }

    private func updateEntry(_ examID: UUID, _ change: (inout LibraryEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.examID == examID }) else { return }
        change(&entries[index])
    }

    // MARK: - Nội bộ: kho

    /// Ghi một mục; lỗi → `LibraryError.storage`, bộ nhớ không đổi (người gọi chỉ đổi sau khi ghi được).
    func save(_ record: LibraryRecord) throws {
        do {
            try repository.saveEntries([record])
        } catch {
            throw LibraryError.storage(error.localizedDescription)
        }
    }

    /// Ghi các mục (bản hiện tại trong bộ nhớ) cho việc chạy ngầm; lỗi ghi vào `lastStorageError`.
    /// - Returns: `false` nếu ghi lỗi.
    @discardableResult
    func persist(_ examIDs: [UUID], while activity: String) -> Bool {
        let current = examIDs.compactMap { records[$0] }
        guard !current.isEmpty else { return true }
        do {
            try repository.saveEntries(current)
            return true
        } catch {
            report(error, while: activity)
            return false
        }
    }

    func report(_ error: any Error, while activity: String) {
        LibraryLog.store.error(
            "Library storage error (\(activity, privacy: .public)): \(String(describing: error), privacy: .public)"
        )
        lastStorageError = .storage(error.localizedDescription)
    }

    // MARK: - Nội bộ: chạy ngoài main actor

    /// Chạy `work` cho từng phần tử trên hàng đợi file (`FileWork`, ngoài main actor), tối đa
    /// `configuration.maxConcurrentReads` việc cùng lúc. `apply` chạy trên main actor ngay khi có kết
    /// quả: theo thứ tự hoàn thành, hoặc theo thứ tự đầu vào nếu `inOrder`. Có `deadline` (hạn của từng
    /// phần tử, hẹn khi việc bắt đầu) thì việc quá hạn nhận `nil` (kết quả về muộn bị bỏ) và nhường chỗ cho
    /// việc kế tiếp; không có thì không bao giờ `nil`.
    func forEachOffMain<Input: Sendable, Output: Sendable>(
        _ inputs: [Input],
        inOrder: Bool,
        deadline: (@Sendable (Input) -> FileWorkDeadline)? = nil,
        work: @escaping @Sendable (Input) -> Output,
        apply: (Int, Output?) -> Void
    ) async {
        guard !inputs.isEmpty else { return }
        let limit = max(1, configuration.maxConcurrentReads)
        await withTaskGroup(of: (Int, Output?).self) { group in
            var nextInput = 0
            func launchNext() {
                let index = nextInput
                let input = inputs[index]
                if let deadline {
                    let expiry = deadline(input)
                    group.addTask { (index, await FileWork.run(deadline: expiry) { work(input) }) }
                } else {
                    group.addTask { (index, await FileWork.run { work(input) }) }
                }
                nextInput += 1
            }
            while nextInput < min(limit, inputs.count) { launchNext() }
            var pending: [Int: Output?] = [:]
            var nextToApply = 0
            while let (index, output) = await group.next() {
                if nextInput < inputs.count { launchNext() }
                if inOrder {
                    pending[index] = output
                    while let ready = pending.removeValue(forKey: nextToApply) {
                        apply(nextToApply, ready)
                        nextToApply += 1
                    }
                } else {
                    apply(index, output)
                }
            }
        }
    }

    /// Chạy một việc đồng bộ với file trên hàng đợi file (ngoài main actor) và chờ kết quả.
    nonisolated static func offMain<Output: Sendable>(_ work: @escaping @Sendable () -> Output) async -> Output {
        await FileWork.run(work)
    }
}
