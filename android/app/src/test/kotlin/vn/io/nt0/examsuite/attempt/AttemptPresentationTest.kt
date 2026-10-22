package vn.io.nt0.examsuite.attempt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.scoring.SectionScore
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.data.library.AttemptSummary

/** Phần trình bày mà màn làm bài thêm trên lõi; luật của phiên (đồng hồ, chuyển trạng thái, chấm) đã test ở `:core`. */
class AttemptPresentationTest {
    @Test
    fun optionLabelsFollowPosition() {
        assertEquals("A", AttemptPresentation.optionLabel(0))
        assertEquals("Z", AttemptPresentation.optionLabel(25))
        assertEquals("27", AttemptPresentation.optionLabel(26))
    }

    @Test
    fun clockTextSwitchesToHoursFromSixtyMinutes() {
        assertEquals("00:00", AttemptPresentation.clockText(0))
        assertEquals("00:00", AttemptPresentation.clockText(-5))
        assertEquals("00:59", AttemptPresentation.clockText(59))
        assertEquals("59:59", AttemptPresentation.clockText(3_599))
        assertEquals("1:00:00", AttemptPresentation.clockText(3_600))
        assertEquals("10:02:05", AttemptPresentation.clockText(36_125))
    }

    @Test
    fun examClockCountsDownRoundingUpWithThreeLevels() {
        val clock = FakeClock()
        val session = startSession(testExam(3), SessionMode.EXAM, clock, timeLimitMinutes = 10)
        assertEquals(ClockDisplay(600, "10:00", ClockLevel.NORMAL, true), AttemptPresentation.clock(session))
        clock.advance(299.5) // còn 300,5 giây: vẫn bình thường, hiện 05:01
        assertEquals(ClockDisplay(301, "05:01", ClockLevel.NORMAL, true), AttemptPresentation.clock(session))
        clock.advance(0.5) // còn đúng 5 phút
        assertEquals(ClockLevel.WARNING, AttemptPresentation.clock(session).level)
        clock.advance(240.0) // còn 60 giây
        assertEquals(ClockDisplay(60, "01:00", ClockLevel.URGENT, true), AttemptPresentation.clock(session))
    }

    @Test
    fun practiceClockShowsElapsedRoundedDown() {
        val clock = FakeClock()
        val session = startSession(testExam(3), SessionMode.PRACTICE, clock)
        clock.advance(3_725.9)
        assertEquals(ClockDisplay(3_725, "1:02:05", ClockLevel.NORMAL, false), AttemptPresentation.clock(session))
    }

    @Test
    fun optionLabelsFollowShuffledDisplayOrder() {
        val clock = FakeClock()
        val shuffled = CompositionOptions(QuestionSelection.All, shuffleOptions = true, seed = 42uL)
        val session = startSession(testExam(1), SessionMode.PRACTICE, clock, shuffled)
        val view = AttemptPresentation.question(session)
        assertEquals(listOf("A", "B", "C", "D"), view.options.map { it.label })
        assertEquals(session.currentItem.optionOrder, view.options.map { it.optionId })
        // Nội dung đi theo mã gốc, nhãn theo vị trí.
        view.options.forEach { assertEquals("Lựa chọn ${it.optionId} của câu 1", it.text) }
    }

    @Test
    fun checkedAnswerMarksCorrectAndWrongSelection() {
        val session = startSession(testExam(1), SessionMode.PRACTICE, FakeClock())
        assertTrue(AttemptPresentation.question(session).options.all { it.mark == null })
        session.select(letter('B'))
        session.checkAnswer()
        val view = AttemptPresentation.question(session)
        assertEquals(mapOf("A" to OptionMark.CORRECT, "B" to OptionMark.INCORRECT), view.options.filter { it.mark != null }.associate { it.optionId.toString() to it.mark })
        assertEquals(AnswerCheckView(isCorrect = false, explanation = "Giải thích câu 1"), view.check)
        assertTrue(view.isLocked)
    }

