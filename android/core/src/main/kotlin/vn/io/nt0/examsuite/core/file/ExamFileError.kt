package vn.io.nt0.examsuite.core.file

import vn.io.nt0.examsuite.core.validation.ValidationIssue

/** Vì sao `exam.json` không hợp lệ (cùng các case của `JSONProblem` bản macOS). Giao diện dựng câu từ case và tham số. */
sealed interface JsonProblem {
    data object NotUtf8 : JsonProblem

    /** Không phân tích được; `detail` là mô tả kỹ thuật, chỉ cho nhật ký. */
    data class Unparsable(val detail: String) : JsonProblem

    data object RootNotObject : JsonProblem

    data object MissingFormatVersion : JsonProblem

    data object FormatVersionNotInteger : JsonProblem

    /** Chỉ chế độ nghiêm: dấu phẩy thừa trước `}`/`]`; đường dẫn object/mảng, gốc là `<gốc>`. */
    data class TrailingCommas(val paths: List<String>) : JsonProblem

    data class MissingKey(val path: String, val key: String) : JsonProblem

    /** Sai kiểu; `expectedType` là tên kỹ thuật (Int, String, Bool, UUID, Array, Object), không dịch. */
    data class TypeMismatch(val path: String, val expectedType: String) : JsonProblem

    /** `null` ở chỗ cần giá trị. */
    data class ValueMissing(val path: String, val expectedType: String) : JsonProblem

    /** Giá trị không hợp lệ (UUID sai, mã lựa chọn sai, loại câu lạ, số không phải số nguyên); `detail` kỹ thuật. */
    data class InvalidValue(val path: String, val detail: String) : JsonProblem
}

enum class MigrationProblem { MISSING_STEP }

/**
 * Lỗi đọc gói `.exam` (cùng các case của `ExamFileError` bản macOS, chỉ phần bản Học viên dùng). Mỗi case có mã và
 * tham số để giao diện dựng câu bằng `strings.xml`; `message` của `Exception` chỉ cho nhật ký.
 */
sealed class ExamFileError(log: String) : Exception(log) {
    data object NotAZipArchive : ExamFileError("không đọc được dạng zip")

    data object MissingManifest : ExamFileError("thiếu exam.json ở gốc gói")

    data class CorruptedEntry(val path: String) : ExamFileError("không giải nén được $path")

    data class InvalidJson(val problem: JsonProblem) : ExamFileError("exam.json không hợp lệ: $problem")

    data class UnsupportedVersion(val found: Long, val supported: Long) :
        ExamFileError("đề cần app mới hơn (v$found, app hiểu tới v$supported)")

    data class InvalidVersion(val version: Long) : ExamFileError("formatVersion không hợp lệ: $version")

    data class UnknownFields(val paths: List<String>) : ExamFileError("trường lạ: $paths")

    data class DuplicateJsonKeys(val paths: List<String>) : ExamFileError("khoá trùng: $paths")

    data class NullValues(val paths: List<String>) : ExamFileError("giá trị null: $paths")

    data class MissingMedia(val paths: List<String>) : ExamFileError("thiếu ảnh: $paths")

    data class InvalidMediaPath(val paths: List<String>) : ExamFileError("đường dẫn ảnh sai: $paths")

    /** Các vấn đề mức error theo thứ tự kiểm đề trả về (không gồm warning). */
    data class ValidationFailed(val issues: List<ValidationIssue>) : ExamFileError("đề có ${issues.size} lỗi")

    data class DuplicateEntry(val path: String) : ExamFileError("nhiều entry cùng tên $path")

    data class TooLarge(val entry: String, val limit: Long) : ExamFileError("vượt giới hạn ở $entry (tối đa $limit)")

    data class TooDeep(val limit: Int) : ExamFileError("lồng quá $limit cấp")

    data class MigrationFailed(val from: Long, val reason: MigrationProblem) :
        ExamFileError("không chuyển được từ v$from: $reason")

    /** File `.oef` của Open Exam Suite không đọc được (`OefReader`). */
    data class Oef(val problem: OefProblem) : ExamFileError("File .oef không đọc được: ${problem.logMessage}")
}
