package vn.io.nt0.examsuite.core.scoring

import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.model.Question
import vn.io.nt0.examsuite.core.model.QuestionType
import java.util.UUID

/** Đáp án theo id câu → tập id lựa chọn **gốc**. Thiếu khoá hoặc tập rỗng = chưa trả lời. */
typealias AnswerSheet = Map<UUID, Set<OptionId>>

enum class QuestionOutcome { CORRECT, INCORRECT, UNANSWERED }

data class SectionScore(val sectionId: UUID, val title: String, val total: Int, val correct: Int)

/** Kết quả chấm cả phiên; chỉ tạo bằng `Scorer.score` (hoặc đọc lại từ payload đã kiểm). */
data class ScoreResult(
    val total: Int,
    val correct: Int,
    val score1000: Int,
    val percent: Int,
    val passPercent: Int,
    val passed: Boolean,
    /** Mọi phần của đề theo thứ tự file, kể cả phần 0/0. */
    val sections: List<SectionScore>,
    val outcomes: Map<UUID, QuestionOutcome>,
    /** Câu theo thứ tự phiên. */
    val questionIds: List<UUID>,
) {
    /** Câu sai hoặc chưa làm, theo thứ tự phiên ("Luyện lại câu sai"). */
    val incorrectOrUnansweredIds: List<UUID> get() = questionIds.filter { outcomes[it] != QuestionOutcome.CORRECT }
}

sealed class ScoringException(message: String) : Exception(message) {
    data class UnknownQuestion(val id: UUID) : ScoringException("câu $id không có trong đề")

    data class DuplicateQuestion(val id: UUID) : ScoringException("câu $id lặp trong phiên")
}

/** Chấm điểm theo docs/product/scoring.md (thẩm quyền); cùng kết quả với `Scorer` của bản macOS. */
object Scorer {
    fun outcome(question: Question, selected: Set<OptionId>?): QuestionOutcome {
        if (selected.isNullOrEmpty()) return QuestionOutcome.UNANSWERED
        if (!question.options.map { it.id }.toSet().containsAll(selected)) return QuestionOutcome.INCORRECT
        val correct = when (question.type) {
            QuestionType.SINGLE -> selected.size == 1 && selected == question.correctSet
            QuestionType.MULTIPLE -> selected == question.correctSet
        }
        return if (correct) QuestionOutcome.CORRECT else QuestionOutcome.INCORRECT
    }

    /** `total <= 0 ? 0 : correct * 1000 / total`, chia lấy phần nguyên. */
    fun score1000(correct: Int, total: Int): Int = if (total <= 0) 0 else (correct * 1000) / total

    /** `total <= 0 ? 0 : correct * 100 / total`, chỉ để hiển thị. */
    fun percent(correct: Int, total: Int): Int = if (total <= 0) 0 else (correct * 100) / total

    fun isPassed(score1000: Int, passPercent: Int): Boolean = score1000 >= passPercent * 10

    /**
     * Chấm cả phiên. Câu ngoài `questionIds` bị bỏ qua. Kiểm theo thứ tự phiên, ném lỗi gặp đầu:
     * `DuplicateQuestion`, `UnknownQuestion`. Id câu trùng trong đề (đề sai) thì lấy lần xuất hiện đầu.
     */
    fun score(exam: Exam, questionIds: List<UUID>, answers: AnswerSheet): ScoreResult {
        val index = HashMap<UUID, Pair<Question, Int>>()
        exam.sections.forEachIndexed { s, section -> section.questions.forEach { if (it.id !in index) index[it.id] = it to s } }
        val seen = HashSet<UUID>()
        val outcomes = LinkedHashMap<UUID, QuestionOutcome>()
        val totals = IntArray(exam.sections.size)
        val corrects = IntArray(exam.sections.size)
        var correct = 0
        for (id in questionIds) {
            if (!seen.add(id)) throw ScoringException.DuplicateQuestion(id)
            val (question, s) = index[id] ?: throw ScoringException.UnknownQuestion(id)
            val result = outcome(question, answers[id])
            outcomes[id] = result
            totals[s] += 1
            if (result == QuestionOutcome.CORRECT) {
                correct += 1
                corrects[s] += 1
            }
        }
        val total = questionIds.size
        val s1000 = score1000(correct, total)
        // Đề đã qua kiểm có passPercent 0–100; ép Int để phép so sánh như bản macOS.
        val passPercent = exam.passPercent.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
        return ScoreResult(
            total = total,
            correct = correct,
            score1000 = s1000,
            percent = percent(correct, total),
            passPercent = passPercent,
            passed = isPassed(s1000, passPercent),
            sections = exam.sections.mapIndexed { s, section -> SectionScore(section.id, section.title, totals[s], corrects[s]) },
            outcomes = outcomes,
            questionIds = questionIds,
        )
    }
}
