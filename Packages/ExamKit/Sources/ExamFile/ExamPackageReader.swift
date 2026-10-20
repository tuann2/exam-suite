import ExamKit
import Foundation
import ZIPFoundation

/// Đọc gói `.exam` (docs/product/exam-format.md). Thứ tự kiểm:
/// zip hợp lệ → có `exam.json` ở gốc → độ sâu lồng ≤ `maxJSONDepth` → JSON parse được → `formatVersion`
/// (mới hơn app hoặc < 1 thì dừng ngay) → chuyển phiên bản nếu cũ hơn →
/// (chỉ `strict`) dấu phẩy thừa, khoá trùng, trường lạ, `null` → giải mã model → (chỉ `strict`) mọi `image` đúng mẫu
/// tên và có trong `media/` → (chỉ `strict`) `ExamValidator` không báo lỗi mức `error`.
/// Mọi lần giải nén bị giới hạn bởi `ExamPackageLimits`.
///
/// Đọc `lenient` (bản Admin) không từ chối gói thiếu ảnh hay vi phạm ràng buộc liên trường
/// (id trùng, đáp án ngoài options…): bản Admin báo lỗi nhưng không chặn lưu
/// (docs/product/exam-format.md); xem `ExamPackage.missingMedia` và `ExamPackage.validationIssues`.
public enum ExamPackageReader {
    public static func read(
        _ data: Data,
        mode: ReadMode,
        limits: ExamPackageLimits = .default
    ) throws -> ExamPackage {
        try read(
            data,
            mode: mode,
            limits: limits,
            currentVersion: ExamFileFormat.currentVersion,
            migrations: FormatMigrator.registered
        )
    }

    public static func read(
        contentsOf url: URL,
        mode: ReadMode,
        limits: ExamPackageLimits = .default
    ) throws -> ExamPackage {
        try read(
            contentsOf: url,
            mode: mode,
            limits: limits,
            currentVersion: ExamFileFormat.currentVersion,
            migrations: FormatMigrator.registered
        )
    }

    /// Bản đầy đủ tham số, để test khung chuyển phiên bản với phiên bản và bộ chuyển đổi giả.
    /// Dữ liệu được đọc qua file tạm (xem `SafeArchive`).
    static func read(
        _ data: Data,
        mode: ReadMode,
        limits: ExamPackageLimits = .default,
        currentVersion: Int,
        migrations: [FormatMigration]
    ) throws -> ExamPackage {
        try SafeArchive.withTemporaryFile(data) { url in
            try read(contentsOf: url, mode: mode, limits: limits, currentVersion: currentVersion,
                     migrations: migrations)
        }
    }

