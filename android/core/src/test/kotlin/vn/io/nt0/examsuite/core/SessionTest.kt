package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.Build.opt
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.composer.ExamPaper
import vn.io.nt0.examsuite.core.composer.PaperItem
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.QuestionType
import vn.io.nt0.examsuite.core.scoring.QuestionOutcome
import vn.io.nt0.examsuite.core.scoring.Scorer
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionCommand
import vn.io.nt0.examsuite.core.session.SessionEvent
import vn.io.nt0.examsuite.core.session.SessionException
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import java.time.Instant

/** Tình huống theo docs/product/exam-session.md và danh sách của `ExamSessionTests` bản macOS. */
class SessionTest {
    private val clock = FakeClock()
    private val exam: Exam = Build.exam(
        Build.section(1, Build.question(1, correct = "B"), Build.question(2, QuestionType.MULTIPLE, correct = "AC")),
        Build.section(2, Build.question(3, correct = "A", optionCount = 3)),
        timeLimitMinutes = 10,
    )
    private fun paper(e: Exam = exam) = ExamComposer.compose(e, CompositionOptions(seed = 1uL))

    private fun session(mode: SessionMode = SessionMode.EXAM, minutes: Int? = null, e: Exam = exam) =
        ExamSession.start(e, paper(e), mode, minutes, "Nguyễn Văn A", clock)

    private inline fun <reified T : SessionException> rejects(s: ExamSession, crossinline block: ExamSession.() -> Unit): T {
        val before = s.state
        val error = assertThrows(T::class.java) { s.block() }
        assertEquals(before.copy(pendingEvents = s.state.pendingEvents, issuedWarnings = s.state.issuedWarnings), s.state, "lệnh bị từ chối đổi phiên")
        return error
    }

    // ---------- Tạo phiên ----------

    @Test
    fun `Thi bắt đầu ngay, đang làm, câu đầu, đồng hồ chạy, thời hạn mặc định của đề`() {
        val s = session()
        assertEquals(SessionPhase.InProgress, s.phase)
        assertEquals(0, s.currentIndex)
        assertTrue(s.isClockRunning)
        assertEquals(10, s.timeLimitMinutes)
        assertEquals(Instant.parse("2026-10-22T08:00:00Z"), s.startedAt)
    }

    @Test
    fun `Luyện tập không đếm ngược, thời hạn truyền vào bị bỏ qua, Thi đổi được thời hạn, phải trong 1 tới 600`() {
        assertNull(session(SessionMode.PRACTICE, minutes = 5).timeLimitMinutes)
        assertNull(session(SessionMode.PRACTICE).remaining)
        assertEquals(45, session(minutes = 45).timeLimitMinutes)
        for (bad in listOf(0, 601)) assertEquals(bad, assertThrows(SessionException.InvalidTimeLimit::class.java) { session(minutes = bad) }.minutes)
        val outOfRange = exam.copy(timeLimitMinutes = 0)
        assertThrows(SessionException.InvalidTimeLimit::class.java) { session(e = outOfRange) }
        session(SessionMode.PRACTICE, e = outOfRange)
    }

    @Test
    fun `hideAnswers khoá Luyện tập nhưng vẫn thi được`() {
        val hidden = exam.copy(hideAnswers = true)
        assertThrows(SessionException.PracticeNotAllowed::class.java) { session(SessionMode.PRACTICE, e = hidden) }
        session(e = hidden)
    }

    @Test
    fun `đề đã tạo cho đề khác, rỗng, có câu lạ hay câu trùng bị từ chối`() {
        val other = ExamPaper(Build.id(1), paper().options, paper().items)
        assertThrows(SessionException.PaperExamMismatch::class.java) { ExamSession.start(exam, other, SessionMode.EXAM, null, "A", clock) }
        assertThrows(SessionException.EmptyPaper::class.java) { ExamSession.start(exam, paper().copy(items = emptyList()), SessionMode.EXAM, null, "A", clock) }
        val stranger = PaperItem(Build.id(77), Build.id(1), listOf(opt('A')))
        assertThrows(SessionException.UnknownQuestion::class.java) { ExamSession.start(exam, paper().copy(items = paper().items + stranger), SessionMode.EXAM, null, "A", clock) }
        assertThrows(SessionException.DuplicateQuestion::class.java) { ExamSession.start(exam, paper().copy(items = paper().items + paper().items[0]), SessionMode.EXAM, null, "A", clock) }
    }

