import ExamKit
import Foundation
import SwiftData

/// Schema v1 của kho Thư viện (docs/product/library.md, mục Lưu trữ). Model chỉ dùng bên trong
/// LibraryData; giao diện nhận `LibraryEntry`/`Attempt` dạng giá trị.
///
/// **Không bao giờ sửa V1** (kể cả đổi tên, đổi kiểu, thêm hay bỏ thuộc tính) sau khi đã phát hành: kho
/// của người dùng tạo bằng V1 khi đó không mở được nữa (bị dời sang `Library.store.broken-…`, mất thư viện
/// và lịch sử thi), hoặc tệ hơn được CoreData chuyển đổi âm thầm và mất dữ liệu của thuộc tính tuỳ chọn bị
/// đổi tên. `LibraryV1FixtureTests` canh việc này bằng một kho V1 thật
/// (`Tests/LibraryDataTests/Fixtures/Library-v1.store`):
/// - so hash phiên bản model (`NSStoreModelVersionHashes`) của kho đó với kho vừa tạo bằng V1 hiện tại: đỏ với
///   mọi thay đổi model, kể cả thêm thuộc tính tuỳ chọn mà CoreData tự chuyển đổi được;
/// - mở kho đó và so đủ dữ liệu: đỏ khi kho bị dời đi hoặc mất dữ liệu (đổi tên, đổi kiểu, bỏ thuộc tính).
///
/// Đổi schema: thêm `LibrarySchemaV2` (chép model sang, sửa ở đó), thêm một `MigrationStage` v1 → v2 vào
/// `LibraryMigrationPlan`, thêm fixture `Library-v2.store` bằng generator mới, giữ nguyên fixture V1 và test
/// mở nó (giờ là test chuyển đổi v1 → v2). Cách tạo lại fixture V1 (chỉ khi V1 còn là schema mới nhất):
/// `Tests/LibraryDataTests/Fixtures/README.md`.
enum LibrarySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LibraryItem.self, AttemptItem.self]
    }

    /// Một mục thư viện. Mỗi id đề một mục: `LibraryStore` kiểm trước khi thêm; `.unique` là lưới
    /// an toàn ở tầng kho (dùng `@Attribute(.unique)` có từ macOS 14 cho một thuộc tính, thay vì
    /// `#Unique` mới có từ macOS 15).
    @Model
    final class LibraryItem {
        @Attribute(.unique) var examID: UUID
        /// Bookmark tới file (không security scope: app không sandbox ở v1).
        var bookmark: Data
        var lastKnownPath: String

        // Thông tin thẻ, để hiện ngay khi mở app.
        var title: String
        var code: String?
        var questionCount: Int
        var sectionCount: Int
        var imageCount: Int
        var timeLimitMinutes: Int
        var passPercent: Int
        var hideAnswers: Bool
        var formatVersion: Int

        // File ở lần đọc trước: khác thì đọc lại.
        var fileSize: Int64?
        var fileModificationDate: Date?

        var isSample: Bool
        var addedAt: Date
        var lastOpenedAt: Date?

        // Kết luận lần kiểm gần nhất (`FileVerdict`), tách thành trường đơn giản thay vì enum
        // có giá trị kèm theo để tránh lỗi lưu enum của SwiftData.
        /// `ready`, `failsStrict`, `corrupt`, `needsNewerApp`; `nil` nếu chưa kiểm.
        var verdictKind: String?
        var verdictReason: String?
        var verdictFoundVersion: Int?
        var verdictSupportedVersion: Int?
        var checkFingerprint: String?
        var checkedAt: Date?

        init(record: LibraryRecord) {
            examID = record.examID
            bookmark = record.location.bookmark
            lastKnownPath = record.location.path
            title = record.summary.title
            code = record.summary.code
            questionCount = record.summary.questionCount
            sectionCount = record.summary.sectionCount
            imageCount = record.summary.imageCount
            timeLimitMinutes = record.summary.timeLimitMinutes
            passPercent = record.summary.passPercent
            hideAnswers = record.summary.hideAnswers
            formatVersion = record.summary.formatVersion
            fileSize = record.facts?.size
            fileModificationDate = record.facts?.modificationDate
            isSample = record.isSample
            addedAt = record.addedAt
            lastOpenedAt = record.lastOpenedAt
            checkFingerprint = record.checkFingerprint
            checkedAt = record.checkedAt
            let verdict = Self.encode(record.verdict)
            verdictKind = verdict.kind
            verdictReason = verdict.reason
            verdictFoundVersion = verdict.found
            verdictSupportedVersion = verdict.supported
        }

        func update(from record: LibraryRecord) {
            bookmark = record.location.bookmark
            lastKnownPath = record.location.path
            title = record.summary.title
            code = record.summary.code
            questionCount = record.summary.questionCount
            sectionCount = record.summary.sectionCount
            imageCount = record.summary.imageCount
            timeLimitMinutes = record.summary.timeLimitMinutes
            passPercent = record.summary.passPercent
            hideAnswers = record.summary.hideAnswers
            formatVersion = record.summary.formatVersion
            fileSize = record.facts?.size
            fileModificationDate = record.facts?.modificationDate
            isSample = record.isSample
            addedAt = record.addedAt
            lastOpenedAt = record.lastOpenedAt
            checkFingerprint = record.checkFingerprint
            checkedAt = record.checkedAt
            let verdict = Self.encode(record.verdict)
            verdictKind = verdict.kind
            verdictReason = verdict.reason
            verdictFoundVersion = verdict.found
            verdictSupportedVersion = verdict.supported
        }

        var record: LibraryRecord {
            LibraryRecord(
                examID: examID,
                location: StoredLocation(bookmark: bookmark, path: lastKnownPath),
                summary: ExamSummary(
                    title: title,
                    code: code,
                    questionCount: questionCount,
                    sectionCount: sectionCount,
                    imageCount: imageCount,
                    timeLimitMinutes: timeLimitMinutes,
                    passPercent: passPercent,
                    hideAnswers: hideAnswers,
                    formatVersion: formatVersion
                ),
                facts: fileSize == nil && fileModificationDate == nil
                    ? nil
                    : FileFacts(size: fileSize, modificationDate: fileModificationDate),
                isSample: isSample,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                verdict: verdict,
                checkFingerprint: checkFingerprint,
                checkedAt: checkedAt
            )
        }

        private var verdict: FileVerdict? {
            switch verdictKind {
            case "ready":
                return .ready
            case "failsStrict":
                return .failsStrict(reason: .stored(verdictReason ?? ""))
            case "corrupt":
                return .corrupt(reason: .stored(verdictReason ?? ""))
            case "needsNewerApp":
                guard let found = verdictFoundVersion, let supported = verdictSupportedVersion else { return nil }
                return .needsNewerApp(found: found, supported: supported)
            default:
                // Chưa kiểm, hoặc giá trị lạ: coi như chưa kiểm, lần làm mới sau đọc lại file.
                return nil
            }
        }

        private static func encode(
            _ verdict: FileVerdict?
        ) -> (kind: String?, reason: String?, found: Int?, supported: Int?) {
            switch verdict {
            case nil: (nil, nil, nil, nil)
            case .ready: ("ready", nil, nil, nil)
            // Lý do lưu thành chữ tiếng Việt như trước bước 7b (bản app cũ đọc kho này vẫn thấy đúng chữ); đọc lại
            // thành `.stored` (xem `FileVerdict.isReusable`).
            case let .failsStrict(reason): ("failsStrict", reason.logMessage, nil, nil)
            case let .corrupt(reason): ("corrupt", reason.logMessage, nil, nil)
            case let .needsNewerApp(found, supported): ("needsNewerApp", nil, found, supported)
            }
        }
    }

    /// Một lần thi: các trường tóm tắt để liệt kê và sắp xếp, cộng `payload` do giai đoạn 3 quyết định.
    @Model
    final class AttemptItem {
        @Attribute(.unique) var attemptID: UUID
        var examID: UUID
        var examTitle: String
        var candidateName: String
        /// `SessionMode.rawValue`: `practice` hoặc `exam`.
        var mode: String
        var startedAt: Date
        var submittedAt: Date
        var elapsedSeconds: Double
        var correct: Int
        var total: Int
        var score1000: Int
        var percent: Int
        var passed: Bool
        var payload: Data

        init(attempt: Attempt, payload: Data) {
            attemptID = attempt.id
            examID = attempt.examID
            examTitle = attempt.examTitle
            candidateName = attempt.candidateName
            mode = attempt.mode.rawValue
            startedAt = attempt.startedAt
            submittedAt = attempt.submittedAt
            elapsedSeconds = attempt.elapsedSeconds
            correct = attempt.correct
            total = attempt.total
            score1000 = attempt.score1000
            percent = attempt.percent
            passed = attempt.passed
            self.payload = payload
        }

        var attempt: Attempt {
            Attempt(
                id: attemptID,
                examID: examID,
                examTitle: examTitle,
                candidateName: candidateName,
                // Chế độ lạ (chỉ có thể do bản app mới hơn ghi) hiện như Thi.
                mode: SessionMode(rawValue: mode) ?? .exam,
                startedAt: startedAt,
                submittedAt: submittedAt,
                elapsedSeconds: elapsedSeconds,
                correct: correct,
                total: total,
                score1000: score1000,
                percent: percent,
                passed: passed
            )
        }
    }
}

typealias LibraryItem = LibrarySchemaV1.LibraryItem
typealias AttemptItem = LibrarySchemaV1.AttemptItem

/// Kế hoạch chuyển đổi kho. v1 là phiên bản đầu nên chưa có bước nào.
enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LibrarySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
