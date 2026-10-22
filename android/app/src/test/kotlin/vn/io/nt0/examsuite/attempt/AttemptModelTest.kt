package vn.io.nt0.examsuite.attempt

import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.review.ReviewFilter
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import vn.io.nt0.examsuite.core.session.SessionSnapshot
import java.util.UUID

/** Nơi lưu giả: ghi lại thứ tự lệnh; mỗi lệnh có thể chờ để thử thứ tự ghi. */
private class FakeStore(
    private val writeDelayMillis: Long = 0,
    var previous: Int? = null,
    var failSave: Boolean = false,
    var failDraft: Boolean = false,
) : AttemptStore {
    val log = mutableListOf<String>()
    var draft: SessionSnapshot? = null

    override suspend fun saveDraft(snapshot: SessionSnapshot) {
        delay(writeDelayMillis)
        if (failDraft) throw java.io.IOException("đĩa đầy")
        draft = snapshot
        log += "saveDraft"
    }

    override suspend fun clearDraft() {
        delay(writeDelayMillis)
        if (failDraft) throw java.io.IOException("đĩa đầy")
        draft = null
        log += "clearDraft"
    }

    override suspend fun previousPercent(examId: UUID, mode: SessionMode): Int? {
        log += "previous"
        return previous
    }

    override suspend fun saveAttempt(session: ExamSession) {
        delay(writeDelayMillis)
        log += "saveAttempt"
        if (failSave) error("đĩa đầy")
        draft = null
    }
}

/** Phần model màn làm bài thêm trên `ExamSession`: dựng màn, xuống nền, lưu, Kết quả, Xem lại. */
class AttemptModelTest {
    private val clock = FakeClock()

    private fun TestScope.model(
        exam: Exam = testExam(3),
        mode: SessionMode = SessionMode.PRACTICE,
        store: AttemptStore = FakeStore(),
        timeLimitMinutes: Int? = null,
        session: ExamSession = startSession(exam, mode, clock, timeLimitMinutes = timeLimitMinutes),
    ) = AttemptModel(session, store, this, newSeed = { 99uL }, writeLock = lock)

    private val lock = kotlinx.coroutines.sync.Mutex()

    private val AttemptModel.screen get() = state.value.screen

    private fun AttemptModel.answering() = screen as AttemptScreen.Answering

    @Test
    fun tappingSelectedSingleOptionClearsIt() = runTest {
        val m = model()
        m.toggleOption(1)
        assertTrue(m.answering().question.options[1].isSelected)
        m.toggleOption(1)
        assertTrue(m.answering().question.options.none { it.isSelected })
        assertEquals(0, m.answering().answeredCount)
    }

    @Test
    fun invalidCommandsLeaveSessionUnchanged() = runTest {
        val m = model()
        m.previous()
        m.toggleOption(9)
        m.checkAnswer() // chưa có đáp án
        assertEquals(0, m.answering().question.index)
        assertNull(m.answering().question.check)
    }

    @Test
    fun goingToBackgroundPausesAndSavesRestorableDraft() = runTest {
        val store = FakeStore()
        val m = model(testExam(3), SessionMode.EXAM, store, timeLimitMinutes = 10)
        m.next()
        m.toggleOption(2)
        clock.advance(65.0)
        m.onBackground()
        assertEquals(AttemptScreen.Paused(PauseReason.BACKGROUND), m.screen)
        assertTrue(m.state.value.navigator.isEmpty())
        advanceUntilIdle()
        val draft = store.draft!!
        clock.advance(3_600.0) // thời gian ở nền không bị trừ
        val restored = ExamSession.restore(testExam(3), draft, clock)
        val again = AttemptModel(restored, store, this, { 1uL }, lock)
        assertEquals(AttemptScreen.Paused(PauseReason.BACKGROUND), again.screen)
        again.resume()
        assertEquals(1, again.answering().question.index)
    }

    @Test
    fun discardedAttemptIsNotSavedAgainWhenScreenStops() = runTest {
        val store = FakeStore(writeDelayMillis = 50)
        val m = model(store = store)
        m.toggleOption(0)
        m.discard()
        m.onBackground() // ON_STOP đến sau Bỏ bài (rời màn hình, đóng Activity)
        m.toggleOption(1)
        advanceUntilIdle()
        assertEquals(listOf("clearDraft"), store.log)
        assertNull(store.draft)
        assertTrue(m.answering().question.options[0].isSelected)
    }

