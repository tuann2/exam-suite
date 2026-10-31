import ExamFile
import ExamKit
import Foundation

/// Danh tính vật lý của file (thiết bị + inode theo `stat(2)`, đi qua symlink) để biết hai đường
/// dẫn có cùng là một file không.
struct FileIdentity: Hashable, Sendable {
    let device: Int64
    let inode: UInt64

    init?(url: URL) {
        var info = stat()
        let result = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return stat(path, &info)
        }
        guard result == 0 else { return nil }
        device = Int64(info.st_dev)
        inode = UInt64(info.st_ino)
    }
}

extension FileFacts {
    /// Dung lượng và ngày sửa đổi của file thường ở `url`; `nil` nếu ở đó không có file thường.
    static func of(_ url: URL) -> FileFacts? {
        // URL mới để không dùng giá trị thuộc tính đã cache trên URL cũ.
        let fresh = URL(fileURLWithPath: url.path)
        guard let values = try? fresh.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        ), values.isRegularFile == true else { return nil }
        return FileFacts(size: values.fileSize.map(Int64.init), modificationDate: values.contentModificationDate)
    }
}

/// File đề vừa đọc được (ít nhất ở chế độ dễ): đủ để thêm hoặc cập nhật một mục thư viện.
struct ReadableFile: Hashable, Sendable {
    /// Đường dẫn thật (đã giải symlink).
    let url: URL
    let examID: UUID
    let summary: ExamSummary
    /// `.ready` hoặc `.failsStrict`.
    let verdict: FileVerdict
    let bookmark: Data
    /// Lấy trước khi đọc: file đổi giữa chừng thì lần làm mới sau thấy khác và đọc lại.
    let facts: FileFacts
    let identity: FileIdentity?
}

/// Mọi việc chạm tới file đề của Thư viện: phân giải bookmark, kiểm file còn không, đọc bằng
/// `ExamPackageReader`, ghi đề mẫu. Không trạng thái, `Sendable`, đồng bộ (chặn luồng): `LibraryStore`
/// gọi trên hàng đợi `FileWork` rồi áp kết quả trên main actor.
struct ExamFileInspector: Sendable {
    typealias Reader = @Sendable (URL, ReadMode) throws -> ExamPackage

    static let defaultReader: Reader = { url, mode in
        try ExamPackageReader.read(contentsOf: url, mode: mode)
    }

    /// Đọc gói đề; test thay bằng bản đếm số lần đọc hoặc kiểm luồng.
    let reader: Reader

    init(reader: @escaping Reader = ExamFileInspector.defaultReader) {
        self.reader = reader
    }

    // MARK: - Đọc và phân loại

    struct Reading: Hashable, Sendable {
        let verdict: FileVerdict
        /// Có khi đọc được ít nhất ở chế độ dễ.
        let examID: UUID?
        let summary: ExamSummary?
    }

    /// Đọc nghiêm trước; được thì Sẵn sàng. Không được thì đọc dễ: được → "đọc dễ được, đọc nghiêm
    /// thất bại" (bản Học viên: Đề có lỗi; bản Admin: Có lỗi), lý do là lỗi của lần đọc nghiêm;
    /// không được → File hỏng hoặc Cần app mới hơn. Lỗi mà đọc dễ chắc chắn cũng gặp thì không đọc lại.
    func read(_ url: URL) -> Reading {
        let strictError: any Error
        do {
            let package = try reader(url, .strict)
            return Reading(verdict: .ready, examID: package.exam.id, summary: ExamSummary(package: package))
        } catch {
            strictError = error
        }
        guard Self.lenientMightSucceed(after: strictError) else {
            return Reading(verdict: Self.unreadableVerdict(strictError), examID: nil, summary: nil)
        }
        do {
            let package = try reader(url, .lenient)
            return Reading(
                verdict: .failsStrict(reason: FileProblemReason(strictError)),
                examID: package.exam.id,
                summary: ExamSummary(package: package)
            )
        } catch {
            return Reading(verdict: Self.unreadableVerdict(error), examID: nil, summary: nil)
        }
    }

