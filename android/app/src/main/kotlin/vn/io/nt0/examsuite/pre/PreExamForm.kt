package vn.io.nt0.examsuite.pre

import vn.io.nt0.examsuite.attempt.NextAttempt
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionMode
import java.util.UUID

enum class SelectionKind { ALL, SECTIONS, RANDOM }

/** Lý do khoá **Bắt đầu**, theo thứ tự hiện (exam-taking.md, Trước khi thi; cùng thứ tự với bản macOS). */
sealed interface PreExamIssue {
    data object PracticeUnavailable : PreExamIssue

    data object NoQuestionsToPractice : PreExamIssue

    data object ExamHasNoQuestions : PreExamIssue

    data object NoSectionSelected : PreExamIssue

    data object SelectedSectionsEmpty : PreExamIssue

    data class RandomCountOutOfRange(val total: Int) : PreExamIssue

    data object TimeLimitOutOfRange : PreExamIssue

    data object EmptyCandidateName : PreExamIssue
}

data class SectionChoice(val id: UUID, val title: String, val questionCount: Int, val isSelected: Boolean)

/**
 * Màn **Trước khi thi** (exam-taking.md): chế độ, tên thí sinh, cách chọn câu, xáo, thời gian, dòng tóm tắt, lý do khoá.
 * Giá trị bất biến; giao diện đổi bằng `copy`/các hàm trả bản mới. Số nhập dạng chữ (ô số); chữ không phải số là ngoài
 * khoảng. Lựa chọn không nhớ giữa các đề, trừ tên thí sinh và chế độ (do nơi gọi truyền vào).
 */
