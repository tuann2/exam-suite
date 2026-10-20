import ExamFile
import ExamKit
import Foundation

/// Ảnh của câu (docs/product/authoring.md, mục Ảnh; exam-format.md, mục Gói).
extension ExamDraft {
    /// Thêm hoặc thay ảnh của câu bằng byte gốc của file ảnh (không chuyển định dạng, không nén lại).
    ///
    /// - Ảnh trùng byte với một ảnh đã có trong gói dùng lại đúng đường dẫn đó (lưu một lần,
    ///   **không đổi tên ảnh đã có**, kể cả ảnh của file cũ đặt tên theo quy tắc khác).
    /// - Ảnh mới: tên `media/<16 hex đầu SHA-256>.<đuôi chữ thường>` (`MediaNaming`, như `ExamPackageWriter`).
    /// - Từ chối đuôi ngoài png, jpg, jpeg, gif, webp, heic; ảnh vượt `limits.mediaEntryBytes`; ảnh
    ///   làm gói vượt tổng dung lượng (tính cả `exam.json`) hoặc số entry mà bộ đọc chấp nhận (để file
    ///   lưu ra mở lại được với cùng `limits`). Lỗi thì đề không đổi.
    /// - Câu đang dùng đúng byte ảnh này: không đổi gì, thay đổi ngược là `.none`.
    /// - Ảnh cũ của câu (nếu có) vẫn giữ trong `package.media` cho Hoàn tác; không câu nào dùng thì
    ///   bị bỏ khi lưu.
    ///
    /// - Parameter fileExtension: đuôi của file nguồn, không có dấu chấm (`"PNG"`, `"jpeg"`…).
    /// - Returns: đường dẫn ảnh trong gói và thay đổi ngược.
    @discardableResult
    public mutating func setImage(
        of address: some QuestionAddress, data: Data, fileExtension: String, limits: ExamPackageLimits = .default
    ) throws(ExamEditError) -> (path: String, inverse: ExamEdit) {
        let questionPath = try address.resolve(in: exam)
        let ext = fileExtension.lowercased()
        guard MediaNaming.allowedExtensions.contains(ext) else { throw .unsupportedImageType(fileExtension) }
        guard data.count <= limits.mediaEntryBytes else {
            throw .imageTooLarge(bytes: data.count, limit: limits.mediaEntryBytes)
        }

        // Câu đang dùng đúng ảnh này: không đổi gì, không tạo bước Hoàn tác.
        if let current = exam.sections[questionPath.section].questions[questionPath.question].image,
           package.media[current] == data {
            return (current, .none)
        }

        let imagePath: String
        if let existing = existingMediaPath(for: data, preferredExtension: ext) {
            imagePath = existing
        } else {
            let candidate: String
            do {
                candidate = try MediaNaming.path(for: data, fileExtension: ext)
            } catch {
                throw .unsupportedImageType(fileExtension)
            }
            if package.media[candidate] != nil { throw .mediaNameCollision(candidate) }
            imagePath = candidate
        }

        // Giới hạn của gói sau khi đổi ảnh, tính trên ảnh sẽ được ghi (ảnh câu nào đó còn dùng).
        var question = exam.sections[questionPath.section].questions[questionPath.question]
        question.image = imagePath
        var after = package.exam
        after.sections[questionPath.section].questions[questionPath.question] = question
        let referenced = Set(after.allQuestions.compactMap(\.image)).filter {
            $0 == imagePath || package.media[$0] != nil
        }
        // exam.json + mỗi ảnh một entry.
        if referenced.count + 1 > limits.entryCount { throw .tooManyImages(limit: limits.entryCount) }
        // Tổng giải nén như bộ đọc tính: exam.json (đúng như ExamPackageWriter mã hoá) + mọi ảnh được ghi.
        var manifestExam = after
        manifestExam.formatVersion = ExamFileFormat.currentVersion
        let manifestSize = (try? ExamJSON.encode(manifestExam).count) ?? 0
        let total = referenced.reduce(manifestSize) { $0 + ($1 == imagePath ? data.count : package.media[$1]?.count ?? 0) }
        if total > limits.totalUncompressedBytes { throw .packageTooLarge(limit: limits.totalUncompressedBytes) }

        let inverse = try apply(.group([
            .insertMedia(path: imagePath, data: data),
            .replaceQuestion(question, at: questionPath),
        ]))
        return (imagePath, inverse)
    }

    /// Bỏ ảnh khỏi câu. Byte ảnh vẫn giữ cho Hoàn tác; không câu nào dùng thì bị bỏ khi lưu.
    @discardableResult
    public mutating func removeImage(of question: some QuestionAddress) throws(ExamEditError) -> ExamEdit {
        try updateQuestion(question) { $0.image = nil }
    }

    /// Đường dẫn của ảnh đã có trong gói trùng byte với `data`; ưu tiên tên đúng mẫu của `MediaNaming`
    /// với đuôi `preferredExtension`, rồi tên đúng mẫu theo thứ tự chữ cái (ổn định giữa các lần gọi).
    private func existingMediaPath(for data: Data, preferredExtension ext: String) -> String? {
        if let canonical = try? MediaNaming.path(for: data, fileExtension: ext), package.media[canonical] == data {
            return canonical
        }
        return package.media
            .filter { MediaNaming.isValidPath($0.key) && $0.value.count == data.count && $0.value == data }
            .keys.min()
    }

    // MARK: - Lưu

    /// Gói để ghi ra file: đề hiện tại và chỉ những ảnh còn câu dùng (ảnh thừa bị bỏ). Tham chiếu ảnh
    /// thiếu (đề đọc dễ) giữ nguyên, không chặn lưu (exam-format.md).
    public var packageForSaving: ExamPackage {
        let referenced = Set(exam.allQuestions.compactMap(\.image))
        return ExamPackage(exam: exam, media: package.media.filter { referenced.contains($0.key) })
    }

    /// Byte của file `.exam` (ghi bằng `ExamPackageWriter`).
    public func fileData() throws -> Data {
        try ExamPackageWriter.write(packageForSaving)
    }
}
