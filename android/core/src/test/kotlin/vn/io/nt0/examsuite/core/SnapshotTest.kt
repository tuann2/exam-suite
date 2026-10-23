package vn.io.nt0.examsuite.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertSame
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import vn.io.nt0.examsuite.core.Build.opt
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.PauseReason
import vn.io.nt0.examsuite.core.session.SessionEvent
import vn.io.nt0.examsuite.core.session.SessionException
import vn.io.nt0.examsuite.core.session.SessionMode
import vn.io.nt0.examsuite.core.session.SessionPhase
import vn.io.nt0.examsuite.core.session.SnapshotCodec

/** Phiên dở của mobile (mobile.md, Q7): chụp, mã hoá, khôi phục ở Tạm dừng, đúng câu, đúng thời gian đã làm. */
class SnapshotTest {
    private val exam = Build.simple(4, sections = 2, timeLimitMinutes = 10)
    private val clock = FakeClock()
    private fun start(mode: SessionMode = SessionMode.EXAM) =
        ExamSession.start(exam, ExamComposer.compose(exam, CompositionOptions(shuffleOptions = true, seed = 4uL)), mode, null, "A", clock)

    private fun roundTrip(s: ExamSession, restoreClock: FakeClock = FakeClock(uptime = 50.0)) =
        ExamSession.restore(exam, SnapshotCodec.decode(SnapshotCodec.encode(s.snapshot())), restoreClock)

    @Test
    fun `phiên đang làm khôi phục ở Tạm dừng vì xuống nền, đúng câu, đáp án, đánh dấu, thời gian, tiếp tục về đang làm`() {
        val s = start()
        s.select(s.currentItem.optionOrder[0]); s.next(); s.toggleFlag()
        clock.advance(90.0)
        val restoreClock = FakeClock(uptime = 50.0)
        val r = roundTrip(s, restoreClock)
        assertEquals(SessionPhase.Paused to PauseReason.BACKGROUND, r.phase to r.pauseReason)
        assertEquals(listOf(1, 1), listOf(r.currentIndex, r.flaggedCount))
        assertEquals(s.answers, r.answers)
        assertEquals(90.0, r.elapsed)
        restoreClock.advance(1_000.0)
        assertEquals(90.0, r.elapsed)
        r.resume(); assertEquals(SessionPhase.InProgress, r.phase)
        restoreClock.advance(10.0); assertEquals(100.0, r.elapsed)
        assertEquals(s.paper, r.paper)
        assertEquals(s.startedAt, r.startedAt)
    }

    @Test
    fun `rà soát chưa khoá về Tạm dừng rồi quay lại rà soát, đã tạm dừng thì giữ lý do cũ`() {
        val s = start()
        s.openReview()
        val r = roundTrip(s)
        r.resume(); assertEquals(SessionPhase.Reviewing(false), r.phase)
        val p = start()
        p.pause(PauseReason.USER)
        assertEquals(PauseReason.USER, roundTrip(p).pauseReason)
    }

    @Test
    fun `hết giờ và rà soát khoá giữ nguyên trạng thái, sự kiện chờ và cảnh báo đã phát được giữ`() {
        val s = start()
        clock.advance(5 * 60.0 + 1); s.next()
        val warned = roundTrip(s)
        assertEquals(listOf(SessionEvent.Warning(5)), warned.tick())
        warned.resume()
        val t = start()
        clock.advance(11 * 60.0); t.tick(); t.openReview()
        val locked = roundTrip(t)
        assertEquals(SessionPhase.Reviewing(true), locked.phase)
        assertEquals(600.0, locked.elapsed)
        locked.submit()
    }

    @Test
    fun `Luyện tập và đáp án đã khoá sau Kiểm tra đáp án qua được khôi phục`() {
        val s = start(SessionMode.PRACTICE)
        s.select(s.currentItem.optionOrder[0]); s.checkAnswer()
        val r = roundTrip(s)
        r.resume()
        assertThrows(SessionException.AnswerLocked::class.java) { r.select(opt('A')) }
    }

    @Test
    fun `đề đã đổi hay snapshot mâu thuẫn thì InvalidSnapshot, phiên đã nộp không chụp được`() {
        val s = start()
        s.select(s.currentItem.optionOrder[0])
        val snap = s.snapshot()
        val fewerOptions = exam.copy(sections = exam.sections.map { sec -> sec.copy(questions = sec.questions.map { it.copy(options = it.options.take(3)) }) })
        for (changed in listOf(exam.copy(id = Build.id(5)), exam.copy(sections = exam.sections.take(1)), fewerOptions, exam.copy(hideAnswers = true).let { it })) {
            if (changed.hideAnswers) continue
            assertThrows(SessionException.InvalidSnapshot::class.java) { ExamSession.restore(changed, snap, clock) }
        }
        assertThrows(SessionException.InvalidSnapshot::class.java) { ExamSession.restore(exam, snap.copy(currentIndex = 9), clock) }
        assertThrows(SessionException.InvalidSnapshot::class.java) { ExamSession.restore(exam, snap.copy(elapsedSeconds = 601.0), clock) }
        assertThrows(SessionException.InvalidSnapshot::class.java) { ExamSession.restore(exam, snap.copy(timeLimitMinutes = null), clock) }
        val practice = start(SessionMode.PRACTICE).snapshot()
        assertThrows(SessionException.InvalidSnapshot::class.java) { ExamSession.restore(exam.copy(hideAnswers = true), practice, clock) }
        s.openReview(); s.submit()
        assertThrows(SessionException.InvalidCommand::class.java) { s.snapshot() }
    }

