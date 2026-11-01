package vn.io.nt0.examsuite.core.file

// Lỗi có mã của bộ đọc `.oef` (docs/product/exam-format.md, mục File `.oef`), cùng các case của `OEFProblem` bản macOS.
// `logMessage` là câu tiếng Việt cho nhật ký và test; giao diện dựng câu từ case và tham số (`strings.xml`).

/**
 * Vị trí của một câu trong file `.oef`: thứ tự phần và thứ tự câu trong phần, đếm từ 0 theo file (kể cả phần và câu bị
 * bỏ khi chuyển).
 */
data class OefPlace(val section: Int, val question: Int) {
    /** "phần 2, câu 3": đếm từ 1, tiếng Việt cho nhật ký và test. */
    val logDescription: String get() = "phần ${section + 1}, câu ${question + 1}"
}

/** Giới hạn khi đọc `.oef`, chống file dựng có chủ đích. Mặc định theo trần của gói `.exam` (`ExamPackageLimits`). */
class OefLimits(
    /** Kích thước file tối đa, byte (bằng tổng giải nén của gói `.exam`). */
    val fileBytes: Long = ExamPackageLimits.DEFAULT.totalUncompressedBytes,
    /** Kích thước tối đa của mỗi ảnh, byte. */
    val imageBytes: Long = ExamPackageLimits.DEFAULT.mediaEntryBytes,
    /** Tổng độ dài (byte UTF-8) của mọi chuỗi tối đa (bằng trần `exam.json`); kiểm trước khi kiểm UTF-8. */
    val textBytes: Long = ExamPackageLimits.DEFAULT.manifestBytes,
    /** Tổng số phần, câu, lựa chọn và đáp án (phần tử của Answers) tối đa. */
    val elementCount: Int = 500_000,
    listedItems: Int = 20,
) {
    /** Số mục giữ lại trong danh sách của câu báo (đường dẫn trường lạ, chữ đáp án không khớp): các mục khác nhau đầu tiên; ít nhất 1. */
    val listedItems: Int = maxOf(1, listedItems)

    companion object {
        val DEFAULT = OefLimits()
    }
}

/** Giới hạn nào của `OefLimits` bị vượt; `raw` cùng tên với bản macOS. */
enum class OefLimit(val raw: String) {
    FILE("file"),
    TEXT("text"),
    ELEMENTS("elements"),
}

/** Vì sao file `.oef` không đọc được (`ExamFileError.Oef`). Lõi Kotlin chỉ đọc nghiêm, nên mọi case đều có thể xảy ra. */
sealed interface OefProblem {
    /** `.oef` bản cũ của Open Exam Suite (zip + XML, hoặc BinaryFormatter của .NET): mở bằng Open Exam Suite rồi lưu lại. */
    data object LegacyFormat : OefProblem

    /** Dây Protobuf hỏng hoặc file không phải `.oef` của Open Exam Suite. `offset`: vị trí byte (từ 0) nơi phát hiện. */
    data class Malformed(val offset: Int) : OefProblem

    /** File không có câu hỏi nào (sau khi bỏ phần không có câu). */
    data object NoQuestions : OefProblem

    /** Vượt giới hạn của `OefLimits`. `value`: byte hoặc số phần tử. */
    data class TooLarge(val limit: OefLimit, val value: Long) : OefProblem

    /** Ảnh của câu vượt `OefLimits.imageBytes`. */
    data class ImageTooLarge(val place: OefPlace, val limit: Long) : OefProblem

    /** Trường không có trong định dạng đã biết, dạng `sections[0].questions[2].#9` (tối đa `OefLimits.listedItems` đường dẫn đầu). */
    data class UnknownFields(val paths: List<String>) : OefProblem

    /** Ngưỡng đậu không phải số trong thang 0–1000. */
    data object PassmarkOutOfRange : OefProblem

    /** Ảnh không thuộc png, jpg, gif, webp, heic (nhận theo byte đầu). */
    data class UnsupportedImage(val place: OefPlace) : OefProblem

    /** Câu có quá 26 lựa chọn. `count`: số lựa chọn trong file. */
    data class TooManyOptions(val place: OefPlace, val count: Int) : OefProblem

    /** Hai lựa chọn của một câu cùng chữ cái. `letter`: chữ cái (hoặc `U+XXXX`). */
    data class DuplicateOptionLetter(val place: OefPlace, val letter: String) : OefProblem

    /** Đáp án không khớp chữ cái của lựa chọn nào trong câu (tối đa `OefLimits.listedItems` chữ đầu). */
    data class AnswerNotInOptions(val place: OefPlace, val letters: List<String>) : OefProblem

    /** Câu tiếng Việt (nhật ký, test), phần sau "File .oef không đọc được: ". */
    val logMessage: String
        get() = when (this) {
            LegacyFormat -> "file .oef bản cũ (trước Open Exam Suite 4). Mở file bằng Open Exam Suite rồi lưu lại để có bản mới."
            is Malformed -> "dữ liệu hỏng ở byte $offset, hoặc file không phải đề của Open Exam Suite."
            NoQuestions -> "file không có câu hỏi nào."
            is TooLarge -> when (limit) {
                OefLimit.FILE -> "file vượt giới hạn $value byte."
                OefLimit.TEXT -> "phần chữ của file vượt giới hạn $value byte."
                OefLimit.ELEMENTS -> "file có quá $value phần, câu, lựa chọn và đáp án."
            }
            is ImageTooLarge -> "ảnh của ${place.logDescription} vượt giới hạn $limit byte."
            is UnknownFields -> "file có trường không được hỗ trợ: ${paths.joinToString(", ")}."
            PassmarkOutOfRange -> "ngưỡng đậu không nằm trong thang 0–1000."
            is UnsupportedImage -> "ảnh của ${place.logDescription} không thuộc loại được hỗ trợ (png, jpg, gif, webp, heic)."
            is TooManyOptions -> "${place.logDescription} có $count lựa chọn (tối đa 26)."
            is DuplicateOptionLetter -> "${place.logDescription} có hai lựa chọn cùng chữ $letter."
            is AnswerNotInOptions -> "đáp án ${letters.joinToString(", ")} của ${place.logDescription} không khớp lựa chọn nào."
        }
}
