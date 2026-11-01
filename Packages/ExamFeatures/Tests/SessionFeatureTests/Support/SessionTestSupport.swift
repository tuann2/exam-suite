import ExamFile
import ExamKit
import Foundation
import LibraryData
import ReportFeature
@testable import SessionFeature
@testable import SessionModel
import Testing

// MARK: - Đồng hồ giả

/// Đồng hồ điều khiển bằng tay: `uptime` (giây) và `now` chỉ đổi khi test gọi `advance`.
final class FakeClock: SessionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var uptimeValue: TimeInterval = 1000
    private var date = Date(timeIntervalSince1970: 1_792_000_000)

    func now() -> Date { lock.withLock { date } }
    func uptime() -> TimeInterval { lock.withLock { uptimeValue } }

    /// Thời gian trôi `seconds` (cả đồng hồ đơn điệu lẫn giờ hệ thống).
    func advance(_ seconds: TimeInterval) {
        lock.withLock {
            uptimeValue += seconds
            date = date.addingTimeInterval(seconds)
        }
    }

    /// Chỉ giờ hệ thống đổi (người dùng chỉnh giờ máy); thời gian làm bài không được đổi theo.
    func shiftWallClock(_ seconds: TimeInterval) {
        lock.withLock { date = date.addingTimeInterval(seconds) }
    }
}

// MARK: - Thư viện và cài đặt giả

@MainActor
final class FakePreferences: SessionPreferences, ReportPreferences {
    var candidateName: String
    var lastMode: SessionMode
    var reportReviewLevel: ResultsReviewLevel = .default

    init(candidateName: String = "Nguyễn Văn An", lastMode: SessionMode = .practice) {
        self.candidateName = candidateName
        self.lastMode = lastMode
    }
}

struct FakeStorageError: Error, LocalizedError {
    var errorDescription: String? { "đĩa đầy" }
}

/// Thư viện giả: đề (gói đọc nghiêm hoặc lỗi), lịch sử thi, payload; ghi lại yêu cầu làm mới.
@MainActor
final class FakeLibrary: SessionLibrary {
    var entries: [UUID: LibraryEntry] = [:]
    var packages: [UUID: Result<ExamPackage, ExamLoadFailure>] = [:]
    var storedAttempts: [Attempt] = []
    var payloads: [UUID: Data] = [:]
    var failSaving = false
    private(set) var refreshRequests: [UUID] = []
    private(set) var readCount = 0
    /// Bật thì `readExam` treo tới khi test gọi `releaseReads()` (giả lập đọc file chậm).
    var holdsReads = false
    private var heldReads: [CheckedContinuation<Void, Never>] = []

    var heldReadCount: Int { heldReads.count }

    /// Cho mọi lần đọc đang treo chạy tiếp.
    func releaseReads() {
        let held = heldReads
        heldReads = []
        for continuation in held { continuation.resume() }
    }

    /// Chờ tới khi có `count` lần đọc đang treo; quá `maxYields` lượt thì báo lỗi test và thôi chờ (không treo
    /// cả bộ test khi code không còn đọc file như mong đợi).
    func waitForHeldReads(
        _ count: Int,
        maxYields: Int = 100_000,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        var yields = 0
        while heldReads.count < count {
            yields += 1
            guard yields <= maxYields else {
                Issue.record(
                    "Chờ \(count) lần đọc file đang treo nhưng chỉ có \(heldReads.count)",
                    sourceLocation: sourceLocation
                )
                return
            }
            await Task.yield()
        }
    }

    /// Thêm đề vào thư viện, Sẵn sàng.
    func add(_ package: ExamPackage, status: LibraryEntryStatus = .ready) {
        let exam = package.exam
        entries[exam.id] = LibraryEntry(
            examID: exam.id,
            summary: ExamSummary(package: package),
            fileURL: URL(fileURLWithPath: "/tmp/\(exam.id).exam"),
            addedAt: Date(timeIntervalSince1970: 0),
            status: status
        )
        packages[exam.id] = .success(package)
    }

    func add(_ exam: Exam) { add(ExamPackage(exam: exam)) }

    /// Đề bị xoá khỏi thư viện.
    func remove(_ examID: UUID) {
        entries[examID] = nil
        packages[examID] = nil
    }

