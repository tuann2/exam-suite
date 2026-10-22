package vn.io.nt0.examsuite.core.validation

import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import java.util.UUID

enum class IssueSeverity { ERROR, WARNING }

/** Vị trí của vấn đề; chỉ số từ 0, theo thứ tự trong file. */
sealed interface IssueLocation {
    data object ExamLevel : IssueLocation

    data class Section(val index: Int, val id: UUID) : IssueLocation

    data class QuestionAt(val sectionIndex: Int, val questionIndex: Int, val id: UUID) : IssueLocation

    data class OptionAt(val sectionIndex: Int, val questionIndex: Int, val optionIndex: Int, val questionId: UUID) : IssueLocation
}

/** Mã vấn đề ổn định, cùng tên với `IssueCode` của bản macOS; mỗi mã một mức độ cố định. */
enum class IssueCode(val severity: IssueSeverity = IssueSeverity.ERROR) {
    TITLE_EMPTY, TITLE_TOO_LONG, CODE_INVALID, PASS_PERCENT_OUT_OF_RANGE, TIME_LIMIT_OUT_OF_RANGE, INSTRUCTIONS_TOO_LONG,
    NO_SECTIONS, DUPLICATE_ID,
    SECTION_HAS_NO_QUESTIONS, DUPLICATE_SECTION_TITLE(IssueSeverity.WARNING),
    QUESTION_TEXT_EMPTY, QUESTION_TEXT_TOO_LONG, EXPLANATION_TOO_LONG, IMAGE_PATH_INVALID, IMAGE_NOT_FOUND,
    TOO_FEW_OPTIONS, TOO_MANY_OPTIONS, NO_CORRECT_ANSWER, DUPLICATE_CORRECT_ANSWER, CORRECT_ANSWER_NOT_IN_OPTIONS,
    SINGLE_HAS_MULTIPLE_CORRECT, MULTIPLE_HAS_SINGLE_CORRECT(IssueSeverity.WARNING),
    OPTION_ID_OUT_OF_ORDER, OPTION_TEXT_EMPTY, OPTION_TEXT_TOO_LONG,
}

/** Giá trị cụ thể của vấn đề để giao diện dựng câu (cùng `IssueArguments` bản macOS, cùng quy tắc điền trường). */
data class IssueArguments(
    val text: String? = null,
    val value: Long? = null,
    val limit: Int? = null,
    val optionId: OptionId? = null,
    val expectedOptionId: OptionId? = null,
    val optionIds: List<OptionId> = emptyList(),
    val firstLocation: IssueLocation? = null,
)

data class ValidationIssue(val code: IssueCode, val location: IssueLocation, val arguments: IssueArguments = IssueArguments()) {
    val severity: IssueSeverity get() = code.severity
}

/**
 * Kiểm một `Exam` đã giải mã: ràng buộc của schema mà model biểu diễn được và ràng buộc liên trường của
 * docs/product/exam-format.md. Cùng kết luận và cùng thứ tự vấn đề với `ExamValidator` của bản macOS (đề → phần → câu
 * → lựa chọn). Không kiểm `formatVersion` và trường lạ (việc của bộ đọc gói).
 */
object ExamValidator {
    val TITLE_LENGTH = 1..200
    const val INSTRUCTIONS_MAX_LENGTH = 4000
    val QUESTION_TEXT_LENGTH = 1..10_000
    const val EXPLANATION_MAX_LENGTH = 10_000
    val OPTION_COUNT = 2..26
    val OPTION_TEXT_LENGTH = 1..4000
    private val PASS_PERCENT = 0L..100L
    private val TIME_LIMIT_MINUTES = 1L..600L
    private val IMAGE_EXTENSIONS = setOf("png", "jpg", "jpeg", "gif", "webp", "heic")

    /** 25 code point `White_Space` (exam-format.md; khoá `whiteSpace` của fixtures/expected-verdicts.json). */
    private val WHITE_SPACE: Set<Int> = buildSet {
        addAll(0x09..0x0D); add(0x20); add(0x85); add(0xA0); add(0x1680); addAll(0x2000..0x200A)
        add(0x2028); add(0x2029); add(0x202F); add(0x205F); add(0x3000)
    }