    @Test
    fun checkAnswerAvailableOnlyForAnsweredUncheckedPracticeQuestion() {
        val practice = startSession(testExam(2), SessionMode.PRACTICE, FakeClock())
        assertFalse(AttemptPresentation.canCheckAnswer(practice))
        practice.select(letter('A'))
        assertTrue(AttemptPresentation.canCheckAnswer(practice))
        practice.checkAnswer()
        assertFalse(AttemptPresentation.canCheckAnswer(practice))
        val exam = startSession(testExam(2), SessionMode.EXAM, FakeClock())
        exam.select(letter('A'))
        assertFalse(AttemptPresentation.canCheckAnswer(exam))
    }

    @Test
    fun multipleQuestionHintCountsCorrectAnswers() {
        val session = startSession(testExam(2, multipleAt = 2), SessionMode.PRACTICE, FakeClock())
        session.next()
        assertEquals(2, AttemptPresentation.question(session).correctCount)
    }

    @Test
    fun navigatorGroupsBySectionInExamOrderWithSessionNumbers() {
        val clock = FakeClock()
        val shuffled = CompositionOptions(QuestionSelection.All, shuffleQuestions = true, seed = 3uL)
        val exam = testExam(2, 3)
        val session = startSession(exam, SessionMode.EXAM, clock, shuffled)
        session.select(letter('A'))
        session.toggleFlag()
        val sections = AttemptPresentation.navigator(session)
        assertEquals(listOf(uuid(1), uuid(2)), sections.map { it.id })
        val cells = sections.flatMap { it.cells }
        assertEquals((1..5).toList(), cells.map { it.number }.sorted())
        // Mỗi ô nằm trong phần của câu đó.
        sections.forEach { section ->
            section.cells.forEach { assertEquals(section.id, session.paper.items[it.index].sectionId) }
        }
        val first = cells.single { it.index == 0 }
        assertEquals(NavigatorCell(0, 1, isAnswered = true, isFlagged = true, isCurrent = true), first)
        assertEquals(1, cells.count { it.isAnswered })
    }

    @Test
    fun navigatorCellSpokenPartsInOrder() {
        assertEquals(
            listOf(CellPart.NUMBER, CellPart.ANSWERED, CellPart.FLAGGED, CellPart.CURRENT),
            NavigatorCell(0, 1, isAnswered = true, isFlagged = true, isCurrent = true).spokenParts,
        )
        assertEquals(listOf(CellPart.NUMBER, CellPart.UNANSWERED), NavigatorCell(4, 5, false, false, false).spokenParts)
    }

    @Test
    fun reviewSummaryListsUnansweredAndFlaggedPositions() {
        val session = startSession(testExam(4), SessionMode.EXAM, FakeClock())
        session.select(letter('A'))
        session.next()
        session.toggleFlag()
        session.next()
        session.select(letter('B'))
        session.toggleFlag()
        session.openReview()
        val summary = AttemptPresentation.reviewSummary(session)
        assertEquals(ReviewSummary(2, 2, 2, listOf(1, 3), listOf(1, 2), isLocked = false), summary)
        assertTrue(summary.needsSubmitConfirmation)
        assertTrue(summary.canReturnToAttempt)
    }

    @Test
    fun numberedSectionPrefixIsReadAsIs() {
        assertTrue(AttemptPresentation.hasNumberedSectionPrefix("Phần 2: Mạng"))
        assertTrue(AttemptPresentation.hasNumberedSectionPrefix("PHẦN 1"))
        assertTrue(AttemptPresentation.hasNumberedSectionPrefix("Section 3"))
        assertTrue(AttemptPresentation.hasNumberedSectionPrefix("Pha\u0302\u0300n 4")) // NFD
        assertFalse(AttemptPresentation.hasNumberedSectionPrefix("Phần mềm"))
        assertFalse(AttemptPresentation.hasNumberedSectionPrefix("Mạng"))
        assertFalse(AttemptPresentation.hasNumberedSectionPrefix("Phần"))
    }