    static func unreadableVerdict(_ error: any Error) -> FileVerdict {
        if case let .unsupportedVersion(found, supported)? = error as? ExamFileError {
            return .needsNewerApp(found: found, supported: supported)
        }
        return .corrupt(reason: FileProblemReason(error))
    }

    /// `false` với lỗi xảy ra trước mọi bước chỉ có ở chế độ nghiêm (zip hỏng, phiên bản, quá lớn…):
    /// đọc dễ sẽ gặp đúng lỗi đó. Thêm case mới vào `ExamFileError` thì switch này buộc phải xét lại.
    static func lenientMightSucceed(after error: any Error) -> Bool {
        guard let error = error as? ExamFileError else { return true }
        switch error {
        case .notAZipArchive, .missingManifest, .corruptedEntry, .unsupportedVersion, .invalidVersion,
             .duplicateEntry, .tooLarge, .tooDeep, .migrationFailed, .unsupportedImageType, .writeFailed:
            return false
        case .invalidJSON, .unknownFields, .duplicateJSONKeys, .nullValues, .missingMedia, .invalidMediaPath,
             .validationFailed:
            // invalidJSON: dấu phẩy thừa chỉ bị từ chối ở chế độ nghiêm.
            return true
        case let .oef(problem):
            switch problem {
            case .legacyFormat, .malformed, .noQuestions, .tooLarge:
                return false
            case .unknownFields, .passmarkOutOfRange, .unsupportedImage, .imageTooLarge, .tooManyOptions,
                 .duplicateOptionLetter, .answerNotInOptions:
                return true
            }
        }
    }

    // MARK: - Tìm file

    struct Located: Sendable {
        let url: URL
        /// Bookmark mới khi bookmark cũ đã cũ (file đổi tên/di chuyển) hoặc phải tìm bằng đường dẫn cũ.
        let refreshedBookmark: Data?
    }

    /// Phân giải bookmark (không hiện giao diện, không tự gắn ổ mạng/ổ ngoài); không được thì thử
    /// đường dẫn cũ. File trong Thùng rác coi như đã xoá. `nil`: không tìm thấy file. iOS: kiểm file trong lúc mở
    /// quyền security scope của URL vừa phân giải (`SecurityScopedAccess`).
    static func locate(_ location: StoredLocation) -> Located? {
        var stale = false
        if let url = try? URL(
            resolvingBookmarkData: location.bookmark,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ), !isInTrash(url), SecurityScopedAccess.with(url, { FileFacts.of(url) }) != nil {
            return Located(
                url: url,
                refreshedBookmark: stale ? SecurityScopedAccess.with(url, { makeBookmark(url) }) : nil
            )
        }
        let fallback = location.url
        guard !isInTrash(fallback), FileFacts.of(fallback) != nil else { return nil }
        return Located(url: fallback, refreshedBookmark: makeBookmark(fallback))
    }

