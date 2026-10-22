package vn.io.nt0.examsuite.attempt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.AttemptSummary

/** Kết quả lần thi cũ mở từ Lịch sử thi: phần model thêm (khi nào Xem lại, Làm lại được); luật Xem lại ở `ReviewItems`. */
class PastAttemptModelTest {
    private val exam = testExam(3)

    /** Lần thi Thi: câu 1 sai, câu 2 đúng, câu 3 chưa làm. */
    private fun submitted(options: CompositionOptions = CompositionOptions(QuestionSelection.All, seed = 4uL)): Pair<AttemptSummary, AttemptPayload> {
        val session = startSession(exam, SessionMode.EXAM, FakeClock(), options, timeLimitMinutes = 25)
        session.select(letter('B'))
        if (session.questionCount > 1) {
            session.next()
            session.select(letter('A'))
        }
        session.openReview()
        session.submit()
        val payload = AttemptPayload.from(session, QuestionFingerprint.fingerprints(exam))
        val r = payload.result
        val summary = AttemptSummary(uuid(900), exam.id, exam.title, exam.code, "An", SessionMode.EXAM, 0, 60_000, 60.0, 25,
            r.total, r.correct, r.score1000, r.percent, r.passPercent, r.passed)
        return summary to payload
    }

    private fun model(summary: AttemptSummary, payload: AttemptPayload?, current: Exam?, problem: ReviewAvailability? = null) =
        PastAttemptModel(summary, payload, current, problem, previousPercent = 10, newSeed = { 77uL })

    private val PastAttemptModel.results get() = (state.value.screen as AttemptScreen.Results).results

    @Test
    fun readableAttemptReviewsAndRetakesWithNewSeed() {
        val (summary, payload) = submitted()
        val m = model(summary, payload, exam)
        assertEquals(ReviewAvailability.AVAILABLE, m.results.review)
        assertTrue(m.results.canRetake)
        assertEquals(23, m.results.previousDelta) // 33% − 10%
        assertEquals(NextAttempt(exam.id, SessionMode.EXAM, payload.options.copy(seed = 77uL), 25, "An", false), m.retake())
        m.openAnswerReview(ReviewFilter.INCORRECT)
        assertEquals(listOf(0), (m.state.value.screen as AttemptScreen.AnswerReview).review.rows.map { it.index })
        assertTrue(m.backFromAnswerReview())
        assertTrue(m.state.value.screen is AttemptScreen.Results)
    }

    @Test
    fun unreadableDetailsShowSummaryOnly() {
        val (summary, _) = submitted()
        val m = model(summary, null, exam)
        assertEquals(ReviewAvailability.DETAILS_UNREADABLE, m.results.review)
        assertFalse(m.results.canRetake)
        assertTrue(m.results.sections.isEmpty())
        assertNull(m.retake())
        assertNull(m.practiceIncorrect())
        m.openAnswerReview(ReviewFilter.ALL)
        assertTrue(m.state.value.screen is AttemptScreen.Results)
    }

    @Test
    fun missingExamDisablesReviewAndRetake() {
        val (summary, payload) = submitted()
        for (problem in listOf(ReviewAvailability.EXAM_GONE, ReviewAvailability.EXAM_UNREADABLE)) {
            val m = model(summary, payload, null, problem)
            assertEquals(problem, m.results.review)
            assertFalse(m.results.canRetake)
            // Phần và số câu sai vẫn có từ chi tiết lần thi.
            assertEquals(1, m.results.incorrectCount)
            assertEquals(1, m.results.sections.size)
        }
    }

    @Test
    fun practiceIncorrectSkipsQuestionsDeletedSinceAttempt() {
        val (summary, payload) = submitted()
        val withoutFirst = exam.copy(sections = exam.sections.map { s -> s.copy(questions = s.questions.drop(1)) })
        val next = model(summary, payload, withoutFirst).practiceIncorrect()!!
        assertEquals(QuestionSelection.Questions(listOf(uuid(103))), next.options.selection)
        assertTrue(next.isPracticeIncorrect)
        assertEquals(SessionMode.PRACTICE, next.mode)
    }

    @Test
    fun retakeOfPracticeIncorrectAttemptStaysPracticeIncorrect() {
        val (summary, payload) = submitted(CompositionOptions(QuestionSelection.Questions(listOf(uuid(101), uuid(102))), seed = 2uL))
        val next = model(summary, payload, exam).retake()!!
        assertTrue(next.isPracticeIncorrect)
        assertEquals(SessionMode.PRACTICE, next.mode)
    }
}