    @Test
    fun failedDraftWritesDoNotCrash() = runTest {
        val store = FakeStore(failDraft = true)
        val m = model(store = store)
        m.onBackground()
        m.discard()
        advanceUntilIdle() // lỗi chưa bắt thì runTest báo lỗi ở đây
        assertTrue(m.screen is AttemptScreen.Paused)
    }

    @Test
    fun backgroundKeepsUserPauseAndStillSaves() = runTest {
        val store = FakeStore()
        val m = model(store = store)
        m.pause()
        m.onBackground()
        assertEquals(AttemptScreen.Paused(PauseReason.USER), m.screen)
        advanceUntilIdle()
        assertEquals(listOf("saveDraft"), store.log)
    }

    @Test
    fun backgroundAfterTimeUpSavesLockedReviewWithoutPausing() = runTest {
        val store = FakeStore()
        val m = model(mode = SessionMode.EXAM, store = store, timeLimitMinutes = 1)
        clock.advance(61.0)
        m.tick()
        m.onBackground()
        val review = m.screen as AttemptScreen.Review
        assertTrue(review.summary.isLocked)
        advanceUntilIdle()
        assertEquals(SessionPhase.Reviewing(true), store.draft!!.phase)
    }

    @Test
    fun backgroundAfterSubmitDoesNotSaveDraft() = runTest {
        val store = FakeStore()
        val m = model(store = store)
        m.openReview()
        m.submit()
        m.onBackground()
        advanceUntilIdle()
        assertEquals(listOf("previous", "saveAttempt"), store.log)
    }

    @Test
    fun timeWarningsShowAutoDismissedBanners() = runTest {
        val m = model(mode = SessionMode.EXAM, timeLimitMinutes = 10)
        clock.advance(300.0)
        m.tick()
        val warning = m.state.value.banner!!
        assertEquals(SessionBanner.Kind.TimeWarning(5), warning.kind)
        assertTrue(warning.autoDismisses)
        m.dismissBanner(warning.id)
        assertNull(m.state.value.banner)
        clock.advance(240.0)
        m.tick()
        assertEquals(SessionBanner.Kind.TimeWarning(1), m.state.value.banner!!.kind)
    }

    @Test
    fun timeUpGoesStraightToLockedReview() = runTest {
        val m = model(mode = SessionMode.EXAM, timeLimitMinutes = 1)
        m.toggleOption(0)
        clock.advance(70.0)
        m.tick()
        val review = m.screen as AttemptScreen.Review
        assertTrue(review.summary.isLocked)
        assertFalse(review.summary.canReturnToAttempt)
        // Dải hết giờ ở lại trên Rà soát khoá, không tự ẩn.
        assertEquals(SessionBanner.Kind.TimeUp, m.state.value.banner!!.kind)
        assertFalse(m.state.value.banner!!.autoDismisses)
        assertEquals("00:00", m.state.value.clock.text)
    }

    @Test
    fun tickWithoutEventsOnlyUpdatesClock() = runTest {
        val m = model()
        val before = m.state.value
        clock.advance(1.0)
        m.tick()
        assertEquals(before.copy(clock = before.clock.copy(seconds = 1, text = "00:01")), m.state.value)
    }

    @Test
    fun restoredTimeUpSessionOpensLockedReview() = runTest {
        val exam = testExam(2)
        val running = startSession(exam, SessionMode.EXAM, clock, timeLimitMinutes = 1)
        clock.advance(90.0)
        running.tick()
        val snapshot = running.snapshot()
        assertEquals(SessionPhase.TimeUp, snapshot.phase)
        val m = model(session = ExamSession.restore(exam, snapshot, clock))
        assertTrue((m.screen as AttemptScreen.Review).summary.isLocked)
    }

    @Test
    fun submitShowsResultsThenSavesAfterReadingPrevious() = runTest {
        val store = FakeStore(writeDelayMillis = 10, previous = 20)
        val m = model(testExam(4), SessionMode.EXAM, store)
        m.toggleOption(0)
        m.openReview()
        m.submit()
        val saving = (m.screen as AttemptScreen.Results).results
        assertEquals(SaveState.SAVING, saving.saveState)
        assertNull(saving.previousDelta)
        advanceUntilIdle()
        val saved = (m.screen as AttemptScreen.Results).results
        assertEquals(SaveState.SAVED, saved.saveState)
        assertEquals(5, saved.previousDelta) // 25% − 20%
        assertEquals(listOf("previous", "saveAttempt"), store.log)
    }