    static func read(
        contentsOf url: URL,
        mode: ReadMode,
        limits: ExamPackageLimits = .default,
        currentVersion: Int,
        migrations: [FormatMigration]
    ) throws -> ExamPackage {
        guard let archive = try SafeArchive.open(url) else { throw ExamFileError.notAZipArchive }

        // Chỉ lấy entry kiểu file: exam.json ở gốc và ảnh có tên đúng mẫu trong media/.
        // Entry khác (thư mục, symlink, file lạ như __MACOSX/…, media/a/b.png) bị bỏ qua.
        var manifestEntry: Entry?
        var mediaEntries: [Entry] = []
        var mediaNames = Set<String>()
        var entryCount = 0
        for entry in archive {
            entryCount += 1
            if entryCount > limits.entryCount {
                throw ExamFileError.tooLarge(entry: ExamPackageLimits.entryCountName, limit: limits.entryCount)
            }
            guard entry.type == .file else { continue }
            if entry.path == ExamFileFormat.manifestName {
                if manifestEntry != nil { throw ExamFileError.duplicateEntry(entry.path) }
                manifestEntry = entry
            } else if MediaNaming.isValidPath(entry.path) {
                if !mediaNames.insert(entry.path).inserted { throw ExamFileError.duplicateEntry(entry.path) }
                mediaEntries.append(entry)
            }
        }
        guard let manifestEntry else { throw ExamFileError.missingManifest }

        var budget = ExtractionBudget(limits: limits)
        let manifest = try extract(manifestEntry, from: archive, entryLimit: limits.manifestBytes, budget: &budget)
        // Trước mọi bước phân tích (cả hai chế độ): JSONSerialization, JSONDecoder và các
        // bước duyệt đều đệ quy theo độ sâu; JSON lồng sâu làm tràn stack.
        if StrictJSON.depthExceeds(manifest, limit: limits.maxJSONDepth) {
            throw ExamFileError.tooDeep(limit: limits.maxJSONDepth)
        }
        let json = try parseObject(manifest)

        let version = try formatVersion(of: manifest)
        if version > currentVersion {
            throw ExamFileError.unsupportedVersion(found: version, supported: currentVersion)
        }
        if version < 1 { throw ExamFileError.invalidVersion(version) }

        var examJSON = json
        var examData = manifest
        if version < currentVersion {
            examJSON = try FormatMigrator.migrate(json, from: version, to: currentVersion, using: migrations)
            do {
                examData = try JSONSerialization.data(withJSONObject: examJSON)
            } catch {
                throw ExamFileError.migrationFailed(from: version, reason: .invalidResult)
            }
        }

        // Bản Học viên từ chối những gì schema cấm mà model bỏ qua; bản Admin đọc như cũ
        // (khoá trùng: Foundation giữ một giá trị; null ở trường tuỳ chọn: coi như vắng mặt).
        if mode == .strict {
            // Quét trên file gốc: JSON sau chuyển phiên bản đã bị gộp khoá trùng.
            let scan = StrictJSON.scan(manifest)
            if !scan.trailingCommas.isEmpty {
                throw ExamFileError.invalidJSON(.trailingCommas(scan.trailingCommas))
            }
            if !scan.duplicateKeys.isEmpty { throw ExamFileError.duplicateJSONKeys(scan.duplicateKeys) }
            let unknown = ExamSchemaKeys.unknownFieldPaths(in: examJSON)
            if !unknown.isEmpty { throw ExamFileError.unknownFields(unknown) }
            let nulls = StrictJSON.nullValuePaths(in: examJSON)
            if !nulls.isEmpty { throw ExamFileError.nullValues(nulls) }
        }

        let exam: Exam
        do {
            exam = try ExamJSON.decode(examData)
        } catch let error as DecodingError {
            throw ExamFileError.invalidJSON(describe(error))
        } catch {
            throw ExamFileError.invalidJSON(.other(String(describing: error)))
        }

        var media: [String: Data] = [:]
        for entry in mediaEntries {
            media[entry.path] = try extract(entry, from: archive, entryLimit: limits.mediaEntryBytes, budget: &budget)
        }
        let package = ExamPackage(exam: exam, media: media)

        // Bản Học viên từ chối đề có ảnh sai đường dẫn hoặc thiếu ảnh; bản Admin mở được
        // và đọc `package.missingMedia` để báo lỗi (docs/product/exam-format.md).
        if mode == .strict {
            var seen = Set<String>()
            let invalid = exam.allQuestions.compactMap(\.image)
                .filter { !MediaNaming.isValidPath($0) && seen.insert($0).inserted }
            if !invalid.isEmpty { throw ExamFileError.invalidMediaPath(invalid) }
            let missing = package.missingMedia
            if !missing.isEmpty { throw ExamFileError.missingMedia(missing) }

            // Ảnh đã qua hai kiểm trên nên validator không báo lại lỗi ảnh.
            let errors = package.validationIssues.filter { $0.severity == .error }
            if !errors.isEmpty { throw ExamFileError.validationFailed(errors) }
        }
        return package
    }

    // MARK: - Các bước