    func entry(_ examID: UUID) -> LibraryEntry? { entries[examID] }

    func attempts(examID: UUID) -> [Attempt] {
        storedAttempts.filter { $0.examID == examID }.sorted(by: Attempt.newestFirst)
    }

    func saveAttempt(_ attempt: Attempt, payload: Data) throws {
        if failSaving { throw LibraryError.storage("đĩa đầy") }
        storedAttempts.append(attempt)
        payloads[attempt.id] = payload
    }

    func attemptPayload(id: UUID) throws -> Data? { payloads[id] }

    func readExam(_ examID: UUID) async -> Result<ExamPackage, ExamLoadFailure> {
        readCount += 1
        if holdsReads {
            await withCheckedContinuation { heldReads.append($0) }
        }
        guard entries[examID] != nil else { return .failure(.notInLibrary) }
        return packages[examID] ?? .failure(.fileMissing)
    }

    func examFileNeedsRefresh(_ examID: UUID) {
        refreshRequests.append(examID)
    }
}

/// Dãy seed cố định cho mỗi lần Bắt đầu.
@MainActor
final class SeedSequence {
    var seeds: [UInt64]
    private(set) var used: [UInt64] = []

    init(_ seeds: [UInt64] = Array(1 ... 100)) { self.seeds = seeds }

    func next() -> UInt64 {
        let seed = seeds.removeFirst()
        used.append(seed)
        return seed
    }
}

/// Mọi phụ thuộc giả của một test.
@MainActor
final class Harness {
    let library = FakeLibrary()
    let preferences: FakePreferences
    let clock = FakeClock()
    let seeds = SeedSequence()
    private(set) var attemptIDs: [UUID] = []

    init(candidateName: String = "Nguyễn Văn An", lastMode: SessionMode = .practice) {
        preferences = FakePreferences(candidateName: candidateName, lastMode: lastMode)
    }

    var environment: SessionEnvironment {
        SessionEnvironment(
            library: library,
            preferences: preferences,
            makeSeed: { [seeds] in seeds.next() },
            makeClock: { [clock] in clock },
            makeAttemptID: { [weak self] in
                let id = UUID()
                self?.attemptIDs.append(id)
                return id
            }
        )
    }

    /// Mở Trước khi thi (đề phải có trong thư viện giả).
    func preExam(_ exam: Exam, preset: PreExamPreset = .fresh) -> PreExamModel {
        if library.entries[exam.id] == nil { library.add(exam) }
        return PreExamModel(package: ExamPackage(exam: exam), preset: preset, environment: environment)
    }

    /// Bắt đầu một phiên với lựa chọn tuỳ chỉnh.
    func start(
        _ exam: Exam,
        mode: SessionMode = .exam,
        configure: (PreExamModel) -> Void = { _ in }
    ) async throws -> AttemptModel {
        let model = preExam(exam)
        model.mode = mode
        configure(model)
        guard let attempt = await model.start() else {
            throw StartFailed(reason: model.startFailure ?? model.issues.map(\.message).joined(separator: "; "))
        }
        return attempt
    }

    struct StartFailed: Error { let reason: String }
}

// MARK: - Đề dựng bằng code

/// Một phần của đề: tiêu đề và các câu.
struct SectionSpec {
    var title: String
    var questions: [Question]
}

/// Câu một đáp án với `options` lựa chọn, đáp án đúng ở vị trí `correct`.
func singleQuestion(_ text: String, options: Int = 4, correct: Int = 1, explanation: String? = "Giải thích") -> Question {
    Question(
        type: .single,
        text: text,
        options: (0 ..< options).map { Option(id: OptionID(index: $0)!, text: "\(text) – lựa chọn \($0 + 1)") },
        correct: [OptionID(index: correct)!],
        explanation: explanation
    )
}

/// Câu nhiều đáp án, đúng là A và C.
func multipleQuestion(_ text: String) -> Question {
    Question(
        type: .multiple,
        text: text,
        options: (0 ..< 4).map { Option(id: OptionID(index: $0)!, text: "\(text) – lựa chọn \($0 + 1)") },
        correct: [OptionID("A")!, OptionID("C")!],
        explanation: "A và C"
    )
}