    // ---------- Trả lời, đánh dấu, điều hướng ----------

    @Test
    fun `single thay đáp án, chọn lại giữ, multiple bật tắt, tắt hết là chưa trả lời`() {
        val s = session()
        s.select(opt('A')); s.select(opt('B')); s.select(opt('B'))
        assertEquals(setOf(opt('B')), s.answers[exam.allQuestions[0].id])
        s.next()
        s.select(opt('A')); s.select(opt('C')); s.select(opt('A'))
        assertEquals(setOf(opt('C')), s.answers[exam.allQuestions[1].id])
        s.select(opt('C'))
        assertTrue(exam.allQuestions[1].id !in s.answers)
        assertEquals(2, s.unansweredCount)
    }

    @Test
    fun `lựa chọn không thuộc câu bị từ chối, xoá đáp án, đáp án theo id gốc không theo vị trí hiển thị`() {
        val shuffled = ExamComposer.compose(exam, CompositionOptions(shuffleOptions = true, seed = 3uL))
        val s = ExamSession.start(exam, shuffled, SessionMode.EXAM, null, "A", clock)
        rejects<SessionException.UnknownOption>(s) { select(opt('Z')) }
        val original = s.currentItem.optionOrder.last()
        s.select(original)
        assertEquals(setOf(original), s.answers[s.currentItem.questionId])
        s.clearAnswer()
        assertTrue(!s.isAnswered(s.currentItem.questionId))
    }

    @Test
    fun `đánh dấu bật tắt theo id câu, điều hướng ở biên đứng yên, goTo ngoài khoảng bị từ chối`() {
        val s = session()
        s.toggleFlag(); assertEquals(1, s.flaggedCount); s.toggleFlag(); assertEquals(0, s.flaggedCount)
        s.previous(); assertEquals(0, s.currentIndex)
        s.goTo(2); s.next(); assertEquals(2, s.currentIndex)
        assertEquals(SessionException.IndexOutOfRange(3, 3), rejects<SessionException.IndexOutOfRange>(s) { goTo(3) })
    }

    @Test
    fun `lệnh sai trạng thái ném InvalidCommand và giữ nguyên phiên, ở Thi và Luyện tập`() {
        for (mode in SessionMode.entries) {
            val s = session(mode)
            rejects<SessionException.InvalidCommand>(s) { resume() }
            rejects<SessionException.InvalidCommand>(s) { submit() }
            rejects<SessionException.InvalidCommand>(s) { returnToAttempt() }
            s.pause(PauseReason.USER)
            for (cmd in listOf<ExamSession.() -> Unit>({ select(opt('A')) }, { clearAnswer() }, { toggleFlag() }, { next() }, { previous() }, { goTo(0) }, { openReview() }, { pause(PauseReason.USER) })) {
                rejects<SessionException.InvalidCommand>(s, cmd)
            }
        }
    }

    @Test
    fun `đích của các chuyển trạng thái hợp lệ, quay lại làm bài có thể tới thẳng một câu, nộp từ rà soát`() {
        val s = session()
        s.openReview(); assertEquals(SessionPhase.Reviewing(false), s.phase)
        s.pause(PauseReason.USER); assertEquals(SessionPhase.Paused, s.phase)
        s.resume(); assertEquals(SessionPhase.Reviewing(false), s.phase)
        s.returnToAttempt(2); assertEquals(SessionPhase.InProgress to 2, s.phase to s.currentIndex)
        s.openReview(); s.submit(); assertEquals(SessionPhase.Submitted, s.phase)
        assertEquals(Instant.parse("2026-10-22T08:00:00Z"), s.submittedAt)
    }

