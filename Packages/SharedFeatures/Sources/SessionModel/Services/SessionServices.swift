import ExamFile
import ExamKit
import Foundation
import InterfaceCore
import LibraryData

/// Vì sao không mở hay bắt đầu được một đề (docs/product/exam-taking.md, mục Bắt đầu).
public enum ExamLoadFailure: Error, Hashable, Sendable {
    /// Đề không còn trong thư viện.
    case notInLibrary
    /// Không tìm thấy file đề ở vị trí đã biết.
    case fileMissing
    /// File có nhưng đọc nghiêm không được; `reason` là câu báo đã tra catalog (lỗi của bộ đọc theo mã,
    /// `ErrorMessages`).
    case unreadable(reason: String)
    /// File giờ là một đề khác (khác id đề).
    case differentExam

    /// Lý do hiển thị, tiếng Việt.
    public var message: String {
        switch self {
        case .notInLibrary:
            localized("Đề không còn trong thư viện.")
        case .fileMissing:
            localized("Không tìm thấy file đề.")
        case let .unreadable(reason):
            reason
        case .differentExam:
            localized("File của đề giờ là một đề khác.")
        }
    }
}

/// Phần Thư viện mà phiên thi cần: mục đề, lịch sử thi, lưu lần thi, đọc nghiêm file đề.
/// App dùng `LibraryStoreSessionLibrary` (bọc `LibraryStore`); test thay bằng bản giả.
@MainActor
public protocol SessionLibrary: AnyObject {
    /// Mục thư viện của đề; nil nếu đề không còn trong thư viện.
    func entry(_ examID: UUID) -> LibraryEntry?
    /// Các lần thi của đề, mới nhất trước.
    func attempts(examID: UUID) -> [Attempt]
    /// Lưu một lần thi đã nộp (tóm tắt + payload `AttemptRecord`).
    func saveAttempt(_ attempt: Attempt, payload: Data) throws
    /// Payload của một lần thi; nil nếu không có.
    func attemptPayload(id: UUID) throws -> Data?
    /// Đọc lại file đề ở chế độ nghiêm (cả hai bản app), không chặn main actor.
    func readExam(_ examID: UUID) async -> Result<ExamPackage, ExamLoadFailure>
    /// Đọc file đề thất bại: yêu cầu Thư viện làm mới trạng thái thẻ (như Làm mới trạng thái của
    /// library.md). Không chờ kết quả.
    func examFileNeedsRefresh(_ examID: UUID)
}

/// Cài đặt nhỏ của phiên thi, chung cho mọi đề: tên thí sinh và chế độ dùng lần trước. App dùng
/// `UserDefaultsSessionPreferences` (cùng khoá với `@AppStorage` của giao diện). Phần xem lại của PDF kết quả dùng lần
/// trước là `ReportPreferences` của SessionFeature (bản macOS): kiểu của nó thuộc ReportFeature, module này không biết.
@MainActor
public protocol SessionPreferences: AnyObject {
    var candidateName: String { get set }
    var lastMode: SessionMode { get set }
}

/// Mọi phụ thuộc bên ngoài của phiên thi, tiêm vào để test được: thư viện, cài đặt, seed, đồng hồ.
@MainActor
public struct SessionEnvironment {
    public var library: any SessionLibrary
    public var preferences: any SessionPreferences
    /// Seed mới cho mỗi lần Bắt đầu (app: ngẫu nhiên của hệ thống).
    public var makeSeed: () -> UInt64
    /// Đồng hồ cho mỗi phiên mới (app: `SystemSessionClock`).
    public var makeClock: () -> any SessionClock
    /// Id cho lần thi khi nộp.
    public var makeAttemptID: () -> UUID

    public init(
        library: any SessionLibrary,
        preferences: any SessionPreferences,
        makeSeed: @escaping () -> UInt64 = { UInt64.random(in: UInt64.min ... UInt64.max) },
        makeClock: @escaping () -> any SessionClock = { SystemSessionClock() },
        makeAttemptID: @escaping () -> UUID = { UUID() }
    ) {
        self.library = library
        self.preferences = preferences
        self.makeSeed = makeSeed
        self.makeClock = makeClock
        self.makeAttemptID = makeAttemptID
    }

    /// Môi trường của app: thư viện thật, cài đặt trong `defaults` (app: `UserDefaults.standard`) và đồng hồ
    /// thật.
    /// - Parameter timeScale: hệ số thời gian của đồng hồ phiên thi; khác 1 chỉ ở chế độ cô lập của UI test
    ///   (build Debug, `AppLaunchStorage`). Bản Release luôn dùng `SystemSessionClock`.
    public static func live(
        store: LibraryStore,
        defaults: UserDefaults = .standard,
        timeScale: Double = 1
    ) -> SessionEnvironment {
        SessionEnvironment(
            library: LibraryStoreSessionLibrary(store: store),
            preferences: UserDefaultsSessionPreferences(defaults: defaults),
            makeClock: clockFactory(timeScale: timeScale)
        )
    }

