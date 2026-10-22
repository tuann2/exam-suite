package vn.io.nt0.examsuite.attempt

import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.review.ReviewItems

/**
 * Trạng thái điều hướng của Xem lại bài (bộ lọc, câu đang mở), dùng chung cho phiên vừa nộp và lần thi cũ mở từ Lịch sử
 * thi. Luật ẩn/hiện ở `ReviewItems` của `:core`.
 */
class AnswerReviewController(private val items: ReviewItems, private val canPracticeIncorrect: Boolean) {
    private var isOpen = false
    private var filter = ReviewFilter.ALL
    private var index: Int? = null

    /** Mở từ Kết quả: **Xem lại bài** (Tất cả) hoặc **Xem câu sai** (Sai). */
    fun open(filter: ReviewFilter) {
        isOpen = true
        this.filter = filter
        index = null
    }

    fun setFilter(filter: ReviewFilter) {
        this.filter = filter
        index = null
    }

    fun openQuestion(index: Int) {
        if (index in 0 until items.questionCount) this.index = index
    }

    /** Câu trước / sau trong bộ lọc đang chọn; ở đầu hay cuối bộ lọc thì đứng yên. */
    fun step(delta: Int) {
        val current = index ?: return
        val indices = items.indices(filter)
        indices.getOrNull(indices.indexOf(current) + delta)?.let { index = it }
    }

    /** Một bậc: chi tiết → danh sách → (đóng, về Kết quả). Trả false khi đã đóng. */
    fun back(): Boolean {
        when {
            index != null -> index = null
            isOpen -> isOpen = false
            else -> return false
        }
        return true
    }

    /** Null khi Xem lại đang đóng (đang ở Kết quả). */
    fun state(): AnswerReviewState? {
        if (!isOpen) return null
        val indices = items.indices(filter)
        val selected = index
        return AnswerReviewState(
            filter = filter,
            counts = ReviewFilter.entries.associateWith { items.count(it) },
            rows = indices.map { i -> ReviewRow(i, i + 1, items.outcome(i), items.isFlagged(i), items.changes[i], items.preview(i)) },
            detail = selected?.let { items.detail(it) },
            positionInFilter = selected?.let { indices.indexOf(it).takeIf { p -> p >= 0 } },
            answersHidden = items.answersHidden,
            canPracticeIncorrect = canPracticeIncorrect,
        )
    }
}