    // ---------- Kiểm tra đáp án ----------

    @Test
    fun `Kiểm tra đáp án hiện đúng sai và giải thích rồi khoá câu đó, gọi lại cùng kết quả, đánh dấu vẫn được`() {
        val s = session(SessionMode.PRACTICE)
        s.select(opt('A'))
        val check = s.checkAnswer()
        assertEquals(QuestionOutcome.INCORRECT, check.outcome)
        assertEquals(setOf(opt('B')), check.correctOptions)
        assertEquals("Giải thích 1", check.explanation)
        assertEquals(check, s.checkAnswer())
        rejects<SessionException.AnswerLocked>(s) { select(opt('B')) }
        rejects<SessionException.AnswerLocked>(s) { clearAnswer() }
        s.toggleFlag()
    }

    @Test
    fun `không kiểm được câu chưa trả lời, chỉ khi đang làm, không có ở Thi`() {
        val p = session(SessionMode.PRACTICE)
        rejects<SessionException.NoAnswerToCheck>(p) { checkAnswer() }
        p.select(opt('B')); p.openReview()
        rejects<SessionException.InvalidCommand>(p) { checkAnswer() }
        val e = session()
        e.select(opt('B'))
        assertEquals(SessionException.UnavailableInMode(SessionCommand.CHECK_ANSWER, SessionMode.EXAM), rejects<SessionException.UnavailableInMode>(e) { checkAnswer() })
    }

    // ---------- Đồng hồ ----------

    @Test
    fun `tạm dừng không trừ giờ, Luyện tập cũng dừng đo, rà soát vẫn tính giờ`() {
        val s = session()
        clock.advance(60.0); s.pause(PauseReason.USER); clock.advance(500.0)
        assertEquals(60.0, s.elapsed); assertTrue(!s.isClockRunning)
        s.resume(); clock.advance(30.0); s.openReview(); clock.advance(30.0)
        assertEquals(120.0, s.elapsed)
        val p = session(SessionMode.PRACTICE)
        clock.advance(10.0); p.pause(PauseReason.USER); clock.advance(100.0); p.resume(); clock.advance(5.0)
        assertEquals(15.0, p.elapsed)
    }

    @Test
    fun `tạm dừng lâu hơn thời hạn không gây hết giờ và không phát cảnh báo`() {
        val s = session(minutes = 1)
        s.pause(PauseReason.USER); clock.advance(3_600.0)
        assertEquals(emptyList<SessionEvent>(), s.tick())
        assertEquals(SessionPhase.Paused, s.phase)
    }

    @Test
    fun `máy ngủ, tạm dừng, giờ ngủ không bị trừ, thức dậy vẫn tạm dừng, ngủ khi rà soát thì quay về rà soát`() {
        val s = session()
        clock.advance(10.0); s.pause(PauseReason.SYSTEM_SLEEP); clock.advance(10_000.0)
        assertEquals(PauseReason.SYSTEM_SLEEP to SessionPhase.Paused, s.pauseReason to s.phase)
        assertEquals(10.0, s.elapsed)
        s.resume(); assertNull(s.pauseReason)
        s.openReview(); s.pause(PauseReason.SYSTEM_SLEEP); s.resume()
        assertEquals(SessionPhase.Reviewing(false), s.phase)
    }

    @Test
    fun `tick mỗi giây phát cảnh báo 5 phút, 1 phút, hết giờ, mỗi cái đúng một lần, đúng thời điểm`() {
        val s = session(minutes = 6)
        val events = mutableListOf<Pair<Int, SessionEvent>>()
        for (second in 1..400) { clock.advance(1.0); s.tick().forEach { events += second to it } }
        assertEquals(listOf(60 to SessionEvent.Warning(5), 300 to SessionEvent.Warning(1), 360 to SessionEvent.TimeUp), events)
        assertEquals(360.0, s.elapsed)
    }