    /// Đồng hồ cho mỗi phiên mới: `SystemSessionClock`, hoặc (chỉ build Debug, hệ số khác 1) đồng hồ chạy nhanh
    /// cho UI test.
    nonisolated static func clockFactory(timeScale: Double) -> () -> any SessionClock {
        #if DEBUG
        if timeScale != 1 {
            return { ScaledSessionClock(base: SystemSessionClock(), factor: timeScale) }
        }
        #endif
        return { SystemSessionClock() }
    }
}

#if DEBUG
/// Đồng hồ chạy nhanh gấp `factor` lần cho UI test (chỉ build Debug, `-ExamSuiteUITestTimeScale`): thời gian đo
/// (`uptime`) nhân hệ số để kiểm cảnh báo 5/1 phút và hết giờ mà không chờ thật; mốc ghi (`now`) là giờ thật.
/// Không sửa ExamKit: phiên thi chỉ thấy một `SessionClock` khác.
struct ScaledSessionClock: SessionClock {
    let base: any SessionClock
    let factor: Double

    func now() -> Date { base.now() }

    func uptime() -> TimeInterval { base.uptime() * factor }
}
#endif

// MARK: - Bản thật

/// Cài đặt phiên thi trong `UserDefaults`. Giao diện dùng `@AppStorage` với cùng khoá.
@MainActor
public final class UserDefaultsSessionPreferences: SessionPreferences {
    /// Tên thí sinh dùng lần trước (chung cho mọi đề).
    public static let candidateNameKey = "session.candidateName"
    /// Chế độ dùng lần trước: `practice` hoặc `exam`; chưa có thì Luyện tập.
    public static let lastModeKey = "session.lastMode"

    /// Nơi lưu; SessionFeature đọc/ghi thêm phần xem lại của PDF kết quả ở đây (`ReportPreferences`).
    public let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var candidateName: String {
        get { defaults.string(forKey: Self.candidateNameKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.candidateNameKey) }
    }

    public var lastMode: SessionMode {
        get { defaults.string(forKey: Self.lastModeKey).flatMap(SessionMode.init(rawValue:)) ?? .practice }
        set { defaults.set(newValue.rawValue, forKey: Self.lastModeKey) }
    }
}

/// `SessionLibrary` trên `LibraryStore` của app.
///
/// Đọc file đề: đường dẫn của mục theo lần phân giải bookmark gần nhất, đọc nghiêm trên hàng đợi GCD
/// (không chiếm luồng của Swift concurrency, cùng lý do với `FileWork` của LibraryData). Đọc lỗi thì
/// giao diện gọi `examFileNeedsRefresh` để Thư viện phân giải lại bookmark và cập nhật trạng thái thẻ.
@MainActor
public final class LibraryStoreSessionLibrary: SessionLibrary {
    public typealias Reader = @Sendable (URL) throws -> ExamPackage

    public let store: LibraryStore
    private let reader: Reader

    private static let queue = DispatchQueue(
        label: "vn.io.nt0.examsuite.session.files",
        qos: .userInitiated,
        attributes: .concurrent
    )

    public init(
        store: LibraryStore,
        reader: @escaping Reader = { try ExamPackageReader.read(contentsOf: $0, mode: .strict) }
    ) {
        self.store = store
        self.reader = reader
    }

    public func entry(_ examID: UUID) -> LibraryEntry? {
        store.entry(examID)
    }

    public func attempts(examID: UUID) -> [Attempt] {
        store.attempts(examID: examID)
    }

    public func saveAttempt(_ attempt: Attempt, payload: Data) throws {
        try store.addAttempt(attempt, payload: payload)
    }

    public func attemptPayload(id: UUID) throws -> Data? {
        try store.attemptPayload(id: id)
    }

    public func readExam(_ examID: UUID) async -> Result<ExamPackage, ExamLoadFailure> {
        guard let entry = store.entry(examID) else { return .failure(.notInLibrary) }
        let url = entry.fileURL
        let reader = reader
        return await withCheckedContinuation { continuation in
            Self.queue.async {
                continuation.resume(returning: Self.read(url, examID: examID, reader: reader))
            }
        }
    }

    public func examFileNeedsRefresh(_ examID: UUID) {
        let store = store
        Task { await store.refreshAll() }
    }

    nonisolated private static func read(
        _ url: URL,
        examID: UUID,
        reader: Reader
    ) -> Result<ExamPackage, ExamLoadFailure> {
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.fileMissing) }
        do {
            let package = try reader(url)
            guard package.exam.id == examID else { return .failure(.differentExam) }
            return .success(package)
        } catch let error as ExamFileError {
            return .failure(.unreadable(reason: ErrorMessages.message(for: error)))
        } catch {
            return .failure(unreadable(error))
        }
    }

    /// Lỗi đọc file ngoài `ExamFileError` (quyền, ổ đĩa…): câu tiếng Việt của app, không dùng
    /// `localizedDescription` của hệ thống (review #23, ghi chú e).
    nonisolated static func unreadable(_ error: any Error) -> ExamLoadFailure {
        switch (error as? CocoaError)?.code {
        case .fileReadNoSuchFile?, .fileNoSuchFile?:
            .fileMissing
        case .fileReadNoPermission?:
            .unreadable(reason: localized("Không có quyền đọc file đề."))
        default:
            .unreadable(reason: localized("Không đọc được file đề."))
        }
    }
}