    @Test
    fun `JSON phiên dở, phiên bản khác hay hỏng thì DecodeException để app bỏ phiên dở`() {
        val text = SnapshotCodec.encode(start().snapshot())
        assertEquals(start().snapshot().copy(elapsedSeconds = 0.0).paper, SnapshotCodec.decode(text).paper)
        for (bad in listOf(text.replace("\"draftVersion\":1", "\"draftVersion\":2"), "{}", "rác", text.replace("\"phase\":\"inProgress\"", "\"phase\":\"x\""))) {
            assertThrows(SnapshotCodec.DecodeException::class.java, { SnapshotCodec.decode(bad) }, bad)
        }
    }

    @Test
    fun `câu đã sửa từ lúc chụp thì không khôi phục, đáp án cũ có thể trỏ nhầm`() {
        val s = start()
        s.select(s.currentItem.optionOrder[0])
        val snap = s.snapshot()
        val edited = exam.copy(sections = exam.sections.map { sec -> sec.copy(questions = sec.questions.map { it.copy(text = it.text + " (sửa)") }) })
        assertThrows(SessionException.InvalidSnapshot::class.java) { ExamSession.restore(edited, snap, clock) }
        ExamSession.restore(exam, snap, clock)
    }

    @Test
    fun `dấu vân tay của phiên tính một lần cho các câu của phiên, phiên dở lưu đúng chúng`() {
        val s = start()
        assertSame(s.fingerprints, s.fingerprints)
        assertEquals(s.paper.items.associate { it.questionId to QuestionFingerprint.fingerprint(s.question(it)) }, s.fingerprints)
        assertEquals(s.fingerprints, s.snapshot().fingerprints)
        assertEquals(s.fingerprints, roundTrip(s).fingerprints)
    }

    @Test
    fun `snapshot mâu thuẫn trạng thái thì InvalidSnapshot`() {
        val running = start().snapshot()
        val paused = start().also { it.pause(PauseReason.USER) }.snapshot()
        val practice = start(SessionMode.PRACTICE).snapshot()
        val cases = listOf(
            paused.copy(pauseReason = null),
            paused.copy(phaseBeforePause = SessionPhase.TimeUp),
            running.copy(pauseReason = PauseReason.USER),
            running.copy(phase = SessionPhase.Reviewing(true)),
            running.copy(phase = SessionPhase.TimeUp, elapsedSeconds = 10.0),
            practice.copy(phase = SessionPhase.TimeUp),
            practice.copy(issuedWarnings = setOf(5)),
            running.copy(checkedQuestionIds = setOf(running.paper.questionIds[0]), answers = mapOf(running.paper.questionIds[0] to setOf(running.paper.items[0].optionOrder[0]))),
            running.copy(issuedWarnings = setOf(7)),
        )
        cases.forEachIndexed { i, bad -> assertThrows(SessionException.InvalidSnapshot::class.java, { ExamSession.restore(exam, bad, clock) }, "ca $i") }
    }

    @Test
    fun `JSON phiên dở chặt như payload, seed có dấu cộng, số viết trong ngoặc kép thì DecodeException`() {
        val text = SnapshotCodec.encode(start().snapshot())
        for ((old, new) in listOf("\"seed\":\"4\"" to "\"seed\":\"+4\"", "\"currentIndex\":0" to "\"currentIndex\":\"0\"")) {
            check(text.contains(old)) { old }
            assertThrows(SnapshotCodec.DecodeException::class.java, { SnapshotCodec.decode(text.replace(old, new)) }, new)
        }
    }

    @Test
    fun `phiên Thi tạm dừng ngay sau khi vượt mốc cảnh báo, có sự kiện chờ, khôi phục được và trả cảnh báo ở tick`() {
        val s = start()
        clock.advance(5 * 60.0 + 1); s.pause(PauseReason.USER)
        val r = roundTrip(s)
        assertEquals(SessionPhase.Paused to PauseReason.USER, r.phase to r.pauseReason)
        assertEquals(listOf(SessionEvent.Warning(5)), r.tick())
    }

    @Test
    fun `mảng cảnh báo đã phát viết dạng chuỗi thì DecodeException`() {
        val s = start()
        clock.advance(5 * 60.0 + 1); s.tick()
        val text = SnapshotCodec.encode(s.snapshot())
        check(text.contains("\"issuedWarnings\":[5]"))
        assertThrows(SnapshotCodec.DecodeException::class.java) { SnapshotCodec.decode(text.replace("\"issuedWarnings\":[5]", "\"issuedWarnings\":[\"5\"]")) }
    }
}
