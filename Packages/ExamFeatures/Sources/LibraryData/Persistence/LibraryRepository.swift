import ExamFile
import Foundation

/// Nơi file đề nằm: bookmark (tìm lại được khi file đổi tên hoặc di chuyển trên cùng ổ) và
/// đường dẫn ở lần phân giải gần nhất.
struct StoredLocation: Hashable, Sendable {
    var bookmark: Data
    var path: String

    var url: URL { URL(fileURLWithPath: path) }
}

/// Dung lượng và ngày sửa đổi file; khác lần đọc trước thì phải đọc lại file.
struct FileFacts: Hashable, Sendable {
    var size: Int64?
    var modificationDate: Date?
}

/// Kết luận đọc nội dung file. Không gồm "không tìm thấy file" vì đó là chuyện vị trí, không phải
/// nội dung. Được lưu kèm `FileFacts` và dấu bộ kiểm để lần làm mới sau khỏi đọc lại file chưa đổi.
enum FileVerdict: Hashable, Sendable {
    /// Đọc nghiêm được (nên đọc dễ cũng được).
    case ready
    /// Đọc dễ được, đọc nghiêm thất bại; `reason` là lỗi của lần đọc nghiêm.
    case failsStrict(reason: FileProblemReason)
    /// Không đọc được kể cả ở chế độ dễ.
    case corrupt(reason: FileProblemReason)
    /// Đề mới hơn phiên bản app hiểu.
    case needsNewerApp(found: Int, supported: Int)

    /// Dùng lại được ở lần làm mới sau khi file không đổi: không, nếu lý do là chữ đọc từ kho (`FileProblemReason.stored`):
    /// kho chỉ lưu chữ tiếng Việt của lý do (`LibrarySchemaV1` không đổi), giao diện cần lý do dạng mã để dựng câu theo
    /// ngôn ngữ giao diện, nên file có vấn đề được đọc lại một lần mỗi lần mở app (bước 7b).
    var isReusable: Bool {
        switch self {
        case .ready, .needsNewerApp: true
        case let .failsStrict(reason), let .corrupt(reason):
            if case .stored = reason { false } else { true }
        }
    }

    /// Trạng thái hiển thị theo chế độ của bản app: cùng một file "đọc dễ được, đọc nghiêm thất bại"
    /// là **Đề có lỗi** ở bản Học viên và **Có lỗi (Admin)** ở bản Admin.
    func status(for mode: ReadMode) -> LibraryEntryStatus {
        switch self {
        case .ready:
            .ready
        case let .failsStrict(reason):
            mode == .strict ? .invalid(reason: reason) : .readableWithIssues(reason: reason)
        case let .corrupt(reason):
            .corrupt(reason: reason)
        case let .needsNewerApp(found, supported):
            .needsNewerApp(found: found, supported: supported)
        }
    }
}

/// Toàn bộ dữ liệu lưu của một mục thư viện (dạng giá trị, độc lập với SwiftData).
struct LibraryRecord: Hashable, Sendable {
    var examID: UUID
    var location: StoredLocation
    var summary: ExamSummary
    /// Dung lượng/ngày sửa đổi ở lần đọc nội dung gần nhất; `nil` nếu chưa đọc lần nào.
    var facts: FileFacts?
    var isSample: Bool
    var addedAt: Date
    var lastOpenedAt: Date?
    /// Kết luận đọc file gần nhất; `nil` nếu chưa đọc.
    var verdict: FileVerdict?
    /// `LibraryConfiguration.checkFingerprint` lúc ra kết luận `verdict`.
    var checkFingerprint: String?
    var checkedAt: Date?

    var fileURL: URL { location.url }

    /// Mục mới từ một file vừa đọc xong.
    init(file: ReadableFile, isSample: Bool, addedAt: Date, fingerprint: String) {
        examID = file.examID
        location = StoredLocation(bookmark: file.bookmark, path: file.url.path)
        summary = file.summary
        facts = file.facts
        self.isSample = isSample
        self.addedAt = addedAt
        lastOpenedAt = nil
        verdict = file.verdict
        checkFingerprint = fingerprint
        checkedAt = addedAt
    }

    init(
        examID: UUID,
        location: StoredLocation,
        summary: ExamSummary,
        facts: FileFacts?,
        isSample: Bool,
        addedAt: Date,
        lastOpenedAt: Date?,
        verdict: FileVerdict?,
        checkFingerprint: String?,
        checkedAt: Date?
    ) {
        self.examID = examID
        self.location = location
        self.summary = summary
        self.facts = facts
        self.isSample = isSample
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.verdict = verdict
        self.checkFingerprint = checkFingerprint
        self.checkedAt = checkedAt
    }

    /// Trỏ mục sang `file` (cùng id đề) và lấy thông tin, kết luận của lần đọc đó.
    /// Giữ ngày thêm, lần mở gần nhất và cờ đề mẫu.
    mutating func adopt(_ file: ReadableFile, fingerprint: String, checkedAt: Date) {
        location = StoredLocation(bookmark: file.bookmark, path: file.url.path)
        summary = file.summary
        facts = file.facts
        verdict = file.verdict
        checkFingerprint = fingerprint
        self.checkedAt = checkedAt
    }
}

/// Mọi truy cập kho Thư viện đi qua đây (docs/product/library.md, mục Lưu trữ: SwiftData sau một
/// lớp repository, dự phòng GRDB). Chạy trên main actor cùng `LibraryStore`; việc nặng (đọc file đề)
/// nằm ngoài repository và ngoài main actor.
@MainActor
protocol LibraryRepository: AnyObject {
    /// Mọi mục, theo ngày thêm tăng dần.
    func fetchEntries() throws -> [LibraryRecord]
    /// Thêm hoặc cập nhật (theo id đề) rồi lưu một lần. Lỗi thì không đổi gì.
    func saveEntries(_ records: [LibraryRecord]) throws
    /// Xoá mục theo id đề; không có thì thôi. Không đụng tới lần thi.
    func deleteEntry(examID: UUID) throws
    /// Mọi lần thi, mới nhất trước.
    func fetchAttempts() throws -> [Attempt]
    func insertAttempt(_ attempt: Attempt, payload: Data) throws
    func attemptPayload(id: UUID) throws -> Data?
}

/// Repository trong bộ nhớ, cho test và preview. Cùng hợp đồng với bản SwiftData.
@MainActor
final class InMemoryLibraryRepository: LibraryRepository {
    private var entries: [UUID: LibraryRecord] = [:]
    private var attempts: [UUID: (attempt: Attempt, payload: Data)] = [:]

    init(entries: [LibraryRecord] = [], attempts: [Attempt] = []) {
        for record in entries { self.entries[record.examID] = record }
        for attempt in attempts { self.attempts[attempt.id] = (attempt, Data()) }
    }

    func fetchEntries() throws -> [LibraryRecord] {
        entries.values.sorted { ($0.addedAt, $0.examID.uuidString) < ($1.addedAt, $1.examID.uuidString) }
    }

    func saveEntries(_ records: [LibraryRecord]) throws {
        for record in records { entries[record.examID] = record }
    }

    func deleteEntry(examID: UUID) throws {
        entries[examID] = nil
    }

    func fetchAttempts() throws -> [Attempt] {
        attempts.values.map(\.attempt).sorted(by: Attempt.newestFirst)
    }

    func insertAttempt(_ attempt: Attempt, payload: Data) throws {
        attempts[attempt.id] = (attempt, payload)
    }

    func attemptPayload(id: UUID) throws -> Data? {
        attempts[id]?.payload
    }
}
