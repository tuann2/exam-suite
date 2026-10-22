package vn.io.nt0.examsuite.core.review

import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import java.util.UUID

/** Bộ lọc của Xem lại bài (exam-taking.md): Đúng, Sai, Chưa làm chia hết các câu; Đã đánh dấu cắt ngang. */
enum class ReviewFilter { ALL, INCORRECT, UNANSWERED, FLAGGED, CORRECT }

/** Câu so với lúc thi, theo dấu vân tay (exam-taking.md, Lịch sử thi). */
enum class QuestionChange { UNCHANGED, EDITED, DELETED }

/** Mức xem lại của PDF kết quả (export-print.md; v1.1): đúng bộ lọc tương ứng của Xem lại. */
enum class ReviewLevel { NONE, INCORRECT_AND_UNANSWERED, ALL }

/**
 * Một lựa chọn như hiện ở Xem lại. `isCorrectAnswer` null khi không được hiện đáp án đúng (đề `hideAnswers`, câu đã
 * sửa). `position` là vị trí hiển thị (nhãn A, B… theo vị trí).
 */
data class ReviewOption(val position: Int, val optionId: OptionId, val text: String, val isSelected: Boolean, val isCorrectAnswer: Boolean?)

/**
 * Chi tiết một câu ở Xem lại. Câu đã xoá: `text`, `options` rỗng, giao diện hiện "Câu này đã bị xoá khỏi đề". Câu đã sửa
 * (`marksHidden`): lựa chọn **hiện tại** theo thứ tự file, không đánh dấu Bạn chọn/Đáp án đúng; giao diện hiện hai dòng
 * báo. `outcome` luôn là kết quả lúc thi.
 */
data class ReviewDetail(
    val index: Int,
    val number: Int,
    val total: Int,
    val sectionTitle: String,
    val outcome: QuestionOutcome,
    val isFlagged: Boolean,
    val change: QuestionChange,
    val text: String?,
    val imagePath: String?,
    val options: List<ReviewOption>,
    val explanation: String?,
) {
    val marksHidden: Boolean get() = change == QuestionChange.EDITED
}

/**
 * Luật của Xem lại bài, không chứa chữ giao diện, **một nơi duy nhất** cho màn Xem lại (v1) và PDF kết quả (v1.1,
 * plan-android-v1.md Phần 4 quy tắc 2). Cùng luật với `AnswerReviewModel` của bản macOS:
 * - nội dung câu lấy từ đề **hiện tại** `exam` (cùng id đề);
 * - ẩn đáp án đúng và giải thích theo `hideAnswers` của đề hiện tại (phương án 4);
 * - câu đã sửa: không đánh dấu lựa chọn, vẫn hiện giải thích hiện tại khi đề không ẩn đáp án (phương án 13, 18);
 * - câu đã xoá: chỉ còn kết quả lúc thi.
 */
class ReviewItems(private val payload: AttemptPayload, exam: Exam) {
    val answersHidden: Boolean = exam.hideAnswers

    private val questions: Map<UUID, Question> = LinkedHashMap<UUID, Question>().also { map ->
        for (q in exam.allQuestions) if (q.id !in map) map[q.id] = q
    }

    val changes: List<QuestionChange> = payload.paper.items.map { item ->
        val question = questions[item.questionId]
        when {
            question == null -> QuestionChange.DELETED
            QuestionFingerprint.fingerprint(question) == payload.fingerprints[item.questionId] -> QuestionChange.UNCHANGED
            else -> QuestionChange.EDITED
        }
    }

    private val sectionTitles: Map<UUID, String> = LinkedHashMap<UUID, String>().also { map ->
        for (s in payload.result.sections) if (s.sectionId !in map) map[s.sectionId] = s.title
    }

    val questionCount: Int get() = payload.paper.items.size

    fun outcome(index: Int): QuestionOutcome = payload.result.outcomes[payload.paper.items[index].questionId] ?: QuestionOutcome.UNANSWERED

    fun isFlagged(index: Int): Boolean = payload.paper.items[index].questionId in payload.flagged

    fun matches(index: Int, filter: ReviewFilter): Boolean = when (filter) {
        ReviewFilter.ALL -> true
        ReviewFilter.INCORRECT -> outcome(index) == QuestionOutcome.INCORRECT
        ReviewFilter.UNANSWERED -> outcome(index) == QuestionOutcome.UNANSWERED
        ReviewFilter.CORRECT -> outcome(index) == QuestionOutcome.CORRECT
        ReviewFilter.FLAGGED -> isFlagged(index)
    }

    /** Vị trí (trong thứ tự phiên) các câu thuộc bộ lọc. */
    fun indices(filter: ReviewFilter): List<Int> = payload.paper.items.indices.filter { matches(it, filter) }

    fun count(filter: ReviewFilter): Int = indices(filter).size

    /** Câu theo mức xem lại của PDF: Câu sai và chưa làm = bộ lọc Sai + Chưa làm, theo thứ tự phiên. */
    fun indices(level: ReviewLevel): List<Int> = when (level) {
        ReviewLevel.NONE -> emptyList()
        ReviewLevel.INCORRECT_AND_UNANSWERED -> payload.paper.items.indices.filter { outcome(it) != QuestionOutcome.CORRECT }
        ReviewLevel.ALL -> payload.paper.items.indices.toList()
    }

    /** Dòng đầu của nội dung câu (cho danh sách); null nếu câu đã xoá. */
    fun preview(index: Int): String? =
        questions[payload.paper.items[index].questionId]?.text?.let { text -> text.lineSequence().firstOrNull { it.isNotEmpty() } ?: "" }

    fun detail(index: Int): ReviewDetail {
        val item = payload.paper.items[index]
        val selected = payload.answers[item.questionId] ?: emptySet()
        val change = changes[index]
        val question = questions[item.questionId]
        val options = when {
            question == null -> emptyList()
            change == QuestionChange.EDITED -> question.options.mapIndexed { position, option ->
                ReviewOption(position, option.id, option.text, isSelected = false, isCorrectAnswer = null)
            }
            else -> {
                val texts = LinkedHashMap<OptionId, String>().also { m -> question.options.forEach { if (it.id !in m) m[it.id] = it.text } }
                item.optionOrder.mapIndexed { position, id ->
                    ReviewOption(position, id, texts[id] ?: "", isSelected = id in selected,
                        isCorrectAnswer = if (answersHidden) null else id in question.correctSet)
                }
            }
        }
        return ReviewDetail(
            index = index,
            number = index + 1,
            total = questionCount,
            sectionTitle = sectionTitles[item.sectionId] ?: "",
            outcome = outcome(index),
            isFlagged = item.questionId in payload.flagged,
            change = change,
            text = question?.text,
            imagePath = question?.image,
            options = options,
            explanation = if (question == null || answersHidden) null else question.explanation,
        )
    }

    /** "Luyện lại câu sai" từ Xem lại: câu sai và chưa làm còn trong đề, theo thứ tự phiên; rỗng nếu đề ẩn đáp án. */
    fun practiceIncorrectIds(): List<UUID> =
        if (answersHidden) emptyList() else payload.result.incorrectOrUnansweredIds.filter { it in questions }
}