    /** @param availableMedia null = không kiểm ảnh có trong gói; khác null = tập `media/…` có trong gói. */
    fun validate(exam: Exam, availableMedia: Set<String>? = null): List<ValidationIssue> {
        val issues = mutableListOf<ValidationIssue>()
        val seenIds = HashMap<UUID, IssueLocation>()
        fun add(code: IssueCode, location: IssueLocation, arguments: IssueArguments = IssueArguments()) {
            issues += ValidationIssue(code, location, arguments)
        }
        fun register(id: UUID, location: IssueLocation): IssueLocation? = seenIds[id] ?: run { seenIds[id] = location; null }

        register(exam.id, IssueLocation.ExamLevel)
        checkTitle(exam.title, IssueLocation.ExamLevel, ::add)
        exam.code?.let { if (!isValidCode(it)) add(IssueCode.CODE_INVALID, IssueLocation.ExamLevel, IssueArguments(text = it)) }
        if (exam.passPercent !in PASS_PERCENT) {
            add(IssueCode.PASS_PERCENT_OUT_OF_RANGE, IssueLocation.ExamLevel, IssueArguments(value = exam.passPercent))
        }
        if (exam.timeLimitMinutes !in TIME_LIMIT_MINUTES) {
            add(IssueCode.TIME_LIMIT_OUT_OF_RANGE, IssueLocation.ExamLevel, IssueArguments(value = exam.timeLimitMinutes))
        }
        exam.instructions?.let {
            val length = textLength(it)
            if (length > INSTRUCTIONS_MAX_LENGTH) {
                add(IssueCode.INSTRUCTIONS_TOO_LONG, IssueLocation.ExamLevel, IssueArguments(value = length.toLong(), limit = INSTRUCTIONS_MAX_LENGTH))
            }
        }
        if (exam.sections.isEmpty()) add(IssueCode.NO_SECTIONS, IssueLocation.ExamLevel)

        val seenTitles = HashMap<String, Int>()
        exam.sections.forEachIndexed { si, section ->
            val sectionLocation = IssueLocation.Section(si, section.id)
            register(section.id, sectionLocation)?.let {
                add(IssueCode.DUPLICATE_ID, sectionLocation, IssueArguments(text = section.id.toString(), firstLocation = it))
            }
            checkTitle(section.title, sectionLocation, ::add)
            // `lowercase()` của Java đổi Σ cuối từ thành ς; `lowercased()` của Swift luôn ra σ: đổi Σ trước cho khớp.
            val key = trimmed(section.title).replace('\u03A3', '\u03C3').lowercase()
            if (key.isNotEmpty()) {
                val first = seenTitles[key]
                if (first != null) {
                    add(IssueCode.DUPLICATE_SECTION_TITLE, sectionLocation, IssueArguments(
                        text = trimmed(section.title),
                        firstLocation = IssueLocation.Section(first, exam.sections[first].id),
                    ))
                } else {
                    seenTitles[key] = si
                }
            }
            if (section.questions.isEmpty()) add(IssueCode.SECTION_HAS_NO_QUESTIONS, sectionLocation)

            section.questions.forEachIndexed { qi, question ->
                val qLocation = IssueLocation.QuestionAt(si, qi, question.id)
                register(question.id, qLocation)?.let {
                    add(IssueCode.DUPLICATE_ID, qLocation, IssueArguments(text = question.id.toString(), firstLocation = it))
                }
                checkQuestion(question, qLocation, availableMedia, ::add)
                question.options.forEachIndexed { oi, option ->
                    val oLocation = IssueLocation.OptionAt(si, qi, oi, question.id)
                    val expected = OptionId.at(oi)
                    if (expected != null && option.id != expected) {
                        add(IssueCode.OPTION_ID_OUT_OF_ORDER, oLocation, IssueArguments(optionId = option.id, expectedOptionId = expected))
                    }
                    val length = textLength(option.text)
                    if (isBlank(option.text)) {
                        add(IssueCode.OPTION_TEXT_EMPTY, oLocation, IssueArguments(optionId = option.id))
                    } else if (length > OPTION_TEXT_LENGTH.last) {
                        add(IssueCode.OPTION_TEXT_TOO_LONG, oLocation,
                            IssueArguments(value = length.toLong(), limit = OPTION_TEXT_LENGTH.last, optionId = option.id))
                    }
                }
            }
        }
        return issues
    }

    private fun checkTitle(title: String, location: IssueLocation, add: (IssueCode, IssueLocation, IssueArguments) -> Unit) {
        val limit = TITLE_LENGTH.last
        if (isBlank(title)) {
            add(IssueCode.TITLE_EMPTY, location, IssueArguments(limit = limit))
        } else if (textLength(title) > limit) {
            add(IssueCode.TITLE_TOO_LONG, location, IssueArguments(value = textLength(title).toLong(), limit = limit))
        }
    }