    @Test
    fun announcementAddsSectionPrefixOnlyWhenNeeded() {
        val exam = testExam(1, 1, sectionTitles = listOf("Mạng", "Phần 2: Bảo mật"))
        val session = startSession(exam, SessionMode.PRACTICE, FakeClock())
        assertEquals(QuestionAnnouncement(1, 2, "Mạng", needsSectionPrefix = true), AttemptPresentation.announcement(session))
        session.next()
        assertEquals(QuestionAnnouncement(2, 2, "Phần 2: Bảo mật", needsSectionPrefix = false), AttemptPresentation.announcement(session))
    }

    @Test
    fun weakestSectionUsesDisplayedPercentFirstOnTie() {
        fun s(n: Int, correct: Int, total: Int) = SectionScore(uuid(n), "P$n", total, correct)
        // 1/3 và 33/100 đều hiện 33%: bằng nhau, lấy phần đứng trước.
        assertEquals(uuid(2), AttemptPresentation.weakestSectionId(listOf(s(1, 9, 10), s(2, 1, 3), s(3, 33, 100))))
        // Phần 0/0 không tính; còn một phần có câu thì không đánh dấu.
        assertNull(AttemptPresentation.weakestSectionId(listOf(s(1, 0, 0), s(2, 1, 2))))
        assertEquals(uuid(3), AttemptPresentation.weakestSectionId(listOf(s(1, 0, 0), s(2, 2, 2), s(3, 0, 2))))
    }

    @Test
    fun previousAttemptIsLatestOfSameExamAndMode() {
        fun a(n: Int, exam: Int, mode: SessionMode, at: Long, percent: Int) = AttemptSummary(
            attemptId = uuid(500 + n), examId = uuid(exam), examTitle = "Đề", examCode = null, candidateName = "A", mode = mode,
            startedAtMillis = at - 60_000, submittedAtMillis = at, elapsedSeconds = 60.0, timeLimitMinutes = null, total = 10,
            correct = percent / 10, score1000 = percent * 10, percent = percent, passPercent = 70, passed = percent >= 70,
        )
        val attempts = listOf(
            a(1, 1, SessionMode.PRACTICE, 1_000, 40),
            a(2, 1, SessionMode.EXAM, 2_000, 50),
            a(3, 1, SessionMode.PRACTICE, 3_000, 60),
            a(4, 2, SessionMode.PRACTICE, 4_000, 90), // đề khác
            a(5, 1, SessionMode.PRACTICE, 5_000, 80),
        )
        assertEquals(80, AttemptPresentation.previousAttempt(attempts, uuid(1), SessionMode.PRACTICE)?.percent)
        assertEquals(50, AttemptPresentation.previousAttempt(attempts, uuid(1), SessionMode.EXAM)?.percent)
        // Mở lần thi cũ từ Lịch sử thi: lần trước nó, không phải lần mới hơn.
        assertEquals(60, AttemptPresentation.previousAttempt(attempts, uuid(1), SessionMode.PRACTICE, beforeMillis = 5_000)?.percent)
        assertNull(AttemptPresentation.previousAttempt(attempts, uuid(1), SessionMode.PRACTICE, beforeMillis = 1_000))
        assertNull(AttemptPresentation.previousAttempt(attempts, uuid(3), SessionMode.PRACTICE))
    }

    @Test
    fun resultsComparePercentWithPreviousAndCountIncorrect() {
        val session = startSession(testExam(2, 2), SessionMode.EXAM, FakeClock())
        session.select(letter('A'))
        session.next()
        session.select(letter('B'))
        session.openReview()
        session.submit()
        val view = AttemptPresentation.results(session, previousPercent = 30, saveState = SaveState.SAVED)
        assertEquals(25, view.percent)
        assertEquals(-5, view.previousDelta)
        assertEquals(1, view.incorrectCount)
        assertEquals(listOf(50, 0), view.sections.map { it.percent })
        assertEquals(listOf(false, true), view.sections.map { it.isWeakest })
        assertNull(AttemptPresentation.results(session, null, SaveState.SAVED).previousDelta)
    }
}