    @Test
    fun failedSaveIsReportedOnResults() = runTest {
        val m = model(store = FakeStore(failSave = true))
        m.openReview()
        m.submit()
        advanceUntilIdle()
        assertEquals(SaveState.FAILED, (m.screen as AttemptScreen.Results).results.saveState)
    }

    @Test
    fun writesRunInCallOrderSoDiscardWinsOverEarlierDraftSave() = runTest {
        val store = FakeStore(writeDelayMillis = 50)
        val m = model(store = store)
        m.onBackground()
        m.discard()
        advanceUntilIdle()
        assertEquals(listOf("saveDraft", "clearDraft"), store.log)
        assertNull(store.draft)
    }

    @Test
    fun draftSavedBeforeSubmitIsClearedBySavingAttempt() = runTest {
        val store = FakeStore(writeDelayMillis = 50)
        val m = model(store = store)
        m.onBackground()
        m.resume()
        m.openReview()
        m.submit()
        advanceUntilIdle()
        assertEquals(listOf("saveDraft", "previous", "saveAttempt"), store.log)
        assertNull(store.draft)
    }

    @Test
    fun retakeKeepsSelectionWithNewSeed() = runTest {
        val options = CompositionOptions(QuestionSelection.Random(2), shuffleQuestions = true, shuffleOptions = true, seed = 5uL)
        val m = model(session = startSession(testExam(4), SessionMode.EXAM, clock, options, timeLimitMinutes = 20))
        assertNull(m.retake())
        m.openReview()
        m.submit()
        assertEquals(NextAttempt(uuid(1), SessionMode.EXAM, options.copy(seed = 99uL), 20, "Nguyễn Văn A", false), m.retake())
    }

    @Test
    fun practiceIncorrectStartsLockedPracticeForSameCandidate() = runTest {
        val m = model(testExam(3), SessionMode.EXAM)
        m.toggleOption(1) // sai
        m.openReview()
        m.submit()
        val next = m.practiceIncorrect()!!
        assertEquals(NextAttempt(uuid(1), SessionMode.PRACTICE, next.options, null, "Nguyễn Văn A", true), next)
        assertEquals(99uL, next.options.seed)
        m.openAnswerReview()
        assertTrue((m.screen as AttemptScreen.AnswerReview).review.canPracticeIncorrect)
    }

    @Test
    fun hiddenAnswersReviewHasNoPracticeIncorrect() = runTest {
        val m = model(testExam(1, hideAnswers = true), SessionMode.EXAM)
        m.openReview()
        m.submit()
        m.openAnswerReview()
        val review = (m.screen as AttemptScreen.AnswerReview).review
        assertTrue(review.answersHidden)
        assertFalse(review.canPracticeIncorrect)
        assertNull(m.practiceIncorrect())
    }

    @Test
    fun answerReviewFiltersStepsAndGoesBack() = runTest {
        val m = model(testExam(4))
        m.toggleOption(1) // 1 sai
        m.next()
        m.toggleOption(0) // 2 đúng
        m.next()
        m.toggleOption(2) // 3 sai, 4 chưa làm
        m.openReview()
        m.submit()
        m.openAnswerReview(ReviewFilter.INCORRECT)
        var review = (m.screen as AttemptScreen.AnswerReview).review
        assertEquals(listOf(0, 2), review.rows.map { it.index })
        m.openReviewQuestion(0)
        m.stepReviewQuestion(1)
        review = (m.screen as AttemptScreen.AnswerReview).review
        assertEquals(3, review.detail!!.number)
        assertEquals(1, review.positionInFilter)
        assertTrue(review.hasPrevious)
        assertFalse(review.hasNext)
        m.stepReviewQuestion(1) // cuối bộ lọc: đứng yên
        assertEquals(3, (m.screen as AttemptScreen.AnswerReview).review.detail!!.number)
        assertTrue(m.backFromAnswerReview())
        assertNull((m.screen as AttemptScreen.AnswerReview).review.detail)
        assertTrue(m.backFromAnswerReview())
        assertTrue(m.screen is AttemptScreen.Results)
        assertFalse(m.backFromAnswerReview())
    }

    @Test
    fun navigatorShownOnlyWhileAnsweringOrReviewing() = runTest {
        val m = model()
        assertEquals(3, m.state.value.navigator.sumOf { it.cells.size })
        m.openReview()
        assertEquals(3, m.state.value.navigator.sumOf { it.cells.size })
        m.submit()
        assertTrue(m.state.value.navigator.isEmpty())
    }
}
