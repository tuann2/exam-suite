package vn.io.nt0.examsuite.core

import vn.io.nt0.examsuite.core.attempt.AttemptPayload
import vn.io.nt0.examsuite.core.composer.CompositionOptions
import vn.io.nt0.examsuite.core.composer.ExamComposer
import vn.io.nt0.examsuite.core.composer.QuestionSelection
import vn.io.nt0.examsuite.core.file.QuestionFingerprint
import vn.io.nt0.examsuite.core.model.Exam
import vn.io.nt0.examsuite.core.model.OptionId
import vn.io.nt0.examsuite.core.session.ExamSession
import vn.io.nt0.examsuite.core.session.SessionMode

/** Phiên đã nộp cố định trên fixture `kien-thuc-chung`, dùng cho JSON mẫu payload và test Xem lại. */
object AttemptSamples {
    val exam: Exam = Repo.exam("kien-thuc-chung")

    /** Luyện tập, xáo câu và đáp án, seed lớn hơn 2^63 (phải giữ đủ 64 bit); câu 1 đúng, câu 2 sai, đánh dấu câu 3. */
    fun practice(clock: FakeClock = FakeClock()): ExamSession {
        val options = CompositionOptions(QuestionSelection.All, shuffleQuestions = true, shuffleOptions = true, seed = 18_446_744_073_709_551_557uL)
        val s = ExamSession.start(exam, ExamComposer.compose(exam, options), SessionMode.PRACTICE, null, "Nguyễn Văn A", clock)
        val q = s.currentQuestion
        q.correct.forEach { s.select(it) }
        s.checkAnswer()
        s.next()
        val wrong = s.currentQuestion.options.map { it.id }.first { it !in s.currentQuestion.correctSet }
        s.select(wrong)
        s.next(); s.toggleFlag()
        clock.advance(125.0)
        s.openReview(); s.submit()
        return s
    }

    fun payload(session: ExamSession = practice()): AttemptPayload = AttemptPayload.from(session, QuestionFingerprint.fingerprints(session.exam))

    fun letters(text: String): Set<OptionId> = text.map { OptionId.of(it.toString())!! }.toSet()
}
