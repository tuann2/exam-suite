package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.review.QuestionChange
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.review.ReviewItems
import vn.io.nt0.examsuite.core.review.ReviewLevel
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome

/** Luật Xem lại bài (exam-taking.md; phương án 4, 13, 18), một nơi cho màn Xem lại và PDF v1.1. */
class ReviewItemsTest {
    private val payload = AttemptSamples.payload()
    private val exam = AttemptSamples.exam
    private val ids = payload.paper.questionIds

    @Test
    fun `bộ lọc, Đúng Sai Chưa làm chia hết các câu, Đã đánh dấu cắt ngang, theo thứ tự phiên`() {
        val r = ReviewItems(payload, exam)
        assertEquals(listOf(0), r.indices(ReviewFilter.CORRECT))
        assertEquals(listOf(1), r.indices(ReviewFilter.INCORRECT))
        assertEquals(listOf(2, 3, 4), r.indices(ReviewFilter.UNANSWERED))
        assertEquals(listOf(2), r.indices(ReviewFilter.FLAGGED))
        assertEquals(5, r.count(ReviewFilter.ALL))
        assertEquals(listOf(1, 2, 3, 4), r.indices(ReviewLevel.INCORRECT_AND_UNANSWERED))
        assertEquals(emptyList<Int>(), r.indices(ReviewLevel.NONE))
    }

    @Test
    fun `câu không đổi, lựa chọn theo thứ tự đã hiện, Bạn chọn và Đáp án đúng, giải thích`() {
        val d = ReviewItems(payload, exam).detail(1)
        assertEquals(QuestionChange.UNCHANGED, d.change)
        assertEquals(payload.paper.items[1].optionOrder, d.options.map { it.optionId })
        assertEquals(payload.answers.getValue(ids[1]), d.options.filter { it.isSelected }.map { it.optionId }.toSet())
        assertEquals(exam.question(ids[1])!!.correctSet, d.options.filter { it.isCorrectAnswer == true }.map { it.optionId }.toSet())
        assertEquals(exam.question(ids[1])!!.explanation, d.explanation)
        assertEquals(listOf(0, 1, 2, 3), d.options.map { it.position })
    }

    @Test
    fun `đề hideAnswers, vẫn có lựa chọn của người làm và kết quả, không lộ đáp án đúng và giải thích, không Luyện lại câu sai`() {
        val r = ReviewItems(payload, exam.copy(hideAnswers = true))
        val d = r.detail(1)
        assertTrue(d.options.all { it.isCorrectAnswer == null })
        assertTrue(d.options.any { it.isSelected })
        assertNull(d.explanation)
        assertEquals(QuestionOutcome.INCORRECT, d.outcome)
        assertEquals(emptyList<java.util.UUID>(), r.practiceIncorrectIds())
    }

    @Test
    fun `câu đã sửa sau lần thi, lựa chọn hiện tại theo thứ tự file, không đánh dấu, kết quả lúc thi, vẫn hiện giải thích hiện tại`() {
        val edited = exam.copy(sections = exam.sections.map { s -> s.copy(questions = s.questions.map { q ->
            if (q.id == ids[1]) q.copy(text = q.text + " (sửa)", explanation = "Giải thích mới") else q }) })
        val r = ReviewItems(payload, edited)
        assertEquals(QuestionChange.EDITED, r.changes[1])
        val d = r.detail(1)
        assertTrue(d.marksHidden)
        assertEquals(edited.question(ids[1])!!.options.map { it.id }, d.options.map { it.optionId })
        assertTrue(d.options.none { it.isSelected || it.isCorrectAnswer != null })
        assertEquals(QuestionOutcome.INCORRECT, d.outcome)
        assertEquals("Giải thích mới", d.explanation)
        assertNull(ReviewItems(payload, edited.copy(hideAnswers = true)).detail(1).explanation)
    }

    @Test
    fun `dấu vân tay đã tính của đề hiện tại được dùng thay vì tính lại, thiếu câu nào thì tự tính`() {
        assertEquals(ReviewItems(payload, exam).changes, ReviewItems(payload, exam, payload.fingerprints).changes)
        // Giá trị đưa vào khác của câu 2: câu đó thành đã sửa, nên giá trị đưa vào được dùng; các câu khác tự tính.
        val r = ReviewItems(payload, exam, mapOf(ids[1] to "0".repeat(64)))
        assertEquals(QuestionChange.EDITED, r.changes[1])
        assertEquals(listOf(QuestionChange.UNCHANGED), (r.changes - QuestionChange.EDITED).distinct())
    }

    @Test
    fun `câu đã xoá khỏi đề chỉ còn kết quả lúc thi, Luyện lại câu sai chỉ lấy câu còn trong đề`() {
        val removed = exam.copy(sections = exam.sections.map { s -> s.copy(questions = s.questions.filter { it.id != ids[3] }) })
        val r = ReviewItems(payload, removed)
        val d = r.detail(3)
        assertEquals(QuestionChange.DELETED, d.change)
        assertNull(d.text); assertEquals(emptyList<Any>(), d.options); assertNull(d.preview())
        assertEquals(listOf(ids[1], ids[2], ids[4]), r.practiceIncorrectIds())
        assertEquals(QuestionOutcome.UNANSWERED, d.outcome)
    }

    private fun vn.io.nt0.examsuite.core.review.ReviewDetail.preview(): String? = ReviewItems(payload, exam.copy(sections = exam.sections.map { s -> s.copy(questions = s.questions.filter { it.id != ids[3] }) })).preview(index)

    @Test
    fun `tiêu đề phần lấy từ kết quả lúc thi, dòng xem trước là dòng đầu không rỗng`() {
        val r = ReviewItems(payload, exam)
        val d = r.detail(0)
        assertEquals(payload.result.sections.first { it.sectionId == payload.paper.items[0].sectionId }.title, d.sectionTitle)
        assertEquals(exam.question(ids[0])!!.text.lines().first { it.isNotEmpty() }, r.preview(0))
    }

    @Test
    fun `dòng xem trước tách theo mọi ký tự xuống dòng như Swift, kể cả U+2028 và NEL`() {
        for (separator in listOf(Char(0x2028), Char(0x0085), '\r')) {
            val changed = exam.copy(sections = exam.sections.map { s -> s.copy(questions = s.questions.map { q ->
                if (q.id == ids[0]) q.copy(text = "Dòng một" + separator + "Dòng hai") else q }) })
            assertEquals("Dòng một", ReviewItems(payload, changed).preview(0))
        }
    }
}