    private fun checkQuestion(
        question: Question,
        location: IssueLocation,
        availableMedia: Set<String>?,
        add: (IssueCode, IssueLocation, IssueArguments) -> Unit,
    ) {
        val length = textLength(question.text)
        if (isBlank(question.text)) {
            add(IssueCode.QUESTION_TEXT_EMPTY, location, IssueArguments())
        } else if (length > QUESTION_TEXT_LENGTH.last) {
            add(IssueCode.QUESTION_TEXT_TOO_LONG, location, IssueArguments(value = length.toLong(), limit = QUESTION_TEXT_LENGTH.last))
        }
        question.explanation?.let {
            if (textLength(it) > EXPLANATION_MAX_LENGTH) {
                add(IssueCode.EXPLANATION_TOO_LONG, location, IssueArguments(value = textLength(it).toLong(), limit = EXPLANATION_MAX_LENGTH))
            }
        }
        question.image?.let { image ->
            if (!isValidImagePath(image)) {
                add(IssueCode.IMAGE_PATH_INVALID, location, IssueArguments(text = image))
            } else if (availableMedia != null && image !in availableMedia) {
                add(IssueCode.IMAGE_NOT_FOUND, location, IssueArguments(text = image))
            }
        }
        val count = question.options.size
        if (count < OPTION_COUNT.first) {
            add(IssueCode.TOO_FEW_OPTIONS, location, IssueArguments(value = count.toLong(), limit = OPTION_COUNT.first))
        } else if (count > OPTION_COUNT.last) {
            add(IssueCode.TOO_MANY_OPTIONS, location, IssueArguments(value = count.toLong(), limit = OPTION_COUNT.last))
        }
        val correct = question.correct
        if (correct.isEmpty()) add(IssueCode.NO_CORRECT_ANSWER, location, IssueArguments())
        val seen = HashSet<OptionId>()
        val duplicates = mutableListOf<OptionId>()
        for (id in correct) if (!seen.add(id) && id !in duplicates) duplicates += id
        if (duplicates.isNotEmpty()) add(IssueCode.DUPLICATE_CORRECT_ANSWER, location, IssueArguments(optionIds = duplicates))
        val optionIds = question.options.map { it.id }.toSet()
        val missing = mutableListOf<OptionId>()
        for (id in correct) if (id !in optionIds && id !in missing) missing += id
        if (missing.isNotEmpty()) add(IssueCode.CORRECT_ANSWER_NOT_IN_OPTIONS, location, IssueArguments(optionIds = missing))
        when {
            question.type == QuestionType.SINGLE && correct.size > 1 ->
                add(IssueCode.SINGLE_HAS_MULTIPLE_CORRECT, location, IssueArguments(value = correct.size.toLong(), optionIds = correct))
            question.type == QuestionType.MULTIPLE && seen.size == 1 ->
                add(IssueCode.MULTIPLE_HAS_SINGLE_CORRECT, location, IssueArguments())
        }
    }

    /** Độ dài theo code point, như JSON Schema `minLength`/`maxLength` (exam-format.md). */
    fun textLength(s: String): Int = s.codePointCount(0, s.length)

    /** Rỗng hoặc toàn code point `White_Space` (không gồm U+200B, U+FEFF, U+001C–U+001F). */
    fun isBlank(s: String): Boolean = s.codePoints().allMatch { it in WHITE_SPACE }

    /** Bỏ code point `White_Space` ở hai đầu. */
    fun trimmed(s: String): String {
        val points = s.codePoints().toArray()
        val start = points.indexOfFirst { it !in WHITE_SPACE }
        if (start < 0) return ""
        val end = points.indexOfLast { it !in WHITE_SPACE }
        return String(points, start, end - start + 1)
    }

    /** `^[A-Za-z0-9._-]{1,32}$`, khớp cả chuỗi. */
    fun isValidCode(code: String): Boolean =
        textLength(code) in 1..32 && code.all { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it == '.' || it == '_' || it == '-' }

    /** `^media/[a-f0-9]{16,64}\.(png|jpg|jpeg|gif|webp|heic)$`, khớp cả chuỗi. */
    fun isValidImagePath(path: String): Boolean {
        if (!path.startsWith("media/")) return false
        val name = path.substring("media/".length)
        val dot = name.lastIndexOf('.')
        if (dot < 0) return false
        val hash = name.substring(0, dot)
        return hash.length in 16..64 && hash.all { it in 'a'..'f' || it in '0'..'9' } && name.substring(dot + 1) in IMAGE_EXTENSIONS
    }
}