func makeExam(
    title: String = "Kiến thức chung",
    code: String? = "KTC01",
    passPercent: Int = 70,
    timeLimitMinutes: Int = 30,
    hideAnswers: Bool = false,
    sections: [SectionSpec]
) -> Exam {
    Exam(
        title: title,
        code: code,
        passPercent: passPercent,
        timeLimitMinutes: timeLimitMinutes,
        hideAnswers: hideAnswers,
        instructions: "Đọc kỹ từng câu.",
        sections: sections.map { ExamSection(title: $0.title, questions: $0.questions) }
    )
}

/// Đề `counts.count` phần, phần i có `counts[i]` câu một đáp án (đúng là B).
func makeExam(
    counts: [Int],
    passPercent: Int = 70,
    timeLimitMinutes: Int = 30,
    hideAnswers: Bool = false
) -> Exam {
    makeExam(
        passPercent: passPercent,
        timeLimitMinutes: timeLimitMinutes,
        hideAnswers: hideAnswers,
        sections: counts.enumerated().map { section, count in
            SectionSpec(
                title: "Phần \(section + 1)",
                questions: (0 ..< count).map { singleQuestion("P\(section + 1)C\($0 + 1)") }
            )
        }
    )
}

extension AttemptModel {
    /// Trả lời câu hiện tại bằng đáp án gốc `letter`.
    @discardableResult
    func answer(_ letter: String) -> Bool {
        selectOption(OptionID(letter)!)
    }

    /// Trả lời đúng câu hiện tại.
    func answerCorrectly() {
        for id in currentQuestion.correct { selectOption(id) }
    }

    /// Trả lời sai câu hiện tại (một lựa chọn không đúng).
    func answerWrongly() {
        let wrong = currentQuestion.options.map(\.id).first { !currentQuestion.correctSet.contains($0) }!
        selectOption(wrong)
    }

    /// Mở rà soát và nộp (xác nhận nếu cần).
    @discardableResult
    func submitNow() -> SessionSubmission? {
        if phase == .inProgress { openReview() }
        if let submission = requestSubmit() { return submission }
        return submit()
    }
}

// MARK: - Fixture thật

/// Đường dẫn tới `fixtures/` ở gốc repo, tính từ vị trí file này.
enum RepoFixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // SessionFeatureTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // ExamFeatures
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("fixtures", isDirectory: true)

    /// Đề trong `fixtures/exams/<name>` (exam.json + media/), dựng thành `ExamPackage`.
    static func package(_ name: String) throws -> ExamPackage {
        let directory = root.appendingPathComponent("exams/\(name)", isDirectory: true)
        let exam = try ExamJSON.decode(Data(contentsOf: directory.appendingPathComponent("exam.json")))
        var media: [String: Data] = [:]
        let mediaDirectory = directory.appendingPathComponent("media", isDirectory: true)
        if FileManager.default.fileExists(atPath: mediaDirectory.path) {
            for file in try FileManager.default.contentsOfDirectory(atPath: mediaDirectory.path) where !file.hasPrefix(".") {
                media["media/\(file)"] = try Data(contentsOf: mediaDirectory.appendingPathComponent(file))
            }
        }
        return ExamPackage(exam: exam, media: media)
    }
}

/// Thư mục tạm riêng của một test (đường dẫn thật), xoá khi test xong.
final class SessionWorkspace {
    let root: URL
    let defaults: UserDefaults

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionFeatureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let resolved = base.withUnsafeFileSystemRepresentation { path -> String? in
            guard let path, let real = realpath(path, nil) else { return nil }
            defer { free(real) }
            return String(cString: real)
        }
        root = resolved.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? base
        defaults = UserDefaults(suiteName: root.appendingPathComponent("defaults.plist").path)!
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath, isDirectory: false)
    }

    func configuration() -> LibraryConfiguration {
        LibraryConfiguration(
            readMode: .strict,
            isAdmin: false,
            storeURL: url("AppSupport/Library.store"),
            samplesDirectoryURL: root.appendingPathComponent("AppSupport/Samples", isDirectory: true),
            samplesSourceURL: nil,
            checkFingerprint: "session-test"
        )
    }

    /// Ghi gói `.exam` bằng `ExamPackageWriter` (như app).
    @discardableResult
    func write(_ package: ExamPackage, to relativePath: String) throws -> URL {
        let url = url(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ExamPackageWriter.write(package, to: url)
        return url
    }
}