    /// Bookmark thường (macOS: không security scope, app không sandbox ở v1; nếu bật sandbox phải đổi sang
    /// `.withSecurityScope`). iOS: tạo trong lúc mở quyền security scope thì bookmark mang theo quyền đó.
    static func makeBookmark(_ url: URL) -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// `~/.Trash` hoặc `.Trashes` trên ổ khác: file người dùng đã xoá trong Finder.
    static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }

    /// Đường dẫn thật (`realpath`): giải mọi symlink, kể cả `/var` → `/private/var`, để khớp với
    /// đường dẫn bookmark trả về. File không tồn tại thì giữ nguyên dạng chuẩn hoá.
    static func canonical(_ url: URL) -> URL {
        let resolved = url.withUnsafeFileSystemRepresentation { path -> String? in
            guard let path, let real = realpath(path, nil) else { return nil }
            defer { free(real) }
            return String(cString: real)
        }
        guard let resolved else { return url.standardizedFileURL }
        return URL(fileURLWithPath: resolved, isDirectory: false)
    }

    // MARK: - Làm mới

    struct RefreshJob: Sendable {
        let examID: UUID
        /// Số lần mục bị đổi ở main actor lúc lấy việc; kết quả chỉ áp nếu mục chưa đổi thêm.
        let revision: Int
        let location: StoredLocation
        let knownFacts: FileFacts?
        /// Kết luận đã lưu với đúng dấu bộ kiểm hiện tại; `nil` thì buộc đọc lại.
        let cachedVerdict: FileVerdict?
    }

    enum RefreshOutcome: Sendable {
        case missing
        /// `reading == nil`: file không đổi so với lần đọc trước, dùng lại kết luận đã lưu.
        case found(url: URL, refreshedBookmark: Data?, facts: FileFacts, reading: Reading?)
    }

    func refresh(_ job: RefreshJob) -> RefreshOutcome {
        guard let located = Self.locate(job.location) else { return .missing }
        return SecurityScopedAccess.with(located.url) { refresh(job, at: located) }
    }

    private func refresh(_ job: RefreshJob, at located: Located) -> RefreshOutcome {
        guard let facts = FileFacts.of(located.url) else { return .missing }
        if job.cachedVerdict != nil, facts == job.knownFacts {
            return .found(url: located.url, refreshedBookmark: located.refreshedBookmark, facts: facts, reading: nil)
        }
        let reading = read(located.url)
        // File biến mất trong lúc đọc: không tìm thấy, không phải file hỏng.
        if reading.examID == nil, FileFacts.of(located.url) == nil { return .missing }
        return .found(url: located.url, refreshedBookmark: located.refreshedBookmark, facts: facts, reading: reading)
    }

    // MARK: - Nhập file

    enum Inspection: Hashable, Sendable {
        /// Không phải file `.exam` (đuôi khác, thư mục).
        case notExam
        /// Không dùng được. `unreadable`: file có thật nhưng không đọc được (kể cả chế độ dễ), đủ để cập
        /// nhật trạng thái của mục đang trỏ tới đúng file đó.
        case problem(LibraryFileProblem, unreadable: UnreadableFile?)
        case readable(ReadableFile)
    }

    /// File có thật nhưng không đọc được kể cả ở chế độ dễ.
    struct UnreadableFile: Hashable, Sendable {
        /// Đường dẫn thật (đã giải symlink).
        let url: URL
        let facts: FileFacts
        /// `.corrupt` hoặc `.needsNewerApp`.
        let verdict: FileVerdict
    }

    /// Đọc một file người dùng chọn hoặc kéo vào. Chưa quyết định thêm hay không: bản Học viên từ
    /// chối `.failsStrict`, việc đó do `LibraryStore` quyết theo chế độ của bản app.
    func inspectNewFile(_ url: URL) -> Inspection {
        guard url.isFileURL, url.pathExtension.lowercased() == ExamFileFormat.fileExtension else { return .notExam }
        // iOS: URL của hộp chọn file mang quyền security scope; mở quyền cho cả lần đọc và lúc tạo bookmark.
        return SecurityScopedAccess.with(url) { inspectAccessibleFile(url) }
    }

    private func inspectAccessibleFile(_ url: URL) -> Inspection {
        let file = Self.canonical(url)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory) else {
            return .problem(.corrupt(reason: .fileNotFound(fileName: url.lastPathComponent)), unreadable: nil)
        }
        guard !isDirectory.boolValue else { return .notExam }
        if Self.isInTrash(file) {
            // Cùng quy tắc với làm mới: file trong Thùng rác coi như đã xoá.
            return .problem(.corrupt(reason: .inTrash(fileName: url.lastPathComponent)), unreadable: nil)
        }
        guard let facts = FileFacts.of(file) else { return .notExam }
        let reading = read(file)
        guard let examID = reading.examID, let summary = reading.summary else {
            let unreadable = UnreadableFile(url: file, facts: facts, verdict: reading.verdict)
            if case let .needsNewerApp(found, supported) = reading.verdict {
                return .problem(.needsNewerApp(found: found, supported: supported), unreadable: unreadable)
            }
            let reason = reading.verdict.reason ?? .package(.notAZipArchive)
            return .problem(.corrupt(reason: reason), unreadable: unreadable)
        }
        guard let bookmark = Self.makeBookmark(file) else {
            return .problem(.corrupt(reason: .bookmarkFailed(fileName: url.lastPathComponent)), unreadable: nil)
        }
        return .readable(ReadableFile(
            url: file,
            examID: examID,
            summary: summary,
            verdict: reading.verdict,
            bookmark: bookmark,
            facts: facts,
            identity: FileIdentity(url: file)
        ))
    }

    struct ImportProbe: Sendable {
        let inspection: Inspection
        /// File vừa đọc chính là file của mục đã có cùng id đề, theo ảnh chụp vị trí lúc bắt đầu nhập.
        let matchesExistingFile: Bool
    }

    func probeImport(_ url: URL, existing: [UUID: StoredLocation]) -> ImportProbe {
        let inspection = inspectNewFile(url)
        guard case let .readable(file) = inspection, let location = existing[file.examID],
              let identity = file.identity
        else {
            return ImportProbe(inspection: inspection, matchesExistingFile: false)
        }
        let existingIdentity = Self.locate(location).flatMap { FileIdentity(url: $0.url) }
        return ImportProbe(inspection: inspection, matchesExistingFile: existingIdentity == identity)
    }

    // MARK: - Đề mẫu

    struct SampleRequest: Sendable {
        let sourceRoot: URL
        let destinationDirectory: URL
        /// Vị trí file của các mục đang có, theo id đề.
        let existing: [UUID: StoredLocation]
        /// Khôi phục: ghi lại file cho đề mẫu đã có mục nhưng mất file.
        let rewriteMissingFiles: Bool
    }

    enum SampleOutcome: Sendable {
        case alreadyInLibrary(examID: UUID)
        case written(ReadableFile, replacesExistingEntry: Bool)
        case failed(sampleName: String, reason: FileProblemReason)
    }

    /// Với mỗi thư mục đề mẫu trong nguồn (theo tên): dựng `ExamPackage` từ `exam.json` + `media/`,
    /// ghi bằng `ExamPackageWriter` ra `<tiêu đề>.exam` trong thư mục đích, rồi đọc lại như file nhập.
    /// Đề đã có trong thư viện thì bỏ qua (trừ khi khôi phục và mục đó mất file).
    func installSamples(_ request: SampleRequest) -> [SampleOutcome] {
        var usedNames = Set<String>()
        return SampleSource.sampleDirectories(in: request.sourceRoot).map { directory in
            let sampleName = directory.lastPathComponent
            let package: ExamPackage
            do {
                package = try SampleSource.loadPackage(from: directory)
            } catch {
                return .failed(sampleName: sampleName, reason: .sampleUnreadable("\(error)"))
            }
            // Giữ tên file cho mọi đề mẫu, kể cả đề được bỏ qua, để tên không đổi giữa các lần.
            let fileName = SampleSource.uniqueFileName(forTitle: package.exam.title, used: &usedNames)
            var replacesExistingEntry = false
            if let location = request.existing[package.exam.id] {
                guard request.rewriteMissingFiles, Self.locate(location) == nil else {
                    return .alreadyInLibrary(examID: package.exam.id)
                }
                replacesExistingEntry = true
            }
            let destination = request.destinationDirectory.appendingPathComponent(fileName, isDirectory: false)
            do {
                try FileManager.default.createDirectory(
                    at: request.destinationDirectory,
                    withIntermediateDirectories: true
                )
                try ExamPackageWriter.write(package, to: destination)
            } catch {
                return .failed(sampleName: sampleName, reason: FileProblemReason(error))
            }
            switch inspectNewFile(destination) {
            case let .readable(file):
                return .written(file, replacesExistingEntry: replacesExistingEntry)
            case let .problem(problem, _):
                return .failed(sampleName: sampleName, reason: problem.reason)
            case .notExam:
                return .failed(sampleName: sampleName, reason: .sampleNotWritten(fileName: fileName))
            }
        }
    }
}

extension FileVerdict {
    var reason: FileProblemReason? {
        switch self {
        case .ready: nil
        case let .failsStrict(reason), let .corrupt(reason): reason
        case let .needsNewerApp(found, supported): .package(.unsupportedVersion(found: found, supported: supported))
        }
    }
}

extension LibraryFileProblem {
    /// Lý do dạng mã (cần app mới hơn là lỗi phiên bản của ExamFile).
    var reason: FileProblemReason {
        switch self {
        case let .corrupt(reason), let .invalid(reason): reason
        case let .needsNewerApp(found, supported): .package(.unsupportedVersion(found: found, supported: supported))
        }
    }
}
