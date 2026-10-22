package vn.io.nt0.examsuite.core.model

import java.util.UUID

/** Loại câu hỏi (docs/product/exam-format.md). `single`: đúng một đáp án; `multiple`: đúng toàn bộ tập đáp án. */
enum class QuestionType(val raw: String) {
    SINGLE("single"),
    MULTIPLE("multiple"),
    ;

    companion object {
        fun fromRaw(raw: String): QuestionType? = entries.firstOrNull { it.raw == raw }
    }
}

/**
 * Mã lựa chọn: đúng một chữ cái in hoa A–Z, theo thứ tự trong `options`. Chấm điểm so theo mã này, không theo vị trí
 * hiển thị. So sánh theo chữ cái (A < B).
 */
@JvmInline
value class OptionId private constructor(val letter: Char) : Comparable<OptionId> {
    /** Vị trí 0-based (A → 0). */
    val index: Int get() = letter - 'A'

    override fun compareTo(other: OptionId): Int = letter.compareTo(other.letter)

    override fun toString(): String = letter.toString()

    companion object {
        /** Null nếu không phải đúng một chữ cái ASCII A–Z. */
        fun of(text: String): OptionId? = if (text.length == 1 && text[0] in 'A'..'Z') OptionId(text[0]) else null

        /** Mã ở vị trí `index` (0 → A, …, 25 → Z); null nếu ngoài khoảng. */
        fun at(index: Int): OptionId? = if (index in 0..25) OptionId('A' + index) else null
    }
}

/** Một lựa chọn của câu hỏi; `text` là Markdown cơ bản. */
data class ExamOption(val id: OptionId, val text: String)

/** Câu hỏi. Thứ tự `options` là thứ tự gốc; xáo đáp án là việc của phiên thi, không đổi dữ liệu này. */
data class Question(
    val id: UUID,
    val type: QuestionType,
    val text: String,
    /** `media/<hash>.<ext>`; null nếu không có ảnh. */
    val image: String? = null,
    val options: List<ExamOption>,
    /** Tập đáp án đúng như ghi trong file; `single` có đúng một phần tử khi đề hợp lệ. */
    val correct: List<OptionId>,
    val explanation: String? = null,
) {
    val correctSet: Set<OptionId> get() = correct.toSet()
}

/** Một phần (section) của đề. */
data class ExamSection(val id: UUID, val title: String, val questions: List<Question>)

/**
 * Đề thi: nội dung của `exam.json` (schema/exam-v1.schema.json). Các số nguyên đọc từ file giữ kiểu `Long` để giữ
 * nguyên giá trị như bộ giải mã Swift (`Int` 64 bit) và để kiểm đề báo đúng giá trị ngoài khoảng.
 */
data class Exam(
    val formatVersion: Long,
    val id: UUID,
    val title: String,
    val code: String? = null,
    /** Ngưỡng đậu theo % câu đúng, 0–100 khi đề hợp lệ (docs/product/scoring.md). */
    val passPercent: Long,
    /** Thời gian mặc định của chế độ Thi, phút, 1–600 khi đề hợp lệ. */
    val timeLimitMinutes: Long,
    val hideAnswers: Boolean = false,
    val instructions: String? = null,
    val sections: List<ExamSection>,
) {
    /** Mọi câu theo thứ tự trong file. */
    val allQuestions: List<Question> get() = sections.flatMap { it.questions }

    val questionCount: Int get() = sections.sumOf { it.questions.size }

    /** Câu theo id; id trùng (đề sai) thì lấy lần xuất hiện đầu. */
    fun question(id: UUID): Question? = allQuestions.firstOrNull { it.id == id }

    /** Phần chứa câu có id đã cho. */
    fun sectionContaining(questionId: UUID): ExamSection? = sections.firstOrNull { s -> s.questions.any { it.id == questionId } }

    companion object {
        const val CURRENT_FORMAT_VERSION: Long = 1
    }
}

/**
 * UUID theo đúng cách bộ giải mã Swift nhận (`UUID(uuidString:)`): 8-4-4-4-12 chữ số hex, hoa hay thường, không
 * ngoặc, không khoảng trắng. `java.util.UUID.fromString` dễ dãi hơn (nhận `1-1-1-1-1`) nên không dùng trực tiếp.
 */
object StrictUuid {
    private val pattern = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")

    fun parse(text: String): UUID? = if (pattern.matches(text)) UUID.fromString(text) else null
}