    /// Đếm tổng số byte đã giải nén để so với `ExamPackageLimits.totalUncompressedBytes`.
    private struct ExtractionBudget {
        let limits: ExamPackageLimits
        var used = 0
    }

    /// Giải nén một entry, có trần: kích thước khai báo vượt `entryLimit` hoặc làm tổng
    /// vượt trần → `tooLarge` trước khi giải nén; dữ liệu thật dài hơn khai báo (zip bomb
    /// nói dối kích thước) → dừng ngay trong consumer, báo `corruptedEntry`.
    private static func extract(
        _ entry: Entry,
        from archive: Archive,
        entryLimit: Int,
        budget: inout ExtractionBudget
    ) throws -> Data {
        let declared = entry.uncompressedSize
        guard declared <= UInt64(entryLimit) else {
            throw ExamFileError.tooLarge(entry: entry.path, limit: entryLimit)
        }
        let total = budget.limits.totalUncompressedBytes
        guard UInt64(budget.used) + declared <= UInt64(total) else {
            throw ExamFileError.tooLarge(entry: ExamPackageLimits.totalSizeName, limit: total)
        }
        let expected = Int(declared)
        var out = Data()
        let checksum: CRC32
        do {
            checksum = try archive.extract(entry, skipCRC32: false) { chunk in
                guard out.count + chunk.count <= expected else {
                    throw ExamFileError.corruptedEntry(entry.path)
                }
                out.append(chunk)
            }
        } catch {
            throw ExamFileError.corruptedEntry(entry.path)
        }
        // `extract(_:consumer:)` chỉ trả CRC tính được, không tự so với CRC ghi trong zip.
        guard checksum == entry.checksum, out.count == expected else {
            throw ExamFileError.corruptedEntry(entry.path)
        }
        budget.used += out.count
        return out
    }

    private static func parseObject(_ data: Data) throws -> [String: Any] {
        guard String(data: data, encoding: .utf8) != nil else {
            throw ExamFileError.invalidJSON(.notUTF8)
        }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ExamFileError.invalidJSON(.unparsable(systemDescription: error.localizedDescription))
        }
        guard let dictionary = object as? [String: Any] else {
            throw ExamFileError.invalidJSON(.rootNotObject)
        }
        return dictionary
    }

    /// Chỉ giải mã `formatVersion` để kiểm phiên bản trước mọi thứ khác,
    /// kể cả khi phần còn lại của file sai cấu trúc.
    private static func formatVersion(of data: Data) throws -> Int {
        struct VersionProbe: Decodable { let formatVersion: Int }
        do {
            return try JSONDecoder().decode(VersionProbe.self, from: data).formatVersion
        } catch DecodingError.keyNotFound {
            throw ExamFileError.invalidJSON(.missingFormatVersion)
        } catch {
            throw ExamFileError.invalidJSON(.formatVersionNotInteger)
        }
    }

    /// Lỗi giải mã kèm đường dẫn dạng `sections[0].questions[2].type` (`message` là câu tiếng Việt như trước).
    static func describe(_ error: DecodingError) -> JSONProblem {
        func path(_ codingPath: [CodingKey]) -> String {
            var out = ""
            for key in codingPath {
                if let index = key.intValue {
                    out += "[\(index)]"
                } else {
                    out += out.isEmpty ? key.stringValue : ".\(key.stringValue)"
                }
            }
            return out.isEmpty ? JSONProblem.rootPath : out
        }
        switch error {
        case let .keyNotFound(key, context):
            return .missingKey(path: path(context.codingPath), key: key.stringValue)
        case let .typeMismatch(type, context):
            return .typeMismatch(path: path(context.codingPath), expectedType: "\(type)")
        case let .valueNotFound(type, context):
            return .valueMissing(path: path(context.codingPath), expectedType: "\(type)")
        case let .dataCorrupted(context):
            return .invalidValue(path: path(context.codingPath), detail: context.debugDescription)
        @unknown default:
            return .other(String(describing: error))
        }
    }
}