    @Test
    fun `tick thưa nhảy qua mốc vẫn phát đủ theo thứ tự 5 rồi 1, đã hết giờ thì chỉ phát timeUp, chuỗi tick thưa mỗi mốc một lần`() {
        val a = session(minutes = 10)
        clock.advance(9.5 * 60); assertEquals(listOf(SessionEvent.Warning(5), SessionEvent.Warning(1)), a.tick())
        assertEquals(emptyList<SessionEvent>(), a.tick())
        val b = session(minutes = 10)
        clock.advance(11 * 60.0); assertEquals(listOf(SessionEvent.TimeUp), b.tick())
        val c = session(minutes = 10)
        clock.advance(6 * 60.0); assertEquals(listOf(SessionEvent.Warning(5)), c.tick())
        clock.advance(1.0); assertEquals(emptyList<SessionEvent>(), c.tick())
        clock.advance(3 * 60.0); assertEquals(listOf(SessionEvent.Warning(1)), c.tick())
    }

    @Test
    fun `thời hạn ngắn chỉ cảnh báo các mốc nhỏ hơn thời hạn`() {
        val five = session(minutes = 5)
        clock.advance(4.5 * 60); assertEquals(listOf(SessionEvent.Warning(1)), five.tick())
        val one = session(minutes = 1)
        clock.advance(59.0); assertEquals(emptyList<SessionEvent>(), one.tick())
    }

    @Test
    fun `tạm dừng không làm mất hay lặp cảnh báo`() {
        val s = session(minutes = 10)
        clock.advance(5 * 60.0 + 1); s.pause(PauseReason.USER)
        assertEquals(listOf(SessionEvent.Warning(5)), s.tick())
        clock.advance(600.0); s.resume(); assertEquals(emptyList<SessionEvent>(), s.tick())
    }

    @Test
    fun `hết giờ, timeUp, rà soát khoá, không sửa đáp án, không quay lại, không tạm dừng, rồi nộp`() {
        val s = session(minutes = 1)
        clock.advance(61.0); assertEquals(listOf(SessionEvent.TimeUp), s.tick())
        assertEquals(SessionPhase.TimeUp, s.phase)
        rejects<SessionException.InvalidCommand>(s) { select(opt('A')) }
        rejects<SessionException.InvalidCommand>(s) { pause(PauseReason.USER) }
        s.openReview(); assertEquals(SessionPhase.Reviewing(true), s.phase)
        rejects<SessionException.InvalidCommand>(s) { returnToAttempt() }
        rejects<SessionException.InvalidCommand>(s) { pause(PauseReason.USER) }
        s.submit(); assertEquals(60.0, s.elapsed)
    }

    @Test
    fun `hết giờ khi đang rà soát chưa khoá cũng chuyển timeUp`() {
        val s = session(minutes = 1)
        s.openReview(); clock.advance(70.0)
        assertEquals(listOf(SessionEvent.TimeUp), s.tick())
        assertEquals(SessionPhase.TimeUp, s.phase)
    }

    @Test
    fun `lệnh sau thời hạn mà tick chưa chạy, phiên ghi nhận hết giờ, lệnh bị từ chối với phase timeUp, kể cả openReview, tick sau phát timeUp`() {
        val s = session(minutes = 1)
        clock.advance(61.0)
        val error = assertThrows(SessionException.InvalidCommand::class.java) { s.select(opt('B')) }
        assertEquals(SessionPhase.TimeUp, error.phase)
        assertTrue(s.answers.isEmpty())
        val t = session(minutes = 1)
        clock.advance(61.0)
        assertEquals(SessionException.InvalidCommand(SessionCommand.OPEN_REVIEW, SessionPhase.TimeUp), assertThrows(SessionException.InvalidCommand::class.java) { t.openReview() })
        assertEquals(listOf(SessionEvent.TimeUp), t.tick())
        t.openReview(); assertEquals(SessionPhase.Reviewing(true), t.phase)
    }