data class PreExamForm(
    val exam: Exam,
    val mode: SessionMode,
    val candidateName: String,
    val kind: SelectionKind,
    val selectedSections: Set<UUID>,
    val randomCountText: String,
    val shuffleQuestions: Boolean,
    val shuffleOptions: Boolean,
    val timeLimitText: String,
    /** Luyện lại câu sai: đúng các câu này, chỉ đổi được tên thí sinh. */
    val fixedQuestionIds: List<UUID>?,
) {
    val isPracticeIncorrect: Boolean get() = fixedQuestionIds != null
    val canChangeOptions: Boolean get() = !isPracticeIncorrect
    val showsTimeLimit: Boolean get() = mode == SessionMode.EXAM
    val totalQuestionCount: Int get() = exam.questionCount
    val trimmedName: String get() = candidateName.trim()
    val randomCount: Int? get() = randomCountText.trim().toIntOrNull()
    val timeLimitMinutes: Int? get() = timeLimitText.trim().toIntOrNull()

    val sections: List<SectionChoice>
        get() = exam.sections.map { SectionChoice(it.id, it.title, it.questions.size, it.id in selectedSections) }

    /** Câu của Luyện lại câu sai còn trong đề, theo thứ tự, bỏ trùng. */
    private val practiceQuestionIds: List<UUID>
        get() {
            val known = exam.allQuestions.map { it.id }.toSet()
            return fixedQuestionIds.orEmpty().filter { it in known }.distinct()
        }

    private val effectiveSections: Set<UUID> get() = selectedSections intersect exam.sections.map { it.id }.toSet()

    /** Số câu của lựa chọn (N câu ngẫu nhiên: đúng N đã nhập, kể cả ngoài khoảng; chữ không phải số là 0). */
    val questionCount: Int
        get() = when {
            isPracticeIncorrect -> practiceQuestionIds.size
            kind == SelectionKind.ALL -> totalQuestionCount
            kind == SelectionKind.SECTIONS -> exam.sections.filter { it.id in effectiveSections }.sumOf { it.questions.size }
            else -> randomCount ?: 0
        }

    val issues: List<PreExamIssue>
        get() = buildList {
            if (mode == SessionMode.PRACTICE && exam.hideAnswers) add(PreExamIssue.PracticeUnavailable)
            if (isPracticeIncorrect) {
                if (practiceQuestionIds.isEmpty()) add(PreExamIssue.NoQuestionsToPractice)
            } else {
                when (kind) {
                    SelectionKind.ALL -> if (totalQuestionCount == 0) add(PreExamIssue.ExamHasNoQuestions)
                    SelectionKind.SECTIONS -> when {
                        effectiveSections.isEmpty() -> add(PreExamIssue.NoSectionSelected)
                        questionCount == 0 -> add(PreExamIssue.SelectedSectionsEmpty)
                    }
                    SelectionKind.RANDOM -> when {
                        totalQuestionCount == 0 -> add(PreExamIssue.ExamHasNoQuestions)
                        randomCount?.let { it in 1..totalQuestionCount } != true -> add(PreExamIssue.RandomCountOutOfRange(totalQuestionCount))
                    }
                }
                if (mode == SessionMode.EXAM && timeLimitMinutes?.let { it in ExamSession.TIME_LIMIT_RANGE } != true) {
                    add(PreExamIssue.TimeLimitOutOfRange)
                }
            }
            if (trimmedName.isEmpty()) add(PreExamIssue.EmptyCandidateName)
        }

    val canStart: Boolean get() = issues.isEmpty()

    fun withMode(mode: SessionMode): PreExamForm =
        if (!canChangeOptions || (mode == SessionMode.PRACTICE && exam.hideAnswers)) this else copy(mode = mode)

    fun withSection(id: UUID, selected: Boolean): PreExamForm =
        if (exam.sections.none { it.id == id }) this else copy(selectedSections = if (selected) selectedSections + id else selectedSections - id)

    fun selectAllSections(): PreExamForm = copy(selectedSections = exam.sections.map { it.id }.toSet())

    fun deselectAllSections(): PreExamForm = copy(selectedSections = emptySet())

    /** Tuỳ chọn tạo đề với `seed`; chỉ gọi khi `canStart`. */
    fun options(seed: ULong): CompositionOptions {
        if (isPracticeIncorrect) return CompositionOptions(QuestionSelection.Questions(practiceQuestionIds), seed = seed)
        val selection = when (kind) {
            SelectionKind.ALL -> QuestionSelection.All
            SelectionKind.SECTIONS -> QuestionSelection.Sections(effectiveSections)
            SelectionKind.RANDOM -> QuestionSelection.Random(randomCount ?: 0)
        }
        return CompositionOptions(selection, shuffleQuestions, shuffleOptions, seed)
    }

    /** Thời hạn truyền vào phiên: chỉ ở Thi. */
    fun sessionTimeLimit(): Int? = if (mode == SessionMode.EXAM) timeLimitMinutes else null

    /** Đề đã đọc lại lúc Bắt đầu (file có thể đã đổi): giữ lựa chọn, kiểm lại trên đề mới. */
    fun withExam(exam: Exam): PreExamForm = copy(exam = exam)

    companion object {
        /** Mở từ thẻ đề: chế độ yêu cầu hoặc lần trước; mọi phần được chọn; N bằng tổng số câu. */
        fun fresh(exam: Exam, mode: SessionMode, candidateName: String): PreExamForm = PreExamForm(
            exam = exam,
            mode = if (exam.hideAnswers) SessionMode.EXAM else mode,
            candidateName = candidateName,
            kind = SelectionKind.ALL,
            selectedSections = exam.sections.map { it.id }.toSet(),
            randomCountText = exam.questionCount.toString(),
            shuffleQuestions = false,
            shuffleOptions = false,
            timeLimitText = exam.timeLimitMinutes.toString(),
            fixedQuestionIds = null,
        )

        /** **Làm lại** (đúng lựa chọn của lần trước) hoặc **Luyện lại câu sai** (danh sách câu cố định, Luyện tập). */
        fun from(exam: Exam, next: NextAttempt, candidateName: String): PreExamForm {
            val base = fresh(exam, next.mode, candidateName)
            val o = next.options
            val form = when (val selection = o.selection) {
                QuestionSelection.All -> base.copy(kind = SelectionKind.ALL)
                is QuestionSelection.Sections -> base.copy(kind = SelectionKind.SECTIONS, selectedSections = selection.ids intersect base.selectedSections)
                is QuestionSelection.Random -> base.copy(kind = SelectionKind.RANDOM, randomCountText = selection.count.toString())
                is QuestionSelection.Questions -> return base.copy(mode = SessionMode.PRACTICE, fixedQuestionIds = selection.ids)
            }
            return form.copy(
                mode = if (exam.hideAnswers) SessionMode.EXAM else next.mode,
                shuffleQuestions = o.shuffleQuestions,
                shuffleOptions = o.shuffleOptions,
                timeLimitText = (next.timeLimitMinutes ?: exam.timeLimitMinutes.toInt()).toString(),
            )
        }
    }
}
