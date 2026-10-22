package vn.io.nt0.examsuite.attempt

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.review.ReviewItems
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.AttemptSummary

/**
 * Kết quả và Xem lại bài của một lần thi cũ mở từ Lịch sử thi (exam-taking.md, Lịch sử thi): nội dung câu lấy từ file đề
 * **hiện tại**. Chi tiết không đọc được thì chỉ còn tóm tắt, không Xem lại, không Làm lại (phương án 12); đề không còn hay
 * không đọc được thì không Xem lại.
 *
 * @param exam đề hiện tại trong Thư viện (cùng id), null nếu không còn hay không đọc được (`examProblem` cho biết lý do).
 */
class PastAttemptModel(
    private val summary: AttemptSummary,
    private val payload: AttemptPayload?,
    private val exam: Exam?,
    examProblem: ReviewAvailability?,
    previousPercent: Int?,
    private val newSeed: () -> ULong,
) : AttemptActions {
    private val items: ReviewItems? = if (payload != null && exam != null && payload.examId == exam.id) ReviewItems(payload, exam) else null
    private val practiceIds = items?.practiceIncorrectIds().orEmpty()
    private val review = items?.let { AnswerReviewController(it, canPracticeIncorrect = practiceIds.isNotEmpty()) }
    private val results = AttemptPresentation.pastResults(
        summary = summary,
        result = payload?.result,
        previousPercent = previousPercent,
        review = when {
            payload == null -> ReviewAvailability.DETAILS_UNREADABLE
            items == null -> examProblem ?: ReviewAvailability.EXAM_GONE
            else -> ReviewAvailability.AVAILABLE
        },
        canRetake = items != null,
    )

    private val _state = MutableStateFlow(build())
    val state: StateFlow<AttemptUiState> = _state.asStateFlow()

    override fun retake(): NextAttempt? {
        val p = payload ?: return null
        if (items == null) return null
        val questions = p.options.selection as? QuestionSelection.Questions
        return NextAttempt(summary.examId, if (questions != null) SessionMode.PRACTICE else summary.mode, p.options.copy(seed = newSeed()),
            summary.timeLimitMinutes, summary.candidateName, isPracticeIncorrect = questions != null)
    }

    override fun practiceIncorrect(): NextAttempt? {
        if (practiceIds.isEmpty()) return null
        val options = CompositionOptions(QuestionSelection.Questions(practiceIds), seed = newSeed())
        return NextAttempt(summary.examId, SessionMode.PRACTICE, options, null, summary.candidateName, isPracticeIncorrect = true)
    }

    override fun openAnswerReview(filter: ReviewFilter) = reviewCommand { it.open(filter) }

    override fun setReviewFilter(filter: ReviewFilter) = reviewCommand { it.setFilter(filter) }

    override fun openReviewQuestion(index: Int) = reviewCommand { it.openQuestion(index) }

    override fun stepReviewQuestion(delta: Int) = reviewCommand { it.step(delta) }

    override fun backFromAnswerReview(): Boolean {
        val changed = review?.back() ?: false
        if (changed) _state.value = build()
        return changed
    }

    private fun reviewCommand(block: (AnswerReviewController) -> Unit) {
        val controller = review ?: return
        Timing.measure("review.command") {
            block(controller)
            _state.value = build()
        }
    }

    private fun build() = AttemptUiState(
        examTitle = summary.examTitle,
        mode = summary.mode,
        clock = ClockDisplay(0, "", ClockLevel.NORMAL, isCountdown = false),
        banner = null,
        navigator = emptyList(),
        screen = review?.state()?.let { AttemptScreen.AnswerReview(it) } ?: AttemptScreen.Results(results),
    )

    // Lần thi đã nộp: các lệnh làm bài không có tác dụng.
    override fun toggleOption(position: Int) = Unit
    override fun next() = Unit
    override fun previous() = Unit
    override fun goTo(index: Int) = Unit
    override fun toggleFlag() = Unit
    override fun checkAnswer() = Unit
    override fun pause() = Unit
    override fun resume() = Unit
    override fun openReview() = Unit
    override fun returnToAttempt(index: Int?) = Unit
    override fun submit() = Unit
    override fun discard() = Unit
    override fun dismissBanner(id: Int) = Unit
}