    @Test
    fun `cảnh báo phát hiện trong lúc chạy lệnh, kể cả lệnh bị từ chối, được giữ tới tick kế tiếp`() {
        val s = session(minutes = 10)
        clock.advance(5 * 60.0 + 1); s.next()
        clock.advance(4 * 60.0 + 1); assertThrows(SessionException.InvalidCommand::class.java) { s.resume() }
        assertEquals(listOf(SessionEvent.Warning(5), SessionEvent.Warning(1)), s.tick())
    }

    @Test
    fun `Luyện tập không hết giờ, tick không phát sự kiện, sau khi nộp tick không trả sự kiện còn chờ`() {
        val p = session(SessionMode.PRACTICE)
        clock.advance(100_000.0); assertEquals(emptyList<SessionEvent>(), p.tick())
        val s = session(minutes = 10)
        clock.advance(5 * 60.0 + 1); s.openReview(); s.submit()
        assertEquals(emptyList<SessionEvent>(), s.tick())
    }

    @Test
    fun `lùi giờ hệ thống không đổi thời gian đã làm, mốc ghi lại dùng giờ hệ thống`() {
        val s = session()
        clock.advance(30.0); clock.wall = Instant.parse("2020-01-01T00:00:00Z")
        assertEquals(30.0, s.elapsed)
        s.openReview(); s.submit()
        assertEquals(Instant.parse("2020-01-01T00:00:00Z"), s.submittedAt)
    }

    @Test
    fun `đồng hồ tiêm vào không đơn điệu thì khoảng đang chạy không âm`() {
        val s = session()
        clock.uptime -= 100.0
        assertEquals(0.0, s.elapsed)
    }

    // ---------- Nộp, Làm lại, Luyện lại câu sai ----------

    @Test
    fun `nộp ra ScoreResult đúng như Scorer, dừng đồng hồ`() {
        val s = session()
        s.select(opt('B')); s.openReview(); clock.advance(5.0); s.submit()
        assertEquals(Scorer.score(exam, s.paper.questionIds, s.answers), s.result)
        assertTrue(!s.isClockRunning)
    }

    @Test
    fun `luyện lại câu sai, câu sai và chưa làm theo thứ tự phiên, không xáo, seed truyền vào, null khi đúng hết hoặc đề hideAnswers`() {
        val s = session(SessionMode.PRACTICE)
        s.select(opt('B')); s.openReview(); s.submit()
        val options = s.practiceIncorrectOptions(9uL)!!
        assertEquals(QuestionSelection.Questions(s.paper.questionIds.drop(1)), options.selection)
        assertEquals(false to false, options.shuffleQuestions to options.shuffleOptions)
        assertEquals(9uL, options.seed)
        assertNull(session().practiceIncorrectOptions(1uL))
        val all = session(SessionMode.PRACTICE)
        all.select(opt('B')); all.next(); all.select(opt('A')); all.select(opt('C')); all.next(); all.select(opt('A')); all.openReview(); all.submit()
        assertNull(all.practiceIncorrectOptions(1uL))
        val hidden = session(e = exam.copy(hideAnswers = true))
        hidden.openReview(); hidden.submit()
        assertNull(hidden.practiceIncorrectOptions(1uL))
    }

    @Test
    fun `làm lại giữ cách chọn câu và xáo, thay seed, seed cũ tái hiện đúng đề`() {
        val options = CompositionOptions(QuestionSelection.Random(2), shuffleQuestions = true, shuffleOptions = true, seed = 42uL)
        val s = ExamSession.start(exam, ExamComposer.compose(exam, options), SessionMode.EXAM, null, "A", clock)
        assertEquals(options.copy(seed = 7uL), s.retakeOptions(7uL))
        assertEquals(s.paper, ExamComposer.compose(exam, s.retakeOptions(42uL)))
    }
}
